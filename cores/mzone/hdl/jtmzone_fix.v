// SPDX-License-Identifier: GPL-3.0-or-later

module jtmzone_fix #(
    // Align the FIX source and priority windows with FIX pixels at colmix.
    parameter FIX_EN_DLY=6
)(
    input               rst,
    input               clk,
    input               clk24,
    input               pxl_cen,

    input        [ 9:0] cpu_addr,
    input        [ 7:0] cpu_dout,
    input               cpu_rnw,
    input               vram_cs,
    input               cram_cs,
    output       [ 7:0] vram_dout,
    output       [ 7:0] cram_dout,

    input        [ 8:0] hdump,
    input        [ 8:0] vdump,
    input               flip,
    input               dip_orig_hactive,

    input        [ 3:0] prog_data,
    input        [ 7:0] prog_addr,
    input               prog_en,

    output reg   [11:0] rom_addr,
    output reg          rom_cs,
    input        [31:0] rom_data,
    input               rom_ok,

    output       [ 3:0] pxl,
    output              fix_src,
    output              fix_en
);

localparam [8:0] HVISIBLE       = 9'd287;
localparam [8:0] HTOTAL         = 9'd384;
localparam [8:0] FETCH_ADVANCE  = 9'd2;
localparam [8:0] FIX_WIDTH      = 9'd48;
localparam [8:0] FIX_FLIP_START = HVISIBLE-FIX_WIDTH+9'd1;
localparam [8:0] FIX_FLIP_END   = FIX_FLIP_START+FIX_WIDTH;
localparam [8:0] FIX_LEAD       = 9'd8;
localparam [8:0] FIX_PRIO_END   = 9'd47;
localparam [8:0] FIX_SRC_END    = 9'd48;
localparam [2:0] RD_PHASE       = 3'd7;
localparam [2:0] FETCH_PHASE    = 3'd0;
// A row loaded on phase 4 becomes glyph bits on the next pixel and reaches
// colmix after the character palette. This effective delay is what the
// colmix blanking delay must match.
localparam [2:0] LOAD_PHASE     = 3'd4;

reg  [31:0] pxl_data;
reg  [31:0] fetched_data;
wire [31:0] load_data = rom_cs && rom_ok ? rom_data : fetched_data;
reg  [ 9:0] ram_addr;
reg  [ 3:0] pal_msb, cur_pal;
reg         hflip, cur_hf;
wire [ 7:0] vram, cram;
wire        vram_we = vram_cs & ~cpu_rnw;
wire        cram_we = cram_cs & ~cpu_rnw;
wire [ 9:0] eff_addr = cpu_addr;

