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
    Date: 11-8-2026 */

// Z80 at 5MHz plus a YM2610 at 8MHz.
//
//   0000-77ff  ROM, the bottom of the 128kB sound ROM
//   7800-7fff  RAM
//   8000-ffff  one of four 32kB banks of the same ROM
//
// Two different port maps:
//   spinlbrk_sound_portmap (pspikes, turbofrc)
//     00     w  bank select    14  r latch / w acknowledge    18-1b rw YM2610
//   pspikes_sound_portmap (aerofgtb) - despite the name, pspikes does NOT use it
//     00-03 rw  YM2610         04  w bank    08 w acknowledge  0c r latch
//
// Getting this wrong stalls the 68000: it polls the pending flag, and if the
// Z80 never hits the acknowledge port the flag never clears.
//
// The latch is two way: a write from the 68000 raises the Z80 NMI and sets a
// pending flag the 68000 can poll; the Z80 clears both by writing to port 14.

module jtpspike_snd(
    input                rst,
    input                clk,
    input                snd_cen,        // 5 MHz
    input                fm_cen,         // 8 MHz

    input      [ 7:0]    snd_latch,
    input                snd_wr,
    input                LVBL_snd,
    output reg           snd_pending,

    output     [16:0]    rom_addr,
    output               rom_cs,
    input      [ 7:0]    rom_data,
    input                rom_ok,

    output     [19:0]    pcma_addr,
    output               pcma_cs,
    input      [ 7:0]    pcma_data,
    input                pcma_ok,

    output     [18:0]    pcmb_addr,
    output               pcmb_cs,
    input      [ 7:0]    pcmb_data,
    input                pcmb_ok,

    input                aerofgt,
    input      [ 7:0]    debug_bus,

    output signed [15:0] fm_l, fm_r
);

wire [15:0] A;
wire [ 7:0] cpu_dout, fm_dout;
reg  [ 7:0] cpu_din;
reg  [ 1:0] bank;
wire        mreq_n, iorq_n, rd_n, wr_n, m1_n, rfsh_n, int_n;
wire        mem_acc, io_acc;
wire        ram_cs, bank_cs, latch_rd, latch_ack, fm_cs;
wire [ 7:0] ram_dout;
wire [19:0] adpcma_addr;
wire [23:0] adpcmb_addr;
// jt10.v declares adpcma_bank as 4 bits but its own jt12_top drives 5, so
// one width warning inside the submodule is unavoidable. Match the port and
// leave it unused: the 1MB region is covered by adpcma_addr alone
wire [ 3:0] adpcma_bank;
wire        adpcma_roe_n, adpcmb_roe_n;
reg  [ 7:0] pcma_l, pcmb_l;

