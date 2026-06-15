`timescale 1ns / 1ps

module test;

localparam HW = 8;
localparam VW = 4;

reg              rst = 1'b1;
reg              clk = 1'b0;
reg              pxl_cen = 1'b0;
reg              lhbl = 1'b0;
reg              ln_done = 1'b0;
reg  [VW-1:0]    vrender = 0;
reg  [VW-1:0]    ln_v = 0;
reg              vs = 1'b0;
reg              frame = 1'b0;
reg              fb_blank = 1'b0;
reg  [15:0]      fb_din = 16'h1234;
reg              ddram_busy = 1'b0;
reg              ddram_dout_ready = 1'b1;
reg  [63:0]      ddram_dout = 64'h0;
reg  [7:0]       st_addr = 8'd0;

wire [HW-1:0]    fb_addr;
wire             fb_clr;
wire             fb_done;
wire [15:0]      fb_dout;
wire [HW-1:0]    rd_addr;
wire             line;
wire             scr_we;
wire             ddram_clk;
wire [7:0]       ddram_burstcnt;
wire [31:3]      ddram_addr;
wire             ddram_rd;
wire [63:0]      ddram_din;
wire [7:0]       ddram_be;
wire             ddram_we;
wire [7:0]       st_dout;

integer errors = 0;
integer cycle = 0;
integer write_seen = 0;
reg [VW-1:0] expected_v = 0;
reg [VW-1:0] got_v = 0;

`include "test_tasks.vh"

always #5 clk = ~clk;

jtframe_lfbuf_ddr_ctrl #(
    .VW(VW),
    .HW(HW)
) uut (
    .rst                ( rst                ),
    .clk                ( clk                ),
    .pxl_cen            ( pxl_cen            ),
    .lhbl               ( lhbl               ),
    .ln_done            ( ln_done            ),
    .vrender            ( vrender            ),
    .ln_v               ( ln_v               ),
    .vs                 ( vs                 ),
    .frame              ( frame              ),
    .fb_blank           ( fb_blank           ),
    .fb_addr            ( fb_addr            ),
    .fb_din             ( fb_din             ),
    .fb_clr             ( fb_clr             ),
    .fb_done            ( fb_done            ),
    .fb_dout            ( fb_dout            ),
    .rd_addr            ( rd_addr            ),
    .line               ( line               ),
    .scr_we             ( scr_we             ),
    .ddram_clk          ( ddram_clk          ),
    .ddram_busy         ( ddram_busy         ),
    .ddram_burstcnt     ( ddram_burstcnt     ),
    .ddram_addr         ( ddram_addr         ),
    .ddram_dout         ( ddram_dout         ),
    .ddram_dout_ready   ( ddram_dout_ready   ),
    .ddram_rd           ( ddram_rd           ),
    .ddram_din          ( ddram_din          ),
    .ddram_be           ( ddram_be           ),
    .ddram_we           ( ddram_we           ),
    .st_addr            ( st_addr            ),
    .st_dout            ( st_dout            )
);

always @(posedge clk) begin
    pxl_cen <= 1'b1;
    cycle <= cycle + 1;
end

task active;
    input integer n;
    integer i;
begin
    lhbl = 1'b1;
    for(i=0; i<n; i=i+1) @(posedge clk);
end
endtask

task blank;
    input integer n;
    integer i;
begin
    lhbl = 1'b0;
    for(i=0; i<n; i=i+1) @(posedge clk);
end
endtask

task pulse_done;
begin
    @(negedge clk);
    ln_done = 1'b1;
    @(posedge clk);
    @(negedge clk);
    ln_done = 1'b0;
end
endtask

always @(posedge clk) begin
    if( ddram_we && !write_seen ) begin
        write_seen = 1;
        got_v = uut.act_addr[HW+VW-1:HW];
        if( got_v !== expected_v ) begin
            $display("FAIL: write used ln_v=%0d expected latched ln_v=%0d act_addr=%h", got_v, expected_v, uut.act_addr);
            errors = errors + 1;
        end
    end
end

initial begin
    repeat(6) @(posedge clk);
    rst = 1'b0;

    // Establish hblank length and hlim with a complete warm-up line.
    active(96);
    blank(320);
    active(96);

    // Finish a line too late in active video for the controller to start
    // writing immediately. Then advance live ln_v before the next write slot.
    expected_v = 4'd5;
    ln_v = expected_v;
    repeat(80) @(posedge clk);
    pulse_done();
    ln_v = 4'd6;

    blank(320);
    active(360);

    if( !write_seen ) begin
        $display("FAIL: write was not observed");
        errors = errors + 1;
    end

    if( errors != 0 ) begin
        $display("FAIL: %0d errors", errors);
        $finish;
    end
    pass();
end

endmodule
