/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jtgrad3_sub(
    input                rst,
    input                clk,
    input                LVBL,
    input                irq2,

    output        [19:1] cpu_addr,
    output        [15:0] cpu_dout,
    output               cpu_we,
    output        [ 1:0] bus_dsn,

    output        [13:1] ram_addr,
    output        [ 1:0] ram_dsn,
    output reg           ram_cs,
    output               ram_we,
    input         [15:0] ram_dout,
    input                ram_ok,

    output reg           rom_cs,
    output        [19:1] rom_addr,
    input         [15:0] rom_dout,
    input                rom_ok,

    output        [ 1:0] sh_we,
    input         [15:0] sh_dout,

    output reg           tile_cs,
    input         [ 7:0] tile_dout,
    input                tile_dtack,

    output reg           obj_cs,
    input         [ 7:0] obj_dout,

    output        [16:1] gchar_addr,
    output        [ 1:0] gchar_dsn,
    output reg           gchar_cs,
    output               gchar_we,
    input         [15:0] gchar_dout,
    input                gchar_ok,

    output        [20:1] gfx_addr,
    output reg           gfx_cs,
    input         [15:0] gfx_data,
    input                gfx_ok,

    input                irq_trig,
    input                dip_pause,
    output        [ 7:0] st_dout
);

