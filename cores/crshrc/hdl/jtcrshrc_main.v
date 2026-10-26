/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-10-2026 */

module jtcrshrc_main(
    input                rst,
    input                clk,
    input                LVBL,
    input                dip_pause,
    input                spr_busy,

    output        [23:1] main_addr,
    output        [15:0] main_dout,
    output               main_rnw,
    output        [ 1:0] main_dsn,
    output        [21:1] rom_addr,
    output               rom_cs,
    input         [15:0] rom_data,
    input                rom_ok,

    output        [ 1:0] ram_we, fgvram_we, pal_we,
                         rozvram_we, sprcg_we, sprvram_we,
    input         [15:0] ram_dout, fgvram_dout, pal_dout,
                         rozvram_dout, sprcg_dout, sprvram_dout,

    output reg    [ 7:0] gfxctrl,
    output reg           flip,
    output reg           roz_we,
    output reg    [ 4:1] roz_addr,

    output reg    [ 7:0] roz_bank,

    output reg    [ 7:0] snd_latch,
    output reg           snd_wr,
    input                snd_pending,

    input         [ 3:0] cab_1p, coin,
    input         [ 6:0] joystick1, joystick2, joystick3,
    input                service, tilt, dip_test,
    input         [31:0] dipsw
);

`ifndef NOMAIN
`ifdef JTFRAME_PLL5369
localparam CEN_W = 10;
localparam [CEN_W-2:0] CEN_NUM = 9'd352;
localparam [CEN_W-1:0] CEN_DEN = 10'd945;
`else
localparam CEN_W = 9;
localparam [CEN_W-2:0] CEN_NUM = 8'd88;
localparam [CEN_W-1:0] CEN_DEN = 9'd315;
`endif
localparam CLK_KHZ = `JTFRAME_MCLK / `ifdef JTFRAME_SDRAM96 2000 `else 1000 `endif;

wire [23:1] A;
reg  [15:0] cpu_din;
wire [ 2:0] cpu_fc;
wire        cpu_as_n, cpu_uds_n, cpu_lds_n, cpu_rnw;
wire        cen16, cen16b, dtack_n, inta_n, irq_n;
wire        bus_cs, bus_busy, cpu_bus, lo_we, hi_we;
wire        ram_cs, fgvram_cs, pal_cs, rozvram_cs;
wire        sprcg_cs, sprvram_cs;
wire        io_cs;
reg  [15:0] cab_dout;
wire        rom_ok_dly;
assign main_addr  = A;
assign rom_addr   = A[23:20]==4'h3 ? {2'b01,A[19:1]} :
                    A[23:21]==3'b010 ? {2'b10,A[19:1]} : A[21:1];
assign main_rnw   = cpu_rnw;
assign main_dsn   = { cpu_uds_n, cpu_lds_n };

