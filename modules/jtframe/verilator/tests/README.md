# JTFRAME Verilator Native Tests

Run every standalone C++ test suite with:

```bash
make -C modules/jtframe/verilator/tests test
```

These tests do not build a game core or require Verilator. They cover pure
components used by the shared whole-core Verilator harness.
