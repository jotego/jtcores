`timescale 1ns / 1ps

module test;

parameter BANK1=1, BANK2=1, BANK3=1,
          IDLE=80, SHIFTED=0, MAXA=21;
parameter BA0_LEN=64, BA1_LEN=64, BA2_LEN=64, BA3_LEN=64;
parameter BA0_AUTOPRECH=0, BA1_AUTOPRECH=0, BA2_AUTOPRECH=0, BA3_AUTOPRECH=0;

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

localparam HF = PERIOD<15.5; // 64 MHz

reg        rst, clk, init_done, waiting;

wire [21:0] ba0_addr, ba1_addr, ba2_addr, ba3_addr;
wire [ 1:0] ba0_din_m;

wire [15:0] dout;
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

wire [ 3:0] dok;
wire        init, rst_req;

wire        hblank;
integer     hcnt;

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

assign rst_req = rst | init;

// horizontal line counter
localparam [31:0] HMAX=64_000/PERIOD;
assign hblank = hcnt==0 && rfsh_en;

initial $display("HMAX=%d",HMAX);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hcnt <= 0;
    end else begin
        hcnt <= hcnt == (HMAX-1) ? 0 : (hcnt+1);
    end
end

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

ba_requester #(0, BA0_LEN, `WRITE_ENABLE,"sdram_bank0.bin", IDLE, `WRITE_CHANCE, MAXA) u_ba0(
    .rst        ( rst_req       ),
    .clk        ( clk           ),
    .ba_addr    ( ba0_addr      ),
    .ba_rd      ( ba0_rd        ),
    .ba_wr      ( ba0_wr        ),
    .ba_dout    ( ba0_din       ),
    .ba_dout_m  ( ba0_din_m     ),
    .ba_rdy     ( ba0_rdy       ),
    .ba_ack     ( ba0_ack       ),
    .ba_dok     ( dok[0]        ),
    .sdram_dq   ( dout          ),
    // Latency
    .start      ( start         ),
    .lat_best   ( lat0_best     ),
    .lat_worst  ( lat0_worst    ),
    .lat_ave    ( lat0_ave      )
);

ba_requester #(1, BA1_LEN, 0,"sdram_bank1.bin", IDLE1, 0, MAXA ) u_ba1(
    .rst        ( rst_req       ),
    .clk        ( clk           ),
    .ba_addr    ( ba1_addr      ),
    .ba_rd      ( ba1_rd        ),
    .ba_rdy     ( ba1_rdy       ),
    .ba_ack     ( ba1_ack       ),
    .ba_dok     ( dok[1]        ),
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

ba_requester #(2, BA2_LEN, 0,"sdram_bank2.bin", IDLE2, 0, MAXA ) u_ba2(
    .rst        ( rst_req       ),
    .clk        ( clk           ),
    .ba_addr    ( ba2_addr      ),
    .ba_rd      ( ba2_rd        ),
    .ba_rdy     ( ba2_rdy       ),
    .ba_ack     ( ba2_ack       ),
    .ba_dok     ( dok[2]        ),
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


ba_requester #(3, BA3_LEN, 0,"sdram_bank3.bin", IDLE3, 0, MAXA ) u_ba3(
    .rst        ( rst_req       ),
    .clk        ( clk           ),
    .ba_addr    ( ba3_addr      ),
    .ba_rd      ( ba3_rd        ),
    .ba_rdy     ( ba3_rdy       ),
    .ba_ack     ( ba3_ack       ),
    .ba_dok     ( dok[3]        ),
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

wire [3:0] rd, wr, rdy, ack;

assign rd = {ba3_rd, ba2_rd, ba1_rd, ba0_rd };
assign wr = { 3'd0, ba0_wr };
assign {ba3_rdy,ba2_rdy,ba1_rdy,ba0_rdy} = rdy;
assign {ba3_ack,ba2_ack,ba1_ack,ba0_ack} = ack;

jtframe_sdram64 #(
    .AW     ( 22      ),
    .HF     ( HF      ),
    .SHIFTED( SHIFTED ),
    .BA0_LEN( BA0_LEN ),
    .BA1_LEN( BA1_LEN ),
    .BA2_LEN( BA2_LEN ),
    .BA3_LEN( BA3_LEN ),
    .BA0_AUTOPRECH( BA0_AUTOPRECH ),
    .BA1_AUTOPRECH( BA1_AUTOPRECH ),
    .BA2_AUTOPRECH( BA2_AUTOPRECH ),
    .BA3_AUTOPRECH( BA3_AUTOPRECH )
) uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .rfsh       ( hblank        ),
    .init       ( init          ),

    // Bank 0: allows R/W
    .ba0_addr   ( ba0_addr      ),
    .ba1_addr   ( ba1_addr      ),
    .ba2_addr   ( ba2_addr      ),
    .ba3_addr   ( ba3_addr      ),
    .rd         ( rd            ),
    .wr         ( wr            ),
    .ba0_din    ( ba0_din       ),
    .ba0_dsn    ( ba0_din_m     ),  // write mask
    .ba1_din    (               ),
    .ba1_dsn    (               ),  // write mask
    .ba2_din    (               ),
    .ba2_dsn    (               ),  // write mask
    .ba3_din    (               ),
    .ba3_dsn    (               ),  // write mask
    .rdy        ( rdy           ),
    .dok        ( dok           ),
    .ack        ( ack           ),

    .prog_en    ( 1'd0          ),

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
    .dout       ( dout          )
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
    $display("Bank lengths: %2d, %2d, %2d, %2d",BA0_LEN, BA1_LEN, BA2_LEN, BA3_LEN );
    rst=1;
    #100 rst=0;
    #SIM_TIME;
    perf = data_cnt*4; // 4 read cycles per each data_cnt
    perf = perf / ticks;
    $display("Performance %.1f%% (%0dx4 / %0d)", perf*100.0, data_cnt, ticks );
    perf = perf / `PERIOD;
    perf = perf *2.0* 1e9/1024.0/1024.0; // 2 bytes per effective clock cycle
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
    input               ba_dok,
    input      [15:0]   sdram_dq,
    // latency measurement
    input               start,
    output reg [31:0]   lat_worst,
    output reg [31:0]   lat_best,
    output reg [31:0]   lat_ave
);

