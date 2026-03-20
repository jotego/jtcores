---
name: create unit simulations
description: Build simunit-compatible RTL unit tests under a ver directory so they run both locally and in GitHub Actions
---

# Purpose

Use this guide when creating or updating a unit test that should run through
`modules/jtframe/bin/simunit.sh`.

# Required Files

Create one folder per test, usually under a `ver` directory:

```text
$JTROOT/modules/<module>/ver/<test-name>
$JTROOT/cores/<core>/ver/<test-name>
```

The folder should contain:

1. `test.v` or `test.sv`
2. `gather.f`
3. `.simunit`

Keep `.simunit` empty unless you need one of the options described below.

# Testbench Contract

- The simulation entry module must be named `test`
- The test must emit `PASS` on success
- The test should emit `FAIL` on failure
- `simunit.sh` only marks the run as passing if `sim.log` contains `PASS`

The common pattern is:

```verilog
module test;

`include "test_tasks.vh"

initial begin
    @(negedge rst);
    // drive stimulus
    // check results
    pass();
end

endmodule
```

`test_tasks.vh` is available through the default include path:

```text
$JTFRAME/ver/inc/test_tasks.vh
```

Use `assert_msg`, `pass()`, and `fail()` where they fit. Some tests print
`PASS`/`FAIL` directly instead, which is also valid.

# `gather.f`

`gather.f` lists the RTL sources needed by the test. Important details:

1. The first line should be the source file for the unit under test
2. The basename of that first file becomes the Verilator lint top module
3. Environment variables are expanded with `envsubst`, so `$JTFRAME` and
   `$JTROOT` are safe to use
4. `.hex` files may be listed here; `simunit.sh` copies them into the run
   folder before simulation

Example:

```text
$JTFRAME/hdl/keyboard/jtframe_joysticks.v
$JTFRAME/hdl/keyboard/jtframe_multiway.v
$JTFRAME/hdl/keyboard/jtframe_beta_lock.v
$JTFRAME/hdl/jtframe_edge.v
```

You do not need to add:

1. `test.v` or `test.sv` from the current folder
2. `$JTFRAME/ver/inc`
3. `$JTFRAME/hdl/video/jtframe_vtimer.v`
4. `$JTFRAME/hdl/ver/jtframe_test_clocks.v`

`simunit.sh` adds those automatically.

# `.simunit`

An empty `.simunit` file is enough to include the test in GitHub Actions.

If the first line contains text, it is parsed as extra `simunit.sh` arguments.
Supported patterns already used in the tree:

1. `--macros JTFRAME_JOY_DURL,JTFRAME_JOY_RLDU`
2. `--macros JTFRAME_MCLK=49152000`
3. `--skip`
4. `--keep`

Use `--macros` when the same testbench should run multiple compile-time
variants. Each comma-separated token becomes a separate `-D` define.

# Optional `init.go`

If the test needs generated input data, add `init.go` in the test folder.
`simunit.sh` runs:

```bash
go run init.go
```

before linting and simulation. Use this for generated ROM data, lookup tables,
or other deterministic fixtures that should not be checked in as static files.

# Clocking and Helpers

Prefer `jtframe_test_clocks` when it gives the signals your test needs. This is
the simplest way to get reset, clock, and frame timing.

Example:

```verilog
jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .lhbl       (               ),
    .lvbl       ( lvbl          ),
    .framecnt   ( framecnt      )
);
```

If the block needs a non-default master clock, set it through `.simunit`:

```text
--macros JTFRAME_MCLK=49152000
```

# Authoring Checklist

1. Put the test in its own folder under `ver`
2. Name the testbench module `test`
3. Put the UUT source first in `gather.f`
4. Make the test print or call `PASS`
5. Add `.simunit`
6. Add `.simunit` options only when required
7. Run the test with `simunit.sh` before relying on CI

# Running the Test

From the repository root:

```bash
source modules/jtframe/bin/setprj.sh > /dev/null
simunit.sh --run modules/jtframe/ver/video/framebuf
```

From inside the test folder:

```bash
source ../../../bin/setprj.sh > /dev/null
simunit.sh
```

For core tests, source the same `setprj.sh` from the repository root and run:

```bash
simunit.sh --run cores/thundr/ver/cenloop
```

# Examples

Use these folders as references:

1. `modules/jtframe/ver/video/framebuf`
2. `modules/jtframe/ver/keyboard/joysticks`
3. `modules/jtframe/ver/ram/ioctl_dump`
4. `cores/thundr/ver/cenloop`
5. `cores/cps2/ver/raster`
