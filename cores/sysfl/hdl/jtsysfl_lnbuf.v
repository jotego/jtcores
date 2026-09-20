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

    Author: Andrea Bogazzi. email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 19-9-2026
*/

// Two local line banks between the C355 and jtframe_lfbuf. The C355 renders
// the next line while the previous one waits for the DDR write window; a
// requested line is copied (written pixels only) into the lfbuf line RAM
module jtsysfl_lnbuf(
    input             rst,
    input             clk,
    // jtframe_lfbuf side
    input             ln_hs,
    input      [ 7:0] ln_v,
    output reg [ 8:0] ln_addr,
    output reg [15:0] ln_data,
    output reg        ln_we,
    output reg        ln_done,
    // C355 side
    output reg        c_hs,
    output reg [ 7:0] c_v,
    input      [ 8:0] c_addr,
    input      [15:0] c_data,
    input             c_we,
    input             c_done
);

localparam [8:0] CPY0 = 9'h040, CPY1 = 9'h161;   // H0+1 .. H0+288 written by the C355

reg  [511:0] wr0, wr1;              // pixels written in each bank
reg  [  7:0] bl0, bl1;              // line held by each bank
reg  [  1:0] rdy;                   // bank holds a finished line
reg          rnd, rb, cpy, cb, cvld, req, cdone_l;
reg  [  7:0] rline, nr, qv;
reg  [  8:0] ca, ca_l;
wire [ 15:0] q0, q1;
wire         free0 = !rdy[0] && !(rnd && !rb) && !(cpy && !cb);
wire         free1 = !rdy[1] && !(rnd &&  rb) && !(cpy &&  cb);
wire         hit0  = rdy[0] && bl0==qv, hit1 = rdy[1] && bl1==qv;
wire         held  = hit0 || hit1 || (rnd && rline==qv);

jtframe_rpwp_ram #(.DW(16),.AW(9)) u_bank0(
    .clk    ( clk               ),
    .rd_addr( ca                ),
    .dout   ( q0                ),
    .wr_addr( c_addr            ),
    .din    ( c_data            ),
    .we     ( c_we && rnd && !rb )
);

jtframe_rpwp_ram #(.DW(16),.AW(9)) u_bank1(
    .clk    ( clk               ),
    .rd_addr( ca                ),
    .dout   ( q1                ),
    .wr_addr( c_addr            ),
    .din    ( c_data            ),
    .we     ( c_we && rnd && rb )
);

always @(posedge clk) begin
    if( rst ) begin
        rdy <= 0; rnd <= 0; cpy <= 0; req <= 0; cvld <= 0;
        c_hs <= 0; ln_we <= 0; ln_done <= 0; cdone_l <= 0;
        nr  <= 0; wr0 <= 0; wr1 <= 0;
    end else begin
        c_hs    <= 0;
        ln_we   <= 0;
        cdone_l <= c_done;
        if( c_we && rnd ) begin
            if( rb ) wr1[c_addr] <= 1; else wr0[c_addr] <= 1;
        end
        // C355 finished its line
        if( rnd && c_done && !cdone_l ) begin
            rnd <= 0;
            rdy[rb] <= 1;
            if( rb ) bl1 <= rline; else bl0 <= rline;
            nr  <= rline + 8'd1;
        end
        // lfbuf asks for a line: blank lines return at once, an unexpected
        // line (frame start) drops the look-ahead and restarts the C355
        if( ln_hs ) begin
            ln_done <= 0;
            if( ln_v >= 8'd224 ) begin
                ln_done <= 1;
            end else begin
                req <= 1;
                qv  <= ln_v;
                if( !((rdy[0] && bl0==ln_v) || (rdy[1] && bl1==ln_v) || (rnd && rline==ln_v)) ) begin
                    rdy <= 0;
                    rnd <= 0;
                    nr  <= ln_v;
                end
            end
        end
        // start the next line in a free bank, never past the last visible one
        if( !rnd && !ln_hs && !c_hs && nr < 8'd224 && (free0 || free1) &&
            !(rdy[0] && bl0==nr) && !(rdy[1] && bl1==nr) ) begin
            rb    <= free0 ? 1'b0 : 1'b1;
            rline <= nr;
            rnd   <= 1;
            c_hs  <= 1;
            c_v   <= nr;
            if( free0 ) wr0 <= 0; else wr1 <= 0;
        end
        // copy the requested line into the lfbuf line RAM
        if( req && !cpy && !ln_hs && (hit0 || hit1) ) begin
            cpy <= 1;
            cb  <= hit1;
            ca  <= CPY0;
            req <= 0;
        end
        cvld <= cpy;
        ca_l <= ca;
        if( cpy ) begin
            ca <= ca + 9'd1;
            if( ca == CPY1 ) begin
                cpy <= 0;
                rdy[cb] <= 0;
            end
        end
        if( cvld ) begin
            ln_addr <= ca_l;
            ln_data <= cb ? q1 : q0;
            ln_we   <= cb ? wr1[ca_l] : wr0[ca_l];
            if( !cpy ) ln_done <= 1;
        end
    end
end

endmodule
