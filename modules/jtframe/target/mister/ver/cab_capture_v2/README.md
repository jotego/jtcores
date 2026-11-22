# MiSTer CAB playback v2

This simunit drives the MiSTer CAB UIO wrapper directly. It validates the v2
CAPS packet, compact ARM/PUSH/PUSH_DIP payloads, two event queue entries,
native frame completion, DIP override validity through natural DONE and its
clear at DONE, coherent status refresh, and the 32-byte snapshot fields. The
shared CAB stream's legacy parameter path remains covered by its existing
target simulations.
