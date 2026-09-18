`timescale 1ns/1ps
module test;
`include "test_tasks.vh"
reg clk96=0, clk=0, rst=1;
// Related, rising-edge aligned clocks, approximating pll6293.
always #4.968 clk96=~clk96;
`ifdef TEST_CLK96
always #4.968 clk=~clk;
`else
initial begin #4.968; forever #9.936 clk=~clk; end
`endif
reg [3:0] divider=0;
`ifdef TEST_CLK96
wire pxl_cen=divider==0;
`else
wire pxl_cen=divider[2:0]==0;
`endif
reg [8:0] h=0;
reg [7:0] v=0;
wire lhbl=h>=32 && h<352, hs=h>=400 && h<432;
reg geometry_ready=0;
wire lvbl=v>=6 && v<12, vs=geometry_ready && v>=2 && v<4;
reg ln_done=0, ln_we=0;
reg [8:0] ln_addr=0;
reg [15:0] ln_data=0;
wire ln_hs, ln_vs, ln_lvbl;
wire [7:0] ln_v;
wire [15:0] ln_pxl, ln_dout;
wire [21:16] cr_addr;
wire [15:0] cr_adq;
wire cr_wait, cr_advn, cr_cre, cr_oen, cr_wen, cr_clk;
wire [1:0] cr_cen, cr_dsn;
wire we, re;
wire [21:0] addr;
wire [15:0] din;
integer requests=0, completions=0, acks=0, memory_acks=0, writes=0;
integer x=-1, id=0, write_x=0, frame_count=0;
integer queue_id[0:127];
reg [7:0] queue_v[0:127];
reg queue_bank[0:127];
integer qi=0, qo=0, pxl_in=0, pxl_out=0;
reg vs_l=0;
reg [1:0] ack_phases=0;
integer config_writes=0, checked_reads=0;
integer written_id[0:511];
integer k;
initial for(k=0;k<512;k=k+1) written_id[k]=0;
realtime we_start, ce_start, adv_end;
reg config_cycle=0;
reg [21:0] config_word;

