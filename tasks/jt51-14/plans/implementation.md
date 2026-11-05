# Joint isolated correction design

Baseline: JT51 985a573dcfc1ff135553a39f7eae21d18ba57cbe. Physical evidence is frozen in the two YM2151 cases documented by jtcores f517d1b7878165b3d85cf69c7c2a2c53115ba4d5. Neither old case is modified. The PCB remains off.

The design preserves the serial operator pipeline, phase generator, logarithmic operator calculation, accumulator and serial conversion. No old Rastan experimental patch or external emulator algorithm is used. Rastan remains the final compound integration investigation, after the isolated cases.

| Requirement | Correction | Interaction / limit |
|---|---|---|
| Sticky timer status creation | Gate new flags by enable; existing flags survive disabling/stopping and clear explicitly | Counter carry remains independent for CSM. IRQ follows sticky flags per Yamaha docs; physical IRQ was not measured. |
| Effective attack RATE30/31 | Correct instant-attack comparison to six-bit RATE62/63 | Preserve attack calculation and entry pipeline. No exact key-on latency claim. |
| Programmed zero AR/D1/D2 | Inhibit before key scaling | Release configuration is odd and remains active. Nonrelease effective RATE0..3 retain the documented hold gate. |
| D1L15 | Use special nominal93dB code31 | Preserve ordinary levels0..14 and current stage comparator. Exact PCM zero is measured; exact analog attenuation is not. |
| Scoped fine D1/D2 steps | Low-group decay uses single attenuation units with twice the counter cadence | Preserve average low-rate progression; high groups12..15 retain existing counter/increments. Broad boundary regressions required. |
| Automatic CSM | Retain written CSM enable; suppress stopped-timer carry output | Preserve normal manual keys, timer flag independence and all32 operator routes. Exact hidden key pulse width unmeasured. |
| Low release RATE2/3 | Enable the release low-group step patterns | Scope to release: no inferred nonrelease low-rate extension. Finite fade, not exact latency or release constant. |
| #16 maximum-off noise | Emit zero at maximum attenuation; preserve all other noise values | Existing physical exact-zero and keyed−9/+8 positive controls support the narrow gate. Do not clamp the entire top attenuation bucket or change the original4PCM screen. |

Independent specification review identified the nonrelease RATE2/3 extrapolation in the first candidate; the final design scopes that correction to release. The first candidate is diagnostic only, not the final source state.

Validation must include public status/output regressions, analytic observer qualification, all32 CSM routes/manual controls, finite low release, exact-zero/low-bit noise controls, archived affected-feature and independent subsystem replays, the existing PM test, shared-core lint and a JT51 consumer FPGA build. No output gain/phase alignment or guard relaxation is permitted.

Remaining odd-MUL, joint-key phase and high-level mixing cases require discriminating physical controls described in jt51-16/plans/offline-dispositions.md. Reference carrier/pan limitations do not prescribe JT51 changes. Rastan has additional accepted-write/epoch/history limits and must not be declared fixed by these corrections.
