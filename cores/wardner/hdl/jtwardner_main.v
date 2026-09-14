/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Wardner main CPU: Z80 at 6 MHz.
 *
 *   0000-6FFF  ROM
 *   7000-7FFF  work RAM, shared with the DSP
 *   8000-8FFF  sprite RAM, shared with the DSP
 *   A000-AFFF  palette RAM, shared with the DSP
 *   C000-C7FF  RAM shared with the sound CPU
 *   8000-FFFF  banked ROM, for reads while port 70 holds a non-zero value
 *
 * The tile maps are only reached through I/O ports. While the DSP runs it
 * holds this CPU and takes over the bus of the RAMs it shares.
 */
module jtwardner_main(
    input             rst,
    input             clk,
    input             cen6,
    input             LVBL,

    output reg [17:0] rom_addr,
    input      [ 7:0] rom_data,
    output reg        rom_cs,
    input             rom_ok,

    output            dsp_on,
    input             dsp_halt,
    input      [13:1] dsp_addr,
    input      [ 1:0] dsp_sel,
    input      [15:0] dsp_dout,
    output     [15:0] dsp_din,
    input             dsp_we,

    output     [11:1] sh_addr,
    output     [15:0] sh_din,
    output     [ 1:0] work_bwe,
    output     [ 1:0] obj_bwe,
    output     [ 1:0] pal_bwe,
    input      [15:0] work_dout,
    input      [15:0] objram_dout,
    input      [15:0] pal_dout,

    output     [10:0] mshr_addr,
    output            mshr_we,
    input      [ 7:0] shared_dout,

    output     [15:0] tx_scrx,
    output     [15:0] tx_scry,
    output     [15:0] bg_scrx,
    output     [15:0] bg_scry,
    output     [15:0] fg_scrx,
    output     [15:0] fg_scry,
    output reg        flip,
    output reg        bg_bank,
    output reg        fg_bank,
    output reg        video_on,

    output     [15:0] cpu16,
    output     [11:1] tx_a,
    output     [13:1] bg_a,
    output     [12:1] fg_a,
    output     [ 1:0] tx_bwe,
    output     [ 1:0] bg_bwe,
    output     [ 1:0] fg_bwe,
    input      [15:0] txram_dout,
    input      [15:0] bgram_dout,
    input      [15:0] fgram_dout,

    output     [ 7:0] cpu_dout,

    input      [15:0] dipsw,
    input      [ 5:0] joystick1,
    input      [ 5:0] joystick2,
    input      [ 1:0] cab_1p,
    input      [ 1:0] coin,
    input             service,
    input             tilt,
    input             dip_test
);

wire        m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, irq_n;
wire        cpu_cen, mreq, iorq, rd, wr, io_wr, io_rd;
wire [15:0] A, txoffs, bgoffs, fgoffs;
wire [ 7:0] port;
reg  [ 7:0] cpu_din, dipsw_a, dipsw_b, joy1, joy2, cab_sys, coin_ctl;
reg  [ 2:0] bank;
reg         ram_view, int_en;
reg         work_cs, obj_cs, pal_cs, shr_cs, bank_cs, txscr_cs, bgscr_cs, fgscr_cs;
reg         tx_lo_we, tx_hi_we, bg_lo_we, bg_hi_we, fg_lo_we, fg_hi_we;

assign cpu_cen   = cen6 & ~dsp_halt;
assign rd        = ~rd_n;
assign wr        = ~wr_n;
assign mreq      = ~mreq_n & rfsh_n;
assign iorq      = ~iorq_n & m1_n;
assign io_wr     = iorq & wr;
assign io_rd     = iorq & rd;
assign port      = A[7:0];
assign dsp_on    = coin_ctl[0];

