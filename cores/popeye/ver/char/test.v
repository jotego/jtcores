`timescale 1ps/1ps

module test;

reg         clk=0, rst=1, rv=0;
reg         cen20=0, cen10=0, cen5=0, cpu_cen=0;
integer     acc=0, cpuc=0;
reg  [ 1:0] div=0;

reg  [11:0] ad=0;
reg  [ 7:0] dd=0;
reg         csv=0, memwr0=0;

wire [ 7:0] tprom_addr, tprom_q, h_raw, h, v;
wire [ 3:0] tprom_data = tprom_q[3:0];
wire        hb, h20, vb, hbd_n, ai_n, bi_n, initeo, sy_n, hs, vs, lhbl, lvbl;

wire [11:0] char_addr;
reg  [ 7:0] char_data=0;
wire        txtv;
wire [ 3:0] txtc;

reg  [ 7:0] rom[0:4095];
reg  [ 7:0] mt[0:1023];
reg  [ 3:0] mc[0:1023];
integer     fd, nrd;

initial forever #10417 clk = ~clk;

always @(posedge clk) begin
    cen20   <= 0;
    cen10   <= 0;
    cen5    <= 0;
    cpu_cen <= 0;
    cpuc    <= cpuc==11 ? 0 : cpuc+1;
    cpu_cen <= cpuc==11;
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

always @(posedge clk) char_data <= rom[char_addr];

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

jtpopeye_char uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen10      ( cen10         ),
    .cen5       ( cen5          ),
    .ad         ( ad            ),
    .dd         ( dd            ),
    .csv        ( csv           ),
    .memwr0     ( memwr0        ),
    .h          ( h             ),
    .hb         ( hb            ),
    .v          ( v             ),
    .vb         ( vb            ),
    .rv         ( rv            ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .txtv       ( txtv          ),
    .txtc       ( txtc          )
);

wire [12:0] ad13 = { 1'b0, ad };
wire [12:0] ad_dec;
wire [ 3:0] txtc20;
wire        txtv20;

jtpopeye_video_dec u_dec2020(
    .AD         ( ad13          ),
    .AD_dec     ( ad_dec        )
);

jtpopeye_txt u_2020(
    .rst_n      ( ~rst          ),
    .clk        ( clk           ),
    .pxl_cen    ( cen5          ),
    .cpu_cen    ( cpu_cen       ),
    .pause      ( 1'b0          ),
    .AD         ( ad_dec        ),
    .DD         ( dd            ),
    .H          ( h             ),
    .V          ( v             ),
    .HB         ( hb            ),
    .VB         ( vb            ),
    .RV         ( rv            ),
    .CSV        ( csv           ),
    .MEMWRO     ( memwr0        ),
    .prog_addr  ( 11'd0         ),
    .prom_5n_we ( 1'b0          ),
    .prom_din   ( 8'd0          ),
    .TXTC       ( txtc20        ),
    .TXTV       ( txtv20        )
);

function [11:0] scramble(input [15:0] a);
    scramble = { a[11], a[10], a[8], a[7], a[6], a[3], ~a[9], ~a[5], ~a[4], ~a[2], ~a[1], ~a[0] };
endfunction

integer cpu_pin_src[0:9];
integer vid_pin_src[0:9];
initial begin
    cpu_pin_src[0]=0; cpu_pin_src[1]=1; cpu_pin_src[2]=2; cpu_pin_src[3]=6; cpu_pin_src[4]=3;
    cpu_pin_src[5]=4; cpu_pin_src[6]=7; cpu_pin_src[7]=8; cpu_pin_src[8]=9; cpu_pin_src[9]=5;
    vid_pin_src[0]=3; vid_pin_src[1]=4; vid_pin_src[2]=5; vid_pin_src[3]=6; vid_pin_src[4]=7;
    vid_pin_src[5]=13; vid_pin_src[6]=14; vid_pin_src[7]=15; vid_pin_src[8]=16; vid_pin_src[9]=17;
end

function [9:0] cpu_index(input [11:0] a);
    integer k;
    reg [11:0] a5u;
    begin
        a5u = a;
        for( k=0; k<6; k=k+1 ) a5u[k] = ~a[k];
        for( k=0; k<10; k=k+1 ) cpu_index[k] = a5u[cpu_pin_src[k]];
    end
endfunction

function [9:0] vid_index(input [7:0] hbus, input [7:0] vbus);
    integer k;
    begin
        for( k=0; k<10; k=k+1 ) vid_index[k] = (vid_pin_src[k]>=10) ? vbus[vid_pin_src[k]-10] : hbus[vid_pin_src[k]];
    end
endfunction

integer errors=0, checks=0, pix_on=0, vb_checks=0, mm20_v=0, mm20_c=0, cmp20=0, ccheck=0;
reg     vb_s=0;
integer mm20_vbedge=0;
reg     checking=0, cmp_on=0, skip_line=0;
reg [7:0] vline=0;
integer vbcnt=0;

task fail(input [8*48-1:0] msg); begin
    errors = errors + 1;
    if( errors < 20 ) $display("FAIL %0s t=%0t hb=%b h_raw=%h v=%h rv=%b txtv=%b txtc=%h", msg, $time, hb, h_raw, v, rv, txtv, txtc);
end endtask

task cpu_wr(input [15:0] a, input [7:0] d, input sel); begin
    @(posedge clk);
    ad <= scramble(a);
    dd <= d;
    repeat(6) @(posedge clk);
    csv <= sel;
    repeat(9) @(posedge clk);
    memwr0 <= 1;
    repeat(18) @(posedge clk);
    memwr0 <= 0;
    repeat(9) @(posedge clk);
    csv <= 0;
    if( sel && a[15:13]==3'b101 && a[11:10]==2'b00 ) mt[cpu_index(scramble(a))] = d;
    if( sel && a[15:13]==3'b101 && a[11:10]==2'b01 ) mc[cpu_index(scramble(a))] = d[3:0];
end endtask

reg  [9:0] ei;
reg  [4:0] col;
reg  [7:0] vrow, byte_e;
reg  [2:0] pi;
reg        tile_dot, exp_pix;
reg  [8:0] dp;
reg        pv_ok=0, pc_ok=0, pv_txtv=1, o_txtv=1;
reg  [3:0] pv_txtc=0, o_txtc=0;
integer    half_checks=0, dot_gap=0, min_gap=99, cen5_to_dotck=0, min_c2d=99;
wire       dotck_tb = cen10 & ~cen5;

always @(posedge clk) begin
    dot_gap       <= cen10 ? 1 : dot_gap + 1;
    cen5_to_dotck <= cen5 ? 1 : cen5_to_dotck + 1;
    if( cen10 && !rst && dot_gap < min_gap ) min_gap <= dot_gap;
    if( dotck_tb && !rst && cen5_to_dotck < min_c2d ) min_c2d <= cen5_to_dotck;
end

always @(posedge clk) if( !rst && dotck_tb && checking && !skip_line ) begin
    if( pv_ok ) begin
        if( txtv != pv_txtv ) fail("txtv, first half of the dot");
        if( pc_ok && txtc != pv_txtc ) fail("txtc, first half of the dot");
        half_checks = half_checks + 1;
    end
end

always @(posedge clk) if( !rst && cen5 ) begin
    if( !hb ) vline <= v;
    vb_s  <= vb;
    vbcnt <= vb ? 0 : (vbcnt < 1000 ? vbcnt+1 : vbcnt);
    tile_dot = 0;
    dp       = (hb ? 9'd256 + {1'b0, h_raw - 8'hc0} : {1'b0, h_raw}) + 9'd1;
    if( dp >= 8 && dp < 264 ) begin
        col      = dp[7:3] - 5'd1;
        pi       = dp[2:0];
        vrow     = hb ? vline : v;
        tile_dot = 1;
    end
    pv_ok = 0;
    pc_ok = 0;
    if( checking && !skip_line ) begin
        if( vb ) begin
            if( !txtv ) fail("pixel during VB");
            vb_checks = vb_checks + 1;
            pv_ok   = vbcnt > 0;
            pv_txtv = 1;
        end else if( vbcnt > 16 ) begin
            if( tile_dot ) begin
                ei      = vid_index( { col ^ {5{rv}}, 3'd0 }, vrow );
                byte_e  = rom[ 12'h800 + { mt[ei], vrow[2:0] } ];
                exp_pix = rv ? byte_e[3'd7-pi] : byte_e[pi];
                if( txtv != ~exp_pix ) fail("txtv");
                if( txtc != mc[ei] ) fail("txtc");
                pv_ok   = 1;
                pc_ok   = 1;
                pv_txtv = ~exp_pix;
                pv_txtc = mc[ei];
                if( exp_pix ) pix_on = pix_on + 1;
                checks = checks + 1;
            end else begin
                if( !txtv ) fail("pixel outside tile dots");
                pv_ok   = 1;
                pv_txtv = 1;
                checks = checks + 1;
            end
        end
    end
    if( gl_arm && !hb && h_raw >= gl_h0 && h_raw < gl_h0+8 ) begin
        gl_n = gl_n + 1;
        if( txtv != ~gl_byte[h_raw[2:0]+3'd1] || txtc != gl_col ) gl_bad = gl_bad + 1;
    end
    if( cmp_on ) begin
        cmp20 = cmp20 + 1;
        if( txtv20 != o_txtv && vb && !vb_s ) mm20_vbedge = mm20_vbedge + 1;
        else if( txtv20 != o_txtv ) begin
            mm20_v = mm20_v + 1;
            if( mm20_v < 5 ) $display("2020 txtv differs: hb=%b h_raw=%h v=%h vb=%b vbcnt=%0d rv=%b ours(dot before)=%b 2020=%b", hb, h_raw, v, vb, vbcnt, rv, o_txtv, txtv20);
        end
        if( tile_dot && !vb && vbcnt > 16 && txtc20 != o_txtc ) mm20_c = mm20_c + 1;
    end
    o_txtv <= txtv;
    o_txtc <= txtc;
end

task wait_field; begin
    @(negedge vb);
    @(posedge vb);
end endtask

task wait_hraw(input [7:0] hv, input hbv); begin
    while( !(cen5 && h_raw==hv && hb==hbv) ) @(posedge clk);
    @(posedge clk);
end endtask

integer i, k, bad_idx, gl_ok;
reg [7:0] gl_code, gl_v;
reg [9:0] gl_idx;
reg [7:0] gl_byte=0, gl_h0=0;
reg [3:0] gl_col=0;
reg       gl_arm=0;
integer   gl_n=0, gl_bad=0;

initial begin
    fd  = $fopen(`CHARROM,"rb");
    nrd = $fread(rom, fd);
    $fclose(fd);
    if( nrd != 4096 ) $fatal(1, "FAIL cannot read 5N (%0d bytes)", nrd);
    for( i=0; i<1024; i=i+1 ) begin mt[i] = 0; mc[i] = 0; end
    bad_idx = 0;
    for( i=0; i<2048; i=i+1 ) if( cpu_index(scramble(16'ha000+i[15:0])) != i[9:0] ) bad_idx = bad_idx + 1;
    $display("drawing address path (5U invert + 6P/6R/6S pins) vs linear CPU A[9:0]: %0d differences over A000-A7FF", bad_idx);
    if( bad_idx != 0 ) errors = errors + 1;
    for( i=0; i<1024; i=i+1 ) if( vid_index( {i[4:0],3'd0}, {i[9:5],3'd0} ) != i[9:0] ) bad_idx = bad_idx + 1;
    if( bad_idx != 0 ) begin errors = errors + 1; $display("FAIL video index"); end
    repeat(40) @(posedge clk);
    rst = 0;
    for( i=0; i<1024; i=i+1 ) cpu_wr( 16'ha000+i[15:0], (i*37 + (i>>5)*11 + 3) & 8'hff, 1 );
    for( i=0; i<1024; i=i+1 ) cpu_wr( 16'ha400+i[15:0], (i + (i>>5)*3) & 8'hf, 1 );
    for( i=0; i<64; i=i+1 )   cpu_wr( 16'ha800+i[15:0]*29, 8'hff, 1 );
    for( i=0; i<64; i=i+1 )   cpu_wr( 16'hac00+i[15:0]*13, 8'h55, 1 );
    for( i=0; i<64; i=i+1 )   cpu_wr( 16'ha000+i[15:0]*7, 8'h00, 0 );
    $display("RAM image written (2048 writes + 192 decoy writes)");
    wait_field;
    checking = 1;
    cmp_on   = 1;
    wait_field;
    $display("clock chain: min cen10 spacing %0d clk, min cen5 -> DOTCK rise %0d clk", min_gap, min_c2d);
    $display("rv=0 field: %0d dots checked, %0d text dots lit, %0d VB dots", checks, pix_on, vb_checks);
    checking = 0;
    cmp_on   = 0;
    rv = 1;
    wait_field;
    k = checks;
    checking = 1;
    cmp_on   = 1;
    wait_field;
    $display("rv=1 field: %0d dots checked", checks-k);
    checking = 0;
    cmp_on   = 0;
    $display("2020 jtpopeye_txt on the same stimulus: %0d dots compared, txtv mismatches %0d (+%0d on the first dot of VB: /VB clears 6M/6N at once on the board, the 2020 code at the next dot), txtc mismatches %0d", cmp20, mm20_v, mm20_vbedge, mm20_c);
    if( mm20_v != 0 || mm20_c != 0 ) errors = errors + 1;

    rv = 0;
    wait_field;
    @(negedge vb);
    repeat(40) @(posedge hb);
    gl_idx = 10'h155;
    wait_hraw( 8'h43, 0 );
    ad  <= scramble( 16'ha000 + {6'd0,gl_idx} );
    csv <= 1;
    gl_v = v;
    $display("scan tile at column 8 of this line: code %02h", mt[ vid_index( 8'h40, v ) ]);
    gl_byte = rom[ 12'h800 + { mt[gl_idx], gl_v[2:0] } ];
    gl_col  = mc[gl_idx];
    gl_h0   = 8'h47;
    gl_n = 0; gl_bad = 0; gl_arm = 1;
    wait_hraw( 8'h47, 0 );
    csv <= 0;
    wait_hraw( 8'h50, 0 );
    gl_arm = 0;
    gl_ok = gl_n==8 && gl_bad==0;
    $display("CSV read held over the load at column 8: loads tile %03h (code %02h) instead of the scan tile: %0s", gl_idx, mt[gl_idx], gl_ok ? "ok" : "WRONG");
    if( !gl_ok ) errors = errors + 1;

    repeat(3) @(posedge hb);
    gl_idx  = 10'h2a7;
    gl_code = 8'h5a;
    wait_hraw( 8'h82, 0 );
    ad     <= scramble( 16'ha000 + {6'd0,gl_idx} );
    dd     <= gl_code;
    csv    <= 1;
    memwr0 <= 1;
    gl_v = v;
    gl_byte = rom[ 12'h800 + { gl_code, gl_v[2:0] } ];
    gl_col  = gl_code[3:0];
    gl_h0   = 8'h87;
    gl_n = 0; gl_bad = 0; gl_arm = 1;
    wait_hraw( 8'h87, 0 );
    memwr0 <= 0;
    csv    <= 0;
    mt[gl_idx] = gl_code;
    wait_hraw( 8'h90, 0 );
    gl_arm = 0;
    gl_ok = gl_n==8 && gl_bad==0;
    $display("CSV write over the load at column 16: ROM address and 5T take the CPU data %02h (DDT bus): %0s", gl_code, gl_ok ? "ok" : "WRONG");
    if( !gl_ok ) errors = errors + 1;

    wait_field;
    k = checks;
    checking = 1;
    wait_field;
    checking = 0;
    $display("field after the write: %0d dots checked (tile %03h now %02h, colour RAM unchanged)", checks-k, gl_idx, gl_code);

    $display("first-half-of-dot (DOTCK phase) checks: %0d", half_checks);
    if( errors==0 && pix_on > 1000 && half_checks > 100000 ) $display("PASS");
    else begin
        $fatal(1, "FAIL: %0d errors, %0d lit dots", errors, pix_on);
    end
    $finish;
end

endmodule

module jt2020_ram #(parameter aw=10, dw=8, synfile="", simfile="")(
    input               clk,
    input               cen,
    input      [dw-1:0] data,
    input      [aw-1:0] addr,
    input               we,
    output reg [dw-1:0] q
);
reg [dw-1:0] mem[0:(2**aw)-1];
integer k;
initial for( k=0; k<2**aw; k=k+1 ) mem[k] = 0;
always @(posedge clk) begin
    q <= mem[addr];
    if( cen && we ) mem[addr] <= data;
end
endmodule

module jt2020_prom #(parameter aw=11, dw=8, simfile="", offset=0)(
    input               clk,
    input               cen,
    input      [dw-1:0] data,
    input      [aw-1:0] rd_addr,
    input      [aw-1:0] wr_addr,
    input               we,
    output reg [dw-1:0] q
);
reg [7:0] file[0:4095];
integer fd, n;
initial begin
    fd = $fopen(`CHARROM,"rb");
    n  = $fread(file, fd);
    $fclose(fd);
end
always @(posedge clk) if( cen ) q <= file[offset+rd_addr];
endmodule
