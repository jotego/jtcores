// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps

// MiSTer Main normally exchanges its low-latency control words through the
// Cyclone V HPS general-purpose input and output registers. On DE25-Nano these
// two words are provided by Avalon PIOs on the lightweight HPS bridge. This
// module keeps the observable MiSTer handshake unchanged for sys_top and
// hps_io.
module de25_mister_gp_bridge #(
    parameter logic [7:0] CORE_TYPE = 8'hA4
) (
    input  logic        clk_sys,
    input  logic        reset,

    input  logic [31:0] hps_gp_out,
    output logic [31:0] hps_gp_in,
    output logic [31:0] gp_out_sync,

    input  logic        btn_user,
    input  logic        btn_osd,
    input  logic        osd_status,
    input  logic        io_dig,
    input  logic        hdmi_int_n,
    input  logic  [1:0] io_ver,
    input  logic        io_wait,
    input  logic        vs_wait,
    input  logic        io_wide,
    input  logic [15:0] io_dout,
    input  logic [15:0] io_dout_sys,
    input  logic  [5:0] diagnostic,

    output logic [15:0] io_din,
    output logic        io_fpga,
    output logic        io_uio,
    output logic        io_strobe,
    output logic        io_ack,
    output logic  [1:0] core_reset_state
);

    (* ASYNC_REG = "TRUE" *) logic [31:0] gp_meta = '0;
    (* ASYNC_REG = "TRUE" *) logic [31:0] gp_sync = '0;
    (* ASYNC_REG = "TRUE" *) logic [1:0] osd_status_sync = '0;
    logic        rack;

    wire [31:0] core_magic = {24'h5CA623, CORE_TYPE};
    wire        io_clk = gp_out_sync[17];
    wire        io_ss0 = gp_out_sync[18];
    wire        io_ss1 = gp_out_sync[19];
    wire        io_ss2 = gp_out_sync[20];

    assign gp_out_sync      = gp_sync;
    assign io_din           = gp_sync[15:0];
    assign io_fpga          = ~io_ss1 & io_ss0;
    assign io_uio           = ~io_ss1 & io_ss2;
    assign io_strobe        = ~rack & io_clk;
    assign core_reset_state = gp_sync[31:30];

    wire [31:0] live_response = {
        1'b0,
        btn_user,
        btn_osd,
        io_dig,
        osd_status_sync[1],
        diagnostic,
        ~hdmi_int_n,
        io_ver,
        io_ack,
        io_wide,
        io_dout | io_dout_sys
    };

    // Bit 31 low selects the core identity word. Bit 31 high selects the live
    // response word. This is the contract used by fpga_core_id() in Main.
    assign hps_gp_in = gp_sync[31] ? live_response : core_magic;

    // The software holds data and select bits stable around the strobe. Two
    // stages protect the core clock domain from the lightweight bridge clock.
    always_ff @(posedge clk_sys) begin
        gp_meta <= hps_gp_out;
        gp_sync <= gp_meta;
        osd_status_sync <= {osd_status_sync[0], osd_status};
    end

    // Match the acknowledge behavior in the Cyclone V MiSTer sys_top. A core
    // may hold io_wait or vs_wait while it consumes the current transfer.
    always_ff @(posedge clk_sys) begin
        if (reset) begin
            rack   <= 1'b0;
            io_ack <= 1'b0;
        end else if (!(io_wait | vs_wait) | io_strobe) begin
            rack   <= io_clk;
            io_ack <= rack;
        end
    end

endmodule
