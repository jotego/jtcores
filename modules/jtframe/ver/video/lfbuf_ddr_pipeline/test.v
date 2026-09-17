`timescale 1ns/1ps
module test;
`include "test_tasks.vh"
`ifdef TEST_WIDE
localparam HW=10, VW=9;
`else
localparam HW=9, VW=8;
`endif
localparam LINE_W=1<<HW;
reg clk=0, rst=1;
reg [2:0] divider=0;
reg [8:0] h=0;
reg [VW-1:0] v=0;
wire [HW-1:0] hdump = {{HW-9{1'b0}}, h};
wire pxl_cen = divider==0;
wire lhbl = h>=32 && h<392;
wire hs = h>=420 && h<452;
wire lvbl = v>=6 && v<12;
wire vs = v>=2 && v<4;
reg [8:0] h_step=9'h100, v_step=9'h100;
reg ln_done=0, ln_we=0;
reg [HW-1:0] ln_addr=0;
reg [15:0] ln_data=0;
wire ln_hs, ln_vs, ln_lvbl;
wire [VW-1:0] ln_v;
wire [15:0] ln_pxl, ln_dout;
wire [28:0] addr;
wire [63:0] din, dout;
wire [7:0] burstcnt, be;
wire rd, we, ready, model_busy;
reg stall=0;
wire busy = model_busy || stall;
wire memory_clk = clk && !stall;
integer requests=0, completed=0, acknowledgements=0, writes=0;
integer draw_x=-1, draw_id=0;
reg draw_blank=0;
reg [VW-1:0] draw_v=0;
reg draw_bank=0;
integer q_in=0, q_out=0, write_x=0;
integer q_id[0:1023];
reg [VW-1:0] q_v[0:1023];
reg q_bank[0:1023];
integer frame_swaps=0, vs_count=0, blank_lines=0, overlaps=0;
reg frame_l=0, vs_l=0, ln_vs_l=0;
integer render_syncs=0;
reg [8:0] held_dh, held_dv;
reg hold_renderer=0;
reg held_bank;
integer before_vs, before_swaps;
integer sparse_writes=0;
integer frame_lines=0, expected_lines=6;

always #5 clk=~clk;
initial begin
    $dumpfile("test.lxt");
    $dumpvars(0, uut, clk, rst, stall, hold_renderer);
    repeat(2_000_000) @(posedge clk);
    $display("FAIL: timeout"); fail();
end
always @(posedge clk) begin
    if(rst) begin divider<=0; h<=0; v<=0; end
    else begin
        divider<=divider+1'd1;
        if(pxl_cen) begin
            h<=h+1'd1;
            if(h==511) v<=v==17 ? 0 : v+1'd1;
        end
    end
end

jtframe_lfbuf_ddr #(.HW(HW),.VW(VW)) uut(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen),
    .vrender(v), .hdump(hdump), .hs(hs), .vs(vs), .lhbl(lhbl), .lvbl(lvbl),
    .h_step(h_step), .v_step(v_step),
    .ln_addr(ln_addr), .ln_data(ln_data), .ln_done(ln_done), .ln_we(ln_we),
    .fb_keep(1'b0), .ln_hs(ln_hs), .ln_vs(ln_vs), .ln_lvbl(ln_lvbl),
    .ln_dout(ln_dout), .ln_pxl(ln_pxl), .ln_v(ln_v),
    .ddram_clk(), .ddram_busy(busy), .ddram_burstcnt(burstcnt),
    .ddram_addr(addr), .ddram_dout(dout), .ddram_dout_ready(ready),
    .ddram_rd(rd), .ddram_din(din), .ddram_be(be), .ddram_we(we),
    .st_addr(8'd0), .st_dout()
);
jtframe_ddr_model u_memory(
    .clk(memory_clk), .busy(model_busy), .burstcnt(burstcnt), .addr(addr),
    .dout(dout), .dout_ready(ready), .rd(rd), .din(din), .be(be), .we(we)
);
function [15:0] pattern(input integer id, input integer x);
    pattern=(id<<HW) | x;
endfunction
function [15:0] expected(input integer id, input integer x);
    expected=(id>4 && x%2==1) ? 16'd0 : pattern(id,x);
endfunction

// Producer follows only the public request/completion handshake. Blank lines
// deliberately write pixels too: they must be discarded and cleared.
always @(negedge clk) begin
    ln_we=0;
    ln_done=0;
    if(!rst) begin
        if(ln_hs) begin
            assert_msg(draw_x==-1, "new request interrupted the renderer");
            assert_msg(requests==acknowledgements, "new request before prior acknowledgement");
            requests=requests+1;
            draw_id=requests;
            draw_v=ln_v;
            draw_bank=uut.frame;
            draw_blank=uut.fb_blank;
            draw_x=0;
        end
        if(draw_x>=0 && !hold_renderer) begin
            if(draw_x==LINE_W) begin
                ln_done=1;
                completed=completed+1;
                if(draw_blank) blank_lines=blank_lines+1;
                else begin
                    frame_lines=frame_lines+1;
                    q_id[q_in]=draw_id;
                    q_v[q_in]=draw_v;
                    q_bank[q_in]=draw_bank;
                    q_in=q_in+1;
                end
                draw_x=-1;
            end else begin
                ln_addr=draw_x;
                ln_data=pattern(draw_id, draw_x);
                ln_we=draw_blank || draw_id<=4 || draw_x%2==0;
                draw_x=draw_x+1;
            end
        end
    end
end

always @(posedge clk) if(!rst) begin
    if(vs && !vs_l) vs_count=vs_count+1;
    vs_l=vs;
    if(ln_vs && !ln_vs_l) render_syncs=render_syncs+1;
    ln_vs_l=ln_vs;
    if(uut.frame!=frame_l) begin
        assert_msg(q_in==q_out, "frame bank changed before DDR drained");
        assert_msg(draw_x==-1 || (ln_hs && draw_x<=1), "frame bank changed while drawing");
        if(frame_swaps>0)
            assert_msg(frame_lines==expected_lines,
                $sformatf("rendered %0d visible lines, expected %0d",frame_lines,expected_lines));
        frame_lines=0;
        expected_lines=v_step>256 ? (6*v_step+255)/256 : 6;
        frame_swaps=frame_swaps+1;
    end
    frame_l=uut.frame;
`ifndef JTFRAME_LF_FULLV
    assert_msg(render_syncs==frame_swaps, "render VS did not follow accepted frame swaps");
