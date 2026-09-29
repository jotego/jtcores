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

// System FL video chain: 123/145 tilemaps + C169 ROZ + C355 sprites -> C116/156 mixer
// Sprites render into the jtframe_lfbuf line frame buffer and come back as ln_pxl
module jtsysfl_video(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             ioctl_ram,

    output            lhbl, lvbl, hs, vs,
    output     [ 8:0] hdump, vdump, vrender,
    output            raster_irqn,
    input             flip,
    input      [ 1:0] sprbank,

    // CPU access, 16-bit for scroll/roz registers
    input             scfg_cs, rozcfg_cs,
    input      [ 5:1] cfg_addr,
    input             cpu_rnw,
    input      [ 1:0] dsn,
    input      [15:0] cpu_dout,
    output     [15:0] scfg_dout, rozcfg_dout,
    // CPU access, 8-bit for palette
    input             pal_cs,
    input      [14:0] pal_amux,
    input      [ 7:0] pal_din,
    output     [ 7:0] pal_dout,

    // Tile map RAM (BRAM)
    output     [15:1] tmap_addr,
    input      [15:0] tmap_data,
    // ROZ map RAM (BRAM)
    output     [16:1] rozmap_addr,
    input      [15:0] rozmap_data,
    // Sprite table RAM (BRAM)
    output     [16:1] objtab_addr,
    output     [15:0] objtab_din,
    output     [ 1:0] objtab_we,
    input      [15:0] objtab_data,
    // Palette RAMs (BRAM)
    output     [12:0] rgb_addr, pal_addr,
    output            rpal_we, gpal_we, bpal_we,
    input      [ 7:0] red_dout,   rpal_dout,
                      green_dout, gpal_dout,
                      blue_dout,  bpal_dout,

    // SDRAM
    output            smask_cs,
    output     [18:0] smask_addr,
    input             smask_ok,
    input      [ 7:0] smask_data,

    output            scr_cs,
    output     [21:0] scr_addr,
    input             scr_ok,
    input      [ 7:0] scr_data,

    output            rmask_cs,
    output     [18:0] rmask_addr,
    input             rmask_ok,
    input      [ 7:0] rmask_data,
    output     [13:0] opq_addr,
    input             opq_bit,
    output     [13:0] opq2_addr,
    input             opq2_bit,

    output     [15:0] sopq_addr,
    input             sopq_bit,
    output            roz_cs,
    output     [20:2] roz_addr,
    input             roz_ok,
    input      [31:0] roz_data,
    output            rozb_cs,
    output     [20:2] rozb_addr,
    input             rozb_ok,
    input      [31:0] rozb_data,

    output            objrom_cs,
    output     [22:2] objrom_addr,
    input             objrom_ok,
    input      [31:0] objrom_data,

    output     [ 7:0] red, green, blue,

    // IOCTL dump
    input      [ 6:0] ioctl_addr,
    output     [ 7:0] ioctl_din,
    // Debug
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

wire [ 8:0] vrender1;
wire [11:0] scr_pxl, roz_pxl, obj_pxl;
wire        sum_vld, sum_full;
wire [ 8:0] sum_x0, sum_x1;
wire [ 3:0] sum_prio;
wire [ 2:0] scr_prio;
wire [ 3:0] roz_prio, obj_prio;
wire        scr_blankn, roz_blankn, obj_blankn, obj_shd;

// sprite layer, read back from the line frame buffer
assign obj_pxl    = ln_pxl[11:0];
assign obj_prio   = ln_pxl[15:12];
assign obj_shd    = obj_pxl == 12'hffe;
assign obj_blankn = obj_pxl[7:0] != 8'hff;
wire [ 7:0] st_scr, st_roz, st_obj, st_pal;
wire [ 7:0] scr_ioctl, roz_ioctl, pal_ioctl;

always @* case( debug_bus[7:6] )
    0: st_dout = debug_bus[5] ? dbg_sskip : st_scr;
    1: st_dout = debug_bus[5] ? (debug_bus[4] ? dbg_oc : dbg_cov) : st_roz;
    2: st_dout = st_obj;
    3: st_dout = st_pal;
endcase

assign ioctl_din = !ioctl_addr[6] ? scr_ioctl :
                    ioctl_addr[5] ? pal_ioctl : roz_ioctl;

// pause-readable per-frame occlusion activity, latched at vs
wire [15:0] cnt_cov, cnt_oc, cnt_ss;
reg  [ 7:0] dbg_cov, dbg_oc, dbg_sskip;
reg         dvs_l;
always @(posedge clk) begin
    dvs_l <= vs;
    if( vs && !dvs_l ) begin
        dbg_cov   <= cnt_cov[13:6]; // roz px skipped under winning scr, /64
        dbg_oc    <= cnt_oc[11:4];  // roz px skipped under sprites, /16
        dbg_sskip <= cnt_ss[10:3];  // scr layer-lines dropped under the road, /8
    end
end

jtsysfl_vtimer u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   ( vrender1  ),
    .hdump      ( hdump     ),
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .vs         ( vs        )
);

