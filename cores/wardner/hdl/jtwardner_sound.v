/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Wardner sound CPU: Z80 at 3.5 MHz (14 MHz crystal / 4) driving a YM3812,
 * also at 3.5 MHz.
 *
 *   0000-7FFF  ROM
 *   8000-807F  RAM, 128 bytes
 *   C000-C7FF  shared with the main CPU
 *   C800-CFFF  RAM, 2 KB
 *
 *   ports 00-01  YM3812
 *
 * There is no sound latch and no NMI: the two processors talk only through the
 * 2 KB of shared RAM. The main CPU never polls that region - its reads of it
 * match its writes almost exactly - so commands go one way and are picked up
 * whenever this CPU next looks.
 *
 * The only interrupt is the YM3812's own, used for its timers.
 */
module jtwardner_sound(
    input             rst,
    input             clk,
    input             cen3p5,         // 3.5 MHz

    // program ROM
    output     [14:0] rom_addr,
    input      [ 7:0] rom_data,
    output            rom_cs,
    input             rom_ok,

    // RAM shared with the main CPU
    output     [10:0] shr_addr,
    output     [ 7:0] shr_dout,
    input      [ 7:0] shr_din,
    output            shr_we,

    // audio
    output signed [15:0] snd,
    output               sample,

    // observation
    output            dbg_fmwr,
    output     [ 7:0] dbg_fmdata,
    output            dbg_fmaddr,
    output     [15:0] dbg_pc_addr,
    output            dbg_m1
);

wire        m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, halt_n, busak_n;
wire [15:0] A;
wire [ 7:0] cpu_dout;
reg  [ 7:0] cpu_din;

wire rd   = ~rd_n;
wire wr   = ~wr_n;
wire mreq = ~mreq_n & rfsh_n;
wire iorq = ~iorq_n & m1_n;

// ------------------------------------------------------------------ decoding
wire in_rom  = mreq && !A[15];                              // 0000-7FFF
wire in_ram1 = mreq && A[15:12] == 4'h8 && A[11:7] == 5'd0; // 8000-807F
wire in_shr  = mreq && A[15:11] == 5'b11000;                // C000-C7FF
wire in_ram2 = mreq && A[15:11] == 5'b11001;                // C800-CFFF

assign rom_cs   = in_rom & rd;
assign rom_addr = A[14:0];

assign shr_addr = A[10:0];
assign shr_dout = cpu_dout;
assign shr_we   = in_shr & wr;

// ---------------------------------------------------------------- local RAM
wire [7:0] ram1_q, ram2_q;

jtframe_dual_ram #(.AW(7),.DW(8)) u_ram1(
    .clk0(clk),.data0(cpu_dout),.addr0(A[6:0]),.we0(in_ram1 & wr),.q0(ram1_q),
    .clk1(clk),.data1(8'd0),.addr1(7'd0),.we1(1'b0),.q1() );

jtframe_dual_ram #(.AW(11),.DW(8)) u_ram2(
    .clk0(clk),.data0(cpu_dout),.addr0(A[10:0]),.we0(in_ram2 & wr),.q0(ram2_q),
    .clk1(clk),.data1(8'd0),.addr1(11'd0),.we1(1'b0),.q1() );

// ------------------------------------------------------------------- YM3812
wire       fm_cs = iorq && A[7:1] == 7'd0;      // ports 00 and 01
wire [7:0] fm_dout;
wire       fm_irq_n;

assign dbg_fmwr   = fm_cs & wr;
assign dbg_fmdata = cpu_dout;
assign dbg_fmaddr = A[0];
assign dbg_pc_addr= A;
assign dbg_m1     = ~m1_n;

jtopl2 u_opl(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen3p5    ),
    .din    ( cpu_dout  ),
    .addr   ( A[0]      ),
    .cs_n   ( ~fm_cs    ),
    .wr_n   ( wr_n      ),
    .dout   ( fm_dout   ),
    .irq_n  ( fm_irq_n  ),
    .snd    ( snd       ),
    .sample ( sample    )
);

// -------------------------------------------------------------- read multiplex
always @* begin
    cpu_din = 8'hff;
    case( 1'b1 )
        rom_cs:  cpu_din = rom_data;
        in_ram1: cpu_din = ram1_q;
        in_ram2: cpu_din = ram2_q;
        in_shr:  cpu_din = shr_din;
        fm_cs:   cpu_din = fm_dout;
        default:;
    endcase
end

wire wait_n = ~(rom_cs & ~rom_ok);

T80s u_cpu(
    .RESET_n ( ~rst      ),
    .CLK     ( clk       ),
    .CEN     ( cen3p5    ),
    .WAIT_n  ( wait_n    ),
    .INT_n   ( fm_irq_n  ),
    .NMI_n   ( 1'b1      ),
    .BUSRQ_n ( 1'b1      ),
    .OUT0    ( 1'b0      ),
    .DI      ( cpu_din   ),
    .M1_n    ( m1_n      ),
    .MREQ_n  ( mreq_n    ),
    .IORQ_n  ( iorq_n    ),
    .RD_n    ( rd_n      ),
    .WR_n    ( wr_n      ),
    .RFSH_n  ( rfsh_n    ),
    .HALT_n  ( halt_n    ),
    .BUSAK_n ( busak_n   ),
    .A       ( A         ),
    .DOUT    ( cpu_dout  )
);

endmodule
