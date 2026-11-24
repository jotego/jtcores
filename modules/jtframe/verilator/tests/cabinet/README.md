# Verilator Cabinet Native Tests

This standalone C++ suite tests the UUT-free cabinet parser/scheduler and
cheat database used by `modules/jtframe/verilator/test.cpp`.

It covers relative and absolute frame timing, loops, blank waits, compact
large repeats, DIP hexadecimal parsing, trace/dump/cheat events, and malformed
cabinet and cheat files.

The golden vectors in `vectors/` are shared with the Go reader in
`modules/jtframe/src/jtutil/regression/cab.go`. Each `ok-*.cab` has an
`ok-*.expect` file with `capture <n|->`, `frames <count>` and one line per run
after merging equal neighbours: `<count> <inputs hex> <dipsw hex|->
<t|-><d|-> <cheats|->`. Each `bad-*.cab` has a `bad-*.expect` file holding
`error <line>`.

Run it with:

```bash
make -C modules/jtframe/verilator/tests/cabinet test
```
