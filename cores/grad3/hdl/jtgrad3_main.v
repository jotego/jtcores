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

    output        [13:1] ram_addr,
    output        [ 1:0] ram_dsn,
    output reg           ram_cs,
    output               ram_we,
    input         [15:0] ram_dout,
    input                ram_ok,

    output reg           rom_cs,
    input         [15:0] rom_dout,
    input                rom_ok,

    output        [ 1:0] sh_we,
    input         [15:0] sh_dout,

    output reg           tile_cs,
    input         [ 7:0] tile_dout,
    input                tile_dtack,
    input                tile_irqn,
    input                tile_nmin,

    output        [16:1] gchar_addr,
    output        [ 1:0] gchar_dsn,
    output reg           gchar_cs,
    output               gchar_we,
    input         [15:0] gchar_dout,
    input                gchar_ok,

    output reg           pal_cs,
    input         [15:0] pal_dout,
    output reg           rmrd,
    output reg           prio,
    output reg           sub_rst,
    output reg           sub_irq,

    output reg    [ 7:0] snd_latch,
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
wire [23:0] AB = { A, 1'b0 };
wire        UDSn, LDSn, RnW, ASn, VPAn, DTACKn, cpu_cen, cpu_cenb;
wire [ 2:0] FC, IPLn;
wire [ 1:0] dws;
wire [15:0] local_ram_dout;
wire [ 1:0] local_ram_we;
wire        sh_cs, ctrl_cs, io_cs, dsw_cs, snd_latch_cs, snd_irq_cs, wdog_cs;
wire        bus_cs, bus_busy, vdtackn, vbl_irqn;
reg  [15:0] cpu_din;
reg  [ 7:0] cab_dout;
reg         irq_en;
reg  [ 4:0] snd_cnt;

assign main_addr  = A[17:1];
assign ram_addr   = A[13:1];
assign ram_dsn    = { UDSn, LDSn };
assign bus_dsn    = { UDSn, LDSn };
assign gchar_addr = A[16:1];
assign gchar_dsn  = { UDSn, LDSn };
assign dws        = ~({2{RnW}} | { UDSn, LDSn });
assign local_ram_we = dws & {2{ram_cs}};
assign sh_we      = dws & {2{sh_cs}};
assign ram_we     = ~RnW;
assign gchar_we   = ~RnW;
assign cpu_we     = ~RnW;
assign snd_irq    = |snd_cnt;

assign ctrl_cs      = !rst && !ASn && AB == 24'h0c0000;
assign io_cs        = !rst && !ASn && AB[23:3] == 21'h19000; // 0c8000-0c8007
assign dsw_cs       = !rst && !ASn && AB[23:2] == 22'h34000; // 0d0000-0d0003
assign snd_latch_cs = !rst && !ASn && AB == 24'h0e8000;
assign snd_irq_cs   = !rst && !ASn && AB == 24'h0f0000;
assign wdog_cs      = !rst && !ASn && AB == 24'h0e0000;
assign sh_cs        = !rst && !ASn && AB >= 24'h100000 && AB <= 24'h103fff;

assign bus_cs = rom_cs | ram_cs | pal_cs | tile_cs | gchar_cs | sh_cs |
                ctrl_cs | io_cs | dsw_cs | snd_latch_cs | snd_irq_cs | wdog_cs;
assign bus_busy = (rom_cs   & ~rom_ok)   |
                  (ram_cs   & ~ram_ok)   |
                  (gchar_cs & ~gchar_ok) |
                  (tile_cs  & ~tile_dtack);
assign vdtackn = DTACKn | (tile_cs & ~tile_dtack);
assign VPAn    = ~( A[23] & ~ASn );
assign IPLn    = !vbl_irqn ? ~3'd2 : 3'b111;
assign st_dout = { sub_rst, irq_en, rmrd, prio, tile_irqn, tile_nmin, snd_irq, sub_irq };

always @* begin
    rom_cs   = 0;
    ram_cs   = 0;
    pal_cs   = 0;
    tile_cs  = 0;
    gchar_cs = 0;

    if( !rst && !ASn ) begin
        if( AB < 24'h040000 ) begin
            rom_cs = 1;
        end else if( AB >= 24'h040000 && AB <= 24'h043fff ) begin
            ram_cs = 1;
        end else if( AB >= 24'h080000 && AB <= 24'h080fff ) begin
            pal_cs = 1;
        end else if( AB >= 24'h14c000 && AB <= 24'h153fff ) begin
            tile_cs = 1;
        end else if( AB >= 24'h180000 && AB <= 24'h19ffff ) begin
            gchar_cs = 1;
        end
    end
end

always @* begin
    case(1'b1)
        rom_cs:   cpu_din = rom_dout;
        ram_cs:   cpu_din = local_ram_dout;
        pal_cs:   cpu_din = pal_dout;
        tile_cs:  cpu_din = { 8'd0, tile_dout };
        gchar_cs: cpu_din = gchar_dout;
        sh_cs:    cpu_din = sh_dout;
        io_cs,
        dsw_cs:   cpu_din = { 8'd0, cab_dout };
        default:  cpu_din = 16'hffff;
    endcase
end

always @* begin
    cab_dout = 8'hff;
    if( io_cs ) begin
        case( A[2:1] )
            2'd0: cab_dout = { 1'b1, coin[2], 1'b1, cab_1p[1], cab_1p[0], 1'b1, coin[1], coin[0] };
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
        irq_en    <= 0;
        prio      <= 0;
        rmrd      <= 0;
        sub_rst   <= 1;
        sub_irq   <= 0;
        snd_latch <= 0;
        snd_cnt   <= 0;
    end else begin
        sub_irq <= 0;
        if( snd_cnt != 0 ) snd_cnt <= snd_cnt - 1'd1;

        if( ctrl_cs && cpu_we && !UDSn ) begin
            prio    <= cpu_dout[10];
            sub_rst <= ~cpu_dout[11];
            irq_en  <= cpu_dout[13];
        end
        if( snd_latch_cs && cpu_we && !UDSn )
            snd_latch <= cpu_dout[15:8];
        if( snd_irq_cs && cpu_we ) snd_cnt <= 5'h1f;
        if( AB == 24'h0d8000 && cpu_we ) sub_irq <= 1;
    end
end

`ifdef JTGRAD3_TRACE_CTRL
reg        trace_ctrl_lvbl_l, trace_ctrl_sub_rst_l;
reg [15:0] trace_ctrl_frame;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        trace_ctrl_lvbl_l    <= 0;
        trace_ctrl_sub_rst_l <= 1;
        trace_ctrl_frame     <= 0;
    end else begin
        trace_ctrl_lvbl_l    <= LVBL;
        trace_ctrl_sub_rst_l <= sub_rst;
        if( trace_ctrl_lvbl_l & ~LVBL )
            trace_ctrl_frame <= trace_ctrl_frame + 1'd1;
        if( ctrl_cs && cpu_we && bus_dsn != 2'b11 )
            $display("G3CTRL frame=%0d ab=%06x data=%04x dsn=%b uds=%b lds=%b prio=%b sub_rst=%b irq_en=%b pc=%06x",
                trace_ctrl_frame, AB, cpu_dout, bus_dsn, UDSn, LDSn, prio, sub_rst, irq_en,
                u_cpu.u_cpu.PC[23:0]);
        if( sub_rst != trace_ctrl_sub_rst_l )
            $display("G3CTRL frame=%0d sub_rst=%b irq_en=%b prio=%b pc=%06x",
                trace_ctrl_frame, sub_rst, irq_en, prio, u_cpu.u_cpu.PC[23:0]);
    end
end
`endif

jtframe_edge #(.QSET(0)) u_vbl(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( ~LVBL     ),
    .clr    ( ~irq_en | ~VPAn ),
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
        $display("G3M pc=%06x ab=%06x ma=%05x rw=%b fc=%0d din=%04x dout=%04x rom=%b:%04x ok=%b dt=%b cs=%b%b%b%b%b%b%b%b",
            u_cpu.u_cpu.PC[23:0], AB, main_addr, RnW, FC, cpu_din, cpu_dout,
            rom_cs, rom_dout, rom_ok, vdtackn,
            rom_cs, ram_cs, sh_cs, tile_cs, gchar_cs, pal_cs, io_cs, dsw_cs);
    end
end
`endif

`else
assign main_addr=0, cpu_dout=0, cpu_we=0, bus_dsn=3, ram_addr=0, ram_dsn=3,
       ram_we=0, sh_we=0, gchar_addr=0, gchar_dsn=3, gchar_we=0,
       snd_irq=0, st_dout=0;
initial begin
    ram_cs=0; rom_cs=0; tile_cs=0; gchar_cs=0; pal_cs=0;
    rmrd=0; prio=0; sub_rst=1; sub_irq=0; snd_latch=0;
end
`endif

endmodule
