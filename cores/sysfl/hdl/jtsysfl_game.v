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

`ifdef JTFRAME_LF_BUFFER
// screen row (0-223, 224+ during blanking) for the line frame buffer.
// Visible rows are 0x121-0x1FF plus the counter-wrap row 0xF8
wire [ 8:0] vmap  = vrender >= 9'h121 ? vrender - 9'h121 : vrender - 9'd25;
assign game_hdump   = hdump;
assign game_vrender = vmap[7:0];
assign fb_keep      = 0;
`else
// video still compiles without the frame buffer, sprites blanked
wire        ln_hs  = 0;
wire [ 7:0] ln_v   = 0;
wire [15:0] ln_pxl = 16'h00ff;
wire [ 8:0] ln_addr;
wire [15:0] ln_data;
wire        ln_we, ln_done;
`endif
assign debug_view = st_video;
assign game_led   = 0;
assign vram_addr  = tmap_addr;
assign rozram_addr= rozmap_addr;
assign oram_addr  = objtab_addr;
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
    .nvram_addr ( nvram_addr    ),
    .nvram_din  ( nvram_din     ),
    .nvram_we   ( nvram_we      ),
    .nvram_dout ( nvram_dout    ),
    .share_addr ( share_addr    ),
    .share_din  ( share_din     ),
    .share_we   ( share_we      ),
    .share_dout ( share_dout    ),
    .comram_addr( comram_addr   ),
    .comram_din ( comram_din    ),
    .comram_we  ( comram_we     ),
    .comram_dout( comram_dout   ),
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
    .start      ( cab_1p[0]     ),
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
assign nvram_addr = 0;
assign nvram_din  = 0;
assign nvram_we   = 0;
assign share_addr = 0;
assign share_din  = 0;
assign share_we   = 0;
assign comram_addr= 0;
assign comram_din = 0;
assign comram_we  = 0;
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

    .ln_hs      ( ln_hs         ),
    .ln_v       ( ln_v          ),
    .ln_pxl     ( ln_pxl        ),
    .ln_addr    ( ln_addr       ),
    .ln_data    ( ln_data       ),
    .ln_we      ( ln_we         ),
    .ln_done    ( ln_done       ),

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

    .smask_cs   ( smask_cs      ),
    .smask_addr ( smask_addr    ),
    .smask_ok   ( smask_ok      ),
    .smask_data ( smask_data    ),
    .scr_cs     ( scr_cs        ),
    .scr_addr   ( scr_addr      ),
    .scr_ok     ( scr_ok        ),
    .scr_data   ( scr_data      ),
    .rmask_cs   ( rmask_cs      ),
    .rmask_addr ( rmask_addr    ),
    .rmask_ok   ( rmask_ok      ),
    .rmask_data ( rmask_data    ),
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

`ifdef SYSFL_VSTAT
// per-frame CPU stats: i960 cen/retired/idle loop (MAME: 0x100004e0-f4, ~98%
// of a race frame), IRQs by line, writes to the race frame counter 0x100ff050,
// C75 cycles in its idle loop (c0f1-c0f4)
integer c_frame=0, c_cen=0, c_ret=0, c_idle=0, c_wait=0, c_cnt=0, c_irq0=0, c_irq1=0, c_irq2=0, c_irq3=0, m_all=0, m_idle=0;
reg     cvs_l=0, cnt_l=0;
reg [5:0] cst_l=0;
wire    cnt_wr = wram_cs && wram_we!=0 && wram_addr==20'h7f828;
always @(posedge clk) begin
    cvs_l <= VS;
    cnt_l <= cnt_wr;
    if( cnt_wr && !cnt_l ) c_cnt <= c_cnt+1;
    m_all <= m_all+1;
    if( u_c75.u_mcu.u_cpu.pc>=16'hc0f0 && u_c75.u_mcu.u_cpu.pc<=16'hc0f5 && u_c75.u_mcu.u_cpu.pg==0 ) m_idle <= m_idle+1;
    if( cpu_cen ) begin
        cst_l <= u_main.u_cpu.st;
        c_cen <= c_cen+1;
        if( u_main.u_cpu.st==6 || u_main.u_cpu.fuse ) c_ret <= c_ret+1;
        if( u_main.u_cpu.PIP>=32'h100004e0 && u_main.u_cpu.PIP<=32'h100004f4 ) c_idle <= c_idle+1;
        if( u_main.u_cpu.bus_cs && !u_main.u_cpu.bus_ok ) c_wait <= c_wait+1;
        if( u_main.u_cpu.st==22 && cst_l!=22 ) case( u_main.u_cpu.int_line )
            0: c_irq0 <= c_irq0+1;
            1: c_irq1 <= c_irq1+1;
            2: c_irq2 <= c_irq2+1;
            3: c_irq3 <= c_irq3+1;
        endcase
    end
    if( cpu_cen && c_frame>=1100 && c_frame<1120 && c_cen[5:0]==0 )
        $display("PCS %08x %0d", u_main.u_cpu.PIP, u_main.u_cpu.st);
    if( VS && !cvs_l ) begin
        $display("CPUSTAT %0d cen=%0d ret=%0d idle=%0d wait=%0d irq=%0d/%0d/%0d/%0d fcnt_wr=%0d | c75 idle=%0d/%0d",
            c_frame, c_cen, c_ret, c_idle, c_wait, c_irq0, c_irq1, c_irq2, c_irq3, c_cnt, m_idle, m_all);
        c_frame<=c_frame+1; c_cen<=0; c_ret<=0; c_idle<=0; c_wait<=0; c_cnt<=0; c_irq0<=0; c_irq1<=0; c_irq2<=0; c_irq3<=0; m_all<=0; m_idle<=0;
    end
