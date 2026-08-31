/* SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps

module jtmoomsa_054338 #(
    parameter BOARD_MODE = 0
)(
    input             clk,
    input             cen,
    input             rst,
    input             cpu_cs,
    input             cpu_wr,
    input             cpu_rd,
    input       [3:0] cpu_addr,
    input      [15:0] cpu_din,
    input       [1:0] cpu_dsn,
    input      [23:0] palette_rgb,
    input       [1:0] board_mix_code,
    input       [1:0] board_shadow_code,
    input       [1:0] board_bright_code,
    input             board_blank,
    output reg [15:0] cpu_dout,
    output reg        cpu_dout_valid,
    input       [7:0] layer_a_r,
    input       [7:0] layer_a_g,
    input       [7:0] layer_a_b,
    input       [7:0] layer_b_r,
    input       [7:0] layer_b_g,
    input       [7:0] layer_b_b,
    input             layer_a_trans,
    input             layer_b_trans,
    input       [1:0] mix_code,
    input       [1:0] shadow_code,
    input       [1:0] bright_code,
    output reg  [7:0] red,
    output reg  [7:0] green,
    output reg  [7:0] blue,
    output reg  [7:0] brightness,
    output reg        pixel_valid
);

reg [15:0] regs [0:15];
reg [7:0] mr, mg, mb;
reg signed [9:0] sr, sg, sb;
reg [7:0] br;
reg [5:0] mix_level;
reg       mix_add;
reg [1:0] mix_q, shadow_q, bright_q;
integer   i;

function automatic [7:0] clamp8(input signed [17:0] v, input disable_clamp);
    begin
        if (disable_clamp)
            clamp8 = v[7:0];
        else if (v < 0)
            clamp8 = 8'h00;
        else if (v > 18'sd255)
            clamp8 = 8'hff;
        else
            clamp8 = v[7:0];
    end
endfunction

function automatic [7:0] mix_chan(
    input [7:0] a,
    input [7:0] b,
    input [5:0] level,
    input       add_mode,
    input signed [9:0] shadow,
    input       disable_clamp);
    reg signed [10:0] aa, bb;
    reg signed [17:0] v;
    reg signed [17:0] pa, pb, sa;
    reg [5:0] inv;
    begin
        aa = {3'b000,a};
        bb = {3'b000,b};
        inv = 6'd32 - level;
        pa = $signed(aa) * $signed({12'd0,level});
        pb = $signed(bb) * $signed({12'd0,inv});
        sa = {{8{shadow[9]}},shadow};
        if (add_mode)
            v = {{7{aa[10]}},aa} + (pb >>> 5) + sa;
        else
            v = ((pa + pb) >>> 5) + sa;
        mix_chan = clamp8(v,disable_clamp);
    end
endfunction

wire [1:0] mix_in = BOARD_MODE ? (regs[15][1] ? board_mix_code : 2'd0) :
                    (regs[15][1] ? mix_q : mix_code);
wire [1:0] shadow_in = BOARD_MODE ? board_shadow_code :
                       (regs[15][2] ? shadow_q : shadow_code);
wire [1:0] bright_in = BOARD_MODE ? board_bright_code :
                       (regs[15][3] ? bright_q : bright_code);

always @* begin
    mr = regs[0][7:0];
    mg = regs[1][15:8];
    mb = regs[1][7:0];
    case (mix_in)
        2'd1: begin mix_add = regs[13][5]; mix_level = {1'b0,regs[13][4:0]}; end
        2'd2: begin mix_add = regs[14][13]; mix_level = {1'b0,regs[14][12:8]}; end
        2'd3: begin mix_add = regs[14][5]; mix_level = {1'b0,regs[14][4:0]}; end
        default: begin mix_add = 1'b0; mix_level = 6'd0; end
    endcase
    case (shadow_in)
        2'd1: begin sr = $signed({regs[2][8],regs[2][8:0]}); sg = $signed({regs[3][8],regs[3][8:0]}); sb = $signed({regs[4][8],regs[4][8:0]}); end
        2'd2: begin sr = $signed({regs[5][8],regs[5][8:0]}); sg = $signed({regs[6][8],regs[6][8:0]}); sb = $signed({regs[7][8],regs[7][8:0]}); end
        2'd3: begin sr = $signed({regs[8][8],regs[8][8:0]}); sg = $signed({regs[9][8],regs[9][8:0]}); sb = $signed({regs[10][8],regs[10][8:0]}); end
        default: begin sr = 10'sd0; sg = 10'sd0; sb = 10'sd0; end
    endcase
    case (bright_in)
        2'd1: br = regs[11][7:0];
        2'd2: br = regs[12][15:8];
        2'd3: br = regs[12][7:0];
        default: br = 8'hff;
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        cpu_dout <= 16'h0;
        cpu_dout_valid <= 1'b0;
        mix_q <= 2'b0;
        shadow_q <= 2'b0;
        bright_q <= 2'b0;
        red <= 8'h0;
        green <= 8'h0;
        blue <= 8'h0;
        brightness <= 8'hff;
        pixel_valid <= 1'b0;
        for (i = 0; i < 16; i = i + 1)
            regs[i] <= 16'h0;
    end else begin
        cpu_dout_valid <= cpu_cs && cpu_rd;
        if (cpu_cs && cpu_wr) begin
            if (!cpu_dsn[1]) regs[cpu_addr][15:8] <= cpu_din[15:8];
            if (!cpu_dsn[0]) regs[cpu_addr][7:0] <= cpu_din[7:0];
        end
        if (cpu_cs && cpu_rd)
            cpu_dout <= regs[cpu_addr];
        pixel_valid <= cen;
        if (cen) begin
            mix_q <= mix_code;
            shadow_q <= shadow_code;
            bright_q <= bright_code;
            if (BOARD_MODE) begin
                if (!regs[15][0]) begin
                    red <= 8'h00;
                    green <= 8'h00;
                    blue <= 8'h00;
                end else if (board_blank) begin
                    red <= mr;
                    green <= mg;
                    blue <= mb;
                end else if (mix_in == 2'd0) begin
                    red <= mix_chan(palette_rgb[23:16],8'h00,6'd32,1'b1,sr,regs[15][5]);
                    green <= mix_chan(palette_rgb[15:8],8'h00,6'd32,1'b1,sg,regs[15][5]);
                    blue <= mix_chan(palette_rgb[7:0],8'h00,6'd32,1'b1,sb,regs[15][5]);
                end else begin
                    red <= mix_chan(palette_rgb[23:16],mr,mix_level,mix_add,sr,regs[15][5]);
                    green <= mix_chan(palette_rgb[15:8],mg,mix_level,mix_add,sg,regs[15][5]);
                    blue <= mix_chan(palette_rgb[7:0],mb,mix_level,mix_add,sb,regs[15][5]);
                end
            end else if (!regs[15][0]) begin
                red <= mr;
                green <= mg;
                blue <= mb;
            end else if (layer_a_trans && layer_b_trans) begin
                red <= mr;
                green <= mg;
                blue <= mb;
            end else if (layer_a_trans) begin
                red <= mix_chan(8'h00,layer_b_r,6'd0,1'b1,sr,regs[15][5]);
                green <= mix_chan(8'h00,layer_b_g,6'd0,1'b1,sg,regs[15][5]);
                blue <= mix_chan(8'h00,layer_b_b,6'd0,1'b1,sb,regs[15][5]);
            end else if (layer_b_trans) begin
                red <= mix_chan(layer_a_r,8'h00,6'd32,1'b1,sr,regs[15][5]);
                green <= mix_chan(layer_a_g,8'h00,6'd32,1'b1,sg,regs[15][5]);
                blue <= mix_chan(layer_a_b,8'h00,6'd32,1'b1,sb,regs[15][5]);
            end else if (mix_add) begin
                red <= mix_chan(layer_a_r,layer_b_r,mix_level,1'b1,sr,regs[15][5]);
                green <= mix_chan(layer_a_g,layer_b_g,mix_level,1'b1,sg,regs[15][5]);
                blue <= mix_chan(layer_a_b,layer_b_b,mix_level,1'b1,sb,regs[15][5]);
            end else begin
                red <= mix_chan(layer_a_r,layer_b_r,mix_level,1'b0,sr,regs[15][5]);
                green <= mix_chan(layer_a_g,layer_b_g,mix_level,1'b0,sg,regs[15][5]);
                blue <= mix_chan(layer_a_b,layer_b_b,mix_level,1'b0,sb,regs[15][5]);
            end
            brightness <= br;
        end
    end
end

endmodule
