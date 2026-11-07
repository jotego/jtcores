# JT8051 instruction vectors

`tests.yaml` contains readable 8051 assembly and expected architectural state
after each instruction. Its `init.go` first generates the JT8051 control ROM,
then uses `modules/jt8051/testgen` and `as31` to produce a program binary and
Verilog boundary checks. `test.v` evaluates every `check` after the matching
`next_instruction` pulse.

Run it with:

```sh
source setprj.sh
simunit.sh --run modules/jt8051/ver/vectors
```

Set `JT8051_VECTOR` to select another YAML group, for example:

```sh
JT8051_VECTOR=divide simunit.sh --run modules/jt8051/ver/vectors
```

Run every readable vector group, including all opcode aliases and flag
matrices, with:

```sh
source setprj.sh
cd modules/jt8051/ver/vectors
bash run_all.sh
```
