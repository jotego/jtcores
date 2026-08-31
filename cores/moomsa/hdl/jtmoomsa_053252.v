/* SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps

// FPGA-native K053252 timing/interrupt controller.
// The direct PCB clock is 32CLK; SEL=000 selects the internal /4 counter
// cadence. The register file and observable timing are kept explicit while
// the literal gate-array/TTL implementation is intentionally collapsed.
module jtmoomsa_053252(
    input             clk,
    input             cen,
    input             rst,
    input             cpu_cs,
    input             cpu_wr,
    input             cpu_rd,
    input       [3:0] cpu_addr,
    input       [7:0] cpu_din,
    output reg  [7:0] cpu_dout,
    output reg        cpu_dout_valid,
    input       [1:0] sel,
    output reg  [9:0] h_count,
    output reg  [8:0] v_count,
    output            [8:0] v_render,
    output            [8:0] v_render1,
    output            [8:0] v_reload_out,
    output            n_hsy,
    output            n_hbk,
    output            n_vsy,
    output            n_vbk,
    output            n_hld,
    output            n_vld,
    output reg        int1,
    output reg        int2,
    output            fcnt,
    output reg        cres_n
);

reg [7:0] regs [0:15];
reg [1:0] clk_div;
reg [1:0] frame_count;
reg       line_irq_en;
reg [3:0] cres_count;
integer   i;

wire [9:0] h_reload = {regs[0][1:0],regs[1]};
wire [8:0] v_reload = {regs[8][0],regs[9]};
wire [10:0] h_total = {1'b0,h_reload} + 11'd1;
wire [9:0] v_total = {1'b0,v_reload} + 10'd1;

// K053252 fields are big-endian pairs on the 8-bit CPU bus.
wire [8:0] hfp = {regs[2][0],regs[3]};
wire [8:0] hbp = {regs[4][0],regs[5]};
wire [9:0] hsw = ({6'd0,regs[12][3:0]} + 10'd1) << 3;
wire [8:0] vfp = {1'b0,regs[10]};
wire [8:0] vbp = {1'b0,regs[11]} + 9'd1;
wire [8:0] vsw = {5'd0,regs[12][7:4]} + 9'd1;

// Moo's K053252 screen offset is the board-specific (40,16) position used
// by the exact MAME machine configuration. Register writes still determine
// totals and porch/sync lengths; the offset is not a fixed raster substitute.
wire [10:0] visible_w = h_total - {2'b0,hfp} -
                         {2'b0,hbp} - {1'b0,hsw};
wire [10:0] visible_h = {1'b0,v_total} - {2'b0,vfp} -
                         {2'b0,vbp} - {2'b0,vsw};
wire [11:0] h_active_end = 12'd40 + visible_w;
wire [11:0] v_active_end = 12'd16 + visible_h;

wire h_active = ({2'b0,h_count} >= 12'd40) &&
                ({2'b0,h_count} < h_active_end);
wire v_active = ({3'b0,v_count} >= 12'd16) &&
                ({3'b0,v_count} < v_active_end);
wire h_sync = ({2'b0,h_count} < {2'b0,hsw});
wire v_sync = ({3'b0,v_count} < {3'b0,vsw});

function [8:0] v_lookahead(input [8:0] base, input [1:0] delta);
    reg [10:0] tmp;
    reg [10:0] period;
    begin
        tmp = {2'b0,base} + {9'd0,delta};
        period = {2'b0,v_reload} + 11'd1;
        if (tmp >= period) tmp = tmp - period;
        if (tmp >= period) tmp = tmp - period;
        v_lookahead = tmp[8:0];
    end
endfunction

assign n_hsy = ~h_sync;
assign n_hbk = h_active;
assign n_vsy = ~v_sync;
assign n_vbk = v_active;
assign n_hld = h_count != h_reload;
assign n_vld = v_count != v_reload;
assign fcnt = regs[7][1] && frame_count[regs[7][0]];
assign v_render = v_lookahead(v_count,2'd1);
assign v_render1 = v_lookahead(v_count,2'd2);
assign v_reload_out = v_reload;

always @(posedge clk) begin
    if (rst) begin
        cpu_dout       <= 8'h00;
        cpu_dout_valid <= 1'b0;
        h_count        <= 10'd0;
        v_count        <= 9'd0;
        clk_div        <= 2'd0;
        frame_count    <= 2'd0;
        line_irq_en    <= 1'b0;
        cres_count     <= 4'd0;
        int1           <= 1'b0;
        int2           <= 1'b0;
        cres_n         <= 1'b0;
        for (i = 0; i < 16; i = i + 1)
            regs[i] <= 8'h00;
        regs[0] <= 8'h03;
        regs[4] <= 8'h01;
        regs[8] <= 8'h01;
    end else begin
        cpu_dout_valid <= cpu_cs && cpu_rd && (cpu_addr >= 4'd14);

        if (cpu_cs && cpu_rd && (cpu_addr >= 4'd14)) begin
            case (cpu_addr)
                4'd14: cpu_dout <= {v_count[7:1],v_count[8]};
                4'd15: cpu_dout <= v_count[7:0];
                default: cpu_dout <= regs[cpu_addr];
            endcase
        end

        // 32CLK -> CLKSEL(/4) for SEL=000. The other SEL values select
        // silicon CRES/clock variants; Moo ties all three SEL pins low.
        if (cen) begin
            if (clk_div == 2'd3) begin
                clk_div <= 2'd0;
                if (h_count == h_reload) begin
                    h_count <= 10'd0;
                    if (v_count == v_reload) begin
                        v_count     <= 9'd0;
                        frame_count <= frame_count + 2'd1;
                        if (sel == 2'b11) begin
                            cres_n     <= 1'b0;
                            cres_count <= 4'd0;
                        end else if (!cres_n) begin
                            if (cres_count + 1'b1 >= (4'd2 << sel))
                                cres_n <= 1'b1;
                            else
                                cres_count <= cres_count + 1'b1;
                        end
                    end else begin
                        v_count <= v_count + 9'd1;
                        // INT1 is latched on the active-to-blank transition,
                        // not at the subsequent full-frame rollover.
                        if (v_active && ({3'b0,v_count} + 12'd1 >= v_active_end))
                            int1 <= 1'b1;
                        if (line_irq_en && v_count == {1'b0,regs[13]})
                            int2 <= 1'b1;
                    end
                end else begin
                    h_count <= h_count + 10'd1;
                end
            end else begin
                clk_div <= clk_div + 2'd1;
            end
        end

        if (cpu_cs && cpu_wr) begin
            case (cpu_addr)
                4'd13: begin
                    regs[13]    <= cpu_din;
                    line_irq_en <= 1'b1;
                end
                4'd14: int1 <= 1'b0;
                4'd15: int2 <= 1'b0;
                default: regs[cpu_addr] <= cpu_din;
            endcase
        end
    end
end

endmodule
