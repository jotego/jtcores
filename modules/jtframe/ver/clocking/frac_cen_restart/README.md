# frac_cen_restart

Checks that `jtframe_frac_cen` restarts its counters when `rst` falls: after
each reset, released at a different phase, the `cen`/`cenb` sequence matches the
one after power-up. It also checks that `cen` keeps running during reset and
that its average rate is N/M. The counters restart one clock cycle after the
release, because `rst` is registered first, and no `cen` or `cenb` pulse is
visible in that cycle.
