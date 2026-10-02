`timescale 1 ps / 1 ps
// jtcores: altsyncram replaced with an inferred single-port RAM (portable across FPGAs +
// simulators). Registered read output (was outdata_reg_a="CLOCK0").
module sram_line_en
#(
parameter DATA_WIDTH    = 128,
parameter ADDRESS_WIDTH = 7,
parameter INITIALIZE_TO_ZERO = 0
)
(
input                           i_clk,
input      [ADDRESS_WIDTH-1:0]  i_address,
input      [DATA_WIDTH-1:0]     i_write_data,
input                           i_write_enable,
output reg [DATA_WIDTH-1:0]     o_read_data
);

reg [DATA_WIDTH-1:0] mem [0:(2**ADDRESS_WIDTH)-1];
always @(posedge i_clk) begin
    if( i_write_enable ) mem[i_address] <= i_write_data;
    o_read_data <= mem[i_address];
end

endmodule
