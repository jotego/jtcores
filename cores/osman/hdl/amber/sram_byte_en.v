`timescale 1 ps / 1 ps
// jtcores: altsyncram replaced with an inferred single-port byte-enable RAM (portable across
// FPGAs + simulators). Registered read output (was outdata_reg_a="CLOCK0").
module sram_byte_en
#(
parameter DATA_WIDTH    = 128,
parameter ADDRESS_WIDTH = 7
)
(
input                           i_clk,
input      [DATA_WIDTH-1:0]     i_write_data,
input                           i_write_enable,
input      [ADDRESS_WIDTH-1:0]  i_address,
input      [DATA_WIDTH/8-1:0]   i_byte_enable,
output reg [DATA_WIDTH-1:0]     o_read_data
);

reg [DATA_WIDTH-1:0] mem [0:(2**ADDRESS_WIDTH)-1];
integer k;
always @(posedge i_clk) begin
    if( i_write_enable )
        for( k=0; k<DATA_WIDTH/8; k=k+1 )
            if( i_byte_enable[k] ) mem[i_address][k*8+:8] <= i_write_data[k*8+:8];
    o_read_data <= mem[i_address];
end

endmodule
