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

module jtpktgal_main(
    input             rst,
    input             clk,
    input             cen_cpu,

    output     [15:0] rom_addr,
    output            rom_cs,
    input      [ 7:0] rom_data,
    input             rom_ok,

    input      [ 1:0] coin,
    input      [ 1:0] cab_1p,
    input      [ 5:0] joystick1,
    input      [ 5:0] joystick2,
    input      [ 7:0] dipsw,
    input             dip_pause,
    input             LVBL,

    output     [10:1] pf_cpu_addr,
    output     [15:0] pf_cpu_din,
    input      [15:0] pf_cpu_dout,
    output     [ 1:0] pf_we,
    output     [ 8:0] obj_cpu_addr,
    output     [ 7:0] obj_cpu_din,
    input      [ 7:0] obj_cpu_dout,
    output            obj_we,

    output     [ 4:0] bac06_addr,
    output     [ 7:0] bac06_din,
    input      [ 7:0] bac06_dout,
    output            bac06_cs,
    output            bac06_rnw,

    output reg [ 7:0] snd_latch,
    output reg        snd_irq,
    output     [ 7:0] st_dout
);

`ifndef NOMAIN
wire [15:0] cpu_addr;
wire [ 7:0] cpu_dout, ram_dout, pf_dout_byte;
wire [ 3:0] ctrl1_lo_addr, ctrl1_hi_addr, ctrl1_rd_addr, ctrl1_wr_addr;
wire        cpu_rd, cpu_wr, cpu_acc, main_nmi, cab_cs;
reg  [ 7:0] cpu_din, cab_dout, bank;
reg         ram_cs, pf_cs, obj_cs, p1_cs, p2_cs, dsw_cs, bank_cs, snd_cs,
            ctrl0_cs, ctrl1_cs;

assign ctrl1_lo_addr = { cpu_addr[3:1], 1'b0 };
assign ctrl1_hi_addr = ctrl1_lo_addr + 4'd1;
assign ctrl1_rd_addr = cpu_addr[0] ? ctrl1_lo_addr : ctrl1_hi_addr;
assign ctrl1_wr_addr = cpu_addr[3:0] < 4'd4 ? ctrl1_rd_addr : ctrl1_lo_addr;
assign cab_cs        = p1_cs | p2_cs | dsw_cs;

always @* begin
    ram_cs   = cpu_acc && cpu_addr[15:11] == 5'b0000_0; // 0000-07ff
    pf_cs    = cpu_acc && cpu_addr[15:11] == 5'b0000_1; // 0800-0fff
    obj_cs   = cpu_acc && cpu_addr[15: 9] == 7'b0001_000; // 1000-11ff
    p1_cs    = cpu_acc && cpu_addr == 16'h1800;
    p2_cs    = cpu_acc && cpu_addr == 16'h1a00;
    dsw_cs   = cpu_acc && cpu_addr == 16'h1c00;
    ctrl0_cs = cpu_acc && cpu_addr[15: 3] == 13'h0300;  // 1800-1807
    ctrl1_cs = cpu_acc && cpu_addr[15: 4] == 12'h181;   // 1810-181f
    bank_cs  = dsw_cs;
    snd_cs   = p2_cs;
end

always @* begin
    cpu_din = rom_cs   ? rom_data     :
              ram_cs   ? ram_dout     :
              pf_cs    ? pf_dout_byte :
              obj_cs   ? obj_cpu_dout :
              cab_cs   ? cab_dout     :
              ctrl1_cs ? bac06_dout   : 8'hff;
end

always @(posedge clk) begin
    case( cpu_addr[11:8] )
        4'h8:    cab_dout <= { joystick1[5:4], cab_1p[1:0], joystick1[3:0] };
        4'ha:    cab_dout <= { joystick2[5:4], coin[1:0],   joystick2[3:0] };
        default: cab_dout <= dipsw;
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        bank      <= 0;
        snd_latch <= 0;
        snd_irq   <= 0;
    end else begin
        snd_irq <= 0;
        if( cpu_wr && bank_cs ) bank <= cpu_dout;
        if( cpu_wr && snd_cs ) begin
            snd_latch <= cpu_dout;
            snd_irq   <= 1;
        end
    end
end

assign rom_cs   = cpu_acc && cpu_addr[15:14] != 2'b00;
assign rom_addr = cpu_addr[15] ? cpu_addr :
                  cpu_addr[13] ? { 1'b0, bank[1], 1'b1, cpu_addr[12:0] } :
                                 { 1'b0, bank[0], 1'b0, cpu_addr[12:0] };
assign st_dout  = { (rom_cs & ~rom_ok), bank[1:0], cen_cpu,
                    ram_cs, pf_cs, obj_cs, snd_cs };
assign main_nmi = ~LVBL & dip_pause;

jt65c02 u_cpu(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen_cpu   ),
    .irq    ( 1'b0      ),
    .nmi    ( main_nmi  ),
    .opdec  ( 1'b0      ),
    .wr     ( cpu_wr    ),
    .rd     ( cpu_rd    ),
    .fetch  (           ),
    .addr   ( cpu_addr  ),
    .din    ( cpu_din   ),
    .dout   ( cpu_dout  )
);

assign pf_dout_byte = cpu_addr[0] ? pf_cpu_dout[7:0] : pf_cpu_dout[15:8];
assign pf_cpu_addr  = cpu_addr[10:1];
assign pf_cpu_din   = { cpu_dout, cpu_dout };
assign pf_we        = {2{cpu_wr & pf_cs}} & (cpu_addr[0] ? 2'b01 : 2'b10);
assign obj_cpu_addr = cpu_addr[8:0];
assign obj_cpu_din  = cpu_dout;
assign obj_we       = cpu_wr & obj_cs;
assign bac06_cs     = ctrl0_cs | ctrl1_cs;
assign bac06_addr   = ctrl0_cs ? { 3'd0, cpu_addr[2:1] } :
                                 5'd8 + { 1'b0, cpu_wr ? ctrl1_wr_addr : ctrl1_rd_addr };
assign bac06_din    = cpu_dout;
assign bac06_rnw    = ~cpu_wr;
assign cpu_acc      = cpu_rd | cpu_wr;

jtframe_ram #(.AW(11)) u_ram(
    .clk    ( clk               ),
    .cen    ( 1'b1              ),
    .data   ( cpu_dout          ),
    .addr   ( cpu_addr[10:0]    ),
    .we     ( cpu_wr & ram_cs   ),
    .q      ( ram_dout          )
);

`else
assign rom_addr     = 16'd0;
assign rom_cs       = 1'b0;
assign pf_cpu_addr  = 10'd0;
assign pf_cpu_din   = 16'd0;
assign pf_we        = 2'd0;
assign obj_cpu_addr = 9'd0;
assign obj_cpu_din  = 8'd0;
assign obj_we       = 1'b0;
assign bac06_addr   = 5'd0;
assign bac06_din    = 8'd0;
assign bac06_cs     = 1'b0;
assign bac06_rnw    = 1'b1;
assign st_dout      = 8'd0;

initial begin
    snd_latch = 8'd0;
    snd_irq   = 1'b0;
end
`endif

endmodule
