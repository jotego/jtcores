`timescale 1ns/1ps

module pcb(
    input   CLK12,
    output  phiB,
    output  [8:0] H,
    output  [8:0] V,
    output  HINIT,
    output  LHBL,
    output  LVBL
);

`include "pcb_model.v"

endmodule
