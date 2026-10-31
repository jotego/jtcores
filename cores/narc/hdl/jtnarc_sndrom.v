/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 5-10-2026 */

module jtnarc_sndrom #(parameter AW=17)(
    input               rst,
    input               clk,
    input               cs,
    input      [AW-1:0] addr,
    output reg [   7:0] dout,
    output reg          ok,

    output reg [AW-1:0] lane_addr,
    output reg          lane_rd,
    input      [   7:0] lane_data,
    input               lane_ok
);

reg valid;

always @(posedge clk) begin
    if( rst ) begin
        lane_addr <= 0;
        lane_rd   <= 0;
        dout      <= 0;
        valid     <= 0;
        ok        <= 0;
    end else begin
        ok <= cs && valid && !lane_rd && addr==lane_addr;
        if( lane_rd ) begin
            if( lane_ok ) begin
                lane_rd <= 0;
                dout    <= lane_data;
                valid   <= 1;
            end
        end else if( cs && (!valid || addr!=lane_addr) ) begin
            lane_addr <= addr;
            lane_rd   <= 1;
            valid     <= 0;
            ok        <= 0;
        end
    end
end

endmodule
