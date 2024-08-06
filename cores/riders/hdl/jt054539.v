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
    Date: 6-8-2024 */

module jt054539(
    input                rst,
    input                clk,
    input                cen, // 18.432 MHz
    // CPU interface
    input          [8:0] addr,
    input          [7:0] din,
    output         [7:0] dout,
    input                we,
    // ROM
    input          [7:0] rom_data
);

parameter RAM=1;
localparam [8:0] MEMACC = 9'h12d, // skipping MAME's bit A8, so 22d becomes 12d
                 CKADDR = 9'h12e, // check address
                 CKEN   = 9'h12f; // check enable

reg  [16:0] ck_ptr;
wire [ 7:0] mmr_dout, ck_dout;
reg  [ 7:0] ck_base;
reg         memrd_en, ck_inc, ck_we;
wire        ram_sel;

assign ram_sel = ck_base[7];
assign dout    = memrd_en ? (ram_sel ? ck_dout : rom_data) : mmr_dout;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        memrd_en <= 0;
        ck_ptr   <= 0;
        ck_inc   <= 0;
        ck_we    <= 0;
    end else begin
        ck_we  <= 0;
        ck_inc <= 0;
        if(ck_inc) ck_ptr <= ck_ptr+1'd1;
        if(we) case(addr)
            MEMACC: begin
                if(ram_sel) ck_we <= 1;
                ck_inc <= 1;
            end
            CKADDR: begin
                ck_base <= din;
                ck_ptr  <= 0;
            end
            CKEN: memrd_en <= din[4];
            default:;
        endcase
    end
end

jtframe_dual_ram #(.AW(9)) u_mmr(
    // CPU access
    .clk0   ( clk       ),
    .addr0  ( addr      ),
    .data0  ( din       ),
    .we0    ( we        ),
    .q0     ( mmr_dout  ),
    // access by PCM engine
    .clk1   ( clk       ),
    .we1    ( 1'b0      ),
    .addr1  ( 9'd0      ),
    .data1  ( 8'd0      ),
    .q1     (           )
);

generate if(RAM==1) begin
    jtframe_dual_ram #(.AW(15)) u_reverb( // 32kB!
        // access via ports (RAM check -> ck )
        .clk0   ( clk       ),
        .addr0  (ck_ptr[14:0]),
        .data0  ( din       ),
        .we0    ( ck_we     ),
        .q0     ( ck_dout   ),
        // access by PCM engine
        .clk1   ( clk       ),
        .we1    ( 1'b0      ),
        .addr1  ( 15'd0     ),
        .data1  ( 8'd0      ),
        .q1     (           )
    );
end endgenerate

endmodule