wire [ 4:0] cov_row;
wire [ 8:0] oc_x, oc_l;
wire [ 4:0] oc_q;
reg  [ 8:0] oc_line;
reg         oc_vld;
wire [215:0] cov_word;
wire [17:0] cov_prio;
wire        cov_ok;

jtc123 u_scr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .vs         ( vs        ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .flip       ( flip      ),

    .cs         ( scfg_cs   ),
    .addr       ( cfg_addr  ),
    .rnw        ( cpu_rnw   ),
    .dsn        ( dsn       ),
    .din        ( cpu_dout  ),
    .dout       ( scfg_dout ),

    .sum_vld    ( sum_vld   ),
    .sum_full   ( sum_full  ),
    .sum_x0     ( sum_x0    ),
    .sum_x1     ( sum_x1    ),
    .sum_prio   ( sum_prio  ),
    .sopq_addr  ( sopq_addr ),
    .sopq_bit   ( sopq_bit  ),
    .cov_row    ( cov_row   ),
    .cov_word   ( cov_word  ),
    .cov_prio   ( cov_prio  ),
    .cov_ok     ( cov_ok    ),
    .cnt_ss     ( cnt_ss    ),
    .tmap_addr  ( tmap_addr ),
    .tmap_data  ( tmap_data ),
    .smask_cs   ( smask_cs  ),
    .smask_addr ( smask_addr),
    .smask_ok   ( smask_ok  ),
    .smask_data ( smask_data),
    .scr_cs     ( scr_cs    ),
    .scr_addr   ( scr_addr  ),
    .scr_ok     ( scr_ok    ),
    .scr_data   ( scr_data  ),

    .scr_pxl    ( scr_pxl   ),
    .scr_prio   ( scr_prio  ),
    .scr_blankn ( scr_blankn),

    .ioctl_addr (ioctl_addr[5:0]),
    .ioctl_din  ( scr_ioctl ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_scr    )
);

jtc169 #(.V0(9'h121)) u_roz(
    .oc_x       ( oc_x      ),
    .oc_l       ( oc_l      ),
    .oc_q       ( oc_q      ),
    .cnt_cov    ( cnt_cov   ),
    .cnt_oc     ( cnt_oc    ),
    .oc_line    ( oc_line   ),
    .oc_vld     ( oc_vld    ),
    .oc_wl      ( c_v[1:0]  ),
    .cov_row    ( cov_row   ),
    .cov_word   ( cov_word  ),
    .cov_prio   ( cov_prio  ),
    .cov_ok     ( cov_ok    ),
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .vs         ( vs        ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),

    .cs         ( rozcfg_cs ),
    .addr       (cfg_addr[4:1]),
    .rnw        ( cpu_rnw   ),
    .dsn        ( dsn       ),
    .din        ( cpu_dout  ),
    .dout       (rozcfg_dout),

    .rozmap_addr(rozmap_addr),
    .rozmap_data(rozmap_data),
    .rmask_cs   ( rmask_cs  ),
    .rmask_addr ( rmask_addr),
    .rmask_ok   ( rmask_ok  ),
    .rmask_data ( rmask_data),
    .opq_addr   ( opq_addr  ),
    .opq_bit    ( opq_bit   ),
    .opq2_addr  ( opq2_addr ),
    .opq2_bit   ( opq2_bit  ),
    .sum_vld    ( sum_vld   ),
    .sum_full   ( sum_full  ),
    .sum_x0     ( sum_x0    ),
    .sum_x1     ( sum_x1    ),
    .sum_prio   ( sum_prio  ),
    .roz_cs     ( roz_cs    ),
    .roz_addr   ( roz_addr  ),
    .roz_ok     ( roz_ok    ),
    .roz_data   ( roz_data  ),
    .rozb_cs    ( rozb_cs   ),
    .rozb_addr  ( rozb_addr ),
    .rozb_ok    ( rozb_ok   ),
    .rozb_data  ( rozb_data ),

    .roz_pxl    ( roz_pxl   ),
    .roz_prio   ( roz_prio  ),
    .roz_blankn ( roz_blankn),

    .ioctl_addr (ioctl_addr[4:0]),
    .ioctl_din  ( roz_ioctl ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_roz    )
);

