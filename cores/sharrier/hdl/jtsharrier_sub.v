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

    Author: niknak
    Version: 1.0
    Date: 2-8-2026 */

/*  JTSHARRIER — Space Harrier sub 68000 (sprite/road math coprocessor)

    Simpler than Out Run: the sub shares RAM with main as true dual-port memory,
    there is NO bus-request/steal arbitration. Main controls this CPU through
    PPI1 port A:  bit5 = RESET, bit6 = IRQ4 (both active-low as driven here).

    Sub 68000 memory map (global mask 0x7FFFF, A = byte address):
      000000-03FFFF  Sub program ROM (64K used)   rom_cs
      068000-068FFF  Road RAM (4K, shared)        roadram_cs   (port B)
      07C000-07FFFF  Shared work RAM (16K)        subram_cs    (port B)
*/

module jtsharrier_sub(
    input              rst,        // global reset
    input              clk,
    input              cen,        // 10 MHz (use the phase opposite main)
    input              cenb,

    // control from main via PPI1 port A
    input              sub_rstn,   // 0 = hold sub in reset
    input              sub_irqn,   // 0 = assert IRQ4

    // ROM (bank 1 'subrom') — 64 KB: epr-7182/7183 interleaved = 0x10000 bytes.
    // mem.yaml subrom addr_width 16, so the generated bus is subrom_addr[15:1].
    output reg         rom_cs,
    output      [15:1] rom_addr,
    input       [15:0] rom_data,
    input              rom_ok,

    // shared dual-port RAMs (port B side)
    output reg         subram_cs,
    output      [13:1] subram_addr,
    input       [15:0] subram_data,
    output reg         roadram_cs,
    output      [11:1] roadram_addr,
    input       [15:0] roadram_data,

    // CPU bus out
    output      [15:0] cpu_dout,
    output      [18:1] cpu_addr,
    output             RnW,
    output      [ 1:0] dsn,        // {UDSn, LDSn}
    output             cpu_we
);

wire        eff_rst = rst | ~sub_rstn;   // main can hold sub in reset

wire [23:1] A;
wire        ASn, UDSn, LDSn, cpu_rnw, VPAn;
wire [ 2:0] FC;
wire [15:0] cpu_din;
// IRQ4 like Out Run: level 4 pins = { IPL2n, IPL1n, IPL0n } = { irqn, 1, 1 }
wire [ 2:0] IPLn = { sub_irqn, 2'b11 };
wire        DTACKn;

wire        bus_cs   = rom_cs | subram_cs | roadram_cs;
wire        bus_busy = rom_cs & ~rom_ok;
assign      DTACKn   = ~(bus_cs & ~bus_busy);

wire        inta_n = ~&FC[1:0];
assign      VPAn   = ~(~ASn & ~inta_n);   // autovector

assign cpu_addr     = A[18:1];
assign RnW          = cpu_rnw;
assign dsn          = { UDSn, LDSn };
assign cpu_we       = ~cpu_rnw;
assign rom_addr     = A[15:1];
assign subram_addr  = A[13:1];
assign roadram_addr = A[11:1];

/* verilator lint_off PINMISSING */
jtframe_m68k u_cpu(
    .clk    ( clk      ), .rst     ( eff_rst  ),
    .cpu_cen( cen      ), .cpu_cenb( cenb     ),
    .eab    ( A        ), .iEdb    ( cpu_din  ), .oEdb ( cpu_dout ),
    .eRWn   ( cpu_rnw  ), .LDSn    ( LDSn     ), .UDSn ( UDSn     ),
    .ASn    ( ASn      ), .VPAn    ( VPAn     ), .FC   ( FC       ),
    .BERRn  ( 1'b1     ), .HALTn   ( 1'b1     ),
    .BRn    ( 1'b1     ), .BGACKn  ( 1'b1     ), .BGn  (          ),
    .DTACKn ( DTACKn   ), .IPLn    ( IPLn     )
);
/* verilator lint_on PINMISSING */

// ---- address decode (registered on cen, gated by !ASn) --------------------
wire valid = ~ASn;

always @(posedge clk) begin
    if( eff_rst ) begin
        rom_cs<=0; subram_cs<=0; roadram_cs<=0;
    end else if( cen ) begin
        rom_cs     <= valid && A[18]==1'b0;              // 000000-03FFFF
        roadram_cs <= valid && A[18:12]==7'h68;          // 068000-068FFF
        subram_cs  <= valid && A[18:14]==5'h1F;          // 07C000-07FFFF
    end
end

assign cpu_din =
    rom_cs     ? rom_data     :
    subram_cs  ? subram_data  :
    roadram_cs ? roadram_data :
    16'hffff;

endmodule
