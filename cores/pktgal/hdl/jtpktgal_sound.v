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
    Date: 12-7-2026 */

module jtpktgal_sound(
    input             rst,
    input             clk,
    input             cen_6,
    input             cen_jt03,
    input             cen_opl2,
    input             cen_pcm,

    output     [15:0] rom_addr,
    output reg        rom_cs,
    input      [ 7:0] rom_data,
    input             rom_ok,

    input      [ 7:0] snd_latch,
    input             snd_irq,
    input             deco222,

    output signed [15:0] jt03_fm,
    output        [ 9:0] jt03_psg,
    output signed [15:0] ym3812,
    output signed [11:0] pcm,
    output     [ 7:0] st_dout
);
`ifndef NOSOUND
wire [15:0] cpu_addr;
wire [ 7:0] cpu_dout, ram_dout, ym1_dout, ym2_dout;
wire        cpu_rd, cpu_wr, cpu_acc, ym1_irqn, ym2_irqn, pcm_vclk;
wire        pcm_irq, pcm_irq_set, pcm_irq_clr, snd_nmi, snd_nmi_clr;
reg  [ 7:0] cpu_din, pcm_data;
reg  [ 3:0] pcm_nibble;
reg         ram_cs, ym1_cs, ym2_cs, pcm_data_cs, bank_cs, latch_cs, unk_cs;
reg         snd_bank, pcm_rst, pcm_toggle;

assign rom_addr    = cpu_addr[15] ? cpu_addr : { 1'b0, snd_bank, cpu_addr[13:0] };
assign pcm_irq_set = pcm_vclk & ~pcm_toggle;
assign pcm_irq_clr = cpu_rd & (cpu_addr == 16'hfffe) & ~pcm_irq_set;
assign snd_nmi_clr = cpu_rd & latch_cs;
assign cpu_acc     = cpu_rd | cpu_wr;
assign st_dout     = { 6'd0, snd_nmi, snd_bank };

always @* begin
    ram_cs      = cpu_acc && cpu_addr[15:11] == 5'b0000_0; // 0000-07ff
    ym1_cs      = cpu_acc && cpu_addr[15: 1] == 15'h0400;  // 0800-0801
    ym2_cs      = cpu_acc && cpu_addr[15: 1] == 15'h0800;  // 1000-1001
    pcm_data_cs = cpu_acc && cpu_addr == 16'h1800;
    bank_cs     = cpu_acc && cpu_addr == 16'h2000;
    latch_cs    = cpu_acc && cpu_addr == 16'h3000;
    unk_cs      = cpu_acc && cpu_addr == 16'h3400;
    rom_cs      = cpu_acc && cpu_addr[15:14] != 2'b00;
end

jtframe_edge u_pcm_irq(
    .rst    ( rst         ),
    .clk    ( clk         ),
    .edgeof ( pcm_irq_set ),
    .clr    ( pcm_irq_clr ),
    .q      ( pcm_irq     )
);

jtframe_edge u_snd_nmi(
    .rst    ( rst         ),
    .clk    ( clk         ),
    .edgeof ( snd_irq     ),
    .clr    ( snd_nmi_clr ),
    .q      ( snd_nmi     )
);

always @* begin
    cpu_din = rom_cs   ? rom_data  :
              ram_cs   ? ram_dout  :
              ym1_cs   ? ym1_dout  :
              ym2_cs   ? ym2_dout  :
              latch_cs ? snd_latch :
              unk_cs   ? 8'd0      : 8'hff;
end

always @(posedge clk) begin
    if( rst ) begin
        snd_bank  <= 0;
        pcm_rst   <= 0;
        pcm_data  <= 0;
        pcm_nibble<= 0;
        pcm_toggle<= 0;
    end else begin
        if( cpu_wr ) begin
            if( bank_cs ) begin
                snd_bank <= cpu_dout[2];
                pcm_rst  <= cpu_dout[1];
            end
            if( pcm_data_cs ) begin
                pcm_data <= cpu_dout;
            end
        end
        if( pcm_vclk ) begin
            pcm_nibble <=  pcm_toggle ? pcm_data[7:4] : pcm_data[3:0];
            pcm_toggle <= ~pcm_toggle;
        end
    end
end

jt65c02 #(.DECO222(1)) u_cpu(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen_6     ),
    .irq    ( pcm_irq   ),
    .nmi    ( snd_nmi   ),
    .opdec  ( deco222   ),
    .wr     ( cpu_wr    ),
    .rd     ( cpu_rd    ),
    .fetch  (           ),
    .addr   ( cpu_addr  ),
    .din    ( cpu_din   ),
    .dout   ( cpu_dout  )
);

jtframe_ram #(.AW(11)) u_ram(
    .clk    ( clk               ),
    .cen    ( 1'b1              ),
    .data   ( cpu_dout          ),
    .addr   ( cpu_addr[10:0]    ),
    .we     ( cpu_wr & ram_cs   ),
    .q      ( ram_dout          )
);

jt03 u_ym1(
    .rst        ( rst         ),
    .clk        ( clk         ),
    .cen        ( cen_jt03    ),
    .din        ( cpu_dout    ),
    .addr       ( cpu_addr[0] ),
    .cs_n       ( ~ym1_cs     ),
    .wr_n       ( ~cpu_wr     ),
    .dout       ( ym1_dout    ),
    .irq_n      ( ym1_irqn    ),
    .IOA_in     ( 8'd0        ),
    .IOB_in     ( 8'd0        ),
    .IOA_out    (             ),
    .IOB_out    (             ),
    .IOA_oe     (             ),
    .IOB_oe     (             ),
    .psg_A      (             ),
    .psg_B      (             ),
    .psg_C      (             ),
    .fm_snd     ( jt03_fm     ),
    .psg_snd    ( jt03_psg    ),
    .snd        (             ),
    .snd_sample (             ),
    .debug_view (             )
);

jtopl2 u_ym2(
    .rst    ( rst         ),
    .clk    ( clk         ),
    .cen    ( cen_opl2    ),
    .din    ( cpu_dout    ),
    .addr   ( cpu_addr[0] ),
    .cs_n   ( ~ym2_cs     ),
    .wr_n   ( ~cpu_wr     ),
    .dout   ( ym2_dout    ),
    .irq_n  ( ym2_irqn    ),
    .snd    ( ym3812      ),
    .sample (             )
);

jt5205 u_pcm(
    .rst    ( pcm_rst    ),
    .clk    ( clk        ),
    .cen    ( cen_pcm    ),
    .sel    ( 2'b10      ), // 8 kHz VCLK
    .din    ( pcm_nibble ),
    .sound  ( pcm        ),
    .sample (            ),
    .irq    (            ),
    .vclk_o ( pcm_vclk   )
);

`else
assign rom_addr = 16'd0;
assign jt03_fm  = 16'sd0;
assign jt03_psg = 10'd0;
assign ym3812   = 16'sd0;
assign pcm      = 12'sd0;
assign st_dout  = 8'd0;

initial rom_cs = 1'b0;
`endif

endmodule
