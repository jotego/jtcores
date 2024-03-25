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
    Date: 24-9-2023 */

module jtshouse_colmix(
    input             rst,
    input             clk,

    input             pxl_cen, lvbl, lhbl,
    input      [ 8:0] hdump, vdump,
    output reg        raster_irqn,

    // pixels
    input      [10:0] scr_pxl,  obj_pxl,
    input      [ 2:0] scr_prio, obj_prio,

    input      [14:0] cpu_addr,
    input             cs, cpu_rnw,
    output     [12:0] rgb_addr, pal_addr,
    output            rpal_we, gpal_we, bpal_we,

    input      [ 7:0] cpu_dout,
                      red_dout,   rpal_dout,
                      green_dout, gpal_dout,
                      blue_dout,  bpal_dout,
    output reg [ 7:0] pal_dout,
    output     [ 7:0] red, green, blue,
    // Debug
    input      [ 3:0] ioctl_addr,
    input      [ 7:0] ioctl_din,
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

wire [ 7:0] st_mmr;
wire [12:0] scr_rgb, obj_rgb;
reg         mmr_cs, r_cs, g_cs, b_cs;
wire        blank, lyr_sel;
wire [15:0] left, right, top, bottom, hirq, virq;

assign pal_addr = { cpu_addr[14:13], cpu_addr[10:0] };
assign scr_rgb  = { 2'b01, scr_pxl };
assign obj_rgb  = { 2'b00, obj_pxl };
assign lyr_sel  = (obj_prio>=scr_prio && obj_pxl[3:0]!='hf) && gfx_en[3] || !gfx_en[0]; // 1 = obj, 0 = scr
assign rgb_addr = lyr_sel ? obj_rgb : scr_rgb;

assign rpal_we = ~cpu_rnw & r_cs;
assign gpal_we = ~cpu_rnw & g_cs;
assign bpal_we = ~cpu_rnw & b_cs;
assign st_dout = st_mmr;

`ifdef GRAY
assign red   = blank ? 8'd0 : {8{scr_pxl[0]}};
assign green = blank ? 8'd0 : {8{scr_pxl[0]}};
assign blue  = blank ? 8'd0 : {8{scr_pxl[0]}};
`else
assign red   = blank ? 8'd0 : red_dout;
assign green = blank ? 8'd0 : green_dout;
assign blue  = blank ? 8'd0 : blue_dout;
`endif
assign blank = ~(lhbl & lvbl);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pal_dout    <= 0;
        raster_irqn <= 1;
    end else begin
        raster_irqn <= !(vdump==virq[8:0] && hdump==hirq[8:0]);
        pal_dout <= r_cs ? rpal_dout :
                    g_cs ? gpal_dout :
                    b_cs ? bpal_dout : mmr_dout;
    end
end

always @* begin
    r_cs   = 0;
    g_cs   = 0;
    b_cs   = 0;
    mmr_cs = 0;
    if(cs) case( cpu_addr[14:11] )
        0, 4, 8,12: r_cs = 1;
        1, 5, 9,13: g_cs = 1;
        2, 6,10,14: b_cs = 1;
        default:  mmr_cs = 1;
    endcase
end

jtshouse_cus116_mmr u_mmr(
    .rst    ( rst           ),
    .clk    ( clk           ),

    .cs     ( mmr_cs        ),
    .addr   ( cpu_addr[2:0] ),
    .rnw    ( cpu_rnw       ),
    .din    ( cpu_dout      ),
    .dout   ( mmr_dout      ),

    .left   ( left          ),
    .right  ( right         ),
    .top    ( top           ),
    .bottom ( bottom        ),
    .hirq   ( hirq          ),
    .virq   ( virq          ),

    // IOCTL dump
    .ioctl_addr ( ioctl_addr    ),
    .ioctl_din  ( ioctl_din     ),
    // Debug
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_mmr        )
);

endmodule