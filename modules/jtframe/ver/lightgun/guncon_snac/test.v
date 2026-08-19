`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

reg        clk = 1'b0;
reg        rst = 1'b1;
reg        enable = 1'b0;
reg        frame_sync = 1'b0;
reg        data_in = 1'b1;
reg        ack_in = 1'b1;
wire       select1_n, select2_n, command, serial_clk;
wire       p1_connected, p1_strobe, p1_aim_valid;
wire [9:0] p1_x;
wire [7:0] p1_y;
wire       p1_trigger, p1_start, p1_button, p1_select;
wire       p2_connected, p2_strobe, p2_aim_valid;
wire [9:0] p2_x;
wire [7:0] p2_y;
wire       p2_trigger, p2_start, p2_button, p2_select;

reg [7:0] response1 [0:8];
reg [7:0] response2 [0:8];
reg [7:0] host1 [0:8];
reg [7:0] host2 [0:8];
integer device_port, device_byte, device_bit;
reg ack_p1 = 1'b1;
reg ack_p2 = 1'b1;

always #5 clk = ~clk;

jtframe_guncon_snac #(
    .HALF_PERIOD     ( 16'd4 ),
    .SELECT_DELAY    ( 16'd2 ),
    .ACK_TIMEOUT     ( 16'd32 ),
    .INTERBYTE_DELAY ( 16'd2 ),
    .DESELECT_DELAY  ( 16'd4 )
) uut(
    .clk         ( clk         ),
    .rst         ( rst         ),
    .enable      ( enable      ),
    .frame_sync  ( frame_sync  ),
    .data_in     ( data_in     ),
    .ack_in      ( ack_in      ),
    .select1_n   ( select1_n   ),
    .select2_n   ( select2_n   ),
    .command     ( command     ),
    .serial_clk  ( serial_clk  ),
    .p1_connected( p1_connected),
    .p1_strobe   ( p1_strobe   ),
    .p1_aim_valid( p1_aim_valid),
    .p1_x        ( p1_x        ),
    .p1_y        ( p1_y        ),
    .p1_trigger  ( p1_trigger  ),
    .p1_start    ( p1_start    ),
    .p1_button   ( p1_button   ),
    .p1_select   ( p1_select   ),
    .p2_connected( p2_connected),
    .p2_strobe   ( p2_strobe   ),
    .p2_aim_valid( p2_aim_valid),
    .p2_x        ( p2_x        ),
    .p2_y        ( p2_y        ),
    .p2_trigger  ( p2_trigger  ),
    .p2_start    ( p2_start    ),
    .p2_button   ( p2_button   ),
    .p2_select   ( p2_select   )
);

task pulse_ack;
begin
    repeat (2) @(posedge clk);
    ack_in = 1'b0;
    repeat (6) @(posedge clk);
    ack_in = 1'b1;
end
endtask

task frame_pulse;
begin
    @(posedge clk);
    frame_sync = 1'b1;
    @(posedge clk);
    frame_sync = 1'b0;
end
endtask

task wait_p1;
    integer timeout;
begin
    timeout = 0;
    while (!p1_strobe && timeout < 30000) begin
        @(posedge clk);
        timeout = timeout + 1;
    end
    assert_msg(p1_strobe, "timed out waiting for P1 poll");
end
endtask

task wait_p2;
    integer timeout;
begin
    timeout = 0;
    while (!p2_strobe && timeout < 30000) begin
        @(posedge clk);
        timeout = timeout + 1;
    end
    assert_msg(p2_strobe, "timed out waiting for P2 poll");
end
endtask

task load_guncon;
    input integer player;
    input [8:0] x;
    input [8:0] y;
    input [7:0] buttons0;
    input [7:0] buttons1;
begin
    if (player == 1) begin
        response1[0] = 8'hff;
        response1[1] = 8'h63;
        response1[2] = 8'h5a;
        response1[3] = buttons0;
        response1[4] = buttons1;
        response1[5] = x[7:0];
        response1[6] = {7'd0, x[8]};
        response1[7] = y[7:0];
        response1[8] = {7'd0, y[8]};
    end else begin
        response2[0] = 8'hff;
        response2[1] = 8'h63;
        response2[2] = 8'h5a;
        response2[3] = buttons0;
        response2[4] = buttons1;
        response2[5] = x[7:0];
        response2[6] = {7'd0, x[8]};
        response2[7] = y[7:0];
        response2[8] = {7'd0, y[8]};
    end
end
endtask

always @(negedge select1_n) begin
    device_port = 1;
    device_byte = 0;
    device_bit = 0;
end

always @(negedge select2_n) begin
    device_port = 2;
    device_byte = 0;
    device_bit = 0;
end

always @(negedge serial_clk) begin
    if (!select1_n) begin
        data_in = response1[device_byte][device_bit];
        host1[device_byte][device_bit] = command;
    end else if (!select2_n) begin
        data_in = response2[device_byte][device_bit];
        host2[device_byte][device_bit] = command;
    end
end

always @(posedge serial_clk) begin
    if (!select1_n || !select2_n) begin
        if (device_bit == 7) begin
            if (device_byte < 8 && ((device_port == 1 && ack_p1) ||
                                    (device_port == 2 && ack_p2))) fork
                pulse_ack();
            join_none
            device_byte = device_byte + 1;
            device_bit = 0;
        end else begin
            device_bit = device_bit + 1;
        end
    end
end

initial begin
    load_guncon(1, 9'h12a, 9'h090, 8'hf6, 8'h9f);
    load_guncon(2, 9'h04d, 9'h019, 8'hff, 8'hff);
    repeat (4) @(posedge clk);
    rst = 1'b0;
    enable = 1'b1;

    wait_p1;
    assert_msg(p1_connected && p1_aim_valid, "P1 GunCon was not detected");
    assert_msg(p1_x == 10'd588 && p1_y == 8'd136, "P1 coordinates are incorrect");
    assert_msg(p1_trigger && p1_start && p1_button && p1_select,
               "P1 GunCon buttons were not decoded");
    assert_msg(host1[0] == 8'h01 && host1[1] == 8'h42,
               "P1 host command is incorrect");

    wait_p2;
    assert_msg(p2_connected && p2_aim_valid, "P2 GunCon was not detected");
    assert_msg(p2_x == 10'd0 && p2_y == 8'd0, "P2 minimum coordinates are incorrect");
    assert_msg(host2[0] == 8'h01 && host2[1] == 8'h42,
               "P2 host command is incorrect");

    ack_p1 = 1'b0;
    frame_pulse;
    wait_p2;
    assert_msg(!p1_connected && !p1_aim_valid, "P1 ACK timeout kept stale state");
    ack_p1 = 1'b1;

    load_guncon(1, 9'h001, 9'h00a, 8'hff, 8'hdf);
    frame_pulse;
    wait_p1;
    assert_msg(p1_connected && !p1_aim_valid,
               "Off-screen GunCon coordinates were accepted");

    pass();
end

endmodule
