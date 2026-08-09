# Verilator Cabinet Native Tests

This standalone C++ suite tests the UUT-free cabinet parser/scheduler and
cheat database used by `modules/jtframe/verilator/test.cpp`.

It covers relative and absolute frame timing, loops, blank waits, compact
large repeats, DIP hexadecimal parsing, trace/dump/cheat events, and malformed
cabinet and cheat files.

Run it with:

```bash
make -C modules/jtframe/verilator/tests/cabinet test
```
