// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
`default_nettype none

// First DE25-Nano implementation of the standard MiSTer platform boundary.
// The board-facing shell remains fixed while the upstream `emu` module is
// replaced for each core build.
module de25_mister_top (
    input  wire         CLOCK0_50,
    input  wire         CLOCK1_50,
    input  wire         CLOCK2_50,
    input  wire  [1:0]  KEY,
    input  wire  [3:0]  SW,
`ifdef DE25_PLATFORM_V2
    inout  wire         SI5332_SDA,
    inout  wire         SI5332_SCL,
`elsif DE25_SI5332_ADDRESS_PROBE
    inout  wire         SI5332_SDA,
    inout  wire         SI5332_SCL,
`endif
    output logic [7:0]  LED,

    output wire         DRAM_CLK,
    output wire         DRAM_CKE,
    output wire [12:0]  DRAM_ADDR,
    output wire [1:0]   DRAM_BA,
    inout  wire [15:0]  DRAM_DQ,
    output wire         DRAM_LDQM,
    output wire         DRAM_UDQM,
    output wire [1:0]   DRAM_CS_n,
    output wire         DRAM_WE_n,
    output wire         DRAM_CAS_n,
    output wire         DRAM_RAS_n,

    input  wire         LPDDR4A_REFCLK_p,
    output wire         LPDDR4A_CS_n,
    output wire [5:0]   LPDDR4A_CA,
    output wire         LPDDR4A_CK,
    output wire         LPDDR4A_CKE,
    output wire         LPDDR4A_CK_n,
    inout  wire [3:0]   LPDDR4A_DM,
    inout  wire [31:0]  LPDDR4A_DQ,
    inout  wire [3:0]   LPDDR4A_DQS,
    inout  wire [3:0]   LPDDR4A_DQS_n,
    output wire         LPDDR4A_RESET_n,
    input  wire         LPDDR4A_RZQ,

    inout  wire         HDMI_LRCLK,
    inout  wire         HDMI_MCLK,
    inout  wire         HDMI_SCLK,
    output wire         HDMI_TX_CLK,
    output wire         HDMI_TX_HS,
    output wire         HDMI_TX_VS,
    output wire [23:0]  HDMI_TX_D,
    output wire         HDMI_TX_DE,
    inout  wire         HDMI_I2C_SCL,
    inout  wire         HDMI_I2C_SDA,
    input  wire         HDMI_TX_INT,
    inout  wire         HDMI_I2S,

    output wire         FPGA_UART_TX,
    input  wire         FPGA_UART_RX,

    input  wire         HPS_CLK_25,
    output wire         HPS_ENET_MDC,
    inout  wire         HPS_ENET_MDIO,
    input  wire         HPS_ENET_RX_CLK,
    input  wire         HPS_ENET_RX_CTL,
    input  wire  [3:0]  HPS_ENET_RX_DATA,
    output wire         HPS_ENET_TX_CLK,
    output wire         HPS_ENET_TX_CTL,
    output wire [3:0]   HPS_ENET_TX_DATA,
    inout  wire         HPS_GSENSOR_I2C_EN,
    inout  wire         HPS_GSENSOR_INT,
    inout  wire         HPS_I2C_SCL,
    inout  wire         HPS_I2C_SDA,
    inout  wire         HPS_KEY,
    inout  wire         HPS_LED,
    output wire         HPS_SD_CLK,
    inout  wire         HPS_SD_CMD,
    inout  wire [3:0]   HPS_SD_DATA,
    input  wire         HPS_UART_RX,
    output wire         HPS_UART_TX,
    input  wire         HPS_USB_CLK,
    inout  wire [7:0]   HPS_USB_DATA,
    input  wire         HPS_USB_DIR,
    input  wire         HPS_USB_NXT,
    output wire         HPS_USB_STP,

    input  wire         FAN_ALERT_n
);
    logic ninit_done;
    logic platform_locked;
    logic clk_hps;
    logic clk_audio;
    logic clk_aux;
    logic h2f_reset;
    logic h2f_warm_reset_req;
    wire h2f_warm_reset_ack_normal;
    wire h2f_warm_reset_ack;
    wire hps_warm_reset_pending;
`ifdef DE25_HPS_RESET_V1_RECOVERY
    // Preserve the first C600 fit while forcing completion of the handshake.
    assign h2f_warm_reset_ack = 1'b0;
`elsif DE25_HPS_RESET_RECOVERY
    // A recovery image can acknowledge a pending HPS warm-reset handshake
    // even when the normal sequenced handshake is not progressing.
    assign h2f_warm_reset_ack = 1'b0;
`else
    assign h2f_warm_reset_ack = h2f_warm_reset_ack_normal;
`endif
    logic [2:0] hps_led_out;
    logic [26:0] heartbeat = '0;
`ifdef DE25_PLATFORM_V2
    wire [23:0] v2_clock1_frequency_khz;
    wire [23:0] v2_clock2_frequency_khz;
    wire [31:0] v2_si5332_probe_status;
    wire [95:0] v2_si5332_identity;
    wire [6:0] v2_si5332_address;
    wire v2_si5332_identity_valid;
    wire v2_si5332_fault;
    wire v2_external_clocks_ready;
`endif
`ifdef DE25_PC110_CORE
    logic [23:0] clock1_frequency_khz;
    logic [23:0] clock2_frequency_khz;
    logic clock1_sample_toggle;
    logic clock2_sample_toggle;
    wire pc110_clk_sys;
    wire pc110_clk_uart1;
    wire pc110_clk_mpu;
    wire pc110_clk_uart2;
    wire pc110_clk_vga;
    wire pc110_clk_scanout;
    wire pc110_core_locked;
`endif

    // HPS reset is masked until Main has taken ownership of core reset. This
    // permits a JTAG-loaded Menu to run while the board has no bootable SD.
`ifdef DE25_PC110_CORE
    wire all_platform_locked = platform_locked & pc110_core_locked;
`else
    wire all_platform_locked = platform_locked;
`endif
`ifdef DE25_HPS_RESET_V1_REPRO
`define DE25_HPS_RESET_V1_ACTIVE
`endif
`ifdef DE25_HPS_RESET_V1_RECOVERY
`define DE25_HPS_RESET_V1_ACTIVE
`endif
`ifdef DE25_HPS_RESET_V1_ACTIVE
    // Reproduce the first C600 migration fit so its HPS-facing implementation
    // can be recovered before applying the forced acknowledgement incrementally.
    wire fabric_reset_request = ninit_done | ~KEY[0] | ~all_platform_locked |
        hps_warm_reset_pending;
`else
    // The pending handshake resets HPS-facing soft logic before acknowledgement.
    // The HPS then asserts h2f_reset while completing its warm reset, so keep
    // every fabric domain held until both phases have ended.
    wire fabric_reset_request = ninit_done | ~KEY[0] | ~all_platform_locked |
        hps_warm_reset_pending | h2f_reset;
`endif
    // Keep the HPS Qsys fabric alive even if a core-specific PLL has not
    // locked. h2f_reset already drives the four dedicated bridge reset ports
    // through mister_h2f_bridge_reset. Feeding it into the global Qsys reset
    // as well creates a reset loop after an HPS boot: the logic needed to
    // reopen the bridge remains disabled and Main's first MMIO access raises
    // an asynchronous SError. The core itself remains held by
    // fabric_reset_request until h2f_reset deasserts.
`ifdef DE25_HPS_RESET_V1_ACTIVE
    wire qsys_reset_n = ~ninit_done & KEY[0] & platform_locked &
        ~hps_warm_reset_pending;
`else
    wire qsys_reset_n = ~ninit_done & KEY[0] & platform_locked &
        ~hps_warm_reset_pending;
`endif
`ifdef DE25_HPS_RESET_V1_ACTIVE
`undef DE25_HPS_RESET_V1_ACTIVE
`endif

    de25_hps_warm_reset_handshake warm_reset_handshake (
        .clk(CLOCK0_50),
        .reset_req_n(h2f_warm_reset_req),
        .reset_ack_n(h2f_warm_reset_ack_normal),
        .reset_pending(hps_warm_reset_pending)
    );

`ifdef DE25_PLATFORM_V2
    de25_platform_v2_clock_service platform_clocks (
        .clock0_50(CLOCK0_50),
        .clock1_si5332(CLOCK1_50),
        .clock2_si5332(CLOCK2_50),
        .reset(ninit_done | ~KEY[0]),
        .si5332_scl(SI5332_SCL),
        .si5332_sda(SI5332_SDA),
        .clk_hps(clk_hps),
        .clk_audio(clk_audio),
        .clk_video(clk_aux),
        .platform_locked(platform_locked),
        .external_clocks_ready(v2_external_clocks_ready),
        .clock1_frequency_khz(v2_clock1_frequency_khz),
        .clock2_frequency_khz(v2_clock2_frequency_khz),
        .si5332_probe_status(v2_si5332_probe_status),
        .si5332_identity(v2_si5332_identity),
        .si5332_identity_valid(v2_si5332_identity_valid),
        .si5332_address(v2_si5332_address),
        .si5332_fault(v2_si5332_fault)
    );
`else
    mister_pll platform_clocks (
        .refclk_clk(CLOCK0_50),
        .reset_reset(ninit_done | ~KEY[0]),
        .locked_export(platform_locked),
        .outclk0_clk(clk_hps),
        .outclk1_clk(clk_audio),
        .outclk2_clk(clk_aux)
    );
`endif

`ifdef DE25_PC110_CORE
    de25_pc110_core_clocks pc110_clocks (
        .refclk(CLOCK0_50),
        .reset(ninit_done | ~KEY[0]),
        .clk_sys(pc110_clk_sys),
        .clk_uart1(pc110_clk_uart1),
        .clk_mpu(pc110_clk_mpu),
        .clk_uart2(pc110_clk_uart2),
        .clk_vga(pc110_clk_vga),
        .clk_scanout(pc110_clk_scanout),
        .locked(pc110_core_locked)
    );
`endif

    wire [31:0] hps_gp_out;
    wire [31:0] hps_gp_in;
    wire [31:0] gp_out_sync;
    wire [6:0] core_user_out;
    wire [15:0] io_din;
    wire io_fpga;
    wire io_uio;
    wire io_strobe;
    wire io_ack;
    wire io_osd = gp_out_sync[19] & ~gp_out_sync[18];
    wire shell_osd_status;
    wire [1:0] core_reset_state;

`ifdef DE25_PC110_CORE
    de25_clock_frequency_monitor clock1_monitor (
        .ref_clk(CLOCK0_50),
        .reset_n(~fabric_reset_request),
        .measured_clk(CLOCK1_50),
        .count_khz(clock1_frequency_khz),
        .sample_toggle(clock1_sample_toggle)
    );

    de25_clock_frequency_monitor clock2_monitor (
        .ref_clk(CLOCK0_50),
        .reset_n(~fabric_reset_request),
        .measured_clk(CLOCK2_50),
        .count_khz(clock2_frequency_khz),
        .sample_toggle(clock2_sample_toggle)
    );

