/*  SPDX-FileCopyrightText: © 2026 Andrea Bogazzi
    SPDX-License-Identifier: GPL-3.0-or-later
    Date: 25-10-2026 */

module jtf1gpr2_main(
    input                rst,
    input                clk,
    input                LVBL,
    input                dip_pause,

    output        [21:1] main_addr,
    output        [15:0] main_dout,
    output               main_rnw,
    output        [ 1:0] main_dsn,
    output               rom_cs,
    input         [15:0] rom_data,
    input                rom_ok,

    output        [ 1:0] ram_we, shared_we, fgvram_we, pal_we,
                         rozvram_we, sprcg_we, sprvram_we,
    input         [15:0] ram_dout, shared_dout, fgvram_dout, pal_dout,
                         rozvram_dout, sprcg_dout, sprvram_dout,

    output reg    [ 7:0] gfxctrl,
    output reg           flip,
    output reg    [ 8:0] fg_scrx, fg_scry,
    output reg           roz_we,
    output reg    [ 4:1] roz_addr,

    output reg    [ 7:0] roz_bank,

    output reg    [ 7:0] snd_latch,
    output reg           snd_wr,
    input                snd_pending,

    input         [ 3:0] cab_1p, coin,
    input         [ 5:0] joystick1,
    input         [ 7:0] wheel,
    input                service, tilt, dip_test,
    input         [31:0] dipsw
);

