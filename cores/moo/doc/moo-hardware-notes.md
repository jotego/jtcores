Moo Mesa audio hardware notes

These notes preserve the implementation rationale moved out of the RTL during the pre-PR cleanup. They describe the existing implementation and its original source comments. The source revisions for MAME and SiliconRE were not recorded in those comments; the line citations below are historical references, not verified citations to a current upstream revision.

Original PCM rationale (pre-cleanup lines 6–14):

Konami K054539 (TOP) PCM sound chip.
   Written from MAME's k054539.cpp and Furrtek's SiliconRE 054539 die
   reconstruction; not derived from jt539. Moo Mesa board straps
   (sound.kicad_sch E4/C5): no A8 pin, so the register file is addressed as
   {A9,A[7:0]} and 0xE1xx mirrors 0xE0xx; YMD=1 with AXDA/AXXA/ALRA/AXWA
   carrying the YM2151 serial stream, so the aux input is mixed digitally here
   and this chip is the board's only analogue source; reverb SRAM C5 is an
   HM62256 on R_A0..13 plus R_A16 (0x8000 byte window), RABS NC; DTS1=1,
   DTS2=0, USE2=0, RRMD=0, DLY=0, ADDA=0; TIM and ROBS NC.

Original PCM rationale (pre-cleanup lines 50–53):

Register file on the board bus {A9,A7:0}. MAME offset -> module offset:
channels 0x0xx unchanged, control 0x2xx -> 0x1xx. MAME's 0x1xx page needs A8
and is unreachable on this board. CPU and sequencer share one write process
so Quartus infers a single register block.

Original PCM rationale (pre-cleanup lines 153–156):

The board leaves the Z80 WAIT pin unconnected because the real chip owns a
private PCM ROM bus. Here the samples come from shared SDRAM, so a data-port
read cannot always answer inside one Z80 bus cycle; `busy` gates the sound
CPU clock enable instead. INFERRED, fidelity only

Original PCM rationale (pre-cleanup lines 164–170):

Reverb (MAME k054539.cpp:116-131,289,302). Per sample: read+clear
rram[reverb_pos] as feedback into L and R, every channel accumulates its
attenuated sample at rram[(rdelta+reverb_pos)&0x1fff], then reverb_pos++.
The audio delay line is int16[0x2000]; the CPU data port sees the board's
full 0x8000 byte store, pointer bit 16 selecting the upper half (MAME models
only 0x4000 bytes). $readmemh init, not an `initial for`: Quartus caps the
unroll at 5000 iterations and 8192 would raise Error 10106

Original PCM rationale (pre-cleanup lines 179–180):

Two 0x4000 byte banks: CPU data port on RAM port 0, audio RMW on port 1, so
Quartus infers two dual port M10Ks instead of 262,144 flops

Original PCM rationale (pre-cleanup lines 455–457):

Key-on restarts every selected voice, including an
already active one: MAME reaches the same result via
its cur_pos != chan->pos test at k054539.cpp:186

Original PCM rationale (pre-cleanup lines 515–517):

Hold the SDRAM request until rom_ok: `cen` is 18.432 MHz on a
48 MHz clock, so clearing it unconditionally would drop the
request before the shared SDRAM could answer

Original PCM rationale (pre-cleanup lines 634–636):

A key-on queued after this channel's S_LOAD is for
the replacement voice; the retiring sample must not
clear its active bit first

Original PCM rationale (pre-cleanup lines 694–697):

The silicon mirrors the live position into 0x0c..0x0e while
register updates are enabled; the Z80 diagnostics read it
back. A key-on committing on this same edge wins, otherwise
S_LOAD would consume restart from the overwritten end address

Original sound-stage rationale:

K054321 global volume (054986A U2, in series with the AD1868). The counter
lives here rather than in the shared jt054321.v because that module cannot
gain audio ports without raising PINMISSING in rungun/xmen

Clarification: the reverb memory consists of two logical 16 KiB dual-port RAM banks. Physical FPGA block usage depends on synthesis; the old phrase “two dual port M10Ks” was not a valid physical block count.
