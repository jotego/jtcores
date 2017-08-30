`timescale 1ns/1ps

module jtgng_obj(
	input			clk,	// 6 MHz
	input			rst,
	output	reg	[8:0]	AB,
	input	[ 7:0]	DB,
	input			OKOUT,
	output	reg		bus_req,		// Request bus
	input			bus_ack,	// bus acknowledge
	output	reg		blen	// bus line counter enable
);

reg [1:0] bus_state;
reg	over96;

localparam ST_IDLE=2'd0, ST_WAIT=2'd1,ST_BUSY=2'd2;
localparam MEM_PREBUF=1'd0,MEM_BUF=1'd1;

always @(negedge clk) 
	if( rst ) begin
		blen <= 1'b0;
		bus_state <= ST_IDLE;
	end else begin
		case( bus_state )
			ST_IDLE: if( OKOUT ) begin
					bus_req <= 1'b1;
					bus_state <= ST_WAIT;
				end
				else begin
					bus_req <= 1'b0;
					blen <= 1'b0;
				end
			ST_WAIT: if( bus_ack && mem_sel == MEM_PREBUF ) begin
				blen <= 1'b1;
				bus_state <= ST_BUSY;
			end
			ST_BUSY: if( AB==9'h180 ) begin
				blen <= 1'b0;
				bus_req <= 1'b0;
				bus_state <= ST_IDLE;
			end
			default: bus_state <= ST_IDLE;
		endcase
	end

reg ABslow;
always @(negedge clk)
	if( !blen )
		{AB, ABslow} <= 9'd0;
	else begin
		{AB, ABslow} <= {AB, ABslow} + 1'b1;
	end

reg mem_sel;
always @(negedge clk)
	if(rst)
		mem_sel <= MEM_PREBUF;
	else begin
		mem_sel <= ~mem_sel;
	end


wire [9:0] 	wr_addr = mem_sel==MEM_PREBUF ? {1'b0, AB } : 9'd0; 
wire [9:0]	rd_addr = 9'd0;
wire [7:0] 	ram_din = mem_sel==MEM_PREBUF ? DB : 8'd0;
wire [7:0]	ram_dout;
wire 		ram_we	= mem_sel==MEM_PREBUF ? blen : 1'b0;

jtgng_objram objram (
	.clock 		( clk		 	),
	.data 		( ram_din 		),
	.rdaddress 	( rd_addr		),
	.wraddress 	( wr_addr		),
	.wren 		( ram_we 		),
	.q 			( ram_dout 		)
);

endmodule // jtgng_char