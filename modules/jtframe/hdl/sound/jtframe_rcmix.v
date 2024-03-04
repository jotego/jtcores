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
    W0=16,W1=16,W2=16,W3=16,W4=12,WOUT=16,
    N0=1, N1=1, N2=1, N3=1, N4=1,   // signed input
    ST=0, // Stereo. Bitwise per channel (bit 0 high for stereo channel 0, etc.)
    DC=0, // dc removal. Bitwise per channel (bit 0 high for removal in channel 0, etc.)
    // Do not set externally:
    SOUT=|ST[5:0],    // is the output stereo?
    CW=8              // pole coefficient resolution
)(
    input                    rst,
    input                    clk,
    // input signals
    input  signed [(ST[0]+1)*W0-1:0] ch0,  // for stereo signals, concatenate {left,right}
    input  signed [(ST[1]+1)*W1-1:0] ch1,
    input  signed [(ST[2]+1)*W2-1:0] ch2,
    input  signed [(ST[3]+1)*W3-1:0] ch3,
    input  signed [(ST[4]+1)*W4-1:0] ch4,
    // up to 2 pole coefficients per input (unsigned numbers, only decimal part)
    input  [CW*2*5-1] poles, // concatenate the bits for each pole coefficient
    // gain for each channel in 4.4 fixed point format
    input  [5*8-1:0] gains,  // concatenate all gains {gain4, gain3,..., gain0}
    output signed [(SOUT+1)*WOUT-1:0] mixed,
    output                   peak   // overflow signal (time enlarged)
);

localparam CH=5, W=WOUT*(SOUT+1);

wire signed [WOUT*(SOUT+1)*CH-1:0]
    sc,     // scale to WOUT bits
    dc,     // dc removal
    pre;    // pre-amplified
reg  signed [WOUT*(SOUT+1)*CH-1:0] prel;
wire cen;   // 48 kHz

jtframe_rcmix_scale #(W0,W,ST[0],SOUT) u_sc0 ( ch0, sc[W*0+:W] );
jtframe_rcmix_scale #(W0,W,ST[1],SOUT) u_sc1 ( ch1, sc[W*1+:W] );
jtframe_rcmix_scale #(W0,W,ST[2],SOUT) u_sc2 ( ch2, sc[W*2+:W] );
jtframe_rcmix_scale #(W0,W,ST[3],SOUT) u_sc3 ( ch3, sc[W*3+:W] );
jtframe_rcmix_scale #(W0,W,ST[4],SOUT) u_sc4 ( ch4, sc[W*4+:W] );

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
            end else if(SOUT) begin // if the output is stereo but the input isn't:
                assign dc[(W*k+WOUT)+:WOUT]=dc[W*k+:WOUT];
            end
        end else begin
            assign dc[W*k+:W]=sc[W*k+:W]; // no dc removal
        end
        // Filters
        if( poles[2*CW*k+:CW]!=0 ) begin
            jtframe_pole #(.WS(WOUT),.WA(CW)) u_pole(
                    .rst    ( rst           ),
                    .clk    ( clk           ),
                    .sample ( cen           ),
                    .a      (poles[2*k*CW+:CW]),
                    .sin    ( dc[W*k+:WOUT] ),
                    .sout   ( p1[W*k+:WOUT] )
            );
            if( ST[k] ) begin
                jtframe_pole #(.WS(WOUT),.WA(CW)) u_pole(
                        .rst    ( rst           ),
                        .clk    ( clk           ),
                        .sample ( cen           ),
                        .a      (poles[2*k*CW+:CW]),
                        .sin    ( dc[(W*k+WOUT)+:WOUT] ),
                        .sout   ( p1[(W*k+WOUT)+:WOUT] )
                );
            end else if(SOUT) begin // if the output is stereo but the input isn't:
                assign p1[(W*k+WOUT)+:WOUT]=p1[W*k+:WOUT];
            end
        end else begin
            assign p1[W*k+:W]=dc[W*k+:W]; // no first pole
        end
        if( poles[(2*k+1)*CW+:CW]!=0 ) begin
            jtframe_pole #(.WS(WOUT),.WA(CW)) u_pole(
                    .rst    ( rst           ),
                    .clk    ( clk           ),
                    .sample ( cen           ),
                    .a      (poles[(2*k+1)*CW+:CW]),
                    .sin    ( p1[W*k+:WOUT] ),
                    .sout   ( p2[W*k+:WOUT] )
            );
            if( ST[k] ) begin
                jtframe_pole #(.WS(WOUT),.WA(CW)) u_pole_l(
                        .rst    ( rst           ),
                        .clk    ( clk           ),
                        .sample ( cen           ),
                        .a      (poles[(2*k+1)*CW+:CW] ),
                        .sin    ( p1[(W*k+WOUT)+:WOUT] ),
                        .sout   ( p2[(W*k+WOUT)+:WOUT] )
                );
            end else if(SOUT) begin // if the output is stereo but the input isn't:
                assign p2[(W*k+WOUT)+:WOUT]=p1[W*k+:WOUT];
            end
        end else begin
            assign p2[W*k+:W]=p1[W*k+:W]; // no second pole
        end
        // Gain
        assign pre[W*k+:WOUT] = gains[8*k+:8]*p2[W*k+:WOUT];
        if(SOUT) assign pre[(W*k+WOUT)+:WOUT] = gains[8*k+:8]*p2[(W*k+WOUT)+:WOUT];
    end
endgenerate

always @(posedge clk) if(cen) begin
    prel <= pre;
end

endmodule

module jtframe_rcmix_scale #(parameter WIN=10,WOUT=16,SIN=0,SOUT=0)(
    input  signed [ WIN-1:0] x,
    output signed [WOUT-1:0] y
);

localparam WH = WIN/2;

assign y = SIN==0 && SOUT==0 ? { x, x[WIN-2-:(WOUT-WIN)] } : // skips the sign bit
           SIN==0 && SOUT==1 ? {2{ x, x[WIN-2-:(WOUT/2-WIN)] }} :
           { x[WIN-1-:WH],x[WIN-2:(WOUT/2-WH)], x[WH-1:0],x[WH-2-:(WOUT/2-WH)]};

endmodule