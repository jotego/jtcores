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

    Author: Andrea Bogazzi. email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 18-9-2026
*/

// System FL top. i960 main CPU + video. C75/C352 still stubbed
// define NOMAIN for video-only simulations (scene replays)
module jtsysfl_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [15:1] tmap_addr;
wire [16:1] rozmap_addr, objtab_addr;
wire [15:0] objtab_din;
wire [ 1:0] objtab_we;
wire [12:0] rgb_addr;
wire [ 8:0] hdump, vdump, vrender;
wire [ 7:0] st_video, ioctl_video, ioctl_misc;
wire        raster_irqn, flip;
wire [ 1:0] sprbank;

// main CPU <-> video
wire        scfg_cs, rozcfg_cs, cpu_rnw, pal_cs, misc_cs;
wire [ 5:1] cfg_addr;
wire [ 1:0] vdsn, misc_a;
wire [15:0] vcpu_dout, scfg_dout, rozcfg_dout;
wire [14:0] pal_amux;
wire [ 7:0] pal_din8, pal_dout8, misc_din;
wire        cpu_halted;

assign flip       = dip_flip;

assign debug_view = st_video;
assign game_led   = 0;
assign vram_addr  = tmap_addr;
assign rozram_addr= rozmap_addr;
assign oram_addr  = objtab_addr;
assign oram_din   = objtab_din;
assign oram_we    = objtab_we;
assign rpal_addr  = rgb_addr;
assign gpal_addr  = rgb_addr;
assign bpal_addr  = rgb_addr;
assign pal_wdin   = pal_din8;

// MMR sections dumped after the BRAMs; 0x56000 is 128B-aligned
assign ioctl_din = &ioctl_addr[6:4] ? ioctl_misc : ioctl_video;


