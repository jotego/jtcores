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
    Date: 21-9-2023 */

// The implementation of the KEY chips follows MAME's namcos1_m.cpp
// These chips won't impact any timing accuracy
/* verilator tracing_on */
module jtshouse_key(
    input               rst,
    input               clk,

    input               cs,
    input               rnw,
    input         [7:0] addr,
    input         [7:0] din,
    output reg    [7:0] dout,

    input               prog_en,
    input               prog_wr,
    input         [2:0] prog_addr,
    input         [7:0] prog_data,

    output        [1:0] io_mode
);

// The random number generator follows MAME's implementation
// for the sake of comparing debug traces

reg  [7:0] cfg[0:7];
reg  [7:0] mmr[0:7];
reg  [5:0] sel;
wire [7:0] mmr_mux;
reg        up_rng, cs_l;

// for protection type 1/2
wire [31:0] quotient;
wire [31:0] remainder;
reg  [15:0] div_h;
reg         div_start;
wire        dbz;
wire [31:0] a = cfg[0][1:0] == 1 ? {16'h0, mmr[1], mmr[2]} : {div_h, mmr[2], mmr[3]};
wire [31:0] b = cfg[0][1:0] == 1 ? {24'h0, mmr[0]} : {16'h0, mmr[0], mmr[1]};

divu_int #(32) divu_int (
    .clk(clk),
    .rst(rst),
    .start(div_start),
    .busy(),
    .done(),
    .valid(),
    .dbz(dbz),
    .a(a),
    .b(b),
    .val(quotient),
    .rem(remainder)
);

assign io_mode = cfg[0][5:4];

integer i, rng, nx_rng;

assign mmr_mux = mmr[cfg[4][2:0]];

always @(posedge clk) begin
    if( prog_en & prog_wr ) cfg[prog_addr] <= prog_data;
end

// Random number generator. Should research the real one: https://github.com/jotego/jtcores/issues/363
// For now, I use JT51's LFSR
// reg [16:0] bb;
// assign rng = bb[16-:8];

// always @(posedge clk, posedge rst) begin : base_counter
//     if( rst ) begin
//         bb <= 14220;
//     end else if(up_rng) begin
//         bb[16:1] <= bb[15:0];
//         bb[0]    <= ~(bb[16]^bb[13]);
//     end
// end

always @* begin
    for(i=0;i<6;i=i+1) sel[i]=addr[6:4]==cfg[i+2][2:0] && cs;
    up_rng = sel[1] && !cs_l;
    nx_rng = 1664525 * rng + 1013904223;
end

always @(posedge clk or posedge rst) begin
    if(rst) begin
        dout    <= 0;
        cs_l    <= 0;
        rng     <= 'h9d14abd7;
        div_start <= 0;
    end else begin
        cs_l    <= cs;
        div_start <= 0;
        case (cfg[0][1:0]) // protection type
        1: begin
            if( cs && ~rnw && addr[7:2] == 0 ) begin
                if(!cs_l) begin
                    // $display("KEY: %X <- %X",addr[1:0], din);
                    mmr[addr[2:0]] <= din;
                    div_start <= 1;
                end
            end
            case (addr)
                0: dout <= dbz ? 8'h00 : remainder[7:0];
                1: dout <= dbz ? 8'hFF : quotient[15:8];
                2: dout <= dbz ? 8'hFF : quotient[7:0];
                default: dout <= cfg[1]; // key ID
            endcase
        end
        2: begin
            if( cs && ~rnw && addr[7:2] == 0 ) begin
                if(!cs_l) begin
                    // $display("KEY: %X <- %X",addr[1:0], din);
                    mmr[addr[2:0]] <= din;
                    if (addr[1:0] == 3) begin
                        div_h <= {mmr[4], mmr[5]};
                        div_start <= 1;
                        mmr[4] <= mmr[2]; // high word
                        mmr[5] <= din;
                    end
                end
            end
            if (cs && rnw) begin
                mmr[4] <= 0;
                mmr[5] <= 0;
            end
            case (addr)
                0: dout <= dbz ? 8'h00 : remainder[15:8];
                1: dout <= dbz ? 8'h00 : remainder[7:0];
                2: dout <= dbz ? 8'hFF : quotient[15:8];
                3: dout <= dbz ? 8'hFF : quotient[7:0];
                default: dout <= cfg[1]; // key ID
            endcase
        end
        3: begin
            if( cs && ~rnw ) begin
                // if(!cs_l) $display("KEY: %X <- %X",addr[6:4], din);
                mmr[addr[6:4]] <= din;
            end
            if( up_rng ) rng <= nx_rng;
            // do not use "case" to avoid Quartus warning
                 if( sel[0] ) dout <= cfg[1];     // key ID
            else if( sel[1] ) dout <= rng[16+:8]; // Random Number Generator
            else if( sel[3] ) dout <= { mmr_mux[3:0], mmr_mux[7:4] }; // swap nibbles
            else if( sel[4] ) dout <= { addr[3:0], mmr_mux[3:0] };    // lower nibble
            else if( sel[5] ) dout <= { addr[3:0], mmr_mux[7:4] };    // upper nibble
        end
        default: ;
        endcase
    end
