`timescale 1ns/1ps

`ifndef CREDITS_PAGES
`define CREDITS_PAGES 3
`endif

module test;

localparam integer PAGES = `CREDITS_PAGES;
localparam integer RGB_LATENCY = 4;

reg clk=0;
always #5 clk=~clk;

reg rst=1;
reg pxl_cen=1;
reg HB=1, VB=1, HS=1, VS=1;
reg [11:0] rgb_in=0;
reg [7:0] vram_din=0;
reg [9:0] vram_addr=0;
reg vram_we=0;
reg enable=1, toggle=0;
reg [2:0] vram_ctrl=0;
reg fast_scroll=0;
reg [1:0] rotate=0;
wire HB_out, VB_out, HS_out, VS_out;
wire [11:0] rgb_out;
wire [7:0] vram_dout;

jtframe_credits #(.PAGES(PAGES),.SPEED(15)) uut(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen),
    .HB(HB), .VB(VB), .HS(HS), .VS(VS), .rgb_in(rgb_in),
    .vram_din(vram_din), .vram_addr(vram_addr), .vram_we(vram_we), .vram_dout(vram_dout),
    .enable(enable), .toggle(toggle), .vram_ctrl(vram_ctrl), .fast_scroll(fast_scroll), .rotate(rotate),
    .HB_out(HB_out), .VB_out(VB_out), .HS_out(HS_out), .VS_out(VS_out), .rgb_out(rgb_out)
);

integer fails=0;
integer bad_samples=0;
integer slow_pixels=0;
integer toggle_enable_in_gap=0;
integer dim_sideband_check=0;
reg [3:0] sync_hist [0:4];
reg [11:0] rgb_hist [0:3];
integer hist_i;

function [11:0] palette;
    input integer index;
    begin
        case(index & 3)
            0: palette=12'hf00;
            1: palette=12'h0f0;
            2: palette=12'h33f;
            default: palette=12'hfff;
        endcase
    end
endfunction

function [11:0] rgb_pattern;
    input integer index;
    reg [3:0] green, blue;
    begin
        green=index[3:0];
        blue=(index ^ 8'h5a) & 4'hf;
        rgb_pattern={4'hf,green,blue};
    end
endfunction

function integer glyph_bit;
    input integer sx, sy;
    integer row, pattern, charcode;
    begin
        row=sy & 7;
        charcode=(sy/256)+1;
        pattern=(8'h81 ^ (8'h11 << ((row+charcode) & 3)) ^ (charcode*8'h13)) & 8'hff;
        glyph_bit=(pattern >> (7-(sx & 7))) & 1;
    end
endfunction

// Pixel oracle uses physical destination coordinates and the documented
// floor(dest*256/extent) mapping. It does not inspect renderer counters or RAM
// addresses. RGB is compared after the renderer's four-cycle character path.
function [11:0] expected_pixel;
    input integer dx, dy, width_px, height_px;
    input [1:0] rot;
    input integer scroll;
    integer sx, sy, extent, page, row, col, pal;
    begin
        expected_pixel=12'h000;
        if(dx<0 || dy<0 || dx>=width_px || dy>=height_px) begin
            expected_pixel=12'h000;
        end else begin
            if(rot==0) begin
                if(width_px>=256) begin
                    sx=dx-((width_px-256)/2);
                    sy=scroll+dy;
                end else begin
                    sx=(dx*256)/width_px;
                    sy=scroll+dy;
                end
            end else begin
                extent=height_px<256 ? height_px : 256;
                if(rot==2'b01) sx=255-(dy*256)/extent;
                else sx=(dy*256)/extent;
                if(rot==2'b01) sy=scroll+dx;
                else sy=PAGES*256-1-(scroll+dx);
            end
            if(sx>=0 && sx<256 && sy>=0 && sy<PAGES*256) begin
                if(glyph_bit(sx,sy)) begin
                    page=sy/256;
                    row=(sy/8)&31;
                    col=(sx/8)&31;
                    pal=(page+3*col+5*row)&3;
                    expected_pixel=palette(pal);
                end
            end
        end
    end
endfunction

task check_sample;
    input integer x, y, width_px, height_px;
    input [1:0] rot;
    input integer scroll;
    reg [11:0] wanted;
    begin
        if(x>=RGB_LATENCY) begin
            wanted=expected_pixel(x-RGB_LATENCY,y,width_px,height_px,rot,scroll);
            if(rgb_out!==wanted && bad_samples<24) begin
                $display("FAIL rgb pages=%0d mode=%b w=%0d h=%0d x=%0d y=%0d srcx=%0d srcy=%0d got=%03x exp=%03x",
                    PAGES,rot,width_px,height_px,x,y,x-RGB_LATENCY,y,rgb_out,wanted);
                fails=fails+1;
                bad_samples=bad_samples+1;
            end else if(rgb_out!==wanted) begin
                fails=fails+1;
            end
        end
    end
endtask

task run_frame;
    input integer width_px, height_px;
    input [1:0] rot;
    input integer check_rgb;
    input integer scroll;
    integer x,y,gap_i;
    reg [3:0] old_sync;
    reg [15:0] held_rgb;
    reg [3:0] held_sync;
    begin
        rotate=rot;
        for(y=0;y<height_px+2;y=y+1) begin
            for(x=0;x<width_px+8;x=x+1) begin
                @(negedge clk);
                HB=(x>=width_px);
                VB=(y>=height_px);
                HS=(x>=width_px+3);
                VS=(y>=height_px+1);
                old_sync={HB,VB,HS,VS};
                if(slow_pixels) begin
                    held_rgb=rgb_out;
                    held_sync={HB_out,VB_out,HS_out,VS_out};
                    pxl_cen=0;
                    for(gap_i=0;gap_i<2;gap_i=gap_i+1) begin
                        if(toggle_enable_in_gap) enable=(gap_i!=0);
                        @(posedge clk); #1;
                        if(rgb_out!==held_rgb || {HB_out,VB_out,HS_out,VS_out}!==held_sync) begin
                            $display("FAIL outputs changed while pxl_cen=0 x=%0d y=%0d",x,y);
                            fails=fails+1;
                        end
                        @(negedge clk);
                    end
                    pxl_cen=1;
                end
                @(posedge clk); #1;
                if({HB_out,VB_out,HS_out,VS_out}!==sync_hist[3]) begin
                    if(fails<8) $display("FAIL sync latency=%0d x=%0d y=%0d got=%04b exp=%04b",
                        RGB_LATENCY,x,y,{HB_out,VB_out,HS_out,VS_out},sync_hist[3]);
                    fails=fails+1;
                end
                for(hist_i=4;hist_i>0;hist_i=hist_i-1) sync_hist[hist_i]=sync_hist[hist_i-1];
                sync_hist[0]=old_sync;
                if(check_rgb && y<height_px && x>=RGB_LATENCY)
                    check_sample(x,y,width_px,height_px,rot,scroll);
                if(dim_sideband_check && x==((width_px-256)/2)+1+RGB_LATENCY && (y==127 || y==128)) begin
                    if(y==127 && rgb_out!==12'hf0f) begin
                        $display("FAIL VRAM row7 sideband clear got=%03x exp=f0f",rgb_out);
                        fails=fails+1;
                    end
                    if(y==128 && rgb_out!==12'h707) begin
                        $display("FAIL VRAM row7 sideband set got=%03x exp=707",rgb_out);
                        fails=fails+1;
                    end
                end
            end
        end
    end
endtask

task reset_dut;
    begin
        @(negedge clk); rst=1; enable=1; pxl_cen=1; rotate=0; fast_scroll=0;
        repeat(4) @(posedge clk);
        @(negedge clk); rst=0;
        for(hist_i=0;hist_i<5;hist_i=hist_i+1) sync_hist[hist_i]=4'b0000;
        sync_hist[0]={HB,VB,HS,VS};
    end
endtask

task check_geometry;
    input integer width_px, height_px;
    input [1:0] rot;
    begin
        reset_dut();
        run_frame(width_px,height_px,rot,0,0);
        run_frame(width_px,height_px,rot,0,0);
        run_frame(width_px,height_px,rot,1,0);
    end
endtask

task advance_scroll;
    input integer steps;
    integer s;
    begin
        @(negedge clk); fast_scroll=1;
        for(s=0;s<steps;s=s+1) begin
            @(negedge clk); HB=0; VB=0;
            @(posedge clk); #1;
            for(hist_i=4;hist_i>0;hist_i=hist_i-1) sync_hist[hist_i]=sync_hist[hist_i-1];
            sync_hist[0]={HB,VB,HS,VS};
            @(negedge clk); HB=1; VB=0;
            @(posedge clk); #1;
            for(hist_i=4;hist_i>0;hist_i=hist_i-1) sync_hist[hist_i]=sync_hist[hist_i-1];
            sync_hist[0]={HB,VB,HS,VS};
            @(negedge clk); HB=0; VB=1;
            @(posedge clk); #1;
            for(hist_i=4;hist_i>0;hist_i=hist_i-1) sync_hist[hist_i]=sync_hist[hist_i-1];
            sync_hist[0]={HB,VB,HS,VS};
        end
        @(negedge clk); fast_scroll=0; HB=1; VB=1;
        @(posedge clk); #1;
        for(hist_i=4;hist_i>0;hist_i=hist_i-1) sync_hist[hist_i]=sync_hist[hist_i-1];
        sync_hist[0]={HB,VB,HS,VS};
    end
endtask

task check_scrolled_frame;
    input integer width_px, height_px, scroll;
    begin
        run_frame(width_px,height_px,2'b00,0,scroll);
        run_frame(width_px,height_px,2'b00,0,scroll);
        run_frame(width_px,height_px,2'b00,1,scroll);
    end
endtask

task check_vbfall_at_hb_rise;
    integer x;
    reg [3:0] sampled_sync;
    begin
        reset_dut();
        run_frame(384,224,2'b00,0,0);
        run_frame(384,224,2'b00,0,0);
        // The active-low VB edge occurs on the same sampled pixel as the
        // active-high HB edge, as it can at jtframe_vtimer's H_VB position.
        for(x=0;x<392;x=x+1) begin
            @(negedge clk);
            HB=(x>=384); VB=(x<384); HS=(x>=387); VS=1;
            sampled_sync={HB,VB,HS,VS};
            @(posedge clk); #1;
            if({HB_out,VB_out,HS_out,VS_out}!==sync_hist[3]) begin
                $display("FAIL coincident HB/VB sync edge x=%0d got=%04b exp=%04b",
                    x,{HB_out,VB_out,HS_out,VS_out},sync_hist[3]);
                fails=fails+1;
            end
            for(hist_i=4;hist_i>0;hist_i=hist_i-1) sync_hist[hist_i]=sync_hist[hist_i-1];
            sync_hist[0]=sampled_sync;
        end
        // The next active line must begin at source row zero after the
        // coincident boundary reset, including the first and last glyph pixel.
        for(x=0;x<392;x=x+1) begin
            @(negedge clk);
            HB=(x>=384); VB=0; HS=(x>=387); VS=1;
            sampled_sync={HB,VB,HS,VS};
            @(posedge clk); #1;
            if({HB_out,VB_out,HS_out,VS_out}!==sync_hist[3]) begin
                $display("FAIL first-row sync x=%0d got=%04b exp=%04b",
                    x,{HB_out,VB_out,HS_out,VS_out},sync_hist[3]);
                fails=fails+1;
            end
            for(hist_i=4;hist_i>0;hist_i=hist_i-1) sync_hist[hist_i]=sync_hist[hist_i-1];
            sync_hist[0]=sampled_sync;
            if(x>=RGB_LATENCY && x<384+RGB_LATENCY)
                check_sample(x,0,384,224,2'b00,0);
        end
    end
endtask

task restart_scroll_with_enable;
    integer t;
    reg [15:0] held_rgb;
    reg [3:0] held_sync;
    begin
        // Sample enable low on one pixel, then raise it during the next
        // disabled pixel interval. The first following sample restarts scroll.
        @(negedge clk); pxl_cen=1; enable=0; HB=1; VB=1; HS=1; VS=1;
        @(posedge clk); #1;
        for(hist_i=4;hist_i>0;hist_i=hist_i-1) sync_hist[hist_i]=sync_hist[hist_i-1];
        sync_hist[0]={HB,VB,HS,VS};
        @(negedge clk); pxl_cen=0; enable=1;
        held_rgb=rgb_out; held_sync={HB_out,VB_out,HS_out,VS_out};
        repeat(2) begin
            @(posedge clk); #1;
            if(rgb_out!==held_rgb || {HB_out,VB_out,HS_out,VS_out}!==held_sync) begin
                $display("FAIL restart gap changed output while pxl_cen=0");
                fails=fails+1;
            end
            @(negedge clk);
        end
        pxl_cen=1;
        repeat(8) begin
            @(posedge clk); #1;
            for(hist_i=4;hist_i>0;hist_i=hist_i-1) sync_hist[hist_i]=sync_hist[hist_i-1];
            sync_hist[0]={HB,VB,HS,VS};
            @(negedge clk);
        end
    end
endtask

task check_disabled_passthrough;
    integer i;
    reg [3:0] sampled_sync;
    reg [15:0] held_rgb;
    reg [3:0] held_sync;
    begin
        reset_dut();
        enable=0; vram_ctrl=0;
        for(hist_i=0;hist_i<4;hist_i=hist_i+1) rgb_hist[hist_i]=0;
        for(i=0;i<48;i=i+1) begin
            @(negedge clk);
            pxl_cen=1; enable=0; rgb_in=rgb_pattern(i);
            HB=(i>=32); VB=(i>=40); HS=(i>=35); VS=(i>=44);
            sampled_sync={HB,VB,HS,VS};
            @(posedge clk); #1;
            if(i>=4 && rgb_out!==rgb_hist[3]) begin
                $display("FAIL disabled passthrough tick=%0d got=%03x exp=%03x",i,rgb_out,rgb_hist[3]);
                fails=fails+1;
            end
            if({HB_out,VB_out,HS_out,VS_out}!==sync_hist[3]) begin
                $display("FAIL disabled sync tick=%0d got=%04b exp=%04b",
                    i,{HB_out,VB_out,HS_out,VS_out},sync_hist[3]);
                fails=fails+1;
            end
            for(hist_i=3;hist_i>0;hist_i=hist_i-1) rgb_hist[hist_i]=rgb_hist[hist_i-1];
            rgb_hist[0]=rgb_in;
            for(hist_i=4;hist_i>0;hist_i=hist_i-1) sync_hist[hist_i]=sync_hist[hist_i-1];
            sync_hist[0]=sampled_sync;
            held_rgb=rgb_out; held_sync={HB_out,VB_out,HS_out,VS_out};
            @(negedge clk); pxl_cen=0; rgb_in=12'habc; HB=~HB; VB=~VB; HS=~HS; VS=~VS;
            repeat(2) begin
                @(posedge clk); #1;
                if(rgb_out!==held_rgb || {HB_out,VB_out,HS_out,VS_out}!==held_sync) begin
                    $display("FAIL disabled output changed with pxl_cen low tick=%0d",i);
                    fails=fails+1;
                end
                @(negedge clk);
            end
        end
        pxl_cen=1;
    end
endtask

initial begin
    for(hist_i=0;hist_i<5;hist_i=hist_i+1) sync_hist[hist_i]=4'b0000;
    repeat(5) @(posedge clk);
    @(negedge clk); rst=0;
    // The first free-running clock after reset samples the initial high sync
    // inputs before the first explicitly driven pixel.
    sync_hist[0]=4'b1111;

    // Horizontal widths exercise centered borders, exact 256-pixel coverage,
    // and the 240-to-256 nearest-neighbor expansion.
    check_geometry(384,224,2'b00);
    check_geometry(320,224,2'b00);
    check_geometry(256,224,2'b00);
    check_geometry(240,224,2'b00);
    check_geometry(512,400,2'b00);

    // Both vertical orientations at both supported physical heights.
    check_geometry(320,224,2'b01);
    check_geometry(320,240,2'b01);
    check_geometry(320,224,2'b11);
    check_geometry(320,240,2'b11);
    check_vbfall_at_hb_rise();

    // Hold the pixel clock enable low for two master clocks between pixels.
    // The renderer and its four-tick RGB/sync pipelines must pause together.
    reset_dut();
    run_frame(320,224,2'b00,0,0);
    run_frame(320,224,2'b00,0,0);
    slow_pixels=1;
    run_frame(320,224,2'b00,1,0);
    slow_pixels=0;

    if(PAGES>1) begin
        // Check the page-0/page-1 seam, the last visible scroll coordinate,
        // the fully blank endpoint, and the automatic cycle back to page 0.
        reset_dut();
        run_frame(384,224,2'b00,0,0);
        run_frame(384,224,2'b00,0,0);
        advance_scroll(255);
        slow_pixels=1; toggle_enable_in_gap=1;
        check_scrolled_frame(384,224,255);
        slow_pixels=0; toggle_enable_in_gap=0;
        restart_scroll_with_enable();
        check_scrolled_frame(384,224,0);
        advance_scroll(PAGES*256-1);
        check_scrolled_frame(384,224,PAGES*256-1);
        advance_scroll(1);
        check_scrolled_frame(384,224,PAGES*256);
        advance_scroll(1);
        check_scrolled_frame(384,224,0);
    end

    // CPU port zero can program and synchronously read page zero.
    @(negedge clk); vram_addr=0; vram_din=8'h55; vram_we=1;
    @(posedge clk); #1;
    @(negedge clk); vram_we=0;
    repeat(2) @(posedge clk);
    #1;
    if(vram_dout!==8'h55) begin
        $display("FAIL page0 VRAM write/read got=%02x exp=55",vram_dout);
        fails=fails+1;
    end

    // vram_ctrl[2] dims only text rows with transformed sourceY[7] set.
    reset_dut();
    enable=1; vram_ctrl=3'b101; rgb_in=12'hf0f;
    run_frame(384,224,2'b00,0,0);
    run_frame(384,224,2'b00,0,0);
    dim_sideband_check=1;
    run_frame(384,224,2'b00,0,0);
    dim_sideband_check=0; vram_ctrl=0;
    check_disabled_passthrough();

    if(fails==0) $display("PASS credits pixel oracle pages=%0d",PAGES);
    else $display("FAIL credits pixel oracle pages=%0d checks=%0d",PAGES,fails);
    $finish;
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
end

endmodule
