`timescale 1ns/1ps
module test;
    reg clk=0; always #5 clk=~clk;
    reg rst=1, hold_req=1, refresh_req=0, cyc_ack=0;
    wire hold_ack,word_ack,host_ack,screen_ack,cyc_req,cyc_iaq;
    wire [3:0] cyc_kind;
    wire [31:0] cyc_addr;
    wire [15:0] cyc_wdata;
    wire fetch_grid_ready;
    jttms10_bus #(.RESET_REFRESH(1)) dut(
        .clk(clk),.rst(rst),.hold_req(hold_req),.hold_ack(hold_ack),
        .fetch_grid_ready(fetch_grid_ready),
        .screen_req(1'b1),.screen_srfaddr(14'h123),
        .screen_dpytap(16'h456),.screen_org(1'b0),.screen_ack(screen_ack),
        .refresh_req(refresh_req),.refresh_row(8'h7a),.refresh_cbr(1'b1),
        .host_mem_req(1'b1),.host_mem_we(1'b1),
        .host_mem_addr(32'h200),.host_mem_wdata(16'h1234),
        .host_mem_is_io(1'b0),.host_mem_io_rdata(16'd0),
        .host_mem_rdata(),.host_mem_ack(host_ack),
        .word_req(1'b1),.word_we(1'b0),.word_iaq(1'b1),
        .word_lock(1'b0),.word_pixel(1'b0),.word_addr(32'h100),
        .word_wdata(16'd0),.is_io(1'b0),.pixel_srt(1'b0),.io_rdata(16'd0),
        .word_rdata(),.word_ack(word_ack),.word_restart(),
        .cyc_req(cyc_req),.cyc_kind(cyc_kind),.cyc_addr(cyc_addr),
        .cyc_wdata(cyc_wdata),.cyc_io_rdata(),.cyc_iaq(cyc_iaq),
        .cyc_srfaddr(),.cyc_dpytap(),.cyc_org(),.cyc_dram_row(),
        .cyc_rdata(16'hbeef),.cyc_ack(cyc_ack)
    );
    integer completed=0,word_acks=0,host_acks=0,screen_acks=0;
    integer delay_left=0, ack_hold=0;
    reg [1:0] state=0;
    reg [3:0] saved_kind;
    reg [31:0] saved_addr;
    reg [15:0] saved_data;
    reg saved_iaq;
    always @(posedge clk) begin
        if(rst) begin
            completed<=0; state<=0; cyc_ack<=0; ack_hold<=0;
            word_acks<=0; host_acks<=0; screen_acks<=0;
        end else begin
            if(word_ack) word_acks<=word_acks+1;
            if(host_ack) host_acks<=host_acks+1;
            if(screen_ack) screen_acks<=screen_acks+1;
            if(completed<8 && (word_ack || host_ack || screen_ack))
                $fatal(1,"client acknowledged before initial RAS cycles");
            if(hold_ack && cyc_req) $fatal(1,"cycle while HOLD acknowledged");
            case(state)
                0: if(cyc_req) begin
                    saved_kind<=cyc_kind; saved_addr<=cyc_addr;
                    saved_data<=cyc_wdata; saved_iaq<=cyc_iaq;
                    delay_left<=3; ack_hold<=0; state<=1;
                    if(completed<8 && (cyc_kind!=3 || cyc_iaq))
                        $fatal(1,"initial cycle %0d kind=%0d IAQ=%b",
                            completed,cyc_kind,cyc_iaq);
                    case(completed)
                        8: if(cyc_kind!=2) $fatal(1,"screen priority lost");
                        9: if(cyc_kind!=4) $fatal(1,"pending CBR refresh lost");
                        10: if(cyc_kind!=1 || cyc_addr!=32'h200)
                            $fatal(1,"host priority lost");
                        11: if(cyc_kind!=0 || cyc_addr!=32'h100 || !cyc_iaq)
                            $fatal(1,"CPU request lost");
                        default:;
                    endcase
                end
                1: begin
                    if(!cyc_req || cyc_kind!==saved_kind ||
                       cyc_addr!==saved_addr || cyc_wdata!==saved_data ||
                       cyc_iaq!==saved_iaq)
                        $fatal(1,"held startup payload changed");
                    if(delay_left!=0) delay_left<=delay_left-1;
                    else begin cyc_ack<=1; state<=2; end
                end
                2: if(!cyc_req) begin
                    if(ack_hold<2) begin
                        ack_hold<=ack_hold+1;
                        if(fetch_grid_ready)
                            $fatal(1,"next phase became grantable while target ACK stayed high");
                    end else begin
                        completed<=completed+1; cyc_ack<=0; state<=0;
                    end
                end
                default: state<=0;
            endcase
        end
    end
    task tick; begin @(posedge clk); #1; end endtask
    task wait_hold;
        integer n;
        begin
            n=0;
            while(!hold_ack && n<256) begin tick(); n=n+1; end
            if(!hold_ack) $fatal(1,"HOLD acknowledgement timeout");
        end
    endtask
    task wait_completed;
        input integer target;
        integer n;
        begin
            n=0;
            while(completed<target && n<512) begin tick(); n=n+1; end
            if(completed!=target)
                $fatal(1,"startup cycle count timeout target=%0d actual=%0d",target,completed);
        end
    endtask
    task wait_target;
        integer n;
        begin
            n=0;
            while(!cyc_req && n<64) begin tick(); n=n+1; end
            if(!cyc_req) $fatal(1,"startup target request timeout");
        end
    endtask
    initial begin
        repeat(4) tick(); @(negedge clk); rst=0; refresh_req=1;
        tick(); @(negedge clk); refresh_req=0;
        wait_hold(); repeat(5) tick();
        if(completed!=0 || cyc_req) $fatal(1,"initial HOLD ignored");
        @(negedge clk); hold_req=0;
        wait_completed(2); wait_target();
        @(negedge clk); hold_req=1;
        wait_hold(); repeat(5) tick();
        if(completed!=3 || cyc_req) $fatal(1,"HOLD did not drain active RAS");
        @(negedge clk); hold_req=0;
        wait_completed(12); repeat(10) tick();
        if(completed!=12 || word_acks!=1 || host_acks!=1 || screen_acks!=1)
            $fatal(1,"duplicate/missing post-init client completion");
        // A later reset must perform eight fresh cycles again.
        @(negedge clk); rst=1; tick(); @(negedge clk); rst=0;
        wait_completed(8); tick();
        $display("jttms10_startup PASS (eight RAS cycles, HOLD and reset)");
        $finish;
    end
    initial begin #100000; $fatal(1,"startup timeout"); end
endmodule
