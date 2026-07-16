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
    Date: 1-7-2025 */

module jttoki_main(
    input             rst,
    input             clk,
    input             lvbl,
    input             cabal,

    // Input
    input      [1:0]  start_button,
    input      [6:0]  joystick1,
    input      [6:0]  joystick2,

    input      [31:0] dipsw,
    input             dip_pause,
    input             service,

    input      [15:0] cpu_rom_data,
    input             cpu_rom_ok,
    output reg [18:1] cpu_rom_addr,
    output reg        cpu_rom_cs,
    output     [15:0] cpu_dout,

    // Main RAM
    output     [15:1] ram_addr,
    output     [ 1:0] ram_we,
    input      [15:0] ram_dout,

    // Palette RAM
    output     [10:1] pal_cpu_addr,
    output     [ 1:0] pal_we,
    input      [15:0] pal_dout,

    // Fixed/BG RAM
    output     [10:1] vram_cpu_addr,
    output     [ 1:0] vram_we,
    input      [15:0] vram_dout,

    output     [10:1] scr1_cpu_addr,
    output     [ 1:0] scr1_we,
    input      [15:0] scr1_dout,

    output     [10:1] scr2_cpu_addr,
    output     [ 1:0] scr2_we,
    input      [15:0] scr2_dout,

    // Sprite RAM
    output     [10:1] obj_cpu_addr,
    output     [ 1:0] obj_we,
    input      [15:0] obj_dout,

    output     [8:0] scr1_scroll_x,
    output     [8:0] scr1_scroll_y,
    output     [8:0] scr2_scroll_x,
    output     [8:0] scr2_scroll_y,

    output            bg_order,

    output reg        sound_wr_2,
    output reg        sound_wr_4,
    output reg        sound_wr_6,

    output reg [15:0] m68k_sound_latch_0,
    output reg [15:0] m68k_sound_latch_1,

    input      [15:0] z80_sound_latch_0,
    input      [15:0] z80_sound_latch_1,
    input      [15:0] z80_sound_latch_2
);

