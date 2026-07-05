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
    Date: 2-7-2026 */

module jtgae1_main (
    input              clk,
    input              rst,
    input              lvbl,
    input              bigkarnk,
    input              vcrypt,
    input      [ 5:0]  vram_p1,

    output     [19:1]  main_addr,
    output reg         main_cs,
    input      [15:0]  main_data,
    input              main_data_ok,

    output     [15:0]  cpu_dout,
    output     [15:1]  ram_addr,
    output     [ 1:0]  ram_dsn,
    output             ram_we,
    output reg         ram_cs,
    input      [15:0]  ram_data,
    input              ram_ok,

    input      [15:0]  dipsw,
    input      [ 5:0]  joystick1,
    input      [ 5:0]  joystick2,
    input      [ 1:0]  coin,
    input      [ 1:0]  start,
    input              service,
    input              dip_test,
    input              dip_pause,

    output             flip,
    output     [13:0]  vmem_addr,
    output             vmem_uds, vmem_lds,
    output             vmem_we,
    output             vmem_vram_cs,
    output             vmem_scrram_cs,
    output             vmem_pal_cs,
    output             vmem_spr_cs,
    output     [15:0]  vmem_dec_wdata,
    output     [15:0]  vmem_io_wdata,
    input      [15:0]  vmem_vram_rdata,
    input      [15:0]  vmem_scrram_rdata,
    input      [15:0]  vmem_pal_rdata,
    input      [15:0]  vmem_spr_rdata,
    output     [15:0]  scr0_y, scr0_x, scr1_y, scr1_x,

    output     [ 7:0]  oki_din,
    input      [ 7:0]  oki_dout,
    output             oki_wrn,
    output     [ 3:0]  oki_bank,
    output reg [ 7:0]  snd_latch,
    output reg         snd_irq
);

wire [23:0] addr;
wire [15:0] scroll_dout;
wire [ 1:0] scroll_dsn;
wire        RnW;
reg         vregs_cs;

