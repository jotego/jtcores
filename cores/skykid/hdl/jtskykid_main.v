/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-9-2026 */

module jtskykid_main(
    input               rst, clk,
                        cen_E, cen_Q, lvbl,

    output reg          flip,
    output              srst,
    output reg   [ 7:0] pri,

    output       [ 7:0] cpu_dout,
    output      [15:0]  cpu_addr,
    output       [ 1:0] vram0_we, vram1_we, oram_we,
    output              rnw,

    output       [15:0] rom_addr,
    input        [ 7:0] rom_data,
    output              rom_cs, bus_busy,
    input               rom_ok,

    output reg   [ 8:0] scrx,
    output reg   [ 7:0] scry,
    input        [15:0] vram0_dout, vram1_dout, oram_dout,

    // CUS30
    output              c30_cs,
    input        [ 7:0] c30_dout,

    // IOCTL dump
    input        [ 1:0] ioctl_addr,
    output       [ 7:0] ioctl_din,

    input        [ 7:0] debug_bus,
    output       [ 7:0] st_dout
);
`ifndef NOMAIN
wire [ 7:0] cpu_din;
reg         bank;
wire        int_n, avma, rst_n,
            vram0_cs, vram1_cs, oram_cs, banked_cs,
            scrx_cs, scry_cs, bank_cs, pri_cs, wdog_cs;

assign st_dout  = {flip,bank,pri[5:0]};
assign rom_addr = banked_cs ? {2'b10, bank, cpu_addr[12:0]} : {1'b0, cpu_addr[14:0]};
assign bus_busy = rom_cs & ~rom_ok;
assign vram0_we = {2{vram0_cs & ~rnw}} & {cpu_addr[0],~cpu_addr[0]};
assign vram1_we = {2{vram1_cs & ~rnw}} & {cpu_addr[0],~cpu_addr[0]};
assign oram_we  = {2{oram_cs  & ~rnw}} & {cpu_addr[0],~cpu_addr[0]};

assign cpu_din  = rom_cs   ? rom_data  :
                  vram0_cs ? (cpu_addr[0] ? vram0_dout[15:8] : vram0_dout[7:0]) :
                  vram1_cs ? (cpu_addr[0] ? vram1_dout[15:8] : vram1_dout[7:0]) :
                  oram_cs  ? (cpu_addr[0] ?  oram_dout[15:8] :  oram_dout[7:0]) :
                  c30_cs   ? c30_dout  : 8'd0;

always @(posedge clk) begin
    if( rst ) begin
        scrx   <= 0;
        scry   <= 0;
        pri    <= 0;
        flip   <= 0;
        bank   <= 0;
    end else begin
        if( scrx_cs ) scrx   <= cpu_addr[8:0];
        if( scry_cs ) scry   <= cpu_addr[7:0];
        if( bank_cs ) bank   <= ~cpu_addr[11];
        if( pri_cs  ) begin
            pri    <= cpu_dout;
            flip   <= cpu_addr[0];
        end
    end
end

jtframe_watchdog #(.INVERT(1)) u_wdog( rst, clk, lvbl, wdog_cs, rst_n );

jtskykid_dec u_dec(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .lvbl       ( lvbl      ),
    .srst       ( srst      ),

    .addr       ( cpu_addr  ),
    .rnw        ( rnw       ),

    .vram0_cs   ( vram0_cs  ),
    .vram1_cs   ( vram1_cs  ),
    .oram_cs    ( oram_cs   ),
    .c30_cs     ( c30_cs    ),
    .rom_cs     ( rom_cs    ),
    .banked_cs  ( banked_cs ),
    .wdog_cs    ( wdog_cs   ),
    .scrx_cs    ( scrx_cs   ),
    .scry_cs    ( scry_cs   ),
    .bank_cs    ( bank_cs   ),
    .pri_cs     ( pri_cs    ),
    .int_n      ( int_n     )
);

mc6809i u_cpu(
    .nRESET     ( rst_n     ),
    .clk        ( clk       ),
    .cen_E      ( cen_E     ),
    .cen_Q      ( cen_Q     ),
    .D          ( cpu_din   ),
    .DOut       ( cpu_dout  ),
    .ADDR       ( cpu_addr  ),
    .RnW        ( rnw       ),
    // Interrupts
    .nIRQ       ( int_n     ),
    .nFIRQ      ( 1'b1      ),
    .nNMI       ( 1'b1      ),
    .nHALT      ( 1'b1      ),
    // unused
    .AVMA       ( avma      ),
    .BS         (           ),
    .BA         (           ),
    .BUSY       (           ),
    .LIC        (           ),
    .nDMABREQ   ( 1'b1      ),
    .OP         (           ),
    .RegData    (           )
);
`else
initial pri=0, scrx=0, scry=0, flip=0;
assign srst=0, cpu_dout=0, cpu_addr=0, rnw=1,
       vram0_we=0, vram1_we=0, oram_we=0,
       rom_addr=0, rom_cs=0, bus_busy=0, c30_cs=0, st_dout=0;
`endif

jtframe_simdumper #(.DW(18)) dumper(
    .clk        ( clk           ),
    .data       ( {flip,scry,scrx} ),
    .ioctl_addr ( ioctl_addr    ),
    .ioctl_din  ( ioctl_din     )
);

endmodule