// Careful with the parameter order!
parameter BANK=0, DW=64, RW=0, MEMFILE="sdram_bank1.bin",
          IDLE=50, WRCHANCE=5, MAXA=21; // Use 100 or more to keep the bank idle

localparam STALL_LIMIT = (5000*`PERIOD)/7;

reg [DW-1:0] data_read;
reg [15:0] mem_data[0:4*1024*1024-1];
reg        waiting, init_done;
reg        rd_cycle, first;
integer    stall, lat_acc, cycles;

wire [DW-1:0] expected = { mem_data[ba_addr+3],mem_data[ba_addr+2], mem_data[ba_addr+1], mem_data[ba_addr] };
wire [15:0] expected_low = mem_data[ba_addr];
wire [15:0] wr_masked = { ba_dout_m[1] ? expected_low[15:8] : ba_dout[15:8],
                          ba_dout_m[0] ? expected_low[ 7:0] : ba_dout[ 7:0] };
wire [DW-1:0] next_data;
integer file, fcnt;

initial begin
    if( IDLE<100 ) begin
        file=$fopen(MEMFILE,"rb");
        if( file==0 ) begin
            $display("Error: cannot open file %s (%m)", MEMFILE );
        end
        fcnt=$fread(mem_data, file );
        // $display("Read 0x%X bytes from %s (%m)", fcnt, MEMFILE );
        $fclose(file);
    end
    init_done = 0;
    #104_500 init_done = 1;
end

initial begin
    #200_000;
    if( first && IDLE<100 ) begin
        $display("Bank %d stall without any access.\nFAIL\n",BANK);
        $finish;
    end
end

assign next_data = DW==16 ? sdram_dq : { sdram_dq, data_read[DW-1:(DW>16?16:0)] };

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
        if( ba_dok ) data_read <= next_data;
        if( ba_rdy ) begin
            first <= 0;
            if( ba_rd || ba_wr ) begin
                $display("Ready signal received without previous ACK signal in bank %1d at time %t ns \nFAIL\n",BANK, $time);
                $finish;
            end
            if( next_data !== expected && rd_cycle) begin
                $display("Data read error at time %t at address %X (bank %1d). %X read, expected %X\nFAIL\n",
                    $time, ba_addr, BANK, next_data, expected );
                #(2*`PERIOD) $finish;
            end
        end
        if( !waiting || ba_rdy ) begin
            if( IDLE==0 || $random%100 >= IDLE ) begin
                if( DW==64 )
                    ba_addr[MAXA:2] <= $random; // bits 1:0 not used for bursts of length 4
                else if(DW==32)
                    ba_addr[MAXA:1] <= $random; // bit 0 not used for bursts of length 2
                else if(DW==16)
                    ba_addr[MAXA:0] <= $random;
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
                $display("Bank %1d stall at time %t\nFAIL\n", BANK,$time );
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
