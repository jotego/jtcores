`include "fixtures.vh"
`timescale 1ps/1ps

module test;


reg         clk=0, rst=1, rv=0;
reg         cen5=0, cen10=0, cen20=0;
integer     acc=0;
reg  [ 1:0] div=0;

wire [ 7:0] tprom_addr, tprom_q, h_raw, h, v;
wire        hb, h20, vb, hbd_n, ai_n, bi_n, initeo, sy_n, hs, vs, lhbl, lvbl;
wire        initeo_b = ~initeo;
wire [ 1:0] h01 = h_raw[1:0];

wire [12:1] a0, a1, a2, a3;
wire [15:0] d0, d1, d2, d3;
wire [ 1:0] obj_v, obj_v_b;
wire [ 2:0] obj_c, obj_c_b;
reg  [17:0] dj=18'h3ffff;

reg  [ 7:0] r0[0:8191], r1[0:8191], r2[0:8191], r3[0:8191];
reg  [17:0] slot[0:63];
localparam  NQ=1280;
reg  [ 1:0] exp_v  [0:NQ-1], exp_vb[0:NQ-1];
reg  [ 2:0] exp_c  [0:NQ-1];
reg  [ 1:0] got_v  [0:511], got_20[0:511];

integer     fd, i, k, p, errs=0, errs_b=0, errs_a=0, errs_w=0, checked=0, lines=0, fields=0;
integer     lone_k, lone_x, lone_first, lone_last, lone_n=0, flipped_n=0, empty_n=0;
integer     off, mm[0:12], tot20=0, mml=0, totl=0;
reg         hb_l=0, vb_l=0, cen20_l=0, cen20_ll=0, lone=0;
reg  [ 1:0] ph=0;
integer     q;
reg  [ 7:0] h_raw_l=0;
reg  [ 1:0] eo_seen=0;
integer     seed=7;

initial forever #10417 clk = ~clk;

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

jtframe_prom #(.DW(8),.AW(13),.SIMFILE(`ROM1E)) u_1elo(.clk(clk),.cen(1'b1),.data(8'd0),.rd_addr({a0,1'b0}),.wr_addr(13'd0),.we(1'b0),.q(d0[7:0]));
jtframe_prom #(.DW(8),.AW(13),.SIMFILE(`ROM1E)) u_1ehi(.clk(clk),.cen(1'b1),.data(8'd0),.rd_addr({a0,1'b1}),.wr_addr(13'd0),.we(1'b0),.q(d0[15:8]));
jtframe_prom #(.DW(8),.AW(13),.SIMFILE(`ROM1F)) u_1flo(.clk(clk),.cen(1'b1),.data(8'd0),.rd_addr({a1,1'b0}),.wr_addr(13'd0),.we(1'b0),.q(d1[7:0]));
jtframe_prom #(.DW(8),.AW(13),.SIMFILE(`ROM1F)) u_1fhi(.clk(clk),.cen(1'b1),.data(8'd0),.rd_addr({a1,1'b1}),.wr_addr(13'd0),.we(1'b0),.q(d1[15:8]));
jtframe_prom #(.DW(8),.AW(13),.SIMFILE(`ROM1J)) u_1jlo(.clk(clk),.cen(1'b1),.data(8'd0),.rd_addr({a2,1'b0}),.wr_addr(13'd0),.we(1'b0),.q(d2[7:0]));
jtframe_prom #(.DW(8),.AW(13),.SIMFILE(`ROM1J)) u_1jhi(.clk(clk),.cen(1'b1),.data(8'd0),.rd_addr({a2,1'b1}),.wr_addr(13'd0),.we(1'b0),.q(d2[15:8]));
jtframe_prom #(.DW(8),.AW(13),.SIMFILE(`ROM1K)) u_1klo(.clk(clk),.cen(1'b1),.data(8'd0),.rd_addr({a3,1'b0}),.wr_addr(13'd0),.we(1'b0),.q(d3[7:0]));
jtframe_prom #(.DW(8),.AW(13),.SIMFILE(`ROM1K)) u_1khi(.clk(clk),.cen(1'b1),.data(8'd0),.rd_addr({a3,1'b1}),.wr_addr(13'd0),.we(1'b0),.q(d3[15:8]));

