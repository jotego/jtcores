# Remaining subsystem differences

[Offline dispositions and precise next-session controls](plans/offline-dispositions.md) separate the maximum-off noise correction from three unresolved physical/model differences and reference-only limitations. This report was prepared with the PCB off, using the frozen measurement cases.

The isolated #14 candidate also corrects the supported maximum-off noise behavior. The public suite passes246/246 checks, including exact-zero noise and keyed−9/+8 controls. The [archived recheck](plans/candidate-recheck-results.md) preserves11 unchanged PCM cases and13 original physical duration bands. Commit and archive references are recorded with the isolated correction results. Odd-MUL, relative joint-key phase and high-level contributor sums remain open until their discriminating physical controls are captured. Rastan remains the final compound investigation.

The maximum-off correction and public regression are in [JT51 31c64cf](http://gitea.jotego.es/jotego/jt51/commit/31c64cf19c8cdc669aa7f4b6b7d8a196f50cae3d), together with the seven coordinated #14 corrections. No pitch, phase or high-level gain/accumulator patch was applied.