`ifndef NOMAIN
jtsysfl_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cpu_cen    ( cpu_cen       ),
    .lvbl       ( LVBL          ),
    .hs         ( HS            ),
    .raster_irqn( raster_irqn   ),
    // program + data ROM
    .main_addr  ( main_addr     ),
    .main_cs    ( main_cs       ),
    .main_ok    ( main_ok       ),
    .main_data  ( main_data     ),
    // work RAM
    .wram_addr  ( wram_addr     ),
    .wram_cs    ( wram_cs       ),
    .wram_we    ( wram_we       ),
    .wram_din   ( wram_din      ),
    .wram_dsn   ( wram_dsn      ),
    .wram_ok    ( wram_ok       ),
    .wram_data  ( wram_data     ),
    .wram32_addr( wram32_addr   ),
    .wram32_cs  ( wram32_cs     ),
    .wram32_ok  ( wram32_ok     ),
    .wram32_data( wram32_data   ),
    // BRAMs
    .cvram_addr ( cvram_addr    ),
    .cvram_din  ( cvram_din     ),
    .cvram_we   ( cvram_we      ),
    .cvram_dout ( cvram_dout    ),
    .crozram_addr( crozram_addr ),
    .crozram_din( crozram_din   ),
    .crozram_we ( crozram_we    ),
    .crozram_dout( crozram_dout ),
    .coram_addr ( coram_addr    ),
    .coram_din  ( coram_din     ),
    .coram_we   ( coram_we      ),
    .coram_dout ( coram_dout    ),
    .share_addr ( share_addr    ),
    .share_din  ( share_din     ),
    .share_we   ( share_we      ),
    .share_dout ( share_dout    ),
    .backup_addr ( backup_addr    ),
    .backup_din  ( backup_din     ),
    .backup_we   ( backup_we      ),
    .backup_dout ( backup_dout    ),
    // video registers
    .scfg_cs    ( scfg_cs       ),
    .rozcfg_cs  ( rozcfg_cs     ),
    .cfg_addr   ( cfg_addr      ),
    .cpu_rnw    ( cpu_rnw       ),
    .vdsn       ( vdsn          ),
    .vcpu_dout  ( vcpu_dout     ),
    .scfg_dout  ( scfg_dout     ),
    .rozcfg_dout( rozcfg_dout   ),
    .pal_cs     ( pal_cs        ),
    .pal_amux   ( pal_amux      ),
    .pal_din    ( pal_din8      ),
    .pal_dout   ( pal_dout8     ),
    // sprite bank
    .misc_cs    ( misc_cs       ),
    .misc_addr  ( misc_a        ),
    .misc_din   ( misc_din      ),
    .halted     ( cpu_halted    )
);

wire flr;

// download remap: weave the raw ROZ (0x300000/0x500000) and scroll
// (0x1600000/0x1A00000) texel+mask streams into their 8-byte unit regions
// (masks stream twice), and move the C75 data rom into the bank0 gap.
// Fillers park at a byte in the gap tail. See doc/roz-mask-interleave.md.
// ioctl_addr comes in header-stripped; jtframe_dwnld strips pre_addr again, +8
wire [25:0] dl_i = ioctl_addr - 26'h30_0000;
wire [25:0] dl_s = ioctl_addr - 26'h160_0000;
always @* begin
    pre_addr = ioctl_addr;
    if( !header ) begin
        pre_addr = ioctl_addr + 26'd8;
        if( ioctl_addr>=26'h30_0000 && ioctl_addr<26'h80_0000 ) begin
            if( ioctl_addr < 26'h50_0000 )      // texels: one zero bit at [2]
                pre_addr = 26'h40_0008 + { dl_i[20:2], 1'b0, dl_i[1:0] };
            else if( ioctl_addr < 26'h60_0000 ) // masks: bytes 4/5 of the unit pair
                pre_addr = 26'h40_0008 + { dl_i[17:0], dl_i[19], 2'b10, dl_i[18] };
            else                                // FF filler: park it in the gap
                pre_addr = 26'h3F_FFF8;
        end
        if( ioctl_addr>=26'h140_0000 && ioctl_addr<26'h148_0000 ) // C75 data
            pre_addr = 26'h30_0008 + { 7'd0, ioctl_addr[18:0] };
        if( ioctl_addr>=26'h148_4000 && ioctl_addr<26'h160_0000 ) // FF filler
            pre_addr = 26'h3F_FFF8;
        if( ioctl_addr>=26'h160_0000 ) begin
            if( ioctl_addr < 26'h1A0_0000 )     // scroll texels
                pre_addr = 26'h160_0008 + { 2'd0, dl_s[21:2], 1'b0, dl_s[1:0] };
            else if( ioctl_addr < 26'h1B0_0000 ) // scroll row masks, unit pair
                pre_addr = 26'h160_0008 + { 2'd0, dl_s[18:0], dl_s[19], 3'b100 };
        end
    end
end

// game id from the MRA header, byte 0
jtsysfl_header u_header(
    .clk        ( clk           ),
    .header     ( header        ),
    .prog_we    ( prog_we       ),
    .flr        ( flr           ),
    .prog_addr  ( prog_addr[2:0]),
    .prog_data  ( prog_data     )
);

`ifdef C75_STUB
// TEMPORARY C75 stub, kept for A/B debugging, see jtsysfl_main.v
jtsysfl_c75stub u_c75stub(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .lvbl       ( LVBL          ),
    .mcu_addr   ( mcu_addr      ),
    .mcu_din    ( mcu_din       ),
    .mcu_we     ( mcu_we        )
);
assign c75bios_addr = 0;
assign mcurom_addr  = 0;
assign mcurom_cs    = 0;
assign pcm_addr     = 0;
assign pcm_cs       = 0;
assign snd_left     = 0;
assign snd_right    = 0;
assign sample       = 0;
`else
// real C75 (M37702 + BIOS) + C352
jtsysfl_c75 u_c75(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .xin_cen    ( xin_cen       ),
    .c352_cen   ( c352_cen      ),
    .lvbl       ( LVBL          ),
    // MISC[7:4] = {SERVICE1, TEST, COIN1, COIN2}, active low
    .cab_misc   ( {service, dip_test, coin[0], coin[1]} ),
    .joystick   ( joystick1[7:0]),
    .joyana_l   ( joyana_l1     ),
    .joyana_r   ( joyana_r1     ),
    .ctrl_type  ( status[22:20] ),
    .start      ( cab_1p[0]     ),
    .flr        ( flr           ),
    .mcu_addr   ( mcu_addr      ),
    .mcu_din    ( mcu_din       ),
    .mcu_we     ( mcu_we        ),
    .mcu_dout   ( mcu_dout      ),
    .bios_addr  ( c75bios_addr  ),
    .bios_data  ( c75bios_data  ),
    .mcurom_addr( mcurom_addr   ),
    .mcurom_cs  ( mcurom_cs     ),
    .mcurom_data( mcurom_data   ),
    .mcurom_ok  ( mcurom_ok     ),
    .pcm_addr   ( pcm_addr      ),
    .pcm_cs     ( pcm_cs        ),
    .pcm_data   ( pcm_data      ),
    .pcm_ok     ( pcm_ok        ),
    .snd_l      ( snd_left      ),
    .snd_r      ( snd_right     ),
    .sample     ( sample        ),
    .debug_bus  ( debug_bus     )
);
`endif
`else
assign main_addr  = 0;
assign main_cs    = 0;
assign wram_addr  = 0;
assign wram_cs    = 0;
assign wram_we    = 0;
assign wram_din   = 0;
assign wram_dsn   = 3;
assign wram32_addr= 0;
assign wram32_cs  = 0;
assign cvram_addr = 0;
assign cvram_din  = 0;
assign cvram_we   = 0;
assign crozram_addr = 0;
assign crozram_din  = 0;
assign crozram_we   = 0;
assign coram_addr = 0;
assign coram_din  = 0;
assign coram_we   = 0;
assign share_addr = 0;
assign share_din  = 0;
assign share_we   = 0;
assign mcu_addr   = 0;
assign mcu_din    = 0;
assign mcu_we     = 0;
assign c75bios_addr = 0;
assign mcurom_addr  = 0;
assign mcurom_cs    = 0;
assign pcm_addr     = 0;
assign pcm_cs       = 0;
assign snd_left     = 0;
assign snd_right    = 0;
assign sample       = 0;
assign scfg_cs    = 0;
assign rozcfg_cs  = 0;
assign cfg_addr   = 0;
assign cpu_rnw    = 1;
assign vdsn       = 3;
assign vcpu_dout  = 0;
assign pal_cs     = 0;
assign pal_amux   = 0;
assign pal_din8   = 0;
assign misc_cs    = 0;
assign misc_a     = 0;
assign misc_din   = 0;
assign cpu_halted = 0;
`endif

