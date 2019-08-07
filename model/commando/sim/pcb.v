`timescale 1ns/1ps

module pcb(
    input         CLK12,
    output        phiB,
    output  [8:0] H,
    output  [8:0] V,
    output        HINIT,
    output        LHBL,
    output        LVBL,
    // SCROLLH
    input         FLIP,
    inout   [3:0] AB,
    inout   [7:0] DB,
    output        SCREN,
    output        LSCREN,
    output        phiSC,
    output        phiMAIN,
    input         D8CS,
    input         C8CS
);

`include "pcb_model.v"

endmodule
