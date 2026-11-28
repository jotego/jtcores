module de25_hps_warm_reset_handshake (
    input  wire clk,
    input  wire reset_req_n,
    output wire reset_ack_n,
    output wire reset_pending
);
`ifdef DE25_HPS_RESET_V1_REPRO
`define DE25_HPS_RESET_V1_ACTIVE
`endif
`ifdef DE25_HPS_RESET_V1_RECOVERY
`define DE25_HPS_RESET_V1_ACTIVE
`endif
`ifdef DE25_HPS_RESET_V1_ACTIVE
    // Reproduce the first C600 migration fit exactly. This intentionally
    // acknowledges in the same asynchronous event as the request and must
    // only be used to reconstruct the saved recovery baseline.
    (* ASYNC_REG = "TRUE" *) logic [2:0] request_n_sync = 3'b111;

    always_ff @(posedge clk or negedge reset_req_n) begin
        if (!reset_req_n)
            request_n_sync <= 3'b000;
        else
            request_n_sync <= {request_n_sync[1:0], 1'b1};
    end

    assign reset_ack_n = request_n_sync[2];
    assign reset_pending = ~request_n_sync[2];
`else
    // The Agilex HPS handshake is active low. Assert reset_pending
    // asynchronously so every HPS-facing soft block starts resetting as soon
    // as SDM requests a warm reset. Acknowledge only after that request has
    // remained asserted for three independent FPGA clock edges. This ordering
    // is important: f2h_pending_rst_ack_n means that all HPS soft logic is
    // already in reset, not merely that the request was observed. Synchronize
    // deassertion before releasing reset and acknowledgement.
    (* ASYNC_REG = "TRUE" *) logic [2:0] request_n_sync = 3'b111;
    logic [2:0] acknowledge_delay = 3'b111;

    always_ff @(posedge clk or negedge reset_req_n) begin
        if (!reset_req_n)
            request_n_sync <= 3'b000;
        else
            request_n_sync <= {request_n_sync[1:0], 1'b1};
    end

    always_ff @(posedge clk) begin
        if (!request_n_sync[2])
            acknowledge_delay <= {acknowledge_delay[1:0], 1'b0};
        else
            acknowledge_delay <= 3'b111;
    end

    assign reset_ack_n = |acknowledge_delay;
    assign reset_pending = ~request_n_sync[2] | ~reset_ack_n;
`endif
`ifdef DE25_HPS_RESET_V1_ACTIVE
`undef DE25_HPS_RESET_V1_ACTIVE
`endif
endmodule