assign sh_addr   = dsp_halt ? dsp_addr[11:1] : A[11:1];
assign sh_din    = dsp_halt ? dsp_dout : {cpu_dout, cpu_dout};
assign work_bwe  = dsp_halt ? {2{dsp_we && dsp_sel==2'd0}} : {2{work_cs & wr}} & {A[0], ~A[0]};
assign obj_bwe   = dsp_halt ? {2{dsp_we && dsp_sel==2'd1}} : {2{obj_cs  & wr}} & {A[0], ~A[0]};
assign pal_bwe   = dsp_halt ? {2{dsp_we && dsp_sel==2'd2}} : {2{pal_cs  & wr}} & {A[0], ~A[0]};
assign dsp_din   = dsp_sel==2'd0 ? work_dout   :
                   dsp_sel==2'd1 ? objram_dout :
                   dsp_sel==2'd2 ? pal_dout    : 16'd0;

assign mshr_addr = A[10:0];
assign mshr_we   = shr_cs & wr;

assign tx_a      = txoffs[10:0];
assign bg_a      = {bg_bank, bgoffs[11:0]};
assign fg_a      = fgoffs[11:0];
assign cpu16     = {cpu_dout, cpu_dout};
assign tx_bwe    = {tx_hi_we, tx_lo_we};
assign bg_bwe    = {bg_hi_we, bg_lo_we};
assign fg_bwe    = {fg_hi_we, fg_lo_we};

// writes always reach the RAMs at 8000-FFFF; reads go to the banked ROM
// unless port 70 was last written with zero
always @* begin
    work_cs  = mreq && A[15:12] == 4'h7;
    obj_cs   = mreq && A[15:12] == 4'h8;
    pal_cs   = mreq && A[15:12] == 4'ha;
    shr_cs   = mreq && A[15:11] == 5'b11000;
    bank_cs  = mreq && A[15] && !ram_view;
    rom_cs   = (mreq && A < 16'h7000) || (bank_cs && rd);
    rom_addr = bank_cs ? {bank, A[14:0]} : {3'd0, A[14:0]};
    txscr_cs = cpu_cen && io_wr && port[7:3] == 5'b00010 && port[2:0] < 3'd6;
    bgscr_cs = cpu_cen && io_wr && port[7:3] == 5'b00100 && port[2:0] < 3'd6;
    fgscr_cs = cpu_cen && io_wr && port[7:3] == 5'b00110 && port[2:0] < 3'd6;
end

// the cabinet ports read active high; jtframe supplies up, down, left, right
// in bits 3 down to 0
always @(posedge clk) begin
    dipsw_a <= dipsw[ 7:0];
    dipsw_b <= dipsw[15:8];
    joy1    <= { 2'b00, ~joystick1[5:4], ~joystick1[0], ~joystick1[1], ~joystick1[2], ~joystick1[3] };
    joy2    <= { 2'b00, ~joystick2[5:4], ~joystick2[0], ~joystick2[1], ~joystick2[2], ~joystick2[3] };
    cab_sys <= { 1'b0, ~cab_1p[1], ~cab_1p[0], ~coin[1], ~coin[0], ~dip_test, ~tilt, ~service };
end

always @* begin
    case( 1'b1 )
        rom_cs:             cpu_din = rom_data;
        work_cs:            cpu_din = A[0] ? work_dout[15:8]   : work_dout[7:0];
        obj_cs && ram_view: cpu_din = A[0] ? objram_dout[15:8] : objram_dout[7:0];
        pal_cs && ram_view: cpu_din = A[0] ? pal_dout[15:8]    : pal_dout[7:0];
        shr_cs && ram_view: cpu_din = shared_dout;
        io_rd: case( port )
            8'h50:   cpu_din = dipsw_a;
            8'h52:   cpu_din = dipsw_b;
            8'h54:   cpu_din = joy1;
            8'h56:   cpu_din = joy2;
            8'h58:   cpu_din = { ~LVBL, cab_sys[6:0] };
            8'h60:   cpu_din = txram_dout[ 7:0];
            8'h61:   cpu_din = txram_dout[15:8];
            8'h62:   cpu_din = bgram_dout[ 7:0];
            8'h63:   cpu_din = bgram_dout[15:8];
            8'h64:   cpu_din = fgram_dout[ 7:0];
            8'h65:   cpu_din = fgram_dout[15:8];
            default: cpu_din = 8'hff;
        endcase
        default:            cpu_din = 8'hff;
    endcase
end

// ports 5A and 5C are LS259 addressable latches: bits 3-1 pick the output,
// bit 0 is the value
always @(posedge clk) begin
    if( rst ) begin
        bank     <= 0;
        ram_view <= 1;
        coin_ctl <= 0;
        int_en   <= 0;
        flip     <= 0;
        bg_bank  <= 0;
        fg_bank  <= 0;
        video_on <= 0;
        { tx_lo_we, tx_hi_we, bg_lo_we, bg_hi_we, fg_lo_we, fg_hi_we } <= 0;
    end else begin
        { tx_lo_we, tx_hi_we, bg_lo_we, bg_hi_we, fg_lo_we, fg_hi_we } <= 0;
        if( cpu_cen && io_wr ) case( port )
            8'h5a: coin_ctl[cpu_dout[3:1]] <= cpu_dout[0];
            8'h5c: case( cpu_dout[3:1] )
                3'd2:    int_en   <= cpu_dout[0];
                3'd3:    flip     <= cpu_dout[0];
                3'd4:    bg_bank  <= cpu_dout[0];
                3'd5:    fg_bank  <= cpu_dout[0];
                3'd6:    video_on <= cpu_dout[0];
                default:;
            endcase
            8'h60: tx_lo_we <= 1;
            8'h61: tx_hi_we <= 1;
            8'h62: bg_lo_we <= 1;
            8'h63: bg_hi_we <= 1;
            8'h64: fg_lo_we <= 1;
            8'h65: fg_hi_we <= 1;
            8'h70: begin
                ram_view <= cpu_dout == 8'd0;
                bank     <= cpu_dout[2:0];
            end
            default:;
        endcase
    end
end

jtwardner_scroll_mmr u_txscr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cs         ( txscr_cs  ),
    .addr       ( port[2:0] ),
    .rnw        ( 1'b0      ),
    .din        ( cpu_dout  ),
    .dout       (           ),
    .scrx       ( tx_scrx   ),
    .scry       ( tx_scry   ),
    .offs       ( txoffs    ),
    .ioctl_addr ( 3'd0      ),
    .ioctl_din  (           ),
    .debug_bus  ( 8'd0      ),
    .st_dout    (           )
);

jtwardner_scroll_mmr u_bgscr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cs         ( bgscr_cs  ),
    .addr       ( port[2:0] ),
    .rnw        ( 1'b0      ),
    .din        ( cpu_dout  ),
    .dout       (           ),
    .scrx       ( bg_scrx   ),
    .scry       ( bg_scry   ),
    .offs       ( bgoffs    ),
    .ioctl_addr ( 3'd0      ),
    .ioctl_din  (           ),
    .debug_bus  ( 8'd0      ),
    .st_dout    (           )
);

jtwardner_scroll_mmr u_fgscr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cs         ( fgscr_cs  ),
    .addr       ( port[2:0] ),
    .rnw        ( 1'b0      ),
    .din        ( cpu_dout  ),
    .dout       (           ),
    .scrx       ( fg_scrx   ),
    .scry       ( fg_scry   ),
    .offs       ( fgoffs    ),
    .ioctl_addr ( 3'd0      ),
    .ioctl_din  (           ),
    .debug_bus  ( 8'd0      ),
    .st_dout    (           )
);

// vertical blanking raises the interrupt while it is enabled; only clearing
// the enable drops it
jtframe_edge #(.QSET(0)) u_irq(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .edgeof     ( ~LVBL     ),
    .clr        ( ~int_en   ),
    .q          ( irq_n     )
);

jtframe_z80 u_cpu(
    .rst_n      ( ~rst                  ),
    .clk        ( clk                   ),
    .cen        ( cpu_cen               ),
    .wait_n     ( ~(rom_cs & ~rom_ok)   ),
    .int_n      ( irq_n                 ),
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
    .dout       ( cpu_dout              )
);

endmodule
