`include "fixtures.vh"
`timescale 1ps/1ps

module test;


reg         clk=0, rst=1;
localparam integer HLEXP = 513;
localparam integer NFIELDS = 8;
reg         cen20=0, cen5=0, cen10=0;
integer     acc=0;
reg  [ 1:0] div=0;

wire [ 7:0] tprom_addr, tprom_q, h_raw, h, v;
wire [ 3:0] tprom_data = tprom_q[3:0];
wire        hb, h20, vb_t, hbd_n_t, ai_n, bi_n, initeo, sy_n, hs, vs, lhbl, lvbl, vtick, vhalf;
wire [ 7:0] vcnt, vlatch;

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
reg  [7:0] brow=0;
reg        bfield=0, blhbl_l=0, blvbl_l=0, bvs_l=0;

wire       txtv    = bfield;
wire [3:0] txtc    = brow[3:0];
wire [4:0] bakc    = { brow[7:4], bx[8] };
wire       hbd_n   = bx[7];
wire       vb      = bx[6];
wire [2:0] obj_chi = bx[5:3];
wire [1:0] obj_va  = bx[2:1];
wire [2:0] obj_ca  = { bx[0], 2'b10 };
wire [1:0] obj_vb  = ~bx[2:1];
wire [2:0] obj_cb  = { bx[0], 2'b01 };

wire       txtv_o, hbd_n_o, vb_o, lhbl_o, lvbl_o, hs_o, vs_o;
wire [3:0] txtc_o;
wire [4:0] bakc_o;
wire [1:0] obj_v_o;
wire [5:0] obj_c_o;

jtpopeye_dbl uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen20      ( cen20         ),
    .cen10      ( cen10         ),
    .cen5       ( cen5          ),
    .vtick      ( vtick         ),
    .vs         ( vs            ),
    .vcnt       ( vcnt          ),
    .vlatch     ( vlatch        ),
    .vhalf      ( vhalf         ),
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

integer errors=0, clkcnt=0;
reg     measure=0;

task fail(input [8*64-1:0] msg); begin
    errors = errors + 1;
    if( errors < 30 ) $display("FAIL %0s at t=%0t oc=%0d px=%0d", msg, $time, uut.oc, uut.px);
end endtask

always @(posedge clk) clkcnt <= clkcnt + 1;

integer slot_row[0:3], slot_done[0:3], slot_field[0:3];
integer t_wend[0:3], t_rend[0:3], read_twice[0:3], slot_meas[0:3];
integer oc_wend[0:3], oc_rend[0:3];
integer min_pre_clk=1<<30, min_post_clk=1<<30, min_pre_hl=1<<30, min_post_hl=1<<30;
integer oc_lvbl_rise=0, oc_wend0=0, oc_wend223=0, vs_phase=0;
integer fpre_hl, fpost_hl;
integer k, wk, rk, write_row;

always @(posedge clk) if( !rst ) begin
    bvs_l <= vs;
    if( vs && !bvs_l ) begin
        bfield <= ~bfield;
        vs_phase <= hb ? 1 : 0;
    end
end

always @(posedge clk) if( !rst && cen10 ) begin
    blhbl_l <= lhbl;
    blvbl_l <= lvbl;
    bx <= lhbl ? bx + 10'd1 : 10'd0;
    if( !lhbl ) brow <= vlatch - 8'd16;
    if( lvbl && !blvbl_l ) begin
        oc_lvbl_rise = uut.oc;
        fpre_hl  = 1<<30;
        fpost_hl = 1<<30;
    end
    if( lhbl && brow<224 && bx==0 ) begin
        write_row = brow;
        wk = write_row % 4;
        if( measure && read_twice[wk]==2 ) begin
            if( clkcnt - t_rend[wk] < min_post_clk ) min_post_clk = clkcnt - t_rend[wk];
            if( uut.oc - oc_rend[wk] < fpost_hl ) fpost_hl = uut.oc - oc_rend[wk];
        end
        if( measure && slot_meas[wk] && slot_done[wk] && read_twice[wk]!=2 ) fail("row overwritten before both reads");
        slot_row[wk]   = brow;
        slot_field[wk] = bfield;
        slot_done[wk]  = 0;
        read_twice[wk] = 0;
        slot_meas[wk]  = measure;
    end
    if( lhbl && lvbl && bx > 511 ) fail("more than 512 source pixels");
    if( !lhbl && blhbl_l && write_row<224 ) begin
        wk = write_row % 4;
        if( bx != 512 ) fail("source line is not 512 pixels");
        slot_done[wk] = 1;
        t_wend[wk]    = clkcnt;
        oc_wend[wk]   = uut.oc;
        if( brow==0 )   oc_wend0   = uut.oc;
        if( brow==223 ) oc_wend223 = uut.oc;
    end
end

reg        olhbl_l=0, olvbl_l=0, ovs_l=0, ohs_l=0;
integer    opx=0, ol=0, olines=0, ohalf=0, olvlines=0, ohs_cnt=0, ohs_to_lhbl=0, oline_len=0;
integer    vs_to_lvbl=-1, vs_to_lvbl_ref=-1, ofields=0, vs_len=0, oc_at_vs=-1;
integer    erow, es, gx, grow, gf, gs;
reg [1:0]  tag;

always @(posedge clk) if( !rst && cen20 ) begin
    olhbl_l <= lhbl_o;
    olvbl_l <= lvbl_o;
    ovs_l   <= vs_o;
    ohs_l   <= hs_o;
    oline_len <= oline_len + 1;
    ohs_to_lhbl <= ohs_to_lhbl + 1;
    if( hs_o && !ohs_l ) begin
        if( measure && oline_len != 640 ) fail("output line is not 640 cen20");
        oline_len   <= 1;
        ohs_to_lhbl <= 1;
        ohalf       <= ohalf + 1;
    end
    if( hs_o ) ohs_cnt <= ohs_cnt + 1;
    if( !hs_o && ohs_l ) begin
        if( measure && ohs_cnt != 64 ) fail("hs_o width");
        ohs_cnt <= 0;
    end
    if( lhbl_o && !olhbl_l && measure && ohs_to_lhbl != 96 ) fail("hs_o to lhbl_o distance");
    if( lvbl_o && !olvbl_l ) begin
        vs_to_lvbl = ohalf;
        if( measure ) begin
            if( vs_to_lvbl_ref < 0 ) vs_to_lvbl_ref = ohalf;
            else if( ohalf != vs_to_lvbl_ref ) fail("picture moved against vs_o");
        end
    end
    if( vs_o ) vs_len <= vs_len + 1;
    if( vs_o && !ovs_l ) begin
        if( measure ) begin
            if( ohalf != HLEXP ) fail("output lines per field");
            if( olvlines != 448 ) fail("active output lines");
            if( vs_len != 6*640 && vs_len != 6*640-1 && vs_len != 6*640+1 ) fail("vs_o width");
            $display("field %0d (VS at Vclk %s): oc at lvbl rise %0d, oc at write end of row 0 %0d, of row 223 %0d; output: %0d lines, vs_o->lvbl_o %0d lines, read margins: pre %0d half-lines, post %0d half-lines",
                ofields, vs_phase ? "dot 272 (HB)" : "dot 112", oc_lvbl_rise, oc_wend0, oc_wend223, ohalf, vs_to_lvbl, fpre_hl, fpost_hl);
            ofields <= ofields + 1;
        end
        ohalf    <= 0;
        olvlines <= 0;
        vs_len   <= 1;
        ol       <= 0;
    end
    if( lhbl_o ) opx <= opx + 1;
    if( !lhbl_o && olhbl_l ) begin
        if( measure && opx != 512 ) fail("lhbl_o is not 512 pixels");
        opx <= 0;
        if( lvbl_o ) begin
            ol       <= ol + 1;
            olvlines <= olvlines + 1;
        end
    end
    if( !lvbl_o ) ol <= 0;
    if( lhbl_o && lvbl_o ) begin
        erow = ol >> 1;
        es   = ol & 1;
        gf   = txtv_o;
        grow = { bakc_o[4:1], txtc_o };
        tag  = obj_c_o[1:0];
        gs   = tag == 2'b01;
        gx   = { bakc_o[0], hbd_n_o, vb_o, obj_c_o[5:3], (gs ? ~obj_v_o : obj_v_o), obj_c_o[2] };
        if( measure ) begin
            if( grow != erow ) fail("row");
            if( gx != opx ) fail("x / pixel alignment");
            if( tag != (es ? 2'b01 : 2'b10) ) fail("obj A/B sub-line");
            if( gf != bfield ) fail("field");
            rk = erow % 4;
            if( slot_row[rk] != erow || slot_field[rk] != bfield ) begin
                fail("read of a row not in the ring");
                if( errors < 30 ) $display("     row %0d sub %0d field %0d, slot holds row %0d field %0d done %0d", erow, es, bfield, slot_row[rk], slot_field[rk], slot_done[rk]);
            end
            if( !slot_done[rk] ) fail("read of a row before it is complete");
            if( opx==0 ) begin
                if( es==0 ) begin
                    if( clkcnt - t_wend[rk] < min_pre_clk ) min_pre_clk = clkcnt - t_wend[rk];
                    if( uut.oc - oc_wend[rk] < fpre_hl ) fpre_hl = uut.oc - oc_wend[rk];
                    if( uut.oc - oc_wend[rk] < min_pre_hl ) min_pre_hl = uut.oc - oc_wend[rk];
                end
            end
            if( opx==511 ) begin
                read_twice[rk] = read_twice[rk] + 1;
                if( es==1 ) begin
                    t_rend[rk]  = clkcnt;
                    oc_rend[rk] = uut.oc;
                end
            end
        end
    end else if( measure ) begin
        if( !txtv_o || obj_v_o!=0 || hbd_n_o || !vb_o || txtc_o!=0 || bakc_o!=0 || obj_c_o!=0 ) fail("bundle not idle outside the window");
    end
end

always @(posedge clk) if( measure && cen10 && lhbl && brow<224 && bx==0 && read_twice[brow%4]==2 ) begin
    if( uut.oc - oc_rend[brow%4] < min_post_hl ) min_post_hl = uut.oc - oc_rend[brow%4];
end

initial begin
    for( k=0; k<4; k=k+1 ) begin
        slot_row[k]=-1; slot_done[k]=0; slot_meas[k]=0; slot_field[k]=-1; read_twice[k]=0; t_wend[k]=0; t_rend[k]=0;
    end
    repeat(20) @(posedge clk);
    if( !txtv_o || obj_v_o!=0 || hbd_n_o || !vb_o || lhbl_o || lvbl_o || hs_o || vs_o ) begin
        $display("FAIL reset values"); errors = errors + 1;
    end
    rst = 0;
    repeat(3) @(posedge vs_o);
    @(negedge vs_o);
    measure = 1;
    wait( ofields == NFIELDS );
    $display("worst margin row complete -> first read pixel %0d clk (%0.1f dots), %0d half-lines from the write-end line to the first read line",
        min_pre_clk, min_pre_clk/(48.0e6/5.04e6), min_pre_hl);
    $display("worst margin last read pixel (2nd sub-line) -> overwrite by row r+4 %0d clk (%0.1f dots), %0d half-lines",
        min_post_clk, min_post_clk/(48.0e6/5.04e6), min_post_hl);
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

initial begin
    repeat(20000000) @(posedge clk);
    $fatal(1,"FAIL bounded simulation timeout");
end
initial begin
    $dumpfile("test.lxt"); $dumpvars(1,uut);
    repeat(2048) @(posedge clk); $dumpoff;
end
endmodule
