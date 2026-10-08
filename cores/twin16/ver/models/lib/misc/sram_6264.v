module sram_6264(
				input [ADDR_WIDTH-1:0] addr,
				inout [DATA_WIDTH-1:0] data,
				input cs1_n,
				input cs2,
				input oe_n,
				input rw_n
				);

parameter DATA_WIDTH = 8;
parameter ADDR_WIDTH = 13;
parameter RAM_DEPTH = 1 << ADDR_WIDTH;

reg [DATA_WIDTH-1:0] data_out,testram;
reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];
reg [ADDR_WIDTH-1:0] addr_previous;
reg ooehiz,test2,test3;

initial 
begin
	test2 = 1'b0;
	test3 = 1'b0;	
end

assign data = (~cs1_n & cs2 & (~oe_n | ~ooehiz) & rw_n) ? data_out :  {DATA_WIDTH{1'bz}};
/*
always @ (posedge cs1_n or negedge cs2)
begin : HIGH_Z
	if ( cs1_n | ~cs2 ) begin
		# 20 // Max tCHZ1 or tCHZ2 is 35ns, use 20ns.
		data_out <= {DATA_WIDTH{1'bz}};
	end
end
*/

always @ (oe_n)
begin :OE_CTRL
	if (oe_n)
	begin
		# 20 // Max tOHZ 35ns, use 20ns.
		ooehiz <= 1;
	end
	else if (~oe_n) // ~ooe_n
	begin
		# 10 // Datasheet for 6264 says min 5ns, use 10ns.
		ooehiz <= 0;
	end
end


always @ (posedge oe_n)
begin : HIGH_Z2
	if ( ~cs1_n & cs2 & rw_n & oe_n) begin
		# 20 // Max tOHZ 35ns, use 20ns.
		data_out <= {DATA_WIDTH{1'bz}};
	end
end

always @ (negedge rw_n or addr or data)
begin : MEM_WRITE
	if ( ~cs1_n & cs2 & ~rw_n ) begin
		# 2 // In reality 2ns is not enough for this, but trying remove write pulse glitch.
		if ( ~cs1_n & cs2 & ~rw_n ) begin
			mem[addr] <= data;
			testram <= data;
			test2 <= ~test2;
		end
	end
end

always @ (addr or negedge cs1_n or posedge cs2 or posedge rw_n or negedge oe_n)
begin : MEM_READ
	if ( ~cs1_n & cs2 & ~oe_n & rw_n /*& ((addr_previous == addr) )*/ )
	begin
		test3 <= ~test3;
		# 20 // 6264-AL-10 10ns data value hold time.
		test3 <= ~test3;
		data_out <= mem[addr];
		addr_previous <= addr;
	end
/*	else if ( ~cs1_n & cs2 & ~oe_n & rw_n & ((addr_previous != addr) ) )
	begin
		# 50 // 6264-AL-10 100ns read cycle.
		data_out <= mem[addr];
		addr_previous <= addr;
	end
*/
end

endmodule