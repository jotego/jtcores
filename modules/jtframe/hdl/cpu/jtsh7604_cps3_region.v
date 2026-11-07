/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jtsh7604_cps3_region(
    input               en,
    input               redearth,
    input       [18:2]  addr,
    input       [ 2:0]  region,
    input       [31:0]  din,
    output      [31:0]  dout
);

localparam [16:0] CPS3_REGION_STD = 17'h07fb2, // 0x1fec8 >> 2
                  CPS3_REGION_RED = 17'h07fb6; // 0x1fed8 >> 2

wire        region_en;
wire [ 2:0] region_code;

assign region_en   = en && region != 3'd7 &&
                     addr == (redearth ? CPS3_REGION_RED : CPS3_REGION_STD);
assign region_code = region + 3'd1;
assign dout        = region_en ? { din[31:3], region_code } : din;

endmodule
