`timescale 1ns / 1ps

module test;

parameter BANK1=1, BANK2=1, BANK3=1,
          IDLE=50, SHIFTED=0, MAXA=21;

`ifndef PERIOD
`define PERIOD 10
`endif

`ifndef WRITE_ENABLE
`define WRITE_ENABLE 1
`endif

`ifndef WRITE_CHANCE
`define WRITE_CHANCE 5
`endif

localparam PERIOD=`PERIOD;
localparam IDLE1=BANK1 ? IDLE : 200,
           IDLE2=BANK2 ? IDLE : 200,
           IDLE3=BANK3 ? IDLE : 200;

localparam HF = PERIOD<15.5;

reg        rst, clk, init_done, waiting;

wire [21:0] ba0_addr, ba1_addr, ba2_addr, ba3_addr;
wire [ 1:0] ba0_din_m;

wire [31:0] dout;
wire        ba0_rd, ba1_rd, ba2_rd, ba3_rd, ba0_wr,
            ba0_rdy, ba1_rdy, ba2_rdy, ba3_rdy,
            ba0_ack, ba1_ack, ba2_ack, ba3_ack,
            rfsh_en;
wire [15:0] ba0_din;
wire        all_ack;
reg         start;

// sdram pins
wire [15:0] sdram_dq;
wire [12:0] sdram_a;
wire [ 1:0] sdram_dqm;
wire [ 1:0] sdram_ba;
wire        sdram_nwe;
wire        sdram_ncas;
wire        sdram_nras;
wire        sdram_ncs;
wire        sdram_cke;

reg  [63:0] data_cnt, ticks;

// Latency
wire [31:0] lat0_best, lat0_worst, lat0_ave,
            lat1_best, lat1_worst, lat1_ave,
            lat2_best, lat2_worst, lat2_ave,
            lat3_best, lat3_worst, lat3_ave;

assign all_ack = ba0_ack | ba1_ack | ba2_ack | ba3_ack;

`ifdef NOREFRESH
assign rfsh_en = 0;
`else
assign rfsh_en = 1;
`endif

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        data_cnt <= 64'd0;
        ticks    <= 64'd0;
        start    <= 0;
    end else begin
        if(start)
            ticks <= ticks+1'd1;
        if( all_ack )
            start <= 1;
        if( ba0_rdy || ba1_rdy || ba2_rdy || ba3_rdy )
            data_cnt <= data_cnt+1'd1;
    end
end

ba_requester #(0, `WRITE_ENABLE,"sdram_bank0.hex", IDLE, `WRITE_CHANCE, MAXA) u_ba0(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .ba_addr    ( ba0_addr      ),
    .ba_rd      ( ba0_rd        ),
    .ba_wr      ( ba0_wr        ),
    .ba_dout    ( ba0_din       ),
    .ba_dout_m  ( ba0_din_m     ),
    .ba_rdy     ( ba0_rdy       ),
    .ba_ack     ( ba0_ack       ),
    .sdram_dq   ( dout          ),
    // Latency
    .start      ( start         ),
    .lat_best   ( lat0_best     ),
    .lat_worst  ( lat0_worst    ),
    .lat_ave    ( lat0_ave      )
);

ba_requester #(1, 0,"sdram_bank1.hex", IDLE1, 0, MAXA ) u_ba1(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .ba_addr    ( ba1_addr      ),
    .ba_rd      ( ba1_rd        ),
    .ba_rdy     ( ba1_rdy       ),
    .ba_ack     ( ba1_ack       ),
    .sdram_dq   ( dout          ),
    // unused ports
    .ba_wr      (               ),
    .ba_dout    (               ),
    .ba_dout_m  (               ),
    // Latency
    .start      ( start         ),
    .lat_best   ( lat1_best     ),
    .lat_worst  ( lat1_worst    ),
    .lat_ave    ( lat1_ave      )
);

ba_requester #(2, 0,"sdram_bank2.hex", IDLE2, 0, MAXA ) u_ba2(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .ba_addr    ( ba2_addr      ),
    .ba_rd      ( ba2_rd        ),
    .ba_rdy     ( ba2_rdy       ),
    .ba_ack     ( ba2_ack       ),
    .sdram_dq   ( dout          ),
    // unused ports
    .ba_wr      (               ),
    .ba_dout    (               ),
    .ba_dout_m  (               ),
    // Latency
    .start      ( start         ),
    .lat_best   ( lat2_best     ),
    .lat_worst  ( lat2_worst    ),
    .lat_ave    ( lat2_ave      )
);


