`timescale 1ps/1ps

module test;

reg         clk=0, rst=1, rv=0;
localparam integer HLEXP = 513;
real        rate_exp = 5.04e6/(160.0*HLEXP);
reg         cen20=0, cen5=0, cen10=0;
integer     acc=0;
reg  [ 1:0] div=0;

wire [ 7:0] tprom_addr, tprom_q, h_raw, h, v;
wire [ 3:0] tprom_data = tprom_q[3:0];
wire        hb, h20, vb, hbd_n, ai_n, bi_n, initeo, sy_n, hs, vs, lhbl, lvbl;

reg  [ 7:0] prom[0:255];
integer     fd, nrd;

initial forever #10417 clk = ~clk;

always @(posedge clk) begin
    cen20 <= 0;
    cen5  <= 0;
    cen10 <= 0;
    if( acc + 21 >= 50 ) begin
        acc   <= acc + 21 - 50;
        cen20 <= 1;
        div   <= div + 2'd1;
        cen5  <= div == 2'd3;
        cen10 <= div[0];
    end else begin
        acc   <= acc + 21;
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

jtpopeye_timing uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen5       ( cen5          ),
    .cen10      ( cen10         ),
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

wire [7:0] V20, H20b;
wire       cen5_2020 = cen5 & ~rst;
wire       H2O20, HB20, HBDn20, VB20, EO20, SYn20, HS20, VS20, pHBD20;

jtpopeye_timing_2020 u_2020(
    .clk        ( clk           ),
    .pxl2_cen   ( 1'b0          ),
    .pxl_cen    ( cen5_2020     ),
    .RV_n       ( ~rv           ),
    .V          ( V20           ),
    .H          ( H20b          ),
    .H2O        ( H2O20         ),
    .HB         ( HB20          ),
    .HBD_n      ( HBDn20        ),
    .pre_HBDn   ( pHBD20        ),
    .VB         ( VB20          ),
    .INITEO     ( EO20          ),
    .SY_n       ( SYn20         ),
    .HS         ( HS20          ),
    .VS         ( VS20          ),
    .prog_addr  ( 8'd0          ),
    .prom_7j_we ( 1'b0          ),
    .prom_din   ( 4'd0          )
);

integer errors=0;
integer k;
integer exp_vclk0, exp_vclk1, nexp;

task fail(input [8*64-1:0] msg); begin
    errors = errors + 1;
    if( errors < 30 ) $display("FAIL %0s at t=%0t idx=%0d h_raw=%h hb=%b vcnt=%h", msg, $time, idx, h_raw, hb, uut.vcnt);
end endtask

integer idx=0, lines=0, chk=0;
reg     hb_s=0, lvbl_s=0;
integer vclk_in_line=0, vclk_pos0=-1, vclk_pos1=-1;
integer half_lines=0, fields=0, vis_lines=0, sy_low=0, hs_len=0, vs_dots=0;
integer last_vb_clk=0, clkcnt=0, vb_hl=0, vb_high_hl=0;
reg     last_eo=0, have_eo=0, eo_valid=0;
reg     vb_d=0, vclk_d=0, armed=0, hb_at_vb=0;
integer act_dots=0, vs_rises=0;
reg     vs_s=0;
reg     line_full=0;
integer r1_wb=0, r1_h=0, r1_v=0, r1_vb=0, r1_hbd=0, r1_eo=0, r1_sy=0, r1_n=0;
integer mm_h=0, mm_hb=0, mm_v=0, mm_vb=0, mm_hbd=0, mm_eo=0, mm_sy=0, mm_h20=0, mm_n=0;
integer first_mm_v=-1, first_mm_vb=-1, first_mm_sy=-1, first_mm_hbd=-1, first_mm_eo=-1;
integer vmin=255, vmax=0, vis_v_ok=1;
real    rate, lrate;
integer line_clk0=0, line_clks=0;
reg [7:0] exp_h;
reg       exp_hb;
reg       measure=0;
integer   sy_hist[0:7];
integer   sy_runs, sy_start, sy_len, sy_pos, sy_cls;
reg       sy_prev;

always @(posedge clk) clkcnt <= clkcnt + 1;

always @(posedge clk) if( !rst ) begin
    vclk_d <= uut.vclk;
    vb_d   <= vb;
    if( uut.vclk && !vclk_d ) begin
        half_lines <= half_lines + 1;
        vb_hl      <= vb_hl + 1;
        if( vb ) vb_high_hl <= vb_high_hl + 1;
        if( measure ) begin
            if( !(({hb,h_raw}==exp_vclk0) || ({hb,h_raw}==exp_vclk1)) ) fail("vclk position");
        end
        vclk_in_line <= vclk_in_line + 1;
    end
    if( vb && !vb_d ) begin
        armed <= measure;
        hb_at_vb <= hb;
        if( measure && armed ) begin
            if( half_lines != HLEXP ) fail("half lines per field");
            if( vs_rises != 1 ) fail("vs pulses per field");
            rate = 48.0e6 / (clkcnt - last_vb_clk);
            if( fields < 4 ) $display("field %0d: %0d half lines, %0d visible lines, VB high for %0d Vclk, field rate %0.4f Hz, v range %h..%h",
                fields, half_lines, vis_lines, vb_high_hl, rate, vmin, vmax);
            if( rate < rate_exp - 0.005 || rate > rate_exp + 0.005 ) fail("field rate");
            if( vis_lines != 224 ) fail("visible lines");
            if( vmin != 8'h10 || vmax != 8'hef ) fail("visible v range");
            if( vs_dots != 4*320 ) fail("vs width");
            fields <= fields + 1;
        end
        last_vb_clk <= clkcnt;
        half_lines  <= 0;
        vis_lines   <= 0;
        vb_high_hl  <= 0;
        vmin        <= 255;
        vmax        <= 0;
        vs_dots     <= 0;
        vs_rises    <= 0;
        have_eo     <= 0;
    end
    if( vb_d && vb==vb_d && !have_eo && measure && armed ) begin
        if( eo_valid && last_eo == initeo ) fail("initeo did not toggle");
        if( initeo != (hb_at_vb ^ rv) ) fail("initeo polarity");
        if( fields < 4 ) $display("  initeo for this field = %b", initeo);
        last_eo  <= initeo;
        have_eo  <= 1;
        eo_valid <= 1;
    end
    if( !measure ) eo_valid <= 0;
end

always @(posedge clk) if( !rst && cen5 ) begin
    hb_s <= hb;
    vs_s <= vs;
    lvbl_s <= lvbl;
    exp_hb = idx >= 256;
    exp_h  = idx < 256 ? idx[7:0] : 8'hc0 + idx - 256;
    if( measure ) begin
        if( h_raw != exp_h || hb != exp_hb ) fail("h counter");
        if( h[2:0] != h_raw[2:0] || h[7:3] != (h_raw[7:3] ^ {5{rv}}) || h20 != (h_raw[2]^rv) ) fail("h flip");
        if( ai_n != ~h_raw[0] || bi_n != ~h_raw[1] ) fail("ai/bi");
        if( hbd_n != !(hb && h_raw >= 8'hc8) ) fail("hbd_n");
        if( lhbl != (hb ? h_raw < 8'hc7 : h_raw >= 8'h07) ) fail("lhbl window");
        if( lhbl ) act_dots <= act_dots + 1;
        if( lvbl != lvbl_s && lhbl ) fail("lvbl changes inside the lhbl window");
        if( hs != (idx >= 278 && idx < 296) ) fail("hs");
        if( v != (uut.vlatch ^ {8{rv}}) ) fail("v flip");
        if( vs ) vs_dots <= vs_dots + 1;
        if( vs && !vs_s ) vs_rises <= vs_rises + 1;
        if( !sy_n ) sy_low <= sy_low + 1;
        if( rv ) begin
            if( H20b[3:0] != h[3:0] || HB20 != hb || H2O20 != h20 ) r1_h <= r1_h + 1;
            if( V20[0] != v[0] ) r1_v <= r1_v + 1;
            if( H20b[7:4] != (h[7:4] ^ 4'hf) || V20[7:1] != (v[7:1] ^ 7'h7f) ) r1_wb <= r1_wb + 1;
            if( VB20 != vb ) r1_vb <= r1_vb + 1;
            if( HBDn20 != hbd_n ) r1_hbd <= r1_hbd + 1;
            if( EO20 != initeo ) r1_eo <= r1_eo + 1;
            if( SYn20 != sy_n ) r1_sy <= r1_sy + 1;
            r1_n <= r1_n + 1;
        end else begin
        if( H20b != h || HB20 != hb || H2O20 != h20 ) mm_h <= mm_h + 1;
        if( V20 != v ) begin mm_v <= mm_v + 1; if( first_mm_v<0 ) first_mm_v <= lines; end
        if( VB20 != vb ) begin mm_vb <= mm_vb + 1; if( first_mm_vb<0 ) first_mm_vb <= lines; end
        if( HBDn20 != hbd_n ) begin mm_hbd <= mm_hbd + 1; if( first_mm_hbd<0 ) first_mm_hbd <= idx; end
        if( EO20 != initeo ) begin mm_eo <= mm_eo + 1; if( first_mm_eo<0 ) first_mm_eo <= lines; end
        if( SYn20 != sy_n ) begin mm_sy <= mm_sy + 1; if( first_mm_sy<0 ) first_mm_sy <= lines; end
        mm_n <= mm_n + 1;
        end
        if( sy_n != sy_prev ) begin
            if( !sy_n ) begin sy_start = idx; end
            else begin
                sy_runs = sy_runs + 1;
                sy_len  = idx - sy_start;
                sy_pos  = sy_start;
            end
        end
    end
    sy_prev <= sy_n;
    idx <= idx + 1;
    if( idx == 319 ) begin
        idx <= 0;
        lines <= lines + 1;
        if( measure ) begin
            if( vclk_in_line != 2 ) fail("vclk count per line");
            if( act_dots != 256 && line_full ) fail("lhbl active dots per line");
            line_clks = clkcnt - line_clk0;
            if( lines < 3 || lines > 1000 ) begin end
        end
        line_clk0 <= clkcnt;
        vclk_in_line <= 0;
        act_dots <= 0;
        line_full <= measure;
    end
    if( idx == 265 ) begin
        if( measure && lvbl ) begin
            vis_lines <= vis_lines + 1;
        end
    end
end

always @(posedge clk) if( !rst && measure && uut.hb && !uut.hb_l ) begin
    if( !vb ) begin
        if( uut.vcnt < vmin ) vmin <= uut.vcnt;
        if( uut.vcnt > vmax ) vmax <= uut.vcnt;
    end
end

integer sy_line_runs, sy_line_low;
reg [8*16-1:0] sy_sig;
integer pat_normal=0, pat_other=0;
integer prev_lines=0;
integer runs_in_line=0, low_in_line=0, run_start=-1;
reg     syp=1;
integer pat_cnt[0:15];
reg [31:0] pat_key[0:15];
integer npat=0, p;
reg [31:0] key;
reg        found;

always @(posedge clk) if( !rst && cen5 && measure ) begin
    syp <= sy_n;
    if( !sy_n ) low_in_line = low_in_line + 1;
    if( !sy_n && syp ) begin runs_in_line = runs_in_line + 1; if( run_start < 0 ) run_start = idx; end
    if( idx == 319 ) begin
        key = { runs_in_line[7:0], low_in_line[11:0], run_start[11:0] };
        found = 0;
        for( p=0; p<npat; p=p+1 ) if( pat_key[p]==key ) begin pat_cnt[p] = pat_cnt[p]+1; found=1; end
        if( !found && npat<16 ) begin pat_key[npat]=key; pat_cnt[npat]=1; npat=npat+1; end
        runs_in_line = 0;
        low_in_line  = 0;
        run_start    = -1;
    end
end

integer i, a, b;

initial begin
    fd = $fopen(`PROM,"rb");
    nrd = $fread(prom, fd);
    $fclose(fd);
    nexp = 0;
    exp_vclk0 = -1;
    exp_vclk1 = -1;
    for( i=0; i<320; i=i+1 ) begin
        a = i<256 ? (i>>1) : 128 + ((192 + i - 256)>>1);
        b = i==0 ? 128+127 : ((i-1)<256 ? ((i-1)>>1) : 128 + ((192 + i - 1 - 256)>>1));
        if( prom[a][1] && !prom[b][1] ) begin
            if( nexp==0 ) exp_vclk0 = (i<256 ? i : 256 + 192 + i - 256); else exp_vclk1 = (i<256 ? i : 256 + 192 + i - 256);
            $display("7J pin 11 (Vclk) rises at dot %0d of the line (HB=%0d H=%h)", i, i>=256, i<256 ? i : 192+i-256);
            nexp = nexp + 1;
        end
    end
    if( nexp != 2 ) begin $display("FAIL: PROM has %0d Vclk rising edges per line", nexp); errors = errors + 1; end
    for( i=0; i<320; i=i+1 ) begin
        a = i<256 ? (i>>1) : 128 + ((192 + i - 256)>>1);
        if( prom[a][2] && (i==0 || !prom[ i-1<256 ? ((i-1)>>1) : 128 + ((192+i-1-256)>>1) ][2]) )
            $display("7J pin 10 (CL1, hsync) rises at dot %0d", i);
        if( prom[a][3] && (i==0 || !prom[ i-1<256 ? ((i-1)>>1) : 128 + ((192+i-1-256)>>1) ][3]) )
            $display("7J pin 9 (SL1) rises at dot %0d", i);
        if( !prom[a][0] && (i==0 || prom[ i-1<256 ? ((i-1)>>1) : 128 + ((192+i-1-256)>>1) ][0]) )
            $display("7J pin 12 falls at dot %0d", i);
    end
    $display("expecting %0d half lines per field, %0.4f Hz", HLEXP, rate_exp);
    sy_prev = 1;
    sy_runs = 0;
    repeat(20) @(posedge clk);
    rst = 0;
    wait( lines == 3*257 );
    @(posedge clk);
    wait( idx == 0 );
    @(posedge cen5);
    measure = 1;
    wait( fields == 3 );
    $display("lhbl: 256 active dots per line, switching mid-dot (cen10) in h_raw 07 and C7, checked every line");
    $display("line: 320 dots checked every line, %0d clk per line -> %0.4f kHz", line_clks, 48.0e3/line_clks);
    $display("composite sync patterns per line (count, runs, low dots, first fall dot), 4 fields:");
    for( p=0; p<npat; p=p+1 ) $display("  %5d lines: %0d pulse(s), %0d dots low, first at dot %0d", pat_cnt[p], pat_key[p][31:24], pat_key[p][23:12], pat_key[p][11:0]);
    $display("JT 2020 comparison over %0d dots (rv=0): H/HB/H20 %0d, V %0d, VB %0d, HBD_n %0d, INITEO %0d, SY_n %0d mismatching dots",
        mm_n, mm_h, mm_v, mm_vb, mm_hbd, mm_eo, mm_sy);
    if( (mm_h || mm_v || mm_vb || mm_hbd || mm_eo || mm_sy) ) begin $display("FAIL: differs from JT 2020 model"); errors = errors + 1; end
    rv = 1;
    measure = 0;
    repeat(2) begin
        @(posedge uut.vb);
    end
    measure = 1;
    repeat(4) @(posedge uut.vb);
    $display("rv=1: four more fields checked (h/v flip, initeo toggling)");
    $display("JT 2020 comparison over %0d dots (rv=1): H/HB/H20 %0d, V %0d, VB %0d, HBD_n %0d, INITEO %0d, SY_n %0d mismatching dots",
        r1_n, r1_h, r1_v, r1_vb, r1_hbd, r1_eo, r1_sy);
    $display("rv=1: H7-H4 and V7-V1 of the 2020 model stay unflipped (its 1-bit RV is zero-extended in the XOR): %0d of %0d dots deviate from that; flip compared on H3-H0, H20, V0", r1_wb, r1_n);
    if( (r1_n==0 || r1_h || r1_v || r1_vb || r1_hbd || r1_eo || r1_sy) ) begin $display("FAIL: differs from JT 2020 model with rv=1"); errors = errors + 1; end
    measure = 0;
    @(posedge cen5);
    rst = 1;
    repeat(3) @(posedge clk);
    if( h_raw!=0 || hb!=0 || vb!=0 || uut.vcnt!=0 || uut.vlatch!=0 || initeo!=rv || !hbd_n || !sy_n || lvbl || lhbl || hs || vs )
        begin $display("FAIL reset values"); errors = errors + 1; end
    else $display("reset values OK");
    @(posedge clk);
    rst = 0;
    idx = 0;
    lines = 0;
    wait( lines == 3*257 );
    wait( idx == 0 );
    @(posedge cen5);
    measure = 1;
    repeat(4) @(posedge uut.vb);
    $display("after reset: fields checked again");
    if( errors==0 ) begin
        $display("PASS");
        $finish;
    end else begin
        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
end

initial begin
    repeat(500) #2_000_000_000;
    $display("FAIL: timeout");
    $fatal(1);
end

endmodule

module jt2020_prom #(parameter aw=8, dw=4, simfile="")(
    input               clk,
    input               cen,
    input      [dw-1:0] data,
    input      [aw-1:0] rd_addr,
    input      [aw-1:0] wr_addr,
    input               we,
    output reg [dw-1:0] q
);
reg [7:0] mem[0:255];
integer f, n;
initial begin
    f = $fopen(`PROM,"rb");
    n = $fread(mem, f);
    $fclose(f);
end
always @(posedge clk) q <= mem[rd_addr][dw-1:0];
endmodule
