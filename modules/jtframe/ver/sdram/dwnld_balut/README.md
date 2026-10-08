# jtframe_dwnld BALUT Decode Test

This simunit test checks the BALUT header offset byte ordering used by
`jtframe_dwnld`. It drives two instances:

- `BALUT_REVERSE=0`, matching headers whose offset words are stored high/low
- `BALUT_REVERSE=1`, matching headers whose offset words are stored low/high

The test uses small LUT-shifted bank thresholds so it can verify bank selection
without an SDRAM controller.
