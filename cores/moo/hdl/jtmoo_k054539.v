/* SPDX-FileCopyrightText: 2026 meathax
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Author: meathax
 * Date: 6-9-2026 */

// Moo Mesa K054539: {A9,A7:0} registers, YM2151 AUX input, and 32 KiB reverb RAM.
// Board straps and source notes: doc/moo-hardware-notes.md.

module jtmoo_k054539 #(parameter
    VOLSHIFT = 0,                   // aux (YM2151) attenuation, in right shifts
    VOLTAB   = "voltab.hex",
    PANTAB   = "pantab.hex",
    REVTAB   = "rram_zero.hex"
)(
    input               rst,
    input               clk,
    input               cen,     // 18.432 MHz. 384 cen = one 48 kHz sample
    output              timeout, // TIM pin, NC on Moo
    // CPU interface. addr = {A[9],A[7:0]}; the chip has no A8 pin
    input      [ 8:0]   addr,
    input               we,
    input               rd,
    input               cs,
    input      [ 7:0]   din,
    output     [ 7:0]   dout,
    output reg          busy,    // holds the sound CPU during a data-port read
    // PCM ROM
    output              rom_cs,
    output     [23:0]   rom_addr,
    input      [ 7:0]   rom_data,
    input               rom_ok,
    // YM2151 serial DAC stream, mixed in by the chip
    input signed [15:0] aux_l,
    input signed [15:0] aux_r,
    // Sound output
    output signed [15:0] left,
    output signed [15:0] right,
    // debug
    input      [ 7:0]   debug_bus,
    output     [ 7:0]   st_dout
);

// Board address {A9,A7:0}: MAME 0x2xx maps to 0x1xx; MAME 0x1xx is inaccessible.
// CPU and sequencer share one register-write process.
reg  [7:0] regs [0:511];
reg  [7:0] active;
reg  [7:0] rr_cpu_data;
reg  [7:0] rb_data;
// UPDATE_AT_KEYON position writes, held outside the visible register file
reg  [7:0] pos_latch [0:23];
// The chip commits a CPU write when the write strobe is released; the Z80 holds
// one transaction across several 48 MHz clocks, so emit exactly one commit
reg        cpu_write_pending;
reg  [8:0] cpu_write_addr;
reg  [7:0] cpu_write_data;
wire       cpu_write_active = cs && we;
wire       cpu_write_commit = cpu_write_pending && !cpu_write_active;
integer    gi;
initial for (gi=0; gi<512; gi=gi+1) regs[gi] = 8'd0;

