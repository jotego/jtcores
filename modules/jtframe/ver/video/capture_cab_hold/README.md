# Capture and CAB hold-boundary regression

Runs the capture controller and real CAB stream from its command interface on
the same native LVBL. It checks capture entry into CAB hold, ABORT just after a
native boundary, suppression of the CAB stream's delayed synchronized tick, and
resume on the next eligible boundary.
