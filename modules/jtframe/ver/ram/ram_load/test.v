`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

localparam AW16 = 3;
localparam AW32 = 4;

wire rst, clk;

reg  [AW16:1] s16_addr_le, s16_addr_be;
reg  [AW32-1:2] s32_addr_le, s32_addr_be;
reg  [AW16:1] d16_addr0, d16_addr1;
reg  [AW32-1:2] d32_addr0, d32_addr1;
wire [15:0] s16_q_le, s16_q_be;
wire [31:0] s32_q_le, s32_q_be;
wire [15:0] d16_q0, d16_q1;
wire [31:0] d32_q0, d32_q1;

initial begin
    s16_addr_le = 0;
    s16_addr_be = 0;
    s32_addr_le = 0;
    s32_addr_be = 0;
    d16_addr0 = 0;
    d16_addr1 = 0;
    d32_addr0 = 0;
    d32_addr1 = 0;

    @(negedge rst);
    repeat(2) @(posedge clk);

    check_single16(0, 16'h1110, 16'h1011);
    check_single16(1, 16'h1312, 16'h1213);
    check_single32(0, 32'h13121110, 32'h10111213);
    check_single32(1, 32'h17161514, 32'h14151617);
    check_dual16(0, 3, 16'h1110, 16'h1716);
    check_dual32(0, 1, 32'h10111213, 32'h14151617);

    pass();
end

task check_single16;
    input [AW16:1] addr_value;
    input [15:0] expected_le;
    input [15:0] expected_be;
    string msg;
    begin
        s16_addr_le <= addr_value;
        s16_addr_be <= addr_value;
        @(posedge clk);
        #1;
        msg = $sformatf("jtframe_ram16 little-endian mismatch at %0d: got %04X expected %04X",
            addr_value, s16_q_le, expected_le);
        assert_msg(s16_q_le == expected_le, msg);
        msg = $sformatf("jtframe_ram16 big-endian mismatch at %0d: got %04X expected %04X",
            addr_value, s16_q_be, expected_be);
        assert_msg(s16_q_be == expected_be, msg);
    end
endtask

task check_single32;
    input [AW32-1:2] addr_value;
    input [31:0] expected_le;
    input [31:0] expected_be;
    string msg;
    begin
        s32_addr_le <= addr_value;
        s32_addr_be <= addr_value;
        @(posedge clk);
        #1;
        msg = $sformatf("jtframe_ram32 little-endian mismatch at %0d: got %08X expected %08X",
            addr_value, s32_q_le, expected_le);
        assert_msg(s32_q_le == expected_le, msg);
        msg = $sformatf("jtframe_ram32 big-endian mismatch at %0d: got %08X expected %08X",
            addr_value, s32_q_be, expected_be);
        assert_msg(s32_q_be == expected_be, msg);
    end
endtask

task check_dual16;
    input [AW16:1] addr0_value;
    input [AW16:1] addr1_value;
    input [15:0] expected0;
    input [15:0] expected1;
    string msg;
    begin
        d16_addr0 <= addr0_value;
        d16_addr1 <= addr1_value;
        @(posedge clk);
        #1;
        msg = $sformatf("jtframe_dual_ram16 port0 mismatch at %0d: got %04X expected %04X",
            addr0_value, d16_q0, expected0);
        assert_msg(d16_q0 == expected0, msg);
        msg = $sformatf("jtframe_dual_ram16 port1 mismatch at %0d: got %04X expected %04X",
            addr1_value, d16_q1, expected1);
        assert_msg(d16_q1 == expected1, msg);
    end
endtask

task check_dual32;
    input [AW32-1:2] addr0_value;
    input [AW32-1:2] addr1_value;
    input [31:0] expected0;
    input [31:0] expected1;
    string msg;
    begin
        d32_addr0 <= addr0_value;
        d32_addr1 <= addr1_value;
        @(posedge clk);
        #1;
        msg = $sformatf("jtframe_dual_ram32 port0 mismatch at %0d: got %08X expected %08X",
            addr0_value, d32_q0, expected0);
        assert_msg(d32_q0 == expected0, msg);
        msg = $sformatf("jtframe_dual_ram32 port1 mismatch at %0d: got %08X expected %08X",
            addr1_value, d32_q1, expected1);
        assert_msg(d32_q1 == expected1, msg);
    end
endtask

jtframe_ram16 #(
    .AW         ( AW16           ),
    .SIMFILE    ( "ram_load.bin" ),
    .ENDIAN     ( 0              )
) u_s16_le (
    .clk        ( clk            ),
    .data       ( 16'd0          ),
    .addr       ( s16_addr_le    ),
    .we         ( 2'd0           ),
    .q          ( s16_q_le       )
);

jtframe_ram16 #(
    .AW         ( AW16           ),
    .SIMFILE    ( "ram_load.bin" ),
    .ENDIAN     ( 1              )
) u_s16_be (
    .clk        ( clk            ),
    .data       ( 16'd0          ),
    .addr       ( s16_addr_be    ),
    .we         ( 2'd0           ),
    .q          ( s16_q_be       )
);

jtframe_ram32 #(
    .AW         ( AW32           ),
    .SIMFILE    ( "ram_load.bin" ),
    .ENDIAN     ( 0              )
) u_s32_le (
    .clk        ( clk            ),
    .data       ( 32'd0          ),
    .addr       ( s32_addr_le    ),
    .we         ( 4'd0           ),
    .q          ( s32_q_le       )
);

jtframe_ram32 #(
    .AW         ( AW32           ),
    .SIMFILE    ( "ram_load.bin" ),
    .ENDIAN     ( 1              )
) u_s32_be (
    .clk        ( clk            ),
    .data       ( 32'd0          ),
    .addr       ( s32_addr_be    ),
    .we         ( 4'd0           ),
    .q          ( s32_q_be       )
);

jtframe_dual_ram16 #(
    .AW         ( AW16           ),
    .SIMFILE    ( "ram_load.bin" ),
    .ENDIAN     ( 0              )
) u_d16_le (
    .clk0       ( clk            ),
    .data0      ( 16'd0          ),
    .addr0      ( d16_addr0      ),
    .we0        ( 2'd0           ),
    .q0         ( d16_q0         ),
    .clk1       ( clk            ),
    .data1      ( 16'd0          ),
    .addr1      ( d16_addr1      ),
    .we1        ( 2'd0           ),
    .q1         ( d16_q1         )
);

jtframe_dual_ram32 #(
    .AW         ( AW32           ),
    .SIMFILE    ( "ram_load.bin" ),
    .ENDIAN     ( 1              )
) u_d32_be (
    .clk0       ( clk            ),
    .data0      ( 32'd0          ),
    .addr0      ( d32_addr0      ),
    .we0        ( 4'd0           ),
    .q0         ( d32_q0         ),
    .clk1       ( clk            ),
    .data1      ( 32'd0          ),
    .addr1      ( d32_addr1      ),
    .we1        ( 4'd0           ),
    .q1         ( d32_q1         )
);

jtframe_test_clocks clocks(
    .rst        ( rst            ),
    .clk        ( clk            )
);

endmodule
