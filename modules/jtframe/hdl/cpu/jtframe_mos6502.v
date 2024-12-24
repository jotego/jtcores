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
      Date: 5-8-2022

*/

module jtframe_mos6502(
    input             rst,
    input             clk,        // This must be 8x faster than cen (16x desired CPU speed)
    input             cen,        // This must be 2x faster that the desired CPU speed
    // cen clock recovery is troublesome because there must be 8 clock tickes in between cen pulses
    // that requires a clk of 48MHz for a 1.5MHz operation, but this module does not synthesize well
    // at that speed

    // Same polarity as the original signals
    input             so,
    input             rdy,
    input             nmi,
    input             irq,
    input      [ 7:0] dbi,
    output     [ 7:0] dbo,
    output            rw,
    output            sync,
    output reg [15:0] ab
);

// Generates the right signals to
// prevent glitches

reg phi=0;
wire [15:0] raw_addr;
reg [2:0] aux=0;
wire raw_rnw;
assign rw = raw_rnw | ~cen | phi;

always @(posedge clk) begin
    aux <= aux << 1;
    if( cen ) begin
        phi<= ~phi;
        aux[0] <= 1;
    end
    if( aux[2] ) ab <= raw_addr;
end


chip_6502 u_cpu(
    .clk    ( clk       ),    // FPGA clock
    .phi    ( phi       ),    // 6502 clock
    .res    ( ~rst      ),
    .so     ( so        ),
    .rdy    ( rdy       ),
    .nmi    ( nmi       ),
    .irq    ( irq       ),
    .dbi    ( dbi       ),
    .dbo    ( dbo       ),
    .rw     ( raw_rnw   ),
    .sync   ( sync      ),
    .ab     ( raw_addr  )
);
    
endmodule