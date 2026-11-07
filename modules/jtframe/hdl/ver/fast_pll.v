/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-8-2022 */

`timescale 1ns/1ps

`ifndef SDRAM_DELAY
    `define SDRAM_DELAY 0
`endif

// 96 MHz PLL model
// The simulator must have defined JTFRAME_PLLSIM to the period in ns
// of c0, the rest of the outputs are derived
module jtframe_pll0(
    input        inclk0,
    output       c0,     // SDRAM (48 or 96)
    output   reg c1,     // 48
    output   reg c2,     // 96
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
        {c2,c1,c3,c4,nc} = 0;
        forever c2 = #(BASE_CLK/2.0) ~c2;
    end

    always @(posedge c2) begin
        {c4,nc,c3,c1} <= {c4,nc,c3,c1} + 1'b1;
    end

    real sdram_delay = `SDRAM_DELAY;
    `ifdef JTFRAME_SDRAM96
        assign #sdram_delay c0 = c2;    // use the high speed clock
    `else
        assign #sdram_delay c0 = c1;
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