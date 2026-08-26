/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-5-2021 */

module jtframe_8751mcu(
    input         rst,
    input         clk,
    input         cen,

    input         int0n,
    input         int1n,

    input  [ 7:0] p0_i,
    input  [ 7:0] p1_i,
    input  [ 7:0] p2_i,
    input  [ 7:0] p3_i,

    output [ 7:0] p0_o,
    output [ 7:0] p1_o,
    output [ 7:0] p2_o,
    output [ 7:0] p3_o,

    // external memory
    input      [ 7:0] x_din,
    output reg [ 7:0] x_dout,
    output reg [15:0] x_addr,
    output reg        x_wr,
    output reg        x_acc,

    // ROM programming
    input         clk_rom,
    input [11:0]  prog_addr,
    input [ 7:0]  prom_din,
    input         prom_we
);

parameter ROMBIN="",
          SYNC_XDATA = 0,
          SYNC_INT = 0,
          SYNC_P0 = 0,
          SYNC_P1 = 0,
          SYNC_P2 = 0,
          SYNC_P3 = 0;

wire [ 7:0] rom_data, ram_data, ram_q;
reg  [15:0] rom_addr;
wire [ 6:0] ram_addr;
wire        ram_we;
reg  [ 7:0] xin_pipe, xin_sync, p0_s, p1_s, p2_s, p3_s;
wire [ 7:0] pre_dout;
wire [15:0] pre_addr, pre_rom;
wire        pre_wr, pre_acc;
wire        cen_eff = cen;

always @(posedge clk) begin
    if (rst) begin
        xin_pipe <= 8'd0;
        xin_sync <= 8'd0;
    end else if(cen_eff) begin
        xin_pipe <= x_din;
        xin_sync <= xin_pipe;
        p0_s     <= p0_i;
        p1_s     <= p1_i;
        p2_s     <= p2_i;
        p3_s     <= p3_i;
    end
end

wire int0n_s, int1n_s;

jtframe_sync #(.W(2)) u_sync(
    .clk_in (   clk               ), // not resampled
    .clk_out(   clk               ),
    .raw    ( {int1n, int0n }     ),
    .sync   ( {int1n_s, int0n_s } )
);

// You need to clock gate for reading or the MCU won't work
jtframe_dual_ram_cen #(.AW(12),.SIMFILE(ROMBIN)) u_prom(
    .clk0   ( clk_rom   ),
    .cen0   ( 1'b1      ),
    .clk1   ( clk       ),
    .cen1   ( cen_eff   ),
    // Port 0
    .data0  ( prom_din  ),
    .addr0  ( prog_addr ),
    .we0    ( prom_we   ),
    .q0     (           ),
    // Port 1
    .data1  (           ),
    .addr1  ( rom_addr[11:0]  ),
    .we1    ( 1'b0      ),
    .q1     ( rom_data  )
);

jtframe_ram_rst #(.AW(7),.CEN_RD(1)) u_ramu(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .cen        ( cen_eff           ),
    .addr       ( ram_addr          ),
    .data       ( ram_data          ),
    .we         ( ram_we            ),
    .q          ( ram_q             )
);

always @(posedge clk) begin
    x_addr   <= pre_addr;
    x_wr     <= pre_wr;
    x_dout   <= pre_dout;
    x_acc    <= pre_acc;
    rom_addr <= pre_rom;
end
/* verilator tracing_on */
jt8051 u_mcu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_eff   ),
    .int0n      ( SYNC_INT ? int0n_s : int0n ),
    .int1n      ( SYNC_INT ? int1n_s : int1n ),
    .p0_i       ( SYNC_P0 ? p0_s : p0_i ),
    .p1_i       ( SYNC_P1 ? p1_s : p1_i ),
    .p2_i       ( SYNC_P2 ? p2_s : p2_i ),
    .p3_i       ( SYNC_P3 ? p3_s : p3_i ),
    .p0_o       ( p0_o      ),
    .p1_o       ( p1_o      ),
    .p2_o       ( p2_o      ),
    .p3_o       ( p3_o      ),
    .rom_data   ( rom_data  ),
    .rom_addr   ( pre_rom   ),
    .ram_din    ( ram_q     ),
    .ram_dout   ( ram_data  ),
    .ram_addr   ( ram_addr  ),
    .ram_we     ( ram_we    ),
    .x_din      ( SYNC_XDATA ? xin_sync : x_din ),
    .x_dout     ( pre_dout  ),
    .x_addr     ( pre_addr  ),
    .x_wr       ( pre_wr    ),
    .x_acc      ( pre_acc   )
);

endmodule
