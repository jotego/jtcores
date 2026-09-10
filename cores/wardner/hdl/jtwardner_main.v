/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Wardner main CPU: Z80 at 6 MHz (24 MHz crystal / 4).
 *
 * Memory map
 *   0000-6FFF  ROM, fixed
 *   7000-7FFF  work RAM, 4 KB          - the DSP reaches into this
 *   8000-8FFF  sprite RAM, 4 KB        - and this
 *   A000-AFFF  palette RAM, 4 KB       - and this
 *   C000-C7FF  shared with the sound Z80
 *   8000-FFFF  32 KB ROM bank window
 *
 * The window at 8000-FFFF is not a plain bank switch. Writes always land in
 * the sprite, palette and sound RAMs; only *reads* move between those RAMs and
 * the banked ROM, chosen by whether port 0x70 was last written with zero.
 *
 * None of the video RAM is in the memory map. A word address is latched
 * through one pair of I/O ports and the data then read or written a byte at a
 * time through another, so the three tile maps live entirely behind ports.
 *
 * Sharing the RAMs with the DSP
 * -----------------------------
 * Work, sprite and palette RAM are byte wide to the Z80 and 16 bits wide to
 * the DSP, so each is built from a pair of byte-wide blocks holding even and
 * odd addresses. The DSP's word is little endian, low byte at the even
 * address.
 *
 * The two processors never run at the same time - the run bit halts this CPU
 * for the whole of the DSP's work - so they share one port of each block
 * rather than needing an arbiter, which leaves the second port free for the
 * video engine.
 *
 * The halt itself is modelled by gating the clock enable, stopping the Z80
 * immediately as MAME's INPUT_LINE_HALT does. The real board most likely uses
 * BUSRQ, which would let the current instruction finish first; the difference
 * is invisible to the software, because the DSP's results are only read after
 * it has released the line again.
 */
module jtwardner_main(
    input             rst,
    input             clk,
    input             cen6,           // 6 MHz
    input             LVBL,           // low during vertical blanking

    // program ROM
    output reg [17:0] rom_addr,
    input      [ 7:0] rom_data,
    output reg        rom_cs,
    input             rom_ok,

    // DSP subsystem
    output            dsp_on,         // run bit: LS259 "coinlatch" bit 0
    input             dsp_halt,       // the DSP is holding this CPU
    input      [12:0] dsp_addr,
    input      [ 1:0] dsp_sel,
    input      [15:0] dsp_dout,
    output     [15:0] dsp_din,
    input             dsp_we,

    // shared RAM with the sound CPU
    input      [10:0] snd_addr,
    input      [ 7:0] snd_dout,
    output     [ 7:0] snd_din,
    input             snd_we,

    // video control registers
    output reg [15:0] tx_scrx, tx_scry, bg_scrx, bg_scry, fg_scrx, fg_scry,
    output reg        flip, bg_bank, fg_bank, video_on,

    // video read ports
    input      [10:0] tx_vaddr,  output [15:0] tx_vq,
    input      [12:0] bg_vaddr,  output [15:0] bg_vq,
    input      [11:0] fg_vaddr,  output [15:0] fg_vq,
    input      [10:0] pal_vaddr, output [15:0] pal_vq,
    input      [10:0] obj_vaddr, output [15:0] obj_vq,

    // cabinet
    input      [ 7:0] dipsw_a, dipsw_b, joy1, joy2, cab_sys,

    // observation, for the bench
    output            dbg_iowr, dbg_iord,
    output     [ 7:0] dbg_port, dbg_data,
    output     [15:0] dbg_pc_addr,
    output            dbg_m1
);

// ------------------------------------------------------------------ the CPU
wire        m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, halt_n, busak_n;
wire [15:0] A;
wire [ 7:0] cpu_dout;
reg  [ 7:0] cpu_din;
reg         irq_n;

wire cpu_cen = cen6 & ~dsp_halt;    // the DSP freezes this CPU here
wire wait_n  = ~(rom_cs & ~rom_ok);

wire rd    = ~rd_n;
wire wr    = ~wr_n;
wire mreq  = ~mreq_n & rfsh_n;      // refresh cycles are not accesses
wire iorq  = ~iorq_n & m1_n;        // and neither is interrupt acknowledge
wire [7:0] port = A[7:0];           // the board decodes eight address bits

assign dbg_iowr    = iorq & wr;
assign dbg_iord    = iorq & rd;
assign dbg_port    = port;
assign dbg_data    = cpu_dout;
assign dbg_pc_addr = A;
assign dbg_m1      = ~m1_n;

