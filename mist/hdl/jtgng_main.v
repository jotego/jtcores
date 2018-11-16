/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */

`timescale 1ns/1ps

module jtgng_main(
	input	clk,	// 6MHz
	input	rst,
	input	soft_rst,
	input	ch_mrdy,
	input	[7:0] char_dout,
	input	LVBL,	// vertical blanking when 0
	output	[7:0] cpu_dout,
	output	main_cs,
	output	char_cs,
	output	blue_cs,
	output	redgreen_cs,	
	output	reg flip,
	// Sound
	output	reg sres_b,	// Z80 reset
	output	reg	[7:0] snd_latch,
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
	input			rom_mrdy,
	// BUS sharing
	output		bus_ack,
	input		bus_req,
	input		blcnten,
	input	[ 8:0]	obj_AB,
	output	[12:0]	cpu_AB,
	output		RnW,
	output		OKOUT,
	output	[7:0]	ram_dout,
	// ROM access
	output	reg [16:0] rom_addr,
	input	[ 7:0] rom_dout,
	// DIP switches
	input	dip_flip,
	input	dip_game_mode,
	input	dip_attract_snd,
	input	dip_upright
);

wire [15:0] A;
wire MRDY_b = ch_mrdy & scr_mrdy & rom_mrdy;
reg nRESET;
wire in_cs;
wire sound_cs, ram_cs, bank_cs, screpos_cs, flip_cs;

reg [12:0] map_cs;

assign { 
	sound_cs, OKOUT, scrpos_cs, scr_cs, in_cs,
	sdram_prog, blue_cs, redgreen_cs, 	flip_cs, 
	ram_cs, 	char_cs, bank_cs, 		main_cs 		} = map_cs;

reg [7:0] AH;
wire E,Q, AVMA;
reg VMA;

always @(negedge E)
	VMA <= AVMA;

always @(*)
	if(!VMA) map_cs = 0;
	else
	casez(A[15:8])
		8'b000?_????: map_cs = 13'h8; // 0000-1FFF, RAM
		// EXTEN
		8'b0010_0???: map_cs = 13'h4; 	// 2000-27FF	Char
		8'b0010_1???: map_cs = 13'h200; // 2800-2FFF	Scroll
		8'b0011_0???: map_cs = 13'h100; // 3000-37FF input
		8'b0011_1000: map_cs = 13'h20; // 3800-38FF, Red, green
		8'b0011_1001: map_cs = 13'h40; // 3900-39FF, blue
		8'b0011_1010: map_cs = 13'h1000; // 3A00-3AFF, sound
		8'b0011_1011: map_cs = 13'h400;// 3B00-3BFF Scroll position
		8'b0011_1100: map_cs = 13'h800;// OKOUT 
		8'b0011_1101: map_cs = 13'h10; // 3D?? flip

		8'b0011_1110: map_cs = 13'h2; // 3E00-3EFF bank
		8'b0011_1111: map_cs = 13'h80; // 3F00-3FFF SDRAM programming
		8'b01??_????: map_cs = 13'h1; // ROMs
		8'b1???_????: map_cs = startup ? 13'h8 : 13'h1; // 8000-BFFF, ROM 9N
		default: map_cs = 13'h0;
	endcase

// special registers
reg	startup;
reg [2:0] bank;
always @(negedge clk)
	if( rst ) begin
		`ifdef OBJTEST
		startup <= 1'b0;
		`else
		startup <= 1'b1;
		`endif
		nRESET <= 1'b0;
	end
	else begin
		if( bank_cs && !RnW ) begin
			bank <= cpu_dout[2:0];
			if(startup ) begin
				if( cpu_dout[7] )  begin
					// write 0x80 to bank clears out startup latch				
					startup <= 1'b0; 
					nRESET <= 1'b0; // Resets CPU
				end
				if( cpu_dout[6] ) startup <= 1'b0; // clear startup without reset
				`ifdef SIMULATION
				if( cpu_dout[4] ) $finish;
				`endif
			end
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
		flip <= 1'b0;
		sres_b <= 1'b1;
		end
	else
	if( flip_cs ) 
		case(A[2:0])
			3'd0: flip <= cpu_dout[0];
			3'd1: sres_b <= cpu_dout[0];
			3'd2: coin_cnt1 <= coin_cnt1+cpu_dout[0];
			3'd3: coin_cnt2 <= coin_cnt2+cpu_dout[0];
		endcase

always @(negedge clk)
	if( rst ) snd_latch <= 8'd0;
	else if( sound_cs ) snd_latch <= cpu_dout;

reg [7:0] cabinet_input;
wire [7:0] dipsw_a = { dip_flip, dip_game_mode, dip_attract_snd, 5'h1F /* 1 coin, 1 credit */ };
wire [7:0] dipsw_b = { 3'd3, /* normal game */
	2'd3, /* bonus at 20k and every 70k */
	dip_upright, 2'd3 /* 3 lifes */ };
/*
reg [7:0] joystick1_sync, joystick2_sync;

// 1 FF synchronizer
always @(negedge clk) begin
	joystick1_sync <= joystick1;
	joystick2_sync <= joystick2;
end
*/
always @(*)
	case( cpu_AB[3:0])
		4'd0: cabinet_input = { joystick2[7],joystick1[7], // COINS
					 4'hf, // undocumented. The game start screen has background when set to 0!
					 joystick2[6], joystick1[6] }; // START
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
wire cpu_ram_we = ram_cs && !RnW;
assign cpu_AB = A[12:0];

wire [12:0] RAM_addr = blcnten ? { 4'hf, obj_AB } : cpu_AB;
wire RAM_we   = blcnten ? 1'b0 : cpu_ram_we;

jtgng_mainram RAM(
	.address	( RAM_addr	),
	.clock		( clk		),
	.data		( cpu_dout	),
	.wren		( RAM_we	),
	.q			( ram_dout	)
);

reg [7:0] cpu_din;

always @(negedge clk)
 	cpu_din <=  ({8{ram_cs}}  & ram_dout )	| 
				({8{char_cs}} & char_dout)	|
				({8{scr_cs}} & scr_dout)	|
				({8{in_cs}} & cabinet_input)| 
				({8{main_cs}}  & rom_dout );

always @(A,bank) begin
	rom_addr[12:0] = A[12:0];
	case( A[15:13] )
		3'd6, 3'd7: rom_addr[16:13] = { 2'h0, A[14:13] }; // 8N
		3'd5, 3'd4: rom_addr[16:13] = { 2'h0, A[14:13] }; // 9N
		3'd3      : rom_addr[16:13] = 4'd5; // 10N
		3'd2      : 
			casez( bank )
				3'd4: rom_addr[16:13] = 4'h4; // 10N
				//3'd3, 3'd2: rom_addr[16:13] = { 3'b100, bank[1:0] }; // 12N
				3'b0??: rom_addr[16:13] =  {2'd0,bank[1:0]}+4'd6; // 13N
				default:rom_addr[16:13] = 4'hx;
			endcase
		default: rom_addr[16:12] = 5'hxx;
	endcase
end

// Bus access
reg nIRQ, last_LVBL;
wire BS,BA;

assign bus_ack = BA && BS;

always @(negedge clk) begin
	last_LVBL <= LVBL;
	if( {BS,BA}==2'b10 )
		nIRQ <= 1'b1;
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
	.RegData (RegData ),
	.AVMA	 ( AVMA   )
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