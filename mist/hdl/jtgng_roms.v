`timescale 1ns/1ps

module jtgng_roms(
	input			clk,	// 72MHz
	input			clk6,	// 6MHz
	input	[17:0]	rom_addr,
	input	[13:0]	char_addr
);


localparam col_w = 9, row_w = 13;
localparam addr_w = 13, data_w = 16;

wire [data_w-1:0] 	Dq;
reg  [addr_w-1:0] 	addr;
reg cs_n, ras_n, cas_n, we_n;

reg  [col_w-1:0] col_cnt;
reg  [1:0] cl_cnt;

localparam	CMD_LOAD_MODE	= 4'b0000,
			CMD_AUTOREFRESH	= 4'b0001,
			CMD_PRECHARGE   = 4'b0010,
			CMD_ACTIVATE	= 4'b0011,
			CMD_READ		= 4'b0101,
			CMD_STOP		= 4'b0110,
			CMD_NOP			= 4'b0111,
			CMD_INHIBIT	 	= 4'b1000;

reg [3:0] state, next;

localparam INITIALIZE = 4'd0, IDLE=4'd1, WAIT_PRECHARGE=4'd2, ACTIVATE=4'd3,
			READ=4'd4, WAIT_CL=4'd5, READ_PAGE=4'd6, AUTO_REFRESH1=4'd7,
			AUTO_REFRESH2=4'd8, LOAD_MODE=4'd9, WAIT_AUTOREFRESH=4'd10,
			AUTO_REFRESH3=4'd11;

reg [2:0] precharge_cnt;

always @(posedge clk)
	if( rst ) begin
		state <= INITIALIZE;
		{ cs_n, ras_n, cas_n, we_n } <= CMD_INHIBIT;
		{ precharge_cnt, addr } <= {2'b0,{1+addr_w{1'b1}}};
		halt  <= 1'b1;
		ready <= 1'b0;
	end else 
	case( state )
		INITIALIZE: begin
			{ precharge_cnt, addr } <= { precharge_cnt, addr }-1'b1;
			if( !{ precharge_cnt, addr } ) begin
					{ cs_n, ras_n, cas_n, we_n } <= CMD_PRECHARGE;
					addr[10]=1'b1; // all banks
					precharge_cnt <= 3'b111;
					state <= WAIT_PRECHARGE;
					next <= AUTO_REFRESH1;
				end
		end
		AUTO_REFRESH1: begin 
			addr[3:0]=4'hf; // counter for auto refresh
			{ cs_n, ras_n, cas_n, we_n } <= CMD_AUTOREFRESH;
			next <= AUTO_REFRESH2;
			state <= WAIT_AUTOREFRESH;
		end
		AUTO_REFRESH2: begin 
			addr[3:0]=4'hf; // counter for auto refresh
			{ cs_n, ras_n, cas_n, we_n } <= CMD_AUTOREFRESH;
			next <= LOAD_MODE;
			state <= WAIT_AUTOREFRESH;
		end
		WAIT_AUTOREFRESH: begin
			addr[3:0] <= addr[3:0]-1'b1;
			{ cs_n, ras_n, cas_n, we_n } <= CMD_NOP;
			if( !addr[3:0] ) state <= next;
		end
		LOAD_MODE: begin 
			addr <= 13'b11_0_111; // CAS=3, Sequential, Full page burst
			{ cs_n, ras_n, cas_n, we_n } <= CMD_LOAD_MODE;
			precharge_cnt <= 3'b111;
			next  <= IDLE;
			state <= WAIT_PRECHARGE;
		end
		IDLE: begin
			if( start ) begin
				col_cnt <= {col_w{1'b1}};
				{ cs_n, ras_n, cas_n, we_n } <= CMD_PRECHARGE;
				precharge_cnt <= 3'b111;
				next  <= ACTIVATE;
				state <= WAIT_PRECHARGE;
				addr[10] <= 1'b0;
				ready <= 1'b0;
			end
			else begin
				{ cs_n, ras_n, cas_n, we_n } <= CMD_INHIBIT;
				ready <= 1'b1;
			end
			halt <= 1'b1;			
		end
		WAIT_PRECHARGE: begin
			{ cs_n, ras_n, cas_n, we_n } <= CMD_NOP;
			if( !precharge_cnt ) state<=next;
			precharge_cnt <= precharge_cnt-2'b1;
		end
		ACTIVATE: begin 
			{ cs_n, ras_n, cas_n, we_n } <= CMD_ACTIVATE;
			addr <= row;
			precharge_cnt <= 3'b011;
			next  <= READ;
			state <= WAIT_PRECHARGE;
		end
		READ:begin
			{ cs_n, ras_n, cas_n, we_n } <= CMD_READ;
			cl_cnt <= 2'd3;
			state <= WAIT_CL;
			addr <= {addr_w{1'b0}};
			end
		WAIT_CL: begin
			{ cs_n, ras_n, cas_n, we_n } <= CMD_NOP;
			cl_cnt <= cl_cnt-1'b1;
			if(!cl_cnt) begin
					state<=READ_PAGE;
					halt<=1'b0; // Data is not ready yet, but this allows the
					// cache to advance the address register. This is useful
					// because Altera memories always latch the address so
					// we need to provide the address one-clock in advance
				end
		end
		READ_PAGE: begin
			//halt <= 1'b0;
			dout <= Dq[7:0];
			col_cnt <= col_cnt-1'b1;
			if( !col_cnt ) begin
				{ cs_n, ras_n, cas_n, we_n }  <= CMD_PRECHARGE;
				precharge_cnt <= 3'b111;
				addr[10]=1'b1; // all banks
				state <= WAIT_PRECHARGE;
				next  <= AUTO_REFRESH3;
			end
		end
		AUTO_REFRESH3: begin 
			addr[3:0]=4'hf; // counter for auto refresh
			{ cs_n, ras_n, cas_n, we_n } <= CMD_AUTOREFRESH;
			next <= IDLE;
			state <= WAIT_AUTOREFRESH;
		end		
	endcase // state

wire clk_sdram = clk_B;

mt48lc16m16a2 mist_sdram (
	.Dq		( Dq		),
	.Addr   ( addr  	),
	.Ba		( 2'd0  	),
	.Clk	( clk_sdram	),
	.Cke	( 1'b1  	),
	.Cs_n   ( cs_n  	),
	.Ras_n  ( ras_n 	),
	.Cas_n  ( cas_n 	),
	.We_n   ( we_n  	),
	.Dqm	( 2'b00 	)
);


endmodule // jtgng_roms