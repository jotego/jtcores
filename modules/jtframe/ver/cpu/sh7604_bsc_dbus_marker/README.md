# SH7604 BSC DBUS Read Marker Unit Test

This test checks that `BUS_DBUS_RD` marks the full DBUS external read cycle,
including the return-data setup window after the external read strobes are
released. CPS3 uses that marker to keep SH-2 DMA BIOS reads on the raw data
path while normal CPU BIOS reads may be decrypted.
