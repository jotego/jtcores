module vram
	(
	input MCLK,
	input RAS,
	input CAS,
	input WE,
	input OE,
	input SC,
	input SE,
	input [7:0] AD,
	input [7:0] RD_i,
	output reg [7:0] RD_o,
	output RD_d,
	output [7:0] SD_o,
	output SD_d
	);
	
	reg [15:0] addr;
	reg dt;
	reg [7:0] addr_ser;
	reg [2047:0] ser;
	
	reg o_OE;
	reg o_RAS;
	reg o_cas;
	reg o_SC;
	reg o_valid;
	
	wire cas = ~RAS & ~CAS;
	wire wr = ~RAS & ~CAS & ~WE;
	wire rd = ~RAS & ~CAS & ~OE & ~dt;
	
	wire [7:0] mem_addr = addr[15:8];
	wire [31:0] mem_be;
	wire [2047:0] mem_o;
	
	wire [7:0] slice_s[0:255];
	wire [7:0] slice_p[0:255];
	
	genvar i;
	generate
		for (i = 0; i < 32; i = i + 1)
		begin : l1
			assign mem_be[i] = addr[4:0] == i;
		end
		for (i = 0; i < 8; i = i + 1)
		begin : l2
			vram_ip mem
				(
				.clock(MCLK),
				.address(mem_addr),
				.byteena(mem_be),
				.data({32{RD_i}}),
				.wren(wr & (addr[7:5] == i)),
				.q(mem_o[(256*(i+1)-1):(256*i)])
				);
		end
		for (i = 0; i < 256; i = i + 1)
		begin : l3
			assign slice_p[i] = mem_o[(8*(i+1)-1):(8*i)];
			assign slice_s[i] = ser[(8*(i+1)-1):(8*i)]; 
		end
	endgenerate
	
	assign RD_d = ~o_valid;
	assign SD_d = SE;
	
	reg [7:0] vram_ser;
	
	assign SD_o = vram_ser;
	
	always @(posedge MCLK)
	begin
		if (dt & !o_OE & OE)
		begin
			addr_ser <= addr[7:0];
			ser <= mem_o;
		end
		else if (~o_SC & SC)
		begin
			addr_ser <= addr_ser + 8'h1;
			vram_ser <= slice_s[addr_ser];
		end
		if (o_RAS & ~RAS)
		begin
			dt <= ~OE;
			addr[15:8] <= AD;
		end
		if (~o_cas & cas)
		begin
			addr[7:0] <= AD;
		end
		if (dt & !o_OE & OE)
		begin
			addr_ser <= addr[7:0];
			ser <= mem_o;
		end
		
		if (rd)
		begin
			RD_o <= slice_p[addr[7:0]];
			o_valid <= 1'h1;
		end
		else if (CAS | OE)
		begin
			o_valid <= 1'h0;
		end
		
		o_OE <= OE;
		o_RAS <= RAS;
		o_cas <= cas;
		o_SC <= SC;
	end

endmodule
