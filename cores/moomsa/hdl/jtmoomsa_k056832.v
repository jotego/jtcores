/* SPDX-License-Identifier: GPL-3.0-or-later */

// Behavioural K056832 CPU/VRAM boundary for Moo Mesa.
//
// This is intentionally an FPGA-native device boundary: the PCB's register,
// bank and VRAM-visible behavior is preserved without reproducing the
// discrete high-impedance/multiplexer netlist.  The K054156/K054157 fetcher
// and raster owner remain separate until their direct arbitration and phase
// contract is closed.
module jtmoomsa_k056832 #(
    parameter VRAM_AW = 17
)(
    input             clk,
    input             rst,
    input             reg_cs,
    input             b_cs,
    input             vram_cs,
    input             cpu_rnw,
    input             cpu_we,
    input      [4:0]  reg_addr,
    input      [1:0]  b_addr,
    input      [12:1] vram_addr,
    input      [15:0] cpu_din,
    input      [1:0]  cpu_dsn,
    output reg [15:0] cpu_dout,
    output            cpu_dout_valid,

    input      [16:0] render_vram_addr,
    output     [15:0] render_vram_dout,

    output     [4:0]  selected_page,
    output     [15:0] rom_bank,
    output     [3:0]  layer_mode,
    output     [3:0]  layer_page0, layer_page1, layer_page2, layer_page3,
    output     [1:0]  layer_flip0, layer_flip1, layer_flip2, layer_flip3,
    output     [1:0]  tile_fbits,
    output     [1:0]  layer_y0, layer_y1, layer_y2, layer_y3,
    output     [1:0]  layer_h0, layer_h1, layer_h2, layer_h3,
    output     [1:0]  layer_x0, layer_x1, layer_x2, layer_x3,
    output     [1:0]  layer_w0, layer_w1, layer_w2, layer_w3,
    output signed [15:0] layer_dx0, layer_dx1, layer_dx2, layer_dx3,
    output signed [15:0] layer_dy0, layer_dy1, layer_dy2, layer_dy3,
    output            flip_x,
    output            flip_y
);

    reg [15:0] regs  [0:31];
    reg [15:0] bregs [0:3];
`ifdef K056832_TEST
    localparam MEM_AW = 12;
`else
    localparam MEM_AW = VRAM_AW;
