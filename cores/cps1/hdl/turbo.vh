`ifdef JTCPS_TURBO
assign turbo = 1;
`else
    `ifdef MISTER
        assign turbo = status[13] | cpu_speed;
    `else
        assign turbo = status[5] | cpu_speed;
    `endif
`endif
