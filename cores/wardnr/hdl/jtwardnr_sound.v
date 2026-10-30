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
module jtwardnr_sound #(parameter TWINCOBR=0)(
    input             rst,
    input             clk,
    input             cen3p5,

    input      [ 7:0] sys,
    input      [15:0] dipsw,
    input             busrq_n,
    output            busak_n,

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

    output signed [15:0] snd
);

wire        m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n;
wire [15:0] A;
wire [ 7:0] fm_dout, wram_dout;
wire        fm_irq_n, mreq, iorq, rd, wr;
reg  [ 7:0] cpu_din;
reg         ram_cs, shr_cs, wram_cs, fm_cs, io_cs;
reg  [ 7:0] io_dout;
reg  [ 1:0] busak_sh;
wire        z80_busak_n;

assign rd        = ~rd_n;
assign wr        = ~wr_n;
assign mreq      = ~mreq_n & rfsh_n;
assign iorq      = ~iorq_n & m1_n;
assign rom_addr  = A[14:0];
assign shr_addr  = A[10:0];
assign ram_addr  = A[6:0];
assign shr_we    = shr_cs  & wr;
assign ram_we    = ram_cs  & wr;
assign busak_n   = TWINCOBR ? busak_sh[1] : z80_busak_n;

always @* begin
    rom_cs  = mreq && !A[15] && rd;
    if( TWINCOBR ) begin
        fm_cs   = iorq && A[6:4] == 3'd0;
        ram_cs  = 0;
        shr_cs  = mreq && A[15];
        wram_cs = 0;
        io_cs   = iorq && rd && A[6:4] != 3'd0;
    end else begin
        fm_cs   = iorq && A[7:1]   == 7'd0;
        ram_cs  = mreq && A[15:7]  == 9'b1000_0000_0;
        shr_cs  = mreq && A[15:11] == 5'b11000;
        wram_cs = mreq && A[15:11] == 5'b11001;
        io_cs   = 0;
    end
end

always @(posedge clk) begin
    case( A[6:4] )
        3'd1:    io_dout <= sys;
        3'd4:    io_dout <= dipsw[ 7:0];
        3'd5:    io_dout <= dipsw[15:8];
        default: io_dout <= 8'hff;
    endcase
    if( rst ) busak_sh <= 2'b11;
    else if( cen3p5 ) busak_sh <= { busak_sh[0], z80_busak_n };
end

always @* begin
    case( 1'b1 )
        rom_cs:  cpu_din = rom_data;
        ram_cs:  cpu_din = ram_dout;
        wram_cs: cpu_din = wram_dout;
        shr_cs:  cpu_din = shr_din;
        fm_cs:   cpu_din = fm_dout;
        io_cs:   cpu_din = io_dout;
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
    .sample (           )
);

jtframe_sysz80 #(.RAM_AW(11)) u_cpu(
    .rst_n      ( ~rst                  ),
    .clk        ( clk                   ),
    .cen        ( cen3p5                ),
    .cpu_cen    (                       ),
    .int_n      ( fm_irq_n              ),
    .nmi_n      ( 1'b1                  ),
    .busrq_n    ( busrq_n               ),
    .m1_n       ( m1_n                  ),
    .mreq_n     ( mreq_n                ),
    .iorq_n     ( iorq_n                ),
    .rd_n       ( rd_n                  ),
    .wr_n       ( wr_n                  ),
    .rfsh_n     ( rfsh_n                ),
    .halt_n     (                       ),
    .busak_n    ( z80_busak_n           ),
    .A          ( A                     ),
    .cpu_din    ( cpu_din               ),
    .cpu_dout   ( shr_dout              ),
    .ram_dout   ( wram_dout             ),
    .ram_cs     ( wram_cs              ),
    .rom_cs     ( rom_cs               ),
    .rom_ok     ( rom_ok               )
);

endmodule