end
// per-access cost: cen and count of data loads/stores by target (wram/rom/bram/mmr),
// frame spill/fill/flush words, plus cen by sequencer state class
integer d_cen[0:7], d_n[0:7], f_cen=0, f_n=0, s_fhit=0, s_fmiss=0, s_xw=0, s_exe=0,
        s_md=0, s_mdn=0, s_call=0, s_calln=0, s_int=0, s_movm=0, s_oth=0, acc=0, dj;
wire [5:0] cst = u_main.u_cpu.st;
wire       inmem = cst>=6'd8 && cst<=6'd11;
wire [1:0] dcls  = u_main.is_rom32 ? 2'd1 : (u_main.is_w32 || u_main.tgt==4'd1) ? 2'd0 :
                   (u_main.tgt>=4'd2 && u_main.tgt<=4'd7) ? 2'd2 : 2'd3;
wire [2:0] dix   = {u_main.u_cpu.bus_wr, dcls};
initial for( dj=0; dj<8; dj=dj+1 ) begin d_cen[dj]=0; d_n[dj]=0; end
always @(posedge clk) begin
  if( cpu_cen ) begin
    if( inmem ) begin
        if( u_main.u_cpu.bus_cs && u_main.u_cpu.bus_ok ) begin
            if( u_main.u_cpu.seq!=0 ) begin f_cen <= f_cen+acc+1; f_n <= f_n+1; end
            else begin d_cen[dix] <= d_cen[dix]+acc+1; d_n[dix] <= d_n[dix]+1; end
            acc <= 0;
        end else acc <= acc+1;
    end else acc <= 0;
    case( cst )
    6'd4:  if( u_main.u_cpu.bus_cs ) s_fmiss <= s_fmiss+1; else s_fhit <= s_fhit+1;
    6'd5:  s_xw   <= s_xw+1;
    6'd6:  s_exe  <= s_exe+1;
    6'd7:  s_movm <= s_movm+1;
    6'd12: s_md   <= s_md+1;
    6'd13,6'd14,6'd15,6'd16,6'd17,6'd18,6'd19,6'd20,6'd21,6'd28,6'd29: s_call <= s_call+1;
    6'd22,6'd23,6'd24,6'd25,6'd26,6'd27: s_int <= s_int+1;
    6'd8,6'd9,6'd10,6'd11: ;
    default: s_oth <= s_oth+1;
    endcase
    if( u_main.u_cpu.md_start ) s_mdn <= s_mdn+1;
    if( cst==6'd13 && cst_l!=6'd13 ) s_calln <= s_calln+1;
  end
    if( VS && !cvs_l ) begin
        $display("CPUDET %0d ld wram=%0d/%0d rom=%0d/%0d bram=%0d/%0d mmr=%0d/%0d | st wram=%0d/%0d rom=%0d/%0d bram=%0d/%0d mmr=%0d/%0d | frame=%0d/%0d calls=%0d callcen=%0d | fhit=%0d fmiss=%0d xw=%0d exe=%0d movm=%0d md=%0d/%0d int=%0d oth=%0d",
            c_frame, d_cen[0], d_n[0], d_cen[1], d_n[1], d_cen[2], d_n[2], d_cen[3], d_n[3],
            d_cen[4], d_n[4], d_cen[5], d_n[5], d_cen[6], d_n[6], d_cen[7], d_n[7],
            f_cen, f_n, s_calln, s_call, s_fhit, s_fmiss, s_xw, s_exe, s_movm, s_md, s_mdn, s_int, s_oth);
        for( dj=0; dj<8; dj=dj+1 ) begin d_cen[dj]<=0; d_n[dj]<=0; end
        f_cen<=0; f_n<=0; s_fhit<=0; s_fmiss<=0; s_xw<=0; s_exe<=0; s_md<=0; s_mdn<=0;
        s_call<=0; s_calln<=0; s_int<=0; s_movm<=0; s_oth<=0;
    end
