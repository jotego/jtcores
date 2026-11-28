// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
`default_nettype none

// Non-destructive Si5332B presence probe.
//
// Both pins are strictly open drain. After a 20 ms settling interval, this
// controller sends only the write-address byte for 0x6a and 0x6b, records the
// ACK bits, emits STOP, and permanently releases both pins. No register or
// data byte is sent, so this module cannot alter volatile or NVM settings.
module de25_si5332_address_probe #(
    parameter integer TICK_DIV = 500
) (
    input  wire        clk,
    input  wire        reset_n,
    inout  wire        scl,
    inout  wire        sda,
    output wire [31:0] status
);
    typedef enum logic [4:0] {
        ST_DELAY,
        ST_WAIT_BUS,
        ST_START_RELEASE,
        ST_START_SDA_LOW,
        ST_START_SCL_LOW,
        ST_BIT_SETUP,
        ST_BIT_RISE,
        ST_BIT_HIGH,
        ST_BIT_FALL,
        ST_ACK_SETUP,
        ST_ACK_RISE,
        ST_ACK_HIGH,
        ST_ACK_FALL,
        ST_STOP_DATA_LOW,
        ST_STOP_CLOCK_HIGH,
        ST_STOP_CLOCK_CHECK,
        ST_STOP_DATA_HIGH,
        ST_INTER_PROBE,
        ST_DONE,
        ST_FAULT
    } state_t;

    logic [8:0] tick_count = '0;
    logic [10:0] startup_count = '0;
    logic [3:0] inter_probe_count = '0;
    logic [15:0] wait_count = '0;
    logic [7:0] tx_byte = 8'hd4;
    logic [2:0] bit_index = 3'd7;
    logic probe_index = 1'b0;
    logic scl_low = 1'b0;
    logic sda_low = 1'b0;
    logic ack_6a = 1'b0;
    logic ack_6b = 1'b0;
    logic done = 1'b0;
    logic bus_fault = 1'b0;
    logic [4:0] fault_state = '0;
    state_t state = ST_DELAY;

    (* ASYNC_REG = "TRUE" *) logic scl_meta = 1'b1;
    (* ASYNC_REG = "TRUE" *) logic scl_sync = 1'b1;
    (* ASYNC_REG = "TRUE" *) logic sda_meta = 1'b1;
    (* ASYNC_REG = "TRUE" *) logic sda_sync = 1'b1;

    wire tick = (tick_count == TICK_DIV - 1);

    // There is intentionally no logic value that can drive either line high.
    assign scl = scl_low ? 1'b0 : 1'bz;
    assign sda = sda_low ? 1'b0 : 1'bz;

    always_ff @(posedge clk) begin
        scl_meta <= scl;
        scl_sync <= scl_meta;
        sda_meta <= sda;
        sda_sync <= sda_meta;

        if (!reset_n || tick)
            tick_count <= '0;
        else
            tick_count <= tick_count + 1'b1;

        if (!reset_n) begin
            state             <= ST_DELAY;
            startup_count     <= '0;
            inter_probe_count <= '0;
            wait_count        <= '0;
            tx_byte           <= 8'hd4;
            bit_index         <= 3'd7;
            probe_index       <= 1'b0;
            scl_low           <= 1'b0;
            sda_low           <= 1'b0;
            ack_6a            <= 1'b0;
            ack_6b            <= 1'b0;
            done              <= 1'b0;
            bus_fault         <= 1'b0;
            fault_state       <= '0;
        end else if (tick) begin
            case (state)
                ST_DELAY: begin
                    scl_low <= 1'b0;
                    sda_low <= 1'b0;
                    if (&startup_count)
                        state <= ST_WAIT_BUS;
                    else
                        startup_count <= startup_count + 1'b1;
                end

                ST_WAIT_BUS: begin
                    // Never attempt recovery clocks on an unexpectedly low
                    // bus. A powered slave or another bus participant may
                    // release it later, so wait passively before latching a
                    // fault and leaving both pins released.
                    scl_low <= 1'b0;
                    sda_low <= 1'b0;
                    if (scl_sync && sda_sync) begin
                        wait_count <= '0;
                        state <= ST_START_RELEASE;
                    end else if (&wait_count) begin
                        bus_fault <= 1'b1;
                        fault_state <= state;
                        state <= ST_FAULT;
                    end else
                        wait_count <= wait_count + 1'b1;
                end

                ST_START_RELEASE: begin
                    scl_low <= 1'b0;
                    sda_low <= 1'b0;
                    if (scl_sync && sda_sync) begin
                        wait_count <= '0;
                        state <= ST_START_SDA_LOW;
                    end else if (&wait_count) begin
                        bus_fault <= 1'b1;
                        fault_state <= state;
                        state <= ST_FAULT;
                    end else
                        wait_count <= wait_count + 1'b1;
                end

                ST_START_SDA_LOW: begin
                    sda_low <= 1'b1;
                    scl_low <= 1'b0;
                    state <= ST_START_SCL_LOW;
                end

                ST_START_SCL_LOW: begin
                    scl_low <= 1'b1;
                    state <= ST_BIT_SETUP;
                end

                ST_BIT_SETUP: begin
                    scl_low <= 1'b1;
                    sda_low <= ~tx_byte[bit_index];
                    state <= ST_BIT_RISE;
                end

                ST_BIT_RISE: begin
                    scl_low <= 1'b0;
                    state <= ST_BIT_HIGH;
                end

                ST_BIT_HIGH: begin
                    // Permit ordinary I2C clock stretching. At the default
                    // divider the all-ones timeout is about 655 ms.
                    if (scl_sync) begin
                        wait_count <= '0;
                        state <= ST_BIT_FALL;
                    end else if (&wait_count) begin
                        bus_fault <= 1'b1;
                        fault_state <= state;
                        state <= ST_FAULT;
                    end else
                        wait_count <= wait_count + 1'b1;
                end

                ST_BIT_FALL: begin
                    scl_low <= 1'b1;
                    if (bit_index == 0)
                        state <= ST_ACK_SETUP;
                    else begin
                        bit_index <= bit_index - 1'b1;
                        state <= ST_BIT_SETUP;
                    end
                end

                ST_ACK_SETUP: begin
                    scl_low <= 1'b1;
                    sda_low <= 1'b0;
                    state <= ST_ACK_RISE;
                end

                ST_ACK_RISE: begin
                    scl_low <= 1'b0;
                    state <= ST_ACK_HIGH;
                end

                ST_ACK_HIGH: begin
                    if (!scl_sync && &wait_count) begin
                        bus_fault <= 1'b1;
                        fault_state <= state;
                        state <= ST_FAULT;
                    end else if (!scl_sync) begin
                        wait_count <= wait_count + 1'b1;
                    end else begin
                        wait_count <= '0;
                        if (!probe_index)
                            ack_6a <= ~sda_sync;
                        else
                            ack_6b <= ~sda_sync;
                        state <= ST_ACK_FALL;
                    end
                end

                ST_ACK_FALL: begin
                    scl_low <= 1'b1;
                    state <= ST_STOP_DATA_LOW;
                end

                ST_STOP_DATA_LOW: begin
                    scl_low <= 1'b1;
                    sda_low <= 1'b1;
                    state <= ST_STOP_CLOCK_HIGH;
                end

                ST_STOP_CLOCK_HIGH: begin
                    scl_low <= 1'b0;
                    state <= ST_STOP_CLOCK_CHECK;
                end

                ST_STOP_CLOCK_CHECK: begin
                    scl_low <= 1'b0;
                    if (scl_sync) begin
                        wait_count <= '0;
                        state <= ST_STOP_DATA_HIGH;
                    end else if (&wait_count) begin
                        bus_fault <= 1'b1;
                        fault_state <= state;
                        state <= ST_FAULT;
                    end else
                        wait_count <= wait_count + 1'b1;
                end

                ST_STOP_DATA_HIGH: begin
                    scl_low <= 1'b0;
                    sda_low <= 1'b0;
                    if (!probe_index) begin
                        probe_index <= 1'b1;
                        tx_byte <= 8'hd6;
                        bit_index <= 3'd7;
                        inter_probe_count <= '0;
                        state <= ST_INTER_PROBE;
                    end else begin
                        done <= 1'b1;
                        state <= ST_DONE;
                    end
                end

                ST_INTER_PROBE: begin
                    scl_low <= 1'b0;
                    sda_low <= 1'b0;
                    if (scl_sync && sda_sync) begin
                        wait_count <= '0;
                        if (&inter_probe_count)
                            state <= ST_START_RELEASE;
                        else
                            inter_probe_count <= inter_probe_count + 1'b1;
                    end else if (&wait_count) begin
                        bus_fault <= 1'b1;
                        fault_state <= state;
                        state <= ST_FAULT;
                    end else
                        wait_count <= wait_count + 1'b1;
                end

                ST_DONE: begin
                    scl_low <= 1'b0;
                    sda_low <= 1'b0;
                    done <= 1'b1;
                end

                default: begin
                    scl_low <= 1'b0;
                    sda_low <= 1'b0;
                    bus_fault <= 1'b1;
                    fault_state <= state;
                    state <= ST_FAULT;
                end
            endcase
        end
    end

    assign status = {
        16'h5332,
        fault_state,
        state[2:0],
        bus_fault,
        done,
        ack_6b,
        ack_6a,
        sda_sync,
        scl_sync,
        sda_low,
        scl_low
    };
endmodule

`default_nettype wire
