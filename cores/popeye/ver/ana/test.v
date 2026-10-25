`include "fixtures.vh"
`timescale 1ps/1ps

module test;


localparam [1:0] DEFL  = `DEFL;
localparam       NARROW = `NARROW;
localparam integer HPOS = `HPOS;
localparam integer VPOS = `VPOS;
localparam integer NFIELDS = 4;

reg         clk=0, rst=1;
reg         cen20=0, cen5=0, cen10=0;
integer     acc=0;
reg  [ 1:0] div=0;

wire [ 7:0] tprom_addr, tprom_q, h_raw, h, v, vcnt, vlatch;
wire [ 3:0] tprom_data = tprom_q[3:0];
wire        hb, h20, vb_t, hbd_n_t, ai_n, bi_n, initeo, sy_n, hs, vs, lhbl, lvbl, vtick, vhalf;

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

jtpopeye_timing u_timing(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen5       ( cen5          ),
    .cen10      ( cen10         ),
    .rv         ( 1'b0          ),
    .tprom_addr ( tprom_addr    ),
    .tprom_data ( tprom_data    ),
    .h_raw      ( h_raw         ),
    .hb         ( hb            ),
    .h          ( h             ),
    .h20        ( h20           ),
    .v          ( v             ),
    .vb         ( vb_t          ),
    .hbd_n      ( hbd_n_t       ),
    .ai_n       ( ai_n          ),
    .bi_n       ( bi_n          ),
    .initeo     ( initeo        ),
    .sy_n       ( sy_n          ),
    .vtick      ( vtick         ),
    .vcnt       ( vcnt          ),
    .vlatch     ( vlatch        ),
    .vhalf      ( vhalf         ),
    .hs         ( hs            ),
    .vs         ( vs            ),
    .lhbl       ( lhbl          ),
    .lvbl       ( lvbl          )
);

reg  [9:0] bx=0;
reg  [7:0] fc=0, brow=0;
reg        blhbl_l=0, bvb_l=0;

wire       txtv    = bx[6];
wire [3:0] txtc    = brow[3:0];
wire [4:0] bakc    = { fc[0], brow[7:4] };
wire       hbd_n   = bx[7];
wire       vb      = bx[8];
wire [2:0] obj_chi = bx[5:3];
wire [1:0] obj_va  = 2'b01;
wire [2:0] obj_ca  = bx[2:0];
wire [1:0] obj_vb  = 2'b10;
wire [2:0] obj_cb  = bx[2:0] ^ fc[3:1];

always @(posedge clk) if( !rst ) begin
    bvb_l <= vb_t;
    if( vb_t && !bvb_l ) fc <= fc + 8'd1;
    if( cen10 ) begin
        blhbl_l <= lhbl;
        bx <= lhbl ? bx + 10'd1 : 10'd0;
        if( !lhbl ) brow <= vlatch;
    end
end

wire       txtv_o, hbd_n_o, vb_o, lhbl_o, lvbl_o, hs_o, vs_o;
wire [3:0] txtc_o;
wire [4:0] bakc_o;
wire [1:0] obj_v_o;
wire [5:0] obj_c_o;

jtpopeye_dbl u_dbl(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen20      ( cen20         ),
    .cen10      ( cen10         ),
    .cen5       ( cen5          ),
    .vtick      ( vtick         ),
    .vcnt       ( vcnt          ),
    .vlatch     ( vlatch        ),
    .vhalf      ( vhalf         ),
    .vs         ( vs            ),
    .lhbl       ( lhbl          ),
    .txtv       ( txtv          ),
    .txtc       ( txtc          ),
    .bakc       ( bakc          ),
    .hbd_n      ( hbd_n         ),
    .vb         ( vb            ),
    .obj_chi    ( obj_chi       ),
    .obj_va     ( obj_va        ),
    .obj_ca     ( obj_ca        ),
    .obj_vb     ( obj_vb        ),
    .obj_cb     ( obj_cb        ),
    .txtv_o     ( txtv_o        ),
    .txtc_o     ( txtc_o        ),
    .bakc_o     ( bakc_o        ),
    .hbd_n_o    ( hbd_n_o       ),
    .vb_o       ( vb_o          ),
    .obj_v_o    ( obj_v_o       ),
    .obj_c_o    ( obj_c_o       ),
    .lhbl_o     ( lhbl_o        ),
    .lvbl_o     ( lvbl_o        ),
    .hs_o       ( hs_o          ),
    .vs_o       ( vs_o          )
);

reg  [7:0] red=0, green=0, blue=0;
reg        LHBL=0, LVBL=0;

always @(posedge clk) if( cen20 ) begin
    red   <= { bakc_o[3:0], txtc_o };
    green <= { obj_v_o, bakc_o[4], vb_o, hbd_n_o, txtv_o, 2'b00 };
    blue  <= { obj_c_o, 2'b00 };
    LHBL  <= lhbl_o;
    LVBL  <= lvbl_o;
end

wire [7:0] ar, ag, ab;
wire       ahs, avs, ade, ace, afield;
wire [5:0] hpos = HPOS;
wire [4:0] vpos = VPOS;

jtpopeye_ana uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen10      ( cen10         ),
    .cen20      ( cen20         ),
    .lhbl       ( lhbl          ),
    .vs         ( vs            ),
    .vtick      ( vtick         ),
    .vlatch     ( vlatch        ),
    .fsel       ( ~initeo       ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .deflicker  ( DEFL          ),
    .narrow     ( NARROW[0]     ),
    .hpos       ( hpos          ),
    .vpos       ( vpos          ),
    .ana_r      ( ar            ),
    .ana_g      ( ag            ),
    .ana_b      ( ab            ),
    .ana_hs     ( ahs           ),
    .ana_vs     ( avs           ),
    .ana_de     ( ade           ),
    .ana_ce     ( ace           ),
    .ana_field  ( afield        )
);

integer errors=0, clkcnt=0;
reg     measure=0;

reg [8*64-1:0] last_msg=0;
task fail(input [8*64-1:0] msg); begin
    errors = errors + 1;
    if( errors < 30 || msg != last_msg ) $display("FAIL %0s at t=%0t clk=%0d", msg, $time, clkcnt);
    last_msg = msg;
end endtask

always @(posedge clk) clkcnt <= clkcnt + 1;

reg [23:0] pm[0:447][0:511];
integer    pl=0, pk=0;
reg        plhbl_l=0;

always @(posedge clk) if( cen20 ) begin
    plhbl_l <= LHBL;
    if( LHBL && LVBL ) begin
        pm[pl][pk] = { red, green, blue };
        if( measure && red != 16 + (pl>>1) ) begin
            fail("progressive row encoding");
            if( errors < 30 ) $display("     line %0d x %0d red %0d vcnt %0d", pl, pk, red, vcnt);
        end
        pk = pk + 1;
    end
    if( !LHBL && plhbl_l && LVBL ) begin
        if( measure && pk != 512 ) fail("progressive line is not 512 pixels");
        pl = pl + 1;
    end
    if( !LHBL ) pk = 0;
    if( !LVBL ) pl = 0;
end

reg        fs_exp=0, fs_cur=0;
always @(posedge clk) if( cen10 && lhbl && !blhbl_l && vlatch == 8'd16 ) fs_exp <= ~initeo;

function [7:0] mixm( input [7:0] a, c, b, input [1:0] m );
    integer t;
    begin
        case( m )
            0: t = c;
            1: t = ( a + b + 6*c ) >> 3;
            2: t = ( 3*a + 3*b + 10*c ) >> 4;
            default: t = ( a + b + 2*c ) >> 2;
        endcase
        mixm = t[7:0];
    end
endfunction

reg        ahs_l=0, avs_l=0, ade_l=0, hs_l=0;
integer    t_hs=0, t_hs_prev=0, t_vs=0, t_vs_prev=0, nlines=0, dlines=0, dl_first=-1, de_px=0;
integer    t_de=0, de_start=0, de_clk=0, fields=0, vs_ph, ph_a=-1, ph_b=-1, ph_cls, first_a=-1, first_b=-1;
integer    de_ref=-1, de_ref_w=-1, vs_width=0, hlines=0, pfield;
integer    row, s, ci, ai, bi, x;
reg [23:0] c, a, b, e, gq;
reg        lastf=0;

always @(posedge clk) if( !rst ) begin
    ahs_l <= ahs;
    avs_l <= avs;
    ade_l <= ade;
    if( avs ) vs_width = vs_width + 1;
    if( ahs && !ahs_l ) begin
        t_hs_prev = t_hs;
        t_hs = clkcnt;
        if( measure && ( t_hs - t_hs_prev < 3046 || t_hs - t_hs_prev > 3049 ) ) fail("HS period");
        hlines = hlines + 1;
    end
    if( avs && !avs_l ) begin
        t_vs_prev = t_vs;
        t_vs = clkcnt;
        vs_ph = t_vs - t_hs;
        ph_cls = vs_ph > 1524 ? 1 : 0;
        if( measure ) begin
            if( t_vs - t_vs_prev < 781710 || t_vs - t_vs_prev > 781719 ) fail("VS period (513 half-lines at 61.40 Hz)");
            if( ph_cls == lastf ) fail("VS half-line phase does not alternate");
            if( ph_cls ) begin
                if( ph_a >= 0 && ( vs_ph < ph_a - 3 || vs_ph > ph_a + 3 ) ) fail("VS position against HS moved (field 1)");
                ph_a = vs_ph;
                if( first_a >= 0 && first_a != dl_first ) fail("picture moved against VS (field 1)");
                first_a = dl_first;
            end else begin
                if( ph_b >= 0 && ( vs_ph < ph_b - 3 || vs_ph > ph_b + 3 ) ) fail("VS position against HS moved (field 0)");
                ph_b = vs_ph;
                if( first_b >= 0 && first_b != dl_first ) fail("picture moved against VS (field 0)");
                first_b = dl_first;
            end
            if( dlines != 224 ) fail("active lines per field");
            $display("field %0d: VS %0d clk after HS (%s), period %0d clk, %0d HS, %0d active lines, first active line %0d after VS, sub %0d, VS width %0d clk, DE start %0d clk after HS, DE %0d clk",
                fields, vs_ph, ph_cls ? "mid-line" : "line start", t_vs - t_vs_prev, hlines, dlines, dl_first, fs_cur, vs_width, de_ref, de_ref_w);
            fields = fields + 1;
        end
        lastf = ph_cls;
        nlines = 0;
        hlines = 0;
        dlines = 0;
        dl_first = -1;
        vs_width = 0;
    end
    if( ahs && !ahs_l ) nlines = nlines + 1;
    if( ade && !ade_l ) begin
        de_start = clkcnt - t_hs;
        t_de = clkcnt;
        de_px = 0;
        if( dl_first < 0 ) begin
            dl_first = nlines;
            fs_cur   = fs_exp;
        end
        if( measure ) begin
            if( de_ref < 0 ) de_ref = de_start;
            else if( de_start < de_ref - 2 || de_start > de_ref + 2 ) fail("DE start moved against HS");
        end
    end
    if( !ade && ade_l ) begin
        de_clk = clkcnt - t_de;
        if( measure ) begin
            if( de_ref_w < 0 ) de_ref_w = de_clk;
            else if( de_clk < de_ref_w - 2 || de_clk > de_ref_w + 2 ) fail("DE width changed");
            if( de_px != 512 ) fail("DE is not 512 pixels");
        end
        dlines = dlines + 1;
    end
    if( ace && ade ) begin
        row = 16 + dlines;
        s   = fs_cur;
        x   = de_px;
        ci  = ( row - 16 ) * 2 + s;
        if( s == 0 ) begin
            ai = row == 16 ? ci : ci - 1;
            bi = ci + 1;
        end else begin
            ai = ci - 1;
            bi = row == 239 ? ci : ci + 1;
        end
        c = pm[ci][x];
        a = pm[ai][x];
        b = pm[bi][x];
        e = { mixm( a[23:16], c[23:16], b[23:16], DEFL ),
              mixm( a[15: 8], c[15: 8], b[15: 8], DEFL ),
              mixm( a[ 7: 0], c[ 7: 0], b[ 7: 0], DEFL ) };
        if( measure ) begin
            if( { ar, ag, ab } != e ) begin
                fail("pixel");
                if( errors < 30 ) $display("     row %0d sub %0d x %0d: got %h expected %h (c %h a %h b %h)", row, s, x, { ar, ag, ab }, e, c, a, b);
            end
            if( DEFL == 0 && ar != row ) fail("row shown");
            if( DEFL == 0 && ag[7:6] != ( s ? 2'b10 : 2'b01 ) ) fail("sprite sub-line");
            if( afield != s ) fail("field flag");
        end
        de_px = de_px + 1;
    end
    if( !ade && ace && measure && { ar, ag, ab } != 0 ) fail("colour outside DE");
    if( measure && ade && ahs ) fail("DE during HS");
    if( measure && ade && avs ) fail("DE during VS");
end

initial begin
    repeat(20) @(posedge clk);
    rst = 0;
    repeat(3) @(posedge avs);
    measure = 1;
    wait( fields == NFIELDS );
    $display("deflicker=%0d narrow=%0d hpos=%0d vpos=%0d: DE starts %0d clk after HS, DE %0d clk, first active line %0d/%0d HS after VS",
        DEFL, NARROW, HPOS, VPOS, de_ref, de_ref_w, first_a, first_b);
    if( errors==0 ) begin
        $display("PASS");
        $finish;
    end else begin
        $display("FAIL: %0d errors", errors);
        $fatal(1);
    end
end

initial begin
    repeat(100) #2_000_000_000;
    $display("FAIL: timeout");
    $fatal(1);
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
