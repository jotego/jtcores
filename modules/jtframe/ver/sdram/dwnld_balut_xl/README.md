# jtframe_dwnld BALUT XL test

Checks `jtframe_dwnld` bank-table decoding when `XL=1`. The test writes a
9-entry `header.offset` table, verifies banks 0-7, checks the second-SDRAM chip
address bit for banks 4-7, and verifies that entry 8 selects the PROM path.
