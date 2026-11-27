# restart

Checks that jt5232 sounds the same every time it leaves reset. The chip plays
some notes, including noise notes, for a different time before each reset, which also lasts a different
time. After each reset the same register writes must give the same `snd1` and
`snd2` sequence as after the first reset. This catches dividers, envelope clocks,
tone counters or noise generators that keep their state through the reset.