jtsysfl_misc_mmr #(.SEEK('h70)) u_misc(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cs         ( misc_cs       ),
    .addr       ( misc_a        ),
    .rnw        ( 1'b0          ), // write-only from the CPU
    .din        ( misc_din      ),
    .dout       (               ),
    .sprbank    ( sprbank       ),
    .ioctl_addr ( ioctl_addr[1:0] ),
    .ioctl_din  ( ioctl_misc    ),
    .debug_bus  ( debug_bus     ),
    .st_dout    (               )
);

jtsysfl_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .ioctl_ram  ( ioctl_ram     ),

    .lhbl       ( LHBL          ),
    .lvbl       ( LVBL          ),
    .hs         ( HS            ),
    .vs         ( VS            ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .raster_irqn( raster_irqn   ),
    .flip       ( flip          ),
    .sprbank    ( sprbank       ),

    .scfg_cs    ( scfg_cs       ),
    .rozcfg_cs  ( rozcfg_cs     ),
    .cfg_addr   ( cfg_addr      ),
    .cpu_rnw    ( cpu_rnw       ),
    .dsn        ( vdsn          ),
    .cpu_dout   ( vcpu_dout     ),
    .scfg_dout  ( scfg_dout     ),
    .rozcfg_dout( rozcfg_dout   ),
    .pal_cs     ( pal_cs        ),
    .pal_amux   ( pal_amux      ),
    .pal_din    ( pal_din8      ),
    .pal_dout   ( pal_dout8     ),

    .tmap_addr  ( tmap_addr     ),
    .tmap_data  ( vram_dout     ),
    .rozmap_addr( rozmap_addr   ),
    .rozmap_data( rozram_dout   ),
    .objtab_addr( objtab_addr   ),
    .objtab_din ( objtab_din    ),
    .objtab_we  ( objtab_we     ),
    .objtab_data( oram_dout     ),
    .rgb_addr   ( rgb_addr      ),
    .pal_addr   ( pal_waddr     ),
    .rpal_we    ( rpal_we       ),
    .gpal_we    ( gpal_we       ),
    .bpal_we    ( bpal_we       ),
    .red_dout   ( rpal_dout     ),
    .rpal_dout  ( rpal_cdout    ),
    .green_dout ( gpal_dout     ),
    .gpal_dout  ( gpal_cdout    ),
    .blue_dout  ( bpal_dout     ),
    .bpal_dout  ( bpal_cdout    ),

    .scr_cs     ( scr_cs        ),
    .scr_addr   ( scr_addr      ),
    .scr_ok     ( scr_ok        ),
    .scr_data   ( scr_data      ),
    .roz_cs     ( roz_cs        ),
    .roz_addr   ( roz_addr      ),
    .roz_ok     ( roz_ok        ),
    .roz_data   ( roz_data      ),
    .objrom_cs  ( objrom_cs     ),
    .objrom_addr( objrom_addr   ),
    .objrom_ok  ( objrom_ok     ),
    .objrom_data( objrom_data   ),

    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),

    .ioctl_addr ( ioctl_addr[6:0] ),
    .ioctl_din  ( ioctl_video   ),
    .gfx_en     ( gfx_en        ),
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_video      )
);


