/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-10-2026 */

module jtnarc_main(
    input             rst,
    input             clk,
    input             rst48,
    input             clk48,
    output reg [19:1] pgm_addr,
    output reg        pgm_rd,
    input      [15:0] pgm_data,
    input             pgm_ok,
    output     [21:2] gfx_addr,
    output            gfx_rd,
    input      [31:0] gfx_data,
    input             gfx_ok,
    output     [19:4] vcpu_addr,
    output            vcpu_rd,
    output            vcpu_we,
    output    [127:0] vcpu_din,
    output     [15:0] vcpu_dsn,
    input     [127:0] vcpu_data,
    input             vcpu_ok,
    output reg        vcpu_flush,
    input             vcpu_flush_done,
    output     [19:4] vrow_addr,
    output            vrow_rd,
    input     [127:0] vrow_data,
    input             vrow_ok,
    output     [16:1] scratch_addr,
    output     [15:0] scratch_din,
    output     [ 1:0] scratch_we,
    input      [15:0] scratch_dout,
    output     [13:1] colram_addr,
    output     [15:0] colram_din,
    output     [ 1:0] colram_we,
    input      [15:0] colram_dout,
    output     [12:0] cmos_addr,
    output     [ 7:0] cmos_din,
    output            cmos_we,
    input      [ 7:0] cmos_dout,
    input      [ 8:0] joystick1,
    input      [ 8:0] joystick2,
    input      [ 3:0] coin,
    input      [ 3:0] cab_1p,
    input             dip_test,
    input             tilt,

    output reg [15:0] snd_latch,
    input      [ 7:0] tb_data,
    input             tb_ack_n,
    output reg        line_load,
    output reg [18:0] line_pstart,
    output            hs,
    output            vs,
    output            hblank,
    output            vblank,
    output     [31:0] pc
);

localparam [3:0] WORD_READ=4'd0, WORD_WRITE=4'd1, SCREEN_REFRESH=4'd2, IO_READ=4'd5, PIXEL_MTR=4'd7, PIXEL_RTM=4'd8;

wire        cyc_req, cyc_iaq, cyc_org;
wire [ 3:0] cyc_kind;
wire [31:0] cyc_addr;
wire [15:0] cyc_wdata, cyc_io_rdata, cyc_dpytap;
wire [13:0] cyc_srfaddr;
reg  [15:0] cyc_rdata, pal_latch, sysctrl;
reg  [17:0] line_start;
wire [15:0] in0, in1, in2;
reg         cyc_ack, seen, busy, wt, ram_we, flushing, t48, t48_s, dma_wr, c_grd, c_vrd, c_vwe, dpause;
reg  [21:2] c_gaddr;
reg  [18:2] c_vaddr;
reg  [31:0] c_vdin;
reg  [ 3:0] c_vdsn, dma_wsel;
wire [15:0] dma_dout;
wire [21:2] dma_saddr;
wire [18:3] dma_vaddr;
wire [63:0] dma_vdin;
wire [ 7:0] dma_vdsn;
wire        dma_busy, dma_irq, dma_paused, dma_srd, dma_vwe;
reg         cpause, cgrant;
wire        dmux = dma_busy & ~cgrant;
wire        vsr_we, vsr_busy, vsr_flush, vsr_pt, vsr_rd, ae_start, ae_rtm;
wire [19:4] vsr_waddr, vsr_raddr;
wire [127:0] vsr_din;
wire [ 8:0] a_phys, b_phys, cp_src, cp_dst;
wire        a_shared, op_ack, cp_start, vmap_rdy, vm_unsh, vm_chg;
wire [ 8:0] vm_unsh_p;
reg         op_req, op_x, op_ae, ae_pend, ae_prtm;
reg  [ 1:0] op_kind;
reg  [ 7:0] op_row, ae_prow, tr_row;
reg  [ 8:0] tr_phys;
reg         tr_sh, tr_dma;
wire [ 7:0] vw_row;
wire [10:4] vw_col;
wire [31:0] vcpu_word;
wire [ 7:0] ae_row;
reg         vsr_gnt, x_pend, x_rtm;
reg  [ 7:0] x_row;
reg  [ 2:0] stg;
reg         vpost;
reg  [31:0] addr;
reg  [ 3:0] kind;
reg  [15:0] wdata;
reg  [13:0] srf;
reg  [ 8:1] tap;
reg         org;

