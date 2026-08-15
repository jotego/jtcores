// MiSTer game-PLL speed selector. This logic deliberately runs from CLK_50M:
// the PLL outputs disappear while a new M/DSM value is being applied.
module jtframe_pll_tune(
    input               clk,
    input               rst,
    input        [ 2:0] speed,
    input               pll_locked,
    input               cfg_waitrequest,
    output reg          cfg_write,
    output reg   [ 5:0] cfg_address,
    output reg   [31:0] cfg_writedata,
    output reg          hold_reset
);

    localparam ST_BOOT   = 3'd0;
    localparam ST_IDLE   = 3'd1;
    localparam ST_HOLD   = 3'd2;
    localparam ST_M      = 3'd3;
    localparam ST_DSM    = 3'd4;
    localparam ST_START  = 3'd5;
    localparam ST_BUSY   = 3'd6;
    localparam ST_SETTLE = 3'd7;

    reg [2:0] state;
    reg [2:0] speed_meta, speed_sync, active_speed, target_speed;
    reg [15:0] timer;
    reg busy_seen;

    // The M counter uses low[7:0], high[15:8], bypass[16], odd[17].
    function [31:0] m_counter;
        input [2:0] profile;
        begin
            case(profile)
                3'd4: m_counter = 32'h0000_0a0a; // 20 + fractional part
                3'd6,
                3'd7: m_counter = 32'h0000_0909; // 18 + fractional part
                default: m_counter = 32'h0002_0a09; // 19 + fractional part
            endcase
        end
    endfunction

    // Fractional values are fractions of the M divider in units of 2^-32.
    function [31:0] dsm_value;
        input [2:0] profile;
        begin
            case(profile)
                3'd0: dsm_value = 32'h3333_3333; // 48.000000 MHz
                3'd1: dsm_value = 32'h645a_1cac; // 48.480000 MHz
                3'd2: dsm_value = 32'h9581_0624; // 48.960000 MHz
                3'd3: dsm_value = 32'hffac_1d29; // 49.996800 MHz
                3'd4: dsm_value = 32'h28f5_c28f; // 50.400000 MHz
                3'd5: dsm_value = 32'h020c_49ba; // 47.520000 MHz
                3'd6: dsm_value = 32'h9fbe_76c8; // 46.560000 MHz
                default: dsm_value = 32'h3d70_a3d7; // 45.600000 MHz
            endcase
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state         <= ST_BOOT;
            speed_meta    <= 3'd0;
            speed_sync    <= 3'd0;
            active_speed  <= 3'd0;
            target_speed  <= 3'd0;
            timer         <= 16'd0;
            busy_seen     <= 1'b0;
            cfg_write     <= 1'b0;
            cfg_address   <= 6'd0;
            cfg_writedata <= 32'd0;
            hold_reset    <= 1'b0;
        end else begin
            speed_meta <= speed;
            speed_sync <= speed_meta;
            cfg_write  <= 1'b0;

            case(state)
                // Let the HPS initialise status and the reconfiguration block
                // complete its own DPRIO initialisation before accepting input.
                ST_BOOT: begin
                    if(timer == 16'hffff) begin
                        timer <= 16'd0;
                        state <= ST_IDLE;
                    end else timer <= timer + 16'd1;
                end

                ST_IDLE: begin
                    hold_reset <= 1'b0;
                    if(speed_sync != active_speed) begin
                        target_speed <= speed_sync;
                        hold_reset   <= 1'b1;
                        timer        <= 16'd0;
                        state        <= ST_HOLD;
                    end
                end

                // Allow jtframe_board to clock its reset fully into the game
                // before removing the game PLL clocks.
                ST_HOLD: begin
                    hold_reset <= 1'b1;
                    if(timer == 16'd8191) state <= ST_M;
                    else timer <= timer + 16'd1;
                end

                ST_M: begin
                    hold_reset <= 1'b1;
                    if(!cfg_waitrequest) begin
                        cfg_write     <= 1'b1;
                        cfg_address   <= 6'd4;
                        cfg_writedata <= m_counter(target_speed);
                        state         <= ST_DSM;
                    end
                end

                ST_DSM: begin
                    hold_reset <= 1'b1;
                    if(!cfg_waitrequest) begin
                        cfg_write     <= 1'b1;
                        cfg_address   <= 6'd7;
                        cfg_writedata <= dsm_value(target_speed);
                        state         <= ST_START;
                    end
                end

                ST_START: begin
                    hold_reset <= 1'b1;
                    if(!cfg_waitrequest) begin
                        cfg_write     <= 1'b1;
                        cfg_address   <= 6'd2;
                        cfg_writedata <= 32'd1;
                        busy_seen     <= 1'b0;
                        state         <= ST_BUSY;
                    end
                end

                ST_BUSY: begin
                    hold_reset <= 1'b1;
                    if(cfg_waitrequest) busy_seen <= 1'b1;
                    if(busy_seen && !cfg_waitrequest && pll_locked) begin
                        timer <= 16'd0;
                        state <= ST_SETTLE;
                    end
                end

                ST_SETTLE: begin
                    hold_reset <= 1'b1;
                    if(timer == 16'd49999) begin
                        active_speed <= target_speed;
                        hold_reset   <= 1'b0;
                        state        <= ST_IDLE;
                    end else timer <= timer + 16'd1;
                end

                default: state <= ST_BOOT;
            endcase
        end
    end
endmodule
