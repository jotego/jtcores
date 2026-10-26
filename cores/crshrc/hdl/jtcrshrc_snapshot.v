/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-10-2026 */

module jtcrshrc_snapshot #(parameter AW=12, SIMFILE="")(
    input               rst,
    input               clk,
    input               LVBL,
    output              busy,
    output     [AW:1]   live_addr,
    input      [15:0]   live_data,
    input      [AW:1]   draw_addr,
    output     [15:0]   draw_data
);

reg lvbl_l;
reg [AW-1:0] address;
reg [1:0] phase;
wire writing = phase==2;
assign live_addr = address;
assign busy = phase!=0 || (lvbl_l && !LVBL);

always @(posedge clk) begin
    if( rst ) begin
        lvbl_l <= 0;
        address <= 0;
        phase <= 0;
    end else begin
        lvbl_l <= LVBL;
`ifndef NOMAIN
        if( lvbl_l && !LVBL ) begin
            address <= 0;
            phase <= 1;
        end else case( phase )
            1: phase <= 2;
            2: begin
                address <= address+1'd1;
                phase <= &address ? 0 : 1;
            end
            default:;
        endcase
`endif
    end
end

jtframe_dual_ram16 #(
    .AW      ( AW      ),
    .SIMFILE ( SIMFILE ),
    .ENDIAN  ( 1       )
) u_buffer(
    .clk0  ( clk          ),
    .data0 ( live_data    ),
    .addr0 ( address      ),
    .we0   ( {2{writing}} ),
    .q0    (              ),
    .clk1  ( clk          ),
    .data1 ( 16'd0        ),
    .addr1 ( draw_addr    ),
    .we1   ( 2'b00        ),
    .q1    ( draw_data    )
);

endmodule
