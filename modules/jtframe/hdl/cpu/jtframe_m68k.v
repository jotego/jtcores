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
    Date: 30-5-2021 */

/*
        Logic cells  | Registers | Memory bits | M9Ks | Compilation time (jtcore shinobi -q -p)
fx68k    5174        |  1388     | 39584       |  6   | 3m00s
fx68k*   3078        |   881     | 40608       |  8   | 3m30s
j68      9020        |  1870     |  7344       |  2   | 5m00s

* using Gyurco's BRAM option

*/

module jtframe_m68k(
    input   clk,
    input   rst,

    // signals supported only by FX68K
    input   cpu_cen,
    input   cpu_cenb,
    input   BERRn,
    input   VPAn,   // J68 only supports autovector interrupts
    input   BGACKn,

    input   HALTn,
    output  RESETn,

    output  [23:1] eab,
    output  ASn,
    output  LDSn,
    output  UDSn,
    output  eRWn,
    input   DTACKn,

    // Data bus
    input   [15:0] iEdb,
    output  [15:0] oEdb,

    // Bus sharing
    input   BRn,
    output  BGn,

    // interrupts
    input  [2:0] IPLn,

    // state
    output [2:0] FC
);

`ifndef VERILATOR_KEEP_CPU /* verilator tracing_off  */ `endif
`ifdef JTFRAME_J68
jtframe_j68 u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
`else
fx68k u_cpu(
    .clk        ( clk         ),
    .extReset   ( rst         ),
    .pwrUp      ( rst         ),
    .enPhi1     ( cpu_cen     ),
    .enPhi2     ( cpu_cenb    ),

    .VPAn       ( VPAn        ),
    .BERRn      ( BERRn       ),
    .oRESETn    ( RESETn      ),
    // Unused
    .oHALTEDn   (             ),
    .VMAn       (             ),
    .E          (             ),
`endif
    .HALTn      ( HALTn       ),

    .eRWn       ( eRWn        ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),

    .DTACKn     ( DTACKn      ),
    .IPL0n      ( IPLn[0]     ),
    .IPL1n      ( IPLn[1]     ),
    .IPL2n      ( IPLn[2]     ),

    .eab        ( eab         ),
    .iEdb       ( iEdb        ),
    .oEdb       ( oEdb        ),

    .BRn        ( BRn         ),
    .BGACKn     ( BGACKn      ),
    .BGn        ( BGn         ),

    .FC0        ( FC[0]       ),
    .FC1        ( FC[1]       ),
    .FC2        ( FC[2]       )
);
endmodule