`ifndef NOMAIN
localparam [3:0] CEN_NUM =  4'd5;
localparam [4:0] CEN_DEN = 5'd24;

wire [23:0] cpu_a;
reg  [15:0] cpu_din;
wire [ 2:0] cpu_fc;
wire        cpu_wrn, cpu_as_n, cpu_lds_n, cpu_uds_n,
            cen10, cen10b, dtack_n, int1;
wire [ 1:0] cpu_dsn, ram_byte_we, pal_byte_we, obj_byte_we,
            vram_byte_we, scr1_byte_we, scr2_byte_we;
wire [15:0] cab_dout, system_dout, cabal_joy_dout, cabal_inputs_dout;
wire        inta_n, inta_clr, bus_cs, bus_busy, sound_lwr;
wire [23:0] sound_base;

assign cpu_a[0] = 0;

assign cpu_dsn       = { cpu_uds_n, cpu_lds_n };
assign ram_byte_we   = { ram_cs     && !cpu_wrn && !cpu_uds_n, ram_cs     && !cpu_wrn && !cpu_lds_n };
assign pal_byte_we   = { palette_cs && !cpu_wrn && !cpu_uds_n, palette_cs && !cpu_wrn && !cpu_lds_n };
assign obj_byte_we   = { sprite_cs  && !cpu_wrn && !cpu_uds_n, sprite_cs  && !cpu_wrn && !cpu_lds_n };
assign vram_byte_we  = { vram_cs    && !cpu_wrn && !cpu_uds_n, vram_cs    && !cpu_wrn && !cpu_lds_n };
assign scr1_byte_we  = { scr1_cs    && !cpu_wrn && !cpu_uds_n, scr1_cs    && !cpu_wrn && !cpu_lds_n };
assign scr2_byte_we  = { scr2_cs    && !cpu_wrn && !cpu_uds_n, scr2_cs    && !cpu_wrn && !cpu_lds_n };
assign sound_lwr     = !cpu_wrn && !cpu_lds_n;

assign ram_addr      = cpu_a[15:1];
assign ram_we        = ram_byte_we;
assign pal_cpu_addr  = cpu_a[10:1];
assign pal_we        = pal_byte_we;
assign obj_cpu_addr  = cpu_a[10:1];
assign obj_we        = obj_byte_we;
assign vram_cpu_addr = cpu_a[10:1];
assign vram_we       = vram_byte_we;
assign scr1_cpu_addr = cpu_a[10:1];
assign scr1_we       = scr1_byte_we;
assign scr2_cpu_addr = cpu_a[10:1];
assign scr2_we       = scr2_byte_we;

assign sound_base    = cabal ? 24'he8000 : 24'h80000;
assign cab_dout      = {2'b11, joystick2[5:0], 2'b11, joystick1[5:0]};
assign system_dout   = {11'h7ff, start_button, 3'h7};
assign cabal_joy_dout = {joystick2[3:0], joystick1[3:0], 8'hff};
assign cabal_inputs_dout = {
    start_button[0], start_button[1],
    joystick1[6], joystick2[6],
    8'hff,
    joystick2[5], joystick2[4],
    joystick1[5], joystick1[4]
};

always @(posedge clk) begin
    if (rst) begin
        m68k_sound_latch_0 <= 16'b0;
        m68k_sound_latch_1 <= 16'b0;
    end else begin
        if ((cpu_a[23:0] == sound_base) && sound_lwr)
            m68k_sound_latch_0 <= {8'b0, cpu_dout[7:0]};
        if ((cpu_a[23:0] == sound_base + 24'd2) && sound_lwr)
            m68k_sound_latch_1 <= {8'b0, cpu_dout[7:0]};
    end
end

fx68k u_cpu(
        .clk      ( clk         ),
        .enPhi1   ( cen10       ),
        .enPhi2   ( cen10b      ),
        .extReset ( rst         ),
        .pwrUp    ( rst         ),
        .HALTn    ( dip_pause   ),
        .BERRn    ( 1'b1        ),
        .oRESETn  (             ),
        .oHALTEDn (             ),
        .eab      ( cpu_a[23:1] ),
        .iEdb     ( cpu_din     ),
        .oEdb     ( cpu_dout    ),
        .ASn      ( cpu_as_n    ),
        .eRWn     ( cpu_wrn     ),
        .UDSn     ( cpu_uds_n   ),
        .LDSn     ( cpu_lds_n   ),
        .DTACKn   ( dtack_n     ),
        .BRn      ( 1'b1        ),
        .BGn      (             ),
        .BGACKn   ( 1'b1        ),
        .E        (             ),
        .VMAn     (             ),
        .VPAn     ( inta_n      ),
        .FC0      ( cpu_fc[0]   ),
        .FC1      ( cpu_fc[1]   ),
        .FC2      ( cpu_fc[2]   ),
        .IPL0n    ( int1        ),
        .IPL1n    ( 1'b1        ),
        .IPL2n    ( 1'b1        )
);

assign inta_n  = ~&{cpu_fc[2], cpu_fc[1], cpu_fc[0], ~cpu_as_n};
assign inta_clr = ~inta_n;

jtframe_virq u_virq(
        .rst        ( rst       ),
        .clk        ( clk       ),
        .LVBL       ( ~lvbl     ),
        .dip_pause  ( dip_pause ), //handle cpu pause
        .skip_en    (),
        .skip_but   (),
        .clr        ( inta_clr  ),
        .custom_in  (),
        .blin_n     (),
        .blout_n    ( int1      ),
        .custom_n   ()
);

assign bus_cs   = cpu_rom_cs;
assign bus_busy = cpu_rom_cs & ~cpu_rom_ok;

jtframe_68kdtack_cen  u_dtack(
        .rst        ( rst       ),
        .clk        ( clk       ),
        .cpu_cen    ( cen10     ),
        .cpu_cenb   ( cen10b    ),
        .bus_cs     ( bus_cs    ),
        .bus_busy   ( bus_busy  ),
        .bus_legit  ( 1'b0      ),
        .bus_ack    ( 1'b0      ),
        .ASn        ( cpu_as_n  ),
        .DSn        ( cpu_dsn   ),
        .num        ( CEN_NUM   ),
        .den        ( CEN_DEN   ),
        .DTACKn     ( dtack_n   ),
        .wait2      ( 1'b0      ),
        .wait3      ( 1'b0      ),
        // unused
        .fave       (),
        .fworst     ()
);

///////// 68k bus mapping  ////////////////////
//
// 0x000000, 0x05ffff : rom        (393216)(ro)
// 0x060000, 0x06d7ff : cpu ram     (55296)(rw)
// 0x06d800, 0x06dfff : spriteram    (2048)(rw)
// 0x06e000, 0x06e7ff : palette      (2048)(rw)
// 0x06e800, 0x06efff : scr1 vram     (2048)(wo)
// 0x06f000, 0x06f7ff : scr2 vram     (2048)(wo)
// 0x06f800, 0x06ffff : videoram     (2048)(wo)
// gap
// 0x080000, 0x08000d : sound latch        (rw)
// gap
// 0x0a0000, 0x0a005f : scroll latch       (wo)
// gap
// 0x0c0000, 0x0c0001 : dip-switch port    (ro)
// 0x0c0002, 0x0c0003 : input port         (ro)
// 0x0c0004, 0x0c0005 : system port        (ro)
//
reg ram_cs, sprite_cs, palette_cs, scr1_cs, scr2_cs, vram_cs,
    scroll_cs, dsw_cs, inputs_cs, system_cs;
reg sound_cs_2, sound_cs_3, sound_cs_4, sound_cs_5, sound_cs_6;

always @(posedge clk) begin
    ram_cs       <= 1'd0;
    sprite_cs    <= 1'd0;
    palette_cs   <= 1'd0;
    scr1_cs      <= 1'd0;
    scr2_cs      <= 1'd0;
    vram_cs      <= 1'd0;
    scroll_cs    <= 1'd0;
    dsw_cs       <= 1'd0;
    inputs_cs    <= 1'd0;
    system_cs    <= 1'd0;
    cpu_rom_addr <= 18'd0;
    cpu_rom_cs   <= 1'd0;
    sound_cs_2   <= 1'd0;
    sound_cs_3   <= 1'd0;
    sound_cs_4   <= 1'd0;
    sound_cs_5   <= 1'd0;
    sound_cs_6   <= 1'd0;
    sound_wr_2   <= 1'd0;
    sound_wr_4   <= 1'd0;
    sound_wr_6   <= 1'd0;
    if(!cpu_as_n) begin
        if (cpu_a[23:0] < (cabal ? 24'h40000 : 24'h60000))
            cpu_rom_addr[18:1] <= cpu_a[18:1];

        cpu_rom_cs <= cpu_a[23:0] < (cabal ? 24'h40000 : 24'h60000);
        if (cabal) begin
            sprite_cs  <= cpu_a[23:0] >= 24'h43800 && cpu_a[23:0] < 24'h44000;
            ram_cs     <= (cpu_a[23:0] >= 24'h40000 && cpu_a[23:0] < 24'h43800) ||
                          (cpu_a[23:0] >= 24'h44000 && cpu_a[23:0] < 24'h50000);
            vram_cs    <= cpu_a[23:0] >= 24'h60000 && cpu_a[23:0] < 24'h60800;
            scr1_cs    <= cpu_a[23:0] >= 24'h80000 && cpu_a[23:0] < 24'h80200;
            palette_cs <= cpu_a[23:0] >= 24'he0000 && cpu_a[23:0] < 24'he0800;
            dsw_cs     <= cpu_a[23:0] >= 24'ha0000 && cpu_a[23:0] < 24'ha0002;
            inputs_cs  <= cpu_a[23:0] >= 24'ha0008 && cpu_a[23:0] < 24'ha000a;
            system_cs  <= cpu_a[23:0] >= 24'ha0010 && cpu_a[23:0] < 24'ha0012;
            sound_cs_2 <= cpu_a[23:0] == 24'he8004;
            sound_cs_3 <= cpu_a[23:0] == 24'he8006;
            sound_cs_4 <= cpu_a[23:0] == 24'he8008;
            sound_cs_5 <= cpu_a[23:0] == 24'he800a;
            sound_cs_6 <= cpu_a[23:0] == 24'he800c;
            sound_wr_2 <= (cpu_a[23:0] == 24'he8004) && sound_lwr;
            sound_wr_4 <= (cpu_a[23:0] == 24'he8008) && sound_lwr;
            sound_wr_6 <= (cpu_a[23:0] == 24'he800c) && sound_lwr;
        end else begin
            ram_cs     <= cpu_a[23:0] >= 24'h60000 && cpu_a[23:0] < 24'h6d800;
            //video
            sprite_cs  <= cpu_a[23:0] >= 24'h6d800 && cpu_a[23:0] < 24'h6e000; //2048
            palette_cs <= cpu_a[23:0] >= 24'h6e000 && cpu_a[23:0] < 24'h6e800; //2048
            scr1_cs    <= cpu_a[23:0] >= 24'h6e800 && cpu_a[23:0] < 24'h6f000; //2048
            scr2_cs    <= cpu_a[23:0] >= 24'h6f000 && cpu_a[23:0] < 24'h6f800; //2048
            vram_cs    <= cpu_a[23:0] >= 24'h6f800 && cpu_a[23:0] < 24'h70000; //2048
            //sound latch
            sound_cs_2 <= cpu_a[23:0] == 24'h80004;
            sound_cs_3 <= cpu_a[23:0] == 24'h80006;
            sound_cs_4 <= cpu_a[23:0] == 24'h80008;
            sound_cs_5 <= cpu_a[23:0] == 24'h8000a;
            sound_cs_6 <= cpu_a[23:0] == 24'h8000c;
            sound_wr_2 <= (cpu_a[23:0] == 24'h80004) && sound_lwr;
            sound_wr_4 <= (cpu_a[23:0] == 24'h80008) && sound_lwr;
            sound_wr_6 <= (cpu_a[23:0] == 24'h8000c) && sound_lwr;
            //scroll
            scroll_cs  <= cpu_a[23:0] >= 24'ha0000 && cpu_a[23:0] < 24'ha005f; //96
            //IO
            dsw_cs     <= cpu_a[23:0] >= 24'hc0000 && cpu_a[23:0] < 24'hc0001; //2
            inputs_cs  <= cpu_a[23:0] >= 24'hc0002 && cpu_a[23:0] < 24'hc0003; //2
            system_cs  <= cpu_a[23:0] >= 24'hc0004 && cpu_a[23:0] < 24'hc0005; //2
        end
    end
end

always @(posedge clk) begin
    cpu_din <= cpu_rom_cs ? cpu_rom_data :
                            ram_cs     ? ram_dout :
                            palette_cs ? pal_dout :
                            sprite_cs  ? obj_dout :
                            vram_cs    ? vram_dout :
                            scr1_cs    ? scr1_dout :
                            dsw_cs     ? dipsw[15:0] :
                            inputs_cs  ? (cabal ? cabal_joy_dout    : cab_dout) :
                            system_cs  ? (cabal ? cabal_inputs_dout : system_dout) :
                            sound_cs_2 ? z80_sound_latch_0 :
                            sound_cs_3 ? z80_sound_latch_1 :
                            sound_cs_5 ? z80_sound_latch_2 :
                            16'd0;
end
`else
assign cpu_dout      = 16'd0;
assign ram_addr      = 15'd0;
assign ram_we        = 2'd0;
assign pal_cpu_addr  = 10'd0;
assign pal_we        = 2'd0;
assign obj_cpu_addr  = 10'd0;
assign obj_we        = 2'd0;
assign vram_cpu_addr = 10'd0;
assign vram_we       = 2'd0;
assign scr1_cpu_addr = 10'd0;
assign scr1_we       = 2'd0;
assign scr2_cpu_addr = 10'd0;
assign scr2_we       = 2'd0;

