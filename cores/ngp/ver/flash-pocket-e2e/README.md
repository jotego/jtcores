# Pocket cartridge-save end-to-end test

Exercises `jtframe_pocket_cartsave` with the real `jtngp_flash` save client
and synchronous JTFRAME RAM. It checks that an erased missing-file header is
accepted, a compact two-block image loads with the expected byte order, and a
subsequent Pocket read returns the same header and flash bytes.
