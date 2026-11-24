# Full capture chain

HPS words go through `jtframe_mister_uio`; a real `jtframe_cab_stream`
replay produces the intervals; `jtframe_mister_capture` captures with a
two-pixel video pipeline delay and 40% random DDR stalls. Main's order is
used: CAB ARM, pushes, capture ARM, CAB START. Session 1 captures frame 3,
a frame in the middle and the last frame M, each checked pixel by pixel
against the generator frame drawn in interval N-1, then checks that the frame
count goes on after DONE. Session 2 checks that the CAB ARM clears the frame
number and that a missed last frame shows as the status frame passing M.
