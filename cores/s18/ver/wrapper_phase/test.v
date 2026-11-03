`timescale 1ns/1ps
module test;
    reg clk96=0, clk48=0, rst=1;
    reg [2:0] multi_clock_cnt=0;
    // Match JTFRAME MultiClock96's half-period scheduler exactly. The first
    // clk48 rising edge is the third 96 MHz half-period tick, with subsequent
    // transitions simultaneous as the scheduler assigns both clock fields.
    always begin
        #5.208;
        clk48 = multi_clock_cnt[1];
        multi_clock_cnt = multi_clock_cnt + 1'b1;
        clk96 = multi_clock_cnt[0];
    end

    wire pxl_cen,pxl2_cen,pxl48,pxl2_48;
    jtframe_pxlcen u_framework_cen(.clk(clk48),.pxl_cen(pxl_cen),.pxl2_cen(pxl2_cen));
    wire [1:0] cen12, frac_cen12;
    wire [15:0] cen_fave, cen_fworst;
    jtframe_gated_cen #(.W(2),.NUM(1),.DEN(4),.MFREQ(48000)) u_memcen6(
        .rst(rst),.clk(clk48),.busy(1'b0),.cen(cen12),.fave(cen_fave),.fworst(cen_fworst));
    jtframe_frac_cen #(.W(2),.WC(6)) u_frac_phase_ref(
        .clk(clk48),.n(6'd1),.m(6'd4),.cen(frac_cen12),.cenb());
    assign pxl48=cen12[1];
    assign pxl2_48=cen12[0];

    wire [8:0] h,v,vrender;
    wire lhbl,lvbl,hs,vs;
    jtframe_vtimer #(.HB_START(9'h1ff),.HB_END(9'h0bf),.HCNT_START(9'h070),.HCNT_END(9'h1ff),
        .VB_START(9'h0df),.VB_END(9'h105),.VCNT_END(9'h105),.VS_START(9'hef),.VS_END(9'h0f3),
        .HS_START(9'h080),.HS_END(9'h0a0)) u_timer(
        .clk(clk48),.pxl_cen(pxl48),.vdump(v),.vrender(vrender),.vrender1(),.H(h),.Hinit(),.Vinit(),
        .LHBL(lhbl),.LVBL(lvbl),.HS(hs),.VS(vs));

    reg geometry_fault=0;
    wire new_hs_i=geometry_fault ? 1'b0 : hs;
    wire new_vs_i=geometry_fault ? 1'b0 : vs;
    reg [23:1] a0=0,a1=0; reg [15:0] d0=0,d1=0;
    reg as0=1,as1=1,rnw0=1,rnw1=1; reg [1:0] ds0=2'b11,ds1=2'b11;
    wire [15:0] q0,q1; wire ack0,ack1, en0,en1,ys0,ys1;
    wire h0,v0,h1,v1,deh0,deh1,dev0,dev1,spa0,spa1;
    wire [7:0] r0,g0,b0,r1,g1,b1;

    jts18_vdp_baseline old_vdp(.rst(rst),.clk96(clk96),.clk48(clk48),.pxl_cen(pxl_cen),
        .hdump(h),.vdump(v),.s16b_hs(hs),.s16b_vs(vs),.addr(a0),.din(d0),.dout(q0),
        .rnw(rnw0),.asn(as0),.dsn(ds0),.dtackn(ack0),.video_en(en0),.hs(h0),.vs(v0),.vde(dev0),
        .hde(deh0),.spa_b(spa0),.ys_n(ys0),.red(r0),.green(g0),.blue(b0),.debug_bus(8'd0),.st_dout());
    jts18_vdp new_vdp(.rst(rst),.clk48(clk48),.pxl2_48cen(pxl2_48),.pxl_48cen(pxl48),
        .HS(new_hs_i),.VS(new_vs_i),.LHBL(lhbl),.LVBL(lvbl),.addr(a1),.din(d1),.dout(q1),
        .rnw(rnw1),.asn(as1),.dsn(ds1),.dtackn(ack1),.video_en(en1),.hs(h1),.vs(v1),.vde(dev1),
        .hde(deh1),.spa_b(spa1),.ys_n(ys1),.red(r1),.green(g1),.blue(b1),.debug_bus(8'd0),.st_dout());

    wire [8:0] sx = h-9'h0c0;
    wire [4:0] sx_mod=sx[4:0];
    wire char_active=(sx_mod<4 || sx_mod>=28);
    wire scr1_active=((sx_mod>=4 && sx_mod<8) || (sx_mod>=16 && sx_mod<20));
    wire scr2_active=((sx_mod>=8 && sx_mod<12) || (sx_mod>=20 && sx_mod<24));
    wire obj_active=(sx_mod>=24 && sx_mod<28);
    wire [6:0] char_pxl={1'b0,3'b001,(char_active ? {1'b0,sx_mod[1:0]+2'd1} : 3'd0)};
    wire [10:0] scr1_pxl={sx_mod[2],6'b000010,(scr1_active ? {1'b0,sx_mod[2:0]+3'd1} : 4'd0)};
    wire [10:0] scr2_pxl={sx_mod[3],6'b000011,(scr2_active ? {1'b0,sx_mod[2:0]+3'd1} : 4'd0)};
    wire [11:0] obj_pxl=obj_active ? {2'b11,6'h04,4'h5} : 12'd0;
    wire obj,sa,layer_b,fix,s1_pri,s2_pri;
    wire [10:0] s16_pal_addr;
    wire s16_shadow;
    reg [15:0] s16_pal_dout=0;
    reg [15:0] s16_pal_ram[0:2047];
    wire [5:0] sr,sg,s16_blue;
    wire [4:0] s16_rpal={s16_pal_dout[3:0],s16_pal_dout[12]};
    wire [4:0] s16_gpal={s16_pal_dout[7:4],s16_pal_dout[13]};
    wire [4:0] s16_bpal={s16_pal_dout[11:8],s16_pal_dout[14]};
    genvar s16_pal_idx;
    generate for(s16_pal_idx=0;s16_pal_idx<2048;s16_pal_idx=s16_pal_idx+1) begin: s16_palette_init
        initial s16_pal_ram[s16_pal_idx]={1'b0,s16_pal_idx[8],s16_pal_idx[7],s16_pal_idx[6],
            s16_pal_idx[3:0],s16_pal_idx[7:4],s16_pal_idx[11:8]};
    end endgenerate
    always @(posedge clk48) s16_pal_dout<=s16_pal_ram[s16_pal_addr];
    jts16_prio s16_priority(.rst(rst),.clk(clk48),.pxl2_cen(pxl2_48),.pxl_cen(pxl48),
        .char_pxl(char_pxl),.scr1_pxl(scr1_pxl),.scr2_pxl(scr2_pxl),.obj_pxl(obj_pxl),.set_fix(1'b0),
        .sa(sa),.sb(layer_b),.fix(fix),.obj(obj),.tprio(),.scr1_prio(s1_pri),.scr2_prio(s2_pri),
        .pal_addr(s16_pal_addr),.shadow(s16_shadow),.gfx_en(4'hf));
    jtshanon_coldac s16_dac(.clk(clk48),.pxl_cen(pxl48),.rin(s16_rpal),.gin(s16_gpal),.bin(s16_bpal),
        .en(1'b1),.gray_n(1'b1),.sh(s16_shadow),.hilo(s16_pal_dout[15]),.rout(sr),.gout(sg),.bout(s16_blue));
    // Static game priority with alternating S16 layer classes below makes
    // the production priority unit select VDP/S16 at repeated boundaries.
    wire [2:0] vdp_prio=3'b010;
    wire [3:0] gfx=4'hf;
    wire [7:0] rr0,gg0,bb0,rr1,gg1,bb1,rrd,ggd,bbd; wire [7:0] st0,st1,std;
    wire [7:0] rso,gso,bso,rsn,gsn,bsn;
    wire lhd0,lvd0,lhd1,lvd1,lhd2,lvd2;
    // `new_vdp` exports the production two-register tuple pipeline. Keep an
    // undelayed raw branch only as a comparison and native-source oracle.
    wire [24:0] raw_tuple1=new_vdp.raw_vdp_tuple;
    wire [24:0] wrapper_d0=new_vdp.vdp_tuple_d0, wrapper_d1=new_vdp.vdp_tuple_d1;
    wire ysd=raw_tuple1[24];
    wire [7:0] rdel=raw_tuple1[23:16],gdel=raw_tuple1[15:8],bdel=raw_tuple1[7:0];
    jts18_colmix mix_old(.rst(rst),.clk(clk48),.pxl_cen(pxl_cen),.pxl2_cen(pxl2_cen),.LHBL(lhbl),.LVBL(lvbl),
        .LHBL_dly(lhd0),.LVBL_dly(lvd0),.vid16_en(1'b1),.obj16(obj),.sa(sa),.sb(layer_b),.fix(fix),
        .s1_pri(s1_pri),.s2_pri(s2_pri),.obj_prio(2'b00),.vdp_en(1'b1),.vdp_prio(vdp_prio),.vdp_ysn(ys0),.gfx_en(gfx),
        .s16_r(sr),.s16_g(sg),.s16_b(s16_blue),.vdp_r(r0),.vdp_g(g0),.vdp_b(b0),.red(rr0),.green(gg0),.blue(bb0),
        .debug_bus(8'd0),.st_show(st0),.joystick1(2'b00));
    jts18_colmix mix_new(.rst(rst),.clk(clk48),.pxl_cen(pxl_cen),.pxl2_cen(pxl2_cen),.LHBL(lhbl),.LVBL(lvbl),
        .LHBL_dly(lhd1),.LVBL_dly(lvd1),.vid16_en(1'b1),.obj16(obj),.sa(sa),.sb(layer_b),.fix(fix),
        .s1_pri(s1_pri),.s2_pri(s2_pri),.obj_prio(2'b00),.vdp_en(1'b1),.vdp_prio(vdp_prio),.vdp_ysn(ys1),.gfx_en(gfx),
        .s16_r(sr),.s16_g(sg),.s16_b(s16_blue),.vdp_r(r1),.vdp_g(g1),.vdp_b(b1),.red(rr1),.green(gg1),.blue(bb1),
        .debug_bus(8'd0),.st_show(st1),.joystick1(2'b00));
    jts18_colmix mix_raw(.rst(rst),.clk(clk48),.pxl_cen(pxl_cen),.pxl2_cen(pxl2_cen),.LHBL(lhbl),.LVBL(lvbl),
        .LHBL_dly(lhd2),.LVBL_dly(lvd2),.vid16_en(1'b1),.obj16(obj),.sa(sa),.sb(layer_b),.fix(fix),
        .s1_pri(s1_pri),.s2_pri(s2_pri),.obj_prio(2'b00),.vdp_en(1'b1),.vdp_prio(vdp_prio),.vdp_ysn(ysd),.gfx_en(gfx),
        .s16_r(sr),.s16_g(sg),.s16_b(s16_blue),.vdp_r(rdel),.vdp_g(gdel),.vdp_b(bdel),.red(rrd),.green(ggd),.blue(bbd),
        .debug_bus(8'd0),.st_show(std),.joystick1(2'b00));
    jts18_colmix mix_old_s16(.rst(rst),.clk(clk48),.pxl_cen(pxl_cen),.pxl2_cen(pxl2_cen),.LHBL(lhbl),.LVBL(lvbl),
        .LHBL_dly(),.LVBL_dly(),.vid16_en(1'b1),.obj16(obj),.sa(sa),.sb(layer_b),.fix(fix),
        .s1_pri(s1_pri),.s2_pri(s2_pri),.obj_prio(2'b00),.vdp_en(1'b0),.vdp_prio(vdp_prio),.vdp_ysn(1'b1),.gfx_en(gfx),
        .s16_r(sr),.s16_g(sg),.s16_b(s16_blue),.vdp_r(8'd0),.vdp_g(8'd0),.vdp_b(8'd0),.red(rso),.green(gso),.blue(bso),
        .debug_bus(8'd0),.st_show(),.joystick1(2'b00));
    jts18_colmix mix_new_s16(.rst(rst),.clk(clk48),.pxl_cen(pxl_cen),.pxl2_cen(pxl2_cen),.LHBL(lhbl),.LVBL(lvbl),
        .LHBL_dly(),.LVBL_dly(),.vid16_en(1'b1),.obj16(obj),.sa(sa),.sb(layer_b),.fix(fix),
        .s1_pri(s1_pri),.s2_pri(s2_pri),.obj_prio(2'b00),.vdp_en(1'b0),.vdp_prio(vdp_prio),.vdp_ysn(1'b1),.gfx_en(gfx),
        .s16_r(sr),.s16_g(sg),.s16_b(s16_blue),.vdp_r(8'd0),.vdp_g(8'd0),.vdp_b(8'd0),.red(rsn),.green(gsn),.blue(bsn),
        .debug_bus(8'd0),.st_show(),.joystick1(2'b00));

    wire hb0,vb0,hb1,vb1,hbd,vbd,fhb0,fvb0,fhb1,fvb1,fhbd,fvbd;
    wire [7:0] fr0,fg0,fb0,fr1,fg1,fb1,frd,fgd,fbd;
    wire old_ref_sel_o,old_ref_sel,new_ref_sel_o,new_ref_sel,raw_ref_sel_o,raw_ref_sel;
    wire [23:0] old_ref_pr,old_ref_mix,old_ref_final,new_ref_pr,new_ref_mix,new_ref_final;
    wire [23:0] raw_ref_pr,raw_ref_mix,raw_ref_final;
    wire [23:0] old_ref_cross,new_ref_cross,raw_ref_cross;
    wire [1:0] old_ref_blank,new_ref_blank,raw_ref_blank;
    wire [1:0] old_ref_final_blank,new_ref_final_blank,raw_ref_final_blank;
    wire [5:0] old_ref_stages,new_ref_stages,raw_ref_stages;
    jtframe_short_blank #(.WIDTH(320),.HEIGHT(224)) crop0(.clk(clk48),.pxl_cen(pxl_cen),.LHBL(lhbl),.LVBL(lvbl),
        .HS(hs),.h_en(1'b0),.v_en(1'b0),.h_wide(1'b0),.v_wide(1'b0),.hb_out(hb0),.vb_out(vb0));
    jtframe_short_blank #(.WIDTH(320),.HEIGHT(224)) crop1(.clk(clk48),.pxl_cen(pxl_cen),.LHBL(lhbl),.LVBL(lvbl),
        .HS(hs),.h_en(1'b0),.v_en(1'b0),.h_wide(1'b0),.v_wide(1'b0),.hb_out(hb1),.vb_out(vb1));
    jtframe_crosshair #(.COLORW(8)) tail0(.rst(rst),.clk(clk48),.pxl_cen(pxl_cen),.flip(1'b0),.draw_en(1'b0),.cross_disable(2'b00),
        .pre_lvbl(vb0),.pre_lhbl(hb0),.pre_hs(hs),.pre_vs(vs),.lvbl(fvb0),.lhbl(fhb0),.hs(),.vs(),
        .gun_1p_x(9'd0),.gun_1p_y(9'd0),.gun_2p_x(9'd0),.gun_2p_y(9'd0),
        .rin(rr0),.gin(gg0),.bin(bb0),.rout(fr0),.gout(fg0),.bout(fb0));
    jtframe_crosshair #(.COLORW(8)) tail1(.rst(rst),.clk(clk48),.pxl_cen(pxl_cen),.flip(1'b0),.draw_en(1'b0),.cross_disable(2'b00),
        .pre_lvbl(vb1),.pre_lhbl(hb1),.pre_hs(hs),.pre_vs(vs),.lvbl(fvb1),.lhbl(fhb1),.hs(),.vs(),
        .gun_1p_x(9'd0),.gun_1p_y(9'd0),.gun_2p_x(9'd0),.gun_2p_y(9'd0),
        .rin(rr1),.gin(gg1),.bin(bb1),.rout(fr1),.gout(fg1),.bout(fb1));
    jtframe_short_blank #(.WIDTH(320),.HEIGHT(224)) cropd(.clk(clk48),.pxl_cen(pxl_cen),.LHBL(lhbl),.LVBL(lvbl),
        .HS(hs),.h_en(1'b0),.v_en(1'b0),.h_wide(1'b0),.v_wide(1'b0),.hb_out(hbd),.vb_out(vbd));
    jtframe_crosshair #(.COLORW(8)) taild(.rst(rst),.clk(clk48),.pxl_cen(pxl_cen),.flip(1'b0),.draw_en(1'b0),.cross_disable(2'b00),
        .pre_lvbl(vbd),.pre_lhbl(hbd),.pre_hs(hs),.pre_vs(vs),.lvbl(fvbd),.lhbl(fhbd),.hs(),.vs(),
        .gun_1p_x(9'd0),.gun_1p_y(9'd0),.gun_2p_x(9'd0),.gun_2p_y(9'd0),
        .rin(rrd),.gin(ggd),.bin(bbd),.rout(frd),.gout(fgd),.bout(fbd));

    jts18_mix_oracle old_oracle(.clk(clk48),.pxl(pxl_cen),.LHBL(lhbl),.LVBL(lvbl),.sa(sa),.sb(layer_b),.fix(fix),
        .s1_pri(s1_pri),.s2_pri(s2_pri),.obj(obj),.obj16(obj),.sr(sr),.sg(sg),.sb6(s16_blue),
        .ys(ys0),.vr(r0),.vg(g0),.vb(b0),.sel_o(old_ref_sel_o),.sel(old_ref_sel),.pr(old_ref_pr),
        .mix_rgb(old_ref_mix),.blank_bits(old_ref_blank),.blank_stages(old_ref_stages),.cross_rgb(old_ref_cross),
        .final_blank(old_ref_final_blank),.final_rgb(old_ref_final));
    jts18_mix_oracle new_oracle(.clk(clk48),.pxl(pxl_cen),.LHBL(lhbl),.LVBL(lvbl),.sa(sa),.sb(layer_b),.fix(fix),
        .s1_pri(s1_pri),.s2_pri(s2_pri),.obj(obj),.obj16(obj),.sr(sr),.sg(sg),.sb6(s16_blue),
        .ys(ys1),.vr(r1),.vg(g1),.vb(b1),.sel_o(new_ref_sel_o),.sel(new_ref_sel),.pr(new_ref_pr),
        .mix_rgb(new_ref_mix),.blank_bits(new_ref_blank),.blank_stages(new_ref_stages),.cross_rgb(new_ref_cross),
        .final_blank(new_ref_final_blank),.final_rgb(new_ref_final));
    jts18_mix_oracle raw_oracle(.clk(clk48),.pxl(pxl_cen),.LHBL(lhbl),.LVBL(lvbl),.sa(sa),.sb(layer_b),.fix(fix),
        .s1_pri(s1_pri),.s2_pri(s2_pri),.obj(obj),.obj16(obj),.sr(sr),.sg(sg),.sb6(s16_blue),
        .ys(ysd),.vr(rdel),.vg(gdel),.vb(bdel),.sel_o(raw_ref_sel_o),.sel(raw_ref_sel),.pr(raw_ref_pr),
        .mix_rgb(raw_ref_mix),.blank_bits(raw_ref_blank),.blank_stages(raw_ref_stages),.cross_rgb(raw_ref_cross),
        .final_blank(raw_ref_final_blank),.final_rgb(raw_ref_final));

    integer cyc=0,lastx=-1,lines=0,fr=0,mis=0,cap=0,capture_start_frame=-1;
    integer old_cen_sampled=0,new_cen_sampled=0,old_blank_active=0,new_blank_active=0,s16only_mismatches=0;
    integer cen_edge=0,gated_count=0,frac_count=0;
    integer gated_tick[0:3],frac_tick[0:3];
    integer old_final_nonblack=0,new_final_nonblack=0,raw_final_nonblack=0;
    integer wrapper_final_mismatch=0,raw_final_mismatch=0,final_visible_samples=0;
    integer old_final_colors=0,new_final_colors=0,raw_final_colors=0;
    reg [23:0] old_fcolor[0:15],new_fcolor[0:15],raw_fcolor[0:15];
    integer old_rgb_nonblack=0,new_rgb_nonblack=0,old_ys_on=0,new_ys_on=0;
    integer old_ys_off=0,new_ys_off=0;
    integer old_tuple_changes=0,new_tuple_changes=0;
    integer old_sel_changes=0,new_sel_changes=0,old_line_sel_changes=0,new_line_sel_changes=0;
    reg old_prev_sel=0,new_prev_sel=0;
    reg [24:0] old_prev_tuple=25'h1ffffff,new_prev_tuple=25'h1ffffff;
    integer old_line_rgb[0:11],new_line_rgb[0:11],old_line_runs[0:11],new_line_runs[0:11];
    integer old_line_ys[0:11],new_line_ys[0:11],old_line_ys_off[0:11],new_line_ys_off[0:11];
    integer old_distinct[0:11],new_distinct[0:11];
    reg [23:0] old_colors[0:11][0:15],new_colors[0:11][0:15];
    integer distinct_i, line_i;
    reg capture_en=0;
    reg lhbl_d=0,lvbl_d=0;
    reg sample_pxl,sample_pxl48,sample_rst,sample_lhbl,sample_lvbl,sample_ys0,sample_ys1,sample_sel0,sample_sel1;
    reg [8:0] sample_h,sample_v,sample_old_h,sample_old_v,sample_new_h,sample_new_v;
    reg [24:0] sample_raw_tuple,sample_d0,sample_d1;
    reg [7:0] sample_r0,sample_g0,sample_b0,sample_r1,sample_g1,sample_b1;
    reg [5:0] sample_sr,sample_sg,sample_sb;
    reg sample_obj,sample_sa,sample_layer_b,sample_fix,sample_s1_pri,sample_s2_pri;
    integer f,fo,fb,boundary_edge=0,native_tuple_checks=0,x6_expected_checks=0,reset_events=0;
    integer reset_bridge_trials=0,cold_reset_checks=0;
    integer reset_bridge_reference_captures=0,reset_bridge_completed_rows=0;
    reg [24:0] reset_bridge_ref[0:319];
    reg [3:0] native_seen[0:1];
    integer native_count[0:1];
    integer native_idx,native_frame;
    initial begin f=$fopen("samples.csv","w");
        $fdisplay(f,"frame,sample,x,H,V,oldH,oldV,newH,newV,oldYS,oldRawRGB,newYS,newRawRGB,oldVDPsel,newVDPsel,S16RGB,obj,sa,sb,fix,s1_pri,s2_pri,LHBL,LVBL,oldMixRGB,oldFinalBlank,oldFinalRGB,newMixRGB,newFinalBlank,newFinalRGB,rawMixRGB,rawFinalBlank,rawFinalRGB,rawYS,deh0,dev0,deh1,dev1");
    end
    initial begin
        fo=$fopen("boundary-oracle.csv","w");
        $fdisplay(fo,"edge,time,frame,mcnt,clk48,clk96,frameworkPxl,framework2x,gatedPxl,gated2x,fracPxl,frac2x,H,V,LHBL,LVBL,oldNativeH,oldNativeV,newNativeH,newNativeV,flags,S16RGB,paladdr,paldata,oldTuple,newTuple,wrapperD0,wrapperD1,rawTuple,oldActualSelO,oldRefSelO,oldActualSel,oldRefSel,oldActualPR,oldRefPR,oldActualMix,oldRefMix,oldBlankStage,oldRefCross,oldMixBlank,oldFinalBlank,oldRefFinalBlank,oldFinal,oldRefFinal,newActualSelO,newRefSelO,newActualSel,newRefSel,newActualPR,newRefPR,newActualMix,newRefMix,newBlankStage,newRefCross,newMixBlank,newFinalBlank,newRefFinalBlank,newFinal,newRefFinal,rawActualSelO,rawRefSelO,rawActualSel,rawRefSel,rawActualPR,rawRefPR,rawActualMix,rawRefMix,rawBlankStage,rawRefCross,rawMixBlank,rawFinalBlank,rawRefFinalBlank,rawFinal,rawRefFinal,oldCrossActual,newCrossActual,rawCrossActual");
        fb=$fopen("boundary-pre.csv","w");
        $fdisplay(fb,"edge,time,frame,mcnt,clk48,clk96,frameworkCEN,gatedCEN,fracCEN,H,V,blank,oldNativeH,oldNativeV,newNativeH,newNativeV,oldTuple,newTuple,wrapperD0,wrapperD1,rawTuple,S16RGB,paladdr,paldata,flags,oldTilemap,oldNblnk,oldSelO,oldSel,oldPR,oldMix,oldMixBlank,oldFinalBlank,oldFinal,newTilemap,newNblnk,newSelO,newSel,newPR,newMix,newMixBlank,newFinalBlank,newFinal,rawTilemap,rawNblnk,rawSelO,rawSel,rawPR,rawMix,rawMixBlank,rawFinalBlank,rawFinal,oldCrossActual,newCrossActual,rawCrossActual");
    end

    function [15:0] physical_addr(input [15:0] cpu_addr);
        begin physical_addr={cpu_addr[9:2],cpu_addr[15:10],cpu_addr[1:0]}; end
    endfunction
    function valid_fixture_color(input [23:0] color);
        begin
            case(color)
                24'hce3100,24'h008e72,24'h0031ff,24'h00ce31,24'h00ff00,
                24'hff0000,24'hff00ff,24'h0000ff: valid_fixture_color=1;
                default: valid_fixture_color=0;
            endcase
        end
    endfunction
    initial for(integer k=0;k<12;k=k+1) begin
        old_line_rgb[k]=0;new_line_rgb[k]=0;old_line_runs[k]=0;new_line_runs[k]=0;
        old_line_ys[k]=0;new_line_ys[k]=0;old_line_ys_off[k]=0;new_line_ys_off[k]=0;old_distinct[k]=0;new_distinct[k]=0;
        for(integer j=0;j<16;j=j+1) begin old_colors[k][j]=24'hffffff;new_colors[k][j]=24'hffffff;end
    end
    initial for(integer k=0;k<16;k=k+1) begin old_fcolor[k]=24'hffffff;new_fcolor[k]=24'hffffff;raw_fcolor[k]=24'hffffff;end
    initial begin native_seen[0]=0;native_seen[1]=0;native_count[0]=0;native_count[1]=0;end
    always @(posedge clk48) begin
        sample_pxl=pxl_cen;
        sample_pxl48=pxl48;
        sample_rst=rst;
        sample_h=h; sample_v=v; sample_lhbl=lhbl; sample_lvbl=lvbl;
        sample_old_h=old_vdp.u_vdp.l106; sample_old_v=old_vdp.u_vdp.l105;
        sample_new_h=new_vdp.u_vdp.l106; sample_new_v=new_vdp.u_vdp.l105;
        sample_ys0=ys0; sample_ys1=ys1; sample_sel0=mix_old.vdp_sel; sample_sel1=mix_new.vdp_sel;
        sample_raw_tuple=raw_tuple1; sample_d0=wrapper_d0; sample_d1=wrapper_d1;
        sample_r0=r0;sample_g0=g0;sample_b0=b0;sample_r1=r1;sample_g1=g1;sample_b1=b1;
        sample_sr=sr;sample_sg=sg;sample_sb=s16_blue;
        sample_obj=obj;sample_sa=sa;sample_layer_b=layer_b;sample_fix=fix;sample_s1_pri=s1_pri;sample_s2_pri=s2_pri;
        #1;
        if(sample_rst) begin
            if(wrapper_d0!==25'd0 || wrapper_d1!==25'd0) $fatal(1,"wrapper tuple reset did not clear both registers");
        end else if(sample_pxl48) begin
            if(wrapper_d0!==sample_raw_tuple || wrapper_d1!==sample_d0)
                $fatal(1,"wrapper tuple pipeline mismatch raw=%h oldD0=%h gotD0/D1=%h/%h",sample_raw_tuple,sample_d0,wrapper_d0,wrapper_d1);
        end else if(wrapper_d0!==sample_d0 || wrapper_d1!==sample_d1)
            $fatal(1,"wrapper tuple changed without gated pixel enable");
        if(capture_en && fr>=capture_start_frame && fr<capture_start_frame+2 && !rst && sample_pxl48 &&
            sample_new_v==5 && sample_new_h>=26 && sample_new_h<=29) begin
            if(sample_v!==9'd5 || sample_h!==(9'h0c0 + (sample_new_h-9'd26)))
                $fatal(1,"native producer/source coordinate mismatch physical H/V=%03x/%03x native H/V=%03x/%03x",
                    sample_h,sample_v,sample_new_h,sample_new_v);
            case(sample_new_h)
                26: if(sample_raw_tuple!==25'h1ce3100) $fatal(1,"native V5/X0 tuple %h expected 1ce3100",sample_raw_tuple);
                27: if(sample_raw_tuple!==25'h1008e72) $fatal(1,"native V5/X1 tuple %h expected 1008e72",sample_raw_tuple);
                28: if(sample_raw_tuple!==25'h0000000) $fatal(1,"native V5/X2 tuple %h expected transparent zero",sample_raw_tuple);
                29: if(sample_raw_tuple!==25'h100ce31) $fatal(1,"native V5/X3 tuple %h expected 100ce31",sample_raw_tuple);
            endcase
            if(wrapper_d0!==sample_raw_tuple) $fatal(1,"native capture did not reach wrapper stage0 H=%0d",sample_new_h);
            if(sample_new_h==29 && wrapper_d1!==25'd0)
                $fatal(1,"known transparent V5/X2 did not propagate through stage1: %h",wrapper_d1);
            native_idx=sample_new_h-26;
            native_frame=fr-capture_start_frame;
            if(native_frame<0 || native_frame>1) $fatal(1,"native tuple observation outside two physical captures");
            if(native_seen[native_frame][native_idx])
                $fatal(1,"duplicate native tuple coordinate frame=%0d external H=%03x native H=%0d",fr,sample_h,sample_new_h);
            native_seen[native_frame][native_idx]=1'b1;
            native_count[native_frame]=native_count[native_frame]+1;
            native_tuple_checks=native_tuple_checks+1;
        end
        if(sample_pxl) begin
            if(sample_lvbl && !lvbl_d) fr=fr+1;
            if(capture_en && fr>=capture_start_frame && fr<capture_start_frame+2 &&
                sample_lhbl && sample_lvbl && sample_v>=5 && sample_v<11 && sample_h>=9'h0c0) begin
                lastx={23'd0,sample_h}-32'd192;
                line_i=cap/320;
                lines=line_i+1;
                $fdisplay(f,"%0d,%0d,%0d,%03x,%03x,%03x,%03x,%03x,%03x,%b,%06x,%b,%06x,%b,%b,%06x,%b,%b,%b,%b,%b,%b,%b,%b,%06x,%02b,%06x,%06x,%02b,%06x,%06x,%02b,%06x,%b,%b,%b,%b,%b",
                    fr,lines,lastx,sample_h,sample_v,sample_old_h,sample_old_v,
                    sample_new_h,sample_new_v,
                    sample_ys0,{sample_r0,sample_g0,sample_b0},sample_ys1,{sample_r1,sample_g1,sample_b1},sample_sel0,sample_sel1,
                    {sample_sr,sample_sg,sample_sb},sample_obj,sample_sa,sample_layer_b,sample_fix,sample_s1_pri,sample_s2_pri,sample_lhbl,sample_lvbl,
                    {rr0,gg0,bb0},{fhb0,fvb0},{fr0,fg0,fb0},
                    {rr1,gg1,bb1},{fhb1,fvb1},{fr1,fg1,fb1},
                    {rrd,ggd,bbd},{fhbd,fvbd},{frd,fgd,fbd},ysd,deh0,dev0,deh1,dev1);
                cap=cap+1;
                if({sample_r0,sample_g0,sample_b0}!=0) old_rgb_nonblack=old_rgb_nonblack+1;
                if({sample_r1,sample_g1,sample_b1}!=0) new_rgb_nonblack=new_rgb_nonblack+1;
                if(sample_ys0) old_ys_on=old_ys_on+1; else old_ys_off=old_ys_off+1;
                if(sample_ys1) new_ys_on=new_ys_on+1; else new_ys_off=new_ys_off+1;
                if({sample_ys0,sample_r0,sample_g0,sample_b0}!==old_prev_tuple) old_tuple_changes=old_tuple_changes+1;
                if({sample_ys1,sample_r1,sample_g1,sample_b1}!==new_prev_tuple) new_tuple_changes=new_tuple_changes+1;
                if(sample_sel0!==old_prev_sel) begin old_sel_changes=old_sel_changes+1;old_line_sel_changes=old_line_sel_changes+1;end
                if(sample_sel1!==new_prev_sel) begin new_sel_changes=new_sel_changes+1;new_line_sel_changes=new_line_sel_changes+1;end
                old_prev_tuple={sample_ys0,sample_r0,sample_g0,sample_b0};new_prev_tuple={sample_ys1,sample_r1,sample_g1,sample_b1};
                old_prev_sel=sample_sel0;new_prev_sel=sample_sel1;
                if({sample_r0,sample_g0,sample_b0}!=0) begin
                    old_line_rgb[line_i]=old_line_rgb[line_i]+1;
                    if(!valid_fixture_color({sample_r0,sample_g0,sample_b0})) $fatal(1,"baseline raw pixel outside fixture palette at line=%0d x=%0d rgb=%06x",line_i,lastx,{sample_r0,sample_g0,sample_b0});
                    distinct_i=0;while(distinct_i<old_distinct[line_i] && old_colors[line_i][distinct_i]!={sample_r0,sample_g0,sample_b0}) distinct_i=distinct_i+1;
                    if(distinct_i==old_distinct[line_i] && old_distinct[line_i]<16) begin old_colors[line_i][distinct_i]={sample_r0,sample_g0,sample_b0};old_distinct[line_i]=old_distinct[line_i]+1;end
                end
                if({sample_r1,sample_g1,sample_b1}!=0) begin
                    new_line_rgb[line_i]=new_line_rgb[line_i]+1;
                    if(!valid_fixture_color({sample_r1,sample_g1,sample_b1})) $fatal(1,"candidate raw pixel outside fixture palette at line=%0d x=%0d rgb=%06x",line_i,lastx,{sample_r1,sample_g1,sample_b1});
                    distinct_i=0;while(distinct_i<new_distinct[line_i] && new_colors[line_i][distinct_i]!={sample_r1,sample_g1,sample_b1}) distinct_i=distinct_i+1;
                    if(distinct_i==new_distinct[line_i] && new_distinct[line_i]<16) begin new_colors[line_i][distinct_i]={sample_r1,sample_g1,sample_b1};new_distinct[line_i]=new_distinct[line_i]+1;end
                end
                if(sample_ys0) old_line_ys[line_i]=old_line_ys[line_i]+1;else old_line_ys_off[line_i]=old_line_ys_off[line_i]+1;
                if(sample_ys1) new_line_ys[line_i]=new_line_ys[line_i]+1;else new_line_ys_off[line_i]=new_line_ys_off[line_i]+1;
                if(lhd0 && lvd0) old_blank_active=old_blank_active+1;
                if(lhd1 && lvd1) new_blank_active=new_blank_active+1;
                if({rr0,gg0,bb0} !== {rr1,gg1,bb1}) mis=mis+1;
                if({rso,gso,bso} !== {rsn,gsn,bsn}) s16only_mismatches=s16only_mismatches+1;
                if(fhb0 && fvb0 && fhb1 && fvb1 && fhbd && fvbd) begin
                    if(lastx==6 && sample_v==5) begin
                        if({fr1,fg1,fb1}!==24'h002800)
                            $fatal(1,"independent x6 S16 pixel expectation failed frame=%0d RGB=%06x expected=002800",fr,{fr1,fg1,fb1});
                        x6_expected_checks=x6_expected_checks+1;
                    end
                    final_visible_samples=final_visible_samples+1;
                    if({fr0,fg0,fb0}!=0) old_final_nonblack=old_final_nonblack+1;
                    if({fr1,fg1,fb1}!=0) new_final_nonblack=new_final_nonblack+1;
                    if({frd,fgd,fbd}!=0) raw_final_nonblack=raw_final_nonblack+1;
                    if({fr0,fg0,fb0}!={fr1,fg1,fb1}) wrapper_final_mismatch=wrapper_final_mismatch+1;
                    if({fr0,fg0,fb0}!={frd,fgd,fbd}) raw_final_mismatch=raw_final_mismatch+1;
                    if({fr0,fg0,fb0}!=0) begin
                        distinct_i=0;while(distinct_i<old_final_colors && old_fcolor[distinct_i]!={fr0,fg0,fb0}) distinct_i=distinct_i+1;
                        if(distinct_i==old_final_colors && old_final_colors<16) begin old_fcolor[distinct_i]={fr0,fg0,fb0};old_final_colors=old_final_colors+1;end
                    end
                    if({fr1,fg1,fb1}!=0) begin
                        distinct_i=0;while(distinct_i<new_final_colors && new_fcolor[distinct_i]!={fr1,fg1,fb1}) distinct_i=distinct_i+1;
                        if(distinct_i==new_final_colors && new_final_colors<16) begin new_fcolor[distinct_i]={fr1,fg1,fb1};new_final_colors=new_final_colors+1;end
                    end
                    if({frd,fgd,fbd}!=0) begin
                        distinct_i=0;while(distinct_i<raw_final_colors && raw_fcolor[distinct_i]!={frd,fgd,fbd}) distinct_i=distinct_i+1;
                        if(distinct_i==raw_final_colors && raw_final_colors<16) begin raw_fcolor[distinct_i]={frd,fgd,fbd};raw_final_colors=raw_final_colors+1;end
                    end
                end
                if(lastx==319) begin
                    if(old_line_rgb[line_i]<64 || new_line_rgb[line_i]<64 || old_line_ys[line_i]<64 || new_line_ys[line_i]<64 ||
                        old_line_ys_off[line_i]<4 || new_line_ys_off[line_i]<4 ||
                        old_distinct[line_i]<4 || new_distinct[line_i]<4 || old_line_sel_changes<10 || new_line_sel_changes<10)
                        $fatal(1,"incomplete per-line pixel oracle row=%0d oldRGB/YS+/YS-/colors/selectEdges=%0d/%0d/%0d/%0d/%0d new=%0d/%0d/%0d/%0d/%0d",
                            line_i,old_line_rgb[line_i],old_line_ys[line_i],old_line_ys_off[line_i],old_distinct[line_i],old_line_sel_changes,
                            new_line_rgb[line_i],new_line_ys[line_i],new_line_ys_off[line_i],new_distinct[line_i],new_line_sel_changes);
                    old_line_sel_changes=0;new_line_sel_changes=0;
                end
            end
            lhbl_d=sample_lhbl; lvbl_d=sample_lvbl;
        end
    end
    always @(posedge clk48) begin
        cen_edge=cen_edge+1;
        if(!rst && pxl48 && gated_count<4) begin
            gated_tick[gated_count]=cen_edge;gated_count=gated_count+1;
        end
        if(!rst && frac_cen12[1] && frac_count<4) begin
            frac_tick[frac_count]=cen_edge;frac_count=frac_count+1;
        end
        if(pxl_cen) old_cen_sampled=old_cen_sampled+1;
        if(pxl48) new_cen_sampled=new_cen_sampled+1;
    end
    // Keep a bounded MCLK-by-MCLK record around x0..8 on row V=5 in both
    // captured frames. Every value before the comma is pre-edge; values after
    // it are sampled after NBA updates. This exposes the mixer/tail latency
    // that the one-sample-per-pixel CSV cannot resolve.
    always @(posedge clk48) begin
        if(capture_en && fr>=capture_start_frame && fr<capture_start_frame+2 &&
            v==5 && h>=9'h0bb && h<=9'h0ca) begin
            $fdisplay(fb,"%0d,%0t,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h",boundary_edge,$time,fr,multi_clock_cnt,clk48,clk96,
                {pxl_cen,pxl2_cen},{pxl48,pxl2_48},{frac_cen12[1],frac_cen12[0]},h,v,{lhbl,lvbl},
                old_vdp.u_vdp.l106,old_vdp.u_vdp.l105,new_vdp.u_vdp.l106,new_vdp.u_vdp.l105,
                {ys0,r0,g0,b0},{ys1,r1,g1,b1},wrapper_d0,wrapper_d1,{ysd,rdel,gdel,bdel},
                {sr,sg,s16_blue},s16_pal_addr,s16_pal_dout,{obj,sa,layer_b,fix,s1_pri},
                mix_old.tilemap_l,mix_old.nblnk,mix_old.vdp_sel_o,mix_old.vdp_sel,{mix_old.pr,mix_old.pg,mix_old.pb},{rr0,gg0,bb0},{lhd0,lvd0},{fhb0,fvb0},{fr0,fg0,fb0},
                mix_new.tilemap_l,mix_new.nblnk,mix_new.vdp_sel_o,mix_new.vdp_sel,{mix_new.pr,mix_new.pg,mix_new.pb},{rr1,gg1,bb1},{lhd1,lvd1},{fhb1,fvb1},{fr1,fg1,fb1},
                mix_raw.tilemap_l,mix_raw.nblnk,mix_raw.vdp_sel_o,mix_raw.vdp_sel,{mix_raw.pr,mix_raw.pg,mix_raw.pb},{rrd,ggd,bbd},{lhd2,lvd2},{fhbd,fvbd},{frd,fgd,fbd},
                {tail0.u_crosshair_color.r_cross,tail0.u_crosshair_color.g_cross,tail0.u_crosshair_color.b_cross},
                {tail1.u_crosshair_color.r_cross,tail1.u_crosshair_color.g_cross,tail1.u_crosshair_color.b_cross},
                {taild.u_crosshair_color.r_cross,taild.u_crosshair_color.g_cross,taild.u_crosshair_color.b_cross});
            #1;
            $fdisplay(fo,"%0d,%0t,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h,%h",
                boundary_edge,$time,fr,multi_clock_cnt,clk48,clk96,pxl_cen,pxl2_cen,pxl48,pxl2_48,frac_cen12[1],frac_cen12[0],h,v,lhbl,lvbl,
                old_vdp.u_vdp.l106,old_vdp.u_vdp.l105,new_vdp.u_vdp.l106,new_vdp.u_vdp.l105,
                {obj,sa,layer_b,fix,s1_pri},{sr,sg,s16_blue},s16_pal_addr,s16_pal_dout,
                {ys0,r0,g0,b0},{ys1,r1,g1,b1},wrapper_d0,wrapper_d1,{ysd,rdel,gdel,bdel},
                mix_old.vdp_sel_o,old_ref_sel_o,mix_old.vdp_sel,old_ref_sel,{mix_old.pr,mix_old.pg,mix_old.pb},old_ref_pr,{rr0,gg0,bb0},old_ref_mix,old_ref_stages,old_ref_cross,{lhd0,lvd0},old_ref_final_blank,{fhb0,fvb0},{fr0,fg0,fb0},old_ref_final,
                mix_new.vdp_sel_o,new_ref_sel_o,mix_new.vdp_sel,new_ref_sel,{mix_new.pr,mix_new.pg,mix_new.pb},new_ref_pr,{rr1,gg1,bb1},new_ref_mix,new_ref_stages,new_ref_cross,{lhd1,lvd1},new_ref_final_blank,{fhb1,fvb1},{fr1,fg1,fb1},new_ref_final,
                mix_raw.vdp_sel_o,raw_ref_sel_o,mix_raw.vdp_sel,raw_ref_sel,{mix_raw.pr,mix_raw.pg,mix_raw.pb},raw_ref_pr,{rrd,ggd,bbd},raw_ref_mix,raw_ref_stages,raw_ref_cross,{lhd2,lvd2},raw_ref_final_blank,{fhbd,fvbd},{frd,fgd,fbd},raw_ref_final,
                {tail0.u_crosshair_color.r_cross,tail0.u_crosshair_color.g_cross,tail0.u_crosshair_color.b_cross},
                {tail1.u_crosshair_color.r_cross,tail1.u_crosshair_color.g_cross,tail1.u_crosshair_color.b_cross},
                {taild.u_crosshair_color.r_cross,taild.u_crosshair_color.g_cross,taild.u_crosshair_color.b_cross});
            if(mix_old.vdp_sel_o!==old_ref_sel_o || mix_old.vdp_sel!==old_ref_sel ||
                {mix_old.pr,mix_old.pg,mix_old.pb}!==old_ref_pr || {rr0,gg0,bb0}!==old_ref_mix ||
                {lhd0,lvd0}!==old_ref_blank || {fhb0,fvb0}!==old_ref_final_blank ||
                {fr0,fg0,fb0}!==old_ref_final || {tail0.u_crosshair_color.r_cross,tail0.u_crosshair_color.g_cross,tail0.u_crosshair_color.b_cross}!==old_ref_cross ||
                mix_new.vdp_sel_o!==new_ref_sel_o || mix_new.vdp_sel!==new_ref_sel ||
                {mix_new.pr,mix_new.pg,mix_new.pb}!==new_ref_pr || {rr1,gg1,bb1}!==new_ref_mix ||
                {lhd1,lvd1}!==new_ref_blank || {fhb1,fvb1}!==new_ref_final_blank ||
                {fr1,fg1,fb1}!==new_ref_final || {tail1.u_crosshair_color.r_cross,tail1.u_crosshair_color.g_cross,tail1.u_crosshair_color.b_cross}!==new_ref_cross ||
                mix_raw.vdp_sel_o!==raw_ref_sel_o || mix_raw.vdp_sel!==raw_ref_sel ||
                {mix_raw.pr,mix_raw.pg,mix_raw.pb}!==raw_ref_pr || {rrd,ggd,bbd}!==raw_ref_mix ||
                {lhd2,lvd2}!==raw_ref_blank || {fhbd,fvbd}!==raw_ref_final_blank ||
                {frd,fgd,fbd}!==raw_ref_final || {taild.u_crosshair_color.r_cross,taild.u_crosshair_color.g_cross,taild.u_crosshair_color.b_cross}!==raw_ref_cross)
                $fatal(1,"independent boundary oracle disagreement frame=%0d H=%03x V=%03x",fr,h,v);
            boundary_edge=boundary_edge+1;
        end
    end

    task write_old_at(input [22:0] address,input [15:0] data);
        integer t; begin
            // Legal FX68K-style S0/S1/S2/S3/S4/S6 sequence, phased from
            // this wrapper's actual 10 MHz service clock.
            @(posedge old_vdp.clk10); a0=address;d0=16'hffff;rnw0=0;ds0=3;as0=1;
            @(negedge old_vdp.clk10); as0=0;
            @(posedge old_vdp.clk10); d0=data;
            @(negedge old_vdp.clk10); ds0=0;t=0;
            while(ack0 && t<1024) begin @(posedge old_vdp.clk10); #2;t=t+1; end
            if(t==1024) $fatal(1,"baseline write timeout %04x",data);
            @(negedge old_vdp.clk10); @(posedge old_vdp.clk10);as0=1;ds0=3;rnw0=1;
            @(negedge old_vdp.clk10);t=0;
            while(!ack0 && t<32) begin @(posedge old_vdp.clk10); #2;t=t+1; end
            if(t==32) $fatal(1,"baseline DTACK stuck after %04x",data);
            @(posedge old_vdp.clk10); // 50 ns S6 post-release hold
        end
    endtask
    task write_old(input [15:0] data); begin write_old_at(23'h600002,data); end endtask
    task write_new_at(input [22:0] address,input [15:0] data);
        integer t; begin
            @(posedge new_vdp.clk10); a1=address;d1=16'hffff;rnw1=0;ds1=3;as1=1;
            @(negedge new_vdp.clk10); as1=0;
            @(posedge new_vdp.clk10); d1=data;
            @(negedge new_vdp.clk10); ds1=0;t=0;
            while(ack1 && t<1024) begin @(posedge new_vdp.clk10); #2;t=t+1; end
            if(t==1024) $fatal(1,"candidate write timeout %04x",data);
            @(negedge new_vdp.clk10); @(posedge new_vdp.clk10);as1=1;ds1=3;rnw1=1;
            @(negedge new_vdp.clk10);t=0;
            while(!ack1 && t<32) begin @(posedge new_vdp.clk10); #2;t=t+1; end
            if(t==32) $fatal(1,"candidate DTACK stuck after %04x",data);
            @(posedge new_vdp.clk10); // 50 ns S6 post-release hold
        end
    endtask
    task write_new(input [15:0] data); begin write_new_at(23'h600002,data); end endtask
    task read_new_at(input [22:0] address,output reg [15:0] data);
        integer t; begin
            @(posedge new_vdp.clk10); a1=address;d1=16'hffff;rnw1=1;ds1=3;as1=1;
            @(negedge new_vdp.clk10); as1=0;
            @(posedge new_vdp.clk10);
            @(negedge new_vdp.clk10); ds1=0;t=0;
            while(ack1 && t<1024) begin @(posedge new_vdp.clk10); #2;t=t+1; end
            if(t==1024 || ack1!==1'b0) $fatal(1,"candidate read timeout/release addr=%06x",address);
            // Sample read data in S6 after the candidate's own ACK and before release.
            @(negedge new_vdp.clk10);
            @(posedge new_vdp.clk10); #2;
            data=q1;as1=1;ds1=3;
            @(negedge new_vdp.clk10);t=0;
            while(!ack1 && t<32) begin @(posedge new_vdp.clk10); #2;t=t+1; end
            if(t==32 || ack1!==1'b1) $fatal(1,"candidate DTACK stuck after read addr=%06x",address);
            @(posedge new_vdp.clk10); // S6 address/data hold
        end
    endtask
    task wait_one_s16_frame;
        integer p; begin
            // Count one complete timer raster at its actual 6 MHz pixel CEN,
            // independent of whether the current cursor is near VS.
            p=0;
            while(p<400*262) begin @(posedge clk48); if(pxl48) p=p+1; end
        end
    endtask
    task wait_raw_zero_and_wrapper_drain(input [255:0] context_name);
        integer t,events; begin
            t=0;
            while(raw_tuple1!==25'd0 && t<2*262*400*8) begin @(posedge clk48); #1; t=t+1; end
            if(raw_tuple1!==25'd0) $fatal(1,"%0s raw YM tuple did not mute",context_name);
            events=0;
            while(events<2) begin
                @(posedge clk48);
                if(pxl48) begin
                    #1; events=events+1;
                    if(events==2 && (wrapper_d0!==25'd0 || wrapper_d1!==25'd0))
                        $fatal(1,"%0s invalidation exceeded two gated captures: d0/d1=%h/%h",context_name,wrapper_d0,wrapper_d1);
                end
            end
        end
    endtask

    task config_old;
        integer t; begin
            write_old(16'h8f02);write_old(16'h8238);write_old(16'h833c);
            write_old(16'h8406);write_old(16'h857e);write_old(16'h8700);write_old(16'h8b00);
            write_old(16'h8d3f);write_old(16'h9000);write_old(16'h9100);write_old(16'h9200);
        end
    endtask
    task config_new;
        integer t; begin
            write_new(16'h8f02);write_new(16'h8238);write_new(16'h833c);
            write_new(16'h8406);write_new(16'h857e);write_new(16'h8700);write_new(16'h8b00);
            write_new(16'h8d3f);write_new(16'h9000);write_new(16'h9100);write_new(16'h9200);
        end
    endtask

    task reset_bridge_check_internal_state(input [8*16-1:0] context_name);
        begin
            if(new_vdp.u_vdp.passive_quarter!==2'd0 || new_vdp.u_vdp.passive_dwell!==3'd2 ||
                new_vdp.u_vdp.passive_tick!==3'd0 || new_vdp.u_vdp.passive_active_countdown!==13'd0 ||
                new_vdp.u_vdp.passive_prime_pending!==1'b0 || new_vdp.u_vdp.passive_seed_active!==1'b0 ||
                new_vdp.u_vdp.passive_seed_committed!==1'b0 || new_vdp.u_vdp.passive_v0_committed!==1'b0 ||
                new_vdp.u_vdp.passive_render_ready!==1'b0 || new_vdp.u_vdp.u_raster.locked!==1'b0 ||
                new_vdp.u_vdp.u_raster.geometry_valid!==1'b0 || new_vdp.u_vdp.u_raster.phase_error!==1'b0)
                $fatal(1,"%0s reset did not clear scheduler/acquisition/raster state",context_name);
        end
    endtask

    task reset_bridge_check_assets;
        begin
            if(new_vdp.u_vdp.color_ram[6'h21]!==9'h007 || new_vdp.u_vdp.color_ram[6'h22]!==9'h038 ||
                new_vdp.u_vdp.color_ram[6'h23]!==9'h1c0 || new_vdp.u_vdp.color_ram[6'h24]!==9'h1c7 ||
                new_vdp.u_vdp.color_ram[6'h25]!==9'h0e0 || new_vdp.u_vdp.color_ram[6'h26]!==9'h00e ||
                new_vdp.u_vdp.color_ram[6'h27]!==9'h070 || new_vdp.u_vdp.color_ram[6'h28]!==9'h1c8)
                $fatal(1,"reset bridge literal CRAM palette asset lost");
            if({new_vdp.u_vram.mem[224],new_vdp.u_vram.mem[225]}!==16'h0240 ||
                {new_vdp.u_vram.mem[physical_addr(16'he080)],new_vdp.u_vram.mem[physical_addr(16'he081)]}!==16'h0240 ||
                {new_vdp.u_vram.mem[physical_addr(16'h0040)],new_vdp.u_vram.mem[physical_addr(16'h0041)]}!==16'h0234)
                $fatal(1,"reset bridge literal VRAM name/pattern assets lost");
        end
    endtask

    task reset_bridge_row(input integer capture_reference,input integer trial_id);
        integer timeout,row_count,row_nonzero,distinct_count,i,row_frame;
        reg seen_color,row_started;
        reg [8:0] native_h,native_v,ext_h,ext_v,expected_native_h;
        reg [24:0] raw_pre,d0_pre;
        reg [23:0] distinct_rgb[0:15];
        begin
            timeout=0;
            while((!new_vdp.u_vdp.passive_render_ready || !new_vdp.u_vdp.passive_raster_locked ||
                !new_vdp.u_vdp.passive_geometry_supported || new_vdp.u_vdp.l106!==9'd26 ||
                new_vdp.u_vdp.l105!==9'd0) && timeout<2*262*400*16) begin
                @(posedge clk48); timeout=timeout+1;
            end
            if(!new_vdp.u_vdp.passive_render_ready || !new_vdp.u_vdp.passive_raster_locked ||
                !new_vdp.u_vdp.passive_geometry_supported || new_vdp.u_vdp.l106!==9'd26 ||
                new_vdp.u_vdp.l105!==9'd0)
                $fatal(1,"reset bridge bounded re-prime missed locked H26/V0 H/V=%0d/%0d ready/locked/supported=%b/%b/%b",
                    new_vdp.u_vdp.l106,new_vdp.u_vdp.l105,new_vdp.u_vdp.passive_render_ready,
                    new_vdp.u_vdp.passive_raster_locked,new_vdp.u_vdp.passive_geometry_supported);
            if(capture_reference!=0 && reset_bridge_reference_captures!=0)
                $fatal(1,"reset bridge reference row capture attempted more than once");
            if(capture_reference==0 && reset_bridge_reference_captures!=320)
                $fatal(1,"reset bridge reference row unavailable before trial %0d: captures=%0d",
                    trial_id,reset_bridge_reference_captures);
            row_count=0;row_nonzero=0;distinct_count=0;timeout=0;row_started=0;row_frame=-1;
            ext_h=0;native_h=0;
            for(i=0;i<16;i=i+1) distinct_rgb[i]=24'hffffff;
            // A physical external V5 scan row maps to native V5 at H26..329
            // and native V6 from H330..345 because the native counter updates
            // at the H330 blank transition. Anchor and retain external coords.
            while(row_count<320 && timeout<262*400*16) begin
                @(posedge clk48);
                if(row_started==0 && !rst && pxl48 && h==9'd192 && v==9'd5 &&
                    new_vdp.u_vdp.l106==9'd26 && new_vdp.u_vdp.l105==9'd5) begin
                    row_started=1;
                    row_frame=fr;
                    $display("RESET_BRIDGE_ROW_ANCHOR trial=%0d ref=%0d frame=%0d ext=%03x/%03x native=%0d/%0d time=%0t",
                        trial_id,capture_reference,fr,h,v,new_vdp.u_vdp.l106,new_vdp.u_vdp.l105,$time);
                end
                if(row_started!=0 && !rst && pxl48 && v==9'd5 && h>=9'd192) begin
                    native_h=new_vdp.u_vdp.l106;native_v=new_vdp.u_vdp.l105;
                    ext_h=h;ext_v=v;raw_pre=raw_tuple1;d0_pre=wrapper_d0;
                    expected_native_h=9'd26+row_count[8:0];
                    if(fr!=row_frame || ext_h!==9'd192+row_count[8:0] ||
                        native_h!==expected_native_h || ext_v!==9'd5 ||
                        native_v!==(native_h<=9'd329 ? 9'd5 : 9'd6))
                        $fatal(1,"reset bridge physical-row coordinate/order mismatch trial=%0d index=%0d frame=%0d ext=%03x/%03x native=%0d/%0d",
                            trial_id,row_count,fr,ext_h,ext_v,native_h,native_v);
                    if(capture_reference!=0) reset_bridge_ref[row_count]=raw_pre;
                    else if(raw_pre!==reset_bridge_ref[row_count])
                        $fatal(1,"reset bridge row differs from frozen pre-warm reference trial=%0d x=%0d got=%h expected=%h",
                            trial_id,row_count,raw_pre,reset_bridge_ref[row_count]);
                    if(row_count==0 && raw_pre!==25'h1ce3100)
                        $fatal(1,"reset bridge V5/X0 raw tuple %h expected 1ce3100",raw_pre);
                    if(row_count==1 && raw_pre!==25'h1008e72)
                        $fatal(1,"reset bridge V5/X1 raw tuple %h expected 1008e72",raw_pre);
                    if(row_count==2 && raw_pre!==25'h0000000)
                        $fatal(1,"reset bridge V5/X2 raw tuple %h expected transparent zero",raw_pre);
                    if(row_count==3 && raw_pre!==25'h100ce31)
                        $fatal(1,"reset bridge V5/X3 raw tuple %h expected 100ce31",raw_pre);
                    #1;
                    if(wrapper_d0!==raw_pre || wrapper_d1!==d0_pre)
                        $fatal(1,"reset bridge tuple pipeline mismatch trial=%0d row=%0d raw=%h oldD0=%h newD0/D1=%h/%h",
                            trial_id,row_count,raw_pre,d0_pre,wrapper_d0,wrapper_d1);
                    if(raw_pre[23:0]!==24'd0) begin
                        row_nonzero=row_nonzero+1;
                        seen_color=0;
                        for(i=0;i<distinct_count;i=i+1)
                            if(distinct_rgb[i]==raw_pre[23:0]) seen_color=1;
                        if(seen_color==0 && distinct_count<16) begin
                            distinct_rgb[distinct_count]=raw_pre[23:0];distinct_count=distinct_count+1;
                        end
                    end
                    row_count=row_count+1;
                end
                timeout=timeout+1;
            end
            if(row_count!=320 || row_nonzero<64 || distinct_count<4 ||
                ext_h!==9'd511 || native_h!==9'd345)
                $fatal(1,"reset bridge physical V5 row anchor/completion/variety failure trial=%0d samples=%0d nonzero=%0d distinct=%0d endpoint=%03x/%0d",
                    trial_id,row_count,row_nonzero,distinct_count,ext_h,native_h);
            if(capture_reference!=0) reset_bridge_reference_captures=row_count;
            else reset_bridge_completed_rows=reset_bridge_completed_rows+1;
                    $display("RESET_BRIDGE_ROW trial=%0d reference=%0d samples=%0d nonzero=%0d distinct=%0d first=%h last=%h nativeV-transition=5@H26..329/6@H330..345 exact=PASS",
                trial_id,capture_reference,row_count,row_nonzero,distinct_count,reset_bridge_ref[0],reset_bridge_ref[319]);
        end
    endtask

    task reset_bridge_trial(input integer phase_ns,input integer trial_id);
        integer t;
        reg found,phase_edge_cen;
        reg [15:0] readback0,readback1;
        begin
            // Choose a clean clock edge with valid tuple contents and low
            // generated pixel CEN. Reset is asserted phase_ns after this edge;
            // because CEN remains low through the next edge, reset clearing is
            // independent of the tuple capture enable.
            t=0;found=0;
            while(!found && t<262*400*8) begin
                @(posedge clk48); #1;
                if(wrapper_d0!==25'd0 && wrapper_d1!==25'd0 && raw_tuple1!==25'd0 && !pxl48) begin
                    found=1;
                    if(phase_ns<1 || phase_ns>16) $fatal(1,"invalid reset phase offset %0d ns",phase_ns);
                    case(phase_ns)
                        1: begin end
                        6: #5;
                        11: #10;
                        16: #15;
                        default: $fatal(1,"unsupported reset phase %0d",phase_ns);
                    endcase
                    if(wrapper_d0===25'd0 || wrapper_d1===25'd0 || raw_tuple1===25'd0 || pxl48)
                        $fatal(1,"reset bridge lost precondition at phase %0d ns",phase_ns);
                    rst=1;
                    $display("RESET_BRIDGE_ASSERT trial=%0d phase_ns=%0d time=%0t raw=%h d0=%h d1=%h CEN=%b",
                        trial_id,phase_ns,$time,raw_tuple1,wrapper_d0,wrapper_d1,pxl48);
                end else t=t+1;
            end
            if(!found) $fatal(1,"reset bridge could not arrange nonzero tuple/CEN-low phase %0d",phase_ns);
            @(posedge clk48); phase_edge_cen=pxl48; #1;
            if(phase_edge_cen!==0 || wrapper_d0!==25'd0 || wrapper_d1!==25'd0 || new_vdp.rst_n!==1'b0)
                $fatal(1,"reset bridge first edge failed phase=%0d CEN=%b tuple=%h/%h rst_n=%b",
                    phase_ns,phase_edge_cen,wrapper_d0,wrapper_d1,new_vdp.rst_n);
            @(posedge clk48); #1;
            reset_bridge_check_internal_state("warm reset");
            if(raw_tuple1!==25'd0) $fatal(1,"raw YM tuple not muted after reset assertion phase=%0d tuple=%h",phase_ns,raw_tuple1);
            repeat(64) begin
                @(posedge clk48); #1;
                if(new_vdp.rst_n!==1'b0 || new_vdp.u_vdp.passive_render_ready!==1'b0 ||
                    wrapper_d0!==25'd0 || wrapper_d1!==25'd0 || raw_tuple1!==25'd0)
                    $fatal(1,"reset hold invariant failed phase=%0d rst_n=%b ready=%b tuple=%h/%h raw=%h",
                        phase_ns,new_vdp.rst_n,new_vdp.u_vdp.passive_render_ready,wrapper_d0,wrapper_d1,raw_tuple1);
            end
            // Deassert at the same declared phase offset and verify the
            // registered rst_n transition after NBA on the following edge.
            @(posedge clk48);
            case(phase_ns)
                1: #1;
                6: #6;
                11: #11;
                16: #16;
                default: $fatal(1,"unsupported reset release phase %0d",phase_ns);
            endcase
            if(new_vdp.rst_n!==1'b0) $fatal(1,"reset released before registered MCLK edge phase=%0d",phase_ns);
            rst=0;
            @(posedge clk48); #1;
            if(new_vdp.rst_n!==1'b1) $fatal(1,"registered reset release missing phase=%0d rst_n=%b",phase_ns,new_vdp.rst_n);
            @(posedge clk48); #1;
            if(new_vdp.u_vdp.passive_render_ready!==1'b0 || raw_tuple1!==25'd0)
                $fatal(1,"reset bridge unexpectedly ready/unmuted before MMR programming phase=%0d ready=%b raw=%h",
                    phase_ns,new_vdp.u_vdp.passive_render_ready,raw_tuple1);
            $display("RESET_BRIDGE_RELEASE trial=%0d phase_ns=%0d time=%0t registered_rst_n=%b",
                trial_id,phase_ns,$time,new_vdp.rst_n);

            // First accepted post-reset MMR write leaves display off while
            // enabling Mode 5, then exercise CPU service before raster lock.
            if(new_vdp.u_vdp.passive_raster_locked!==1'b0)
                $fatal(1,"reset bridge expected unlocked tracker before first MMR write phase=%0d",phase_ns);
            write_new(16'h8105);
            t=0;
            while((new_vdp.u_vdp.reg_m5!==1 || new_vdp.u_vdp.reg_disp!==0) && t<1024) begin
                @(posedge clk48); t=t+1;
            end
            if(t==1024 || new_vdp.u_vdp.reg_m5!==1 || new_vdp.u_vdp.reg_disp!==0)
                $fatal(1,"post-reset R1=05 MMR decode failed phase=%0d M5/disp=%b/%b",phase_ns,
                    new_vdp.u_vdp.reg_m5,new_vdp.u_vdp.reg_disp);
            if(new_vdp.u_vdp.passive_render_ready!==1'b0 || raw_tuple1!==25'd0)
                $fatal(1,"display-off MMR write exposed stale pixels before raster lock phase=%0d",phase_ns);
            write_new(16'h8f02);
            write_new(16'h4000);write_new(16'h0000); // VRAM write address 0
            write_new_at(23'h600000,16'h1234);
            write_new_at(23'h600000,16'h5678);
            t=0;
            while({new_vdp.u_vram.mem[0],new_vdp.u_vram.mem[1],new_vdp.u_vram.mem[2],new_vdp.u_vram.mem[3]}!==
                {8'h34,8'h12,8'h78,8'h56} && t<100000) begin @(posedge clk48);t=t+1;end
            if({new_vdp.u_vram.mem[0],new_vdp.u_vram.mem[1],new_vdp.u_vram.mem[2],new_vdp.u_vram.mem[3]}!==
                {8'h34,8'h12,8'h78,8'h56})
                $fatal(1,"post-reset VRAM write retirement failed phase=%0d memory=%02x,%02x,%02x,%02x",
                    phase_ns,new_vdp.u_vram.mem[0],new_vdp.u_vram.mem[1],new_vdp.u_vram.mem[2],new_vdp.u_vram.mem[3]);
            write_new(16'h0000);write_new(16'h0000); // VRAM read address 0
            read_new_at(23'h600000,readback0);read_new_at(23'h600000,readback1);
            if(readback0!==16'h1234 || readback1!==16'h5678)
                $fatal(1,"post-reset VRAM readback failed phase=%0d words=%04x/%04x expected=1234/5678",
                    phase_ns,readback0,readback1);
            if(new_vdp.u_vdp.passive_render_ready!==1'b0 || raw_tuple1!==25'd0)
                $fatal(1,"CPU VRAM traffic exposed pixels before display/raster programming phase=%0d",phase_ns);
            if(new_vdp.u_vdp.passive_raster_locked!==1'b0)
                $fatal(1,"reset bridge CPU service unexpectedly waited through tracker lock phase=%0d",phase_ns);
            $display("RESET_BRIDGE_CPU trial=%0d phase_ns=%0d MMR=8105 ACKed VRAM=1234/5678 readback=%04x/%04x RETIRED after=%0d clk48",
                trial_id,phase_ns,readback0,readback1,t);

            // The normal fixture initializes physical bytes 0..3 as the
            // original zero tile. Restore them with that same documented
            // fixture-memory initializer after the CPU service probe.
            new_vdp.u_vram.mem[0]=0;new_vdp.u_vram.mem[1]=0;
            new_vdp.u_vram.mem[2]=0;new_vdp.u_vram.mem[3]=0;
            if({new_vdp.u_vram.mem[0],new_vdp.u_vram.mem[1],new_vdp.u_vram.mem[2],new_vdp.u_vram.mem[3]}!==32'd0)
                $fatal(1,"reset bridge failed to restore logical scratch bytes 0..3 to original tile-zero contents");
            $display("RESET_BRIDGE_ASSET_RESTORE trial=%0d physical_bytes_0_3=00000000 verified",trial_id);

            // Restore the proven table/window/palette bases and external
            // raster startup sequence before requiring full geometry lock.
            config_new();
            write_new(16'h8145);
            write_new(16'h8007);wait_one_s16_frame();
            write_new(16'h8cc1);wait_one_s16_frame();
            write_new(16'h8006);
            t=0;
            while((new_vdp.u_vdp.reg_m5!==1 || new_vdp.u_vdp.reg_disp!==1 ||
                new_vdp.u_vdp.reg_rs1!==1 || new_vdp.u_vdp.reg_rs0!==1 ||
                new_vdp.u_vdp.reg_data_l2[7:0]!==8'h06) && t<1024) begin @(posedge clk48);t=t+1;end
            if(t==1024) $fatal(1,"post-reset raster MMR restore failed phase=%0d",phase_ns);
            reset_bridge_check_assets();
            reset_bridge_row(0,trial_id);
            reset_bridge_trials=reset_bridge_trials+1;
            reset_events=reset_events+1;
            $display("RESET_BRIDGE_TRIAL trial=%0d phase_ns=%0d PASS",trial_id,phase_ns);
        end
    endtask

    initial begin
        repeat(40) @(posedge clk96);
        if($test$plusargs("RESET_BRIDGE")) begin
            // The simulation begins in cold reset. Observe the registered
            // active-low pin, then release 1 ns after a clk48 rising edge.
            @(posedge clk48); #1;
            if(new_vdp.rst_n!==1'b0 || wrapper_d0!==25'd0 || wrapper_d1!==25'd0)
                $fatal(1,"cold reset assertion did not reach wrapper/YM rst_n and tuple stages");
            reset_bridge_check_internal_state("cold reset");
            if(raw_tuple1!==25'd0) $fatal(1,"cold reset left raw YM output nonzero: %h",raw_tuple1);
            rst=0;
            $display("RESET_BRIDGE_COLD release_phase_ns=1 time=%0t registered_rst_n=%b",$time,new_vdp.rst_n);
            @(posedge clk48); #1;
            if(new_vdp.rst_n!==1'b1) $fatal(1,"cold reset release was not registered on clk48");
            @(posedge clk48); #1;
            if(new_vdp.u_vdp.passive_render_ready!==1'b0 || raw_tuple1!==25'd0)
                $fatal(1,"cold start became ready/unmuted before programming");
            cold_reset_checks=cold_reset_checks+1;
        end else rst=0;
        config_old(); config_new();
        $display("CONFIG old/en=%b M5=%b disp=%b rs=%b%b rdata=%h w217=%b; new/en=%b M5=%b disp=%b rs=%b%b rdata=%h w217=%b",
            en0,old_vdp.u_vdp.reg_m5,old_vdp.u_vdp.reg_disp,old_vdp.u_vdp.reg_rs1,old_vdp.u_vdp.reg_rs0,
            old_vdp.u_vdp.reg_data_l2,old_vdp.u_vdp.w217,
            en1,new_vdp.u_vdp.reg_m5,new_vdp.u_vdp.reg_disp,new_vdp.u_vdp.reg_rs1,new_vdp.u_vdp.reg_rs0,
            new_vdp.u_vdp.reg_data_l2,new_vdp.u_vdp.w217);
        // Duplicate the known varied-tile setup in each real attached VRAM and CRAM.
        // Copy the accepted fixture's address-swizzled physical VRAM image.
        // Its bytes are not contiguous in `vram.mem` after the 8/6/2-bit
        // address permutation; writing `4096+i` was an invalid approximation.
        begin : initialize_fixture
            integer i;
            reg [15:0] cpu_addr,phys,offset;
            for(i=0;i<65536;i=i+1) begin
                old_vdp.u_vram.mem[i]=0; new_vdp.u_vram.mem[i]=0;
            end
            for(i=0;i<40;i=i+1) begin
                old_vdp.u_vdp.vsram[i]=0; new_vdp.u_vdp.vsram[i]=0;
            end
            for(i=0;i<64;i=i+1) begin
                old_vdp.u_vdp.color_ram[i]=0; new_vdp.u_vdp.color_ram[i]=0;
            end
            for(i=0;i<32;i=i+1) begin
                cpu_addr=16'h0040+i[15:0]; phys=physical_addr(cpu_addr);
                case(i%8)
                  0: begin old_vdp.u_vram.mem[phys]=8'h02;new_vdp.u_vram.mem[phys]=8'h02;end
                  1: begin old_vdp.u_vram.mem[phys]=8'h34;new_vdp.u_vram.mem[phys]=8'h34;end
                  2: begin old_vdp.u_vram.mem[phys]=8'h56;new_vdp.u_vram.mem[phys]=8'h56;end
                  3: begin old_vdp.u_vram.mem[phys]=8'h70;new_vdp.u_vram.mem[phys]=8'h70;end
                  4: begin old_vdp.u_vram.mem[phys]=8'h07;new_vdp.u_vram.mem[phys]=8'h07;end
                  5: begin old_vdp.u_vram.mem[phys]=8'h65;new_vdp.u_vram.mem[phys]=8'h65;end
                  6: begin old_vdp.u_vram.mem[phys]=8'h43;new_vdp.u_vram.mem[phys]=8'h43;end
                  default: begin old_vdp.u_vram.mem[phys]=8'h20;new_vdp.u_vram.mem[phys]=8'h20;end
                endcase
            end
            // Fill the complete 64x32 name table footprint so both candidate
            // origins exercise valid tile rows through V=10, not just row0.
            offset=0;
            for(i=0;i<2048;i=i+1) begin
                cpu_addr=16'he000+offset; phys=physical_addr(cpu_addr);
                old_vdp.u_vram.mem[phys]=8'h02;new_vdp.u_vram.mem[phys]=8'h02;
                cpu_addr=cpu_addr+1'b1;phys=physical_addr(cpu_addr);
                old_vdp.u_vram.mem[phys]=8'h40;new_vdp.u_vram.mem[phys]=8'h40;
                offset=offset+16'd2;
            end
            if ({old_vdp.u_vram.mem[224],old_vdp.u_vram.mem[225],old_vdp.u_vram.mem[physical_addr(16'he080)],old_vdp.u_vram.mem[physical_addr(16'he081)],
                 old_vdp.u_vram.mem[physical_addr(16'he100)],old_vdp.u_vram.mem[physical_addr(16'he101)],old_vdp.u_vram.mem[4096],old_vdp.u_vram.mem[4097]}!==
                {8'h02,8'h40,8'h02,8'h40,8'h02,8'h40,8'h02,8'h34} ||
                {new_vdp.u_vram.mem[224],new_vdp.u_vram.mem[225],new_vdp.u_vram.mem[physical_addr(16'he080)],new_vdp.u_vram.mem[physical_addr(16'he081)],
                 new_vdp.u_vram.mem[physical_addr(16'he100)],new_vdp.u_vram.mem[physical_addr(16'he101)],new_vdp.u_vram.mem[4096],new_vdp.u_vram.mem[4097]}!==
                {8'h02,8'h40,8'h02,8'h40,8'h02,8'h40,8'h02,8'h34})
                $fatal(1,"address-swizzled VRAM fixture/table rows mismatch");
        end
        write_old(16'h8145);write_new(16'h8145);
        begin integer t;t=0;while(old_vdp.u_vdp.reg_disp!==1 && t<1024) begin @(posedge clk96);t=t+1;end
            if(t==1024 || old_vdp.u_vdp.reg_m5!==1 || old_vdp.u_vdp.reg_81_b0!==1) $fatal(1,"baseline R1 0x8145 not decoded before palette setup");end
        begin integer t;t=0;while(new_vdp.u_vdp.reg_disp!==1 && t<1024) begin @(posedge clk48);t=t+1;end
            if(t==1024 || new_vdp.u_vdp.reg_m5!==1 || new_vdp.u_vdp.reg_81_b0!==1) $fatal(1,"candidate R1 0x8145 not decoded before palette setup");end
        // Use the accepted fixture's CPU CRAM command and wait for its
        // delayed write before checking/replacing the remaining colors.
        write_old(16'hc042);write_old(16'h0000);write_old_at(23'h600000,16'h000e);
        write_new(16'hc042);write_new(16'h0000);write_new_at(23'h600000,16'h000e);
        begin integer timeout;timeout=0;
            while ((old_vdp.u_vdp.color_ram[6'h21]!==9'h007 || new_vdp.u_vdp.color_ram[6'h21]!==9'h007) && timeout<4096) begin
                @(posedge clk96);timeout=timeout+1;
            end
            if(old_vdp.u_vdp.color_ram[6'h21]!==9'h007 || new_vdp.u_vdp.color_ram[6'h21]!==9'h007)
                $fatal(1,"CRAM write not committed: baseline=%h candidate=%h",
                    old_vdp.u_vdp.color_ram[6'h21],new_vdp.u_vdp.color_ram[6'h21]);
        end
        // Match the proven varied-pixel fixture palette directly after its
        // CPU command-path setup, avoiding palette-write timing as a variable.
        old_vdp.u_vdp.color_ram[6'h21]=9'h007;new_vdp.u_vdp.color_ram[6'h21]=9'h007;
        old_vdp.u_vdp.color_ram[6'h22]=9'h038;new_vdp.u_vdp.color_ram[6'h22]=9'h038;
        old_vdp.u_vdp.color_ram[6'h23]=9'h1c0;new_vdp.u_vdp.color_ram[6'h23]=9'h1c0;
        old_vdp.u_vdp.color_ram[6'h24]=9'h1c7;new_vdp.u_vdp.color_ram[6'h24]=9'h1c7;
        old_vdp.u_vdp.color_ram[6'h25]=9'h0e0;new_vdp.u_vdp.color_ram[6'h25]=9'h0e0;
        old_vdp.u_vdp.color_ram[6'h26]=9'h00e;new_vdp.u_vdp.color_ram[6'h26]=9'h00e;
        old_vdp.u_vdp.color_ram[6'h27]=9'h070;new_vdp.u_vdp.color_ram[6'h27]=9'h070;
        old_vdp.u_vdp.color_ram[6'h28]=9'h1c8;new_vdp.u_vdp.color_ram[6'h28]=9'h1c8;
        $display("PALETTE initialized CRAM[21]=%03x/%03x VRAM name=%02x%02x pattern=%02x%02x",
            old_vdp.u_vdp.color_ram[6'h21],new_vdp.u_vdp.color_ram[6'h21],
            old_vdp.u_vram.mem[224],old_vdp.u_vram.mem[225],old_vdp.u_vram.mem[4096],old_vdp.u_vram.mem[4097]);
        // Reproduce astormj-ports.csv ordering: R1=45 is already active,
        // R0=07 spans two frame intervals with the R12=C1 change between,
        // then R0=06. This sequence is part of legacy sync phase acquisition.
        write_old(16'h8007);write_new(16'h8007);
        wait_one_s16_frame();
        write_old(16'h8cc1);write_new(16'h8cc1);
        begin integer t;t=0;while((old_vdp.u_vdp.reg_rs1!==1 || old_vdp.u_vdp.reg_rs0!==1 ||
            new_vdp.u_vdp.reg_rs1!==1 || new_vdp.u_vdp.reg_rs0!==1) && t<2048) begin @(posedge clk96);t=t+1;end
            if(t==2048) $fatal(1,"R12=C1 not decoded in both wrappers");end
        wait_one_s16_frame();
        write_old(16'h8006);write_new(16'h8006);
        begin integer t;t=0;while((old_vdp.u_vdp.reg_80_b0!==0 || new_vdp.u_vdp.reg_80_b0!==0) && t<1024) begin @(posedge clk96);t=t+1;end
            if(t==1024) $fatal(1,"R0=06 not decoded in both wrappers");end
        if(old_vdp.u_vdp.reg_data_l2[7:0]!==8'h06 || new_vdp.u_vdp.reg_data_l2[7:0]!==8'h06 ||
            old_vdp.u_vdp.reg_disp!==1 || new_vdp.u_vdp.reg_disp!==1 ||
            old_vdp.u_vdp.reg_m5!==1 || new_vdp.u_vdp.reg_m5!==1 ||
            old_vdp.u_vdp.reg_rs1!==1 || old_vdp.u_vdp.reg_rs0!==1 ||
            new_vdp.u_vdp.reg_rs1!==1 || new_vdp.u_vdp.reg_rs0!==1)
            $fatal(1,"final sync/config state mismatch old R0/R1/R12=%h/%b%b/%b%b new=%h/%b%b/%b%b",
                old_vdp.u_vdp.reg_data_l2[7:0],old_vdp.u_vdp.reg_m5,old_vdp.u_vdp.reg_disp,old_vdp.u_vdp.reg_rs1,old_vdp.u_vdp.reg_rs0,
                new_vdp.u_vdp.reg_data_l2[7:0],new_vdp.u_vdp.reg_m5,new_vdp.u_vdp.reg_disp,new_vdp.u_vdp.reg_rs1,new_vdp.u_vdp.reg_rs0);
        // Wait for the passive renderer's prefetched-ready boundary. Capture
        // the first six active lines of the following two visible frames.
        begin integer timeout; timeout=0;
            while(!new_vdp.u_vdp.passive_render_ready && timeout<2*262*400*16) begin
                @(posedge clk48); timeout=timeout+1;
            end
            if(!new_vdp.u_vdp.passive_render_ready) $fatal(1,"candidate renderer never became ready: supported=%b valid=%b locked=%b phaseerr=%b line=%0d active=%0d frame=%0d lines=%0d h/v=%0d/%0d",
                new_vdp.u_vdp.passive_geometry_supported,new_vdp.u_vdp.passive_raster_valid,
                new_vdp.u_vdp.passive_raster_locked,new_vdp.u_vdp.passive_raster_phase_error,
                new_vdp.u_vdp.passive_line_pixels,new_vdp.u_vdp.passive_active_pixels,
                new_vdp.u_vdp.passive_frame_lines,new_vdp.u_vdp.passive_active_lines,
                new_vdp.u_vdp.l106,new_vdp.u_vdp.l105);
            capture_start_frame=fr+1; capture_en=1;
            timeout=0;
            while((fr<capture_start_frame+1 || cap<12*320) && timeout<2*262*400*16) begin
                @(posedge clk48); timeout=timeout+1;
            end
            if(fr<capture_start_frame+1 || cap<12*320) $fatal(1,"bounded two-frame capture incomplete: frame=%0d start=%0d tuples=%0d",fr,capture_start_frame,cap);
        end
        capture_en=0;
        if(native_tuple_checks!=8 || native_seen[0]!==4'hf || native_seen[1]!==4'hf ||
            native_count[0]!=4 || native_count[1]!=4 || x6_expected_checks!=2)
            $fatal(1,"independent native/final coverage missing: total=%0d masks=%h/%h counts=%0d/%0d x6=%0d",
                native_tuple_checks,native_seen[0],native_seen[1],native_count[0],native_count[1],x6_expected_checks);

        // Verify normal invalidation propagation at the production output
        // boundary. Raw YM mute is immediate; wrapper output drains by its
        // second following generated pixel capture.
        write_new(16'h8105);
        begin integer t;t=0;while(new_vdp.u_vdp.reg_disp!==0 && t<1024) begin @(posedge clk48);t=t+1;end
            if(t==1024) $fatal(1,"display-off R1 state not decoded");end
        wait_raw_zero_and_wrapper_drain("display-off");
        write_new(16'h8145);
        begin integer t;t=0;while(!new_vdp.u_vdp.passive_render_ready && t<3*262*400*8) begin @(posedge clk48);t=t+1;end
            if(!new_vdp.u_vdp.passive_render_ready) $fatal(1,"renderer did not reacquire after display re-enable");end
        begin integer t;t=0;while(raw_tuple1===25'd0 && t<262*400*8) begin @(posedge clk48);t=t+1;end
            if(raw_tuple1===25'd0) $fatal(1,"raw tuple did not resume after display re-enable");end
        write_new(16'h8141);
        begin integer t;t=0;while(new_vdp.u_vdp.reg_m5!==0 && t<1024) begin @(posedge clk48);t=t+1;end
            if(t==1024) $fatal(1,"Mode5-clear R1 state not decoded");end
        wait_raw_zero_and_wrapper_drain("Mode5-clear");
        write_new(16'h8145);
        begin integer t;t=0;while(!new_vdp.u_vdp.passive_render_ready && t<3*262*400*8) begin @(posedge clk48);t=t+1;end
            if(!new_vdp.u_vdp.passive_render_ready) $fatal(1,"renderer did not reacquire after Mode5 re-enable");end
        begin integer t;t=0;while(raw_tuple1===25'd0 && t<262*400*8) begin @(posedge clk48);t=t+1;end
            if(raw_tuple1===25'd0) $fatal(1,"raw tuple did not resume after Mode5 re-enable");end
        geometry_fault=1;
        begin integer t;t=0;while(new_vdp.u_vdp.passive_raster_valid!==0 && t<2*262*400*8) begin @(posedge clk48);t=t+1;end
            if(new_vdp.u_vdp.passive_raster_valid!==0) $fatal(1,"raster tracker did not lose geometry after sync loss");end
        wait_raw_zero_and_wrapper_drain("geometry-loss");
        geometry_fault=0;
        begin integer t;t=0;while(!new_vdp.u_vdp.passive_render_ready && t<4*262*400*8) begin @(posedge clk48);t=t+1;end
            if(!new_vdp.u_vdp.passive_render_ready) $fatal(1,"renderer did not reacquire after geometry restoration");end
        begin integer t;t=0;while(raw_tuple1===25'd0 && t<262*400*8) begin @(posedge clk48);t=t+1;end
            if(raw_tuple1===25'd0) $fatal(1,"raw tuple did not resume after geometry restoration");end
        if($test$plusargs("RESET_BRIDGE")) begin
            reset_bridge_row(1,0);
            reset_bridge_trial(1,1);
            reset_bridge_trial(6,2);
            reset_bridge_trial(11,3);
            reset_bridge_trial(16,4);
            if(cold_reset_checks!=1 || reset_events!=4 || reset_bridge_trials!=4 ||
                reset_bridge_reference_captures!=320 || reset_bridge_completed_rows!=4)
                $fatal(1,"reset bridge matrix coverage cold=%0d resets=%0d trials=%0d ref=%0d rows=%0d",
                    cold_reset_checks,reset_events,reset_bridge_trials,
                    reset_bridge_reference_captures,reset_bridge_completed_rows);
        end else begin
            begin integer t;t=0;
                @(negedge clk48);
                while((wrapper_d0===25'd0 || wrapper_d1===25'd0 || pxl48) && t<262*400*8) begin @(negedge clk48);t=t+1;end
                if(wrapper_d0===25'd0 || wrapper_d1===25'd0 || pxl48)
                    $fatal(1,"could not arrange reset with nonzero tuple stages and pixel enable low d0/d1=%h/%h cen=%b",wrapper_d0,wrapper_d1,pxl48);
                rst=1;
                @(posedge clk48);
                if(pxl48) $fatal(1,"reset validation edge unexpectedly had pxl_48cen asserted");
                #1;
                if(wrapper_d0!==25'd0 || wrapper_d1!==25'd0 || new_vdp.rst_n!==1'b0)
                    $fatal(1,"synchronous reset did not clear nonzero tuple stages while pxl_48cen=0");
                reset_events=reset_events+1;
                @(negedge clk48);rst=0;
            end
        end
        $display("WRAPPER_PROPAGATION cold_reset_checks=%0d reset_events=%0d reset_bridge_trials=%0d native_tuple_checks=%0d x6_expected_checks=%0d display_off=2-events Mode5_clear=2-events geometry_loss=2-events reenable=renderer-ready",
            cold_reset_checks,reset_events,reset_bridge_trials,native_tuple_checks,x6_expected_checks);
        $fclose(f);
        $display("WRAPPER_PHASE_RESULT baseline_sha=3dc6b88e0204fd3abbb462b34f428757f8596e94 frames=%0d lines=%0d samples=%0d mixer_mismatches=%0d",fr,lines,cap,mis);
        $display("SAMPLE_ORACLE oldRGB=%0d newRGB=%0d oldYS=%0d newYS=%0d oldRuns=%0d newRuns=%0d oldBlank=%0d newBlank=%0d CEN-old=%0d new=%0d S16-only-mismatch=%0d final-visible=%0d final-nonblack old/wrapper/raw=%0d/%0d/%0d final-RGB-mismatch wrapper/raw=%0d/%0d",
            old_rgb_nonblack,new_rgb_nonblack,old_ys_on,new_ys_on,old_tuple_changes,new_tuple_changes,
            old_blank_active,new_blank_active,old_cen_sampled,new_cen_sampled,s16only_mismatches,
            final_visible_samples,old_final_nonblack,new_final_nonblack,raw_final_nonblack,
            wrapper_final_mismatch,raw_final_mismatch);
        $display("CEN_PHASE gated=%0d,%0d,%0d,%0d framework-frac=%0d,%0d,%0d,%0d delta-mod8=%0d/%0d/%0d/%0d",
            gated_tick[0],gated_tick[1],gated_tick[2],gated_tick[3],frac_tick[0],frac_tick[1],frac_tick[2],frac_tick[3],
            (gated_tick[0]-frac_tick[0]+8)%8,(gated_tick[1]-frac_tick[1]+8)%8,
            (gated_tick[2]-frac_tick[2]+8)%8,(gated_tick[3]-frac_tick[3]+8)%8);
        if(cap!=3840 || old_rgb_nonblack<1000 || new_rgb_nonblack<1000 ||
            old_tuple_changes<4 || new_tuple_changes<4 || old_ys_on==0 || new_ys_on==0 ||
            old_ys_off==0 || new_ys_off==0 || old_sel_changes<10 || new_sel_changes<10 ||
            old_blank_active==0 || new_blank_active==0 || s16only_mismatches!=0 ||
            final_visible_samples!=cap || old_final_nonblack<1000 || new_final_nonblack<1000 || raw_final_nonblack<1000 ||
            old_final_colors<4 || new_final_colors<4 || raw_final_colors<4)
            $fatal(1,"invalid varied-pixel/YS/priority/final-output oracle");
        if(gated_count<4 || frac_count<4 || gated_tick[1]-gated_tick[0]!=8 ||
            frac_tick[1]-frac_tick[0]!=8 || (gated_tick[0]-frac_tick[0]+8)%8!=7 ||
            (gated_tick[1]-frac_tick[1]+8)%8!=7)
            $fatal(1,"unexpected generated gated/frac enable phase: gated=%0d,%0d frac=%0d,%0d",
                gated_tick[0],gated_tick[1],frac_tick[0],frac_tick[1]);
        if(boundary_edge==0) $fatal(1,"boundary observation window empty");
        $fclose(fo);$fclose(fb);
        $finish;
    end
    initial begin
        if($test$plusargs("RESET_BRIDGE")) begin
            // Keep the established 200 ms common-fixture cap, add the one
            // pre-warm reference's two-frame row cap, then add four warm
            // cases' maxima: two sync waits, the four-frame re-prime cap,
            // and the two-frame row cap.
            // 21 ns is a conservative integer upper bound for one clk48 period.
            #(200000000 + (262*400*16 + 4*(2*262*400*8 + 2*262*400*16 + 262*400*16))*21);
            $fatal(1,"wrapper reset bridge matrix timeout");
        end else begin
            #200000000; $fatal(1,"wrapper phase timeout");
        end
    end
endmodule

// Independent test-side replay of the production mixer equations for the
// fixed vdp_prio=010 fixture. It consumes only source tuples, S16 flags/colors,
// and framework pixel enables; it does not observe DUT selection or RGB.
// With both layers enabled, next_sel = YS && (nblnk || priority_sel); if S16
// is disabled the production override selects VDP regardless of YS, and if
// VDP is disabled it forces S16. This fixture keeps both layers enabled.
module jts18_mix_oracle(
    input clk, pxl, LHBL, LVBL,
    input sa, sb, fix, s1_pri, s2_pri, obj, obj16,
    input [5:0] sr, sg, sb6,
    input ys,
    input [7:0] vr, vg, vb,
        output reg sel_o=0, sel=0,
    output reg [23:0] pr=0, mix_rgb=0, final_rgb=0,
    output [1:0] blank_bits,
    output [5:0] blank_stages,
    output reg [23:0] cross_rgb=0,
    output reg [1:0] final_blank=0
);
    reg [4:0] tilemap=0;
    reg nblnk=0;
    reg i3=0,i4=0,i5=0,i8=0,i9=0;
    reg [2:0] blh=0,blv=0;
    reg [1:0] blank_out=0;
    reg cross_l=0;
    wire [7:0] exr={sr,sr[5:4]}, exg={sg,sg[5:4]}, exb={sb6,sb6[5:4]};
    wire pri2=i3 && i4 && ((!1'b0 && !1'b0) || i8 || i9); // obj_prio=00, p=010
    wire pri_sel=pri2;
    wire [1:0] predly={blh[2],blv[2]};
    assign blank_bits=blank_out;
    assign blank_stages={blh,blv};

    always @(posedge clk) begin
        tilemap <= {sa,sb,fix,s1_pri,s2_pri};
        nblnk <= {obj16,sa,sb,fix}==0;
        i3 <= !tilemap[2];
        i4 <= !tilemap[4];
        i5 <= obj && tilemap[1];
        i8 <= tilemap[1] && tilemap[0];
        i9 <= !tilemap[3] && tilemap[0];
        sel_o <= pri_sel;
        sel <= sel_o;
        if(nblnk) sel<=1;
        if(!ys) sel<=0;
        pr <= sel ? {vr,vg,vb} : {exr,exg,exb};
        if(pxl) begin
            blh <= {blh[1:0],LHBL};
            blv <= {blv[1:0],LVBL};
            blank_out <= predly;
            mix_rgb <= predly==2'b11 ? pr : 24'd0;
            cross_rgb <= mix_rgb;
            final_blank <= {LHBL,LVBL};
            final_rgb <= (LHBL && LVBL) ? cross_rgb : 24'd0;
        end else begin
            cross_rgb <= mix_rgb;
        end
    end
endmodule
