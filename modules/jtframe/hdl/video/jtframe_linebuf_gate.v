/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 07-08-2025 */

module jtframe_linebuf_gate #(
    parameter       HW      = 9,
                    VW      = 9,
                    PW      = 8,
                    HS      = 0,
parameter [HW-1:0]  B_VIS   = 9'd30, A_VIS=9'd37, VIS=9'd304, // number of counting points before, after and during visible section
                    RST_CT  = 9'h058,         // starting value for wr_addr
                    RD_DLY  = 9'h00B,         // number of times to delay hdump
                    WR_STRT = RST_CT + B_VIS, // wr_addr to start checking rom_ok & rom_cs
                    WR_END  = WR_STRT+ VIS,   // wr_addr where stops checking rom_ok & rom_cs
                    RD_END  = WR_END + A_VIS, //
                    HTOT    = 9'd384,         // number of pxl_cen pulses in a line
                    HEND    = RST_CT + HTOT,  // value of wr_addr to stop cnt_cen
                    VB_END  = 9'h10F          // Must be same as in vtimer
) (
    input               rst,
    input               clk,
    input               cen,
    input               pxl_cen,
    input               lvbl,
    input               hs,
    input               we,

    // screen
    input      [HW-1:0] hdump,
    input      [VW-1:0] vdump,

    // to graphics block
    input      [PW-1:0] pxl_data,
    input               rom_ok,     // SDRAM output
    input               rom_cs,
    output   reg        cnt_cen,

    output     [PW-1:0] pxl_dump
);

reg  hs_cen, hs_l, done, fastwr;
wire pre_lvbl;
wire [HW-1:0] wr_addr, rd_addr;

assign pre_lvbl  = vdump==VB_END;

always @(*) begin
    done    = wr_addr>=RD_END;
    cnt_cen = 0;
    hs_cen  = 0;
    fastwr  = wr_addr<WR_STRT || wr_addr>WR_END && wr_addr<RD_END || hs && wr_addr < HEND; // It is needed for psac to have some pulse during hs
    if(cen) begin
        cnt_cen = rom_cs & rom_ok & !done;
        if( lvbl | pre_lvbl ) hs_cen  = ~hs & hs_l;  // starts drawing in buffer one line before lvbl is high
    end
    if( fastwr ) cnt_cen = cen;
end

always @(posedge clk) begin
    if(cen) hs_l     <= hs;
end

jtframe_counter #(.W(HW),.RST_VAL(RST_CT)) u_counter(
    .rst        ( hs_cen    ),
    .clk        ( clk       ),
    .cen        ( cnt_cen   ),
    .cnt        ( wr_addr   )
);

jtframe_sh #(.W(HW),.L(RD_DLY)) u_hb_dly(
    .clk        ( clk       ),
    .clk_en     ( pxl_cen   ),
    .din        ( hdump     ),
    .drop       ( rd_addr   )
);

jtframe_linebuf #(.AW(HW),.DW(PW)) u_linebuf(
    .clk        ( clk       ),
    .LHBL       ( ~hs       ),
    // New line writting
    .we         ( we        ),
    .wr_data    ( pxl_data  ),
    .wr_addr    ( wr_addr   ),
    // Previous line reading
    .rd_gated   (           ),
    .rd_addr    ( rd_addr   ),
    .rd_data    ( pxl_dump  )
);

endmodule
