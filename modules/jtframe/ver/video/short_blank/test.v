module test;

wire      rst, clk, pxl_cen, lhbl, lvbl;
`include "test_tasks.vh"

localparam HEIGHT = 240, WIDTH=280, CLIP=8;

reg    v_en,h_en, wd, h_rise, v_rise, start, sign=0;
wire   lhbs, lvbs, hs, hs_edge, vs;
string hstring, vstring;

integer hcnt=0, vcnt=0, framecnt, hclip, vclip;

always @(posedge clk) begin
    if(rst) {hcnt, vcnt, h_rise, v_rise} <= 0;
    else begin
        if(pxl_cen) begin
            hcnt <= 0;
            if(lhbl != lhbs) hcnt <= hcnt + 1;
        end
        if(hs_edge) begin
            vcnt <= 0;
            if(lvbl != lvbs) vcnt <= vcnt + 1;
        end

        if( hs ) h_rise <= 1;
        if(lhbs) h_rise <= 0;
        if( vs ) v_rise <= 1;
        if(lvbs) v_rise <= 0;
    end
end

always @(posedge clk) if(pxl_cen && start) check_line();
always @(posedge clk) if(hs_edge && start) check_vertical();

initial begin
    start=0;
    crop_disabled();
    crop_8_pxl();
    new_frame(); // 0

    start=1;

    new_frame(); // 1
    crop_16_pxl();

    new_frame(); // 2
    enable_v_crop();
    crop_8_pxl();

    new_frame(); // 3
    crop_16_pxl();

    new_frame(); // 4
    enable_h_crop();
    disable_v_crop();
    crop_8_pxl();

    new_frame(); // 5
    crop_16_pxl();


    new_frame(); // 6
    enable_v_crop();
    crop_8_pxl();

    new_frame(); // 7
    crop_16_pxl();

    new_frame(); // 8
    crop_disabled();
    crop_8_pxl();

    new_frame(); // 9
    start = 0;
    pass();
end

task crop_disabled();
    disable_h_crop();
    disable_v_crop();
endtask

task disable_v_crop();
    v_en = 0;
endtask

task disable_h_crop();
    h_en = 0;
endtask

task enable_v_crop();
    v_en = 1;
endtask

task enable_h_crop();
    h_en = 1;
endtask

task crop_8_pxl();
    wd = 0;
    set_new_clip();
endtask

task crop_16_pxl();
    wd = 1;
    set_new_clip();
endtask

task new_frame();
    wait(vs==1) @(posedge clk);
    wait(vs==0) @(posedge clk);
endtask

task set_new_clip();
    @(posedge clk);
    hclip = h_en ? CLIP << wd : 0;
    vclip = v_en ? CLIP << wd : 0;
endtask

task check_line();
    if(lhbl==0)
        assert_msg(lhbs==0, "lhbs should not be up when lhbl is low");
    else if(lhbs==0) begin
        if(h_rise==1) begin @(posedge lhbs);
            hstring = $sformatf("left horizontal clip (%1d) is not as expected (%1d)",hcnt,hclip);
            assert_msg(hcnt==hclip, hstring); end
        if(h_rise==0) begin @(negedge lhbl);
            hstring = $sformatf("right horizontal clip (%1d) is not as expected (%1d)",hcnt,hclip);
            assert_msg(hcnt==hclip, hstring); end
    end else
        assert_msg(lhbs==1, "lhbs shoudl be up");
endtask

task check_vertical();
    if(lvbl==0)
        assert_msg(lvbs==0, "lhbs should not be up when lhbl is low");
    else if(lvbs==0) begin
        if(v_rise==1) begin @(posedge lvbs);
            vstring = $sformatf("upper vertical clip (%1d) is not as expected (%1d)",vcnt,vclip);
            assert_msg(vcnt==vclip, vstring); end
        if(v_rise==0) begin @(negedge lvbl);
            vstring = $sformatf("down vertical clip (%1d) is not as expected (%1d)",vcnt,vclip);
            assert_msg(vcnt==vclip, vstring); end
    end else
        assert_msg(lvbs==1, "lhbs shoudl be up");
endtask

jtframe_test_clocks #(.MAXFRAMES(9), .TIMEOUT(200_000_000)) clocks(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .vs         ( vs        ),
    .framecnt   ( framecnt  )
);

jtframe_edge cnt_pulse(
    .rst   ( rst     ),
    .clk   ( clk     ),
    .edgeof( hs      ),
    .clr   ( hs_edge ),
    .q     ( hs_edge )
);

jtframe_short_blank #(
    .WIDTH (WIDTH),
    .HEIGHT(HEIGHT)
) u_short_blank(
    .clk        ( clk     ),
    .pxl_cen    ( pxl_cen ),
    .LHBL       ( lhbl    ),
    .LVBL       ( lvbl    ),
    .h_en       ( h_en    ),
    .v_en       ( v_en    ),
    .wide       ( wd      ),
    .HS         ( hs      ),
    .hb_out     ( lhbs    ),
    .vb_out     ( lvbs    )
);

endmodule