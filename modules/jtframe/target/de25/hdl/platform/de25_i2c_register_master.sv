// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
`default_nettype none

// Small, single-command I2C register master used by the DE25 platform clock
// service. Both pins are strictly open drain. A command writes one 8-bit
// register or reads one 8-bit register using a repeated START.
module de25_i2c_register_master #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer I2C_HZ = 25_000
) (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        command_valid,
    output wire        command_ready,
    input  wire        command_write,
    input  wire [6:0]  device_address,
    input  wire [7:0]  register_address,
    input  wire [7:0]  write_data,
    output logic [7:0] read_data,
    output logic       busy,
    output logic       done,
    output logic       error,
    output logic [2:0] error_code,
    inout  wire        scl,
    inout  wire        sda
);
    localparam integer TICK_DIV_RAW = CLOCK_HZ / (I2C_HZ * 4);
    localparam integer TICK_DIV = (TICK_DIV_RAW < 2) ? 2 : TICK_DIV_RAW;
    localparam integer TICK_WIDTH = $clog2(TICK_DIV);

    typedef enum logic [5:0] {
        ST_IDLE,
        ST_WAIT_BUS,
        ST_START_RELEASE,
        ST_START_DATA_LOW,
        ST_START_CLOCK_LOW,
        ST_TX_SETUP,
        ST_TX_RAISE,
        ST_TX_HIGH,
        ST_TX_FALL,
        ST_ACK_SETUP,
        ST_ACK_RAISE,
        ST_ACK_HIGH,
        ST_ACK_FALL,
        ST_RESTART_RELEASE_DATA,
        ST_RESTART_RAISE,
        ST_RESTART_HIGH,
        ST_RESTART_DATA_LOW,
        ST_RESTART_CLOCK_LOW,
        ST_RX_SETUP,
        ST_RX_RAISE,
        ST_RX_HIGH,
        ST_RX_FALL,
        ST_NACK_SETUP,
        ST_NACK_RAISE,
        ST_NACK_HIGH,
        ST_NACK_FALL,
        ST_STOP_DATA_LOW,
        ST_STOP_RAISE,
        ST_STOP_HIGH,
        ST_STOP_RELEASE,
        ST_COMPLETE
    } state_t;

    state_t state = ST_IDLE;
    logic [TICK_WIDTH-1:0] tick_count = '0;
    logic [15:0] wait_count = '0;
    logic [7:0] tx_byte = '0;
    logic [7:0] rx_shift = '0;
    logic [2:0] bit_index = 3'd7;
    logic [1:0] tx_phase = '0;
    logic command_write_latched = 1'b0;
    logic [6:0] device_address_latched = '0;
    logic [7:0] register_address_latched = '0;
    logic [7:0] write_data_latched = '0;
    logic scl_low = 1'b0;
    logic sda_low = 1'b0;

    (* ASYNC_REG = "TRUE" *) logic scl_meta = 1'b1;
    (* ASYNC_REG = "TRUE" *) logic scl_sync = 1'b1;
    (* ASYNC_REG = "TRUE" *) logic sda_meta = 1'b1;
    (* ASYNC_REG = "TRUE" *) logic sda_sync = 1'b1;

    wire tick = (tick_count == TICK_DIV - 1);
    assign command_ready = (state == ST_IDLE) && !busy;
    assign scl = scl_low ? 1'b0 : 1'bz;
    assign sda = sda_low ? 1'b0 : 1'bz;

    task automatic fail(input logic [2:0] code);
        begin
            error <= 1'b1;
            error_code <= code;
            state <= ST_STOP_DATA_LOW;
        end
    endtask

    always_ff @(posedge clk) begin
        scl_meta <= scl;
        scl_sync <= scl_meta;
        sda_meta <= sda;
        sda_sync <= sda_meta;

        done <= 1'b0;
        if (!reset_n || tick)
            tick_count <= '0;
        else
            tick_count <= tick_count + 1'b1;

        if (!reset_n) begin
            state <= ST_IDLE;
            wait_count <= '0;
            tx_byte <= '0;
            rx_shift <= '0;
            bit_index <= 3'd7;
            tx_phase <= '0;
            command_write_latched <= 1'b0;
            device_address_latched <= '0;
            register_address_latched <= '0;
            write_data_latched <= '0;
            read_data <= '0;
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            error_code <= 3'd0;
            scl_low <= 1'b0;
            sda_low <= 1'b0;
        end else if (state == ST_IDLE) begin
            scl_low <= 1'b0;
            sda_low <= 1'b0;
            busy <= 1'b0;
            if (command_valid) begin
                command_write_latched <= command_write;
                device_address_latched <= device_address;
                register_address_latched <= register_address;
                write_data_latched <= write_data;
                tx_byte <= {device_address, 1'b0};
                bit_index <= 3'd7;
                tx_phase <= 2'd0;
                rx_shift <= '0;
                error <= 1'b0;
                error_code <= 3'd0;
                wait_count <= '0;
                busy <= 1'b1;
                state <= ST_WAIT_BUS;
            end
        end else if (tick) begin
            case (state)
                ST_WAIT_BUS: begin
                    scl_low <= 1'b0;
                    sda_low <= 1'b0;
                    if (scl_sync && sda_sync) begin
                        wait_count <= '0;
                        state <= ST_START_RELEASE;
                    end else if (&wait_count) begin
                        error <= 1'b1;
                        error_code <= 3'd4;
                        state <= ST_COMPLETE;
                    end else
                        wait_count <= wait_count + 1'b1;
                end

                ST_START_RELEASE: begin
                    scl_low <= 1'b0;
                    sda_low <= 1'b0;
                    state <= ST_START_DATA_LOW;
                end
                ST_START_DATA_LOW: begin
                    scl_low <= 1'b0;
                    sda_low <= 1'b1;
                    state <= ST_START_CLOCK_LOW;
                end
                ST_START_CLOCK_LOW: begin
                    scl_low <= 1'b1;
                    state <= ST_TX_SETUP;
                end

                ST_TX_SETUP: begin
                    scl_low <= 1'b1;
                    sda_low <= ~tx_byte[bit_index];
                    state <= ST_TX_RAISE;
                end
                ST_TX_RAISE: begin
                    scl_low <= 1'b0;
                    state <= ST_TX_HIGH;
                end
                ST_TX_HIGH: begin
                    if (scl_sync) begin
                        wait_count <= '0;
                        state <= ST_TX_FALL;
                    end else if (&wait_count) begin
                        fail(3'd4);
                    end else
                        wait_count <= wait_count + 1'b1;
                end
                ST_TX_FALL: begin
                    scl_low <= 1'b1;
                    if (bit_index == 0)
                        state <= ST_ACK_SETUP;
                    else begin
                        bit_index <= bit_index - 1'b1;
                        state <= ST_TX_SETUP;
                    end
                end

                ST_ACK_SETUP: begin
                    scl_low <= 1'b1;
                    sda_low <= 1'b0;
                    state <= ST_ACK_RAISE;
                end
                ST_ACK_RAISE: begin
                    scl_low <= 1'b0;
                    state <= ST_ACK_HIGH;
                end
                ST_ACK_HIGH: begin
                    if (!scl_sync && &wait_count) begin
                        fail(3'd4);
                    end else if (!scl_sync) begin
                        wait_count <= wait_count + 1'b1;
                    end else begin
                        wait_count <= '0;
                        if (sda_sync)
                            fail({1'b0, tx_phase} + 3'd1);
                        else
                            state <= ST_ACK_FALL;
                    end
                end
                ST_ACK_FALL: begin
                    scl_low <= 1'b1;
                    bit_index <= 3'd7;
                    case (tx_phase)
                        2'd0: begin
                            tx_phase <= 2'd1;
                            tx_byte <= register_address_latched;
                            state <= ST_TX_SETUP;
                        end
                        2'd1: begin
                            if (command_write_latched) begin
                                tx_phase <= 2'd2;
                                tx_byte <= write_data_latched;
                                state <= ST_TX_SETUP;
                            end else begin
                                state <= ST_RESTART_RELEASE_DATA;
                            end
                        end
                        2'd2: state <= ST_STOP_DATA_LOW;
                        default: state <= ST_RX_SETUP;
                    endcase
                end

                ST_RESTART_RELEASE_DATA: begin
                    scl_low <= 1'b1;
                    sda_low <= 1'b0;
                    state <= ST_RESTART_RAISE;
                end
                ST_RESTART_RAISE: begin
                    scl_low <= 1'b0;
                    state <= ST_RESTART_HIGH;
                end
                ST_RESTART_HIGH: begin
                    if (scl_sync) begin
                        wait_count <= '0;
                        state <= ST_RESTART_DATA_LOW;
                    end else if (&wait_count) begin
                        fail(3'd4);
                    end else
                        wait_count <= wait_count + 1'b1;
                end
                ST_RESTART_DATA_LOW: begin
                    sda_low <= 1'b1;
                    state <= ST_RESTART_CLOCK_LOW;
                end
                ST_RESTART_CLOCK_LOW: begin
                    scl_low <= 1'b1;
                    tx_phase <= 2'd3;
                    tx_byte <= {device_address_latched, 1'b1};
                    bit_index <= 3'd7;
                    state <= ST_TX_SETUP;
                end

                ST_RX_SETUP: begin
                    scl_low <= 1'b1;
                    sda_low <= 1'b0;
                    state <= ST_RX_RAISE;
                end
                ST_RX_RAISE: begin
                    scl_low <= 1'b0;
                    state <= ST_RX_HIGH;
                end
                ST_RX_HIGH: begin
                    if (scl_sync) begin
                        wait_count <= '0;
                        rx_shift[bit_index] <= sda_sync;
                        state <= ST_RX_FALL;
                    end else if (&wait_count) begin
                        fail(3'd4);
                    end else
                        wait_count <= wait_count + 1'b1;
                end
                ST_RX_FALL: begin
                    scl_low <= 1'b1;
                    if (bit_index == 0) begin
                        read_data <= {rx_shift[7:1], sda_sync};
                        state <= ST_NACK_SETUP;
                    end else begin
                        bit_index <= bit_index - 1'b1;
                        state <= ST_RX_SETUP;
                    end
                end

                ST_NACK_SETUP: begin
                    scl_low <= 1'b1;
                    sda_low <= 1'b0;
                    state <= ST_NACK_RAISE;
                end
                ST_NACK_RAISE: begin
                    scl_low <= 1'b0;
                    state <= ST_NACK_HIGH;
                end
                ST_NACK_HIGH: begin
                    if (scl_sync) begin
                        wait_count <= '0;
                        state <= ST_NACK_FALL;
                    end else if (&wait_count) begin
                        fail(3'd4);
                    end else
                        wait_count <= wait_count + 1'b1;
                end
                ST_NACK_FALL: begin
                    scl_low <= 1'b1;
                    state <= ST_STOP_DATA_LOW;
                end

                ST_STOP_DATA_LOW: begin
                    scl_low <= 1'b1;
                    sda_low <= 1'b1;
                    state <= ST_STOP_RAISE;
                end
                ST_STOP_RAISE: begin
                    scl_low <= 1'b0;
                    state <= ST_STOP_HIGH;
                end
                ST_STOP_HIGH: begin
                    if (scl_sync) begin
                        wait_count <= '0;
                        state <= ST_STOP_RELEASE;
                    end else if (&wait_count) begin
                        error <= 1'b1;
                        error_code <= 3'd4;
                        state <= ST_COMPLETE;
                    end else
                        wait_count <= wait_count + 1'b1;
                end
                ST_STOP_RELEASE: begin
                    scl_low <= 1'b0;
                    sda_low <= 1'b0;
                    state <= ST_COMPLETE;
                end
                ST_COMPLETE: begin
                    scl_low <= 1'b0;
                    sda_low <= 1'b0;
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= ST_IDLE;
                end
                default: begin
                    scl_low <= 1'b0;
                    sda_low <= 1'b0;
                    busy <= 1'b0;
                    error <= 1'b1;
                    error_code <= 3'd7;
                    state <= ST_COMPLETE;
                end
            endcase
        end
    end
endmodule

`default_nettype wire
