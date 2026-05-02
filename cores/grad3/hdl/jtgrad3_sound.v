/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jtgrad3_sound(
    input           rst,
    input           clk,
    input           cen_fm,
    input           cen_fm2,

    input           snd_irq,
    input    [ 7:0] snd_latch,

    output   [15:0] rom_addr,
    output reg      rom_cs,
    input    [ 7:0] rom_data,
    input           rom_ok,

    output   [18:0] pcma_addr,
    input    [ 7:0] pcma_dout,
    output          pcma_cs,
    input           pcma_ok,
    output   [18:0] pcmb_addr,
    input    [ 7:0] pcmb_dout,
    output          pcmb_cs,
    input           pcmb_ok,

    output signed [15:0] fm_l,
    output signed [15:0] fm_r,
    output signed [10:0] pcm,

    input    [ 7:0] debug_bus,
    output   [ 7:0] st_dout
);

`ifndef NOSOUND
wire [15:0] A;
wire [ 7:0] cpu_dout, ram_dout, fm_dout, st_pcm;
wire [16:0] k32a_addr, k32b_addr;
wire        m1_n, mreq_n, rd_n, wr_n, iorq_n, rfsh_n, cpu_cen;
wire        mem_acc, fm_sample;
wire signed [15:0] fm_r_raw;
reg  [ 7:0] cpu_din;
reg         ram_cs, bank_cs, latch_cs, pcm_cs, fm_cs;
reg  [ 1:0] bank_a, bank_b;

assign rom_addr  = A;
assign mem_acc   = !mreq_n && rfsh_n;
assign pcma_addr = { bank_a, k32a_addr };
assign pcmb_addr = { bank_b, k32b_addr };
assign fm_r      = fm_r_raw;
assign st_dout   = debug_bus[5] ? st_pcm : { bank_b, bank_a, snd_latch[3:0] };

always @* begin
    rom_cs   = mem_acc && A < 16'hf000 && !rd_n;
    bank_cs  = mem_acc && A == 16'hf000;
    latch_cs = mem_acc && A == 16'hf010;
    pcm_cs   = mem_acc && A >= 16'hf020 && A <= 16'hf02d;
    fm_cs    = mem_acc && A >= 16'hf030 && A <= 16'hf031;
    ram_cs   = mem_acc && A >= 16'hf800;
end

always @* begin
    case(1'b1)
        rom_cs:   cpu_din = rom_data;
        ram_cs:   cpu_din = ram_dout;
        latch_cs: cpu_din = snd_latch;
        fm_cs:    cpu_din = fm_dout;
        default:  cpu_din = 8'hff;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank_a <= 0;
        bank_b <= 0;
    end else if( bank_cs && !wr_n ) begin
        bank_a <= cpu_dout[1:0];
        bank_b <= cpu_dout[3:2];
    end
end

jtframe_sysz80 #(.RAM_AW(11), .CLR_INT(1)) u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .cpu_cen    ( cpu_cen   ),
    .int_n      ( ~snd_irq  ),
    .nmi_n      ( 1'b1      ),
    .busrq_n    ( 1'b1      ),
    .m1_n       ( m1_n      ),
    .mreq_n     ( mreq_n    ),
    .iorq_n     ( iorq_n    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .rfsh_n     ( rfsh_n    ),
    .halt_n     (           ),
    .busak_n    (           ),
    .A          ( A         ),
    .cpu_din    ( cpu_din   ),
    .cpu_dout   ( cpu_dout  ),
    .ram_dout   ( ram_dout  ),
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    )
);

jt51 u_jt51(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .cen_p1     ( cen_fm2   ),
    .cs_n       ( !fm_cs    ),
    .wr_n       ( wr_n      ),
    .a0         ( A[0]      ),
    .din        ( cpu_dout  ),
    .dout       ( fm_dout   ),
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      (           ),
    .sample     ( fm_sample ),
    .left       (           ),
    .right      (           ),
    .xleft      ( fm_l      ),
    .xright     ( fm_r_raw  )
);

jt007232 u_k7232(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .addr       ( A[3:0]    ),
    .dacs       ( pcm_cs    ),
    .cen_q      (           ),
    .cen_e      (           ),
    .wr_n       ( wr_n      ),
    .din        ( cpu_dout  ),
    .swap_gains ( 1'b0      ),

    .roma_addr  ( k32a_addr ),
    .roma_dout  ( pcma_dout ),
    .roma_cs    ( pcma_cs   ),
    .roma_ok    ( pcma_ok   ),
    .romb_addr  ( k32b_addr ),
    .romb_dout  ( pcmb_dout ),
    .romb_cs    ( pcmb_cs   ),
    .romb_ok    ( pcmb_ok   ),

    .snda       (           ),
    .sndb       (           ),
    .snd        ( pcm       ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_pcm    )
);

`else
assign rom_addr=0, pcma_addr=0, pcmb_addr=0, pcma_cs=0, pcmb_cs=0,
       fm_l=0, fm_r=0, pcm=0, st_dout=0;
initial rom_cs=0;
`endif

endmodule
