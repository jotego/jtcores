`timescale 1ns/1ps

module jtgng_rom(
	input			clk,	
	input			rst,
	input	[12:0]	char_addr,
	input	[17:0]	main_addr,
	input	[14:0]	snd_addr,
	input	[14:0]	obj_addr,
	input	[15:0]	scr_addr,
	//input	[ 7:0]	din,

	output	reg	[15:0]	char_dout,
	output	reg	[ 7:0]	main_dout,
	output	reg	[ 7:0]	snd_dout,
	output	reg	[15:0]	obj_dout,
	output	reg	[23:0]	scr_dout,
	output	reg			ready
);

localparam col_w = 9, row_w = 13;
localparam addr_w = 13, data_w = 16;
localparam false=1'b0, true=1'b1;

wire [data_w-1:0] 	Dq;
reg  [addr_w-1:0] 	addr, row_addr;
reg  [col_w-1:0] col_cnt, col_addr;

reg [3:0] rd_state;
reg	read_done, autorefresh;

wire [(row_w+col_w-1):0] full_addr = {row_addr,col_addr};
wire [(row_w+col_w-1-12):0] top_addr = full_addr>>12;

always @(posedge clk)
	if( rst ) begin
		rd_state <= 0;
		autorefresh <= false;
		{row_addr, col_addr} <= { 8'b110, snd_addr };
	end
	else if( read_done ) begin
		// state 10 (autorefresh) lasts twice as long as the others
		// Get data from current read
		case(rd_state)
			4'd0, 4'd3, 4'd6, 4'd9: snd_dout <= Dq[7:0];
			4'd1, 4'd7: main_dout <= Dq[7:0];
			4'd2: char_dout <= Dq;
			4'd4: scr_dout[15:0] <= Dq;
			4'd5: scr_dout[23:0] <= Dq[7:0];
			4'd8: obj_dout <= Dq;
		endcase
		// Set ADDR for next read
		case(rd_state)
			4'd10, 4'd2, 4'd5, 4'd8: 
						{row_addr, col_addr} <= { 4'b00, 3'b110,  snd_addr }; // 14:0
			4'd0, 4'd6: {row_addr, col_addr} <= { 4'b00,         main_addr }; // 17:0
			4'd7: 		{row_addr, col_addr} <= { 4'b01, 3'b010,  obj_addr }; // 14:0
			4'd1: 		{row_addr, col_addr} <= { 4'b10, 4'b000, char_addr }; // 12:0
			4'd3: 		{row_addr, col_addr} <= { 4'b01, 2'b10,   scr_addr }; // 15:0 B/C ROMs
			4'd4: 		{row_addr, col_addr} <= { 4'b01, 2'b11,   scr_addr }; // 15:0 E ROMs
		endcase	
		// auto refresh request
		case(rd_state)	
			4'd8: autorefresh <= true;
			default: autorefresh <= false;
		endcase
		rd_state <= rd_state==4'd10 ? 4'd0: rd_state+4'b1;
	end

reg cs_n, ras_n, cas_n, we_n;

reg  [1:0] cl_cnt;

localparam	CMD_LOAD_MODE	= 4'b0000,
			CMD_AUTOREFRESH	= 4'b0001,
			CMD_PRECHARGE   = 4'b0010,
			CMD_ACTIVATE	= 4'b0011,
			CMD_READ		= 4'b0101,
			CMD_STOP		= 4'b0110,
			CMD_NOP			= 4'b0111,
			CMD_INHIBIT	 	= 4'b1000;

reg [3:0] state, next, init_state;

localparam INITIALIZE = 4'd0, IDLE=4'd1, WAIT=4'd2, ACTIVATE=4'd3,
			READ=4'd4, WAIT_CL=4'd5, SET_READ=4'd6, AUTO_REFRESH1=4'd7,
			SET_PRECHARGE = 4'd8;

reg [3:0] wait_cnt;
localparam PRECHARGE_WAIT = 4'd1, ACTIVATE_WAIT=4'd0, CL_WAIT=4'd1;

wire [3:0] mem_cmd = { cs_n, ras_n, cas_n, we_n };

always @(posedge clk)
	if( rst ) begin
		state <= INITIALIZE;
		init_state <= 4'd0;
		{ cs_n, ras_n, cas_n, we_n } <= CMD_INHIBIT;
		{ wait_cnt, addr } <= 8400;
		read_done <= false;
		ready <= false;
	end else 
	case( state )
		default: state <= SET_PRECHARGE;
		INITIALIZE: begin
			case(init_state)
				4'd0: begin	// wait for 100us
					{ cs_n, ras_n, cas_n, we_n } <= CMD_NOP;
					{ wait_cnt, addr } <= { wait_cnt, addr }-1'b1;
					if( !{ wait_cnt, addr } ) 
						init_state <= init_state+4'd1;
					end
				4'd1: begin
					{ cs_n, ras_n, cas_n, we_n } <= CMD_PRECHARGE;
					addr[10]=1'b1; // all banks
					wait_cnt <= PRECHARGE_WAIT;
					state <= WAIT;
					next <= INITIALIZE;
					init_state <= init_state+4'd1;
					end
				4'd2,4'd3: begin
					{ cs_n, ras_n, cas_n, we_n } <= CMD_AUTOREFRESH;
					wait_cnt <= 4'd10;
					state <= WAIT;
					next <= INITIALIZE;
					init_state <= init_state+4'd1;
					end
				4'd4: begin
					{ cs_n, ras_n, cas_n, we_n } <= CMD_LOAD_MODE;
					addr <= 12'b00_1_00_011_0_000;
					wait_cnt <= 4'd2;
					state <= WAIT;
					next <= SET_PRECHARGE;
					init_state <= 0;
					ready <= true;
					end
			endcase
			end
		SET_PRECHARGE: begin
			{ cs_n, ras_n, cas_n, we_n } <= CMD_PRECHARGE;
			addr[10]=1'b1; // all banks
			wait_cnt <= PRECHARGE_WAIT;
			state <= WAIT;
			next <= autorefresh ? AUTO_REFRESH1 : ACTIVATE;		
			read_done <= false;
			end
		WAIT: begin
			{ cs_n, ras_n, cas_n, we_n } <= CMD_NOP;
			if( !wait_cnt ) state<=next;
			wait_cnt <= wait_cnt-2'b1;
			end
		ACTIVATE: begin 
			{ cs_n, ras_n, cas_n, we_n } <= CMD_ACTIVATE;
			addr <= row_addr;
			wait_cnt <= ACTIVATE_WAIT;
			next  <= SET_READ;
			state <= WAIT;
			end		
		SET_READ:begin
			{ cs_n, ras_n, cas_n, we_n } <= CMD_READ;
			wait_cnt <= CL_WAIT;
			state <= WAIT;
			next  <= READ;
			addr <= { {(addr_w-col_w){1'b0}}, col_addr};
			end		
		READ: begin
			read_done <= true;
			state <=  SET_PRECHARGE;
			end
		AUTO_REFRESH1: begin
			{ cs_n, ras_n, cas_n, we_n } <=	CMD_AUTOREFRESH;
			wait_cnt <= 4'd12;
			state <= WAIT;
			next <= READ; // just to generate the read_done
			end
	endcase // state

mt48lc16m16a2 mist_sdram (
	.Dq		( Dq		),
	.Addr   ( addr  	),
	.Ba		( 2'd0  	),
	.Clk	( clk		),
	.Cke	( 1'b1  	),
	.Cs_n   ( cs_n  	),
	.Ras_n  ( ras_n 	),
	.Cas_n  ( cas_n 	),
	.We_n   ( we_n  	),
	.Dqm	( 2'b00 	)
);


endmodule // jtgng_rom