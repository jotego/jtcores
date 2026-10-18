`timescale 1ns/1ps

module test;

`ifndef RV
`define RV 0
`endif

`ifndef BOARD
`define BOARD 0
`endif

`ifndef IMG
`define IMG 0
`endif

reg         clk = 0, rst = 1;
wire        rv = `RV;
wire [ 1:0] board = `BOARD;
wire        nibd7 = board!=2'd0,
            tnx1  = board==2'd3;
wire        nibd7 = `BOARD != 0;
wire        tnx1  = `BOARD == 3;
wire        dd7, do16;
wire [ 2:0] cen;
wire        cen20, cen10, cen5, n_qb_fall, dotck_rise;

wire [ 7:0] tprom_addr, tprom_q, h_raw, h, v;
wire [ 3:0] tprom_data;
wire        hb, h20, vb, hbd_n, ai_n, bi_n, initeo, sy_n, hs, vs, lhbl, lvbl;

wire        busrq_n, dma_cs, rohvs, rohvck;
reg         busak_n = 1;
wire [10:0] dma_addr;
wire [ 7:0] dm;
wire [ 3:0] dmcs_n;

reg  [12:0] ad = 0;
reg  [ 7:0] dd = 0;
reg         csbw_n = 1, dwrbk_n = 1, memwr0 = 0;

reg  [ 7:0] lane0[0:255], lane1[0:255], lane2[0:255];
reg  [ 7:0] obj_do = 0, y_q = 0, dm_q = 0, l2_q = 0;
wire [ 8:0] ysum;
wire [ 8:1] rovi;
wire [ 3:0] bakc, bakc20;

assign cen20      = cen[0];
assign cen10      = cen[1];
assign cen5       = cen[2];
assign tprom_data = tprom_q[3:0];
assign ysum       = { 1'b0, y_q } + { 1'b0, v } + { 8'd0, rohvck ^ rv };
assign rovi       = ysum[8:1];
assign dd7        = dd[7];
assign do16       = l2_q[0];
assign n_qb_fall  = cen10 & ~cen5;
assign dotck_rise = n_qb_fall;

always #10.41667 clk = ~clk;

always @(posedge clk) begin
    dm_q    <= dm;
    obj_do  <= lane0[dm];
    y_q     <= lane1[dm];
    l2_q    <= lane2[dm];
    busak_n <= busrq_n;
end

jtframe_gated_cen #(.W(3),.NUM(21),.DEN(50),.MFREQ(48000)) u_cen(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .busy   ( 1'b0          ),
    .cen    ( cen           ),
    .fave   (               ),
    .fworst (               )
);

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
    .rv         ( rv            ),
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

jtpopeye_dma u_dma(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .reset_n    ( 1'b1      ),
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

jtpopeye_bg uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen5       ( cen5          ),
    .cen10      ( cen10         ),
    .nibd7      ( nibd7         ),
    .tnx1       ( tnx1          ),
    .ad         ( ad            ),
    .dd         ( dd[3:0]       ),
    .dd7        ( dd7           ),
    .csbw_n     ( csbw_n        ),
    .dwrbk_n    ( dwrbk_n       ),
    .memwr0     ( memwr0        ),
    .rohvck     ( rohvck        ),
    .obj_do     ( obj_do        ),
    .do16       ( do16          ),
    .rovi       ( rovi          ),
    .bakc       ( bakc          )
);

`ifdef REF
wire [ 3:0] bakc_ref;
integer     ref_n = 0, ref_bad = 0;

jtpopeye_bg_ref u_ref(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen5       ( cen5          ),
    .cen10      ( cen10         ),
    .ad         ( ad            ),
    .dd         ( dd[3:0]       ),
    .csbw_n     ( csbw_n        ),
    .dwrbk_n    ( dwrbk_n       ),
    .memwr0     ( memwr0        ),
    .rohvck     ( rohvck        ),
    .obj_do     ( obj_do        ),
    .rovi       ( rovi          ),
    .bakc       ( bakc_ref      )
);

always @(posedge clk) if( `BOARD==0 ) begin
    ref_n = ref_n + 1;
    if( bakc !== bakc_ref ) begin
        ref_bad = ref_bad + 1;
        if( ref_bad < 10 ) $display("FAIL %0t: bakc=%h, previous bg module gives %h", $time, bakc, bakc_ref);
    end
