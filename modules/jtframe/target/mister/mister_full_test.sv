`timescale 1ns/1ps

module mister_full_test;

reg  FPGA_CLK1_50;
wire FPGA_CLK2_50, FPGA_CLK3_50;

assign FPGA_CLK2_50 = FPGA_CLK1_50;
assign FPGA_CLK3_50 = FPGA_CLK1_50;

wire [5:0]  VGA_R;
wire [5:0]  VGA_G;
wire [5:0]  VGA_B;
wire        VGA_HS;  // VGA_HS is secondary SD card detect when VGA_EN = 1 (inactive)
wire        VGA_VS;
wire        VGA_EN;  // active low

wire        AUDIO_L;
wire        AUDIO_R;
wire        AUDIO_SPDIF;

wire        HDMI_I2C_SCL;
wire        HDMI_I2C_SDA;
wire        HDMI_MCLK;
wire        HDMI_SCLK;
wire        HDMI_LRCLK;
wire        HDMI_I2S;
wire        HDMI_TX_CLK;
wire        HDMI_TX_DE;
wire [23:0] HDMI_TX_D;
wire        HDMI_TX_HS;
wire        HDMI_TX_VS;
wire        HDMI_TX_INT = 1'b0;

wire [12:0] SDRAM_A;
wire [15:0] SDRAM_DQ;
wire        SDRAM_DQML;
wire        SDRAM_DQMH;
wire        SDRAM_nWE;
wire        SDRAM_nCAS;
wire        SDRAM_nRAS;
wire        SDRAM_nCS;
wire  [1:0] SDRAM_BA;
wire        SDRAM_CLK;
wire        SDRAM_CKE;

wire        LED_USER;
wire        LED_HDD;
wire        LED_POWER;
wire        BTN_USER = 1'b0;
wire        BTN_OSD  = 1'b0;
wire        BTN_RESET= 1'b0;

wire  [3:0] SDIO_DAT;
wire        SDIO_CMD;
wire        SDIO_CLK;
wire        SDIO_CD;

wire   [1:0] KEY = 2'b0;
wire   [3:0] SW = 4'd0;
wire   [7:0] LED;
wire   [5:0] USER_IO;

sys_top UUT
(
    .*
);

integer cnt;

initial begin
    FPGA_CLK1_50 = 1'b0;
    for(cnt=0; cnt<1_000; cnt=cnt+1) FPGA_CLK1_50 = #10 ~FPGA_CLK1_50;
    $finish;
end


mt48lc16m16a2 #(.filename("../../rom/JT1943.rom")) u_sdram (
    .Dq         ( SDRAM_DQ      ),
    .Addr       ( SDRAM_A       ),
    .Ba         ( SDRAM_BA      ),
    .Clk        ( SDRAM_CLK     ),
    .Cke        ( SDRAM_CKE     ),
    .Cs_n       ( SDRAM_nCS     ),
    .Ras_n      ( SDRAM_nRAS    ),
    .Cas_n      ( SDRAM_nCAS    ),
    .We_n       ( SDRAM_nWE     ),
    .Dqm        ( {SDRAM_DQMH,SDRAM_DQML}   )
);

endmodule // sys_top