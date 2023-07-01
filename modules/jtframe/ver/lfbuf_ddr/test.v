`timescale 1ns/1ps

module test;

localparam DW=16,HW=9,VW=8;

reg rst, clk;
reg [2:0] pxlcnt=0;

wire [8:0] vdump, vrender,vrender1, hdump;
wire Hinit, Vinit, LHBL, LVBL, HS, VS;

wire          ddram_clk;
wire  [7:0]   ddram_burstcnt;
wire [28:0]   ddram_addr;
wire          ddram_rd;
wire [63:0]   ddram_din;
wire  [7:0]   ddram_be;
wire          ddram_we;

reg           ddram_busy=0;
wire          ddram_dout_ready;
reg  [63:0]   ddram_dout=0;
reg  [ 7:0]   ddram_cnt=0;

reg [HW-1:0] ln_addr=0;
reg [DW-1:0] ln_data=0;
reg          ln_done=0;
reg          ln_we=0;

wire          ln_hs;
wire [DW-1:0] ln_pxl;
wire [VW-1:0] ln_v;

wire pxl_cen = pxlcnt==0;

integer framecnt=0;

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

initial begin
    clk = 0;
    forever #5 clk=~clk;
end

initial begin
    rst = 1;
    # 25;
    rst = 0;
    #100_000_000 $finish;
end

always @(posedge VS) begin
    framecnt <= framecnt+1;
    if( framecnt==6 ) $finish;
end

always @(posedge clk) begin
    pxlcnt <= pxlcnt+1'd1;
end

integer objcnt=0;
reg ln_hsl;

always @(posedge clk) begin
    ln_hsl <= ln_hs;
    objcnt <= objcnt + 1;
    ln_done <= 0;
    if( objcnt==400 && ln_v<224 ) begin
        ln_done <= 1;
    end
    if( ln_hs && !ln_hsl ) objcnt  <= 0;
    if( VS ) begin
        objcnt  <= 0;
    end
end

reg ddram_rdl;
assign ddram_dout_ready = ddram_cnt!=0 && ddram_cnt<=ddram_burstcnt;

always @(posedge clk) begin
    ddram_rdl  <= ddram_rd;
    ddram_busy <= $random%10 < 2;
    if( ddram_cnt!=0 ) ddram_cnt <= ddram_cnt-1'd1;
    if( ddram_rd && !ddram_rdl ) begin
        ddram_cnt <= ddram_burstcnt+8'd7; // it will work for bursts 7 counts smaller than the maximum
    end
end

jtframe_vtimer u_vtimer (
    .clk     (clk     ),
    .pxl_cen (pxl_cen ),
    .vdump   (vdump   ),
    .vrender (vrender ), // TODO: Check connection ! Incompatible port direction (not an input)
    .vrender1(vrender1),
    .H       ( hdump  ),
    .Hinit   (Hinit   ),
    .Vinit   (Vinit   ),
    .LHBL    (LHBL    ),
    .LVBL    (LVBL    ),
    .HS      (HS      ),
    .VS      (VS      )
);

jtframe_lfbuf_ddr uut(
    .rst        ( rst       ),     // hold in reset for >150 us
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    // video status
    .vrender    (vrender[7:0]),
    .hdump      ( hdump     ),
    .vs         ( VS        ),
    .lhbl       ( LHBL      ),
    .lvbl       ( LVBL      ),

    // core interface
    .ln_addr    ( ln_addr   ),
    .ln_data    ( ln_data   ),
    .ln_done    ( ln_done   ),
    .ln_hs      ( ln_hs     ),
    .ln_pxl     ( ln_pxl    ),
    .ln_v       ( ln_v      ),
    .ln_we      ( ln_we     ),

    // DDR3 RAM
    .ddram_clk      ( ddram_clk         ),
    .ddram_busy     ( ddram_busy        ),
    .ddram_burstcnt ( ddram_burstcnt    ),
    .ddram_addr     ( ddram_addr        ),
    .ddram_dout     ( ddram_dout        ),
    .ddram_dout_ready( ddram_dout_ready ),
    .ddram_rd       ( ddram_rd          ),
    .ddram_din      ( ddram_din         ),
    .ddram_be       ( ddram_be          ),
    .ddram_we       ( ddram_we          ),
    // Status
    .st_addr        ( 8'h80             ),
    .st_dout        (                   )
);

endmodule