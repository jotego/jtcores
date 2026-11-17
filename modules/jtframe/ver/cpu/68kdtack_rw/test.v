/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 17-11-2026 */

`timescale 1ns/1ps

`ifndef JTFRAME_DTACK_DEN
`define JTFRAME_DTACK_DEN 3
`endif

module test;
`include "test_tasks.vh"

reg clk=0;
wire [84:0] done;
wire [31:0] clocks[0:83], phases[0:83];
integer cfg;
genvar k;

always #10 clk=~clk;

initial begin
    $dumpfile("test.lxt");
    $dumpvars(1,test);
    #250000;
    assert_msg(0,"real CPU read/write timing timeout");
end

initial begin
    wait(&done);
    for(cfg=0;cfg<16;cfg=cfg+1) begin
        if(`JTFRAME_DTACK_DEN>2) assert_msg(clocks[cfg*5]==clocks[cfg*5+1],"ready reads and writes take equal master clocks");
        assert_msg(phases[cfg*5]==phases[cfg*5+1],"ready reads and writes take equal CPU phases");
        if(`JTFRAME_DTACK_DEN>2) assert_msg(clocks[cfg*5+2]==clocks[cfg*5+3],"late reads and writes take equal master clocks");
        assert_msg(phases[cfg*5+2]==phases[cfg*5+3],"late reads and writes take equal CPU phases");
        $display("DEN=%0d registered=%0d WAIT1=%0d wait2=%0d wait3=%0d ready R/W=%0d/%0d late R/W=%0d/%0d TAS=%0d",
            `JTFRAME_DTACK_DEN,cfg/8,(cfg/4)%2,cfg%2,(cfg/2)%2,clocks[cfg*5],clocks[cfg*5+1],
            clocks[cfg*5+2],clocks[cfg*5+3],clocks[cfg*5+4]);
    end
    for(cfg=0;cfg<5;cfg=cfg+1) begin
        assert_msg(clocks[10+cfg]==clocks[15+cfg],"both waits equal wait3 with WAIT1=0");
        assert_msg(clocks[30+cfg]==clocks[35+cfg],"both waits equal wait3 with WAIT1=1");
    end
    assert_msg(phases[80]==phases[81] && phases[82]==phases[83],"unmapped reads/writes preserve CPU bus timing");
    if(`JTFRAME_DTACK_DEN>2)
        assert_msg(clocks[80]==clocks[81] && clocks[82]==clocks[83],"unmapped reads/writes preserve master-clock timing");
    pass();
end

generate for(k=0;k<80;k=k+1) begin: cases
    dtack_cpu #(.WAIT1((k/20)%2),.REGISTERED(k/40),.WAIT2((k/5)%2),.WAIT3((k/10)%2),
                .MODE(k%5==4 ? 2 : (k%5)%2),.LATENCY(k%5==2 || k%5==3 ? 16 : 0)) check_cpu(
        .clk    ( clk       ),
        .done   ( done[k]   ),
        .clocks ( clocks[k] ),
        .phases ( phases[k] )
    );
end endgenerate

generate for(k=80;k<84;k=k+1) begin: unmapped
    dtack_cpu #(.WAIT1((k-80)/2),.MODE(k%2),.UNMAPPED(1)) check_cpu(
        .clk    ( clk       ),
        .done   ( done[k]   ),
        .clocks ( clocks[k] ),
        .phases ( phases[k] )
    );
end endgenerate

dtack_ownership check_ownership(
    .clk  ( clk      ),
    .done ( done[84] )
);

endmodule

module dtack_cpu #(
    parameter WAIT1=0, WAIT2=0, WAIT3=0, MODE=0, LATENCY=0, REGISTERED=0, UNMAPPED=0
)(
    input clk,
    output reg done=0,
    output reg [31:0] clocks=0, phases=0
);
`include "test_tasks.vh"

// MOVE.W (A0),D0 and MOVE.W D0,(A0) are both 8-clock instructions.
// BRA.S is 10 clocks (including its discarded prefetch). The four transfers
// in this loop each receive the
// original read-side delay: WAIT1 adds one; wait3 adds one beyond that.
localparam [4:0] DIVISOR=`JTFRAME_DTACK_DEN;
localparam WAITS=WAIT1+WAIT3;
localparam ITERATIONS=16;
localparam EXPECT_PHASES=ITERATIONS*2*(18+4*WAITS);

reg rst=1, decoded=0, finished=0;
wire cen, cenb, asn, udsn, ldsn, rnw, dtackn, selected, data_cs, busy, wait2, wait3, bus_cs, helper_asn;
wire [1:0] dsn;
wire [23:1] addr;
wire [15:0] dout;
reg [15:0] din, memory;
reg selected_l=0, accepted=0, transfer_read=0, tas_gap=0, asn_l=1;
integer ticks=0, delivered=0, loops=0, start_tick=0, start_phase=0;
integer age=0, reads=0, writes=0, gaps=0, bus_start=0, transfers=0, start_transfers=0;
integer held=0, replayed=0, start_held=0, start_replayed=0, start_debt=0, idle_clocks=0;

assign helper_asn=asn || finished;
assign dsn={udsn,ldsn};
assign wait2=WAIT2!=0;
assign wait3=WAIT3!=0;
assign selected=!asn && !(&dsn);
assign data_cs=addr==23'h7f8000;
// Artificial latency is counted from the CPU's common address setup, before
// write strobes arrive. This makes the response deadline identical for R/W.
assign busy=selected && data_cs && age<LATENCY;
assign bus_cs=UNMAPPED!=0 && data_cs ? 1'b0 : REGISTERED!=0 ? decoded : selected;

initial begin
    memory=MODE==1 ? 16'ha55a : MODE==2 ? 16'h5a3c : 16'h1234;
    repeat(8) @(negedge clk);
    rst=0;
end

always @* begin
    case({addr,1'b0})
        24'h000000: din=16'h00ff;
        24'h000002: din=16'h8000;
        24'h000004: din=16'h0000;
        24'h000006: din=16'h0100;
        24'h000100: din=16'h207c; // MOVEA.L #$ff0000,A0
        24'h000102: din=16'h00ff;
        24'h000104: din=16'h0000;
        24'h000106: din=16'h303c; // MOVE.W #initial,D0
        24'h000108: din=MODE==0 ? 16'hbeef : 16'h1234;
        24'h00010a: din=MODE==0 ? 16'h3010 : MODE==1 ? 16'h3080 : 16'h4ad0;
        24'h00010c: din=16'h60fc; // BRA.S $10a
        24'hff0000: din=memory;
        default: din=16'h4e71;
    endcase
end

always @(posedge clk) decoded<=selected;

// Count enables on the edge consumed by the CPU, then inspect bus and debt
// after nonblocking updates. Recovered phases can occupy adjacent clocks.
always @(posedge clk) if(!rst && !finished) begin
    ticks=ticks+1;
    if(cen || cenb) delivered=delivered+1;
    if(uut.charge) held=held+1;
    if(uut.recover) replayed=replayed+1;
    if(asn) age<=0;
    else if(age<LATENCY) age<=age+1;
end

always @(negedge clk) if(!rst && !finished) begin
    assert_msg(!(selected && data_cs && age<LATENCY && !dtackn),"DTACK never precedes decoded memory readiness");
    if(ticks>64) assert_msg((^{asn,dsn,rnw,dtackn}) !== 1'bx,"CPU handshake signals must be known");
    assert_msg(held-replayed=={21'd0,uut.missing},"withheld minus replayed phases equals actual recovery debt");
    selected_l<=selected;
    if(selected && !selected_l) transfers=transfers+1;
    if(!selected) accepted<=0;
    if(selected && !selected_l && rnw && addr==23'h85) begin
        loops=loops+1;
        if(loops==5) begin
            start_tick=ticks;
            start_phase=delivered;
            start_transfers=transfers;
            start_held=held;
            start_replayed=replayed;
            start_debt={21'd0,uut.missing};
        end
        if(loops==5+ITERATIONS) begin
            clocks=ticks-start_tick;
            phases=delivered-start_phase;
            if(MODE!=2) begin
                assert_msg(transfers-start_transfers==4*ITERATIONS,"MOVE/BRA executes four transfers per loop");
                assert_msg(phases==EXPECT_PHASES,"MOVE/BRA loop has exact independent nominal plus wait timing");
                if(`JTFRAME_DTACK_DEN>2 && LATENCY==0) begin
                    if(clocks!=EXPECT_PHASES*`JTFRAME_DTACK_DEN/2)
                        $display("%m ticks=%0d expected=%0d phases=%0d debt %0d->%0d held=%0d replay=%0d",clocks,EXPECT_PHASES*`JTFRAME_DTACK_DEN/2,phases,start_debt,uut.missing,held-start_held,replayed-start_replayed);
                    assert_msg(clocks==EXPECT_PHASES*`JTFRAME_DTACK_DEN/2,"recovery preserves nominal master-clock duration");
                end
                assert_msg(memory==16'h1234,"data word has the expected read or written value");
                if(MODE==0) begin
                    assert_msg(reads>=ITERATIONS && writes==0,"read loop executes real reads only");
                    assert_msg(u_cpu.u_cpu.D0[15:0]==16'h1234,"CPU consumes the read value");
                end else assert_msg(writes>=ITERATIONS && reads==0,"write loop executes real writes only");
            end else begin
                assert_msg(phases==ITERATIONS*2*(24+5*WAITS),"TAS/BRA exact nominal plus configured wait phases");
                assert_msg(reads==writes && writes>=ITERATIONS,"each TAS executes one read and one accepted write");
                assert_msg(gaps==writes,"each TAS write follows a strobe gap with AS held low");
                assert_msg(memory==16'hda3c,"TAS sets the selected byte and preserves its neighbour");
            end
            if(LATENCY!=0) assert_msg(held>0,"late memory really withholds CPU phases");
            if(`JTFRAME_DTACK_DEN>2) begin
                if(LATENCY!=0) assert_msg(replayed>0,"late memory phases are recovered");
                if(LATENCY==0)
                    assert_msg(held-start_held==replayed-start_replayed && {21'd0,uut.missing}==start_debt,
                        "ready loops balance held/replayed phases without growing debt");
            end
            assert_msg((held-start_held)-(replayed-start_replayed)=={21'd0,uut.missing}-start_debt,
                "measurement interval conserves withheld phases and recovery debt");
            if(LATENCY!=0)
                $display("%m late ticks=%0d debt=%0d->%0d withheld=%0d replayed=%0d",clocks,start_debt,uut.missing,held-start_held,replayed-start_replayed);
            finished=1;
        end
    end
    if(selected && data_cs && !accepted && !dtackn) begin
        accepted<=1;
        transfer_read<=rnw;
        if(rnw) begin
            reads=reads+1;
            if(MODE==2 && reads>1)
                assert_msg(din==16'hda3c,"the following TAS reads the preceding write");
        end else begin
            writes=writes+1;
            if(MODE==2) begin
                assert_msg(tas_gap,"TAS write was rearmed by the read/write strobe gap");
                tas_gap<=0;
            end
            if(!udsn) memory[15:8]<=dout[15:8];
            if(!ldsn) memory[7:0]<=dout[7:0];
        end
    end
    if(MODE==2 && selected_l && !selected && !asn && transfer_read) begin
        gaps=gaps+1;
        tas_gap<=1;
    end
    if(MODE==2 && tas_gap && &dsn && !rnw)
        assert_msg(dtackn,"DTACK stays high in TAS write setup before data strobes");
    assert_msg(!(cen && cenb),"CPU phases never overlap");
end

// Observe bus edges after CPU nonblocking updates, before another recovered
// phase can execute on the immediately following master clock.
always @(negedge clk) if(!rst && !finished) begin
    asn_l<=asn;
    if(asn_l && !asn) bus_start=delivered;
    if(!asn_l && asn && data_cs && MODE!=2) begin
        if(delivered-bus_start!=5+2*WAITS)
            $display("%m bus phases=%0d expected=%0d",delivered-bus_start,5+2*WAITS);
        assert_msg(delivered-bus_start==5+2*WAITS,"data read/write has exact S2-to-S7 bus phase duration");
    end
end

// Stop offering transactions, and prove the bounded residual debt really
// drains. At DEN=2 every master clock is nominal, leaving no replay slots.
initial begin
    wait(finished);
    if(`JTFRAME_DTACK_DEN>2) begin
        while(uut.missing!=0 && idle_clocks<4096) begin
            @(negedge clk);
            idle_clocks=idle_clocks+1;
        end
        assert_msg(uut.missing==0,"remaining debt drains once the bus is idle");
    end
    done=1;
end

jtframe_68kdtack_cen #(.WAIT1(WAIT1),.MFREQ(48000)) uut(
    .rst          ( rst        ),
    .clk          ( clk        ),
    .cpu_cen      ( cen        ),
    .cpu_cenb     ( cenb       ),
    .bus_cs       ( bus_cs     ),
    .bus_busy     ( busy       ),
    .bus_legit    ( 1'b0       ),
    .bus_ack      ( 1'b0       ),
    .RnW          ( rnw        ),
    .BGACKn       ( 1'b1       ),
    .ASn          ( helper_asn ),
    .DSn          ( dsn        ),
    .num          ( 4'd1       ),
    .den          ( DIVISOR    ),
    .wait2        ( wait2      ),
    .wait3        ( wait3      ),
    .DTACKn       ( dtackn     ),
    .fave         (            ),
    .fworst       (            )
);

jtframe_m68k u_cpu(
    .clk          ( clk        ),
    .rst          ( rst        ),
    .cpu_cen      ( cen        ),
    .cpu_cenb     ( cenb       ),
    .BERRn        ( 1'b1       ),
    .VPAn         ( 1'b1       ),
    .BGACKn       ( 1'b1       ),
    .HALTn        ( 1'b1       ),
    .RESETn       (            ),
    .eab          ( addr       ),
    .ASn          ( asn        ),
    .LDSn         ( ldsn       ),
    .UDSn         ( udsn       ),
    .eRWn         ( rnw        ),
    .DTACKn       ( dtackn     ),
    .iEdb         ( din        ),
    .oEdb         ( dout       ),
    .BRn          ( 1'b1       ),
    .BGn          (            ),
    .IPLn         ( 3'b111     ),
    .FC           (            )
);

endmodule

// Isolate the new raw ownership input: legacy bus_ack is deliberately low.
module dtack_ownership(
    input clk,
    output reg done=0
);
`include "test_tasks.vh"

reg rst=1, asn=1, bgackn=1, busy=1;
wire cen, cenb, dtackn, selected;
wire [1:0] dsn;
integer debt, phases=0, phase_start;

assign selected=!asn;
assign dsn={2{asn}};

always @(posedge clk) if(cen || cenb) phases=phases+1;

initial begin
    repeat(8) @(negedge clk);
    rst=0;
    repeat(8) @(negedge clk);
    asn=0;
    repeat(40) @(negedge clk);
    assert_msg(uut.missing>0,"memory stall creates debt before raw BGACK");
    bgackn=0;
    debt={21'd0,uut.missing};
    phase_start=phases;
    repeat(40) begin
        @(negedge clk);
        assert_msg({21'd0,uut.missing}==debt,"raw BGACK freezes recovery debt");
        assert_msg(!uut.hold_cpu && !uut.recover && dtackn,"raw BGACK releases phases and clears DTACK");
    end
    assert_msg(phases>phase_start,"CPU phases continue during raw BGACK ownership");
    asn=1;
    busy=0;
    repeat(2) @(negedge clk);
    bgackn=1;
    repeat(160) @(negedge clk);
    assert_msg(uut.missing==0,"recovery resumes after raw BGACK release");
    done=1;
end

jtframe_68kdtack_cen #(.MFREQ(48000)) uut(
    .rst          ( rst        ),
    .clk          ( clk        ),
    .cpu_cen      ( cen        ),
    .cpu_cenb     ( cenb       ),
    .bus_cs       ( selected   ),
    .bus_busy     ( busy       ),
    .bus_legit    ( 1'b0       ),
    .bus_ack      ( 1'b0       ),
    .RnW          ( 1'b1       ),
    .BGACKn       ( bgackn     ),
    .ASn          ( asn        ),
    .DSn          ( dsn        ),
    .num          ( 4'd1       ),
    .den          ( 5'd4       ),
    .wait2        ( 1'b0       ),
    .wait3        ( 1'b0       ),
    .DTACKn       ( dtackn     ),
    .fave         (            ),
    .fworst       (            )
);

endmodule
