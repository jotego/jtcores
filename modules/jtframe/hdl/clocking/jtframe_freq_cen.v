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
    Date: 8-3-2024

*/

module jtframe_freq_cen #(parameter
    SFREQ = 48,     // desired frequency in kHz
    WC    = 10      // counter bit width
)(
    input       clk,
    output      cen
);

localparam MFREQ = `ifdef JTFRAME_MCLK `JTFRAME_MCLK `else 48000 `endif;

reg [WC-1:0] m,n;
integer tn,tm,err,berr,eff;
wire    nc;

initial begin
    berr = MFREQ;
    for(tm=1;tm<(1<<WC)-1;tm=tm+1) begin
        tn = SFREQ*tm/MFREQ;
        eff= MFREQ*tn/tm;
        err = SFREQ-eff;
        if( err<0 ) err=-err;
        if( err<berr ) begin
            berr = err;
            n    = tn[9:0];
            m    = tm[9:0];
            // $display("%0d/%0d = %0d (%d)",tn,tm,eff,err);
        end
    end /* verilator lint_off WIDTHEXPAND */
    $display("%m effective frequency %0d kHz", n*MFREQ/m); /* verilator lint_on WIDTHEXPAND */
end

jtframe_frac_cen #(.WC(WC)) u_cen(
    .clk    ( clk       ),
    .n      ( n         ),
    .m      ( m         ),
    .cen    ({nc,cen}   ),
    .cenb   (           )
);

endmodule