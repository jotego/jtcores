/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 16-4-2022 */

module jtframe_freqinfo #(parameter
    KHZ   = 1,      // set to 1 to output kHz, set to 0 to output Hz
    MFREQ = 48_000, // clk input frequency in kHz
    DIGITS = 4      // count up to 9999 kHz, change to 5 for 10MHz and above
)(
    input             rst,
    input             clk,
    input             pulse,
    output reg [DIGITS*4-1:0] fave,   // average cpu_cen frequency in kHz (BCD encoding)
    output reg [DIGITS*4-1:0] fworst  // worst case registered (BCD)
);

wire cnt_event;
wire cen, ms;

assign ms = freq_cnt == MFREQ-1;

generate
    if( KHZ==1 )
        assign cen = 1;
    else begin
        // counts a full second
        // This is useful when the input signal is below 1kHz
        reg [9:0] div;
        assign cen = div==999;
        always @(posedge clk, posedge rst) begin
            if( rst ) begin
                div <= 0;
            end else begin
                div <= cen ? 10'd0 : div+10'd1;
            end
        end
    end
endgenerate

// Frequency reporting
reg  [15:0] freq_cnt;
wire [DIGITS*4-1:0] fout_cnt;
reg         pulse_l;

assign cnt_event = pulse & ~pulse_l;

always @(posedge clk, posedge rst) begin
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

jtframe_bcd_cnt #(.DIGITS(DIGITS)) u_bcd(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clr        ( ms        ),
    .up         ( cnt_event ),
    .cnt        ( fout_cnt  )
);

endmodule