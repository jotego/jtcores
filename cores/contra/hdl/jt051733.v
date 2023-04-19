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
    Date: 4-10-2020 */

module jt051733(
    input              clk,
    input              rst,
    input              cen,
    input      [4:0]   addr,
    input              wr_n,
    input              cs,
    input      [7:0]   din,
    output reg [7:0]   dout
);

reg  [ 7:0] mem[0:31];
reg  [ 7:0] rng;
reg  [15:0] div, mod, sqr;
reg         upsqr, div_start;
wire        div_ack;
wire [ 7:0] next_rng;

wire [15:0] op1   = { mem[ 0],mem[ 1] };
wire [15:0] op2   = { mem[ 2],mem[ 3] };
wire [15:0] op3   = { mem[ 4],mem[ 5] };
wire [15:0] rad   = { mem[ 6],mem[ 7] };
wire [15:0] yobj1 = { mem[ 8],mem[ 9] };
wire [15:0] xobj1 = { mem[10],mem[11] };
wire [15:0] yobj2 = { mem[12],mem[13] };
wire [15:0] xobj2 = { mem[14],mem[15] };

reg  [15:0] xrad1, yrad1, xrad2, yrad2, xdiff;
wire [15:0] quo, rem;

assign next_rng = rng + mem[5'h13];

//integer aux;

`ifdef SIMULATION
always @(posedge cs) if(wr_n) begin
    $display("op = %5d - %5d - %5d",op1,op2,op3);
    $display("rad   = %d",rad);
    $display("obj1 = %5d - %5d",xobj1,yobj1);
    $display("obj2 = %5d - %5d",xobj2,yobj2);
    $display("xdiff = %d",xdiff);
    $display("div = %5d\tmod = %5d\tsqr = %5d",div,mod,sqr);
end
`endif

divfunc #(.XLEN(16), .STAGE_LIST(16'h1111)) u_div(
    .clk    ( clk       ),
    .rst    ( rst       ),
    .a      ( op1       ),
    .b      ( op2       ),
    .vld    ( div_start ),
    .quo    ( quo       ),
    .rem    ( rem       ),
    .ack    ( div_ack   )

);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        //for( aux=0; aux<32; aux=aux+1 ) mem[aux] <= 8'd0;
        rng       <= 8'd0;
        upsqr     <= 0;
        dout      <= 8'd0;
        div_start <= 0;
        div       <= 16'd0;
        mod       <= 16'd0;
    end else begin
        if(cs && !wr_n && cen) begin
            mem[addr] <= din;
            upsqr     <= addr==5'd4 || addr==5'd5;
            div_start <= 1; // The division is always updated
        end else begin
            upsqr     <= 0;
            div_start <= 0;
        end
        xrad1 <= xobj1+rad;
        yrad1 <= yobj1+rad;
        xrad2 <= xobj2+rad;
        yrad2 <= yobj2+rad;
        xdiff <= xobj2 - xobj1;

        if( div_ack ) begin
            div <= quo;
            mod <= rem;
        end

        case( addr )
            0: dout <= div[15:8];
            1: dout <= div[ 7:0];
            2: dout <= mod[15:8];
            3: dout <= mod[ 7:0];
            4: dout <= sqr[15:8];
            5: dout <= sqr[ 7:0];
            6: begin
                rng  <= next_rng;
                dout <= next_rng;
            end
            7:  dout <= ( xrad1 < xobj2 || xrad2 < xobj1 || yrad1 < yobj2 || yrad2 < yobj1 ) ?
                        8'hff : 8'h00;
            14: dout <= xdiff[15:8];
            15: dout <= xdiff[ 7:0];
            default:
                dout <= mem[addr];
        endcase
    end
end

reg  [14:0] step;
reg  [31:0] sqr2;
reg         idle;
wire [31:0] op3ext = { op3, 16'd0 };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        sqr  <= 16'd0;
        idle <= 0;
    end else begin
        sqr2 <= sqr*sqr;
        idle <= ~idle;
        if( upsqr ) begin
            sqr  <= 16'h8000;
            step <= 15'h4000;
            idle <= 1;
        end else if( !idle && step != 15'd0 ) begin
            if( sqr2 == op3ext ) begin
                step <= 15'd0; // sqr found
            end else begin
                if( sqr2 > op3ext )
                    sqr <= sqr - {1'b0, step};
                else
                    sqr <= sqr + {1'b0, step};
                step <= step>>1;
            end
        end
    end
end

endmodule