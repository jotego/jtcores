/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

module jtroundu_snd(
    input rst,
    input clk,
    input cen,
    input fm_cen,
    input oki_cen,
    input halt,
    input [7:0] in0,
    input [7:0] in1,
    input [7:0] stick,
    input [15:0] v30_addr,
    input v30_sel,
    input v30_rd,
    input v30_wr,
    input [7:0] v30_din,
    output [7:0] v30_dout,
    output v30_ok,
    output signed [15:0] snd,
    output sample,
    output [15:0] audiocpu_addr,
    output audiocpu_cs,
    input [7:0] audiocpu_data,
    input audiocpu_ok,
    output [15:0] v30_audio_rom_addr,
    output v30_audio_rom_cs,
    input [7:0] v30_audio_rom_data,
    input v30_audio_rom_ok,
    output [17:0] oki_addr,
    output oki_cs,
    input [7:0] oki_data,
    input oki_ok,
    output [12:0] soundram_addr,
    output [7:0] soundram_din,
    input [7:0] soundram_dout,
    output soundram_we,
    output [12:0] v30_soundram_addr,
    output [7:0] v30_soundram_din,
    input [7:0] v30_soundram_dout,
    output v30_soundram_we
);

wire [15:0] cpu_addr;
wire [7:0] cpu_dout;
reg [7:0] cpu_din;
wire mreq_n, rd_n, wr_n, rfsh_n, busak_n;
wire cpu_mem = !mreq_n && rfsh_n && busak_n;
wire cpu_ram = cpu_addr >= 16'he000 && cpu_addr <= 16'hffef;
wire v30_ram = v30_addr >= 16'he000 && v30_addr <= 16'hffef;
wire host_io = v30_sel && v30_addr >= 16'hfff0;
wire [15:0] io_addr = host_io ? v30_addr : cpu_addr;
wire [7:0] io_din = host_io ? v30_din : cpu_dout;
wire io_rd = host_io ? v30_rd : cpu_mem && !rd_n;
wire io_wr = host_io ? v30_wr : cpu_mem && !wr_n;
wire fm_cs = io_addr[15:1] == 15'h7ff8 && (io_rd || io_wr);
wire pcm_cs = io_addr == 16'hfff4 && (io_rd || io_wr);
wire ppi_cs = io_addr[15:2] == 14'h3ffe && (io_rd || io_wr);
wire [7:0] fm_dout, pcm_dout, ppi_dout;
reg [7:0] io_dout;
wire fm_irq_n;
reg fm_half;
wire signed [15:0] fm_left, fm_right;
wire signed [13:0] pcm_snd;
assign audiocpu_addr = cpu_addr;
assign audiocpu_cs = cpu_mem && !rd_n && cpu_addr <= 16'hdfff;
assign v30_audio_rom_addr = v30_addr;
assign v30_audio_rom_cs = v30_rd && v30_addr <= 16'hdfff;
assign v30_ok = !v30_audio_rom_cs || v30_audio_rom_ok;
assign v30_dout = v30_audio_rom_cs ? v30_audio_rom_data : v30_ram ? v30_soundram_dout : io_dout;
assign soundram_addr = cpu_addr[12:0];
assign soundram_din = cpu_dout;
assign soundram_we = cpu_mem && cpu_ram && !wr_n && cen;
assign v30_soundram_addr = v30_addr[12:0];
assign v30_soundram_din = v30_din;
assign v30_soundram_we = v30_wr && v30_ram;
assign oki_cs = 1'b1;

jtroundu_mix u_mix (
    .fm_left  ( fm_left  ),
    .fm_right ( fm_right ),
    .pcm      ( pcm_snd  ),
    .snd      ( snd      )
);

always @* begin
    io_dout = 8'hff;
    if (fm_cs) io_dout = fm_dout;
    else if (pcm_cs) io_dout = pcm_dout;
    else if (ppi_cs) io_dout = ppi_dout;
    else if (io_addr == 16'hfffc) io_dout = stick;
    cpu_din = 8'hff;
    if (cpu_mem && !rd_n) begin
        if (audiocpu_cs) cpu_din = audiocpu_data;
        else if (cpu_ram) cpu_din = soundram_dout;
        else if (!host_io) cpu_din = io_dout;
    end
end

always @(posedge clk) begin
    if (rst) fm_half <= 0;
    else if (fm_cen) fm_half <= ~fm_half;
end

jtframe_z80 u_cpu (
    .rst_n   ( ~rst                        ),
    .clk     ( clk                         ),
    .cen     ( cen                         ),
    .wait_n  ( !audiocpu_cs || audiocpu_ok ),
    .int_n   ( fm_irq_n                    ),
    .nmi_n   ( 1'b1                        ),
    .busrq_n ( ~halt                       ),
    .m1_n    (                             ),
    .mreq_n  ( mreq_n                      ),
    .iorq_n  (                             ),
    .rd_n    ( rd_n                        ),
    .wr_n    ( wr_n                        ),
    .rfsh_n  ( rfsh_n                      ),
    .halt_n  (                             ),
    .busak_n ( busak_n                     ),
    .A       ( cpu_addr                    ),
    .din     ( cpu_din                     ),
    .dout    ( cpu_dout                    )
);

jt8255 u_ppi (
    .rst        ( rst          ),
    .clk        ( clk          ),
    .addr       ( io_addr[1:0] ),
    .din        ( io_din       ),
    .dout       ( ppi_dout     ),
    .rdn        ( ~io_rd       ),
    .wrn        ( ~io_wr       ),
    .csn        ( ~ppi_cs      ),
    .porta_din  ( in0          ),
    .portb_din  ( in1          ),
    .portc_din  ( 8'hff        ),
    .porta_dout (              ),
    .portb_dout (              ),
    .portc_dout (              )
);

jt51 u_fm (
    .rst    ( rst               ),
    .clk    ( clk               ),
    .cen    ( fm_cen            ),
    .cen_p1 ( fm_cen && fm_half ),
    .cs_n   ( ~fm_cs            ),
    .wr_n   ( ~io_wr            ),
    .a0     ( io_addr[0]        ),
    .din    ( io_din            ),
    .dout   ( fm_dout           ),
    .ct1    (                   ),
    .ct2    (                   ),
    .irq_n  ( fm_irq_n          ),
    .sample ( sample            ),
    .left   (                   ),
    .right  (                   ),
    .xleft  ( fm_left           ),
    .xright ( fm_right          )
);

jt6295 u_pcm (
    .rst      ( rst                ),
    .clk      ( clk                ),
    .cen      ( oki_cen            ),
    .ss       ( 1'b1               ),
    .wrn      ( !(pcm_cs && io_wr) ),
    .din      ( io_din             ),
    .dout     ( pcm_dout           ),
    .rom_addr ( oki_addr           ),
    .rom_data ( oki_data           ),
    .rom_ok   ( oki_ok             ),
    .sound    ( pcm_snd            ),
    .sample   (                    )
);

endmodule
