/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-5-2021 */

/*
    Generate DTACK and alternating fx68k enables at num/den CPU clocks per
    master clock. At an artificial SDRAM wait, hold the S4 DTACK-sampling
    Phi2 and all following CPU phases until acknowledgement is ready.
    Recovery replays only divider events physically withheld by that hold.

    bus_legit and bus_ack keep the CPU phases running at nominal rate and
    exclude both debt creation and recovery. WAIT1/wait2/wait3 qualification
    also runs on nominal phases; once armed, DTACK can complete on a master
    clock without requiring the held CPU to advance.

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
    input         ASn,  // DTACKn set low at the next cpu_cen after ASn goes low
    input [1:0]   DSn,  // If DSn goes high, DTACKn is reset high
    input [W-2:0] num,  // numerator
    input [W-1:0] den,  // denominator
    input         wait2, // high for 2 wait states
    input         wait3, // high for 3 wait states

    output reg    DTACKn,
    output  [15:0] fave, // average cpu_cen frequency in kHz
    output  [15:0] fworst  // average cpu_cen frequency in kHz
);
localparam CW=W+WD;

reg [W:0]    count=0;
reg [CW-1:0] missing=0;
reg [1:0]    waitsh;
reg          phase=0, active_phi1=0, wait1, ack_armed;
wire [W:0]   step;
wire         over, hold_cpu, recover, emit, charge, ack_ready, board_wait;
wire [3:0]   nc1, nc2;

assign step = {1'b0,num,1'b0};
assign over = count > {1'b0,den}-step;
assign ack_ready = ack_armed || (WAIT1==0 && waitsh==0);
assign board_wait = !ASn && !(&DSn) &&
                    (waitsh!=0 || (WAIT1!=0 && !ack_armed));
// AS falls on Phi1 entering S2. Allow the next Phi1 to enter S4, then
// hold its DTACK-sampling Phi2. Do not stop setup, a TAS strobe gap, a
// legitimate board wait, or the clocks needed by bus-grant handshakes.
assign hold_cpu = !ASn && !(&DSn) && bus_cs && DTACKn && ack_ready &&
                  !bus_legit && !bus_ack && active_phi1 && !phase;
assign recover = RECOVERY!=0 && missing!=0 && !over && !hold_cpu &&
                 !bus_ack && !bus_legit && !board_wait && !rst;
assign emit = !rst && !hold_cpu && (over || recover);
assign charge = RECOVERY!=0 && over && hold_cpu;
assign cpu_cen = emit && phase;
assign cpu_cenb = emit && !phase;

always @(posedge clk) begin
    if(rst || ASn) active_phi1 <= 0;
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

always @(posedge clk) begin
    if(rst) begin
        DTACKn <= 1;
        waitsh <= 0;
        wait1 <= 0;
        ack_armed <= 0;
    end else if(ASn || &DSn) begin
        DTACKn <= 1;
        wait1 <= 1;
        waitsh <= {wait3,wait2};
        ack_armed <= 0;
    end else begin
        if(cpu_cen || WAIT1==0) begin
            wait1 <= 0;
            if(cpu_cen) waitsh <= waitsh>>1;
            if(waitsh==0 && !wait1) begin
                ack_armed <= 1;
                DTACKn <= DTACKn && bus_cs && bus_busy;
            end
        end
        if(ack_armed) DTACKn <= DTACKn && bus_cs && bus_busy;
    end
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
