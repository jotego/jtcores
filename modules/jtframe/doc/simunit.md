# Unit Tests

You can build unit tests for modules and have them run automatically as a GitHub action. Follow these steps:

1. Tests go into the ver folder of each core `$JTROOT/cores/core-name/ver/test-name`
2. The folder must contain a test.v (or test.sv) file that defines a **test** module
3. Other files to include in the simulation must be listed in the file **gather.f**
4. The test must print out "PASS" and exit with code 0 or "FAIL" and exit with code 1
5. Create a file called **.simunit** so the test is included in the automatic runs

The jtframe_test_clocks module provides basic clocks for the test:

```
jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .lhbl       (               ),
    .lvbl       ( lvbl          ),
    .framecnt   ( framecnt      )
);
```

See examples in `$CORES/fround/ver/0078x_dma`
