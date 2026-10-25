`include "fixtures.vh"
`timescale 1ns/1ps

module test;


parameter NFIELDS = 9;

reg         clk = 0, rst = 1;
reg         cen20 = 0, cen10 = 0, cen5 = 0;
integer     acc = 0;
reg  [ 1:0] div = 0;
reg         rv = 0;
reg  [31:0] bsr = 32'hffffffff;
wire        busak_n;

wire [ 7:0] tprom_addr, tprom_q, h_raw, h, v;
wire        hb, h20, vb, hbd_n, ai_n, bi_n, initeo, sy_n, hs, vs, lhbl, lvbl;
wire        busrq_n, dma_cs, rohvs, rohvck;
wire [10:0] dma_addr;
wire [ 7:0] dm;
wire [ 3:0] dmcs_n;
reg  [ 7:0] dd = 0;

wire [28:0] obj_do;
wire [ 8:1] rovi;
wire [17:0] dj;
wire [ 5:3] obj_c;
wire        bakc4;

assign busak_n = bsr[31];

always #10.41667 clk = ~clk;

always @(posedge clk) begin
    cen20 <= 0;
    cen10 <= 0;
    cen5  <= 0;
    if( acc + 21 >= 50 ) begin
        acc   <= acc + 21 - 50;
        cen20 <= 1;
        div   <= div + 2'd1;
        cen10 <= div[0];
        cen5  <= div == 2'd3;
    end else begin
        acc   <= acc + 21;
    end
    bsr <= { bsr[30:0], busrq_n };
end

reg [7:0] wram[0:2047];
always @(posedge clk) dd <= busak_n ? $random : wram[dma_addr];

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
    .cen10      ( cen10         ),
    .rv         ( rv            ),
    .tprom_addr ( tprom_addr    ),
    .tprom_data ( tprom_q[3:0]  ),
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
    .rst        ( rst           ),
    .clk        ( clk           ),
    .reset_n    ( 1'b1          ),
    .ai_n       ( ai_n          ),
    .bi_n       ( bi_n          ),
    .hbd_n      ( hbd_n         ),
    .vb         ( vb            ),
    .busak_n    ( busak_n       ),
    .busrq_n    ( busrq_n       ),
    .dma_cs     ( dma_cs        ),
    .dma_addr   ( dma_addr      ),
    .dm         ( dm            ),
    .dmcs_n     ( dmcs_n        ),
    .rohvs      ( rohvs         ),
    .rohvck     ( rohvck        )
);

jtpopeye_objbuf uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen5       ( cen5          ),
    .cen10      ( cen10         ),
    .h          ( h             ),
    .h20        ( h20           ),
    .hb         ( hb            ),
    .v          ( v             ),
    .rv         ( rv            ),
    .dm         ( dm            ),
    .dmcs_n     ( dmcs_n        ),
    .dd         ( dd            ),
    .rohvs      ( rohvs         ),
    .rohvck     ( rohvck        ),
    .obj_do     ( obj_do        ),
    .rovi       ( rovi          ),
    .dj         ( dj            ),
    .obj_c      ( obj_c         ),
    .bakc4      ( bakc4         )
);

`ifdef JT2020
wire [ 8:0] rovi20;
wire        rvn2020 = ~rv;
wire [17:0] dj20;
jtpopeye_buf u_2020(
    .rst_n      ( ~rst          ),
    .clk        ( clk           ),
    .H0_cen     ( cen5          ),
    .pxl_cen    ( cen5          ),
    .ROHVS      ( rohvs         ),
    .ROHVCK     ( rohvck        ),
    .RV_n       ( rvn2020       ),
    .H          ( h             ),
    .HB         ( hb            ),
    .V          ( v             ),
    .H2O        ( h20           ),
    .DO         ( obj_do        ),
    .ROVI       ( rovi20        ),
    .DJ         ( dj20          )
);
`endif

