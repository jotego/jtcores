/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-10-2026 */

module jtsvolle_main(
    input              rst, clk, dip_pause, irq_event,
    output     [19:1]  addr,
    output     [15:0]  dout,
    output     [ 1:0]  dsn,
    output             rnw, rom_cs, work_cs, work_we,
    input      [15:0]  rom_data, work_data,
    input              rom_ok, work_ok,
    output     [ 1:0]  vram0_we, vram1_we, oram_we, pal_we,
    input      [15:0]  vram0_data, vram1_data, oram_data, pal_data,
    input      [ 5:0]  joystick1, joystick2,
    input      [ 3:0]  coin, cab_1p,
    input              service, dip_test,
    input      [15:0]  dipsw,
    output reg [ 7:0]  snd_latch,
    output reg         snd_wr,
    input              snd_pending,
    output     [ 8:0]  scrx0, scry0, scrx1, scry1,
    output     [15:0]  videoflags,
    output     [ 5:0]  obj_count, obj_pri,
    output     [31:0]  gga_h,
    output     [23:0]  gga_v,
    output     [ 7:0]  irq_control,
    input      [ 7:0]  debug_bus,
    output     [ 7:0]  debug_view
);

wire [23:1] a;
wire [2:0] fc;
wire asn, udsn, ldsn, dtackn, inta_n, cen, cenb;
wire cpu_access = !asn && fc != 3'b111 && dsn!=2'b11;
wire write_bus = cpu_access && !rnw && dsn != 2'b11;
wire vram0_cs, vram1_cs, oram_cs, pal_cs, gga_cs;
wire scroll_cs, flags_cs, objctl_cs, sound_cs;
wire p1_cs, p2_cs, dip_cs, pending_cs;
wire ready;
wire [7:0] system_bits = {1'b0, !cab_1p[1], !cab_1p[0], !coin[0],
                          !coin[1], 1'b0, !dip_test, !service};
wire [15:0] cpu_din = rom_cs ? (a[17:16]==2'b11 ? 16'd0 : rom_data) :
                     work_cs ? work_data :
                     vram0_cs ? vram0_data :
                     vram1_cs ? vram1_data :
                     oram_cs ? oram_data :
                     pal_cs ? pal_data :
                     p1_cs ? {system_bits, 2'b00, ~joystick1} :
                     p2_cs ? {system_bits, 2'b00, ~joystick2} :
                     dip_cs ? dipsw :
                     pending_cs ? {15'd0, snd_pending} : 16'hffff;
wire irq_n;
reg irq_pending, write_seen;
reg [3:0] gga_index;
wire write_once = write_bus && !write_seen;
wire control_we = write_once && (flags_cs ||
                  (scroll_cs && dsn==2'b00) || (objctl_cs && !ldsn));
wire gga_we = write_once && gga_cs && !ldsn;

assign addr = a[19:1];
assign dsn = {udsn,ldsn};
assign work_we = work_cs && write_bus;
assign vram0_we = {2{vram0_cs && write_bus}} & ~dsn;
assign vram1_we = {2{vram1_cs && write_bus}} & ~dsn;
assign oram_we  = {2{oram_cs && write_bus}} & ~dsn;
assign pal_we   = {2{pal_cs && write_bus}} & ~dsn;
assign inta_n = !(&fc && !asn);
assign irq_n = !irq_pending;
assign debug_view = debug_bus[0] ? a[15:8] : {irq_pending, fc, a[7:4]};

`ifdef SVOLLE_SIM_STATUS
always @(posedge clk) begin
    if(!rst && gga_we && !a[5])
        $display("SVOLLE GGA %x=%x",gga_index,dout[7:0]);
    if(!rst && write_once && objctl_cs)
        $display("SVOLLE sprite control %x=%x",a[4:1],dout[7:0]);
    if(!rst && irq_event)
        $display("SVOLLE IRQ addr=%x fc=%x flags=%x count=%d pending=%b",
            {a,1'b0},fc,videoflags,obj_count,snd_pending);
end
`endif

`ifdef SVOLLE_IO_STATUS
reg [15:0] last_p1, last_p2;
always @(posedge clk) begin
    if(rst) begin
        last_p1 <= 16'hffff;
        last_p2 <= 16'hffff;
    end else begin
        if(p1_cs && cpu_din!=last_p1) begin
            last_p1 <= cpu_din;
            $display("SVOLLE P1=%04x",cpu_din);
        end
        if(p2_cs && cpu_din!=last_p2) begin
            last_p2 <= cpu_din;
            $display("SVOLLE P2=%04x",cpu_din);
        end
    end
end
`endif

jtsvolle_decode u_decode(
    .addr       ( a             ),
    .access     ( cpu_access    ),
    .rnw        ( rnw           ),
    .rom_cs     ( rom_cs        ),
    .work_cs    ( work_cs       ),
    .vram0_cs   ( vram0_cs      ),
    .vram1_cs   ( vram1_cs      ),
    .oram_cs    ( oram_cs       ),
    .pal_cs     ( pal_cs        ),
    .gga_cs     ( gga_cs        ),
    .scroll_cs  ( scroll_cs     ),
    .flags_cs   ( flags_cs      ),
    .objctl_cs  ( objctl_cs     ),
    .sound_cs   ( sound_cs      ),
    .p1_cs      ( p1_cs         ),
    .p2_cs      ( p2_cs         ),
    .dip_cs     ( dip_cs        ),
    .pending_cs ( pending_cs    )
);

always @(posedge clk) begin
    if(rst) begin
        write_seen <= 0;
        irq_pending <= 0;
        snd_latch <= 0;
        snd_wr <= 0;
        gga_index <= 0;
    end else begin
        snd_wr <= 0;
        if(!write_bus) write_seen <= 0;
        else if(write_once) write_seen <= 1;
        if(!inta_n) irq_pending <= 0;
        else if(irq_event && dip_pause) irq_pending <= 1;
        if(write_once && sound_cs && !ldsn) begin
            snd_latch <= dout[7:0];
            snd_wr <= 1;
        end
        if(gga_we && a[5]) gga_index <= dout[3:0];
    end
end

jtsvolle_control_mmr u_control(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cs         ( control_we    ),
    .addr       ( a[4:1]        ),
    .rnw        ( rnw           ),
    .din        ( dout          ),
    .dsn        ( dsn           ),
    .scry0      ( scry0         ),
    .scrx0      ( scrx0         ),
    .scry1      ( scry1         ),
    .scrx1      ( scrx1         ),
    .videoflags ( videoflags    ),
    .obj_count  ( obj_count     ),
    .obj_pri    ( obj_pri       ),
    .ioctl_addr ( 5'd0          ),
    .ioctl_din  (               ),
    .debug_bus  ( debug_bus     ),
    .st_dout    (               )
);

jtsvolle_gga_mmr #(
    .INIT       ( 128'h0000001f0077736b0000011f6b615747 )
) u_gga(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cs         ( gga_we && !a[5] ),
    .addr       ( gga_index     ),
    .rnw        ( 1'b0          ),
    .din        ( dout[7:0]     ),
    .hblank     ( gga_h[7:0]    ),
    .hsync_start( gga_h[15:8]   ),
    .hsync_end  ( gga_h[23:16]  ),
    .htotal     ( gga_h[31:24]  ),
    .vblank     ( gga_v[7:0]    ),
    .vsync_start( gga_v[15:8]   ),
    .vsync_end  ( gga_v[23:16]  ),
    .irq_control( irq_control   ),
    .ioctl_addr ( 4'd0          ),
    .ioctl_din  (               ),
    .debug_bus  ( debug_bus     ),
    .st_dout    (               )
);

jtframe_okdly #(
    .W          ( 2             )
) u_ready(
    .clk        ( clk           ),
    .rst        ( rst           ),
    .cs         ( {work_cs,rom_cs} ),
    .ok         ( {work_ok,rom_ok} ),
    .ok_dly     ( ready         )
);

`ifndef NOMAIN
fx68k u_cpu(
    .clk        ( clk           ),
    .enPhi1     ( cen           ),
    .enPhi2     ( cenb          ),
    .extReset   ( rst           ),
    .pwrUp      ( rst           ),
    .HALTn      ( dip_pause     ),
    .BERRn      ( 1'b1          ),
    .oRESETn    (               ),
    .oHALTEDn   (               ),
    .eab        ( a             ),
    .iEdb       ( cpu_din       ),
    .oEdb       ( dout          ),
    .ASn        ( asn           ),
    .eRWn       ( rnw           ),
    .UDSn       ( udsn          ),
    .LDSn       ( ldsn          ),
    .DTACKn     ( dtackn        ),
    .BRn        ( 1'b1          ),
    .BGn        (               ),
    .BGACKn     ( 1'b1          ),
    .E          (               ),
    .VMAn       (               ),
    .VPAn       ( inta_n        ),
    .FC0        ( fc[0]         ),
    .FC1        ( fc[1]         ),
    .FC2        ( fc[2]         ),
    .IPL0n      ( irq_n         ),
    .IPL1n      ( 1'b1          ),
    .IPL2n      ( 1'b1          )
);

jtframe_68kdtack_cen #(
    .W          ( 12            ),
    .MFREQ      ( 53365         )
) u_dtack(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cpu_cen    ( cen           ),
    .cpu_cenb   ( cenb          ),
    .bus_cs     ( rom_cs || work_cs ),
    .bus_busy   ( !ready        ),
    .bus_legit  ( 1'b0          ),
    .bus_ack    ( 1'b0          ),
    .ASn        ( asn           ),
    .DSn        ( dsn           ),
    .num        ( 11'd416       ),
    .den        ( 12'd2775      ),
    .wait2      ( 1'b0          ),
    .wait3      ( 1'b0          ),
    .DTACKn     ( dtackn        ),
    .fave       (               ),
    .fworst     (               )
);
`else
assign a = 0;
assign fc = 0;
assign asn = 1;
assign udsn = 1;
assign ldsn = 1;
assign rnw = 1;
assign dout = 0;
`endif

endmodule
