# Full capture chain

HPS words go through `jtframe_mister_uio`; a real `jtframe_cab_stream`
replay produces the interval counters; `jtframe_mister_capture` captures with
a two-pixel video pipeline delay and 40% random DDR stalls. Three captures are
checked pixel by pixel against the generator frame that carried each tag: one
armed before CAB START, one in the middle of the replay and one on the final
checkpoint, after the replay reaches DONE.
