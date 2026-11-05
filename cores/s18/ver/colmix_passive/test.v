`timescale 1ns/1ps

module test;

reg clk=0;
always #5 clk=~clk;

integer cycle=0;
wire pxl_cen  = cycle[2:0]==3'd7;
wire pxl2_cen = cycle[1:0]==2'd3;
reg rst=1;
wire LHBL, LVBL, HS, VS;
wire LHBL_game, LVBL_game;
wire [8:0] hdump, vdump, vrender;
reg vid16_en=1, vdp_en=1;
reg [2:0] vdp_prio=3'b111;
reg vdp_ys_src=0;
reg manual_ys=0;
reg obj16=0, sa=0, sb=0, fix=0, s1_pri=0, s2_pri=0;
reg [1:0] obj_prio=0;
reg [3:0] gfx_en=0;
reg [5:0] s16_r=6'h15, s16_g=6'h0d, s16_b=6'h2b;
reg pattern_mode=0;
reg [8:0] pixel_id=0;
wire [7:0] vdp_r_src = pattern_mode ? 8'hd3 : 8'h52;
wire [7:0] vdp_g_src = pattern_mode ? 8'h5a : 8'h20 | pixel_id[8];
wire [7:0] vdp_b_src = pattern_mode ? 8'he7 : 8'h80 | pixel_id[7:0];
wire [24:0] vdp_tuple_src = {vdp_ys_src,vdp_r_src,vdp_g_src,vdp_b_src};
reg [24:0] tuple_d0=0, tuple_d1=0, tuple_d2=0;
wire LHBL_dly_raw, LVBL_dly_raw, LHBL_dly_comp, LVBL_dly_comp;
wire [7:0] raw_r, raw_g, raw_b, comp_r, comp_g, comp_b;
wire [7:0] st_raw, st_comp;
wire LHBL_out_raw, LVBL_out_raw, LHBL_out_comp, LVBL_out_comp;
wire [7:0] out_raw_r, out_raw_g, out_raw_b;
wire [7:0] out_comp_r, out_comp_g, out_comp_b;
reg LHBL_l=0, line_started=0;
reg capture_line=0, capture_done=0;
reg blank_after_checked=0;
integer line_origin=-1;
integer active_count_raw=0, active_count_comp=0;
integer first_edge_raw=-1, last_edge_raw=-1;
integer first_edge_comp=-1, last_edge_comp=-1;
integer active_count_out_raw=0, active_count_out_comp=0;
integer first_edge_out=-1, last_edge_out=-1;
integer errors=0;
integer sample_edge;
integer expected_id;
reg [23:0] expected_rgb;

jtframe_vtimer #(
    .HB_START   ( 9'h1ff ),
    .HB_END     ( 9'h0bf ),
    .HCNT_START ( 9'h070 ),
    .HCNT_END   ( 9'h1ff ),
    .VB_START   ( 9'h0df  ),
    .VB_END     ( 9'h105  ),
    .VCNT_END   ( 9'h105  ),
    .VS_START   ( 9'hef   ),
    .VS_END     ( 9'h0f3  ),
    .HS_START   ( 9'h080  ),
    .HS_END     ( 9'h0a0  )
) u_s16_timer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   (           ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        )
);

jtframe_short_blank #(.WIDTH(320),.HEIGHT(224)) u_game_blank(
    .clk        ( clk        ),
    .pxl_cen    ( pxl_cen    ),
    .LHBL       ( LHBL       ),
    .LVBL       ( LVBL       ),
    .h_en       ( 1'b0       ),
    .v_en       ( 1'b0       ),
    .h_wide     ( 1'b0       ),
    .v_wide     ( 1'b0       ),
    .HS         ( HS         ),
    .hb_out     ( LHBL_game  ),
    .vb_out     ( LVBL_game  )
);

always @(posedge clk) if (pxl_cen) begin
    tuple_d0 <= vdp_tuple_src;
    tuple_d1 <= tuple_d0;
    tuple_d2 <= tuple_d1;
end

jts18_colmix uut_raw(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .pxl_cen    ( pxl_cen      ),
    .pxl2_cen   ( pxl2_cen     ),
    .LHBL       ( LHBL         ),
    .LVBL       ( LVBL         ),
    .LHBL_dly   ( LHBL_dly_raw ),
    .LVBL_dly   ( LVBL_dly_raw ),
    .vid16_en   ( vid16_en     ),
    .obj16      ( obj16        ),
    .sa         ( sa           ),
    .sb         ( sb           ),
    .fix        ( fix          ),
    .s1_pri     ( s1_pri       ),
    .s2_pri     ( s2_pri       ),
    .obj_prio   ( obj_prio     ),
    .vdp_en     ( vdp_en       ),
    .vdp_prio   ( vdp_prio     ),
    .vdp_ysn    ( vdp_ys_src   ),
    .gfx_en     ( gfx_en       ),
    .s16_r      ( s16_r        ),
    .s16_g      ( s16_g        ),
    .s16_b      ( s16_b        ),
    .vdp_r      ( vdp_r_src    ),
    .vdp_g      ( vdp_g_src    ),
    .vdp_b      ( vdp_b_src    ),
    .red        ( raw_r        ),
    .green      ( raw_g        ),
    .blue       ( raw_b        ),
    .debug_bus  ( 8'd0         ),
    .st_show    ( st_raw       ),
    .joystick1  ( 2'b00        )
);

jts18_colmix uut_comp(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .pxl_cen    ( pxl_cen      ),
    .pxl2_cen   ( pxl2_cen     ),
    .LHBL       ( LHBL         ),
    .LVBL       ( LVBL         ),
    .LHBL_dly   ( LHBL_dly_comp),
    .LVBL_dly   ( LVBL_dly_comp),
    .vid16_en   ( vid16_en     ),
    .obj16      ( obj16        ),
    .sa         ( sa           ),
    .sb         ( sb           ),
    .fix        ( fix          ),
    .s1_pri     ( s1_pri       ),
    .s2_pri     ( s2_pri       ),
    .obj_prio   ( obj_prio     ),
    .vdp_en     ( vdp_en       ),
    .vdp_prio   ( vdp_prio     ),
    .vdp_ysn    ( tuple_d2[24] ),
    .gfx_en     ( gfx_en       ),
    .s16_r      ( s16_r        ),
    .s16_g      ( s16_g        ),
    .s16_b      ( s16_b        ),
    .vdp_r      ( tuple_d2[23:16]),
    .vdp_g      ( tuple_d2[15: 8]),
    .vdp_b      ( tuple_d2[ 7: 0]),
    .red        ( comp_r       ),
    .green      ( comp_g       ),
    .blue       ( comp_b       ),
    .debug_bus  ( 8'd0         ),
    .st_show    ( st_comp      ),
    .joystick1  ( 2'b00        )
);

jtframe_crosshair #(.COLORW(8)) u_output_raw(
    .rst          ( rst           ),
    .clk          ( clk           ),
    .pxl_cen      ( pxl_cen       ),
    .flip         ( 1'b0          ),
    .draw_en      ( 1'b0          ),
    .cross_disable( 2'b00         ),
    .pre_lvbl     ( LVBL_game     ),
    .pre_lhbl     ( LHBL_game     ),
    .pre_hs       ( HS            ),
    .pre_vs       ( VS            ),
    .lvbl         ( LVBL_out_raw  ),
    .lhbl         ( LHBL_out_raw  ),
    .hs           (              ),
    .vs           (              ),
    .gun_1p_x     ( 9'd0          ),
    .gun_1p_y     ( 9'd0          ),
    .gun_2p_x     ( 9'd0          ),
    .gun_2p_y     ( 9'd0          ),
    .rin          ( raw_r         ),
    .gin          ( raw_g         ),
    .bin          ( raw_b         ),
    .rout         ( out_raw_r     ),
    .gout         ( out_raw_g     ),
    .bout         ( out_raw_b     )
);

jtframe_crosshair #(.COLORW(8)) u_output_comp(
    .rst          ( rst           ),
    .clk          ( clk           ),
    .pxl_cen      ( pxl_cen       ),
    .flip         ( 1'b0          ),
    .draw_en      ( 1'b0          ),
    .cross_disable( 2'b00         ),
    .pre_lvbl     ( LVBL_game     ),
    .pre_lhbl     ( LHBL_game     ),
    .pre_hs       ( HS            ),
    .pre_vs       ( VS            ),
    .lvbl         ( LVBL_out_comp ),
    .lhbl         ( LHBL_out_comp ),
    .hs           (              ),
    .vs           (              ),
    .gun_1p_x     ( 9'd0          ),
    .gun_1p_y     ( 9'd0          ),
    .gun_2p_x     ( 9'd0          ),
    .gun_2p_y     ( 9'd0          ),
    .rin          ( comp_r        ),
    .gin          ( comp_g        ),
    .bin          ( comp_b        ),
    .rout         ( out_comp_r    ),
    .gout         ( out_comp_g    ),
    .bout         ( out_comp_b    )
);

function [23:0] id_rgb;
    input [8:0] id;
    begin
        id_rgb = {8'h52,8'h20|id[8],8'h80|id[7:0]};
    end
endfunction

always @(posedge clk) begin
    sample_edge = cycle;

    // The timer's blanking outputs update by NBA on the H=191/511 pixel edge.
    // The passive YM source tuple is modeled from H26 publish at the helper's
    // following clk48 edge, then advances once per native H event.
    if (LHBL && !LHBL_l) begin
        line_started=1;
        pixel_id <= 0;
        if (!manual_ys) vdp_ys_src <= 0;
        if (LVBL && !capture_done) begin
            capture_line = 1;
            line_origin = cycle;
        end
    end else if (pxl_cen && line_started) begin
        pixel_id <= pixel_id+1'b1;
        if (!manual_ys) vdp_ys_src <= ~pixel_id[0];
    end
    LHBL_l <= LHBL;

    if (pxl_cen) begin
        #1;
        if (capture_line && LHBL_dly_raw && LVBL_dly_raw) begin
            if (first_edge_raw<0) first_edge_raw=sample_edge;
            last_edge_raw=sample_edge;
            expected_id=(sample_edge-line_origin-1)/8;
            if (expected_id<0 || expected_id>322 ||
                {raw_r,raw_g,raw_b} !== (expected_id[0] ? id_rgb(expected_id[8:0]) : 24'h5534ae)) begin
                $display("FAIL raw edge%0d origin%0d id%0d RGB=%06x",sample_edge,line_origin,
                    expected_id,{raw_r,raw_g,raw_b});
                errors=errors+1;
            end
            active_count_raw=active_count_raw+1;
        end
        if (capture_line && LHBL_dly_comp && LVBL_dly_comp) begin
            if (first_edge_comp<0) first_edge_comp=sample_edge;
            last_edge_comp=sample_edge;
            expected_id=(sample_edge-line_origin-31)/8;
            if (expected_id<0 || expected_id>319 ||
                {comp_r,comp_g,comp_b} !== (expected_id[0] ? id_rgb(expected_id[8:0]) : 24'h5534ae)) begin
                $display("FAIL comp edge%0d origin%0d id%0d RGB=%06x",sample_edge,line_origin,
                    expected_id,{comp_r,comp_g,comp_b});
                errors=errors+1;
            end
            active_count_comp=active_count_comp+1;
        end
        if (capture_line && LHBL_out_raw && LVBL_out_raw) begin
            if (first_edge_out<0) first_edge_out=sample_edge;
            last_edge_out=sample_edge;
            expected_id=(sample_edge-line_origin-7)/8;
            if (expected_id<0 || expected_id>319) begin
                $display("FAIL: exposed raw blank index%0d at edge%0d",expected_id,sample_edge);
                errors=errors+1;
            end else begin
                if (expected_id<4) expected_rgb=24'h000000;
                else begin
                    expected_id=expected_id-1;
                    expected_rgb=expected_id[0] ? id_rgb(expected_id[8:0]) : 24'h5534ae;
                end
                if ({out_raw_r,out_raw_g,out_raw_b} !== expected_rgb) begin
                    $display("FAIL exposed raw x%0d edge%0d RGB=%06x expected=%06x",
                        (sample_edge-line_origin-7)/8,{out_raw_r,out_raw_g,out_raw_b},expected_rgb);
                    errors=errors+1;
                end
            end
            active_count_out_raw=active_count_out_raw+1;
        end
        if (capture_line && LHBL_out_comp && LVBL_out_comp) begin
            expected_id=(sample_edge-line_origin-7)/8;
            if (expected_id<0 || expected_id>319) begin
                $display("FAIL: exposed comp blank index%0d at edge%0d",expected_id,sample_edge);
                errors=errors+1;
            end else begin
                if (expected_id<4) expected_rgb=24'h000000;
                else begin
                    expected_id=expected_id-4;
                    expected_rgb=expected_id[0] ? id_rgb(expected_id[8:0]) : 24'h5534ae;
                end
                if ({out_comp_r,out_comp_g,out_comp_b} !== expected_rgb) begin
                    $display("FAIL exposed comp x%0d edge%0d RGB=%06x expected=%06x",
                        (sample_edge-line_origin-7)/8,{out_comp_r,out_comp_g,out_comp_b},expected_rgb);
                    errors=errors+1;
                end
            end
            active_count_out_comp=active_count_out_comp+1;
        end
        if (LHBL_out_raw!==LHBL_out_comp || LVBL_out_raw!==LVBL_out_comp) begin
            $display("FAIL exposed blank mismatch raw=%b%b comp=%b%b at%0d",
                LHBL_out_raw,LVBL_out_raw,LHBL_out_comp,LVBL_out_comp,sample_edge);
            errors=errors+1;
        end
        if (LHBL_dly_raw!==LHBL_dly_comp || LVBL_dly_raw!==LVBL_dly_comp) begin
            $display("FAIL delayed blank mismatch raw=%b%b comp=%b%b at%0d",
                LHBL_dly_raw,LVBL_dly_raw,LHBL_dly_comp,LVBL_dly_comp,sample_edge);
            errors=errors+1;
        end
        if (capture_done && !blank_after_checked && sample_edge==last_edge_comp+8) begin
            if (LHBL_dly_comp!==1'b0 || {comp_r,comp_g,comp_b}!==24'h000000) begin
                $display("FAIL: delayed blank after final pixel at edge%0d LHBL=%b RGB=%06x",
                    sample_edge,LHBL_dly_comp,{comp_r,comp_g,comp_b});
                errors=errors+1;
            end else begin
                $display("CHECK: delayed blank suppresses output after final pixel at edge%0d",sample_edge);
            end
            blank_after_checked=1;
        end
        if (active_count_raw==320 && active_count_comp==320) begin
            capture_done=1;
            capture_line=0;
        end
    end
    cycle <= cycle+1;
end

task next_pixel;
    begin
        @(posedge clk);
        while (!pxl_cen) @(posedge clk);
        #2;
    end
endtask

task check_comp_rgb;
    input [23:0] expected;
    input [8*48-1:0] label;
    begin
        next_pixel;
        if (!LHBL_dly_comp || !LVBL_dly_comp || {comp_r,comp_g,comp_b} !== expected) begin
            $display("FAIL: %0s at edge%0d blank=%b%b RGB=%06x expected=%06x",
                label,cycle-1,LHBL_dly_comp,LVBL_dly_comp,{comp_r,comp_g,comp_b},expected);
            errors=errors+1;
        end else begin
            $display("CHECK: %0s RGB=%06x",label,{comp_r,comp_g,comp_b});
        end
        next_pixel;
        if (!LHBL_out_comp || !LVBL_out_comp || {out_comp_r,out_comp_g,out_comp_b} !== expected) begin
            $display("FAIL: %0s final output blank=%b%b RGB=%06x expected=%06x",
                label,LHBL_out_comp,LVBL_out_comp,{out_comp_r,out_comp_g,out_comp_b},expected);
            errors=errors+1;
        end else begin
            $display("CHECK: %0s final output RGB=%06x",label,{out_comp_r,out_comp_g,out_comp_b});
        end
    end
endtask

initial begin
    repeat (20) @(posedge clk);
    #1 rst=0;

    wait (active_count_raw==320 && active_count_comp==320);
    #2;
    if (first_edge_raw!=line_origin+31 || last_edge_raw!=line_origin+2583 ||
        first_edge_comp!=line_origin+31 || last_edge_comp!=line_origin+2583 ||
        active_count_raw!=320 || active_count_comp!=320 ||
        first_edge_out!=line_origin+7 || last_edge_out!=line_origin+2559 ||
        active_count_out_raw!=320 || active_count_out_comp!=320) begin
        $display("FAIL: origin%0d raw[%0d..%0d/%0d] comp[%0d..%0d/%0d]",
            line_origin,first_edge_raw,last_edge_raw,active_count_raw,
            first_edge_comp,last_edge_comp,active_count_comp);
        $display("FAIL: exposed[%0d..%0d raw%0d comp%0d] expected origin+7..+2559 count320",
            first_edge_out,last_edge_out,active_count_out_raw,active_count_out_comp);
        errors=errors+1;
    end else begin
        $display("CHECK: internal window %0d..%0d; exposed output blank %0d..%0d count320",
            first_edge_comp,last_edge_comp,first_edge_out,last_edge_out);
        $display("CHECK: raw internal IDs3..322; compensated IDs0..319; exposed comp x0..3 black then IDs0..315");
    end

    // Test steady selected/transparent behavior on the following real timer line.
    @(negedge clk) begin
        pattern_mode=1;
        manual_ys=1;
        vdp_ys_src=1;
    end
    wait (LHBL_dly_comp && LVBL_dly_comp && cycle>line_origin+3200+40);
    check_comp_rgb(24'hd35ae7,"empty S16 layers select VDP");

    // With both sources enabled, delayed YS low makes the VDP pixel transparent.
    @(negedge clk) vdp_ys_src=0;
    repeat (40) @(posedge clk);
    check_comp_rgb(24'h5534ae,"YS low selects S16 RGB");

    // A priority request selects VDP even with S16 content present.
    @(negedge clk) begin
        vdp_ys_src=1;
        obj16=1;
        vdp_prio=3'b111;
    end
    repeat (40) @(posedge clk);
    check_comp_rgb(24'hd35ae7,"priority selects VDP over S16 content");

    // The mixer intentionally gives VDP priority when S16 is disabled,
    // even if YS is low; this locks down the override order.
    @(negedge clk) begin
        vid16_en=0;
        vdp_ys_src=0;
        vdp_prio=3'b000;
    end
    repeat (40) @(posedge clk);
    check_comp_rgb(24'hd35ae7,"disabled S16 overrides YS transparency");

    @(negedge clk) begin
        vid16_en=1;
        vdp_en=0;
        vdp_ys_src=1;
    end
    repeat (40) @(posedge clk);
    check_comp_rgb(24'h5534ae,"disabled VDP selects S16 RGB");

    if (errors!=0) begin
        $fatal(1,"FAIL: %0d mixer checks failed",errors);
    end
    $display("PASS");
    $finish;
end

initial begin
    $dumpfile("colmix_passive.lxt");
    $dumpvars;
end

endmodule
