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
    W0=16,W1=16,W2=16,W3=16,W4=16,
    STEREO =1, // is the output stereo?
    DCRM0=0,DCRM1=0,DCRM2=0,DCRM3=0,DCRM4=0,      // dc removal
    STEREO0=1,STEREO1=1,STEREO2=1,STEREO3=1,STEREO4=1, // are the input channels stereo?
    // Path to FIR filter coefficient files. Enabling FIR will disable the 2-pole filters
    FIR0="",FIR1="",FIR2="",FIR3="",FIR4="",
    // Fractional divider
    FRACW=12, FRACN = 1, FRACM=262,
    // Do not set externally:
    WOUT=16,
    WC  =8,             // pole coefficient resolution
    WMX=STEREO ==1?WOUT*2:WOUT,
    WS0=STEREO0==1?  W0*2:W0,
    WS1=STEREO1==1?  W1*2:W1,
    WS2=STEREO2==1?  W2*2:W2,
    WS3=STEREO3==1?  W3*2:W3,
    WS4=STEREO4==1?  W4*2:W4
)(
    input                   rst,
    input                   clk,
    input                   mute,
    // input signals
    input  signed [WS0-1:0] ch0,  // for stereo signals, concatenate {left,right}
    input  signed [WS1-1:0] ch1,
    input  signed [WS2-1:0] ch2,
    input  signed [WS3-1:0] ch3,
    input  signed [WS4-1:0] ch4,
    input  [4:0]            ch_en,
    // up to 2 pole coefficients per input (unsigned numbers, only decimal part)
    input  [WC*2-1:0] p0,p1,p2,p3,p4, // concatenate the bits for each pole coefficient
    input  [WC  -1:0] gpole,          // allow for one global pole
    // gain for each channel in 4.4 fixed point format
    input       [7:0] g0,g1,g2,g3,g4,  // concatenate all gains {gain4, gain3,..., gain0}
    output              sample,
    output reg signed [WMX-1:0] mixed,
    output reg          peak   // overflow signal
);

localparam SFREQ = 192,              // sampling frequency in kHz
           STEFF0 = STEREO0 && STEREO,
           STEFF1 = STEREO1 && STEREO,
           STEFF2 = STEREO2 && STEREO,
           STEFF3 = STEREO3 && STEREO,
           STEFF4 = STEREO4 && STEREO,
           WE0    = STEFF0==1 ? 2*W0 : W0,
           WE1    = STEFF1==1 ? 2*W1 : W1,
           WE2    = STEFF2==1 ? 2*W2 : W2,
           WE3    = STEFF3==1 ? 2*W3 : W3,
           WE4    = STEFF4==1 ? 2*W4 : W4,
           WO0    = STEFF0==1 ? 2*WOUT : WOUT,
           WO1    = STEFF1==1 ? 2*WOUT : WOUT,
           WO2    = STEFF2==1 ? 2*WOUT : WOUT,
           WO3    = STEFF3==1 ? 2*WOUT : WOUT,
           WO4    = STEFF4==1 ? 2*WOUT : WOUT;

wire signed [WE0-1:0] sm0;
wire signed [WE1-1:0] sm1;
wire signed [WE2-1:0] sm2;
wire signed [WE3-1:0] sm3;
wire signed [WE4-1:0] sm4;
wire signed [WO0-1:0] ft0;
wire signed [WO1-1:0] ft1;
wire signed [WO2-1:0] ft2;
wire signed [WO3-1:0] ft3;
wire signed [WO4-1:0] ft4;
wire           [ 4:0] v;        // overflow in sound chain
wire signed    [15:0] left, right, pre_l, pre_r;
wire                  peak_l, peak_r;
wire                  cen;          // sampling frequency

assign sample=cen;

wire nc;
jtframe_frac_cen #(.WC(FRACW)) u_cen(
    .clk    ( clk       ),
    .n      ( FRACN     ),
    .m      ( FRACM     ),
    .cen    ({nc,cen}   ),
    .cenb   (           )
);

// convert to mono if the system is mono, otherwise kept as stereo
jtframe_st2mono #(.W(W0),.SIN(STEREO0),.SOUT(STEREO)) u_st0(.sin(ch0),.sout(sm0));
jtframe_st2mono #(.W(W1),.SIN(STEREO1),.SOUT(STEREO)) u_st1(.sin(ch1),.sout(sm1));
jtframe_st2mono #(.W(W2),.SIN(STEREO2),.SOUT(STEREO)) u_st2(.sin(ch2),.sout(sm2));
jtframe_st2mono #(.W(W3),.SIN(STEREO3),.SOUT(STEREO)) u_st3(.sin(ch3),.sout(sm3));
jtframe_st2mono #(.W(W4),.SIN(STEREO4),.SOUT(STEREO)) u_st4(.sin(ch4),.sout(sm4));

