module quick_sdram(
    input   SDRAM_nCS,
    input   SDRAM_CLK,
    input   SDRAM_nRAS,
    input   SDRAM_nCAS,
    input   SDRAM_nWE,
    input   SDRAM_CKE,
    input   [12:0] SDRAM_A,
    output  [15:0] SDRAM_DQ
);

// Quick model for SDRAM
reg  [15:0] sdram_mem[0:2**18-1];
reg  [12:0] sdram_row;
//reg  [10:0] sdram_col;
reg  [15:0] sdram_data;
reg  [17:0] sdram_compound;
assign SDRAM_DQ = sdram_data;
initial $readmemh("../../../rom/gng.hex",  sdram_mem, 0, 180223);
always @(posedge SDRAM_CLK) begin
    if( !SDRAM_nCS && !SDRAM_nRAS &&  SDRAM_nCAS && SDRAM_nWE && SDRAM_CKE ) sdram_row <= SDRAM_A;
    if( !SDRAM_nCS &&  SDRAM_nRAS && !SDRAM_nCAS && SDRAM_nWE && SDRAM_CKE ) sdram_compound <= {sdram_row[8:0], SDRAM_A[8:0]};
    sdram_data <= sdram_mem[ sdram_compound ];
end

endmodule // quick_sdram