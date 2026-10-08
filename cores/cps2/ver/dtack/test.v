`timescale 1ns/1ps
module test;
`include "test_tasks.vh"

reg clk=0, rst=1, cen=0, cenb=0, asn=1, bgackn=1;
reg [23:20] addr=0;
wire board_wait;
wire [3:0] done;
wire [31:0] baseline, timed, stalled, tas;
integer page;
reg expected;

always #10 clk=~clk;
initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
    #1000000;
    fail("timeout");
end

jtcps2_dtack uut(
    .rst          ( rst                ),
    .clk          ( clk                ),
    .cpu_cen      ( cen                ),
    .cpu_cenb     ( cenb               ),
    .ASn          ( asn                ),
    .BGACKn       ( bgackn             ),
    .A            ( addr               ),
    .board_wait   ( board_wait         )
);

// Exercise the actual CPU and the production stall/recovery generator,
// with ideal memory and with deliberately late memory responses.
dtack_cpu #(.BOARD(0),.LATENCY(0)) u_baseline(
    .clk          ( clk                ),
    .done         ( done[0]            ),
    .clocks       ( baseline           )
);
dtack_cpu #(.BOARD(1),.LATENCY(0)) u_timed(
    .clk          ( clk                ),
    .done         ( done[1]            ),
    .clocks       ( timed              )
);
dtack_cpu #(.BOARD(1),.LATENCY(18)) u_stalled(
    .clk          ( clk                ),
    .done         ( done[2]            ),
    .clocks       ( stalled            )
);
dtack_cpu #(.BOARD(1),.LATENCY(18),.TAS(1)) u_tas(
    .clk          ( clk                ),
    .done         ( done[3]            ),
    .clocks       ( tas                )
);

task step(input p, input n);
begin
    @(negedge clk);
    cen=p;
    cenb=n;
    @(posedge clk);
    #1;
end
endtask

initial begin
    step(0,0);
    rst=0;
    for(page=0; page<16; page=page+1) begin
        asn=1;
        step(0,0);
        addr=page[3:0];
        asn=0;
        expected=(page<5 || page>=8);
        #1;
        assert_msg(board_wait==expected,"address-range qualification");
        step(0,1);
        assert_msg(board_wait==expected,"falling edge before first rising must not acknowledge");
        step(1,0);
        assert_msg(board_wait==expected,"first rising edge must not acknowledge");
        step(0,0);
        assert_msg(board_wait==expected,"master clocks must not advance the delay");
        step(0,1);
        assert_msg(!board_wait,"acknowledge follows next falling edge");
        repeat(4) begin
            step(1,0);
            step(0,1);
            assert_msg(!board_wait,"acknowledge must remain asserted while AS is low");
        end
    end
    // Aborted transfers and bus ownership must clear the timing stages.
    asn=1;
    step(0,0);
    addr=0;
    asn=0;
    step(1,0);
    asn=1;
    step(0,0);
    asn=0;
    step(0,1);
    assert_msg(board_wait,"aborted transfer must not acknowledge the next one early");
    bgackn=0;
    step(0,0);
    assert_msg(!board_wait,"DMA owns the bus");
    bgackn=1;
    step(0,1);
    assert_msg(board_wait,"bus reacquisition must start a fresh timing sequence");
    step(1,0);
    step(0,1);
    assert_msg(!board_wait,"reacquired bus can acknowledge");
    wait(&done);
    $display("CPU clocks/100 loops: baseline=%0d timed=%0d stalled=%0d",baseline,timed,stalled);
    assert_msg(baseline==3800,"baseline addq.l absolute + bra loop is 38 clocks");
    assert_msg(timed==4700,"nine external transfers add nine real wait clocks per loop");
    assert_msg(stalled==timed,"artificial memory latency must not erase or multiply board waits");
    assert_msg(tas==6300,"TAS must preserve acknowledgement across its data-strobe gap");
    pass();
end
endmodule

