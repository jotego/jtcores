`timescale 1ns/1ps

module jtgng_main(
	input	clk,	// 6MHz
	input	rst,
	input	ch_mrdy,
	input	[7:0] char_dout,
	input	LVBL,	// vertical blanking when 0
	output	[7:0] cpu_dout,
	output	reg char_cs,
	// BUS sharing
	output		bus_ack,
	input		bus_req
	// ROM access
	output	[17:0] rom_addr,
	input	[ 7:0] rom_dout
);

wire [15:0] A;
wire MRDY_b = ch_mrdy;
wire nRESET = ~rst;

wire [2:0] map_cs;
assign { ram_cs, char_cs, bank_cs, rom_cs } = map_cs;


always @(A[15:8])
	case(A[15:8])
		8'b000x_xxxx: map_cs = 4'b1000; // 0000-1FFF
		8'b0010_0xxx: map_cs = 4'b0100; // 2000-27FF
		8'b0011_1110: map_cs = 4'b0010; // 3E00-3EFF
		8'b10xx_xxxx: map_cs = 4'b0001; // 8000-BFFF, ROM 9N
	endcase

wire RnW;

// bank
reg [2:0] bank;
always @(negedge clk)
	if( bank_cs && !RnW ) bank <= cpu_dout[2:0];

// RAM, 8kB
wire [7:0] ram_dout;
wire ram_we = ram_cs && !RnW;
wire [12:0] AB = A[12:0];

jtgng_m9k #(.addrw(13)) RAM(
	.clk ( clk       ),
	.addr( AB[12:0]  ),
	.din ( cpu_dout  ),
	.dout( ram_dout  ),
	.we  ( ram_we    )
);

wire E,Q;
wire [7:0] cpu_din =({8{ram_cs}}  & ram_dout )	| 
					({8{char_cs}} & char_dout)	|
					({8{rom_cs}}  & rom_dout )	|;


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

mc6809 main (
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