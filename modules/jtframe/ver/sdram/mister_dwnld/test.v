`timescale 1ns/1ps

module test;

reg rst, clk;

initial begin
    rst = 0;
    #10 rst = 1;
    #40 rst = 0;
end

initial begin
    clk = 0;
    forever #10 clk=~clk;
end

// jtframe_mister_dwnld's outputs
wire downloading, hps_wait,
     ioctl_rom_wr, ioctl_ram,
     ddram_rd;

wire [26:0] ioctl_addr;
wire [ 7:0] ioctl_dout;
wire [ 6:0] core_mod;
wire [31:0] dipsw;

wire [ 7:0] ddram_burstcnt;
wire [28:0] ddram_addr;

// DDRAM model
reg  [63:0] ddram_dout;
reg         ddram_dout_ready;
integer     ddram_lag, burst;

// core programmer model
reg       dwnld_busy;
wire      prog_we, prog_rdy;
reg [9:0] prog_sh;

// hps model
wire hps_download;

// simulation ticks
integer ticks=0;
always @(posedge clk) ticks<=ticks+1;

assign hps_download = ticks==10;

// programmer model
assign prog_we  = |prog_sh;
assign prog_rdy = prog_sh[9];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dwnld_busy <= 0;
        prog_sh  <= 10'd0;
    end else begin
        prog_sh <= prog_sh<<1;
        if( ioctl_rom_wr ) begin
            if( ioctl_addr<27'h3FFF ) begin
                dwnld_busy <= 1;
                prog_sh[0] <= 1;
            end else begin
                dwnld_busy <= 0;
            end
        end
    end
end

// DDRAM model
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ddram_dout_ready <= 0;
        ddram_dout <= 64'd0;
        burst <= 0;
    end else begin
        if( ddram_lag>0 ) ddram_lag <= ddram_lag-1;
        if( ddram_rd ) begin
            ddram_lag        <= $random&7;
            ddram_dout_ready <= 0;
            burst            <= ddram_burstcnt;
        end else begin
            if( ddram_lag==0 && burst>0 ) begin
                ddram_dout       <= { $random, $random };
                ddram_dout_ready <= 1;
                burst            <= burst-1;
            end else begin
                ddram_dout_ready <= 0;
            end
        end
    end
end

jtframe_mister_dwnld uut(
    .rst            (   rst         ),
    .clk            (   clk         ),

    .downloading    ( downloading   ),
    .dwnld_busy     ( dwnld_busy    ),

    .prog_we        ( prog_we       ),
    .prog_rdy       ( prog_rdy      ),

    .hps_download   ( hps_download  ), // signal indicating an active download
    .hps_index      ( 8'h0          ),        // menu index used to upload the file
    .hps_wr         ( 1'b0          ),
    .hps_addr       ( 27'd0         ),         // in WIDE mode address will be incremented by 2
    .hps_dout       (  8'd0         ),
    .hps_wait       ( hps_wait      ),

    .ioctl_rom_wr   ( ioctl_rom_wr  ),
    .ioctl_ram      ( ioctl_ram     ),
    .ioctl_addr     ( ioctl_addr    ),
    .ioctl_dout     ( ioctl_dout    ),

    // Configuration
    .core_mod       ( core_mod      ),
    .status         ( 32'd0         ),
    .dipsw          ( dipsw         ),

    // DDR3 RAM
    .ddram_busy    ( 1'b0           ),
    .ddram_burstcnt( ddram_burstcnt ),
    .ddram_addr    ( ddram_addr     ),
    .ddram_dout    ( ddram_dout     ),
    .ddram_dout_ready( ddram_dout_ready ),
    .ddram_rd      ( ddram_rd       )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    #4100_000 $finish;
end

endmodule
