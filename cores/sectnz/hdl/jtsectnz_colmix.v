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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 16-4-2020 */


module jtsectnz_colmix #(
    parameter CHARW = 6
) (
    input            rst,
    input            clk,
    input            cen12,
    input            pxl_cen,
    input            cpu_cen,

    // pixel input from generator modules
    input [CHARW-1:0]char_pxl,        // character color code
    input [6:0]      scr_pxl,
    input [6:0]      obj_pxl,
    input            preLVBL,
    input            preLHBL,
    output           LHBL,
    output           LVBL,
    // CPU inteface
    input [9:0]      AB,
    input            blue_cs,
    input            redgreen_cs,
    input [7:0]      DB,
    input            cpu_wrn,

    output     [3:0] red,
    output     [3:0] green,
    output     [3:0] blue,
    // Priority PROMs bd01.8j
    // input [7:0]     prog_addr,
    // input           prom_prior_we,
    // input [3:0]     prom_din,
    // Debug
    input      [3:0] gfx_en
);

reg [9:0] pixel_mux;

wire enable_char = gfx_en[0];
wire enable_scr  = gfx_en[1];
wire enable_obj  = gfx_en[3];

wire char_blank  = (&char_pxl[1:0]) | ~enable_char;
wire obj_blank   = (&obj_pxl[3:0])  | ~enable_obj;

reg  [2:0] obj_sel; // signals whether an object pixel is selected

reg  [7:0] seladdr;
reg  [1:0] selbus;

reg [6:0] scr0, obj0;
reg [CHARW-1:0] char0;

wire [1:0] scr_prio = scr_pxl[6:5] + 2'b01;

always @(posedge clk) if(pxl_cen) begin
    seladdr <= { ~char_blank, ~obj_blank,
        !enable_scr ? 2'b00 : {scr_prio}, scr_pxl[3:0] };
    scr0 <= scr_pxl;
    char0 <= char_pxl;
    obj0 <= obj_pxl;

    obj_sel[2] <= obj_sel[1];
    obj_sel[1] <= obj_sel[0];
    obj_sel[0] <= 1'b0;

    pixel_mux[9:8] <= selbus;
    case( selbus )
        2'b10: pixel_mux[7:0] <= { {(8-CHARW){1'b0}}, char0[5:2], char0[0], char0[1] };
        2'b00: pixel_mux[7:0] <= { 1'b0, scr0 };
        2'b01: begin
            pixel_mux[7:0] <= { 1'b1, obj0 };
            obj_sel[0] <= 1'b1;
        end
        default: pixel_mux[7:0] <= 8'd0; // this value is a guess
    endcase
end

always @(posedge clk) if(cen12) begin
    selbus <= seladdr[7] ? 2'b10 : ( // char
        seladdr[6] ? 2'b01 : // obj
        2'b00); // scr
end

wire [3:0] pal_red, pal_green, pal_blue;

// Palette is in RAM. There are writes outside the vertical blank
// If I gate the signals for VB only then the sea turns yellow in
// Legendary Wings after playing a game
// There could be an error bit like wrerr_n in Side Arms but it is not documented
// in MAME and I don't have schematics.
// I have tried implementing it at resonable locations in memory
// but the bad colour problems still occured if I gated the we_rg/b signals
// I have also tried triggering the vertical interrupt a bit before LVBL (few lines)
// but as long as we_rg/b are gated with LVBL, there are wrong colours
// So I don't gate these signals:

wire we_rg = !cpu_wrn &&  redgreen_cs;
wire we_b  = !cpu_wrn &&  blue_cs;

`ifndef PAL_GRAY
jtgng_dual_ram #(.AW(10),.SIMFILE("rg_ram.bin")) u_redgreen(
    .clk        ( clk         ),
    .clk_en     ( cpu_cen     ), // clock enable only applies to write operation
    .data       ( DB          ),
    .rd_addr    ( pixel_mux   ),
    .wr_addr    ( AB          ),
    .we         ( we_rg       ),
    .q          ( {pal_red, pal_green}     )
);

jtgng_dual_ram #(.AW(10),.DW(4),.SIMFILE("b_ram.bin")) u_blue(
    .clk        ( clk         ),
    .clk_en     ( cpu_cen     ), // clock enable only applies to write operation
    .data       ( DB[7:4]     ),
    .rd_addr    ( pixel_mux   ),
    .wr_addr    ( AB          ),
    .we         ( we_b        ),
    .q          ( pal_blue    )
);
`else
// by pass palette for quick sims:
assign {pal_red, pal_green, pal_blue} = {3{pixel_mux[3:0]}};
`endif

jtframe_blank #(.DLY(8),.DW(12)) u_dly(
    .clk        ( clk                 ),
    .pxl_cen    ( pxl_cen             ),
    .preLHBL    ( preLHBL             ),
    .preLVBL    ( preLVBL             ),
    .preLBL     (                     ),
    .LHBL       ( LHBL                ),
    .LVBL       ( LVBL                ),
    .rgb_in     ( {pal_red, pal_green, pal_blue} ),
    .rgb_out    ( {red, green, blue } )
);


endmodule // jtgng_colmix