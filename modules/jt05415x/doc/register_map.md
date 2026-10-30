# K054156/K054157 Register Map Notes

These notes relate the MAME `k054156_k054157_k056832` register map to the
current HDL extraction in `modules/jt05415x/hdl/jt054156.v` and
`modules/jt05415x/hdl/jt054157.v`.

MAME uses two CPU-visible banks for the Moo Mesa board:

- `0x0c0000-0x0c003f`: first bank, handled by `k056832_device::word_w`.
- `0x0d8000-0x0d8007`: second bank, handled by `k056832_device::b_word_w`.

The first bank maps to `jt054156`. The second bank maps to the CPU entry
registers in `jt054157`.

## First Bank, K054156

| Byte offset | HDL register | Current HDL interpretation | MAME status |
| --- | --- | --- | --- |
| `0x00` | `reg0_db` | Global/timing control. Bit 4 is H flip, bit 5 is V flip. Other bits feed timing, VRAM strobe, VD latch, and RAM address path controls. | Flip bits match. Other MAME notes are too broad for the extracted K054156 behavior. |
| `0x02` | `reg2_db` | Per-layer flip-enable bitmap. H flip enable uses bits `0/2/4/6`; V flip enable uses bits `1/3/5/7`. | MAME leaves this unknown. |
| `0x04` | `reg4_db` | Tile attribute, LUT/color source, CPU address latch width/shift, and high-output selection control. | MAME's possible bank-count note is too narrow. |
| `0x06` | `reg6_db` | Bits `0/1/2` gate IRQ/FIRQ/NMI. Bit 3 steers VRAM chip select. Bit 4 selects VD byte pair for attribute decode. Bit 5 steers CPU data bus halves. Bits `6/7` select color/attribute sources. | IRQ note matches low bits; attribute note is plausible but incomplete. |
| `0x08` | `reg8_db` | Bits `0..3` are per-layer low CA/VA address-source mode bits. Bits `4..7` are per-layer vertical scroll/size mux enables. | MAME's lower-nibble tile mode is plausible but should be understood as address/source mode. Upper nibble roughly matches synchronous scroll behavior. |
| `0x0a` | `rega_db` | Two bits per layer for line-scroll behavior. Even bits `0/2/4/6` select CPU X-scroll register versus latched line-scroll data. Odd bits `1/3/5/7` control line-scroll tick capture. | Good structural match to MAME's linescroll control. |
| `0x0c` | `regc_db` | CPU/VRAM DB output selection, VRAM strobe selection, RAM address high-bit shift, and active-page/address timing. | MAME's possible bank-size note is too narrow. |
| `0x10,0x12,0x14,0x16` | `reg10_d..reg16_d` | Vertical layer grid/size. Bits `[5:3]` feed `vs_mux`; bits `[2:0]` feed `vb_mux`. | Matches MAME Y position/height notes. |
| `0x18,0x1a,0x1c,0x1e` | `reg18_d..reg1e_d` | Horizontal layer grid/size. Bits `[5:3]` feed `hs_mux`; bits `[2:0]` feed `hb_mux`. | Matches MAME X position/width notes. |
| `0x20,0x22,0x24,0x26` | `reg20_d..reg26_d` | Layer Y scroll registers. | Matches MAME. |
| `0x28,0x2a,0x2c,0x2e` | `reg28_d..reg2e_d` | Layer X scroll registers. | Matches MAME. |
| `0x30` | `reg30_d` | Line-scroll / active-page bank source for VA high bits. | Matches MAME's linescroll RAM bank role. |
| `0x32` | `reg32_d` | CPU-visible VRAM bank source for VA high bits. | Matches MAME's CPU RAM bank role. |
| `0x34` | `reg34l_d`, `reg34u_d` | ROM/checksum bank path. `reg34l_d[0]` feeds `CA11`; `reg34l_d[1:7]` feed `CA12..CA18`; `reg34u_d[0:7]` drive `COL0..COL7` in ROM/checksum mode. | MAME's ROM bank naming is materially correct. |
| `0x36` | `reg36_d` | Two VRC bits only, feeding `pin_vrc[1:0]`. | MAME models four secondary ROM-bank bits; the HDL only supports two bits so far. |
| `0x38` | `reg38_d` | Four-entry tile-bank lookup table. Each entry is four bits selected by tile LUT address bits. | Matches MAME. |
| `0x3a` | `reg3a_d` | HFLIP horizontal correction, gated by global H flip. | Matches newer MAME comments. |
| `0x3c` | `reg3c_d` | VFLIP vertical correction, gated by global V flip. | Matches newer MAME comments. |

Offsets `0x0e` and `0x3e` are unused in the decoded HDL, matching MAME.

## Second Bank, K054157

The second bank is not a copy of first-bank offsets `0x02..0x07`. The HDL
captures only selected low-byte bits in `jt054157_page02_cpu_entry`.

| Byte offset | Captured CPU DB bits | HDL names | Current HDL interpretation |
| --- | --- | --- | --- |
| `0x00` | DB0, DB3, DB4 | `reg0_d0`, `reg0_d3`, `reg0_d4` | Global H offset phase/polarity, page-1 clock fanout reset/enable, and page-9 RAM/readout clock phase selection. |
| `0x02` | DB0, DB2, DB4, DB6 | `reg2_d0`, `reg2_d2`, `reg2_d4`, `reg2_d6` | Per-layer H offset flip enables for HOFSA, HOFSB, HOFSC, and HOFSD. |
| `0x04` | DB3, DB4, DB5, DB6 | `reg4_d3`, `reg4_d4`, `reg4_d5`, `reg4_d6` | RAM/readout/output mux mode, DB output mux selection, and readout/VC direction control. |
| `0x06` | DB5, DB6, DB7 | `reg6_d5`, `reg6_d6`, `reg6_d7` | DB half/byte-lane selection and color/attribute column source selection. |

## MAME Differences

- The MAME comment that second-bank registers `0x02..0x07` copy first-bank
  `0x02..0x07` is wrong for the current K054156/K054157 HDL.
- MAME stores second-bank registers as full 16-bit words, but the HDL captures
  only specific low-byte bits.
- MAME's first-bank `0x36` four-bit secondary ROM bank does not match the HDL,
  which captures only `reg36_d[1:0]`.
- MAME's first-bank `0x08` lower nibble is best described as per-layer
  address/source mode, not just a tilemap dirty flag.

## Source Pointers

- MAME address map: `cores/moo/doc/moo.cpp`, `moo_prot_state::moo_map`.
- MAME device model: `modules/jt05415x/doc/mame/k054156_k054157_k056832.cpp`.
- K054156 register decode: `jt054156_page01_low_reg_wr_decode`,
  `jt054156_page01_reg_wr_decode`, and `jt054156_page02_low_regs`.
- K054156 scroll and bank paths: `jt054156_page05_start_size_mux`,
  `jt054156_page07_xsrc`, `jt054156_page08_scrolly_mux`,
  `jt054156_page10_va_high`, `jt054156_page12_ca_low`, and
  `jt054156_page12_ca_col_high`.
- K054157 second bank: `jt054157_page02_cpu_entry`, page-5 H offset paths,
  page-8 DB output muxes, page-9 RAM/readout control, and page-11 readout
  output paths.