jtpopeye_obj uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen20      ( cen20         ),
    .cen10      ( cen10         ),
    .cen5       ( cen5          ),
    .h          ( h01           ),
    .hb         ( hb            ),
    .vb         ( vb            ),
    .rv         ( rv            ),
    .initeo     ( initeo        ),
    .dj         ( dj            ),
    .obj0_addr  ( a0            ),
    .obj0_data  ( d0            ),
    .obj1_addr  ( a1            ),
    .obj1_data  ( d1            ),
    .obj2_addr  ( a2            ),
    .obj2_data  ( d2            ),
    .obj3_addr  ( a3            ),
    .obj3_data  ( d3            ),
    .obj_v      ( obj_v         ),
    .obj_c      ( obj_c         )
);

jtpopeye_obj uut_b(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen20      ( cen20         ),
    .cen10      ( cen10         ),
    .cen5       ( cen5          ),
    .h          ( h01           ),
    .hb         ( hb            ),
    .vb         ( vb            ),
    .rv         ( rv            ),
    .initeo     ( initeo_b      ),
    .dj         ( dj            ),
    .obj0_addr  (               ),
    .obj0_data  ( d0            ),
    .obj1_addr  (               ),
    .obj1_data  ( d1            ),
    .obj2_addr  (               ),
    .obj2_data  ( d2            ),
    .obj3_addr  (               ),
    .obj3_data  ( d3            ),
    .obj_v      ( obj_v_b       ),
    .obj_c      ( obj_c_b       )
);

wire [12:0] a20;
wire [12:0] a20n = ~a20;
reg  [15:0] q20_0=0, q20_1=0;
wire [ 2:0] objc20;
wire [ 1:0] objv20;
wire [17:0] dj20 = ~dj;

always @(posedge clk) begin
    q20_0 <= { r2[a20n], r3[a20n] };
    q20_1 <= { r0[a20n], r1[a20n] };
end

