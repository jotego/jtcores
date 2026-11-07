/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-2-2019 */


module jt1943_security(
    input            clk,
    input            cen,
    input            wr_n,
    input            cs,
    input      [7:0] din,
    output reg [7:0] dout
);

///////////////////////////////////////////////////////////////////
// CPU Security (copy protection)
reg [7:0] security;

always @(posedge clk) if(cen) begin
    if( cs && !wr_n ) begin
        security <= din;
        `ifdef SIMULATION
        $display("INFO: security write %X\n", din);
        `endif
    end
    case( security )
        8'h24: dout <= 8'h1d;
        8'h60: dout <= 8'hf7;
        8'h01: dout <= 8'hac;
        8'h55: dout <= 8'h50;
        8'h56: dout <= 8'he2;
        8'h2a: dout <= 8'h58;
        8'ha8: dout <= 8'h13;
        8'h22: dout <= 8'h3e;
        8'h3b: dout <= 8'h5a;
        8'h1e: dout <= 8'h1b;
        8'he9: dout <= 8'h41;
        8'h7d: dout <= 8'hd5;
        8'h43: dout <= 8'h54;
        8'h37: dout <= 8'h6f;
        8'h4c: dout <= 8'h59;
        8'h5f: dout <= 8'h56;
        8'h3f: dout <= 8'h2f;
        8'h3e: dout <= 8'h3d;
        8'hfb: dout <= 8'h36;
        8'h1d: dout <= 8'h3b;
        8'h27: dout <= 8'hae;
        8'h26: dout <= 8'h39;
        8'h58: dout <= 8'h3c;
        8'h32: dout <= 8'h51;
        8'h1a: dout <= 8'ha8;
        8'hbc: dout <= 8'h33;
        8'h30: dout <= 8'h4a;
        8'h64: dout <= 8'h12;
        8'h11: dout <= 8'h40;
        8'h33: dout <= 8'h35;
        8'h09: dout <= 8'h17;
        8'h25: dout <= 8'h04;
        default: dout <= 8'h0;
    endcase
end

endmodule // jt1943_security