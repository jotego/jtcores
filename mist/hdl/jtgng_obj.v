`timescale 1ns/1ps

module jtgng_obj(
	input			clk,	// 6 MHz
	input			rst,
	// screen
	input			HINIT,
	input			LVBL,
	input	[ 7:0]	V,
	input	[ 8:0]	H,
	input			flip,
	// shared bus
	output	reg	[8:0]	AB,
	input	[ 7:0]	DB,
	input			OKOUT,
	output	reg		bus_req,		// Request bus
	input			bus_ack,	// bus acknowledge
	output	reg		blen,	// bus line counter enable
	// SDRAM interface
	output	reg [13:0] obj_addr,
	input		[31:0] objrom_data
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
			ST_WAIT: if( bus_ack && mem_sel == MEM_PREBUF && !LVBL ) begin
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
reg  [8:0]	pre_scan;
wire [7:0] 	ram_din = mem_sel==MEM_PREBUF ? DB : 8'd0;
wire [7:0]	ram_dout;
wire 		ram_we	= mem_sel==MEM_PREBUF ? blen : 1'b0;

jtgng_objram objram (
	.clock 		( clk		 	),
	.data 		( ram_din 		),
	.rdaddress 	( pre_scan		),
	.wraddress 	( wr_addr		),
	.wren 		( ram_we 		),
	.q 			( ram_dout 		)
);

reg line;
localparam lineA=1'b0, lineB=1'b1;
reg [4:0] post_scan;
reg fill;
reg line_obj_we;
reg [1:0] trf_state, trf_next;

wire [7:0] VF = {8{flip}} ^ V;
wire [7:0] VFx = {8{flip}} ^ (V+8'd8);

localparam SEARCH=2'd1, WAIT=2'd2, TRANSFER=2'd3, FILL=2'd0;

always @(negedge clk) 
	if( rst )
		line <= lineA;
	else if( HINIT ) line <= ~line;


always @(negedge clk) 
	if( rst ) begin
		trf_state <= SEARCH;
		line_obj_we <= 1'b0;
	end
	else begin
		case( trf_state )
			SEARCH: begin
				if( !LVBL ) begin
					pre_scan <= 9'd2;
					post_scan<= 5'd8;
					fill <= 1'd0;
				end
				else begin
					line_obj_we <= 1'b0;
					if( ram_dout[7:5] == VFx[7:5] ) begin
						pre_scan[1:0] <= 2'd0;
						trf_next  <= TRANSFER;
						trf_state <= WAIT;
					end
					else begin
						if( pre_scan>=9'h17E ) begin
							trf_next  <= FILL;
							trf_state <= WAIT;
							pre_scan <= 9'h180;
							fill <= 1'b1;
						end else begin
							pre_scan <= pre_scan + 3'd4;
							trf_state <= WAIT;
							trf_next  <= SEARCH;
						end
					end
				end
			end
			WAIT: begin
				trf_state <= trf_next;
				if( trf_next==TRANSFER || trf_next==FILL ) line_obj_we <= 1'b1;
			end
			TRANSFER: begin
				line_obj_we <= 1'b0;
				if( pre_scan[1:0]==2'b11 ) begin
					post_scan <= post_scan+1'b1;
					pre_scan <= pre_scan + 2'd3;
					trf_state <= SEARCH;
				end
				else begin
					pre_scan[1:0] <= pre_scan[1:0]+1'b1;
					trf_state <= WAIT;
				end
			end
			FILL: begin
				pre_scan <= pre_scan + 1'b1;
				if( pre_scan[1:0]==2'b11 ) post_scan <= post_scan + 1'b1;
				trf_next <= FILL;
				if( &{ post_scan, pre_scan[1:0] } ) begin
					pre_scan <= 9'd2;
					post_scan<= 5'd8;
					fill <= 1'd0;
					trf_state <= WAIT;
					trf_next <= SEARCH;
					line_obj_we <= 1'b0;
				end
				else begin
					line_obj_we <= 1'b0;
					trf_state <= WAIT;
				end
			end
		endcase
	end


wire [6:0] hscan = { H[8:4], H[2:1] };
wire [7:0] q_a, q_b;
wire [7:0] objbuf_data = line==lineA ? q_b : q_a;

reg [7:0] ADlow;
reg [1:0] objpal;
reg [7:0] objy, objx;
wire [3:0] VB=4'd0;

always @(negedge clk)
	case( H[2:1] )
		2'd0: ADlow <= objbuf_data;
		2'd1: begin
			obj_addr <= { objbuf_data[7:6], ADlow, H[3], VB };
			objpal  <= objbuf_data[5:4];
		end
		2'd2: objy <= objbuf_data;
		2'd3: objx <= objbuf_data;
	endcase

reg [9:0] address_a, address_b;
reg we_a, we_b;
reg [7:0] data_a, data_b;

always @(*)
	if( line == lineA ) begin
		address_a = { post_scan, pre_scan[1:0] };
		address_b = hscan;
		we_a = line_obj_we;
		we_b = 1'b0;
		data_a = fill ? 8'hff : ram_dout;
		data_b = 8'hff;
	end
	else begin
		address_a = hscan;
		address_b = { post_scan, pre_scan[1:0] };
		we_a = 1'b0;
		we_b = line_obj_we;
		data_a = 8'hff;
		data_b = fill ? 8'hff : ram_dout;
	end

jtgng_objbuf objbuf(
	.address_a	( address_a ),
	.address_b	( address_b ),
	.clock		( clk	 	),
	.data_a		( data_a 	),
	.data_b		( data_b 	),
	.wren_a		( we_a	 	),
	.wren_b		( we_b	 	),
	.q_a		( q_a 		),
	.q_b		( q_b 		)
);

endmodule // jtgng_char