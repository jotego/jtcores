`include "jtframe_common_ports.inc"
    // Memory ports
`ifndef JTFRAME_MEMGEN // If the game does not use mem.yaml
    `include "jtframe_mem_ports.inc"
`else
    `include "mem_ports.inc"
`endif