// ------------------------------------------------------------------ banking
reg [2:0] bank;
reg       ram_view;                 // 1 = the RAMs answer reads at 8000-FFFF

// ---------------------------------------------------------- memory decoding
wire in_rom0 = mreq && A < 16'h7000;
wire in_work = mreq && A[15:12] == 4'h7;
wire in_obj  = mreq && A[15:12] == 4'h8;
wire in_pal  = mreq && A[15:12] == 4'ha;
wire in_snd  = mreq && A[15:11] == 5'b11000;                // C000-C7FF
wire in_bank = mreq && A[15] && !ram_view;

wire work_we = in_work && wr;
wire obj_we  = in_obj  && wr;       // writes land whatever the view says
wire pal_we  = in_pal  && wr;
wire shr_we  = in_snd  && wr;

always @* begin
    rom_cs   = (in_rom0 | (in_bank & rd));
    rom_addr = in_bank ? {bank, A[14:0]} : {3'd0, A[14:0]};
end

// ------------------------------------------------- work / sprite / palette
// Port 0 of each block is shared between the Z80 and the DSP; only one of them
// is ever running. Port 1 is the video engine's read port.
wire [15:0] work_q, obj_q, pal_q;
wire        dsp_work = dsp_sel == 2'd0;
wire        dsp_obj  = dsp_sel == 2'd1;
wire        dsp_pal  = dsp_sel == 2'd2;

wire [10:0] sh_addr  = dsp_halt ? dsp_addr[10:0] : A[11:1];
wire [ 7:0] sh_dlo   = dsp_halt ? dsp_dout[ 7:0] : cpu_dout;
wire [ 7:0] sh_dhi   = dsp_halt ? dsp_dout[15:8] : cpu_dout;

wire work_lo_we = dsp_halt ? (dsp_we & dsp_work) : (work_we & ~A[0]);
wire work_hi_we = dsp_halt ? (dsp_we & dsp_work) : (work_we &  A[0]);
wire obj_lo_we  = dsp_halt ? (dsp_we & dsp_obj ) : (obj_we  & ~A[0]);
wire obj_hi_we  = dsp_halt ? (dsp_we & dsp_obj ) : (obj_we  &  A[0]);
wire pal_lo_we  = dsp_halt ? (dsp_we & dsp_pal ) : (pal_we  & ~A[0]);
wire pal_hi_we  = dsp_halt ? (dsp_we & dsp_pal ) : (pal_we  &  A[0]);

jtframe_dual_ram #(.AW(11),.DW(8)) u_work_lo(
    .clk0(clk),.data0(sh_dlo),.addr0(sh_addr),.we0(work_lo_we),.q0(work_q[ 7:0]),
    .clk1(clk),.data1(8'd0  ),.addr1(11'd0  ),.we1(1'b0      ),.q1() );
jtframe_dual_ram #(.AW(11),.DW(8)) u_work_hi(
    .clk0(clk),.data0(sh_dhi),.addr0(sh_addr),.we0(work_hi_we),.q0(work_q[15:8]),
    .clk1(clk),.data1(8'd0  ),.addr1(11'd0  ),.we1(1'b0      ),.q1() );

jtframe_dual_ram #(.AW(11),.DW(8)) u_obj_lo(
    .clk0(clk),.data0(sh_dlo),.addr0(sh_addr),.we0(obj_lo_we),.q0(obj_q[ 7:0]),
    .clk1(clk),.data1(8'd0  ),.addr1(obj_vaddr),.we1(1'b0    ),.q1(obj_vq[ 7:0]) );
jtframe_dual_ram #(.AW(11),.DW(8)) u_obj_hi(
    .clk0(clk),.data0(sh_dhi),.addr0(sh_addr),.we0(obj_hi_we),.q0(obj_q[15:8]),
    .clk1(clk),.data1(8'd0  ),.addr1(obj_vaddr),.we1(1'b0    ),.q1(obj_vq[15:8]) );

jtframe_dual_ram #(.AW(11),.DW(8)) u_pal_lo(
    .clk0(clk),.data0(sh_dlo),.addr0(sh_addr),.we0(pal_lo_we),.q0(pal_q[ 7:0]),
    .clk1(clk),.data1(8'd0  ),.addr1(pal_vaddr),.we1(1'b0    ),.q1(pal_vq[ 7:0]) );
jtframe_dual_ram #(.AW(11),.DW(8)) u_pal_hi(
    .clk0(clk),.data0(sh_dhi),.addr0(sh_addr),.we0(pal_hi_we),.q0(pal_q[15:8]),
    .clk1(clk),.data1(8'd0  ),.addr1(pal_vaddr),.we1(1'b0    ),.q1(pal_vq[15:8]) );

