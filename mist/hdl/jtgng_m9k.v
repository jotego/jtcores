`timescale 1ns/1ps

module jtgng_m9k #(parameter addrw=12, id=0)(
	input	clk,
	input	[addrw-1:0] addr,
	input	[7:0] din,
	output	reg [7:0] dout,
	input	we
);

reg [addrw-1:0] addr_latch;
reg [7:0] mem[0:(2**addrw-1)];
reg [7:0] data_latch;

`ifdef SIMULATION
initial begin
	case(id)
		10: begin
				$display("ram.hex loaded");
				$readmemh("ram.hex",mem);
			end
	endcase
end
`endif

always @(posedge clk) begin
	addr_latch <= addr;
	data_latch <= din;
	if( we )
		mem[addr_latch] <= data_latch;	
end

always @(addr_latch)
	dout <= mem[addr_latch];


endmodule // jtgng_m9k