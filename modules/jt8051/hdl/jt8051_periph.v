/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

module jt8051_periph(
    input             rst,
    input             clk,
    input             cen,
    input             int0n,
    input             int1n,
    input      [ 7:0] p0_i,
    input      [ 7:0] p1_i,
    input      [ 7:0] p2_i,
    input      [ 7:0] p3_i,
    output     [ 7:0] p0_o,
    output     [ 7:0] p1_o,
    output     [ 7:0] p2_o,
    output     [ 7:0] p3_o,
    input      [ 7:0] sfr_addr,
    input      [ 7:0] sfr_din,
    input             sfr_we,
    input             latch_read,
    output reg [ 7:0] sfr_dout,
    input             irq_take,
    input             reti,
    input             instruction_end,
    output            irq,
    output     [15:0] irq_vec
);

reg [ 7:0] p0, p1, p2, p3;
reg [ 7:0] pcon, tcon, tmod, tl0, tl1, th0, th1, scon, sbuf, ie, ip;
reg [ 3:0] osc;
reg [ 1:0] service;
reg [ 1:0] irq_delay;
reg        service_low;
reg        irq_vec_hold;
reg [15:0] irq_vec_l;
reg [ 2:0] irq_sel_l;
reg        irq_high_l;
reg        int0_l, int1_l, p3_4_l, p3_5_l, t0_fall, t1_fall, t1_ovf;
wire       int0_req, t0_req, int1_req, t1_req, ser_req;
wire       high_req, low_req, select_high;
wire       t0_edge, t1_edge;
wire [7:0] p3_pin_i;
wire       rxd_o, txd, ti_set, rx_valid, ri_set, rx_rb8;
wire [7:0] rx_data;
reg  [15:0] irq_vec_now;
reg  [ 2:0] irq_sel_now;

localparam [2:0] INT0_IRQ = 3'd0,
                 T0_IRQ   = 3'd1,
                 INT1_IRQ = 3'd2,
                 T1_IRQ   = 3'd3,
                 SER_IRQ  = 3'd4;

assign p0_o = p0;
assign p1_o = p1;
assign p2_o = p2;
// The UART drives the physical TxD function on P3.1, gated by the P3 latch.
// With SCON reset (the normal arcade configuration) txd is high and p3_o is
// exactly the software latch.
assign p3_o = {p3[7:2],p3[1]&txd,p3[0]&rxd_o};
// P3.2 and P3.3 are the physical INT0/INT1 pins.  Cores that do not feed
// them back through p3_i must still observe a low external interrupt pin
// when firmware polls P3.
assign p3_pin_i = p3_i & {4'hf,int1n,int0n,2'b11};
assign int0_req = ie[7] && ie[0] && (tcon[0] ? tcon[1] : !int0n);
assign t0_req   = ie[7] && ie[1] && tcon[5];
assign int1_req = ie[7] && ie[2] && (tcon[2] ? tcon[3] : !int1n);
assign t1_req   = ie[7] && ie[3] && tcon[7];
assign ser_req  = ie[7] && ie[4] && (scon[0] || scon[1]);
assign high_req = (int0_req&&ip[0]) || (t0_req&&ip[1]) ||
                  (int1_req&&ip[2]) || (t1_req&&ip[3]) || (ser_req&&ip[4]);
assign low_req  = (int0_req&&!ip[0]) || (t0_req&&!ip[1]) ||
                  (int1_req&&!ip[2]) || (t1_req&&!ip[3]) || (ser_req&&!ip[4]);
// The original MCS-51 executes one complete instruction after RETI or a
// write to IE/IP before it samples another interrupt request.
assign irq      = irq_delay==0 && (service==0 ? (high_req || low_req) : service==1 && high_req);
assign select_high = high_req && service!=2;
assign t0_edge  = t0_fall | (p3_4_l && !p3_i[4]);
assign t1_edge  = t1_fall | (p3_5_l && !p3_i[5]);
// An edge-triggered request is cleared when the CPU acknowledges it.  Keep
// the selected vector through the following ISR micro-operations instead of
// recomputing it from that now-cleared request.
assign irq_vec = irq ? irq_vec_now : (irq_vec_hold ? irq_vec_l : irq_vec_now);

