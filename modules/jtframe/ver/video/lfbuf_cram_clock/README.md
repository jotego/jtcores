# Pocket LF buffer clock regression

Runs the actual Cell RAM wrapper at ~100.6 MHz with related, aligned producer
clocks at ~50.3 MHz and ~100.6 MHz. Video has six active lines and eight/sixteen
producer clocks per pixel. NOMAIN skips the frame-count startup delay, but the
real configuration bus sequence is exercised.

Checks both configuration words and the asynchronous write timing in ns,
complete physical write addresses/data, sparse reuse of both line banks,
known scanout data/address alignment, pixel-enable event counts, and lossless
acknowledgements on both phases of the 2:1 clock ratio. The pin-level memory
model alternates initial WAIT latency to change the completion phase and uses
jtframe_dual_ram storage. It does not model board propagation delays; these
must be checked with the Pocket SDC and release-build timing analysis.
