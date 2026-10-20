/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

module jtroundu_v30bus(
    input             rst,
    input             clk,
    input             cen,
    input             cenb,
    input             ready,
    input      [19:0] cpu_addr,
    input      [ 2:0] bs,
    input             ube_n,
    output reg [19:0] addr,
    output reg [ 1:0] lane,
    output            addr_valid,
    output            mem_rd,
    output            mem_wr,
    output            inta,
    output            commit
);

localparam [2:0] TI=0, T1=1, T2=2, T3=3, TW=4, T4=5;
reg [2:0] state, cycle_type;
reg t1_latched;
wire active = addr_valid;

assign addr_valid = (state == T1 && t1_latched) || state == T2
                 || state == T3 || state == TW || state == T4;

assign mem_rd = active && (cycle_type == 4 || cycle_type == 5);
assign mem_wr = active && cycle_type == 6;
assign inta   = active && cycle_type == 0;
assign commit = cen && (state == T3 || state == TW) && ready;

always @(posedge clk) begin
    if (rst) begin
        state      <= TI;
        cycle_type <= 7;
        addr       <= 0;
        lane       <= 0;
        t1_latched <= 0;
    end else begin
        if (cenb && state == T1) begin
            addr <= cpu_addr;
            lane <= {~ube_n,~cpu_addr[0]};
            t1_latched <= 1;
        end
        if (cen) begin
            case (state)
                TI, T4: begin
                    if (bs != 7) begin
                        state      <= T1;
                        cycle_type <= bs;
                        t1_latched <= 0;
                    end else state <= TI;
                end
                T1:     state <= T2;
                T2:     state <= T3;
                T3, TW: state <= ready ? T4 : TW;
                default: state <= TI;
            endcase
        end
    end
end

endmodule
