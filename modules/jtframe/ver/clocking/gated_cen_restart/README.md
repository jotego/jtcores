# jtframe_gated_cen restart

Two `jtframe_gated_cen` instances with a fractional ratio leave reset at
different times. The test checks that their cen pulses follow the same pattern
counted from the reset release seen by the game. The game gets its reset
through `jtframe_rsthold`, one clock after the `jtframe_gated_cen` reset, as
in `game_sdram.v`. So a game starts with the same cen phase in
every run.