end
`endif

`ifdef SYSFL_VSTAT
// ROZ timing: i960 writes to the layer-0 scanline records (mirror = lines
// 11-37, road = 76-223) with the vdump at write time, and missed lines by area
integer r_frame=0, rw_m=0, rw_r=0, rm_m=0, rm_r=0;
reg [8:0] rw_mf, rw_ml, rw_rf, rw_rl;
reg     rvs_l=0, rhs_l=0;
wire [15:0] roff  = crozram_addr - 16'h7040;     // words from the record base
wire [ 8:0] rline = {1'b0, roff[11:7], roff[5:3]};
wire        rrec  = crozram_we!=0 && crozram_addr>=16'h7040 && roff[6]==0 && roff<16'h0e00;
always @(posedge clk) begin
    rvs_l <= VS;
    rhs_l <= HS;
    if( rrec ) begin
        if( rline>=11 && rline<=37 ) begin
            if( rw_m==0 ) rw_mf <= vdump;
            rw_ml <= vdump; rw_m <= rw_m+1;
        end else if( rline>=76 ) begin
            if( rw_r==0 ) rw_rf <= vdump;
            rw_rl <= vdump; rw_r <= rw_r+1;
        end
    end
    if( HS && !rhs_l && u_video.u_roz.fsm!=0 && !u_video.u_roz.lyr1 ) begin
        if( u_video.u_roz.lline>=11 && u_video.u_roz.lline<=37 ) rm_m <= rm_m+1;
        else rm_r <= rm_r+1;
    end
    if( VS && !rvs_l ) begin
        $display("ROZT %0d mirror_wr=%0d vd %h-%h road_wr=%0d vd %h-%h | miss mirror=%0d road=%0d",
            r_frame, rw_m, rw_mf, rw_ml, rw_r, rw_rf, rw_rl, rm_m, rm_r);
        r_frame<=r_frame+1; rw_m<=0; rw_r<=0; rm_m<=0; rm_r<=0;
    end
end
`endif

`ifdef SYSFL_VSTAT
// which layer is opaque per displayed row, mirror rows of one frame
integer ly_frame=0, ly_scr=0, ly_roz=0, ly_obj=0;
reg     lyvs_l=0, lyhs_l=0;
always @(posedge clk) begin
    lyvs_l <= VS;
    lyhs_l <= HS;
    if( pxl_cen && LHBL ) begin
        if( u_video.scr_blankn ) ly_scr <= ly_scr+1;
        if( u_video.roz_blankn ) ly_roz <= ly_roz+1;
        if( u_video.obj_blankn ) ly_obj <= ly_obj+1;
    end
    if( HS && !lyhs_l ) begin
        if( ly_frame==1508 && u_video.vdump>=9'h118 && u_video.vdump<=9'h140 )
            $display("LAYER row vdump=%h scr=%0d roz=%0d obj=%0d", u_video.vdump, ly_scr, ly_roz, ly_obj);
        ly_scr <= 0; ly_roz <= 0; ly_obj <= 0;
    end
    if( VS && !lyvs_l ) ly_frame <= ly_frame+1;
end
`endif

`ifdef SYSFL_VSTAT
// sprite pixels written per line, for a window of frames
integer sp_cnt=0, sp_frame=0;
reg     spvs_l=0;
always @(posedge clk) begin
    spvs_l <= VS;
    if( u_video.u_obj.ln_we ) sp_cnt <= sp_cnt+1;
    if( u_video.u_obj.ln_hs ) begin
        if( sp_frame>=1500 && sp_frame<=1512 )
            $display("SPRL %0d line %0d pixels %0d", sp_frame, u_video.u_obj.vlat, sp_cnt);
        sp_cnt <= 0;
    end
    if( VS && !spvs_l ) sp_frame <= sp_frame+1;
end
`endif

`ifdef SYSFL_VSTAT
// C355 time per frame by state, sprite ROM waits, sprites hit per line
integer o_frame=0, o_busy=0, o_romw=0, o_hits=0, o_hmax=0, o_div=0;
integer o_st[0:19];
integer oi;
reg     ovs_l=0, ohs_l=0;
initial for( oi=0; oi<20; oi=oi+1 ) o_st[oi]=0;
always @(posedge clk) begin
    ovs_l <= VS;
    if( u_video.u_obj.st!=0 ) begin
        o_busy <= o_busy+1;
        o_st[u_video.u_obj.st] <= o_st[u_video.u_obj.st]+1;
    end
    if( objrom_cs && !objrom_ok ) o_romw <= o_romw+1;
    if( u_video.u_obj.div_working ) o_div <= o_div+1;
    if( u_video.u_obj.ln_hs ) begin
        o_hits <= o_hits + u_video.u_obj.hitcnt;
        if( u_video.u_obj.hitcnt > o_hmax ) o_hmax <= u_video.u_obj.hitcnt;
    end
    if( VS && !ovs_l ) begin
        $display("OBJSTAT %0d busy=%0d romw=%0d div=%0d hits=%0d hmax=%0d st= %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
            o_frame, o_busy, o_romw, o_div, o_hits, o_hmax,
            o_st[0],o_st[1],o_st[2],o_st[3],o_st[4],o_st[5],o_st[6],o_st[7],o_st[8],o_st[9],
            o_st[10],o_st[11],o_st[12],o_st[13],o_st[14],o_st[15],o_st[16],o_st[17],o_st[18],o_st[19]);
        o_frame<=o_frame+1; o_busy<=0; o_romw<=0; o_hits<=0; o_hmax<=0; o_div<=0;
        for( oi=0; oi<20; oi=oi+1 ) o_st[oi]<=0;
    end
end
`endif

`ifdef SYSFL_VSTAT
// per-frame bandwidth stats: C123 lines that ran out of time and how many
// pixels were lost, sprite lines finished, bank 2 traffic
integer r_miss=0, r_miss1=0, r_lost=0, v_mainw=0, v_rozw=0;
integer vs_frame=0, v_miss=0, v_lost=0, v_maxlost=0, v_spr=0, v_mcu=0, v_mcuw=0, v_scrw=0, v_mskw=0;
reg     vs_l=0, hs_l=0, lnd_l=0, mcs_l=0;
always @(posedge clk) begin
    vs_l  <= VS;
    hs_l  <= HS;
    lnd_l <= u_video.ln_done;
    mcs_l <= mcurom_cs;
    if( HS && !hs_l && !u_video.u_scr.done ) begin
        v_miss <= v_miss+1;
        v_lost <= v_lost + (u_video.u_scr.HEND - u_video.u_scr.hcnt);
        if( u_video.u_scr.HEND - u_video.u_scr.hcnt > v_maxlost ) v_maxlost <= u_video.u_scr.HEND - u_video.u_scr.hcnt;
    end
    if( HS && !hs_l && u_video.u_roz.fsm!=0 ) begin
        if( u_video.u_roz.lyr1 ) r_miss1 <= r_miss1+1; else begin
            r_miss <= r_miss+1;
            r_lost <= r_lost + (288 - u_video.u_roz.baddr);
        end
    end
    if( main_cs && !main_ok ) v_mainw <= v_mainw+1;
    if( (roz_cs && !roz_ok) || (rmask_cs && !rmask_ok) ) v_rozw <= v_rozw+1;
    if( u_video.ln_done && !lnd_l ) v_spr <= v_spr+1;
    if( mcurom_cs && !mcs_l ) v_mcu <= v_mcu+1;
    if( mcurom_cs && !mcurom_ok ) v_mcuw <= v_mcuw+1;
    if( scr_cs && !scr_ok ) v_scrw <= v_scrw+1;
    if( smask_cs && !smask_ok ) v_mskw <= v_mskw+1;
    if( VS && !vs_l ) begin
        $display("VSTAT %0d c123_miss=%0d lost_px=%0d max_lost=%0d spr_lines=%0d mcurom_rd=%0d mcurom_wait=%0d scr_wait=%0d smask_wait=%0d | roz_miss=%0d roz_lost_px=%0d roz_miss_l1=%0d roz_wait=%0d main_wait=%0d",
            vs_frame, v_miss, v_lost, v_maxlost, v_spr, v_mcu, v_mcuw, v_scrw, v_mskw, r_miss, r_lost, r_miss1, v_rozw, v_mainw);
        r_miss<=0; r_lost<=0; r_miss1<=0; v_rozw<=0; v_mainw<=0;
        vs_frame<=vs_frame+1; v_miss<=0; v_lost<=0; v_maxlost<=0; v_spr<=0; v_mcu<=0; v_mcuw<=0; v_scrw<=0; v_mskw<=0;
    end
end
`endif
endmodule
