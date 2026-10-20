# Timer flag conformance probe

Run from the jtcores root after sourcing `setprj.sh`:

```
bash tasks/jtcores-143/ver/timer_flags/sim.sh
```

This standalone probe drives the public timer inputs and checks both
status flags and the active-low interrupt. It verifies:

* Overflow while IRQEN is clear leaves the corresponding status flag clear.
* IRQEN permits new overflow flags, and disabling it preserves an existing flag
  and interrupt until F RESET clears the flag.
* Flags are independent and combine into IRQ; clearing one leaves the other.
* F RESET has priority over overflow and works without a clock enable.
* Counter load, automatic reload, stopped counters, and changed reload values.
* Timer A periods at multiple preloads and Timer B's divide-by-16 period.
* CEN and ZERO pause counting and the Timer B prescaler.
* Timer A overflow remains available while its status flag is inhibited, as
  required by the separate CSM overflow path.

The Yamaha YM2151 application notes, printed pages 12–13 (PDF pages 13–14), define
IRQEN as inhibiting the overflow flag register, LOAD as starting/stopping the
counter, and F RESET as clearing its flag. Diet Go Go PCB measurements for
jtcores issue 143 confirm disabled-overflow suppression and sticky status across
disabling/stopping. IRQ persistence is cross-checked against independently
reviewed Nuked-OPM and MAME ymfm behavior; no physical IRQ wire was captured.
No third-party implementation code is included here. This probe currently
reports known conformance failures against unchanged jt51 commit
`985a573dcfc1ff135553a39f7eae21d18ba57cbe`. Its nonzero exit is intentional evidence
of those mismatches; it has no `.simunit` marker and is excluded from normal CI.
The runner retains each log and waveform in a fresh directory under
`artifacts/timer-flags-probe` and prints the directory name.

Timer A's ZERO ticks correspond to 64 input master clocks in the full chip;
Timer B divides this by 16. This test checks periods in those logical ticks.
It does not change or establish exact CPU-write-to-first-overflow timing.
Counter storage is initialized through the public LOAD path after reset, since
the existing implementation does not reset that storage. This isolates the
specified steady counting and flag behavior from stale pre-reset counts.

Source review supporting the expected flag behavior:

* Nuked-OPM commit `a0ab44be60cb28b68431779829454ddf3284f272` exposes timer control,
  status and IRQ through `OPM_Write`, `OPM_Read` and `OPM_ReadIRQ`.
  `OPM_DoTimerA2`/`OPM_DoTimerB2` gate new status flags with IRQEN, retain old flags
  until clear/reset, and `OPM_DoTimerIRQ` combines the latched status flags.
* MAME ymfm `fm_engine_base::engine_timer_expired` gates new status with the
  OPM register accessors `enable_timer_a/b` (reg 14 bits 2/3).
  `engine_check_interrupts` combines the stored status using a fixed timer mask;
  OPM's inherited `status_mask()` is zero. Disabling IRQEN therefore preserves
  an already-latched IRQ in both independent models.
* jt51's public `jt51_timers` interface already separates LOAD, IRQEN, F RESET,
  flags, Timer A overflow, and active-low IRQ. Its current sub-timer always
  records overflow, then its wrapper masks IRQ with IRQEN. This accounts for
  disabled-overflow status flags and the loss of IRQ when disabling an existing
  flag. The probe deliberately leaves that implementation unchanged.
