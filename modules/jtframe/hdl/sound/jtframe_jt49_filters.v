/* This file is part of JTFRAME.


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
    Date: 25-11-2020

*/

module jtframe_jt49_filters(
    input                rst,
    input                clk,
    input         [ 9:0] din0,
    input         [ 9:0] din1,
    input                sample,
    output signed [15:0] dout
);

localparam W=11,WD=16-W;

wire signed [W-1:0] dcrm_snd;
reg         [W-1:0] base_snd;
wire signed [ 15:0] dcrm16 = { dcrm_snd, dcrm_snd[W-2:W-WD-1] };

always @(posedge clk, posedge rst ) begin
    if( rst ) begin
        base_snd <= {W{1'd0}};
    end else if(sample) begin
        base_snd <= { {W-10{1'b0}}, din0} + { {W-10{1'b0}}, din1};
    end
end

jtframe_dcrm #(.SW(W)) u_dcrm(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .sample ( sample    ),
    .din    ( base_snd  ),
    .dout   ( dcrm_snd  )
);

jtframe_fir #(.KMAX(126),.COEFFS("firjt49.hex")) u_fir(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .sample ( sample    ),
    .l_in   ( dcrm16    ),
    .r_in   ( 16'd0     ),
    .l_out  ( dout      ),
    .r_out  (           )
);

endmodule