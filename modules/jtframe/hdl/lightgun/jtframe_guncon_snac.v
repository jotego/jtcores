/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    PlayStation GunCon polling through the MiSTer PSX SNAC adapter. */

module jtframe_guncon_snac #(
    parameter [15:0] HALF_PERIOD     = 16'd68,
    parameter [15:0] SELECT_DELAY    = 16'd255,
    parameter [15:0] ACK_TIMEOUT     = 16'd1800,
    parameter [15:0] INTERBYTE_DELAY = 16'd173,
    parameter [15:0] DESELECT_DELAY  = 16'd1694
)(
    input         clk,
    input         rst,
    input         enable,
    input         frame_sync,
    input         data_in,
    input         ack_in,

    output reg    select1_n,
    output reg    select2_n,
    output reg    command,
    output reg    serial_clk,

    output reg    p1_connected,
    output reg    p1_strobe,
    output reg    p1_aim_valid,
    output reg [9:0] p1_x,
    output reg [7:0] p1_y,
    output reg    p1_trigger,
    output reg    p1_start,
    output reg    p1_button,
    output reg    p1_select,

    output reg    p2_connected,
    output reg    p2_strobe,
    output reg    p2_aim_valid,
    output reg [9:0] p2_x,
    output reg [7:0] p2_y,
    output reg    p2_trigger,
    output reg    p2_start,
    output reg    p2_button,
    output reg    p2_select
);

localparam [3:0] ST_IDLE       = 4'd0;
localparam [3:0] ST_SELECT     = 4'd1;
localparam [3:0] ST_CLOCK_HIGH = 4'd2;
localparam [3:0] ST_CLOCK_LOW  = 4'd3;
localparam [3:0] ST_WAIT_ACK   = 4'd4;
localparam [3:0] ST_GAP        = 4'd5;
localparam [3:0] ST_FINISH     = 4'd6;
localparam [3:0] ST_DESELECT   = 4'd7;

reg  [ 3:0] state;
reg  [15:0] timer;
reg  [ 3:0] byte_index;
reg  [ 2:0] bit_index;
reg  [ 7:0] tx_shift, rx_shift;
reg  [ 7:0] rx_bytes [0:8];
reg         active_port, pending_p1, pending_p2;
reg         data_meta, data_sync, ack_meta, ack_sync;
reg  [ 3:0] ack_history;
reg         frame_meta, frame_sync_l, frame_sync_ll, enable_l;

wire        ack_low;
wire        frame_event, enable_event;
wire [ 7:0] received_byte;
wire [ 8:0] raw_x, raw_y;
wire        response_valid, coordinates_valid;
wire [ 8:0] x_offset, y_offset;
wire [17:0] x_product, y_product;
wire [ 9:0] aim_x;
wire [ 8:0] aim_y_wide;
wire [ 7:0] aim_y;

assign ack_low        = ~|ack_history;
assign frame_event    = frame_sync_l & ~frame_sync_ll;
assign enable_event   = enable & ~enable_l;
assign received_byte  = { data_sync, rx_shift[6:0] };
assign raw_x          = { rx_bytes[6][0], rx_bytes[5] };
assign raw_y          = { rx_bytes[8][0], rx_bytes[7] };
assign response_valid = rx_bytes[1] == 8'h63 && rx_bytes[2] == 8'h5a;
assign coordinates_valid = response_valid && raw_x >= 9'h04d && raw_x <= 9'h1cd &&
                            raw_y >= 9'h019 && raw_y <= 9'h0f8;

// The NTSC GunCon reporting window is X=77..461 and Y=25..248. The X range
// maps exactly to 10 bits. The Y factor approximates 255/223 without a divider.
assign x_offset   = raw_x - 9'h04d;
assign y_offset   = raw_y - 9'h019;
assign x_product  = x_offset * 9'd341;
assign y_product  = y_offset * 9'd293;
assign aim_x      = x_product[16:7];
assign aim_y_wide = y_product[16:8];
assign aim_y      = aim_y_wide[8] ? 8'hff : aim_y_wide[7:0];

function [7:0] poll_byte;
    input [3:0] index;
begin
    case (index)
        4'd0:   poll_byte = 8'h01;
        4'd1:   poll_byte = 8'h42;
        default: poll_byte = 8'h00;
    endcase
end
endfunction

task clear_p1;
begin
    p1_connected <= 1'b0;
    p1_aim_valid <= 1'b0;
    p1_x         <= 10'd0;
    p1_y         <= 8'd0;
    p1_trigger   <= 1'b0;
    p1_start     <= 1'b0;
    p1_button    <= 1'b0;
    p1_select    <= 1'b0;
end
endtask

task clear_p2;
begin
    p2_connected <= 1'b0;
    p2_aim_valid <= 1'b0;
    p2_x         <= 10'd0;
    p2_y         <= 8'd0;
    p2_trigger   <= 1'b0;
    p2_start     <= 1'b0;
    p2_button    <= 1'b0;
    p2_select    <= 1'b0;
end
endtask

