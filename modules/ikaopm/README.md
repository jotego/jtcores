# IKAOPM module

This directory contains the synthesizable Verilog sources from
[ika-musume/IKAOPM](https://github.com/ika-musume/IKAOPM), imported from
commit `08a5b40ed14418319287df450f7d4a523ddeed5e`.
The original
license is preserved in [LICENSE](LICENSE), and the original README is copied
to [doc/README.md](doc/README.md).

## JTCORES wrapper

`hdl/jtikaopm.v` wraps the `IKAOPM` module with signal names and
active levels matching the conventions used by `jt51`.
