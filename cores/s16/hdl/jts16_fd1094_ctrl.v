/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-6-2021 */

module jts16_fd1094_ctrl(
    input             rst,
    input             clk,

    // Operation
    input             inta_n,      // interrupt acknowledgement
    input             op_n,

    input      [23:1] addr,
    input      [15:0] dec,    
    input      [ 7:0] gkey0,

    input             sup_prog,
    input             dtackn,
    output     [ 7:0] st
);

reg [ 7:0] state;
reg        irqmode;
reg [ 1:0] stchange;
reg [15:0] stcode;
reg        dtacknl;
wire       stadv;

assign st    = irqmode ? gkey0 : state;
assign stadv = !op_n && dtacknl && !dtackn && sup_prog && stchange!=0;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        state     <= 0;
        stchange  <= 0;
        irqmode   <= 0;
        dtacknl   <= 0;
    end else begin
        dtacknl <= dtackn;
        if( !inta_n ) irqmode <= 1;
        if( stadv ) begin
            stchange <= stchange << 1;
            if( stchange[0] ) begin
                stcode <= dec;
                if( dec[15:10]!=0 ) stchange <= 0; // not a cmpi.l #$00/01/02/03
            end
            if( stchange[1] && dec==16'hffff ) begin
                case( stcode[9:8])
                    0: state <= stcode[7:0];
                    1: begin
                        state   <= 0; // reset
                        irqmode <= 0;
                    end
                    2: irqmode <= 1; // enter interruption
                    3: irqmode <= 0; // leave interruption
                endcase
            end
        end
        if( !op_n && !dtackn && sup_prog /*&& stchange==0*/ ) begin
            // cmpi.l #data
            if( dec[15:8]==8'h0c && dec[7:6]==2'b10 ) begin
                stchange <= 2'b01;
            end
            // rte
            if( dec == 16'h4e73 ) irqmode <= 0;
        end
    end
end

endmodule