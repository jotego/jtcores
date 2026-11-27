/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-10-2026 */

module jtseicro_snd(
    input             rst, clk, audio_cen,
    input             bdir, bc1,
    input       [7:0] cpu_dout,
    output      [7:0] cpu_din,
    input       [7:0] debug_dip,
    output            irq_en, flip,
    output reg        mcu_run,
    output      [9:0] psg,
    output      [7:0] porta,
    output            sample
);

wire [7:0] porta_out, portb_out;
wire porta_oe, portb_oe;
reg [7:0] portb;
reg mcu_clk_l;
wire mcu_clk = !portb_oe || portb_out[2];

`ifdef NOMAIN
reg [7:0] scene_portb[0:0];
initial begin
    $readmemh("seicro_portb.hex",scene_portb);
    portb = scene_portb[0];
    $display("SEICRO_SCENE_PORTB=%02x",portb);
end
`endif

`ifdef NOMAIN
assign irq_en = portb[0];
`else
assign irq_en = !portb_oe || portb_out[0];
`endif
assign flip = portb[1];

always @(posedge clk) begin
    if(rst) begin
`ifndef NOMAIN
        portb <= 0;
`endif
        mcu_run <= 0;
        mcu_clk_l <= 1;
    end else begin
        mcu_clk_l <= mcu_clk;
        if(!mcu_clk_l && mcu_clk) mcu_run <= 1;
        if(portb_oe) begin
            portb <= portb_out;
        end
    end
end

`ifndef NOSOUND
assign porta = porta_oe ? porta_out : 8'hff;

jt49_bus u_ay8910(
    .rst_n   ( ~rst                        ),
    .clk     ( clk                         ),
    .clk_en  ( audio_cen                   ),
    .bdir    ( bdir                        ),
    .bc1     ( bc1                         ),
    .din     ( cpu_dout                    ),
    .dout    ( cpu_din                     ),
    .sel     ( 1'b1                        ),
    .sound   ( psg                         ),
    .sample  ( sample                      ),
    .A       (                             ),
    .B       (                             ),
    .C       (                             ),
    .IOA_in  ( porta                       ),
    .IOA_out ( porta_out                   ),
    .IOA_oe  ( porta_oe                    ),
    .IOB_in  ( {debug_dip[7:4],portb[3:0]} ),
    .IOB_out ( portb_out                   ),
    .IOB_oe  ( portb_oe                    )
);
`else
assign porta_out = 0;
assign porta_oe = 0;
assign porta = 0;
assign portb_out = 0;
assign portb_oe = 0;
assign cpu_din = 8'hff;
assign psg = 0;
assign sample = 0;
`endif

endmodule
