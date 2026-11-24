# Mega Zone Timing Reference

Counter mappings and object hardware notes moved from the HDL comments.

## PCB horizontal counter mapping

PCB horizontal counter mapping for normal and flipped display modes.

```verilog
if( flip ) begin
    hn = h < 9'd048 ? 9'd047 - h :
         h < 9'd128 ? 9'd271 - h :
         h < 9'd144 ? 9'd143 - h :
         h < 9'd288 ? 9'd399 - h :
                       9'd399 - h;
end else begin
    hn = h < 9'd048 ? h :
         h < 9'd288 ? h - 9'd032 :
                       h - 9'd160;
end
pcb_hcnt = hn[7:0];
```

## PCB vertical counter mapping

PCB vertical counter mapping for normal and flipped display modes.

```verilog
PCB vcount mapping:
raw vdump 0..255   -> PCB vcount 0..255
raw vdump 256..263 -> PCB vcount 248..255
flip mirrors the final 8-bit PCB vcount with bitwise inversion

if( vdump[8] )
    vsum = vdump[7:0] - 8'd8;
else
    vsum = vdump[7:0];

v_eff = flip ? ~vsum : vsum;
```

## PCB object hardware

### Render RAM scan

Each line, the PCB scans 36 four-byte entries at addresses 0–143, starting
at HCNT=40 and finishing before the next HCNT=40.

The PCB scans forward with selective overwrites. The core scans entries
35–0, using write order to establish priority.

### Object DMA

DMA arms when VBLK goes active, starts one pixel count after HSYNC goes
active, and lasts for 240*4+1 HCNTs. The object RAM and object render RAM
address go from 0 to 240 in that time.

### Object ROM organization

Code bit 7 selects one of two ROM pairs. Each pair outputs
`{byte23, byte01}`.

For one 4-pixel group, MAME's x offsets use bit 0 for pixel 0:

    byte01 = { pl0_px3, pl0_px2, pl0_px1, pl0_px0,
               pl1_px3, pl1_px2, pl1_px1, pl1_px0 }

    byte23 = { pl2_px3, pl2_px2, pl2_px1, pl2_px0,
               pl3_px3, pl3_px2, pl3_px1, pl3_px0 }

Pixels are reconstructed as:

    pxN = { pl3_pxN, pl2_pxN, pl1_pxN, pl0_pxN }

PCB address order inside the selected ROM pair:

    addr[0] = v0
    addr[1] = v1
    addr[2] = v2
    addr[3] = h0
    addr[4] = h1
    addr[5] = v3

### MAME and core ROM layout

MAME flattens the four ROMs into one `gfx1` region:

    gfx1 + 0x0000: byte01 for codes 0x00..0x7f
    gfx1 + 0x2000: byte01 for codes 0x80..0xff
    gfx1 + 0x4000: byte23 for codes 0x00..0x7f
    gfx1 + 0x6000: byte23 for codes 0x80..0xff

`mame2mra` pairs the plane bytes using `width=16, sequence=[0,2,1,3]`:

    word16 = { byte23, byte01 }

In `cfg/mem.yaml`, `gfx_sort: hvvvx` rearranges download addresses so each
32-bit word contains eight adjacent pixels from one row. Sorting is limited
to the object ROM, ending at `SCR_START`. The object drawer uses:

    rom_addr = { code, ysub[3], half, ysub[2:0] }

where half selects the left or right eight-pixel half.  Each response contains
two adjacent four-pixel groups in its lower and upper 16-bit lanes:

    pixels 0..3 = rom_data[15:0]
    pixels 4..7 = rom_data[31:16]

Each response supplies eight horizontal pixels, so a 16-pixel sprite row
requires two requests. Pixels are decoded from byte01/byte23 and written
to a one-line object buffer.
