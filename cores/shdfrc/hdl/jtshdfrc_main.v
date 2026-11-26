/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-11-2026 */

module jtshdfrc_main(
    input                rst,
    input                clk,

    input                line_start,
    input         [ 8:0] vpos,

    output        [19:1] rom_addr,
    output               rom_cs,
    input                rom_ok,
    input         [15:0] rom_data,

    output        [15:0] ram_din,
    output        [16:1] wram_addr,
    output               wram_cs,
    output               wram_we,
    output        [ 1:0] wram_dsn,
    input                wram_ok,
    input         [15:0] wram_data,
    output               spr_cpu_cs, spr_cpu_we,
    input                spr_cpu_ok, spr_cpu_hold,
    input                pal_local,
    output        [ 1:0] bg0_we, bg1_we, fg_we, pal_we,
    input         [15:0] bg0_q, bg1_q, fg_q, spr_q, pal_q,

    output reg    [ 8:0] scrx0, scry0, scrx1, scry1,
    output reg           flip,
    output reg           video_en,
    output reg    [ 7:0] brt,

    output reg           snd_on,
    output reg    [ 7:0] snd_latch,

    input         [ 9:0] joystick1,
    input         [ 9:0] joystick2,
    input         [ 1:0] cab_1p,
    input         [ 1:0] coin,
    input                service,
    input                dip_pause,
    input         [15:0] dipsw
);

wire [23:1] A;
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, RnW, ASn, VPAn, DTACKn;
wire [ 2:0] FC;
reg  [ 2:0] IPLn;
wire [15:0] cpu_dout;
reg  [15:0] cpu_din;
wire        vram_cs, bg0_cs, bg1_cs, fg_cs, spr_cs, pal_cs, scr_cs, io_cs;
reg  [15:0] io_dout;
wire [ 1:0] dsn_we;
wire        bus_active, bus_cs, bus_busy;

