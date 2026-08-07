/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Volfied colour mixer: bitmap (background) behind PC090OJ sprites.
    Palette RAM 0x500000-0x503fff = 8192 entries, xBGR-555 (TC0070RGB/PC050CM).
*/

module jtvolfied_colmix(
    input           rst,
    input           clk,
    input           pxl_cen,

    input    [13:1] main_addr,
    input    [15:0] main_dout,
    output   [15:0] main_din,
    input    [ 1:0] main_dsn,
    input           main_rnw,
    input           pal_cs,

    input           preLHBL,
    input           preLVBL,
    output          LHBL,
    output          LVBL,

    input    [11:0] fb_pxl,
    input    [ 7:0] obj_pxl,
    input    [ 3:0] obj_pal,

    output    [4:0] red,
    output    [4:0] green,
    output    [4:0] blue,

    input     [3:0] gfx_en
);

wire [15:0] pal_dout;
reg  [12:0] pal_addr;
wire        obj_blank;
wire [ 1:0] cpu_we;

assign obj_blank = obj_pxl[3:0]==0 || !gfx_en[3];
assign cpu_we    = ~main_dsn & {2{pal_cs & ~main_rnw}};

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pal_addr <= 0;
    end else if(pxl_cen) begin
        if( !obj_blank )
            // sprites: palette idx = {1, sprite_ctrl[5:2], obj_pxl} = 0x1000-0x1fff
            pal_addr <= { 1'b1, obj_pal, obj_pxl };
        else
            pal_addr <= gfx_en[0] ? { 1'b0, fb_pxl } : 13'd0; // 12-bit bitmap index

    end
end

jtframe_dual_ram16 #(
    .AW         (        13  ),
    .SIMFILE    ( "pal.bin"  )
) u_palram(
    // Port 0: CPU
    .clk0   ( clk       ),
    .data0  ( main_dout ),
    .we0    ( cpu_we    ),
    .addr0  ( main_addr ),
    .q0     ( main_din  ),
    // Port 1: scanout
    .clk1   ( clk       ),
    .data1  ( 16'd0     ),
    .addr1  ( pal_addr  ),
    .we1    ( 2'd0      ),
    .q1     ( pal_dout  )
);

`ifdef SIMULATION
integer rgbnz=0, palwrnz=0, pdnz_all=0, palwr_lo=0; reg [15:0] maxpd=0; reg [12:0] maxpaddr=0, minwr=13'h1fff, maxwr=0; reg [27:0] vh=0;
always @(posedge clk) begin
    if(|cpu_we && main_dout!=0) begin
        palwrnz<=palwrnz+1;                            // nonzero palette writes
        if(main_addr<=13'h0bf) palwr_lo<=palwr_lo+1;   // ...into the read range 0-0xbf
        if(main_addr<minwr) minwr<=main_addr;
        if(main_addr>maxwr) maxwr<=main_addr;
    end
    // whole-frame (not gated by active window): does the palette EVER read nonzero?
    if(pal_dout[14:0]!=0) begin pdnz_all<=pdnz_all+1; if(pal_dout>maxpd) maxpd<=pal_dout; end
    if(pal_addr>maxpaddr) maxpaddr<=pal_addr;
    if(LHBL && LVBL && pal_dout[14:0]!=0) rgbnz<=rgbnz+1;
    vh<=vh+1;
    if(vh[23:0]==0)
        $display("[COLMIX] palwr_nz=%0d palwr_into_0-bf=%0d wr_range=%04x..%04x | pdout_nz=%0d max_pdout=%04x max_rdaddr=%04x",
                 palwrnz, palwr_lo, minwr, maxwr, pdnz_all, maxpd, maxpaddr);
end
`endif

jtframe_blank #(
    .DLY( 4),
    .DW (15)
) u_dly(
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),
    .preLHBL    ( preLHBL           ),
    .preLVBL    ( preLVBL           ),
    .LHBL       ( LHBL              ),
    .LVBL       ( LVBL              ),
    .preLBL     (                   ),
    .rgb_in     ( pal_dout[14:0]    ),
    .rgb_out    ( {blue,green,red}  )
);

endmodule
