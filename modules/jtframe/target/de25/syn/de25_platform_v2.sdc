# Si5332 I2C is self-timed at 25 kHz. Inputs enter explicit two-register
# synchronizers and outputs are protocol edges, not synchronous data paths.
set_false_path -from [get_ports {SI5332_SCL SI5332_SDA}]
set_false_path -to   [get_ports {SI5332_SCL SI5332_SDA}]
