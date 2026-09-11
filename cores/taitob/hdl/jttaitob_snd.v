/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    Author: Andrea Bogazzi.
    Date: 5-2026 */

// ============================================================================
// jttaitob_snd — Z80 + YM2610 sound subsystem for Taito B System
// ============================================================================
//
// Topology is identical to the Taito X System (Superman) — Z80 @ 4 MHz,
// YM2610 @ 8 MHz, TC0140SYT handles the Z80 memory decode and chip
// selects. ROM bank window at 0x4000-0x7FFF, RAM at 0xC000-0xDFFF,
// YM at 0xE000-0xE0FF, SYT at 0xE200-0xE2FF, bank reg at 0xF200.
//
// Difference vs Superman:
//   • Rastan Saga 2 has ADPCM-B samples (B81-01.1, 512 KB) wired into
//     the YM2610 Delta-T port. They live in SDRAM bank 3 (`adpcmb` bus,
//     JTFRAME_BA3_START) and feed the jt10 adpcmb_data input — Superman
//     had no ADPCM-B region so it left that port at 0.
//
// Read alongside cores/superman/hdl/jtsuperman_snd.v — same shape.
// ============================================================================

module jttaitob_snd(
    input               rst,
    input               clk,                     // 48 MHz JTFRAME_CLK48
    input               cen_z80,                 // 4 MHz Z80 cen
    input               cen_ym,                  // 8 MHz YM2610 cen

    // TC0140SYT slave-side connections (chip selects emitted by SYT)
    input               snd_rom_cs,
    input        [ 1:0] snd_rom_a16,
    input               snd_ram_cs,
    input               snd_ym_cs,
    input               snd_syt_sel,
    input               snd_rst_soft,
    input               snd_nmi_n,
    input        [ 7:0] syt_dout_z80,

    // Z80 bus exposed back to SYT
    output       [15:0] z80_addr,
    output       [ 7:0] z80_dout,
    output              z80_mreq_n,
    output              z80_rd_n,
    output              z80_wr_n,

    // Z80 sound ROM (SDRAM `snd` bus, 64 KB)
    output       [15:0] rom_addr,
    output reg          rom_cs,
    input        [ 7:0] rom_data,
    input               rom_ok,

    // YM2610 ADPCM-A (SDRAM `adpcma` bus, 512 KB)
    output       [18:0] adpcma_addr,
    output              adpcma_cs,
    input        [ 7:0] adpcma_data,
    input               adpcma_ok,

    // YM2610 ADPCM-B / Delta-T (SDRAM `adpcmb` bus, 512 KB)
    output       [18:0] adpcmb_addr,
    output              adpcmb_cs,
    input        [ 7:0] adpcmb_data,
    input               adpcmb_ok,

    // Audio output
    output signed [15:0] fm_l,
    output signed [15:0] fm_r,

    input        [ 7:0] debug_bus,
    output       [ 7:0] st_dout
);

`ifndef NOSOUND

wire        z80_int_n;
wire        z80_m1_n, z80_iorq_n, z80_rfsh_n;
wire [ 7:0] z80_din;
wire        z80_cpu_cen;

wire [ 7:0] ym_dout;
wire [19:0] ym_adpcma_addr;
wire [ 3:0] ym_adpcma_bank;     // jt10's external port is 4 bits; the
                                // upstream WIDTHEXPAND warning inside
                                // jt10.v is a jt10-internal issue
                                // (same warning in Superman/etc.).
wire        ym_adpcma_roe_n;
wire [23:0] ym_adpcmb_addr;
wire        ym_adpcmb_roe_n;

wire [ 7:0] sram_dout;
wire        snd_rstn = ~rst & ~snd_rst_soft;

// ─── Z80 ROM address mapping (banked window @ 0x4000-0x7FFF) ──────────────
wire in_bank = z80_addr[15:14] == 2'b01;
assign rom_addr = in_bank
    ? {snd_rom_a16, z80_addr[13:0]}
    : {2'b00,       z80_addr[13:0]};
always @(posedge clk) rom_cs <= snd_rom_cs;

// ─── ADPCM-A address mapping ──────────────────────────────────────────────
assign adpcma_addr = ym_adpcma_addr[18:0];
assign adpcma_cs   = ~ym_adpcma_roe_n;

// ─── ADPCM-B (Delta-T) address mapping ────────────────────────────────────
assign adpcmb_addr = ym_adpcmb_addr[18:0];
assign adpcmb_cs   = ~ym_adpcmb_roe_n;

// ─── Z80 data mux ─────────────────────────────────────────────────────────
assign z80_din = snd_rom_cs  ? rom_data            :
                 snd_ram_cs  ? sram_dout           :
                 snd_ym_cs   ? ym_dout             :
                 snd_syt_sel ? syt_dout_z80        :
                 8'hFF;

// Suppress lint warning on currently-unused inputs (kept for future use).
// ym_adpcmb_addr is 24-bit; only [18:0] address the 512 KB region, so the
// top bits [23:19] are intentionally unused.
/* verilator lint_off UNUSED */
wire _unused_z80 = z80_iorq_n | z80_rfsh_n | z80_cpu_cen | adpcma_ok | adpcmb_ok |
                   |ym_adpcma_bank | |ym_adpcmb_addr[23:19] | |debug_bus;
/* verilator lint_on UNUSED */

// ─── SIM Z80 PC tracker — first-hit log at key boot landmarks ─────────────
`ifdef SIMULATION
reg [10:0] z80_pc_seen = 11'd0;
wire z80_m1_active = ~z80_m1_n & ~z80_mreq_n;
// Z80 activity counter — fires for ANY M1 fetch. If this stays 0,
// the Z80 isn't executing at all (held in reset, halted, etc.).
integer z80_m1_total = 0;
reg z80_first_logged = 1'b0;
// Log EVERY M1 fetch for the first 200 cycles after Z80 released.
// Include rom_cs / rom_ok so we can see if Z80 is stalled in WAIT
// (rom_ok never asserts → Z80 keeps re-trying same fetch).
integer z80_m1_log_count = 0;
always @(posedge clk) if (snd_rstn && z80_m1_active && z80_m1_log_count < 200) begin
    z80_m1_log_count <= z80_m1_log_count + 1;
    $display("[%0t] Z80 M1#%0d: PC=0x%h nmi_n=%b int_n=%b rom_cs=%b rom_ok=%b rom_data=0x%02x snd_rom_cs=%b",
             $time, z80_m1_log_count, z80_addr, snd_nmi_n, z80_int_n,
             rom_cs, rom_ok, rom_data, snd_rom_cs);
