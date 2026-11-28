// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
`default_nettype none

// Safe Si5332 control plane for the DE25 platform.
//
// Probe and identify the chip before accepting live register transactions.
module de25_si5332_service #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer I2C_HZ = 25_000
) (
    input  wire         clk,
    input  wire         reset_n,
    inout  wire         scl,
    inout  wire         sda,

    output logic        present,
    output logic [6:0]  detected_address,
    output logic        identity_valid,
    output logic [95:0] identity,
    output logic        fault,
    output logic [2:0]  fault_code,
    output wire [31:0]  probe_status,

    input  wire         profile_enable,
    input  wire         profile_valid,
    output wire         profile_ready,
    input  wire [7:0]   profile_register,
    input  wire [7:0]   profile_data,
    input  wire         profile_write,
    output wire [7:0]   profile_read_data,
    output logic        profile_done,
    output logic        profile_error
);
    typedef enum logic [3:0] {
        ST_WAIT_PROBE,
        ST_READ_ISSUE,
        ST_READ_WAIT,
        ST_PROFILE_READY,
        ST_PROFILE_WAIT,
        ST_FAULT
    } state_t;

    state_t state = ST_WAIT_PROBE;
    logic [3:0] identity_index = '0;

    wire master_ready;
    logic master_command_valid;
    logic master_command_write;
    logic [7:0] master_register;
    logic [7:0] master_write_data;
    wire [7:0] master_read_data;
    wire master_busy;
    wire master_done;
    wire master_error;
    wire [2:0] master_error_code;

    function automatic logic [7:0] identity_register(
        input logic [3:0] index
    );
        begin
            case (index)
                4'd0: identity_register = 8'h0d; // DEVICE_PN_BASE
                4'd1: identity_register = 8'h0e; // DEVICE_REV
                4'd2: identity_register = 8'h0f; // DEVICE_GRADE
                4'd3: identity_register = 8'h10; // FACTORY_OPN_ID0/1
                4'd4: identity_register = 8'h11; // FACTORY_OPN_ID2/3
                4'd5: identity_register = 8'h12; // OPN_ID4/revision
                4'd6: identity_register = 8'h17; // DESIGN_ID0
                4'd7: identity_register = 8'h18; // DESIGN_ID1
                4'd8: identity_register = 8'h19; // DESIGN_ID2
                4'd9: identity_register = 8'h21; // I2C_ADDR
                4'd10: identity_register = 8'h05; // supply status
                default: identity_register = 8'h07; // USYS_STAT
            endcase
        end
    endfunction

    de25_si5332_address_probe #(
        .TICK_DIV(CLOCK_HZ / (I2C_HZ * 4))
    ) address_probe (
        .clk(clk),
        .reset_n(reset_n),
        .scl(scl),
        .sda(sda),
        .status(probe_status)
    );

    de25_i2c_register_master #(
        .CLOCK_HZ(CLOCK_HZ),
        .I2C_HZ(I2C_HZ)
    ) register_master (
        .clk(clk),
        .reset_n(reset_n & probe_status[6]),
        .command_valid(master_command_valid),
        .command_ready(master_ready),
        .command_write(master_command_write),
        .device_address(detected_address),
        .register_address(master_register),
        .write_data(master_write_data),
        .read_data(master_read_data),
        .busy(master_busy),
        .done(master_done),
        .error(master_error),
        .error_code(master_error_code),
        .scl(scl),
        .sda(sda)
    );

    always_comb begin
        master_command_valid = 1'b0;
        master_command_write = 1'b0;
        master_register = identity_register(identity_index);
        master_write_data = 8'd0;
        if (state == ST_READ_ISSUE) begin
            master_command_valid = 1'b1;
        end else if (state == ST_PROFILE_READY && profile_enable &&
                     profile_valid) begin
            master_command_valid = 1'b1;
            master_command_write = profile_write;
            master_register = profile_register;
            master_write_data = profile_data;
        end
    end

    assign profile_read_data = master_read_data;
    assign profile_ready = (state == ST_PROFILE_READY) && profile_enable &&
                           master_ready;

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            state <= ST_WAIT_PROBE;
            identity_index <= '0;
            present <= 1'b0;
            detected_address <= 7'h00;
            identity_valid <= 1'b0;
            identity <= '0;
            fault <= 1'b0;
            fault_code <= 3'd0;
            profile_done <= 1'b0;
            profile_error <= 1'b0;
        end else begin
            profile_done <= 1'b0;
            case (state)
                ST_WAIT_PROBE: begin
                    if (probe_status[7]) begin
                        fault <= 1'b1;
                        fault_code <= 3'd4;
                        state <= ST_FAULT;
                    end else if (probe_status[6]) begin
                        if (probe_status[4]) begin
                            detected_address <= 7'h6a;
                            present <= 1'b1;
                            state <= ST_READ_ISSUE;
                        end else if (probe_status[5]) begin
                            detected_address <= 7'h6b;
                            present <= 1'b1;
                            state <= ST_READ_ISSUE;
                        end else begin
                            fault <= 1'b1;
                            fault_code <= 3'd1;
                            state <= ST_FAULT;
                        end
                    end
                end

                ST_READ_ISSUE: begin
                    if (master_ready)
                        state <= ST_READ_WAIT;
                end

                ST_READ_WAIT: begin
                    if (master_done) begin
                        if (master_error) begin
                            fault <= 1'b1;
                            fault_code <= master_error_code;
                            state <= ST_FAULT;
                        end else begin
                            identity[identity_index * 8 +: 8] <=
                                master_read_data;
                            if (identity_index == 4'd11) begin
                                identity_valid <= 1'b1;
                                state <= ST_PROFILE_READY;
                            end else begin
                                identity_index <= identity_index + 1'b1;
                                state <= ST_READ_ISSUE;
                            end
                        end
                    end
                end

                ST_PROFILE_READY: begin
                    if (profile_enable && profile_valid && master_ready) begin
                        state <= ST_PROFILE_WAIT;
                    end
                end

                ST_PROFILE_WAIT: begin
                    if (master_done) begin
                        if (master_error) begin
                            profile_error <= 1'b1;
                            fault <= 1'b1;
                            fault_code <= master_error_code;
                            state <= ST_FAULT;
                        end else begin
                            profile_done <= 1'b1;
                            state <= ST_PROFILE_READY;
                        end
                    end
                end

                default: state <= ST_FAULT;
            endcase
        end
    end

    wire unused = &{1'b0, master_busy};
endmodule

`default_nettype wire
