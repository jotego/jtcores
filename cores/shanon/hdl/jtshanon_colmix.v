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
    Date: 13-7-2022 */

// Video board, schematic sheet 5 of 7

module jtshanon_colmix(
    input              rst,
    input              clk,
    input              pxl2_cen,  // pixel clock enable (2x)
    input              pxl_cen,   // pixel clock enable

    input              video_en,

    input              preLHBL,
    input              preLVBL,

    // CPU interface
    input              pal_cs,
    input      [13:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  dswn,
    output     [15:0]  cpu_din,

    // From tile map generator
    input      [10:0]  tmap_addr,
    input      [11:0]  obj_pxl,
    input      [ 7:0]  rd_pxl,
    input      [ 4:3]  rc,
    input              shadow,
    input              sa,
    input              sb,
    input              fix,

    output     [ 4:0]  red,
    output     [ 4:0]  green,
    output     [ 4:0]  blue,
    output             LVBL,
    output             LHBL,
    input      [ 7:0]  debug_bus,
    // SD card dumps
    input      [21:0]  ioctl_addr,
    input              ioctl_ram,
    output     [ 7:0]  ioctl_din
);

wire [ 1:0] we;
wire [15:0] pal_out;
wire [14:0] rgb;
reg  [10:0] rd_mux;
reg  [11:0] pal_addr, pre_addr;
reg  [11:0] objl;
reg         muxsel;
// reg  [ 1:0] blink;

assign we = ~dswn & {2{pal_cs}};
assign { red, green, blue } = rgb;

wire [4:0] rpal, gpal, bpal;

`ifndef GRAY
assign rpal  = { pal_out[ 3:0], pal_out[12] };
assign gpal  = { pal_out[ 7:4], pal_out[13] };
assign bpal  = { pal_out[11:8], pal_out[14] };
`else
assign rpal  = { pal_addr[3:0], pal_addr[3] };
assign gpal  = { pal_addr[3:0], pal_addr[3] };
assign bpal  = { pal_addr[3:0], pal_addr[3] };
`endif

function [4:0] dim;
    input [4:0] a;
    dim = a - (a>>2);
endfunction

function [4:0] light;
    input [4:0] a;
    begin : fn_light
        reg [5:0] aux;
        aux = {1'b0, a } + ( {1'b0, a } >>2);
        light = aux[5] ? 5'h1f : aux[4:0];
    end
endfunction

reg [14:0] gated;

// Super Hang On Equations 315-5251
// muxel ==0 selects tile mapper output, ==1 selects road
// muxsel = obj0 & obj1 & obj2 & obj3 & FIX & !rc3q #
//       obj0 & obj1 & obj2 & obj3 & sa_n & sb_n & FIX #
//       !obj0 & obj1 & !obj2 & obj3 & obj10 & !obj11 & FIX;

always @(posedge clk) if(pxl_cen) begin
    pal_addr <= pre_addr;
    objl     <= obj_pxl;

    gated <= !video_en ? 15'd0 :
         !shadow     ? { rpal, gpal, bpal }                      : // no shade effect
         pal_out[15] ? { light(rpal), light(gpal), light(bpal) } : // brighter
                       { dim(rpal), dim(gpal), dim(bpal) };        // dimmer
end

always @(*) begin
    rd_mux[3:0] = rd_pxl[3:0];
    // This mux only appears in Super Hang On
    case( rc[4:3] )
        0,1: rd_mux[5:4] = 2'b11;
        2: rd_mux[5:4] = {1'b0, rd_pxl[4]};
        3: rd_mux[5:4] = rd_pxl[5:4];
    endcase
    rd_mux[10:6] = {5{rc[4]}};
    // The shadow doesn't seem to be used in the trees and other road objects
    // Not clear whether it is used for the bike
    // The schematics show a *shade* signal coming from pin 17 of the 315-5251
    // not from the tile mapper, as it is connected now here
    muxsel = !fix && (
            ((objl[3:0]==4'h0 || shadow)  && (!rc[3] || (!sa && !sb) )) ||
            (objl[11:10]==~2'b01 && objl[3:0]==~4'b1010 ));
    // muxsel = (objl[3:0]==4'hf && !fix && (!rc[3] || (!sa && !sb) )) ||
    //          (objl[11:10]==2'b01 && objl[3:0]==4'b1010 && !fix );
    //if( debug_bus[7] ) muxsel=0;
    `ifdef FORCE_ROAD
    muxsel=1;
    `endif
    pre_addr[10:0] = muxsel ? ( /*debug_bus[7] ? 11'd0 :*/ rd_mux) : tmap_addr;
    pre_addr[11] = 0; // Super Hang On
end

// reg LVBLl;

// always @(posedge clk) begin
//     LVBLl <= LVBL;
//     if( LVBLl && !LVBL ) blink <= blink+2'd1;
// end

jtframe_dual_nvram16 #(
    .AW        (13          ),
    .SIMFILE_LO("pal_lo.bin"),
    .SIMFILE_HI("pal_hi.bin")
) u_ram(
    .clk0   ( clk       ),
    .clk1   ( clk       ),

    // CPU writes
    .addr0  ( cpu_addr  ),
    .data0  ( cpu_dout  ),
    .we0    ( we        ),
    .q0     ( cpu_din   ),

    // Video reads
    .addr1a ( {1'b0, pal_addr } ),
    .q1a    ( pal_out   ),
    // SD card dumps
    .we1b   ( 1'b0      ),
    .data1  (           ),
    .addr1b ( ioctl_addr[13:0]),
    .sel_b  ( ioctl_ram ),
    .q1b    ( ioctl_din )
);

jtframe_blank #(.DLY(3),.DW(15)) u_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .preLBL     (           ),
    .rgb_in     ( gated     ),
    .rgb_out    ( rgb[14:0] )
);

endmodule