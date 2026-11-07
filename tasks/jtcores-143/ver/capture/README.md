Run from jtcores root after sourcing setprj.sh and enabling the documented
Verilator compatibility wrapper:

    simunit-all.sh --only c96_capture

The test uses a 32-word buffer and asynchronous command timing. It checks the
known LFSR vector, buffer boundaries, complete and stopped captures, repeated
arming, immutable completed data, invalid commands, busy rejection, divider
timing and request/reply toggles. It exercises PRNG, raw, PCM and Yamaha through
the same synchronous JTFRAME RAM used in hardware.

Independent pin stimulus encodes the absolute source-word index. Strides 1,2,3
and 1024 must preserve adjacent stereo words and the requested frame spacing.
An odd capture limit verifies bounded partial pairs; reset/ARM clear selection;
STOP is finite, and missing strobes during skipped frames still increment errors.
The long maximum-stride section suppresses waveform dumping to limit artifacts.
Hardware qualification separately exercises the full 64 KiB and long durations.
