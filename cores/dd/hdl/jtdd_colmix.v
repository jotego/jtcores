/*  This file is part of JTDD.
    JTDD program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTDD program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTDD.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 2-12-2017 */


module jtdd_colmix(
    input              clk,
    input              rst,
    (*direct_enable*) input pxl_cen,
    (*direct_enable*) input cen_Q,
    input      [7:0]   cpu_dout,
    input              cpu_wrn,
    output reg [7:0]   pal_dout,
    input [9:0]        cpu_AB,
    // blanking
    input              VBL,
    input              HBL,
    output             LVBL_dly,
    output             LHBL_dly,
    // Pixel inputs
    input [6:0]        char_pxl,  // called mcol in schematics
    input [7:0]        obj_pxl,  // called ocol in schematics
    input [7:0]        scr_pxl,  // called bcol in schematics
    input              pal_cs,
    // PROM programming
    input [7:0]        prog_addr,
    input [3:0]        prom_din,
    input              prom_prio_we,
    // Pixel output
    output reg [3:0]   red,
    output reg [3:0]   green,
    output reg [3:0]   blue,
    // Debug
    input      [3:0] gfx_en
);

parameter SIM_PRIO="../../../rom/21j-k-0";

wire [7:0] pal_gr;
wire [3:0] pal_b;
reg        pal_gr_we, pal_b_we;
reg  [8:0] pal_addr;
wire [1:0] prio;
wire       obj_blank  = ~gfx_en[2] | ~|obj_pxl[3:0];
wire       char_blank = ~gfx_en[0] | ~|char_pxl[3:0];
wire [7:0] scr2_pxl   = scr_pxl & {8{gfx_en[1]}}; // gated by global enable signal
wire [7:0] seladdr = { scr2_pxl[7], obj_pxl[7], obj_blank, char_blank, scr2_pxl[3:0] };

reg [7:0] pal_din;

always @(posedge clk) begin
    pal_gr_we <= pal_cs && !cpu_AB[9] && !cpu_wrn;
    pal_b_we  <= pal_cs &&  cpu_AB[9] && !cpu_wrn;
    pal_din   <= cpu_dout;
    pal_dout  <= cpu_AB[9] ? {4'hf, pal_b } : pal_gr;
    if( pal_cs )
        pal_addr <= cpu_AB[8:0];
    else 
        case( prio )
            default: pal_addr <= { 2'b00, char_pxl };
            2'd2:    pal_addr <= { 2'b01, obj_pxl[6:0] };
            2'd3:    pal_addr <= { 2'b10, scr2_pxl[6:0] };
        endcase

end

wire BL = ~LVBL_dly | ~LHBL_dly;

jtframe_sh #(.width(2), .stages(6)) u_sh(
    .clk    ( clk                   ),
    .clk_en ( pxl_cen               ),
    .din    ( ~{VBL, HBL}           ),
    .drop   ( {LVBL_dly, LHBL_dly } )
);

always @(posedge clk) if(pxl_cen) begin
    { blue, green, red } <= BL ? 12'd0 : { pal_b, pal_gr };
end

jtframe_ram #(.AW(9),.SIMFILE("pal_gr.bin")) u_pal_gr(
    .clk    ( clk         ),
    .cen    ( cen_Q     ),
    .data   ( pal_din     ),
    .addr   ( pal_addr    ),
    .we     ( pal_gr_we   ),
    .q      ( pal_gr      )
);

jtframe_ram #(.AW(9),.DW(4),.SIMFILE("pal_b.bin")) u_pal_b(
    .clk    ( clk           ),
    .cen    ( cen_Q       ),
    .data   ( cpu_dout[3:0] ),
    .addr   ( pal_addr      ),
    .we     ( pal_b_we      ),
    .q      ( pal_b         )
);

jtframe_prom #(.AW(8),.DW(2),.SIMFILE(SIM_PRIO)) u_prio(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( prom_din[1:0] ),
    .rd_addr( seladdr       ),
    .wr_addr( prog_addr     ),
    .we     ( prom_prio_we  ),
    .q      ( prio          )
);

endmodule