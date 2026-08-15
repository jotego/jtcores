/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Date: 5-2026 */

// ============================================================================
// jtsuperman_snd — Z80 + YM2610 sound subsystem for Taito X System
// ============================================================================
//
// Z80 @ 16/4 = 4 MHz   (jtframe_sysz80)
// YM2610 @ 16/2 = 8 MHz   (jt10)
// TC0140SYT slave port  (jtsuperman_syt, instantiated in jtsuperman_game.v —
//                        decodes Z80 memory map and emits the chip selects
//                        consumed here)
//
// Z80 memory map (per real chip + F2 reference; selects come from SYT):
//   0x0000-0x3FFF : ROM, fixed (snd_rom_cs && !in_bank)
//   0x4000-0x7FFF : ROM, banked  (snd_rom_cs && in_bank, +snd_rom_a16 hi bits)
//   0x8000-0xBFFF : unused
//   0xC000-0xDFFF : 8 KB internal RAM   (snd_ram_cs)
//   0xE000-0xE0FF : YM2610 read/write    (snd_ym_cs)
//   0xE200-0xE2FF : TC0140SYT slave port (snd_syt_sel — SYT consumes directly)
//   0xF200        : ROM-bank register   (handled inside SYT)
//
// IRQ source: Z80 INT_n is driven by YM2610's irq_n (timer flag).
// NMI source: from SYT (snd_nmi_n) when 68k posts data with NMI-enabled.
//
// ADPCM-A ROM: SDRAM `adpcma` bus from cfg/mem.yaml.
// ADPCM-B ROM: not used on Superman (zero-driven; would be on Ballbros etc.)
// ============================================================================

module jtsuperman_snd(
    input               rst,
    input               clk,                  // 48 MHz JTFRAME_CLK48
    input               cen_z80,              // 4 MHz Z80 cen
    input               cen_ym,               // 8 MHz YM2610 cen

    // ─── TC0140SYT slave-side connections ─────────────────────────────────
    // SYT decodes the Z80 address space and emits these chip selects.
    // We don't decode the address space here ourselves — the SYT owns it.
    input               snd_rom_cs,           // 0x0000-0x7FFF
    input        [ 1:0] snd_rom_a16,          // upper bits during 0x4000-0x7FFF window
    input               snd_ram_cs,           // 0xC000-0xDFFF
    input               snd_ym_cs,            // 0xE000-0xE0FF
    input               snd_syt_sel,          // 0xE200-0xE2FF (SYT consumes)
    input               snd_rst_soft,         // software reset (from SYT idx 7)
    input               snd_nmi_n,            // NMI from SYT
    input        [ 7:0] syt_dout_z80,         // SYT data response to Z80

    // ─── Z80 bus exposed back to SYT (so it can sample addr/data) ─────────
    output       [15:0] z80_addr,
    output       [ 7:0] z80_dout,
    output              z80_mreq_n,
    output              z80_rd_n,
    output              z80_wr_n,

    // ─── Z80 sound ROM (SDRAM `snd` bus, 64 KB) ───────────────────────────
    output       [15:0] rom_addr,             // byte address into 64 KB ROM
    output reg          rom_cs,
    input        [ 7:0] rom_data,
    input               rom_ok,

    // ─── YM2610 ADPCM-A (SDRAM `adpcma` bus, 512 KB) ──────────────────────
    output       [18:0] adpcma_addr,
    output              adpcma_cs,
    input        [ 7:0] adpcma_data,
    input               adpcma_ok,

    // ─── Audio output (FM stereo, fed to game.v `fm_l/fm_r` ports) ────────
    output signed [15:0] fm_l,
    output signed [15:0] fm_r,

    // ─── Debug ─────────────────────────────────────────────────────────────
    input        [ 7:0] debug_bus,
    output       [ 7:0] st_dout
);

