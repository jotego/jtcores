`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/18/2016 09:25:01 PM
// Design Name: 
// Module Name: 6809 Superset module of MC6809 and MC6809E signals
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mc6809s(
    input   [7:0] D,
    output  [7:0] DOut,
    output  [15:0] ADDR,
    output  RnW,
    input   CLK4,
    output  BS,
    output  BA,
    input   nIRQ,
    input   nFIRQ,
    input   nNMI,
    output  AVMA,
    output  BUSY,
    output  LIC,
    input   nRESET,
    input   nHALT,
    input   nDMABREQ,
    output  E,
    output  Q,
    output reg [1:0] clk4_cnt,
    output  [111:0] RegData
);

    reg     rE;
    reg     rQ;
    assign  E = rE;
    assign  Q = rQ;
    reg     nCoreRESET;
    
 mc6809i corecpu(.D(D), .DOut(DOut), .ADDR(ADDR), .RnW(RnW), .E(rE), .Q(rQ), .BS(BS), .BA(BA), .nIRQ(nIRQ), .nFIRQ(nFIRQ), .nNMI(nNMI), .AVMA(AVMA), .BUSY(BUSY), .LIC(LIC), .nRESET(nCoreRESET),
                 .nDMABREQ(nDMABREQ), .nHALT(nHALT), .RegData(RegData) );
                 
 always @(posedge CLK4)
 begin
     clk4_cnt <= clk4_cnt+2'b01;
     
     if (nRESET == 0)
     begin
         clk4_cnt <= 0;
         nCoreRESET <= 0;
     end
     
     if ( clk4_cnt == 2'b00  )     // RISING EDGE OF E
         rE <= 1;
     
     if (clk4_cnt == 2'b01)        // RISING EDGE OF Q
        rQ <= 1;     

     if (clk4_cnt == 2'b10)        // FALLING EDGE OF E
        rE <= 0;
     
     if (clk4_cnt == 2'b11)        // FALLING EDGE OF Q
     begin
        rQ <= 0;
        nCoreRESET <= 1;
     end
 end
       
    
endmodule
