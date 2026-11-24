// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps

// Independent RAM/ROM responders for each renderer: requests may be prefetched,
// but each pixel, FIX control and late-fetch report must match the frozen RTL.
module tilemap_memory #(parameter SEED=0)(
    input clk, rst,
    input [9:0] ram_addr,
    output reg [7:0] vram, cram,
    input [11:0] rom_addr,
    input rom_cs,
    input [7:0] latency,
    output reg [31:0] rom_data,
    output reg rom_ok
);
reg active;
reg [11:0] addr;
reg [7:0] wait_count;
function [31:0] graphics;
    input [11:0] a;
    reg [31:0] x;
    begin
        x={a,a[7:0],a} ^ (32'h93a75c1e + SEED);
        x=x ^ (x<<13); x=x ^ (x>>17); x=x ^ (x<<5);
        graphics=x;
    end
endfunction
always @(posedge clk) begin
    // Exercise all code/bank, palette, per-tile H/V flip combinations.
    vram <= ram_addr[7:0] ^ {ram_addr[4:0],ram_addr[9:7]} ^ (8'h35 + SEED);
    cram <= {ram_addr[3],ram_addr[0],ram_addr[5],1'b0,ram_addr[9:6]};
    if(rst || !rom_cs) begin
        rom_ok <= 0;
        active <= 0;
        wait_count <= 0;
    end else if(!active || addr!=rom_addr) begin
        active <= 1;
        addr <= rom_addr;
        wait_count <= latency;
        rom_ok <= latency==0;
        rom_data <= graphics(rom_addr);
    end else if(wait_count!=0) begin
        wait_count <= wait_count-1'b1;
        rom_ok <= wait_count==1;
    end
end
endmodule

module test;
reg clk=0, rst=1, flip=0, orig=0, checking=0;
always #5 clk=~clk;
reg [3:0] div=0;
integer pixel_period=4;
wire pxl_cen=div==pixel_period-1;
reg [8:0] h=0,v=0;
reg [7:0] sx=0,sy=0,latency=0;
reg [7:0] prog_data=0,prog_addr=0;
reg prog_en=0;
always @(posedge clk) begin
    div <= pxl_cen ? 4'd0 : div+1'b1;
    if(!rst && pxl_cen) begin
        h <= h==383 ? 9'd0 : h+1'b1;
        // Match jtmzone_video's H_VNEXT and VCNT_END behavior.
        if(h==319) v <= v==263 ? 9'd0 : v+1'b1;
    end
end
wire [9:0] fa,fr_a,sa,sr_a;
wire [7:0] fv,fc,fr_v,fr_c,sv,sc,sr_v,sr_c;
wire [11:0] f_addr,fr_addr,s_addr,sr_addr;
wire f_cs,fr_cs,s_cs,sr_cs,f_ok,fr_ok,s_ok,sr_ok;
wire [31:0] f_data,fr_data,s_data,sr_data;
wire [3:0] f_pxl,fr_pxl,s_pxl,sr_pxl;
wire f_src,fr_src,f_en,fr_en;
`ifdef MZONE_FETCH_DIAG
wire s_late,sr_late;
`endif

tilemap_memory #(.SEED(1)) fm(clk,rst,fa,fv,fc,f_addr,f_cs,latency,f_data,f_ok);
tilemap_memory #(.SEED(1)) frm(clk,rst,fr_a,fr_v,fr_c,fr_addr,fr_cs,latency,fr_data,fr_ok);
tilemap_memory #(.SEED(2)) sm(clk,rst,sa,sv,sc,s_addr,s_cs,latency,s_data,s_ok);
tilemap_memory #(.SEED(2)) srm(clk,rst,sr_a,sr_v,sr_c,sr_addr,sr_cs,latency,sr_data,sr_ok);

jtmzone_fix fix_dut(
 .rst(rst),.clk(clk),.pxl_cen(pxl_cen),.ram_addr(fa),.vram(fv),.cram(fc),
 .hdump(h),.vdump(v),.flip(flip),.dip_orig_hactive(orig),
 .prog_data(prog_data[3:0]),.prog_addr(prog_addr),.prog_en(prog_en),
 .rom_addr(f_addr),.rom_cs(f_cs),.rom_data(f_data),.rom_ok(f_ok),
 .pxl(f_pxl),.fix_src(f_src),.fix_en(f_en));
jtmzone_fix_reference fix_ref(
 .rst(rst),.clk(clk),.pxl_cen(pxl_cen),.ram_addr(fr_a),.vram(fr_v),.cram(fr_c),
 .hdump(h),.vdump(v),.flip(flip),.dip_orig_hactive(orig),
 .prog_data(prog_data[3:0]),.prog_addr(prog_addr),.prog_en(prog_en),
 .rom_addr(fr_addr),.rom_cs(fr_cs),.rom_data(fr_data),.rom_ok(fr_ok),
 .pxl(fr_pxl),.fix_src(fr_src),.fix_en(fr_en));
jtmzone_scroll scroll_dut(
 .rst(rst),.clk(clk),.pxl_cen(pxl_cen),.ram_addr(sa),.vram(sv),.cram(sc),
 .HS(h>=320 && h<352),.hdump(h),.vdump(v),.scrollx(sx),.scrolly(sy),.flip(flip),
 .prog_data(prog_data[3:0]),.prog_addr(prog_addr),.prog_en(prog_en),
 .rom_addr(s_addr),.rom_cs(s_cs),.rom_data(s_data),.rom_ok(s_ok),.pxl(s_pxl)
`ifdef MZONE_FETCH_DIAG
 ,.fetch_late(s_late)
`endif
);
jtmzone_scroll_reference scroll_ref(
 .rst(rst),.clk(clk),.pxl_cen(pxl_cen),.ram_addr(sr_a),.vram(sr_v),.cram(sr_c),
 .hdump(h),.vdump(v),.scrollx(sx),.scrolly(sy),.flip(flip),
 .prog_data(prog_data[3:0]),.prog_addr(prog_addr),.prog_en(prog_en),
 .rom_addr(sr_addr),.rom_cs(sr_cs),.rom_data(sr_data),.rom_ok(sr_ok),.pxl(sr_pxl)
`ifdef MZONE_FETCH_DIAG
 ,.fetch_late(sr_late)
`endif
);
// Compare the observable RGB path, including real mixer/blanking latency.
// Internal request phases intentionally follow the native helper now.
wire pre_lh = h<288 && !(orig && !flip && h==287);
wire pre_lv = v>=16 && v<240;
// Exercise the delayed FIX-priority and source-window tails.
wire [3:0] object_pixel = h==53 ? 4'h7 : h==293 ? 4'h9 : 4'd0;
wire [7:0] color_data = (prog_addr*8'd37)^8'h93;
wire [11:0] rgb,rgb_ref;
wire lh,lv,lh_ref,lv_ref;
jtmzone_colmix mix_dut(
 .rst(rst),.clk(clk),.pxl_cen(pxl_cen),.scr_pxl(s_pxl),.fix_pxl(f_pxl),
 .obj_pxl(object_pixel),.gfx_en(4'hf),.fix_src(f_src),.fix_prio(f_en),
 .preLHBL(pre_lh),.preLVBL(pre_lv),.prog_data(color_data),
 .prog_addr({14'd0,prog_addr}),.prom_we(prog_en && prog_addr<32),
 .red(rgb[11:8]),.green(rgb[7:4]),.blue(rgb[3:0]),.LHBL(lh),.LVBL(lv),.preLBL());
jtmzone_colmix mix_ref(
 .rst(rst),.clk(clk),.pxl_cen(pxl_cen),.scr_pxl(sr_pxl),.fix_pxl(fr_pxl),
 .obj_pxl(object_pixel),.gfx_en(4'hf),.fix_src(fr_src),.fix_prio(fr_en),
 .preLHBL(pre_lh),.preLVBL(pre_lv),.prog_data(color_data),
 .prog_addr({14'd0,prog_addr}),.prom_we(prog_en && prog_addr<32),
 .red(rgb_ref[11:8]),.green(rgb_ref[7:4]),.blue(rgb_ref[3:0]),
 .LHBL(lh_ref),.LVBL(lv_ref),.preLBL());
reg fix_missed=0,scroll_missed=0;
always @(posedge clk) begin
    if(rst) begin fix_missed<=0;scroll_missed<=0;end
    else if(pxl_cen) begin
        if(fix_dut.u_tilemap.zero) fix_missed<=!f_ok;
        if(scroll_dut.u_scroll.u_tilemap.zero) scroll_missed<=!s_ok;
    end
end
integer scenario=0,compared=0,display_compared=0,zero_checks=0,nonblack_checks=0;
always @(negedge clk) if(checking) begin
    compared=compared+1;
    if(^{rgb,rgb_ref,f_src,fr_src,f_en,fr_en,lh,lv,lh_ref,lv_ref} === 1'bx)
        $fatal(1,"unknown renderer output case=%0d h=%0d v=%0d",scenario,h,v);
    if({f_src,f_en,lh,lv} !== {fr_src,fr_en,lh_ref,lv_ref})
        $fatal(1,"FIX controls/blanking mismatch case=%0d h=%0d v=%0d",scenario,h,v);
    // Only timely responses have the same contract as the frozen controller.
    // Delayed words use native zero-fill, not the old retained-word fallback.
    if(latency<=8) begin
        display_compared=display_compared+1;
        if(rgb!=0) nonblack_checks=nonblack_checks+1;
        if(rgb !== rgb_ref)
            $fatal(1,"RGB mismatch case=%0d h=%0d v=%0d flip=%b orig=%b sx=%h sy=%h latency=%0d got=%h ref=%h",scenario,h,v,flip,orig,sx,sy,latency,rgb,rgb_ref);
    end
    if(fix_missed) begin
        zero_checks=zero_checks+1;
        if(fix_dut.raw_pxl[3:0] !== 0)
            $fatal(1,"FIX missed deadline did not zero-fill case=%0d",scenario);
    end
    if(scroll_missed) begin
        zero_checks=zero_checks+1;
        if(scroll_dut.raw_pxl[3:0] !== 0)
            $fatal(1,"SCROLL missed deadline did not zero-fill case=%0d",scenario);
    end
`ifdef MZONE_FETCH_DIAG
    if(s_late !== (!rst && pxl_cen && scroll_dut.u_scroll.u_tilemap.zero && !s_ok))
        $fatal(1,"native deadline diagnostic mismatch case=%0d",scenario);
`endif
end
integer i,period_case,flip_case,width_case,scroll_case,delay_case,vertical_case;
initial begin
    // Nonidentity PROM catches bit-plane order and palette alignment errors.
    for(i=0;i<256;i=i+1) begin
        @(negedge clk);prog_en=1;prog_addr=i;prog_data=(i[7:4]^i[3:0])+4'd3;
    end
    @(negedge clk);prog_en=0;
    for(period_case=0;period_case<2;period_case=period_case+1)
    for(flip_case=0;flip_case<2;flip_case=flip_case+1)
    for(width_case=0;width_case<2;width_case=width_case+1)
    for(scroll_case=0;scroll_case<4;scroll_case=scroll_case+1)
    for(delay_case=0;delay_case<4;delay_case=delay_case+1)
    for(vertical_case=0;vertical_case<4;vertical_case=vertical_case+1) begin
        @(negedge clk);checking=0;rst=1;
        pixel_period=period_case==0 ? 4 : 8;
        flip=flip_case;orig=width_case;
        case(scroll_case)
            0: begin sx=0;sy=0;end
            1: begin sx=7;sy=1;end
            2: begin sx=8'h81;sy=8'h7f;end
            3: begin sx=8'hff;sy=8'hff;end
        endcase
        case(delay_case)
            0: latency=0;
            1: latency=8;
            2: latency=24;
            3: latency=55;
        endcase
        repeat(16) @(negedge clk);
        h=0;
        case(vertical_case)
            0: v=14;
            1: v=238;
            2: v=254;
            3: v=262;
        endcase
        rst=0;
        // Warm up one line, then compare every master-clock result for 3 lines,
        // including blanking, using the real output mixer on both renderers.
        repeat(384*pixel_period) @(negedge clk);
        checking=1;
        repeat(3*384*pixel_period) @(negedge clk);
        checking=0;
        scenario=scenario+1;
        if(scenario%16==0) begin
            $display("Checked %0d/512 renderer scenarios",scenario);
            $fflush();
        end
    end
    if(display_compared==0 || zero_checks==0 || nonblack_checks==0) $fatal(1,"missing test coverage");
    $display("PASS native tile helpers: %0d scenarios, %0d control checks, %0d RGB comparisons, %0d zero-fill checks",scenario,compared,display_compared,zero_checks);
    $finish;
end
initial begin
    #1000000000;
    $fatal(1,"equivalence test timeout");
end
endmodule