wire update_at_keyon = regs[9'h12f][0];   // MAME `latch`: UPDATE_AT_KEYON && PCM enable
wire reg_updates     = ~regs[9'h12f][7];
wire [7:0] keyon_retrigger = (cpu_write_commit &&
                              (cpu_write_addr == 9'h114) && reg_updates) ?
                              cpu_write_data : 8'h00;

assign dout    = (addr == 9'h12c) ? active :
                 (addr == 9'h12d) ? ((rd && regs[9'h12f][4]) ?
                                      (regs[9'h12e] == 8'h80 ? rr_cpu_data : rb_data) : 8'h00) :
                 regs[addr];

// 0x227 timer: MAME k054539.cpp:426 gives a toggle every 7200/(38+data) sample
// ticks. Free running once armed; the output moves only while 0x22f b5 is set
reg  [12:0] timer_cnt;
reg         timer_state;
reg         timer_armed;
wire [12:0] timer_add   = 13'd38 + {5'b0, regs[9'h127]};
localparam  [12:0] TIMER_THRESH = 13'd7200;
wire [13:0] timer_sum   = {1'b0, timer_cnt} + {1'b0, timer_add};

wire [8:0] b1 = {1'b0, ch, 5'b0};
wire [8:0] b2 = 9'h100 + {5'b0, ch, 1'b0};
assign timeout = timer_state;

// Q16 volume/pan tables, MAME k054539.cpp:531-539 rounded to nearest.
// Bare file names follow the jtframe convention (cf. log2.hex)
reg [15:0] voltab [0:255];   // <= 0x4000
reg [16:0] pantab [0:15];    // <= 0x10000
initial begin
    $readmemh(VOLTAB, voltab);
    $readmemh(PANTAB, pantab);
end

// Per channel state, in BYTE units between samples
reg [23:0] cpos   [0:7];
reg [15:0] cpfrac [0:7];
reg signed [15:0] cval  [0:7];

reg  [7:0] restart;   // key-on edge restart

localparam [3:0]
    S_IDLE = 4'd0, S_LOAD = 4'd1, S_ACC = 4'd2,
    S_R8   = 4'd3, S_R16L = 4'd4, S_R16H = 4'd5, S_RD = 4'd6,
    S_MIX  = 4'd7, S_NEXT = 4'd8, S_DONE = 4'd9,
    S_REVRD= 4'd10, S_RVWR = 4'd11;   // reverb: read feedback @revpos, RMW @widx

reg [3:0]  state;
reg [8:0]  sample_cnt;
reg [2:0]  ch;

// current channel working registers
reg [24:0] w_pos;              // 25b: DPCM works in NIBBLE units (pos<<1)
reg signed [31:0] w_pfrac;
reg signed [15:0] w_val;
reg [23:0] w_loop;
reg [7:0]  w_lo;              // low byte of a 16 bit sample
reg [7:0]  w_vol;
reg [3:0]  w_pan;
reg [1:0]  w_type;            // 0=8bit, 1=16bit(0x4), 2=DPCM(0x8), 3=no-op(0xc)
reg        w_loopen;
reg        w_reverse;
// MAME retries a terminator at the loop point only once and then keys off
// (k054539.cpp:206-214); without this flag a loop point holding a terminator
// would spin the sequencer forever
reg        w_looped;

// Playback ROM request, arbitrated with the data-port readback below
reg         sample_rom_cs;
reg  [23:0] sample_rom_addr;

reg         rb_pending, rb_active, rb_read_seen, rb_data_valid;
reg         rr_cpu_read_seen, rr_cpu_data_valid;
reg  [23:0] rb_addr_l;
reg  [14:0] rr_cpu_addr_l;
wire        rb_rom_bank = regs[9'h12e] != 8'h80;
wire        rb_cpu_read = cs && rd && (addr == 9'h12d) && regs[9'h12f][4] && rb_rom_bank;
wire        rr_cpu_read = cs && rd && (addr == 9'h12d) &&
                          (regs[9'h12e] == 8'h80) && regs[9'h12f][4];

assign rom_cs   = sample_rom_cs | rb_active;
assign rom_addr = rb_active ? rb_addr_l : sample_rom_addr;

// The PCB leaves WAIT unconnected. Shared SDRAM requires an emulated readback
// wait; busy gates the Z80 clock enable.
wire        rb_wait  = rb_pending | rb_active |
                       (rb_cpu_read && !rb_data_valid) |
                       (rr_cpu_read && !rr_cpu_data_valid);

// Q16 accumulators, as MAME: sum at full precision and shift >>16 once
reg signed [39:0] accL, accR;

// Read and clear feedback, then accumulate each channel into the delay line.
// Audio uses 8,192 int16 samples; the CPU sees 32 KiB, banked by pointer bit 16.
// Use $readmemh: an 8,192-iteration init loop exceeds the Quartus unroll limit.
reg  [16:0] read_ptr;             // 0x22d pointer, wraps at 0x1ffff
reg  [12:0] reverb_pos;
reg  [12:0] rr_addr;              // write address: clear @revpos, RMW @widx
reg         rr_we;
reg  signed [15:0] rr_din;
wire [14:0] rr_port_addr = {read_ptr[16], read_ptr[13:0]};
wire [12:0] rd_addr;

// Two 16 KiB dual-port RAM banks; the CPU uses port 0.
// Audio uses port 1 of the lower bank.
wire        rr_cpu_write = cpu_write_commit && (cpu_write_addr == 9'h12d) &&
                            (regs[9'h12e] == 8'h80);
wire [1:0]  rr_cpu_we = rr_cpu_write ?
                        (rr_port_addr[0] ? 2'b10 : 2'b01) : 2'b00;
wire [15:0] rr_cpu_din = rr_port_addr[0] ? {cpu_write_data,8'h00} :
                                           {8'h00,cpu_write_data};
wire [15:0] rr_lo_cpu_q, rr_hi_cpu_q, rr_audio_q;
// The upper CPU visible bank has no audio port consumer
/* verilator lint_off UNUSEDSIGNAL */
wire [15:0] rr_hi_audio_q;
/* verilator lint_on UNUSEDSIGNAL */
wire [12:0] rr_cpu_word_addr = rr_cpu_read_seen ? rr_cpu_addr_l[13:1] :
                                                  rr_port_addr[13:1];
wire [15:0] rr_cpu_q = rr_cpu_addr_l[14] ? rr_hi_cpu_q : rr_lo_cpu_q;
wire signed [15:0] rr_dout = rr_audio_q;

jtframe_dual_ram16 #(
    .AW           ( 13     ),
    .SIMHEXFILE_LO( REVTAB ),
    .SIMHEXFILE_HI( REVTAB ),
    .SYNFILE_LO   ( REVTAB ),
    .SYNFILE_HI   ( REVTAB )
) u_rram_lo (
    .clk0  ( clk           ),
    .data0 ( rr_cpu_din    ),
    .addr0 ( rr_cpu_word_addr ),
    .we0   ( rr_port_addr[14] ? 2'b00 : rr_cpu_we ),
    .q0    ( rr_lo_cpu_q   ),
    .clk1  ( clk           ),
    .data1 ( rr_din        ),
    .addr1 ( rr_we ? rr_addr : rd_addr ),
    .we1   ( rr_we ? 2'b11 : 2'b00 ),
    .q1    ( rr_audio_q    )
);

jtframe_dual_ram16 #(
    .AW           ( 13     ),
    .SIMHEXFILE_LO( REVTAB ),
    .SIMHEXFILE_HI( REVTAB ),
    .SYNFILE_LO   ( REVTAB ),
    .SYNFILE_HI   ( REVTAB )
) u_rram_hi (
    .clk0  ( clk           ),
    .data0 ( rr_cpu_din    ),
    .addr0 ( rr_cpu_word_addr ),
    .we0   ( rr_port_addr[14] ? rr_cpu_we : 2'b00 ),
    .q0    ( rr_hi_cpu_q   ),
    .clk1  ( clk           ),
    .data1 ( 16'h0000      ),
    .addr1 ( 13'd0         ),
    .we1   ( 2'b00         ),
    .q1    ( rr_hi_audio_q )
);

wire [7:0] rram_port_dout = rr_cpu_addr_l[0] ?
                              rr_cpu_q[15:8] :
                              rr_cpu_q[7:0];

// current channel L/R volume, Q16. VOL_CAP=1.8, MAME k054539.cpp:109,158-164
wire [16:0] vt   = {1'b0, voltab[w_vol]};
wire [16:0] pl   = pantab[w_pan];
wire [16:0] pr   = pantab[4'd14 - w_pan];
wire [33:0] lfull= vt * pl;
wire [33:0] rfull= vt * pr;
/* verilator lint_off UNUSEDSIGNAL */
wire [16:0] lfull_discarded_diag = {lfull[33], lfull[15:0]};
wire [16:0] rfull_discarded_diag = {rfull[33], rfull[15:0]};
/* verilator lint_on UNUSEDSIGNAL */
wire [16:0] lvol = lful_clamp(lfull[32:16]);
wire [16:0] rvol = lful_clamp(rfull[32:16]);
function [16:0] lful_clamp(input [16:0] v);
    lful_clamp = (v > 17'h1CCCC) ? 17'h1CCCC : v;
endfunction

// channel contribution in Q16, rounded once at S_DONE
wire signed [33:0] cprodL = $signed(w_val) * $signed({1'b0, lvol});
wire signed [33:0] cprodR = $signed(w_val) * $signed({1'b0, rvol});
wire signed [39:0] contribL = {{6{cprodL[33]}}, cprodL};
wire signed [39:0] contribR = {{6{cprodR[33]}}, cprodR};

// Reverb parameters of the current channel. MAME k054539.cpp:170-171,289 adds
// reverb_pos twice on the way to widx; that is reproduced deliberately
wire [15:0] rdelta_word = {regs[b1+9'd7], regs[b1+9'd6]};
/* verilator lint_off UNUSEDSIGNAL */
wire [2:0]  rdelta_discarded_diag = rdelta_word[2:0];
/* verilator lint_on UNUSEDSIGNAL */
wire [12:0] rrd  = rdelta_word[15:3];                            // 16b >>3 = 13b
wire [13:0] rd14 = ({1'b0,rrd} + {1'b0,reverb_pos}) & 14'h3fff;
wire [14:0] wsum = {1'b0,rd14} + {2'b0,reverb_pos};
/* verilator lint_off UNUSEDSIGNAL */
wire [1:0]  wsum_discarded_diag = wsum[14:13];
/* verilator lint_on UNUSEDSIGNAL */
wire [12:0] widx = wsum[12:0];                                    // &0x1fff
assign rd_addr = ((state == S_MIX) || (state == S_RVWR)) ?
                 widx : reverb_pos;
wire [8:0]  bsum = {1'b0,w_vol} + {1'b0, regs[b1+9'd4]};
wire [7:0]  bval = bsum[8] ? 8'd255 : bsum[7:0];                  // clamp 255
wire [15:0] rbvol = {1'b0, voltab[bval][15:1]};                   // voltab/2
wire signed [32:0] rprod = $signed(w_val) * $signed({1'b0, rbvol});
/* verilator lint_off UNUSEDSIGNAL */
wire [16:0] rprod_discarded_diag = {rprod[32], rprod[15:0]};
/* verilator lint_on UNUSEDSIGNAL */
wire signed [15:0] rev_contrib = rprod[31:16];                    // (>>16) to int16

// channel base addresses
wire [23:0] delta_now = {regs[b1+9'd2], regs[b1+9'd1], regs[b1+9'd0]};
wire signed [31:0] delta_signed = regs[b2][5] ?
                                   -$signed({8'b0,delta_now}) :
                                    $signed({8'b0,delta_now});
// MAME k054539.cpp:197 switches on base2[0]&0xc; 0xc falls to the default at
// :283, which reads no ROM and advances nothing, so type 2'd3 idles the channel
wire [1:0]  type_now  = (regs[b2] & 8'h0c)==8'h00 ? 2'd0 :
                        (regs[b2] & 8'h0c)==8'h04 ? 2'd1 :
                        (regs[b2] & 8'h0c)==8'h08 ? 2'd2 : 2'd3;

// UPDATE_AT_KEYON latch index 3*ch + (addr[4:0]-0x0c); addr[4:2] is 3'b011 in
// that window, so the offset is just addr[1:0]
wire [4:0] pl_idx = {2'b0,addr[7:5]} + {1'b0,addr[7:5],1'b0} + {3'b0,addr[1:0]};

// DPCM step table (x0x100), MAME k054539.cpp:111-114
function signed [15:0] dpcm_step(input [3:0] n);
    case (n)
        4'd0:  dpcm_step =  16'sd0;      4'd1:  dpcm_step =  16'sd256;
        4'd2:  dpcm_step =  16'sd512;    4'd3:  dpcm_step =  16'sd1024;
        4'd4:  dpcm_step =  16'sd2048;   4'd5:  dpcm_step =  16'sd4096;
        4'd6:  dpcm_step =  16'sd8192;   4'd7:  dpcm_step =  16'sd16384;
        4'd8:  dpcm_step =  16'sd0;      4'd9:  dpcm_step = -16'sd16384;
        4'd10: dpcm_step = -16'sd8192;   4'd11: dpcm_step = -16'sd4096;
        4'd12: dpcm_step = -16'sd2048;   4'd13: dpcm_step = -16'sd1024;
        4'd14: dpcm_step = -16'sd512;    4'd15: dpcm_step = -16'sd256;
    endcase
endfunction

// clamp to int16
function signed [15:0] clip16(input signed [23:0] v);
    clip16 = (v >  24'sd32767) ? 16'sd32767 :
             (v < -24'sd32768) ? -16'sd32768 : v[15:0];
endfunction
function [3:0] pan_idx(input [7:0] p);
    if      (p >= 8'h81 && p <= 8'h8f) pan_idx = p[3:0] - 4'd1;
    else if (p >= 8'h11 && p <= 8'h1f) pan_idx = p[3:0] - 4'd1;
    else                               pan_idx = 4'd7;
endfunction

// current DPCM nibble, by position parity (nibble units)
wire [3:0] dnib = w_pos[0] ? rom_data[7:4] : rom_data[3:0];
wire signed [15:0] ds = dpcm_step(dnib);

// position advance, in w_pos units
wire [24:0] npos1 = w_reverse ? w_pos - 25'd1 : w_pos + 25'd1;
wire [24:0] npos2 = w_reverse ? w_pos - 25'd2 : w_pos + 25'd2;

// Output. The board mixes the YM2151 aux stream inside this chip (see header);
// VOLSHIFT attenuates the aux leg only
reg signed [15:0] pcm_l, pcm_r;
wire signed [15:0] aux_l_att = aux_l >>> VOLSHIFT;
wire signed [15:0] aux_r_att = aux_r >>> VOLSHIFT;
wire signed [16:0] sum_l = {pcm_l[15],pcm_l} + {aux_l_att[15],aux_l_att};
wire signed [16:0] sum_r = {pcm_r[15],pcm_r} + {aux_r_att[15],aux_r_att};

function signed [15:0] sat17(input signed [16:0] v);
    sat17 = (v >  17'sd32767) ?  16'sd32767 :
            (v < -17'sd32768) ? -16'sd32768 : v[15:0];
endfunction

assign left    = sat17(sum_l);
assign right   = sat17(sum_r);
assign st_dout = debug_bus[0] ? {4'd0, state} : active;

integer ci;
always @(posedge clk) begin
    if (rst) begin
        state <= S_IDLE; sample_cnt <= 0; ch <= 0;
        sample_rom_cs <= 0; sample_rom_addr <= 0;
        pcm_l <= 0; pcm_r <= 0; accL <= 0; accR <= 0;
        busy <= 1'b0;
        active <= 0; restart <= 0;
        w_looped <= 1'b0;
        // MAME device_reset clears 0x22c (=active) and 0x22f only
        regs[9'h12f] <= 8'd0;
        cpu_write_pending <= 1'b0;
        cpu_write_addr <= 9'd0;
        cpu_write_data <= 8'd0;
        read_ptr <= 0;
        rb_pending <= 1'b0;
        rb_active <= 1'b0;
        rb_read_seen <= 1'b0;
        rb_data_valid <= 1'b0;
        rr_cpu_read_seen <= 1'b0;
        rr_cpu_data_valid <= 1'b0;
        rr_cpu_data <= 8'd0;
        rr_cpu_addr_l <= 15'd0;
        rb_addr_l <= 24'd0;
        rb_data <= 8'd0;
        reverb_pos <= 0; rr_we <= 0; rr_addr <= 0; rr_din <= 0;
        timer_cnt <= 13'd0; timer_state <= 1'b0; timer_armed <= 1'b0;
        for (ci=0; ci<8; ci=ci+1) begin
            cpos[ci] <= 0; cpfrac[ci] <= 0; cval[ci] <= 0;
        end
        for (ci=0; ci<24; ci=ci+1) pos_latch[ci] <= 0;
    end else begin
        busy <= rb_wait;
        if (cpu_write_active) begin
            cpu_write_pending <= 1'b1;
            cpu_write_addr <= addr;
            cpu_write_data <= din;
        end else begin
            cpu_write_pending <= 1'b0;
        end

        // ROM bank data port reads are serialized behind the playback sequencer
        if (!rb_cpu_read) begin
            rb_read_seen <= 1'b0;
            rb_data_valid <= 1'b0;
            if (rb_pending && !rb_active)
                rb_pending <= 1'b0;
        end else if (!rb_read_seen) begin
            rb_read_seen <= 1'b1;
            if (!rb_pending && !rb_active) begin
                // Capture the byte address at the start of the transaction: the
                // pointer increments on this same edge below
                rb_pending <= 1'b1;
                rb_addr_l  <= {regs[9'h12e][6:0], read_ptr};
            end
        end

        // The dual port RAM presents the reverb byte one clock after the read
        // starts; hold the Z80 until it is valid
        if (!rr_cpu_read) begin
            rr_cpu_read_seen <= 1'b0;
            rr_cpu_data_valid <= 1'b0;
        end else if (!rr_cpu_read_seen) begin
            rr_cpu_read_seen <= 1'b1;
            rr_cpu_data_valid <= 1'b0;
            rr_cpu_addr_l <= rr_port_addr;
        end else begin
            rr_cpu_data <= rram_port_dout;
            rr_cpu_data_valid <= 1'b1;
        end
        // Use only idle slack: the 48 kHz stream must not stop for a data port
        if (rb_pending && !rb_active && (state == S_IDLE) &&
            (sample_cnt != 9'd0) && (sample_cnt < 9'd320)) begin
            rb_pending <= 1'b0;
            rb_active  <= 1'b1;
        end
        if (rb_active && rom_ok) begin
            rb_data       <= rom_data;
            rb_active     <= 1'b0;
            rb_data_valid <= 1'b1;
        end

        // Register storage is transparent while the write strobe is low.
        // Position bytes divert to the UPDATE_AT_KEYON latches
        if (cpu_write_active) begin
            if (addr == 9'h12f) begin
                regs[9'h12f][7] <= din[7];   // D7 transparent; D0/1/4/5 commit below
            end else if (update_at_keyon && !addr[8] &&
                         (addr[4:0] >= 5'h0c) && (addr[4:0] <= 5'h0e)) begin
                pos_latch[pl_idx] <= din;
            end else if (addr[8] && (addr[7:4] == 4'h0) && addr[0]) begin
                // Odd channel control D0 is release latched
                regs[addr] <= {din[7:1], regs[addr][0]};
            end else begin
                regs[addr] <= din;
            end
        end

        // The decapped start/stop block captures key-on at nKONWR release
        if (cpu_write_commit) begin
            case (cpu_write_addr)
                9'h114: begin
                    if (reg_updates) begin
                        active  <= active | cpu_write_data;
                        // Key-on restarts every selected voice, including an active voice.
                        restart <= restart | cpu_write_data;
                    end
                    if (update_at_keyon) begin
                        for (ci=0; ci<8; ci=ci+1) begin
                            if (cpu_write_data[ci]) begin
                                regs[(ci*32)+32'd12] <= pos_latch[(ci*3)+0];
                                regs[(ci*32)+32'd13] <= pos_latch[(ci*3)+1];
                                regs[(ci*32)+32'd14] <= pos_latch[(ci*3)+2];
                            end
                        end
                    end
                end
                // SiliconRE captures 0x22f D0/D1/D4/D5 on the write strobe
                // rising edge; D7 is transparent above, D2/D3/D6 unimplemented
                9'h12f: begin
                    regs[9'h12f][0] <= cpu_write_data[0];
                    regs[9'h12f][1] <= cpu_write_data[1];
                    regs[9'h12f][4] <= cpu_write_data[4];
                    regs[9'h12f][5] <= cpu_write_data[5];
                    // k054539.cpp:449-454: clearing bit 5 forces the output low
                    if (!cpu_write_data[5]) timer_state <= 1'b0;
                end
                // k054539.cpp:424-432: any 0x227 write reprograms and restarts
                9'h127: begin
                    timer_cnt   <= 13'd0;
                    timer_state <= 1'b0;
                    timer_armed <= 1'b1;
                end
                default: begin
                    if (cpu_write_addr[8] &&
                        (cpu_write_addr[7:4] == 4'h0) && cpu_write_addr[0])
                        regs[cpu_write_addr][0] <= cpu_write_data[0];
                end
            endcase
        end
        // Key-off is level visible for the whole write strobe in the decapped
        // start/stop block; release must not apply it twice
        if (cpu_write_active) begin
            case (addr)
                9'h115: if (reg_updates) active <= active & ~din;
                9'h12c: if (reg_updates) active <= din;
                default: ;
            endcase
        end

        // 0x22d advances the serial pointer on reads and writes; 0x22e selects
        // a bank and resets it
        if (cpu_write_commit && (cpu_write_addr == 9'h12d))
            read_ptr <= read_ptr + 17'd1;
        else if ((rb_cpu_read && !rb_read_seen) ||
                 (rr_cpu_read && !rr_cpu_read_seen))
            read_ptr <= read_ptr + 17'd1;
        else if (cpu_write_active && (addr == 9'h12e))
            read_ptr <= 17'd0;

        if (cen) begin
            sample_cnt <= (sample_cnt == 9'd383) ? 9'd0 : sample_cnt + 9'd1;
            // Hold the SDRAM request until rom_ok, including clocks without cen.
            sample_rom_cs <= (state==S_R8 || state==S_R16L ||
                              state==S_R16H || state==S_RD) && !rom_ok;
            rr_we  <= 1'b0;   // no reverb write by default

            // Timer divider, one step per audio sample tick
            if (timer_armed && (sample_cnt == 9'd0)) begin
                if (timer_sum >= {1'b0, TIMER_THRESH}) begin
                    timer_cnt <= timer_sum[12:0] - TIMER_THRESH;
                    if (regs[9'h12f][5]) timer_state <= ~timer_state;
                end else begin
                    timer_cnt <= timer_sum[12:0];
                end
            end

            case (state)
            S_IDLE: if ((sample_cnt == 9'd0) && !rb_active) begin
                        ch <= 0;
                        if (regs[9'h12f][0]) begin
                            state <= S_REVRD;
                        end else begin
                            accL <= 0; accR <= 0; state <= S_LOAD;   // chip off: no reverb
                        end
                    end

            // reverb: feedback @reverb_pos seeds accL/accR and the slot clears
            S_REVRD: begin
                accL <= { {8{rr_dout[15]}}, rr_dout, 16'b0 };   // rbase[revpos]<<16
                accR <= { {8{rr_dout[15]}}, rr_dout, 16'b0 };
                rr_addr <= reverb_pos; rr_din <= 16'sd0; rr_we <= 1'b1;
                state <= S_LOAD;
            end

            S_LOAD: begin
                if (!active[ch] || !regs[9'h12f][0]) begin
                    state <= S_NEXT;
                end else begin
                    w_vol    <=  regs[b1+9'd3];
                    w_loop   <= {regs[b1+9'ha], regs[b1+9'h9], regs[b1+9'h8]};
                    w_loopen <=  regs[b2+9'd1][0];
                    w_pan    <=  pan_idx(regs[b1+9'd5]);
                    w_type   <=  type_now;
                    w_reverse<=  regs[b2][5];
                    // pos/frac base in byte units; DPCM is scaled to nibbles
                    if (type_now == 2'd2) begin
                        if (restart[ch]) begin
                            w_pos   <= {regs[b1+9'he], regs[b1+9'hd], regs[b1+9'hc]} << 1;
                            w_pfrac <= delta_signed;                     // (0<<1)=0, +/-delta
                            w_val   <= 0;
                            // do not lose a same-clock CPU retrigger
                            restart[ch] <= keyon_retrigger[ch];
                        end else begin
                            // frac<<1; bit16 -> pos|1, frac&0xffff; then +delta
                            w_pos   <= ({cpos[ch],1'b0}) | (cpfrac[ch][15] ? 25'd1 : 25'd0);
                            w_pfrac <= $signed({15'b0, cpfrac[ch], 1'b0}) + delta_signed
                                       - (cpfrac[ch][15] ? 32'h0001_0000 : 32'd0);
                            w_val   <= cval[ch];
                        end
                    end else begin
                        if (restart[ch]) begin
                            w_pos   <= {1'b0, regs[b1+9'he], regs[b1+9'hd], regs[b1+9'hc]};
                            w_pfrac <= delta_signed;
                            w_val   <= 0;
                            restart[ch] <= keyon_retrigger[ch];
                        end else if (type_now == 2'd3) begin
                            // MAME default branch: cur_pfrac+=delta never runs
                            w_pos   <= {1'b0, cpos[ch]};
                            w_pfrac <= $signed({16'b0, cpfrac[ch]});
                            w_val   <= cval[ch];
                        end else begin
                            w_pos   <= {1'b0, cpos[ch]};
                            w_pfrac <= $signed({16'b0, cpfrac[ch]}) + delta_signed;
                            w_val   <= cval[ch];
                        end
                    end
                    state <= (type_now == 2'd3) ? S_MIX : S_ACC;
                end
            end

            // while(cur_pfrac & ~0xffff): advance and read
            S_ACC: begin
                if (|w_pfrac[31:16]) begin
                    // forward subtracts a whole fraction, reverse adds it back:
                    // MAME's fdelta/pdelta pair
                    w_pfrac <= w_pfrac +
                               (w_reverse ? 32'sh0001_0000 : -32'sh0001_0000);
                    w_looped <= 1'b0;   // one loop retry per iteration
                    case (w_type)
                    2'd0: begin // 8 bit: +1 byte
                        w_pos    <= npos1;
                        sample_rom_addr <= npos1[23:0];
                        sample_rom_cs   <= 1'b1; state <= S_R8;
                    end
                    2'd1: begin // 16 bit: +2 bytes (low then high)
                        w_pos    <= npos2;
                        sample_rom_addr <= npos2[23:0];
                        sample_rom_cs   <= 1'b1; state <= S_R16L;
                    end
                    default: begin // DPCM: +1 nibble; read byte pos>>1
                        w_pos    <= npos1;
                        sample_rom_addr <= npos1[24:1];
                        sample_rom_cs   <= 1'b1; state <= S_RD;
                    end
                    endcase
                end else begin
                    state <= S_MIX;
                end
            end

            // 8 bit capture, waits for rom_ok
            S_R8: if (rom_ok) begin
                if (rom_data == 8'h80) begin
                    if (w_loopen && !w_looped) begin
                        w_looped <= 1'b1;
                        w_pos <= {1'b0, w_loop};
                        sample_rom_addr <= w_loop;
                        sample_rom_cs <= 1'b1;
                        state <= S_R8;
                    end else begin
                        // A retiring sample must not clear a queued or simultaneous retrigger.
                        if (reg_updates && !restart[ch] && !keyon_retrigger[ch]) active[ch] <= 1'b0;
                        w_val <= 16'sd0; state <= S_MIX;
                    end
                end else begin
                    w_val <= $signed({rom_data, 8'h00}); state <= S_ACC;
                end
            end

            // 16 bit capture, low byte then high, rom_ok on each
            S_R16L: if (rom_ok) begin
                w_lo     <= rom_data;
                sample_rom_addr <= w_pos[23:0] + 24'd1;   // high byte
                sample_rom_cs   <= 1'b1; state <= S_R16H;
            end
            S_R16H: if (rom_ok) begin
                if ({rom_data, w_lo} == 16'h8000) begin
                    if (w_loopen && !w_looped) begin
                        w_looped <= 1'b1;
                        w_pos <= {1'b0, w_loop};
                        sample_rom_addr <= w_loop;
                        sample_rom_cs <= 1'b1;
                        state <= S_R16L;
                    end else begin
                        if (reg_updates && !restart[ch] && !keyon_retrigger[ch]) active[ch] <= 1'b0;
                        w_val <= 16'sd0; state <= S_MIX;
                    end
                end else begin
                    w_val <= $signed({rom_data, w_lo}); state <= S_ACC;
                end
            end

            // DPCM capture, waits for rom_ok
            S_RD: if (rom_ok) begin
                if (rom_data == 8'h88) begin
                    if (w_loopen && !w_looped) begin
                        w_looped <= 1'b1;
                        w_pos <= {w_loop, 1'b0};
                        sample_rom_addr <= w_loop;
                        sample_rom_cs <= 1'b1;
                        state <= S_RD;
                    end else begin
                        if (reg_updates && !restart[ch] && !keyon_retrigger[ch]) active[ch] <= 1'b0;
                        w_val <= 16'sd0; state <= S_MIX;
                    end
                end else begin
                    w_val  <= clip16( {{8{w_val[15]}}, w_val} + {{8{ds[15]}}, ds} );
                    state  <= S_ACC;
                end
            end

            // mix and writeback; DPCM is scaled back down
            S_MIX: begin
                accL <= accL + contribL;
                accR <= accR + contribR;
                if (w_type == 2'd2) begin
                    cpos[ch]   <= w_pos[24:1];                             // pos>>1
                    cpfrac[ch] <= w_pfrac[16:1] | (w_pos[0] ? 16'h8000 : 16'h0000);
                end else begin
                    cpos[ch]   <= w_pos[23:0];
                    cpfrac[ch] <= w_pfrac[15:0];
                end
                // Mirror live position unless a queued or simultaneous key-on owns the start address.
                if (reg_updates && !restart[ch] && !keyon_retrigger[ch]) begin
                    regs[b1+9'h0c] <= (w_type == 2'd2) ? w_pos[8:1]  : w_pos[7:0];
                    regs[b1+9'h0d] <= (w_type == 2'd2) ? w_pos[16:9] : w_pos[15:8];
                    regs[b1+9'h0e] <= (w_type == 2'd2) ? w_pos[24:17] : w_pos[23:16];
                end
                cval[ch]  <= w_val;
                state <= S_RVWR;        // rd_addr=widx issued here, ready in S_RVWR
            end

            // reverb RMW: rram[widx] += rev_contrib (int16, wraps)
            S_RVWR: begin
                rr_addr <= widx;                   // ch not yet advanced
                rr_din  <= rr_dout + rev_contrib;  // rr_dout = old rram[widx]
                rr_we   <= 1'b1;                   // commits during S_NEXT
                state   <= S_NEXT;
            end

            S_NEXT: begin
                if (ch == 3'd7) state <= S_DONE;
                else begin ch <= ch + 3'd1; state <= S_LOAD; end
            end

            S_DONE: begin  // Q16 -> integer (>>16) and clamp, as MAME
                pcm_l <= clip16($signed(accL[39:16]));
                pcm_r <= clip16($signed(accR[39:16]));
                if (regs[9'h12f][0]) reverb_pos <= reverb_pos + 13'd1;  // frozen if chip off
                state <= S_IDLE;
            end

            default: state <= S_IDLE;
            endcase
        end
    end
end

endmodule
