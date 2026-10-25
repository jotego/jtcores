// Test-only compatibility for the pinned 2020 schematic reference modules.
module jt2020_ram #(parameter aw=10,dw=8,synfile="",simfile="",simhexfile="")(
 input clk,cen,input [dw-1:0] data,input [aw-1:0] addr,input we,output reg [dw-1:0] q);
 reg [dw-1:0] mem[0:(1<<aw)-1];integer i;
 initial for(i=0;i<(1<<aw);i=i+1) mem[i]=0;
 always @(posedge clk) begin q<=mem[addr];if(cen&&we)mem[addr]<=data;end
endmodule
module jt2020_prom #(parameter aw=8,dw=8,simfile="",offset=0)(
 input clk,cen,input [dw-1:0] data,input [aw-1:0] rd_addr,wr_addr,input we,output reg [dw-1:0] q);
 reg [7:0] mem[0:4095];integer f,n;
 initial begin
  f=$fopen(simfile,"rb");if(f==0)$fatal(1,"FAIL cannot read fixture %s",simfile);
  n=$fread(mem,f);$fclose(f);if(n==0)$fatal(1,"FAIL empty fixture");
 end
 always @(posedge clk)if(cen)q<=mem[offset+rd_addr];
endmodule
module jt2020_sh #(parameter width=2,stages=4)(
 input clk,clk_en,input [width-1:0]din,output [width-1:0]drop);
 jtframe_sh #(.W(width),.L(stages)) u_shift(.clk(clk),.clk_en(clk_en),.din(din),.drop(drop));
endmodule
