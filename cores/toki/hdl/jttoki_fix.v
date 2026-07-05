module jttoki_fix(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             cabal,

    input       [8:0] hdump,
    input       [8:0] vdump,
    input             blankn,

    output     [10:1] ram_addr,
    input      [15:0] ram_out,

    input      [15:0] gfx_data,
    input             gfx_ok,
    output     [15:1] gfx_addr,
    output            gfx_cs,

    input      [15:0] gfx_hi_data,
    input             gfx_hi_ok,
    output     [15:1] gfx_hi_addr,
    output            gfx_hi_cs,

    output      [7:0] pxl
);

localparam [8:0] HPF_START  = 9'd376;
localparam [8:0] HPF_ADD    = 9'd120;
localparam [8:0] ACTIVE_END = 9'd258;
localparam [1:0] FILL_IDLE  = 2'd0,
                 FILL_VRAM  = 2'd1,
                 FILL_WAIT  = 2'd2,
                 FILL_ROM   = 2'd3;

wire [31:0] toki_sorted;
wire [15:0] cabal_sorted;
wire [14:0] toki_raw_addr;
wire [ 7:0] toki_pxl, cabal_pxl;
wire [11:0] code = ram_out[11:0];
wire [ 3:0] pal  = ram_out[15:12];
wire        rom_ok = gfx_ok && gfx_hi_ok;
wire [ 8:0] vdump_adj = vdump - 9'd1;
wire [ 8:0] hdump_pf  = hdump >= HPF_START ? hdump + HPF_ADD : hdump;
wire [ 8:0] vdump_pf  = hdump >= HPF_START ? vdump : vdump_adj;
wire        active = blankn && hdump < ACTIVE_END;
wire        group_start = pxl_cen && hdump[2:0] == 3'd0;
wire        line_start  = group_start && hdump[7:0] == 8'd0;

wire [10:1] toki_ram_addr;
wire [15:1] toki_gfx_addr;
wire        toki_gfx_cs;
reg  [10:1] cabal_ram_addr;
reg  [15:1] cabal_gfx_addr;
reg         cabal_gfx_cs;

reg  [15:0] cabal_pxl_data = 16'd0;
reg  [15:0] group_data [0:1][0:31];
reg  [ 5:0] group_pal  [0:1][0:31];
reg  [ 5:0] cur_pal = 6'd0;
reg  [ 4:0] fill_slot, rom_slot;
reg  [ 2:0] fill_row;
reg  [ 8:0] fill_line;
reg  [ 5:0] rom_pal;
reg         display_bank, fill_bank;
reg         vram_pending, rom_pending;
reg  [ 1:0] fill_state;
integer     i;

wire [7:0] plane3 = { gfx_hi_data[ 4], gfx_hi_data[ 5], gfx_hi_data[ 6], gfx_hi_data[ 7],
                      gfx_hi_data[12], gfx_hi_data[13], gfx_hi_data[14], gfx_hi_data[15] };
wire [7:0] plane2 = { gfx_hi_data[ 0], gfx_hi_data[ 1], gfx_hi_data[ 2], gfx_hi_data[ 3],
                      gfx_hi_data[ 8], gfx_hi_data[ 9], gfx_hi_data[10], gfx_hi_data[11] };
wire [7:0] plane1 = { gfx_data[ 4],    gfx_data[ 5],    gfx_data[ 6],    gfx_data[ 7],
                      gfx_data[12],    gfx_data[13],    gfx_data[14],    gfx_data[15] };
wire [7:0] plane0 = { gfx_data[ 0],    gfx_data[ 1],    gfx_data[ 2],    gfx_data[ 3],
                      gfx_data[ 8],    gfx_data[ 9],    gfx_data[10],    gfx_data[11] };

assign toki_sorted = { plane3, plane2, plane1, plane0 };
assign cabal_sorted = {
    gfx_data[ 4], gfx_data[ 5], gfx_data[ 6], gfx_data[ 7],
    gfx_data[12], gfx_data[13], gfx_data[14], gfx_data[15],
    gfx_data[ 0], gfx_data[ 1], gfx_data[ 2], gfx_data[ 3],
    gfx_data[ 8], gfx_data[ 9], gfx_data[10], gfx_data[11]
};

assign cabal_pxl[7:2] = cur_pal;
assign cabal_pxl[0]   = cabal_pxl_data[ 7];
assign cabal_pxl[1]   = cabal_pxl_data[15];

