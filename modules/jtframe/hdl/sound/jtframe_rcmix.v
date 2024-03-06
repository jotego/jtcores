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
    Date: 20-12-2019

*/

// Generic mixer: improves on the jt12_mixer in JT12 repository

// Usage:
// Specify width of input signals and desired outputs
// Select gain for each signal

module jtframe_rcmix #(parameter
    W0=16,W1=16,W2=16,W3=16,W4=16,WOUT=16,
    ST=32'h1f, // Stereo. Bitwise per channel (bit 0 high for stereo channel 0, etc.)
    DC=0,      // dc removal. Bitwise per channel (bit 0 high for removal in channel 0, etc.)
    STEREO=1,  // module output
    // Do not set externally:
    SOUT={31'd0,ST[4:0]!=0},    // calculations in stereo?
    CW=8,             // pole coefficient resolution
    WMX=STEREO==1?WOUT*2:WOUT
)(
    input                    rst,
    input                    clk,
    // input signals
    input  signed [({31'd0,ST[0]}+32'd1)*W0-1:0] ch0,  // for stereo signals, concatenate {left,right}
    input  signed [({31'd0,ST[1]}+32'd1)*W1-1:0] ch1,
    input  signed [({31'd0,ST[2]}+32'd1)*W2-1:0] ch2,
    input  signed [({31'd0,ST[3]}+32'd1)*W3-1:0] ch3,
    input  signed [({31'd0,ST[4]}+32'd1)*W4-1:0] ch4,
    // up to 2 pole coefficients per input (unsigned numbers, only decimal part)
    input  [CW*2*5-1:0] poles, // concatenate the bits for each pole coefficient
    // gain for each channel in 4.4 fixed point format
    input  [5*8-1:0] gains,  // concatenate all gains {gain4, gain3,..., gain0}
    output signed [WMX-1:0] mixed,
    output reg              peak   // overflow signal (time enlarged)
);

localparam CH=5, W=WOUT*(SOUT+1),
           MFREQ = `ifdef JTFRAME_MCLK `JTFRAME_MCLK `else 48000 `endif,
           SFREQ = 192000;  // sampling frequency

wire signed [WOUT*(SOUT+1)*CH-1:0]
    sc,     // scale to WOUT bits
    dc,     // dc removal
    p1,     // after 1st pole
    p2,     // after 2nd pole
    pre;    // pre-amplified
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

jtframe_rcmix_scale #(W0*({31'b0,ST[0]}+32'd1),W,ST[0],SOUT) u_sc0 ( ch0, sc[W*0+:W] );
jtframe_rcmix_scale #(W1*({31'b0,ST[1]}+32'd1),W,ST[1],SOUT) u_sc1 ( ch1, sc[W*1+:W] );
jtframe_rcmix_scale #(W2*({31'b0,ST[2]}+32'd1),W,ST[2],SOUT) u_sc2 ( ch2, sc[W*2+:W] );
jtframe_rcmix_scale #(W3*({31'b0,ST[3]}+32'd1),W,ST[3],SOUT) u_sc3 ( ch3, sc[W*3+:W] );
jtframe_rcmix_scale #(W4*({31'b0,ST[4]}+32'd1),W,ST[4],SOUT) u_sc4 ( ch4, sc[W*4+:W] );

generate
    genvar k;
    for(k=0;k<CH;k=k+1) begin
        // DC removal
        if( DC[k] ) begin
            jtframe_dcrm #(.SW(WOUT),.SIGNED_INPUT(1)) u_dcrm(
                .rst    ( rst           ),
                .clk    ( clk           ),
                .sample ( cen           ),
                .din    ( sc[W*k+:WOUT] ),
                .dout   ( dc[W*k+:WOUT] )
            );
            if( ST[k]) begin // if stereo in origin, apply DC removal to left channel
                jtframe_dcrm #(.SW(WOUT),.SIGNED_INPUT(1)) u_dcrm_l(
                    .rst    ( rst           ),
                    .clk    ( clk           ),
                    .sample ( cen           ),
                    .din    ( sc[(W*k+WOUT)+:WOUT] ),
                    .dout   ( dc[(W*k+WOUT)+:WOUT] )
                );
            end else if(SOUT==1) begin // if the output is stereo but the input isn't:
                assign dc[(W*k+WOUT)+:WOUT]=dc[W*k+:WOUT];
            end
        end else begin
            assign dc[W*k+:W]=sc[W*k+:W]; // no dc removal
        end
        // Filters
        jtframe_pole #(.WS(WOUT),.WA(CW)) u_pole1(
                .rst    ( rst           ),
                .clk    ( clk           ),
                .sample ( cen           ),
                .a      (poles[2*k*CW+:CW]),
                .sin    ( dc[W*k+:WOUT] ),
                .sout   ( p1[W*k+:WOUT] )
        );
        if( ST[k] ) begin
            jtframe_pole #(.WS(WOUT),.WA(CW)) u_pole1_l(
                    .rst    ( rst           ),
                    .clk    ( clk           ),
                    .sample ( cen           ),
                    .a      (poles[2*k*CW+:CW]),
                    .sin    ( dc[(W*k+WOUT)+:WOUT] ),
                    .sout   ( p1[(W*k+WOUT)+:WOUT] )
            );
        end else if(SOUT==1) begin // if the output is stereo but the input isn't:
            assign p1[(W*k+WOUT)+:WOUT]=p1[W*k+:WOUT];
        end
        jtframe_pole #(.WS(WOUT),.WA(CW)) u_pole2(
                .rst    ( rst           ),
                .clk    ( clk           ),
                .sample ( cen           ),
                .a      (poles[(2*k+1)*CW+:CW]),
                .sin    ( p1[W*k+:WOUT] ),
                .sout   ( p2[W*k+:WOUT] )
        );
        if( ST[k] ) begin
            jtframe_pole #(.WS(WOUT),.WA(CW)) u_pole2_l(
                    .rst    ( rst           ),
                    .clk    ( clk           ),
                    .sample ( cen           ),
                    .a      (poles[(2*k+1)*CW+:CW] ),
                    .sin    ( p1[(W*k+WOUT)+:WOUT] ),
                    .sout   ( p2[(W*k+WOUT)+:WOUT] )
            );
        end else if(SOUT==1) begin // if the output is stereo but the input isn't:
            assign p2[(W*k+WOUT)+:WOUT]=p1[W*k+:WOUT];
        end
        // Gain
        assign pre[W*k+:WOUT] = gains[8*k+:8]*p2[W*k+:WOUT];
        if(SOUT==1) assign pre[(W*k+WOUT)+:WOUT] = gains[8*k+:8]*p2[(W*k+WOUT)+:WOUT];
    end
endgenerate

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

module jtframe_rcmix_scale #(parameter WIN=10,WOUT=16,SIN=0,SOUT=0)(
    input      signed [ WIN-1:0] x,
    output reg signed [WOUT-1:0] y
);
    localparam WDS=WOUT/2 < WIN ? WOUT/2 : WOUT/2-WIN;
    initial begin
        if( WIN[0] || WOUT[0] ) begin
            $display("ERROR: WIN and WOUT must be even numbers in %m");
            $finish;
        end
        if( WOUT<WIN ) begin
            $display("ERROR: WOUT must be larger than WIN in %m");
            $finish;
        end
    end
    always @* begin
        y = 0;
        if( SIN==1 ) begin
            y[WOUT-1-:WIN/2]=x[WIN-1-:WIN/2];
            y[0+:WIN/2]=x[0+:WIN/2];
        end else begin
            if( SOUT==0 ) begin
                y = {x,{WOUT-WIN{1'b0}}};
            end else begin
                y[WOUT-1  -:WDS] = x[WIN-1-:WDS];
                y[WOUT/2-1-:WDS] = x[WIN-1-:WDS];
            end
        end
    end
endmodule