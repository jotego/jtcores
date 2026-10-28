# 511-pixel capture SPI regression

This actual-pin `user_io`/capture/RAM integration test streams every packed
RGB444 byte from a 511-pixel row through 24 MHz SPI, checks the independent
pixel packing oracle for all three rows and both BRAM banks, retries partial CS,
and leaves SCK stopped after BEGIN while rows publish.
