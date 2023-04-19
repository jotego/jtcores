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
    Date: 27-10-2017 */

// The basic count for most games (LAYOUT==0) is
// H goes from 80 to 1FF
// LHBL goes down at 87 and back up at 107
// V is incremented in the H=1FF to 80 transition
// LVBL goes down at 1F0, when LHBL goes down too (at H=87)
// LVBL goes up at 110, again when LHBL goes down at H=87

module jtgng_timer(
    input               clk,
    input               cen6,   //  6 MHz
    output  reg [8:0]   V,
    output  reg [8:0]   H,
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
// 0 for most games (224px height, 59.64Hz)
// 5 for Section Z  (240px height, 55.37Hz)
// 6 for Section Z  (240px height, 55.97Hz)
parameter LAYOUT=0;

localparam [8:0] V_START  = (LAYOUT != 5 && LAYOUT!=6) ? 9'd250 : (LAYOUT==5 ? 9'd230 : 9'd233),
                 VB_START = (LAYOUT != 5 && LAYOUT!=6) ? 9'd494 : 9'd502,
                 VB_END   = (LAYOUT != 5 && LAYOUT!=6) ? 9'd270 : 9'd262,
                 VS_START = (LAYOUT != 5 && LAYOUT!=6) ? 9'd507 : 9'd244,
                 // VS length doesn't affect position
                 VS_END   = (LAYOUT != 5 && LAYOUT!=6) ? 9'd510 : (VS_START+9'd3),
                 // H signals: all must be multiple of 8
                 H_START  = 9'd128,
                 HB_START = (LAYOUT != 5 && LAYOUT!=6) ? 9'h087 : 9'd128,
                            //( LAYOUT == 1 ? 9'd136 : 9'd128 ),
                 HB_END   = (LAYOUT != 5 && LAYOUT!=6) ?
                      9'h107  // other games
                    : 9'd256; // Section Z

// H counter
always @(posedge clk) if(cen6) begin
    Hinit <= H == 9'h86;
    if( H == 9'd511 ) begin
        //Hinit <= 1'b1;
        H <= H_START;
    end
    else begin
        //Hinit <= 1'b0;
        H <= H + 9'b1;
    end
end

reg LVBL_x;

`ifdef SIMULATION
initial begin
    // These numbers produce a good image in simulation
    // after binary to jpg conversion. Tested with layout=5
    // might need different H/V values for layout 0
    // The problem is the few pixels for which both LHBL and LVBL
    // are high before LVBL goes down, that can shift the image
    // in the jpg files.
    LVBL_obj = 1;
    LVBL_x = 1;
    LVBL   = 1;
    LHBL   = 0;
    H = 192;
    V = 264;
end
`endif

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

    if( H == 9'd511 ) begin
        Vinit <= &V;
        V <= &V ? V_START : V + 1'd1;
    end

    if( H == HB_START ) begin
        LHBL <= 0;
        { LVBL, LVBL_x } <= { LVBL_x, LVBL_obj };
        case( V )
            // OBJ LVBL is two lines ahead
            VB_START: LVBL_obj <= 1'b0;
            VB_END:   LVBL_obj <= 1'b1;
            default:;
        endcase // V
    end else if( H == HB_END ) LHBL <= 1;

    if (H==9'd178) begin
        HS <= 1;
        if (V==VS_START) VS <= 1;
        if (V==VS_END  ) VS <= 0;
    end

    if (H==9'd206) HS <= 0;
end

`ifdef SIMULATION_TIMER
reg LVBL_Last, LHBL_last, VS_last, HS_last;

wire new_line  = LHBL_last && !LHBL;
wire new_frame = LVBL_Last && !LVBL;
wire new_HS = HS && !HS_last;
wire new_VS = VS && !VS_last;

integer vbcnt=0, vcnt=0, hcnt=0, hbcnt=0, vs0, vs1, hs0, hs1;
integer framecnt=0;

always @(posedge clk) if(cen6) begin
    LHBL_last <= LHBL;
    HS_last   <= HS;
    VS_last   <= VS;
    if( new_HS ) hs1 <= hbcnt;
    if( new_VS ) vs1 <= vbcnt;
    if( new_line ) begin
        LVBL_Last <= LVBL;
        if( new_frame ) begin
            if( framecnt>0 ) begin
                $display("VB count = %3d (sync at %2d)", vbcnt, vs1 );
                $display("V  total = %3d (%.2f Hz)", vcnt, 6e6/(hcnt*vcnt) );
                $display("HB count = %3d (sync at %2d)", hbcnt, hs1 );
                $display("H  total = %3d", hcnt );
                $display("-------------" );
            end
            vbcnt <= 1;
            vcnt  <= 1;
            framecnt <= framecnt+1;
        end else begin
            vcnt <= vcnt+1;
            if( !LVBL ) vbcnt <= vbcnt+1;
        end
        hbcnt <= 1;
        hcnt  <= 1;
    end else begin
        hcnt <= hcnt+1;
        if( !LHBL ) hbcnt <= hbcnt+1;
    end
end
`endif

endmodule // jtgng_timer
