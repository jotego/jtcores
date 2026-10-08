/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-4-2022 */

module jtframe_freqinfo #(parameter
    KHZ   = 1,      // set to 1 to output kHz, set to 0 to output Hz
    MFREQ = `JTFRAME_MCLK/1000, // clk input frequency in kHz
    DIGITS = 4      // count up to 9999 kHz, change to 5 for 10MHz and above
)(
    input             rst,
    input             clk,
    input             pulse,
    output reg [DIGITS*4-1:0] fave,   // average cpu_cen frequency in kHz (BCD encoding)
    output reg [DIGITS*4-1:0] fworst  // worst case registered (BCD)
);

localparam BW=$clog2(MFREQ-1);

wire cnt_event;
wire cen, ms;
reg  [BW-1:0] freq_cnt;
wire [DIGITS*4-1:0] fout_cnt;
reg         pulse_l;

assign ms = freq_cnt == MFREQ[BW-1:0]-1'd1;

generate
    if( KHZ==1 )
        assign cen = 1;
    else begin
        // counts a full second
        // This is useful when the input signal is below 1kHz
        reg [9:0] div;
        assign cen = div==999;
        always @(posedge clk) begin
            if( rst ) begin
                div <= 0;
            end else begin
                div <= cen ? 10'd0 : div+10'd1;
            end
        end
    end
endgenerate

// Frequency reporting
assign cnt_event = pulse & ~pulse_l;

always @(posedge clk) begin
    if( rst ) begin
        freq_cnt <= 0;
        fworst   <= {DIGITS*4{1'b1}};
        fave     <= 0;
    end else begin
        pulse_l <= pulse;
        if( cen ) freq_cnt <= freq_cnt + 1'd1;
        if( ms ) begin // updated every 1ms
            freq_cnt <= 0;
            fave <= fout_cnt;
            if( fworst > fout_cnt ) fworst <= fout_cnt;
        end
    end
end

jtframe_bcd_cnt #(.DIGITS(DIGITS),.WRAP(0)) u_bcd(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clr        ( ms        ),
    .up         ( cnt_event ),
    .cnt        ( fout_cnt  )
);

endmodule