# DDR mux: ROM loader and capture writer

`jtframe_mr_ddrmux` between the real DDR ROM loader (`jtframe_mister_dwnld`)
and a video client that behaves like the capture writer (32-beat bursts, lock
held from the first beat to the last). The DDR model has random `busy` and
delayed read data. One run per `{DDRLOAD, VERTICAL}` = 00, 01, 10, 11; the mux
is included from `test.v` so that the variant macros reach it.

Checks: a ROM load requested during a capture burst waits for the burst to
end; after `ioctl_rom` falls the loader releases the port within 50 cycles and
the next capture burst lands in the slot; every loader byte is the right ROM
byte; reads happen only at loader addresses, one per page; every capture beat
reaches its address once, with its data. Without DDRLOAD the loader never gets
the port.