`endif
    integer idx;

    wire reg_write  = reg_cs  && cpu_we;
    wire b_write    = b_cs    && cpu_we;
    wire vram_write = vram_cs && cpu_we;

    function [15:0] combine_word;
        input [15:0] old_word;
        input [15:0] new_word;
        input [1:0]  dsn;
        begin
            combine_word = old_word;
            if (!dsn[1]) combine_word[15:8] = new_word[15:8];
            if (!dsn[0]) combine_word[7:0]  = new_word[7:0];
        end
    endfunction

    wire [16:0] vram_cpu_phys = {selected_page, vram_addr};
    wire [MEM_AW-1:0] vram_cpu_mem_addr = vram_cpu_phys[MEM_AW-1:0];
    wire [MEM_AW-1:0] vram_render_mem_addr = render_vram_addr[MEM_AW-1:0];
    wire [7:0] vram_cpu_hi_q, vram_cpu_lo_q;
    wire [7:0] vram_render_hi_q, vram_render_lo_q;
    wire [15:0] vram_cpu_q = {vram_cpu_hi_q, vram_cpu_lo_q};
    wire [15:0] vram_render_q = {vram_render_hi_q, vram_render_lo_q};
    reg vram_read_valid;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (idx = 0; idx < 32; idx = idx + 1)
                regs[idx] <= 16'h0000;
            // K054156/K056832 tile mode is the power-on tilemap path.  A zero
            // bit selects the separate 512-pixel line-map path; it does not
            // disable a layer.  Keep the FPGA owner in the supported tile
            // path until line-map scheduling is implemented explicitly.
            regs[5'h04] <= 16'h000f;
            for (idx = 0; idx < 4; idx = idx + 1)
                bregs[idx] <= 16'h0000;
            vram_read_valid <= 1'b0;
        end else begin
            if (reg_write)
                regs[reg_addr] <= combine_word(regs[reg_addr], cpu_din, cpu_dsn);
            if (b_write)
                bregs[b_addr] <= combine_word(bregs[b_addr], cpu_din, cpu_dsn);
            vram_read_valid <= vram_cs && cpu_rnw;
        end
    end

    // The PCB exposes CPU and graphics accesses through separate K056832/
    // K054156 paths.  A true dual-port block RAM is the FPGA equivalent: it
    // preserves the two independent address streams without building a
    // 17-bit asynchronous read mux in ALMs.  Both JTFRAME RAM outputs are
    // registered, so the renderer and CPU read contracts explicitly account
    // for one clock of memory latency.
    jtframe_dual_ram #(.DW(8), .AW(MEM_AW)) u_vram_hi(
        .clk0(clk), .data0(cpu_din[15:8]), .addr0(vram_cpu_mem_addr),
        .we0(vram_write && !cpu_dsn[1]), .q0(vram_cpu_hi_q),
        .clk1(clk), .data1(8'h00), .addr1(vram_render_mem_addr),
        .we1(1'b0), .q1(vram_render_hi_q)
    );
    jtframe_dual_ram #(.DW(8), .AW(MEM_AW)) u_vram_lo(
        .clk0(clk), .data0(cpu_din[7:0]), .addr0(vram_cpu_mem_addr),
        .we0(vram_write && !cpu_dsn[0]), .q0(vram_cpu_lo_q),
        .clk1(clk), .data1(8'h00), .addr1(vram_render_mem_addr),
        .we1(1'b0), .q1(vram_render_lo_q)
    );

    assign selected_page = regs[5'h00][1] ? 5'd16 :
                           {1'b0, regs[5'h19][4:3], regs[5'h19][1:0]};
    assign rom_bank = regs[5'h1a] | (regs[5'h1b] << 16);
    // The packed CPU index 0x04 represents the device byte offset 0x08.
    // Its low nibble selects tile versus line mode for layers A-D.
    assign layer_mode = regs[5'h04][3:0];

    assign layer_page0 = {regs[5'h08][4:3], regs[5'h0c][4:3]};
    assign layer_page1 = {regs[5'h09][4:3], regs[5'h0d][4:3]};
    assign layer_page2 = {regs[5'h0a][4:3], regs[5'h0e][4:3]};
    assign layer_page3 = {regs[5'h0b][4:3], regs[5'h0f][4:3]};

    // REG1 supplies the per-layer flip override.  The tile attribute still
    // gates these two bits in the renderer, as on the K056832.
    assign layer_flip0 = regs[5'h01][1:0];
    assign layer_flip1 = regs[5'h01][3:2];
    assign layer_flip2 = regs[5'h01][5:4];
    assign layer_flip3 = regs[5'h01][7:6];
    assign tile_fbits = regs[5'h03][7:6];

    assign layer_y0 = regs[5'h08][4:3];
    assign layer_y1 = regs[5'h09][4:3];
    assign layer_y2 = regs[5'h0a][4:3];
    assign layer_y3 = regs[5'h0b][4:3];
    assign layer_h0 = regs[5'h08][1:0];
    assign layer_h1 = regs[5'h09][1:0];
    assign layer_h2 = regs[5'h0a][1:0];
    assign layer_h3 = regs[5'h0b][1:0];

    assign layer_x0 = regs[5'h0c][4:3];
    assign layer_x1 = regs[5'h0d][4:3];
    assign layer_x2 = regs[5'h0e][4:3];
    assign layer_x3 = regs[5'h0f][4:3];
    assign layer_w0 = regs[5'h0c][1:0];
    assign layer_w1 = regs[5'h0d][1:0];
    assign layer_w2 = regs[5'h0e][1:0];
    assign layer_w3 = regs[5'h0f][1:0];

    assign layer_dy0 = regs[5'h10];
    assign layer_dy1 = regs[5'h11];
    assign layer_dy2 = regs[5'h12];
    assign layer_dy3 = regs[5'h13];
    assign layer_dx0 = regs[5'h14];
    assign layer_dx1 = regs[5'h15];
    assign layer_dx2 = regs[5'h16];
    assign layer_dx3 = regs[5'h17];

    assign flip_x = regs[5'h00][4];
    assign flip_y = regs[5'h00][5];

    // VRAM is the 16 selected 4K-word pages plus the external line-scroll
    // page selected when REG0 bit 1 is set.  The registered RAM outputs make
    // a read acknowledge explicit for the CPU and renderer.
    assign render_vram_dout = vram_render_q;
    assign cpu_dout_valid = ((reg_cs || b_cs) && cpu_rnw) ||
                            (vram_cs && vram_read_valid);

    always @* begin
        cpu_dout = 16'hffff;
        if (reg_cs && cpu_rnw)
            cpu_dout = regs[reg_addr];
        else if (b_cs && cpu_rnw)
            cpu_dout = bregs[b_addr];
        else if (vram_cs && cpu_rnw)
            cpu_dout = vram_cpu_q;
    end

endmodule