assign dsp_din = dsp_work ? work_q : dsp_obj ? obj_q : dsp_pal ? pal_q : 16'd0;

// shared RAM with the sound CPU, byte wide on both sides
wire [7:0] shr_q;
jtframe_dual_ram #(.AW(11),.DW(8)) u_shared(
    .clk0(clk),.data0(cpu_dout),.addr0(A[10:0]),.we0(shr_we),.q0(shr_q),
    .clk1(clk),.data1(snd_dout),.addr1(snd_addr),.we1(snd_we),.q1(snd_din) );

// ---------------------------------------------------------------- video RAM
// A word address is latched through ports 14/15, 24/25 and 34/35, then the
// data moves a byte at a time through ports 60-65. Each map is a pair of
// byte-wide blocks so the Z80 can write either half on its own.
reg [15:0] txoffs, bgoffs, fgoffs;
wire [10:0] tx_a = txoffs[10:0];
wire [12:0] bg_a = {bg_bank, bgoffs[11:0]};     // 0x2000 words: two banks of 0x1000
wire [11:0] fg_a = fgoffs[11:0];

wire [15:0] tx_q, bg_q, fg_q;
reg  tx_lo_we, tx_hi_we, bg_lo_we, bg_hi_we, fg_lo_we, fg_hi_we;

jtframe_dual_ram #(.AW(11),.DW(8)) u_tx_lo(
    .clk0(clk),.data0(cpu_dout),.addr0(tx_a),.we0(tx_lo_we),.q0(tx_q[ 7:0]),
    .clk1(clk),.data1(8'd0),.addr1(tx_vaddr),.we1(1'b0),.q1(tx_vq[ 7:0]) );
jtframe_dual_ram #(.AW(11),.DW(8)) u_tx_hi(
    .clk0(clk),.data0(cpu_dout),.addr0(tx_a),.we0(tx_hi_we),.q0(tx_q[15:8]),
    .clk1(clk),.data1(8'd0),.addr1(tx_vaddr),.we1(1'b0),.q1(tx_vq[15:8]) );

jtframe_dual_ram #(.AW(13),.DW(8)) u_bg_lo(
    .clk0(clk),.data0(cpu_dout),.addr0(bg_a),.we0(bg_lo_we),.q0(bg_q[ 7:0]),
    .clk1(clk),.data1(8'd0),.addr1(bg_vaddr),.we1(1'b0),.q1(bg_vq[ 7:0]) );
jtframe_dual_ram #(.AW(13),.DW(8)) u_bg_hi(
    .clk0(clk),.data0(cpu_dout),.addr0(bg_a),.we0(bg_hi_we),.q0(bg_q[15:8]),
    .clk1(clk),.data1(8'd0),.addr1(bg_vaddr),.we1(1'b0),.q1(bg_vq[15:8]) );

jtframe_dual_ram #(.AW(12),.DW(8)) u_fg_lo(
    .clk0(clk),.data0(cpu_dout),.addr0(fg_a),.we0(fg_lo_we),.q0(fg_q[ 7:0]),
    .clk1(clk),.data1(8'd0),.addr1(fg_vaddr),.we1(1'b0),.q1(fg_vq[ 7:0]) );
jtframe_dual_ram #(.AW(12),.DW(8)) u_fg_hi(
    .clk0(clk),.data0(cpu_dout),.addr0(fg_a),.we0(fg_hi_we),.q0(fg_q[15:8]),
    .clk1(clk),.data1(8'd0),.addr1(fg_vaddr),.we1(1'b0),.q1(fg_vq[15:8]) );

// ------------------------------------------------------------ I/O registers
wire io_wr = iorq & wr;
wire io_rd = iorq & rd;

