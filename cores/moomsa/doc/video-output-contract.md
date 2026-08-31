# Moo Mesa video-output contract

This document records the video boundary that the Moo Mesa core presents to
the standard MiSTer framework. It is an implementation audit, not a claim that
a fresh RBF has been validated on a physical DAC, CRT or HDMI display.

## Native raster and refresh

| Item | Contract | Provenance |
| --- | --- | --- |
| Raster clock | 8 MHz equivalent pixel cadence from the 32 MHz K053252 clock | **INFERRED** from the direct KiCad clock identity and the K053252 `/4` mode |
| Horizontal total | 512 raster clocks | **KNOWN** from `tb_053252.sv` and the pinned startup vector |
| Vertical total | 264 lines | **KNOWN** from `tb_053252.sv` and the pinned startup vector |
| Active image | 384 × 224 | **KNOWN** from the same vector bench |
| Refresh | `8,000,000 / (512 × 264) = 59.185606060606 Hz` | **INFERRED** from the measured vector and 8 MHz cadence |
| Aspect ratio | 4:3 | **INFERRED** cabinet/display contract; framework macros are `JTFRAME_ARX=4`, `JTFRAME_ARY=3` |

The K053252 remains a programmable register file. The core does not replace its
totals, porches or sync widths with a fixed timing shell. The 59.185606 Hz
value is declared in both `cfg/macros.def` and the generated Moo QSF so the
framework timing checks use the actual startup vector. The old rate and video
size skip macros are intentionally absent.

## Output path

```text
Moo RGB + K053252 blank/sync
        │
        ▼
jtframe_emu → jtframe_mister → arcade_video
                                  ├─ raw/direct path ──┐
                                  └─ video_freak/ascal ─┤
                                                        ▼
                                           MiSTer HDMI and DB15 outputs
```

The core supplies 8-bit RGB, horizontal/vertical blanking and sync through the
generated `jtframe_emu` boundary. `jtframe_mister` consumes those signals in
`arcade_video`; the output stage is then selected by the normal MiSTer system
logic. `tools/validate_video_contract.py` checks this fan-out and the source
closure on every audit run.

### Direct video

Direct video is an HPS/OSD setting, not a Moo RTL signal. In the production
`sys_top` path, `direct_video` is `cfg[10]`; when the framebuffer/scaler is not
selected, that bit selects the raw `arcade_video` timing/data into the HDMI
transmitter. The Moo core does not hard-force it.

Use direct video with a compatible 15 kHz DAC/CRT chain. A normal HDMI TV or
monitor should use the standard processed path. This distinction follows the
[MiSTer Direct Video documentation](https://github.com/MiSTer-devel/Wiki_MiSTer/wiki/Direct-Video).

### Analog and CRT

The MiSTer target includes the standard DB15 analog pin/IO assignments in
`modules/jtframe/target/mister/hdl/sys/sys_analog.tcl`:

- six-bit RGB `VGA_R/G/B`;
- separate `VGA_HS` and `VGA_VS`;
- `VGA_EN` output enable;
- analog audio pins alongside the video pins.

The core declares `resolution=15kHz` in its release metadata and preserves the
native 59.185606 Hz raster. The framework's forced-scandoubler and scanline
controls remain available for displays that require a higher-rate VGA signal;
`VGA_SL` is passed from the OSD-controlled framework stage. No analogizer or
CRT-specific signal is fabricated in Moo RTL. The `JTFRAME_NO_ANALOGIZER`
default seen in the MiSTer QSF concerns the separate Pocket cartridge
analogizer/SNAC feature; it does not remove the MiSTer DB15 path.

### HDMI

The normal HDMI path remains enabled through `sys.tcl`. `sys_top` selects the
direct/raw or processed HDMI clock and signal set using `direct_video`,
`vga_fb`, and the framework's `video_freak`/scaler state. The core supplies
`VIDEO_ARX/VIDEO_ARY` and leaves `HDMI_FREEZE`, `HDMI_BLACKOUT`, and
`HDMI_BOB_DEINT` inactive because Moo has one fixed startup raster and no
runtime resolution mode change in the four supported profiles.

This is a source-level and static-integration audit. A physical HDMI/CRT
acceptance result still requires a fresh Quartus RBF, loading it on a real
MiSTer, and checking display lock, geometry, audio and controls.

## Audit command

From the jtcores checkout:

```text
python cores/moomsa/tools/validate_video_contract.py
```

The validator also rejects stale fixed bank macros, stale 320 × 240/60 Hz
declarations, and any Moo-specific `direct_video` override.

The corresponding EEPROM persistence contract is checked with:

```text
python cores/moomsa/tools/validate_save_contract.py
```
