/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

This core is available for hardware compatible with MiSTer.
Other FPGA systems may be supported by the time you read this.
This work is not mantained by the MiSTer project. Please contact the
core authors for issues and updates.

(c) LMN-san, OScherler, Raki 2020–2023.

Support the authors:

       Raki: https://www.patreon.com/ikamusume
    LMN-san: https://ko-fi.com/lmnsan
  OScherler: https://ko-fi.com/oscherler

The authors do not endorse or participate in illegal distribution
of copyrighted material. This work can be used with legally
obtained ROM dumps of games or with homebrew software for
the arcade platform.

This file license is GNU GPLv3.
You can read the whole license file at http://www.gnu.org/licenses/

*/

//================================================================================
//  Nemesis Sound Module (audio components of main CPU board)
//================================================================================

`default_nettype none

module nemesis_sound(
	input         i_clk,        // 48 MHz
	input         i_cen3p5,
	input         i_cen1p7,
	input         i_cen_clk_div,
	input         i_rst,

	input  [ 7:0] i_main_db,    // Sound input data (DATA Bus 0-7)
	input         i_data_n,     // Sound request (/DATA)
	input         i_sound_on_n, // Sound On (/SOUND_ON)

	input         i_cpu_start,
	output        o_z80_cs,
	output [13:0] o_z80_addr,
	input  [ 7:0] i_z80_data,
	input         i_z80_ok,

	output [ 7:0] o_wav1_addr,
	output [ 7:0] o_wav1_vol_addr,
	output [ 7:0] o_wav2_addr,
	output [ 7:0] o_wav2_vol_addr,
	input  [ 3:0] i_wav1_data,
	input  [ 7:0] i_wav1_vol_data,
	input  [ 3:0] i_wav2_data,
	input  [ 7:0] i_wav2_vol_data,

	output [15:0] o_sound,      // Sound output

	// OSD controls, temporary
	input         i_prom1_on,
	input         i_prom2_on,
	input         i_ay7_on,
	input         i_ay8_on,
	input  [ 7:0] i_vol_prom,
	input  [ 7:0] i_vol_ay7,
	input  [ 7:0] i_vol_ay8
);

////////////////////////////////////////////////////////////////////////////////////////////////////

// Clocks enables
wire        cen14;         // 14'318'182 Hz
wire        cen_k5289;     //  3'579'546 Hz
wire        cen_z80;       //  1'789'773 Hz
wire        cen_div_256;
reg  [ 7:0] r_clk_div_cnt;
reg  [ 7:0] r_ay8_ioa_in;

// Z80 signals
wire        cpu_rst_n, cpu_int_n, cpu_rfsh_n, cpu_mreq_n, cpu_iorq_n, cpu_rd_n, cpu_wr_n;
wire [15:0] cpu_addr;

// Z80 data bus
reg  [ 7:0] cpu_data_in;
wire [ 7:0] cpu_data_out, cpu_rom_data, cpu_ram_data,
            ay7_data, ay8_data, data_ff_out;

// Chip selects
reg         r_rom_CE_n, r_ram_CS, r_k5289_ld1, r_k5289_ld2, r_k5289_tg1, r_k5289_tg2,
            r_ay7_sel_n, r_ay8_sel_n, r_filter_ff_clk, r_data_OC_n;

// Audio PROM signals
wire [ 7:0] prom1_addr, prom2_addr;
wire [ 3:0] prom1_data, prom2_data;

wire [ 7:0] prom1_snd, prom2_snd;

// AY-3-8910 signals
wire [ 7:0] ay7_ioa_out, ay7_iob_out;
wire        ay7_bc1, ay7_bdir, ay8_bc1, ay8_bdir;

wire [ 9:0] ay7_sound, ay8_sound;

// Signal audio RC filter FIR for AY 7e and 8e
wire        ay7_filter_on, ay8_filter_on;

////////////////////////////////////////////////////////////////////////////////////////////////////

assign cen_k5289   = i_cen3p5;
assign cen_z80     = i_cen1p7;
assign cen_div_256 = i_cen_clk_div;

// Z80 reset
assign cpu_rst_n = ~i_rst;

// simple mixer
// the sum of 4 audio signal should be 2 bit bigger to accept the max of each
wire [15:0] full_audio;

// jtframe_mixer scales all input signals to output width before doing anything else. The drawback
// of that is that if you’re already working with full scale signals, it doesn’t leave much room
// for gains > 1, and thus to balance the sound, we end up mostly attenuating signals. Since the
// gains are in 4.4 fixed point format, it means that we waste the 4 bits of the integer part, and
// thus lose a lot of tuning range.
// 
// Therefore we left-pad the input signals to reduce the amount of scaling the mixer does, to be
// able to use the full range of the 4.4 gains.
// 
// Before switching back to jtframe_mixer, we were using the following integer gains on the 10-bit
// AY signals and the 8-bit PROM signals, without first upscaling the PROM signals to match the 10
// bits of the AYs:
// 
// PROM: 12       AY7:  24       AY8: 14
// 
// Therefore, to reproduce this with the jtframe_mixer, we padded the PROM signals with 00 on the
// left, and the integer gains 0x0C / 0x18 / 0x0E became the 4.4 fixed point values with the same
// representation, i.e.:
// 
//          PROM      AY7       AY8
//  PadTo   10(+2)    10(+0)    10(+0)
//  Int     12        24        14
//  4.4     0x0.C     0x1.8     0x0.E
//  Frac    0.75      1.5       0.875
// 
// Note: the AY gains at this point were very unbalanced because we were working with unsigned
// signals, but eventually the sound output is interpreted as signed. Therefore, we couldn’t go
// over half volume, or else the MSB that would be interpreted as the sign bit would flip and
// cause huge jumps in the signal, resulting in strong saturation (especially noticeable in the
// big core explosion, which uses almost all channels of all sound generators, instead of just one
// AY like the other sound effects.) This is the same reason why the jtframe_mixer was seemingly
// saturating at certain volumes, but much earlier because of the signals extension, which made us
// switch to a simpler, “manual” mixer. This was fixed by adding DC removal filters on each signal
// before entering the mixer, which is what allowed us to switch back to the jtframe_mixer.
// 
// Once this was done, a better sound mix could be achieved with the following values, wich match
// the schematic better, as there is less difference between the gains of AY7 and AY8:
// 
//          PROM      AY7       AY8
//  PadTo   10(+2)    10(+0)    10(+0)
//  Int     14        7         8
//  4.4     0x0.E     0x0.7     0x0.8
//  Frac    0.875     0.4375    0.5
// 
// Then, in order to have a wider range of gains available, we can pad the signals to avoid the
// mixer extending them too much, so we can amplify them instead of only attenuating them. First,
// we recalculate the PROM volume table to go from 0x80 at full volume to 0xff, effectively
// doubling all values. To compensate for that and keep the same mixer volume, we pad the PROM
// signals with an additional zero before the mixer. Then we pad all signals with an additional
// three zeroes, and multiply all volumes by 8 to compensate, which gives us:
// 
//          PROM      AY7       AY8
//  PadTo   14(+6)    13(+3)    13(+3)
//  Int     112       56        64
//  4.4     0x7.0     0x3.1     0x4.0
//  Frac    7.0       3.5       4.0
// 
// The problem with the DCRM filters is that they need a `sample` input to operate, which we don’t
// really know how to generate for the K5289. In addition, they affect the signal shape at low
// frequency, because the PROM dwells for a long time on the same sample, and the high-pass filter
// that is the DCRM causes the value to decrease. Since we only have unsigned signals with full
// contrast (the signal goes from 0 to its max value, it doesn’t have an offset larger than its
// amplitude,) there is no loss in amplification range caused by keeping the DC of the signals.
//
// unsigned_mixer is a copy of jtframe_mixer, but with unsigned inputs and outputs, and the sign
// extensions removed.

unsigned_mixer #(
	.W0   ( 14 ), // PROM 1
	.W1   ( 14 ), // PROM 2
	.W2   ( 14 ), // AY 7
	.W3   ( 14 ), // AY 8
	.WOUT ( 16 )
) u_mixer (
    .rst   ( i_rst        ),
    .clk   ( i_clk        ),
    .cen   ( cen_k5289    ),
    // input signals
    .ch0   ( { {6{1'b0}}, prom1_snd } ), // 14 bits
    .ch1   ( { {6{1'b0}}, prom2_snd } ), // 14 bits
    .ch2   ( { {4{1'b0}}, ay7_sound } ), // 14 bits
    .ch3   ( { {4{1'b0}}, ay8_sound } ), // 14 bits
    // gain for each channel in 4.4 fixed point format
    .gain0 ( i_prom1_on ? i_vol_prom : 8'd0 ),
    .gain1 ( i_prom2_on ? i_vol_prom : 8'd0 ),
    .gain2 ( i_ay7_on ? i_vol_ay7    : 8'd0 ),
    .gain3 ( i_ay8_on ? i_vol_ay8    : 8'd0 ),

	.mixed ( full_audio   ),
	.peak  (  )   // overflow signal (time enlarged)
);

// just in case we need to reduce the volume here...
assign o_sound = full_audio[15:0];

// Z80 address decoding
//
// ** 2 x 3-to-8 Line Decoder **
// ** [LS138] @ 10C, 11C      **
// ** Quad 2-Input AND Gate   **
// ** [LS08]  @ 11F           **
always @(*) begin
	reg rfsh_not_mreq, u11c_g2b_n;

	// [LS138] @ 10C
	rfsh_not_mreq   = cpu_rfsh_n & ~cpu_mreq_n;
	r_rom_CE_n      = ! ( rfsh_not_mreq && cpu_addr[15:14] == 2'b00  ); // Y0 and Y1
	r_ram_CS        = ! ( rfsh_not_mreq && cpu_addr[15:13] == 3'b010 ); // Y2
	r_k5289_ld1     = ! ( rfsh_not_mreq && cpu_addr[15:13] == 3'b101 ); // Y5
	r_k5289_ld2     = ! ( rfsh_not_mreq && cpu_addr[15:13] == 3'b110 ); // Y6
	u11c_g2b_n      = ! ( rfsh_not_mreq && cpu_addr[15:13] == 3'b111 ); // Y7 -> LS138@11C G2B_n

	// [LS138] @ 11C
	r_data_OC_n     = ! ( ~u11c_g2b_n && cpu_addr[2:0] == 3'b001 ); // Y1
	r_k5289_tg1     = ! ( ~u11c_g2b_n && cpu_addr[2:0] == 3'b011 ); // Y3
	r_k5289_tg2     = ! ( ~u11c_g2b_n && cpu_addr[2:0] == 3'b100 ); // Y4
	r_ay7_sel_n     = ! ( ~u11c_g2b_n && cpu_addr[2:0] == 3'b101 ); // Y5
	r_ay8_sel_n     = ! ( ~u11c_g2b_n && cpu_addr[2:0] == 3'b110 ); // Y6
	r_filter_ff_clk = ! ( ~u11c_g2b_n && cpu_addr[2:0] == 3'b111 ); // Y7
end

// Direct modelling of data inputs to the Z80
always @(*) begin
	case( 1'b1 )
		~r_rom_CE_n:             cpu_data_in <= cpu_rom_data;
		~r_ram_CS && ~cpu_rd_n:  cpu_data_in <= cpu_ram_data;
		~ay7_bdir && ay7_bc1:    cpu_data_in <= ay7_data;
		~ay8_bdir && ay8_bc1:    cpu_data_in <= ay8_data;
		~r_data_OC_n:            cpu_data_in <= data_ff_out;
		default:                 cpu_data_in <= 8'hff;
	endcase
end

wire cen_z80_wait, cpu_busak_n;

// Audio CPU - Zilog Z80 (uses T80s variant of the T80 soft core)
// NMI, BUSRQ, WAIT_n unused, pull high
// 
// ** Z80 CPU      **
// ** [Z80A] @ 10A **
T80s u_audio_cpu(
	.RFSH_n  ( cpu_rfsh_n   ),
	.MREQ_n  ( cpu_mreq_n   ),
	.INT_n   ( cpu_int_n    ),
	.IORQ_n  ( cpu_iorq_n   ),
	.RESET_n ( cpu_rst_n    ),
	
	.NMI_n   ( 1'b1         ),
	.BUSRQ_n ( 1'b1         ),
	.WAIT_n  ( 1'b1         ),
	.BUSAK_n ( cpu_busak_n  ),
	
	.CLK     ( i_clk        ),
	.CEN     ( cen_z80_wait ),
	
	.RD_n    ( cpu_rd_n     ),
	.WR_n    ( cpu_wr_n     ),
	
	// M1_n, HALT_n unused
	
	.A       ( cpu_addr     ),
	.DI      ( cpu_data_in  ),
	.DO      ( cpu_data_out )
);

jtframe_z80wait #(1) u_wait(
	.rst_n      ( cpu_rst_n    ),
	.clk        ( i_clk        ),
	.cen_in     ( cen_z80      ),
	.cen_out    ( cen_z80_wait ),
	.gate       (              ),
	.iorq_n     ( cpu_iorq_n   ),
	.mreq_n     ( cpu_mreq_n   ),
	.busak_n    ( cpu_busak_n  ),
	// manage access to shared memory
	.dev_busy   ( 1'b0         ),
	// manage access to ROM data from SDRAM
	.rom_cs     ( ~r_rom_CE_n  ),
	.rom_ok     ( i_z80_ok     )
);

// Audio CPU ROM (in SDRAM)
//
// ** NMOS 128 Kbit (16Kb x 8) UV EPROM **
// ** [27128] @ 9C                      **
assign o_z80_cs = ~r_rom_CE_n;
assign o_z80_addr = cpu_addr[13:0];
assign cpu_rom_data = i_z80_data;

// Audio CPU RAM
//
// ** 2k x 8bit Static RAM **
// ** [2128] @ 9A          **
jtframe_ram #(
	.AW( 11 ),
	.DW(  8 )
)
u_audio_cpu_ram(
	.clk  ( i_clk                    ),
	.cen  ( cen_z80_wait             ),
	.addr ( cpu_addr[10:0]           ),
	.data ( cpu_data_out             ),
	.we   ( ~r_ram_CS & ~cpu_wr_n    ),
	.q    ( cpu_ram_data             )
);

// ** Dual 4-Bit Binary Counter **
// ** [LS393] @ 7G              **
always @( posedge i_clk ) if( cen_div_256 ) begin
	r_clk_div_cnt <= r_clk_div_cnt + 8'd1;

	r_ay8_ioa_in  <= { 4'b0, r_clk_div_cnt[7:4] };  // AY-3-8910 IO ports are 8-bit
end

// ** Custom Chip Konami SCC Sound **
// ** [K0005289] @ 8A              **
K005289 u_k5289(
	.i_RST_n     ( cpu_rst_n       ),
	.i_CLK       ( i_clk           ),
	.i_CEN       ( cen_k5289       ),
	.i_LD1       ( r_k5289_ld1     ),
	.i_TG1       ( r_k5289_tg1     ),
	.i_LD2       ( r_k5289_ld2     ),
	.i_TG2       ( r_k5289_tg2     ),
	.i_COUNTER   ( cpu_addr[11:0]  ),
	.o_Q1        ( prom1_addr[4:0] ),
	.o_Q2        ( prom2_addr[4:0] )
);

// Waveform PROM
//
// ** 1K (256 x 4) NiCR PROM **
// ** [6301] @ 7A            **
assign o_wav1_addr = { ay7_ioa_out[7:5], prom1_addr[4:0] };
assign prom1_data  = i_wav1_data;

// Waveform PROM
//
// ** 1K (256 x 4) NiCR PROM **
// ** [6301] @ 7B            **
assign o_wav2_addr = { ay7_iob_out[7:5], prom2_addr[4:0] };
assign prom2_data  = i_wav2_data;

// Waveform Volume PROM
//
// Switched resistor ladders
//
// ** 2 x CMOS Quad Bilateral Switch **
// ** [4066] @ 5A, 5B                **
assign o_wav1_vol_addr = { ay7_ioa_out[3:0], prom1_data };
assign o_wav2_vol_addr = { ay7_iob_out[3:0], prom2_data };
assign prom1_snd       = i_wav1_vol_data;
assign prom2_snd       = i_wav2_vol_data;

// ** Quad 2-Input NOR Gate **
// ** [LS02] @ 6G           **
assign ay7_bdir = ~|{ r_ay7_sel_n, cpu_addr[ 9] };
assign ay7_bc1  = ~|{ r_ay7_sel_n, cpu_addr[10] };
assign ay8_bdir = ~|{ r_ay8_sel_n, cpu_addr[ 7] };
assign ay8_bc1  = ~|{ r_ay8_sel_n, cpu_addr[ 8] };

// ** Programmable Sound Generator **
// ** [AY-3-8910] @ 7E             **
jt49_bus #( .COMP( 2'b01 ) ) u_ay_7 (
	.rst_n   ( cpu_rst_n    ),
	.clk     ( i_clk        ),
	.clk_en  ( cen_z80      ),
	.bdir    ( ay7_bdir     ),
	.bc1     ( ay7_bc1      ),
	.din     ( cpu_data_out ),
	.sel     ( 1'b1         ),
	.dout    ( ay7_data     ),
	.sound   ( ay7_sound    ),
	.A       (              ),
	.B       (              ),
	.C       (              ),
	.sample  (              ),
	.IOA_in  ( 8'b0         ),
	.IOA_out ( ay7_ioa_out  ),
	.IOB_in  ( 8'b0         ),
	.IOB_out ( ay7_iob_out  )
);

// ** Programmable Sound Generator **
// ** [AY-3-8910] @ 8E             **
jt49_bus #( .COMP( 2'b01 ) ) u_ay_8 (
	.rst_n   ( cpu_rst_n    ),
	.clk     ( i_clk        ),
	.clk_en  ( cen_z80      ),
	.bdir    ( ay8_bdir     ),
	.bc1     ( ay8_bc1      ),
	.din     ( cpu_data_out ),
	.sel     ( 1'b1         ),
	.dout    ( ay8_data     ),
	.sound   ( ay8_sound    ),
	.A       (              ),
	.B       (              ),
	.C       (              ),
	.sample  (              ),
	.IOA_in  ( r_ay8_ioa_in ),
	.IOA_out (              ),
	.IOB_in  ( 8'b0         ),
	.IOB_out (              )
);

// Generate the following signals:
// Z80 !INT input
//
// ** Dual D Flip-Flop **
// ** [LS74] @ 18F     **
jtframe_ff u_sound_on_ff(
	.rst     ( i_rst                       ),
	.clk     ( i_clk                       ),
	.cen     ( 1'b1                        ),
	.sigedge ( i_sound_on_n                ),
	.set     ( 1'b0                        ),
	.clr     ( ~&{ cpu_rst_n, cpu_iorq_n } ),
	.din     ( 1'b1                        ),
	.q       (                             ),
	.qn      ( cpu_int_n                   )
);

// enable filter Select AY-3-8910 a or b
//
// These filters (1) don’t seem to do much, as the one on AY7 cuts off at 4.8 kHz,
// and the one on AY8 cuts off at 2.8 Hz (yes, Hz), which would just mute the sound,
// and (2) are never enabled in Nemesis. So we kept the logic, but didn’t include the filters.
//
// ** Hex D Flip-Flop **
// ** [LS174] @ 8J    **
bus_ff #( .W( 2 ) ) u_ay_filter_ff(
	.rst     ( i_rst           ),
	.clk     ( i_clk           ),
	.trig    ( r_filter_ff_clk ),
	.d       ( { cpu_addr[12], cpu_addr[11]   } ),
	.q       ( { ay8_filter_on, ay7_filter_on } ),
	.q_n     (                 )
);

// Latch data bus from X68K board
//
// ** Octal D Flip-Flop **
// ** [LS374] @ 11A     **
bus_ff #( .W( 8 ) ) u_data_ff(
	.rst     ( i_rst       ),
	.clk     ( i_clk       ),
	.trig    ( i_data_n    ),
	.d       ( i_main_db   ),
	.q       ( data_ff_out ),
	.q_n     (             )
);

endmodule
