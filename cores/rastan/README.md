# JTRASTAN FPGA core compatible with the Rastan hardware

You have in your hands a faithful reproduction of Rastan Saga's hardware. We have analysed the PCB and the official schematics. This verilog implementation is compatible with all major retro FPGA platforms, particularly MiSTerFPGA.

You can show your appreciation through
* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate
* Github: https://github.com/sponsors/jotego

## Disclaimer

This work is for research and historical purposes. This work itself does not contain copyrighted software and should not be packed or distributed with illegal copies of the copyright protected software.

## Video Timing

The original clock was based on a crystal oscillator at 26.686MHz. The video chips operate at 13.343MHz and the pixel clock is 6.6715

# Sound

The sound subsystem of Rastan and Operation Wolf boards is quite different. They share the YM2151 but the number and use of PCM chips (MSM5205) is different. The analog signal processing for each output is different too

## Rastan

The FM right/left outputs are added with unity gain, together with the PCM at 1.1x.

The PCM chip has a 4th order filter at 4kHz. We model it with `fir_192k_4k.csv`

## Operation Wolf

There are two MSM5205 chips. They are amplified digitally by a chip labeld as `TC0060DCA`. This chip registers the CPU output with the volume value when the signals VAVOL and VBVOL are set:

- `VAVOL = !mreq_n && A[15:12]==4'b1011 && A[2:0]==5`
- `VBVOL = !mreq_n && A[15:12]==4'b1100 && A[2:0]==5`

`A[15:12]==4'b1011` selects operation for the `VA` MSM5205. `4'b1100` selects the `VB` MSM5205.

The `VA` chip output goes straight into the volume multiplier. Then it goes through a -5dB attenuation network getting merge with the YM2151 output inside HIC-SEIBU, HB-41. Let's assume that HIC-SEIBU simply mixes the channels without adding gain. The output is called MIXOUT in the schematics

The `VB` chip output goes first through three low-pass filters, which are equivalent to a very flat response upto 4kHz and a very sharp decay after that. We model that with `fir_192k_4k.csv` in mem.yaml. The output of `VB` after the filter and the TC0060DCA gain is called `VBOUT`.

The MIXOUT (VA+YM2151) is then added via an opamp. MIXOUT is applied unity gain, and `VBOUT` has a 0.55x gain. Let's call this output `PREAMP=MIXOUT+VBOUT*0.55`

PREAMP goes into a second TC0060DCA, whose gain is programmed when `A[15:12]==4'b1101` for speaker 1 and `A[15:12]==4'b1110` for speaker 2. Which one is left/right is unclear.

The digital amplifier TC0060DCA seems to be a kind of linear-in-db amplifier whose transmission function is documented in `cores/rastan/doc/tc0060dca.cpp`.