assign rom_addr   = A[19:1];
assign bus_active = !ASn && !(UDSn && LDSn);
assign VPAn       = !(!ASn && FC==3'd7);
assign dsn_we     = ~{UDSn, LDSn} & {2{~RnW}};

assign rom_cs  = bus_active && A[23:20]==4'h0;
assign vram_cs = bus_active && A[23:14]==10'h040;
assign bg0_cs  = vram_cs && A[13:12]==2'b00;
assign bg1_cs  = vram_cs && A[13:11]==3'b100;
assign fg_cs   = bus_active && A[23:13]==11'h0a0;
assign spr_cs  = bus_active && A[23:13]==11'h0a1;
assign pal_cs  = bus_active && A[23:15]==9'h030;
assign scr_cs  = bus_active && A[23:4] ==20'h1c000;
assign io_cs   = bus_active && A[23:6] ==18'h07400;
assign wram_cs = (bus_active && A[23:16]==8'h1f) || (vram_cs && !bg0_cs && !bg1_cs) ||
                 (pal_cs && !pal_local);
assign wram_addr = pal_cs ? {2'b11, A[14:1]} : {vram_cs, A[15:1]};

assign bus_cs   = rom_cs | wram_cs | spr_cs;
assign bus_busy = (rom_cs & ~rom_ok) | (wram_cs & ~wram_ok) | (spr_cs & ~spr_cpu_ok);

assign ram_din  = cpu_dout;
assign wram_we  = wram_cs & ~RnW;
assign wram_dsn = {UDSn, LDSn};
assign bg0_we   = dsn_we & {2{bg0_cs}};
assign bg1_we   = dsn_we & {2{bg1_cs}};
assign fg_we    = dsn_we & {2{fg_cs}};
assign spr_cpu_cs = spr_cs;
assign spr_cpu_we = !RnW;
assign pal_we   = dsn_we & {2{pal_cs && pal_local}};

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scrx0 <= 0; scry0 <= 0; scrx1 <= 0; scry1 <= 0; flip <= 0;
    end else if( scr_cs && !RnW && !LDSn ) begin
        case( A[3:1] )
            3'd0: scrx0 <= cpu_dout[8:0];
            3'd1: scry0 <= cpu_dout[8:0];
            3'd2: scrx1 <= cpu_dout[8:0];
            3'd3: scry1 <= cpu_dout[8:0];
            3'd5: flip  <= cpu_dout[0];
            default:;
        endcase
    end
end

reg  [2:0] irq;
reg        irqs_en, ras_en, vblank;
reg  [8:0] ras_sl;
reg        io_we_l;
wire       io_we = io_cs && !RnW;
wire       io_we_edge = io_we && !io_we_l;

always @* begin
    IPLn = irq[2] ? ~3'd3 : irq[1] ? ~3'd2 : irq[0] ? ~3'd1 : 3'b111;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        irq <= 0; irqs_en <= 0; ras_en <= 0; ras_sl <= 0; vblank <= 0;
        video_en <= 0; brt <= 8'hff; snd_on <= 0; snd_latch <= 0; io_we_l <= 0;
    end else begin
        io_we_l <= io_we;
        snd_on  <= 0;

        if( line_start ) begin
            if( vpos==9'd0   ) vblank <= 0;
            if( vpos==9'd247 ) vblank <= 1;
            if( ras_en && vpos==ras_sl ) begin
                ras_sl <= ras_sl==9'd239 ? 9'd0 : ras_sl + 9'd1;
                irq[0] <= 1;
            end
            if( irqs_en && vpos[3:0]==0 ) irq[1] <= 1;
            if( irqs_en && vpos==9'd248 ) irq[2] <= 1;
        end
        if( io_we_edge ) begin
            case( A[5:1] )
                5'd0: irq[2] <= 0;
                5'd1: irq[1] <= 0;
                5'd2: irq[0] <= 0;
                5'd3: if( !LDSn ) begin
                    irqs_en  <= cpu_dout[0];
                    video_en <= cpu_dout[3];
                    ras_en   <= cpu_dout[2];
                end
                5'd4: if( !LDSn ) ras_sl <= cpu_dout[8:0];
                5'd6: begin
                    if( !UDSn ) begin snd_latch <= cpu_dout[15:8]; snd_on <= 1; end
                    if( !LDSn ) brt <= cpu_dout[7:0];
                end
                default:;
            endcase
        end
    end
end

wire [7:0] p1  = { cab_1p[0], joystick1[6:4], joystick1[3:0] };
wire [7:0] p2  = { cab_1p[1], joystick2[6:4], joystick2[3:0] };

wire [7:0] extra = { 2'b11, joystick2[9:7], joystick1[9:7] };
wire [3:0] sys = { 1'b1, service, coin[1], coin[0] };
wire [7:0] dsw1 = dipsw[7:0], dsw2 = dipsw[15:8];

always @(posedge clk) begin
    case( A[2:1] )
        2'd0: io_dout <= { 2'b0, dsw2[7:6], sys, p1 };
        2'd1: io_dout <= { 2'b0, dsw2[5:0], p2 };
        2'd2: io_dout <= { 2'b0, dsw1[5:0], extra };
        2'd3: io_dout <= { 2'b0, 3'b111, vblank, dsw1[7:6], 8'hff };
    endcase
end

always @(posedge clk) begin
    cpu_din <= ({16{rom_cs}}  & rom_data)  |
               ({16{wram_cs}} & wram_data) |
               ({16{bg0_cs}}  & bg0_q)     |
               ({16{bg1_cs}}  & bg1_q)     |
               ({16{fg_cs}}   & fg_q)      |
               ({16{spr_cs}}  & spr_q)     |
               ({16{pal_cs && pal_local}} & pal_q) |
               ({16{io_cs && A[5]}} & io_dout);
end

jtframe_68kdtack_cen #(
    .W ( 6 )
) u_dtack(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .cpu_cen    ( cpu_cen      ),
    .cpu_cenb   ( cpu_cenb     ),
    .bus_cs     ( bus_cs       ),
    .bus_busy   ( bus_busy     ),
    .bus_legit  ( spr_cpu_hold ),
    .bus_ack    ( 1'b0         ),
    .RnW        ( RnW          ),
    .BGACKn     ( 1'b1         ),
    .ASn        ( ASn          ),
    .DSn        ( {UDSn, LDSn} ),
    .num        ( 5'd1         ),
    .den        ( 6'd4         ),
    .DTACKn     ( DTACKn       ),
    .waitn      ( 2'd0         ),
    .fave       (              ),
    .fworst     (              )
);

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .RESETn     (             ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),
    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),
    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( VPAn        ),
    .FC         ( FC          ),
    .BERRn      ( 1'b1        ),
    .HALTn      ( dip_pause   ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),
    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        )
);

endmodule