`ifdef DE25_SI5332_ADDRESS_PROBE
    wire [31:0] si5332_probe_status;
    de25_si5332_address_probe si5332_address_probe (
        .clk(CLOCK0_50),
        .reset_n(~ninit_done & KEY[0]),
        .scl(SI5332_SCL),
        .sda(SI5332_SDA),
        .status(si5332_probe_status)
    );
`endif
`endif
`ifdef DE25_AO486_CORE
`ifdef DE25_PLL_DIAGNOSTIC
    logic [5:0] ao486_ddr_diagnostic;
    wire  [5:0] ao486_scaler_diagnostic;
`endif
`endif
`ifdef DE25_PLL_DIAGNOSTIC
`ifdef DE25_PLATFORM_V2
    logic [5:0] v2_platform_diagnostic;
    always_comb begin
        case (gp_out_sync[4:0])
            // Page 0 preserves the original probe layout:
            // {fault, done, ACK_6B, ACK_6A, SDA, SCL}.
            5'd0: v2_platform_diagnostic = v2_si5332_probe_status[7:2];
            5'd1: v2_platform_diagnostic = {
                v2_si5332_identity_valid,
                v2_external_clocks_ready,
                v2_si5332_fault,
                v2_si5332_address[2:0]
            };
            5'd2,  5'd3,  5'd4,  5'd5,
            5'd6,  5'd7,  5'd8,  5'd9,
            5'd10, 5'd11, 5'd12, 5'd13,
            5'd14, 5'd15, 5'd16, 5'd17:
                v2_platform_diagnostic =
                    v2_si5332_identity[(gp_out_sync[4:0] - 2) * 6 +: 6];
            5'd18, 5'd19, 5'd20, 5'd21:
                v2_platform_diagnostic =
                    v2_clock1_frequency_khz[
                        (gp_out_sync[4:0] - 18) * 6 +: 6];
            5'd22, 5'd23, 5'd24, 5'd25:
                v2_platform_diagnostic =
                    v2_clock2_frequency_khz[
                        (gp_out_sync[4:0] - 22) * 6 +: 6];
            5'd26: v2_platform_diagnostic = v2_si5332_address[6:1];
            default: v2_platform_diagnostic = 6'd0;
        endcase
    end
    wire [5:0] gp_diagnostic = v2_platform_diagnostic;
`elsif DE25_AO486_CORE
    logic [5:0] ao486_user_meta = 6'd0;
    logic [5:0] ao486_user_sync = 6'd0;
    wire [31:0] ao486_execution_eip = core.system.ao486.eip;
    wire [63:0] ao486_execution_cs_cache = core.system.ao486.cs_cache;
    wire [31:0] ao486_execution_cs_base = {
        ao486_execution_cs_cache[63:56], ao486_execution_cs_cache[39:16]
    };
    wire [31:0] ao486_execution_linear =
        ao486_execution_cs_base + ao486_execution_eip;
    logic [5:0] ao486_eip_chunk;

    always_ff @(posedge clk_hps) begin
        ao486_user_meta <= core_user_out[5:0];
        ao486_user_sync <= ao486_user_meta;
    end

    // Main can be stopped temporarily and the low three GPO bits used as a
    // read-only diagnostic page selector. Six pages expose all 32 bits of the
    // live CS-base-plus-EIP address, letting the HPS identify a BIOS loop.
    always_comb begin
        case (gp_out_sync[2:0])
            3'd0: ao486_eip_chunk = ao486_execution_linear[5:0];
            3'd1: ao486_eip_chunk = ao486_execution_linear[11:6];
            3'd2: ao486_eip_chunk = ao486_execution_linear[17:12];
            3'd3: ao486_eip_chunk = ao486_execution_linear[23:18];
            3'd4: ao486_eip_chunk = ao486_execution_linear[29:24];
            3'd5: ao486_eip_chunk = {4'd0, ao486_execution_linear[31:30]};
            3'd6: ao486_eip_chunk = ao486_ddr_diagnostic;
            default: ao486_eip_chunk = ao486_user_sync;
        endcase
    end
    wire [5:0] gp_diagnostic = ao486_eip_chunk;
