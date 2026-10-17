Run after sourcing jtcores/setprj.sh:

    simunit.sh --run "$HOME/SiliconRE/Konami/054539/chameleon96/ver/capture"

The test uses a 32-word buffer and asynchronous command timing. It checks the
known LFSR vector, buffer boundaries, complete and stopped captures, repeated
arming, immutable completed data, invalid commands, busy rejection, divider
timing and request/reply toggles. RAM is the same synchronous JTFRAME primitive
as the hardware. Hardware qualification separately exercises the full 64 KiB.