end

// `ifdef SIMULATION
// reg [2:0] addrl;
// reg       rnwl;

// always @(posedge clk) begin
//     addrl <= addr[6:4];
//     rnwl  <= rnw;
//     if( !cs && cs_l && rnwl ) begin
//         $display("KEY: %X => %X",addrl, dout);
//     end
// end
// `endif

endmodule


// https://projectf.io/posts/division-in-verilog/
module divu_int #(parameter WIDTH=5) ( // width of numbers in bits
    input  clk,              // clock
    input  rst,              // reset
    input  start,            // start calculation
    output reg busy,         // calculation in progress
    output reg done,         // calculation is complete (high for one tick)
    output reg valid,        // result is valid
    output reg dbz,          // divide by zero
    input  [WIDTH-1:0] a,    // dividend (numerator)
    input  [WIDTH-1:0] b,    // divisor (denominator)
    output reg [WIDTH-1:0] val,  // result value: quotient
    output reg [WIDTH-1:0] rem   // result: remainder
    );

    reg [WIDTH-1:0] b1;             // copy of divisor
    reg [WIDTH-1:0] quo, quo_next;  // intermediate quotient
    reg [WIDTH:0] acc, acc_next;    // accumulator (1 bit wider)
    reg [$clog2(WIDTH):0] i;        // iteration counter

    // division algorithm iteration
    always @(*) begin
        if (acc >= {1'b0, b1}) begin
            acc_next = acc - b1;
            {acc_next, quo_next} = {acc_next[WIDTH-1:0], quo, 1'b1};
        end else begin
            {acc_next, quo_next} = {acc, quo} << 1;
        end
    end

    // calculation control
    always @(posedge clk) begin
        done <= 0;
        if (start) begin
            valid <= 0;
            i <= 0;
            if (b == 0) begin  // catch divide by zero
                busy <= 0;
                done <= 1;
                dbz <= 1;
            end else begin
                busy <= 1;
                dbz <= 0;
                b1 <= b;
                {acc, quo} <= {{WIDTH{1'b0}}, a, 1'b0};  // initialize calculation
            end
        end else if (busy) begin
            if (i == WIDTH-1) begin  // we're done
                busy <= 0;
                done <= 1;
                valid <= 1;
                val <= quo_next;
                rem <= acc_next[WIDTH:1];  // undo final shift
            end else begin  // next iteration
                i <= i + 1'd1;
                acc <= acc_next;
                quo <= quo_next;
            end
        end
        if (rst) begin
            busy <= 0;
            done <= 0;
            valid <= 0;
            dbz <= 0;
            val <= 0;
            rem <= 0;
        end
    end
endmodule