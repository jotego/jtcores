`timescale 1ns/1ps

module jtgng_main(
	input	clk,	// 6MHz
	input	rst,
	input	ch_mrdy,
	input	[7:0] char_dout,
	input	LVBL,	// vertical blanking when 0
	output	[7:0] cpu_dout,
	output	char_cs,
	output	blue_cs,
	output	redgreen_cs,	
	output	reg flip,
	output	reg sres_b,
	// BUS sharing
	output		bus_ack,
	input		bus_req,
	output	[12:0]	cpu_AB,
	output		RnW,
	// ROM access
	output	reg [17:0] rom_addr,
	input	[ 7:0] rom_dout
);

wire [15:0] A;
wire MRDY_b = ch_mrdy;
reg nRESET;

reg [6:0] map_cs;
assign { blue_cs, redgreen_cs, flip_cs, 
	ram_cs, char_cs, bank_cs, rom_cs } = map_cs;

reg [7:0] AH;
wire E,Q;
reg VMA;

//always @(posedge Q)
//	VMA <= AVMA;

always @(*)
	// if(!VMA) map_cs = 4'h0;
	// else
	casex(A[15:8])
		8'b000x_xxxx: map_cs = 7'h8; // 0000-1FFF
		// EXTEN
		8'b0010_0xxx: map_cs = 7'h4; // 2000-27FF
		8'b0011_1000: map_cs = 7'h20; // 3800-38FF, Red, green
		8'b0011_1001: map_cs = 7'h40; // 3900-39FF, blue
		8'b0011_1101: map_cs = 7'h10; // 3Dxx flip

		8'b0011_1110: map_cs = 7'h2; // 3E00-3EFF bank
		8'b10xx_xxxx: map_cs = 7'h1; // 8000-BFFF, ROM 9N
		8'b1111_1111: map_cs = startup ? 7'b0 : 7'h1; // FF00-FFFF reset vector
		default: map_cs = 7'h0;
	endcase

wire RnW;

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
			if( cpu_dout[7] )  begin
				// write 0x80 to bank clears out startup latch				
				startup <= 1'b0; 
				nRESET <= 1'b0; // Resets CPU
			end
		end
		else nRESET <= ~rst;
	end

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

// RAM, 8kB
wire [7:0] ram_dout;
wire ram_we = ram_cs && !RnW;
assign cpu_AB = A[12:0];

jtgng_m9k #(.addrw(13),.id(10)) RAM(
	.clk ( clk       ),
	.addr( cpu_AB[12:0]  ),
	.din ( cpu_dout  ),
	.dout( ram_dout  ),
	.we  ( ram_we    )
);

wire [7:0] cpu_din =({8{ram_cs}}  & ram_dout )	| 
					({8{char_cs}} & char_dout)	|
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