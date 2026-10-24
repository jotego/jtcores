# T80 interrupt and bus timing

This simunit exercises the public pins of the T80S used by `jtframe_z80` without changing production RTL. Short ROM programs use `jtframe_ram` clocked from `~clk`; its synchronous read data settles on the CPU's falling edge before the next rising-edge sample, so the model adds no CPU T-state. The bench covers NMI, IM0/1/2, EI/DI/RETN/RETI, IFF restoration, HALT, OTIR interruption, CEN, WAIT, BUSRQ, and interrupt arrival around an indexed instruction.

Run from the project root after sourcing `modules/jtframe/bin/setprj.sh`:

```sh
cd modules/jtframe/ver/cpu/t80_interrupts
simunit.sh --run .
```

The test writes `test.lxt` as a VCD waveform. To emit the shared replay format, compile the source list in `gather.f` and pass `+TRACE=<path>`. Each CSV row records inputs sampled before a rising edge and public outputs after `#1 ns`; see the task artifact case sidecar for reset-delimited cases.

The independent documented oracle is Zilog, *Z80 CPU User Manual*, UM008011-0816 (2016), [official PDF](https://www.zilog.com/docs/z80/um0080.pdf): pp. 12–14 for bus cycles and interrupt acknowledge, pp. 17–19 for IFF and EI/NMI behavior, pp. 184–187 for IM0/1/2, p. 288 for RETI, and p. 311 for OTIR. The test measures enabled-clock intervals between public M1-start edges separately from sampled public-pin edge placement. It does not claim analog or board-level timing fidelity.