`ifndef NOMAIN
wire [23:1] A;
wire [ 2:0] FC, IPLn;
wire [15:0] dec_word, vmem_wdata;
wire [15:0] in_dsw1, in_dsw2, in_p1, in_p2, in_service;
wire [ 7:0] okibank;
wire [ 1:0] cpu_dsn;
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, ASn, BUSn, VPAn, DTACKn;
wire        bus_cs, bus_busy, LDSWn;
wire        IPL_n, uds, lds, vmem_acc, vram_or_scrram_cs, lvbl_fall;
wire        vdec_is2nd;
wire [15:0] vdec_prev_enc, vdec_prev_dec;

reg  [15:0] cpu_din;
reg  [15:0] vdec_last_enc, vdec_last_dec;
reg  [15:0] pend_enc, pend_dec;
reg  [12:0] vdec_prev_woff, pend_woff;
reg  [ 7:0] outlatch;
reg         vram_cs, scrram_cs, pal_cs, spr_cs;
reg         clrint_cs, dsw2_cs, dsw1_cs, p1_cs, p2_cs, service_cs;
reg         outlatch_cs, okibank_cs, oki_cs, snd_latch_cs;
reg         vdec_prev_wr, pend_vramwr, pend_is2nd;

assign addr             = { A, 1'b0 };
assign main_addr        = A[19:1];
assign ram_addr         = A[15:1];
assign ram_dsn          = cpu_dsn;
assign ram_we           = ram_cs & ~RnW;
assign cpu_dsn          = { UDSn, LDSn };
assign scroll_dsn       = cpu_dsn;
assign BUSn             = ASn | &cpu_dsn;
assign VPAn             = !(!ASn && FC == 3'd7 && RnW);
assign bus_cs           = main_cs | ram_cs;
assign bus_busy         = (main_cs & ~main_data_ok) | (ram_cs & ~ram_ok);
assign IPLn             = { IPL_n, IPL_n, 1'b1 };
assign LDSWn            = RnW | LDSn;
assign oki_wrn          = LDSWn | ~oki_cs;
assign oki_din          = cpu_dout[7:0];
assign oki_bank         = okibank[3:0];

assign in_dsw1          = { 8'hff, dipsw[ 7:0] };
assign in_dsw2          = bigkarnk ? { 8'hff, dipsw[15:8] } :
                                      { 8'hff, dipsw[15] & service, dipsw[14:8] };
assign in_p1            = { 8'hff, coin,  joystick1 };
assign in_p2            = { 8'hff, start, joystick2 };
assign in_service       = { 8'hff, 6'h3f, dip_test, service };

assign uds              = ~UDSn;
assign lds              = ~LDSn;
assign vmem_addr        = addr[13:0];
assign vmem_uds         = uds;
assign vmem_lds         = lds;
assign vmem_vram_cs     = vram_cs;
assign vmem_scrram_cs   = scrram_cs;
assign vmem_pal_cs      = pal_cs;
assign vmem_spr_cs      = spr_cs;
assign vmem_acc         = vram_cs | scrram_cs | pal_cs | spr_cs;
assign vmem_we          = ~RnW & vmem_acc;
assign vmem_dec_wdata   = vmem_wdata;
assign vmem_io_wdata    = cpu_dout;

assign vram_or_scrram_cs = vram_cs | scrram_cs;
assign vdec_is2nd        = vdec_prev_wr & (vdec_prev_woff == (addr[13:1] - 13'd1));
assign vdec_prev_enc     = vcrypt && vdec_is2nd ? vdec_last_enc : 16'd0;
assign vdec_prev_dec     = vcrypt && vdec_is2nd ? vdec_last_dec : 16'd0;
assign vmem_wdata        = vcrypt ? dec_word : cpu_dout;
assign lvbl_fall         = ~lvbl;

assign flip              = outlatch[5];

always @* begin
    main_cs     = 1'b0;
    ram_cs      = 1'b0;
    vram_cs     = 1'b0;
    scrram_cs   = 1'b0;
    pal_cs      = 1'b0;
    spr_cs      = 1'b0;
    vregs_cs    = 1'b0;
    clrint_cs   = 1'b0;
    dsw2_cs     = 1'b0;
    dsw1_cs     = 1'b0;
    p1_cs       = 1'b0;
    p2_cs       = 1'b0;
    service_cs  = 1'b0;
    outlatch_cs = 1'b0;
    okibank_cs  = 1'b0;
    oki_cs      = 1'b0;
    snd_latch_cs = 1'b0;

    main_cs   = !BUSn && addr[23:20] == 4'h0 && RnW;
    ram_cs    = !BUSn && addr[23:16] == 8'hff;
    vram_cs   = !BUSn && addr[23:14] == 10'b0001_0000_00 && ~addr[13];
    scrram_cs = !BUSn && addr[23:14] == 10'b0001_0000_00 &&  addr[13];
    pal_cs    = !BUSn && addr[23:20] == 4'h2 && addr[19:11] == 9'd0;
    spr_cs    = !BUSn && addr[23:16] == 8'h44 && addr[15:12] == 4'h0;
    vregs_cs  = !BUSn && addr[23:12] == 12'h108 && addr[11:3] == 9'd0;
    clrint_cs = !BUSn && addr[23:12] == 12'h108 && addr[11:2] == 10'b0000000011;

    if (!BUSn && addr[23:8] == 16'h7000) begin
        dsw1_cs     = addr[7:1] == (bigkarnk ? 7'h00 : 7'h01);
        dsw2_cs     = addr[7:1] == (bigkarnk ? 7'h01 : 7'h00);
        p1_cs       = addr[7:1] == 7'h02;
        p2_cs       = addr[7:1] == 7'h03;
        service_cs  = bigkarnk && addr[7:1] == 7'h04;
        outlatch_cs = addr[7:1] == 7'h05;
        okibank_cs  = !bigkarnk && addr[7:1] == 7'h06;
        oki_cs      = !bigkarnk && addr[7:1] == 7'h07;
        snd_latch_cs =  bigkarnk && addr[7:1] == 7'h07;
    end
end

always @(posedge clk) begin
    cpu_din <= main_cs  ? main_data        :
               ram_cs   ? ram_data         :
               vram_cs   ? vmem_vram_rdata  :
               scrram_cs ? vmem_scrram_rdata:
               pal_cs    ? vmem_pal_rdata   :
               spr_cs    ? vmem_spr_rdata   :
               vregs_cs  ? scroll_dout      :
               dsw2_cs   ? in_dsw2          :
               dsw1_cs   ? in_dsw1          :
               p1_cs     ? in_p1            :
               p2_cs     ? in_p2            :
               service_cs ? in_service       :
               oki_cs    ? { 8'hff, oki_dout } : 16'hffff;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        vdec_prev_wr   <= 1'b0;
        vdec_prev_woff <= 13'd0;
        vdec_last_enc  <= 16'd0;
        vdec_last_dec  <= 16'd0;
        pend_woff      <= 13'd0;
        pend_enc       <= 16'd0;
        pend_dec       <= 16'd0;
        pend_vramwr    <= 1'b0;
        pend_is2nd     <= 1'b0;
    end else begin
        if (!BUSn) begin
            pend_woff   <= addr[13:1];
            pend_enc    <= cpu_dout;
            pend_dec    <= vmem_wdata;
            pend_vramwr <= ~RnW & vram_or_scrram_cs;
            pend_is2nd  <= vdec_is2nd;
        end else begin
            if (pend_vramwr) begin
                vdec_prev_wr <= ~pend_is2nd;
                if (!pend_is2nd) begin
                    vdec_prev_woff <= pend_woff;
                    vdec_last_enc  <= pend_enc;
                    vdec_last_dec  <= pend_dec;
                end
            end
            pend_vramwr <= 1'b0;
            pend_is2nd  <= 1'b0;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        snd_latch <= 8'd0;
        snd_irq   <= 1'b0;
    end else begin
        snd_irq <= 1'b0;
        if (snd_latch_cs && !LDSWn) begin
            snd_latch <= cpu_dout[7:0];
            snd_irq   <= 1'b1;
        end
    end
end

jtframe_edge #(.QSET(0)) u_irq(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( lvbl_fall ),
    .clr    ( clrint_cs ),
    .q      ( IPL_n     )
);

jtframe_8bit_reg u_okibank(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .wr_n       ( LDSWn          ),
    .din        ( cpu_dout[7:0]  ),
    .cs         ( okibank_cs     ),
    .dout       ( okibank        )
);

always @(posedge clk) begin
    if (rst) begin
        outlatch <= 8'd0;
    end else if (outlatch_cs && !LDSWn) begin
        outlatch[addr[6:4]] <= cpu_dout[0];
    end
end

jtframe_68kdtack_cen #(.W(6),.RECOVERY(1)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ( cpu_dsn   ),
    .num        ( 5'd1      ),
    .den        ( 6'd4      ),
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       (           ),
    .fworst     (           )
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

jtgae1_vram_decrypt u_decrypt (
    .key        ( vram_p1       ),
    .prev_ciph  ( vdec_prev_enc ),
    .prev_plain ( vdec_prev_dec ),
    .din        ( cpu_dout      ),
    .dout       ( dec_word      )
);

`else
assign main_addr       = 19'd0;
assign ram_addr        = 15'd0;
assign ram_dsn         = 2'b11;
assign ram_we          = 1'b0;
assign flip            = 1'b0;
assign vmem_addr       = 14'd0;
assign vmem_uds        = 1'b0;
assign vmem_lds        = 1'b0;
assign vmem_we         = 1'b0;
assign vmem_vram_cs    = 1'b0;
assign vmem_scrram_cs  = 1'b0;
assign vmem_pal_cs     = 1'b0;
assign vmem_spr_cs     = 1'b0;
assign vmem_dec_wdata  = 16'd0;
assign vmem_io_wdata   = 16'd0;
assign oki_din         = 8'd0;
assign oki_wrn         = 1'b1;
assign oki_bank        = 4'd0;

assign addr            = 24'd0;
assign cpu_dout        = 16'd0;
assign RnW             = 1'b1;
assign scroll_dsn      = 2'b11;

initial begin
    main_cs = 1'b0;
    ram_cs  = 1'b0;
    vregs_cs = 1'b0;
    snd_latch = 8'd0;
    snd_irq   = 1'b0;
end
`endif

jtgae1_scroll_mmr u_scroll_mmr (
    .rst        ( rst         ),
    .clk        ( clk         ),
    .cs         ( vregs_cs    ),
    .addr       ( addr[2:1]   ),
    .rnw        ( RnW         ),
    .din        ( cpu_dout    ),
    .dout       ( scroll_dout ),
    .dsn        ( scroll_dsn  ),
    .scr0_y     ( scr0_y      ),
    .scr0_x     ( scr0_x      ),
    .scr1_y     ( scr1_y      ),
    .scr1_x     ( scr1_x      ),
    .ioctl_addr ( 3'd0        ),
    .ioctl_din  (             ),
    .debug_bus  ( 8'd0        ),
    .st_dout    (             )
);

endmodule
