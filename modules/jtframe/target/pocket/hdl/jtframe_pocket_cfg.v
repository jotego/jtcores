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
    along with JTFRAME. If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 22-4-2025 */

module jtframe_pocket_cfg(
    input             rst_rom, clk_rom, clk_74a,

    // clk_74a domain
    input      [31:2] sys_addr,
    input      [31:0] sys_dout,
    input             sys_wr,

    // clk_rom domain
    output reg [31:0] dipsw,
    output reg        dipsw_rst,
    output reg [17:0] core_mod,
    output reg [23:0] button_map,
    output reg [ 7:0] game_vol=0,
    output reg [63:0] status
);

// Memory mapped registers values
localparam [7:0] MMR_CMD     = 8'hF8, // Reserved by Analogue for host/target commands
                 MMR_MOD     = 8'hF9, // MODe byte, see JTFRAME docs
                 MMR_DIPSW   = 8'hFA, // DIP switches
                 MMR_STATUS  = 8'hFB, // status word, see doc/osd.md
                 MMR_BUTTONS = 8'hFC, // Six action-button selectors
                 MMR_VERSION = 8'hFF; // Git commit

wire [31:2] addr;
wire [31:0] dout;
wire        wr;

jtframe_sync #(.W(30+32+1)) u_sync(
    .clk_in     ( clk_74a       ),
    .clk_out    ( clk_rom       ),
    .raw        ( {sys_addr, sys_wr, sys_dout } ),
    .sync       ( {addr,wr,dout})
);

always @(posedge clk_rom) begin
    if( rst_rom ) begin
        core_mod <= 0;
        button_map <= 24'h543210;
        status   <= 0;
        dipsw_rst<= 0;
`ifndef JTFRAME_FORCED_DIPSW
        dipsw    <= ~32'h0;
`endif
    end else begin
        dipsw_rst<= 0;
        if( wr ) begin
            case (addr[31:24])
                MMR_MOD: begin
                    core_mod <= {dout[17:16],9'd0,dout[6:0]};
                    game_vol <= dout[15:8];
                end
    `ifndef JTFRAME_FORCED_DIPSW
                MMR_DIPSW: begin
                    dipsw <= dout;
                    if( dipsw != dout ) dipsw_rst <= 1;
                end
    `endif
                MMR_STATUS: begin
                    if( addr[2] )
                        status[63:32] <= dout;
                    else
                        status[31: 0] <= dout;
                end
                MMR_BUTTONS: button_map <= dout[23:0];
                default:;
            endcase
        end
    end
end

endmodule
