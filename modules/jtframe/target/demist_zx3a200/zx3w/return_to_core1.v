module return_to_core1 (
  input wire clk,
  input wire boot_core
  );
    
  reg [2:0] divclkicap = 3'b000;
  wire clk_icap = divclkicap[2];
  always @(posedge clk)
    divclkicap <= divclkicap + 1;

  reg reboot_ff = 1'b0;
  always @(posedge clk)
    reboot_ff <= reboot_ff | boot_core;

  reg regclkicap = 1'b0;
  wire icap_ce, icap_we;
  wire [31:0] icap_data;
  
  multiboot_artix7 el_multiboot (
    .clk(clk_icap),
    .reboot(reboot_ff),
    .icap_ce(icap_ce),
    .icap_we(icap_we),
    .icap_data(icap_data)
  );
  
  icape el_icap (
    .clk(clk_icap),
    .ce(icap_ce),
    .we(icap_we),
    .din(icap_data)
  );  
endmodule            
    
// When using ICAPE2 to set the WBSTAR address, the 24 most significant address bits
// should be written to WBSTAR[23:0]. For SPI 32-bit addressing mode, WBSTAR[23:0]
// are sent as address bits [31:8]. The lower 8 bits of the address are undefined and
// the value could be as high as 0xFF. Any bitstream at the WBSTAR address should 
// contain 256 dummy bytes before the start of the bitstream.

// The software option spi_32bit_addr is used to generate a bitstream that can address 
// flash densities over 128 Mb. This option must be used consistently for all bitstreams 
// used for fallback MultiBoot such that all bitstreams have the option enabled if the SPI 
// flash is over 128 Mb or all bitstreams have it disabled if the SPI flash is 128 Mb or lower.

module multiboot_artix7 (
  input wire clk,
  input wire reboot,
  output reg icap_ce,
  output reg icap_we,
  output reg [31:0] icap_data
  );
  
  reg [33:0] icap_command[0:15];
  initial begin  // Lista de comandos en UG470, p. 145
    icap_command[ 0] = {1'b0, 1'b0, 32'hFFFFFFFF};
    icap_command[ 1] = {1'b1, 1'b1, 32'hAA995566};  // sync word
    icap_command[ 2] = {1'b1, 1'b1, 32'h20000000};  // nop
    icap_command[ 3] = {1'b1, 1'b1, 32'h30020001};  // escritura en registro WBSTAR
    icap_command[ 4] = {1'b1, 1'b1, 32'h00000000};  // en este ciclo hay que poner la dirección SPI (28 bits)
    icap_command[ 5] = {1'b1, 1'b1, 32'h30008001};  // escritura en registro CMD
    icap_command[ 6] = {1'b1, 1'b1, 32'h0000000F};  // dar orden de warm reboot (IPROG)
    icap_command[ 7] = {1'b1, 1'b1, 32'h20000000};  // nop 
    icap_command[ 8] = {1'b1, 1'b1, 32'h20000000};  // nop
    icap_command[ 9] = {1'b1, 1'b1, 32'h20000000};  // nop
    icap_command[10] = {1'b1, 1'b1, 32'h20000000};  // nop
    icap_command[11] = {1'b1, 1'b1, 32'h20000000};  // nop
    icap_command[12] = {1'b1, 1'b1, 32'h20000000};  // nop
    icap_command[13] = {1'b1, 1'b1, 32'h20000000};  // nop
    icap_command[14] = {1'b1, 1'b1, 32'h20000000};  // nop
    icap_command[15] = {1'b1, 1'b1, 32'h20000000};  // nop
  end
  
  reg [4:0] indx = 5'b00000;
  always @(posedge clk) begin
    if (indx[4] == 1'b1)
      indx <= indx + 5'd1;
    if (reboot == 1'b1 && indx[4] == 1'b0)
      indx <= 5'b10000;
    else
      {icap_ce, icap_we, icap_data} <= icap_command[indx[3:0]];
  end      
endmodule

module icape (
  input wire clk,
  input wire ce,
  input wire we,
  input wire [31:0] din
  );

  wire [31:0] swapped;
  genvar j;
  generate
    for(j=0; j<32; j=j+1) begin : swap
	    assign swapped[j] = din[31-j];
	  end
  endgenerate

   // Write and CE are active low, I is bit swapped
   ICAPE2 #(.ICAP_WIDTH("X32")) ICAP_i
     (.O(),
      .CLK(clk),
      .CSIB(~we),
      .I({swapped[7:0], swapped[15:8], swapped[23:16], swapped[31:24]}),
      .RDWRB(~ce)
      );
      
endmodule