end
// Track snd_rstn transitions (initialized to avoid X-prop issues)
reg snd_rstn_d = 1'b0;
always @(posedge clk) begin
    snd_rstn_d <= snd_rstn;
    if (snd_rstn_d !== snd_rstn) begin
        $display("[%0t] Z80 reset_n: %b → %b (rst=%b snd_rst_soft=%b)",
                 $time, snd_rstn_d, snd_rstn, rst, snd_rst_soft);
    end
end
// Periodic state dump (every 1M clk after release)
integer rstn_print_ctr = 0;
initial $display("[INIT] jttaitob_snd debug block compiled in");
always @(posedge clk) begin
    rstn_print_ctr <= rstn_print_ctr + 1;
    if ((rstn_print_ctr & 32'h000FFFFF) == 32'h0) begin
        $display("[%0t] Z80 state @ctr=%0d: snd_rstn=%b rst=%b snd_rst_soft=%b z80_addr=0x%h",
                 $time, rstn_print_ctr, snd_rstn, rst, snd_rst_soft, z80_addr);
    end
end
always @(posedge clk) if (z80_m1_active) begin
    z80_m1_total <= z80_m1_total + 1;
    if (!z80_first_logged) begin
        $display("[%0t] Z80 FIRST M1 fetch — Z80 IS ALIVE  addr=0x%h",
                 $time, z80_addr);
        z80_first_logged <= 1'b1;
    end
end
always @(posedge clk) if (snd_rstn && z80_m1_active) begin
    case (z80_addr)
        16'h0000: if (!z80_pc_seen[ 0]) begin z80_pc_seen[ 0] <= 1; $display("[%0t] Z80 PC=0000  (boot entry: DI)",            $time); end
        16'h0001: if (!z80_pc_seen[ 1]) begin z80_pc_seen[ 1] <= 1; $display("[%0t] Z80 PC=0001  (IM 1)",                       $time); end
        16'h0003: if (!z80_pc_seen[ 2]) begin z80_pc_seen[ 2] <= 1; $display("[%0t] Z80 PC=0003  (LD A,#$05)",                  $time); end
        16'h0005: if (!z80_pc_seen[ 3]) begin z80_pc_seen[ 3] <= 1; $display("[%0t] Z80 PC=0005  (LD (E200),A — port_w #5)",   $time); end
        16'h0008: if (!z80_pc_seen[ 4]) begin z80_pc_seen[ 4] <= 1; $display("[%0t] Z80 PC=0008  (LD (E201),A — comm_w #5)",   $time); end
        16'h000B: if (!z80_pc_seen[ 5]) begin z80_pc_seen[ 5] <= 1; $display("[%0t] Z80 PC=000B  (JP $01AA)",                   $time); end
        16'h01AA: if (!z80_pc_seen[ 6]) begin z80_pc_seen[ 6] <= 1; $display("[%0t] Z80 PC=01AA  (main init)",                  $time); end
        16'h01B5: if (!z80_pc_seen[ 7]) begin z80_pc_seen[ 7] <= 1; $display("[%0t] Z80 PC=01B5  (LD SP,$E000)",                $time); end
        16'h01C4: if (!z80_pc_seen[ 8]) begin z80_pc_seen[ 8] <= 1; $display("[%0t] Z80 PC=01C4  (post-RAM-clear)",             $time); end
        16'h02D6: if (!z80_pc_seen[ 9]) begin z80_pc_seen[ 9] <= 1; $display("[%0t] Z80 PC=02D6  (NMI ENABLE point #1)",        $time); end
        16'h04CE: if (!z80_pc_seen[10]) begin z80_pc_seen[10] <= 1; $display("[%0t] Z80 PC=04CE  (NMI ENABLE point #2)",        $time); end
        default: ;
    endcase
end
`endif

// ─── jtframe_sysz80 (Z80 @ 4 MHz, internal 8 KB RAM) ──────────────────────
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
    // ADPCM-B (Delta-T) — reads b81-01.1 from SDRAM bank 3 (`adpcmb`).
    .adpcmb_addr    ( ym_adpcmb_addr    ),
    .adpcmb_roe_n   ( ym_adpcmb_roe_n   ),
    .adpcmb_data    ( adpcmb_data       ),

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

`else  // NOSOUND
assign z80_addr   = 16'h0;
assign z80_dout   = 8'h0;
assign z80_mreq_n = 1'b1;
assign z80_rd_n   = 1'b1;
assign z80_wr_n   = 1'b1;
assign rom_addr   = 16'h0;
assign adpcma_addr= 19'h0;
assign adpcma_cs  = 1'b0;
assign adpcmb_addr= 19'h0;
assign adpcmb_cs  = 1'b0;
assign fm_l       = 16'h0;
assign fm_r       = 16'h0;
assign st_dout    = 8'h0;
initial rom_cs    = 1'b0;
`endif

endmodule
