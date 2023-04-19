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
    Date: 9-8-2020 */

// The original priority PROM has been hard coded into equations
// The end result is the same but the logic gets a bit simpler
// and also, I could reuse the jtsectionz_prom_we without modifying it
// I have left the PROM reference in the MRA in case we want to
// change this in the future

module jtsarms_colmix #(
    parameter CHARW     = 8,
              BLANK_DLY = 8
) (
    input            rst,
    input            clk,
    input            pxl2_cen,
    input            pxl_cen,
    input            cpu_cen,

    // pixel input from generator modules
    input [CHARW-1:0]char_pxl,        // character color code
    input [8:0]      scr_pxl,
    input [2:0]      star_pxl,
    input [7:0]      obj_pxl,
    input            preLVBL,
    input            preLHBL,
    output           LHBL,
    output           LVBL,
    // Enable bits
    input            CHON,
    input            SCRON,
    input            OBJON,
    // CPU inteface
    input      [9:0] AB,
    input            blue_cs,
    input            redgreen_cs,
    input      [7:0] DB,
    input            cpu_wrn,
    input            eres_n,        // clears palette error signal
    output reg       wrerr_n,       // marks an attempt to write in palette outside v-blanking

    output     [3:0] red,
    output     [3:0] green,
    output     [3:0] blue,
    // Priority PROM
    // input      [7:0] prog_addr,
    // input            prom_prio_we,
    // input      [3:0] prom_din,
    // Debug
    input      [3:0] gfx_en
);

reg [9:0] pixel_mux;

wire enable_char = gfx_en[0];
wire enable_scr  = gfx_en[1];
wire enable_star = gfx_en[2];
wire enable_obj  = gfx_en[3];

wire char_blank  = (&char_pxl[1:0]) | ~enable_char;
wire obj_blank   = (&obj_pxl[3:0])  | ~enable_obj;
// wire scr_blank   = &scr_pxl[3:0];

reg  [7:0] seladdr;
reg  [1:0] selbus, colmsb;

reg [7:0] obj0, scr0;
reg [2:0] star0;
reg [CHARW-1:0] char0;

localparam [1:0] STAR=2'b00, SCR=2'b01, CHAR=2'b11, OBJ=2'b10;

always @(posedge clk) if(pxl_cen) begin
    seladdr <= { ~char_blank, ~obj_blank, 1'b0,
        scr_pxl[8], enable_scr ? scr_pxl[3:0] : 4'd15 };
    scr0  <= scr_pxl[7:0];
    star0 <= enable_star ? star_pxl : 3'd0;
    char0 <= char_pxl;
    obj0  <= obj_pxl;

    pixel_mux[9:8] <= colmsb;
    case( selbus )
        CHAR: pixel_mux[7:0] <= char0;
        SCR:  pixel_mux[7:0] <= scr0;
        OBJ:  pixel_mux[7:0] <= obj0;
        STAR: pixel_mux[7:0] <= { 5'b0_1111, star0 };
    endcase
end

always @(posedge clk) if(pxl2_cen) begin
    if( seladdr[7] ) begin
        selbus <= CHAR;
        colmsb <= CHAR;
    end else if(seladdr[6]) begin
        selbus <= OBJ;
        colmsb <= OBJ;
    end else if(seladdr[3:0]==4'd15)  begin
        selbus <= STAR;
        colmsb <= CHAR;
    end else begin
        selbus <= SCR;
        colmsb <= {1'b0, seladdr[4]};
    end
end

wire [3:0] pal_red, pal_green, pal_blue;

// Palette is in RAM
wire we_rg = !LVBL && !cpu_wrn &&  redgreen_cs;
wire we_b  = !LVBL && !cpu_wrn &&  blue_cs;

always @(posedge clk, posedge rst) begin
    if( rst )
        wrerr_n <= 0;
    else begin
        if( !eres_n )
            wrerr_n <= 1;
        else if( (redgreen_cs || blue_cs) && LVBL ) wrerr_n <= 0;
    end
end

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
    .data       ( DB[3:0]     ),
    .rd_addr    ( pixel_mux   ),
    .wr_addr    ( AB          ),
    .we         ( we_b        ),
    .q          ( pal_blue    )
);
`else
// bypass palette for quick sims:
assign {pal_red, pal_green, pal_blue} = {3{pixel_mux[3:0]}};
`endif

wire [11:0] pal_out = {pal_red, pal_green, pal_blue};

jtframe_blank #(.DLY(BLANK_DLY),.DW(12)) u_dly(
    .clk        ( clk                 ),
    .pxl_cen    ( pxl_cen             ),
    .preLHBL    ( preLHBL             ),
    .preLVBL    ( preLVBL             ),
    .LHBL       ( LHBL                ),
    .LVBL       ( LVBL                ),
    .rgb_in     ( pal_out             ),
    .rgb_out    ( {red, green, blue } ),
    // unused:
    .preLBL     (                     )
);

endmodule