always @* begin
    irq_vec_now = 16'h0023;
    irq_sel_now = SER_IRQ;
    if (select_high) begin
        if (int0_req && ip[0]) begin irq_vec_now = 16'h0003; irq_sel_now = INT0_IRQ; end
        else if (t0_req && ip[1]) begin irq_vec_now = 16'h000b; irq_sel_now = T0_IRQ; end
        else if (int1_req && ip[2]) begin irq_vec_now = 16'h0013; irq_sel_now = INT1_IRQ; end
        else if (t1_req && ip[3]) begin irq_vec_now = 16'h001b; irq_sel_now = T1_IRQ; end
    end else begin
        if (int0_req && !ip[0]) begin irq_vec_now = 16'h0003; irq_sel_now = INT0_IRQ; end
        else if (t0_req && !ip[1]) begin irq_vec_now = 16'h000b; irq_sel_now = T0_IRQ; end
        else if (int1_req && !ip[2]) begin irq_vec_now = 16'h0013; irq_sel_now = INT1_IRQ; end
        else if (t1_req && !ip[3]) begin irq_vec_now = 16'h001b; irq_sel_now = T1_IRQ; end
    end
end

always @* begin
    case (sfr_addr)
        8'h80: sfr_dout = latch_read ? p0 : p0 & p0_i;
        8'h81: sfr_dout = 8'd0;
        8'h82: sfr_dout = 8'd0;
        8'h83: sfr_dout = 8'd0;
        8'h87: sfr_dout = pcon;
        8'h88: sfr_dout = tcon;
        8'h89: sfr_dout = tmod;
        8'h8a: sfr_dout = tl0;
        8'h8b: sfr_dout = tl1;
        8'h8c: sfr_dout = th0;
        8'h8d: sfr_dout = th1;
        8'h90: sfr_dout = latch_read ? p1 : p1 & p1_i;
        8'h98: sfr_dout = scon;
        8'h99: sfr_dout = sbuf;
        8'ha0: sfr_dout = latch_read ? p2 : p2 & p2_i;
        8'ha8: sfr_dout = ie;
        8'hb0: sfr_dout = latch_read ? p3 : p3 & p3_pin_i;
        8'hb8: sfr_dout = ip;
        default: sfr_dout = 8'hff;
    endcase
end

task tick0;
begin
    if (tcon[4] && (!tmod[3] || int0n) &&
        (!tmod[2] || t0_edge)) case (tmod[1:0])
        2'b00: if ({th0,tl0[4:0]}==13'h1fff) begin {th0,tl0[4:0]}<=0; tcon[5]<=1; end
               else {th0,tl0[4:0]} <= {th0,tl0[4:0]}+1'd1;
        2'b01: if ({th0,tl0}==16'hffff) begin {th0,tl0}<=0; tcon[5]<=1; end
               else {th0,tl0} <= {th0,tl0}+1'd1;
        default: if (tl0==8'hff) begin tl0<=th0; tcon[5]<=1; end
                 else tl0 <= tl0+1'd1;
    endcase
end
endtask

task tick1;
    input suppress_tf1, split0;
begin
    if ((split0 || (tcon[6] && (!tmod[7] || int1n) &&
        (!tmod[6] || t1_edge))) && tmod[5:4]!=2'b11) case (tmod[5:4])
        2'b00: if ({th1,tl1[4:0]}==13'h1fff) begin {th1,tl1[4:0]}<=0; t1_ovf<=1; if (!suppress_tf1) tcon[7]<=1; end
               else {th1,tl1[4:0]} <= {th1,tl1[4:0]}+1'd1;
        2'b01: if ({th1,tl1}==16'hffff) begin {th1,tl1}<=0; t1_ovf<=1; if (!suppress_tf1) tcon[7]<=1; end
               else {th1,tl1} <= {th1,tl1}+1'd1;
        2'b10: if (tl1==8'hff) begin tl1<=th1; t1_ovf<=1; if (!suppress_tf1) tcon[7]<=1; end
               else tl1 <= tl1+1'd1;
        default: ;
    endcase
end
endtask

