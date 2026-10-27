# SiDi128 native RGB444 capture protocol v1

SiDi128 target macro `JTFRAME_VIDEO_CAPTURE` advertises feature0x00100000.
This protocol uses SPI user-I/O0x90..0x99, independent of unchanged CAB0x81..0x89.
All multibyte integers are little endian. New counters/session identifiers are64bit;
legacy CAB counters remain32bit and are retained separately. Counters identify
current logical intervals/completed boundaries, not MCU receive timestamps.
Native LVBL rising increments physical raster; game time advances there except
when a separately validated capture pause is effective. CAB START retains its
frame-zero preload. Main CPU VBL interrupt acceptance never adds another game tick.

`JTFRAME_CAPTURE_FEEDBACK` adds two optional game outputs: the active-high
post-arbitration CPU VBL request and a source-qualified accepted-event toggle.
Unsupported cores tie them to zero. Toggles use two-flop synchronization and
reset transitions are absorbed. The source must toggle slowly enough to sample;
GNG's CPU acceptance rate is far below the system clock.

GNG has only a latched VBL IRQ; FIRQ/NMI are inactive. Acceptance is the rising
edge of `irq_ack` (BA/BS=01) with an IRQ-vector read at FFF8. The vector check
excludes reset acknowledgements. No PC decoding or ROM-signature gate is used.
The opt-in IRQ-driven pause policy requires an accepted VBL within the last three
unpaused native raster boundaries, no pending IRQ, and 256 quiet system clocks.
Once confirmed, pause retains that evidence while logical game/CAB time holds.
The controller allows two additional rasters for CPU/video settling before pixels
are acquired. A new pending IRQ or acceptance invalidates the confirmation;
losing it during a strict acquisition aborts that capture.

This is the practical assumption that the game finishes its current update and
waits for the next VBL. It does not prove CPU halt or handler completion. During
boot without recent interrupt acceptance, the bounded confirmation deadline falls
back to an advancing composite. Raster-sensitive games and software that keeps
writing video with frame IRQs suppressed need separate qualification.

Two512×16-bit synchronous dual-port BRAMs hold native scanlines. The selected
RGB444 raw/RLE wire representation is encoded in-place behind consumed pixels.
No SDRAM or FPGA framebuffer is used. Lines become immutable when READY;
read-at-offset retries never release them. A missing-line bitmap selects the next
upcoming missing native y with a free buffer; line order is not prescribed.
Native RGB and matching pixel/blanking qualifiers enter before any overlays.
Native component widths1..4 repeat MSBs to four bits; this first implementation
rejects higher precision and oversized MCU frame/provenance staging requirements.

## Measured FPGA cost

Post-fit GNG SiDi128 release build, 256×224 RGB444, seed 3 (2026-10-27):

| Hierarchy (includes children) | Logic elements | Registers | RAM bits | M9Ks |
| --- | ---: | ---: | ---: | ---: |
| `jtframe_capture` | 11,355 | 8,232 | 16,384 | 2 |
| `jtframe_capture_progress` | 650 | 407 | 0 | 0 |
| `jtframe_capture_line`, buffer 0 | 2,832 | 1,845 | 8,192 | 1 |
| `jtframe_capture_line`, buffer 1 | 2,820 | 1,846 | 8,192 | 1 |
| Complete GNG core | 30,250 | 15,477 | 230,912 | 57 |

Rows overlap and must not be added. Each line RAM stores 8,192 logical bits in
one physical 9,216-bit M9K. The two-line RAM is small, but the capture subtree
uses 9.53% of SiDi128's 119,088 logic elements. GNG leaves 88,838 logic elements
and 375 of 432 M9Ks; that is not a headroom guarantee for larger cores. Capture
is enabled in ordinary SiDi128 builds, so this shared target cost must be
budgeted for every core. Geometry, feedback capability and fitter packing affect
actual cost; qualify large cores separately.

Compared with the previous video-enabled PC/idle-loop policy at the same seed,
whole GNG changes from 30,306 to 30,250 logic elements and 15,485 to 15,477
registers, with unchanged RAM. The GNG main block loses eight registers; capture
subtree changes from 11,392 to 11,355 logic elements, while progress changes from
645 to 650. These are measured fitted results, including placement/packing, not
an exact feature-disabled overhead or a source-line-based savings estimate.
Minimum reported slack is +0.103 ns; all reported setup/hold/recovery/removal
summaries pass. Reports and comparison data are under the issue task artifacts
`video/irq-pause-simplification/`.

## SPI commands

| ID | Write payload / read snapshot |
| --- | --- |
|90|192-byte coherent progress/capability snapshot|
|98|cookie64, expected epoch64, flags8 (bit0 enable IRQ-driven pause policy); only idle/done/error|
|91|requested game frame64, reserved flags32=0; begin, increment capture sequence|
|92|cookie64, capture64, buffer8; select retained line header|
|97|96-byte immutable selected line header|
|93|cookie64, capture64, buffer8, line sequence32, offset16, length8(1..128); prepare read window|
|96|16-byte coherent window status|
|94|one guard byte then exactly requested bytes from the fixed read window|
|95|cookie64, capture64, buffer8, line sequence32; explicit release|
|99|cookie64, capture64; abort/end, release both buffers and owned pause|

