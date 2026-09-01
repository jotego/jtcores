/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_objrom_latches(
    input             clkobj,
    input      [31:0] x_data,
    input      [31:0] y_data,
    input       [3:0] set_n,
    output     [15:0] objromd
);

reg [15:0] x_hi, x_lo, y_hi, y_lo;

always @(posedge clkobj) begin
    x_hi <= {x_data[31:24],x_data[23:16]};
    x_lo <= {x_data[15:8],x_data[7:0]};
    y_hi <= {y_data[31:24],y_data[23:16]};
    y_lo <= {y_data[15:8],y_data[7:0]};
end

assign objromd = !set_n[0] ? x_hi :
                 !set_n[1] ? x_lo :
                 !set_n[2] ? y_hi :
                 !set_n[3] ? y_lo : 16'hffff;

endmodule
