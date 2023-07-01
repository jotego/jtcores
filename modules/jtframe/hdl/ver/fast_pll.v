/*  This file is part of JTFRAME.
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
    Date: 7-8-2022 */

`timescale 1ns/1ps

`ifndef SDRAM_DELAY
    `define SDRAM_DELAY 1
`endif

// 96 MHz PLL model
// The simulator must have defined JTFRAME_PLLSIM to the period in ns
// of c0, the rest of the outputs are derived
module jtframe_pll0(
    input        inclk0,
    output   reg c0,     // 96
    output   reg c1,     // 48
    output       c2,     // 48 (shifted by -2.5ns)
    output   reg c3,     // 24
    output   reg c4,     // 6
    output   reg locked
);
    localparam real BASE_CLK=`JTFRAME_PLLSIM;

    initial begin
        locked = 0;
        #30 locked = 1;
    end

    reg nc;

    initial begin
        {c0,c1,c3,c4,nc} = 0;
        forever c0 = #(BASE_CLK/2.0) ~c0;
    end

    always @(posedge c0) begin
        {c4,nc,c3,c1} <= {c4,nc,c3,c1} + 1'b1;
    end

    real sdram_delay = `SDRAM_DELAY;
    `ifdef JTFRAME_SDRAM96
        assign #sdram_delay c2 = c0;    // use the high speed clock
    `else
        assign #sdram_delay c2 = c1;
    `endif

endmodule

/////////////////////////////////////
// Wrappers

// 96 MHz PLL
module jtframe_pllgame96(
    input        inclk0,
    output       c0,     // 96
    output       c1,     // 48
    output       c2,     // 96 (shifted by -2.5ns)
    output       c3,     // 24
    output       c4,     // 6
    output       locked
);
    jtframe_pll0 pll(
        .inclk0 ( inclk0    ),
        .c0     ( c0        ),
        .c1     ( c1        ),
        .c2     ( c2        ),
        .c3     ( c3        ),
        .c4     ( c4        ),
        .locked ( locked    )
    );
endmodule

// 48 MHz PLL
module jtframe_pllgame(
    input        inclk0,
    output       c0,     // 50.3
    output       c1,     // 50.3
    output       c2,     // 50.3 (shifted by -2.5ns)
    output       c3,     // 25.17
    output       c4,     // 6.29
    output       locked
);

    jtframe_pll0 pll(
        .inclk0 ( inclk0    ),
        .c0     ( c0        ),
        .c1     ( c1        ),
        .c2     ( c2        ),
        .c3     ( c3        ),
        .c4     ( c4        ),
        .locked ( locked    )
    );
endmodule

module jtframe_pll6000(
    input        inclk0,
    output       c0,
    output       locked
);
    jtframe_pll0 pll(
        .inclk0 ( inclk0    ),
        .c0     ( c0        ),
        .c1     (           ),
        .c2     (           ),
        .c3     (           ),
        .c4     (           ),
        .locked ( locked    )
    );
endmodule

module jtframe_pll6293(
    input        inclk0,
    output       c0,     // 50.3
    output       locked
);
    jtframe_pll0 pll(
        .inclk0 ( inclk0    ),
        .c0     ( c0        ),
        .c1     (           ),
        .c2     (           ),
        .c3     (           ),
        .c4     (           ),
        .locked ( locked    )
    );
endmodule

module jtframe_pll6144(
    input        inclk0,
    output       c0,     // 49.152
    output       locked
);
    jtframe_pll0 pll(
        .inclk0 ( inclk0    ),
        .c0     ( c0        ),
        .c1     (           ),
        .c2     (           ),
        .c3     (           ),
        .c4     (           ),
        .locked ( locked    )
    );
endmodule

module jtframe_pll6671(
    input        inclk0,
    output       c0,     // 53.368
    output       locked
);
    jtframe_pll0 pll(
        .inclk0 ( inclk0    ),
        .c0     ( c0        ),
        .c1     (           ),
        .c2     (           ),
        .c3     (           ),
        .c4     (           ),
        .locked ( locked    )
    );
endmodule