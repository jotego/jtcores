# jtframe_reset first download

The game must stay in reset after the FPGA starts until a first download ends:
the SDRAM holds stale data before it, and a game running from it leaves RAM and
register contents that the game reset does not clear. The test checks that
`game_rst` stays high with no download, that it is released after the first
download ends, and that a later download without `ioctl_rom` (a cartridge) does
not reset the game again.
