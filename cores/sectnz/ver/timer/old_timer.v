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

module old_timer(
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

`ifdef SIMULATION
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
                $display(" *old* VB count = %3d (sync at %2d)", vbcnt, vs1 );
                $display(" *old* V  total = %3d (%.2f Hz)", vcnt, 6e6/(hcnt*vcnt) );
                $display(" *old* HB count = %3d (sync at %2d)", hbcnt, hs1 );
                $display(" *old* H  total = %3d", hcnt );
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
