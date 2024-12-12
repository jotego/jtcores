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
    Date: 8-12-2024 */

// bass/treble "equalizer"
module jt7630_equ #( parameter
    SW=16,       // signal bit width
    DCRM=1       // add a previous DCRM stage
)(
    input         rst,
    input         clk,
    input         cen48k,
    output        peak,
    input   [3:0] lo_setting,
    input   [3:0] hi_setting,
    input  signed [SW-1:0] sin, // can be unsigned if DCRM=0
    output signed [SW-1:0] sout
);
/* verilator lint_off REALCVT */
localparam WA = SW/2;
localparam [WA-1:0] P100 = 0.98708*{WA{1'b1}};
localparam [WA-1:0] P1k  = 0.88425*{WA{1'b1}};
localparam [WA-1:0] Z100 = 0.01292*{WA{1'b1}};
localparam [WA-1:0] Z1k  = 0.11575*{WA{1'b1}};

wire signed [SW-1:0] dcrm, lo100, lo1k, hi100, hi1k, loamp, hiamp;
reg  [7:0] logain, higain;

// 0=-16dB, 15=14dB, 2dB step
// encoded as 3.5 integer.decimal
function [7:0] gain(input [3:0] s);
    case(s)
        0: gain=8'd006; // -16dB
        1: gain=8'd007;
        2: gain=8'd009;
        3: gain=8'd012;
        4: gain=8'd015;
        5: gain=8'd018;
        6: gain=8'd023;
        7: gain=8'd029;
        8: gain=8'd036;
        9: gain=8'd046;
       10: gain=8'd058;
       11: gain=8'd073;
       12: gain=8'd092;
       13: gain=8'd115;
       14: gain=8'd145;
       15: gain=8'd183; // +14dB
    endcase
endfunction

always @(posedge clk) begin
    logain <= gain(lo_setting);
    higain <= gain(hi_setting);
end

generate
    if(DCRM==1) begin
        jtframe_dcrm #(.SW(SW)) u_dcrm(
            .rst    ( rst       ),
            .clk    ( clk       ),
            .sample ( cen48k    ),
            .din    ( sin       ),
            .dout   ( dcrm      )
        );
    end else begin
        assign dcrm = sin;
    end
endgenerate

// low pass filter  at 100Hz
// a = 0.98708 -> 100Hz fc
jtframe_pole u_pole100(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .sample ( cen48k    ),
    .sin    ( dcrm      ),
    .a      ( P100      ),
    .sout   ( lo100     )
);

// low pass filter  at 1kHz
// a = 0.88425 -> 1kHz fc
jtframe_pole u_pole1k(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .sample ( cen48k    ),
    .sin    ( dcrm      ),
    .a      ( P1k       ),
    .sout   ( lo1k      )
);

// high pass filter  at 100Hz
// a = 0.01292 -> 100Hz fc
jtframe_zero u_zero100(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .sample ( cen48k    ),
    .sin    ( dcrm      ),
    .a      ( Z100      ),
    .sout   ( hi100     )
);

// high pass filter  at 1kHz
// a = 0.11575 -> 1kHz fc
jtframe_zero u_zero1k(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .sample ( cen48k    ),
    .sin    ( dcrm      ),
    .a      ( Z1k       ),
    .sout   ( hi1k      )
);

jtframe_limmul #(.WD(5)) u_logain(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen48k    ),
    .sin    ( lo100     ),
    .gain   ( logain    ),
    .peaked ( 1'b0      ),
    .mul    ( loamp     ),
    .peak   (           )
);

jtframe_limmul #(.WD(5)) u_higain(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen48k    ),
    .sin    ( hi1k      ),
    .gain   ( higain    ),
    .peaked ( 1'b0      ),
    .mul    ( hiamp     ),
    .peak   (           )
);

jtframe_limsum #(.K(4)) u_sum(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen48k    ),
    .parts  ( {loamp,hiamp,hi100,lo1k}),
    .en     ( 4'b1111   ),
    .sum    ( sout      ),
    .peak   ( peak      )
);

endmodule
