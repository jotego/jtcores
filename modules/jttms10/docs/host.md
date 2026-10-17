# Synchronous host boundary

`jttms10_host.v` implements the four host-visible register transactions in
the `clk` domain. Its `host_req`, `host_we`, `host_reg[1:0]`, `host_be[1:0]`,
and `host_wdata[15:0]` inputs represent a host-pin cycle **already converted**
to a synchronous held request. The direct host request is accepted once until
`host_req` falls; `host_ack` pulses on acceptance and `host_rdata` captures the
old selected register contents. `host_busy` remains high while a triggered
indirect local-word cycle is pending. A new direct HSTCTL request is accepted
during that cycle without changing its captured address, data, or INCW decision.
HSTADRL, HSTADRH, and HSTDATA requests wait for the cycle to finish. This
follows TI User's Guide §10.3.2 (printed pp. 10-8–10-9): an HSTCTL access has
only a one-to-two-local-clock HRDY wait even if a preceding indirect cycle is
active, while the other registers wait for local completion. The older
`modules/tms34010/rtl/host/tms34010_host_if.sv` gates all host accepts on its
idle state, so it differs from that primary rule. The asynchronous physical HCS/HREAD/
HWRITE/HRDY timing and clock-domain crossing are not implemented here; NARC
ties the synchronous request inactive.

Register selection is 0 HSTADRL, 1 HSTADRH, 2 HSTDATA, 3 HSTCTL. Byte enables
select the low and high byte independently. HSTADRL forces address bits 3:0
to zero. The HSTCTLH.LBL bit chooses the last byte of each host transfer:
with LBL=0, upper HSTADRH completes an address and upper HSTDATA completes
data; with LBL=1, lower HSTADRL and lower HSTDATA are last. Writing the last
address byte starts a local read at the newly merged pointer to prefetch
HSTDATA. Reading the last HSTDATA byte returns the old buffer and starts a
new local read; INCR=1 advances the pointer by 16 bit addresses **before**
that read. Writing the last HSTDATA byte starts a local write using the merged
buffer; INCW=1 advances the pointer by 16 only **after** completion. These
rules follow the 1988 TI TMS34010 User's Guide §§6 and 10 and the GPL
`modules/tms34010/rtl/host/tms34010_host_if.sv` reference.

`jttms10_io` owns the I/O page and instantiates this host engine. The engine
owns HSTADRL/HSTADRH/HSTDATA storage; both CPU and host-indirect I/O accesses
use that same storage. Completed CPU writes to those registers update it
without launching an indirect cycle. An indirect client may target the I/O
page, including the host registers, and writes commit only on the selected
physical cycle's `host_mem_ack`. Such writes do not recursively launch another
host cycle. Host direct HSTCTL writes pass to the I/O page on host acceptance.
The low-byte ownership is complementary: host writes MSGIN, sets INTIN with
one, and clears INTOUT with zero; CPU writes MSGOUT, clears INTIN with zero,
and sets INTOUT with one. Both may write the defined high-byte fields. A host
INTIN set and CPU INTOUT set win simultaneous opposite clears.

`jttms10_bus` places the held host-indirect client after DRAM refresh and
before an unreserved CPU request. An already selected cycle is never
interrupted; a CPU partial-word RMW reservation beats the host client. Host
I/O reads carry a grant-time snapshot of `host_mem_io_rdata` as NARC kind 5,
and host I/O writes use kind 6. The bus returns `cyc_rdata` and one
`host_mem_ack` on physical completion. The held client must drop its request
after acknowledgement before another identical transaction.

The integrated directed test uses a delayed NARC target and checks direct
host byte ordering, address-completion prefetch, HSTDATA's old-buffer read,
INCR-before-read, INCW-after-write, CPU writes without local side effects,
HSTCTL per-side ownership and HIP/HINT, indirect I/O targeting HSTCTL and all
three host registers, no recursive cycle, and host priority over a pending
CPU request. It also stalls an indirect write, verifies HSTCTL reads and
writes acknowledge before local completion, proves HSTADR/HSTDATA stay blocked,
and checks that changing INCW cannot alter the captured write:

```sh
iverilog -g2005 -s test -o /tmp/jttms10-host-test \
  modules/jttms10/ver/host/test.sv \
  modules/jttms10/hdl/jttms10_fabric.v \
  modules/jttms10/hdl/jttms10_io.v \
  modules/jttms10/hdl/jttms10_host.v \
  modules/jttms10/hdl/jttms10_bus.v \
  modules/jttms10/hdl/jttms10_video.v \
  modules/jttms10/hdl/jttms10_refresh.v
vvp /tmp/jttms10-host-test
```
