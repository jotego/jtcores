`timescale 1ns/1ps

module test;

reg clk = 0;
always #5 clk = ~clk;

reg [15:1] cpu_addr;
reg [15:0] cpu_din;
reg uds_n, lds_n, rnw;
reg chacs_n, objram_n, vcs1, vcs2, vzcs;
reg pal_cs_n;
wire [10:0] pal_addr;
wire [15:0] pal_din, pal_cpu_dout;
wire [1:0] pal_we;
reg [10:0] pal_video_addr;
wire [15:0] pal_video_dout;

wire [10:0] scroll_cpu_addr, obj_cpu_addr;
wire [7:0] scroll_cpu_din, scroll_cpu_dout;
wire [7:0] obj_cpu_din, obj_cpu_dout;
wire scroll_cpu_we, obj_cpu_we;
wire [12:1] vram1_cpu_addr;
wire [15:0] vram1_cpu_din, vram1_cpu_dout;
wire [1:0] vram1_cpu_we;
wire [11:0] vram2_cpu_addr;
wire [7:0] vram2_cpu_din, vram2_cpu_dout;
wire vram2_cpu_we;
wire [15:2] char_cpu_addr;
wire [31:0] char_cpu_din, char_cpu_dout;
wire [3:0] char_cpu_we;
wire [15:0] cpu_dout;
reg [10:0] scroll_video_addr, obj_video_addr;
reg [12:1] vram_video_addr;
wire [11:0] vram2_video_addr = vram_video_addr;
reg [15:2] char_video_addr;
wire [7:0] scroll_video_dout, obj_video_dout, vram2_video_dout;
wire [15:0] vram1_video_dout;
wire [31:0] char_video_dout;

reg mmr_rst, mmr_cs;
reg [2:0] mmr_addr, mmr_ioctl_addr;
reg [7:0] mmr_din;
wire [7:0] mmr_u11k_ioctl, mmr_u13j_ioctl;
wire [7:0] mmr_u11k_q, mmr_u13j_q;
wire u11k_q0,u11k_q1,u11k_q2,u11k_q3,u11k_q4,u11k_q5,u11k_q6,u11k_q7;
wire u13j_q0,u13j_q1,u13j_q2,u13j_q3,u13j_q4,u13j_q5,u13j_q6,u13j_q7;
integer i;

assign mmr_u11k_q = {u11k_q7,u11k_q6,u11k_q5,u11k_q4,
                     u11k_q3,u11k_q2,u11k_q1,u11k_q0};
assign mmr_u13j_q = {u13j_q7,u13j_q6,u13j_q5,u13j_q4,
                     u13j_q3,u13j_q2,u13j_q1,u13j_q0};

jtnemsis_u11k_mmr #(.SIMFILE("mmr_seed.bin"), .SEEK(0)) mmr_11k(
    .rst(mmr_rst), .clk(clk), .cs(mmr_cs), .addr(mmr_addr), .rnw(1'b0),
    .din(mmr_din), .dout(),
    .u11k_q0(u11k_q0), .u11k_q1(u11k_q1), .u11k_q2(u11k_q2), .u11k_q3(u11k_q3),
    .u11k_q4(u11k_q4), .u11k_q5(u11k_q5), .u11k_q6(u11k_q6), .u11k_q7(u11k_q7),
    .ioctl_addr(mmr_ioctl_addr), .ioctl_din(mmr_u11k_ioctl), .debug_bus(8'd0), .st_dout()
);

jtnemsis_u13j_mmr #(.SIMFILE("mmr_seed.bin"), .SEEK(8)) mmr_13j(
    .rst(mmr_rst), .clk(clk), .cs(mmr_cs), .addr(mmr_addr), .rnw(1'b0),
    .din(mmr_din), .dout(),
    .u13j_q0(u13j_q0), .u13j_q1(u13j_q1), .u13j_q2(u13j_q2), .u13j_q3(u13j_q3),
    .u13j_q4(u13j_q4), .u13j_q5(u13j_q5), .u13j_q6(u13j_q6), .u13j_q7(u13j_q7),
    .ioctl_addr(mmr_ioctl_addr), .ioctl_din(mmr_u13j_ioctl), .debug_bus(8'd0), .st_dout()
);

jtnemsis_palram_if pal_if(
    .cpu_addr(cpu_addr[11:1]), .cpu_din(cpu_din), .cs_n(pal_cs_n),
    .rnw(rnw), .uds_n(uds_n), .lds_n(lds_n),
    .pal_addr(pal_addr), .pal_din(pal_din), .pal_we(pal_we)
);

jtnemsis_video_bram_if video_if(
    .cpu_addr(cpu_addr), .cpu_din(cpu_din), .uds_n(uds_n), .lds_n(lds_n),
    .rnw(rnw), .chacs_n(chacs_n), .objram_n(objram_n),
    .vcs1(vcs1), .vcs2(vcs2), .vzcs(vzcs),
    .scroll_cpu_addr(scroll_cpu_addr), .scroll_cpu_din(scroll_cpu_din),
    .scroll_cpu_we(scroll_cpu_we), .scroll_cpu_dout(scroll_cpu_dout),
    .obj_cpu_addr(obj_cpu_addr), .obj_cpu_din(obj_cpu_din),
    .obj_cpu_we(obj_cpu_we), .obj_cpu_dout(obj_cpu_dout),
    .vram1_cpu_addr(vram1_cpu_addr), .vram1_cpu_din(vram1_cpu_din),
    .vram1_cpu_we(vram1_cpu_we), .vram1_cpu_dout(vram1_cpu_dout),
    .vram2_cpu_addr(vram2_cpu_addr), .vram2_cpu_din(vram2_cpu_din),
    .vram2_cpu_we(vram2_cpu_we), .vram2_cpu_dout(vram2_cpu_dout),
    .char_cpu_addr(char_cpu_addr), .char_cpu_din(char_cpu_din),
    .char_cpu_we(char_cpu_we), .char_cpu_dout(char_cpu_dout),
    .cpu_dout(cpu_dout)
);

jtframe_dual_ram16 #(.AW(11)) pal_ram(
    .clk0(clk), .addr0(pal_addr), .data0(pal_din), .we0(pal_we),
    .q0(pal_cpu_dout), .clk1(clk), .addr1(pal_video_addr),
    .data1(16'd0), .we1(2'd0), .q1(pal_video_dout)
);

jtframe_dual_ram #(.AW(11), .DW(8)) scroll_ram(
    .clk0(clk), .addr0(scroll_cpu_addr), .data0(scroll_cpu_din),
    .we0(scroll_cpu_we), .q0(scroll_cpu_dout), .clk1(clk),
    .addr1(scroll_video_addr), .data1(8'd0), .we1(1'b0), .q1(scroll_video_dout)
);

jtframe_dual_ram #(.AW(11), .DW(8)) obj_ram(
    .clk0(clk), .addr0(obj_cpu_addr), .data0(obj_cpu_din),
    .we0(obj_cpu_we), .q0(obj_cpu_dout), .clk1(clk),
    .addr1(obj_video_addr), .data1(8'd0), .we1(1'b0), .q1(obj_video_dout)
);

jtframe_dual_ram16 #(.AW(12)) vram1_ram(
    .clk0(clk), .addr0(vram1_cpu_addr), .data0(vram1_cpu_din),
    .we0(vram1_cpu_we), .q0(vram1_cpu_dout), .clk1(clk),
    .addr1(vram_video_addr), .data1(16'd0), .we1(2'd0), .q1(vram1_video_dout)
);

jtframe_dual_ram #(.AW(12), .DW(8)) vram2_ram(
    .clk0(clk), .addr0(vram2_cpu_addr), .data0(vram2_cpu_din),
    .we0(vram2_cpu_we), .q0(vram2_cpu_dout), .clk1(clk),
    .addr1(vram2_video_addr), .data1(8'd0), .we1(1'b0), .q1(vram2_video_dout)
);

jtframe_dual_ram32 #(.AW(16)) char_ram(
    .clk0(clk), .addr0(char_cpu_addr), .data0(char_cpu_din),
    .we0(char_cpu_we), .q0(char_cpu_dout), .clk1(clk),
    .addr1(char_video_addr), .data1(32'd0), .we1(4'd0), .q1(char_video_dout)
);

task check;
    input condition;
    input [8*96-1:0] message;
    begin
        if (condition !== 1'b1) begin
            $display("FAIL: %0s", message);
            $fatal(1);
        end
    end
endtask

task tick;
    begin
        @(posedge clk);
        #1;
    end
endtask

task write_char_lane;
    input half;
    input lane_hi;
    input [15:0] value;
    input [3:0] expected_we;
    begin
        cpu_addr = half ? 15'h7fff : 15'h7ffe;
        cpu_din = value;
        chacs_n = 0;
        rnw = 0;
        uds_n = ~lane_hi;
        lds_n = lane_hi;
        #1;
        check(char_cpu_we == expected_we, "character write lane enable");
        tick();
    end
endtask

initial begin
    cpu_addr = 0;
    cpu_din = 0;
    uds_n = 1; lds_n = 1; rnw = 1;
    chacs_n = 1; objram_n = 1; vcs1 = 1; vcs2 = 1; vzcs = 1;
    pal_cs_n = 1;
    mmr_rst = 1; mmr_cs = 0; mmr_addr = 0; mmr_ioctl_addr = 0; mmr_din = 0;
    pal_video_addr = 0;
    scroll_video_addr = 0; obj_video_addr = 0;
    vram_video_addr = 0; char_video_addr = 0;
    tick();
    mmr_rst = 0;

    // Restore both generated MMR blocks from distinct byte ranges in rest.bin.
    for (i=0; i<8; i=i+1) begin
        mmr_ioctl_addr = i[2:0];
        tick();
        check(mmr_u11k_ioctl == (8'h11 + i), "11K MMR restore byte/SEEK");
        check(mmr_u13j_ioctl == (8'h81 + i), "13J MMR restore byte/SEEK");
        check(mmr_u11k_q[i] == ((8'h11 + i) & 1), "11K MMR restored output bit");
        check(mmr_u13j_q[i] == ((8'h81 + i) & 1), "13J MMR restored output bit");
    end
    mmr_addr = 3'd5; mmr_din = 8'h01; mmr_cs = 1;
    tick(); mmr_cs = 0; mmr_ioctl_addr = 3'd5; tick();
    check(mmr_u11k_ioctl == 8'h01 && mmr_u11k_q[5], "11K MMR addressed write/readback");
    check(mmr_u13j_ioctl == 8'h01 && mmr_u13j_q[5], "13J MMR addressed write/readback");

    // Palette RAM has two independently written byte lanes and wraps at 2K words.
    cpu_addr = 15'h7fff;
    pal_cs_n = 0; rnw = 0; lds_n = 0; uds_n = 1; cpu_din = 16'h005a;
    #1; check(pal_addr == 11'h7ff && pal_we == 2'b01, "palette low-byte lane/address");
    tick();
    uds_n = 0; lds_n = 1; cpu_din = 16'hc300;
    #1; check(pal_we == 2'b10, "palette high-byte lane");
    tick();
    rnw = 1; lds_n = 0; uds_n = 0; pal_video_addr = 11'h7ff;
    tick();
    check(pal_cpu_dout == 16'hc35a, "palette CPU read and renderer address");
    check(pal_video_dout == 16'hc35a, "palette synchronous renderer read");

    // Eight-bit memories mirror on CPU address bits above their fitted address pins.
    cpu_addr = 15'h7fff; cpu_din = 8'h3c; rnw = 0; lds_n = 0; uds_n = 1;
    vzcs = 0; #1;
    check(scroll_cpu_addr == 11'h7ff && scroll_cpu_we, "scroll top address and LDS write");
    tick(); vzcs = 1; objram_n = 0; cpu_din = 8'h96; #1;
    check(obj_cpu_addr == 11'h7ff && obj_cpu_we, "object top address and LDS write");
    tick(); objram_n = 1;

    // VRAM1's upper and lower byte strobes are independent; VRAM2 is one LDS lane.
    vcs1 = 0; cpu_din = 16'ha55a; lds_n = 0; uds_n = 1; #1;
    check(vram1_cpu_addr == 12'hfff && vram1_cpu_we == 2'b01, "VRAM1 low byte write");
    tick(); cpu_din = 16'hc300; lds_n = 1; uds_n = 0; #1;
    check(vram1_cpu_we == 2'b10, "VRAM1 high byte write");
    tick(); vcs1 = 1;
    vcs2 = 0; cpu_din = 16'h00c3; lds_n = 0; uds_n = 1; #1;
    check(vram2_cpu_addr == 12'hfff && vram2_cpu_we, "VRAM2 top address and LDS write");
    tick(); vcs2 = 1;

    // The generated 8-bit VRAM2 renderer port receives the complete 12-bit
    // address via the separate [11:0] alias (not a malformed [12:1] slice).
    cpu_addr = 15'h0800; cpu_din = 16'h007b; rnw = 0; lds_n = 0; uds_n = 1;
    vram_video_addr = 12'h800;
    vcs2 = 0; #1;
    check(vram2_cpu_addr == 12'h800 && vram2_video_addr == 12'h800,
          "VRAM2 independent address bit 11");
    tick(); vcs2 = 1; rnw = 1; vram_video_addr = 12'h800;
    tick();
    check(vram2_video_dout == 8'h7b, "VRAM2 renderer reads top address bit");

    // Character lanes map to the four bytes of one 32-bit little-endian word.
    write_char_lane(0, 0, 16'ha55a, 4'b0001);
    write_char_lane(0, 1, 16'hc300, 4'b0010);
    write_char_lane(1, 0, 16'h007e, 4'b0100);
    write_char_lane(1, 1, 16'he400, 4'b1000);
    check(char_cpu_addr == 14'h3fff, "character top address");

    // A simultaneous CPU and renderer read sees the same synchronous word.
    cpu_addr = 15'h7ffe; chacs_n = 0; rnw = 1;
    char_video_addr = 14'h3fff;
    tick();
    check(cpu_dout == 16'hc35a, "character CPU low-half selection");
    check(char_video_dout == 32'he47ec35a, "character renderer lane ordering");
    cpu_addr = 15'h7fff;
    tick();
    check(cpu_dout == 16'he47e, "character CPU high-half selection");

    // Renderer reads remain registered when the address changes between clocks.
    cpu_addr = 15'h0000; chacs_n = 1;
    char_video_addr = 14'h0000;
    #1; check(char_video_dout == 32'he47ec35a, "renderer output holds before clock");
    tick();

    // One-cycle CPU read latency and each mapped RAM's upper address mirroring.
    cpu_addr = 15'h0fff; rnw = 1; vzcs = 0; objram_n = 1;
    tick(); check(cpu_dout == 16'h003c, "scroll synchronous CPU read");
    vzcs = 1; objram_n = 0;
    tick(); check(cpu_dout == 16'h0096, "object synchronous CPU read");
    objram_n = 1; vcs1 = 0;
    tick(); check(cpu_dout == 16'hc35a, "VRAM1 synchronous CPU read");
    vcs1 = 1; vcs2 = 0;
    tick(); check(cpu_dout == 16'h00c3, "VRAM2 synchronous CPU read");

    $display("PASS");
    $finish;
end

endmodule
