/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-5-2021 */

/*
    Generate DTACK and alternating fx68k enables at num/den CPU clocks per
    master clock. At an artificial SDRAM wait, hold the S4 DTACK-sampling
    Phi2 and all following CPU phases until acknowledgement is ready.
    Recovery replays only divider events physically withheld by that hold.

    bus_legit, bus_ack and active BGACKn keep CPU phases at nominal rate and
    exclude both debt creation and recovery. WAIT1/wait2/wait3 qualification
    also runs on nominal phases; once armed, DTACK can complete on a master
    clock without requiring the held CPU to advance.

    Read timing starts with the data strobes. Write timing starts at AS/RnW,
    one CPU clock before fx68k asserts its write strobes. Both directions
    therefore qualify the same CPU phases. The TAS gap (DSn high, RnW high)
    reloads the timing before the write half even though AS stays low.
    A master-clock strobe guard lets registered chip selects settle; the
    sampling phase can be held while decode is pending even when bus_cs=0.

    DSn must delimit transfers, including both halves of TAS. SDRAM request
    selects must also include DSn so the second transfer issues a new request.
    AS alone is not enough to detect that gap, and gating before S2 setup
    completes would prevent the CPU from asserting write data strobes.
*/

module jtframe_68kdtack_cen
#(parameter W=5,
            RECOVERY=1,
            WD=6,
            WAIT1=0,    // set to 1 to always wait for 1 cpu_cen
            MFREQ=`JTFRAME_MCLK/1000  // clk input frequency in kHz
)(
    input         rst,
    input         clk,
    output        cpu_cen,
    output        cpu_cenb,
    input         bus_cs,
    input         bus_busy,
    input         bus_legit,
    input         bus_ack, // do not recover cycles if another CPU has the bus
    input         RnW,
    input         BGACKn, // raw CPU bus ownership, active low
    input         ASn,
    input [1:0]   DSn,  // If DSn goes high, DTACKn is reset high
    input [W-2:0] num,  // numerator
    input [W-1:0] den,  // denominator
    input         wait2, // first extra qualification stage
    input         wait3, // second stage; takes priority when both are high

    output reg    DTACKn,
    output  [15:0] fave, // average cpu_cen frequency in kHz
    output  [15:0] fworst  // average cpu_cen frequency in kHz
);
localparam CW=W+WD;

reg [W:0]    count=0;
reg [CW-1:0] missing=0;
reg [1:0]    waitsh;
reg          phase=0, active_phi1=0, wait1, ack_armed, strobe_l;
wire [W:0]   step;
wire         over, hold_cpu, recover, emit, charge, ack_ready, board_wait;
wire         timing_active, qualify, bus_owned;
wire [3:0]   nc1, nc2;

assign step = {1'b0,num,1'b0};
assign over = count > {1'b0,den}-step;
assign bus_owned = bus_ack || !BGACKn;
assign timing_active = !ASn && BGACKn && (!RnW || !(&DSn));
assign qualify = (cpu_cen || WAIT1==0) && waitsh==0 && !wait1;
assign ack_ready = ack_armed || (WAIT1==0 && waitsh==0);
assign board_wait = timing_active &&
                    (waitsh!=0 || (WAIT1!=0 && !ack_armed));
// AS falls on Phi1 entering S2. Allow the next Phi1 to enter S4, then
// hold its DTACK-sampling Phi2. Do not stop setup, a TAS strobe gap, a
// legitimate board wait, or the clocks needed by bus-grant handshakes.
assign hold_cpu = !ASn && !(&DSn) && DTACKn && ack_ready &&
                  !bus_legit && !bus_owned && active_phi1 && !phase;
assign recover = RECOVERY!=0 && missing!=0 && !over && !hold_cpu &&
                 !bus_owned && !bus_legit && !board_wait && !rst;
assign emit = !rst && !hold_cpu && (over || recover);
assign charge = RECOVERY!=0 && over && hold_cpu;
assign cpu_cen = emit && phase;
assign cpu_cenb = emit && !phase;

always @(posedge clk) begin
    if(rst || !timing_active) active_phi1 <= 0;
    else if(cpu_cen) active_phi1 <= 1;
end

always @(posedge clk) begin
    if(rst) begin
        count <= 0;
        missing <= 0;
        phase <= 0;
    end else begin
        count <= over ? count+step-{1'b0,den} : count+step;
        if(emit) phase <= ~phase;
        if(charge) missing <= missing+1'b1;
        if(recover) missing <= missing-1'b1;
    end
end

// Qualification includes write setup, but DTACK still requires a data strobe.
// Keep the old read timing: wait2 shifts out one Phi1 before wait3, and with
// WAIT1=1 wait2 aliases the base qualification instead of adding another wait.
always @(posedge clk) begin
    if(rst) begin
        waitsh <= 0;
        wait1 <= 0;
        ack_armed <= 0;
    end else if(!timing_active) begin
        wait1 <= 1;
        waitsh <= {wait3,wait2};
        ack_armed <= 0;
    end else begin
        if(cpu_cen || WAIT1==0) wait1 <= 0;
        if(cpu_cen) waitsh <= waitsh>>1;
        if(qualify) ack_armed <= 1;
    end
end

// Registered chip selects need one master clock after the data strobes.
// Until then bus_cs=0 cannot distinguish unmapped space from pending decode.
// Hold the qualified sampling phase through this setup as well as busy RAM.
always @(posedge clk) begin
    if(rst) strobe_l <= 0;
    else strobe_l <= !ASn && !(&DSn) && BGACKn;
end

always @(posedge clk) begin
    if(rst || ASn || &DSn || !BGACKn) DTACKn <= 1;
    else if(strobe_l && (ack_armed || qualify)) DTACKn <= DTACKn && bus_cs && bus_busy;
end

// Report phases actually delivered to fx68k, including their preserved
// alternation. Recovery only repays phases that were physically withheld.
jtframe_freqinfo #(.DIGITS(5),.MFREQ(MFREQ)) u_freq(
    .rst    ( rst               ),
    .clk    ( clk               ),
    .pulse  ( cpu_cen           ),
    .fave   ( { fave, nc1 }     ),
    .fworst ( { fworst, nc2 }   )
);

`ifdef SIMULATION
always @(posedge clk) if(!rst && charge && &missing) begin
    $display("FAIL: %m recovery counter overflow (CW=%0d)",CW);
    $finish;
end
`endif

endmodule
