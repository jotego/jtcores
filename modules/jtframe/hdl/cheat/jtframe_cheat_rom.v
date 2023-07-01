/*  This file is part of JT_FRAME.
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
    Date: 1-6-2021 */

module jtframe_cheat_rom #(parameter AW=10)(
    input           rst,
    input           clk_rom,
    input           clk_pico,
    input  [AW-1:0] iaddr,
    output   [17:0] idata,
    // PBlaze Program
    input           prog_en,      // resets the address counter
    input           prog_wr,      // strobe for new data
    input  [7:0]    prog_addr,
    input  [7:0]    prog_data
);

// 8 to 18 bit conversion
reg   [15:0] prog_fifo;
reg          last_en, prog_post;
reg   [17:0] prog_word;
reg          word_we;
reg   [ 3:0] word_cnt;
reg [AW-1:0] prom_addr;
wire  [17:0] iraw;
reg          irom_ok=0; // reset only at FPGA programming

// If the ROM has not been loaded, it outputs 0
assign idata = irom_ok ? iraw : 18'd0;

`ifdef JTFRAME_CHEAT_SCRAMBLE
    reg  [7:0] new_data;
    reg  [7:0] mask;
    localparam [15:0] SCRAMBLE = `JTFRAME_CHEAT_SCRAMBLE;

    initial $display("scramble!");

    always @(*) begin
        new_data = prog_data;
        mask = prog_addr[7:0] ^ SCRAMBLE[7:0];
        if( mask[0] ) new_data[1:0] = {new_data[0], new_data[1]};
        if( mask[1] ) new_data[3:2] = {new_data[2], new_data[3]};
        if( mask[2] ) new_data[5:4] = {new_data[4], new_data[5]};
        if( mask[3] ) new_data[7:6] = {new_data[6], new_data[7]};
        new_data = new_data ^ SCRAMBLE[15:8];
        if( mask[4] ) new_data[1:0] = {new_data[0], new_data[1]};
        if( mask[5] ) new_data[3:2] = {new_data[2], new_data[3]};
        if( mask[6] ) new_data[5:4] = {new_data[4], new_data[5]};
        if( mask[7] ) new_data[7:6] = {new_data[6], new_data[7]};
    end
`else
    wire [7:0] new_data = prog_data;
`endif

always @(posedge clk_rom) begin
    last_en <= prog_en;
    if(word_we) irom_ok <= 1;
    if( prog_en & ~last_en ) begin
        word_cnt  <= 0;
        prog_post <= 0;
        prom_addr <= 0;
        prog_word <= 0;
    end else begin
        if( prog_wr & prog_en ) begin
            prog_fifo <= { new_data, prog_fifo[15:8] };
            word_cnt  <= word_cnt[3] ? 4'd0 : word_cnt + 4'd1;
            case( word_cnt )
                2: begin
                    word_we   <= 1;
                    prog_word <= { new_data[1:0], prog_fifo };
                end
                4: begin
                    word_we   <= 1;
                    prog_word <= { new_data[3:0], prog_fifo[15:2] };
                end
                6: begin
                    word_we   <= 1;
                    prog_word <= { new_data[5:0], prog_fifo[15:4] };
                end
                8: begin
                    word_we   <= 1;
                    prog_word <= { new_data[7:0], prog_fifo[15:6] };
                end
                default: word_we <= 0;
            endcase
        end else begin
            word_we <= 0;
        end
        if( word_we ) prom_addr <= prom_addr+1'd1;
    end
end

jtframe_dual_ram #(
    .DW     ( 18        ),
    .AW     ( AW        )
    //.SIMHEXFILE("cheat.hex")
) u_irom(
    .clk0   ( clk_rom   ),
    .clk1   ( clk_pico  ),
    // Port 0
    .data0  ( prog_word ),
    .addr0  ( prom_addr ),
    .we0    ( word_we   ),
    .q0     (           ),
    // Port 1
    .data1  (           ),
    .addr1  ( iaddr[AW-1:0] ),
    .we1    ( 1'b0      ),
    .q1     ( iraw      )
);

endmodule
