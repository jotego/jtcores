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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 21-7-2026 */

// Taito TC0030CMD "C-Chip" — jtframe wrapper around the IKA87AD core.
//
// The physical package holds four dies (see doc, from the Op.Wolf schematic):
//   1 - uPD78C11 MCU + 4 KB internal mask ROM  (common to every game)
//   2 - uPD27C64 8 KB EPROM                     (game specific)
//   3 - uPD4464 8 KB SRAM                       (shared, banked 1 KB windows)
//   4 - ASIC (NEC ULA): 4-byte reg file + two bank registers + /DTACK gen
//
// The MCU (IKA87AD, decap-based, cycle-accurate) exposes the full 16-bit
// address directly, so the wrapper implements the internal memory map that
// MAME's taito_cchip_device::cchip_map describes:
//   0x0000-0x0FFF  internal mask ROM  (read only)
//   0x1000-0x13FF  1 KB window into the 8 KB shared SRAM, bank = bank_mcu
//   0x1400-0x17FF  ASIC region: 0x1600 write -> bank_mcu; else 4-byte reg
//   0x2000-0x3FFF  game EPROM         (read only)
//   0xFF00-0xFFFF  256 B MCU internal RAM
//
// The host (68k) side mirrors the real C-chip external pins (A0-A10, D0-D7,
// /CS, R/W, /DTACK):
//   0x000-0x3FF  1 KB window into the shared SRAM, bank = bank_68k
//   0x400-0x5FF  ASIC 4-byte reg file
//   0x600        bank_68k select (low 3 bits)
//
// There are two independent bank registers (bank_mcu / bank_68k) into the one
// 8 KB SRAM, exactly as MAME keeps m_upd4464_bank and m_upd4464_bank68.
//
// The C-chip drives no 68k interrupt line (pin 34 is /DTACK, there is no INT
// out pin); games poll the shared RAM.  INT1/NMI are inputs to the MCU
// (INT1 = vblank via MAME's ext_interrupt -> INTF1; NMI used by Rainbow Is.).