`elsif DE25_PC110_CORE
    wire  [5:0] pc110_scaler_diagnostic;
    wire  [5:0] pc110_scaler_data_diagnostic;
    logic [27:0] pc110_scaler_first_read_address = 28'd0;
    logic [27:0] pc110_scaler_min_read_address = {28{1'b1}};
    logic [27:0] pc110_scaler_max_read_address = 28'd0;
    logic [27:0] pc110_scaler_last_read_address = 28'd0;
    logic        pc110_scaler_read_address_seen = 1'b0;
    logic        pc110_scaler_read_address_changed = 1'b0;
    logic  [7:0] pc110_scaler_read_burstcount = 8'd0;
    logic [127:0] pc110_scaler_first_response0 = 128'd0;
    logic [127:0] pc110_scaler_first_response1 = 128'd0;
    logic [127:0] pc110_scaler_first_response2 = 128'd0;
    logic [127:0] pc110_scaler_first_response3 = 128'd0;
    logic [127:0] pc110_scaler_selected_response;
    logic [31:0] pc110_scaler_address_diagnostic_word;
    wire  [31:0] pc110_scaler_debug_state0;
    wire  [31:0] pc110_scaler_debug_state1;
    wire [31:0] pc110_execution_eip = core.system.ao486.eip;
    wire [63:0] pc110_execution_cs_cache = core.system.ao486.cs_cache;
    wire [31:0] pc110_execution_cs_base = {
        pc110_execution_cs_cache[63:56], pc110_execution_cs_cache[39:16]
    };
    wire [31:0] pc110_execution_linear =
        pc110_execution_cs_base + pc110_execution_eip;
    logic [5:0] pc110_execution_diagnostic;
    logic [5:0] pc110_ddr_diagnostic = 6'd0;
    logic [5:0] pc110_clock_diagnostic;

    always_comb begin
        case (gp_out_sync[2:0])
            3'd0: pc110_clock_diagnostic = gp_out_sync[22] ?
                clock2_frequency_khz[5:0] : clock1_frequency_khz[5:0];
            3'd1: pc110_clock_diagnostic = gp_out_sync[22] ?
                clock2_frequency_khz[11:6] : clock1_frequency_khz[11:6];
            3'd2: pc110_clock_diagnostic = gp_out_sync[22] ?
                clock2_frequency_khz[17:12] : clock1_frequency_khz[17:12];
            3'd3: pc110_clock_diagnostic = gp_out_sync[22] ?
                clock2_frequency_khz[23:18] : clock1_frequency_khz[23:18];
            3'd4: pc110_clock_diagnostic = {
                4'd0,
                gp_out_sync[22] ? clock2_sample_toggle :
                                  clock1_sample_toggle,
                gp_out_sync[22]
            };
            default: pc110_clock_diagnostic = 6'd0;
        endcase
    end

    // With Main stopped, the HPS may retain reset-release state 2 in GPO
    // bits 31:30 and use bits 2:0 as a read-only page selector. Pages 0-5
    // expose CS-base-plus-EIP. Page 6 identifies every PC110 reset source,
    // Page 7 reports whether the CPU issued a DDR read, whether data returned,
    // whether the PC110 reset-vector beat returned intact, and a response
    // count. GPO bit 23, when bit 24 is clear, selects the auxiliary
    // board-clock counter. Bit 22 selects CLOCK1_50 or CLOCK2_50 and bits 2:0
    // select a six-bit result page. Other unused high GPO bits provide
    // diagnostics independently of the low 16-bit user-I/O data word: bit 27
    // selects the configuration-ROM
    // byte, bit 28 selects its read counter, and bit 29 selects the live
    // user-I/O select/strobe state plus four synchronized selector bits. The
    // GP bridge itself is clocked by
    // the private 30 MHz domain, so a readable page already proves that clock
    // is advancing.

    always_comb begin
        pc110_scaler_selected_response = pc110_scaler_first_response0;
        pc110_scaler_address_diagnostic_word =
            {4'd0, pc110_scaler_first_read_address};
        if (gp_out_sync[23] && !gp_out_sync[24]) begin
            pc110_execution_diagnostic = pc110_clock_diagnostic;
        end else if (gp_out_sync[24]) begin
            if (gp_out_sync[25]) begin
                case (gp_out_sync[23:22])
                    2'd0: pc110_scaler_selected_response =
                        pc110_scaler_first_response0;
                    2'd1: pc110_scaler_selected_response =
                        pc110_scaler_first_response1;
                    2'd2: pc110_scaler_selected_response =
                        pc110_scaler_first_response2;
                    default: pc110_scaler_selected_response =
                        pc110_scaler_first_response3;
                endcase
                case (gp_out_sync[21:20])
                    2'd0: pc110_scaler_address_diagnostic_word =
                        pc110_scaler_selected_response[31:0];
                    2'd1: pc110_scaler_address_diagnostic_word =
                        pc110_scaler_selected_response[63:32];
                    2'd2: pc110_scaler_address_diagnostic_word =
                        pc110_scaler_selected_response[95:64];
                    default: pc110_scaler_address_diagnostic_word =
                        pc110_scaler_selected_response[127:96];
                endcase
            end else begin
                case (gp_out_sync[23:22])
                    2'd0: pc110_scaler_address_diagnostic_word =
                        {4'd0, pc110_scaler_first_read_address};
                    2'd1: pc110_scaler_address_diagnostic_word =
                        {4'd0, pc110_scaler_min_read_address};
                    2'd2: pc110_scaler_address_diagnostic_word =
                        {4'd0, pc110_scaler_max_read_address};
                    default: begin
                        if (gp_out_sync[21])
                            pc110_scaler_address_diagnostic_word =
                                pc110_scaler_debug_state0;
                        else if (gp_out_sync[20])
                            pc110_scaler_address_diagnostic_word =
                                pc110_scaler_debug_state1;
                        else
                            pc110_scaler_address_diagnostic_word =
                                {4'd0, pc110_scaler_last_read_address};
                    end
                endcase
            end
            case (gp_out_sync[2:0])
                3'd0: pc110_execution_diagnostic =
                    pc110_scaler_address_diagnostic_word[5:0];
                3'd1: pc110_execution_diagnostic =
                    pc110_scaler_address_diagnostic_word[11:6];
                3'd2: pc110_execution_diagnostic =
                    pc110_scaler_address_diagnostic_word[17:12];
                3'd3: pc110_execution_diagnostic =
                    pc110_scaler_address_diagnostic_word[23:18];
                3'd4: pc110_execution_diagnostic =
                    pc110_scaler_address_diagnostic_word[29:24];
                3'd5: pc110_execution_diagnostic =
                    {4'd0, pc110_scaler_address_diagnostic_word[31:30]};
                3'd6: pc110_execution_diagnostic = {
                    pc110_scaler_read_address_changed,
                    pc110_scaler_read_address_seen,
                    pc110_scaler_read_burstcount[3:0]
                };
                default: pc110_execution_diagnostic = 6'd0;
            endcase
        end else if (gp_out_sync[25]) begin
            pc110_execution_diagnostic = pc110_scaler_data_diagnostic;
        end else if (gp_out_sync[26]) begin
            pc110_execution_diagnostic = pc110_scaler_diagnostic;
        end else if (gp_out_sync[29]) begin
            pc110_execution_diagnostic = {
                io_uio,
                io_strobe,
                gp_out_sync[20:17]
            };
        end else if (gp_out_sync[28]) begin
            pc110_execution_diagnostic = core.hps_io.byte_cnt[5:0];
        end else if (gp_out_sync[27]) begin
            pc110_execution_diagnostic = core.hps_io.conf_byte[5:0];
        end else begin
            case (gp_out_sync[2:0])
                3'd0: pc110_execution_diagnostic = pc110_execution_linear[5:0];
                3'd1: pc110_execution_diagnostic = pc110_execution_linear[11:6];
                3'd2: pc110_execution_diagnostic = pc110_execution_linear[17:12];
                3'd3: pc110_execution_diagnostic = pc110_execution_linear[23:18];
                3'd4: pc110_execution_diagnostic = pc110_execution_linear[29:24];
                3'd5: pc110_execution_diagnostic = {4'd0, pc110_execution_linear[31:30]};
                3'd6: pc110_execution_diagnostic = {
                    core_reset,
                    core.reset,
                    core.system.kbc_cpu_reset,
                    core.init_reset[2],
                    core.menu_reset,
                    core.status[0]
                };
                default: pc110_execution_diagnostic = pc110_ddr_diagnostic;
            endcase
        end
    end
`ifdef DE25_SI5332_ADDRESS_PROBE
    // Fixed read-only result in the existing GP diagnostic field, so JTAG can
    // read it without writing GPO or competing with a running MiSTer Main. A
    // failure reports 1 followed by the five-bit state that observed it;
    // success retains {fault, done, ACK6B, ACK6A, SDA, SCL}.
    wire [5:0] gp_diagnostic = si5332_probe_status[7] ?
        {1'b1, si5332_probe_status[15:11]} : si5332_probe_status[7:2];
`else
    wire [5:0] gp_diagnostic = pc110_execution_diagnostic;
`endif
`elsif DE25_NES_CORE
    // Read-only NES execution trace. Capture complete bus samples in the NES
    // clock domain, then leave them stable for the HPS diagnostic pager. This
    // avoids pairing an address from one CPU cycle with data/control from a
    // neighboring cycle while crossing asynchronously into the HPS clock.
    // GPO[26] selects one of eight post-vector CPU bus samples with GPO[25:23].
    // GPO[27] selects mapper flags and GPO[28] selects the PRG/CHR masks.
    wire [15:0] nes_cpu_addr_async = core.nes.cpu_addr;
    wire  [7:0] nes_cpu_data_async = core.nes.internal_data_bus;
    wire        nes_cpu_rnw_async = core.nes.cpu_rnw;
    wire        nes_cpu_ce_async = core.nes.cpu_ce;
    wire        nes_cpu_instrnew_async = core.nes.cpu_Instrnew;
    wire        nes_reset_async = core.reset_nes;
    wire        nes_render_async = core.nes.render_ena;

    logic [7:0] nes_reset_vector_low = 8'd0;
    logic [7:0] nes_reset_vector_high = 8'd0;
    logic nes_reset_vector_low_seen = 1'b0;
    logic nes_reset_vector_high_seen = 1'b0;
    logic nes_ppu_ctrl_write_seen = 1'b0;
    logic nes_ppu_mask_write_seen = 1'b0;
    logic [3:0] nes_bus_trace_count = 4'd0;
    logic [31:0] nes_bus_trace [0:7];
    logic [31:0] nes_selected_bus_trace;
    logic [31:0] nes_diagnostic_word;
    logic [5:0] nes_execution_diagnostic;
    integer nes_trace_index;

    always_ff @(posedge core_clk_video) begin
        if (nes_reset_async) begin
            nes_reset_vector_low_seen <= 1'b0;
            nes_reset_vector_high_seen <= 1'b0;
            nes_ppu_ctrl_write_seen <= 1'b0;
            nes_ppu_mask_write_seen <= 1'b0;
            nes_bus_trace_count <= 4'd0;
            for (nes_trace_index = 0; nes_trace_index < 8;
                 nes_trace_index = nes_trace_index + 1)
                nes_bus_trace[nes_trace_index] <= 32'd0;
        end else begin
            if (nes_cpu_ce_async && nes_cpu_rnw_async &&
                nes_cpu_addr_async == 16'hfffc) begin
                nes_reset_vector_low <= nes_cpu_data_async;
                nes_reset_vector_low_seen <= 1'b1;
            end
            if (nes_cpu_ce_async && nes_cpu_rnw_async &&
                nes_cpu_addr_async == 16'hfffd) begin
                nes_reset_vector_high <= nes_cpu_data_async;
                nes_reset_vector_high_seen <= 1'b1;
            end
            if (nes_reset_vector_high_seen && nes_cpu_ce_async &&
                nes_bus_trace_count < 8) begin
                nes_bus_trace[nes_bus_trace_count[2:0]] <= {
                    6'd0,
                    nes_cpu_instrnew_async,
                    nes_cpu_rnw_async,
                    nes_cpu_addr_async,
                    nes_cpu_data_async
                };
                nes_bus_trace_count <= nes_bus_trace_count + 1'b1;
            end
            if (nes_cpu_ce_async && !nes_cpu_rnw_async &&
                nes_cpu_addr_async == 16'h2000)
                nes_ppu_ctrl_write_seen <= 1'b1;
            if (nes_cpu_ce_async && !nes_cpu_rnw_async &&
                nes_cpu_addr_async == 16'h2001)
                nes_ppu_mask_write_seen <= 1'b1;
        end
    end

    always_comb begin
        nes_diagnostic_word = {
            nes_bus_trace[0][23:8],
            nes_reset_vector_high,
            nes_reset_vector_low
        };
        case (gp_out_sync[25:23])
            3'd0: nes_selected_bus_trace = nes_bus_trace[0];
            3'd1: nes_selected_bus_trace = nes_bus_trace[1];
            3'd2: nes_selected_bus_trace = nes_bus_trace[2];
            3'd3: nes_selected_bus_trace = nes_bus_trace[3];
            3'd4: nes_selected_bus_trace = nes_bus_trace[4];
            3'd5: nes_selected_bus_trace = nes_bus_trace[5];
            3'd6: nes_selected_bus_trace = nes_bus_trace[6];
            default: nes_selected_bus_trace = nes_bus_trace[7];
        endcase
        if (gp_out_sync[26])
            nes_diagnostic_word = nes_selected_bus_trace;
        else if (gp_out_sync[27])
            nes_diagnostic_word = core.mapper_flags[31:0];
        else if (gp_out_sync[28])
            nes_diagnostic_word = {12'd0, core.prg_mask, core.chr_mask};

        case (gp_out_sync[2:0])
            3'd0: nes_execution_diagnostic = nes_diagnostic_word[5:0];
            3'd1: nes_execution_diagnostic = nes_diagnostic_word[11:6];
            3'd2: nes_execution_diagnostic = nes_diagnostic_word[17:12];
            3'd3: nes_execution_diagnostic = nes_diagnostic_word[23:18];
            3'd4: nes_execution_diagnostic = nes_diagnostic_word[29:24];
            3'd5: nes_execution_diagnostic =
                {4'd0, nes_diagnostic_word[31:30]};
            3'd6: nes_execution_diagnostic = {
                nes_bus_trace_count != 0,
                nes_reset_vector_high_seen,
                nes_reset_vector_low_seen,
                nes_ppu_ctrl_write_seen,
                nes_ppu_mask_write_seen,
                nes_render_async
            };
            default: nes_execution_diagnostic = core_user_out[5:0];
        endcase
    end
    wire [5:0] gp_diagnostic = nes_execution_diagnostic;
`else
    wire [5:0] gp_diagnostic = core_user_out[5:0];
`endif
`else
    wire [5:0] gp_diagnostic = 6'd0;
`endif
`ifdef DE25_HPS_BUS_49
    wire [48:0] hps_bus;
`else
    wire [45:0] hps_bus;
`endif

    // Core-to-HPS portions of HPS_BUS are intentionally read from the shared
    // net. Top drives only the HPS-to-core and video-feedback portions.
    wire        io_wait = hps_bus[37];
    wire        io_wide = hps_bus[32];
    wire [15:0] io_dout = hps_bus[15:0];
    wire        core_clk_sys = hps_bus[36];
`ifdef DE25_CORE_HAS_NATIVE_DDRAM_CLK
    wire        core_ddram_clk;
    wire        ddram_domain_clk = core_ddram_clk;
`else
    wire        ddram_domain_clk = core_clk_sys;
`endif
    wire        core_domain_reset;

    de25_mister_gp_bridge gp_bridge (
        .clk_sys(core_clk_sys),
        .reset(core_domain_reset),
        .hps_gp_out(hps_gp_out),
        .hps_gp_in(hps_gp_in),
        .gp_out_sync(gp_out_sync),
        .btn_user(~KEY[1]),
        .btn_osd(1'b0),
        .osd_status(shell_osd_status),
        .io_dig(1'b0),
        .hdmi_int_n(HDMI_TX_INT),
        .io_ver(2'd1),
        .io_wait(io_wait),
        .vs_wait(1'b0),
        .io_wide(io_wide),
        .io_dout(io_dout),
        .io_dout_sys(16'd0),
        .diagnostic(gp_diagnostic),
        .io_din(io_din),
        .io_fpga(io_fpga),
        .io_uio(io_uio),
        .io_strobe(io_strobe),
        .io_ack(io_ack),
        .core_reset_state(core_reset_state)
    );

    wire reset_request;
`ifdef DE25_AO486_CORE
    localparam bit allow_standalone_core_release = 1'b0;
`else
    localparam bit allow_standalone_core_release = 1'b1;
`endif
    de25_mister_reset_control #(
        .ALLOW_STANDALONE_RELEASE(allow_standalone_core_release)
    ) reset_control (
        .clk_sys(core_clk_sys),
        // core_domain_reset asserts with the fabric request but releases only
        // after three core clock edges. Feeding that synchronized release to
        // the controller prevents the platform PLL lock signal from directly
        // driving asynchronous clears in the core clock domain.
        .fabric_reset_request(core_domain_reset),
        .hps_reset_request(h2f_reset),
        .core_reset_state(core_reset_state),
        .reset_request(reset_request)
    );

    // Every fabric domain gets asynchronous assertion and synchronous reset
    // release. This prevents HPS reset and PLL lock signals from deasserting
    // directly into state machines clocked by unrelated PLL outputs.
    (* ASYNC_REG = "TRUE" *) logic [2:0] core_reset_pipe  = 3'b111;
    (* ASYNC_REG = "TRUE" *) logic [2:0] audio_reset_pipe = 3'b111;
    (* ASYNC_REG = "TRUE" *) logic [2:0] hps_reset_pipe   = 3'b111;
    (* ASYNC_REG = "TRUE" *) logic [2:0] vbuf_reset_pipe  = 3'b111;
    (* ASYNC_REG = "TRUE" *) logic [2:0] ddram_reset_pipe = 3'b111;

