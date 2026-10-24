# Unit Simulations

`simunit.sh` runs Verilog/SystemVerilog unit tests that follow the jtframe
unit-test layout. GitHub Actions discovers tests by looking for `.simunit`
files, and the same runner can be used locally.

## Quick Start

From the repository root:

```bash
source modules/jtframe/bin/setprj.sh > /dev/null
simunit.sh --run modules/jtframe/ver/video/framebuf
```

If you are inside the test directory already:

```bash
source ../../../bin/setprj.sh > /dev/null
simunit.sh
```

In CI, `.github/workflows/simunit.yaml` finds every `.simunit` file and runs
each folder through `modules/jtframe/devops/xsimunit.sh`, which sets `JTROOT`,
`JTFRAME`, sources `setprj.sh`, and then calls `simunit.sh --run <folder>`.

## Required Test Layout

Each simunit-compatible test lives in its own folder, usually under a `ver`
directory, for example:

```text
$JTROOT/modules/jtframe/ver/video/framebuf
$JTROOT/cores/thundr/ver/cenloop
```

The folder should contain:

1. `test.v` or `test.sv` defining a module named `test`
2. `gather.f` listing the design files needed by the test
3. `.simunit` so GitHub Actions includes the folder in the unit-sim matrix

Optional files:

1. `init.go` to generate fixtures before the simulation starts
2. `test.gtkw` or a saved `test.lxt` waveform for local debugging
3. `.hex` files referenced from `gather.f`

## What `simunit.sh` Does

For each test folder, the runner:

1. Changes into the requested folder
2. Reads the first line of `.simunit` and treats it as extra command-line
   arguments
3. Runs `go run init.go` if `init.go` exists
4. Expands environment variables inside `gather.f` with `envsubst`
5. Copies any `.hex` files listed in `gather.f` into the run directory and
   removes them from the generated file list
6. Lints the unit under test with Verilator
7. Builds the simulation with Icarus Verilog and runs `sim -lxt`
8. Marks the run as passing only if `sim.log` contains `PASS`

The simulation entry point is always `test`, and the inferred lint top module is
the basename of the first path listed in `gather.f`.

## `gather.f`

`gather.f` is passed through `envsubst`, so paths like `$JTFRAME/...` and
`$JTROOT/...` are valid and commonly used.

Example:

```text
../../hdl/jtthundr_cenloop.v
$JTFRAME/hdl/clocking/jtframe_freqinfo.v
$JTFRAME/hdl/jtframe_bcd_cnt.v
```

Guidelines:

1. Put the unit under test first so the lint top module is inferred correctly
2. List every RTL dependency that is not picked up automatically
3. Use repository-relative paths or `$JTFRAME`/`$JTROOT`
4. Include `.hex` files here if the test needs them copied into the run folder

`simunit.sh` also adds:

1. Every `*.v` and `*.sv` file in the current test folder
2. `$JTFRAME/ver/inc` as an include path
3. `jtframe_vtimer.v`
4. `jtframe_test_clocks.v`
5. `-D SIMULATION`
6. `-D JTFRAME_MCLK=48000000` unless that macro is already provided

## Writing the Testbench

The testbench module must be named `test`.

Most existing tests include the shared helpers in
`$JTFRAME/ver/inc/test_tasks.vh`:

```verilog
module test;

`include "test_tasks.vh"

initial begin
    @(negedge rst);
    // stimulus and checks
    pass();
end

endmodule
```

Two passing styles are used in the tree:

1. Call `pass()` / `fail()` from `test_tasks.vh`
2. Print `PASS` or `FAIL` explicitly and finish the simulation

Only the presence of `PASS` in `sim.log` makes the run succeed.

## `.simunit` Options

An empty `.simunit` file is valid. If the first line is not empty, it is parsed
as extra `simunit.sh` arguments.

Supported options:

1. `--keep` keeps `test.lxt` after a passing run
2. `--run <folder>` overrides the folder to run
3. `--skip` prints `PASS` and exits early when `GITHUB_ACTIONS=true`
4. `--macros A,B,C` runs the same test once per comma-separated macro token

Examples:

```text
--macros JTFRAME_JOY_DURL,JTFRAME_JOY_RLDU
```

```text
--macros JTFRAME_MCLK=49152000
```

When `--macros` is used, the runner prints the macro name before each run and
passes it through as `-D <macro>`.

## Common Patterns

`jtframe_test_clocks` is the simplest way to obtain reset, clock, blanking, and
frame counters in many jtframe tests:

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

Representative examples:

1. `modules/jtframe/ver/video/framebuf`
2. `modules/jtframe/ver/keyboard/joysticks`
3. `cores/thundr/ver/cenloop`
4. `cores/cps2/ver/raster`

## Troubleshooting

If a test is not picked up by GitHub Actions:

1. Make sure the folder contains `.simunit`
2. Make sure `.simunit` is not outside the actual test directory

If Verilator lint fails on the wrong module:

1. Check the first line of `gather.f`
2. Put the UUT source file first

If the simulation passes locally but CI still fails:

1. Run it through `simunit.sh` rather than a custom command
2. Check whether the test depends on generated files that should move into
   `init.go`
3. Check whether `.simunit` should contain `--skip` or `--macros`