`endif
    if(uut.fb_done) begin
        acknowledgements=acknowledgements+1;
        assert_msg(acknowledgements<=completed, "duplicate line acknowledgement");
    end
    if(ln_we && we) overlaps=overlaps+1;
    if(we && !busy) begin
        assert_msg(q_out<q_in, "unexpected DDR write (blank line or duplicate)");
        assert_msg(addr[HW+VW]==q_bank[q_out], "wrong destination frame bank");
        assert_msg(addr[HW+VW-1:HW]==q_v[q_out], "wrong destination row");
        assert_msg(addr[HW+VW]==uut.frame, "write into displayed frame bank");
        assert_msg(din[15:0]===expected(q_id[q_out],write_x),
            $sformatf("pixel mismatch request=%0d x=%0d got=%h expected=%h",q_id[q_out],write_x,din[15:0],expected(q_id[q_out],write_x)));
        if(q_id[q_out]>4 && write_x%2==1) sparse_writes=sparse_writes+1;
        writes=writes+1;
        write_x=write_x+1;
        if(write_x==LINE_W) begin write_x=0; q_out=q_out+1; end
    end
end

task wait_new_frame;
    integer previous;
    begin
        previous=frame_swaps;
        wait(frame_swaps>previous);
        @(negedge clk);
    end
endtask

task pause_word(input integer x);
    begin
        wait(we && write_x==x);
        @(negedge clk); stall=1;
        repeat(3) @(negedge clk);
        stall=0;
    end
endtask

initial begin
    repeat(8) @(negedge clk);
    rst=0;
    wait(frame_swaps>=3);
    // Pause on the first word, either side of a burst boundary, and last word.
    pause_word(0);
    pause_word(127);
    pause_word(128);
    pause_word(LINE_W-1);
    // Hold the memory in the middle of a burst, while the other line fills.
    wait(we && write_x==17);
    @(negedge clk); stall=1;
    held_bank=uut.frame;
    held_dh=uut.u_line.dh; held_dv=uut.u_line.dv;
    h_step=9'h0fc; v_step=9'h180;
    before_swaps=frame_swaps;
    before_vs=vs_count;
    wait(vs_count>=before_vs+2);
    @(negedge clk);
    assert_msg(uut.frame==held_bank && frame_swaps==before_swaps,
        "DDR overrun swapped the display bank");
    assert_msg(uut.u_ctrl.swap_pend, "test did not fill both line buffers");
    assert_msg(uut.u_line.dh==held_dh && uut.u_line.dv==held_dv,
        "repeated frame changed its readout scale");
    stall=0;
    wait_new_frame();
    // Also cover a renderer that takes longer than an entire video frame.
    hold_renderer=1;
    before_vs=vs_count;
    before_swaps=frame_swaps;
    wait(vs_count>=before_vs+2);
    @(negedge clk);
    assert_msg(frame_swaps==before_swaps, "renderer overrun restarted the frame");
    hold_renderer=0;
    wait_new_frame();
    // Finish the last transfer immediately before VS: clearing must still
    // keep the bank private, even though all DDR pixels have been accepted.
    wait(we && uut.u_line.done && write_x==LINE_W-1);
    @(negedge clk); stall=1;
    held_bank=uut.frame;
    before_swaps=frame_swaps;
    before_vs=vs_count;
    wait(v==1 && h==511 && divider==6);
    @(negedge clk); stall=0;
    wait(vs_count>before_vs);
    repeat(10) @(negedge clk);
    assert_msg(uut.fb_clr, "test missed clearing across VS");
    assert_msg(uut.frame==held_bank && frame_swaps==before_swaps,
        "bank swapped before clearing completed");
    wait_new_frame();
    // Exercise both sides of unity scaling and the larger write-side extent.
    h_step=9'h0fc; v_step=9'h180;
    repeat(3) wait_new_frame();
    assert_msg(uut.u_line.vend_eff>uut.u_line.vend, "scaled write extent not exercised");
    h_step=9'h100; v_step=9'h155; // fractional source extent must round up
    repeat(3) wait_new_frame();
    h_step=9'h180; v_step=9'h0fc;
    repeat(3) wait_new_frame();
    assert_msg(overlaps>0, "drawing never overlapped DDR writes");
    assert_msg(sparse_writes>0, "buffer clearing not checked");
`ifdef JTFRAME_LF_FULLV
    assert_msg(blank_lines>0, "FULLV blank lines not exercised");
`else
    assert_msg(blank_lines==0, "unexpected blank render request");
`endif
    $display("Checked %0d DDR pixels, %0d requests, %0d blank lines",writes,requests,blank_lines);
    pass();
end
endmodule
