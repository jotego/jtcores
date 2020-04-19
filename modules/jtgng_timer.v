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
parameter LAYOUT=0; // 0 for most games, 5 for Section Z (240px height)

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

reg LVBL_x;

localparam [8:0] V_START  = LAYOUT != 5 ? 9'd250 : 9'd232,
                 VB_START = LAYOUT != 5 ? 9'd494 : 9'd502,
                 VB_END   = LAYOUT != 5 ? 9'd270 : 9'd262,
                 VS_START = LAYOUT != 5 ? 9'd507 : 9'd245,
                 // VS length doesn't affect position
                 VS_END   = LAYOUT != 5 ? 9'd510 : (VS_START+2);

// V Counter
always @(posedge clk) if(cen6) begin
    if( H == 9'd511 ) begin
        Vinit <= &V;
        V <= &V ? V_START : V + 1'd1;
        { LVBL, LVBL_x } <= { LVBL_x, LVBL_obj };
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



wire bl_switch = H[2:0]==3'b111; //LAYOUT != 5 ? (H[2:0]==3'b111) : (H[2:0]==3'd0);

always @(posedge clk) if(cen6) begin
    if( H==LHBL_obj1[8:0] ) LHBL_obj<=1'b1;
    if( H==LHBL_obj0[8:0] ) LHBL_obj<=1'b0;

    if( bl_switch ) begin
        LHBL <= H[8];
        case( V )
            // OBJ LVBL is two lines ahead
            VB_START: LVBL_obj <= 1'b0;
            VB_END:   LVBL_obj <= 1'b1;
            default:;
        endcase // V
    end

    if (H==9'd178) begin
        HS <= 1;
        if (V==VS_START) VS <= 1;
        if (V==VS_END  ) VS <= 0;
    end

    if (H==9'd206) HS <= 0;
end

endmodule // jtgng_timer
