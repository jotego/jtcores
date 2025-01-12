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
    W0=16,W1=16,W2=16,W3=16,W4=16,W5=16,
    STEREO =1, // is the output stereo?
    DCRM0=0,DCRM1=0,DCRM2=0,DCRM3=0,DCRM4=0,DCRM5=0,     // dc removal
    STEREO0=1,STEREO1=1,STEREO2=1,STEREO3=1,STEREO4=1,STEREO5=1, // are the input channels stereo?
    // Path to FIR filter coefficient files. Enabling FIR will disable the 2-pole filters
    FIR0="",FIR1="",FIR2="",FIR3="",FIR4="",FIR5="",
    // Fractional divider
    FRACW=12, FRACN = 1, FRACM=262,
    // Do not set externally:
    WOUT=16,
    WC  =15,             // pole coefficient resolution
    WMX=STEREO ==1?WOUT*2:WOUT,
    WS0=STEREO0==1?  W0*2:W0,
    WS1=STEREO1==1?  W1*2:W1,
    WS2=STEREO2==1?  W2*2:W2,
    WS3=STEREO3==1?  W3*2:W3,
    WS4=STEREO4==1?  W4*2:W4,
    WS5=STEREO5==1?  W5*2:W5
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
    input  signed [WS5-1:0] ch5,
    input  [5:0]            ch_en,
    // up to 2 pole coefficients per input (unsigned numbers, only decimal part)
    input  [WC*2-1:0] p0,p1,p2,p3,p4,p5, // concatenate the bits for each pole coefficient
    input  [WC  -1:0] gpole,          // allow for one global pole
    // gain for each channel in 4.4 fixed point format
    input       [7:0] g0,g1,g2,g3,g4,g5,  // concatenate all gains {gain4, gain3,..., gain0}
    input       [7:0] gain,               // global gain
    output              sample,
    output reg  [5:0]   vu,     // "volume unit", signals channel activity
    output reg signed [WMX-1:0] mixed,
    output reg          peak   // overflow signal
);

localparam SFREQ = 192,              // sampling frequency in kHz
           STEFF0 = STEREO0 && STEREO,
           STEFF1 = STEREO1 && STEREO,
           STEFF2 = STEREO2 && STEREO,
           STEFF3 = STEREO3 && STEREO,
           STEFF4 = STEREO4 && STEREO,
           STEFF5 = STEREO5 && STEREO,
           WE0    = STEFF0==1 ? 2*W0 : W0,
           WE1    = STEFF1==1 ? 2*W1 : W1,
           WE2    = STEFF2==1 ? 2*W2 : W2,
           WE3    = STEFF3==1 ? 2*W3 : W3,
           WE4    = STEFF4==1 ? 2*W4 : W4,
           WE5    = STEFF5==1 ? 2*W5 : W5,
           WO0    = STEFF0==1 ? 2*WOUT : WOUT,
           WO1    = STEFF1==1 ? 2*WOUT : WOUT,
           WO2    = STEFF2==1 ? 2*WOUT : WOUT,
           WO3    = STEFF3==1 ? 2*WOUT : WOUT,
           WO4    = STEFF4==1 ? 2*WOUT : WOUT,
           WO5    = STEFF5==1 ? 2*WOUT : WOUT;

wire signed [WE0-1:0] sm0;
wire signed [WE1-1:0] sm1;
wire signed [WE2-1:0] sm2;
wire signed [WE3-1:0] sm3;
wire signed [WE4-1:0] sm4;
wire signed [WE5-1:0] sm5;
wire signed [WO0-1:0] ft0;
wire signed [WO1-1:0] ft1;
wire signed [WO2-1:0] ft2;
wire signed [WO3-1:0] ft3;
wire signed [WO4-1:0] ft4;
wire signed [WO5-1:0] ft5;
wire           [ 5:0] v;        // overflow in sound chain
wire signed    [15:0] left, right, mul_l, mul_r;
wire signed    [16:0] pre_l, pre_r; // extra bit to allow reduction in the final gain stage
wire                  peak_l, peak_r, pks_l, pks_r;
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

always @(posedge clk) if(cen) begin
    vu[0] <= ch0!=0;
    vu[1] <= ch1!=0;
    vu[2] <= ch2!=0;
    vu[3] <= ch3!=0;
    vu[4] <= ch4!=0;
    vu[5] <= ch5!=0;
end

// convert to mono if the system is mono, otherwise kept as stereo
jtframe_st2mono #(.W(W0),.STEREO_IN(STEREO0),.STEREO_OUT(STEREO)) u_st0(.sin(ch0),.sout(sm0));
jtframe_st2mono #(.W(W1),.STEREO_IN(STEREO1),.STEREO_OUT(STEREO)) u_st1(.sin(ch1),.sout(sm1));
jtframe_st2mono #(.W(W2),.STEREO_IN(STEREO2),.STEREO_OUT(STEREO)) u_st2(.sin(ch2),.sout(sm2));
jtframe_st2mono #(.W(W3),.STEREO_IN(STEREO3),.STEREO_OUT(STEREO)) u_st3(.sin(ch3),.sout(sm3));
jtframe_st2mono #(.W(W4),.STEREO_IN(STEREO4),.STEREO_OUT(STEREO)) u_st4(.sin(ch4),.sout(sm4));
jtframe_st2mono #(.W(W5),.STEREO_IN(STEREO5),.STEREO_OUT(STEREO)) u_st5(.sin(ch5),.sout(sm5));

