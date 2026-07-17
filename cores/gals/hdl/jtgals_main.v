/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 12-7-2026 */

module jtgals_main(
    input              rst,
    input              clk,
    input              lvbl,
    input       [ 8:0] vdump,
    input              dip_pause,
    input              prot_wdog,

    input       [ 5:0] joystick1,
    input       [ 5:0] joystick2,
    input       [ 1:0] start_button,
    input       [ 1:0] coin,
    input              service,
    input              tilt,
    input       [31:0] dipsw,

    output      [23:1] cpu_addr,
    output      [15:0] cpu_dout,
    output reg  [15:0] cpu_din,
    output             cpu_rnw,

    output      [16:1] ram_addr,
    output      [ 1:0] ram_dsn,
    output reg         ram_cs,
    input       [15:0] ram_data,
    input              ram_ok,

    output      [16:1] fg_addr,
    output      [ 1:0] fg_we,
    input       [15:0] fg_dout,
    output      [16:1] bg_addr,
    output      [ 1:0] bg_we,
    input       [15:0] bg_dout,
    output      [10:1] pal_addr,
    output      [ 1:0] pal_we,
    input       [15:0] pal_dout,
    output      [12:1] objram_addr,
    output      [15:0] objram_din,
    output      [ 1:0] objram_we,
    input       [15:0] objram_dout,
    output      [13:1] objaux_addr,
    output      [ 1:0] objaux_we,
    input       [15:0] objaux_dout,

    input       [ 7:0] oki_dout,
    output reg         oki_cs,
    output             oki_wr,
    output             oki_bank_we,
    output reg  [ 3:0] oki_bank,
    output             irq3_n,
    output             irq5_n,
    output reg         fb_keep,

    output      [22:1] rom_addr,
    output reg         rom_cs,
    input       [15:0] rom_data,
    input              rom_ok
);

