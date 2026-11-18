# Actual-ascal frame capture simulation

`sim.sh` snapshots the production `ascal.vhd`, adversarial Avalon memory model, and testbench, records their SHA-256 hashes, and compiles those copies with GHDL 2008. It exercises progressive video with capture enabled and disabled, capture backpressure, coalesced half acknowledgements, and write collision recovery.

The ordinary-image test checks scaler writes, Avalon burst behavior and every visible RGB byte in all three slots. The 87×9 raster has a 512-byte pitch and crosses word and burst boundaries. The double buffer starts with defined zero contents; subsequent row padding can contain bytes from earlier writes.

With no capture commands, the suite also compares the actual active video
output with capture enabled and disabled, both without stalls and with
periodic Avalon backpressure. It requires a minimum number of nonblack samples
before comparing the streams.

Capture tests use actual native frame boundaries and an independent frame manifest. While the selected slot is held, the test checks visible RGB and independently hashes all committed payload words, including row padding, against the GFW1 descriptor hash. It also swaps committed bursts and rows and checks that the hash changes while the additive sum does not. The descriptor CRC and target burst count are checked separately. READY follows acceptance of every target write and ordered half acknowledgements; it does not guarantee that an external DDR observer has already seen every write. The receiving software checks its copied payload against the checksum and retries mismatches while ownership remains valid.

The writer leases two half buffers until their last-beat acknowledgements return. A one-bit order tag distinguishes the at most two outstanding writes, including across frame boundaries. Directed tests cover coalesced acknowledgements, last-beat stalls, attempted reuse of each leased half, reset, fault cleanup and repeated captures. The native 256-byte scaler header still precedes pixel data; capture does not write a DDR metadata header or issue a pixel-readback scan.

These simulations do not establish physical HPS mapping attributes, timing margin, or hardware repeatability. Interlaced capture remains unsupported.

Run `./sim.sh [output-directory]` from any directory. GHDL output and frozen source hashes remain in that directory.
