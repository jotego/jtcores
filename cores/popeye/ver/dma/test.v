`timescale 1ns/1ps

module test;

parameter NFIELDS = 8;

reg         clk = 0, rst = 1, reset_n = 1;
reg         cen20 = 0, cen5 = 0;
integer     acc = 0;
reg  [ 1:0] div = 0;
reg  [ 3:0] cpucnt = 0;
reg         cpu_cen = 0;
reg         busak_n = 1;
integer     lat = 3;
integer     seed = 7;

wire [ 7:0] tprom_addr, tprom_q, h_raw, h, v;
wire [ 3:0] tprom_data;
wire        hb, h20, vb, hbd_n, ai_n, bi_n, initeo, sy_n, hs, vs, lhbl, lvbl;

wire        busrq_n, dma_cs, rohvs, rohvck;
wire [10:0] dma_addr;
wire [ 7:0] dm;
wire [ 3:0] dmcs_n;

wire        ref_vb_n, ref_busak, ref_rohvs, ref_rohvck, ref_dmacs, ref_busrq_n, ref_g2a_n, ref_g2b_n, ref_cs;
wire [10:0] ref_dm;
wire [ 7:0] ref_y;
wire [ 2:0] ref_a;
wire [ 3:0] ref_dmcs_n;

assign tprom_data = tprom_q[3:0];
assign ref_vb_n   = ~vb;
assign ref_busak  = ~busak_n;
assign ref_g2a_n  = ~ref_dmacs;
assign ref_g2b_n  = ref_dm[10];
assign ref_a      = { 1'b0, ref_dm[9:8] };
assign ref_dmcs_n = ref_y[3:0];
assign ref_cs     = ref_dmacs & ~ref_dm[10];

always #10.41667 clk = ~clk;

always @(posedge clk) begin
    cen20 <= 0;
    cen5  <= 0;
    if( acc + 21 >= 50 ) begin
        acc   <= acc + 21 - 50;
        cen20 <= 1;
        div   <= div + 2'd1;
        cen5  <= div == 2'd3;
    end else begin
        acc   <= acc + 21;
    end
    cpucnt  <= cpucnt == 11 ? 4'd0 : cpucnt + 4'd1;
    cpu_cen <= cpucnt == 0;
end

always @(posedge clk) if( cpu_cen ) begin
    if( !reset_n ) begin
        busak_n <= 1;
    end else if( !busrq_n && busak_n ) begin
        if( lat == 0 ) busak_n <= 0; else lat <= lat - 1;
    end else if( busrq_n && !busak_n ) begin
        busak_n <= 1;
    end else if( busrq_n && busak_n ) begin
        lat <= 1 + ({$random(seed)} % 6);
    end
end

jtframe_prom #(.DW(8),.AW(8),.SIMFILE(`PROM)) u_prom(
    .clk        ( clk           ),
    .cen        ( 1'b1          ),
    .data       ( 8'd0          ),
    .rd_addr    ( tprom_addr    ),
    .wr_addr    ( 8'd0          ),
    .we         ( 1'b0          ),
    .q          ( tprom_q       )
);

jtpopeye_timing u_timing(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen5       ( cen5          ),
    .rv         ( 1'b0          ),
    .tprom_addr ( tprom_addr    ),
    .tprom_data ( tprom_data    ),
    .h_raw      ( h_raw         ),
    .hb         ( hb            ),
    .h          ( h             ),
    .h20        ( h20           ),
    .v          ( v             ),
    .vb         ( vb            ),
    .hbd_n      ( hbd_n         ),
    .ai_n       ( ai_n          ),
    .bi_n       ( bi_n          ),
    .initeo     ( initeo        ),
    .sy_n       ( sy_n          ),
    .hs         ( hs            ),
    .vs         ( vs            ),
    .lhbl       ( lhbl          ),
    .lvbl       ( lvbl          )
);

jtpopeye_dma uut(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .reset_n    ( reset_n   ),
    .ai_n       ( ai_n      ),
    .bi_n       ( bi_n      ),
    .hbd_n      ( hbd_n     ),
    .vb         ( vb        ),
    .busak_n    ( busak_n   ),
    .busrq_n    ( busrq_n   ),
    .dma_cs     ( dma_cs    ),
    .dma_addr   ( dma_addr  ),
    .dm         ( dm        ),
    .dmcs_n     ( dmcs_n    ),
    .rohvs      ( rohvs     ),
    .rohvck     ( rohvck    )
);

jtpopeye_roh_model u_ref(
    .VB_n       ( ref_vb_n      ),
    .AI_n       ( ai_n          ),
    .BI_n       ( bi_n          ),
    .HBD_n      ( hbd_n         ),
    .busak      ( ref_busak     ),
    .ROHVS      ( ref_rohvs     ),
    .ROHVCK     ( ref_rohvck    ),
    .dma_cs     ( ref_dmacs     ),
    .busrq_n    ( ref_busrq_n   ),
    .DM         ( ref_dm        )
);

jt74138 u_ref1e(
    .e1_b       ( ref_g2a_n     ),
    .e2_b       ( ref_g2b_n     ),
    .e3         ( bi_n          ),
    .a          ( ref_a         ),
    .y_b        ( ref_y         ),
    .VDD        ( 1'b1          ),
    .VSS        ( 1'b0          )
);

integer errors = 0;
reg     cmp_en = 0, chk_en = 0;

task fail(input [8*64-1:0] msg);
begin
    errors = errors + 1;
    if( errors < 20 ) $display("FAIL %0t: %0s", $time, msg);
end
endtask

integer field = 0, line = 0;
reg     hb_t = 0, vb_t = 0;
always @(posedge clk) begin
    hb_t <= hb;
    vb_t <= vb;
    if( hb && !hb_t ) line = line + 1;
    if( vb && !vb_t ) begin field = field + 1; line = 0; end
end

integer settled = 0, set_err = 0;
always @(posedge clk) if( cmp_en && cen5 ) begin
    settled = settled + 1;
    if( busrq_n !== ref_busrq_n || dm !== ref_dm[7:0] || dmcs_n !== ref_dmcs_n ||
        rohvs !== ref_rohvs || rohvck !== ref_rohvck || dma_cs !== ref_cs ) begin
        set_err = set_err + 1;
        if( set_err < 10 ) $display("MISMATCH %0t h=%0d line=%0d: busrq %b/%b dm %h/%h dmcs %h/%h rohvs %b/%b rohvck %b/%b dmacs %b/%b",
            $time, h_raw, line, busrq_n, ref_busrq_n, dm, ref_dm[7:0], dmcs_n, ref_dmcs_n,
            rohvs, ref_rohvs, rohvck, ref_rohvck, dma_cs, ref_cs);
    end
end

integer raw_clk = 0, raw_err = 0, run = 0, maxrun = 0;
integer r_busrq = 0, r_dm = 0, r_dmcs = 0, r_rohvs = 0, r_rohvck = 0, r_dmacs = 0, r_cs2020 = 0;
always @(negedge clk) if( !rst ) raw_clk = raw_clk + 1;
always @(negedge clk) if( cmp_en ) begin
    if( busrq_n !== ref_busrq_n ) r_busrq  = r_busrq  + 1;
    if( dm      !== ref_dm[7:0] ) r_dm     = r_dm     + 1;
    if( dmcs_n  !== ref_dmcs_n  ) r_dmcs   = r_dmcs   + 1;
    if( rohvs   !== ref_rohvs   ) r_rohvs  = r_rohvs  + 1;
    if( rohvck  !== ref_rohvck  ) r_rohvck = r_rohvck + 1;
    if( dma_cs  !== ref_cs      ) r_dmacs  = r_dmacs  + 1;
    if( dma_cs  !== ref_dmacs   ) r_cs2020 = r_cs2020 + 1;
    if( busrq_n !== ref_busrq_n || dm !== ref_dm[7:0] || dmcs_n !== ref_dmcs_n ||
        rohvs !== ref_rohvs || rohvck !== ref_rohvck || dma_cs !== ref_cs ) begin
        raw_err = raw_err + 1;
        run     = run + 1;
        if( run > maxrun ) maxrun = run;
    end else run = 0;
end

function [10:0] ad_of(input [15:0] a);
    ad_of = { a[10], a[8], a[7], a[6], a[3], ~a[9], ~a[5], ~a[4], ~a[2], ~a[1], ~a[0] };
endfunction

reg  [ 3:0] dmcs_l = 4'hf;
reg  [ 3:0] w_cs;
reg  [ 7:0] w_dm;
reg  [10:0] w_addr;
reg         busrq_l = 1, vb_l = 0, busak_l = 1;
reg         seen [0:1023];
integer     k, w_len, w_min = 1<<30, w_max = 0, nwin = 0, ndup = 0, ndma = 0, last_k = -1;
integer     t_rq0, t_ak0, t_w0, t_w1, t_vb, i, idx;
integer     rq_min = 1<<30, rq_max = 0, cp_min = 1<<30, cp_max = 0, ak_wait_max = 0;
integer     cs_off_min = 1<<30, cs_off_max = 0, t_cs1 = 0, n_akrel = 0;
integer     bkd_over_max = 0, bkd_over = 0;
reg  [15:0] cpu_a;

always @(posedge clk) if( chk_en ) begin
    vb_l    <= vb;
    busrq_l <= busrq_n;
    busak_l <= busak_n;
    dmcs_l  <= dmcs_n;
    if( vb && !vb_l ) t_vb = raw_clk;
    if( dma_cs && busak_n ) fail("dma_cs high while the CPU owns the bus");
    if( uut.busak_d && busak_n ) bkd_over = bkd_over + 1; else bkd_over = 0;
    if( bkd_over > bkd_over_max ) bkd_over_max = bkd_over;
    if( busak_n && !busak_l ) begin
        n_akrel = n_akrel + 1;
        if( !uut.busak_d ) fail("busak_d already low when BUSAK was released");
        if( raw_clk - t_cs1 < cs_off_min ) cs_off_min = raw_clk - t_cs1;
        if( raw_clk - t_cs1 > cs_off_max ) cs_off_max = raw_clk - t_cs1;
    end
    if( !busrq_n && busrq_l ) begin
        t_rq0 = raw_clk;
        if( raw_clk - t_vb > 2 ) fail("busrq_n late after VB rise");
        for( i=0; i<1024; i=i+1 ) seen[i] = 0;
        nwin = 0; ndup = 0; last_k = -1; t_ak0 = -1;
    end
    if( !busrq_n && !busak_n && t_ak0 < 0 ) t_ak0 = raw_clk;
    if( dma_cs ) t_cs1 = raw_clk;
    if( dmcs_n != 4'hf ) begin
        if( busak_n ) fail("DMCS active while the CPU owns the bus");
        if( !dma_cs ) fail("DMCS active without dma_cs");
        if( dmcs_n != 4'he && dmcs_n != 4'hd && dmcs_n != 4'hb && dmcs_n != 4'h7 ) fail("DMCS not one-hot");
        if( dmcs_l == 4'hf ) begin
            w_cs = dmcs_n; w_dm = dm; w_addr = dma_addr; w_len = 1;
            if( nwin == 0 ) t_w0 = raw_clk;
        end else begin
            w_len = w_len + 1;
            if( dmcs_n != w_cs || dm != w_dm || dma_addr != w_addr ) fail("DM/DMCS/address moved inside a window");
        end
    end else if( dmcs_l != 4'hf ) begin
        idx = w_cs == 4'he ? 0 : w_cs == 4'hd ? 1 : w_cs == 4'hb ? 2 : 3;
        k   = idx*256 + w_dm;
        cpu_a = 16'h8c00 + w_dm*4 + idx;
        if( w_addr != ad_of(cpu_a) ) fail("dma_addr does not match the CPU address 8C00+4*dm+n");
        if( k == last_k ) ndup = ndup + 1;
        else if( k != last_k + 1 ) fail("DMA window out of order");
        seen[k] = 1;
        last_k = k;
        nwin = nwin + 1;
        t_w1 = raw_clk;
        if( w_len < w_min ) w_min = w_len;
        if( w_len > w_max ) w_max = w_len;
    end
    if( busrq_n && !busrq_l ) begin
        ndma = ndma + 1;
        for( i=0; i<1024; i=i+1 ) if( !seen[i] ) fail("DMA address not copied");
        if( last_k != 1023 ) fail("DMA did not end at count 3FF");
        if( dm != 0 ) fail("busrq_n released with DM not 00 (count 400)");
        if( raw_clk - t_rq0 < rq_min ) rq_min = raw_clk - t_rq0;
        if( raw_clk - t_rq0 > rq_max ) rq_max = raw_clk - t_rq0;
        if( t_w1 - t_w0 < cp_min ) cp_min = t_w1 - t_w0;
        if( t_w1 - t_w0 > cp_max ) cp_max = t_w1 - t_w0;
        if( t_ak0 - t_rq0 > ak_wait_max ) ak_wait_max = t_ak0 - t_rq0;
        $display("DMA %0d field %0d: %0d windows (%0d repeated), busrq low %0d clk, copy %0d clk",
            ndma, field, nwin, ndup, raw_clk - t_rq0, t_w1 - t_w0);
    end
end

integer hv_fall = 0, hv_min = 1<<30, hv_max = 0, ck_fall = 0, ck_min = 1<<30, ck_max = 0, dm_max = 0, dm_line = 0;
integer scan_lines = 0, hbd_len = 0, hbd_cnt = 0;
reg     rohvs_l = 1, rohvck_l = 1, hb_l = 0, hbd_l = 1;
always @(posedge clk) if( chk_en ) begin
    rohvs_l  <= rohvs;
    rohvck_l <= rohvck;
    hb_l     <= hb;
    hbd_l    <= hbd_n;
    if( cen5 && !hbd_n ) hbd_cnt = hbd_cnt + 1;
    if( hbd_n && !hbd_l ) begin hbd_len = hbd_cnt; hbd_cnt = 0; end
    if( busrq_n && busak_n && !uut.busak_d ) begin
        if( !rohvs && rohvs_l ) hv_fall = hv_fall + 1;
        if( !rohvck && rohvck_l ) ck_fall = ck_fall + 1;
        if( dm > dm_line ) dm_line = dm;
    end
    if( hb && !hb_l ) begin
        if( busrq_n && busak_n && !vb && line > 2 ) begin
            scan_lines = scan_lines + 1;
            if( hv_fall < hv_min ) hv_min = hv_fall;
            if( hv_fall > hv_max ) hv_max = hv_fall;
            if( ck_fall < ck_min ) ck_min = ck_fall;
            if( ck_fall > ck_max ) ck_max = ck_fall;
            if( dm_line > dm_max ) dm_max = dm_line;
        end
        hv_fall = 0; ck_fall = 0; dm_line = 0;
    end
end

real clk_ns = 20.83333;
real dot_ns = 1e3/5.04;
real line_ns;
integer t_rst, t_rq1, t_ak2, t_cs2;

initial begin
    line_ns = dot_ns*320.0;
    repeat(40) @(posedge clk);
    #1;
    if( busrq_n !== 1 || dmcs_n !== 4'hf || dma_cs !== 0 || dm !== 0 ) fail("reset values");
    rst = 0;
    wait( line == 3 );
    cmp_en = 1;
    chk_en = 1;
    wait( field == NFIELDS );
    wait( line == 20 );
    @(posedge clk);
    cmp_en = 0;
    chk_en = 0;
    $display("HBD low %0d dots per line", hbd_len);
    $display("Settled comparison vs jtpopeye_roh_model: %0d dot samples, %0d mismatches", settled, set_err);
    $display("Per-clk comparison: %0d clk, %0d with a difference, longest run %0d clk", raw_clk, raw_err, maxrun);
    $display("  per signal (clk): busrq_n %0d, dm %0d, dmcs_n %0d, rohvs %0d, rohvck %0d, dma_cs %0d (vs 2020 busak_d without DM10: %0d)",
        r_busrq, r_dm, r_dmcs, r_rohvs, r_rohvck, r_dmacs, r_cs2020);
    $display("DMA runs %0d. busrq_n low %0d..%0d clk = %0.2f..%0.2f lines; first to last window %0d..%0d clk = %0.1f..%0.1f dots",
        ndma, rq_min, rq_max, rq_min*clk_ns/line_ns, rq_max*clk_ns/line_ns, cp_min, cp_max, cp_min*clk_ns/dot_ns, cp_max*clk_ns/dot_ns);
    $display("  window length %0d..%0d clk, BUSAK wait <= %0d clk", w_min, w_max, ak_wait_max);
    $display("  BUSAK released %0d times with busak_d still high (for up to %0d clk); dma_cs had dropped %0d..%0d clk before",
        n_akrel, bkd_over_max, cs_off_min, cs_off_max);
    $display("Scan lines %0d: ROHVS falls/line %0d..%0d, ROHVCK falls/line %0d..%0d, max DM in a line %h",
        scan_lines, hv_min, hv_max, ck_min, ck_max, dm_max);
    if( set_err != 0 ) fail("settled comparison");
    if( maxrun > 3 ) fail("per-clk differences longer than 3 clk");
    if( ndma != NFIELDS ) fail("number of DMA runs");
    if( n_akrel != NFIELDS || bkd_over_max == 0 ) fail("BUSAK release while busak_d high not exercised");
    if( scan_lines == 0 ) fail("no scan lines checked");
    if( hbd_len != 56 ) fail("HBD length from jtpopeye_timing");

    wait( !busrq_n && !busak_n && uut.busak_d && dm >= 8'h80 );
    @(posedge clk); #1;
    reset_n = 0;
    t_rst = raw_clk;
    t_rq1 = -1; t_ak2 = -1; t_cs2 = -1;
    while( t_rq1 < 0 || t_ak2 < 0 || t_cs2 < 0 ) begin
        @(posedge clk); #1;
        if( t_rq1 < 0 && busrq_n  ) t_rq1 = raw_clk;
        if( t_ak2 < 0 && busak_n  ) t_ak2 = raw_clk;
        if( t_cs2 < 0 && !dma_cs  ) t_cs2 = raw_clk;
        if( raw_clk - t_rst > 400 ) begin fail("reset_n during DMA did not finish"); t_rq1 = 0; t_ak2 = 0; t_cs2 = 0; end
    end
    $display("reset_n low mid-copy (dm=%h): busrq_n high after %0d clk, BUSAK released after %0d clk, dma_cs low after %0d clk",
        dm, t_rq1 - t_rst, t_ak2 - t_rst, t_cs2 - t_rst);
    if( t_rq1 - t_rst > 1 ) fail("reset_n did not clear 1L at once");
    if( t_cs2 - t_ak2 > 40 ) fail("dma_cs stayed high longer than one /BI period after BUSAK");
    repeat(100) @(posedge clk);
    if( dmcs_n !== 4'hf || dma_cs !== 0 ) fail("DMCS after reset_n");
    reset_n = 1;
    wait( !busrq_n && !busak_n );
    repeat(2000) @(posedge clk);
    rst = 1;
    @(posedge clk); @(posedge clk);
    #1;
    if( busrq_n !== 1 || dmcs_n !== 4'hf || dma_cs !== 0 || dm !== 0 ) fail("rst during DMA");
    if( errors == 0 ) begin
        $display("PASS");
        $finish;
    end else begin
        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
end

initial begin
    #600_000_000;
    $display("FAIL: timeout");
    $fatal(1);
end

`ifdef DUMP
initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
end
`endif

endmodule
