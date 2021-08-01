`timescale 1ns/1ps

module test;

localparam MAIN0_ADDR  = 22'h00000;
localparam MAIN1_ADDR  = 22'h20000;
localparam SND_ADDR    = 22'h40000;
localparam SND2_ADDR   = 22'h48000;
localparam CHAR_ADDR   = 22'h58000;
localparam MAP_ADDR    = 22'h60000;
// Scroll
localparam SCRZW_ADDR  = 22'h70000;
localparam SCRXY_ADDR  = 22'hF0000;
// even words
localparam OBJWZ_ADDR0 = 22'h170000;
localparam OBJXY_ADDR0 = 22'h190000;
// odd words
localparam OBJWZ_ADDR1 = 22'h1B0000;
localparam OBJXY_ADDR1 = 22'h1D0000;
// FPGA BRAM:
localparam PROM_ADDR   = 22'h1F0000;
// ROM length 1F0100

reg         rst;
reg         clk, downloading=1'b1;
reg  [21:0] ioctl_addr= 22'd0;
reg  [ 7:0] ioctl_dout= 8'd0;
reg         ioctl_wr;

wire [21:0] prog_addr;
wire [ 7:0] prog_data, game_cfg;
wire [ 1:0] prog_mask;
wire        prog_we, jap;
wire [`PROM_W-1:0] prom_we;
wire [15:0]        sdram_dout = 16'habcd;

reg  [ 3:0] random=4'd1;

always @(posedge clk) begin
    random <= { random[2:0], random[3]^random[2] };
end

reg         sdram_ack=1'b0, data_ok=1'b0;
reg         sdram_st;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        sdram_st <= 1'b0;
    end else begin
        sdram_ack <= 1'b0;
        data_ok   <= 1'b0;
        if( prog_we && random[0] && !sdram_st) begin
            sdram_st  <= 1'b1;
            sdram_ack <= 1'b1;
        end
        if( sdram_st && random[0] ) begin
            sdram_st <= 1'b0;
            data_ok  <= 1'b1;
        end
    end
end

jtsectionz_prom_we uut(
    .clk         ( clk           ),
    .downloading ( downloading   ),
    .ioctl_addr  ( ioctl_addr    ),
    .ioctl_dout  ( ioctl_dout    ),
    .ioctl_wr    ( ioctl_wr      ),
    .prog_addr   ( prog_addr     ),
    .prog_data   ( prog_data     ),
    .prog_mask   ( prog_mask     ),
    .prog_we     ( prog_we       ),
    .sdram_ack   ( sdram_ack     ),
    .game_cfg    ( game_cfg      )
);

always @(posedge jap) $display("JAP enabled");
always @(negedge jap) $display("JAP disabled");

wire [21:0] obj_addr;
wire [ 7:0] obj_data;
wire [ 1:0] obj_mask;
wire        obj_we;

initial begin
    clk = 1'b0;    
    forever #10 clk = ~clk;
end

initial begin
    rst = 1'b0;
    #7 rst = 1'b1;
    #7 rst = 1'b0;
end

reg [1:0] cnt=2'b0;
reg [7:0] romfile[0:`ROM_LEN-1];
integer f;

initial begin    
    f=$fopen(`ROM_PATH,"rb");
    if( f==0 ) begin
        $display("ERROR: cannot open file %s",`ROM_PATH);
        $finish;
    end
    cnt=$fread(romfile,f);
    $display("INFO: %s ROM lentgh 0x%h",`ROM_PATH,cnt);
    $fclose(f);
end

reg [15:0] sdram[0:2**22-1];
integer cnt2;
reg tx_done = 1'b0;

always @(posedge clk) begin
    cnt      <= cnt+2'd1;
    ioctl_wr <= 1'b0;
    if( ioctl_addr < `ROM_LEN && cnt==2'b10 ) begin
        ioctl_dout <= romfile[ioctl_addr];
        ioctl_wr   <= 1'b1;
    end else if(cnt==2'b11) begin
        ioctl_addr <= ioctl_addr + 22'd1;
    end else if( ioctl_addr >= `ROM_LEN && !tx_done) begin
        downloading <= 1'b0;
        f=$fopen("sdram.hex");
        for( cnt2=0; cnt2<(2**22-1); cnt2=cnt2+1) begin
            $fdisplay(f,"%04X",sdram[cnt2]);
        end
        $fclose(f);
        $display("INFO: SDRAM download done");
        tx_done <= 1'b1;
    end
end

reg last_busy;
always @(posedge clk) begin
    last_busy <= downloading;

    if( last_busy && !downloading ) begin
        $display("INFO: conversion finished");
        #500 $finish;
    end
end

always @(negedge prog_we) begin
    if(!prog_mask[1]) sdram[ prog_addr ][15:8] <= prog_data;
    if(!prog_mask[0]) sdram[ prog_addr ][ 7:0] <= prog_data;
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
    $dumpon;    
end

endmodule