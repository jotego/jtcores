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
    Date: 28-2-2019 */

////////////////////////////////////////////////////////////
/////// read/write type
/////// simple pass through
/////// It requires addr_ok signal to toggle for each request
/////// addr_ok is meant to be the CS signal coming from a CPU memory decoder
/////// so it should go up and stay up until the data is served. It should go down
/////// after that.

module jtframe_ram_rq #(parameter
    SDRAMW = 22,
    AW     = 18,
    DW     = 8,
    FASTWR = 0  // gives an ok as soon as the slot mux accepts the write
                // operation. But a new operation won't be accepted until
                // the current one finishes
                // This is useful to have a CPU continue working while a
                // write occurs in the background
)(
    input               rst,
    input               clk,
    input [AW-1:0]      addr,
    input [SDRAMW-1:0]  offset,     // It is not supposed to change during game play
    input               addr_ok,    // signals that value in addr is valid
    input [15:0]        din,        // data read from SDRAM
    input               din_ok,
    input               wrin,
    input               we,
    input               dst,
    output reg          req,
    output reg          req_rnw,
    output reg          data_ok,    // strobe that signals that data is ready
    output reg [SDRAMW-1:0]   sdram_addr,
    input      [DW-1:0] wrdata,
    output reg [DW-1:0] dout        // sends SDRAM data back to requester
);

    wire  [SDRAMW-1:0] size_ext   = { {SDRAMW-AW{1'b0}}, addr };

    reg    last_cs, pending;
    wire   cs_posedge = addr_ok && !last_cs;
    // wire   cs_negedge = !addr_ok && last_cs;

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            last_cs <= 0;
            req     <= 0;
            data_ok <= 0;
            pending <= 0;
            dout    <= 0;
            req_rnw <= 1;
        end else begin
            last_cs <= addr_ok;
            if( !addr_ok ) data_ok <= 0;
            if( we ) begin
                if( cs_posedge && FASTWR ) begin
                    data_ok <= 0;
                    pending <= 1;
                end
                req <= 0;
                if( FASTWR && !req_rnw ) begin
                    data_ok <= 1;
                end
                if( dst ) begin
                    dout    <= din[DW-1:0];
                end
                if( din_ok && (!FASTWR || req_rnw) ) data_ok <= 1;
            end else if( cs_posedge || pending ) begin
                req        <= 1;
                req_rnw    <= ~wrin;
                data_ok    <= 0;
                pending    <= 0;
                sdram_addr <= size_ext + offset;
            end

        end
    end

endmodule
