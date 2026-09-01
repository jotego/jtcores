/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_objbus_data(
    input      [15:0] main_d,
    input             ce_n,
    output     [15:0] lutd
);

assign lutd = ce_n ? 16'hffff : {main_d[7:0],main_d[15:8]};

endmodule
