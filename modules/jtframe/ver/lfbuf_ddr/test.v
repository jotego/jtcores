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

wire          lf_ddram_clk;
wire  [7:0]   lf_ddram_burstcnt;
wire [28:0]   lf_ddram_addr;
wire          lf_ddram_rd;
wire [63:0]   lf_ddram_din;
wire  [7:0]   lf_ddram_be;
wire          lf_ddram_we;
wire          lf_ddram_busy;
wire          lf_ddram_dout_ready;
wire          lfbuf_rst;

reg           ddram_busy=0;
wire          ddram_dout_ready;
reg  [63:0]   ddram_dout=0;
reg  [ 7:0]   ddram_cnt=0;

reg           ioctl_rom=0;
reg  [ 7:0]   ddrld_burstcnt=8'd4;
reg  [28:0]   ddrld_addr=29'h01_2345;
reg           ddrld_rd=0;
wire          ddrld_busy;

reg [HW-1:0] ln_addr=0;
reg [DW-1:0] ln_data=0;
reg          ln_done=0;
reg          ln_we=0;

wire          ln_hs, ln_vs, ln_lvbl;
wire [DW-1:0] ln_dout;
wire [DW-1:0] ln_pxl;
wire [VW-1:0] ln_v;

wire pxl_cen = pxlcnt==0;

integer framecnt=0;
reg download_done=0, saw_loader_own=0, saw_lf_blocked=0, saw_lf_resume=0;

assign lfbuf_rst = rst | ioctl_rom;

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
    #100_000_000;
    $display("FAIL timeout");
    $finish;
end

initial begin
    wait(!rst);
    repeat(12000) @(posedge clk);
    ioctl_rom <= 1;
    repeat(64) begin
        wait(!ddrld_busy);
        ddrld_addr <= ddrld_addr + 1'd1;
        ddrld_rd   <= 1;
        @(posedge clk);
        ddrld_rd   <= 0;
        repeat(3) @(posedge clk);
    end
    wait(!ddrld_busy);
    ddrld_rd <= 1;
    @(posedge clk);
    ddrld_rd <= 0;
    repeat(8) @(posedge clk);
    ioctl_rom     <= 0;
    download_done <= 1;
end

always @(posedge VS) begin
    framecnt <= framecnt+1;
    if( framecnt==6 ) begin
        if( !saw_loader_own ) begin
            $display("FAIL DDR loader never owned the mux");
            $finish;
        end
        if( !saw_lf_blocked ) begin
            $display("FAIL line buffer was not blocked during DDR load");
            $finish;
        end
        if( !saw_lf_resume ) begin
            $display("FAIL line buffer did not resume after DDR load");
            $finish;
        end
        $display("PASS");
        $finish;
    end
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

assign lf_ddram_dout_ready = lf_ddram_busy ? 1'b0 : ddram_dout_ready;

always @(posedge clk) begin
    if( !rst ) begin
        if( ioctl_rom && (ddram_we || (ddram_rd && ddram_addr!=ddrld_addr)) ) begin
            $display("FAIL line-buffer command reached DDR during download");
            $finish;
        end
        if( ioctl_rom && !ddrld_busy && ddram_rd ) begin
            saw_loader_own <= 1;
        end
        if( ioctl_rom && lf_ddram_busy ) begin
            saw_lf_blocked <= 1;
        end
        if( download_done && !lf_ddram_busy && (lf_ddram_rd || lf_ddram_we) &&
            ddram_addr==lf_ddram_addr ) begin
            saw_lf_resume <= 1;
        end
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
    .rst        ( lfbuf_rst ),     // hold in reset for >150 us
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    // video status
    .vrender    (vrender[7:0]),
    .hdump      ( hdump     ),
    .hs         ( HS        ),
    .vs         ( VS        ),
    .lhbl       ( LHBL      ),
    .lvbl       ( LVBL      ),

    // core interface
    .ln_addr    ( ln_addr   ),
    .ln_data    ( ln_data   ),
    .ln_done    ( ln_done   ),
    .ln_hs      ( ln_hs     ),
    .ln_dout    ( ln_dout   ),
    .ln_pxl     ( ln_pxl    ),
    .ln_v       ( ln_v      ),
    .ln_vs      ( ln_vs     ),
    .ln_lvbl    ( ln_lvbl   ),
    .ln_we      ( ln_we     ),

    // DDR3 RAM
    .ddram_clk      ( lf_ddram_clk      ),
    .ddram_busy     ( lf_ddram_busy     ),
    .ddram_burstcnt ( lf_ddram_burstcnt ),
    .ddram_addr     ( lf_ddram_addr     ),
    .ddram_dout     ( ddram_dout        ),
    .ddram_dout_ready( lf_ddram_dout_ready ),
    .ddram_rd       ( lf_ddram_rd       ),
    .ddram_din      ( lf_ddram_din      ),
    .ddram_be       ( lf_ddram_be       ),
    .ddram_we       ( lf_ddram_we       ),
    // Status
    .st_addr        ( 8'h80             ),
    .st_dout        (                   )
);

jtframe_mr_ddrmux u_ddrmux(
    .rst            ( rst                 ),
    .clk            ( clk                 ),
    .ioctl_rom      ( ioctl_rom           ),
    // Fast DDR load
    .ddrld_burstcnt ( ddrld_burstcnt      ),
    .ddrld_addr     ( ddrld_addr          ),
    .ddrld_rd       ( ddrld_rd            ),
    .ddrld_busy     ( ddrld_busy          ),
    // Video DDR client
    .rot_clk        ( lf_ddram_clk        ),
    .rot_burstcnt   ( lf_ddram_burstcnt   ),
    .rot_addr       ( lf_ddram_addr       ),
    .rot_rd         ( lf_ddram_rd         ),
    .rot_we         ( lf_ddram_we         ),
    .rot_be         ( lf_ddram_be         ),
    .rot_din        ( lf_ddram_din        ),
    .rot_busy       ( lf_ddram_busy       ),
    // DDR Signals
    .ddr_clk        ( ddram_clk           ),
    .ddr_busy       ( ddram_busy          ),
    .ddr_burstcnt   ( ddram_burstcnt      ),
    .ddr_addr       ( ddram_addr          ),
    .ddr_rd         ( ddram_rd            ),
    .ddr_we         ( ddram_we            ),
    .ddr_be         ( ddram_be            ),
    .ddr_din        ( ddram_din           )
);

endmodule
