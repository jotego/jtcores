/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */

module jtapach3_sub(
    input             rst,
    input             clk,
    input             halt,
    input             vblank,
    output            reset_n,
    output reg        z80_halt,
    output reg [15:0] rotate_data,
    output reg        rotate_we,
    output reg [ 7:0] road_z,
    output     [18:1] slave_rom_addr,
    output            slave_rom_cs,
    input      [15:0] slave_rom_data,
    input             slave_rom_ok,
    output     [13:1] sharedram_addr,
    output     [15:0] sharedram_din,
    input      [15:0] sharedram_dout,
    output     [ 1:0] sharedram_we,
    output     [13:1] spriteram_addr,
    output     [15:0] spriteram_din,
    input      [15:0] spriteram_dout,
    output     [ 1:0] spriteram_we,
    output     [ 8:1] obj_ctrl_ram_addr,
    output     [15:0] obj_ctrl_ram_din,
    input      [15:0] obj_ctrl_ram_dout,
    output     [ 1:0] obj_ctrl_ram_we,
    output     [15:1] ground_ram_addr,
    output            ground_ram_cs,
    output            ground_ram_we,
    output     [15:0] ground_ram_din,
    output     [ 1:0] ground_ram_dsn,
    input      [15:0] ground_ram_data,
    input             ground_ram_ok,
    output     [12:0] m68k_z80ram_addr,
    output     [ 7:0] m68k_z80ram_din,
    input      [ 7:0] m68k_z80ram_dout,
    output            m68k_z80ram_we
);

