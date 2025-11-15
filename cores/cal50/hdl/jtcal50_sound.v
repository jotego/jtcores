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

module jtcal50_main(
    input              clk,        // 24 MHz
    input              rst,
    input              cen3,
    input              cen1p5,
    input              LVBL,
    input              v8,

    input       [ 7:0] snd_cmd,
    output      [ 7:0] snd_st,

    // ROM
    input              rom_ok,
    output reg         rom_cs,
    output      [17:0] rom_addr,
    input       [ 7:0] rom_data
);
`ifndef NOMAIN
wire [15:0] A;
wire [ 4:0] rom_upper;
reg  [ 7:0] cpu_din;
wire [ 7:0] cfg;
wire [ 3:0] bank;
reg         bank_cs, banked, st_cs, cmd_cs, x1pcm_cs;
wire        rdy, nmi_n, nmi_clrn, irqn, irq_clrn, mute;

// $4'0000 (256kB), 16 pages of 8kB each (128kB) plus $4000 (16kB) Fixed
assign rom_addr  = { rom_upper, A[12:0] };
assign rom_upper = banked ? {1'b0,bank}+5'h1 : {3'b0,A[14:13]}
assign rdy       = ~rom_cs | rom_ok;
assign nmi_n     = LVBL & dip_pause;
assign {bank,nmi_clrn,irq_clrn,mute} = cfg[7:1];

always @* begin
    x1pcm_cs = A[15:12]<=1;
    cmd_cs   = A[15:12]==4 &&  rnw;
    bank_cs  = A[15:12]==4 && !rnw;
    banked   = A[15:12]<=4'hc && A[15];
    rom_cs   = A[15] && rnw;
    st_cs    = A[15:12]==4'hc && !rnw;
end

jtframe_8bit_reg u_st(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .wr_n       ( rnw       ),
    .din        ( cpu_dout  ),
    .cs         ( st_cs     ),
    .dout       ( snd_st    )
);

jtframe_8bit_reg u_cfg(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .wr_n       ( rnw       ),
    .din        ( cpu_dout  ),
    .cs         ( bank_cs   ),
    .dout       ( cfg       )
);

always @(posedge clk) begin
    cpu_din <=rom_cs      ? rom_data :
              ram_cs      ? ram_dout :
              cmd_cs      ? snd_cmd  : 8'h0;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank      <= 0;
        snd_latch <= 0;
        scrpos    <= 0;
        flip      <= 0;
    end else begin
        if( bank_cs ) bank <= cpu_dout[0];
        if( snd_irq ) snd_latch <= cpu_dout;
        if( scrpos0_cs ) scrpos[7:0] <= cpu_dout;
        if( scrpos1_cs ) scrpos[9:8] <= cpu_dout[1:0];
        if( flip_cs ) flip <= ~cpu_dout[0];
    end
end

jtframe_ff u_ff (
    .clk    ( clk       ),
    .rst    ( rst       ),
    .cen    ( cen1p5    ),
    .din    ( 1'b1      ),
    .q      (           ),
    .qn     ( irqn      ),
    .set    ( 1'b0      ),
    .clr    ( irq_clr   ),
    .sigedge( v8        )
);

wire [7:0] nc;
/* verilator tracing_off */
T65 u_cpu(
    .Mode   ( 2'd0      ),  // 6502 mode
    .Res_n  ( ~rst      ),
    .Enable ( cen1p5    ),
    .Clk    ( clk       ),
    .Rdy    ( rdy       ),
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
