module test;

`define SIMULATION

reg clk;

initial begin
	clk = 0;
	forever #10 clk = ~clk;
end

`ifdef ROTATE
wire [1:0] rotate = 2'b01;
`else
`ifdef FLIP
wire [1:0] rotate = 2'b11;
`else
wire [1:0] rotate = 2'b00;
`endif
`endif

wire [7:0] r,g,b;
wire de_out, osd_status;

reg io_osd, io_strobe=1'b0;
reg [15:0] io_din;

always @(posedge clk)
	io_strobe <= ~io_strobe;

localparam WIDTH =500;
localparam HEIGHT=300;

reg [23:0] frame_buffer[WIDTH*HEIGHT];

integer hcnt=0, vcnt=0, frame_cnt=0, pxl_cnt=0;

always @(posedge clk) begin : video_drv
	integer file, aux1,aux2;

	hcnt <= hcnt < WIDTH-1 ? hcnt+1 : 0;
	pxl_cnt <= pxl_cnt+1;
	if( hcnt==WIDTH-1 ) begin
		vcnt <= vcnt < HEIGHT-1 ? vcnt+1 : 0;
		if( vcnt==HEIGHT-1) begin
			frame_cnt <= frame_cnt + 1;
			if( frame_cnt==3 ) begin
				file = $fopen("video_dump.m","w");
				for( aux2=0; aux2<HEIGHT; aux2++) begin
					for( aux1=0; aux1<WIDTH; aux1++) begin
						$fwrite(file,"%1d ", frame_buffer[aux2*WIDTH+aux1]);
					end
					$fwrite(file,"\n");
				end
				$fclose(file);
				$finish;
			end
			pxl_cnt <= 0;
		end
	end
end

// blanking
wire hb = !(hcnt>19 && hcnt<WIDTH-20);
wire vb = !(vcnt>9 && vcnt<HEIGHT-10);
// Data enable time
wire de_in = !hb && !vb;

always @(posedge clk)
	frame_buffer[pxl_cnt] <= {r,g,b};

osd dut(
	.clk_sys	( clk	     ),
	.io_osd	    ( io_osd     ),
	.io_strobe  ( io_strobe  ),
	.io_din		( io_din     ),
	.rotate     ( rotate     ),

	.clk_video	( clk      	 ),
	.din		( 24'd0      ),
	.dout		( {r,g,b}    ),
	.de_in		( de_in      ),
	.de_out     ( de_out     ),
	.osd_status ( osd_status )
);

`ifdef DUMP
initial begin
    $dumpfile("test.lxt");	
	$dumpvars;	
	//#1000_000 $finish;
end
`endif

integer cnt;

initial begin
	io_osd    = 1'b0;
	io_din    = 16'd0;
	cnt		  = 0;
	#100;
	io_osd    = 1'b1;
	io_din    = 16'h41; // Display OSD
	#40
	io_osd    = 1'b0;	// OSD gets enabled when io_osd goes down
	#1000;
end

endmodule