end
`endif

`ifdef JT2020
wire [28:0] do20;
wire [ 8:0] rovi20;
assign do20   = { 21'd0, obj_do };
assign rovi20 = { rovi, 1'b0 };

wire [12:0] adv20;
jtpopeye_video_dec u_dec20b(
    .AD         ( ad            ),
    .AD_dec     ( adv20         )
);

jtpopeye_bck u_2020(
    .rst_n      ( ~rst          ),
    .clk        ( clk           ),
    .pxl_cen    ( cen5          ),
    .cpu_cen    ( 1'b0          ),
    .CSBW_n     ( csbw_n        ),
    .DWRBK      ( ~dwrbk_n      ),
    .ROHVCK     ( rohvck        ),
    .AD         ( adv20         ),
    .ROVI       ( rovi20        ),
    .DO         ( do20          ),
    .DD         ( dd            ),
    .BAKC       ( bakc20        )
);
`else
assign bakc20 = 0;
`endif

reg  [ 3:0] ref_mem[0:8191];
integer     errors = 0, checks = 0, i;
integer     seed = 11, seed2 = 5;

task fail(input [8*80-1:0] msg);
begin
    errors = errors + 1;
    if( errors < 25 ) $display("FAIL %0t: %0s", $time, msg);
end
endtask

function [12:0] scr(input [15:0] a);
    scr = { a[12:10], a[8], a[7], a[6], a[3], ~a[9], ~a[5], ~a[4], ~a[2:0] };
endfunction

function [3:0] pat(input [12:0] a, input [3:0] k);
    reg [25:0] m;
begin
    m   = a * 13'd1237 + { a[6:0], a[12:7] } * 13'd91;
    pat = m[9:6] ^ m[3:0] ^ k;
end
endfunction

function [12:0] widx(input [15:0] a, input [7:0] d);
    widx = nibd7 ? { d[7], a[11:0] } : a[12:0];
endfunction

function [12:0] oidx(input [15:0] a, input [7:0] d);
    oidx = nibd7 ? { ~d[7], a[11:0] } : { ~a[12], a[11:0] };
endfunction

function [3:0] img(input [6:0] r, input [6:0] c);
    reg [13:0] m;
begin
    m   = { r, c } * 14'd2731 + { c, r } * 14'd77;
    img = m[11:8] ^ m[3:0] ^ { r[0], c[0], r[3], c[5] };
end
endfunction

reg         busy = 0;
reg  [ 3:0] frz_exp = 0;
reg         cleared = 0;
integer     excl = 0;

task cpu_cycle(input [15:0] a, input [7:0] d, input wr, input inbmp);
    reg [3:0] other;
begin
    @(posedge clk) #1;
    ad = scr(a);
    dd = d;
    other = ref_mem[oidx(a, d)];
    frz_exp = bakc;
    if( inbmp ) begin
        busy = 1;
        csbw_n = 0;
        cleared = 1;
        excl = 1;
    end
    repeat(6) @(posedge clk) #1;
    if( wr ) memwr0 = 1;
    repeat(6) @(posedge clk) #1;
    if( wr && inbmp ) begin
        dwrbk_n = 0;
        if( !nibd7 || !a[12] ) ref_mem[widx(a, d)] = d[3:0];
    end
    repeat(8) @(posedge clk) #1;
    dwrbk_n = 1;
    repeat(2) @(posedge clk) #1;
    memwr0 = 0;
    repeat(4) @(posedge clk) #1;
    if( inbmp ) begin
        checks = checks + 1;
        if( wr ) begin
            if( ^other !== 1'bx && bakc !== other ) fail("8U capture at MEMWR0 rise is not the other nibble");
        end else begin
            if( bakc !== frz_exp ) fail("8U not frozen during a CSBW read");
        end
    end
    csbw_n = 1;
    @(posedge clk) #1;
    busy = 0;
end
endtask

reg  [ 2:0] c5d = 0, cfd = 0;
reg  [ 7:0] sy = 0;
reg  [ 8:0] sx = 0, rline = 0;
reg  [ 8:0] yline = 0;
reg         chk_en = 0, rohvck_t = 1;
integer     nld = 0;
integer     cov_n = 0;
reg         cov[0:8191];
integer     n20 = 0, n20_pre = 0, nonzero_ld = 0;
integer     img_n = 0, wrap_n = 0, hi_n = 0;
reg         imgchk = 0;
reg  [ 3:0] img_exp;

function [12:0] exp_addr(input [8:0] rr);
    reg nib;
begin
    nib = tnx1 ? rr[8] : nibd7 ? yline[1] : yline[7];
    if( cleared )
        exp_addr = { tnx1 & rr[8], 6'd0, rr[7:2] };
    else if( !yline[8] )
        exp_addr = { nib, 12'd0 };
    else if( nibd7 )
        exp_addr = { nib, yline[7:2], rr[7:2] };
    else
        exp_addr = { yline[7], yline[6:1], rr[7:2] };
end
endfunction

reg  [ 8:0] rpost, rpre, rr_s;
reg  [12:0] ea;
always @(posedge clk) begin
    c5d <= { c5d[1:0], cen5 };
    cfd <= { cfd[1:0], dotck_rise };
    rohvck_t <= rohvck;
    if( dotck_rise ) begin
        rline <= !rohvck ? { tnx1 & lane2[dm_q][0], lane0[dm_q] } : rline + 9'd1;
        nld   <= !rohvck ? 0 : nld + 1;
    end
    if( cen5 ) begin
        if( csbw_n && !busy && excl>0 ) excl = excl + 1;
        if( excl > 7 ) excl = 0;
    end
    if( !rohvck ) yline <= { 1'b0, lane1[dm_q] } + { 1'b0, v } + { 8'd0, rv };
    if( !rohvck && cen5 && dm_q!=0 ) nonzero_ld = nonzero_ld + 1;
    if( rohvck && !rohvck_t && csbw_n ) cleared = 0;
    if( chk_en && !hb && excl==0 && !busy && nld>4 && (c5d[2] || cfd[2]) ) begin
        rpost = rline - ((rline + 9'd1) & 9'd3);
        rpre  = rline - 9'd1 - (rline & 9'd3);
        rr_s  = cfd[2] ? rpre : rpost;
        ea    = exp_addr( rr_s );
        if( imgchk && !cleared && yline[8] ) begin
            img_exp = tnx1 ? img( { 1'b0, yline[7:2] }, rr_s[8:2] ) : img( yline[7:1], { 1'b0, rr_s[7:2] } );
            img_n = img_n + 1;
            if( tnx1 && rr_s < sx ) wrap_n = wrap_n + 1;
            if( tnx1 && rr_s[8] ) hi_n = hi_n + 1;
            if( bakc !== img_exp ) begin
                errors = errors + 1;
                if( errors < 25 ) $display("FAIL %0t: picture v=%h y=%h x=%h bakc=%h img=%h", $time, v, yline, rr_s, bakc, img_exp);
            end
        end
        checks = checks + 1;
        if( bakc !== ref_mem[ea] ) begin
            errors = errors + 1;
            if( errors < 25 ) $display("FAIL %0t: v=%h h=%0d %s rline=%h y=%h clr=%b addr=%h bakc=%h exp=%h rov=%h roh=%h field=%0d",
                $time, v, h_raw, cfd[2] ? "pre " : "post", rline, yline, cleared, ea, bakc, ref_mem[ea], uut.rov, uut.roh, field);
        end else if( !cov[ea] ) begin
            cov[ea] = 1;
            cov_n = cov_n + 1;
        end
`ifdef JT2020
        n20 = n20 + 1;
        if( bakc20 !== ref_mem[ea] ) n20_pre = n20_pre + 1;
`endif
    end
end

integer field = 0;
reg     vb_t = 0;
always @(posedge clk) begin
    vb_t <= vb;
    if( vb && !vb_t ) field = field + 1;
end

task set_scroll(input [7:0] x, input [7:0] y);
begin
    @(posedge vb);
    @(posedge hb);
    wait( rohvck );
    sx = { 1'b0, x }; sy = y;
    lane0[0] = x;
    lane1[0] = y;
end
endtask

task set_scroll9(input [8:0] x, input [7:0] y);
begin
    @(posedge vb);
    @(posedge hb);
    wait( rohvck );
    sx = tnx1 ? x : { 1'b0, x[7:0] }; sy = y;
    lane0[0] = x[7:0];
    lane2[0] = { lane2[0][7:1], x[8] };
    lane1[0] = y;
end
endtask

integer a, k, nw, r, c, f_end;
task fill_tpp2;
begin
    for( a=0; a<8192; a=a+1 ) cpu_cycle( 16'hc000 | a, 8'h00, 1, 1 );
    for( c=0; c<64; c=c+1 )
        for( r=127; r>=0; r=r-1 )
            cpu_cycle( 16'hc000 | ( r[6] << 12 ) | ( r[5:0] << 6 ) | c, { 4'h0, img( r[6:0], c[6:0] ) }, 1, 1 );
end
endtask

task fill_tpp1;
begin
    for( a=0; a<4096; a=a+1 ) cpu_cycle( 16'hc000 | a, 8'h00, 1, 1 );
    for( a=0; a<4096; a=a+1 ) cpu_cycle( 16'hc000 | a, 8'h80, 1, 1 );
    for( c=0; c<64; c=c+1 )
        for( r=63; r>=0; r=r-1 ) begin
            cpu_cycle( 16'hc000 | ( r << 6 ) | c, { 4'h8, img( 2*r+1, c[6:0] ) }, 1, 1 );
            cpu_cycle( 16'hc000 | ( r << 6 ) | c, { 4'h0, img( 2*r,   c[6:0] ) }, 1, 1 );
        end
end
endtask

task fill_tnx1;
begin
    for( a=0; a<4096; a=a+1 ) cpu_cycle( 16'hc000 | a, 8'h00, 1, 1 );
    for( a=0; a<4096; a=a+1 ) cpu_cycle( 16'hc000 | a, 8'h80, 1, 1 );
    for( c=0; c<128; c=c+1 )
        for( r=63; r>=0; r=r-1 )
            cpu_cycle( 16'hc000 | ( r << 6 ) | c[5:0], { c[6], 3'd0, img( r[6:0], c[6:0] ) }, 1, 1 );
end
endtask

initial begin
    for( i=0; i<256; i=i+1 ) begin
        lane0[i] = $random(seed);
        lane1[i] = $random(seed);
        lane2[i] = $random(seed2);
    end
    for( i=0; i<8192; i=i+1 ) begin
        ref_mem[i] = 4'bxxxx;
        cov[i] = 0;
    end
    #100;
    repeat(20) @(posedge clk);
    if( bakc !== 4'd0 ) fail("bakc not 0 in reset");
    rst = 0;
    if( `BOARD==0 && `IMG==0 ) begin
        for( a=0; a<4096; a=a+1 ) cpu_cycle( 16'hc000 | a, { 4'h9, pat(a, 4'd0) }, 1, 1 );
        for( a=4096; a<8192; a=a+1 ) cpu_cycle( 16'hc000 | a, { 4'h6, pat(a, 4'd0) }, 1, 1 );
        for( a=0; a<8192; a=a+1 )
            if( ref_mem[a] !== pat(a, 4'd0) ) fail("bench ref_mem fill");
        set_scroll( 8'h00, 8'h00 );
        chk_en = 1;
        set_scroll( 8'h00, 8'hf0 );
        set_scroll( 8'h5b, 8'h31 );
        set_scroll( 8'hc4, 8'h88 );
        set_scroll( 8'h13, 8'hc7 );
    end else begin
        if( tnx1 ) fill_tnx1; else if( nibd7 ) fill_tpp1; else fill_tpp2;
        imgchk = 1;
        set_scroll9( 9'h000, 8'h00 );
        chk_en = 1;
        set_scroll9( 9'h000, 8'hf0 );
        set_scroll9( 9'h0c4, 8'h31 );
        set_scroll9( 9'h100, 8'h88 );
        set_scroll9( 9'h15b, 8'hc7 );
        set_scroll9( 9'h1c0, 8'h40 );
        set_scroll9( 9'h1ff, 8'h13 );
        set_scroll9( 9'h0ff, 8'hb0 );
        @(posedge vb);
        imgchk = 0;
        $display("picture checks=%0d (TNX1: after the 9-bit wrap %0d, right half %0d)", img_n, wrap_n, hi_n);
    end
    $display("phase 1 (static scrolls) checks=%0d coverage=%0d/8192 errors=%0d", checks, cov_n, errors);
`ifndef SHORT
    set_scroll( 8'h2a, 8'hb0 );
    nw = 0;
    f_end = ( `BOARD==0 && `IMG==0 ) ? 9 : field + 4;
    while( field < f_end ) begin
        repeat( 200 + {$random(seed)} % 4000 ) @(posedge clk);
        a = {$random(seed)} % 8192;
        k = {$random(seed)} % 8;
        if( k==0 )
            cpu_cycle( 16'hc000 | a, 8'h00, 0, 1 );
        else if( k==1 )
            cpu_cycle( 16'h8000 | a, 8'h55, 1, 0 );
        else begin
            cpu_cycle( 16'hc000 | a, $random(seed), 1, 1 );
            nw = nw + 1;
        end
    end
    $display("phase 2 (CPU accesses during display) writes=%0d", nw);
    set_scroll( 8'hff, 8'hff );
    set_scroll( 8'h80, 8'h7f );
`endif
`ifdef REF
    if( `BOARD==0 ) $display("board 0 against the previous bg module: %0d of %0d clocks differ", ref_bad, ref_n);
    if( ref_bad != 0 ) errors = errors + 1;
`endif
    $display("checks=%0d coverage=%0d/8192 rv=%0d board=%0d; ROH loads from a list entry other than 0 (DMA in VB): %0d", checks, cov_n, rv, `BOARD, nonzero_ld);
`ifdef JT2020
    $display("2020 jtpopeye_bck: %0d of %0d dot samples differ from the bench model", n20_pre, n20);
`endif
    if( errors==0 ) begin
        $display("PASS");
        $finish;
    end else begin
        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
end

endmodule
