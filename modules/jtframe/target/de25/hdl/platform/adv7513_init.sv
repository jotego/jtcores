`timescale 1ns/1ps

module adv7513_init #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer I2C_HZ   = 20_000,
    parameter integer STATUS_POLL_HZ = 4
) (
    input  logic clk,
    input  logic reset_n,
    input  logic interrupt_n,
    inout  wire  scl,
    inout  wire  sda,
    output logic done,
    output logic ack_error,
    output logic status_valid,
    output logic transmitter_powered,
    output logic hpd_high,
    output logic monitor_sense,
    output logic pll_locked,
    output logic tmds_outputs_powered,
    output logic edid_ready,
    output logic [3:0] ddc_state,
    output logic [3:0] ddc_error,
    // Coherent raw register snapshot. Byte lanes, low to high, are
    // 0x41, 0x42, 0x9e, 0xa1, 0x96, 0x97, 0xc8, and 0x3e. Register 0x97[7]
    // qualifies the 0xc8 error nibble; 0x3e[7:2] is the detected input VIC.
    output logic [63:0] raw_status
);

    localparam integer TICK_DIV = CLOCK_HZ / (I2C_HZ * 4);
    localparam logic [7:0] ADV7513_WRITE_ADDRESS = 8'h72;
    localparam integer REGISTER_COUNT = 34;

    localparam logic [7:0] ADV7513_READ_ADDRESS = 8'h73;
    localparam integer STATUS_POLL_TICKS =
        (I2C_HZ * 4) / STATUS_POLL_HZ;
    localparam integer STATUS_POLL_WIDTH =
        (STATUS_POLL_TICKS <= 1) ? 1 : $clog2(STATUS_POLL_TICKS);

    typedef enum logic [4:0] {
        ST_IDLE,
        ST_START_A,
        ST_START_B,
        ST_START_C,
        ST_BIT_LOW,
        ST_BIT_HIGH,
        ST_BIT_HOLD,
        ST_BIT_FALL,
        ST_ACK_LOW,
        ST_ACK_HIGH,
        ST_ACK_SAMPLE,
        ST_ACK_FALL,
        ST_STOP_LOW,
        ST_STOP_HIGH,
        ST_STOP_RELEASE,
        ST_GAP,
        ST_RESTART_HIGH,
        ST_RESTART_START,
        ST_RESTART_LOW,
        ST_READ_LOW,
        ST_READ_HIGH,
        ST_READ_SAMPLE,
        ST_READ_FALL,
        ST_NACK_LOW,
        ST_NACK_HIGH,
        ST_NACK_HOLD,
        ST_NACK_FALL,
        ST_WAIT
    } state_t;

    state_t state;
    logic [$clog2(TICK_DIV)-1:0] divider;
    logic [5:0] register_index;
    logic [1:0] byte_index;
    logic [2:0] bit_index;
    logic [7:0] tx_byte;
    logic [7:0] rx_byte;
    logic [7:0] power_control_readback;
    logic [7:0] connection_status_readback;
    logic [7:0] pll_status_readback;
    logic [7:0] tmds_power_readback;
    logic [7:0] interrupt_status_readback;
    logic [7:0] ddc_control_readback;
    logic [7:0] ddc_status_readback;
    logic scl_low;
    logic sda_low;
    logic status_read;
    logic [2:0] status_register_select;
    logic status_cycle_error;
    logic [STATUS_POLL_WIDTH-1:0] status_poll_counter;
    wire tick = (divider == TICK_DIV - 1);
    wire [15:0] current_register_word = register_word(register_index);

    assign scl = scl_low ? 1'b0 : 1'bz;
    assign sda = sda_low ? 1'b0 : 1'bz;

    function automatic logic [15:0] register_word(input logic [5:0] index);
        begin
            case (index)
                 // Exact DE25-Nano HDMI_ASx4 reference sequence from
                 // Terasic's Rev-A v1.0.0 resource package.
                 0: register_word = 16'h9803;
                 1: register_word = 16'h0100;
                 2: register_word = 16'h0218;
                 3: register_word = 16'h0300;
                 // Match MiSTer's production ADV7513 stereo-I2S setup. The
                 // Terasic reference values enabled four I2S inputs, declared
                 // eight channels, and selected an incompatible word length.
                 4: register_word = 16'h0b0e;
                 5: register_word = 16'h0c04;
                 6: register_word = 16'h0d10;
                 7: register_word = 16'h1402;
                 8: register_word = 16'h1520;
                 9: register_word = 16'h1630;
                10: register_word = 16'h1846;
                11: register_word = 16'h4080;
                12: register_word = 16'h4110;
                13: register_word = 16'h49a8;
                14: register_word = 16'h5510;
                15: register_word = 16'h5608;
                16: register_word = 16'h96f6;
                17: register_word = 16'h7301;
                18: register_word = 16'h761f;
                19: register_word = 16'h9803;
                20: register_word = 16'h9902;
                21: register_word = 16'h9ae0;
                22: register_word = 16'h9c30;
                23: register_word = 16'h9d61;
                24: register_word = 16'ha2a4;
                25: register_word = 16'ha3a4;
                26: register_word = 16'ha504;
                27: register_word = 16'hab40;
                28: register_word = 16'haf16;
                29: register_word = 16'hba60;
                30: register_word = 16'hd1ff;
                31: register_word = 16'hde10;
                32: register_word = 16'he460;
                33: register_word = 16'hfa7d;
                default: register_word = 16'h9803;
            endcase
        end
    endfunction

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            divider       <= '0;
            register_index <= '0;
            byte_index    <= '0;
            bit_index     <= 3'd7;
            tx_byte       <= ADV7513_WRITE_ADDRESS;
            scl_low       <= 1'b0;
            sda_low       <= 1'b0;
            done          <= 1'b0;
            ack_error     <= 1'b0;
            status_valid  <= 1'b0;
            transmitter_powered <= 1'b0;
            hpd_high      <= 1'b0;
            monitor_sense <= 1'b0;
            pll_locked    <= 1'b0;
            tmds_outputs_powered <= 1'b0;
            edid_ready    <= 1'b0;
            ddc_state     <= '0;
            ddc_error     <= '0;
            raw_status    <= '0;
            rx_byte       <= '0;
            power_control_readback <= '0;
            connection_status_readback <= '0;
            pll_status_readback <= '0;
            tmds_power_readback <= '0;
            interrupt_status_readback <= '0;
            ddc_control_readback <= '0;
            ddc_status_readback <= '0;
            status_read   <= 1'b0;
            status_register_select <= 3'd0;
            status_cycle_error <= 1'b0;
            status_poll_counter <= '0;
            state         <= ST_IDLE;
        end else begin
            if (tick)
                divider <= '0;
            else
                divider <= divider + 1'b1;

            if (tick) begin
                case (state)
                    ST_IDLE: begin
                        scl_low    <= 1'b0;
                        sda_low    <= 1'b0;
                        byte_index <= 2'd0;
                        bit_index  <= 3'd7;
                        tx_byte    <= ADV7513_WRITE_ADDRESS;
                        state      <= ST_START_A;
                    end
                    ST_START_A: begin
                        scl_low <= 1'b0;
                        sda_low <= 1'b0;
                        state   <= ST_START_B;
                    end
                    ST_START_B: begin
                        sda_low <= 1'b1;
                        state   <= ST_START_C;
                    end
                    ST_START_C: begin
                        scl_low <= 1'b1;
                        state   <= ST_BIT_LOW;
                    end
                    ST_BIT_LOW: begin
                        scl_low <= 1'b1;
                        sda_low <= ~tx_byte[bit_index];
                        state   <= ST_BIT_HIGH;
                    end
                    ST_BIT_HIGH: begin
                        scl_low <= 1'b0;
                        state   <= ST_BIT_HOLD;
                    end
                    ST_BIT_HOLD: state <= ST_BIT_FALL;
                    ST_BIT_FALL: begin
                        scl_low <= 1'b1;
                        if (bit_index == 0)
                            state <= ST_ACK_LOW;
                        else begin
                            bit_index <= bit_index - 1'b1;
                            state <= ST_BIT_LOW;
                        end
                    end
                    ST_ACK_LOW: begin
                        scl_low <= 1'b1;
                        sda_low <= 1'b0;
                        state   <= ST_ACK_HIGH;
                    end
                    ST_ACK_HIGH: begin
                        scl_low <= 1'b0;
                        state   <= ST_ACK_SAMPLE;
                    end
                    ST_ACK_SAMPLE: begin
                        if (sda !== 1'b0) begin
                            ack_error <= 1'b1;
                            if (status_read)
                                status_cycle_error <= 1'b1;
                        end
                        state <= ST_ACK_FALL;
                    end
                    ST_ACK_FALL: begin
                        scl_low <= 1'b1;
                        if (status_read) begin
                            case (byte_index)
                                0: begin
                                    byte_index <= 2'd1;
                                    bit_index  <= 3'd7;
                                    case (status_register_select)
                                        0: tx_byte <= 8'h41;
                                        1: tx_byte <= 8'h42;
                                        2: tx_byte <= 8'h9e;
                                        3: tx_byte <= 8'ha1;
                                        4: tx_byte <= 8'h96;
                                        5: tx_byte <= 8'h97;
                                        6: tx_byte <= 8'hc8;
                                        default: tx_byte <= 8'h3e;
                                    endcase
                                    state      <= ST_BIT_LOW;
                                end
                                1: begin
                                    byte_index <= 2'd2;
                                    bit_index  <= 3'd7;
                                    tx_byte    <= ADV7513_READ_ADDRESS;
                                    state      <= ST_RESTART_HIGH;
                                end
                                default: begin
                                    bit_index <= 3'd7;
                                    rx_byte   <= '0;
                                    state     <= ST_READ_LOW;
                                end
                            endcase
                        end else if (byte_index == 2) begin
                            state <= ST_STOP_LOW;
                        end else begin
                            byte_index <= byte_index + 1'b1;
                            bit_index  <= 3'd7;
                            if (byte_index == 0)
                                tx_byte <= current_register_word[15:8];
                            else
                                tx_byte <= current_register_word[7:0];
                            state <= ST_BIT_LOW;
                        end
                    end
                    ST_RESTART_HIGH: begin
                        scl_low <= 1'b0;
                        sda_low <= 1'b0;
                        state   <= ST_RESTART_START;
                    end
                    ST_RESTART_START: begin
                        sda_low <= 1'b1;
                        state   <= ST_RESTART_LOW;
                    end
                    ST_RESTART_LOW: begin
                        scl_low <= 1'b1;
                        state   <= ST_BIT_LOW;
                    end
                    ST_READ_LOW: begin
                        scl_low <= 1'b1;
                        sda_low <= 1'b0;
                        state   <= ST_READ_HIGH;
                    end
                    ST_READ_HIGH: begin
                        scl_low <= 1'b0;
                        state   <= ST_READ_SAMPLE;
                    end
                    ST_READ_SAMPLE: begin
                        rx_byte[bit_index] <= sda;
                        state <= ST_READ_FALL;
                    end
                    ST_READ_FALL: begin
                        scl_low <= 1'b1;
                        if (bit_index == 0)
                            state <= ST_NACK_LOW;
                        else begin
                            bit_index <= bit_index - 1'b1;
                            state <= ST_READ_LOW;
                        end
                    end
                    // A one-byte register read ends with a master-generated
                    // NACK, followed by STOP.
                    ST_NACK_LOW: begin
                        scl_low <= 1'b1;
                        sda_low <= 1'b0;
                        state   <= ST_NACK_HIGH;
                    end
                    ST_NACK_HIGH: begin
                        scl_low <= 1'b0;
                        state   <= ST_NACK_HOLD;
                    end
                    ST_NACK_HOLD: state <= ST_NACK_FALL;
                    ST_NACK_FALL: begin
                        scl_low <= 1'b1;
                        state   <= ST_STOP_LOW;
                    end
                    ST_STOP_LOW: begin
                        scl_low <= 1'b1;
                        sda_low <= 1'b1;
                        state   <= ST_STOP_HIGH;
                    end
                    ST_STOP_HIGH: begin
                        scl_low <= 1'b0;
                        state   <= ST_STOP_RELEASE;
                    end
                    ST_STOP_RELEASE: begin
                        sda_low <= 1'b0;
                        state   <= ST_GAP;
                    end
                    ST_GAP: begin
                        if (status_read) begin
                            case (status_register_select)
                                0: begin
                                    power_control_readback <= rx_byte;
                                    status_register_select <= 3'd1;
                                    state <= ST_IDLE;
                                end
                                1: begin
                                    connection_status_readback <= rx_byte;
                                    status_register_select <= 3'd2;
                                    state <= ST_IDLE;
                                end
                                2: begin
                                    pll_status_readback <= rx_byte;
                                    status_register_select <= 3'd3;
                                    state <= ST_IDLE;
                                end
                                3: begin
                                    tmds_power_readback <= rx_byte;
                                    status_register_select <= 3'd4;
                                    state <= ST_IDLE;
                                end
                                4: begin
                                    interrupt_status_readback <= rx_byte;
                                    status_register_select <= 3'd5;
                                    state <= ST_IDLE;
                                end
                                5: begin
                                    ddc_control_readback <= rx_byte;
                                    status_register_select <= 3'd6;
                                    state <= ST_IDLE;
                                end
                                6: begin
                                    ddc_status_readback <= rx_byte;
                                    status_register_select <= 3'd7;
                                    state <= ST_IDLE;
                                end
                                default: begin
                                    if (!status_cycle_error) begin
                                        status_valid <= 1'b1;
                                        hpd_high <= connection_status_readback[6];
                                        monitor_sense <= connection_status_readback[5];
                                        pll_locked <= pll_status_readback[4];
                                        tmds_outputs_powered <=
                                            (tmds_power_readback[5:2] == 4'b0000);
                                        edid_ready <= interrupt_status_readback[2];
                                        ddc_state <= ddc_status_readback[3:0];
                                        ddc_error <= ddc_status_readback[7:4];
                                        // Commit every byte together only
                                        // after the complete poll succeeds.
                                        raw_status <= {
                                            rx_byte,
                                            ddc_status_readback,
                                            ddc_control_readback,
                                            interrupt_status_readback,
                                            tmds_power_readback,
                                            pll_status_readback,
                                            connection_status_readback,
                                            power_control_readback
                                        };
                                        // The diagnostic override makes the
                                        // internal HPD source high. This page
                                        // therefore reports the software
                                        // power latch read back at 0x41[6],
                                        // independently of physical HPD.
                                        transmitter_powered <=
                                            !power_control_readback[6];
                                    end else begin
                                        status_valid <= 1'b0;
                                        transmitter_powered <= 1'b0;
                                        hpd_high <= 1'b0;
                                        monitor_sense <= 1'b0;
                                        pll_locked <= 1'b0;
                                        tmds_outputs_powered <= 1'b0;
                                        edid_ready <= 1'b0;
                                        ddc_state <= '0;
                                        ddc_error <= '0;
                                        raw_status <= '0;
                                    end
                                    done <= 1'b1;
                                    status_poll_counter <= '0;
                                    state <= ST_WAIT;
                                end
                            endcase
                        end else if (register_index == REGISTER_COUNT - 1) begin
                            status_read <= 1'b1;
                            status_register_select <= 3'd0;
                            status_cycle_error <= 1'b0;
                            state <= ST_IDLE;
                        end else begin
                            register_index <= register_index + 1'b1;
                            state <= ST_IDLE;
                        end
                    end
                    ST_WAIT: begin
                        scl_low <= 1'b0;
                        sda_low <= 1'b0;
                        if (status_poll_counter == STATUS_POLL_TICKS - 1) begin
                            status_poll_counter <= '0;
                            status_register_select <= 3'd0;
                            status_cycle_error <= 1'b0;
                            state <= ST_IDLE;
                        end else begin
                            status_poll_counter <= status_poll_counter + 1'b1;
                            state <= ST_WAIT;
                        end
                    end
                    default: state <= ST_IDLE;
                endcase
            end

            // A hot-plug interrupt restarts the transmitter configuration.
            if (done && !interrupt_n) begin
                register_index <= '0;
                ack_error      <= 1'b0;
                done           <= 1'b0;
                status_valid   <= 1'b0;
                transmitter_powered <= 1'b0;
                hpd_high       <= 1'b0;
                monitor_sense  <= 1'b0;
                pll_locked     <= 1'b0;
                tmds_outputs_powered <= 1'b0;
                edid_ready     <= 1'b0;
                ddc_state      <= '0;
                ddc_error      <= '0;
                raw_status     <= '0;
                status_read    <= 1'b0;
                status_register_select <= 3'd0;
                status_cycle_error <= 1'b0;
                status_poll_counter <= '0;
                state          <= ST_IDLE;
            end
        end
    end

endmodule
