/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jtgrad3_main(
    input                rst,
    input                clk,
    input                LVBL,

    output        [17:1] main_addr,
    output        [15:0] cpu_dout,
    output               cpu_we,
    output        [ 1:0] bus_dsn,

    output reg           rom_cs,
    input         [15:0] rom_dout,
    input                rom_ok,

    output        [ 1:0] sh_we,
    input         [15:0] sh_dout,

    output reg           tile_cs,
    input         [ 7:0] tile_dout,
    input                tile_dtack,

    output        [16:1] gchar_addr,
    output        [ 1:0] gchar_dsn,
    output reg           gchar_cs,
    output               gchar_we,
    input         [15:0] gchar_dout,
    input                gchar_ok,

    output reg           pal_cs,
    input         [15:0] pal_dout,
    output               rmrd,
    output               prio,
    output               sub_rst,
    output reg           sub_irq,

    output        [ 7:0] snd_latch,
    output               snd_irq,

    input         [ 2:0] cab_1p,
    input         [ 2:0] coin,
    input         [ 6:0] joystick1,
    input         [ 6:0] joystick2,
    input                service,
    input                dip_pause,
    input         [19:0] dipsw,

    output        [ 7:0] st_dout,
    input         [ 7:0] debug_bus
);

`ifndef NOMAIN
wire [23:1] A;
wire        UDSn, LDSn, RnW, ASn, VPAn, DTACKn, cpu_cen, cpu_cenb;
wire [ 2:0] FC, IPLn;
wire [ 1:0] dws;
wire [13:1] ram_addr;
wire [15:0] local_ram_dout;
wire [ 1:0] local_ram_we;
wire        cab_cs;
reg         snd_latch_cs, snd_irq_cs, wdog_cs, sub_irq_cs,
            ctrl_cs, io_cs, dsw_cs, dec_cs;
wire        bus_cs, bus_busy, vdtackn, vbl_irqn, lvbln, vbl_clr, irq_en;
wire [ 7:0] ctrl;
reg  [15:0] cpu_din;
reg  [ 7:0] cab_dout;
reg  [ 4:0] snd_cnt;
reg         sh_cs, ram_cs, io_dec_cs;
`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign rmrd       = 1'b0;
assign prio       = ctrl[2];
assign sub_rst    = ~ctrl[3];
assign irq_en     = ctrl[5];
assign lvbln      = ~LVBL;
assign vbl_clr    = ~irq_en | ~VPAn;
assign main_addr  = A[17:1];
assign ram_addr   = A[13:1];
assign bus_dsn    = { UDSn, LDSn };
assign gchar_addr = A[16:1];
assign gchar_dsn  = { UDSn, LDSn };
assign dws        = ~({2{RnW}} | { UDSn, LDSn });
assign local_ram_we = dws & {2{ram_cs}};
assign sh_we      = dws & {2{sh_cs}};
assign gchar_we   = ~RnW;
assign cpu_we     = ~RnW;
assign snd_irq    = |snd_cnt;

assign cab_cs   = io_cs  | dsw_cs;
assign bus_cs   = rom_cs | ram_cs | pal_cs | tile_cs | gchar_cs | sh_cs |
                  ctrl_cs | io_cs | dsw_cs | snd_latch_cs | snd_irq_cs | wdog_cs;
assign bus_busy = (rom_cs   & ~rom_ok)   |
                  (gchar_cs & ~gchar_ok) |
                  (tile_cs  & ~tile_dtack);
assign vdtackn  = DTACKn | (tile_cs & ~tile_dtack);
assign VPAn     = ~( A[23] & ~ASn );
assign IPLn     = !vbl_irqn ? ~3'd2 : 3'b111;
assign st_dout  = { sub_rst, irq_en, rmrd, prio, 2'b0, snd_irq, sub_irq };

always @* begin
    rom_cs       = 0;
    ram_cs       = 0;
    pal_cs       = 0;
    io_dec_cs    = 0;
    sh_cs        = 0;
    tile_cs      = 0;
    gchar_cs     = 0;
    ctrl_cs      = 0;
    io_cs        = 0;
    dsw_cs       = 0;
    sub_irq_cs   = 0;
    wdog_cs      = 0;
    snd_latch_cs = 0;
    snd_irq_cs   = 0;
    dec_cs       = 0;

    if( !ASn && !A[23] )
        dec_cs = 1;

    if( dec_cs ) begin
        case( A[20:18] )
            3'd0: rom_cs    = 1;
            3'd1: ram_cs    = 1;
            3'd2: pal_cs    = 1;
            3'd3: io_dec_cs = 1;
            3'd4: sh_cs     = 1;
            3'd5: tile_cs   = 1;
            3'd6: gchar_cs  = 1;
            default:;
        endcase
    end

    if( io_dec_cs ) begin
        case( A[17:15] )
            3'd0: ctrl_cs      = 1;
            3'd1: io_cs        = 1;
            3'd2: dsw_cs       = 1;
            3'd3: sub_irq_cs   = 1;
            3'd4: wdog_cs      = 1;
            3'd5: snd_latch_cs = 1;
            3'd6: snd_irq_cs   = 1;
            default:;
        endcase
    end
end

always @(posedge clk) begin
    cpu_din <= rom_cs   ? rom_dout            :
               ram_cs   ? local_ram_dout      :
               pal_cs   ? pal_dout            :
               tile_cs  ? { 8'd0, tile_dout } :
               gchar_cs ? gchar_dout          :
               sh_cs    ? sh_dout             :
               cab_cs   ? { 8'd0, cab_dout }  :
               16'hffff;
end

always @* begin
    cab_dout = 8'hff;
    if( io_cs ) begin
        case( A[2:1] )
            2'd0: cab_dout = { 1'b1, coin[2], 1'b1, cab_1p[1:0], 1'b1, coin[1:0] };
            2'd1: cab_dout = { 1'b1, joystick1 };
            2'd2: cab_dout = { 1'b1, joystick2 };
            2'd3: cab_dout = { 4'hf, dipsw[19:16] };
        endcase
    end else if( dsw_cs ) begin
        cab_dout = A[1] ? dipsw[15:8] : dipsw[7:0];
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        sub_irq   <= 0;
        snd_cnt   <= 0;
    end else begin
        sub_irq <= 0;
        if( snd_cnt != 0 ) snd_cnt <= snd_cnt - 1'd1;

        if( snd_irq_cs && cpu_we ) snd_cnt <= 5'h1f;
        if( sub_irq_cs && cpu_we ) sub_irq <= 1;
    end
end

jtframe_8bit_reg u_ctrl(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .wr_n       ( RnW | UDSn     ),
    .din        ( cpu_dout[15:8] ),
    .cs         ( ctrl_cs        ),
    .dout       ( ctrl           )
);

jtframe_8bit_reg u_snd_latch(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .wr_n       ( RnW | UDSn     ),
    .din        ( cpu_dout[15:8] ),
    .cs         ( snd_latch_cs   ),
    .dout       ( snd_latch      )
);

jtframe_edge #(.QSET(0)) u_vbl(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( lvbln     ),
    .clr    ( vbl_clr   ),
    .q      ( vbl_irqn  )
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

`else
assign main_addr=0, cpu_dout=0, cpu_we=0, bus_dsn=3,
       sh_we=0, gchar_addr=0, gchar_dsn=3, gchar_we=0,
       rmrd=0, prio=0, sub_rst=1, snd_latch=0, snd_irq=0, st_dout=0;
initial begin
    ram_cs=0; rom_cs=0; tile_cs=0; gchar_cs=0; pal_cs=0;
    sub_irq=0;
end
`endif

endmodule
