/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */

module jtframe_v20_bus (
    input             rst,
    input             clk,
    input             cen,
    input      [19:0] cpu_addr,
    input      [15:0] cpu_dout,
    input      [ 2:0] cpu_bs,
    input             cpu_rd_n,
    input             cpu_wr_n,
    input             cpu_ube_n,
    output reg [15:0] cpu_din,
    output            cpu_ready,
    output reg [19:0] A,
    output reg [ 7:0] dout,
    input      [ 7:0] din,
    output reg [ 2:0] bs,
    output            req,
    output            rd_n,
    output            wr_n,
    input             ready
);

localparam [2:0] IDLE=0, BYTE=1, GAP=2, DONE=3;
reg [2:0] state;
reg       upper, second, write_cycle;
reg [7:0] high_data;

assign req       = state == BYTE && !rst;
assign rd_n      = !(req && !write_cycle);
assign wr_n      = !(req &&  write_cycle);
assign cpu_ready = !rst && (state == DONE ||
                   (state == IDLE && cpu_rd_n && cpu_wr_n));

always @(posedge clk) begin
    if (rst) begin
        state       <= IDLE;
        A           <= 0;
        dout        <= 0;
        bs          <= 7;
        cpu_din     <= 0;
        upper       <= 0;
        second      <= 0;
        write_cycle <= 0;
        high_data   <= 0;
    end else if (cen) begin
        case (state)
            IDLE: if (!cpu_rd_n || !cpu_wr_n) begin
                A           <= cpu_addr;
                bs          <= cpu_bs;
                write_cycle <= !cpu_wr_n;
                // INTA is one byte per acknowledge, regardless of stale UBE.
                upper       <= cpu_addr[0] && cpu_bs != 0;
                second      <= !cpu_addr[0] && !cpu_ube_n && cpu_bs != 0;
                dout        <= cpu_addr[0] && cpu_bs != 0 ? cpu_dout[15:8] : cpu_dout[7:0];
                high_data   <= cpu_dout[15:8];
                cpu_din     <= 0;
                state       <= BYTE;
            end
            BYTE: if (ready) begin
                if (!write_cycle) begin
                    if (upper) cpu_din[15:8] <= din;
                    else       cpu_din[ 7:0] <= din;
                end
                state <= second ? GAP : DONE;
            end
            GAP: begin
                A      <= A + 20'd1;
                dout   <= high_data;
                upper  <= 1;
                second <= 0;
                state  <= BYTE;
            end
            DONE: if (cpu_rd_n && cpu_wr_n) begin
                state <= IDLE;
                bs    <= 7;
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule
