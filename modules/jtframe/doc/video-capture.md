# Minimal native RGB444/RGB555 capture

`JTFRAME_REMOTE` enables a paired debug recorder on the MiST-family user-I/O
SPI path, together with the CAB stream interface. It is selected at one
capture-instantiation boundary; the existing feature mask gates remote SPI
handlers and CAB snapshot logic when disabled. Shared board/input/joystick
logic is CAB-aware unconditionally and receives zero controls on unsupported
targets. SiDi128 enables it in both debug and release builds. The firmware and
FPGA images must use the same interface.
There is no compatibility negotiation with the previous experimental ABI.
CAB input commands `0x81..0x89` are unchanged.

## SPI commands

Multibyte values are little endian. Commands are sent on the existing user-I/O
SPI chip select.

| Opcode | Transfer after opcode | Meaning |
| --- | --- | --- |
| `0x90 INFO` | Read 8 bytes: tagged-width16, height16, selected frame32 | Read once at run start and after the first row of each capture. |
| `0x91 BEGIN` | Write target frame32, row step16 | Start a capture. A zero step is treated as one; steps above the image height clamp to the height. |
| `0x94 READ` | Read one prefix byte and its payload | Reads the ordered head row. A complete payload transfer consumes it. |
| `0x99 ABORT` | No payload | Cancel and release capture-owned pause. |

`READ` prefix 0 means empty and has no payload. Prefixes 1..254 mean that many
16-bit RLE words, including any long-run extension words. Prefix `0xff` means
raw pixels: `(3*width+1)/2` bytes for RGB444 or `2*width` bytes for RGB555.
INFO width bit 15 tags RGB555; clear means RGB444. Width occupies bits 14..0.
There are no row IDs, y values,
headers, status records, ACK command, magic/version fields or checksums. The MCU
and FPGA independently generate the same row sequence from geometry and step.

RGB444 keeps the existing packed-nibble raw format and compact RLE words: the
high nibble is run length minus one (0..14 represents one through fifteen
pixels; 15 indicates a following 16-bit extension), and the low twelve bits
are the color. RGB555 is canonical little-endian 16-bit `{0, R5, G5, B5}`.
Its RLE literals are little-endian `{0,color15}` and repeats are
`{1,color15}` followed by a little-endian run length minus two. A run of two
pixels does not save bytes by itself. Both encoders select RLE only when it is
strictly smaller than raw and no more than 508 bytes; otherwise the row is
raw. RGB555 is selected at compile time for COLORW>=5, taking each component's
five most significant bits; COLORW<=4 retains the existing RGB444 expansion.

For height H and step S clamped to H, rows are visited residue-major. Start at
row zero, add S while the sum is below H, then advance the residue and continue
at residue plus one. For example, H=7 and S=3 yields `0,3,6,1,4,2,5`. Two
synchronous dual-port BRAM banks hold encoded lines. A row stays immutable until
the SPI master samples the final payload bit; ending chip select early leaves
the same row at the head. If both banks are full, acquisition waits without
overwriting a row.

## Capture timing and limits

The capture engine samples native color before OSD. It targets a native raster
boundary, waits two raster intervals, and then acquires the selected rows. It
pauses the game through the normal combined pause input. In CAB mode the
existing CAB frame counter supplies the target timeline; otherwise a local
32-bit counter advances at native raster boundaries and clears on game reset.
CAB input hold remains boundary-aligned so capture pause does not consume input
durations. Reset, ABORT, or owner cleanup clears pending rows and releases the
capture-owned pause.

This pause policy assumes the game finishes its current update and waits after
its frame interrupt is suppressed. The recorder does not inspect CPU interrupt
acceptance, program counter, ROM identity, or handler completion. A game that
continues writing video, or depends on raster timing, can produce mixed or
different images. The frame returned by INFO is the actual paused checkpoint;
a late target is not relabeled as its requested frame.

