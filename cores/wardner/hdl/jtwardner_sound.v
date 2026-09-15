/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Wardner sound CPU: Z80 and YM3812 at 3.5 MHz. It talks to the main CPU only
 * through 2 kB of shared RAM; the YM3812 timer is its only interrupt.
 *
 *   0000-7FFF  ROM
 *   8000-807F  RAM
 *   C000-C7FF  shared with the main CPU
 *   C800-CFFF  RAM
 *   ports 00-01 YM3812
 */
module jtwardner_sound(
    input             rst,
    input             clk,
    input             cen3p5,

    output     [14:0] rom_addr,
    input      [ 7:0] rom_data,
    output reg        rom_cs,
    input             rom_ok,

    // shr_dout is the CPU data bus, written to all three RAMs
    output     [10:0] shr_addr,
    output     [ 7:0] shr_dout,
    input      [ 7:0] shr_din,
    output            shr_we,

    output     [ 6:0] ram_addr,
    output            ram_we,
    input      [ 7:0] ram_dout,

    output     [10:0] wram_addr,
    output            wram_we,
    input      [ 7:0] wram_dout,

    output signed [15:0] snd,
    output               sample
);

wire        m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n;
wire [15:0] A;
wire [ 7:0] fm_dout;
wire        fm_irq_n, mreq, iorq, rd, wr;
reg  [ 7:0] cpu_din;
reg         ram_cs, shr_cs, wram_cs, fm_cs;

assign rd        = ~rd_n;
assign wr        = ~wr_n;
assign mreq      = ~mreq_n & rfsh_n;
assign iorq      = ~iorq_n & m1_n;
assign rom_addr  = A[14:0];
assign shr_addr  = A[10:0];
assign ram_addr  = A[6:0];
assign wram_addr = A[10:0];
assign shr_we    = shr_cs  & wr;
assign ram_we    = ram_cs  & wr;
assign wram_we   = wram_cs & wr;

always @* begin
    rom_cs  = mreq && !A[15] && rd;
    ram_cs  = mreq && A[15:7]  == 9'b1000_0000_0;
    shr_cs  = mreq && A[15:11] == 5'b11000;
    wram_cs = mreq && A[15:11] == 5'b11001;
    fm_cs   = iorq && A[7:1]   == 7'd0;
end

always @* begin
    case( 1'b1 )
        rom_cs:  cpu_din = rom_data;
        ram_cs:  cpu_din = ram_dout;
        wram_cs: cpu_din = wram_dout;
        shr_cs:  cpu_din = shr_din;
        fm_cs:   cpu_din = fm_dout;
        default: cpu_din = 8'hff;
    endcase
end

jtopl2 u_opl(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen3p5    ),
    .din    ( shr_dout  ),
    .addr   ( A[0]      ),
    .cs_n   ( ~fm_cs    ),
    .wr_n   ( wr_n      ),
    .dout   ( fm_dout   ),
    .irq_n  ( fm_irq_n  ),
    .snd    ( snd       ),
    .sample ( sample    )
);

jtframe_z80 u_cpu(
    .rst_n      ( ~rst                  ),
    .clk        ( clk                   ),
    .cen        ( cen3p5                ),
    .wait_n     ( ~(rom_cs & ~rom_ok)   ),
    .int_n      ( fm_irq_n              ),
    .nmi_n      ( 1'b1                  ),
    .busrq_n    ( 1'b1                  ),
    .m1_n       ( m1_n                  ),
    .mreq_n     ( mreq_n                ),
    .iorq_n     ( iorq_n                ),
    .rd_n       ( rd_n                  ),
    .wr_n       ( wr_n                  ),
    .rfsh_n     ( rfsh_n                ),
    .halt_n     (                       ),
    .busak_n    (                       ),
    .A          ( A                     ),
    .din        ( cpu_din               ),
    .dout       ( shr_dout              )
);

endmodule