Read snapshots use the first byte as a fixed guard/magic and then snapshot bytes
1..N-1, allowing the SPI/sys-domain request to settle. 94 has a separate guard,
so discard it before payload bytes. Range/identity/epoch errors never release a
buffer. New context cannot steal an active capture. Epoch changes abort capture.
Pause release occurs at native LVBL, with the pause decision for that exact edge retained for the synchronized CAB
tick, preserving the pending input duration even if confirmation changes between
the native edge and the delayed CAB tick. Unconfirmed pause expires after two
rasters and proceeds as an advancing composite. Lost confirmed contract is an
explicit error and releases pause/buffers. Legacy dump barriers cannot overlap.

Progress90 offsets:0magic76,1version1,2state(0idle,1waiting,2confirm,3acquire,
4done,5error,6resume),3error;4width16,6height16,8nativebits32,12flags32
(feedback,contract,IRQ,recent-service,effective,strict bits0..5). 16cookie64,24epoch64,
32capture64,40raster64,48game64,56acceptedIRQ64,64requested64,72achieved64,
80firstRaster64,88lastRaster64,96firstGame64,104lastGame64,112IRQgeneration64,
120CABframe32,124CABepoch32,128rasterPeriodCycles32,132clockHz32,
136remainingLines16,138readyBufferBits8,139reserved,140releasedLines32.
Physical raster is monotonic through game reset; game/IRQ reset and epoch increments
once per reset assertion. Firmware sessions distinguish FPGA reconfiguration.

Line97:0magic16=4c56,2version8=1,3buffer8,4lineSeq32,8cookie64,16epoch64,
24capture64,32sourceRaster64,40sourceGame64,48firstIRQ64,56firstCAB32,
60y16,62width16,64IRQdelta32,68lastCAB32,72flags32,76encodedBytes16,
78encoding8(1packed,2RLE),79nativeBits8,80..91reserved,92CRC32.
CRC32 is reflected IEEE over header0..91 followed by encoded payload.
First/last pixel raster/game/epoch must agree; invalid crossing lines remain missing.
IRQdelta is bounded by a scanline's possible accepted events and reconstructs its
last IRQ count exactly. CAB first/last retain the legacy synchronization phase.

Window96:0magic77,1flags(bit0ready,bit1buffer),2length,3reserved,4offset16,
6reserved16,8lineSeq32,12reserved32. 94 must be read only after matching readiness.

RGB444 RLE word LE16=CCCCRRRRGGGGBBBB; count nibble0..14 gives1..15 pixels;
nibble15 is followed by LE16 extension for count16+extension. Raw fallback packs
A,B as A[11:4],{A[3:0],B[11:8]},B[7:0]; odd last pixel pads low nibble0.
Decoder must produce exactly the declared width and reject all trailing/truncated
or overlong runs. A retained line's encoding/CRC never changes between retries.

## Files and provenance

MCU raw image header128: magic `JTV44401`,8version32=1,12headerBytes32=128,
16width32,20height32,24encoding32=1,28nativeBits32,32pixelBytes32,
36pixelCRC32,40capture64,48firstGame64,56firstRaster64,64lastRaster64,
72epoch64,80cookie64,88canonicalSHA256[32],120headerCRC32(over0..119),124reserved0.
Payload is normalized packed12-bit RGB444, row padding as above. Canonical SHA256
covers four LE32 values(format1,width,height,nativeBits) followed by payload.
Consecutive identical canonical images reuse the prior immutable payload before
any image SD write; each acquisition still publishes timing/provenance.

Map header128:magic `JTVMAP01`,8headerBytes32=128,12recordBytes32=48,
16height32,24cookie64,32epoch64,40capture64,48requested64,56payloadCRC32,124headerCRC32(over0..123).
One record per native y:0y16,2width16,4lineSeq32,8raster64,16game64,24firstIRQ64,
32firstCAB32,36lastCAB32,40IRQdelta32,44flags32. The run identity supplies epoch,
cookie and capture to every row without allocating them repeatedly in MCU SRAM.

index.jsonl records run identity/ROM SHA, each requested/achieved capture, image/map
references, canonical digest, duplicate/classification flags, source ranges,
transfer end and elapsed time. A composite spanning sourceF..L covers [F,L+1);
overlap is clipped against prior presentation coverage, and gaps are explicit.
Repeating a composite is a timing approximation, not independent live capture.
Raw image names resemble jtsim (`frame_nnnnn.raw`); PC exports frame_nnnnn.png.
Unique run directories prevent overwrite. SD staging is checked write/sync/close
then rename/index publication, not a power-loss-atomic FAT transaction.

See firmware doc/ftp-video.md for authenticated commands, limits and cleanup.
