/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */

module jtgng_timer(
    input               clk,
    input               cen6,   //  6 MHz
    input               rst,
    output  reg [8:0]   V = 9'd496,
    output  reg [8:0]   H = 9'd135,
    output  reg         Hinit = 1'b0,
    output  reg         Vinit = 1'b1,
    output  reg         LHBL = 1'b0,
    output  reg         LHBL_obj = 1'b0,
    output  reg         LVBL = 1'b0,
    output  reg         LVBL_obj = 1'b0,
    output  reg         HS = 1'b0,
    output  reg         VS = 1'b0
);

parameter obj_offset=10'd3;

//reg LHBL_short;
//reg G4_3H;  // high on 3/4 H transition
//reg G4H;    // high on 4H transition
//reg OH;     // high on 0H transition

// H counter
always @(posedge clk) if(cen6) begin
    Hinit <= H == 9'h86;
    if( H == 9'd511 ) begin
        //Hinit <= 1'b1;
        H <= 9'd128;
    end
    else begin
        //Hinit <= 1'b0;
        H <= H + 9'b1;
    end
end

// V Counter
always @(posedge clk) if(cen6) begin
    if( H == 9'd511 ) begin
        Vinit <= &V;
        V <= &V ? 9'd250 : V + 1'd1;
    end
end

wire [9:0] LHBL_obj0 = 10'd135-obj_offset >= 10'd128 ? 10'd135-obj_offset : 10'd135-obj_offset+10'd512-10'd128;
wire [9:0] LHBL_obj1 = 10'd263-obj_offset;

// L Horizontal/Vertical Blanking
// Objects are drawn using a 2-line buffer
// so they are calculated two lines in advanced
// original games use a small ROM to generate
// control signals for the object buffers.
// I do not always use that ROM in my games,
// I often just generates the signals with logic
// LVBL_obj is such a signal. In CAPCOM schematics
// this is roughly equivalent to BLTM (1943) or BLTIMING (GnG)
always @(posedge clk) if(cen6) begin
    if( H==LHBL_obj1[8:0] ) LHBL_obj<=1'b1;
    if( H==LHBL_obj0[8:0] ) LHBL_obj<=1'b0;
    if( &H[2:0] ) begin
        LHBL <= H[8];
        case( V )
            9'd496: LVBL <= 1'b0; // h1F0
            9'd272: LVBL <= 1'b1; // h110
            // OBJ LVBL is two lines ahead
            9'd494: LVBL_obj <= 1'b0;
            9'd270: LVBL_obj <= 1'b1;
            default:;
        endcase // V
    end

    if (H==9'd178) begin
        HS <= 1;
        if (V==9'd507) VS <= 1;
        if (V==9'd510) VS <= 0;
    end

    if (H==9'd206) HS <= 0;
    // if (H==9'd136) LHBL_short <= 1'b0;
    // if (H==9'd248) LHBL_short <= 1'b1;
end

endmodule // jtgng_timer