integer errors = 0;
task fail(input [8*96-1:0] msg);
begin
    errors = errors + 1;
    if( errors < 30 ) $display("FAIL %0t v=%h h_raw=%h rv=%b: %0s", $time, v, h_raw, rv, msg);
end
endtask

function [17:0] desc_of(input [28:0] d, input [7:0] vv, input c);
    reg [8:0] s;
    begin
        s = { 1'b0, d[15:8] } + { 1'b0, vv } + { 8'd0, c };
        desc_of[0]     = d[27];
        desc_of[3:1]   = s[2:0] ^ {3{d[27]}};
        desc_of[8:4]   = d[20:16];
        desc_of[11:9]  = d[23:21];
        desc_of[13:12] = d[1:0];
        desc_of[16:14] = d[26:24];
        desc_of[17]    = d[28];
    end
endfunction

function inrange(input [7:0] y, input [7:0] vv, input c);
    reg [8:0] s;
    begin
        s = { 1'b0, y } + { 1'b0, vv } + { 8'd0, c };
        inrange = s[7:3] == 0;
    end
endfunction

function [10:0] adr_of(input [9:0] c);
    adr_of = { 1'b1, c[6:4], c[1], ~c[7], ~c[3:2], ~c[0], ~c[9:8] };
endfunction

reg  [28:0] tbl [0:3][0:255];
reg  [28:0] cur [0:255];
integer     sched [0:15];
reg         rvsch [0:15];
integer     ndma = 0, curtbl = -1, i, j, k;

task make_tables;
    reg [28:0] e;
begin
    for( i=0; i<256; i=i+1 ) begin
        e = $random;
        e[15:8] = 8'h08;
        tbl[0][i] = e;
        e = $random;
        e[15:8] = 8'hc0 - ({$random} % 8'h50);
        tbl[1][i] = e;
        e = $random;
        e[15:8] = $random;
        tbl[2][i] = e;
    end
    tbl[0][8'h00] = { 5'h15, 8'h77, 8'h42, 8'h35 };
    tbl[0][8'h01] = { 5'h13, 8'h5a, 8'hc0, 8'h20 };
    tbl[0][8'h05] = { 5'h02, 8'h11, 8'hb0, 8'h81 };
    tbl[0][8'h09] = { 5'h0c, 8'h22, 8'hae, 8'h82 };
    tbl[0][8'h0c] = { 5'h1d, 8'h33, 8'h10, 8'h83 };
    tbl[0][8'h20] = { 5'h01, 8'h66, 8'h90, 8'h00 };
    tbl[0][8'h21] = { 5'h00, 8'h67, 8'h90, 8'h04 };
    tbl[0][8'h9b] = { 5'h07, 8'h44, 8'ha0, 8'hfc };
    for( i=0; i<256; i=i+1 ) tbl[3][i] = tbl[0][i];
    tbl[3][8'h01][15:8] = 8'h40;
    tbl[3][8'h05][15:8] = 8'h50;
    tbl[3][8'h09][15:8] = 8'h52;
    tbl[3][8'h0c][15:8] = 8'hf0;
    tbl[3][8'h20][15:8] = 8'h70;
    tbl[3][8'h21][15:8] = 8'h70;
    tbl[3][8'h9b][15:8] = 8'h60;
end
endtask

task load_wram(input integer t);
begin
    for( i=0; i<2048; i=i+1 ) wram[i] = $random;
    for( i=0; i<256; i=i+1 ) begin
        wram[adr_of({2'd0,i[7:0]})] = tbl[t][i][7:0];
        wram[adr_of({2'd1,i[7:0]})] = tbl[t][i][15:8];
        wram[adr_of({2'd2,i[7:0]})] = tbl[t][i][23:16];
        wram[adr_of({2'd3,i[7:0]})] = { $random } & 8'he0 | tbl[t][i][28:24];
    end
end
endtask

reg busrq_l = 1;
always @(posedge clk) begin
    busrq_l <= busrq_n;
    if( !busrq_n && busrq_l ) load_wram( sched[ndma] );
    if( busrq_n && !busrq_l ) begin
        curtbl = sched[ndma];
        for( i=0; i<256; i=i+1 ) cur[i] = tbl[curtbl][i];
        rv = rvsch[ndma];
        $display("DMA %0d done: table %0d, rv=%b", ndma, curtbl, rv);
        ndma = ndma + 1;
    end
end

reg  [18:0] refb [0:1][0:63];
reg         known[0:1][0:63];
reg  [ 7:0] v_l = 0, vprev = 0;
reg         vbper = 0, rohvck_l = 1, djck_l = 0, chk = 0;
integer     cleanper = 0;
integer     n_wr = 0, n_rd = 0, n_full = 0, n_empty = 0, n_late = 0, n_clr = 0, n_obj = 0, n_rov = 0;
integer     n_ce = 0, n_wr0 = 0, n_wr1 = 0, n_cl0 = 0, n_cl1 = 0, n_flip = 0, n_ref = 0, n_tab = 0;
integer     wb, rb, slot, prevdm = -1;
reg  [17:0] dsc, exp_dj;
reg  [ 7:0] y0;
reg  [ 8:0] s9;

always @(posedge clk) if( !rst ) begin
    v_l      <= v;
    rohvck_l <= rohvck;
    if( v != v_l ) begin
        if( vbper || vb ) cleanper = 0; else cleanper = cleanper + 1;
        vbper  = vb;
        vprev <= v_l;
    end
    if( vb ) vbper = 1;
    chk = cleanper >= 3 && curtbl >= 0 && !vb;

    if( cen5 && h_raw[0] ) begin
        wb = v[0] ? 0 : 1;
        if( !rohvs && inrange( obj_do[15:8], v, rohvck ^ rv ) ) begin
            refb[wb][obj_do[7:2]] = { 1'b1, desc_of( obj_do, v, rohvck ^ rv ) };
            n_wr = n_wr + 1;
        end
        if( !vb && busak_n && curtbl >= 0 ) begin
            n_obj = n_obj + 1;
            if( obj_do !== cur[dm] ) fail("obj_do differs from the DMA'd table");
            if( !rohvs && rohvck !== 1'b1 ) fail("rohvck low during the scan");
        end
    end

    if( cen5 && h_raw[1:0]==2'b01 ) begin
        rb   = v[0] ? 1 : 0;
        slot = { h[7:3], h20 };
        if( rv && slot != (~h_raw[7:2] & 6'h3f) ) fail("flipped read address");
        if( !rv && slot != h_raw[7:2] ) fail("read address");
        if( rv ) n_flip = n_flip + 1;
        if( chk && known[rb][slot] ) begin
            n_rd = n_rd + 1;
            if( refb[rb][slot][18] ) begin
                n_full = n_full + 1;
                if( dj !== ~refb[rb][slot][17:0] ) begin
                    fail("dj differs from the reference descriptor");
                    $display("      slot %0d dj=%h exp=%h", slot, dj, ~refb[rb][slot][17:0]);
                end
            end else begin
                n_empty = n_empty + 1;
                if( dj[16:14] !== 3'b111 ) fail("empty slot does not read colour 111");
            end
        end
        if( !hb ) begin
            refb[rb][slot]  = 0;
            known[rb][slot] = 1;
        end
    end

    if( uut.wr0 ) begin
        if( v[0] ) begin
            n_wr0 = n_wr0 + 1;
            if( !( h[0] && uut.q4b ) ) fail("buffer 0 write outside the N2 window");
        end else begin
            n_cl0 = n_cl0 + 1;
            if( !( h[1] && !hb && !( h[0] && uut.q4b ) ) ) fail("buffer 0 clear outside the N1 window");
            if( uut.din0[16:14] !== 0 ) fail("buffer 0 clear with colour");
        end
    end
    if( uut.wr1 ) begin
        if( !v[0] ) begin
            n_wr1 = n_wr1 + 1;
            if( !( h[0] && uut.q4b ) ) fail("buffer 1 write outside the N2 window");
        end else begin
            n_cl1 = n_cl1 + 1;
            if( !( h[1] && !hb && !( h[0] && uut.q4b ) ) ) fail("buffer 1 clear outside the N1 window");
            if( uut.din1[16:14] !== 0 ) fail("buffer 1 clear with colour");
        end
    end

    djck_l <= uut.djck;
    if( uut.djck && !djck_l ) begin
        if( v[0] ? !uut.ce0_l : !uut.ce1_l ) n_ce = n_ce + 1;
        if( h_raw[1:0] != 2'b01 ) fail("DJ latched outside dot 4k+1");
    end

    if( rohvck && !rohvck_l && busak_n && curtbl >= 0 ) begin
        n_rov = n_rov + 1;
        y0 = cur[0][15:8];
        s9 = { 1'b0, y0 } + { 1'b0, v } + { 8'd0, rv };
        if( prevdm != 0 ) fail("ROHVCK low not on DM 0");
        if( rovi !== s9[8:1] ) begin
            fail("rovi at ROHVCK rise");
            $display("      rovi=%h exp=%h", rovi, s9[8:1]);
        end
    end
    if( !rohvck && rohvck_l ) prevdm = dm;
end

reg rohvck_ll = 1;
always @(posedge clk) begin
    rohvck_ll <= rohvck_l;
    if( !rst && curtbl >= 0 && rohvck_l && !rohvck_ll && busak_n )
        if( { bakc4, obj_c } !== cur[0][27:24] ) fail("3U colour latch");
end

integer ln_ok = 0, ln_cnt = 0;
reg [17:0] want [0:63];
reg        wantv[0:63];
reg        lin_chk = 0;
always @(posedge clk) if( !rst ) begin
    if( v != v_l ) lin_chk = 0;
    if( v != v_l && chk && (curtbl==0 || curtbl==3) ) begin
        for( k=0; k<64; k=k+1 ) wantv[k] = 0;
        for( j=8'h9b; j<8'h9b+8'h9f; j=j+1 ) begin
            k = j > 8'h9f ? j - 8'h9f : j;
            if( inrange( cur[k][15:8], v_l, ~rv ) ) begin
                wantv[cur[k][7:2]] = 1;
                want [cur[k][7:2]] = desc_of( cur[k], v_l, ~rv );
            end
        end
        lin_chk = 1;
    end
    if( cen5 && h_raw[1:0]==2'b01 && !hb && lin_chk && chk ) begin
        slot = { h[7:3], h20 };
        n_tab = n_tab + 1;
        exp_dj = wantv[slot] ? ~want[slot] : dj;
        if( wantv[slot] ? dj !== exp_dj : dj[16:14] !== 3'b111 ) begin
            fail("table-only expectation");
            $display("      slot %0d dj=%h exp=%h valid=%b", slot, dj, exp_dj, wantv[slot]);
        end
        if( curtbl==0 && v==8'h53 && slot==6'h20 && !rv ) begin
            $display("line V=53 slot 20h: dj=%h (~dj=%h) -> DM9 sprite B %s", dj, ~dj,
                dj === ~desc_of(cur[9], vprev, 1'b1) ? "WINS over A (DM5); C (DM0C, out of range) did not overwrite" : "WRONG");
            if( dj !== ~desc_of(cur[9], vprev, 1'b1) ) fail("later sprite did not win");
            ln_ok = ln_ok + 1;
        end
        if( curtbl==0 && v==8'h48 && slot==6'h08 && !rv ) begin
            $display("line V=48 slot 08h: dj[16:14]=%b (sprite S1 ended at V=47: slot read back cleared)", dj[16:14]);
            if( dj[16:14] !== 3'b111 ) fail("slot not cleared after read");
            ln_ok = ln_ok + 1;
        end
        if( curtbl==0 && v==8'h70 && (slot==0 || slot==1) && !rv ) begin
            $display("line V=70 slot %0d: dj=%h colour=%b (table colour %0d)", slot, dj, dj[16:14], slot==0 ? 1 : 0);
            ln_ok = ln_ok + 1;
        end
        if( curtbl==0 && v==8'h60 && slot==63 && !rv ) begin
            $display("line V=60 slot 63: dj=%h colour bits=%b (table colour 7 stores 111 -> reads 000)", dj, dj[16:14]);
            ln_ok = ln_ok + 1;
        end
    end
end

`ifdef JT2020
integer n20 = 0, e20 = 0, e20row = 0, e20oth = 0;
reg [17:0] mine, theirs;
always @(posedge clk) if( !rst ) begin
    if( cen5 && h_raw[1:0]==2'b11 && !hb && chk ) begin
        n20    = n20 + 1;
        mine   = ~dj;
        theirs = dj20;
        if( mine[16:14] != 0 || theirs[16:14] != 0 ) begin
            if( mine != theirs ) begin
                e20 = e20 + 1;
                if( mine[3:1] != theirs[3:1] ) e20row = e20row + 1;
                if( { mine[17:4], mine[0] } != { theirs[17:4], theirs[0] } ) e20oth = e20oth + 1;
                if( e20 < 6 ) $display("2020 diff v=%h slot=%0d mine(~dj)=%h 2020=%h", v, {h[7:3],h20}, mine, theirs);
            end
        end
    end
end
`endif

initial begin
    make_tables;
    for( i=0; i<256; i=i+1 ) wram[i] = 0;
    sched[0] = 0; rvsch[0] = 0;
    sched[1] = 1; rvsch[1] = 0;
    sched[2] = 2; rvsch[2] = 0;
    sched[3] = 3; rvsch[3] = 1;
    sched[4] = 1; rvsch[4] = 1;
    sched[5] = 2; rvsch[5] = 1;
    sched[6] = 0; rvsch[6] = 0;
    sched[7] = 1; rvsch[7] = 0;
    for( i=8; i<16; i=i+1 ) begin sched[i] = 2; rvsch[i] = 0; end
    for( i=0; i<2; i=i+1 ) for( j=0; j<64; j=j+1 ) begin refb[i][j] = 0; known[i][j] = 0; end
    #200 rst = 0;
    wait( ndma == NFIELDS-1 );
    @(posedge vb);
    $display("scan samples checked against the table: %0d, buffer writes in reference: %0d", n_obj, n_wr);
    $display("slot reads checked: %0d (%0d with a sprite, %0d empty), %0d of them flipped", n_rd, n_full, n_empty, n_flip);
    $display("table-only slot checks: %0d, explicit line checks printed: %0d", n_tab, ln_ok);
    $display("write strobes: buffer0 %0d (V0=1) clear %0d (V0=0); buffer1 %0d (V0=0) clear %0d (V0=1)", n_wr0, n_cl0, n_wr1, n_cl1);
    $display("ROHVCK rises checked (rovi/3U): %0d; DJ latches with the write buffer enabled the clk before: %0d", n_rov, n_ce);
`ifdef JT2020
    $display("2020 jtpopeye_buf (RV_n=%0s): %0d occupied-slot compares, %0d differ (%0d in the row bits DJ1-3, %0d elsewhere)",
        "~rv", n20, e20, e20row, e20oth);
`endif
    if( n_ce != 0 ) fail("write buffer drove DJI at a latch edge");
    if( ln_ok < 4 || n_full < 1000 || n_empty < 1000 || (NFIELDS > 5 && n_flip < 1000) || n_tab < 1000 ) fail("coverage too low");
    if( errors == 0 ) $display("PASS");
    else $display("FAIL: %0d errors", errors);
    $finish;
end

initial begin
    repeat(20000000) @(posedge clk);
    $fatal(1,"FAIL bounded simulation timeout");
end
initial begin
    $dumpfile("test.lxt"); $dumpvars(1,uut);
    repeat(2048) @(posedge clk); $dumpoff;
end
endmodule
