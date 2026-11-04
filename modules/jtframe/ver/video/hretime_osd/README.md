# Native OSD and analog retiming

Tests s18 (320/424, DIV=8), Run and Gun (416/512, DIV=12), and CPS3 (384/455, DIV=14) horizontal timing, plus a 256-pixel-wide profile where the menu fills the screen. The vertical period is shortened. `.simunit` runs all four profiles.

The VGA OSD consumes the native pixel enable. Alternating bitmap columns expose repeated or skipped font pixels; a solid box cannot detect that problem. The scoreboard checks each emitted retimer pixel against the composed input sequence and requires exactly 256 OSD pixels before and after retiming, including bypass and all 16 scale encodings. The physical porch budget can truncate the game's far-right edge at extreme stretch, but must not truncate the centered menu.

The test models FPGA zero power-up for legacy OSD geometry registers. It enables the high-resolution 128-line menu, waits for geometry to settle, then tests individual rows to keep simulation time bounded. Native game RGB/DE/sync are delayed by four pixels to align with the bitmap. The four-clock enable delay matches the final OSD output pipeline. A numbered background also checks that game pixels outside the OSD retain their coordinates.
