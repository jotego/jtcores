/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

// Capture the 68k-ROM response for the 8751 only when the SDRAM interface
// marks it valid.  cpu_din is a registered bus value and can still contain
// the preceding CPU access on that edge; rom_din is the valid combinational
// ROM/decryption output.
module jts16_mcu_romresp(
    input              rst,
    input              clk,
    input              mcu_bus,
    input              rom_ok,
    input              LDSn,
    input       [15:0] rom_din,
    output reg  [ 7:0] mcu_din
);

always @(posedge clk, posedge rst) begin
    if (rst)
        mcu_din <= 8'h00;
    else if (mcu_bus && rom_ok)
        mcu_din <= LDSn ? rom_din[15:8] : rom_din[7:0];
end

endmodule
