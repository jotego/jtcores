# MiSTer video clock measurement

After sourcing `setprj.sh` from the worktree root and pinning JTROOT/JTFRAME/
CORES/MODULES/JTBIN/RLS/MRA/ROM to that tree, run `sim.sh local`. It checks
`video_calc` progressive and two-field interlaced counts, a divided pixel enable,
stable held values and timing changes. A separate real `hps_io` instance receives
the video-info command `0x23` over asynchronous system, video and 100 MHz
reference clocks; words 19/20 are checked above bit 21, along with representative
existing words. The independent reference count is also used for a bounded
known-clock PHASE_INC calculation.
