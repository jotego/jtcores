`include "fixtures.vh"
`timescale 1ps/1ps

module test;


reg         clk=0, rst=1;
reg         cen20=0, cen10=0, cen5=0;
integer     acc=0;
reg  [ 1:0] div=0;

reg         txtv=1;
reg  [ 3:0] txtc=0;
reg  [ 1:0] obj_v=0;
reg  [ 5:0] obj_c=0;
reg  [ 4:0] bakc=0;
reg  [ 3:0] gfx_en=4'hf;

wire [ 7:0] tprom_addr, tprom_q;
wire [ 7:0] h_raw, h, v;
wire        hb, h20, vb, hbd_n, ai_n, bi_n, initeo, sy_n, hs, vs, lhbl, lvbl;

wire [ 4:0] txtpal_addr, bgpal_addr;
wire [ 7:0] objpall_addr, objpalh_addr;
wire [ 7:0] txtpal_data, bgpal_data, objpall_q, objpalh_q;
wire [ 3:0] objpall_data = objpall_q[3:0];
wire [ 3:0] objpalh_data = objpalh_q[3:0];
wire [ 7:0] red, green, blue;
wire        LHBL, LVBL;

reg  [ 7:0] p3a[0:31], p4a[0:31], p5a[0:255], p5b[0:255];
integer     fd, nrd;

integer     errors=0, checks=0, npix=0, nvis=0, i;
integer     hit_txt=0, hit_obj=0, hit_bak=0, hit_none=0, hit_blank=0;
reg         seen3a[0:31], seen4a[0:31], seen5b[0:255];
reg  [23:0] exp_rgb[0:3];
reg         exp_hb[0:3], exp_vb[0:3];
reg         run=0, compare2020=0;

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

jtframe_prom #(.DW(8),.AW(8),.SIMFILE(`P7J)) u_7j(
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
    .rv         ( 1'b0          ),
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

jtframe_prom #(.DW(8),.AW(5),.SIMFILE(`P3A)) u_3a(
    .clk(clk), .cen(1'b1), .data(8'd0), .rd_addr(txtpal_addr), .wr_addr(5'd0), .we(1'b0), .q(txtpal_data) );
jtframe_prom #(.DW(8),.AW(5),.SIMFILE(`P4A)) u_4a(
    .clk(clk), .cen(1'b1), .data(8'd0), .rd_addr(bgpal_addr), .wr_addr(5'd0), .we(1'b0), .q(bgpal_data) );
jtframe_prom #(.DW(8),.AW(8),.SIMFILE(`P5B)) u_5b(
    .clk(clk), .cen(1'b1), .data(8'd0), .rd_addr(objpall_addr), .wr_addr(8'd0), .we(1'b0), .q(objpall_q) );
jtframe_prom #(.DW(8),.AW(8),.SIMFILE(`P5A)) u_5a(
    .clk(clk), .cen(1'b1), .data(8'd0), .rd_addr(objpalh_addr), .wr_addr(8'd0), .we(1'b0), .q(objpalh_q) );