wire        c_we, c_done;
wire [ 8:0] c_addr;
wire [15:0] c_data, ln_pxl;
// double line buffer: draw the next row while the mixer reads the current one
wire [ 8:0] vmap = vrender >= 9'h120 ? vrender - 9'h120 : vrender - 9'd24;
reg         lhbl_l, c_hs;
reg  [ 7:0] c_v;

always @(posedge clk) begin
    lhbl_l <= lhbl;
    c_hs   <= !lhbl && lhbl_l;
    if( !lhbl && lhbl_l ) c_v <= vmap < 9'd224 ? vmap[7:0] : 8'hff;
end

jtframe_obj_buffer #(
    .DW(16), .AW(9), .ALPHAW(8), .ALPHA(16'h00ff), .BLANK(16'h00ff)
) u_lnbuf(
    .clk    ( clk       ),
    .LHBL   ( lhbl      ),
    .flip   ( 1'b0      ),
    .wr_data( c_data    ),
    .wr_addr( c_addr    ),
    .we     ( c_we      ),
    .rd_addr( hdump     ),
    .rd     ( pxl_cen   ),  // free-running: primes the read pipe before lhbl
    .rd_data( ln_pxl    )
);

// obj coverage tap for the roz drawer: four line planes; while obj draws
// line M an idle-cycle sweep clears plane M+1, so entries are always this
// line's truth and sparse writes cannot leave stale sprites behind
wire oc_opq = c_data[7:0]!=8'hff && c_data[11:0]!=12'hffe; // not blank, not shadow
reg        vs_l, occ_on;
reg  [7:0] oc_vl;
reg  [8:0] occ_a;
reg  [1:0] occ_pl;
always @(posedge clk) begin
    vs_l <= vs;
    if( vs && !vs_l ) oc_vld <= 0;
    if( c_hs ) begin
        oc_vl <= c_v;
        if( c_v != 8'hff ) begin
            occ_pl <= c_v[1:0] + 2'd1;
            occ_a  <= 0;
            occ_on <= 1;
        end
    end else if( occ_on && !c_we ) begin
        occ_a <= occ_a + 9'd1;
        if( occ_a == 9'd287 ) occ_on <= 0;
    end
    if( c_done && oc_vl != 8'hff ) begin
        oc_line <= {1'b0, oc_vl};
        oc_vld  <= 1;
    end
end

jtframe_dual_ram #(.DW(5),.AW(11)) u_octap(
    .clk0   ( clk       ),
    .data0  ( c_we ? {oc_opq, c_data[15:12]} : 5'd0 ),
    .addr0  ( c_we ? {c_v[1:0], c_addr} : {occ_pl, occ_a} ),
    .we0    ( c_we | occ_on ),
    .q0     (           ),
    .clk1   ( clk       ),
    .data1  ( 5'd0      ),
    .addr1  ( {oc_l[1:0], oc_x} ),
    .we1    ( 1'b0      ),
    .q1     ( oc_q      )
);

jtc355 #(.H0(9'h041)) u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .ioctl_ram  ( ioctl_ram ),
    .flip       ( flip      ),
    .sprbank    ( sprbank   ),

    .ln_hs      ( c_hs      ),
    .ln_v       ( c_v       ),
    .ln_addr    ( c_addr    ),
    .ln_data    ( c_data    ),
    .ln_we      ( c_we      ),
    .ln_done    ( c_done    ),

    .objtab_addr( objtab_addr),
    .objtab_din ( objtab_din ),
    .objtab_we  ( objtab_we  ),
    .objtab_data( objtab_data),
    .objrom_cs  ( objrom_cs ),
    .objrom_addr( objrom_addr),
    .objrom_ok  ( objrom_ok ),
    .objrom_data( objrom_data),

    .debug_bus  ( debug_bus ),
    .st_dout    ( st_obj    )
);

jtc116 u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .lvbl       ( lvbl      ),
    .lhbl       ( lhbl      ),
    .hs         ( hs        ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .raster_irqn( raster_irqn),

    .scr_pxl    ( scr_pxl   ),
    .scr_prio   ( scr_prio  ),
    .scr_blankn ( scr_blankn),
    .roz_pxl    ( roz_pxl   ),
    .roz_prio   ( roz_prio  ),
    .roz_blankn ( roz_blankn),
    .obj_pxl    ( obj_pxl   ),
    .obj_prio   ( obj_prio  ),
    .obj_shd    ( obj_shd   ),
    .obj_blankn ( obj_blankn),

    .cpu_addr   ( pal_amux  ),
    .cs         ( pal_cs    ),
    .cpu_rnw    ( cpu_rnw   ),
    .cpu_dout   ( pal_din   ),
    .pal_dout   ( pal_dout  ),

    .rgb_addr   ( rgb_addr  ),
    .pal_addr   ( pal_addr  ),
    .rpal_we    ( rpal_we   ),
    .gpal_we    ( gpal_we   ),
    .bpal_we    ( bpal_we   ),
    .red_dout   ( red_dout  ),
    .rpal_dout  ( rpal_dout ),
    .green_dout ( green_dout),
    .gpal_dout  ( gpal_dout ),
    .blue_dout  ( blue_dout ),
    .bpal_dout  ( bpal_dout ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),

    .ioctl_addr (ioctl_addr[3:0]),
    .ioctl_din  ( pal_ioctl ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_pal    )
);


`ifdef SYSFL_LNDUMP
// C355 line-write stream dump for old-vs-new drawer diffing
integer lnf, lnfr=0;
reg lnvs=0;
initial lnf = $fopen("lndump.txt","w");
always @(posedge clk) begin
    lnvs <= vs;
    if( vs && !lnvs ) lnfr <= lnfr+1;
    if( c_hs  ) $fdisplay(lnf,"H %0d %0d", lnfr, c_v);
    if( c_we  ) $fdisplay(lnf,"W %0d %04x", c_addr, c_data);
    if( objrom_cs && objrom_ok ) $fdisplay(lnf,"F %06x %08x", objrom_addr, objrom_data);
    if( c_done) $fdisplay(lnf,"D");
end
`endif

`ifdef SIMSCENE
// bring-up probe: per-frame layer activity counters
integer cnt_scr, cnt_roz, cnt_obj, cnt_scs, cnt_sok, cnt_rcs, cnt_ocs, cnt_msk, cnt_vis, cnt_rgb, cnt_lin, cnt_bsy, cnt_wai;
reg vsl, lndone_l;
always @(posedge clk) begin
    if( scr_blankn  ) cnt_scr <= cnt_scr+1;
    if( roz_blankn  ) cnt_roz <= cnt_roz+1;
    if( obj_blankn  ) cnt_obj <= cnt_obj+1;
    if( scr_cs      ) cnt_scs <= cnt_scs+1;
    if( scr_cs && scr_ok ) cnt_sok <= cnt_sok+1;
    if( roz_cs      ) cnt_rcs <= cnt_rcs+1;
    if( objrom_cs   ) cnt_ocs <= cnt_ocs+1;
    if( smask_cs    ) cnt_msk <= cnt_msk+1;
    lndone_l <= c_done;
    if( c_done && !lndone_l ) cnt_lin <= cnt_lin+1;
    if( !c_done ) cnt_bsy <= cnt_bsy+1;
    if( c_done ) cnt_wai <= cnt_wai+1;
    if( pxl_cen && lvbl && lhbl ) begin
        if( u_colmix.blank==0 ) cnt_vis <= cnt_vis+1;
        if( red!=0 || green!=0 || blue!=0 ) cnt_rgb <= cnt_rgb+1;
    end
    vsl <= vs;
    if( vs && !vsl ) begin
        $display("VIDEO: scr=%0d roz=%0d obj=%0d | scr_cs=%0d ok=%0d smask_cs=%0d roz_cs=%0d obj_cs=%0d | vis=%0d rgb=%0d lines=%0d bsy=%0d wai=%0d",
            cnt_scr, cnt_roz, cnt_obj, cnt_scs, cnt_sok, cnt_msk, cnt_rcs, cnt_ocs,
            cnt_vis, cnt_rgb, cnt_lin, cnt_bsy, cnt_wai);
        cnt_scr<=0; cnt_roz<=0; cnt_obj<=0; cnt_scs<=0; cnt_sok<=0; cnt_rcs<=0; cnt_ocs<=0; cnt_msk<=0;
        cnt_vis<=0; cnt_rgb<=0; cnt_lin<=0; cnt_bsy<=0; cnt_wai<=0;
    end
end
`endif

endmodule
