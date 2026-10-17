# Integrated CPU and NARC cycle boundary

`jttms10_system.v` connects the microcoded `jttms10_word` CPU and its field
adapter to `jttms10_fabric`. The field adapter emits held physical 16-bit
requests with **bit addresses**. The fabric performs I/O/video/refresh/host
arbitration and presents the existing NARC `cyc_*` cycle kind, address,
payload, IAQ, screen, and DRAM-row signals. An external NARC cycle controller
still supplies `cyc_ack` and `cyc_rdata`, including timed I/O cycles.

The fabric's prioritized `irq_pending` and 32-bit `irq_vector` go to the CPU's
maskable interrupt entry. `nmi_pending` and `nmi_nmim` go to its NMI entry;
the CPU's `nmi_clear` pulse returns to HSTCTLH. HSTCTLH.HLT controls
`halt_req`, and the separate `emu_run` input and `emu_ack` output expose the
processor's EMU/RUN boundary. `hcs_n` is sampled by the I/O block at reset:
a host-present value of one sets HLT until a direct synchronous host HSTCTL
write releases it. The host request/ack ports are synchronous; physical
asynchronous HCS/HREAD/HWRITE/HRDY timing and clock crossing remain outside
this wrapper.

`cen` enables CPU microinstruction execution, while the fabric, host, bus,
and field response handling remain in `clk`. `vclk_cen` advances video
counters; I/O commits and screen acknowledgements are handled on every core
clock. HOLD passes to the arbiter and its `word_restart` pulse returns to the
field adapter so an interrupted partial-word RMW rereads fresh memory data.
CPW and CVXYL use the implied B registers and the fabric's PSIZE/CONVDP taps.
The [pixel tag path](pixel-bus.md) connects the CPU through the word wrapper
to the fabric, with SRT classification and partial-field RMW sequencing.
The CPU drives that tag low until pixel instruction microcode is added;
`wvp_set` is also tied low. `jttms10_pixel.v` remains a standalone processing
helper until graphics microcode and field scheduling are added.

The focused system bench runs a real program through the CPU, field adapter,
fabric, and a waiting NARC target. A host-present reset allows the reset-vector
transaction to finish but holds instruction retirement; a host HSTCTL write
releases the CPU. The program sets INTENB, enables video,
and sets ST.IE; one video tick latches display IRQ. The CPU enters the display
vector, saves PC/ST, executes a handler that clears INTPEND.DIP, and returns
with RETI. The bench checks the vector read count, stack order, restored PC/ST,
three single-commit I/O writes, and no repeated IRQ after return. It uses only
new `jttms10` modules at runtime:

```sh
bash modules/jttms10/ver/build.sh /tmp/jttms10-system-build
iverilog -g2005 -s test -I /tmp/jttms10-system-build \
  -o /tmp/jttms10-system-test \
  modules/jttms10/ver/system/test.sv modules/jttms10/hdl/*.v
(cd /tmp/jttms10-system-build && vvp /tmp/jttms10-system-test)
```
