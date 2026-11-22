# CPS1 TAS and memory acknowledgement regression

Run with `simunit.sh --run cores/cps1/ver/tas_dtack` after sourcing
`setprj.sh`. The fx68k executes consecutive `tas.b` instructions on both byte
lanes of work RAM and video RAM. The real CPS1 memory requesters and SDRAM
controller/model or video RAM perform the accesses. The test checks the TAS
strobe/DTACK gap, the write acknowledgement, SDRAM slot acceptance, the
unchanged byte, and the following CPU readback.

The test initializes SDRAM and VRAM directly and disables the work-RAM reset
erase in a generated copy to keep startup short. It does not replace testing
arbitration, all memory response delays, or a complete game.
