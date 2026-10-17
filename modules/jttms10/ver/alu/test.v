`timescale 1ns/1ps

module test;
    reg [31:0] a, b;
    reg [3:0] op;
    reg cin;
    wire [31:0] result;
    wire n, z, c, v;
    integer checks;

    jttms10_alu dut(
        .a(a), .b(b), .op(op), .cin(cin),
        .result(result), .n(n), .z(z), .c(c), .v(v)
    );

    task check;
        input [3:0] selected_op;
        input [31:0] source, destination, expected;
        input carry_in, expected_c, expected_v;
        begin
            op = selected_op;
            a = source;
            b = destination;
            cin = carry_in;
            #1;
            if ({result,n,z,c,v} !==
                {expected,expected[31],(expected == 32'd0),expected_c,expected_v}) begin
                $display("FAIL op=%0d a=%08x b=%08x cin=%b: result=%08x nzcv=%b%b%b%b expected=%08x nzcv=%b%b%b%b",
                    op,a,b,cin,result,n,z,c,v,expected,expected[31],
                    (expected == 32'd0),expected_c,expected_v);
                $fatal(1);
            end
            checks = checks + 1;
        end
    endtask

    initial begin
        checks = 0;
        check( 0,32'h12345678,32'hffffffff,32'h12345678,0,0,0);
        check( 1,32'h00000001,32'hffffffff,32'h00000000,0,1,0);
        check( 1,32'h00000001,32'h7fffffff,32'h80000000,0,0,1);
        check( 2,32'h00000000,32'hffffffff,32'h00000000,1,1,0);
        check( 3,32'h00000001,32'h00000000,32'hffffffff,0,1,0);
        check( 3,32'hffffffff,32'h7fffffff,32'h80000000,0,1,1);
        check( 4,32'h00000000,32'h00000000,32'hffffffff,1,1,0);
        check( 4,32'h00000001,32'h00000002,32'h00000001,0,0,0);
        check( 5,32'hff00ff00,32'h0f0f0f0f,32'h0f000f00,0,0,0);
        check( 6,32'hff00ff00,32'h0f0f0f0f,32'h000f000f,0,0,0);
        check( 7,32'hff00ff00,32'h0f0f0f0f,32'hff0fff0f,0,0,0);
        check( 8,32'hff00ff00,32'h0f0f0f0f,32'hf00ff00f,0,0,0);
        check( 9,32'h00000000,32'h00000000,32'hffffffff,0,0,0);
        check(10,32'h00000000,32'h00000000,32'h00000000,0,0,0);
        check(10,32'h00000001,32'h00000000,32'hffffffff,0,1,0);
        check(10,32'h80000000,32'h00000000,32'h80000000,0,1,1);
        check(11,32'hffffffff,32'h00000000,32'h00000001,0,0,0);
        check(11,32'h80000000,32'h00000000,32'h80000000,0,0,1);
        check(12,32'h80000001,32'h00000000,32'h00000002,0,1,0);
        check(13,32'h80000001,32'h00000000,32'h40000000,0,1,0);
        check(14,32'h80000001,32'h00000000,32'hc0000000,0,1,0);
        check(15,32'h80000001,32'h00000000,32'h00000003,0,1,0);
        $display("PASS: %0d ALU boundary checks", checks);
        $finish;
    end
endmodule