The MCU owns two 1,024-byte row buffers; the 8 KiB FatFs sector buffer is only
temporary SPI scratch. Raw files contain tagged-width16, height16, then
canonical row-major packed RGB444 or little-endian RGB555 pixels. For a
possible duplicate, the recorder compares each received row against the prior
image and opens no output image while rows match. A complete match adds only an
index reference and performs zero image-file creates or writes. At the first
difference, the recorder stages an image, replays the verified equal prefix
one row per poll, then writes the held different row and remaining rows. Each
unique image row is written once. There are no per-row maps, ROM hashes, image
hashes, CRC fields or full-frame buffer.

The implementation accepts widths and heights from 1 through 512. The
firmware polls empty READs through its normal service loop and writes images
using exact-seek/read/write, file-size, sync, close and rename checks.
Owner lease expiry, OSD interruption, reset, disconnect, explicit VIDSTOP and
SD errors stop the recorder and remove an unpublished temporary file.

## COLORW5 measurements and validation

Both tested cores were built for SiDi128 with Quartus 20.1, seed 3, release
(`--nodbg`), and the same timestamp. The capture hierarchy uses a true dual-port
1024×16 RAM split into two 512-word banks, or 2 M9Ks. Contra fitted the capture
hierarchy at 910 logic cells and 395 registers; the full core used 25,128 logic
elements, 9,454 registers and 65 M9Ks. Shinobi/S16 fitted the capture hierarchy
at 902 logic cells and 395 registers; its full core used 31,552 logic elements,
13,495 registers and 92 M9Ks. These are separate core totals, not an estimate of
the feature's whole-core incremental cost. Full fitter and STA reports are in
`/nobackup/tasks/jtcores-166/artifacts/video/colorw5/build/`.

Both builds passed 102 reported timing checks at three corners with no negative
slack, zero TNS, and no unconstrained clocks or I/O paths. Minimum setup slack
was +0.564 ns for Contra and +1.616 ns for S16; minimum hold slack was +0.120 ns
and +0.102 ns, respectively. Targeted slow-corner RAM-to-SPI-byteout slacks
were +32.729 ns and +32.755 ns; byteout-to-MISO were +18.018 ns and +15.106 ns;
MISO-to-SPI_DO setup were +4.100 ns and +3.644 ns. Per-core reports include the
RAM-to-high-word path and MISO output hold check.

The paired production firmware and RBFs were installed and verified on SiDi128.
Each core completed a controlled 2,000-frame CAB run with 35 input events and
captures requested and received at frames 600, 1200 and 1800. All six images
were nonblank RGB555 and had native channel values outside the RGB444 lattice.
Contra images are 280×224; S16 images are 320×224. S16's frame 1800 was an exact
duplicate of frame 1200 and reused its image. The simplified pause policy can
select different content from earlier recordings; equality with older captures
is not required.

A task-only S16 firmware build measured 148,853 video SPI bytes for three
captures at 600-frame spacing. Encoded pixel payload, including raw fallback,
was 116,246 bytes (78.09% of the wire total); 646 rows used RLE and 26 used raw
fallback. There were 16,275 READ commands, including 15,603 empty polls, and 672
consumed rows. Two unique files accounted for 286,728 bytes and 448 row writes.
The duplicate frame caused zero image creates, zero image bytes, and zero row
writes. This measurement uses three checkpoints; its empty-poll ratio should
not be compared directly with an earlier 20-checkpoint run at 100-frame
spacing.

Reset and FTP disconnect were tested during row acquisition after two rows had
been written. Both canceled the current run, removed its temporary image,
released the input owner, and allowed a fresh nonblank capture. The uninstrumented
production firmware and S16 RBF were restored and verified afterward; the final
board had no input owner, all joystick inputs zero, capture inactive, and CAB
idle.

The production firmware is 283,900 bytes. The linker-map SRAM span from
`_srelocate` to `__heap_start__` is 250,080 bytes, 96,224 bytes below the earlier
346,304-byte build; `.bss` is 244,424 bytes. The 96 KiB frame arena was removed
and replaced by two 1,024-byte row buffers. The 8 KiB heap and 24 KiB stack
reservations remain; observed stack use was 3,064 bytes. Full reports, image
fixtures, SWD logs and run manifests are under
`/nobackup/tasks/jtcores-166/artifacts/video/colorw5/`.
