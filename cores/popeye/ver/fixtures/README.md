# Reproducible Popeye test inputs

`init.go` generates timing-decode fixtures plus distinct synthetic character,
sprite-bitplane and palette patterns in each test's working directory. It is
symlinked as each suite's simunit initializer. The timing fixture describes
the board's 7J decode from address `{HB,H[7:1]}` to serr/VCLK/HSY and the spare
output; the spatial/data patterns are synthetic and include no game ROM data.

The original tests compared with schematic-based circuits from
[jotego/jtpopeye](https://github.com/jotego/jtpopeye), pinned at
`d8e07faf0f3f0af65eb545cdee701659e66b9366`. Those independent test-only modules
are included here with Jose Tejada's original GPL attribution. Adaptations
rename colliding modules, use local generated fixtures and provide the old
RAM/PROM parameter names through `jt2020_shims.v`. The TTL counter/decoder
models come from JTFRAME's `hdl/jt74.v`; the delayed LS74 is in the DMA test.
No unversioned sibling checkout or inaccessible local Git object is needed.

The old timing model's one-bit flip XOR and several asynchronous gate effects
are intentionally preserved as reference behavior; the benches also check
explicit coordinate/pixel expectations rather than accepting equivalence alone.