`ifdef DE25_GAME_REF_HZ
    wire game_pll_locked;
    wire game_reset_request = fabric_reset_request | ~v2_external_clocks_ready | ~game_pll_locked;
`else
    wire game_reset_request = fabric_reset_request;
`endif
    always_ff @(posedge core_clk_sys or posedge game_reset_request) begin
        if (game_reset_request)
            core_reset_pipe <= 3'b111;
        else
            core_reset_pipe <= {core_reset_pipe[1:0], 1'b0};
    end

    always_ff @(posedge clk_audio or posedge fabric_reset_request) begin
        if (fabric_reset_request)
            audio_reset_pipe <= 3'b111;
        else
            audio_reset_pipe <= {audio_reset_pipe[1:0], reset_request};
    end

    always_ff @(posedge clk_hps or posedge fabric_reset_request) begin
        if (fabric_reset_request)
            hps_reset_pipe <= 3'b111;
        else
            hps_reset_pipe <= {hps_reset_pipe[1:0], 1'b0};
    end

    always_ff @(posedge clk_hps or posedge fabric_reset_request) begin
        if (fabric_reset_request)
            vbuf_reset_pipe <= 3'b111;
        else
            vbuf_reset_pipe <= {vbuf_reset_pipe[1:0], reset_request};
    end

    assign core_domain_reset = core_reset_pipe[2];
    wire core_reset = core_domain_reset | reset_request;

    always_ff @(posedge ddram_domain_clk or posedge core_reset) begin
        if (core_reset)
            ddram_reset_pipe <= 3'b111;
        else
            ddram_reset_pipe <= {ddram_reset_pipe[1:0], 1'b0};
    end
    wire ddram_domain_reset = ddram_reset_pipe[2];
    wire audio_reset = audio_reset_pipe[2];
    wire hps_domain_reset = hps_reset_pipe[2];
    wire vbuf_domain_reset = vbuf_reset_pipe[2];

    wire core_clk_video;
    wire core_ce_pixel;
    wire [7:0] core_r;
    wire [7:0] core_g;
    wire [7:0] core_b;
    wire core_hs;
    wire core_vs;
    wire core_de;
    wire core_f1;
    wire [1:0] core_scanlines;
    wire [23:0] shell_video_data;
    wire shell_video_hs;
    wire shell_video_vs;
    wire shell_video_de;
`ifdef DE25_VIDEO_SCALER
    wire [23:0] scaler_video_data;
    wire scaler_video_hs;
    wire scaler_video_vs;
    wire scaler_video_de;
    wire [27:0] scaler_ddram_address;
    wire  [7:0] scaler_ddram_burstcount;
    wire [127:0] scaler_ddram_writedata;
    wire  [15:0] scaler_ddram_byteenable;
    wire scaler_ddram_read;
    wire scaler_ddram_write;
`endif
`ifdef DE25_CORE_HAS_FB
    wire        core_fb_en;
    wire  [4:0] core_fb_format;
    wire [11:0] core_fb_width;
    wire [11:0] core_fb_height;
    wire [31:0] core_fb_base;
    wire [13:0] core_fb_stride;
    wire        core_fb_force_blank;
`ifdef DE25_CORE_HAS_FB_PALETTE
    wire        core_fb_pal_clk;
    wire  [7:0] core_fb_pal_addr;
    wire [23:0] core_fb_pal_dout;
    logic [23:0] core_fb_pal_din;
    wire        core_fb_pal_wr;
    logic [23:0] core_fb_palette [0:255];

    // Keep the core-facing palette interface functional even before the
    // DE25 DDR framebuffer/scaler path is enabled. Minimig reads this RAM
    // back through its RTG registers as well as writing it.
    always_ff @(posedge core_fb_pal_clk) begin
        if (core_fb_pal_wr)
            core_fb_palette[core_fb_pal_addr] <= core_fb_pal_dout;
        core_fb_pal_din <= core_fb_palette[core_fb_pal_addr];
    end
`endif
`else
    wire        core_fb_en = 1'b0;
`endif

`ifdef DE25_HPS_BUS_49
    // Current MiSTer cores report framebuffer enable and scanline mode in
    // the three HPS_BUS bits added after the original 46-bit interface.
    // The DE25 shell does not enable the DDR framebuffer yet.
    assign hps_bus[48]    = core_fb_en;
    assign hps_bus[47:46] = core_scanlines;
`endif
    assign hps_bus[45]    = core_f1;
    assign hps_bus[44]    = core_vs;
    assign hps_bus[43]    = clk_hps;
    assign hps_bus[42]    = core_clk_video;
    assign hps_bus[41]    = core_ce_pixel;
    assign hps_bus[40]    = core_de;
    assign hps_bus[39]    = core_hs;
    assign hps_bus[38]    = core_vs;
    assign hps_bus[35]    = io_fpga;
    assign hps_bus[34]    = io_uio;
    assign hps_bus[33]    = io_strobe;
    assign hps_bus[31:16] = io_din;

    wire [7:0]  ddram_burstcount;
    wire [28:0] ddram_address;
    wire [63:0] ddram_writedata;
    wire [7:0]  ddram_byteenable;
    wire        ddram_read;
    wire        ddram_write;
    wire        ddram_busy;
    wire [63:0] ddram_readdata;
    wire        ddram_readdatavalid;

    wire        av_waitrequest;
    wire [63:0] av_readdata;
    wire        av_readdatavalid;
    wire [7:0]  av_burstcount;
    wire [31:0] av_address;
    wire [63:0] av_writedata;
    wire [7:0]  av_byteenable;
    wire        av_read;
    wire        av_write;

`ifdef DE25_HPS_LEGACY_NO_VBUF
    wire        vbuf_av_waitrequest = 1'b1;
    wire [127:0] vbuf_av_readdata = 128'd0;
    wire        vbuf_av_readdatavalid = 1'b0;
`else
    wire        vbuf_av_waitrequest;
    wire [127:0] vbuf_av_readdata;
    wire        vbuf_av_readdatavalid;
`endif
    wire  [7:0] vbuf_av_burstcount;
    wire [31:0] vbuf_av_address;
    wire [127:0] vbuf_av_writedata;
    wire  [15:0] vbuf_av_byteenable;
    wire        vbuf_av_read;
    wire        vbuf_av_write;

`ifdef DE25_AO486_CORE
`ifdef DE25_PLL_DIAGNOSTIC
    // ao486 fills each cache line with an eight-beat DDRAM burst. Expose a
    // saturating returned-beat count, whether the bridge accepted a read, and
    // whether the BIOS reset-vector beat came back with the expected bytes.
    // GPI bits 26:21 are {response_count[3:0], reset_vector_seen, read_seen}.
    always_ff @(posedge core_clk_sys) begin
        if (core_reset) begin
            ao486_ddr_diagnostic <= 6'd0;
        end else begin
            if (av_read && !av_waitrequest)
                ao486_ddr_diagnostic[0] <= 1'b1;
            if (av_readdatavalid &&
                av_readdata == 64'h2f32_31f0_00e0_5bea)
                ao486_ddr_diagnostic[1] <= 1'b1;
            if (av_readdatavalid &&
                ao486_ddr_diagnostic[5:2] != 4'hf)
                ao486_ddr_diagnostic[5:2] <=
                    ao486_ddr_diagnostic[5:2] + 1'b1;
        end
    end
`endif
`endif

`ifdef DE25_PC110_CORE
`ifdef DE25_PLL_DIAGNOSTIC
    always_ff @(posedge core_clk_sys) begin
        if (core_reset) begin
            pc110_ddr_diagnostic <= 6'd0;
        end else begin
            if (av_read && !av_waitrequest)
                pc110_ddr_diagnostic[0] <= 1'b1;
            if (av_readdatavalid) begin
                pc110_ddr_diagnostic[1] <= 1'b1;
                if (av_readdata == 64'h2f31_31f0_00e0_5bea)
                    pc110_ddr_diagnostic[2] <= 1'b1;
                if (pc110_ddr_diagnostic[5:3] != 3'h7)
                    pc110_ddr_diagnostic[5:3] <=
                        pc110_ddr_diagnostic[5:3] + 1'b1;
            end
        end
    end
`endif
`endif

    // The core retains its standard DDRAM channel whether or not the common
    // video scaler is enabled. Platform Designer arbitrates this channel and
    // the independent video-buffer channel at the LPDDR4 bridge.
    de25_mister_ddram ddram_bridge (
        .reset(ddram_domain_reset),
        .core_burstcount(ddram_burstcount),
        .core_address(ddram_address),
        .core_busy(ddram_busy),
        .core_readdata(ddram_readdata),
        .core_readdatavalid(ddram_readdatavalid),
        .core_read(ddram_read),
        .core_writedata(ddram_writedata),
        .core_byteenable(ddram_byteenable),
        .core_write(ddram_write),
        .av_waitrequest(av_waitrequest),
        .av_readdata(av_readdata),
        .av_readdatavalid(av_readdatavalid),
        .av_burstcount(av_burstcount),
        .av_address(av_address),
        .av_writedata(av_writedata),
        .av_byteenable(av_byteenable),
        .av_read(av_read),
        .av_write(av_write)
    );

`ifdef DE25_VIDEO_SCALER
    de25_mister_ddram #(
        .DATA_WIDTH(128),
        .ADDRESS_WIDTH(28)
    ) vbuf_bridge (
        .reset(vbuf_domain_reset),
        .core_burstcount(scaler_ddram_burstcount),
        .core_address(scaler_ddram_address),
        .core_busy(),
        .core_readdata(),
        .core_readdatavalid(),
        .core_read(scaler_ddram_read),
        .core_writedata(scaler_ddram_writedata),
        .core_byteenable(scaler_ddram_byteenable),
        .core_write(scaler_ddram_write),
        .av_waitrequest(vbuf_av_waitrequest),
        .av_readdata(vbuf_av_readdata),
        .av_readdatavalid(vbuf_av_readdatavalid),
        .av_burstcount(vbuf_av_burstcount),
        .av_address(vbuf_av_address),
        .av_writedata(vbuf_av_writedata),
        .av_byteenable(vbuf_av_byteenable),
        .av_read(vbuf_av_read),
        .av_write(vbuf_av_write)
    );
`else
    assign vbuf_av_burstcount = 8'd0;
    assign vbuf_av_address = 32'd0;
    assign vbuf_av_writedata = 128'd0;
    assign vbuf_av_byteenable = 16'd0;
    assign vbuf_av_read = 1'b0;
    assign vbuf_av_write = 1'b0;
`endif

    wire [15:0] audio_left;
    wire [15:0] audio_right;
    wire audio_signed;
    wire audio_bit_clock;
    wire audio_word_clock;
    wire audio_data;

