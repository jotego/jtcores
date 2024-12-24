////////// dual ram buffer ///////////////////////
//
//  8-bits dual ram that copy the ram content to 
//  a secondary ram at @posedge of trigger
//  
//
module dual_ram_buffer #(parameter W=10)
(
	input            clk,
  input            trigger, // trigger high to copy ram content
  
  input            we,      // 1st ram write
  input    [W-1:0] addr_in, // 1st ram address
  input      [7:0] data,    // 1st ram data 
  output reg [7:0] q_in,    // 1st ram data out 
  
  input    [W-1:0] addr_out,// 2nd ram addr 
  output reg [7:0] q        // 2nd ram data out
);

(* ramstyle = "no_rw_check" *)reg [7:0]      ram[0:(2**W)-1];
(* ramstyle = "no_rw_check" *)reg [7:0]  ram_out[0:(2**W)-1];

reg [W:0] i = 0;

always @(posedge clk) begin
  if (clk) begin
    if (trigger && i <= (2**W)-1) begin
      ram_out[i[W-1:0]] <= ram[i[W-1:0]];
      i <= i + 1'b1;
      end
    else if (~trigger && i == (2**W))
      i <= 0;

    if (we == 1'b1)
      ram[addr_in] <= data;

    q <= ram_out[addr_out];
    q_in <= ram[addr_in];
  end
end

endmodule