`ifndef NOMAIN

localparam [7:0] WDOG_FRAMES = 8'd180;

wire [23:1] A;
wire [ 2:0] fc;
wire        as_n, lds_n, uds_n, wr_n, dtack_n, vpa_n, bus_n;
wire        cpu_cen, cpu_cenb;
wire [ 1:0] dsn, fg_byte_we, bg_byte_we,
            pal_byte_we, objram_byte_we, objaux_byte_we;
wire [ 2:0] ipl_n;
wire        bus_cs, bus_busy, int_ack, calc_wdog_clr;
wire        irq3_clr, irq5_clr, irq3_trig, irq5_trig, vdump32;
wire [15:0] dsw1_dout, dsw2_dout, system_dout, calc_dout;
reg         fg_cs, bg_cs, pal_cs, objram_cs, objaux_cs,
            dsw1_cs, dsw2_cs, system_cs, calc_cs;
reg         lvbl_l, wdog_rst, main_rst;
reg  [ 7:0] wdog_frame_cnt;

assign rom_addr      = A[22:1];
assign cpu_addr      = A;
assign cpu_rnw       = wr_n;
assign dsn           = { uds_n, lds_n };
assign bus_n         = as_n | (lds_n & uds_n);
assign oki_wr        = oki_cs && !wr_n && !lds_n;
assign oki_bank_we   = !as_n && A[23:1] == 23'h480000 && !wr_n;
assign bus_cs        = rom_cs | ram_cs;
assign bus_busy      = (rom_cs && !rom_ok) | (ram_cs && !ram_ok);
assign int_ack       = fc == 3'b111 && !as_n;
assign vpa_n         = !int_ack;
assign ipl_n         = !irq5_n ? 3'b010 : (!irq3_n ? 3'b100 : 3'b111);
assign calc_wdog_clr = prot_wdog && calc_cs && wr_n && A[4:1] == 4'd0 && dsn != 2'b11;
assign vdump32       = vdump == 9'd32;
assign irq3_trig     = ~lvbl & dip_pause;
assign irq5_trig     = vdump32;
assign irq3_clr      = int_ack && !irq3_n;
assign irq5_clr      = int_ack &&  irq3_n;

assign ram_addr      = A[16:1];
assign ram_dsn       = dsn;
assign fg_addr       = A[16:1];
assign bg_addr       = A[16:1];
assign pal_addr      = A[10:1];
assign objram_addr   = A[12:1];
assign objaux_addr   = A[13:1] - 13'h1000;

assign fg_byte_we    = { 2 { fg_cs     && !wr_n } } & ~dsn;
assign bg_byte_we    = { 2 { bg_cs     && !wr_n } } & ~dsn;
assign pal_byte_we   = { 2 { pal_cs    && !wr_n } } & ~dsn;
assign objram_byte_we= { 2 { objram_cs && !wr_n } } & ~dsn;
assign objaux_byte_we= { 2 { objaux_cs && !wr_n } } & ~dsn;
assign fg_we         = fg_byte_we;
assign bg_we         = bg_byte_we;
assign pal_we        = pal_byte_we;
assign objram_we     = objram_byte_we;
assign objaux_we     = objaux_byte_we;
assign objram_din    = !uds_n ? { 2{ cpu_dout[15:8] } } : { 2{ cpu_dout[7:0] } };

assign dsw1_dout     = { 2'b11, joystick1, dipsw[ 7:0] };
assign dsw2_dout     = { 2'b11, joystick2, dipsw[15:8] };
assign system_dout   = { 1'b1, service, tilt, 1'b1, coin[1:0], start_button[1:0], 8'hff };

always @* begin
    rom_cs    = 1'b0;
    fg_cs     = 1'b0;
    bg_cs     = 1'b0;
    ram_cs    = 1'b0;
    pal_cs    = 1'b0;
    objram_cs = 1'b0;
    objaux_cs = 1'b0;
    dsw1_cs   = 1'b0;
    dsw2_cs   = 1'b0;
    system_cs = 1'b0;
    oki_cs    = 1'b0;
    calc_cs   = 1'b0;

    if (!bus_n) begin
        rom_cs    = A[23:22] == 2'b00;
        fg_cs     = A[23:17] == 7'b0101000;         // 500000-51ffff
        bg_cs     = A[23:17] == 7'b0101001;         // 520000-53ffff
        ram_cs    = bg_cs;                          // bg RAM also works as CPU RAM
        pal_cs    = A[23:11] == 13'b0110000000000;  // 600000-6007ff
        objram_cs = A[23:13] == 11'b01110000000;    // 700000-701fff
        objaux_cs = A[23:12] >= 12'h702 && A[23:12] <= 12'h704;
        dsw1_cs   = A[23:1] == 23'h400000;
        dsw2_cs   = A[23:1] == 23'h400001;
        system_cs = A[23:2] == 22'h200001;
        oki_cs    = A[23:1] == 23'h200000;
        calc_cs   = A[23:5] == 19'h70000 && A[4:1] <= 4'ha; // e00000-e00014
    end
end

always @(posedge clk) begin
    cpu_din <= rom_cs    ? rom_data :
               fg_cs     ? fg_dout :
               ram_cs    ? ram_data :
               bg_cs     ? bg_dout :
               pal_cs    ? pal_dout :
               objram_cs ? objram_dout :
               objaux_cs ? objaux_dout :
               dsw1_cs   ? dsw1_dout :
               dsw2_cs   ? dsw2_dout :
               system_cs ? system_dout :
               oki_cs    ? { 8'hff, oki_dout } :
               calc_cs   ? calc_dout :
               16'hffff;
end

always @(posedge clk) begin
    lvbl_l   <= lvbl;
    main_rst <= rst | (prot_wdog & wdog_rst);
end

always @(posedge clk) begin
    if (rst || !prot_wdog) begin
        wdog_frame_cnt <= 8'd0;
        wdog_rst       <= 1'b0;
    end else begin
        if (wdog_rst) begin
            if (!lvbl && lvbl_l)
                wdog_rst <= 1'b0;
        end else if (calc_wdog_clr) begin
            wdog_frame_cnt <= 8'd0;
        end else if (!lvbl && lvbl_l) begin
            if (wdog_frame_cnt == WDOG_FRAMES) begin
                wdog_frame_cnt <= 8'd0;
                wdog_rst       <= 1'b1;
            end else begin
                wdog_frame_cnt <= wdog_frame_cnt + 8'd1;
            end
        end
    end
end

always @(posedge clk) begin
    if (main_rst) begin
        oki_bank <= 4'd0;
        fb_keep  <= 1'b0;
    end else begin
        if (oki_bank_we && !uds_n) begin
            oki_bank <= cpu_dout[11:8];
            fb_keep  <=~cpu_dout[15];
        end
    end
end

jtgals_calc u_calc(
    .rst    ( main_rst  ),
    .clk    ( clk       ),
    .cs     ( calc_cs   ),
    .rnw    ( wr_n      ),
    .dsn    ( dsn       ),
    .addr   ( A[4:1]    ),
    .din    ( cpu_dout  ),
    .dout   ( calc_dout )
);

jtframe_edge #(.QSET(0)) u_irq3(
    .rst    ( main_rst  ),
    .clk    ( clk       ),
    .edgeof ( irq3_trig ),
    .clr    ( irq3_clr  ),
    .q      ( irq3_n    )
);

jtframe_edge #(.QSET(0)) u_irq5(
    .rst    ( main_rst  ),
    .clk    ( clk       ),
    .edgeof ( irq5_trig ),
    .clr    ( irq5_clr  ),
    .q      ( irq5_n    )
);

jtframe_m68k u_cpu(
    .clk     ( clk       ),
    .rst     ( main_rst  ),
    .cpu_cen ( cpu_cen   ),
    .cpu_cenb( cpu_cenb  ),
    .BERRn   ( 1'b1      ),
    .VPAn    ( vpa_n     ),
    .BGACKn  ( 1'b1      ),
    .HALTn   ( dip_pause ),
    .RESETn  (           ),
    .eab     ( A         ),
    .ASn     ( as_n      ),
    .LDSn    ( lds_n     ),
    .UDSn    ( uds_n     ),
    .eRWn    ( wr_n      ),
    .DTACKn  ( dtack_n   ),
    .iEdb    ( cpu_din   ),
    .oEdb    ( cpu_dout  ),
    .BRn     ( 1'b1      ),
    .BGn     (           ),
    .IPLn    ( ipl_n     ),
    .FC      ( fc        )
);

jtframe_68kdtack_cen u_dtack(
    .rst       ( main_rst ),
    .clk       ( clk      ),
    .cpu_cen   ( cpu_cen  ),
    .cpu_cenb  ( cpu_cenb ),
    .bus_cs    ( bus_cs   ),
    .bus_busy  ( bus_busy ),
    .bus_legit ( 1'b0     ),
    .bus_ack   ( 1'b0     ),
    .ASn       ( as_n     ),
    .DSn       ( dsn      ),
    .num       ( 4'd1     ),
    .den       ( 5'd4     ),
    .DTACKn    ( dtack_n  ),
    .wait2     ( 1'b0     ),
    .wait3     ( 1'b0     ),
    .fave      (          ),
    .fworst    (          )
);

`else

assign cpu_addr    = 23'd0;
assign cpu_dout    = 16'd0;
assign cpu_rnw     = 1'b1;
assign ram_addr    = 16'd0;
assign ram_dsn     = 2'd3;
assign fg_addr     = 16'd0;
assign fg_we       = 2'd0;
assign bg_addr     = 16'd0;
assign bg_we       = 2'd0;
assign pal_addr    = 10'd0;
assign pal_we      = 2'd0;
assign objram_addr = 12'd0;
assign objram_din  = 16'd0;
assign objram_we   = 2'd0;
assign objaux_addr = 13'd0;
assign objaux_we   = 2'd0;
assign oki_wr      = 1'b0;
assign oki_bank_we = 1'b0;
assign irq3_n      = 1'b1;
assign irq5_n      = 1'b1;

initial begin
    cpu_din  = 16'd0;
    ram_cs   = 1'b0;
    oki_cs   = 1'b0;
    oki_bank = 4'd0;
    fb_keep  = 1'b0;
    rom_addr = 22'd0;
    rom_cs   = 1'b0;
end

`endif

endmodule
