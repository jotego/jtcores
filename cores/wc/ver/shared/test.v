module test;

reg         rst, clk, mx, sx;
wire        msw, ssw;
wire [10:0] sha;
wire		mseld, sseld, nowait;

assign mseld  = uut.msel;
assign sseld  = uut.ssel;
assign nowait = {msw,ssw}==0;

initial begin
	$dumpfile("test.lxt");
	$dumpvars;
	$dumpon;
end

initial begin
	clk = 0;
	forever clk = #10 ~clk;
end

initial begin
	rst = 1;
	mx  = 0;
	sx  = 0;
	repeat (5) @(posedge clk);
	rst = 0;
	// individual request
	@(posedge clk) assert(nowait);
	@(posedge clk) mx=1;
	@(posedge clk) assert(!mseld);
	@(posedge clk) begin assert(mseld); assert(nowait); end
	@(posedge clk) mx=0;
	@(posedge clk) sx=1;
	@(posedge clk) assert(!sseld);
	@(posedge clk) begin assert(sseld); assert(nowait); end
	@(posedge clk) sx=0;
	@(posedge clk) assert(nowait);
	// main req, then sub
	@(posedge clk) mx=1;
	@(posedge clk) assert(!mseld);
	@(posedge clk) begin assert(mseld); assert(nowait); end
	@(posedge clk) sx=1;
	@(posedge clk) begin assert(mseld); assert(!msw); end
	@(posedge clk) assert(ssw);
	@(posedge clk) mx=0;
	@(posedge clk) mx=0;
	@(posedge clk) begin assert(sseld); assert(nowait); end
	@(posedge clk) sx=0;
	@(posedge clk) assert(nowait);
	// sub, then main
	@(posedge clk) sx=1;
	@(posedge clk) assert(nowait);
	@(posedge clk) begin assert(sseld); assert(nowait); end
	@(posedge clk) mx=1;
	@(posedge clk);
	@(posedge clk) begin assert(sseld); assert(msw); assert(!ssw); end
	@(posedge clk) sx=0;
	@(posedge clk);
	@(posedge clk) begin assert(mseld); assert(nowait); end
	@(posedge clk) mx=0;
	@(posedge clk) assert(nowait);
	// both at the same time
	@(posedge clk) {mx,sx}=2'b11;
	@(posedge clk);
	@(posedge clk) begin assert(mseld); assert(!msw); assert(ssw); end
	@(posedge clk) mx=0;
	@(posedge clk);
	@(posedge clk) begin assert(sseld); assert(nowait); end
	@(posedge clk) sx=0;
	@(posedge clk) assert(nowait);
	repeat (10) @(posedge clk);
	// one after the other
	@(posedge clk) mx=1;
	@(posedge clk) assert(nowait);
	@(posedge clk) assert(mseld); {mx,sx}=2'b01; assert(nowait);
	@(posedge clk) assert(nowait);
	@(posedge clk) assert(sseld); sx=0; assert(nowait);
	repeat (10) @(posedge clk) assert(nowait);
	$finish;
end

wire mxd, sxd;

assign #1 mxd = mx;
assign #1 sxd = sx;

jtwc_shared uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    // main
    .ma         ( 11'd1			),
    .mdout      (  8'd0         ),
    .mwr_n      (  1'd1         ),
    .mxc8       (  1'd0         ),
    .mxd0       (  1'd0         ),
    .mxd8       (  1'd0         ),
    .mxe0       (  1'd0         ),
    .mxe8       ( mxd           ),
    .msw        ( msw           ),
    // sub
    .sa         ( 11'd2         ),
    .sdout      (  8'd0         ),
    .swr_n      (  1'd1         ),
    .sxc8       (  1'd0         ),
    .sxd0       (  1'd0         ),
    .sxd8       (  1'd0         ),
    .sxe0       (  1'd0         ),
    .sxe8       ( sxd           ),
    .ssw        ( ssw           ),
    // mux'ed
    .sha        ( sha           ),
    .sha_din    (               ),
    .shram_we   (               ),
    .pal_we     (               ),
    .fix_we     (               ),
    .obj_we     (               ),
    .scr_we     (               ),
    .shram_dout (  8'd0         ),
    .pal16_dout ( 16'd0         ),
    .fix16_dout ( 16'd0         ),
    .vram16_dout( 16'd0         ),
    .obj_dout   ( 16'd0         ),
    .sha_dout   (               ),
    // video scroll
    .scrx       (               ),
    .scry       (               )
);

endmodule