reg [7:0] coin_ctl;                 // LS259 at port 5A
reg       int_en;                   // LS259 at port 5C, bit 2
assign dsp_on = coin_ctl[0];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank <= 3'd0; ram_view <= 1'b1;
        txoffs <= 0; bgoffs <= 0; fgoffs <= 0;
        tx_scrx<=0; tx_scry<=0; bg_scrx<=0; bg_scry<=0; fg_scrx<=0; fg_scry<=0;
        flip <= 0; bg_bank <= 0; fg_bank <= 0; video_on <= 0;
        int_en <= 0;
        coin_ctl <= 0;
    end else begin
        tx_lo_we <= 0; tx_hi_we <= 0;
        bg_lo_we <= 0; bg_hi_we <= 0;
        fg_lo_we <= 0; fg_hi_we <= 0;
        if( cpu_cen && io_wr ) begin
            case( port )
                8'h10: tx_scrx[ 7:0] <= cpu_dout;
                8'h11: tx_scrx[15:8] <= cpu_dout;
                8'h12: tx_scry[ 7:0] <= cpu_dout;
                8'h13: tx_scry[15:8] <= cpu_dout;
                8'h14: txoffs[ 7:0]  <= cpu_dout;
                8'h15: txoffs[15:8]  <= cpu_dout;

                8'h20: bg_scrx[ 7:0] <= cpu_dout;
                8'h21: bg_scrx[15:8] <= cpu_dout;
                8'h22: bg_scry[ 7:0] <= cpu_dout;
                8'h23: bg_scry[15:8] <= cpu_dout;
                8'h24: bgoffs[ 7:0]  <= cpu_dout;
                8'h25: bgoffs[15:8]  <= cpu_dout;

                8'h30: fg_scrx[ 7:0] <= cpu_dout;
                8'h31: fg_scrx[15:8] <= cpu_dout;
                8'h32: fg_scry[ 7:0] <= cpu_dout;
                8'h33: fg_scry[15:8] <= cpu_dout;
                8'h34: fgoffs[ 7:0]  <= cpu_dout;
                8'h35: fgoffs[15:8]  <= cpu_dout;

                // two LS259 addressable latches: bits 3-1 pick the output,
                // bit 0 is the value
                8'h5a: coin_ctl[cpu_dout[3:1]] <= cpu_dout[0];
                8'h5c: case( cpu_dout[3:1] )
                           3'd2: int_en   <= cpu_dout[0];
                           3'd3: flip     <= cpu_dout[0];
                           3'd4: bg_bank  <= cpu_dout[0];
                           3'd5: fg_bank  <= cpu_dout[0];
                           3'd6: video_on <= cpu_dout[0];
                           default:;
                       endcase

                8'h60: tx_lo_we <= 1'b1;
                8'h61: tx_hi_we <= 1'b1;
                8'h62: bg_lo_we <= 1'b1;
                8'h63: bg_hi_we <= 1'b1;
                8'h64: fg_lo_we <= 1'b1;
                8'h65: fg_hi_we <= 1'b1;

                8'h70: begin
                    ram_view <= cpu_dout == 8'd0;
                    bank     <= cpu_dout[2:0];
                end
                default:;
            endcase
        end
    end
end

// --------------------------------------------------------------- interrupts
// The vertical blanking edge raises the interrupt when it is enabled, and
// nothing clears it except the enable bit going away again - acknowledging
// the interrupt does not.
reg lvbl_l;
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        irq_n  <= 1'b1;
        lvbl_l <= 1'b1;
    end else begin
        lvbl_l <= LVBL;
        if( !int_en ) irq_n <= 1'b1;
        else if( lvbl_l && !LVBL ) irq_n <= 1'b0;   // blanking has just begun
    end
end

// ------------------------------------------------------------- read multiplex
always @* begin
    cpu_din = 8'hff;
    if( rom_cs )      cpu_din = rom_data;
    else if( in_work )               cpu_din = A[0] ? work_q[15:8] : work_q[7:0];
    else if( in_obj && ram_view )    cpu_din = A[0] ? obj_q[15:8]  : obj_q[7:0];
    else if( in_pal && ram_view )    cpu_din = A[0] ? pal_q[15:8]  : pal_q[7:0];
    else if( in_snd && ram_view )    cpu_din = shr_q;
    else if( io_rd ) case( port )
        8'h50: cpu_din = dipsw_a;
        8'h52: cpu_din = dipsw_b;
        8'h54: cpu_din = joy1;
        8'h56: cpu_din = joy2;
        8'h58: cpu_din = { ~LVBL, cab_sys[6:0] };
        8'h60: cpu_din = tx_q[ 7:0];
        8'h61: cpu_din = tx_q[15:8];
        8'h62: cpu_din = bg_q[ 7:0];
        8'h63: cpu_din = bg_q[15:8];
        8'h64: cpu_din = fg_q[ 7:0];
        8'h65: cpu_din = fg_q[15:8];
        default: cpu_din = 8'hff;
    endcase
end

T80s u_cpu(
    .RESET_n ( ~rst      ),
    .CLK     ( clk       ),
    .CEN     ( cpu_cen   ),
    .WAIT_n  ( wait_n    ),
    .INT_n   ( irq_n     ),
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