`ifndef NOMAIN
wire [23:1] A;
wire [23:0] AB = { A, 1'b0 };
wire        UDSn, LDSn, RnW, ASn, VPAn, DTACKn, cpu_cen, cpu_cenb;
wire [ 2:0] FC, IPLn;
wire [ 1:0] dws;
wire [15:0] local_ram_dout;
wire [ 1:0] local_ram_we;
wire        sh_cs, irqmask_cs, bus_cs, bus_busy, vdtackn;
wire        irq1n, irq2n, irq4n;
reg  [15:0] cpu_din;
reg  [ 2:0] irq_mask;

assign cpu_addr  = A[19:1];
assign rom_addr  = A[19:1];
assign ram_addr  = A[13:1];
assign ram_dsn   = { UDSn, LDSn };
assign bus_dsn   = { UDSn, LDSn };
assign gchar_addr= A[16:1];
assign gchar_dsn = { UDSn, LDSn };
assign gfx_addr  = A[20:1];
assign dws       = ~({2{RnW}} | { UDSn, LDSn });
assign local_ram_we = dws & {2{ram_cs}};
assign sh_we     = dws & {2{sh_cs}};
assign ram_we    = ~RnW;
assign gchar_we  = ~RnW;
assign cpu_we    = ~RnW;

assign irqmask_cs = !rst && !ASn && AB == 24'h140000;
assign sh_cs      = !rst && !ASn && AB >= 24'h200000 && AB <= 24'h203fff;
assign bus_cs     = rom_cs | ram_cs | tile_cs | obj_cs | gchar_cs | gfx_cs | sh_cs | irqmask_cs;
assign bus_busy   = (rom_cs   & ~rom_ok)   |
                    (ram_cs   & ~ram_ok)   |
                    (gchar_cs & ~gchar_ok) |
                    (gfx_cs   & ~gfx_ok)   |
                    (tile_cs  & ~tile_dtack);
assign vdtackn = DTACKn | (tile_cs & ~tile_dtack);
assign VPAn    = ~( A[23] & ~ASn );
assign IPLn    = !irq4n ? ~3'd4 : !irq2n ? ~3'd2 : !irq1n ? ~3'd1 : 3'b111;
assign st_dout = { irq_mask, irq1n, irq2n, irq4n, tile_cs, obj_cs };

always @* begin
    rom_cs   = 0;
    ram_cs   = 0;
    tile_cs  = 0;
    obj_cs   = 0;
    gchar_cs = 0;
    gfx_cs   = 0;

    if( !rst && !ASn ) begin
        if( AB < 24'h100000 ) begin
            rom_cs = 1;
        end else if( AB >= 24'h100000 && AB <= 24'h103fff ) begin
            ram_cs = 1;
        end else if( AB >= 24'h24c000 && AB <= 24'h253fff ) begin
            tile_cs = 1;
        end else if( AB >= 24'h280000 && AB <= 24'h29ffff ) begin
            gchar_cs = 1;
        end else if( AB >= 24'h2c0000 && AB <= 24'h2c0fff ) begin
            obj_cs = 1;
        end else if( AB >= 24'h400000 && AB <= 24'h5fffff ) begin
            gfx_cs = 1;
        end
    end
end

always @* begin
    case(1'b1)
        rom_cs:   cpu_din = rom_dout;
        ram_cs:   cpu_din = local_ram_dout;
        sh_cs:    cpu_din = sh_dout;
        tile_cs:  cpu_din = { 8'd0, tile_dout };
        obj_cs:   cpu_din = { 8'd0, obj_dout };
        gchar_cs: cpu_din = gchar_dout;
        gfx_cs:   cpu_din = gfx_data;
        default:  cpu_din = 16'hffff;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        irq_mask <= 0;
    end else begin
        if( irqmask_cs && cpu_we && !UDSn )
            irq_mask <= cpu_dout[10:8];
    end
end

jtframe_edge #(.QSET(0)) u_irq1(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( ~LVBL     ),
    .clr    ( ~irq_mask[0] | ~VPAn ),
    .q      ( irq1n     )
);

jtframe_edge #(.QSET(0)) u_irq2(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( irq2      ),
    .clr    ( ~irq_mask[1] | ~VPAn ),
    .q      ( irq2n     )
);

jtframe_edge #(.QSET(0)) u_irq4(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( irq_trig  ),
    .clr    ( ~irq_mask[2] | ~VPAn ),
    .q      ( irq4n     )
);

jtframe_68kdtack_cen #(.W(6), .RECOVERY(1)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 5'd5      ),
    .den        ( 6'd24     ),
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       (           ),
    .fworst     (           )
);

jtframe_ram16 #(.AW(13)) u_ram(
    .clk    ( clk            ),
    .data   ( cpu_dout       ),
    .addr   ( ram_addr       ),
    .we     ( local_ram_we   ),
    .q      ( local_ram_dout )
);

jtframe_m68k u_cpu(
    .clk        ( clk       ),
    .rst        ( rst       ),
    .RESETn     (           ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .eab        ( A         ),
    .iEdb       ( cpu_din   ),
    .oEdb       ( cpu_dout  ),
    .eRWn       ( RnW       ),
    .LDSn       ( LDSn      ),
    .UDSn       ( UDSn      ),
    .ASn        ( ASn       ),
    .VPAn       ( VPAn      ),
    .FC         ( FC        ),
    .BERRn      ( 1'b1      ),
    .HALTn      ( dip_pause ),
    .BRn        ( 1'b1      ),
    .BGACKn     ( 1'b1      ),
    .BGn        (           ),
    .DTACKn     ( vdtackn   ),
    .IPLn       ( IPLn      )
);

`ifdef JTGRAD3_TRACE_CPU
always @(posedge clk) begin
    if( !rst && !ASn && !vdtackn && cpu_cen ) begin
        $display("G3S pc=%06x ab=%06x rw=%b fc=%0d din=%04x dout=%04x cs=%b%b%b%b%b%b%b",
            u_cpu.u_cpu.PC[23:0], AB, RnW, FC, cpu_din, cpu_dout,
            rom_cs, ram_cs, sh_cs, tile_cs, obj_cs, gchar_cs, gfx_cs);
    end
end
`endif

`else
assign cpu_addr=0, cpu_dout=0, cpu_we=0, bus_dsn=3, ram_addr=0, ram_dsn=3,
       ram_we=0, rom_addr=0, sh_we=0, gchar_addr=0, gchar_dsn=3,
       gchar_we=0, gfx_addr=0, st_dout=0;
initial begin
    ram_cs=0; rom_cs=0; tile_cs=0; obj_cs=0; gchar_cs=0; gfx_cs=0;
end
`endif

endmodule