`ifndef NOSOUND

// ─── Internal nets ───────────────────────────────────────────────────────
wire        z80_int_n;                        // YM2610 irq → Z80 INT
wire        z80_m1_n, z80_iorq_n, z80_rfsh_n;
wire [ 7:0] z80_din;
wire        z80_cpu_cen;

wire [ 7:0] ym_dout;
wire [19:0] ym_adpcma_addr;
wire [ 3:0] ym_adpcma_bank;                   // jt10 wrapper exports 4 bits
wire        ym_adpcma_roe_n;
wire [23:0] ym_adpcmb_addr;
wire        ym_adpcmb_roe_n;

// sysz80 owns the internal sound RAM (8 KB @ 0xC000-0xDFFF); we feed it
// snd_ram_cs from the TC0140SYT and get ram_dout back.
wire [ 7:0] sram_dout;

wire        snd_rstn = ~rst & ~snd_rst_soft;  // active-high rst → active-low rst_n

// ─── Z80 ROM address mapping ──────────────────────────────────────────────
// 0x0000-0x3FFF: not banked, byte addr = z80_addr[13:0] with rom_a16=2'b00
// 0x4000-0x7FFF: banked window, rom_a16 from SYT provides A14/A15
wire        in_bank = z80_addr[15:14] == 2'b01;
assign rom_addr = in_bank
    ? {snd_rom_a16, z80_addr[13:0]}
    : {2'b00,        z80_addr[13:0]};
// rom_cs from SYT directly
always @(posedge clk) rom_cs <= snd_rom_cs;

// ─── ADPCM-A address mapping (jt10 splits into bank[3:0] + addr[19:0]) ────
// We combine bank+addr into the SDRAM `adpcma` byte address (19 bits).
// jt10's full address is {bank[3:0], adpcma_addr[19:0]} = 24 bits total but
// Superman has 512 KB samples = 19 bits, so we just use adpcma_addr[18:0].
assign adpcma_addr = ym_adpcma_addr[18:0];
assign adpcma_cs   = ~ym_adpcma_roe_n;

// ─── Z80 data mux ─────────────────────────────────────────────────────────
assign z80_din = snd_rom_cs  ? rom_data            :
                 snd_ram_cs  ? sram_dout           :
                 snd_ym_cs   ? ym_dout             :
                 snd_syt_sel ? syt_dout_z80        :
                 8'hFF;

// ─── jtframe_sysz80 (Z80 @ 4 MHz) — owns the 8 KB sound RAM internally ───
//
// RAM_AW=13 = 8 KB at the Z80 region the SYT decodes as snd_ram_cs.
`ifdef SIMULATION
// Z80 PC probes — log the FIRST M1 fetch at each known MAME-trace PC so
// we can see how far our Z80 boot path gets compared to MAME's.  M1 cycle
// (m1_n=0) on Z80 marks an opcode fetch where z80_addr == PC.
reg [10:0] z80_pc_seen = 11'd0;
wire z80_m1_active = ~z80_m1_n & ~z80_mreq_n;
always @(posedge clk) if (snd_rstn && z80_m1_active) begin
    case (z80_addr)
        16'h0000: if (!z80_pc_seen[ 0]) begin z80_pc_seen[ 0] <= 1; $display("[%0t] Z80 PC=0000  (boot entry)",                 $time); end
        16'h0008: if (!z80_pc_seen[ 1]) begin z80_pc_seen[ 1] <= 1; $display("[%0t] Z80 PC=0008  (NMI-disable port_w 0x05)",    $time); end
        16'h000B: if (!z80_pc_seen[ 2]) begin z80_pc_seen[ 2] <= 1; $display("[%0t] Z80 PC=000B  (NMI-disable comm_w 0x05)",    $time); end
        16'h01AF: if (!z80_pc_seen[ 3]) begin z80_pc_seen[ 3] <= 1; $display("[%0t] Z80 PC=01AF  (set submode 0)",              $time); end
        16'h0276: if (!z80_pc_seen[ 4]) begin z80_pc_seen[ 4] <= 1; $display("[%0t] Z80 PC=0276  (ack prep — set submode 0)",   $time); end
        16'h0280: if (!z80_pc_seen[ 5]) begin z80_pc_seen[ 5] <= 1; $display("[%0t] Z80 PC=0280  (ack write 1: comm_w 0xE0)",   $time); end
        16'h0287: if (!z80_pc_seen[ 6]) begin z80_pc_seen[ 6] <= 1; $display("[%0t] Z80 PC=0287  (ack write 2: comm_w 0x0E)",   $time); end
        16'h006D: if (!z80_pc_seen[ 7]) begin z80_pc_seen[ 7] <= 1; $display("[%0t] Z80 PC=006D  (status-poll loop #1)",        $time); end
        16'h02D0: if (!z80_pc_seen[ 8]) begin z80_pc_seen[ 8] <= 1; $display("[%0t] Z80 PC=02D0  (status-poll loop #2)",        $time); end
        16'h1617: if (!z80_pc_seen[ 9]) begin z80_pc_seen[ 9] <= 1; $display("[%0t] Z80 PC=1617  (YM2610 init port_w)",         $time); end
        16'h1622: if (!z80_pc_seen[10]) begin z80_pc_seen[10] <= 1; $display("[%0t] Z80 PC=1622  (YM2610 init data_w)",         $time); end
        default: ;
    endcase
