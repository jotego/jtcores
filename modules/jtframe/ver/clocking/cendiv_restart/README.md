# cendiv_restart

Checks that `jtframe_cendiv` restarts its divider when `rst` falls. The input
clock enable is gated by the reset, as in `jtcus30`, so the old divider kept
the phase it had when the reset came. After each reset, which comes at a
different phase, the `cen_div`/`cen_da` sequence must match the one after the
first reset. It also checks that `cen_div` divides `cen_in` by MDIV.
