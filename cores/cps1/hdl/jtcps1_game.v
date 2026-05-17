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
    Date: 28-1-2020 */

module jtcps1_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire        clk_gfx, rst_gfx, hold_rst;
wire        main_ram_cs, main_vram_cs;
wire [ 1:0] joymode;
wire [17:1] ram_addr;
wire [15:0] mmr_dout;
wire        ppu1_cs, ppu2_cs, ppu_rstn;
wire [19:0] rom1_addr, rom0_addr;
wire [15:0] cpu_dout;
wire        cpu_speed;
wire        star_bank, dump_flag;

wire        main_rnw, busreq, busack;
wire [ 7:0] snd_latch0, snd_latch1;
wire [ 7:0] dipsw_a, dipsw_b, dipsw_c;

wire [12:0] star0_addr, star1_addr;
wire        vram_clr, vram_rfsh_en;
wire [ 8:0] hdump;
wire [ 8:0] vdump, vrender;

wire        rom0_half, rom1_half;
wire        cfg_we;

// EEPROM
wire        sclk, sdi, sdo, scs;

assign { dipsw_c, dipsw_b, dipsw_a } = dipsw[23:0];

wire [15:0] fave;
wire        cen10b;
wire        cpu_cen, cpu_cenb;
wire        charger;
wire        turbo, video_flip, filter_old;
reg         rst_game;

