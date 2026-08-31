/* SPDX-License-Identifier: GPL-3.0-or-later */

// FPGA boundary for the populated Moo N4/053990 bus register window.
// The proven work-RAM transform is sequenced through a dual-port owner; other
// address spaces remain explicit errors until their bus-master contract is
// established.
module jtmoomsa_053990_regs(
    input             clk,
    input             rst,
    input             cen,
    input             cpu_cs,
    input             cpu_wr,
    input       [3:0] cpu_addr,
    input      [15:0] cpu_din,
    input       [1:0] cpu_dsn,
    output     [15:0] cpu_dout,
    output            work_req,
    output     [15:1] work_addr,
    output     [1:0]  work_we,
    output     [15:0] work_dout,
    input      [15:0] work_din,
    output            obj_req,
    output     [15:1] obj_addr,
    input      [15:0] obj_din,
    output            pal_req,
    output     [12:1] pal_addr,
    input      [15:0] pal_din,
    output            busy,
    output            error
);

reg [15:0] regs [0:15];
integer i;
localparam S_IDLE = 3'd0, S_READ1_REQ = 3'd1, S_READ1_WAIT = 3'd2,
           S_READ2_REQ = 3'd3, S_READ2_WAIT = 3'd4, S_WRITE = 3'd5,
           S_ABORT = 3'd6;
reg [2:0] state;
reg [23:0] src1, src2, dst;
reg [15:0] length;
reg [15:0] src1_data, src2_data;
reg busy_q, error_q;
`ifdef MOO_PROTECTION_TRACE
reg [2:0] trace_prev_state;
`endif

wire trigger = cpu_cs && cpu_wr && (cpu_addr == 4'hc);
wire src1_work = src1[23:16] == 8'h18;
wire src2_work = src2[23:16] == 8'h18;
wire src1_obj  = src1[23:16] == 8'h19;
wire src2_obj  = src2[23:16] == 8'h19;
wire src1_pal  = src1[23:16] == 8'h1c;
wire src2_pal  = src2[23:16] == 8'h1c;
wire dst_work  = dst [23:16] == 8'h18;

assign cpu_dout = regs[cpu_addr];
assign busy      = busy_q;
assign error     = error_q;
assign work_req  = busy_q && (((state == S_READ1_REQ) && src1_work) ||
                              ((state == S_READ2_REQ) && src2_work) ||
                              (state == S_WRITE));
assign obj_req   = busy_q && (((state == S_READ1_REQ) && src1_obj) ||
                              ((state == S_READ2_REQ) && src2_obj));
assign obj_addr  = (state == S_READ2_REQ || state == S_READ2_WAIT) ?
                   src2[15:1] : src1[15:1];
assign pal_req   = busy_q && ((((state == S_READ1_REQ) || (state == S_READ1_WAIT)) && src1_pal) ||
                              (((state == S_READ2_REQ) || (state == S_READ2_WAIT)) && src2_pal));
assign pal_addr  = (state == S_READ2_REQ || state == S_READ2_WAIT) ?
                   src2[12:1] : src1[12:1];
assign work_addr = (state == S_READ2_REQ || state == S_READ2_WAIT) ?
                   src2[15:1] : ((state == S_WRITE) ? dst[15:1] : src1[15:1]);
assign work_we   = (state == S_WRITE && dst_work) ? 2'b11 : 2'b00;
// The work bus is 16 bits; doubling the second operand wraps at bit 15.
assign work_dout = src1_data + (src2_data << 1);

always @(posedge clk) begin
    if (rst) begin
        for (i = 0; i < 16; i = i + 1)
            regs[i] <= 16'h0000;
        state     <= S_IDLE;
        src1      <= 24'h0;
        src2      <= 24'h0;
        dst       <= 24'h0;
        length    <= 16'h0;
        src1_data <= 16'h0;
        src2_data <= 16'h0;
        busy_q    <= 1'b0;
        error_q   <= 1'b0;
`ifdef MOO_PROTECTION_TRACE
        trace_prev_state <= S_IDLE;
`endif
    end else if (cen) begin
`ifdef MOO_PROTECTION_TRACE
        if (state != trace_prev_state) begin
            $display("MOO-PROT-REG state=%0d src1=%06x src2=%06x dst=%06x len=%04x s1work=%0d s1obj=%0d s1pal=%0d s2work=%0d s2obj=%0d s2pal=%0d dstwork=%0d busy=%0d error=%0d",
                     state, src1, src2, dst, length, src1_work, src1_obj, src1_pal,
                     src2_work, src2_obj, src2_pal, dst_work, busy_q, error_q);
            trace_prev_state <= state;
        end
        if (trigger)
            $display("MOO-PROT-REG trigger regs0=%04x regs1=%04x regs2=%04x regs3=%04x regs4=%04x regs5=%04x len=%04x",
                     regs[0], regs[1], regs[2], regs[3], regs[4], regs[5], regs[4'hf]);
`endif
        if (cpu_cs && cpu_wr) begin
            if (!cpu_dsn[1]) regs[cpu_addr][15:8] <= cpu_din[15:8];
            if (!cpu_dsn[0]) regs[cpu_addr][7:0]  <= cpu_din[7:0];
        end

        case (state)
            S_IDLE: begin
                busy_q <= 1'b0;
                if (trigger && (regs[4'hf] != 16'h0000)) begin
                    src1    <= {regs[1][7:0],regs[0]};
                    src2    <= {regs[3][7:0],regs[2]};
                    dst     <= {regs[5][7:0],regs[4]};
                    length  <= regs[4'hf];
                    error_q <= 1'b0;
                    busy_q  <= 1'b1;
                    state   <= S_READ1_REQ;
                end
            end
            S_READ1_REQ: begin
                if (!src1_work && !src1_obj && !src1_pal)
                    state <= S_ABORT;
                else
                    state <= S_READ1_WAIT;
            end
            S_READ1_WAIT: begin
                src1_data <= src1_pal ? pal_din : (src1_obj ? obj_din : work_din);
                state <= S_READ2_REQ;
            end
            S_READ2_REQ: begin
                if (!src2_work && !src2_obj && !src2_pal)
                    state <= S_ABORT;
                else
                    state <= S_READ2_WAIT;
            end
            S_READ2_WAIT: begin
                src2_data <= src2_pal ? pal_din : (src2_obj ? obj_din : work_din);
                state <= S_WRITE;
            end
            S_WRITE: begin
                if (!dst_work)
                    state <= S_ABORT;
                else if (length == 16'h0001) begin
                    length <= 16'h0000;
                    busy_q <= 1'b0;
                    state <= S_IDLE;
                end else begin
                    src1 <= src1 + 24'd2;
                    src2 <= src2 + 24'd2;
                    dst  <= dst  + 24'd2;
                    length <= length - 16'd1;
                    state <= S_READ1_REQ;
                end
            end
            default: begin
                busy_q  <= 1'b0;
                error_q <= 1'b1;
                state   <= S_IDLE;
            end
        endcase
    end
end

endmodule