ba_requester #(3, 0,"sdram_bank3.hex", IDLE3, 0, MAXA ) u_ba3(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .ba_addr    ( ba3_addr      ),
    .ba_rd      ( ba3_rd        ),
    .ba_rdy     ( ba3_rdy       ),
    .ba_ack     ( ba3_ack       ),
    .sdram_dq   ( dout          ),
    // unused ports
    .ba_wr      (               ),
    .ba_dout    (               ),
    .ba_dout_m  (               ),
    // Latency
    .start      ( start         ),
    .lat_best   ( lat3_best     ),
    .lat_worst  ( lat3_worst    ),
    .lat_ave    ( lat3_ave      )
);

jtframe_sdram_bank #(.AW(22),.HF(HF),.SHIFTED(SHIFTED)) uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    // Bank 0: allows R/W
    .ba0_addr   ( ba0_addr      ),
    .ba0_rd     ( ba0_rd        ),
    .ba0_wr     ( ba0_wr        ),
    .ba0_din    ( ba0_din       ),
    .ba0_din_m  ( ba0_din_m     ),  // write mask
    .ba0_rdy    ( ba0_rdy       ),
    .ba0_ack    ( ba0_ack       ),

    // Bank 1: Read only
    .ba1_addr   ( ba1_addr      ),
    .ba1_rd     ( ba1_rd        ),
    .ba1_rdy    ( ba1_rdy       ),
    .ba1_ack    ( ba1_ack       ),

    // Bank 2: Read only
    .ba2_addr   ( ba2_addr      ),
    .ba2_rd     ( ba2_rd        ),
    .ba2_rdy    ( ba2_rdy       ),
    .ba2_ack    ( ba2_ack       ),

    // Bank 3: Read only
    .ba3_addr   ( ba3_addr      ),
    .ba3_rd     ( ba3_rd        ),
    .ba3_rdy    ( ba3_rdy       ),
    .ba3_ack    ( ba3_ack       ),

    // ROM downloading
    .prog_en    ( 1'b0          ),
    .prog_addr  (               ),
    .prog_ba    (               ),  // bank
    .prog_rd    (               ),
    .prog_wr    (               ),
    .prog_din   (               ),
    .prog_din_m (               ),  // write mask
    .prog_rdy   (               ),
    // SDRAM pins
    .sdram_dq   ( sdram_dq      ),
    .sdram_a    ( sdram_a       ),
    .sdram_dqml ( sdram_dqm[0]  ),
    .sdram_dqmh ( sdram_dqm[1]  ),
    .sdram_ba   ( sdram_ba      ),
    .sdram_nwe  ( sdram_nwe     ),
    .sdram_ncas ( sdram_ncas    ),
    .sdram_nras ( sdram_nras    ),
    .sdram_ncs  ( sdram_ncs     ),
    .sdram_cke  ( sdram_cke     ),
    // Common signals
    .dout       ( dout          ),
    .rfsh_en    ( rfsh_en       )
);

reg clk_sdram;

initial begin
    clk=0;
    forever begin
        #(PERIOD/2) clk=~clk;
        #(`SDRAM_SHIFT) clk_sdram = clk;
    end
end

