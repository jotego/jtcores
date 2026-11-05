# Single-row INFO checkpoint regression

This test selects CAB checkpoint 2000, publishes and consumes the only row,
waits through drain release, then requests INFO. It verifies INFO still reports
the frame that produced the row even though CAB ownership has ended and the live
local frame counter has advanced.
