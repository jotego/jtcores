# Toki sound interrupt controller test

This simunit test checks the Seibu sound interrupt behavior used by Toki and
Cabal. It covers RST18 priority over RST10, preservation of simultaneous
requests, a second CPU request queued while RST18 is in service, an FM request
held through RST10 EOI, one event for a held CPU trigger, a new CPU edge on the
same clock as interrupt acceptance, and MAME's `0x00` spurious-acknowledge
response.
