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
    Date: 2-4-2019 */

// Tape input for DE10-Nano board (MiSTer)

module jtframe_tape(
    input             clk,      // 50 MHz clock
    // ADC control
    input             adc_sdo,
    output            adc_convst,
    output            adc_sck,
    output            adc_sdi,
    // Tape data
    output reg        tape
);

reg [5:0] rst_sr=6'b100_000;
always @(negedge clk) begin
    rst_sr <= { rst_sr[4:0], 1'b1 };
end

wire rst_n = rst_sr[5];

reg last_convst;
wire [11:0] adc_read;
reg [11:0] avg_buf0;
wire[12:0] sum = {1'b0,avg_buf0} + {1'b0,adc_read};
wire [7:0] avg = sum[12:4];

always @(posedge clk ) begin
    last_convst <= adc_convst;
    if( last_convst && !adc_convst ) begin
        avg_buf0 <= adc_read;
    end
    tape  <= avg > 8'h80; // set a threshold different from 0 to avoid noise
end

// clock divider
reg [1:0] adccen_cnt=0;
reg adccen;
always @(negedge clk) begin
    adccen_cnt <= adccen_cnt+2'd1;
    adccen <= adccen_cnt == 2'b00;
end

jtframe_2308 i_jtframe_2308 (
    .rst_n     (rst_n     ),
    .clk       (clk       ),
    .cen       (adccen    ),
    .adc_sdo   (adc_sdo   ),
    .adc_convst(adc_convst),
    .adc_sck   (adc_sck   ),
    .adc_sdi   (adc_sdi   ),
    .adc_read  (adc_read  )
);


endmodule // jtframe_tape