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
    Date: 13-4-2022 */

module jtframe_ddr_model(
    input         clk,
    output reg    busy,
    input   [7:0] burstcnt,
    input  [28:0] addr,
    output [63:0] dout,
    output reg    dout_ready,
    input         rd,
    input  [63:0] din,
    input   [7:0] be,
    input         we
);

    localparam SW=20, SIZE=2**SW;

    reg [63:0] mem[0:SIZE-1]; // only the first 8MB are modelled
    reg [ 4:0] busy_cnt;
    reg [ 7:0] cnt;
    reg [ 3:0] dout_cnt;
    reg [SW-1:0] areg;
    reg        rding, wring;

    assign dout = mem[areg];

    integer aux;
    initial begin
        busy       = 1;
        busy_cnt   = 0;
        dout_cnt   = 0;
        cnt        = 0;
        dout_ready = 0;
        rding      = 0;
        wring      = 0;
        for( aux=0; aux<SIZE; aux=aux+1 ) begin
            mem[aux] = 0;
        end
    end

    assign busy = 0; //busy_cnt==7 && !(rding || wring);

    always @(posedge clk) begin
        busy_cnt <= busy_cnt+1'd1;
        if(dout_cnt != 0) begin
            dout_cnt <= dout_cnt-1'd1;
        end else begin
            dout_ready <= rding;
        end
        if( cnt==0 ) begin
            rding <= 0;
            wring <= 0;
            dout_ready <= 0;
        end
        if( (wring || dout_ready) && cnt != 0 && !busy ) begin
            cnt  <= cnt-8'd1;
            areg <= areg + 1'd1;
        end
        if( (rd || (we&&!wring)) && !busy ) begin
            cnt        <= burstcnt;
            areg       <= addr[SW-1:0];
            rding      <= rd;
            wring      <= we;
            dout_ready <= 0;
            dout_cnt   <= 7;
        end
        if( wring ) begin
            for( aux=0;aux<8;aux=aux+1)
                if( be[aux] ) mem[areg][8*aux+:8] <= din[8*aux+:8];
        end
    end

endmodule
