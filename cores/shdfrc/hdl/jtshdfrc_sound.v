/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-11-2026 */

module jtshdfrc_sound(
    input                rst,
    input                clk,

    input                cen_fm,
    input                cen_fm2,
    input                cen_oki,

    input                snd_on,
    input         [ 7:0] snd_latch,

    output        [15:0] rom_addr,
    input         [ 7:0] rom_data,
    output    reg        rom_cs,
    input                rom_ok,

    output        [18:0] pcm_addr,
    output               pcm_cs,
    input         [ 7:0] pcm_data,
    input                pcm_ok,

    output signed [15:0] fm_l, fm_r,
    output signed [13:0] pcm
);
`ifndef NOSOUND
reg         [ 7:0] din;
wire        [ 7:0] ram_dout, dout, oki_dout, fm_dout;
wire        [15:0] A;
wire        [17:0] oki_addr;
reg                fm_cs, ram_cs, oki_cs, latch_cs, bank_cs, oki_bank;
wire               iorq_n, m1_n, mreq_n, rfsh_n, int_n, oki_wrn, rd_n, wr_n, nmi_n;

assign pcm_cs   = 1;
assign oki_wrn  = ~(oki_cs & ~wr_n);
assign rom_addr = A;
assign pcm_addr = { oki_bank, oki_addr };

always @* begin
    rom_cs   = 0;
    ram_cs   = 0;
    fm_cs    = 0;
    oki_cs   = 0;
    latch_cs = 0;
    bank_cs  = 0;
    if( !mreq_n && rfsh_n ) begin
        casez( A[15:11] )
            5'b0????, 5'b10???: rom_cs = 1;
            5'b11000: ram_cs   = 1;
            5'b11001: fm_cs    = 1;
            5'b11011: oki_cs   = 1;
            5'b11100: latch_cs = 1;
            5'b11101: bank_cs  = 1;
            5'b11110, 5'b11111: ram_cs = 1;
            default:;
        endcase
    end
end

always @(posedge clk, posedge rst) begin
    if( rst )
        oki_bank <= 0;
    else if( bank_cs && !wr_n ) oki_bank <= dout[0];
end

always @(posedge clk) begin
    din <= ({8{rom_cs}}   & rom_data)  |
           ({8{ram_cs}}   & ram_dout)  |
           ({8{oki_cs}}   & oki_dout)  |
           ({8{fm_cs}}    & fm_dout)   |
           ({8{latch_cs}} & snd_latch);
end

jtframe_edge #(.QSET(0)) u_edge(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( snd_on    ),
    .clr    ( latch_cs  ),
    .q      ( nmi_n     )
);

jt6295 #(.INTERPOL(0)) u_adpcm(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_oki   ),
    .ss         ( 1'b1      ),

    .wrn        ( oki_wrn   ),
    .din        ( dout      ),
    .dout       ( oki_dout  ),

    .rom_addr   ( oki_addr  ),
    .rom_data   ( pcm_data  ),
    .rom_ok     ( pcm_ok    ),

    .sound      ( pcm       ),
    .sample     (           )
);

jtframe_sysz80 #(.RAM_AW(13)) u_cpu(
    .rst_n      ( ~rst        ),
    .clk        ( clk         ),
    .cen        ( cen_fm      ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ),
    .nmi_n      ( nmi_n       ),
    .busrq_n    ( 1'b1        ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .cpu_din    ( din         ),
    .cpu_dout   ( dout        ),
    .ram_dout   ( ram_dout    ),

    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);
/* verilator tracing_off */
jt51 u_jt51(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .cen_p1     ( cen_fm2   ),
    .cs_n       ( !fm_cs    ),
    .wr_n       ( wr_n      ),
    .a0         ( A[0]      ),
    .din        ( dout      ),
    .dout       ( fm_dout   ),
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      ( int_n     ),

    .sample     (           ),
    .left       (           ),
    .right      (           ),

    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);

`else
    initial rom_cs   = 0;
    assign  rom_addr = 0;
    assign  pcm_addr = 0;
    assign  pcm_cs   = 0;
    assign  fm_l     = 0, fm_r = 0;
    assign  pcm      = 0;
`endif
endmodule
