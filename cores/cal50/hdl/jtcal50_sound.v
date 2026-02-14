/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-11-2025 */

module jtcal50_sound(
    input              clk,
    input              rst,
    input              cen2, cen244, cen_pcm,

    input       [ 7:0] snd_cmd,
    output      [ 7:0] snd_rply,
    input              set_cmd,
    // PCM ROM
    output      [19:0] pcm_addr,
    input       [ 7:0] pcm_data,
    output             pcm_cs,
    // ROM
    input              rom_ok,
    output reg         rom_cs,
    output      [17:0] rom_addr,
    input       [ 7:0] rom_data,
    // Sound
    output signed [15:0] snd,
    output             mute,
    // Debug
    input       [ 7:0] debug_bus,
    output      [ 7:0] st_dout
);
`ifndef NOSOUND
wire [15:0] A;
wire [ 4:0] rom_upper;
reg  [ 7:0] cpu_din;
wire [ 7:0] nc, cfg, cpu_dout, pcm_dout;
wire [ 3:0] bank;
reg         cfg_cs, bank_cs, st_cs, cmd_cs, x1pcm_cs;
wire        nmi, nmi_clrn, irq, irq_clrn, rnw,
            cpu_wr, cpu_rd, cpu_acc;

// $4'0000 (256kB), 16 pages of 8kB each (128kB) plus $4000 (16kB) Fixed
assign rom_addr  = { rom_upper, A[12:0] };
assign rom_upper = bank_cs ? {bank,A[13]} : {4'b00,A[13]};
assign {bank,nmi_clrn,irq_clrn,mute} = cfg[7:1];

assign st_dout     = {7'd0,mute};
assign rnw         =~cpu_wr;
assign cpu_acc     = cpu_wr | cpu_rd;

always @* begin
    x1pcm_cs = cpu_acc && A[15:12]<=1;
    cmd_cs   = cpu_rd  && A[15:12]==4;
    cfg_cs   = cpu_wr  && A[15:12]==4;
    rom_cs   = cpu_rd  && A[15];
    bank_cs  = cpu_rd  && A[15:14]==2;
    st_cs    = cpu_wr  && A[15:12]==4'hc;
end

jtframe_edge u_244hz(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( cen244    ),
    .clr    (~irq_clrn  ),
    .q      ( irq       )
);

jtframe_edge u_cmd(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( set_cmd   ),
    .clr    (~nmi_clrn  ),
    .q      ( nmi       )
);

jtframe_8bit_reg u_st(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .wr_n       ( rnw       ),
    .din        ( cpu_dout  ),
    .cs         ( st_cs     ),
    .dout       ( snd_rply  )
);

jtframe_8bit_reg u_cfg(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .wr_n       ( rnw       ),
    .din        ( cpu_dout  ),
    .cs         ( cfg_cs   ),
    .dout       ( cfg       )
);

always @* begin
    cpu_din = rom_cs   ? rom_data :
              x1pcm_cs ? pcm_dout :
              cmd_cs   ? snd_cmd  : 8'h0;
end

jtx1010 u_pcm(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_pcm   ),

    // CPU interface
    .cpu_addr   ( A[12:0]   ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    ( pcm_dout  ),
    .cpu_wr     ( cpu_wr    ),
    .cpu_cs     ( x1pcm_cs  ),

    // ROM interface
    .rom_addr   ( pcm_addr  ),
    .rom_data   ( pcm_data  ),
    .rom_cs     ( pcm_cs    ),

    // sound output
    .snd_left   (           ),
    .snd_right  ( snd       ),
    .sample     (           )
);

jt65c02 u_cpu(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen2      ),  // crystal clock freq. = 4x E pin freq.
    .irq    ( irq       ),
    .nmi    ( nmi       ),
    .rd     ( cpu_rd    ),
    .wr     ( cpu_wr    ),
    .addr   ( A         ), // always valid
    .din    ( cpu_din   ),
    .dout   ( cpu_dout  )
);
`else
    initial rom_cs   = 0;
    assign  pal_cs   = 0;
    assign  ram_cs   = 0;
    assign  snd_irq  = 0;
    assign  snd_latch= 0;
    assign  rom_addr = 0;
    assign  mcu_addr = 0;
    assign  A = 0;
    assign  rnw  = 1;
    assign  cpu_dout = 0;
`endif
endmodule
