# Compact TMS34010 peripheral page

`jttms10_io.v` is a standalone 16-bit physical-word I/O page. It decodes bit
addresses `C0000000` through `C00001FF` (`word_addr[8:4]` selects the register).
The surrounding arbiter must present a held request and pulse `word_ack` once
when its physical cycle completes. A write commits on
`word_req && word_we && word_ack && is_io`; `io_rdata` is the combinational
internal word for a kind-5 I/O read. The arbiter still owns the CPU's read
acknowledgement and the NARC kind-5/kind-6 cycle. The field adapter owns
partial and cross-word field accesses. `nmi_clear` is the CPU interrupt-entry
completion pulse; `wvp_set` is the graphics window-violation event.

`jttms10_video.v` runs timing counters on `vclk_cen`, but consumes completed
HCOUNT/VCOUNT/DPYADR writes and `screen_ack` on any `clk`. Its screen request
and SRFADR/DPYTAP/ORG payload remain held until `screen_ack`. The arbiter must
acknowledge that request once, then wait for `screen_req` to drop before
accepting a new request. `refresh_req` from `jttms10_refresh.v` is a one-clock
event, so the arbiter must capture its row and `refresh_cbr` until service.
Screen refresh has priority over DRAM refresh and CPU memory cycles. A CPU
partial-word read/write reservation and HOLD restart belong to the bus arbiter,
not this I/O page.

The I/O page resets ordinary registers to zero. HSTCTLH.HLT samples active-low
`hcs_n`: low selects self bootstrap (HLT=0), high selects host-present halt.
CONTROL masks bits 1:0; DPYCTL masks bit 1; DPYTAP masks bits 15:14; INTENB
keeps only bits 1, 2, 9, 10, 11; HSTCTLH keeps bits 8, 9, 11–15. Locations
17h–1Ah read zero and ignore writes. HCOUNT, VCOUNT, DPYADR, and REFCNT read
their live counters. INTPEND bits 1/2 reflect synchronized active-low input
levels; bit 9 reflects HSTCTLL.INTIN; DIP/WVP bits 10/11 latch hardware events,
clear only on a write of zero, and hardware set wins a same-clock clear.
Interrupt priority is host, display, window, INT1, INT2; the CPU must apply
ST.IE to `irq_pending`. NMI is independent of ST.IE and HLT. CPU writes to
HSTCTLL preserve host-owned MSGIN, clear INTIN on zero, write MSGOUT, and set
INTOUT on one. HSTADRL forces its low four bits to zero.

The synchronous host-register and indirect-word engine is implemented in
`jttms10_host.v`, instantiated by this I/O page; see [host.md](host.md).
Physical asynchronous host-pin timing is a separate boundary. NARC ties
the synchronous host request inactive. External sync is accepted here but
the NARC wrapper only uses HS/VS/HBLANK/VBLANK; sync output-enable pins are
not exposed.

TI User's Guide section 9.10.1 (pages 9-20/9-21) resolves an apparent
shortcut in the chapter 6 wording: with ORG=0, software loads the one's
complement of the desired start address. The *stored* DPYADR.SRFADR then
decrements after each completed refresh in either ORG mode. ORG=0 inverts the
stored SRFADR at the local-bus pins, giving an effectively increasing screen
address. `screen_srfaddr` carries raw stored bits; NARC applies
`org ? srfaddr : ~srfaddr`. CPU readback is raw DPYADR. This follows the old
GPL `tms34010_display_addr.sv` and is tested in both ORG modes.

The implementation translates behavior from the GPL
`modules/tms34010/rtl/io/tms34010_io_regs.sv`,
`modules/tms34010/rtl/video/tms34010_video.sv`,
`modules/tms34010/rtl/video/tms34010_display_addr.sv`, and
`modules/tms34010/rtl/video/tms34010_refresh.sv`; its source of architectural
meaning is the 1988 TI TMS34010 User's Guide sections 6, 8, 9, and 11.3.
Focused standalone verification:

```sh
iverilog -g2012 -s test -o /tmp/jttms10io-test.vvp \
    modules/jttms10/ver/io/test.sv modules/jttms10/hdl/jttms10_io.v \
    modules/jttms10/hdl/jttms10_host.v modules/jttms10/hdl/jttms10_video.v \
    modules/jttms10/hdl/jttms10_refresh.v
vvp /tmp/jttms10io-test.vvp
```
