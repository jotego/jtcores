`timescale 1ns/1ps

module jtgng_main(
	input	clk,	// 6MHz
	input	rst,
	input	soft_rst,
	input	ch_mrdy,
	input	[7:0] char_dout,
	input	LVBL,	// vertical blanking when 0
	output	[7:0] cpu_dout,
	output	char_cs,
	output	blue_cs,
	output	redgreen_cs,	
	output	reg flip,
	output	reg sres_b,
	// scroll
	input			scr_mrdy,
	input	[7:0]	scr_dout,
	output			scr_cs,
	output			scrpos_cs,
	// cabinet I/O
	input	[7:0]	joystick1,
	input	[7:0]	joystick2,
	// SDRAM programming
	output	reg	[15:0]	sdram_din,
	output	reg	[12:0]  wr_row,
	output	reg	[ 8:0]	wr_col,
	output	reg			sdram_we,	
	input	[31:0]		crc,  // 627A_4660	
	// BUS sharing
	output		bus_ack,
	input		bus_req,
	output	[12:0]	cpu_AB,
	output		RnW,
	// ROM access
	output	reg [17:0] rom_addr,
	input	[ 7:0] rom_dout,
	// DIP switches
	input	dip_flip,
	input	dip_game_mode,
	input	dip_attract_snd,
	input	dip_upright
);

wire [15:0] A;
wire MRDY_b = ch_mrdy & scr_mrdy;
reg nRESET;
wire in_cs;

reg [10:0] map_cs;

assign { 
	scrpos_cs, scr_cs, in_cs,
	sdram_prog, blue_cs, redgreen_cs, 	flip_cs, 
	ram_cs, 	char_cs, bank_cs, 		rom_cs 		} = map_cs;

reg [7:0] AH;
wire E,Q;
reg VMA;

//always @(posedge Q)
//	VMA <= AVMA;

always @(*)
	// if(!VMA) map_cs = 4'h0;
	// else
	casex(A[15:8])
		8'b000x_xxxx: map_cs = 11'h8; // 0000-1FFF, RAM
		// EXTEN
		8'b0010_0xxx: map_cs = 11'h4; 	// 2000-27FF	Char
		8'b0010_1xxx: map_cs = 11'h200; // 2800-2FFF	Scroll
		8'b0011_0xxx: map_cs = 11'h100; // 3000-37FF input
		8'b0011_1000: map_cs = 11'h20; // 3800-38FF, Red, green
		8'b0011_1001: map_cs = 11'h40; // 3900-39FF, blue
		8'b0011_1011: map_cs = 11'h400;// 3B00-3BFF Scroll position
		8'b0011_1101: map_cs = 11'h10; // 3Dxx flip

		8'b0011_1110: map_cs = 11'h2; // 3E00-3EFF bank
		8'b0011_1111: map_cs = 11'h80; // 3F00-3FFF SDRAM programming
		8'b01xx_xxxx: map_cs = 11'h1; // ROMs
		8'b1xxx_xxxx: map_cs = startup ? 11'h8 : 11'h1; // 8000-BFFF, ROM 9N
		default: map_cs = 11'h0;
	endcase

// special registers
reg	startup;
reg [2:0] bank;
always @(negedge clk)
	if( rst ) begin
		startup <= 1'b1;
		nRESET <= 1'b0;
	end
	else begin
		if( bank_cs && !RnW ) begin
			bank <= cpu_dout[2:0];
			if( cpu_dout[7] && startup )  begin
				// write 0x80 to bank clears out startup latch				
				startup <= 1'b0; 
				nRESET <= 1'b0; // Resets CPU
			end
			if( cpu_dout[6] && startup ) startup <= 1'b0; // clear startup without reset
		end
		else nRESET <= ~(rst | soft_rst);
	end

// SDRAM programming
always @(negedge clk)
	if( rst )
		sdram_we <= 1'b0;
	else if( sdram_prog && startup && !RnW ) begin
		case( A[3:0] )
			4'd0: sdram_din[15:8] <= cpu_dout;
			4'd1: sdram_din[ 7:0] <= cpu_dout;
			4'd2: wr_row[ 12:8]	  <= cpu_dout[4:0];
			4'd3: wr_row[  7:0]	  <= cpu_dout;
			4'd4: wr_col[    8]	  <= cpu_dout[0];
			4'd5: wr_col[  7:0]	  <= cpu_dout;
			4'd7: sdram_we <= 1'b1;
		endcase
	end
	else sdram_we <= 1'b0;


localparam coinw = 4;
reg [coinw-1:0] coin_cnt1, coin_cnt2;

always @(negedge clk)
	if( rst ) begin
		coin_cnt1 <= {coinw{1'b0}};
		coin_cnt2 <= {coinw{1'b0}};
		end
	else
	if( flip_cs ) 
		case(A[2:0])
			3'd0: flip <= cpu_dout[0];
			3'd1: sres_b <= cpu_dout[0];
			3'd2: coin_cnt1 <= coin_cnt1+cpu_dout[0];
			3'd3: coin_cnt2 <= coin_cnt2+cpu_dout[0];
		endcase

reg [7:0] cabinet_input;
wire [7:0] dipsw_a = { dip_flip, dip_game_mode, dip_attract_snd, 5'b0 };
wire [7:0] dipsw_b = { 5'd0, dip_upright, 2'd0 };
/*
reg [7:0] joystick1_sync, joystick2_sync;

// 1 FF synchronizer
always @(posedge clk) begin
	joystick1_sync <= joystick1;
	joystick2_sync <= joystick2;
end
*/
always @(*)
	case( cpu_AB[3:0])
		4'd0: cabinet_input = { {2{joystick1[7:6]}}, {2{joystick2[7:6]}} };
		4'd1: cabinet_input = { 2'b11, joystick1[5:0] };
		4'd2: cabinet_input = { 2'b11, joystick2[5:0] };
		4'd3: cabinet_input = dipsw_a;
		4'd4: cabinet_input = dipsw_b;
		4'd5: cabinet_input = crc[31:24];
		4'd6: cabinet_input = crc[23:16];
		4'd7: cabinet_input = crc[15: 8];
		4'd8: cabinet_input = crc[ 7: 0];
		default: cabinet_input = 8'hff;
	endcase


// RAM, 8kB
wire [7:0] ram_dout;
wire ram_we = ram_cs && !RnW;
assign cpu_AB = A[12:0];

jtgng_mainram RAM(
	.address	( cpu_AB[12:0]	),
	.clock		( clk			),
	.data		( cpu_dout		),
	.wren		( ram_we		),
	.q			( ram_dout		)
);

reg [7:0] cpu_din;

always @(posedge clk)
 	cpu_din <=  ({8{ram_cs}}  & ram_dout )	| 
				({8{char_cs}} & char_dout)	|
				({8{scr_cs}} & scr_dout)	|
				({8{in_cs}} & cabinet_input)| 
				({8{rom_cs}}  & rom_dout );

always @(A,bank) begin
	rom_addr[12:0] = A[12:0];
	case( A[15:13] )
		3'd6, 3'd7: rom_addr[17:13] = { 3'b000, A[14:13] }; // 8N
		3'd5, 3'd4: rom_addr[17:13] = { 3'b001, A[14:13] }; // 9N
		3'd3      : rom_addr[17:13] = { 3'b010, 2'b01 }; // 10N
		3'd2      : 
			case( bank )
				3'd4      : rom_addr[17:13] = { 3'b010, 2'b00 }; // 10N
				3'd3, 3'd2: rom_addr[17:13] = { 3'b100, bank[1:0] }; // 12N
				3'd1, 3'd0: rom_addr[17:13] = { 3'b101, bank[1:0] }; // 13N
				default: rom_addr[17:13] = 5'hxx;
			endcase
		default: rom_addr[17:13] = 5'hxx;
	endcase
end

// Bus access
reg nIRQ, last_LVBL;
wire BS,BA;

assign bus_ack = BA && BS;

always @(negedge clk) begin
	last_LVBL <= LVBL;
	if( {BS,BA}==2'b10 )
		nIRQ = 1'b1;
	else 
		if(last_LVBL && !LVBL ) nIRQ<=1'b0; // when LVBL goes low
end

wire [111:0] RegData;

mc6809 cpu (
	.Q		 (Q		  ),
	.E		 (E		  ),
	.D       (cpu_din ),
	.DOut    (cpu_dout),
	.ADDR    (A		  ),
	.RnW     (RnW     ),
	.BS      (BS      ),
	.BA      (BA      ),
	.nIRQ    (nIRQ    ),
	.nFIRQ   (1'b1    ),
	.nNMI    (1'b1    ),
	.EXTAL   (clk	  ),
	.XTAL    (1'b0    ),
	.nHALT   (~bus_req),
	.nRESET  (nRESET  ),
	.MRDY    (MRDY_b  ),
	.nDMABREQ(1'b1    ),
	.RegData (RegData )
);

`ifdef SIMULATION
wire [7:0] main_a   = RegData[7:0];
wire [7:0] main_b   = RegData[15:8];
wire [15:0] main_x   = RegData[31:16];
wire [15:0] main_y   = RegData[47:32];
wire [15:0] main_s   = RegData[63:48];
wire [15:0] main_u   = RegData[79:64];
wire [7:0] main_cc  = RegData[87:80];
wire [7:0] main_dp  = RegData[95:88];
wire [15:0] main_pc  = RegData[111:96];
`endif

endmodule // jtgng_main