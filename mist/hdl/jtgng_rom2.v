`timescale 1ns/1ps

module jtgng_rom2(
	input			clk,
	input			clk_pxl,	
	input			rst,
	input	[12:0]	char_addr,
	input	[16:0]	main_addr,
	input	[14:0]	snd_addr,
	input	[14:0]	obj_addr,
	input	[14:0]	scr_addr,
	input			main_cs,
	// input			bank_sw,
	input			snd_cs,
	input			LHBL,
	input	[2:0]	HS,

	// write interface
	input	[15:0]	din,
	input	[12:0]  wr_row,
	input	[ 8:0]	wr_col,
	input			we,

	output	reg	[15:0]	char_dout,
	output	reg	[ 7:0]	main_dout,
	output	reg	[ 7:0]	snd_dout,
	output	reg	[31:0]	obj_dout,
	output	reg	[23:0]	scr_dout_pxl,
	output	reg			ready,

	// SDRAM interface
	inout [15:0]  	SDRAM_DQ, 		// SDRAM Data bus 16 Bits
	output reg [12:0] 	SDRAM_A, 		// SDRAM Address bus 13 Bits
	output        	SDRAM_DQML, 	// SDRAM Low-byte Data Mask
	output        	SDRAM_DQMH, 	// SDRAM High-byte Data Mask
	output  reg    	SDRAM_nWE, 		// SDRAM Write Enable
	output  reg    	SDRAM_nCAS, 	// SDRAM Column Address Strobe
	output  reg    	SDRAM_nRAS, 	// SDRAM Row Address Strobe
	output  reg    	SDRAM_nCS, 		// SDRAM Chip Select
	output [1:0]  	SDRAM_BA, 		// SDRAM Bank Address
	output        	SDRAM_CKE, 		// SDRAM Clock Enable	
	// ROM load
	input			downloading,
	input	[24:0]	romload_addr,
	input	[15:0]	romload_data,
	input			romload_wr,
	output	[31:0]	crc_out	
);

assign SDRAM_DQMH = 1'b0;
assign SDRAM_DQML = 1'b0;
assign SDRAM_BA   = 2'b0;
assign SDRAM_CKE  = 1'b1;

reg romload_wr16;

localparam col_w = 9, row_w = 13;
localparam addr_w = 13, data_w = 16;
localparam false=1'b0, true=1'b1;

reg  [addr_w-1:0] 	row_addr;
reg  [col_w-1:0] col_cnt, col_addr;
reg [addr_w-1:0] romload_row;
reg [col_w-1:0]  romload_col;

reg [1:0] rd_state;
reg	read_done;
reg rq_autorefresh, rq_autorefresh_aux;

wire [(row_w+col_w-1):0] full_addr = {row_addr,col_addr};
wire [(row_w+col_w-1-12):0] top_addr = full_addr>>12;

reg SDRAM_WRITE;
assign SDRAM_DQ =  SDRAM_WRITE ? 
	( romload_wr16 ? romload_data : din ) : 
	16'hzzzz;

reg crc_en;

crc32 crc32_chk (.data_in(romload_data), .crc_en(crc_en), .crc_out(crc_out), .rst(rst), .clk(clk));
reg [15:0] scr_aux;


reg [12:0]	char_addr_last;
reg [14:0]	obj_addr_last;
reg [14:0]	scr_addr_last;
// do not keep LSB:
reg [14:0]	main_addr_last;
reg [13:0]	snd_addr_last;

reg [15:0]	snd_cache, main_cache0, main_cache1;
reg rd_req; // read request

reg [2:0] gra_state;
reg rd_collect, main_valid;
reg collect_msb;
localparam ST_SND=2'd0, ST_MAIN=2'd1, ST_GRAPH=2'd2, ST_REFRESH=2'd3;
localparam ST_CHAR=3'd0, ST_SCR=3'b010, ST_SCRHI=3'b110, ST_OBJ=3'b001, ST_OBJHI=3'b101;

// reg bank_sw_sync;
reg clk_pxl_edge;
reg [1:0] clk_pxl_aux;

reg	[12:0]	char_addr_sync;
reg	[16:0]	main_addr_sync;
//reg	[14:0]	snd_addr_sync,
reg	[14:0]	obj_addr_sync;
reg	[14:0]	scr_addr_sync;
reg main_cs_sync;
reg	[23:0]	scr_dout;

localparam	scr_addr_stage = 3'd3,
			scr_dout_stage = 3'd5;

always @(posedge clk) begin 
	clk_pxl_aux <= { clk_pxl_aux[0], clk_pxl };
	clk_pxl_edge <= clk_pxl_aux[1] && !clk_pxl_aux[0];
	if( clk_pxl_edge ) begin // negedge
		main_cs_sync <= main_cs;
		main_addr_sync <= main_addr;
		char_addr_sync <= char_addr;
		obj_addr_sync <= obj_addr;
		// bank_sw_sync <= bank_sw;
		//case( HS[2:0] )
		//	scr_addr_stage: scr_addr_sync <= scr_addr;
		//	//scr_dout_stage:	scr_dout_pxl <= scr_dout;
		//endcase
		scr_addr_sync <= scr_addr;
		scr_dout_pxl <= scr_dout;
	end
end

reg skip_refresh;

always @(posedge clk)
	if( rst ) begin
		rd_state <= ST_SND;
		rd_collect <= 1'b0;
		gra_state <= ST_CHAR;
		rq_autorefresh <= false;
		{row_addr, col_addr} <= { 8'b110, snd_addr };
		char_addr_last	<= ~13'd0;
		// main_addr_last	<= 15'd0;
		snd_addr_last	<= 15'd0;
		obj_addr_last	<= ~15'd0;
		scr_addr_last	<= ~15'd0;
		main_valid <= false;
		skip_refresh <= false;		
	end
	else begin
	// if( bank_sw_sync ) main_valid <= false;
	if( !downloading && read_done && !rd_req ) begin
		if( rd_collect ) begin // collects data
			case( rd_state )
				ST_MAIN: if(!collect_msb) begin					
					main_cache0 <= SDRAM_DQ;	
					collect_msb <= 1'b1;		
				end else begin
					main_cache1 <= SDRAM_DQ;
					collect_msb <= 1'b0;
					main_valid <= true;
					rd_collect <= 1'b0;
				end
				ST_GRAPH: begin
					case( gra_state )
						ST_CHAR: begin
							// rd_state <= ST_SND;
							char_dout <= SDRAM_DQ;
							rd_collect <= 1'b0;
							gra_state <= ST_SCR;
						end
						ST_SCR: begin
							scr_aux <= SDRAM_DQ;
							gra_state <= ST_SCRHI;
						end
						ST_SCRHI: begin
							rd_collect <= 1'b0;
							scr_dout <= { SDRAM_DQ[7:0], scr_aux };
							rd_state <= ST_SND;
							gra_state <= ST_OBJ;
						end
						ST_OBJ: begin
							gra_state <= ST_OBJHI;
							scr_aux <= SDRAM_DQ;
						end
						ST_OBJHI: begin
							rd_state <= ST_SND;
							rd_collect <= 1'b0;
							if( LHBL ) gra_state <= ST_CHAR; else gra_state <= ST_OBJ;
							obj_dout <= { SDRAM_DQ, scr_aux };
						end
					endcase
				end
				default: begin
					rd_collect <= 1'b0;
					rd_state <= ST_MAIN;
				end
			endcase
		end else			
		case( rd_state )
			ST_SND: rd_state <= ST_MAIN; // No audio for now
			ST_MAIN: if( main_cs_sync ) begin
				if( (main_addr_sync>>2)==main_addr_last && main_valid ) begin
					case( main_addr_sync[1:0] )
						2'd0: main_dout <= main_cache0[ 7:0];
						2'd1: main_dout <= main_cache0[15:8];
						2'd2: main_dout <= main_cache1[ 7:0];
						2'd3: main_dout <= main_cache1[15:8];
					endcase
					rd_state  <= ST_GRAPH; // Graphics
					if( !LHBL ) gra_state <= ST_OBJ;
				end
				else begin
					rd_req <= 1'b1;
					collect_msb <= 1'b0;
					{row_addr, col_addr} <= {main_addr_sync[16:2],1'b0}; 
					main_addr_last <= main_addr_sync>>2;					
				end
			end
			else begin
					rd_state  <= ST_GRAPH; // Graphics
			end
			ST_REFRESH: begin
				// Char output is set to spaces during blanking
				char_addr_last <= 10'h20 << 3;
				char_dout <= 16'hFFFF;
				// and SCR to 0
				scr_addr_last <= 0;
				scr_dout <= 24'd0;
				rd_state <= ST_SND;
			end
			ST_GRAPH: case( gra_state )
				ST_CHAR: begin
					if( char_addr_sync == char_addr_last ) begin
						gra_state <= ST_SCR;
					end
					else 
					if( char_addr_sync[12:3]==10'h20 ) begin // SPACE
						char_dout <= 16'hFFFF;
						char_addr_last <= char_addr_sync;
						gra_state <= ST_SCR;
					end
					else begin
						rd_req <= 1'b1;
						{row_addr, col_addr} <= 16'hA000 + char_addr_sync; // 12:0
						char_addr_last <= char_addr_sync;
					end
				end
				ST_SCR:
				begin
					if( scr_addr_sync == scr_addr_last ) begin
						rd_state <= ST_SND;						
						gra_state <= ST_OBJ;
					end					
					else 
					if( scr_addr_sync[14:5]==10'h00 ) begin // blank
						scr_dout <= 24'd0;
						rd_state <= ST_SND;
						gra_state <= ST_OBJ;
						scr_addr_last <= scr_addr_sync;					
					end
					else begin
						rd_req <= 1'b1;
						{row_addr, col_addr} <= 16'hc000 + { scr_addr_sync, 1'b0 }; // 14:0 BC/E ROMs
						scr_addr_last <= scr_addr_sync;					
					end
				end
				ST_OBJ:	
					if( obj_addr_sync[14:5]==10'd0 || obj_addr_sync[14:5]=={2'b11,8'hf8} ) begin
						if( LHBL ) begin
							rd_state <= ST_SND;
							gra_state <= ST_CHAR;
							//skip_refresh <= false;
						end else begin
							rq_autorefresh <= 1'b1;
							rq_autorefresh_aux <= 1'b1;
							rd_state <= ST_REFRESH;
						end							
						obj_dout = ~32'd0;
					end
					else
					if( obj_addr_last == obj_addr_sync) begin
						if( LHBL  ) begin
							rd_state <= ST_SND;
							gra_state <= ST_CHAR;
							//skip_refresh <= false;
						end	else begin
							rq_autorefresh <= 1'b1;
							rq_autorefresh_aux <= 1'b1;
							rd_state <= ST_REFRESH;
						end								
					end else begin
						rd_req <= 1'b1;
						{row_addr, col_addr} <= 17'h1C000 + obj_addr_sync;
						obj_addr_last <= obj_addr_sync;					
					end
				default: gra_state <= ST_CHAR;
				endcase
		endcase // rd_state
	end else begin
		rd_req <= 1'b0;
		if(!downloading) 
			rd_collect <= 1'b1; 
		else begin
			rd_collect<=1'b0;
			main_addr_last <= 0;
			snd_addr_last <= 0; // these must not interfere with CPU reset!!
		end
		{ rq_autorefresh, rq_autorefresh_aux } <= { rq_autorefresh_aux, 1'b0 };
	end
end

reg  [1:0] cl_cnt;

localparam	CMD_LOAD_MODE	= 4'b0000,
			CMD_AUTOREFRESH	= 4'b0001,
			CMD_PRECHARGE   = 4'b0010,
			CMD_ACTIVATE	= 4'b0011,
			CMD_WRITE		= 4'b0100,
			CMD_READ		= 4'b0101,
			CMD_STOP		= 4'b0110,
			CMD_NOP			= 4'b0111,
			CMD_INHIBIT	 	= 4'b1000;

reg [3:0] state, next, init_state;

localparam INITIALIZE = 4'd0, IDLE=4'd1, WAIT=4'd2, ACTIVATE=4'd3,
			READ=4'd4, WAIT_CL=4'd5, SET_READ=4'd6, AUTO_REFRESH1=4'd7,
			SET_PRECHARGE = 4'd8, SET_PRECHARGE_WR = 4'd9, ACTIVATE_WR=4'd10,
			SET_WRITE=4'd11;

reg [3:0] wait_cnt;
reg write_done;
localparam PRECHARGE_WAIT = 4'd1, ACTIVATE_WAIT=4'd0, CL_WAIT=4'd1;

wire [3:0] COMMAND = { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE };

`ifdef SIMULATION
integer sdram_writes = 0;
`endif


always @(posedge clk)
	if( rst ) begin
		state <= INITIALIZE;
		init_state <= 4'd0;
		{ SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_INHIBIT;
		{ wait_cnt, SDRAM_A } <= 8400;
		read_done <= false;
		ready <= false;
		write_done <= 1'b0;
		romload_wr16 <= false;
		crc_en <= 1'b0;
	end else  begin
	if( romload_wr ) begin
		romload_wr16 <= 1'b1;
		{ romload_row, romload_col } <= romload_addr[24:1]-1'b1;
	end
	case( state )
		default: state <= SET_PRECHARGE;
		INITIALIZE: begin
			case(init_state)
				4'd0: begin	// wait for 100us
					{ SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_NOP;
					{ wait_cnt, SDRAM_A } <= { wait_cnt, SDRAM_A }-1'b1;
					if( !{ wait_cnt, SDRAM_A } ) 
						init_state <= init_state+4'd1;
					end
				4'd1: begin
					{ SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_PRECHARGE;
					SDRAM_A[10]=1'b1; // all banks
					wait_cnt <= PRECHARGE_WAIT;
					state <= WAIT;
					next <= INITIALIZE;
					init_state <= init_state+4'd1;
					end
				4'd2,4'd3: begin
					{ SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_AUTOREFRESH;
					wait_cnt <= 4'd10;
					state <= WAIT;
					next <= INITIALIZE;
					init_state <= init_state+4'd1;
					end
				4'd4: begin
					{ SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_LOAD_MODE;
					SDRAM_A <= 12'b00_1_00_011_0_001; // Burst length=2
					wait_cnt <= 4'd2;
					state <= WAIT;
					next <= SET_PRECHARGE;
					init_state <= 0;
					ready <= true;
					end
			endcase
			end
		SET_PRECHARGE: begin
			{ SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_PRECHARGE;
			SDRAM_A[10]<=1'b1; // all banks
			wait_cnt <= PRECHARGE_WAIT;
			state <= WAIT;
			next <= rq_autorefresh ? AUTO_REFRESH1 : ACTIVATE;		
			read_done <= false;
			// Clear WRITE state:
			SDRAM_WRITE <= 1'b0;
			if( write_done ) begin
				romload_wr16 <= 1'b0;			
				write_done <= false;
			end
			end
		WAIT: begin
			{ SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_NOP;
			if( !wait_cnt ) state<=next;
			wait_cnt <= wait_cnt-2'b1;
			crc_en <= 1'b0;
			end
		ACTIVATE: begin 
			{ SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_ACTIVATE;
			SDRAM_A <= row_addr;
			wait_cnt <= ACTIVATE_WAIT;
			next  <= SET_READ;
			state <= WAIT;
			end		
		SET_READ:begin
			{ SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_READ;
			wait_cnt <= CL_WAIT;
			state <= WAIT;
			next  <= READ;
			SDRAM_A <= { {(addr_w-col_w){1'b0}}, col_addr};
			end		
		READ: begin
			read_done <= true;
			if( downloading && romload_wr16 )
				state <=  SET_PRECHARGE_WR; // it stays on READ state until romload_wr16 asserted
			else if( !downloading )
				if( we )
					state <= SET_PRECHARGE_WR;
				else if( rd_req || rq_autorefresh ) begin
					read_done <= false;
					state <= SET_PRECHARGE;
				end
			end
		AUTO_REFRESH1: begin
			{ SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <=	CMD_AUTOREFRESH;
			wait_cnt <= 4'd12;
			state <= WAIT;
			next <= READ; // just to generate the read_done
			end
		// Write states
		SET_PRECHARGE_WR: begin
			{ SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_PRECHARGE;
			SDRAM_A[10]=1'b1; // all banks
			wait_cnt <= PRECHARGE_WAIT;
			state <= WAIT;
			next <= ACTIVATE_WR;
			read_done <= false;
			end
		ACTIVATE_WR: begin 
			{ SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_ACTIVATE;
			SDRAM_A <= romload_wr16 ? romload_row : wr_row;
			wait_cnt <= ACTIVATE_WAIT;
			next  <= SET_WRITE;
			state <= WAIT;
			end		
		SET_WRITE:begin
			{ SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE } <= CMD_WRITE;
			SDRAM_WRITE <= 1'b1;
			wait_cnt <= CL_WAIT;
			state <= WAIT;
			next  <= SET_PRECHARGE;
			SDRAM_A  <= { {(addr_w-col_w){1'b0}}, romload_wr16 ? romload_col : wr_col};
			crc_en <= 1'b1;
			write_done <= true;
			`ifdef SIMULATION
				sdram_writes <= sdram_writes + 2;
			`endif
			end		
	endcase // state
	end

endmodule // jtgng_rom