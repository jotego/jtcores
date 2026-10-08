/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 14-3-2021 */

module jtframe_68kramcs #(parameter W=2)(
    input          rst,
    input          clk,
    input          cpu_cen,

    input          UDSWn,
    input          LDSWn,

    input  [W-1:0] pre_cs,
    output [W-1:0] cs
);

reg         dsn_dly;
reg [W-1:0] cs_latch;

// ram_cs and vram_cs signals go down before DSWn signals
// that causes a false read request to the SDRAM. In order
// to avoid that a little bit of logic is needed:
assign cs  = dsn_dly ? (cs_latch&pre_cs)  : pre_cs;

always @(posedge clk) begin
    if( rst ) begin
        cs_latch <= 0;
        dsn_dly  <= 1;
    end else if(cpu_cen) begin
        cs_latch <= pre_cs;
        dsn_dly  <= &{UDSWn,LDSWn}; // low if any DSWn was low
    end
end

endmodule