assign cpu_bus = ~cpu_as_n && (cpu_rnw || main_dsn!=2'b11);
assign hi_we   = ~cpu_rnw & ~cpu_uds_n;
assign lo_we   = ~cpu_rnw & ~cpu_lds_n;

assign rom_cs     = cpu_bus & (A[23:19]==5'd0 || A[23:20]==4'h3 || A[23:21]==3'b010);
assign sprcg_cs   = cpu_bus & A[23:16]==8'ha0;
assign rozvram_cs = cpu_bus & A[23:13]==11'h680;
assign sprvram_cs = cpu_bus & A[23:13]==11'h700;
assign ram_cs     = cpu_bus & A[23:16]==8'hfe;
assign fgvram_cs  = cpu_bus & A[23:12]==12'hffd;
assign pal_cs     = cpu_bus & A[23:12]==12'hffe;
assign io_cs      = cpu_bus & A[23:8]==16'hfff0;

assign ram_we     = { ram_cs     & hi_we, ram_cs     & lo_we };
assign fgvram_we  = { fgvram_cs  & hi_we, fgvram_cs  & lo_we };
assign pal_we     = { pal_cs     & hi_we, pal_cs     & lo_we };
assign rozvram_we = { rozvram_cs & hi_we, rozvram_cs & lo_we };
assign sprcg_we   = { sprcg_cs   & ~spr_busy & hi_we, sprcg_cs   & ~spr_busy & lo_we };
assign sprvram_we = { sprvram_cs & ~spr_busy & hi_we, sprvram_cs & ~spr_busy & lo_we };

function [7:0] player;
    input [6:0] joy;
    begin
        player = {1'b1,joy[6],joy[5],joy[4],joy[0],joy[1],joy[2],joy[3]};
    end
endfunction

wire [7:0] p3 = player(joystick3);
always @* begin
    cab_dout = 16'hffff;
    case( A[7:1] )
        7'h00: cab_dout = {service,tilt,dip_test,cab_1p[1:0],coin[2:0],player(joystick1)};
        7'h01: cab_dout = {8'hff,player(joystick2)};
        7'h02: cab_dout = dipsw[15:0];
        7'h03: cab_dout = {snd_pending,3'd0,dipsw[27:24],8'd0};
        7'h05: cab_dout = {8'hff,dipsw[23:16]};
        7'h07: cab_dout = {8'hff,cab_1p[2],p3[6:0]};
        default:;
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        gfxctrl   <= 0;
        flip      <= 0;
        snd_latch <= 0;
        snd_wr    <= 0;
        roz_we    <= 0;
        roz_addr  <= 0;
        roz_bank  <= 0;
    end else begin
        snd_wr <= 0;
        roz_we <= 0;
        if( cpu_bus && A==23'h7fe000 && lo_we ) roz_bank <= main_dout[7:0];
        if( io_cs && !cpu_rnw ) begin
            case( A[7:1] )
                7'h00: if( lo_we ) begin
                    gfxctrl <= main_dout[7:0] & 8'hdf;
                    flip    <= main_dout[5];
                end
                7'h04: if( lo_we ) begin snd_latch <= main_dout[7:0]; snd_wr <= 1; end
                default:;
            endcase
            if( A[7:5]==3'b001 ) begin
                roz_we   <= 1;
                roz_addr <= A[4:1];
            end
        end
    end
end

always @(posedge clk) begin
    cpu_din <= rom_cs      ? rom_data      :
               ram_cs      ? ram_dout      :
               fgvram_cs   ? fgvram_dout   :
               pal_cs      ? pal_dout      :
               rozvram_cs  ? rozvram_dout  :
               sprcg_cs    ? sprcg_dout    :
               sprvram_cs  ? sprvram_dout  :
               io_cs       ? cab_dout      : 16'hffff;
end

assign bus_cs   = rom_cs || sprcg_cs || sprvram_cs;
assign bus_busy = (rom_cs & ~rom_ok_dly) || ((sprcg_cs || sprvram_cs) && spr_busy);

jtframe_okdly #(
    .W ( 1 )
) u_romok(
    .rst    ( rst        ),
    .clk    ( clk        ),
    .cs     ( rom_cs     ),
    .ok     ( rom_ok     ),
    .ok_dly ( rom_ok_dly )
);

fx68k u_cpu(
    .clk      ( clk       ),
    .enPhi1   ( cen16     ),
    .enPhi2   ( cen16b    ),
    .extReset ( rst       ),
    .pwrUp    ( rst       ),
    .HALTn    ( dip_pause ),
    .BERRn    ( 1'b1      ),
    .oRESETn  (           ),
    .oHALTEDn (           ),
    .eab      ( A         ),
    .iEdb     ( cpu_din   ),
    .oEdb     ( main_dout ),
    .ASn      ( cpu_as_n  ),
    .eRWn     ( cpu_rnw   ),
    .UDSn     ( cpu_uds_n ),
    .LDSn     ( cpu_lds_n ),
    .DTACKn   ( dtack_n   ),
    .BRn      ( 1'b1      ),
    .BGn      (           ),
    .BGACKn   ( 1'b1      ),
    .E        (           ),
    .VMAn     (           ),
    .VPAn     ( inta_n    ),
    .FC0      ( cpu_fc[0] ),
    .FC1      ( cpu_fc[1] ),
    .FC2      ( cpu_fc[2] ),
    .IPL0n    ( irq_n     ),
    .IPL1n    ( 1'b1      ),
    .IPL2n    ( 1'b1      )
);

assign inta_n = ~&{ cpu_fc, ~cpu_as_n };

jtframe_virq u_virq(
    .rst       ( rst       ),
    .clk       ( clk       ),
    .LVBL      ( LVBL      ),
    .dip_pause ( dip_pause ),
    .skip_en   ( 1'b0      ),
    .skip_but  ( 1'b0      ),
    .clr       ( ~inta_n   ),
    .custom_in ( 1'b0      ),
    .blin_n    ( irq_n     ),
    .blout_n   (           ),
    .custom_n  (           )
);

jtframe_68kdtack_cen #(
    .W     ( CEN_W   ),
    .MFREQ ( CLK_KHZ )
) u_dtack(
    .rst       ( rst                                  ),
    .clk       ( clk                                  ),
    .cpu_cen   ( cen16                                ),
    .cpu_cenb  ( cen16b                               ),
    .bus_cs    ( bus_cs                               ),
    .bus_busy  ( bus_busy                             ),
    .bus_legit ( spr_busy && (sprcg_cs || sprvram_cs) ),
    .bus_ack   ( 1'b0                                 ),
    .ASn       ( cpu_as_n                             ),
    .DSn       ( main_dsn                             ),
    .num       ( CEN_NUM                              ),
    .den       ( CEN_DEN                              ),
    .DTACKn    ( dtack_n                              ),
    .wait2     ( 1'b0                                 ),
    .wait3     ( 1'b0                                 ),
    .fave      (                                      ),
    .fworst    (                                      )
);

`ifdef SIMULATION
reg sim_lvbl;
reg [15:0] sim_p1, sim_p2;
integer sim_frame, sim_writes;
always @(posedge clk) begin
    if( rst ) begin
        sim_lvbl <= 0;
        sim_p1 <= 16'hffff;
        sim_p2 <= 16'hffff;
        sim_frame <= 0;
        sim_writes <= 0;
    end else begin
        sim_lvbl <= LVBL;
        if( io_cs && cpu_rnw && cen16b && !dtack_n ) begin
            if( A[7:1]==0 && cab_dout!=sim_p1 ) begin
                sim_p1 <= cab_dout;
                $display("CRSHRC_INPUT player=1 data=%04x joy=%02x",cab_dout,joystick1);
            end
            if( A[7:1]==1 && cab_dout!=sim_p2 ) begin
                sim_p2 <= cab_dout;
                $display("CRSHRC_INPUT player=2 data=%04x joy=%02x",cab_dout,joystick2);
            end
        end
        if( |fgvram_we ) sim_writes <= sim_writes+1;
        if( sim_lvbl && !LVBL ) begin
            sim_frame <= sim_frame+1;
            if( sim_frame%30==0 )
                $display("CRSHRC_BOOT frame=%0d pc=%04x%04x bus=%06x gfx=%02x bank=%02x fg_writes=%0d snd_pending=%0d",sim_frame,u_cpu.excUnit.PcH,u_cpu.excUnit.PcL,{A,1'b0},gfxctrl,roz_bank,sim_writes,snd_pending);
        end
    end
end
`endif


`else
assign main_addr  = 0;
assign rom_addr   = 0;
assign main_dout  = 0;
assign main_rnw   = 1;
assign main_dsn   = 2'b11;
assign rom_cs     = 0;
assign ram_we     = 0;
assign fgvram_we  = 0;
assign pal_we     = 0;
assign rozvram_we = 0;
assign sprcg_we   = 0;
assign sprvram_we = 0;

wire [ 7:0] scene_gfxctrl, scene_roz_bank;

jtcrshrc_control_mmr #(
    .SIMFILE ( "mmr.bin" ),
    .SEEK    ( 0         )
) u_scene(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .cs         ( 1'b0           ),
    .addr       ( 2'd0           ),
    .rnw        ( 1'b1           ),
    .din        ( 16'd0          ),
    .dsn        ( 2'b11          ),
    .gfxctrl    ( scene_gfxctrl  ),
    .roz_bank   ( scene_roz_bank ),
    .ioctl_addr ( 3'd0           ),
    .ioctl_din  (                ),
    .debug_bus  ( 8'd0           ),
    .st_dout    (                )
);

always @* begin
    gfxctrl  = scene_gfxctrl & 8'hdf;
    flip     = scene_gfxctrl[5];
    roz_bank = scene_roz_bank;
end

initial begin
    snd_latch = 0; snd_wr = 0; roz_we = 0; roz_addr = 0;
end
`endif

endmodule
