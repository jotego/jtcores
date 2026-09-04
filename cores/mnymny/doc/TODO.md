# TODO

## Schematic-exact object engine (after first boot)

Handoff prompt:

> Replace the behavioural object path (jtmnymny_obj.v scanner + jtframe_objdraw)
> with the real 1B11140 object engine. Everything needed is in this repo:
>
> **Sources**
> - doc/sch/money_money.pdf pages 5 (sheet 3/5: line buffers), 6 (sheet 4/5:
>   control + object RAM), 7 (sheet 5/5: phase muxes). Digest with IC roles:
>   doc/sch/1b11140-video.md.
> - doc/pld/equations.md: dumped and pin-mapped equations for the two
>   sequencers 6J (CONTROL LOGIC 1) and 6K (CONTROL LOGIC 2). Transcribe them
>   as combinational modules (all outputs enabled; i<n> = pin level, polarity
>   per the pin tables there).
>
> **Structure to implement (sheets 3/4)**
> - Object RAM 1L/1M (the objram BRAM) is read out through 1J LS241 as the
>   HPLA0..7 stream; 1P/1N LS157 mux CPU/video addresses (BIT80, A0DES/A1DES/
>   A2DES slot sequencing from 2K LS157 + 3F LS08).
> - Two ping-pong halves: position counters 7G/8G and 8H/7H (LS161) preset
>   from HPLA (sprite X), loaded by /CNTLDT1//CNTLDT2, cleared by /CNTCLR,
>   counted at 6MHz; LS86 banks 7F/8F and 8J/7J XOR the counter into the
>   2148H line buffer addresses (7E/7D and 7K/7L), write strobes /CST1//CST2
>   from the 6F/6G/8K/8L gates, read/write phase R//WT1 R//WT2 from 6K pins
>   17/12 via 5K+6L with /6MHz.
> - Attribute pipeline: 4J LS373 (PAP0..3), 3K LS377/3J LS374 (COL1..6, CF1..4,
>   LDCOL3H strobe), 4K LS175 (HHHx), 6P//ABT flop, 6N SELECT chain, 6M
>   /ABLOAD//CNTLD flops — sheet 4 bottom.
> - 6J outputs drive the counter loads (/CNTLDT1/2, /CNTLD, /CNTCLR, LDCOL3H,
>   /YA //YB, /BIT80); 6K produces /COLL1 (collision), /VPL, /OBDLOUT,
>   CKOKVER, /LPREPF, /LPFMSW, WT1/WT2. Use the dumped equations verbatim and
>   cite "doc/pld/equations.md" in a one-line comment per module.
>
> **8C/8N 82S100 PLAs (still undumped)**
> - They map latched buffer pixels + SELECT/256Hx/ABDISP1/2/SELOBJ/VBLANK to
>   X1OUT..X6OUT / COLOUT1..6 (palette address, sheet 1 9E/9D muxes) and
>   /X123 //X456 (priority, into 6K pins 8/11). Implement a guess as
>   jtmnymny_82s100.v with the exact pin interface from sheet 3 (8C pins:
>   in 6,5,4,26,25,24 = x1'..x6', out 15,13,12,18,17,16 = X1..X6OUT etc)
>   so a real dump can replace the guts 1:1.
> - Guess logic from MAME behaviour: buffer pixel non-zero wins over
>   background (SELOBJ), pass order priority sr1[0]>sr0>sr1[0x20] equals
>   "second buffer over first" per the ABDISP phase; /X123 //X456 signal
>   "pixel group non-zero" back to 6K. Validate against the behavioural
>   renderer frame-by-frame (jtframe sim + frame dumps, compare PNGs).
>
> Wire the new engine behind a macro (e.g. MNYMNY_OBJSCH) so both paths
> build until the schematic one matches.

## Other pending items

- TMS5200 speech: stubbed in jtmnymny_snd.v (no model in repo).
- Analog filters (rullante/cassa/basso/piano/tromba) + LS156 attenuator:
  move the crude mixer in jtmnymny_game.v to a mem.yaml audio: section
  with the RC values from audio sheet 2/3.
- flip_y row math in the scroll shim is unverified.
- MRA header byte for the Jack Rabbit sets (different protection PAL —
  current jtmnymny_prot.v equations are from the Money Money dump).
- NVRAM: only 7400-77FF is battery backed on the PCB (6514s); the core
  saves the whole 2KB wram. Harmless, but could split.

## compare original videos

https://www.youtube.com/watch?v=DPv9WxUmAOs