wire [23:1] addr;
wire [23:0] byte_addr = {addr,1'b0};
wire [15:0] dout;
reg  [15:0] din;
wire as_n, uds_n, lds_n, rw, dtack_n, cpu_cen, cpu_cenb;
wire [2:0] fc;
wire bus_cycle = !as_n && !(uds_n && lds_n);
wire iack = !as_n && fc == 3'b111;
wire [1:0] lane = {~uds_n,~lds_n};
wire rom_cs    = bus_cycle && !iack && byte_addr <= 24'h07ffff;
wire shared_cs = bus_cycle && !iack && byte_addr >= 24'h080000 && byte_addr <= 24'h083fff;
wire sprite_cs = bus_cycle && !iack && byte_addr >= 24'h090000 && byte_addr <= 24'h093fff;
wire obj_cs    = bus_cycle && !iack && byte_addr >= 24'h09a000 && byte_addr <= 24'h09a1ff;
wire rotate_cs = bus_cycle && !iack && byte_addr == 24'h0a0000;
wire zctrl_cs  = bus_cycle && !iack && byte_addr == 24'h0b0000;
wire road_z_cs = bus_cycle && !iack && byte_addr == 24'h0c0000;
wire ground_cs = bus_cycle && !iack && byte_addr >= 24'h0d0000 && byte_addr <= 24'h0dffff;
wire zram_cs   = bus_cycle && !iack && byte_addr >= 24'h0e0000 && byte_addr <= 24'h0e7fff;
wire bus_busy = (slave_rom_cs && !slave_rom_ok) || (ground_ram_cs && !ground_ram_ok);
`ifdef SIMULATION
reg [7:0] road_init [0:33];
integer road_file, road_count;
initial begin
    for (integer k=0;k<34;k=k+1) road_init[k]=0;
    road_file=$fopen("rest.bin","rb");
    if (road_file != 0) begin
        road_count=$fread(road_init,road_file);
        $fclose(road_file);
        if (road_count != 34) $fatal(1,"Incomplete road restore data");
    end
end
`endif
reg write_seen, irq, old_vblank;
wire commit = !rst && bus_cycle && !rw && !write_seen && !bus_busy;

assign slave_rom_addr    = addr[18:1];
assign slave_rom_cs      = rom_cs && rw;
assign sharedram_addr    = addr[13:1];
assign sharedram_din     = dout;
assign sharedram_we      = {2{commit && shared_cs}} & lane;
assign spriteram_addr    = addr[13:1];
assign spriteram_din     = dout;
assign spriteram_we      = {2{commit && sprite_cs}} & lane;
assign obj_ctrl_ram_addr = addr[8:1];
assign obj_ctrl_ram_din  = dout;
assign obj_ctrl_ram_we   = {2{commit && obj_cs}} & lane;
assign ground_ram_addr   = addr[15:1];
assign ground_ram_cs     = !rst && ground_cs;
assign ground_ram_we     = !rst && ground_cs && !rw;
assign ground_ram_din    = dout;
assign ground_ram_dsn    = rst ? 2'b00 : ~lane;
assign m68k_z80ram_addr  = addr[13:1];
assign m68k_z80ram_din   = dout[7:0];
assign m68k_z80ram_we    = commit && zram_cs;

always @* begin
    din = 16'hffff;
    if (rom_cs)         din = {slave_rom_data[7:0],slave_rom_data[15:8]};
    else if (shared_cs) din = sharedram_dout;
    else if (sprite_cs) din = spriteram_dout;
    else if (obj_cs)    din = obj_ctrl_ram_dout;
    else if (ground_cs) din = ground_ram_data;
    else if (zram_cs)   din = {8'h00,m68k_z80ram_dout};
end

always @(posedge clk) begin
    if (rst) begin
        write_seen <= 0;
        irq <= 0;
        old_vblank <= 0;
        z80_halt <= 0;
        rotate_data <= 0;
        rotate_we <= 0;
`ifdef SIMULATION
        road_z <= road_init[32];
`else
        road_z <= 0;
`endif
    end else begin
        old_vblank <= vblank;
        rotate_we <= 0;
        if (vblank && !old_vblank) irq <= 1;
        if (iack && cpu_cen) irq <= 0;
        if (!bus_cycle) write_seen <= 0;
        else if (commit) begin
            write_seen <= 1;
            if (rotate_cs) begin
                rotate_data <= dout;
                rotate_we <= 1;
            end
            if (zctrl_cs) z80_halt <= dout[1];
            if (road_z_cs) road_z <= dout[7:0];
        end
    end
end

jtframe_68kdtack_cen #(
    .W        ( 15 ),
    .RECOVERY ( 1  )
) u_dtack (
    .rst       ( rst                          ),
    .clk       ( clk                          ),
    .cpu_cen   ( cpu_cen                      ),
    .cpu_cenb  ( cpu_cenb                     ),
    .bus_cs    ( slave_rom_cs | ground_ram_cs ),
    .bus_busy  ( bus_busy                     ),
    .bus_legit ( 1'b0                         ),
    .bus_ack   ( 1'b0                         ),
    .ASn       ( as_n                         ),
    .DSn       ( {uds_n,lds_n}                ),
    .num       ( 14'd7818                     ),
    .den       ( 15'd31471                    ),
    .wait2     ( 1'b0                         ),
    .wait3     ( 1'b0                         ),
    .DTACKn    ( dtack_n                      ),
    .fave      (                              ),
    .fworst    (                              )
);

jtframe_m68k u_cpu (
    .clk      ( clk                   ),
    .rst      ( rst                   ),
    .cpu_cen  ( cpu_cen               ),
    .cpu_cenb ( cpu_cenb              ),
    .BERRn    ( 1'b1                  ),
    .VPAn     ( ~iack                 ),
    .BGACKn   ( 1'b1                  ),
    .HALTn    ( ~halt                 ),
    .RESETn   ( reset_n               ),
    .eab      ( addr                  ),
    .ASn      ( as_n                  ),
    .LDSn     ( lds_n                 ),
    .UDSn     ( uds_n                 ),
    .eRWn     ( rw                    ),
    .DTACKn   ( dtack_n               ),
    .iEdb     ( din                   ),
    .oEdb     ( dout                  ),
    .BRn      ( 1'b1                  ),
    .BGn      (                       ),
    .IPLn     ( irq ? 3'b011 : 3'b111 ),
    .FC       ( fc                    )
);

endmodule
