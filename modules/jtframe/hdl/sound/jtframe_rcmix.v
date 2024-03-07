/* This file is part of JTFRAME.


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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 4-3-2024

*/

// Generic mixer: improves on the jt12_mixer in JT12 repository

// Usage:
// Specify width of input signals and desired outputs
// Select gain for each signal

module jtframe_rcmix #(parameter
    W0=16,W1=16,W2=16,W3=16,W4=16,WOUT=16,
    ST=32'h1f, // Stereo. Bitwise per channel (bit 0 high for stereo channel 0, etc.)
    DCRM0=0,DCRM1=0,DCRM2=0,DCRM3=0,DCRM4=0,      // dc removal
    STEREO0=1,STEREO1=1,STEREO2=1,STEREO3=1,STEREO4=1,
    // Do not set externally:
    SOUT={31'd0,ST[4:0]!=0},    // calculations in stereo?
    WC=8,             // pole coefficient resolution
    WMX=STEREO==1?WOUT*2:WOUT,
    WS0=STEREO0==1?W0*2:W0,
    WS1=STEREO1==1?W1*2:W1,
    WS2=STEREO2==1?W2*2:W2,
    WS3=STEREO3==1?W3*2:W3,
    WS4=STEREO4==1?W4*2:W4
)(
    input                   rst,
    input                   clk,
    // input signals
    input  signed [WS0-1:0] ch0,  // for stereo signals, concatenate {left,right}
    input  signed [WS1-1:0] ch1,
    input  signed [WS2-1:0] ch2,
    input  signed [WS3-1:0] ch3,
    input  signed [WS4-1:0] ch4,
    // up to 2 pole coefficients per input (unsigned numbers, only decimal part)
    input  [WC*2-1:0] p0,p1,p2,p3,p4, // concatenate the bits for each pole coefficient
    // gain for each channel in 4.4 fixed point format
    input  [5*8-1:0] g0,g1,g2,g3,g4,  // concatenate all gains {gain4, gain3,..., gain0}
    output reg signed [WMX-1:0] mixed,
    output reg              peak   // overflow signal (time enlarged)
);

localparam CH=5, W=WOUT*(SOUT+1),
           WP=((ST[0]?2:1)+(ST[1]?2:1)+(ST[2]?2:1)+(ST[3]?2:1)+(ST[4]?2:1))*WOUT,
           MFREQ = `ifdef JTFRAME_MCLK `JTFRAME_MCLK `else 48000 `endif,
           SFREQ = 192000;  // sampling frequency

wire signed [WP-1:0]
    sc,     // scale to WOUT bits
    dc,     // dc removal
    p1,     // after 1st pole
    p2,     // after 2nd pole
    pre;    // pre-amplified
wire signed [WOUT-1:0] sc0, sc1, sc2, sc3, sc4;
reg  signed [ WOUT*(SOUT+1)*CH-1:0] prel;
reg  signed [(WOUT+3)*(SOUT+1)-1:0] lsum;
reg  signed [ W-1:0] sum;
wire cen, nc;   // sampling frequency

// cen generation
reg [9:0] m,n;
integer tn,tm,err,f,berr;

initial begin
    berr = SFREQ;
    for(tm=1;tm<1023;tm=tm+1) begin
        tn = MFREQ/tm;
        err = SFREQ-MFREQ*tn/tm;
        if( err<0 ) err=-err;
        if( err<berr ) begin
            berr = err;
            n    = tn[9:0];
            m    = tm[9:0];
        end
    end
end

reg signed [WOUT:0] mono;
always @* begin
    mono = sum[WOUT-1:0]+sum[W-1-:WOUT];
    case( {STEREO[0],SOUT[0]} )
        // module output is mono
        2'b00: mixed[WOUT-1:0] = sum[WOUT-1:0];
        2'b01: mixed[WOUT-1:0] = mono[WOUT:1]; /* verilator lint_off WIDTHTRUNC */
        // module output is stereo
        2'b10: mixed = {2{sum[WOUT-1:0]}};
        2'b11: mixed = sum; /* verilator lint_on WIDTHTRUNC */
    endcase
end

generate
    if(SOUT==1) assign mixed[((SOUT+1)*WOUT-1)-:WOUT] = sum[((SOUT+1)*WOUT-1)-:WOUT];
endgenerate

jtframe_frac_cen u_cen(
    .clk    ( clk       ),
    .n      ( n         ),
    .m      ( m         ),
    .cen    ({nc,cen}   ),
    .cenb   (           )
);

function [WOUT+2:0] ext;
    input [WOUT-1:0] a;
    ext = { {3{a[WOUT-1]}}, a };
endfunction

jtframe_sndchain #(.W(W0),.DCRM(DC0),.STEREO(STEREO0)) u_ch0(.rst(rst),.clk(clk),.cen(cen),.poles(p0),.gain(g0),.sin(ch0), .sout(ft0));
jtframe_sndchain #(.W(W1),.DCRM(DC1),.STEREO(STEREO1)) u_ch1(.rst(rst),.clk(clk),.cen(cen),.poles(p1),.gain(g1),.sin(ch1), .sout(ft1));
jtframe_sndchain #(.W(W2),.DCRM(DC2),.STEREO(STEREO2)) u_ch2(.rst(rst),.clk(clk),.cen(cen),.poles(p2),.gain(g2),.sin(ch2), .sout(ft2));
jtframe_sndchain #(.W(W3),.DCRM(DC3),.STEREO(STEREO3)) u_ch3(.rst(rst),.clk(clk),.cen(cen),.poles(p3),.gain(g3),.sin(ch3), .sout(ft3));
jtframe_sndchain #(.W(W4),.DCRM(DC4),.STEREO(STEREO4)) u_ch4(.rst(rst),.clk(clk),.cen(cen),.poles(p4),.gain(g4),.sin(ch4), .sout(ft4));


always @(posedge clk) if(cen) begin
    prel <= pre;
    lsum[WOUT+2:0] <= ext(prel[0+:WOUT])+ext(prel[W+:WOUT])+ext(prel[W*2+:WOUT])+
                     ext(prel[W*3+:WOUT])+ext(prel[W*4+:WOUT]);
    peak <= 0;
    if( ^lsum[WOUT+2:WOUT-1] ) begin
        peak <= 1;
        sum[WOUT-1:0] <= { lsum[WOUT+2], {WOUT-1{~lsum[WOUT+2]}}};
    end else begin
        sum[WOUT-1:0] <= lsum[WOUT-1:0];
    end
    if(SOUT==1) begin
        lsum[(WOUT+3)+:WOUT+3] <= ext(prel[WOUT+:WOUT])+ext(prel[(W+WOUT)+:WOUT])+ext(prel[(W*2+WOUT)+:WOUT])+
                                 ext(prel[(W*3+WOUT)+:WOUT])+ext(prel[(W*4+WOUT)+:WOUT]);
        if( ^lsum[WOUT*2+2:WOUT*2-1] ) begin
            peak <= 1;
            sum[(WOUT*2-1)-:WOUT] <= { lsum[WOUT*2+2], {WOUT-1{~lsum[WOUT*2+2]}}};
        end else begin
            sum[WOUT*2-1-:WOUT] <= lsum[(WOUT*2-1)-:WOUT];
        end
    end
end

endmodule
