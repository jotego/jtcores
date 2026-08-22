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

    Author: Andrea Bogazzi.
    Date: 5-2026

    Reference for protocol semantics:
      - MAME taito/taitoio.cpp::tc0220ioc_device (mirrored in
        cores/taitob/doc/taitoio.cpp lines 200-307).
      - Arcade-TaitoF2_MiSTer rtl/tc0220ioc.sv (GPLv2, read-only).
        85-line register file; not copied verbatim. The behaviour is
        small enough that two implementations from the same MAME
        reference are essentially identical.
*/

// Taito TC0220IOC — I/O controller used by the Taito B System and the
// earlier Taito F2 boards. 16-register window decoded by A[4:1] off the
// 68k bus. On Taito B the chip lives on the UPPER byte lane
// (umask16(0xff00) in MAME), so the 68k accesses register N via byte
// addresses 0xA0000<N> on the high byte.
//
// Register layout (per rastsag2_map machine_config @ taito_b.cpp:1870):
//   0x0  R: DSW A           W: watchdog reset (any value)
//   0x1  R: DSW B           W: -
//   0x2  R: IN0 (P1 stick + buttons + start)
//   0x3  R: IN1 (P2 stick + buttons + start)
//   0x4  R: coin/lockout latch (last written value)  W: coin counter / lockout
//   0x7  R: IN2 (coin, service, tilt)
//   others: hi-Z (return 0xFF in the real chip)
//
// First-cut stub: combinational reads only, no watchdog wiring, no
// coin-meter wiring. The coin-meter callback is set via the JT
// framework's `coin` input on the JTFRAME side; we ignore the
// 68k's writes to register 4 for now.

module jttaitob_ioc(
    input               rst,
    input               clk,

    // 68k bus (decoded by jttaitob_main.v)
    input               cs,
    input        [ 3:0] addr,                    // = 68k A[4:1]
    input               rnw,                     // 1 = read
    input               lds_n,                   // chip on UDS lane → use UDSn
    input        [ 7:0] din,                     // 68k high byte
    output reg   [ 7:0] dout,

    // Cabinet inputs (active LOW, packed by jttaitob_game.v)
    input        [ 7:0] dipsw_a,
    input        [ 7:0] dipsw_b,
    input        [ 7:0] in0,                     // P1 stick + buttons
    input        [ 7:0] in1,                     // P2 stick + buttons
    input        [ 7:0] in2                      // coin / service / tilt
);

reg [7:0] coin_latch;

always @* begin
    case (addr)
        4'h0: dout = dipsw_a;
        4'h1: dout = dipsw_b;
        4'h2: dout = in0;
        4'h3: dout = in1;
        4'h4: dout = coin_latch;
        4'h7: dout = in2;
        default: dout = 8'hFF;
    endcase
end

// Writes: only register 4 (coin counters / lockout) is captured.
// Register 0 writes are watchdog kicks — we drop them on the floor
// since JTFRAME provides its own framework-level watchdog.
always @(posedge clk, posedge rst) begin
    if (rst) begin
        coin_latch <= 8'h00;
    end else if (cs && ~rnw && ~lds_n) begin
        if (addr == 4'h4) coin_latch <= din;
    end
end

`ifdef SIMULATION
// One-shot dump of every IOC register on its first read so we can
// confirm the CPU actually sees the DIP / cabinet bits we think it does.
reg [7:0] seen;
initial seen = 8'h00;
always @(posedge clk) begin
    if (cs && rnw && addr[3] == 1'b0 /* only first 8 regs */ ) begin
        if (!seen[addr[2:0]]) begin
            $display("[%0t] IOC first read reg %0d -> 0x%02h  (dipsw_a=0x%02h dipsw_b=0x%02h in0=0x%02h in1=0x%02h in2=0x%02h)",
                     $time, addr[2:0], dout,
                     dipsw_a, dipsw_b, in0, in1, in2);
            seen[addr[2:0]] <= 1'b1;
        end
    end
end
`endif

endmodule
