/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

module jtroundu_sub(
    input rst,
    input clk,
    input cen,
    input halt,
    input irq_set,
    output reg [15:0] road_yclip,
    output reg [15:0] road_vregs,
    output [18:1] slave_rom_addr,
    output slave_rom_cs,
    input [15:0] slave_rom_data,
    input slave_rom_ok,
    output [13:1] sharedram_addr,
    output [15:0] sharedram_din,
    input [15:0] sharedram_dout,
    output [1:0] sharedram_we,
    output [13:1] spriteram_addr,
    output [15:0] spriteram_din,
    input [15:0] spriteram_dout,
    output [1:0] spriteram_we,
    output [8:1] obj_ctrl_ram_addr,
    output [15:0] obj_ctrl_ram_din,
    input [15:0] obj_ctrl_ram_dout,
    output [1:0] obj_ctrl_ram_we,
    output [11:1] road_ctrl_ram_addr,
    output [15:0] road_ctrl_ram_din,
    input [15:0] road_ctrl_ram_dout,
    output [1:0] road_ctrl_ram_we,
    output [11:1] road_pixel_ram_addr,
    output [15:0] road_pixel_ram_din,
    input [15:0] road_pixel_ram_dout,
    output [1:0] road_pixel_ram_we,
    output [11:1] road_color_ram_addr,
    output [15:0] road_color_ram_din,
    input [15:0] road_color_ram_dout,
    output [1:0] road_color_ram_we
);

reg [1:0] half_delay=0;
wire [23:1] addr;
wire [15:0] dout;
reg [15:0] din;
wire as_n, uds_n, lds_n, rw;
wire [2:0] fc;
wire bus_cycle = !as_n && !(uds_n && lds_n);
wire iack = fc == 7 && !as_n;
wire [1:0] lane = {~uds_n,~lds_n};
wire [23:0] byte_addr = {addr,1'b0};
wire [7:0] cs;
wire ready = !slave_rom_cs || slave_rom_ok;
reg write_seen, irq;
wire commit = bus_cycle && !rw && !write_seen && ready;

assign cs[0] = bus_cycle && !iack && byte_addr <= 24'h07ffff;
assign cs[1] = bus_cycle && byte_addr >= 24'h080000 && byte_addr <= 24'h083fff;
assign cs[2] = bus_cycle && byte_addr >= 24'h090000 && byte_addr <= 24'h093fff;
assign cs[3] = bus_cycle && byte_addr >= 24'h09a000 && byte_addr <= 24'h09a1ff;
assign cs[4] = bus_cycle && byte_addr >= 24'h0a0000 && byte_addr <= 24'h0a0fff;
assign cs[5] = bus_cycle && byte_addr >= 24'h0b0000 && byte_addr <= 24'h0b0fff;
assign cs[6] = bus_cycle && byte_addr >= 24'h0c0000 && byte_addr <= 24'h0c0fff;
assign cs[7] = bus_cycle && byte_addr == 24'h0e0000;
assign slave_rom_addr = addr[18:1];
assign slave_rom_cs = cs[0] && rw;
assign sharedram_addr = addr[13:1];
assign sharedram_din = dout;
assign sharedram_we = {2{commit && cs[1]}} & lane;
assign spriteram_addr = addr[13:1];
assign spriteram_din = dout;
assign spriteram_we = {2{commit && cs[2]}} & lane;
assign obj_ctrl_ram_addr = addr[8:1];
assign obj_ctrl_ram_din = dout;
assign obj_ctrl_ram_we = {2{commit && cs[3]}} & lane;
assign road_ctrl_ram_addr = addr[11:1];
assign road_ctrl_ram_din = dout;
assign road_ctrl_ram_we = {2{commit && cs[4]}} & lane;
assign road_pixel_ram_addr = addr[11:1];
assign road_pixel_ram_din = dout;
assign road_pixel_ram_we = {2{commit && cs[5]}} & lane;
assign road_color_ram_addr = addr[11:1];
assign road_color_ram_din = dout;
assign road_color_ram_we = {2{commit && cs[6]}} & lane;

always @* begin
    din = 16'hffff;
    if (cs[0]) din = {slave_rom_data[7:0],slave_rom_data[15:8]};
    else if (cs[1]) din = sharedram_dout;
    else if (cs[2]) din = spriteram_dout;
    else if (cs[3]) din = obj_ctrl_ram_dout;
    else if (cs[4]) din = road_ctrl_ram_dout;
    else if (cs[5]) din = road_pixel_ram_dout;
    else if (cs[6]) din = road_color_ram_dout;
    else if (cs[7]) din = road_vregs;
    else if (bus_cycle && byte_addr == 24'h0d0000) din = road_yclip;
end

always @(posedge clk) half_delay <= {half_delay[0],cen};

always @(posedge clk) begin
    if (rst) begin
        irq <= 0;
        write_seen <= 0;
        road_yclip <= 0;
        road_vregs <= 0;
    end else begin
        if (irq_set) irq <= 1;
        if (!bus_cycle) write_seen <= 0;
        else if (commit) begin
            write_seen <= 1;
            if (cs[7]) begin
                irq <= 0;
                if (lane[0]) road_vregs[7:0] <= dout[7:0];
                if (lane[1]) road_vregs[15:8] <= dout[15:8];
            end
            if (byte_addr == 24'h0d0000) begin
                if (lane[0]) road_yclip[7:0] <= dout[7:0];
                if (lane[1]) road_yclip[15:8] <= dout[15:8];
            end
        end
    end
end

jtframe_m68k u_cpu (
    .clk      ( clk                            ),
    .rst      ( rst                            ),
    .cpu_cen  ( cen                            ),
    .cpu_cenb ( half_delay[1]                  ),
    .BERRn    ( 1'b1                           ),
    .VPAn     ( ~iack                          ),
    .BGACKn   ( 1'b1                           ),
    .HALTn    ( ~halt                          ),
    .RESETn   (                                ),
    .eab      ( addr                           ),
    .ASn      ( as_n                           ),
    .LDSn     ( lds_n                          ),
    .UDSn     ( uds_n                          ),
    .eRWn     ( rw                             ),
    .DTACKn   ( ~(bus_cycle && ready && !iack) ),
    .iEdb     ( din                            ),
    .oEdb     ( dout                           ),
    .BRn      ( 1'b1                           ),
    .BGn      (                                ),
    .IPLn     ( irq ? 3'b011 : 3'b111          ),
    .FC       ( fc                             )
);

endmodule