wire [6:0] hi       = addr[26:20];
wire       pgm_cs   = hi[6:5]==2'b11;
wire       img_cs   = hi[6:5]==2'b01 || hi[6:5]==2'b10;
wire       vram_cs  = hi[6:4]==3'b000;
wire       scr_cs   = hi==7'b0010000;
wire       cmos_cs  = hi[6:1]==6'b001010;
wire       col_cs   = hi[6:1]==6'b001100;
wire       dma_cs   = hi[6:1]==6'b001101;
wire       in_cs    = hi[6:1]==6'b001110;
wire       snd_cs   = hi==7'b0011110;
wire       sys_cs   = hi==7'b0011111;
wire       is_rd    = kind==WORD_READ;
wire       is_wr    = kind==WORD_WRITE;
wire       palmode  = ~sysctrl[5];
wire       ae_en    = ~sysctrl[4];
wire [1:0] cmos_pg  = ~sysctrl[7:6];
wire       door_open= in1[11];
wire [13:0] sa      = org ? srf : ~srf;
wire       gsp_edge = t48==t48_s;
wire       cyc_vbus = cyc_kind<=WORD_WRITE && cyc_addr[26:24]==3'd0;
wire [3:0] dma_rsel = dma_wr ? dma_wsel : addr[7:4];
wire       dma_pause= dpause | cpause;
wire       dma_ok   = vcpu_ok & ~vsr_gnt;
wire       vsr_ok   = vcpu_ok &  vsr_gnt;
wire       vsr_fdone= vsr_gnt & vcpu_flush & vcpu_flush_done;
wire       c_dmareq = cyc_req && !seen && !busy && cyc_vbus;

