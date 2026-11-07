/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

module jtnarc_vmap(
    input             rst,
    input             clk,
    output            ready,
    output reg        chg,
    input             op_req,
    input      [ 1:0] op_kind,
    input      [ 7:0] op_row,
    output reg        op_ack,
    input      [ 7:0] a_row,
    output     [ 8:0] a_phys,
    output            a_shared,
    input      [ 7:0] b_row,
    output     [ 8:0] b_phys,
    output reg        cp_start,
    output reg [ 8:0] cp_src,
    output reg [ 8:0] cp_dst,
    input             cp_busy,
    output reg        unsh,
    output reg [ 8:0] unsh_p
);

localparam [3:0] INIT=0, IDLE=1, MTR=2, RTM=3, COW=4, COW_POP=5, COW_RUN=6, COW_END=7, RC_RD=8, RC_WR=9, DONE=10;

(* ramstyle = "MLAB, no_rw_check" *) reg [8:0] rt [0:255];
(* ramstyle = "MLAB, no_rw_check" *) reg [8:0] rt2[0:255];
reg  [511:0] multi;
reg  [ 3:0] st, ret;
reg  [ 9:0] icnt;
reg  [ 7:0] row;
reg  [ 8:0] sr_p, rc_addr, rc_din, p, dec_p;
reg         sr_v, rc_up, rc_we, dec_pend, fr_push, fr_pop, cp_wait;
reg  [ 8:0] fr_wa, fr_ra, fr_din;
wire [ 8:0] rc_q, fr_q;
wire [ 8:0] rc_nv = rc_up ? rc_q+9'd1 : rc_q-9'd1;

assign ready    = st!=INIT;
assign a_phys   = rt[a_row];
assign a_shared = multi[a_phys];
assign b_phys   = rt2[b_row];

always @(posedge clk) begin
    if( rst ) begin
        st       <= INIT;
        icnt     <= 0;
        op_ack   <= 0;
        sr_v     <= 0;
        sr_p     <= 0;
        rc_we    <= 0;
        fr_push  <= 0;
        fr_pop   <= 0;
        fr_wa    <= 0;
        fr_ra    <= 0;
        cp_start <= 0;
        dec_pend <= 0;
        multi    <= 0;
        chg      <= 1;
    end else begin
        op_ack   <= 0;
        chg      <= 0;
        rc_we    <= 0;
        fr_push  <= 0;
        fr_pop   <= 0;
        cp_start <= 0;
        unsh     <= 0;
        case( st )
            INIT: begin
                chg     <= 1;
                rc_addr <= icnt[8:0];
                rc_din  <= icnt[8] ? 9'd0 : 9'd1;
                rc_we   <= 1;
                if( !icnt[8] ) begin
                    rt [icnt[7:0]] <= icnt[8:0];
                    rt2[icnt[7:0]] <= icnt[8:0];
                end else begin
                    fr_din  <= icnt[8:0];
                    fr_push <= 1;
                end
                icnt <= icnt+10'd1;
                if( icnt==10'd511 ) st <= IDLE;
            end
            IDLE: if( op_req && !op_ack ) begin
                row  <= op_row;
                p    <= rt[op_row];
                st   <= op_kind==2'd0 ? MTR : op_kind==2'd1 ? RTM : COW;
            end
            MTR: begin
                if( sr_v && sr_p==p ) st <= DONE;
                else begin
                    dec_pend <= sr_v;
                    dec_p    <= sr_p;
                    sr_p     <= p;
                    sr_v     <= 1;
                    rc_addr  <= p;
                    rc_up    <= 1;
                    ret      <= DONE;
                    st       <= RC_RD;
                end
            end
            RTM: begin
                if( !sr_v || p==sr_p ) st <= DONE;
                else begin
                    rt [row] <= sr_p;
                    rt2[row] <= sr_p;
                    chg      <= 1;
                    dec_pend <= 1;
                    dec_p    <= p;
                    rc_addr  <= sr_p;
                    rc_up    <= 1;
                    ret      <= DONE;
                    st       <= RC_RD;
                end
            end
            COW: begin
                if( !multi[p] ) st <= DONE;
                else begin
                    fr_pop <= 1;
                    st     <= COW_POP;
                end
            end
            COW_POP: begin
                cp_src   <= p;
                cp_dst   <= fr_q;
                cp_start <= 1;
                cp_wait  <= 1;
                st       <= COW_RUN;
            end
            COW_RUN: begin
                if( cp_busy ) cp_wait <= 0;
                if( !cp_wait && !cp_busy ) begin
                    rt [row] <= cp_dst;
                    rt2[row] <= cp_dst;
                    chg      <= 1;
                    rc_addr  <= cp_dst;
                    rc_din   <= 9'd1;
                    rc_we    <= 1;
                    multi[cp_dst] <= 0;
                    dec_pend <= 1;
                    dec_p    <= p;
                    st       <= COW_END;
                end
            end
            COW_END: st <= DONE;
            RC_RD: st <= RC_WR;
            RC_WR: begin
                rc_din <= rc_nv;
                rc_we  <= 1;
                multi[rc_addr] <= rc_nv>=9'd2;
                chg    <= 1;
                if( !rc_up && rc_nv<9'd2 ) begin
                    unsh   <= 1;
                    unsh_p <= rc_addr;
                end
                if( !rc_up && rc_nv==0 ) begin
                    fr_din  <= rc_addr;
                    fr_push <= 1;
                end
                st <= ret;
            end
            DONE: begin
                if( dec_pend ) begin
                    dec_pend <= 0;
                    rc_addr  <= dec_p;
                    rc_up    <= 0;
                    ret      <= DONE;
                    st       <= RC_RD;
                end else begin
                    op_ack <= 1;
                    st     <= IDLE;
                end
            end
            default: st <= IDLE;
        endcase
        if( fr_push ) fr_wa <= fr_wa+9'd1;
        if( fr_pop  ) fr_ra <= fr_ra+9'd1;
    end
end

jtframe_dual_ram #(.DW(9),.AW(9)) u_rc(
    .clk0  ( clk     ),
    .data0 ( rc_din  ),
    .addr0 ( rc_addr ),
    .we0   ( rc_we   ),
    .q0    ( rc_q    ),
    .clk1  ( clk     ),
    .data1 ( 9'd0    ),
    .addr1 ( 9'd0    ),
    .we1   ( 1'b0    ),
    .q1    (         )
);

jtframe_dual_ram #(.DW(9),.AW(9)) u_free(
    .clk0  ( clk     ),
    .data0 ( fr_din  ),
    .addr0 ( fr_wa   ),
    .we0   ( fr_push ),
    .q0    (         ),
    .clk1  ( clk     ),
    .data1 ( 9'd0    ),
    .addr1 ( fr_ra   ),
    .we1   ( 1'b0    ),
    .q1    ( fr_q    )
);

endmodule
