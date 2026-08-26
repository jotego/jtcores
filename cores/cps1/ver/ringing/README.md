# JT6295 ringing regression

This simunit test starts a synthetic OKI6295 phrase through the normal CPU,
ROM and serializer interfaces.  The phrase contains only `0xff` bytes, as in
the Gulun.Pa failure reported in jtcores #1017.  It rejects the decoder's
`-863, -2048, +2047` saturation limit cycle that produces audible ringing.