`include "turbo.vh"
assign filter_old   = dipsw[24];
assign debug_view   = debug_bus[0] ? fave[7:0] : fave[15:8];
assign clk_gfx  = clk;
assign rst_gfx  = rst;

always @(posedge clk) rst_game <= hold_rst | rst48;

localparam REGSIZE=24,
           START_HEADER=16;

localparam [ 5:0] CFG_BYTE=6'd39;
localparam [22:0] VRAM_OFFSET=23'h20_0000,
                  WRAM_OFFSET=23'h30_0000;

reg decrypt, pang3_bit;
wire dump_we = ioctl_wr & ioctl_ram;

function [7:0] pang3_decrypt;
    input [7:0] din;
    begin
        pang3_decrypt =
            (((((((din[0] ? 8'h04 : 8'h00) ^
                  (din[1] ? 8'h21 : 8'h00)) ^
                  (din[2] ? 8'h01 : 8'h00)) ^
                  (din[3] ? 8'h00 : 8'h50)) ^
                  (din[4] ? 8'h40 : 8'h00)) ^
                  (din[5] ? 8'h06 : 8'h00)) ^
                  (din[6] ? 8'h08 : 8'h00)) ^
                  (din[7] ? 8'h00 : 8'h88);
    end
endfunction

assign hold_rst   = 1'b0;
assign joymode    = 2'd0;
assign ram_vram_cs = main_ram_cs | main_vram_cs;
assign main_ram_we = !main_rnw;
assign main_offset = main_ram_cs ? WRAM_OFFSET : VRAM_OFFSET;
assign main_addr_x = { 3'd0, ram_addr };
assign gfx0_addr   = { rom0_addr, rom0_half, 1'b0 };
assign gfx1_addr   = { rom1_addr, rom1_half, 1'b0 };
assign gfx_star0   = { 1'b0, star_bank, 5'd0, star0_addr, 2'b00 };
assign gfx_star1   = { 1'b0, star_bank, 5'd0, star1_addr, 2'b10 };
assign cfg_we      = header && prog_we &&
                     ioctl_addr > 7 &&
                     ioctl_addr < (REGSIZE+START_HEADER);

always @(*) begin
    post_data = prog_data;
    if( prog_we && !header && !ioctl_ram && prog_ba==2'd0 &&
        ioctl_addr[19] && decrypt && (ioctl_addr[0]^pang3_bit) ) begin
        post_data = pang3_decrypt(prog_data);
    end
end

always @(posedge clk) begin
    if( rst || (header && prog_we && ioctl_addr==0) ) begin
        decrypt   <= 0;
        pang3_bit <= 0;
    end else if( header && prog_we && ioctl_addr[5:0]==CFG_BYTE ) begin
        { decrypt, pang3_bit } <= prog_data[7:6];
    end
end

// EEPROM used by Pang 3.
jt9346_16b8b #(.DW(16),.AW(6)) u_eeprom(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .sclk       ( sclk      ),
    .sdi        ( sdi       ),
    .sdo        ( sdo       ),
    .scs        ( scs       ),
    .dump_clk   ( clk       ),
    .dump_addr  ( ioctl_addr[7:0] ),
    .dump_we    ( dump_we   ),
    .dump_din   ( ioctl_dout),
    .dump_dout  ( ioctl_din ),
    .dump_flag  ( dump_flag ),
    .dump_clr   ( ioctl_ram )
);

// Turbo speed disables DMA
wire busreq_cpu = busreq & ~turbo;
wire busack_cpu;
assign busack = busack_cpu | turbo;
/* verilator tracing_on */
`ifndef NOMAIN
jtcps1_main u_main(
    .rst        ( rst_game          ),
    .clk        ( clk48             ),
    .cen10      ( cpu_cen           ),
    .cen10b     ( cpu_cenb          ),
    .cpu_cen    (                   ),
    .turbo      ( turbo             ),
    .joymode    ( joymode           ),
    // Timing
    .V          ( vdump             ),
    .LVBL       ( LVBL              ),
    .LHBL       ( LHBL              ),
    // PPU
    .ppu1_cs    ( ppu1_cs           ),
    .ppu2_cs    ( ppu2_cs           ),
    .ppu_rstn   ( ppu_rstn          ),
    .mmr_dout   ( mmr_dout          ),
    // Sound
    .snd_latch0 ( snd_latch0        ),
    .snd_latch1 ( snd_latch1        ),
    .UDSWn      ( dsn[1]            ),
    .LDSWn      ( dsn[0]            ),
    // cabinet I/O
    // Cabinet input
    .charger     ( charger          ),
    .cab_1p      ( cab_1p[1:0]      ),
    .coin        ( coin[1:0]        ),
    .joystick1   ( joystick1        ),
    .joystick2   ( joystick2        ),
    .dial_x      ( dial_x           ),
    .dial_y      ( dial_y           ),
    .service     ( service          ),
    .tilt        ( 1'b1             ),
    // BUS sharing
    .busreq      ( busreq_cpu       ),
    .busack      ( busack_cpu       ),
    .RnW         ( main_rnw         ),
    // RAM/VRAM access
    .addr        ( ram_addr         ),
    .cpu_dout    ( main_dout        ),
    .ram_cs      ( main_ram_cs      ),
    .vram_cs     ( main_vram_cs     ),
    .ram_data    ( main_ram_data    ),
    .ram_ok      ( main_ram_ok      ),
    // ROM access
    .rom_cs      ( main_rom_cs      ),
    .rom_addr    ( main_rom_addr    ),
    .rom_data    ( main_rom_data    ),
    .rom_ok      ( main_rom_ok      ),
    // DIP switches
    .dip_pause   ( dip_pause        ),
    .dip_test    ( dip_test         ),
    .dipsw_a     ( dipsw_a          ),
    .dipsw_b     ( dipsw_b          ),
    .dipsw_c     ( dipsw_c          ),
    .fave        ( fave             )
);
`else
assign ram_addr      = 0;
assign main_ram_cs   = 0;
assign main_vram_cs  = 0;
assign main_rom_cs   = 0;
assign main_rom_addr = 0;
assign main_dout     = 0;
assign dsn           = 2'b11;
assign main_rnw      = 1'b1;
assign busack_cpu    = 1;
assign ppu1_cs       = 0;
assign ppu2_cs       = 0;
assign ppu_rstn      = 1;
`endif

reg rst_video;

always @(posedge clk_gfx) begin
    rst_video <= rst_gfx;
end

assign dip_flip = video_flip;
/* verilator tracing_off */
jtcps1_video #(REGSIZE) u_video(
    .rst            ( rst_video     ),
    .clk            ( clk_gfx       ),
    .clk_cpu        ( clk48         ),
    .pxl2_cen       ( pxl2_cen      ),
    .pxl_cen        ( pxl_cen       ),

    .hdump          ( hdump         ),
    .vdump          ( vdump         ),
    .vrender        ( vrender       ),
    .gfx_en         ( gfx_en        ),
    .cpu_speed      ( cpu_speed     ),
    .charger        ( charger       ),
    .kabuki_en      (               ),
    .raster         (               ),
    .watch          (               ),
    .watch_vram_cs  (               ),
    .star_bank      ( star_bank     ),

    // CPU interface
    .ppu_rstn       ( ppu_rstn      ),
    .ppu1_cs        ( ppu1_cs       ),
    .ppu2_cs        ( ppu2_cs       ),
    .addr           ( ram_addr[12:1]),
    .dsn            ( dsn           ),      // data select, active low
    .cpu_dout       ( main_dout     ),
    .mmr_dout       ( mmr_dout      ),
    // BUS sharing
    .busreq         ( busreq        ),
    .busack         ( busack        ),

    // Video signal
    .HS             ( HS            ),
    .VS             ( VS            ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    .flip           ( video_flip    ),

    // CPS-B Registers
    .cfg_we         ( cfg_we        ),
    .cfg_data       ( prog_data[7:0]),

    // EEPROM
    .sclk           ( sclk          ),
    .sdi            ( sdi           ),
    .sdo            ( sdo           ),
    .scs            ( scs           ),

    // Extra inputs read through the C-Board
    .cab_1p   ( cab_1p  ),
    .coin     ( coin    ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .joystick3      ( joystick3     ),
    .joystick4      ( joystick4     ),

    // Video RAM interface
    .vram_dma_addr  ( vram_dma_addr ),
    .vram_dma_data  ( vram_dma_data ),
    .vram_dma_ok    ( vram_dma_ok   ),
    .vram_dma_cs    ( vram_dma_cs   ),
    .vram_dma_clr   ( vram_clr      ),
    .vram_rfsh_en   ( vram_rfsh_en  ),

    // GFX ROM interface
    .rom1_addr      ( rom1_addr     ),
    .rom1_half      ( rom1_half     ),
    .rom1_data      ( rom1_data     ),
    .rom1_cs        ( rom1_cs       ),
    .rom1_ok        ( rom1_ok       ),
    .rom0_addr      ( rom0_addr     ),
    .rom0_bank      (               ),
    .rom0_half      ( rom0_half     ),
    .rom0_data      ( rom0_data     ),
    .rom0_cs        ( rom0_cs       ),
    .rom0_ok        ( rom0_ok       ),

    .star0_addr     ( star0_addr    ),
    .star0_data     ( star0_data    ),
    .star0_ok       ( star0_ok      ),
    .star0_cs       ( star0_cs      ),

    .star1_addr     ( star1_addr    ),
    .star1_data     ( star1_data    ),
    .star1_ok       ( star1_ok      ),
    .star1_cs       ( star1_cs      ),
    .debug_bus      ( debug_bus     )
);

`ifndef NOSOUND
`ifdef FAKE_LATCH
integer snd_frame_cnt=0;
reg [7:0] fake_latch0 = 8'h0, fake_latch1 = 8'h0;
assign snd_latch1 = fake_latch1;
assign snd_latch0 = fake_latch0;
localparam FAKE0=20;
localparam FAKE1=1000;
always @(negedge LVBL) begin
    snd_frame_cnt <= snd_frame_cnt+1;
    case( snd_frame_cnt )
        /* ffight
        FAKE0: fake_latch <= 8'hf0;
        FAKE0+5+2: fake_latch <= 8'hf7;
        FAKE0+5+4: fake_latch <= 8'hf2;
        FAKE0+5+6: fake_latch <= 8'h55;
        default: fake_latch <= 8'hff;
        */
        // Nemo
        //FAKE0: fake_latch <= 8'h2;
        //FAKE0+1: fake_latch <= 8'h2;
        //FAKE0+2: fake_latch <= 8'h0;
        // KOD
        FAKE0: fake_latch0 <= 8'h6;
        // Magic Sword
        //FAKE0: fake_latch <= 8'h1e;
        //FAKE1: fake_latch <= 8'h0;
        //FAKE1+1: fake_latch <= 8'h4;
        //FAKE1+2: fake_latch <= 8'h0;
        // SF2, Chun Li
        // FAKE0: begin
        //     fake_latch1 <= 8'h00;
        //     fake_latch0 <= 8'hf0;
        // end

        // FAKE0+10: begin
        //     fake_latch1 <= 8'h00;
        //     fake_latch0 <= 8'hff;
        // end
        // FAKE0+11: begin
        //     fake_latch1 <= 8'h00;
        //     fake_latch0 <= 8'hf7;
        // end
        // FAKE0+12: begin
        //     fake_latch1 <= 8'h00;
        //     fake_latch0 <= 8'hff;
        // end
        // FAKE0+13: begin
        //     fake_latch1 <= 8'h00;
        //     fake_latch0 <= 8'h06;
        // end
        // FAKE0+14: begin
        //     fake_latch1 <= 8'h00;
        //     fake_latch0 <= 8'hff;
        // end

        //default: fake_latch <= 8'hff;
    endcase
end
`endif

reg [3:0] rst_snd;
always @(posedge clk) begin
    rst_snd <= { rst_snd[2:0], rst_game };
end
/* verilator tracing_off */
jtcps1_sound u_sound(
    .rst            ( rst_snd[3]    ),
    .clk            ( clk48         ),

    .filter_old     ( filter_old    ),
    .dip_fxlevel    ( dip_fxlevel   ),
    // Interface with main CPU
    .snd_latch0     ( snd_latch0    ),
    .snd_latch1     ( snd_latch1    ),

    // ROM
    .rom_addr       ( snd_addr      ),
    .rom_cs         ( snd_cs        ),
    .rom_data       ( snd_data      ),
    .rom_ok         ( snd_ok        ),

    // ADPCM ROM
    .adpcm_addr     ( adpcm_addr    ),
    .adpcm_cs       ( adpcm_cs      ),
    .adpcm_data     ( adpcm_data    ),
    .adpcm_ok       ( adpcm_ok      ),

    // Sound output
    .left           ( snd_left      ),
    .right          ( snd_right     ),
    .sample         ( sample        ),
    .peak           (               ),
    .debug_bus      ( debug_bus     )
);
`else
assign snd_addr   = 0;
assign snd_cs     = 0;
assign snd_left   = 0;
assign snd_right  = 0;
assign adpcm_addr = 0;
assign adpcm_cs   = 0;
assign sample     = 0;
`endif

reg rst_sdram;
always @(posedge clk) rst_sdram <= rst;

wire nc0, nc1, nc2, nc3;

endmodule
