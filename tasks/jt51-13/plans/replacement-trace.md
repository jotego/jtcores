# Authorized replacement input

The user authorized recording a new complete Rastan YM2151 register-write
history on 2026-10-18, after confirming that the original CSV location was no
longer known. The original investigation is Gitea jotego/jt51#1; its missing
input was named `rastan-ym2151.csv` and contained 98,880 writes. A new capture
must carry its own identity and must not be represented as the recovered file.

Record every address/data bus transaction and timestamp from the sound CPU,
then derive delta-time/register/value rows. Preserve capture startup time,
ROM identity, MAME executable and source identity, invocation, input actions,
termination reason, counts, and hashes. Check deterministic repeatability.

For #7, #8 and #13, select relevant attack, release and algorithm programs from
the new trace. Compare isolated setup with complete preceding register writes
and delays. A register image or a single previous note is not full history.
Document the timing transformation from Rastan's 4 MHz chip to the measured
3.57–3.58 MHz bench. Characterize physical replay timing before interpreting
transient disagreements. The original trace remains a separate missing input.

The previous task and sealed Drive archive are immutable. New artifacts live
under `tasks/jt51-13/artifacts/` and will be archived in a separate case folder.
