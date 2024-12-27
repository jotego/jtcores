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
    Date: 22-12-2024 */

// time sharing signals run at 768 kHz

module jttwin16_share(
    input                rst,
    input                clk,   // 48 MHz
    input                cen,   // 1.536 MHz
    output reg           tim1=0,// main CPU has access to video
    output reg           tim2=0,// sub CPU does

    input         [15:0] m_dout, s_dout,
    output        [15:0] v_din,
    input         [13:1] m_addr, s_addr,
    // shared RAM
    input         [ 1:0] shm_we, shs_we,
    output        [15:0] shm_dout, shs_dout,
    // video RAM multiplexers
    output        [12:1] vram_addr,
    output        [13:1] osha_addr,

    input          [1:0] om_we, os_we,
    output         [1:0] oram_we,

    input          [1:0] vam_we, vas_we,
    output         [1:0] va_we,

    input          [1:0] vbm_we, vbs_we,
    output         [1:0] vb_we
);

`ifdef SIMULATION
reg [13:1] oma_l, osa_l;

always @(posedge |om_we) oma_l <= m_addr;
always @(posedge |os_we) osa_l <= s_addr;

`endif

assign v_din     = tim1 ? m_dout : s_dout;
assign oram_we   = tim1 ? om_we  : os_we;
assign va_we     = tim1 ? vam_we : vas_we;
assign vb_we     = tim1 ? vbm_we : vbs_we;
assign osha_addr = tim1 ? m_addr : s_addr;
assign vram_addr = tim1 ? m_addr[12:1] : s_addr[12:1];

always @(posedge clk) if(cen) begin
    tim1 <= ~tim1;
    tim2 <=  tim1;
end

jtframe_dual_ram16 #(.AW(13)) u_shram(
    // Port 0 - main CPU
    .clk0   ( clk       ),
    .data0  ( m_dout    ),
    .addr0  (m_addr[13:1]),
    .we0    ( shm_we    ),
    .q0     ( shm_dout  ),
    // Port 1 - sub CPU
    .clk1   ( clk       ),
    .data1  ( s_dout    ),
    .addr1  (s_addr[13:1]),
    .we1    ( shs_we    ),
    .q1     ( shs_dout  )
);

endmodule
