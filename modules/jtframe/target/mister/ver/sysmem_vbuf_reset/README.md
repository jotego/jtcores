# VBUF user reset / safe terminator

Run with `bash run.sh`. The test models the existing two-stage `sysmem_lite` VBUF reset synchronizer,
including its new `reset_out | vbuf_user_reset` input, and connects the real
`f2sdram_safe_terminator`. It begins a four-beat write, accepts one beat, stalls
the master, then asserts a user reset while global `reset_out` remains low. The
source keeps the accepted Avalon request stable as ascal does during reset.
After the synchronized reset reaches the terminator, the remaining beats must
complete with the original address/count/data before the user side is released.
The test checks the reset stays asserted through drain and that no tail request
appears after drain.