jtpopeye_colmix uut(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .pxl_cen        ( cen10         ),
    .hbd_n          ( hbd_n         ),
    .vb             ( vb            ),
    .lhbl           ( lhbl          ),
    .lvbl           ( lvbl          ),
    .txtv           ( txtv          ),
    .txtc           ( txtc          ),
    .obj_v          ( obj_v         ),
    .obj_c          ( obj_c         ),
    .bakc           ( bakc          ),
    .boot           ( 1'b0          ),
    .tnx1           ( 1'b0          ),
    .txtpal_addr    ( txtpal_addr   ),
    .txtpal_data    ( txtpal_data   ),
    .bgpal_addr     ( bgpal_addr    ),
    .bgpal_data     ( bgpal_data    ),
    .objpall_addr   ( objpall_addr  ),
    .objpall_data   ( objpall_data  ),
    .objpalh_addr   ( objpalh_addr  ),
    .objpalh_data   ( objpalh_data  ),
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .gfx_en         ( gfx_en        )
);

wire [2:0] r2020, g2020;
wire [1:0] b2020;
wire       lhbl2020, lvbl2020;

jtpopeye_colmix_2020 u_2020(
    .rst_n      ( ~rst          ),
    .clk        ( clk           ),
    .pxl2_cen   ( cen10         ),
    .gfx_en     ( 3'b111        ),
    .prog_addr  ( 8'd0          ),
    .prom_4a_we ( 1'b0          ),
    .prom_5b_we ( 1'b0          ),
    .prom_5a_we ( 1'b0          ),
    .prom_3a_we ( 1'b0          ),
    .prom_din   ( 8'd0          ),
    .HBD_n      ( 1'b1          ),
    .VB_n       ( 1'b1          ),
    .LHBL_dly   ( lhbl2020      ),
    .LVBL_dly   ( lvbl2020      ),
    .bakc       ( bakc          ),
    .objc       ( obj_c         ),
    .objv       ( obj_v         ),
    .txtc       ( txtc          ),
    .txtv       ( txtv          ),
    .red        ( r2020         ),
    .green      ( g2020         ),
    .blue       ( b2020         )
);

// The 2020 core's colours: the inverted 3/3/2 PROM bits widened by bit repetition
function [23:0] pal_rgb( input [7:0] d );
    pal_rgb = { {2{~d[2:0]}}, ~d[2:1], {2{~d[5:3]}}, ~d[5:4], {4{~d[7:6]}} };
endfunction

reg        t_n, cs3a_n, cs4a_n, cs5b1, cs5b2, en5b, spr;
reg  [7:0] dnode;
reg  [1:0] objv_e;
reg [23:0] ref_rgb;

always @* begin
    t_n    = gfx_en[0] ? txtv : 1'b1;
    objv_e = gfx_en[3] ? obj_v : 2'b00;
    spr    = ~(objv_e[0] | objv_e[1]);
    cs3a_n = t_n;
    cs4a_n = ~(t_n & spr & hbd_n & ~vb & gfx_en[1]);
    cs5b1  = spr;
    cs5b2  = ~t_n;
    en5b   = ~cs5b1 & ~cs5b2;
    dnode  = 8'hff;
    ref_rgb= 24'd0;
    if( !cs3a_n ) ref_rgb = pal_rgb( p3a[{txtc[3],txtc}] );
    if( en5b    ) ref_rgb = pal_rgb( { p5a[{obj_c,obj_v}][3:0], p5b[{obj_c,obj_v}][3:0] } );
    if( !cs4a_n ) ref_rgb = pal_rgb( p4a[bakc] );
end

always @(posedge clk) if( cen10 && run ) begin
    exp_rgb[0] <= (lhbl & lvbl) ? ref_rgb : 24'd0;
    exp_hb[0]  <= lhbl;
    exp_vb[0]  <= lvbl;
    for( i=1; i<4; i=i+1 ) begin
        exp_rgb[i] <= exp_rgb[i-1];
        exp_hb[i]  <= exp_hb[i-1];
        exp_vb[i]  <= exp_vb[i-1];
    end
    npix <= npix + 1;
    if( lhbl & lvbl ) begin
        nvis <= nvis+1;
        if( !cs3a_n ) begin hit_txt <= hit_txt+1; seen3a[{txtc[3],txtc}] <= 1; end
        else if( en5b ) begin hit_obj <= hit_obj+1; seen5b[{obj_c,obj_v}] <= 1; end
        else if( !cs4a_n ) begin hit_bak <= hit_bak+1; seen4a[bakc] <= 1; end
        else hit_none <= hit_none+1;
    end else hit_blank <= hit_blank+1;
end

always @(negedge clk) if( cen10 && run && npix>4 ) begin
    checks = checks+1;
    if( {red,green,blue} !== exp_rgb[2] || LHBL !== exp_hb[2] || LVBL !== exp_vb[2] ) begin
        errors = errors+1;
        if( errors<20 ) $display("ERROR pix %0d: rgb %06X LHBL %b LVBL %b, expected %06X %b %b",
            npix, {red,green,blue}, LHBL, LVBL, exp_rgb[2], exp_hb[2], exp_vb[2]);
    end
end

always @(negedge clk) if( cen10 && run && !compare2020 ) begin
    txtv  <= $random % 3 != 0;
    txtc  <= $random;
    obj_v <= $random;
    obj_c <= $random;
    bakc  <= $random;
    if( ($random & 63)==0 ) gfx_en <= $random; else if( ($random & 15)==0 ) gfx_en <= 4'hf;
end

task check(input [23:0] got, input [23:0] want, input [255:0] what);
    begin
        checks = checks+1;
        if( got !== want ) begin
            errors = errors+1;
            $display("ERROR %0s: got %06X expected %06X", what, got, want);
        end
    end
endtask

integer k, mism2020=0, cmp2020=0;
reg [7:0] raw2020, rawnew;

initial begin
    fd=$fopen(`P3A,"rb"); nrd=$fread(p3a,fd); $fclose(fd);
    fd=$fopen(`P4A,"rb"); nrd=$fread(p4a,fd); $fclose(fd);
    fd=$fopen(`P5A,"rb"); nrd=$fread(p5a,fd); $fclose(fd);
    fd=$fopen(`P5B,"rb"); nrd=$fread(p5b,fd); $fclose(fd);
    for( k=0; k<256; k=k+1 ) seen5b[k]=0;
    for( k=0; k<32; k=k+1 ) begin seen3a[k]=0; seen4a[k]=0; end

    repeat(20) @(posedge clk);
    check( {red,green,blue}, 24'd0, "rgb during reset" );
    check( {22'd0, uut.sel}, 24'd0, "sel during reset" );
    check( {16'd0, uut.pal}, 24'h0000ff, "pal during reset (all outputs open)" );
    rst = 0;
    run = 1;
    wait( u_timing.vb ); wait( !u_timing.vb ); wait( u_timing.vb ); wait( !u_timing.vb );
    $display("random run over one field + VB: %0d pixels, %0d visible, %0d blank", npix, nvis, hit_blank);
    $display("visible pixels: text %0d, sprite %0d, background %0d, none (black) %0d", hit_txt, hit_obj, hit_bak, hit_none);
    nrd=0; for( k=0; k<32; k=k+1 ) if( !seen3a[k] && (k[4]==k[3]) ) nrd=nrd+1;
    if( nrd ) begin errors=errors+1; $display("ERROR 3A: %0d reachable addresses never used", nrd); end
    nrd=0; for( k=0; k<32; k=k+1 ) if( !seen4a[k] ) nrd=nrd+1;
    if( nrd ) begin errors=errors+1; $display("ERROR 4A: %0d addresses never used", nrd); end
    nrd=0; for( k=0; k<256; k=k+1 ) if( !seen5b[k] && k[1:0]!=0 ) nrd=nrd+1;
    if( nrd ) begin errors=errors+1; $display("ERROR 5B/5A: %0d sprite addresses never used", nrd); end
    if( hit_txt==0 || hit_obj==0 || hit_bak==0 || hit_none==0 ) begin errors=errors+1; $display("ERROR layer coverage"); end
    compare2020 = 1;
    gfx_en = 4'hf;
    @(negedge clk);
    for( k=0; k<4096; k=k+1 ) begin
        @(negedge clk);
        txtv  = k[0];
        txtc  = k[4:1];
        obj_v = k[6:5];
        obj_c = {k[11:7], k[2]};
        bakc  = k[11:7];
        nrd = 0;
        while( nrd<8 ) begin
            @(posedge cen10);
            nrd = (hbd_n & ~vb) ? nrd+1 : 0;
        end
        rawnew  = ~uut.pal;
        raw2020 = { b2020, g2020, r2020 };
        cmp2020 = cmp2020+1;
        if( rawnew !== raw2020 ) begin
            mism2020 = mism2020+1;
            if( mism2020<10 ) $display("2020 diff: txtv %b objv %0d -> new %02X 2020 %02X", txtv, obj_v, rawnew, raw2020);
        end
    end
    $display("2020 colmix comparison (3/3/2 PROM bits, inverted, visible area): %0d cases, %0d differences", cmp2020, mism2020);
    if( mism2020 ) errors = errors+1;

    $display("%0d checks, %0d errors", checks, errors);
    if( errors==0 ) begin $display("PASS"); $finish; end
    else begin $display("FAIL"); $fatal(1); end
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
