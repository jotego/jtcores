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
    parameter          HW      = 9, // 8,
                       VW      = 9, // 8,
                       PALW    = 4,
                       HOFFSET = 0,
                       PW      = PALW+4,
                       HS      = 0,
    parameter [HW-1:0] HOVER = {HW{1'd1}}, // H count at which a new line starts
                       HSTART = HOVER,      // H count starting value
parameter [8:0] WR_STRT=9'h060, // Positions in wr_addr skipped during blanking
                VB_END =9'h10F, // Must be same as in vtimer
                RST_CT =9'h058, // starting value for wr_addr
                RD_DLY =9'h00B, // number of times to delay hdump
                RD_END =9'h19F // Value of rd_addr when LHBL goes low
) (
    input               rst,
    input               clk,
    input               cen,
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

reg hs_cen, hs_l, done;
wire pre_lvbl;
wire [HW-1:0] wr_addr, rd_addr;

assign pre_lvbl  = vdump==VB_END;

always @(*) begin
    done    = wr_addr>=RD_END;
    cnt_cen = 0;
    hs_cen  = 0;
    if(cen) begin
        cnt_cen = rom_cs & rom_ok & !done;
        if( lvbl | pre_lvbl ) hs_cen  = ~hs & /*~*/hs_l;  // starts drawing in buffer one line before lvbl is high
    end
    if( wr_addr<WR_STRT ) cnt_cen = 1;
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
    .clk_en     ( cen       ),
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