end
`endif

jtframe_sysz80 #(.RECOVERY(0), .RAM_AW(13)) u_z80(
    .rst_n      ( snd_rstn      ),
    .clk        ( clk           ),
    .cen        ( cen_z80       ),
    .cpu_cen    ( z80_cpu_cen   ),
    .int_n      ( z80_int_n     ),
    .nmi_n      ( snd_nmi_n     ),
    .busrq_n    ( 1'b1          ),
    .m1_n       ( z80_m1_n      ),
    .mreq_n     ( z80_mreq_n    ),
    .iorq_n     ( z80_iorq_n    ),
    .rd_n       ( z80_rd_n      ),
    .wr_n       ( z80_wr_n      ),
    .rfsh_n     ( z80_rfsh_n    ),
    .halt_n     (               ),
    .busak_n    (               ),
    .A          ( z80_addr      ),
    .cpu_din    ( z80_din       ),
    .cpu_dout   ( z80_dout      ),
    .ram_dout   ( sram_dout     ),
    .ram_cs     ( snd_ram_cs    ),
    .rom_cs     ( snd_rom_cs    ),
    .rom_ok     ( rom_ok        )
);

// ─── YM2610 (jt10) ────────────────────────────────────────────────────────
jt10 u_jt10(
    .rst            ( ~snd_rstn         ),
    .clk            ( clk               ),
    .cen            ( cen_ym            ),
    .din            ( z80_dout          ),
    .addr           ( z80_addr[1:0]     ),
    .cs_n           ( ~snd_ym_cs        ),
    .wr_n           ( z80_wr_n          ),

    .dout           ( ym_dout           ),
    .irq_n          ( z80_int_n         ),

    .adpcma_addr    ( ym_adpcma_addr    ),
    .adpcma_bank    ( ym_adpcma_bank    ),
    .adpcma_roe_n   ( ym_adpcma_roe_n   ),
    .adpcma_data    ( adpcma_data       ),
    .adpcmb_addr    ( ym_adpcmb_addr    ),
    .adpcmb_roe_n   ( ym_adpcmb_roe_n   ),
    .adpcmb_data    ( 8'h0              ),   // ADPCM-B unused on Superman

    .psg_A          (                   ),
    .psg_B          (                   ),
    .psg_C          (                   ),
    .fm_snd         (                   ),
    .psg_snd        (                   ),
    .snd_right      ( fm_r              ),
    .snd_left       ( fm_l              ),
    .snd_sample     (                   ),
    .ch_enable      ( 6'b111111         )
);

assign st_dout = { 6'd0, snd_ram_cs, snd_rom_cs };

`ifdef SIMULATION
// Z80 PC probe — does the Z80 actually run? Sample z80_addr periodically.
// If running, addr ticks through ROM ($0000-$3FFF unbanked or $4000-$7FFF
// banked).  If stuck (HALT or tight wait), addr stays constant.  Also
// track min/max so we see the address range the Z80 visits.
integer z80_inst_count = 0;
integer z80_inst_prev  = 0;
integer ym_wr_count    = 0;
integer ym_rd_count    = 0;
integer ram_wr_count   = 0;
reg [15:0] z80_addr_min = 16'hFFFF;
reg [15:0] z80_addr_max = 16'h0000;
reg z80_m1_n_q;
reg z80_ym_q;
reg z80_ym_wr_q, z80_ym_rd_q, z80_ram_wr_q;
always @(posedge clk) begin
    z80_ym_wr_q  <= snd_ym_cs & ~z80_wr_n;
    z80_ym_rd_q  <= snd_ym_cs & ~z80_rd_n;
    z80_ram_wr_q <= snd_ram_cs & ~z80_wr_n;
    if ((snd_ym_cs & ~z80_wr_n) & ~z80_ym_wr_q) begin
        ym_wr_count = ym_wr_count + 1;
        if (ym_wr_count <= 16 || (ym_wr_count % 100) == 0)
            $display("[%0t] YM WR  reg=%02x  data=%02x  (#%0d)",
                     $time, {6'd0, z80_addr[1:0]}, z80_dout, ym_wr_count);
    end
    if ((snd_ym_cs & ~z80_rd_n) & ~z80_ym_rd_q) begin
        ym_rd_count = ym_rd_count + 1;
    end
    if ((snd_ram_cs & ~z80_wr_n) & ~z80_ram_wr_q) begin
        ram_wr_count = ram_wr_count + 1;
    end
end
always @(posedge clk) begin
    if (cen_z80) begin
        z80_m1_n_q <= z80_m1_n;
        // M1 falling edge = start of opcode fetch
        if (z80_m1_n_q & ~z80_m1_n) begin
            z80_inst_count = z80_inst_count + 1;
            if (z80_addr < z80_addr_min) z80_addr_min <= z80_addr;
            if (z80_addr > z80_addr_max) z80_addr_max <= z80_addr;
            if (z80_inst_count <= 16 ||
                (z80_inst_count <= 1024 && (z80_inst_count % 64) == 0) ||
                (z80_inst_count % 100000) == 0) begin
                $display("[%0t] Z80 inst #%0d  PC=%04x  (min=%04x max=%04x  rst_n=%b nmi_n=%b)",
                         $time, z80_inst_count, z80_addr,
                         z80_addr_min, z80_addr_max,
                         snd_rstn, snd_nmi_n);
            end
        end
    end
end
`endif

`else  // NOSOUND — keep ports stable, drive silent

assign z80_addr   = 16'd0;
assign z80_dout   = 8'd0;
assign z80_mreq_n = 1'b1;
assign z80_rd_n   = 1'b1;
assign z80_wr_n   = 1'b1;
assign rom_addr   = 16'd0;
assign adpcma_addr= 19'd0;
assign adpcma_cs  = 1'b0;
assign fm_l       = 16'sd0;
assign fm_r       = 16'sd0;
assign st_dout    = 8'h0;
initial rom_cs    = 1'b0;

`endif
endmodule
