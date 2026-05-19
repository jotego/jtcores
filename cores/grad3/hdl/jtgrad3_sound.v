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
    input           cen_pcm,

    input           snd_irq,
    input    [ 7:0] snd_latch,

    output   [15:0] rom_addr,
    output reg      rom_cs,
    input    [ 7:0] rom_data,
    input           rom_ok,

    output   [18:0] pcma_addr,
    input    [ 7:0] pcma_data,
    output          pcma_cs,
    input           pcma_ok,
    output   [18:0] pcmb_addr,
    input    [ 7:0] pcmb_data,
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
wire        mem_acc, fm_sample, rst_n, int_n, fm_csn;
wire signed [15:0] fm_r_raw;
wire [ 7:0] bank;
reg  [ 7:0] cpu_din;
reg         ram_cs, bank_cs, latch_cs, pcm_cs, fm_cs;
wire [ 1:0] bank_a, bank_b;

assign bank_a    = bank[1:0];
assign bank_b    = bank[3:2];
assign rst_n     = ~rst;
assign int_n     = ~snd_irq;
assign fm_csn    = ~fm_cs;
assign rom_addr  = A;
assign mem_acc   = !mreq_n && rfsh_n;
assign pcma_addr = { bank_a, k32a_addr };
assign pcmb_addr = { bank_b, k32b_addr };
assign fm_r      = fm_r_raw;
assign st_dout   = debug_bus[5] ? st_pcm : { bank_b, bank_a, snd_latch[3:0] };

always @* begin
    rom_cs   = 0;
    bank_cs  = 0;
    latch_cs = 0;
    pcm_cs   = 0;
    fm_cs    = 0;
    ram_cs   = 0;

    if( mem_acc) begin
        case (A[15:11])
            5'h1f: ram_cs = 1;
            5'h1e: begin
                case (A[5:4])
                    0: bank_cs  = 1;
                    1: latch_cs = 1;
                    2: pcm_cs   = 1;
                    3: fm_cs    = 1;
                endcase
            end
            default : rom_cs = !rd_n;
        endcase
    end
end

always @(posedge clk) begin
    cpu_din <= rom_cs   ? rom_data  :
               ram_cs   ? ram_dout  :
               latch_cs ? snd_latch :
               fm_cs    ? fm_dout   :
               8'hff;
end

jtframe_8bit_reg u_bank(rst,clk,wr_n,cpu_dout,bank_cs,bank);

jtframe_sysz80 #(.RAM_AW(11), .CLR_INT(1)) u_cpu(
    .rst_n      ( rst_n     ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .cpu_cen    ( cpu_cen   ),
    .int_n      ( int_n     ),
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
    .cs_n       ( fm_csn    ),
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

jt007232 #(.INVA0(1)) u_k7232(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_pcm   ),
    .addr       ( A[3:0]    ),
    .dacs       ( pcm_cs    ),
    .cen_q      (           ),
    .cen_e      (           ),
    .wr_n       ( wr_n      ),
    .din        ( cpu_dout  ),
    .swap_gains ( 1'b0      ),

    .roma_addr  ( k32a_addr ),
    .roma_dout  ( pcma_data ),
    .roma_cs    ( pcma_cs   ),
    .roma_ok    ( pcma_ok   ),
    .romb_addr  ( k32b_addr ),
    .romb_dout  ( pcmb_data ),
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
