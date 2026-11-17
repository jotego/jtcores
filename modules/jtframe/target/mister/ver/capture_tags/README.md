# MiSTer capture tag source

This simunit checks interval-index tagging from the real CAB frame-start and
raw LVBL falling edge, with native checkpoint N identifying interval N-1. It
checks delayed DONE/STOP mailbox acknowledgements followed by IDLE/ARMED/RUNNING
before checkpoint 1 is reused on a fresh run, sticky overflow on a held tag,
and discontinuity detection. The fault flags remain asserted until a new
IDLE-to-ARMED lifecycle tuple is acknowledged; a failed or unacknowledged run
cannot clear them. The tag output is the
single ascal-owned async FIFO's ready/valid write interface; this module has no
token FIFO and never stalls native video.