jtframe_sndchain #(.W(W0),.DCRM(DCRM0),.STEREO(STEFF0),.FIR(FIR0)) u_ch0(.rst(rst),.clk(clk),.cen(cen),.poles(p0),.gain(g0),.sin(sm0), .sout(ft0), .peak(v[0]));
jtframe_sndchain #(.W(W1),.DCRM(DCRM1),.STEREO(STEFF1),.FIR(FIR1)) u_ch1(.rst(rst),.clk(clk),.cen(cen),.poles(p1),.gain(g1),.sin(sm1), .sout(ft1), .peak(v[1]));
jtframe_sndchain #(.W(W2),.DCRM(DCRM2),.STEREO(STEFF2),.FIR(FIR2)) u_ch2(.rst(rst),.clk(clk),.cen(cen),.poles(p2),.gain(g2),.sin(sm2), .sout(ft2), .peak(v[2]));
jtframe_sndchain #(.W(W3),.DCRM(DCRM3),.STEREO(STEFF3),.FIR(FIR3)) u_ch3(.rst(rst),.clk(clk),.cen(cen),.poles(p3),.gain(g3),.sin(sm3), .sout(ft3), .peak(v[3]));
jtframe_sndchain #(.W(W4),.DCRM(DCRM4),.STEREO(STEFF4),.FIR(FIR4)) u_ch4(.rst(rst),.clk(clk),.cen(cen),.poles(p4),.gain(g4),.sin(sm4), .sout(ft4), .peak(v[4]));


jtframe_limsum #(.W(WOUT),.K(5)) u_right(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .cen    ( cen   ),
    .en     ( ch_en ),
    .parts  ( {ft4[WOUT-1:0], ft3[WOUT-1:0], ft2[WOUT-1:0], ft1[WOUT-1:0], ft0[WOUT-1:0]} ),
    .sum    ( pre_r ),
    .peak   ( peak_r)
);

// Global RC
jtframe_pole #(.WS(16),.WA(WC)) u_pole1(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .sample ( cen   ),
    .a      ( gpole ),
    .sin    ( pre_r ),
    .sout   ( right )
);

always @(posedge clk) mixed[WOUT-1:0] <= mute ? {WOUT{1'b0}} : right;

generate
    if( STEREO==1 ) begin
        jtframe_limsum #(.W(WOUT),.K(5)) u_left(
            .rst    ( rst   ),
            .clk    ( clk   ),
            .cen    ( cen   ),
            .en     ( ch_en ),
            .parts  ( {ft4[WO4-1-:WOUT],
                       ft3[WO3-1-:WOUT],
                       ft2[WO2-1-:WOUT],
                       ft1[WO1-1-:WOUT],
                       ft0[WO0-1-:WOUT] } ),
            .sum    ( pre_l ),
            .peak   ( peak_l)
        );
        // Global RC
        jtframe_pole #(.WS(16),.WA(WC)) u_pole1(
            .rst    ( rst   ),
            .clk    ( clk   ),
            .sample ( cen   ),
            .a      ( gpole ),
            .sin    ( pre_l ),
            .sout   ( left  )
        );

        always @(posedge clk) begin
            mixed[WMX-1-:WOUT] <= mute ? {WOUT{1'b0}} : left;
            peak <= | {peak_l, peak_r, v};
        end
    end else begin
        always @(posedge clk) peak <= | {peak_r, v};
    end
endgenerate

endmodule

// converts stereo to mono by a clipping adder
// or leaves the signal as stereo if the output can take stereo
module jtframe_st2mono #(parameter
    W    = 12,
    SIN  = 1,
    SOUT = 1,
    // Do not assign
    WI   = (SIN==1?2*W:W),
    WO   = (SIN==1&&SOUT==1)?2*W:W
)(
    input      [WI-1:0] sin,
    output reg [WO-1:0] sout
);

wire [W:0] raw = {sin[W-1],sin[0+:W]}+{sin[WI-1],sin[WI-1-:W]};
reg [W-1:0] mono;
localparam [1:0] ST2MONO  =2'b10,
                 STEREO   =2'b11;

always @* begin
    mono = raw[W]!=raw[W-1] ? { raw[W], {W-1{~raw[W]}}} : raw[W-1:0];
    case( {SIN[0], SOUT[0]} )
        STEREO:  sout        = sin[WO-1:0];
        ST2MONO: sout[W-1:0] = mono;
        default: sout[W-1:0] = sin[W-1:0];
    endcase
end

endmodule