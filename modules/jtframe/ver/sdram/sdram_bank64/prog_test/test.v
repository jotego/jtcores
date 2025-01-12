`timescale 1ns / 1ps

module test;

parameter BANK1=1, BANK2=1, BANK3=1,
          IDLE=50, SHIFTED=0, MAXA=21;
parameter BA0_LEN=64, BA1_LEN=64, BA2_LEN=64, BA3_LEN=64;

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
wire        hblank;
integer     hcnt;

assign all_ack = ba0_ack | ba1_ack | ba2_ack | ba3_ack;

`ifdef NOREFRESH
assign rfsh_en = 0;
`else
assign rfsh_en = 1;
`endif

localparam HMAX=64_000/PERIOD;
assign hblank = hcnt==0;

// horizontal line counter
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hcnt <= 0;
    end else begin
        hcnt <= hcnt == HMAX-1 ? 0 : (hcnt+1);
    end
end

reg         ioctl_rom;
reg  [25:0] ioctl_addr;
wire [ 7:0] ioctl_dout;
wire        ioctl_wr;
wire [21:0] prog_addr;
wire [15:0] prog_data;
wire [ 1:0] prog_mask;
wire        prog_we;
wire        prog_rd;
wire [ 1:0] prog_ba;
wire        prom_we;
wire        header;
wire        sdram_ack;

// ROW download
reg [28:0] lfsr;
reg [ 4:0] timer;

assign ioctl_dout = lfsr[7:0];
assign ioctl_wr   = timer==0;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        lfsr <= 1;

        ioctl_addr <= 0;
        timer      <= 31;
        ioctl_rom <= 0;
    end else begin
        if( sdram_ack )
            lfsr <= { lfsr[0], lfsr[28], lfsr[27]^lfsr[0], lfsr[26:1] };
        timer <= timer-1;
        if( timer==1 ) begin
            ioctl_addr <= ioctl_addr+1;
            ioctl_rom <= 1;
            if( &ioctl_addr ) begin
                $display("All 32MB written");
                $finish;
            end
        end
    end
end

jtframe_sdram64 #(
    .AW     ( 22      ),
    .HF     ( HF      ),
    .SHIFTED( SHIFTED ),
    .BA0_LEN( BA0_LEN ),
    .BA1_LEN( BA1_LEN ),
    .BA2_LEN( BA2_LEN ),
    .BA3_LEN( BA3_LEN )
) uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .rfsh       ( hblank        ),
    .init       (               ),
    // Bank 0: allows R/W
    .ba0_addr   (               ),
    .ba1_addr   (               ),
    .ba2_addr   (               ),
    .ba3_addr   (               ),
    .rd         ( 4'd0          ),
    .wr         ( 4'd0          ),
    .ba0_din    (               ),
    .ba0_dsn    (               ),  // write mask
    .ba1_din    (               ),
    .ba1_dsn    (               ),  // write mask
    .ba2_din    (               ),
    .ba2_dsn    (               ),  // write mask
    .ba3_din    (               ),
    .ba3_dsn    (               ),  // write mask
    .rdy        (               ),
    .dok        (               ),
    .ack        (               ),

    .prog_en    ( ioctl_rom     ),
    .prog_addr  ( prog_addr     ),
    .prog_rd    ( prog_rd       ),
    .prog_wr    ( prog_we       ),
    .prog_din   ( prog_data     ),
    .prog_dsn   ( prog_mask     ),
    .prog_ba    ( prog_ba       ),
    .prog_dst   (               ),
    .prog_dok   (               ),
    .prog_rdy   ( sdram_ack     ),

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

jtframe_dwnld #(
    .BA1_START( 25'h1_000 ),
    .BA2_START( 25'h2_000 ),
    .BA3_START( 25'h3_000 )
) u_dwnld(
    .clk        ( clk           ),
    .ioctl_rom  ( ioctl_rom     ),
    .ioctl_addr ( ioctl_addr    ),
    .ioctl_dout ( ioctl_dout    ),
    .ioctl_wr   ( ioctl_wr      ),
    .prog_addr  ( prog_addr     ),
    .prog_data  ( prog_data     ),
    .prog_mask  ( prog_mask     ), // active low
    .prog_we    ( prog_we       ),
    .prog_rd    ( prog_rd       ),
    .prog_ba    ( prog_ba       ),
    .prom_we    ( prom_we       ),
    .header     ( header        ),
    .sdram_ack  ( sdram_ack     )
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
