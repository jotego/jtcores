/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

module jtgrad3_sub(
    input                rst,
    input                sub_rst,
    input                clk,
    input                LVBL,
    input                cpu_trig,
    input         [ 4:0] cen_num,

    output        [19:1] cpu_addr,
    output        [15:0] cpu_dout,
    output               cpu_we,
    output        [ 1:0] bus_dsn,

    output reg           rom_cs,
    output        [19:1] rom_addr,
    input         [15:0] rom_dout,
    input                rom_ok,

    input         [15:0] ram_dout,
    output        [ 1:0] ram_we,

    output        [ 1:0] sh_we,
    input         [15:0] sh_dout,

    output reg           tile_cs,
    input         [ 7:0] tile_dout,
    input                tile_dtack,
    output               video_req_n,
    input                video_grant_n,

    output reg           obj_cs,
    input         [ 7:0] obj_dout,

    output reg           gchar_cs,
    output               gchar_we,
    input         [15:0] gchar_dout,
    input                gchar_ok,

    output        [20:1] gfx_addr,
    output reg           gfx_cs,
    input         [15:0] gfx_data,
    input                gfx_ok,

    output               irq_trig,
    input                dip_pause,
    output        [ 7:0] st_dout
);

`ifndef NOMAIN
wire [23:1] A;
wire        UDSn, LDSn, RnW, ASn, VPAn, DTACKn, cpu_cen, cpu_cenb;
wire [ 2:0] FC, IPLn;
wire [ 1:0] dws;
wire        bus_cs, bus_busy, vdtackn;
wire        rst_cpu, BUSn;
reg  [15:0] cpu_din;
wire        ok_dly;
reg         irq_mask_cs, ram_cs, prog_dec_cs, vid_dec_cs, sh_cs;
reg         gchar_sel;
wire        video_req;

assign rst_cpu   = rst | sub_rst;
assign cpu_addr  = A[19:1];
assign rom_addr  = A[19:1];
assign bus_dsn   = { UDSn, LDSn };
assign gfx_addr  = A[20:1];
assign dws       = ~({2{RnW}} | { UDSn, LDSn });
assign ram_we    = dws & {2{ram_cs}};
assign sh_we     = dws & {2{sh_cs}};
assign gchar_we  = ~RnW;
assign cpu_we    = ~RnW;
assign irq_trig  = A[22:18]=={2'd0,3'd6};

assign bus_cs    = rom_cs | ram_cs | tile_cs | obj_cs | gchar_sel | gfx_cs | sh_cs | irq_mask_cs;
wire [2:0] ok_cs, ok_in;
assign ok_cs = { rom_cs, gchar_cs, gfx_cs };
assign ok_in = { rom_ok, gchar_ok, gfx_ok };
assign video_req = (tile_cs | gchar_sel) & ~BUSn;
assign video_req_n = ~video_req;
assign bus_busy  = (rom_cs   & ~ok_dly)   |
                   (gchar_cs & ~ok_dly)   |
                   (gfx_cs   & ~ok_dly)   |
                   (video_req & video_grant_n) |
                   (tile_cs  & ~tile_dtack);
assign vdtackn   = DTACKn | (tile_cs & ~tile_dtack);
assign VPAn      = ~( A[23] & ~ASn );
assign BUSn      = &bus_dsn;
assign st_dout   = { 6'd0, tile_cs, obj_cs };

always @* begin
    rom_cs      = 0;
    ram_cs      = 0;
    tile_cs     = 0;
    obj_cs      = 0;
    gchar_cs    = 0;
    gchar_sel   = 0;
    gfx_cs      = 0;
    sh_cs       = 0;
    irq_mask_cs = 0;
    prog_dec_cs = 0;
    vid_dec_cs  = 0;

    if( !ASn ) begin
        casez( A[23:21] )
            3'b010: gfx_cs      = 1;
            3'b?00: prog_dec_cs = 1;
            3'b?01: vid_dec_cs  = 1;
            default:;
        endcase
    end
    if( prog_dec_cs ) begin
        case( A[20:18] )
            3'd0, 3'd1, 3'd2, 3'd3: rom_cs = 1;
            3'd4: ram_cs     = 1;
            3'd5: irq_mask_cs = 1;
            default:;
        endcase
    end
    if( vid_dec_cs ) begin
        case( A[19:18] )
            2'd0: sh_cs    = 1;
            2'd1: tile_cs  = 1;
            2'd2: begin gchar_sel = !BUSn; gchar_cs = !BUSn & ~video_grant_n; end
            2'd3: obj_cs   = 1;
            default:;
        endcase
    end
end

always @(posedge clk) begin
    cpu_din <= rom_cs   ? rom_dout            :
               ram_cs   ? ram_dout            :
               sh_cs    ? sh_dout             :
               tile_cs  ? { 8'd0, tile_dout } :
               obj_cs   ? { 8'd0, obj_dout  } :
               gchar_cs ? gchar_dout          :
               gfx_cs   ? gfx_data            :
               16'hffff;
end

jtframe_okdly #(.W(3)) u_okdly(
    .rst    ( rst_cpu ),
    .clk    ( clk     ),
    .cs     ( ok_cs   ),
    .ok     ( ok_in   ),
    .ok_dly ( ok_dly  )
);

jtgrad3_int u_int(
    .rst      ( rst_cpu          ),
    .clk      ( clk              ),
    .LVBL     ( LVBL             ),
    .cpu_trig ( cpu_trig         ),
    .din      ( cpu_dout[10:8]   ),
    .wr       ( irq_mask_cs      ),
    .IPLn     ( IPLn             )
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
    .num        ( cen_num   ),
    .den        ( 6'd24     ),
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       (           ),
    .fworst     (           )
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
       rom_addr=0, sh_we=0,
       gchar_we=0, gfx_addr=0, irq_trig=0, st_dout=0, ram_we=0;
initial begin
    rom_cs=0; tile_cs=0; obj_cs=0; gchar_cs=0; gfx_cs=0;
end
`endif

endmodule