`ifdef SYSFL_OBJDBG
// per-line C355 render-time audit over the whole sim: line cycle histogram,
// cuts (line not finished when the next starts) and the worst line
integer ob_cyc=0, ob_max=0, ob_cut=0, ob_lines=0, ob_over=0, ob_maxf=0, ob_frame=0;
reg obhs_l=0, obvs_l=0;
always @(posedge clk) begin
    obvs_l <= VS;
    if( VS && !obvs_l ) ob_frame <= ob_frame+1;
    if( u_video.u_obj.u_scan.st != 0 ) ob_cyc <= ob_cyc+1;
    obhs_l <= u_video.u_obj.ln_hs;
    if( u_video.u_obj.ln_hs && !obhs_l ) begin
        ob_lines <= ob_lines+1;
        if( u_video.u_obj.u_scan.st != 0 ) begin
            ob_cut <= ob_cut+1;
            $display("OBJCUT f=%0d line=%0d busy=%0d", ob_frame, u_video.u_obj.ln_v, ob_cyc);
        end
        if( ob_cyc > ob_max ) begin ob_max <= ob_cyc; ob_maxf <= ob_frame; end
        if( ob_cyc > 3072 ) ob_over <= ob_over+1;   // one 48MHz line time
        ob_cyc <= 0;
    end
    if( VS && !obvs_l && ob_frame % 500 == 0 )
        $display("OBJAUD f=%0d lines=%0d cut=%0d over1line=%0d max=%0d (f=%0d)",
            ob_frame, ob_lines, ob_cut, ob_over, ob_max, ob_maxf);
end
// state/stall breakdown per frame in the rock-section window
// st: 1 LIST 15 TILR 16 DPIX 17 DSKP 18 CNXT 19 ENXT 20 ROWW 21 COLW
integer w_st[0:21], w_romw=0, w_div=0, w_hits=0, w_hmax=0, wi;
// objrom cache audit: requests, 1-cycle hits, reuse of the last 4 lines
integer w_req=0, w_hit=0, w_reuse=0;
reg [19:0] w_lines[0:3];   // 64-bit line ids = objrom_addr[22:3]
reg [22:2] w_lastaddr=0;
reg w_cs_l=0, w_newreq=0;
reg wvs_l=0, whs2_l=0;
initial for( wi=0; wi<22; wi=wi+1 ) w_st[wi]=0;
always @(posedge clk) begin
    wvs_l <= VS;
    if( ob_frame>=2450 && ob_frame<=2700 ) begin
        if( u_video.u_obj.u_scan.st!=0 ) w_st[u_video.u_obj.u_scan.st] <= w_st[u_video.u_obj.u_scan.st]+1;
        if( objrom_cs && !objrom_ok ) w_romw <= w_romw+1;
        w_cs_l <= objrom_cs;
        if( ob_frame>=2555 && ob_frame<=2557 && objrom_cs && (!w_cs_l || objrom_addr!=w_lastaddr) )
            $display("OTRC %0d %h", ob_frame, {objrom_addr,2'b00});
        // new request = cs rising or address change while cs
        if( objrom_cs && (!w_cs_l || objrom_addr!=w_lastaddr) ) begin
            w_req      <= w_req+1;
            w_newreq   <= 1;
            w_lastaddr <= objrom_addr;
            if( objrom_addr[22:3]==w_lines[0] || objrom_addr[22:3]==w_lines[1] ||
                objrom_addr[22:3]==w_lines[2] || objrom_addr[22:3]==w_lines[3] )
                w_reuse <= w_reuse+1;
            w_lines[3] <= w_lines[2]; w_lines[2] <= w_lines[1];
            w_lines[1] <= w_lines[0]; w_lines[0] <= objrom_addr[22:3];
        end else if( w_newreq ) begin
            w_newreq <= 0;
            if( objrom_ok ) w_hit <= w_hit+1;   // served the cycle after the request
        end
        if( u_video.u_obj.u_scan.div_working ) w_div <= w_div+1;
        whs2_l <= u_video.u_obj.ln_hs;
        if( u_video.u_obj.ln_hs && !whs2_l ) begin
            w_hits <= w_hits + u_video.u_obj.u_scan.hitcnt;
            if( u_video.u_obj.u_scan.hitcnt > w_hmax ) w_hmax <= u_video.u_obj.u_scan.hitcnt;
        end
        if( VS && !wvs_l ) begin
            $display("OBJC f=%0d req=%0d hit=%0d reuse4=%0d", ob_frame, w_req, w_hit, w_reuse);
            w_req<=0; w_hit<=0; w_reuse<=0;
            $display("OBJW f=%0d romw=%0d div=%0d hits=%0d hmax=%0d LIST=%0d ATR=%0d ROWS=%0d COLS=%0d TILR=%0d DPIX=%0d DSKP=%0d NXT=%0d",
                ob_frame, w_romw, w_div, w_hits, w_hmax,
                w_st[1], w_st[2]+w_st[3]+w_st[4]+w_st[5]+w_st[6]+w_st[11]+w_st[12]+w_st[13],
                w_st[7]+w_st[8]+w_st[9]+w_st[10]+w_st[20],
                w_st[14]+w_st[21], w_st[15], w_st[16], w_st[17], w_st[18]+w_st[19]);
            w_romw<=0; w_div<=0; w_hits<=0; w_hmax<=0;
            for( wi=0; wi<22; wi=wi+1 ) w_st[wi]<=0;
        end
    end
end
`endif




