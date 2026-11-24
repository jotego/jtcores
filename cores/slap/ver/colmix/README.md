# Colour mixer unit simulation

Checks every layer-enable combination, transparent fixed/object pens,
fixed > object > background priority, both blanking signals, pixel enable,
and all sixteen native PROM values for each 4-bit RGB channel.

Run `simunit-all.sh --only jtslap_colmix` after sourcing `setprj.sh`.
