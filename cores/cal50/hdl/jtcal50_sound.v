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
    input              clk,        // 24 MHz
    input              rst,
    input              cen2,
    input              cen244,

    input       [ 7:0] snd_cmd,
    output      [ 7:0] snd_rply,
    input              set_cmd,
    // PCM RAM
    output             pcmram_we,
    output      [ 7:0] pcmram_din,
    input       [ 7:0] pcmram_dout,
    output      [12:0] pcmram_addr,
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
    output      [15:0] snd,
    output             sample,
    // Debug
    input       [ 7:0] debug_bus,
    output      [ 7:0] st_dout
);
`ifndef NOSOUND
wire [15:0] A;
wire [ 4:0] rom_upper;
reg  [ 7:0] cpu_din;
wire [ 7:0] nc, cfg, cpu_dout;
wire [ 3:0] bank;
reg         cfg_cs, bank_cs, st_cs, cmd_cs, x1pcm_cs;
wire        rdy, nmi_n, nmi_clrn, irqn, irq_clrn, mute, rnw;

// $4'0000 (256kB), 16 pages of 8kB each (128kB) plus $4000 (16kB) Fixed
assign rom_addr  = { rom_upper, A[12:0] };
assign rom_upper = bank_cs ? {bank,A[13]} : {4'b00,A[13]};
assign rdy       = ~rom_cs | rom_ok;
assign {bank,nmi_clrn,irq_clrn,mute} = cfg[7:1];

assign pcmram_we   = x1pcm_cs & ~rnw;
assign pcmram_din  = cpu_dout;
assign pcmram_addr = A[12:0];
assign pcm_addr    = 0;
assign pcm_cs      = 0;
assign st_dout     = 0;
assign snd         = 0;
assign sample      = 0;

always @* begin
    x1pcm_cs = A[15:12]<=1;
    cmd_cs   = A[15:12]==4 &&  rnw;
    cfg_cs   = A[15:12]==4 && !rnw;
    rom_cs   = A[15] && rnw;
    bank_cs  = A[15:14]==2;
    st_cs    = A[15:12]==4'hc && !rnw;
end

jtframe_edge #(.QSET(0)) u_244hz(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( cen244    ),
    .clr    (~irq_clrn  ),
    .q      ( irqn      )
);

jtframe_edge #(.QSET(0)) u_cmd(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( set_cmd   ),
    .clr    (~nmi_clrn  ),
    .q      ( nmi_n     )
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

always @(posedge clk) begin
    cpu_din <=rom_cs      ? rom_data    :
              x1pcm_cs    ? pcmram_dout :
              cmd_cs      ? snd_cmd     : 8'h0;
end

localparam R65C02=2'b01;

wire ceng = cen2 & (rom_ok | ~rom_cs);

T65 u_cpu(
    .Mode   ( R65C02    ),
    .Res_n  ( ~rst      ),
    .Enable ( ceng      ),
    .Clk    ( clk       ),
    .Rdy    ( 1'b1      ),
    .Abort_n( 1'b1      ),
    .IRQ_n  ( irqn      ),
    .NMI_n  ( nmi_n     ),
    .SO_n   ( 1'b1      ),
    .R_W_n  ( rnw       ),
    .Sync   (           ),
    .EF     (           ),
    .MF     (           ),
    .XF     (           ),
    .ML_n   (           ),
    .VP_n   (           ),
    .VDA    (           ),
    .VPA    (           ),
    .A      ( {nc,A}    ),
    .DI     ( cpu_din   ),
    .DO     ( cpu_dout  )
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