`ifdef SYSFL_OBJDBG
// objrom request->ack latency histogram on the fixed scene (deterministic)
integer og=0, oreq=0, owcyc=0, ob_lat[0:7], obi;
reg ocs_l=0; reg [22:2] oaddr_l=0;
initial for(obi=0;obi<8;obi=obi+1) ob_lat[obi]=0;
reg olvbl=0;
always @(posedge clk) begin
    olvbl <= LVBL;
    if( objrom_cs ) begin
        if( !ocs_l || objrom_addr!=oaddr_l ) begin // new request
            oreq <= oreq+1; og <= 0;               // start timing
            owcyc <= owcyc+og;
            if( og>0 ) begin // classify the just-finished one
                ob_lat[ og<4?0 : og<8?1 : og<12?2 : og<20?3 : og<32?4 : og<48?5 : og<64?6:7 ]
                    <= ob_lat[ og<4?0 : og<8?1 : og<12?2 : og<20?3 : og<32?4 : og<48?5 : og<64?6:7 ]+1;
            end
        end else if( !objrom_ok ) og <= og+1;      // waiting
        ocs_l   <= 1;
        oaddr_l <= objrom_addr;
    end else ocs_l <= 0;
    if( LVBL && !olvbl )
        $display("OLAT req=%0d owcyc=%0d buckets[<4 <8 <12 <20 <32 <48 <64 64+]= %0d %0d %0d %0d %0d %0d %0d %0d",
            oreq, owcyc, ob_lat[0],ob_lat[1],ob_lat[2],ob_lat[3],ob_lat[4],ob_lat[5],ob_lat[6],ob_lat[7]);
end
// roz slot: request vs waited-request tally (cache hit-rate proxy)
integer rreq=0, rwait=0, rwcyc=0;
reg rcs_l=0; reg [21:3] raddr_l=0; reg rwaited=0;
always @(posedge clk) begin
    if( roz_cs ) begin
        if( !rcs_l || roz_addr!=raddr_l ) begin
            rreq <= rreq+1;
            if( rwaited ) rwait <= rwait+1;
            rwaited <= 0;
        end else if( !roz_ok ) begin
            rwcyc <= rwcyc+1; rwaited <= 1;
        end
        rcs_l <= 1; raddr_l <= roz_addr;
    end else rcs_l <= 0;
    if( LVBL && !olvbl )
        $display("RLAT req=%0d waited=%0d wcyc=%0d", rreq, rwait, rwcyc);
end
`endif

`ifdef SYSFL_PACE
// game-logic rate: at full speed the game rebuilds the sprite tables every
// frame; the active-frame ratio reads the effective logic fps
integer pc_f=0, pc_act=0, pc_wr=0;
reg pc_lvbl=1;
always @(posedge clk) begin
    pc_lvbl <= LVBL;
    if( coram_we!=0 && coram_addr<16'h1400 ) pc_wr = pc_wr+1;
    if( pc_lvbl && !LVBL ) begin
        if( pc_wr>0 ) pc_act = pc_act+1;
        pc_wr = 0;
        pc_f  = pc_f+1;
        if( pc_f%64==0 )
            $display("PACE f=%0d act=%0d/64", pc_f, pc_act) ;
        if( pc_f%64==0 ) pc_act = 0;
    end
end
`endif

endmodule