assign ram_addr    = cabal ? cabal_ram_addr : toki_ram_addr;
assign gfx_addr    = cabal ? cabal_gfx_addr : toki_gfx_addr;
assign gfx_hi_addr = toki_gfx_addr;
assign gfx_cs      = cabal ? cabal_gfx_cs : toki_gfx_cs;
assign gfx_hi_cs   = cabal ? 1'b0 : toki_gfx_cs;
assign pxl         = active ? (cabal ? cabal_pxl : toki_pxl) : 8'h0f;

jtframe_tilemap #(
    .SIZE         ( 8  ),
    .PW           ( 8  ),
    .CW           ( 12 ),
    .VA           ( 10 ),
    .MAP_HW       ( 8  ),
    .MAP_VW       ( 8  ),
    .HJUMP        ( 0  ),
    .HDUMP_OFFSET ( -8 )
) u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .vdump      ( vdump_pf  ),
    .hdump      ( hdump_pf  ),
    .blankn     ( 1'b1      ),
    .flip       ( 1'b0      ),

    .vram_addr  ( toki_ram_addr ),

    .code       ( code      ),
    .pal        ( pal       ),
    .hflip      ( 1'b0      ),
    .vflip      ( 1'b0      ),

    .rom_addr   ( toki_gfx_addr ),
    .rom_data   ( toki_sorted   ),
    .rom_cs     ( toki_gfx_cs   ),
    .rom_ok     ( rom_ok    ),

    .pxl        ( toki_pxl  )
);

always @(posedge clk) begin
    if (rst) begin
        cabal_ram_addr  <= 10'd0;
        cabal_gfx_addr  <= 15'd0;
        cabal_gfx_cs    <= 1'b0;
        cabal_pxl_data  <= 16'd0;
        cur_pal         <= 6'd0;
        fill_slot       <= 5'd0;
        rom_slot        <= 5'd0;
        fill_row        <= 3'd0;
        fill_line       <= 9'd0;
        rom_pal         <= 6'd0;
        display_bank    <= 1'b0;
        fill_bank       <= 1'b1;
        vram_pending    <= 1'b0;
        rom_pending     <= 1'b0;
        fill_state      <= FILL_IDLE;
        for (i = 0; i < 32; i = i + 1) begin
            group_data[0][i] <= 16'd0;
            group_data[1][i] <= 16'd0;
            group_pal[0][i]  <= 6'd0;
            group_pal[1][i]  <= 6'd0;
        end
    end else begin
        if (group_start) begin
            cabal_pxl_data <= group_data[display_bank][hdump[7:3]];
            cur_pal        <= group_pal[display_bank][hdump[7:3]];
        end else if (pxl_cen) begin
            cabal_pxl_data <= cabal_pxl_data << 1;
        end

        if (line_start) begin
            display_bank <= fill_bank;
            fill_bank    <= ~fill_bank;
            fill_line    <= vdump;
            fill_row     <= vdump[2:0];
            fill_slot    <= 5'd0;
            fill_state   <= FILL_VRAM;
            vram_pending <= 1'b0;
            rom_pending  <= 1'b0;
            cabal_gfx_cs <= 1'b0;
        end

        case (fill_state)
            FILL_VRAM: begin
                cabal_ram_addr <= {fill_line[7:3], fill_slot};
                fill_state     <= FILL_WAIT;
            end

            FILL_WAIT: begin
                vram_pending <= 1'b1;
                fill_state   <= FILL_ROM;
            end

            FILL_ROM: begin
                if (vram_pending) begin
                    cabal_gfx_addr <= {2'd0, ram_out[9:0], fill_row};
                    cabal_gfx_cs   <= 1'b1;
                    rom_slot       <= fill_slot;
                    rom_pal        <= ram_out[15:10];
                    rom_pending    <= 1'b1;
                    vram_pending   <= 1'b0;
                end else if (rom_pending && gfx_ok) begin
                    group_data[fill_bank][rom_slot] <= cabal_sorted;
                    group_pal[fill_bank][rom_slot]  <= rom_pal;
                    cabal_gfx_cs                    <= 1'b0;
                    rom_pending                     <= 1'b0;
                    if (fill_slot == 5'd31) begin
                        fill_state <= FILL_IDLE;
                    end else begin
                        fill_slot  <= fill_slot + 5'd1;
                        fill_state <= FILL_VRAM;
                    end
                end
            end

            default: begin
                cabal_gfx_cs <= 1'b0;
            end
        endcase

        if (!rom_pending && fill_state != FILL_ROM)
            cabal_gfx_cs <= 1'b0;
    end
end

endmodule