assign mem_acc  = ~mreq_n & rfsh_n;
assign io_acc   = ~iorq_n & m1_n;
// 7800-7fff is the only RAM, everything else in memory space is ROM
assign ram_cs   = mem_acc & A[15:11]==5'b01111;
assign rom_cs   = mem_acc & ~ram_cs;
assign bank_cs  = io_acc & (aerofgt ? A[7:0]==8'h04 : A[7:0]==8'h00);
assign latch_rd = io_acc & (aerofgt ? A[7:0]==8'h0c : A[7:0]==8'h14);
assign latch_ack= io_acc & (aerofgt ? A[7:0]==8'h08 : A[7:0]==8'h14);
assign fm_cs    = io_acc & (aerofgt ? A[7:2]==6'b0000_00     // 00-03
                                    : A[7:2]==6'b0001_10);   // 18-1b
assign rom_addr = { A[15] ? bank : 2'd0, A[14:0] };

always @* begin
    cpu_din = 8'hff;
    case( 1'b1 )
        ram_cs:   cpu_din = ram_dout;
        rom_cs:   cpu_din = rom_data;
        latch_rd: cpu_din = snd_latch;
        fm_cs:    cpu_din = fm_dout;
        default:;
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        bank        <= 0;
        snd_pending <= 0;
    end else begin
        if( bank_cs && !wr_n ) bank <= cpu_dout[1:0];
        // the 68000 write wins over a simultaneous acknowledge
        if( latch_ack && !wr_n ) snd_pending <= 0;
        if( snd_wr            ) snd_pending <= 1;
    end
end

jtframe_z80_devwait u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( snd_cen   ),
    .cpu_cen    (           ),
    .int_n      ( int_n     ),
    .nmi_n      ( ~snd_pending ),
    .busrq_n    ( 1'b1      ),
    .m1_n       ( m1_n      ),
    .mreq_n     ( mreq_n    ),
    .iorq_n     ( iorq_n    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .rfsh_n     ( rfsh_n    ),
    .halt_n     (           ),
    .busak_n    (           ),
    .A          ( A         ),
    .din        ( cpu_din   ),
    .dout       ( cpu_dout  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .dev_busy   ( 1'b0      )
);

jtframe_ram #(.AW(11)) u_ram(
    .clk        ( clk       ),
    .cen        ( 1'b1      ),
    .addr       ( A[10:0]   ),
    .data       ( cpu_dout  ),
    .we         ( ram_cs & ~wr_n ),
    .q          ( ram_dout  )
);

// ADPCM ROMs. The chip has no wait handshake, so the byte is latched when
// SDRAM answers and held until the next request
assign pcma_cs   = ~adpcma_roe_n;
assign pcmb_cs   = ~adpcmb_roe_n;
assign pcma_addr = adpcma_addr;         // 1 MB region, adpcma_bank stays 0
assign pcmb_addr = adpcmb_addr[18:0];   // 256 kB region

// Latch on ok alone, NOT on cs&&ok. roe_n is a narrow strobe and the SDRAM
// answers after it has already dropped, so cs&&ok is never true on the same
// edge for ADPCM-B and the chip is fed a constant zero. ADPCM-A only got away
// with it because its roe_n stays asserted for long stretches.
always @(posedge clk) begin
    if( pcma_ok ) pcma_l <= pcma_data;
    if( pcmb_ok ) pcmb_l <= pcmb_data;
end

`ifdef SIMULATION
// Isolated ADPCM-B render. jt10 leaves jt12_top's adpcmB_l/r unconnected, so
// reach them hierarchically and write a raw stereo stream. Converted to a wav
// and listened to - the only way to tell whether the crowd sample decodes,
// since it cannot be picked out of the full mix.
integer fbraw; reg [10:0] bdiv=0;
initial fbraw = $fopen("adpcmb.raw","wb");
always @(posedge clk) begin
    bdiv <= bdiv==11'd936 ? 11'd0 : bdiv+11'd1;   // ~57 kHz, the harness rate
    if( bdiv==0 ) begin
        $fwrite(fbraw,"%c%c%c%c",
            u_jt10.u_jt12.adpcmB_l[ 7:0], u_jt10.u_jt12.adpcmB_l[15:8],
            u_jt10.u_jt12.adpcmB_r[ 7:0], u_jt10.u_jt12.adpcmB_r[15:8]);
    end
end

// sound path probe: is the main CPU sending commands, is the Z80 running,
// is the YM2610 being written, and is the ADPCM-A bank ever non-zero
integer cmd_n=0, rom_n=0, fm_n=0, pa_n=0, pb_n=0, pa_both=0, pb_both=0;
reg [4:0] bank_max=0;
always @(posedge clk) begin
    if( snd_wr             ) cmd_n <= cmd_n+1;
    if( rom_cs   & rom_ok  ) rom_n <= rom_n+1;
    if( fm_cs    & ~wr_n   ) fm_n  <= fm_n +1;
    if( pcma_cs            ) pa_n  <= pa_n +1;
    if( pcmb_cs            ) pb_n  <= pb_n +1;
    // how often was the OLD cs&&ok condition true? near zero for B confirms
    // the strobe never overlapped the SDRAM answer
    if( pcma_cs & pcma_ok  ) pa_both <= pa_both+1;
    if( pcmb_cs & pcmb_ok  ) pb_both <= pb_both+1;
    if( {1'b0,adpcma_bank} > bank_max ) bank_max <= {1'b0,adpcma_bank};
end
// Which YM2610 register bank does the Z80 actually reach? ADPCM-B is bank 0
// (regs 10-1c) and ADPCM-A is bank 1 (regs 100-12d), so a dead bank 1 kills
// ADPCM-A and FM channels 4-6 while leaving ADPCM-B working
integer b0_n=0, b1_n=0, kon_n=0, koff_n=0, start_n=0, end_n=0, bstart_n=0;
reg [7:0] bstlo=0, bsthi=0, benlo=0, benhi=0, bdnlo=0, bdnhi=0, blvl=0;
reg [1:0] bpan=0;
reg [1:0] ch_lr [0:7];
reg [4:0] ch_lvl[0:7];
reg [7:0] ch_stlo[0:7], ch_sthi[0:7], ch_enlo[0:7], ch_enhi[0:7];
integer ch_kon[0:7];
// what part of each ADPCM ROM do we actually touch? compare with the start/end
// the game programs - a wrong delta-T address shift shows up here immediately
reg [19:0] amin=20'hfffff, amax=0;
reg [18:0] bmin=19'h7ffff, bmax=0;
integer i;
initial for(i=0;i<8;i=i+1) begin
    ch_lr[i]=0; ch_lvl[i]=0; ch_kon[i]=0;
    ch_stlo[i]=0; ch_sthi[i]=0; ch_enlo[i]=0; ch_enhi[i]=0;
end
always @(posedge clk) begin
    if( pcma_cs ) begin
        if( pcma_addr<amin ) amin <= pcma_addr;
        if( pcma_addr>amax ) amax <= pcma_addr;
    end
    if( pcmb_cs ) begin
        if( pcmb_addr<bmin ) bmin <= pcmb_addr;
        if( pcmb_addr>bmax ) bmax <= pcmb_addr;
    end
end
reg [7:0] b0_reg=0, b1_reg=0, last_kon=0;
reg [7:0] atl=0, ar=0;   // 0x101 total level, 0x100 key-on
always @(posedge clk) if( fm_cs & ~wr_n ) begin
    case( A[1:0] )
        2'd0: b0_reg <= cpu_dout;
        2'd1: begin
            b0_n <= b0_n+1;
            // ADPCM-B, bank 0 regs 10-1b. Mirrors ym_trace.lua's B-START line
            case( b0_reg )
                8'h11: bpan  <= cpu_dout[7:6];
                8'h12: bstlo <= cpu_dout;
                8'h13: bsthi <= cpu_dout;
                8'h14: benlo <= cpu_dout;
                8'h15: benhi <= cpu_dout;
                8'h19: bdnlo <= cpu_dout;
                8'h1a: bdnhi <= cpu_dout;
                8'h1b: blvl  <= cpu_dout;
                8'h10: if( cpu_dout[7] ) begin
                    bstart_n <= bstart_n+1;
                    $display("f%0d B-START      start=%06X end=%06X  pan=%02b lvl=%03d deltaN=%02X%02X rep=%0d",
                        fcnt, {bsthi,bstlo,8'd0}, {benhi,benlo,8'd0},
                        bpan, blvl, bdnhi, bdnlo, cpu_dout[4]);
                end
                default:;
            endcase
        end
        2'd2: b1_reg <= cpu_dout;
        2'd3: begin
            b1_n <= b1_n+1;
            // reg 00 bit 7: 0 = key ON for the channels in [5:0], 1 = dump/key off
            if( b1_reg==8'h00 ) begin
                last_kon <= cpu_dout;
                if( cpu_dout[7] ) koff_n <= koff_n+1; else kon_n <= kon_n+1;
            end
            if( b1_reg==8'h01 ) atl <= cpu_dout;
            // 10-1f start address, 20-2f end address, per channel
            if( b1_reg[7:4]==4'h1 ) start_n <= start_n+1;
            if( b1_reg[7:4]==4'h2 ) end_n   <= end_n+1;
            // mirror of cores/pspike/ver/powerspikes/mame_scripts/ym_trace.lua
            // so the two traces can be diffed line for line
            if( b1_reg[7:4]==4'h0 && b1_reg[3:0]>=4'h8 && b1_reg[3:0]<=4'hd ) begin
                ch_lr [b1_reg[2:0]] <= cpu_dout[7:6];
                ch_lvl[b1_reg[2:0]] <= cpu_dout[4:0];
            end
            if( b1_reg[7:4]==4'h1 ) begin
                if( !b1_reg[3] ) ch_stlo[b1_reg[2:0]] <= cpu_dout;
                else             ch_sthi[b1_reg[2:0]] <= cpu_dout;
            end
            if( b1_reg[7:4]==4'h2 ) begin
                if( !b1_reg[3] ) ch_enlo[b1_reg[2:0]] <= cpu_dout;
                else             ch_enhi[b1_reg[2:0]] <= cpu_dout;
            end
            if( b1_reg==8'h00 && !cpu_dout[7] ) begin : keyon_report
                integer c;
                for( c=0; c<6; c=c+1 ) if( cpu_dout[c[2:0]] ) begin
                    ch_kon[c] <= ch_kon[c]+1;
                    $display("f%0d KEYON ch%0d  start=%06X end=%06X  lr=%02b lvl=%02d",
                        fcnt, c,
                        {ch_sthi[c[2:0]], ch_stlo[c[2:0]], 8'd0},
                        {ch_enhi[c[2:0]], ch_enlo[c[2:0]], 8'd0},
                        ch_lr[c[2:0]], ch_lvl[c[2:0]]);
                end
            end
        end
    endcase
end
integer fcnt=0;
always @(negedge LVBL_snd) begin
    fcnt <= fcnt+1;
    if( fcnt[3:0]==0 ) begin
        $display("SND cmd=%0d z80rom=%0d fmwr=%0d pcma=%0d pcmb=%0d bankmax=%0d",
            cmd_n, rom_n, fm_n, pa_n, pb_n, bank_max);
        $display("SND regs bank0=%0d bank1=%0d | ADPCM-A kon=%0d koff=%0d | ADPCM-B starts=%0d",
            b0_n, b1_n, kon_n, koff_n, bstart_n);
        $display("SND rom span: pcma %05X-%05X  pcmb %05X-%05X | cs&&ok overlaps: pcma=%0d pcmb=%0d",
            amin, amax, bmin, bmax, pa_both, pb_both);
    end
end
`endif

jt10 u_jt10(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( fm_cen    ),
    .din        ( cpu_dout  ),
    .addr       ( A[1:0]    ),
    .cs_n       ( ~fm_cs    ),
    .wr_n       ( wr_n      ),
    .dout       ( fm_dout   ),
    .irq_n      ( int_n     ),

    .adpcma_addr( adpcma_addr  ),
    .adpcma_bank( adpcma_bank  ),
    .adpcma_roe_n(adpcma_roe_n ),
    .adpcma_data( pcma_l       ),
    .adpcmb_addr( adpcmb_addr  ),
    .adpcmb_roe_n(adpcmb_roe_n ),
    .adpcmb_data( pcmb_l       ),

    // separated outputs unused, the mixed ones carry everything
    .psg_A      (           ),
    .psg_B      (           ),
    .psg_C      (           ),
    .fm_snd     (           ),
    .psg_snd    (           ),
    .snd_right  ( fm_r      ),
    .snd_left   ( fm_l      ),
    .snd_sample (           ),
    // debug_bus[5:0] mutes individual ADPCM-A channels, 0 = all playing
    .ch_enable  ( ~debug_bus[5:0] )
);

endmodule