task tick_split0;
begin
    if (tcon[4] && (!tmod[3] || int0n) &&
        (!tmod[2] || t0_edge)) begin
        if (tl0==8'hff) begin tl0<=0; tcon[5]<=1; end
        else tl0 <= tl0+1'd1;
    end
    if (tcon[6]) begin
        if (th0==8'hff) begin th0<=0; tcon[7]<=1; end
        else th0 <= th0+1'd1;
    end
end
endtask

always @(posedge clk) begin
    if (rst) begin
        p0<=8'hff; p1<=8'hff; p2<=8'hff; p3<=8'hff;
        pcon<=0; tcon<=0; tmod<=0; tl0<=0; tl1<=0; th0<=0; th1<=0;
        scon<=0; sbuf<=0; ie<=0; ip<=0; osc<=0; service<=0; service_low<=0; irq_delay<=0;
        irq_vec_hold<=0; irq_vec_l<=16'h0023; irq_sel_l<=SER_IRQ; irq_high_l<=0;
        int0_l<=1; int1_l<=1; p3_4_l<=1; p3_5_l<=1; t0_fall<=0; t1_fall<=0; t1_ovf<=0;
    end else if (cen) begin
        // Timers advance once per 12 oscillator periods.  Do not let this
        // become a natural 4-bit (16-period) rollover: firmware relies on
        // the original 8051 machine-cycle cadence.
        osc     <= osc==4'd11 ? 4'd0 : osc+1'd1;
        int0_l  <= int0n;
        int1_l  <= int1n;
        p3_4_l  <= p3_i[4];
        p3_5_l  <= p3_i[5];
        t1_ovf  <= 1'b0;
        if (p3_4_l && !p3_i[4]) t0_fall <= 1'b1;
        if (p3_5_l && !p3_i[5]) t1_fall <= 1'b1;
        if (tcon[0] && int0_l && !int0n) tcon[1] <= 1'b1;
        if (tcon[2] && int1_l && !int1n) tcon[3] <= 1'b1;
        if (osc==11) begin
            if (tmod[1:0]==2'b11) begin
                tick_split0;
                tick1(1'b1,1'b1);
            end else begin
                tick0;
                tick1(1'b0,1'b0);
            end
            t0_fall <= 1'b0;
            t1_fall <= 1'b0;
        end
        // The controller consumes a request one cen after observing it.
        // Preserve the selected source during that interval: a short edge
        // may disappear, or a higher-priority request may arrive, before NI.
        if (irq) begin
            irq_vec_l  <= irq_vec_now;
            irq_sel_l  <= irq_sel_now;
            irq_high_l <= select_high;
        end
        if (irq_take) begin
            irq_vec_hold <= 1'b1;
            if (irq_high_l) begin
                service_low <= service==1;
                service <= 2'd2;
            end else service <= 2'd1;
            case (irq_sel_l)
                INT0_IRQ: if (tcon[0]) tcon[1] <= 0;
                T0_IRQ:   tcon[5] <= 0;
                INT1_IRQ: if (tcon[2]) tcon[3] <= 0;
                T1_IRQ:   tcon[7] <= 0;
                default: ; // RI/TI are cleared by software.
            endcase
        end
        if (reti) begin
            service <= service==2 && service_low ? 2'd1 : 2'd0;
            irq_vec_hold <= 1'b0;
        end
        if (instruction_end && irq_delay!=0) irq_delay <= irq_delay-1'd1;
        if (reti || (sfr_we && (sfr_addr==8'ha8 || sfr_addr==8'hb8))) irq_delay <= 2'd2;
        if (ti_set) scon[1] <= 1'b1;
        if (rx_valid) begin
            sbuf    <= rx_data;
            scon[2] <= rx_rb8;
            if (ri_set) scon[0] <= 1'b1;
        end
        if (sfr_we) case (sfr_addr)
            8'h80: p0<=sfr_din; 8'h87: pcon<=sfr_din; 8'h88: tcon<=sfr_din;
            8'h89: tmod<=sfr_din; 8'h8a: tl0<=sfr_din; 8'h8b: tl1<=sfr_din;
            8'h8c: th0<=sfr_din; 8'h8d: th1<=sfr_din; 8'h90: p1<=sfr_din;
            8'h98: scon<=sfr_din; 8'h99: sbuf<=sfr_din; 8'ha0: p2<=sfr_din;
            8'ha8: ie<=sfr_din; 8'hb0: p3<=sfr_din; 8'hb8: ip<=sfr_din;
            default: ;
        endcase
    end
end

jt8051_serial u_serial(
    .rst      ( rst                  ), .clk      ( clk                  ), .cen      ( cen                  ),
    .tick12   ( osc==4'd11           ), .t1_ovf   ( t1_ovf               ),
    .pcon     ( pcon                 ), .scon     ( scon                 ),
    .sbuf_we  ( sfr_we && sfr_addr==8'h99 ), .sbuf_din( sfr_din          ), .rxd      ( p3_i[0]              ),
    .rxd_o    ( rxd_o                ), .txd      ( txd                  ), .ti_set   ( ti_set               ),
    .rx_valid ( rx_valid             ), .ri_set   ( ri_set               ),
    .rx_data  ( rx_data              ), .rx_rb8   ( rx_rb8               )
);

endmodule
