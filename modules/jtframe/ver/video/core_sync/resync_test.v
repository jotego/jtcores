`timescale 1ns/1ps

module resync_test;
reg clk=0;
always #5 clk=~clk;
wire lhbl, lvbl, hs, vs;

`ifdef CORE_BLKOUT
localparam HT=512, VT=269, HW=27, VW=3;
localparam EXPECT_H_ESCAPE=0, EXPECT_V_ESCAPE=0;
jtblkout_video dut(.clk(clk),.rst(1'b0),.pxl_cen(1'b1),.LHBL(lhbl),.LVBL(lvbl),.HS(hs),.VS(vs));
`elsif CORE_PKTGAL
localparam HT=384, VT=260, HW=32, VW=3;
localparam EXPECT_H_ESCAPE=0, EXPECT_V_ESCAPE=0;
jtpktgal_video dut(.clk(clk),.rst(1'b0),.pxl_cen(1'b1),.LHBL(lhbl),.LVBL(lvbl),.HS(hs),.VS(vs));
`elsif CORE_SF
localparam HT=512, VT=256, HW=40, VW=3;
localparam EXPECT_H_ESCAPE=0, EXPECT_V_ESCAPE=1;
jtsf_video dut(.clk(clk),.rst(1'b0),.pxl_cen(1'b1),.LHBL(lhbl),.LVBL(lvbl),.HS(hs),.VS(vs));
`elsif CORE_SARMS
localparam HT=512, VT=256, HW=40, VW=3;
localparam EXPECT_H_ESCAPE=0, EXPECT_V_ESCAPE=1;
jtsarms_video dut(.clk(clk),.rst(1'b0),.pxl_cen(1'b1),.LHBL(lhbl),.LVBL(lvbl),.HS(hs),.VS(vs));
`elsif CORE_GAE1
`ifndef TEST_VTOTAL
`define TEST_VTOTAL 272
`endif
localparam HT=384, VT=`TEST_VTOTAL, HW=28, VW=8;
localparam EXPECT_H_ESCAPE=1, EXPECT_V_ESCAPE=0;
jtgae1_video #(.VTOTAL(VT)) dut(.clk(clk),.rst(1'b0),.pxl_cen(1'b1),
    .lhbl(lhbl),.lvbl(lvbl),.hsync(hs),.vsync(vs),.gfx_en(4'b0),.gfx_4m(1'b0),
    .squash(1'b0),.bigkarnk(1'b0),.spr_force_high(6'b0));
`elsif CORE_TOKI
localparam HT=384, VT=262, HW=32, VW=3;
localparam EXPECT_H_ESCAPE=0, EXPECT_V_ESCAPE=0;
jttoki_video dut(.clk(clk),.rst(1'b0),.pxl_cen(1'b1),.pxl2_cen(1'b1),.cabal(1'b0),
    .lhbl(lhbl),.lvbl(lvbl),.hsync(hs),.vsync(vs));
`endif

localparam WIDE = `JTFRAME_WIDTH >= 320;
wire [8:0] rhs, rvs;
genvar g;
generate for(g=0;g<9;g=g+1) begin: offsets
    localparam HC=g%3, VC=g/3;
    localparam [3:0] HO=HC==0 ? 4'h8 : HC==1 ? 4'h0 : 4'h7;
    localparam [3:0] VO=VC==0 ? 4'h8 : VC==1 ? 4'h0 : 4'h7;
    jtframe_resync #(.WIDE(WIDE)) uut(
        .clk(clk),.pxl_cen(1'b1),.hs_in(hs),.vs_in(vs),
        .LVBL(lvbl),.LHBL(lhbl),.hoffset(HO),.voffset(VO),
        .hs_out(rhs[g]),.vs_out(rvs[g]));
    // `jtframe_resync` has no reset for field; model FPGA power-up in Icarus.
    initial uut.field=0;
end endgenerate

integer tick=0, hblank=-1, vblank=-1, prev_hblank=-1, prev_vblank=-1;
integer source_hs=-1, source_vs=-1, source_hwidth=-1, source_vwidth=-1;
integer hstart[0:8], vstart[0:8], hfront[0:8], vfront[0:8];
integer hwidth[0:8], vwidth[0:8];
integer h_escape_ticks[0:8], v_escape_ticks[0:8];
integer i, he, ve, checks=0;
integer phase_delta, expected_phase, h_escape_mask=0, v_escape_mask=0;
reg last_lhbl=0, last_lvbl=0, last_hs=0, last_vs=0;
reg [8:0] last_rhs=0, last_rvs=0;

initial begin
    for(i=0;i<9;i=i+1) begin
        hstart[i]=-1; vstart[i]=-1; hfront[i]=-1; vfront[i]=-1;
        hwidth[i]=-1; vwidth[i]=-1;
        h_escape_ticks[i]=0; v_escape_ticks[i]=0;
    end
end

always @(negedge clk) begin
    tick=tick+1;
    if(last_lhbl && !lhbl) begin
        if(tick>6*HT*VT && prev_hblank>=0 && tick-prev_hblank!=HT)
            $fatal(1,"input Htotal changed");
        prev_hblank=tick; hblank=tick;
    end
    if(last_lvbl && !lvbl) begin
        if(tick>6*HT*VT && prev_vblank>=0 && tick-prev_vblank!=HT*VT)
            $fatal(1,"input frame total changed");
        prev_vblank=tick; vblank=tick;
    end
    if(!last_hs && hs) source_hs=tick;
    if(last_hs && !hs) source_hwidth=tick-source_hs;
    if(!last_vs && vs) source_vs=tick;
    if(last_vs && !vs) source_vwidth=tick-source_vs;

    for(i=0;i<9;i=i+1) begin
        if(!last_rhs[i] && rhs[i]) begin hstart[i]=tick; hfront[i]=tick-hblank; end
        if(last_rhs[i] && !rhs[i]) hwidth[i]=tick-hstart[i];
        if(!last_rvs[i] && rvs[i]) begin vstart[i]=tick; vfront[i]=tick-vblank; end
        if(last_rvs[i] && !rvs[i]) vwidth[i]=tick-vstart[i];
        if(tick>6*HT*VT) begin
            if(rhs[i]!==1'b0 && rhs[i]!==1'b1) $fatal(1,"HS unknown offset=%0d",i);
            if(rvs[i]!==1'b0 && rvs[i]!==1'b1) $fatal(1,"VS unknown offset=%0d",i);
            if(rhs[i] && lhbl) h_escape_ticks[i]=h_escape_ticks[i]+1;
            if(rvs[i] && lvbl) v_escape_ticks[i]=v_escape_ticks[i]+1;
        end
    end

    if(tick>6*HT*VT && !last_lhbl && lhbl) begin
        if(source_hwidth!=HW) $fatal(1,"source HS width %0d expected %0d",source_hwidth,HW);
        for(i=0;i<9;i=i+1) begin
            he=(i%3==0 ? -8 : i%3==1 ? 0 : 7)*(WIDE ? 2 : 1);
            if(hwidth[i]!=HW) $fatal(1,"HS width offset=%0d got=%0d",i,hwidth[i]);
            phase_delta=(hfront[i]-hfront[4])%HT;
            if(phase_delta<0) phase_delta=phase_delta+HT;
            expected_phase=he%HT;
            if(expected_phase<0) expected_phase=expected_phase+HT;
            if(phase_delta!=expected_phase)
                $fatal(1,"H phase offset=%0d got=%0d expected=%0d",i,hfront[i]-hfront[4],he);
            if(tick>7*HT*VT && (EXPECT_H_ESCAPE && i%3==0)!=(h_escape_ticks[i]>0))
                $fatal(1,"unexpected H blanking escape at offset=%0d ticks=%0d",i,h_escape_ticks[i]);
            if(h_escape_ticks[i]>0) h_escape_mask=h_escape_mask|(1<<i);
        end
    end
    if(tick>6*HT*VT && !last_lvbl && lvbl) begin
        if(source_vwidth!=VW*HT) $fatal(1,"source VS width %0d expected %0d",source_vwidth,VW*HT);
        for(i=0;i<9;i=i+1) begin
            he=(i%3==0 ? -8 : i%3==1 ? 0 : 7)*(WIDE ? 2 : 1);
            ve=(i/3==0 ? -8 : i/3==1 ? 0 : 7)*HT;
            if(vwidth[i]!=VW*HT)
                $fatal(1,"VS width offset=%0d got=%0d expected=%0d",i,vwidth[i],VW*HT);
            phase_delta=(vfront[i]-vfront[4])%(HT*VT);
            if(phase_delta<0) phase_delta=phase_delta+(HT*VT);
            expected_phase=(he+ve)%(HT*VT);
            if(expected_phase<0) expected_phase=expected_phase+(HT*VT);
            if(phase_delta!=expected_phase)
                $fatal(1,"V phase offset=%0d got=%0d expected=%0d",i,vfront[i]-vfront[4],he+ve);
            if(tick>7*HT*VT && (EXPECT_V_ESCAPE && i/3==0)!=(v_escape_ticks[i]>0))
                $fatal(1,"unexpected V blanking escape at offset=%0d ticks=%0d",i,v_escape_ticks[i]);
            if(v_escape_ticks[i]>0) v_escape_mask=v_escape_mask|(1<<i);
        end
        checks=checks+1;
        if(checks==2) begin
            $display("PASS resync Htotal=%0d Vtotal=%0d Hwidth=%0d Vwidth=%0d WIDE=%0d combinations=9 default_latency=%0d H_escape_mask=%03x V_escape_mask=%03x",
                HT,VT,HW,VW,WIDE,hstart[4]-source_hs,h_escape_mask,v_escape_mask);
            $finish;
        end
    end

    last_lhbl=lhbl; last_lvbl=lvbl; last_hs=hs; last_vs=vs;
    last_rhs=rhs; last_rvs=rvs;
    if(tick>HT*VT*10) $fatal(1,"watchdog timeout");
end
endmodule
