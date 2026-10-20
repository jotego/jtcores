// SPDX-License-Identifier: GPL-3.0-or-later
// Behavioral full-system reference. It deliberately does not instantiate the
// FPGA sequencer or use its packed RAM/prefetch/control-output implementation.
module reference_stimulus(
    input clk,rst,measuring,finished,
    input [31:0] absolute_clock,relative_clock,
    input write_complete,decode,
    input [31:0] decode_pc,
    input hold_ack,host_ack,
    output reg lint1_n=1,lint2_n=1,hold_req=0,emu_run=1,cen_enable=1,
    output reg host_req=0,
    output reg [15:0] host_wdata=0
);
    integer count=0,cursor=0,fd,rc;
    reg [31:0] trigger[0:15],argument[0:15],control[0:15];
    string path,extra;
    reg [31:0] writes=0,holds=0,hosts=0,issued=0,last_clock=0,paused=0;
    reg decoded=0,previous_hold=0;
    reg [31:0] decoded_pc=0;
    reg ready,late,old_request;

    initial begin
        if(!$value$plusargs("EXTERNAL_EVENTS=%s",path)) $fatal(1,"missing external reference table");
        fd=$fopen(path,"r");
        if(fd==0) $fatal(1,"cannot open external reference table");
        rc=$fscanf(fd,"%d",count);
        if(rc!=1 || count<0 || count>16) $fatal(1,"invalid external reference count");
        for(integer q=0;q<count;q=q+1) begin
            rc=$fscanf(fd,"%h %h %h",trigger[q],argument[q],control[q]);
            if(rc!=3 || trigger[q]>5 || (control[q] & 32'hffff7cc0)!=0 ||
               ((control[q] & 32'h8300)!=0 && !control[q][4]) ||
               (trigger[q]==2 && argument[q][3:0]!=0) ||
               ((trigger[q]==1 || trigger[q]>=3) && argument[q]==0))
                $fatal(1,"invalid external reference entry %0d",q);
        end
        rc=$fscanf(fd,"%s",extra);
        if(rc==1) $fatal(1,"trailing external reference data");
        $fclose(fd);
    end

    always @(posedge clk) begin
        if(rst) begin
            writes<=0;holds<=0;hosts<=0;paused<=0;
            decoded<=0;decoded_pc<=0;previous_hold<=0;
        end else begin
            decoded<=measuring && decode;
            decoded_pc<=decode_pc;
            previous_hold<=hold_ack;
            if(measuring) begin
                if(write_complete) writes<=writes+1;
                if(hold_ack) holds<=holds+1;
                if(host_ack) begin
                    hosts<=hosts+1;
                    $display("HOST_ACK %0d",absolute_clock);
                end
                if(hold_ack!=previous_hold)
                    $display("HOLD_ACK %0d %0d",absolute_clock,hold_ack);
                if(!cen_enable) paused<=paused+1;
            end
        end
    end

    always @(negedge clk) begin
        if(rst) begin
            cursor=0;issued=0;last_clock=0;
            lint1_n=1;lint2_n=1;hold_req=0;emu_run=1;cen_enable=1;
            host_req=0;host_wdata=0;
        end else if(measuring) begin
            old_request=host_req;
            if(old_request && !host_ack) $fatal(1,"external reference missing host ACK");
            host_req=0;
            if(cursor<count) begin
                ready=0;late=0;
                case(trigger[cursor])
                    0: begin ready=relative_clock==argument[cursor];late=relative_clock>argument[cursor];end
                    1: begin ready=writes==argument[cursor];late=writes>argument[cursor];end
                    2: ready=decoded && decoded_pc==argument[cursor];
                    3: begin ready=relative_clock-last_clock==argument[cursor];late=relative_clock-last_clock>argument[cursor];end
                    4: begin ready=holds==argument[cursor];late=holds>argument[cursor];end
                    5: begin ready=hosts==argument[cursor];late=hosts>argument[cursor];end
                    default: $fatal(1,"unknown external reference trigger");
                endcase
                if(late) $fatal(1,"external reference missed event %0d",cursor);
                if(ready) begin
                    if(control[cursor][4] && old_request) $fatal(1,"external reference adjacent host writes");
                    lint1_n=!control[cursor][0];
                    lint2_n=!control[cursor][1];
                    hold_req=control[cursor][2];
                    emu_run=!control[cursor][3];
                    cen_enable=!control[cursor][5];
                    host_req=control[cursor][4];
                    host_wdata={control[cursor][15],5'b0,control[cursor][9:8],8'b0};
                    if(host_req) issued=issued+1;
                    $display("STIMULUS %0d %0d %0d %08h %04h",absolute_clock,cursor,
                        trigger[cursor],argument[cursor],16'(control[cursor]));
                    last_clock=relative_clock;
                    cursor=cursor+1;
                end
            end
        end else begin
            lint1_n=1;lint2_n=1;hold_req=0;emu_run=1;cen_enable=1;host_req=0;
        end
    end

    // Let the final positive-edge counters settle, before the parent bench
    // finishes at the following negative edge.
    always @(posedge finished) begin
        #1;
        if(cursor!=count || hosts!=issued) $fatal(1,"external reference unfinished table/host work");
        $display("EXTERNAL_RESULT configured=%0d applied=%0d writes=%0d holds=%0d hosts=%0d issued=%0d error=0 last=%0d paused=%0d",
            count,cursor,writes,holds,hosts,issued,last_clock,paused);
    end
endmodule