mt48lc16m16a2 sdram(
    .Clk        ( clk_sdram ),
    .Cke        ( sdram_cke ),
    .Dq         ( sdram_dq  ),
    .Addr       ( sdram_a   ),
    .Ba         ( sdram_ba  ),
    .Cs_n       ( sdram_ncs ),
    .Ras_n      ( sdram_nras),
    .Cas_n      ( sdram_ncas),
    .We_n       ( sdram_nwe ),
    .Dqm        ( sdram_dqm ),
    .downloading( 1'b0      ),
    .VS         ( 1'b0      ),
    .frame_cnt  ( 0         )
);


`ifdef SIM_TIME
localparam SIM_TIME = `SIM_TIME;
`else
localparam SIM_TIME = 5_000_000;
`endif

real perf;

initial begin
    $display("Simulation begins HF=%d",HF);
    rst=1;
    #100 rst=0;
    #SIM_TIME;
    perf = data_cnt*2; // 2 read cycles per each data_cnt
    perf = perf / ticks;
    $display("Performance %.1f%% (%0dx2 / %0d)", perf*100.0, data_cnt, ticks );
    perf = perf / `PERIOD;
    perf = perf *2.0* 1e9/1024.0/1024.0; // 2 bytes per read cycle
    $display("Data throughput %.0f MB/s (at %.0f MHz)", perf, 1e3/`PERIOD );
    $display("Latency\nBank\tBest\tAve\tWorst");
    $display("  0\t%2d\t%2d",lat0_best, lat0_ave, lat0_worst);
    $display("  1\t%2d\t%2d",lat1_best, lat1_ave, lat1_worst);
    $display("  2\t%2d\t%2d",lat2_best, lat2_ave, lat2_worst);
    $display("  3\t%2d\t%2d",lat3_best, lat3_ave, lat3_worst);
    $display("PASSED");
    $finish;
end

`ifdef DUMP
initial begin
    $dumpfile("test.lxt");
    $dumpvars;
end
`endif

endmodule


module  ba_requester(
    input               rst,
    input               clk,
    output reg [21:0]   ba_addr,
    output reg          ba_rd,
    output reg          ba_wr,
    output reg [15:0]   ba_dout,
    output reg [ 1:0]   ba_dout_m,
    input               ba_rdy,
    input               ba_ack,
    input      [31:0]   sdram_dq,
    // latency measurement
    input               start,
    output reg [31:0]   lat_worst,
    output reg [31:0]   lat_best,
    output reg [31:0]   lat_ave
);

parameter BANK=0, RW=0, MEMFILE="sdram_bank1.hex",
          IDLE=50, WRCHANCE=5, MAXA=21; // Use 100 or more to keep the bank idle

localparam STALL_LIMIT = (5000*`PERIOD)/7;

reg [31:0] data_read;
reg [15:0] mem_data[0:4*1024*1024-1];
reg        waiting, init_done;
reg        rd_cycle, first;
integer    stall, lat_acc, cycles;

wire [31:0] expected = { mem_data[ba_addr+1], mem_data[ba_addr] };
wire [15:0] expected_low = mem_data[ba_addr];
wire [15:0] wr_masked = { ba_dout_m[1] ? expected_low[15:8] : ba_dout[15:8],
                          ba_dout_m[0] ? expected_low[ 7:0] : ba_dout[ 7:0] };

initial begin
    if( IDLE<100 ) $readmemh( MEMFILE, mem_data );
    init_done = 0;
    #104_500 init_done = 1;
end

initial begin
    #200_000;
    if( first && IDLE<100 ) begin
        $display("Bank %d stall without any access",BANK);
        $finish;
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ba_addr  <= 22'd0;
        ba_rd    <= 0;
        ba_wr    <= 0;
        waiting  <= 0;
        rd_cycle <= 0;
        stall    <= 0;
        lat_best <= ~0;
        lat_worst<= 0;
        first    <= 1;
        lat_acc  <= 0;
        cycles   <= 1;
    end else if(init_done) begin
        if( ba_rdy ) begin
            first <= 0;
            if( ba_rd || ba_wr ) begin
                $display("Ready signal received without previous ACK signal in bank %1d at time %t ns \n",BANK, $time);
                $finish;
            end
            data_read <= sdram_dq;
            if( sdram_dq !== expected && rd_cycle) begin
                $display("Data read error at time %t at address %X (bank %1d). %X read, expected %X\n",
                    $time, ba_addr, BANK, sdram_dq, expected );
                #(2*`PERIOD) $finish;
            end
        end
        if( !waiting || ba_rdy ) begin
            if( IDLE==0 || $random%100 >= IDLE ) begin
                ba_addr[MAXA:1] <= $random; // bit 0 not used for bursts of length 2
                if( $random%100>(100-WRCHANCE) && RW) begin
                    ba_rd      <= 0;
                    ba_wr      <= 1;
                    ba_dout    <= $random;
                    ba_dout_m  <= $random;
                    rd_cycle   <= 0;
                end else begin
                    ba_rd    <= 1;
                    ba_wr    <= 0;
                    rd_cycle <= 1;
                end
                waiting  <= 1;
                stall    <= 1;
            end else begin
                rd_cycle  <= 0;
                waiting   <= 0;
            end
            if( ba_rdy && !first) begin
                if( lat_best  > stall ) lat_best  <= stall;
                if( lat_worst < stall ) lat_worst <= stall;
                lat_acc <= lat_acc + stall;
                cycles  <= cycles + 1;
                lat_ave <= lat_acc / cycles;
            end
        end else begin
            stall <= stall + 1;
            if( stall== STALL_LIMIT) begin
                $display("Bank %1d stall at time %t\n", BANK,$time );
                $finish;
            end
            if( ba_ack ) begin
                if( ba_wr ) begin
                    mem_data[ ba_addr ] <= wr_masked;
                end
                ba_rd <= 0;
                ba_wr <= 0;
            end
        end
    end
end

endmodule
