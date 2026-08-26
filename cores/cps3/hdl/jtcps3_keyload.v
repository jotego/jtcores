/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

module jtcps3_keyload(
    input               clk,
    input               header,
    input               prog_we,
    input       [ 4:0]  prog_addr,
    input       [ 7:0]  prog_data,
`ifdef CPS3_CPU_TEST
    input       [ 2:0]  cputest_crypt_mode,
`endif
    output reg  [31:0]  cps3_key1,
    output reg  [31:0]  cps3_key2,
    output reg  [ 2:0]  cps3_crypt_mode,
    output reg          cps3_region_redearth
);

localparam [2:0] CPS3_CRYPT_ALT    = 3'b001,
                 CPS3_CRYPT_NONE   = 3'b010,
                 CPS3_CRYPT_NORMAL = 3'b100;

`ifdef CPS3_CPU_TEST
reg [31:0] cpu_test_key1;
reg [31:0] cpu_test_key2;

initial begin
`ifdef CPS3_CPU_TEST_KEY1
    cpu_test_key1 = `CPS3_CPU_TEST_KEY1;
`else
    cpu_test_key1 = 32'd0;
`endif
`ifdef CPS3_CPU_TEST_KEY2
    cpu_test_key2 = `CPS3_CPU_TEST_KEY2;
`else
    cpu_test_key2 = 32'd0;
`endif
    if( $value$plusargs("cps3_key1=%h", cpu_test_key1) )
        $display("CPS3_CPU_TEST cps3_key1=%08X", cpu_test_key1);
    if( $value$plusargs("cps3_key2=%h", cpu_test_key2) )
        $display("CPS3_CPU_TEST cps3_key2=%08X", cpu_test_key2);
    if( cpu_test_key1 != 32'd0 || cpu_test_key2 != 32'd0 )
        $display("CPS3_CPU_TEST ROM keys cps3_key1=%08X cps3_key2=%08X",
            cpu_test_key1, cpu_test_key2);
end
`endif

reg       key_we;
reg [3:0] addr_l;
reg [7:0] data_l;

initial begin
    cps3_key1             = 32'd0;
    cps3_key2             = 32'd0;
    cps3_crypt_mode       = CPS3_CRYPT_NONE;
    cps3_region_redearth = 1'b0;
end

always @(posedge clk) begin
    key_we <= header && prog_we && prog_addr[4];
    addr_l <= prog_addr[3:0];
    data_l <= prog_data;
end

always @(posedge clk) begin
`ifdef CPS3_CPU_TEST
    cps3_key1 <= cputest_crypt_mode == CPS3_CRYPT_NONE ? 32'd0 : cpu_test_key1;
    cps3_key2 <= cputest_crypt_mode == CPS3_CRYPT_NONE ? 32'd0 : cpu_test_key2;
    cps3_crypt_mode <= cputest_crypt_mode;
`else
    if( key_we ) begin
        case( addr_l )
            4'h0: cps3_key1[31:24] <= data_l;
            4'h1: cps3_key1[23:16] <= data_l;
            4'h2: cps3_key1[15: 8] <= data_l;
            4'h3: cps3_key1[ 7: 0] <= data_l;
            4'h4: cps3_key2[31:24] <= data_l;
            4'h5: cps3_key2[23:16] <= data_l;
            4'h6: cps3_key2[15: 8] <= data_l;
            4'h7: cps3_key2[ 7: 0] <= data_l;
            4'h8: cps3_crypt_mode  <= data_l[2:0];
            4'h9: cps3_region_redearth <= data_l[0];
            default:;
        endcase
    end
`endif
end

endmodule