`ifdef DE25_PLATFORM_V2
    de25_mister_audio_v2 audio (
`else
    de25_mister_audio audio (
`endif
        .clk_audio(clk_audio),
        .reset(audio_reset),
        .core_left(audio_left),
        .core_right(audio_right),
        .core_signed(audio_signed),
        .bit_clock(audio_bit_clock),
        .word_clock(audio_word_clock),
        .serial_data(audio_data)
    );

    wire        core_sdram_clk;
    wire        core_sdram_cke;
    wire [12:0] core_sdram_addr;
    wire  [1:0] core_sdram_ba;
    wire        core_sdram_dqml;
    wire        core_sdram_dqmh;
    wire        core_sdram_ncs;
    wire        core_sdram_ncas;
    wire        core_sdram_nras;
    wire        core_sdram_nwe;
`ifdef DE25_CORE_HAS_SPLIT_SDRAM_DQ
    wire [15:0] core_sdram_dq_in;
    wire [15:0] core_sdram_dq_out;
    wire        core_sdram_dq_oe;
`endif
    wire core_led_user;
    wire [1:0] core_led_power;
    wire [1:0] core_led_disk;
    wire [1:0] core_buttons;
    wire core_uart_tx;
    wire core_uart_rts;
    wire core_uart_dtr;
    wire [3:0] adc_bus;

    emu core (
`ifdef DE25_GAME_REF_HZ
        .CLK_50M(CLOCK1_50),
        .GAME_REF_READY(v2_external_clocks_ready),
        .GAME_PLL_LOCKED(game_pll_locked),
`else
        .CLK_50M(CLOCK0_50),
`endif
`ifdef DE25_AO486_CORE
        .DE25_CLK_VGA(clk_hps),
`endif
`ifdef DE25_PC110_CORE
        .DE25_CLK_SYS(pc110_clk_sys),
        .DE25_CLK_UART1(pc110_clk_uart1),
        .DE25_CLK_MPU(pc110_clk_mpu),
        .DE25_CLK_OPL(CLOCK0_50),
        .DE25_CLK_VGA(pc110_clk_vga),
        .DE25_CLK_UART2(pc110_clk_uart2),
`endif
        .RESET(core_reset),
        .HPS_BUS(hps_bus),
        .CLK_VIDEO(core_clk_video),
        .CE_PIXEL(core_ce_pixel),
        .VIDEO_ARX(),
        .VIDEO_ARY(),
        .VGA_R(core_r),
        .VGA_G(core_g),
        .VGA_B(core_b),
        .VGA_HS(core_hs),
        .VGA_VS(core_vs),
        .VGA_DE(core_de),
        .VGA_F1(core_f1),
        .VGA_SL(core_scanlines),
        .VGA_SCALER(),
        .VGA_DISABLE(),
        .HDMI_WIDTH(12'd0),
        .HDMI_HEIGHT(12'd0),
        .HDMI_FREEZE(),
        .HDMI_BLACKOUT(),
`ifdef DE25_CORE_HAS_FB
        .FB_EN(core_fb_en),
        .FB_FORMAT(core_fb_format),
        .FB_WIDTH(core_fb_width),
        .FB_HEIGHT(core_fb_height),
        .FB_BASE(core_fb_base),
        .FB_STRIDE(core_fb_stride),
        .FB_VBL(core_vs),
        .FB_LL(1'b0),
        .FB_FORCE_BLANK(core_fb_force_blank),
`ifdef DE25_CORE_HAS_FB_PALETTE
        .FB_PAL_CLK(core_fb_pal_clk),
        .FB_PAL_ADDR(core_fb_pal_addr),
        .FB_PAL_DOUT(core_fb_pal_dout),
        .FB_PAL_DIN(core_fb_pal_din),
        .FB_PAL_WR(core_fb_pal_wr),
`endif
`endif
`ifdef DE25_CORE_HAS_HDMI_BOB_DEINT
        .HDMI_BOB_DEINT(),
`endif
        .LED_USER(core_led_user),
        .LED_POWER(core_led_power),
        .LED_DISK(core_led_disk),
        .BUTTONS(core_buttons),
        .CLK_AUDIO(clk_audio),
        .AUDIO_L(audio_left),
        .AUDIO_R(audio_right),
        .AUDIO_S(audio_signed),
        .AUDIO_MIX(),
`ifdef DE25_CORE_HAS_TAPE_IN
        .TAPE_IN(1'b0),
`endif
        .ADC_BUS(adc_bus),
        .SD_SCK(),
        .SD_MOSI(),
        .SD_MISO(1'b1),
        .SD_CS(),
        .SD_CD(1'b1),
`ifdef DE25_CORE_HAS_NATIVE_DDRAM_CLK
        .DDRAM_CLK(core_ddram_clk),
`else
        .DDRAM_CLK(),
`endif
        .DDRAM_BUSY(ddram_busy),
        .DDRAM_BURSTCNT(ddram_burstcount),
        .DDRAM_ADDR(ddram_address),
        .DDRAM_DOUT(ddram_readdata),
        .DDRAM_DOUT_READY(ddram_readdatavalid),
        .DDRAM_RD(ddram_read),
        .DDRAM_DIN(ddram_writedata),
        .DDRAM_BE(ddram_byteenable),
        .DDRAM_WE(ddram_write),
        .SDRAM_CLK(core_sdram_clk),
        .SDRAM_CKE(core_sdram_cke),
        .SDRAM_A(core_sdram_addr),
        .SDRAM_BA(core_sdram_ba),
`ifdef DE25_CORE_HAS_SPLIT_SDRAM_DQ
        .de25_sdram_dq_in(core_sdram_dq_in),
        .de25_sdram_dq_out(core_sdram_dq_out),
        .de25_sdram_dq_oe(core_sdram_dq_oe),
`elsif DE25_CORE_IGNORE_SDRAM_DQ
        // Some DDRAM-only legacy cores retain an inactive MiSTer SDRAM
        // controller. Leave that controller's bidirectional port internal so
        // it can never contend with the DE25-Nano's soldered SDRAM devices.
        .SDRAM_DQ(),
`else
        .SDRAM_DQ(DRAM_DQ),
`endif
        .SDRAM_DQML(core_sdram_dqml),
        .SDRAM_DQMH(core_sdram_dqmh),
        .SDRAM_nCS(core_sdram_ncs),
        .SDRAM_nCAS(core_sdram_ncas),
        .SDRAM_nRAS(core_sdram_nras),
        .SDRAM_nWE(core_sdram_nwe),
        .UART_CTS(1'b0),
        .UART_RTS(core_uart_rts),
        .UART_RXD(FPGA_UART_RX),
        .UART_TXD(core_uart_tx),
        .UART_DTR(core_uart_dtr),
        .UART_DSR(1'b0),
        .USER_IN(7'h7f),
        .USER_OUT(core_user_out),
        .OSD_STATUS(shell_osd_status)
    );

`ifdef DE25_CORE_HAS_SDRAM
    // The two 64 MB SDRAM devices are soldered to the DE25-Nano and share all
    // signals except chip select. MiSTer's nCS is a rank selector, not a
    // global deselect. CKE low is the platform quiesce request. Keep the rank
    // selects as direct registered-core paths so Quartus can use the output
    // registers and meet the SDRAM command setup time. With CKE low, the
    // SDRAM ignores both rank-select values during reset or quiesce.
    wire sdram_bus_enabled = core_sdram_cke & ~game_reset_request;
`ifdef DE25_CORE_HAS_SPLIT_SDRAM_DQ
    assign core_sdram_dq_in = DRAM_DQ;
    // The controller drops its registered DQ enable before acknowledging a
    // requested quiesce. On unexpected PLL loss the dedicated bus is already
    // made harmless by CKE low and both ranks deselected, so keeping this path
    // free of an extra asynchronous gate lets the DQ registers pack into I/O.
    assign DRAM_DQ = core_sdram_dq_oe ?
                     core_sdram_dq_out : 16'bZ;
`endif
    assign DRAM_CLK   = core_sdram_clk;
    assign DRAM_CKE   = sdram_bus_enabled;
    assign DRAM_ADDR  = core_sdram_addr;
    assign DRAM_BA    = core_sdram_ba;
    assign DRAM_LDQM  = core_sdram_dqml;
    assign DRAM_UDQM  = core_sdram_dqmh;
    assign DRAM_WE_n  = core_sdram_nwe;
    assign DRAM_CAS_n = core_sdram_ncas;
    assign DRAM_RAS_n = core_sdram_nras;

    assign DRAM_CS_n[0] =  core_sdram_ncs;
    assign DRAM_CS_n[1] = ~core_sdram_ncs;
`else
    // A core which does not use native SDRAM normally drives these ports to
    // high impedance. Keep the physical device explicitly deselected instead
    // of allowing a floating core output to become an active chip select.
    assign DRAM_CLK   = 1'b0;
    assign DRAM_CKE   = 1'b0;
    assign DRAM_ADDR  = 13'd0;
    assign DRAM_BA    = 2'd0;
    assign DRAM_LDQM  = 1'b1;
    assign DRAM_UDQM  = 1'b1;
    assign DRAM_CS_n  = 2'b11;
    assign DRAM_WE_n  = 1'b1;
    assign DRAM_CAS_n = 1'b1;
    assign DRAM_RAS_n = 1'b1;
    assign DRAM_DQ    = 16'bZ;
`endif

    // MiSTer Main sends the menu bitmap over the OSD SPI chip select. Scaled
    // cores must composite it after the framebuffer scaler. NES has only 256
    // source pixels per line, which cannot represent MiSTer's 512-column OSD;
    // compositing before the scaler therefore aliases the menu into a narrow
    // vertical strip. The fixed 640x480 side has enough pixels and a continuous
    // pixel clock. Direct-video personas retain the original core-video input.
`ifdef DE25_MENU_CORE
    // Menu already generates the fixed 640x480 platform mode. Keep its OSD
    // and forwarded HDMI clock in the same core video domain. Routing Menu's
    // OSD through clk_aux while forwarding core_clk_video creates a real
    // asynchronous output crossing and produces intermittent tearing/flicker.
    wire        shell_osd_clk = core_clk_video;
    wire [23:0] shell_osd_input_data = {core_r, core_g, core_b};
    wire        shell_osd_input_de = core_de;
    wire        shell_osd_input_vs = core_vs;
    wire        shell_osd_input_hs = core_hs;
`elsif DE25_VIDEO_SCALER
    wire        shell_osd_clk = clk_aux;
    wire [23:0] shell_osd_input_data = scaler_video_data;
    wire        shell_osd_input_de = scaler_video_de;
    wire        shell_osd_input_vs = scaler_video_vs;
    wire        shell_osd_input_hs = scaler_video_hs;
`else
    wire        shell_osd_clk = core_clk_video;
    wire [23:0] shell_osd_input_data = {core_r, core_g, core_b};
    wire        shell_osd_input_de = core_de;
    wire        shell_osd_input_vs = core_vs;
    wire        shell_osd_input_hs = core_hs;
`endif

    osd shell_osd (
        .clk_sys(core_clk_sys),
`ifdef DE25_MENU_CORE
        .menu_core(1'b1),
`else
        .menu_core(1'b0),
`endif
`ifdef DE25_VIDEO_SCALER
        // Fixed-scaled cores expose a full 16-row MiSTer configuration menu.
        // Do not depend on the line-8 SPI write arriving before OSD enable.
        .force_highres(1'b1),
`else
        .force_highres(1'b0),
`endif
        .io_osd(io_osd),
        .io_strobe(io_strobe),
        .io_din(io_din),
        .clk_video(shell_osd_clk),
        .din(shell_osd_input_data),
        .de_in(shell_osd_input_de),
        .vs_in(shell_osd_input_vs),
        .hs_in(shell_osd_input_hs),
        .dout(shell_video_data),
        .de_out(shell_video_de),
        .vs_out(shell_video_vs),
        .hs_out(shell_video_hs),
        .osd_status(shell_osd_status)
    );

`ifdef DE25_VIDEO_SCALER
    // MiSTer's production framebuffer scaler converts each core's native
    // video clock into the fixed 640x480 clock accepted by the DE25 ADV7513.
    // ao486 and PC110 use the 0x30000000 window for system RAM, unlike the
    // standard 0x20000000 core allocation. Put their scaler in the other
    // 256 MiB half so video traffic cannot overwrite x86 RAM or BIOS data.
`ifdef DE25_AO486_CORE
    localparam logic [31:0] scaler_rambase = 32'h2000_0000;
`elsif DE25_PC110_CORE
    localparam logic [31:0] scaler_rambase = 32'h2000_0000;
`else
    localparam logic [31:0] scaler_rambase = 32'h3000_0000;
`endif
`ifdef DE25_PC110_CORE
    // Use a complete frame store for physical output as well as screenshots.
    // PC110's source frame cadence is independent of the fixed HDMI timing;
    // a two-line CDC cannot safely phase-lock those frames and can expose its
    // blanking hold as a wide black split. The scaler absorbs that cadence
    // difference and emits an uninterrupted 640x480 stream on clk_aux.
`endif
    ascal #(
        .RAMBASE(scaler_rambase),
        .RAMSIZE(32'h0020_0000),
        .PALETTE(1'b0),
        .PALETTE2(1'b0),
        .ADAPTIVE(1'b0),
        .FRAC(8),
        .OHRES(1024),
        .IHRES(1024),
        // Keep MiSTer's native 128-bit, 256-byte scaler transactions intact.
        // The Agilex HPS bridge is 256 bits wide and Platform Designer adapts
        // this interface directly without the previous 64-bit repacking path.
        .N_DW(128),
        .N_AW(28),
        .N_BURST(256)
    ) video_scaler (
        .reset_na(~core_reset),
        .run(1'b1),
        .freeze(1'b0),
        .bob_deint(1'b0),
        .i_clk(core_clk_video),
        .i_ce(core_ce_pixel),
        .i_r(core_r),
        .i_g(core_g),
        .i_b(core_b),
        .i_hs(core_hs),
        .i_vs(core_vs),
        .i_fl(core_f1),
        .i_de(core_de),
        .iauto(1'b1),
        .himin(0),
        .himax(0),
        .vimin(0),
        .vimax(0),
        .o_clk(clk_aux),
        .o_ce(1'b1),
        .o_r(scaler_video_data[23:16]),
        .o_g(scaler_video_data[15:8]),
        .o_b(scaler_video_data[7:0]),
        .o_hs(scaler_video_hs),
        .o_vs(scaler_video_vs),
        .o_de(scaler_video_de),
        .htotal(800),
        .hsstart(656),
        .hsend(752),
        .hdisp(640),
        .hmin(64),
        .hmax(575),
        .vtotal(525),
        .vsstart(490),
        .vsend(492),
        .vdisp(480),
        .vmin(0),
        .vmax(479),
        .vrr(1'b0),
        .vrrmax(525),
        .swblack(1'b0),
        // Standard MiSTer operation uses triple buffering when low latency is
        // disabled. It lets the independent PC110 and HDMI frame cadences
        // exchange complete frames without tearing.
        .mode(5'b01000),
        .poly_clk(core_clk_sys),
        .poly_a(12'd0),
        .poly_dw(10'd0),
        .poly_wr(1'b0),
        // Use the HPS bridge clock for both sides of the scaler's Avalon port.
        .avl_clk(clk_hps),
        .avl_waitrequest(vbuf_av_waitrequest),
        .avl_readdata(vbuf_av_readdata),
        .avl_readdatavalid(vbuf_av_readdatavalid),
        .avl_burstcount(scaler_ddram_burstcount),
        .avl_writedata(scaler_ddram_writedata),
        .avl_address(scaler_ddram_address),
        .avl_write(scaler_ddram_write),
        .avl_read(scaler_ddram_read),
        .avl_byteenable(scaler_ddram_byteenable),
`ifdef DE25_PC110_CORE
        .debug_state0(pc110_scaler_debug_state0),
        .debug_state1(pc110_scaler_debug_state1)
`else
        .debug_state0(),
        .debug_state1()
`endif
    );

`ifdef DE25_PLL_DIAGNOSTIC
`ifdef DE25_AO486_CORE
    // Once the core DDR response probe has completed, publish a sticky trace
    // of the complete scaler pipeline: input active video, input RGB, frame
    // writes, frame reads, returned DDR data, and output active video.
    logic ao486_scaler_input_de_seen = 1'b0;
    logic ao486_scaler_input_rgb_seen = 1'b0;
    logic ao486_scaler_write_seen = 1'b0;
    logic ao486_scaler_read_seen = 1'b0;
    logic ao486_scaler_response_seen = 1'b0;
    logic ao486_scaler_output_de_seen = 1'b0;
    logic [5:0] ao486_scaler_diag_meta = 6'd0;
    logic [5:0] ao486_scaler_diag_sync = 6'd0;

    always_ff @(posedge core_clk_video) begin
        if (core_reset) begin
            ao486_scaler_input_de_seen <= 1'b0;
            ao486_scaler_input_rgb_seen <= 1'b0;
        end else if (core_ce_pixel) begin
            if (shell_video_de)
                ao486_scaler_input_de_seen <= 1'b1;
            if (shell_video_de && (|shell_video_data))
                ao486_scaler_input_rgb_seen <= 1'b1;
        end
    end

    always_ff @(posedge clk_hps) begin
        if (vbuf_domain_reset) begin
            ao486_scaler_write_seen <= 1'b0;
            ao486_scaler_read_seen <= 1'b0;
            ao486_scaler_response_seen <= 1'b0;
        end else begin
            if (scaler_ddram_write && !vbuf_av_waitrequest)
                ao486_scaler_write_seen <= 1'b1;
            if (scaler_ddram_read && !vbuf_av_waitrequest)
                ao486_scaler_read_seen <= 1'b1;
            if (vbuf_av_readdatavalid)
                ao486_scaler_response_seen <= 1'b1;
        end

        ao486_scaler_diag_meta <= {
            ao486_scaler_input_de_seen,
            ao486_scaler_input_rgb_seen,
            ao486_scaler_write_seen,
            ao486_scaler_read_seen,
            ao486_scaler_response_seen,
            ao486_scaler_output_de_seen
        };
        ao486_scaler_diag_sync <= ao486_scaler_diag_meta;
    end

    always_ff @(posedge clk_aux) begin
        if (core_reset)
            ao486_scaler_output_de_seen <= 1'b0;
        else if (scaler_video_de)
            ao486_scaler_output_de_seen <= 1'b1;
    end

    assign ao486_scaler_diagnostic = ao486_scaler_diag_sync;
`elsif DE25_PC110_CORE
    // Expose one sticky bit for every stage of the PC110 scaler path. The
    // diagnostic page distinguishes a healthy source/frame writer from the
    // independent LPDDR reader and fixed-rate HDMI output without changing
    // video timing or memory traffic.
    logic pc110_scaler_input_de_seen = 1'b0;
    logic pc110_scaler_input_rgb_seen = 1'b0;
    logic pc110_scaler_write_seen = 1'b0;
    logic pc110_scaler_read_seen = 1'b0;
    logic pc110_scaler_response_seen = 1'b0;
    logic pc110_scaler_output_de_seen = 1'b0;
    logic pc110_scaler_second_read_seen = 1'b0;
    logic pc110_scaler_full_burst_seen = 1'b0;
    logic pc110_scaler_response_nonzero_seen = 1'b0;
    logic pc110_scaler_output_rgb_seen = 1'b0;
    logic pc110_scaler_output_hs_low_seen = 1'b0;
    logic pc110_scaler_output_vs_low_seen = 1'b0;
    logic pc110_scaler_first_read_seen = 1'b0;
    logic [4:0] pc110_scaler_response_count = 5'd0;
    logic [5:0] pc110_scaler_diag_meta = 6'd0;
    logic [5:0] pc110_scaler_diag_sync = 6'd0;
    logic [5:0] pc110_scaler_data_diag_meta = 6'd0;
    logic [5:0] pc110_scaler_data_diag_sync = 6'd0;

    always_ff @(posedge core_clk_video) begin
        if (core_reset) begin
            pc110_scaler_input_de_seen <= 1'b0;
            pc110_scaler_input_rgb_seen <= 1'b0;
        end else if (core_ce_pixel) begin
            if (shell_video_de)
                pc110_scaler_input_de_seen <= 1'b1;
            if (shell_video_de && (|shell_video_data))
                pc110_scaler_input_rgb_seen <= 1'b1;
        end
    end

    always_ff @(posedge clk_hps) begin
        if (vbuf_domain_reset) begin
            pc110_scaler_write_seen <= 1'b0;
            pc110_scaler_read_seen <= 1'b0;
            pc110_scaler_response_seen <= 1'b0;
            pc110_scaler_second_read_seen <= 1'b0;
            pc110_scaler_full_burst_seen <= 1'b0;
            pc110_scaler_response_nonzero_seen <= 1'b0;
            pc110_scaler_first_read_seen <= 1'b0;
            pc110_scaler_response_count <= 5'd0;
            pc110_scaler_first_read_address <= 28'd0;
            pc110_scaler_min_read_address <= {28{1'b1}};
            pc110_scaler_max_read_address <= 28'd0;
            pc110_scaler_last_read_address <= 28'd0;
            pc110_scaler_read_address_seen <= 1'b0;
            pc110_scaler_read_address_changed <= 1'b0;
            pc110_scaler_read_burstcount <= 8'd0;
            pc110_scaler_first_response0 <= 128'd0;
            pc110_scaler_first_response1 <= 128'd0;
            pc110_scaler_first_response2 <= 128'd0;
            pc110_scaler_first_response3 <= 128'd0;
        end else begin
            if (scaler_ddram_write && !vbuf_av_waitrequest)
                pc110_scaler_write_seen <= 1'b1;
            if (scaler_ddram_read && !vbuf_av_waitrequest) begin
                pc110_scaler_read_seen <= 1'b1;
                pc110_scaler_last_read_address <= scaler_ddram_address;
                pc110_scaler_read_burstcount <= scaler_ddram_burstcount;
                if (!pc110_scaler_read_address_seen) begin
                    pc110_scaler_first_read_address <= scaler_ddram_address;
                    pc110_scaler_min_read_address <= scaler_ddram_address;
                    pc110_scaler_max_read_address <= scaler_ddram_address;
                end else begin
                    if (scaler_ddram_address < pc110_scaler_min_read_address)
                        pc110_scaler_min_read_address <= scaler_ddram_address;
                    if (scaler_ddram_address > pc110_scaler_max_read_address)
                        pc110_scaler_max_read_address <= scaler_ddram_address;
                    if (scaler_ddram_address != pc110_scaler_first_read_address)
                        pc110_scaler_read_address_changed <= 1'b1;
                end
                pc110_scaler_read_address_seen <= 1'b1;
                if (pc110_scaler_first_read_seen)
                    pc110_scaler_second_read_seen <= 1'b1;
                pc110_scaler_first_read_seen <= 1'b1;
            end
            if (vbuf_av_readdatavalid) begin
                pc110_scaler_response_seen <= 1'b1;
                case (pc110_scaler_response_count)
                    5'd0: pc110_scaler_first_response0 <= vbuf_av_readdata;
                    5'd1: pc110_scaler_first_response1 <= vbuf_av_readdata;
                    5'd2: pc110_scaler_first_response2 <= vbuf_av_readdata;
                    5'd3: pc110_scaler_first_response3 <= vbuf_av_readdata;
                    default: begin end
                endcase
                if (|vbuf_av_readdata)
                    pc110_scaler_response_nonzero_seen <= 1'b1;
                if (pc110_scaler_response_count < 5'd16)
                    pc110_scaler_response_count <=
                        pc110_scaler_response_count + 1'b1;
                if (pc110_scaler_response_count == 5'd15)
                    pc110_scaler_full_burst_seen <= 1'b1;
            end
        end

        pc110_scaler_diag_meta <= {
            pc110_scaler_input_de_seen,
            pc110_scaler_input_rgb_seen,
            pc110_scaler_write_seen,
            pc110_scaler_read_seen,
            pc110_scaler_response_seen,
            pc110_scaler_output_de_seen
        };
        pc110_scaler_diag_sync <= pc110_scaler_diag_meta;
        pc110_scaler_data_diag_meta <= {
            pc110_scaler_second_read_seen,
            pc110_scaler_full_burst_seen,
            pc110_scaler_response_nonzero_seen,
            pc110_scaler_output_rgb_seen,
            pc110_scaler_output_hs_low_seen,
            pc110_scaler_output_vs_low_seen
        };
        pc110_scaler_data_diag_sync <= pc110_scaler_data_diag_meta;
    end

    always_ff @(posedge clk_aux) begin
        if (core_reset) begin
            pc110_scaler_output_de_seen <= 1'b0;
            pc110_scaler_output_rgb_seen <= 1'b0;
            pc110_scaler_output_hs_low_seen <= 1'b0;
            pc110_scaler_output_vs_low_seen <= 1'b0;
        end else begin
            if (scaler_video_de)
                pc110_scaler_output_de_seen <= 1'b1;
            if (scaler_video_de && (|scaler_video_data))
                pc110_scaler_output_rgb_seen <= 1'b1;
            if (!scaler_video_hs)
                pc110_scaler_output_hs_low_seen <= 1'b1;
            if (!scaler_video_vs)
                pc110_scaler_output_vs_low_seen <= 1'b1;
        end
    end

    assign pc110_scaler_diagnostic = pc110_scaler_diag_sync;
    assign pc110_scaler_data_diagnostic = pc110_scaler_data_diag_sync;
`endif
`endif
`endif

`ifdef DE25_MENU_CORE
    // SW3 selects a self-contained 640x480 timing and color-bar probe. In
    // normal operation Menu must always use the shared OSD compositor. A
    // physical switch must not silently bypass Main's menu bitmap.
    logic [9:0] hdmi_probe_h = '0;
    logic [9:0] hdmi_probe_v = '0;
    logic [23:0] hdmi_probe_data;
    wire hdmi_probe_de = (hdmi_probe_h < 640) && (hdmi_probe_v < 480);
    wire hdmi_probe_hs = !((hdmi_probe_h >= 656) && (hdmi_probe_h < 752));
    wire hdmi_probe_vs = !((hdmi_probe_v >= 490) && (hdmi_probe_v < 492));

    always_ff @(posedge core_clk_video) begin
        if (core_reset) begin
            hdmi_probe_h <= '0;
            hdmi_probe_v <= '0;
        end else if (hdmi_probe_h == 799) begin
            hdmi_probe_h <= '0;
            if (hdmi_probe_v == 524)
                hdmi_probe_v <= '0;
            else
                hdmi_probe_v <= hdmi_probe_v + 1'b1;
        end else begin
            hdmi_probe_h <= hdmi_probe_h + 1'b1;
        end
    end

    always_comb begin
        if (!hdmi_probe_de)
            hdmi_probe_data = 24'h000000;
        else if (hdmi_probe_h < 80)
            hdmi_probe_data = 24'hffffff;
        else if (hdmi_probe_h < 160)
            hdmi_probe_data = 24'hffff00;
        else if (hdmi_probe_h < 240)
            hdmi_probe_data = 24'h00ffff;
        else if (hdmi_probe_h < 320)
            hdmi_probe_data = 24'h00ff00;
        else if (hdmi_probe_h < 400)
            hdmi_probe_data = 24'hff00ff;
        else if (hdmi_probe_h < 480)
            hdmi_probe_data = 24'hff0000;
        else if (hdmi_probe_h < 560)
            hdmi_probe_data = 24'h0000ff;
        else
            hdmi_probe_data = 24'h000000;
    end

    wire [23:0] hdmi_selected_data = SW[3] ? hdmi_probe_data : shell_video_data;
    wire hdmi_selected_de = SW[3] ? hdmi_probe_de : shell_video_de;
    wire hdmi_selected_hs = SW[3] ? hdmi_probe_hs : shell_video_hs;
    wire hdmi_selected_vs = SW[3] ? hdmi_probe_vs : shell_video_vs;
`else
`ifdef DE25_VIDEO_SCALER
`ifdef DE25_PC110_CORE
    // Hardware-only HDMI discriminator for PC110 bring-up. For roughly the
    // first ten seconds after Main releases the core, drive a self-contained
    // 640x480 test pattern from the same clk_aux domain as the scaler. This
    // proves the ADV7513 bus and forwarded clock independently, then changes
    // over to the real scaler output without requiring a physical switch.
    logic [27:0] pc110_hdmi_probe_hold = '0;
    logic  [9:0] pc110_hdmi_probe_h = '0;
    logic  [9:0] pc110_hdmi_probe_v = '0;
    logic [23:0] pc110_hdmi_probe_data;
    // The production image uses the scaler. A separate immutable diagnostic
    // RBF keeps this probe forced on for physical HDMI-path validation.
    wire pc110_hdmi_probe_active = 1'b0;
    wire pc110_hdmi_probe_de =
        (pc110_hdmi_probe_h < 640) && (pc110_hdmi_probe_v < 480);
    wire pc110_hdmi_probe_hs =
        !((pc110_hdmi_probe_h >= 656) && (pc110_hdmi_probe_h < 752));
    wire pc110_hdmi_probe_vs =
        !((pc110_hdmi_probe_v >= 490) && (pc110_hdmi_probe_v < 492));

    always_ff @(posedge clk_aux) begin
        if (core_reset) begin
            pc110_hdmi_probe_hold <= '0;
            pc110_hdmi_probe_h <= '0;
            pc110_hdmi_probe_v <= '0;
        end else begin
            if (!(&pc110_hdmi_probe_hold))
                pc110_hdmi_probe_hold <= pc110_hdmi_probe_hold + 1'b1;
            if (pc110_hdmi_probe_h == 799) begin
                pc110_hdmi_probe_h <= '0;
                if (pc110_hdmi_probe_v == 524)
                    pc110_hdmi_probe_v <= '0;
                else
                    pc110_hdmi_probe_v <= pc110_hdmi_probe_v + 1'b1;
            end else begin
                pc110_hdmi_probe_h <= pc110_hdmi_probe_h + 1'b1;
            end
        end
    end

    always_comb begin
        if (!pc110_hdmi_probe_de)
            pc110_hdmi_probe_data = 24'h000000;
        else if (pc110_hdmi_probe_h < 80)
            pc110_hdmi_probe_data = 24'hffffff;
        else if (pc110_hdmi_probe_h < 160)
            pc110_hdmi_probe_data = 24'hffff00;
        else if (pc110_hdmi_probe_h < 240)
            pc110_hdmi_probe_data = 24'h00ffff;
        else if (pc110_hdmi_probe_h < 320)
            pc110_hdmi_probe_data = 24'h00ff00;
        else if (pc110_hdmi_probe_h < 400)
            pc110_hdmi_probe_data = 24'hff00ff;
        else if (pc110_hdmi_probe_h < 480)
            pc110_hdmi_probe_data = 24'hff0000;
        else if (pc110_hdmi_probe_h < 560)
            pc110_hdmi_probe_data = 24'h0000ff;
        else
            pc110_hdmi_probe_data = 24'h000000;
    end
`endif

    // Register the scaler bus on the source-clock edge. The ADV7513 samples
    // it on the opposite forwarded-clock edge, providing a deterministic
    // half-cycle setup interval and preventing combinational scaler activity
    // from appearing as colored vertical lines on the physical HDMI output.
    // Preserve these registers so synthesis cannot merge them back into the
    // scaler's internal pipeline. The physical pins must have one explicit,
    // common launch edge.
    (* preserve *) logic [23:0] hdmi_selected_data = 24'd0;
    (* preserve *) logic hdmi_selected_de = 1'b0;
    (* preserve *) logic hdmi_selected_hs = 1'b1;
    (* preserve *) logic hdmi_selected_vs = 1'b1;
    always_ff @(posedge clk_aux) begin
        if (core_reset) begin
            hdmi_selected_data <= 24'd0;
            hdmi_selected_de <= 1'b0;
            hdmi_selected_hs <= 1'b1;
            hdmi_selected_vs <= 1'b1;
`ifdef DE25_PC110_CORE
        end else if (pc110_hdmi_probe_active) begin
            hdmi_selected_data <= pc110_hdmi_probe_data;
            hdmi_selected_de <= pc110_hdmi_probe_de;
            hdmi_selected_hs <= pc110_hdmi_probe_hs;
            hdmi_selected_vs <= pc110_hdmi_probe_vs;
`endif
        end else begin
            hdmi_selected_data <= shell_video_data;
            hdmi_selected_de <= shell_video_de;
            hdmi_selected_hs <= shell_video_hs;
            hdmi_selected_vs <= shell_video_vs;
        end
    end
`else
    wire [23:0] hdmi_selected_data = shell_video_data;
    wire hdmi_selected_de = shell_video_de;
    wire hdmi_selected_hs = shell_video_hs;
    wire hdmi_selected_vs = shell_video_vs;
`endif
`endif

    // Core video is registered on the rising edge of its source clock. The
    // ADV7513 samples its parallel input on a rising edge, so forward the
    // opposite phase to give RGB, DE, and sync half a pixel period of setup.
    // The output-delay constraints model this same inverted relationship.
`ifdef DE25_MENU_CORE
    // Menu's direct HDMI data and sync are registered by core_clk_video. The
    // scaler remains compiled for framebuffer capture, but it does not own the
    // direct Menu output clock.
    assign HDMI_TX_CLK = ~core_clk_video;
`elsif DE25_VIDEO_SCALER
    assign HDMI_TX_CLK = ~clk_aux;
`else
    assign HDMI_TX_CLK = ~core_clk_video;
`endif
    assign HDMI_TX_HS  = hdmi_selected_hs;
    assign HDMI_TX_VS  = hdmi_selected_vs;
    assign HDMI_TX_D   = hdmi_selected_data;
    assign HDMI_TX_DE  = hdmi_selected_de;
    assign HDMI_MCLK   = clk_audio;
    assign HDMI_SCLK   = audio_bit_clock;
    assign HDMI_LRCLK  = audio_word_clock;
    assign HDMI_I2S    = audio_data;
    assign FPGA_UART_TX = core_uart_tx;

    logic hdmi_init_done;
    logic hdmi_init_error;
    logic hdmi_status_valid;
    logic hdmi_transmitter_powered;
    logic hdmi_hpd_high;
    logic hdmi_monitor_sense;
    logic hdmi_pll_locked;
    logic hdmi_tmds_powered;
    logic hdmi_edid_ready;
    logic [3:0] hdmi_ddc_state;
    logic [3:0] hdmi_ddc_error;
    logic [63:0] hdmi_raw_status;

    // Hold the transmitter initializer in reset after every FPGA load. The
    // SDM reset-release signal can already be inactive on the first fabric
    // clock edge, so relying on it alone does not guarantee an observable
    // reset pulse when a core is loaded over JTAG.
    logic [19:0] hdmi_power_on_reset = '0;
    always_ff @(posedge CLOCK0_50 or posedge ninit_done) begin
        if (ninit_done)
            hdmi_power_on_reset <= '0;
        else if (!(&hdmi_power_on_reset))
            hdmi_power_on_reset <= hdmi_power_on_reset + 1'b1;
    end

    adv7513_init hdmi_init (
        .clk(CLOCK0_50),
        .reset_n(~ninit_done & KEY[1] & (&hdmi_power_on_reset)),
        .interrupt_n(HDMI_TX_INT),
        .scl(HDMI_I2C_SCL),
        .sda(HDMI_I2C_SDA),
        .done(hdmi_init_done),
        .ack_error(hdmi_init_error),
        .status_valid(hdmi_status_valid),
        .transmitter_powered(hdmi_transmitter_powered),
        .hpd_high(hdmi_hpd_high),
        .monitor_sense(hdmi_monitor_sense),
        .pll_locked(hdmi_pll_locked),
        .tmds_outputs_powered(hdmi_tmds_powered),
        .edid_ready(hdmi_edid_ready),
        .ddc_state(hdmi_ddc_state),
        .ddc_error(hdmi_ddc_error),
        .raw_status(hdmi_raw_status)
    );

    mister_hps hps (
        .clk_100_clk(clk_hps),
        .mister_ddram_clk_clk(ddram_domain_clk),
        .mister_ddram_reset_reset(ddram_domain_reset),
        .mister_ddram_waitrequest(av_waitrequest),
        .mister_ddram_readdata(av_readdata),
        .mister_ddram_readdatavalid(av_readdatavalid),
        .mister_ddram_burstcount(av_burstcount),
        .mister_ddram_writedata(av_writedata),
        .mister_ddram_address(av_address),
        .mister_ddram_write(av_write),
        .mister_ddram_read(av_read),
        .mister_ddram_byteenable(av_byteenable),
        .mister_ddram_debugaccess(1'b0),
`ifndef DE25_HPS_LEGACY_NO_VBUF
        .mister_vbuf_waitrequest(vbuf_av_waitrequest),
        .mister_vbuf_readdata(vbuf_av_readdata),
        .mister_vbuf_readdatavalid(vbuf_av_readdatavalid),
        .mister_vbuf_burstcount(vbuf_av_burstcount),
        .mister_vbuf_writedata(vbuf_av_writedata),
        .mister_vbuf_address(vbuf_av_address),
        .mister_vbuf_write(vbuf_av_write),
        .mister_vbuf_read(vbuf_av_read),
        .mister_vbuf_byteenable(vbuf_av_byteenable),
        .mister_vbuf_debugaccess(1'b0),
`endif
        .mister_gp_in_export(hps_gp_in),
        .mister_gp_out_export(hps_gp_out),
        .reset_reset_n(qsys_reset_n),
        .ninit_done_ninit_done(ninit_done),
        .h2f_reset_reset(h2f_reset),
`ifndef DE25_HPS_LEGACY_NO_VBUF
        .mister_h2f_bridge_reset_reset(h2f_reset),
`endif
        .h2f_warm_reset_handshake_reset_req(h2f_warm_reset_req),
        .h2f_warm_reset_handshake_reset_ack(h2f_warm_reset_ack),
        .hps_io_hps_osc_clk(HPS_CLK_25),
        .hps_io_sdmmc_data0(HPS_SD_DATA[0]),
        .hps_io_sdmmc_data1(HPS_SD_DATA[1]),
        .hps_io_sdmmc_cclk(HPS_SD_CLK),
        .hps_io_sdmmc_data2(HPS_SD_DATA[2]),
        .hps_io_sdmmc_data3(HPS_SD_DATA[3]),
        .hps_io_sdmmc_cmd(HPS_SD_CMD),
        .hps_io_usb0_clk(HPS_USB_CLK),
        .hps_io_usb0_stp(HPS_USB_STP),
        .hps_io_usb0_dir(HPS_USB_DIR),
        .hps_io_usb0_data0(HPS_USB_DATA[0]),
        .hps_io_usb0_data1(HPS_USB_DATA[1]),
        .hps_io_usb0_nxt(HPS_USB_NXT),
        .hps_io_usb0_data2(HPS_USB_DATA[2]),
        .hps_io_usb0_data3(HPS_USB_DATA[3]),
        .hps_io_usb0_data4(HPS_USB_DATA[4]),
        .hps_io_usb0_data5(HPS_USB_DATA[5]),
        .hps_io_usb0_data6(HPS_USB_DATA[6]),
        .hps_io_usb0_data7(HPS_USB_DATA[7]),
        .hps_io_emac0_tx_clk(HPS_ENET_TX_CLK),
        .hps_io_emac0_tx_ctl(HPS_ENET_TX_CTL),
        .hps_io_emac0_rx_clk(HPS_ENET_RX_CLK),
        .hps_io_emac0_rx_ctl(HPS_ENET_RX_CTL),
        .hps_io_emac0_txd0(HPS_ENET_TX_DATA[0]),
        .hps_io_emac0_txd1(HPS_ENET_TX_DATA[1]),
        .hps_io_emac0_rxd0(HPS_ENET_RX_DATA[0]),
        .hps_io_emac0_rxd1(HPS_ENET_RX_DATA[1]),
        .hps_io_emac0_txd2(HPS_ENET_TX_DATA[2]),
        .hps_io_emac0_txd3(HPS_ENET_TX_DATA[3]),
        .hps_io_emac0_rxd2(HPS_ENET_RX_DATA[2]),
        .hps_io_emac0_rxd3(HPS_ENET_RX_DATA[3]),
        .hps_io_mdio0_mdio(HPS_ENET_MDIO),
        .hps_io_mdio0_mdc(HPS_ENET_MDC),
        .hps_io_uart1_tx(HPS_UART_TX),
        .hps_io_uart1_rx(HPS_UART_RX),
        .hps_io_i2c1_sda(HPS_I2C_SDA),
        .hps_io_i2c1_scl(HPS_I2C_SCL),
        .hps_io_gpio28(HPS_GSENSOR_INT),
        .hps_io_gpio34(HPS_GSENSOR_I2C_EN),
        .hps_io_gpio40(HPS_KEY),
        .hps_io_gpio41(HPS_LED),
        .f2h_irq1_in_irq(32'd0),
        .emif_hps_emif_mem_0_mem_cs(LPDDR4A_CS_n),
        .emif_hps_emif_mem_0_mem_ca(LPDDR4A_CA),
        .emif_hps_emif_mem_0_mem_cke(LPDDR4A_CKE),
        .emif_hps_emif_mem_0_mem_dq(LPDDR4A_DQ),
        .emif_hps_emif_mem_0_mem_dqs_t(LPDDR4A_DQS),
        .emif_hps_emif_mem_0_mem_dqs_c(LPDDR4A_DQS_n),
        .emif_hps_emif_mem_0_mem_dmi(LPDDR4A_DM),
        .emif_hps_emif_mem_ck_0_mem_ck_t(LPDDR4A_CK),
        .emif_hps_emif_mem_ck_0_mem_ck_c(LPDDR4A_CK_n),
        .emif_hps_emif_mem_reset_n_mem_reset_n(LPDDR4A_RESET_n),
        .emif_hps_emif_oct_0_oct_rzqin(LPDDR4A_RZQ),
        .emif_hps_emif_ref_clk_0_clk(LPDDR4A_REFCLK_p),
        .button_pio_external_connection_export({2'b11, KEY}),
        .dipsw_pio_external_connection_export(SW),
        .led_pio_external_connection_in_port({hdmi_pll_locked, hdmi_hpd_high, hdmi_init_done}),
        .led_pio_external_connection_out_port(hps_led_out)
    );

    always_ff @(posedge clk_hps) begin
        if (hps_domain_reset)
            heartbeat <= '0;
        else
            heartbeat <= heartbeat + 1'b1;
    end

    always_comb begin
        LED[0] = platform_locked;
        LED[1] = ~hps_domain_reset;
        LED[2] = ~core_reset;
        LED[3] = ddram_read | ddram_write;
        LED[4] = hdmi_init_done;
        LED[5] = hdmi_hpd_high;
        LED[6] = hdmi_pll_locked;
`ifdef DE25_PLATFORM_V2
        // A slow blink means the external clock service needs attention. A
        // steady light means identity and both output counters are healthy.
        LED[7] = (hdmi_init_error || v2_si5332_fault) ? heartbeat[20] :
                 v2_external_clocks_ready;
`else
        LED[7] = hdmi_init_error ? heartbeat[20] : core_led_user;
`endif
    end

    wire unused = &{1'b0, clk_aux, gp_out_sync[0], io_ack, core_led_power,
                    core_led_disk, core_buttons, core_uart_rts, core_uart_dtr,
                    core_user_out, adc_bus, hdmi_status_valid,
                    hdmi_transmitter_powered, hdmi_monitor_sense,
                    hdmi_tmds_powered, hdmi_edid_ready, hdmi_ddc_state,
                    hdmi_ddc_error, hdmi_raw_status, hps_led_out,
`ifdef DE25_PLATFORM_V2
                    v2_clock1_frequency_khz, v2_clock2_frequency_khz,
                    v2_si5332_identity, v2_si5332_address,
                    v2_si5332_identity_valid,
`endif
`ifdef DE25_CORE_HAS_FB
                    core_fb_format, core_fb_width, core_fb_height,
                    core_fb_base, core_fb_stride, core_fb_force_blank,
`ifdef DE25_CORE_HAS_FB_PALETTE
                    core_fb_pal_din,
`endif
`endif
                    FAN_ALERT_n};
endmodule
`default_nettype wire
