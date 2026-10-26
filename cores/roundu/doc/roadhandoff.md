# Road math investigation

Investigate how the original Round Up 5 road hardware positions and scales its two pixel strips. Ask Andrea for the relevant schematic pages if they are not available; trace the actual counters, arithmetic, timing, and edge behavior before proposing a hardware-faithful implementation. Compare it with MAME's `draw_road` in `~/develop/mame/src/mame/tatsumi/roundup5.cpp`, whose road model is marked unfinished. Pay particular attention to rounding, signed shifts, zero scale, wrapping, and strip boundaries.

The current implementation is `cores/roundu/hdl/jtroundu_road.v` (commit `54620f67b`). A Quartus report for the preceding implementation showed −45.202 ns setup slack through its combinational road divider. The current version divides sequentially during horizontal blanking and advances pixel positions with accumulators. Its visible-line arithmetic was compared with the preceding implementation using Verilator; this establishes equivalence to that model, not to the board. Check a new Quartus timing report before claiming timing closure. Temporary comparison material is under `cores/roundu/ver/roundup5/scratch/road-timing/`.

Recommend the simplest timing-safe implementation supported by the schematics, and validate any behavior changes against board evidence and MAME scenes. Keep temporary experiments in `scratch` and follow the repository instructions.

Suggested skill: `jtcore-start` for core bring-up and verification guidance.
