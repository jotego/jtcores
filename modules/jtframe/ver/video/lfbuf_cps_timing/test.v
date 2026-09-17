`timescale 1ns/1ps
module test;
`include "test_tasks.vh"
reg clk=0, rst=1;
wire [8:0] hdump, vrender;
wire [9:0] hdump_wide;
wire hs, vs, hb, vb, lhbl, lvbl;
wire frame, ln_hs;
reg fb_done=0;
reg [8:0] v_step=9'h100;
reg [3:0] delay=0;
reg frame_l=0;
integer frames=0, requests=0, expected_lines=224;
assign hdump_wide={1'b0,hdump};
assign lhbl=~hb;
assign lvbl=~vb;
always #5 clk=~clk;
initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    repeat(8) @(negedge clk);
    rst=0;
    wait(frames==1);
    @(negedge clk); v_step=9'h155;
end
initial begin
    repeat(700000) @(posedge clk);
    $display("FAIL: frame scheduling stopped"); fail();
end
// CPS3 uses this timing generator, including its delayed vertical blanking
// and vrender lead. Measure its actual visible interval rather than assuming
// that LVBL changes on the same cycle as a vertical-counter increment.
jtcps1_timing u_timing(
    .clk(clk), .cen8(1'b1), .hdump(hdump), .vdump(), .vrender(vrender),
    .vrender1(), .line_start(), .line_inc(), .frame_start(),
    .HS(hs), .VS(vs), .VB(vb), .preVB(), .HB(hb), .debug_bus(8'd0)
);
jtframe_lfbuf_line #(.HW(10),.VW(9),.PIPELINED(1)) uut(
    .rst(rst), .clk(clk), .clk_ctrl(clk), .pxl_cen(1'b1),
    .vrender(vrender), .vread(), .hdump(hdump_wide),
    .hs(hs), .lhbl(lhbl), .vs(vs), .lvbl(lvbl),
    .h_step(9'h100), .v_step(v_step),
    .ln_hs(ln_hs), .ln_vs(), .ln_lvbl(), .ln_v(),
    .ln_addr(10'd0), .ln_data(16'd0), .ln_we(1'b0), .ln_dout(), .ln_pxl(),
    .frame(frame), .fb_addr(10'd0), .rd_addr(10'd0), .fb_din(),
    .fb_clr(1'b0), .fb_done(fb_done), .fb_busy(1'b0), .fb_blank(),
    .fb_dout(16'd0), .line(1'b0), .scr_we(1'b0)
);
always @(posedge clk) begin
    fb_done<=0;
    if(!rst) begin
        if(frame!=frame_l) begin
            if(frames>0) begin
                assert_msg(requests==expected_lines,
                    $sformatf("CPS timing requested %0d lines, expected %0d (start=%0d end=%0d)",
                        requests,expected_lines,uut.vstart,uut.vend));
                if(frames==2) pass();
            end
            expected_lines=v_step>256 ? (224*v_step+255)/256 : 224;
            requests=0;
            frames=frames+1;
        end
        frame_l=frame;
        if(ln_hs) begin
            requests=requests+1;
            delay<=4;
        end else if(delay!=0) begin
            delay<=delay-1'd1;
            if(delay==1) fb_done<=1;
        end
    end
end
endmodule