jtframe_sndchain #(.FILE("ch0.raw"),.W(W0),.WC(WC),.DCRM(DCRM0),.STEREO(STEFF0),.FIR(FIR0)) u_ch0(.rst(rst),.clk(clk),.cen(cen),.poles(p0),.gain(g0),.sin(sm0), .sout(ft0), .peak(v[0]));
jtframe_sndchain #(.FILE("ch1.raw"),.W(W1),.WC(WC),.DCRM(DCRM1),.STEREO(STEFF1),.FIR(FIR1)) u_ch1(.rst(rst),.clk(clk),.cen(cen),.poles(p1),.gain(g1),.sin(sm1), .sout(ft1), .peak(v[1]));
jtframe_sndchain #(.FILE("ch2.raw"),.W(W2),.WC(WC),.DCRM(DCRM2),.STEREO(STEFF2),.FIR(FIR2)) u_ch2(.rst(rst),.clk(clk),.cen(cen),.poles(p2),.gain(g2),.sin(sm2), .sout(ft2), .peak(v[2]));
jtframe_sndchain #(.FILE("ch3.raw"),.W(W3),.WC(WC),.DCRM(DCRM3),.STEREO(STEFF3),.FIR(FIR3)) u_ch3(.rst(rst),.clk(clk),.cen(cen),.poles(p3),.gain(g3),.sin(sm3), .sout(ft3), .peak(v[3]));
jtframe_sndchain #(.FILE("ch4.raw"),.W(W4),.WC(WC),.DCRM(DCRM4),.STEREO(STEFF4),.FIR(FIR4)) u_ch4(.rst(rst),.clk(clk),.cen(cen),.poles(p4),.gain(g4),.sin(sm4), .sout(ft4), .peak(v[4]));
jtframe_sndchain #(.FILE("ch5.raw"),.W(W5),.WC(WC),.DCRM(DCRM5),.STEREO(STEFF5),.FIR(FIR5)) u_ch5(.rst(rst),.clk(clk),.cen(cen),.poles(p5),.gain(g5),.sin(sm5), .sout(ft5), .peak(v[5]));

jtframe_limsum #(.WI(WOUT),.WO(WOUT+1),.K(6)) u_right(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .cen    ( cen   ),
    .en     ( ch_en ),
    .parts  ( {ft5[WOUT-1:0], ft4[WOUT-1:0], ft3[WOUT-1:0], ft2[WOUT-1:0], ft1[WOUT-1:0], ft0[WOUT-1:0]} ),
    .sum    ( pre_r ),
    .peak   ( pks_r )
);

jtframe_limmul #(.WI(WOUT+1),.WO(WOUT)) u_gain(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .cen    ( cen   ),
    .gain   ( gain  ),
    .sin    ( pre_r ),
    .mul    ( mul_r ),
    .peaked ( pks_r ),
    .peak   ( peak_r)
);

// Global RC
jtframe_pole #(.WS(16),.WA(WC)) u_pole1(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .sample ( cen   ),
    .a      ( gpole ),
    .sin    ( mul_r ),
    .sout   ( right )
);

always @(posedge clk) mixed[WOUT-1:0] <= mute ? {WOUT{1'b0}} : right;

generate
    if( STEREO==1 ) begin : leftch
        jtframe_limsum #(.WI(WOUT),.WO(WOUT+1),.K(6)) u_left(
            .rst    ( rst   ),
            .clk    ( clk   ),
            .cen    ( cen   ),
            .en     ( ch_en ),
            .parts  ( {ft5[WO5-1-:WOUT],
                       ft4[WO4-1-:WOUT],
                       ft3[WO3-1-:WOUT],
                       ft2[WO2-1-:WOUT],
                       ft1[WO1-1-:WOUT],
                       ft0[WO0-1-:WOUT] } ),
            .sum    ( pre_l ),
            .peak   ( pks_l )
        );

        jtframe_limmul #(.WI(WOUT+1),.WO(WOUT)) u_gain(
            .rst    ( rst   ),
            .clk    ( clk   ),
            .cen    ( cen   ),
            .gain   ( gain  ),
            .sin    ( pre_l ),
            .mul    ( mul_l ),
            .peaked ( pks_l ),
            .peak   ( peak_l)
        );

        // Global RC
        jtframe_pole #(.WS(16),.WA(WC)) u_pole1(
            .rst    ( rst   ),
            .clk    ( clk   ),
            .sample ( cen   ),
            .a      ( gpole ),
            .sin    ( mul_l ),
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