jtpopeye_obj_2020 u_2020(
    .rst_n      ( ~rst          ),
    .clk        ( clk           ),
    .pxl_cen    ( cen5          ),
    .pxl2_cen   ( cen10         ),
    .ROHVS      ( 1'b0          ),
    .ROHVCK     ( 1'b0          ),
    .RV_n       ( ~rv           ),
    .INITEO     ( initeo        ),
    .HB         ( hb            ),
    .VB         ( vb            ),
    .H          ( h_raw         ),
    .DJ         ( dj20          ),
    .obj_addr   ( a20           ),
    .obj_data0  ( q20_0         ),
    .obj_data1  ( q20_1         ),
    .OBJC       ( objc20        ),
    .OBJV       ( objv20        )
);

task load_rom( input [8*256-1:0] fname, input integer which );
    integer f, n, j;
    reg [7:0] buffer[0:8191];
    begin
        f = $fopen(fname,"rb");
        if( f==0 ) begin $display("ERROR cannot open %0s", fname); $finish(1); end
        n = $fread(buffer, f);
        $fclose(f);
        for( j=0; j<8192; j=j+1 ) case(which)
            0: r0[j] = buffer[j];
            1: r1[j] = buffer[j];
            2: r2[j] = buffer[j];
            default: r3[j] = buffer[j];
        endcase
    end
endtask

function [12:0] rom_addr( input [17:0] d, input eo_in );
    reg [17:0] q;
    begin
        q = ~d;
        rom_addr = { q[16], q[17], q[10:1], q[0] ^ ~eo_in };
    end
endfunction

function [1:0] pixel( input [17:0] d, input eo_in, input rvi, input integer n );
    reg [17:0] q;
    reg [12:0] a;
    integer    j;
    begin
        q = ~d;
        a = rom_addr( d, eo_in );
        j = (q[11] ^ rvi) ? n : 15-n;
        pixel = j < 8 ? { r1[a][j], r3[a][j] } : { r0[a][j-8], r2[a][j-8] };
    end
endfunction

task model( input eo_in, output integer first_start );
    integer kk, s, fx, dot, q, n, dir, pdir;
    reg [17:0] d;
    begin
        first_start = -1;
        pdir = -1;
        for( q=0; q<NQ; q=q+1 ) begin
            exp_v[q] = 0; exp_c[q] = 0; exp_vb[q] = 0;
        end
        for( kk=0; kk<64; kk=kk+1 ) begin
            s = rv ? 63-kk : kk;
            d = slot[s];
            if( d[16:14] != 0 ) begin
                fx  = rv ? 3-d[13:12] : d[13:12];
                dot = 4*kk + 4 + fx;
                if( first_start < 0 ) first_start = 4*dot+1;
                dir = (d[11] ^ rv) ? 0 : 1;
                if( pdir >= 0 && pdir != dir && 4*dot < NQ ) begin
                    exp_v [4*dot] = 0;
                    exp_vb[4*dot] = 0;
                end
                pdir = dir;
                for( q=4*dot; q<NQ; q=q+1 ) exp_c[q] = d[16:14];
                for( q=4*dot+1; q<NQ; q=q+1 ) begin
                    n = (q-4*dot-1)/2;
                    exp_v [q] = n<16 ? pixel( d,  eo_in, rv, n ) : 2'd0;
                    exp_vb[q] = n<16 ? pixel( d, ~eo_in, rv, n ) : 2'd0;
                end
            end
        end
    end
endtask

task new_table;
    integer kk, r, j, fs;
    reg [17:0] d;
    reg [12:0] a;
    begin
        lone = (lines % 7) == 3;
        if( lone ) begin
            for( kk=0; kk<64; kk=kk+1 ) slot[kk] = { 1'b0, 3'd0, 14'h0 };
            lone_k = 2 + ($unsigned($random(seed)) % 56);
            lone_x = $unsigned($random(seed)) % 4;
            for( j=0; j<20000; j=j+1 ) begin
                a = $random(seed);
                if( (r3[a][0] | r1[a][0]) && (r2[a][7] | r0[a][7]) && a[12] ) j = 30000;
            end
            d[0]     = ~(a[0] ^ ~initeo);
            d[10:1]  = ~a[10:1];
            d[17]    = ~a[11];
            d[16]    = ~a[12];
            d[15:14] = 2'b11 ^ ($unsigned($random(seed)) % 3);
            d[11]    = $random(seed);
            d[13:12] = lone_x;
            slot[ rv ? 63-lone_k : lone_k ] = d;
            if( d[11] ) flipped_n = flipped_n + 1;
        end else begin
            for( kk=0; kk<64; kk=kk+1 ) begin
                d = $random(seed);
                if( ($unsigned($random(seed)) % 3) == 0 ) begin
                    d[16:14] = 0;
                    empty_n = empty_n + 1;
                end
                slot[kk] = d;
            end
        end
        model( initeo, fs );
        lone_first = -1;
        lone_last  = -1;
    end
endtask

always @(posedge clk) begin
    hb_l     <= hb;
    h_raw_l  <= h_raw;
    cen20_l  <= cen20;
    cen20_ll <= cen20_l;
    if( cen5 ) ph <= 0; else if( cen20 ) ph <= ph + 2'd1;
    if( !rst ) begin
        if( hb && !hb_l ) begin
            if( lone && !vb ) begin
                if( lone_first != 4*(4*lone_k+4+(rv ? 3-lone_x : lone_x))+1 || lone_last != lone_first+31 ) begin
                    errs_w = errs_w + 1;
                    $display("ERROR lone sprite k=%0d x=%0d rv=%0d: first %0d last %0d", lone_k, lone_x, rv, lone_first, lone_last);
                end else lone_n = lone_n + 1;
            end
            if( !vb ) for( off=-6; off<=6; off=off+1 ) begin
                for( p=8; p<504; p=p+1 ) if( got_v[p] != got_20[p+off] ) mm[off+6] = mm[off+6] + 1;
            end
            if( !vb ) tot20 = tot20 + 496;
            if( !vb && lone ) begin
                totl = totl + 496;
                for( p=8; p<504; p=p+1 ) if( got_v[p] != got_20[p+2] ) mml = mml + 1;
            end
            lines = lines + 1;
            new_table;
        end
        if( h_raw != h_raw_l && h_raw[1:0] == 2'd1 ) dj <= ~slot[{ h[7:3], h20 }];
        if( a0 != a1 || a0 != a2 || a0 != a3 ) errs_a = errs_a + 1;
        if( uut.addr[12:1] != uut_b.addr[12:1] || uut.addr[0] == uut_b.addr[0] ) errs_a = errs_a + 1;
        if( cen20_ll && !hb ) begin
            q = 4*h_raw + ph;
            if( ph[0] ) begin
                p = 2*h_raw + ph[1];
                got_v [p] = obj_v;
                got_20[p] = objv20;
            end
            checked = checked + 1;
            if( obj_v != (vb_l ? 2'd0 : exp_v[q]) || (obj_v != 0 && obj_c != exp_c[q]) ) begin
                errs = errs + 1;
                if( errs < 10 ) $display("ERROR v=%0d q=%0d rv=%0d eo=%0d: obj_v %0d exp %0d  obj_c %0d exp %0d",
                    v, q, rv, initeo, obj_v, vb_l ? 0 : exp_v[q], obj_c, exp_c[q]);
            end
            if( obj_v_b != (vb_l ? 2'd0 : exp_vb[q]) || (obj_v_b != 0 && obj_c_b != exp_c[q]) ) errs_b = errs_b + 1;
            if( obj_v != 0 ) begin
                if( lone_first < 0 ) lone_first = q;
                lone_last = q;
            end
        end
    end
end

always @(posedge clk) vb_l <= vb;

initial begin
    for( off=0; off<13; off=off+1 ) mm[off] = 0;
    load_rom( `ROM1E, 0 );
    load_rom( `ROM1F, 1 );
    load_rom( `ROM1J, 2 );
    load_rom( `ROM1K, 3 );
    for( i=0; i<64; i=i+1 ) slot[i] = 0;
    for( i=0; i<NQ; i=i+1 ) begin exp_v[i]=0; exp_c[i]=0; exp_vb[i]=0; end
    repeat(40) @(posedge clk);
    rst = 0;
    while( fields < 7 ) begin
        @(posedge vb);
        fields = fields + 1;
        eo_seen[initeo] = 1;
        if( fields == 4 ) rv = 1;
        $display("field %0d: initeo=%0d rv=%0d lines=%0d checked=%0d errs=%0d errs_b=%0d", fields, initeo, rv, lines, checked, errs, errs_b);
    end
    $display("lone-sprite lines checked: %0d (h-flipped %0d), empty slots generated: %0d", lone_n, flipped_n, empty_n);
    $display("2020 module, mismatches of its OBJV vs ours by pixel offset (10 MHz px), %0d px per offset:", tot20);
    for( off=-6; off<=6; off=off+1 ) $display("  offset %3d: %0d", off, mm[off+6]);
    $display("  lone-sprite lines only, offset 2: %0d of %0d", mml, totl);
    if( errs==0 && errs_b==0 && errs_a==0 && errs_w==0 && lone_n>0 && eo_seen==2'b11 && checked>0 ) begin
        $display("PASS");
        $finish;
    end else begin
        $display("FAIL errs=%0d errs_b=%0d errs_a=%0d errs_w=%0d eo_seen=%b", errs, errs_b, errs_a, errs_w, eo_seen);
        $finish(1);
    end
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
