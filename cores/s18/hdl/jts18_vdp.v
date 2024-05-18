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
    Date: 29-4-2024 */

module jts18_vdp(
    input              rst,
    input              clk96,
    input              clk48,

    // Main CPU interface
    input       [23:1] addr,
    input       [15:0] din,
    output      [15:0] dout,
    input              rnw,
    input              asn,
    input       [ 1:0] dsn,
    output             dtackn,
    // Video output
    output             hs,
    output             vs,
    output      [ 7:0] red,
    output      [ 7:0] green,
    output      [ 7:0] blue,
    input       [ 7:0] debug_bus,
    output reg  [ 7:0] st_dout
);

reg [15:0] mem;
reg [ 7:0] mmr[0:31];
reg [31:0] ptr;
reg        csl;
wire cs;
integer cnt;

assign hs=0, vs=0;
assign red=0, green=0, blue=0;
assign cs=(addr>>4 == 23'h60_000) && !asn;
assign dout=mem|{{8{dsn[1]}},{8{dsn[0]}}};
assign dtackn = 0;

always @(posedge clk48) st_dout <= debug_bus[0] ? mem[0+:8] : mem[8+:8];

always @(posedge clk48, posedge rst) begin
    if( rst ) begin
        mem <= 0;
        cnt <= 0;
        csl <= 0;
    end else begin
        csl <= cs;
        if(cs) begin
            if( !rnw ) begin
                case( addr[3:1] )
                    3'd0: begin
                        if(!dsn[0]) mem[0+:8]<=din[0+:8];
                        if(!dsn[1]) mem[8+:8]<=din[8+:8];
                        if( cs && !csl ) begin
                            $display("%X <- %X",ptr,din);
                            cnt <= cnt+1;
                        end
                    end
                    3'd2: if( din[15:13]==3'b100) begin
                        mmr[din[12:8]]<=din[7:0];
                    end else begin
                        ptr[16+:16] <= din;
                        cnt <= 0;
                    end
                    3'd3: ptr[ 0+:16] <= din;
                endcase
            end else begin
                case( addr[3:1] )
                    3'd0: if( cs && !csl ) begin
                        cnt <= cnt+1;
                        $display("%X -> %X",ptr,mem);
                    end
                    default:;
                endcase
            end
        end
    end
end

endmodule