initial begin
    cpu_rom_addr       = 18'd0;
    cpu_rom_cs         = 1'b0;
    sound_wr_2         = 1'b0;
    sound_wr_4         = 1'b0;
    sound_wr_6         = 1'b0;
    m68k_sound_latch_0 = 16'd0;
    m68k_sound_latch_1 = 16'd0;
end
`endif

jttoki_video_mmr u_video_mmr(
    .rst          ( rst                  ),
    .clk          ( clk                  ),

    .din          ( cpu_dout             ),
`ifndef NOMAIN
    .cs           ( scroll_cs            ),
    .addr         ( cpu_a[6:1]           ),
    .rnw          ( cpu_wrn              ),
    .dsn          ( cpu_dsn              ),
`else
    .cs           ( 1'b0                 ),
    .addr         ( 6'd0                 ),
    .rnw          ( 1'b1                 ),
    .dsn          ( 2'b11                ),
`endif

    .scr1_scroll_x( scr1_scroll_x        ),
    .scr1_scroll_y( scr1_scroll_y        ),
    .scr2_scroll_x( scr2_scroll_x        ),
    .scr2_scroll_y( scr2_scroll_y        ),
    .bg_order     ( bg_order             ),

    .ioctl_addr   ( 7'd0                 ),
    .ioctl_din    (                      ),
    .debug_bus    ( 8'd0                 ),
    .st_dout      (                      )
);

endmodule