integer i;
always @(posedge clk) begin
    data_meta     <= data_in;
    data_sync     <= data_meta;
    ack_meta      <= ack_in;
    ack_sync      <= ack_meta;
    ack_history   <= { ack_history[2:0], ack_sync };
    frame_meta    <= frame_sync;
    frame_sync_l  <= frame_meta;
    frame_sync_ll <= frame_sync_l;
    enable_l      <= enable;
    p1_strobe     <= 1'b0;
    p2_strobe     <= 1'b0;

    if (rst || !enable) begin
        state         <= ST_IDLE;
        timer         <= 16'd0;
        byte_index    <= 4'd0;
        bit_index     <= 3'd0;
        tx_shift      <= 8'hff;
        rx_shift      <= 8'h00;
        active_port   <= 1'b0;
        pending_p1    <= 1'b0;
        pending_p2    <= 1'b0;
        select1_n     <= 1'b1;
        select2_n     <= 1'b1;
        command       <= 1'b1;
        serial_clk    <= 1'b1;
        ack_history   <= 4'hf;
        clear_p1;
        clear_p2;
        for (i=0; i<9; i=i+1) rx_bytes[i] <= 8'hff;
    end else begin
        if (frame_event || enable_event) begin
            pending_p1 <= 1'b1;
            pending_p2 <= 1'b1;
        end

        case (state)
            ST_IDLE: begin
                select1_n  <= 1'b1;
                select2_n  <= 1'b1;
                command    <= 1'b1;
                serial_clk <= 1'b1;
                if (pending_p1) begin
                    active_port <= 1'b0;
                    pending_p1  <= 1'b0;
                    select1_n   <= 1'b0;
                    timer       <= SELECT_DELAY;
                    byte_index  <= 4'd0;
                    state       <= ST_SELECT;
                    for (i=0; i<9; i=i+1) rx_bytes[i] <= 8'hff;
                end else if (pending_p2) begin
                    active_port <= 1'b1;
                    pending_p2  <= 1'b0;
                    select2_n   <= 1'b0;
                    timer       <= SELECT_DELAY;
                    byte_index  <= 4'd0;
                    state       <= ST_SELECT;
                    for (i=0; i<9; i=i+1) rx_bytes[i] <= 8'hff;
                end
            end

            ST_SELECT: begin
                if (timer != 0) timer <= timer - 16'd1;
                else begin
                    tx_shift   <= poll_byte(4'd0);
                    rx_shift   <= 8'h00;
                    bit_index  <= 3'd0;
                    timer      <= HALF_PERIOD - 16'd1;
                    state      <= ST_CLOCK_HIGH;
                end
            end

            ST_CLOCK_HIGH: begin
                if (timer != 0) timer <= timer - 16'd1;
                else begin
                    command    <= tx_shift[0];
                    serial_clk <= 1'b0;
                    timer      <= HALF_PERIOD - 16'd1;
                    state      <= ST_CLOCK_LOW;
                end
            end

            ST_CLOCK_LOW: begin
                if (timer != 0) timer <= timer - 16'd1;
                else begin
                    serial_clk <= 1'b1;
                    rx_shift[bit_index] <= data_sync;
                    if (bit_index == 3'd7) begin
                        rx_bytes[byte_index] <= received_byte;
                        if (byte_index == 4'd8) begin
                            timer <= INTERBYTE_DELAY;
                            state <= ST_FINISH;
                        end else begin
                            timer <= ACK_TIMEOUT;
                            state <= ST_WAIT_ACK;
                        end
                    end else begin
                        bit_index <= bit_index + 3'd1;
                        tx_shift  <= { 1'b1, tx_shift[7:1] };
                        timer     <= HALF_PERIOD - 16'd1;
                        state     <= ST_CLOCK_HIGH;
                    end
                end
            end

            ST_WAIT_ACK: begin
                command <= 1'b1;
                if (ack_low) begin
                    timer <= INTERBYTE_DELAY;
                    state <= ST_GAP;
                end else if (timer != 0) timer <= timer - 16'd1;
                else begin
                    select1_n <= 1'b1;
                    select2_n <= 1'b1;
                    serial_clk <= 1'b1;
                    if (active_port) clear_p2;
                    else             clear_p1;
                    timer <= DESELECT_DELAY;
                    state <= ST_DESELECT;
                end
            end

            ST_GAP: begin
                if (timer != 0) timer <= timer - 16'd1;
                else begin
                    byte_index <= byte_index + 4'd1;
                    bit_index  <= 3'd0;
                    tx_shift   <= poll_byte(byte_index + 4'd1);
                    rx_shift   <= 8'h00;
                    timer      <= HALF_PERIOD - 16'd1;
                    state      <= ST_CLOCK_HIGH;
                end
            end

            ST_FINISH: begin
                command <= 1'b1;
                if (timer != 0) timer <= timer - 16'd1;
                else begin
                    select1_n <= 1'b1;
                    select2_n <= 1'b1;
                    serial_clk <= 1'b1;
                    if (active_port) begin
                        p2_strobe     <= 1'b1;
                        p2_connected  <= response_valid;
                        p2_aim_valid  <= coordinates_valid;
                        p2_x          <= aim_x;
                        p2_y          <= aim_y;
                        p2_trigger    <= response_valid && !rx_bytes[4][5];
                        p2_start      <= response_valid && !rx_bytes[3][3];
                        p2_button     <= response_valid && !rx_bytes[4][6];
                        p2_select     <= response_valid && !rx_bytes[3][0];
                    end else begin
                        p1_strobe     <= 1'b1;
                        p1_connected  <= response_valid;
                        p1_aim_valid  <= coordinates_valid;
                        p1_x          <= aim_x;
                        p1_y          <= aim_y;
                        p1_trigger    <= response_valid && !rx_bytes[4][5];
                        p1_start      <= response_valid && !rx_bytes[3][3];
                        p1_button     <= response_valid && !rx_bytes[4][6];
                        p1_select     <= response_valid && !rx_bytes[3][0];
                    end
                    timer <= DESELECT_DELAY;
                    state <= ST_DESELECT;
                end
            end

            ST_DESELECT: begin
                select1_n  <= 1'b1;
                select2_n  <= 1'b1;
                command    <= 1'b1;
                serial_clk <= 1'b1;
                if (timer != 0) timer <= timer - 16'd1;
                else state <= ST_IDLE;
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule
