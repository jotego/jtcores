`timescale 1ns/1ps

module test;
`include "test_tasks.vh"

reg rst=1'b1, clk=0;
reg [11:0] addr=0;
reg addr_ok=0;
wire init_b, init_l, ok_b, ok_l, req_b, req_l;
wire [7:0] dout_b, dout_l;
integer n;

always #5 clk=~clk;

cache_path #(.LARGE(0)) uut_bcache(
    .rst(rst), .clk(clk), .addr(addr), .addr_ok(addr_ok),
    .init(init_b), .dout(dout_b), .data_ok(ok_b), .req(req_b));
cache_path #(.LARGE(1)) uut_lcache(
    .rst(rst), .clk(clk), .addr(addr), .addr_ok(addr_ok),
    .init(init_l), .dout(dout_l), .data_ok(ok_l), .req(req_l));

task request(input [11:0] a, input expect_b_hit, input expect_l_hit);
    integer timeout, latency_b, latency_l;
    reg seen_req_b, seen_req_l, seen_ok_b, seen_ok_l;
    reg [7:0] response_b, response_l;
    begin
        seen_req_b=0; seen_req_l=0; seen_ok_b=0; seen_ok_l=0;
        latency_b=-1; latency_l=-1;
        @(negedge clk); addr=a; addr_ok=1;
        for(timeout=0; timeout<200; timeout=timeout+1) begin
            @(posedge clk); #1;
            seen_req_b = seen_req_b | req_b;
            seen_req_l = seen_req_l | req_l;
            if(ok_b && !seen_ok_b) begin
                seen_ok_b=1; latency_b=timeout;
                assert_msg(^dout_b !== 1'bx, "bcache dout is unknown when data_ok is high");
                response_b=dout_b;
            end
            if(ok_l && !seen_ok_l) begin
                seen_ok_l=1; latency_l=timeout;
                assert_msg(^dout_l !== 1'bx, "lcache dout is unknown when data_ok is high");
                response_l=dout_l;
            end
            if(seen_ok_b && seen_ok_l) begin
                assert_msg(response_b===response_l, "caches returned different data for one address");
                assert_msg(expect_b_hit ? !seen_req_b : seen_req_b, "bcache hit/miss request behavior is wrong");
                assert_msg(expect_l_hit ? !seen_req_l : seen_req_l, "lcache hit/miss request behavior is wrong");
                assert_msg(latency_b>=0 && latency_l>=0, "response latency was not recorded");
                $display("addr=%03h bcache=%0d cycles lcache=%0d cycles",a,latency_b,latency_l);
                @(negedge clk); addr_ok=0;
                repeat(8) @(posedge clk);
                disable request;
            end
        end
        $display("Timed out waiting for ROM response"); fail();
    end
endtask

initial begin
    repeat(4) @(posedge clk); rst=0;
    wait(!init_b && !init_l);
    repeat(2) @(posedge clk);
    // First accesses miss. Following byte accesses exercise the different
    // cache-line geometries without requiring their pin waveforms to match.
    request(12'h020,0,0); request(12'h021,1,1); request(12'h022,1,1);
    request(12'h07c,0,0); request(12'h080,0,0); request(12'h123,0,0);
    request(12'h001,0,0);
    pass();
end
endmodule

// One complete SDRAM path per cache prevents arbitration from changing either
// observed consumer latency.  The models have identical deterministic data.
module cache_path #(parameter LARGE=0)(
    input rst, clk, input [11:0] addr, input addr_ok,
    output init, output [7:0] dout, output data_ok, output req);
wire ack, dst, rdy;
reg selected;
wire [21:0] rq_addr;
wire [15:0] data_read;
wire [21:0] ba0_addr=rq_addr;
wire [3:0] rd={3'b000,req};
wire [3:0] wr=0;
wire [3:0] acks, dsts, rdys;
wire [15:0] dq;
wire [12:0] sdram_a;
wire [1:0] sdram_dqm, sdram_ba;
wire sdram_nwe,sdram_ncas,sdram_nras,sdram_ncs,sdram_cke;
reg clk_sdram=0;
integer i;

always @(clk) #1 clk_sdram=clk;

jtframe_romrq #(.SDRAMW(22),.AW(12),.DW(8),.CACHE_SIZE(LARGE?1024:0),
    .CACHE_LARGE(LARGE),.BURSTLEN(64),.DOUBLE(1)) uut(
    .rst(rst|init),.clk(clk),.clr(1'b0),.offset(22'd0),
    .din(data_read),.din_ok(rdy),.dst(dst),.we(selected),.req(req),
    .sdram_addr(rq_addr),.addr(addr),.addr_ok(addr_ok),.data_ok(data_ok),.dout(dout));

jtframe_sdram64 #(.AW(22),.HF(1),.SHIFTED(0),.BA0_LEN(64),.BA1_LEN(16),.BA2_LEN(16),.BA3_LEN(16)) u_ctrl(
    .rst(rst),.clk(clk),.init(init),.ba0_addr(ba0_addr),.ba1_addr(22'd0),.ba2_addr(22'd0),.ba3_addr(22'd0),
    .rd(rd),.wr(wr),.ba0_din(16'd0),.ba0_dsn(2'b11),.ba1_din(16'd0),.ba1_dsn(2'b11),.ba2_din(16'd0),.ba2_dsn(2'b11),.ba3_din(16'd0),.ba3_dsn(2'b11),
    .prog_en(1'b0),.prog_addr(22'd0),.prog_rd(1'b0),.prog_wr(1'b0),.prog_din(16'd0),.prog_dsn(2'd0),.prog_ba(2'd0),.rfsh(1'b0),
    .ack(acks),.dst(dsts),.dok(),.rdy(rdys),.dout(data_read),
    .sdram_dq(dq),.sdram_a(sdram_a),.sdram_dqml(sdram_dqm[0]),.sdram_dqmh(sdram_dqm[1]),.sdram_ba(sdram_ba),
    .sdram_nwe(sdram_nwe),.sdram_ncas(sdram_ncas),.sdram_nras(sdram_nras),.sdram_ncs(sdram_ncs),.sdram_cke(sdram_cke));
assign ack=acks[0]; assign dst=dsts[0]; assign rdy=rdys[0];
always @(posedge clk) begin
    if(rst|init) selected <= 0;
    else if(ack) selected <= 1;
    else if(rdy) selected <= 0;
end

mt48lc16m16a2 u_sdram(.Clk(clk_sdram),.Cke(sdram_cke),.Dq(dq),.Addr(sdram_a),.Ba(sdram_ba),
    .Cs_n(sdram_ncs),.Ras_n(sdram_nras),.Cas_n(sdram_ncas),.We_n(sdram_nwe),.Dqm(sdram_dqm),
    .downloading(1'b0),.VS(1'b0),.frame_cnt(0));
initial for(i=0;i<4096;i=i+1) u_sdram.Bank0[i] = {i[7:0],~i[7:0]};
endmodule
