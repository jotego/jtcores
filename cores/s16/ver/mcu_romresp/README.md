# System 16 MCU ROM-response regression

The 8751 XDATA request and the main-ROM response are separated by the SDRAM
latency.  This test requires the response latch to ignore stale 68000 data
until `rom_ok`, then retain the selected byte for the MCU synchronizer.
