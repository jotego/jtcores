/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 8-7-2025 */

module jtrungun_sound(
    input           rst,
    input           clk,
    input           cen_8,
    input           cen_pcm,

    input           pair_we,
    // communication with main CPU
    input   [ 7:0]  main_dout,
    output  [ 7:0]  pair_dout,
    input   [ 4:1]  main_addr,

    input           snd_irq,
    // ROM
    output  [16:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,
    // ADPCM ROM
    output   [21:0] pcma_addr, pcmb_addr,
    input    [ 7:0] pcma_data, pcmb_data,
    output          pcma_cs,   pcmb_cs,
    // Sound output
    output     signed [15:0] k539_l, k539_r,
    // Debug
    input    [ 7:0] debug_bus,
    output   [ 7:0] st_dout
);
/* verilator tracing_off */
parameter PRMR=0;
localparam  VOLSHIFT = PRMR==1 ? 2 : 3; // Per-set gain from full-volume MAME peak captures

wire        [ 7:0]  cpu_dout, cpu_din,  ram_dout, ctl,
                    k39a_dout, k39b_dout, latch_dout, sta_dout, stb_dout;
wire        [ 3:0]  rom_hi;
wire        [ 3:0]  bank;
wire        [15:0]  A;
wire                m1_n, mreq_n, rd_n, wr_n, iorq_n, rfsh_n, nmi_n,
                    cpu_cen, latch_we, tima,
                    latch_intn, int_n, nmi_clr;
reg                 ram_cs, k21_cs, k39a_cs, k39b_cs, mem_acc,
                    bank_cs;
wire signed [15:0]  k539a_l, k539a_r, k539b_l, k539b_r;

assign rom_hi   = A[15] ? bank : {3'd0, A[14]};
assign rom_addr = {rom_hi[2:0], A[13:0]};
assign nmi_clr  =~ctl[4];
assign bank     = ctl[3:0];
assign st_dout  = debug_bus[7] ? stb_dout : sta_dout;
assign latch_we = k21_cs & ~wr_n;

always @(*) begin
    mem_acc =!mreq_n  && rfsh_n;
    rom_cs  = mem_acc &&(!A[15] || !A[14]);
    ram_cs  = mem_acc &&  A[15:13]==3'b110;     // Cxxx
    k39a_cs = mem_acc &&  A[15:10]==6'b1110_00; // E0xx
    k39b_cs = mem_acc &&  A[15:10]==6'b1110_01; // E4xx
    k21_cs  = mem_acc &&  A[15:10]==6'b1111_00; // F0xx (pair_cs on sch)
    bank_cs = mem_acc &&  A[15:10]==6'b1111_10; // F8xx
end

jtframe_8bit_reg u_reg(rst,clk,wr_n,cpu_dout,bank_cs,ctl);

jtframe_edge #(.QSET(0)) u_edge (
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( tima      ),
    .clr    ( nmi_clr   ),
    .q      ( nmi_n     )
);

jt054321 u_54321(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .maddr      ( main_addr ),
    .mdout      ( main_dout ),
    .mdin       ( pair_dout ),
    .mwe        ( pair_we   ),

    .saddr      ( A[1:0]    ),
    .sdout      ( cpu_dout  ),
    .sdin       ( latch_dout),
    .swe        ( latch_we  ),

    // Z80 bus control
    .snd_on     ( snd_irq   ),
    .siorq_n    ( iorq_n    ),
    .int_n      ( int_n     )
);

`ifndef NOSOUND
wire eff_nmin = PRMR==1 ? tima : nmi_n;

assign cpu_din  = rom_cs  ? rom_data   :
                  ram_cs  ? ram_dout   :
                  k39a_cs ? k39a_dout  :
                  k39b_cs ? k39b_dout  :
                  k21_cs  ? latch_dout : 8'h0;

jtframe_sysz80 #(.RAM_AW(13)) u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen_8     ),  // wait states ignored
    .cpu_cen    ( cpu_cen   ),
    .int_n      ( int_n     ),
    .nmi_n      ( eff_nmin  ),
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
    // ROM access
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    )
);

wire [8:0] ma;
wire [1:0] nca;

assign ma = PRMR==1 ? A[8:0] : {A[9],A[7:0]};
/* verilator tracing_on */
generate if(PRMR==0) begin: dual
    wire [1:0] ncb;
    wire [15:0] auxb_l, auxb_r;
    reg signed [15:0] out_l, out_r;
    jt539_dual #(.VOLSHIFT_A(VOLSHIFT)) u_k54539(
        .rst        ( rst       ),
        .clk        ( clk       ),
        .cen        ( cen_pcm   ),
        .timeout_a  ( tima      ),
        .timeout_b  (           ),
        .addr_a     ( ma        ),
        .addr_b     ( {A[9],A[7:0]} ),
        .we_a       ( ~wr_n     ),
        .we_b       ( ~wr_n     ),
        .rd_a       ( ~rd_n     ),
        .rd_b       ( ~rd_n     ),
        .cs_a       ( k39a_cs   ),
        .cs_b       ( k39b_cs   ),
        .din_a      ( cpu_dout  ),
        .din_b      ( cpu_dout  ),
        .dout_a     ( k39a_dout ),
        .dout_b     ( k39b_dout ),
        .rom_cs_a   ( pcma_cs   ),
        .rom_cs_b   ( pcmb_cs   ),
        .rom_addr_a ( {nca,pcma_addr} ),
        .rom_addr_b ( {ncb,pcmb_addr} ),
        .rom_data_a ( pcma_data ),
        .rom_data_b ( pcmb_data ),
        .aux_l_a    ( k539b_l   ),
        .aux_r_a    ( k539b_r   ),
        .aux_l_b    ( auxb_l    ),
        .aux_r_b    ( auxb_r    ),
        .left_a     ( k539a_l   ),
        .right_a    ( k539a_r   ),
        .left_b     ( k539b_l   ),
        .right_b    ( k539b_r   ),
        .debug_bus  ( debug_bus ),
        .st_dout_a  ( sta_dout  ),
        .st_dout_b  ( stb_dout  )
    );
    assign auxb_l = 16'd0,
           auxb_r = 16'd0;
    always @(posedge clk) begin
        out_l <= k539a_l;
        out_r <= k539a_r;
    end
    assign k539_l = out_l,
           k539_r = out_r;
end else begin: single // 2nd jt539 not present in prmrsocr
    jt539_single #(.VOLSHIFT(VOLSHIFT)) u_k54539a(
        .rst        ( rst       ),
        .clk        ( clk       ),
        .cen        ( cen_pcm   ),
        .timeout    ( tima      ),
        .addr       ( ma        ),
        .we         ( ~wr_n     ),
        .rd         ( ~rd_n     ),
        .cs         ( k39a_cs   ),
        .din        ( cpu_dout  ),
        .dout       ( k39a_dout ),
        .rom_cs     ( pcma_cs   ),
        .rom_addr   ( {nca,pcma_addr} ),
        .rom_data   ( pcma_data ),
        .aux_l      ( 16'd0    ),
        .aux_r      ( 16'd0    ),
        .left       ( k539a_l   ),
        .right      ( k539a_r   ),
        .debug_bus  ( debug_bus ),
        .st_dout    ( sta_dout  )
    );
    assign k39b_dout=0,
           pcmb_cs=0, pcmb_addr=0, stb_dout=0,
           k539_l = k539a_l, k539_r = k539a_r;
end endgenerate

`else
assign k539_l=0, k539_r=0,
       m1_n=1, mreq_n=1, rfsh_n=1, wr_n=1, A=0, cpu_dout=0, iorq_n=1, tima=0,
       pcma_cs=0, pcmb_cs=0, pcma_addr=0, pcmb_addr=0, ram_dout=0,
       k39a_dout=0, k39b_dout=0, sta_dout=0, stb_dout=0;
`endif
endmodule 