jtframe_lfbuf_cram uut(
    .rst(rst), .clk(clk), .clk96(clk96), .pxl_cen(pxl_cen),
    .vrender(v), .hdump(h), .hs(hs), .vs(vs), .lhbl(lhbl), .lvbl(lvbl),
    .h_step(9'h100), .v_step(9'h100),
    .ln_addr(ln_addr), .ln_data(ln_data), .ln_done(ln_done), .ln_we(ln_we),
    .fb_keep(1'b0), .ln_hs(ln_hs), .ln_vs(ln_vs), .ln_lvbl(ln_lvbl),
    .ln_dout(ln_dout), .ln_pxl(ln_pxl), .ln_v(ln_v),
    .cr_addr(cr_addr), .cr_adq(cr_adq), .cr_wait(cr_wait),
    .cr_advn(cr_advn), .cr_cre(cr_cre), .cr_cen(cr_cen),
    .cr_oen(cr_oen), .cr_wen(cr_wen), .cr_dsn(cr_dsn), .cr_clk(cr_clk)
);
cell_ram_model u_memory(
    .clk(clk96), .stall(1'b0), .cr_addr(cr_addr), .cr_adq(cr_adq),
    .cr_wait(cr_wait), .cr_advn(cr_advn), .cr_cre(cr_cre), .cr_cen(cr_cen),
    .cr_oen(cr_oen), .cr_wen(cr_wen), .cr_dsn(cr_dsn),
    .write_beat(we), .read_beat(re), .address(addr), .write_data(din)
);
function [15:0] pattern(input integer n, input integer col);
    pattern=(n<<9)|col;
endfunction
function [15:0] expected(input integer n, input integer col);
    expected=n>4 && col%2 ? 16'd0 : pattern(n,col);
endfunction
always @(posedge clk) begin
    if(rst) begin divider<=0; h<=0; v<=0; end
    else begin
        divider<=divider+1'd1;
        if(v==12) geometry_ready<=1;
        if(pxl_cen) begin
            pxl_in=pxl_in+1;
            h<=h+1'd1;
            if(h==511) v<=v==17 ? 0 : v+1'd1;
        end
        if(uut.fb_done) acks=acks+1;
        vs_l<=vs;
        if(vs && !vs_l) frame_count=frame_count+1;
    end
end
always @(posedge clk96) if(!rst) begin
    if(uut.pxl96_cen) pxl_out=pxl_out+1;
    if(uut.fb_done96) begin
        memory_acks=memory_acks+1;
        ack_phases[clk]=1;
    end
    if(we && uut.u_ctrl.st!=0) begin
        assert_msg(qo<qi,"unexpected memory write");
        if(addr!=={queue_bank[qo],queue_v[qo],4'd0,write_x[8:0]}) begin
            $display("address=%h expected=%h qi=%0d qo=%0d row=%0d frame=%b",addr,{queue_bank[qo],queue_v[qo],4'd0,write_x[8:0]},qi,qo,uut.u_ctrl.wr_v,uut.frame);
            fail();
        end
        if(din!==expected(queue_id[qo],write_x)) begin
            $display("word %0d id %0d got %h expected %h",write_x,queue_id[qo],din,expected(queue_id[qo],write_x));
            fail();
        end
        writes=writes+1;
        write_x=write_x+1;
        if(write_x==512) begin
            written_id[{queue_bank[qo],queue_v[qo]}]=queue_id[qo];
            write_x=0; qo=qo+1;
        end
    end
    if(re && uut.u_ctrl.st!=0) begin
        assert_msg(uut.rd_addr==addr[8:0],"scanout address misaligned with returned data");
        if(written_id[addr[21:13]]!=0) begin
            assert_msg(uut.fb_dout===expected(written_id[addr[21:13]],addr[8:0]),"scanout readback mismatch");
            checked_reads=checked_reads+1;
        end
    end
end
// Complete only after the last producer write; exercise sparse bank reuse.
always @(negedge clk) begin
    ln_we=0;
    ln_done=0;
    if(!rst) begin
        if(ln_hs) begin
            assert_msg(x==-1,"producer interrupted");
            if(requests!=0 && ln_v!=6) assert_msg(acks==completions,"completion lost at clock crossing");
            requests=requests+1;
            id=requests;
            x=0;
            queue_id[qi]=id;
            queue_v[qi]=ln_v;
            queue_bank[qi]=~uut.frame;
        end
        if(x>=0) begin
            if(x==512) begin
                ln_done=1; completions=completions+1; qi=qi+1; x=-1;
            end else begin
                ln_addr=x;
                ln_data=pattern(id,x);
                ln_we=id<=4 || x%2==0;
                x=x+1;
            end
        end
    end
end
// Check actual configuration bus accesses and nanosecond pulse lengths.
always @(negedge cr_cen[0]) if(!rst) ce_start=$realtime;
always @(posedge cr_advn) if(!rst && !cr_cen[0] && uut.u_ctrl.st==0) begin
    adv_end=$realtime;
    if(config_cycle) config_word={cr_addr,cr_adq};
end
always @(negedge cr_advn) if(!rst && cr_cre) config_cycle=1;
always @(negedge cr_wen) if(!rst && config_cycle) we_start=$realtime;
always @(posedge cr_wen) if(!rst && config_cycle) begin
    assert_msg($realtime-we_start>=45.0,"configuration WE pulse shorter than 45 ns");
    assert_msg($realtime-ce_start>=70.0,"configuration CE pulse shorter than 70 ns");
    assert_msg($realtime-adv_end>=70.0,"configuration ADV-to-write end shorter than 70 ns");
    assert_msg(config_word== (config_writes==0 ? 22'h000014 : 22'h08181f),"configuration address/data mismatch");
    config_writes=config_writes+1;
    config_cycle=0;
end
initial begin
    $dumpfile("test.lxt"); $dumpvars(0,test);
    repeat(16) @(negedge clk); rst=0;
    wait(frame_count==6);
    repeat(100) @(negedge clk);
    assert_msg(config_writes==2,"missing configuration writes");
    assert_msg(qo>=24,"too few completed lines");
    assert_msg(checked_reads>=512,"no known scanout data checked");
    assert_msg(acks==memory_acks && acks==completions,"lost/duplicate acknowledgements");
    assert_msg(pxl_in-pxl_out<=1,"lost/duplicate pixel enables");
`ifndef TEST_CLK96
    assert_msg(ack_phases==3,"did not cover both fast-clock completion phases");
`endif
    $display("lines=%0d words=%0d ack=%0d phases=%b",qo,writes,acks,ack_phases);
    pass();
end
initial begin
    #20_000_000;
    $display("timeout requests=%0d completions=%0d acks=%0d memory=%0d state=%0d",requests,completions,acks,memory_acks,uut.u_ctrl.st);
    fail();
end
endmodule
