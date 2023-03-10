// x1-007 model by Furrtek

module x1_007(
    input PXCLK,
    input nVBLK,
    input nHSYNC, nVSYNC,
    input RGB[14:0],
    input PIN26,
    output CSYNC,
    output reg R[5:0],
    output reg G[5:0],
    output reg B[5:0],
    output reg PIN11
);
 
reg PIN26_reg;
reg [14:0] RGB_reg;
reg nVBLK_A_reg, nVBLK_B_reg;
 
assign CSYNC = ~(nHSYNC | nVSYNC);  // BOTO
 
always @(negedge PXCLK) begin
    PIN26_reg <= PIN26;             // AGIT
    nVBLK_A_reg <= nVBLK;           // AFAX
    nVBLK_B_reg <= nVBLK_A_reg;     // BOLO
    PIN11 <= nVBLK_A_reg ? PIN26_reg : 1'b0;    // BEDI
end
 
always @(posedge PXCLK)
    RGB_reg <= RGB;     // 15x FD1S cells
 
always @(posedge PXCLK or negedge nVBLK_B_reg) begin
    if (!nVBLK_B_reg)
        {R, G, B} <= 18'd0; // 18x FD2S cells
    else
        {R, G, B} <= {RGB_reg[14:10], |{RGB_reg[14:10]}, RGB_reg[9:5], |{RGB_reg[9:5]} , RGB_reg[4:0], |{RGB_reg[4:0]}};
end
 
endmodule