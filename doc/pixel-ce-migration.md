# Pixel enable migration notes

This records the core-side choices made while moving renderer pixel enables to
the framework `pxl_cen` / `pxl2_cen` inputs. `JTFRAME_PXLCLK` selects the
nominal pixel cadence; it does not promise the same edge phase as a core's
former local divider. In particular, the old `jtframe_cen48` outputs and the
framework pixel enables have matching rates but different steady-state phases.
The old `jtframe_cen48` chain also asserted its 12, 6, 3 and 1.5 MHz enables
together at startup. When a `jtframe_gated_cen` chain replaces a local divider,
its CPU enables can have different startup and absolute phase relative to the
pixel clock even when their steady-state relationships to one another remain
preserved. Consumers that need the ordinary CPU, sound or timer cadence
therefore retain their former clock-enable source unless the pixel-only divider
could be removed without changing those consumers.

The migration does not claim that the pixel pulse coincides with any retained
CPU or sound enable. The affected video and bus paths were reviewed for such a
requirement; pixel timing changes are instead validated with core boot and
video simulations. Shared H/V timer consumers in Btiger and Commando now use
the same framework pixel enable as their renderers.

| Core(s) | Pixel cadence | Retained local timing |
|---|---:|---|
| 1942, Commando | 6 MHz nominal | Keep the existing `mem.yaml` generated enable chain for CPU, sound and related logic; renderers take framework pixel inputs. |
| Trojan | 6 MHz nominal | Remove unused un-gated `cen12/cen6/cen3/cen1p5` and `cen8` outputs; the old video `cen3`/`cen8` inputs are unused. Retain gated `cpu_cen1p5/cpu_cen3/cpu_cen6/cpu_cen12` for MCU, main CPU and sound consumers, plus `cenp384` for sound. Renderers use framework pixel inputs. |
| Black Tiger, Exed Exes, Section Z | 6 MHz nominal | Keep `jtframe_cen48` and its non-pixel enables; renderers take framework pixel inputs. Black Tiger's 3.579545 MHz sound enable also remains in use. |
| Hcastle, Contra, Combat School, Fast Lane, Labyrinth Runner, MX5000 | 6 MHz nominal | Remove the local divider where it only generated renderer pixel enables. Retain independent `clk24` CPU/sound enables. Fast Lane keeps the shared `jtframe_cen48` file because its main module uses the 3.579545 MHz enable. |
| Rastan / Rainbow Islands | About 6.67 MHz physical (`JTFRAME_PLL=jtframe_pll6671`) | Target-dependent PLL generation gives about 53.37 MHz `clk_rom`; the fixed /8 and /4 dividers produce about 6.67/13.34 MHz. Replace the local fractional renderer divider; its former `n=1,m=4` waveform matches the framework divider. |
| Rumble | 8 MHz nominal | Use framework pixel inputs; preserve the configured 4/2 MHz and 8 MHz related enable cadences. The 2 MHz sound enable remains unchanged. |
| NARC | 16 MHz nominal from 96 MHz | Remove the redundant 32/16 MHz `mem.yaml` generator; keep the independent `clk24` sound enables. NARC requires MiSTer DDR3 video RAM and has no supported SiDi/SiDi128 target. |
| Kyukyoku Tiger, Wardner | 7 MHz physical | MiSTer gets 7 MHz from `JTFRAME_PXLCLK=6` with its 56 MHz `clk_rom` (divider 8). SiDi128 keeps native 7 MHz enables from its 49 MHz clock; the framework's fixed /8 divider would produce 6.125 MHz. KTiger selects framework pixels only for MiSTer; Wardner uses the same 56/8 setting there. |

The measured `jtframe_cen48` comparison at 48 MHz demonstrates why equal rates
do not imply equal phase: the old 6 MHz enable first asserts at sampled cycle 1,
while the compared fractional 6 MHz sequence first asserts at cycle 4; both
repeat every 8 cycles after startup, a 3-cycle steady phase offset. The old 8
MHz enable first asserts at cycle 1 and the compared fractional sequence at
cycle 3; both repeat every 6 cycles, a 2-cycle offset. The old 12 MHz enable
first asserts at cycle 1 and the compared fractional sequence at cycle 4; both
repeat every 4 cycles, a 3-cycle offset. Samples are taken on falling edges
after rising-edge logic has settled. These measurements describe those
generators and sampling convention, not a universal phase guarantee for every
PLL or target. The comparison is reproducible from the phase harness in the
issue validation archive.

This phase movement is intentional: renderer timing moves to the framework
pixel domain while ordinary CPU/audio enables keep their old cadence. Consumers
that need coherent video timers now use the same pixel enable as their
renderers. Rastan's former fractional divider is an exception: its complete
pixel waveform matched the framework sequence over 2048 cycles.
