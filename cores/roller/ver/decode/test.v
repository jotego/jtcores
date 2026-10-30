`timescale 1ns/1ps

module test;

reg         as_n, g18p7;
reg  [19:0] addr;
wire        cs1_n, rom_oe_n, data_oe_n;
wire        pal12_n, ccu_n, pal14_n, objset_n;
wire        objoe_n, pal17_n, obj_cs_n, objse_n;
wire [ 3:0] rom_ab;

jtroller_decode uut(
    .as_n      ( as_n      ),
    .addr      ( addr      ),
    .g18p7     ( g18p7     ),
    .cs1_n     ( cs1_n     ),
    .rom_ab    ( rom_ab    ),
    .rom_oe_n  ( rom_oe_n  ),
    .data_oe_n ( data_oe_n ),
    .pal12_n   ( pal12_n   ),
    .ccu_n     ( ccu_n     ),
    .pal14_n   ( pal14_n   ),
    .objset_n  ( objset_n  ),
    .objoe_n   ( objoe_n   ),
    .pal17_n   ( pal17_n   ),
    .obj_cs_n  ( obj_cs_n  ),
    .objse_n   ( objse_n   )
);

task check;
    input [19:0] a;
    input bank;
    input [7:0] selected;
begin
    addr=a;
    g18p7=bank;
    as_n=0;
    #1;
    if ({!pal12_n,!ccu_n,!pal14_n,!objset_n,
         !objoe_n,!pal17_n,!obj_cs_n,!objse_n} !== selected) begin
        $display("FAIL: F12 at %05x bank %b",a,bank);
        $finish;
    end
end
endtask

initial begin
    // F12 partitions the 0000-1fff region by A12:A8; A10 is ignored.
    check(20'h00000,0,8'b1000_0000);
    check(20'h004ff,0,8'b1000_0000);
    check(20'h00100,0,8'b0100_0000);
    check(20'h005ff,0,8'b0100_0000);
    check(20'h00200,0,8'b0010_0000);
    check(20'h006ff,0,8'b0010_0000);
    check(20'h00300,0,8'b0001_0000);
    check(20'h007ff,0,8'b0001_0000);
    check(20'h00800,0,8'b0000_0100);
    check(20'h00fff,1,8'b0000_1000);
    check(20'h01000,0,8'b0000_0010);
    check(20'h017ff,1,8'b0000_0010);
    check(20'h01800,0,8'b0000_0001);
    check(20'h01fff,1,8'b0000_0001);
    check(20'h02000,0,8'b0000_0000);
    if (cs1_n !== 0) begin $display("FAIL: work RAM select"); $finish; end

    // F11 maps fixed ROM at 8000-ffff to the top 32 KiB of the 128 KiB ROM.
    check(20'h08000,0,0);
    if (rom_ab !== 4'b1100 || rom_oe_n !== 0 || data_oe_n !== 1) begin
        $display("FAIL: fixed ROM base"); $finish;
    end
    check(20'h0c000,0,0);
    if (rom_ab !== 4'b1110) begin $display("FAIL: fixed ROM upper half"); $finish; end
    check(20'h04000,0,0);
    if (rom_oe_n !== 0 || data_oe_n !== 1) begin
        $display("FAIL: banked ROM select"); $finish;
    end
    check(20'h00000,0,8'b1000_0000);
    if (rom_oe_n !== 1 || data_oe_n !== 0) begin
        $display("FAIL: ROM enabled in I/O space"); $finish;
    end

    as_n=1;
    #1;
    if (!cs1_n || {pal12_n,ccu_n,pal14_n,objset_n,
                    objoe_n,pal17_n,obj_cs_n,objse_n} !== 8'hff) begin
        $display("FAIL: /AS does not suppress chip selects"); $finish;
    end
    $display("PASS");
    $finish;
end

endmodule