`ifndef NOMAIN
localparam [6:0] CEN_NUM = 7'd11;
localparam [7:0] CEN_DEN = 8'd63;

wire [23:1] A;
reg  [15:0] cpu_din;
wire [ 2:0] cpu_fc;
wire        cpu_as_n, cpu_uds_n, cpu_lds_n, cpu_rnw;
wire        cen10, cen10b, dtack_n, inta_n, irq_n;
wire        bus_cs, bus_busy, cpu_bus, lo_we, hi_we;
wire        ram_cs, shared_cs, fgvram_cs, pal_cs, rozvram_cs;
wire        sprcg_cs, sprvram_cs;
wire        io_cs, ffblk;
reg  [15:0] cab_dout;
wire        rom_ok_dly;
assign main_addr  = A[21:1];
assign main_rnw   = cpu_rnw;
assign main_dsn   = { cpu_uds_n, cpu_lds_n };

assign cpu_bus = ~cpu_as_n && (cpu_rnw || main_dsn!=2'b11);
assign hi_we   = ~cpu_rnw & ~cpu_uds_n;
assign lo_we   = ~cpu_rnw & ~cpu_lds_n;

assign ffblk      = &A[23:16];
assign rom_cs     = cpu_bus & (A[23:18]==6'd0 ||
                               A[23:21]==3'b000 && A[20] ||
                               A[23:20]==4'h2);
assign sprcg_cs   = cpu_bus & A[23:16]==8'ha0 & ~A[15];        // a00000-a07fff
assign rozvram_cs = cpu_bus & A[23:16]==8'hd0 & A[15:13]==3'd0; // d00000-d01fff, no mirror
assign sprvram_cs = cpu_bus & A[23:16]==8'he0 & A[15:12]==4'd0; // e00000-e00fff
assign ram_cs     = cpu_bus & ffblk & A[15:14]==2'b10;
assign shared_cs  = cpu_bus & ffblk & A[15:12]==4'hc;
assign fgvram_cs  = cpu_bus & ffblk & A[15:12]==4'hd;
assign pal_cs     = cpu_bus & ffblk & A[15:12]==4'he;
assign io_cs      = cpu_bus & ffblk & A[15:8]==8'hf0;

assign ram_we     = { ram_cs     & hi_we, ram_cs     & lo_we };
assign shared_we  = { shared_cs  & hi_we, shared_cs  & lo_we };
assign fgvram_we  = { fgvram_cs  & hi_we, fgvram_cs  & lo_we };
assign pal_we     = { pal_cs     & hi_we, pal_cs     & lo_we };
assign rozvram_we = { rozvram_cs & hi_we, rozvram_cs & lo_we };
assign sprcg_we   = { sprcg_cs   & hi_we, sprcg_cs   & lo_we };
assign sprvram_we = { sprvram_cs & hi_we, sprvram_cs & lo_we };

always @* begin
    cab_dout = 16'hffff;
    case( A[7:1] )
        7'h00: cab_dout = { 1'b1, ~service, 3'b111, cab_1p[0], coin[1:0],
                            2'b11, joystick1[4], joystick1[5],
                            joystick1[0], joystick1[1],
                            joystick1[2], joystick1[3] };
        7'h01: cab_dout = { 8'h0, wheel };
        7'h02: cab_dout = dipsw[15:0];
        7'h03: cab_dout = { dipsw[23:16], 8'h0 };
        7'h04: cab_dout = { 8'hff, {8{snd_pending}} };
        7'h05: cab_dout = { 15'd0, dipsw[24] };
        default:;
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        gfxctrl   <= 0;
        flip      <= 0;
        fg_scrx   <= 0;
        fg_scry   <= 0;
        snd_latch <= 0;
        snd_wr    <= 0;
        roz_we    <= 0;
        roz_addr  <= 0;
        roz_bank  <= 0;
    end else begin
        snd_wr <= 0;
        roz_we <= 0;
        if( io_cs && !cpu_rnw ) begin
            case( A[7:1] )
                7'h00: begin
                    if( hi_we ) roz_bank <= main_dout[15:8];
                    if( lo_we ) begin
                        gfxctrl <= main_dout[7:0] & 8'hdf;
                        flip    <= main_dout[5];
                    end
                end
                7'h04: if( lo_we ) begin snd_latch <= main_dout[7:0]; snd_wr <= 1; end
                7'h22: fg_scrx <= main_dout[8:0];
                7'h23: fg_scry <= main_dout[8:0];
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
               shared_cs   ? shared_dout   :
               fgvram_cs   ? fgvram_dout   :
               pal_cs      ? pal_dout      :
               rozvram_cs  ? rozvram_dout  :
               sprcg_cs    ? sprcg_dout    :
               sprvram_cs  ? sprvram_dout  :
               io_cs       ? cab_dout      : 16'hffff;
end

assign bus_cs   = rom_cs;
assign bus_busy = rom_cs & ~rom_ok_dly;

jtframe_okdly #(.W(1)) u_romok(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .cs     ( rom_cs        ),
    .ok     ( rom_ok        ),
    .ok_dly ( rom_ok_dly    )
);

fx68k u_cpu(
    .clk        ( clk       ),
    .enPhi1     ( cen10     ),
    .enPhi2     ( cen10b    ),
    .extReset   ( rst       ),
    .pwrUp      ( rst       ),
    .HALTn      ( dip_pause ),
    .BERRn      ( 1'b1      ),
    .oRESETn    (           ),
    .oHALTEDn   (           ),
    .eab        ( A         ),
    .iEdb       ( cpu_din   ),
    .oEdb       ( main_dout ),
    .ASn        ( cpu_as_n  ),
    .eRWn       ( cpu_rnw   ),
    .UDSn       ( cpu_uds_n ),
    .LDSn       ( cpu_lds_n ),
    .DTACKn     ( dtack_n   ),
    .BRn        ( 1'b1      ),
    .BGn        (           ),
    .BGACKn     ( 1'b1      ),
    .E          (           ),
    .VMAn       (           ),
    .VPAn       ( inta_n    ),
    .FC0        ( cpu_fc[0] ),
    .FC1        ( cpu_fc[1] ),
    .FC2        ( cpu_fc[2] ),
    .IPL0n      ( irq_n     ),
    .IPL1n      ( 1'b1      ),
    .IPL2n      ( 1'b1      )
);

assign inta_n = ~&{ cpu_fc, ~cpu_as_n };

jtframe_virq u_virq(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .LVBL       ( LVBL      ),
    .dip_pause  ( dip_pause ),
    .skip_en    ( 1'b0      ),
    .skip_but   ( 1'b0      ),
    .clr        ( ~inta_n   ),
    .custom_in  ( 1'b0      ),
    .blin_n     ( irq_n     ),
    .blout_n    (           ),
    .custom_n   (           )
);

jtframe_68kdtack_cen #(.W(8),.MFREQ(`JTFRAME_MCLK/2000)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cen10     ),
    .cpu_cenb   ( cen10b    ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( cpu_as_n  ),
    .DSn        ( main_dsn  ),
    .num        ( CEN_NUM   ),
    .den        ( CEN_DEN   ),
    .DTACKn     ( dtack_n   ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       (           ),
    .fworst     (           )
);


`else
assign main_addr  = 0;
assign main_dout  = 0;
assign main_rnw   = 1;
assign main_dsn   = 2'b11;
assign rom_cs     = 0;
assign ram_we     = 0;
assign shared_we  = 0;
assign fgvram_we  = 0;
assign pal_we     = 0;
assign rozvram_we = 0;
assign sprcg_we   = 0;
assign sprvram_we = 0;

initial begin
    gfxctrl = 0; flip = 0; fg_scrx = 0; fg_scry = 0;
    snd_latch = 0; snd_wr = 0; roz_we = 0; roz_addr = 0;
    roz_bank = 0;
end
`endif

endmodule
