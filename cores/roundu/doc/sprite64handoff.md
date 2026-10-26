# Sprite ROM 64-bit read investigation

Investigate combining Round Up 5's `sprites_l` and `sprites_h` ROM data into one interleaved SDRAM region with a 64-bit read, rather than the current two 32-bit buses. Determine whether JTFRAME's memory generator, SDRAM controller, cache and ROM loading support this efficiently on the target FPGA. Check `cores/roundu/cfg/mem.yaml`, `cores/roundu/cfg/mame2mra.toml`, `cores/roundu/hdl/jtroundu_obj.v`, and the matching MAME sprite layout.

Work out the exact byte and word ordering, address mapping, bank selection, ROM padding and download format. Verify that all sprite data and rendering results remain correct, including rotated sprites. Measure whether the wider read reduces stalls or instead wastes bandwidth when only one half is needed; compare cache usage, BRAM cost and suitable SDRAM burst lengths. Consider prefetching the next sprite while drawing the current one.

Keep temporary tests in `cores/roundu/ver/roundup5/scratch/`. Report measured tradeoffs and compatibility before choosing an implementation; validate changes with sprite tests and scene replay. Follow the repository instructions.

Suggested skill: `jtcore-start` for ROM layout and core verification guidance.
