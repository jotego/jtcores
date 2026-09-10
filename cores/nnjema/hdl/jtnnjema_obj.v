/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 8-9-2026 */

// 64 (galivan) / 128 (ninjemak) sprites, 16x16, buffered at vblank
// entry: y, code low, attr, x
// attr: 7 vflip, 6 hflip, 5:2 color, 2:1 code high, 0 x high
module jtnnjema_obj(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             m4_en,
    input             flip,
    input             hs,
    input             LVBL,
    input      [ 8:0] hdump,
    input      [ 8:0] vrender,

    // sprite RAM, second port
    output reg [ 8:0] oram_addr,
    input      [ 7:0] oram_data,

    // palette bank PROM
    output     [ 7:0] objbank_addr,
    input      [ 3:0] objbank_data,

    output     [16:2] rom_addr,
    output            rom_cs,
    input             rom_ok,
    input      [31:0] rom_data,

    output     [11:0] pxl        // {bank[3:0],color[3:0],px[3:0]}
);

reg  [ 8:0] dma_addr, dma_addr_l;
reg         dma_bsy, dma_we, LVBLl, hsl;
reg  [ 7:0] shadow[0:511];
reg  [ 7:0] dram;   // shadow read
reg  [ 8:0] scan_addr;
reg  [ 2:0] st;  // 0-3 read entry, 4-5 PROM, 6 draw
reg  [ 6:0] idx;
reg         scanning;
reg  [ 7:0] ypos, code_lo, attr;
reg  [ 8:0] ydiff;
wire [ 9:0] code;
reg  [ 9:0] dr_code;
reg  [ 8:0] dr_xpos;
reg  [ 3:0] dr_ysub;
reg  [ 7:0] dr_pal;
reg         dr_hflip, dr_vflip, dr_draw, inrange;
wire        dr_busy;
wire [16:2] pre_addr;
wire [31:0] swapped;

wire last_idx = idx == (m4_en ? 7'd127 : 7'd63);
// galivan only has 512 sprites: MAME wraps the code modulo the gfx count
assign code = m4_en ? {attr[2:1], code_lo} : {1'b0, attr[1], code_lo};
assign objbank_addr = code[9:2];
// gfx rows packed by V first: {code, v[3:0], h[3]}
assign rom_addr = {pre_addr[16:7],pre_addr[5:2],pre_addr[6]};
assign swapped  = rom_data;

// vblank DMA into the shadow buffer; oram dout lags the address by one clock
always @(posedge clk) begin
    LVBLl      <= LVBL;
    dma_addr_l <= dma_addr;
    dma_we     <= dma_bsy;
    if( dma_we ) shadow[dma_addr_l] <= oram_data;
    if( rst ) begin
        dma_bsy  <= 0;
        dma_addr <= 0;
    end else begin
        if( LVBLl && !LVBL ) begin
            dma_bsy  <= 1;
            dma_addr <= 0;
        end else if( dma_bsy ) begin
            {dma_bsy, dma_addr} <= {1'b1, dma_addr} + 10'd1;
        end
    end
end

always @* oram_addr = dma_addr;
always @(posedge clk) dram <= shadow[scan_addr];

// line scanner
always @(posedge clk) begin
    hsl <= hs;
    if( rst ) begin
        scanning <= 0;
        dr_draw  <= 0;
        st       <= 0;
        idx      <= 0;
    end else begin
        dr_draw <= 0;
        if( hs && !hsl ) begin
            scanning  <= 1;
            idx       <= 0;
            st        <= 0;
            scan_addr <= 0;
        end else if( scanning && !dr_draw ) begin
            st <= st+3'd1;
            case( st )
                0: scan_addr <= scan_addr+9'd1;                 // y read issued
                1: begin
                    ypos      <= dram;
                    scan_addr <= scan_addr+9'd1;
                end
                2: begin
                    code_lo   <= dram;
                    ydiff     <= vrender + {1'b0,ypos} - 9'd240;
                    scan_addr <= scan_addr+9'd1;
                end
                3: begin
                    attr      <= dram;
                    scan_addr <= scan_addr+9'd1;
                end
                4: begin // objbank PROM readout settles
                    dr_code  <= code;
                    dr_xpos  <= {attr[0],dram} - 9'd128;
                    dr_ysub  <= ydiff[3:0];
                    dr_hflip <= attr[6];
                    dr_vflip <= attr[7];
                    inrange  <= ydiff[8:4]==0;
                end
                5: begin
                    dr_pal  <= {objbank_data, attr[5:2]};
                    dr_draw <= inrange;
                end
                6: begin
                    st <= 6;
                    if( !dr_busy ) begin
                        if( last_idx )
                            scanning <= 0;
                        else begin
                            idx <= idx+7'd1;
                            st  <= 0;
                        end
                    end
                end
                default: st <= 0;
            endcase
        end
    end
end

`ifdef SIMULATION
always @(posedge clk) if( rom_cs && rom_ok && dr_code==10'h028 )
    $display("OBJF code=%x addr=%x data=%x ysub=%0d", dr_code, {rom_addr,2'b0}, rom_data, dr_ysub);
`endif

jtframe_objdraw #(
    .AW     (  9 ),
    .CW     ( 10 ),
    .PW     ( 12 ),
    .ALPHA  ( 15 ),
    .HFIX   (  0 ),
    .PACKED (  1 )
) u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),
    .draw       ( dr_draw   ),
    .busy       ( dr_busy   ),
    .code       ( dr_code   ),
    .xpos       ( dr_xpos   ),
    .ysub       ( dr_ysub   ),
    .hzoom      ( 6'd0      ),
    .hz_keep    ( 1'b0      ),
    .hflip      ( dr_hflip  ),
    .vflip      ( dr_vflip  ),
    .pal        ( dr_pal    ),
    .rom_addr   ( pre_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( swapped   ),
    .pxl        ( pxl       )
);

endmodule
