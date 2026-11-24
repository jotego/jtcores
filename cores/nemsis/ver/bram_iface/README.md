# Nemesis BRAM interface regression

Checks the core-local palette/video BRAM adapters against the original byte
lane behavior while using JTFRAME's dual-port RAM models for storage and
synchronous read timing. It covers the six generated memory layouts, top
addresses, palette and VRAM byte strobes, four character RAM lanes, CPU half
selection, and concurrent renderer reads.
