// SPDX-License-Identifier: GPL-3.0-or-later
// Live OUT0 frequency selection, Si5332 reference manual sections 7.1-7.5.
// OUT1b is the fixed 50 MHz infrastructure clock. On integer-fed OUT1 designs
// its two dividers identify the factory VCO without changing the system PLL.
module de25_si5332_out0 #(parameter integer TARGET_HZ = 49152000) (
    input wire clk, reset, start, fault, sample_toggle,
    input wire [23:0] count_khz,
    output logic clock_ready,
    output wire valid, output logic write,
    output logic [7:0] addr, wdata,
    input wire ready, done,
    input wire [7:0] rdata
);
    typedef enum logic [3:0] {IDLE, MUXES, POWER, BANKS, R0, R1, HSDIV, PLAN,
        SPREAD, PROGRAM, SELECT_BANK, ROUTE, SETTLE, RUN, FAILED} state_t;
    state_t state;
    logic pending, use_id1, id0_used, id1_used;
    logic [2:0] index, ref_mux;
    logic [7:0] mux0, banks, spread;
    logic [5:0] out0_div, out1_div;
    logic [13:0] vco_multiple;
    logic [47:0] words;

    // Fvco = 50 MHz * (OUT1_DIV * HSDIV), within the 2.375-2.625 GHz range.
    // All division below is constant-folded at synthesis for the selected core.
    // A zero entry means the requested N is outside the chip's 10..255 range.
    function automatic [47:0] divider_words(input integer multiple, post_div);
        reg [63:0] numerator, denominator, scaled;
        reg [15:0] intg, residue;
        begin
            numerator = 64'd50000000 * multiple;
            denominator = 64'(TARGET_HZ) * post_div;
            divider_words = 0;
            if (numerator >= 10 * denominator && numerator <= 255 * denominator) begin
                // IDx_INTG = floor(128*N) - 512. RES/DEN is the remainder.
                scaled = (numerator * 128 * 16384 + denominator/2) / denominator;
                intg = (scaled >> 14) - 512;
                residue = scaled & 14'h3fff;
                divider_words = {intg, residue, 16'd16384};
            end
        end
    endfunction
    wire [47:0] plans [48:52][1:63];
    for (genvar m=48; m<=52; m=m+1) begin : vco
        for (genvar r=1; r<=63; r=r+1) begin : output_divider
            assign plans[m][r] = divider_words(m,r);
        end
    end

    wire [7:0] bank_bit = use_id1 ? 8'h80 : 8'h40;
    wire new_bank_b = (banks & bank_bit) == 0;
    wire [7:0] bank_base = (use_id1 ? 8'h4e : 8'h36) + (new_bank_b ? 8'h0c : 8'h00);
    wire [7:0] route = (mux0 & 8'h8f) | (use_id1 ? 8'h60 : 8'h50);
    wire transaction = (state >= MUXES && state <= HSDIV) ||
                       (state >= SPREAD && state <= ROUTE);
    assign valid = transaction && !pending && !fault;

    always_comb begin
        addr = 0;
        wdata = 0;
        write = 0;
        case (state)
            MUXES: addr = 8'h25 + index;
            POWER: addr = 8'hba; // HSDIV/ID power-down readback
            BANKS: addr = 8'h35;
            R0: addr = 8'h7b;
            R1: addr = 8'h80;
            HSDIV: addr = 8'h2b + 2 * ref_mux + banks[ref_mux];
            SPREAD: addr = bank_base + 6;
            PROGRAM: begin
                addr = bank_base + index;
                write = 1;
                // The Si5332 stores the high byte at the lower address.
                if (index < 6) wdata = words[47-index*8 -: 8];
                else wdata = spread & 8'hfe;
            end
            SELECT_BANK: begin addr = 8'h35; write = 1; wdata = banks ^ bank_bit; end
            ROUTE: begin addr = 8'h25; write = 1; wdata = route; end
            default: ;
        endcase
    end

    localparam integer TARGET_KHZ = (TARGET_HZ + 500) / 1000;
    wire frequency_ok = count_khz >= TARGET_KHZ-2 && count_khz <= TARGET_KHZ+2;
    logic previous_sample, have_window;
    logic [1:0] good_windows;

    always_ff @(posedge clk) begin
        previous_sample <= sample_toggle;
        if (reset) begin
            state <= IDLE;
            clock_ready <= 0;
            pending <= 0;
            index <= 0;
            id0_used <= 0;
            id1_used <= 0;
            good_windows <= 0;
            have_window <= 0;
        end else if (fault && transaction) state <= FAILED;
        else begin
            if (previous_sample != sample_toggle) have_window <= 1;
            if (valid && ready) pending <= 1;
            if (done) pending <= 0;
            case (state)
                IDLE: begin
                    // Menu or a previous RBF may already have set this rate.
                    if (have_window && previous_sample != sample_toggle) begin
                        if (frequency_ok) begin
                            if (good_windows == 2) begin
                                clock_ready <= 1;
                                state <= RUN;
                            end
                            else good_windows <= good_windows + 1'b1;
                        end else begin
                            good_windows <= 0;
                            if (start && !fault) state <= MUXES;
                        end
                    end
                end
                MUXES: if (done) begin
                    if (index == 0) mux0 <= rdata;
                    else begin
                        if (rdata[6:4] == 5) id0_used <= 1;
                        if (rdata[6:4] == 6) id1_used <= 1;
                    end
                    if (index == 1) ref_mux <= rdata[6:4];
                    if (index == 5) state <= POWER;
                    else index <= index + 1'b1;
                end
                POWER: if (done) begin
                    // Leave powered-down dividers alone during a live core change.
                    use_id1 <= id0_used || rdata[5];
                    if (((id0_used || rdata[5]) && (id1_used || rdata[6])) || ref_mux > 4)
                        state <= FAILED;
                    else state <= BANKS;
                end
                BANKS: if (done) begin
                    banks <= rdata;
                    state <= R0;
                end
                R0: if (done) begin out0_div <= rdata[5:0]; state <= R1; end
                R1: if (done) begin out1_div <= rdata[5:0]; state <= HSDIV; end
                HSDIV: if (done) begin
                    vco_multiple <= rdata * out1_div;
                    state <= PLAN;
                end
                PLAN: begin
                    if (vco_multiple < 48 || vco_multiple > 52 || out0_div == 0)
                        state <= FAILED;
                    else if (plans[vco_multiple][out0_div] == 0) state <= FAILED;
                    else begin words <= plans[vco_multiple][out0_div]; state <= SPREAD; end
                end
                SPREAD: if (done) begin spread <= rdata; index <= 0; state <= PROGRAM; end
                PROGRAM: if (done) begin
                    if (index == 6) state <= SELECT_BANK;
                    else index <= index + 1'b1;
                end
                SELECT_BANK: if (done) state <= ROUTE;
                ROUTE: if (done) state <= SETTLE;
                SETTLE: if (previous_sample != sample_toggle) begin
                    if (!frequency_ok) good_windows <= 0;
                    else if (good_windows == 2) begin
                        clock_ready <= 1;
                        state <= RUN;
                    end
                    else good_windows <= good_windows + 1'b1;
                end
                RUN: if (previous_sample != sample_toggle && !frequency_ok) begin
                    clock_ready <= 0;
                    good_windows <= 0;
                    state <= SETTLE;
                end
                default: state <= FAILED;
            endcase
        end
    end
endmodule