module jttc0030cmd #(
    parameter        SIMHEX_MROM  = "",   // 4 KB common mask ROM (sim load)
    parameter        SIMHEX_EPROM = ""    // 8 KB game EPROM      (sim load)
)(
    input             rst,        // active high, synchronous
    input             clk,
    input             cen,        // MCU clock enable (positive-edge PCEN)

    // ---- Host (68k) side: real C-chip external pins ----
    input             cs,         // active high (parent inverts /CS)
    input      [10:0] addr,       // A10..A0
    input      [ 7:0] din,
    output reg [ 7:0] dout,
    input             rnw,        // 1 = read, 0 = write
    output            dtack_n,

    // ---- MCU interrupt inputs ----
    input             int1,       // INT1 request (vblank). Pulse OR level; the
                                  // module holds it across the core's sample
                                  // filter (see INT1_HOLD), one IRQ per assert.
    input             nmi_n,      // /NMI pin

    // ---- MCU GPIO (PA/PB/PC bidirectional; direction is game-controlled) ----
    input      [ 7:0] pa_in,
    input      [ 7:0] pb_in,
    input      [ 7:0] pc_in,
    output     [ 7:0] pa_out,
    output     [ 7:0] pb_out,
    output     [ 7:0] pc_out,

    // ---- ADC / digital AN inputs (an[x]=1 reads back as 0xFF) ----
    input      [ 7:0] an,

    // ---- ROM download (jtframe): common mask ROM + game EPROM ----
    input      [12:0] prog_addr,  // 13 bits: 8 KB EPROM; low 12 for mask ROM
    input      [ 7:0] prog_data,
    input             mrom_we,    // write strobe: 4 KB mask ROM
    input             eprom_we,   // write strobe: 8 KB EPROM

    // ---- debug taps (sim) ----
    output     [15:0] dbg_pc,     // MCU bus address (= PC during opcode fetch)
    output            dbg_fetch   // opcode-fetch cycle (M1)
);

    // --------------------------------------------------------------------
    // MCU bus (from IKA87AD)
    // --------------------------------------------------------------------
    wire [15:0] mcu_addr;
    wire [ 7:0] mcu_dout;
    wire        mcu_wr_n, mcu_m1_n;
    reg  [ 7:0] mcu_din;
    wire        mcu_wr = ~mcu_wr_n;   // read strobe (o_RD_n) unused: storage is
                                      // always readable, CPU samples when ready

    assign dbg_pc    = mcu_addr;
    assign dbg_fetch = ~mcu_m1_n;

    // MCU-side region decodes (partial, mirror cchip_map exactly)
    wire mcu_mask = mcu_addr <  16'h1000;                     // 0x0000-0x0FFF
    wire mcu_sram = mcu_addr[15:10]==6'b0001_00;              // 0x1000-0x13FF
    wire mcu_asic = mcu_addr[15:10]==6'b0001_01;              // 0x1400-0x17FF
    wire mcu_epr  = mcu_addr[15:13]==3'b001;                  // 0x2000-0x3FFF
    wire mcu_iram = &mcu_addr[15:8];                          // 0xFF00-0xFFFF
    // Within the ASIC region the bank register is offset 0x200 (byte 0x1600).
    wire mcu_asic_off = mcu_addr[9];                          // 1 => 0x1600-0x17FF
    wire mcu_bank_we  = mcu_wr & mcu_asic & (mcu_addr[9:0]==10'h200);

    // --------------------------------------------------------------------
    // Host (68k) side decodes
    // --------------------------------------------------------------------
    wire k68_sram    = cs & ~addr[10];                        // 0x000-0x3FF
    wire k68_asic    = cs &  addr[10];                        // 0x400-0x7FF
    wire k68_wr      = cs & ~rnw;
    wire k68_bank_we = k68_wr & k68_asic & (addr[9:0]==10'h200); // byte 0x600

    // --------------------------------------------------------------------
    // Bank registers (two views into the same 8 KB SRAM)
    // --------------------------------------------------------------------
    reg [2:0] bank_mcu, bank_68k;
    reg [7:0] asic_ram[0:3];

    always @(posedge clk) begin
        if( rst ) begin
            bank_mcu    <= 3'd0;
            bank_68k    <= 3'd0;
            asic_ram[0] <= 8'd0; asic_ram[1] <= 8'd0;
            asic_ram[2] <= 8'd0; asic_ram[3] <= 8'd0;
        end else begin
            // ASIC 4-byte reg file: any ASIC write that is not a bank-set
            // lands in asic_ram[offset&3] (MAME asic_w / asic68_w).  68k wins
            // a same-cycle collision with the MCU.
            if     ( k68_wr & k68_asic & ~k68_bank_we ) asic_ram[addr[1:0]]     <= din;
            else if( mcu_wr & mcu_asic & ~mcu_bank_we ) asic_ram[mcu_addr[1:0]] <= mcu_dout;
            if( k68_bank_we ) bank_68k <= din[2:0];
            if( mcu_bank_we ) bank_mcu <= mcu_dout[2:0];
        end
    end

    // ASIC read-back: offset < 0x200 returns the reg file, else 0 (bank regs
    // are write-only on read, per MAME asic_r).
    wire [7:0] mcu_asic_rd = mcu_asic_off ? 8'h00 : asic_ram[mcu_addr[1:0]];
    wire [7:0] k68_asic_rd = addr[9]      ? 8'h00 : asic_ram[addr[1:0]];

    // --------------------------------------------------------------------
    // Storage.  BRAM runs on the full-rate clk (cen tied high) so its 1-cycle
    // latency is hidden inside the much slower MCU cycle; mcu_addr / addr are
    // held stable across the whole access, so the read mux can be combinational.
    // --------------------------------------------------------------------
    wire [7:0] mrom_q, epr_q, iram_q;
    wire [7:0] sram_qmcu, sram_q68;

    jtframe_prom #(.DW(8),.AW(12),.SIMHEX(SIMHEX_MROM)) u_mask(
        .clk    ( clk               ),
        .cen    ( 1'b1              ),
        .data   ( prog_data         ),
        .rd_addr( mcu_addr[11:0]    ),
        .wr_addr( prog_addr[11:0]   ),
        .we     ( mrom_we           ),
        .q      ( mrom_q            )
    );

    jtframe_prom #(.DW(8),.AW(13),.SIMHEX(SIMHEX_EPROM)) u_eprom(
        .clk    ( clk               ),
        .cen    ( 1'b1              ),
        .data   ( prog_data         ),
        .rd_addr( mcu_addr[12:0]    ),
        .wr_addr( prog_addr[12:0]   ),
        .we     ( eprom_we          ),
        .q      ( epr_q             )
    );

    // 8 KB shared SRAM — port 0 = MCU, port 1 = 68k, each with its own bank.
    jtframe_dual_ram #(.DW(8),.AW(13)) u_sram(
        .clk0   ( clk                         ),
        .data0  ( mcu_dout                    ),
        .addr0  ( {bank_mcu, mcu_addr[9:0]}   ),
        .we0    ( mcu_wr & mcu_sram           ),
        .q0     ( sram_qmcu                   ),
        .clk1   ( clk                         ),
        .data1  ( din                         ),
        .addr1  ( {bank_68k, addr[9:0]}       ),
        .we1    ( k68_wr & k68_sram           ),
        .q1     ( sram_q68                    )
    );

    // 256 B MCU internal RAM (single port on port 0).
    jtframe_dual_ram #(.DW(8),.AW(8)) u_iram(
        .clk0   ( clk                 ),
        .data0  ( mcu_dout            ),
        .addr0  ( mcu_addr[7:0]       ),
        .we0    ( mcu_wr & mcu_iram   ),
        .q0     ( iram_q              ),
        .clk1   ( clk                 ),
        .data1  ( 8'd0                ),
        .addr1  ( 8'd0                ),
        .we1    ( 1'b0                ),
        .q1     (                     )
    );

    // MCU read mux
    always @* begin
        case( 1'b1 )
            mcu_mask: mcu_din = mrom_q;
            mcu_sram: mcu_din = sram_qmcu;
            mcu_asic: mcu_din = mcu_asic_rd;
            mcu_epr:  mcu_din = epr_q;
            mcu_iram: mcu_din = iram_q;
            default:  mcu_din = 8'hFF;
        endcase
    end

    // Host read mux
    always @* begin
        if     ( k68_sram ) dout = sram_q68;
        else if( k68_asic ) dout = k68_asic_rd;
        else                dout = 8'hFF;
    end

    // /DTACK: one wait-state after cs, enough for the SRAM read latency.
    reg dtack;
    always @(posedge clk) begin
        if( rst ) dtack <= 1'b0;
        else      dtack <= cs;
    end
    assign dtack_n = ~dtack;

    // --------------------------------------------------------------------
    // ADC: MAME returns 0xFF/0x00 per AN bit; AN4-7 double as the digital
    // edge inputs.
    // --------------------------------------------------------------------
    wire [2:0] adc_ch;
    wire [7:0] adc_data = an[adc_ch] ? 8'hFF : 8'h00;

    // --------------------------------------------------------------------
    // INT1 conditioning. The IKA core samples INT1 through a datasheet-
    // accurate noise filter: it takes one sample every 36 MCU-clock (cen)
    // ticks and only recognises the request once it has read high across 3
    // consecutive samples (~108-144 cen ticks). On real hardware the /INT1
    // pin is a vblank LEVEL that easily spans that; a short FPGA pulse would
    // be rejected. Hold an incoming int1 request (pulse OR level) high for a
    // comfortable number of *cen* ticks so it is always recognised — exactly
    // once per request — independent of the request width and of the cen
    // rate passed in (the count is in cen ticks, not clk cycles).
    localparam [8:0] INT1_HOLD = 9'd192;   // > 3 sample windows + phase margin
    reg  [8:0] int1_cnt;
    reg        int1_held;
    always @(posedge clk) begin
        if( rst ) begin
            int1_cnt  <= 9'd0;
            int1_held <= 1'b0;
        end else if( int1 ) begin               // (re)arm on request
            int1_held <= 1'b1;
            int1_cnt  <= INT1_HOLD;
        end else if( cen && int1_cnt != 9'd0 ) begin
            int1_cnt <= int1_cnt - 9'd1;
            if( int1_cnt == 9'd1 ) int1_held <= 1'b0;
        end
    end

    // --------------------------------------------------------------------
    // MCU core
    // --------------------------------------------------------------------
    IKA87AD u_mcu(
        .i_EMUCLK           ( clk           ),
        .i_MCUCLK_PCEN      ( cen           ),
        .i_RESET_n          ( ~rst          ),
        .i_STOP_n           ( 1'b1          ),

        .o_M1_n             ( mcu_m1_n      ),
        .o_IO_n             (               ),
        .o_ALE              (               ),
        .o_RD_n             (               ),
        .o_WR_n             ( mcu_wr_n      ),
        .o_A                ( mcu_addr      ),
        .i_DI               ( mcu_din       ),
        .o_DO               ( mcu_dout      ),
        .o_PD_DO_OE         (               ),
        .o_D_nA_SEL         (               ),
        .o_DO_OE            (               ),
        .o_REG_MM           (               ),

        .i_NMI_n            ( nmi_n         ),
        .i_INT1             ( int1_held     ),   // conditioned (see INT1_HOLD)
        .i_INT2_n           ( 1'b1          ),

        .i_TI               ( 1'b0          ),
        .o_TO               (               ),
        .o_TO_PCEN          (               ),
        .o_TO_NCEN          (               ),
        .i_CI               ( 1'b0          ),

        .i_PA_I             ( pa_in         ),
        .o_PA_O             ( pa_out        ),
        .o_PA_OE            (               ),
        .i_PB_I             ( pb_in         ),
        .o_PB_O             ( pb_out        ),
        .o_PB_OE            (               ),
        .i_PC_I             ( pc_in         ),
        .o_PC_O             ( pc_out        ),
        .o_PC_OE            (               ),
        .o_REG_MCC          (               ),
        .i_PD_I             ( 8'd0          ),
        .o_PD_O             (               ),
        .o_PD_OE            (               ),
        .i_PF_I             ( 8'd0          ),
        .o_PF_O             (               ),
        .o_PF_OE            (               ),

        .i_ANx_DIGITAL      ( an[7:4]       ),
        .o_ANx_ANALOG_CH    ( adc_ch        ),
        .i_ANx_ANALOG_DATA  ( adc_data      ),
        .o_ANx_ANALOG_RD_n  (               )
    );

endmodule