module dtack_cpu #(
    parameter BOARD=1, LATENCY=0, TAS=0
)(
    input clk,
    output reg done=0,
    output reg [31:0] clocks=0
);
`include "test_tasks.vh"
reg rst=1;
wire cen, cenb, asn, udsn, ldsn, rnw, dtackn, board_wait;
wire selected, busy, legit;
wire [1:0] dsn;
wire [23:1] addr;
wire [15:0] dout;
reg [15:0] din;
reg [31:0] counter=0;
reg selected_l=0;
integer age=0, ticks=0, loops=0, first_tick=0, phases=0, first_phase=0;

assign dsn={udsn,ldsn};
assign selected=!asn && !(&dsn);
assign legit=BOARD!=0 && board_wait;
// A cache miss on the loop entry; all other accesses are hits. Permanent
// latency on every transfer would exceed the available memory bandwidth.
assign busy=legit || (selected && addr==23'h80 && age<LATENCY);

initial begin
    repeat(8) @(negedge clk);
    rst=0;
end

always @* begin
    case({addr,1'b0})
        24'h000000: din=16'h00ff;
        24'h000002: din=16'h8000;
        24'h000004: din=16'h0000;
        24'h000006: din=16'h0100;
        24'h000100: din=TAS!=0 ? 16'h4af9 : 16'h52b9; // tas.b / addq.l $ff0000
        24'h000102: din=16'h00ff;
        24'h000104: din=16'h0000;
        24'h000106: din=TAS!=0 ? 16'h5279 : 16'h60f8; // addq.w / bra.s $100
        24'h000108: din=16'h00ff;
        24'h00010a: din=16'h0002;
        24'h00010c: din=16'h60f2; // bra.s $100
        24'hff0000: din=counter[31:16];
        24'hff0002: din=counter[15:0];
        default: din=16'h4e71;
    endcase
end

always @(posedge clk) if(!rst) begin
    ticks=ticks+1;
    if(cen || cenb) phases=phases+1;
    selected_l<=selected;
    if(!selected) age<=0;
    else if(age<LATENCY) age<=age+1;
    if(selected && !selected_l && rnw && addr==23'h7f8000) begin
        loops=loops+1;
        if(loops==21) begin
            first_tick=ticks;
            first_phase=phases;
        end
        if(loops==121) begin
            assert_msg(counter==(TAS!=0 ? 32'h80000078 : 32'd120),
                "read/modify/write data must survive all waits");
            clocks=(ticks-first_tick)/3;
            assert_msg(phases-first_phase==(TAS!=0 ? 12600 : BOARD!=0 ? 9400 : 7600),
                "CPU must execute exactly the expected nominal plus board wait phases");
            $display("BOARD=%0d LATENCY=%0d TAS=%0d ticks=%0d phases=%0d",BOARD,LATENCY,TAS,ticks-first_tick,phases-first_phase);
            done=1;
        end
    end
    if(selected && !rnw && !dtackn) begin
        if(addr==23'h7f8000) begin
            if(!udsn) counter[31:24]<=dout[15:8];
            if(!ldsn) counter[23:16]<=dout[7:0];
        end
        if(addr==23'h7f8001) begin
            if(!udsn) counter[15:8]<=dout[15:8];
            if(!ldsn) counter[7:0]<=dout[7:0];
        end
    end
    if(legit) begin
        assert_msg(!u_cen.charge && !u_cen.recover,
            "board waits must neither create nor repay recovery debt");
    end
end

jtcps2_dtack uut(
    .rst          ( rst                ),
    .clk          ( clk                ),
    .cpu_cen      ( cen                ),
    .cpu_cenb     ( cenb               ),
    .ASn          ( asn                ),
    .BGACKn       ( 1'b1               ),
    .A            ( addr[23:20]        ),
    .board_wait   ( board_wait         )
);
jtframe_68kdtack_cen #(.MFREQ(48000)) u_cen(
    .rst          ( rst                ),
    .clk          ( clk                ),
    .cpu_cen      ( cen                ),
    .cpu_cenb     ( cenb               ),
    .bus_cs       ( selected           ),
    .bus_busy     ( busy               ),
    .bus_legit    ( legit              ),
    .bus_ack      ( 1'b0               ),
    .ASn          ( asn                ),
    .DSn          ( dsn                ),
    .num          ( 4'd1               ),
    .den          ( 5'd3               ),
    .wait2        ( 1'b0               ),
    .wait3        ( 1'b0               ),
    .DTACKn       ( dtackn             ),
    .fave         (                    ),
    .fworst       (                    )
);
jtframe_m68k u_cpu(
    .clk          ( clk                ),
    .rst          ( rst                ),
    .cpu_cen      ( cen                ),
    .cpu_cenb     ( cenb               ),
    .BERRn        ( 1'b1               ),
    .VPAn         ( 1'b1               ),
    .BGACKn       ( 1'b1               ),
    .HALTn        ( 1'b1               ),
    .RESETn       (                    ),
    .eab          ( addr               ),
    .ASn          ( asn                ),
    .LDSn         ( ldsn               ),
    .UDSn         ( udsn               ),
    .eRWn         ( rnw                ),
    .DTACKn       ( dtackn             ),
    .iEdb         ( din                ),
    .oEdb         ( dout               ),
    .BRn          ( 1'b1               ),
    .BGn          (                    ),
    .IPLn         ( 3'b111             ),
    .FC           (                    )
);
endmodule