assign gfx_addr  = dmux ? dma_saddr : c_gaddr;
assign gfx_rd    = dmux ? dma_srd   : c_grd;
assign vw_row    = dmux ? dma_vaddr[18:11] : c_vaddr[18:11];
assign vw_col    = dmux ? dma_vaddr[10:4]  : c_vaddr[10:4];
assign vcpu_word = vcpu_data[ {c_vaddr[3:2],5'd0} +: 32 ];
wire       vw_we    = dmux ? dma_vwe : c_vwe;
wire       tr_ok    = tr_row==vw_row && tr_dma==dmux && !vm_chg;
wire       cow_need = vw_we & tr_ok & tr_sh;
wire       c_pres   = !dmux && tr_ok && ( c_vrd || (c_vwe && !tr_sh) );
wire       d_pres   = dmux && dma_vwe && tr_ok && !tr_sh;
wire       c_coww   = !dmux && c_vwe && tr_ok && tr_sh;
wire       d_coww   = dmux && dma_vwe && tr_ok && tr_sh;
wire       vblock   = (vpost && !(cyc_kind==SCREEN_REFRESH && c_coww)) || ( dmux && cyc_vbus );

assign vcpu_addr = vsr_gnt ? vsr_waddr : { tr_phys, vw_col };
assign vcpu_rd   = vsr_gnt ? 1'b0      : dmux ? 1'b0 : c_vrd & tr_ok;
assign vcpu_we   = vsr_gnt ? vsr_we    : vw_we & tr_ok & ~tr_sh;
assign vcpu_din  = vsr_gnt ? vsr_din   : dmux ? {2{dma_vdin}} : {4{c_vdin}};
assign vcpu_dsn  = vsr_gnt ? 16'd0     :
                   dmux ? ~( { 8'd0,~dma_vdsn} << {dma_vaddr[3],3'd0} ) :
                              ~( {12'd0,~c_vdsn}   << {c_vaddr[3:2],2'd0} );
assign vrow_addr = vsr_raddr;
assign vrow_rd   = vsr_rd;

assign scratch_addr = addr[19:4];
assign scratch_din  = wdata;
assign scratch_we   = {2{ram_we & scr_cs}};
assign colram_addr  = addr[16:4];
assign colram_din   = wdata;
assign colram_we    = {2{ram_we & col_cs}};
assign cmos_addr    = { cmos_pg, addr[14:4] };
assign cmos_din     = wdata[7:0];
assign cmos_we      = ram_we & cmos_cs & (door_open | ~addr[14]);

always @(posedge clk48) t48   <= rst48 ? 1'b0 : ~t48;
always @(posedge clk)   t48_s <= t48;

always @(posedge clk) begin
    tr_row  <= vw_row;
    tr_dma  <= dmux;
    tr_phys <= a_phys;
    tr_sh   <= a_shared;
end

always @(posedge clk) begin
    if( rst ) begin
        vsr_gnt    <= 0;
        x_pend     <= 0;
        x_rtm      <= 0;
        x_row      <= 0;
        op_req     <= 0;
        op_x       <= 0;
        op_ae      <= 0;
        ae_pend    <= 0;
        seen       <= 0;
        busy       <= 0;
        wt         <= 0;
        flushing   <= 0;
        ram_we     <= 0;
        cyc_ack    <= 0;
        cyc_rdata  <= 16'hffff;
        pgm_rd     <= 0;
        pgm_addr   <= 0;
        c_grd      <= 0;
        c_gaddr    <= 0;
        c_vrd      <= 0;
        c_vwe      <= 0;
        c_vaddr    <= 0;
        c_vdin     <= 0;
        c_vdsn     <= 4'hf;
        vcpu_flush <= 0;
        vpost      <= 0;
        dma_wr     <= 0;
        dma_wsel   <= 0;
        dpause     <= 0;
        stg        <= 0;
        addr       <= 0;
        kind       <= 0;
        wdata      <= 0;
        srf        <= 0;
        tap        <= 0;
        org        <= 0;
        sysctrl    <= 16'hfffc;
        snd_latch  <= 16'hfbff;
        pal_latch  <= 0;
        line_load  <= 0;
        line_start <= 0;
    end else begin
        ram_we    <= 0;
        line_load <= 0;
        dma_wr    <= 0;
        if( gsp_edge ) cyc_ack <= 0;
        if( gsp_edge && !cyc_req ) seen <= 0;
        if( gsp_edge && cyc_req && !seen && !busy && !vblock ) begin
            seen      <= 1;
            busy      <= 1;
            addr      <= cyc_addr;
            kind      <= cyc_kind;
            wdata     <= cyc_wdata;
            srf       <= cyc_srfaddr;
            tap       <= cyc_dpytap[8:1];
            org       <= cyc_org;
            stg       <= 0;
            cyc_rdata <= 16'hffff;
        end
        vsr_gnt <= vsr_busy && ( (vsr_gnt && !(flushing && vsr_pt)) ||
                   ( !flushing && !vcpu_flush && !c_pres && !d_pres ) );
        if( vsr_gnt && vsr_flush && !vcpu_flush ) vcpu_flush <= 1;
        if( vsr_gnt && vcpu_flush && vcpu_flush_done ) vcpu_flush <= 0;
        if( ae_start ) begin
            ae_pend <= 1;
            ae_prtm <= ae_rtm;
            ae_prow <= ae_row;
        end
        if( !op_req && vmap_rdy ) begin
            if( ae_pend ) begin
                op_req  <= 1;
                op_ae   <= 1;
                op_kind <= { 1'b0, ae_prtm };
                op_row  <= ae_prow;
            end else if( x_pend ) begin
                op_req  <= 1;
                op_x    <= 1;
                op_kind <= { 1'b0, x_rtm };
                op_row  <= x_row;
            end else if( cow_need ) begin
                op_req  <= 1;
                op_kind <= 2'd2;
                op_row  <= vw_row;
            end
        end
        if( op_req && op_ack ) begin
            op_req <= 0;
            op_x   <= 0;
            op_ae  <= 0;
            if( op_ae ) ae_pend <= 0;
            if( op_x  ) begin
                x_pend <= 0;
                wt     <= 0;
            end
        end
        if( (c_vrd || c_vwe) && vcpu_ok && !dmux && !vsr_gnt ) begin
            c_vrd <= 0;
            c_vwe <= 0;
            if( vpost ) begin
                vpost <= 0;
            end else begin
                cyc_rdata <= palmode ? { vcpu_word[31:24], vcpu_word[15:8] } : { vcpu_word[23:16], vcpu_word[7:0] };
                wt        <= 0;
            end
        end
        if( busy ) begin
            if( stg!=3'd7 ) stg <= stg+3'd1;
            if( stg==0 ) begin
                case( kind )
                    IO_READ: cyc_rdata <= cyc_io_rdata;
                    PIXEL_MTR, PIXEL_RTM: begin
                        x_pend <= 1;
                        x_rtm  <= kind==PIXEL_RTM;
                        x_row  <= addr[20:13];
                        wt     <= 1;
                    end
                    SCREEN_REFRESH: begin
                        dpause     <= 1;
                        flushing   <= 1;
                        wt         <= 1;
                    end
                    WORD_READ, WORD_WRITE: begin
                        if( is_rd && pgm_cs ) begin
                            pgm_addr <= addr[22:4];
                            pgm_rd   <= 1;
                            wt       <= 1;
                        end
                        if( is_rd && img_cs && dma_busy )
                            cyc_rdata <= 16'hffff;
                        if( is_rd && img_cs && !dma_busy ) begin
                            c_gaddr <= addr[24:5];
                            c_grd   <= 1;
                            wt      <= 1;
                        end
                        if( vram_cs ) begin
                            c_vaddr <= addr[20:4];
                            c_vrd   <= is_rd;
                            c_vwe   <= is_wr;
                            c_vdin  <= palmode ? { wdata[15:8], 8'h0, wdata[7:0], 8'h0 } :
                                                 { pal_latch[15:8], wdata[15:8], pal_latch[7:0], wdata[7:0] };
                            c_vdsn  <= is_wr && palmode ? 4'b0101 : 4'b0000;
                            vpost   <= is_wr;
                            wt      <= ~is_wr;
                        end
                        if( is_wr ) begin
                            ram_we <= 1;
                            if( sys_cs ) sysctrl   <= wdata;
                            if( snd_cs ) snd_latch <= wdata;
                            if( dma_cs ) begin
                                dma_wr   <= 1;
                                dma_wsel <= addr[7:4];
                                if( addr[7:4]==4'h8 ) pal_latch <= wdata;
                            end
                        end
                        if( is_rd ) begin
                            if( in_cs  ) cyc_rdata <= addr[6:4]==0 ? in0 : addr[6:4]==1 ? in1 : in2;
                        end
                    end
                    default:;
                endcase
            end
            if( stg==3'd2 && is_rd ) begin
                if( dma_cs  ) cyc_rdata <= dma_dout;
                if( scr_cs  ) cyc_rdata <= scratch_dout;
                if( col_cs  ) cyc_rdata <= colram_dout;
                if( cmos_cs ) cyc_rdata <= { 8'hff, cmos_dout };
            end
            if( pgm_rd && pgm_ok ) begin
                cyc_rdata <= pgm_data;
`ifdef NARC_SKIPPOST
                if( pgm_addr==19'h77716 ) cyc_rdata <= 16'h00F0;
                if( pgm_addr==19'h77717 ) cyc_rdata <= 16'hFFC0;
`endif
                pgm_rd    <= 0;
                wt        <= 0;
            end
            if( c_grd && gfx_ok && !dmux ) begin
                cyc_rdata <= addr[4] ? gfx_data[31:16] : gfx_data[15:0];
                c_grd     <= 0;
                wt        <= 0;
            end
            if( flushing && dpause && (dma_paused || d_coww) && (!vpost || c_coww) && !vsr_gnt ) vcpu_flush <= 1;
            if( flushing && vcpu_flush && vcpu_flush_done && !vsr_gnt ) begin
                vcpu_flush <= 0;
                dpause     <= 0;
                flushing   <= 0;
                wt         <= 0;
                line_load  <= 1;
                line_start <= { sa[10:3], sa[2:0] | tap[8:6], tap[5:1], 2'b00 };
                line_pstart<= { b_phys, sa[2:0] | tap[8:6], tap[5:1], 2'b00 };
            end
            if( !wt && stg>=3'd3 && gsp_edge ) begin
                cyc_ack <= 1;
                busy    <= 0;
            end
        end
    end
end

`ifdef SIMULATION
always @(posedge clk) if( cyc_ack && gsp_edge && cyc_iaq && addr[31:22]!=10'h3FF ) begin
    $display("Instruction fetch outside the program ROM at %08X", addr);
    $finish;
end
`endif

always @(posedge clk) begin
    if( rst ) begin
        cpause <= 0;
        cgrant <= 0;
    end else begin
        if( dma_busy && c_dmareq && !cgrant ) cpause <= 1;
        if( cpause && dma_paused ) cgrant <= 1;
        if( !dma_busy || ( cgrant && !busy && !c_vrd && !c_vwe && !c_grd && !vpost && !c_dmareq ) ) begin
            cpause <= 0;
            cgrant <= 0;
        end
    end
end

jtnarc_cab u_cab(
    .clk       ( clk       ),
    .joystick1 ( joystick1 ),
    .joystick2 ( joystick2 ),
    .coin      ( coin      ),
    .cab_1p    ( cab_1p    ),
    .dip_test  ( dip_test  ),
    .tilt      ( tilt      ),
    .tb_data   ( tb_data   ),
    .tb_ack_n  ( tb_ack_n  ),
    .in0       ( in0       ),
    .in1       ( in1       ),
    .in2       ( in2       )
);

jtnarc_dma u_dma(
    .rst      ( rst        ),
    .clk      ( clk        ),
    .wr       ( dma_wr     ),
    .sel      ( dma_rsel   ),
    .din      ( wdata      ),
    .dout     ( dma_dout   ),
    .busy     ( dma_busy   ),
    .irq      ( dma_irq    ),
    .pause    ( dma_pause  ),
    .paused   ( dma_paused ),
    .src_addr ( dma_saddr  ),
    .src_rd   ( dma_srd    ),
    .src_data ( gfx_data   ),
    .src_ok   ( gfx_ok     ),
    .dst_addr ( dma_vaddr  ),
    .dst_we   ( dma_vwe    ),
    .dst_din  ( dma_vdin   ),
    .dst_dsn  ( dma_vdsn   ),
    .dst_ok   ( dma_ok     )
);

jtnarc_aerase u_aerase(
    .rst       ( rst              ),
    .clk       ( clk              ),
    .en        ( ae_en            ),
    .vb        ( vblank           ),
    .line_load ( line_load        ),
    .line_y    ( line_start[17:9] ),
    .start     ( ae_start         ),
    .rtm       ( ae_rtm           ),
    .row       ( ae_row           ),
    .busy      ( ae_pend          )
);

jtnarc_vmap u_vmap(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .ready    ( vmap_rdy  ),
    .chg      ( vm_chg    ),
    .op_req   ( op_req    ),
    .op_kind  ( op_kind   ),
    .op_row   ( op_row    ),
    .op_ack   ( op_ack    ),
    .a_row    ( vw_row    ),
    .a_phys   ( a_phys    ),
    .a_shared ( a_shared  ),
    .b_row    ( sa[10:3]  ),
    .b_phys   ( b_phys    ),
    .cp_start ( cp_start  ),
    .cp_src   ( cp_src    ),
    .cp_dst   ( cp_dst    ),
    .cp_busy  ( vsr_busy  ),
    .unsh     ( vm_unsh   ),
    .unsh_p   ( vm_unsh_p )
);

jtnarc_vsr u_vsr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .start      ( cp_start  ),
    .src        ( cp_src    ),
    .dst        ( cp_dst    ),
    .busy       ( vsr_busy  ),
    .idle_pt    ( vsr_pt    ),
    .gnt        ( vsr_gnt   ),
    .flush      ( vsr_flush ),
    .flush_done ( vsr_fdone ),
    .rd_addr    ( vsr_raddr ),
    .rd         ( vsr_rd    ),
    .dout       ( vrow_data ),
    .rd_ok      ( vrow_ok   ),
    .wr_addr    ( vsr_waddr ),
    .we         ( vsr_we    ),
    .din        ( vsr_din   ),
    .we_ok      ( vsr_ok    ),
    .inval      ( vm_unsh   ),
    .inval_p    ( vm_unsh_p )
);

`ifndef NOMAIN
wire        dma_irq_n = ~dma_irq;

jtnarc_gsp u_gsp(
    .rst          ( rst48        ),
    .clk          ( clk48        ),
    .lint1_n      ( dma_irq_n    ),
    .lint2_n      ( 1'b1         ),
    .cyc_req      ( cyc_req      ),
    .cyc_kind     ( cyc_kind     ),
    .cyc_addr     ( cyc_addr     ),
    .cyc_wdata    ( cyc_wdata    ),
    .cyc_io_rdata ( cyc_io_rdata ),
    .cyc_iaq      ( cyc_iaq      ),
    .cyc_srfaddr  ( cyc_srfaddr  ),
    .cyc_dpytap   ( cyc_dpytap   ),
    .cyc_org      ( cyc_org      ),
    .cyc_rdata    ( cyc_rdata    ),
    .cyc_ack      ( cyc_ack      ),
    .hs           ( hs           ),
    .vs           ( vs           ),
    .hblank       ( hblank       ),
    .vblank       ( vblank       ),
    .pc           ( pc           )
);
`else
assign cyc_req      = 0;
assign cyc_kind     = 0;
assign cyc_addr     = 0;
assign cyc_wdata    = 0;
assign cyc_io_rdata = 0;
assign cyc_iaq      = 0;
assign cyc_srfaddr  = 0;
assign cyc_dpytap   = 0;
assign cyc_org      = 0;
assign hs           = 0;
assign vs           = 0;
assign hblank       = 0;
assign vblank       = 0;
assign pc           = 0;
`endif

endmodule
