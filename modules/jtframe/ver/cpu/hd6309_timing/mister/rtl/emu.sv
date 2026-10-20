`ifndef MCTEST_TARGET_INSTRUCTIONS
`define MCTEST_TARGET_INSTRUCTIONS 1000000000
`endif
`ifndef MCTEST_NATIVE_MODE
`define MCTEST_NATIVE_MODE 1
`endif
// Example MiSTer top-level adapter around the reusable module-test transport.
module emu #(
    parameter integer TARGET_INSTRUCTIONS = `MCTEST_TARGET_INSTRUCTIONS,
    parameter integer NATIVE_MODE = `MCTEST_NATIVE_MODE
) (
    `include "sys/emu_ports.vh"
);
    assign CLK_VIDEO = CLK_50M;
    assign CE_PIXEL = 1'b1;
    assign VIDEO_ARX = 13'd4;
    assign VIDEO_ARY = 13'd3;
    assign {VGA_R, VGA_G, VGA_B} = 24'h0;
    assign {VGA_HS, VGA_VS, VGA_DE, VGA_F1} = 4'h0;
    assign VGA_SL = 2'b0;
    assign VGA_SCALER = 1'b0;
    assign VGA_DISABLE = 1'b1;
    assign {HDMI_FREEZE, HDMI_BLACKOUT, HDMI_BOB_DEINT} = 3'b0;
    assign AUDIO_L = 16'b0;
    assign AUDIO_R = 16'b0;
    assign AUDIO_S = 1'b0;
    assign LED_DISK = 2'b0;
    assign LED_POWER = 2'b0;
    assign USER_OUT = '1;
    assign UART_RTS = 1'b0;
    assign UART_TXD = 1'b0;
    assign UART_DTR = 1'b0;
    assign SD_SCK = 1'bZ;
    assign SD_MOSI = 1'bZ;
    assign SD_CS = 1'bZ;
    assign ADC_BUS = 'Z;
    assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE,
            SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS,
            SDRAM_nRAS, SDRAM_nCS} = 'Z;
    assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN,
            DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;
    assign BUTTONS = '0;

    wire test_reset_n;
    wire [7:0] result_word_addr;
    wire [31:0] result_word_data;
    wire test_done;
    wire input_wr;
    wire [26:0] input_addr;
    wire [7:0] input_data;

    hd6309_cycle_test #(
        .TARGET_INSTRUCTIONS(TARGET_INSTRUCTIONS),
        .NATIVE_MODE(NATIVE_MODE)
    ) u_test (
        .clk(CLK_50M),
        .reset_n(test_reset_n),
        .result_word_addr(result_word_addr),
        .result_word_data(result_word_data),
        .test_done(test_done)
    );

    mister_test_transport #(.RESULT_WORDS(96)) u_transport (
        .clk_sys(CLK_50M),
        .reset_in(RESET),
        .HPS_BUS(HPS_BUS),
        .test_done(test_done),
        .test_reset_n(test_reset_n),
        .result_word_addr(result_word_addr),
        .result_word_data(result_word_data),
        .input_wr(input_wr),
        .input_addr(input_addr),
        .input_data(input_data)
    );
endmodule
