/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jtgrad3_sub(
    input                rst,
    input                sub_rst,
    input                clk,
    input                LVBL,
    input                irq2,

    output        [19:1] cpu_addr,
    output        [15:0] cpu_dout,
    output               cpu_we,
    output        [ 1:0] bus_dsn,

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
wire        UDSn, LDSn, RnW, ASn, VPAn, DTACKn, cpu_cen, cpu_cenb;
wire [ 2:0] FC, IPLn;
wire [ 1:0] dws;
wire [13:1] ram_addr;
wire [15:0] local_ram_dout;
wire [ 1:0] local_ram_we;
wire        prog_dec_cs, vid_dec_cs, sh_cs, bus_cs, bus_busy, vdtackn;
wire        irq1n, irq2n, irq4n, rst_cpu, lvbln;
wire        irq1_clr, irq2_clr, irq4_clr;
reg  [15:0] cpu_din;
reg         irqmask_cs, ram_cs;
reg  [ 2:0] irq_mask;

assign rst_cpu   = rst | sub_rst;
assign lvbln     = ~LVBL;
assign irq1_clr  = ~irq_mask[0] | ~VPAn;
assign irq2_clr  = ~irq_mask[1] | ~VPAn;
assign irq4_clr  = ~irq_mask[2] | ~VPAn;
assign cpu_addr  = A[19:1];
assign rom_addr  = A[19:1];
assign ram_addr  = A[13:1];
assign bus_dsn   = { UDSn, LDSn };
assign gchar_addr= A[16:1];
assign gchar_dsn = { UDSn, LDSn };
assign gfx_addr  = A[20:1];
assign dws       = ~({2{RnW}} | { UDSn, LDSn });
assign local_ram_we = dws & {2{ram_cs}};
assign sh_we     = dws & {2{sh_cs}};
assign gchar_we  = ~RnW;
assign cpu_we    = ~RnW;

assign prog_dec_cs = !ASn && !A[22] && !A[21];
assign vid_dec_cs  = !ASn && !A[22] &&  A[21];
assign sh_cs       = vid_dec_cs && A[19:18] == 2'd0;
assign bus_cs      = rom_cs | ram_cs | tile_cs | obj_cs | gchar_cs | gfx_cs | sh_cs | irqmask_cs;
assign bus_busy    = (rom_cs   & ~rom_ok)   |
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
    irqmask_cs = 0;

    if( prog_dec_cs ) begin
        case( A[20:18] )
            3'd0, 3'd1, 3'd2, 3'd3: rom_cs = 1;
            3'd4: ram_cs     = 1;
            3'd5: irqmask_cs = 1;
            default:;
        endcase
    end
    if( vid_dec_cs ) begin
        case( A[19:18] )
            2'd1: tile_cs  = 1;
            2'd2: gchar_cs = 1;
            2'd3: obj_cs   = 1;
            default:;
        endcase
    end
    if( !ASn && !A[23] && A[22] && !A[21] ) begin
        gfx_cs = 1;
    end
end

always @(posedge clk) begin
    cpu_din <= rom_cs   ? rom_dout            :
               ram_cs   ? local_ram_dout      :
               sh_cs    ? sh_dout             :
               tile_cs  ? { 8'd0, tile_dout } :
               obj_cs   ? { 8'd0, obj_dout  } :
               gchar_cs ? gchar_dout          :
               gfx_cs   ? gfx_data            :
               16'hffff;
end

always @(posedge clk, posedge rst_cpu) begin
    if( rst_cpu ) begin
        irq_mask <= 0;
    end else begin
        if( irqmask_cs && cpu_we && !UDSn )
            irq_mask <= cpu_dout[10:8];
    end
end

jtframe_edge #(.QSET(0)) u_irq1(
    .rst    ( rst_cpu   ),
    .clk    ( clk       ),
    .edgeof ( lvbln     ),
    .clr    ( irq1_clr  ),
    .q      ( irq1n     )
);

jtframe_edge #(.QSET(0)) u_irq2(
    .rst    ( rst_cpu   ),
    .clk    ( clk       ),
    .edgeof ( irq2      ),
    .clr    ( irq2_clr  ),
    .q      ( irq2n     )
);

jtframe_edge #(.QSET(0)) u_irq4(
    .rst    ( rst_cpu   ),
    .clk    ( clk       ),
    .edgeof ( irq_trig  ),
    .clr    ( irq4_clr  ),
    .q      ( irq4n     )
);

jtframe_68kdtack_cen #(.W(6), .RECOVERY(1)) u_dtack(
    .rst        ( rst_cpu   ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ( bus_dsn   ),
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
    .rst        ( rst_cpu   ),
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

`else
assign cpu_addr=0, cpu_dout=0, cpu_we=0, bus_dsn=3,
       rom_addr=0, sh_we=0, gchar_addr=0, gchar_dsn=3,
       gchar_we=0, gfx_addr=0, st_dout=0;
initial begin
    ram_cs=0; rom_cs=0; tile_cs=0; obj_cs=0; gchar_cs=0; gfx_cs=0;
end
`endif

endmodule