// FIX local X uses the common hdump reference, sign-extended in HBLANK.
// Its origin is 0 normally and FIX_FLIP_START (240) when flipped.
// hsum/heff include the fetch lead and the existing -flip phase correction.
// PCB counter reference mappings are documented in ../doc/timing.md.
wire [ 8:0] nonflip_hvisible = dip_orig_hactive ? 9'd287 : 9'd288;
wire [ 8:0] hsum_limit = flip ? HVISIBLE : nonflip_hvisible;
wire [ 8:0] hsum_base = hdump < hsum_limit ? hdump : { ~6'h0, hdump[2:0] };
wire [ 8:0] fix_origin = flip ? FIX_FLIP_START : 9'd0;
wire [ 8:0] fix_hsum = hsum_base - fix_origin;
wire [ 8:0] hsum = fix_hsum + FIX_LEAD - {8'd0, flip};
wire        blank_fetch = hdump >= 9'd288 && hdump <= 9'd375;
wire [ 8:0] heff = blank_fetch ? hdump - 9'd160 :
                    flip ? FIX_WIDTH - 9'd1 - hsum : hsum;
// Use the PCB's 8-bit wrapped h counter for phase and tile column.
wire [ 7:0] h_eff = heff[7:0];
// Wrap the last eight raw lines onto PCB vcount 248..255 before flipping.
wire [ 7:0] vsum = vdump[8] ? vdump[7:0] - 8'd8 : vdump[7:0];
wire [ 7:0] v_eff = flip ? ~vsum : vsum;
wire [11:0] tile_addr = { cram[7], vram, v_eff[2:0] ^ {3{cram[5]}} };
// Advance only the read/request coordinate by two display pixels.
// Keep the original load coordinate and source/priority delays unchanged.
wire [8:0] fetch_hdump = hdump >= HTOTAL - FETCH_ADVANCE ?
                        hdump - (HTOTAL - FETCH_ADVANCE) : hdump + FETCH_ADVANCE;
wire [8:0] fetch_hsum_base = fetch_hdump < hsum_limit ? fetch_hdump : {~6'h0,fetch_hdump[2:0]};
wire [8:0] fetch_hsum = fetch_hsum_base - fix_origin + FIX_LEAD - {8'd0,flip};
wire fetch_blank = fetch_hdump >= 9'd288 && fetch_hdump <= 9'd375;
wire [8:0] fetch_heff_full = fetch_blank ? fetch_hdump - 9'd160 :
                           flip ? FIX_WIDTH - 9'd1 - fetch_hsum : fetch_hsum;
wire [7:0] fetch_heff = fetch_heff_full[7:0];
wire        read_tile = fetch_heff[2:0] == RD_PHASE;
wire        load_tile = h_eff[2:0] == LOAD_PHASE;
wire        fetch_tile = fetch_heff[2:0] == FETCH_PHASE;
wire [ 3:0] pxl_raw = cur_hf ? pxl_data[3:0] : pxl_data[31:28];
wire [ 3:0] color_raw = cur_pal;
wire [ 7:0] pal_addr = { color_raw, pxl_raw[0], pxl_raw[1], pxl_raw[2], pxl_raw[3] };
// FIX remains the character source for one pixel after its forced priority
// ends. Both controls use the same delay so that distinction reaches colmix.
wire        fix_en_pre  = flip ? hdump >= FIX_FLIP_START && hdump < FIX_FLIP_END :
                                 hdump >= nonflip_hvisible || hdump < FIX_PRIO_END;
wire        fix_src_pre = flip ? hdump >= FIX_FLIP_START && hdump < FIX_FLIP_END :
                                 hdump >= nonflip_hvisible || hdump < FIX_SRC_END;

jtframe_sh #(.W(1),.L(FIX_EN_DLY)) u_fix_en_dly(
    .clk    ( clk        ),
    .clk_en ( pxl_cen    ),
    .din    ( fix_en_pre ),
    .drop   ( fix_en     )
);

jtframe_sh #(.W(1),.L(FIX_EN_DLY)) u_fix_src_dly(
    .clk    ( clk         ),
    .clk_en ( pxl_cen     ),
    .din    ( fix_src_pre ),
    .drop   ( fix_src     )
);


always @(posedge clk) begin
    if( rst ) begin
        rom_addr <= 12'd0;
        rom_cs <= 1'b0;
        ram_addr <= 10'd0;
        pxl_data <= 32'd0;
        fetched_data <= 32'd0;
        pal_msb <= 4'd0;
        cur_pal <= 4'd0;
        hflip <= 1'b0;
        cur_hf <= 1'b0;
    end else begin
        // Match SCROLL: keep the request asserted until the ROM acknowledges it.
        if( rom_ok && rom_cs ) begin
            rom_cs <= 1'b0;
            fetched_data <= rom_data;
        end

        if( pxl_cen ) begin
            if( read_tile )
                ram_addr <= { v_eff[7:3], fetch_heff[7:3] };

            if( fetch_tile ) begin
                rom_addr <= tile_addr;
                rom_cs   <= 1'b1;
                pal_msb  <= cram[3:0];
                hflip    <= cram[6] ^ flip;
            end

            if( load_tile ) begin
                pxl_data <= {
                    load_data[4],  load_data[5],  load_data[6],  load_data[7],
                    load_data[0],  load_data[1],  load_data[2],  load_data[3],
                    load_data[12], load_data[13], load_data[14], load_data[15],
                    load_data[8],  load_data[9],  load_data[10], load_data[11],
                    load_data[20], load_data[21], load_data[22], load_data[23],
                    load_data[16], load_data[17], load_data[18], load_data[19],
                    load_data[28], load_data[29], load_data[30], load_data[31],
                    load_data[24], load_data[25], load_data[26], load_data[27]
                };
                cur_pal  <= pal_msb;
                cur_hf   <= hflip;
            end else begin
                pxl_data <= cur_hf ? pxl_data >> 4 : pxl_data << 4;
            end

        end
    end
end

jtframe_dual_ram #(
`ifdef SIMSCENE
    .SIMFILE ( "vram1.bin" ),
`endif
    .AW ( 10 ),
    .DW ( 8  )
) u_vram(
    .clk0   ( clk           ),
    .data0  ( 8'd0          ),
    .addr0  ( ram_addr      ),
    .we0    ( 1'b0          ),
    .q0     ( vram          ),

    .clk1   ( clk24         ),
    .data1  ( cpu_dout      ),
    .addr1  ( eff_addr      ),
    .we1    ( vram_we       ),
    .q1     ( vram_dout     )
);

jtframe_dual_ram #(
`ifdef SIMSCENE
    .SIMFILE ( "cram1.bin" ),
`endif
    .AW ( 10 ),
    .DW ( 8  )
) u_cram(
    .clk0   ( clk           ),
    .data0  ( 8'd0          ),
    .addr0  ( ram_addr      ),
    .we0    ( 1'b0          ),
    .q0     ( cram          ),

    .clk1   ( clk24         ),
    .data1  ( cpu_dout      ),
    .addr1  ( eff_addr      ),
    .we1    ( cram_we       ),
    .q1     ( cram_dout     )
);

jtframe_prom #(
    .DW ( 4 ),
    .AW ( 8 )
) u_palette(
    .clk    ( clk              ),
    .cen    ( pxl_cen          ),
    .data   ( prog_data        ),
    .wr_addr( prog_addr        ),
    .we     ( prog_en          ),
    .rd_addr( pal_addr         ),
    .q      ( pxl              )
);

endmodule
