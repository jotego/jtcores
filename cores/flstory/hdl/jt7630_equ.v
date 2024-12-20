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
    output signed [SW-1:0] sout,
    // debug - independent outputs
    output signed [SW-1:0] lopass0, lopass1, hipass0, hipass1
);
/* verilator lint_off REALCVT */
localparam WA = 14;
localparam [WA-1:0] P100 = 0.99836*{WA{1'b1}};
localparam [WA-1:0] P1k  = 0.98363*{WA{1'b1}};
localparam [WA-1:0] P10k = 0.83489*{WA{1'b1}};

wire signed [SW-1:0] dcrm, loamp, hiamp;
reg  [7:0] logain, higain;

// 0=-16dB, 15=14dB, 2dB step
// encoded as 3.5 integer.decimal
function [7:0] gain(input [3:0] s);
    case(s)
        0: gain=8'd001; // -16dB
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
        // wire signed [SW-1:0] sin_sh = sin-{1'b1,{SW-1{1'b0}}};
        // jtframe_hipass #(.WA(14)) u_dcrm(
        //     .rst    ( rst       ),
        //     .clk    ( clk       ),
        //     .sample ( cen48k    ),
        //     .sin    ( sin_sh    ),
        //     .b      ( 14'd16381 ),
        //     .a      ( 14'd16379 ),
        //     .sout   ( dcrm      )
        // );
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
jtframe_pole #(.WA(WA)) u_pole100(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .sample ( cen48k    ),
    .sin    ( dcrm      ),
    .a      ( P100      ),
    .sout   ( lopass0   )
);

// low pass filter  at 10kHz
// a = 0.43308 -> 10kHz fc
jtframe_pole #(.WA(WA)) u_pole1k(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .sample ( cen48k    ),
    .sin    ( dcrm      ),
    .a      ( P1k       ),
    .sout   ( lopass1   )
);

// high pass filter  at 100Hz
jtframe_hipass #(.WA(14)) u_hipass100(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .sample ( cen48k    ),
    .sin    ( dcrm      ),
    .b      ( 14'd16357 ),
    .a      ( 14'd16330 ),
    .sout   ( hipass0   )
);

// high pass filter  at 1kHz
jtframe_hipass #(.WA(14)) u_hipass1k(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .sample ( cen48k    ),
    .sin    ( dcrm      ),
    // 1kHz
    // .b      ( 14'd16120 ),
    // .a      ( 14'd15856 ),
    .b      ( 14'd14062 ),
    .a      ( 14'd11741 ),
    .sout   ( hipass1   )
);

jtframe_limmul #(.WD(6)) u_logain(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen48k    ),
    .sin    ( lopass0   ),
    .gain   ( logain    ),
    .peaked ( 1'b0      ),
    .mul    ( loamp     ),
    .peak   (           )
);

jtframe_limmul #(.WD(6)) u_higain(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen48k    ),
    .sin    ( hipass1   ),
    .gain   ( higain    ),
    .peaked ( 1'b0      ),
    .mul    ( hiamp     ),
    .peak   (           )
);

jtframe_limsum #(.K(4)) u_sum(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen48k    ),
    .parts  ( {loamp>>>1,hiamp>>>1,hipass0>>>1,lopass1>>>1}),
    .en     ( 4'b1111   ),
    .sum    ( sout      ),
    .peak   ( peak      )
);

endmodule
