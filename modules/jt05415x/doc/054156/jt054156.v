// Simplified Verilog deliverable for Konami 054156.
// Derived from modules/jt05415x/doc/054156/jt054156_all.v for jtcores issue #37; tracked/adapted in jtcores issue #53.
// Simple continuous-assignment cells are inlined with schematic instance comments.


// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054156_cells.v
// -----------------------------------------------------------------------------

// Preliminary 054156 primitive cells extracted from the schematic.
// Only cells whose symbol polarity has been visually checked are modeled here.

module jt054156_p24(
    input  wire a1,
    input  wire b1,
    input  wire a2,
    input  wire b2,
    input  wire a3,
    input  wire b3,
    input  wire a4,
    input  wire b4,
    input  wire sa,
    input  wire sb,
    output wire x1,
    output wire x2,
    output wire x3,
    output wire x4
);

wire select_a = ~sa &  sb;
wire select_b =  sa & ~sb;

assign x1 = (select_a & a1) | (select_b & b1);
assign x2 = (select_a & a2) | (select_b & b2);
assign x3 = (select_a & a3) | (select_b & b3);
assign x4 = (select_a & a4) | (select_b & b4);

endmodule

module jt054156_t2b(
    input  wire a,
    input  wire b,
    input  wire s1,
    input  wire s2,
    output wire x
);

wire select_a = ~s1 & s2;
wire select_b = s1 & ~s2;
wire selected = (select_a & a) | (select_b & b);

assign x = ~selected;

endmodule

module jt054156_t5a(
    input  wire a1,
    input  wire a2,
    input  wire s1,
    input  wire s2,
    input  wire s5,
    input  wire s6,
    input  wire s3,
    input  wire s4,
    input  wire b1,
    input  wire b2,
    output wire x
);

wire select_a1 = ~s1 &  s2;
wire select_a2 =  s1 & ~s2;
wire select_b1 = ~s3 &  s4;
wire select_b2 =  s3 & ~s4;
wire select_a  = ~s5 &  s6;
wire select_b  =  s5 & ~s6;
wire mux_a     = (select_a1 & a1) | (select_a2 & a2);
wire mux_b     = (select_b1 & b1) | (select_b2 & b2);
wire selected  = (select_a & mux_a) | (select_b & mux_b);

assign x = ~selected;

endmodule

module jt054156_c43(
    input  wire       ck,
    input  wire [3:0] d,
    input  wire       load_n,
    input  wire       en,
    input  wire       ci,
    input  wire       clear_n,
    output reg  [3:0] q,
    output wire       co
);

always @(posedge ck or negedge clear_n) begin
    if (!clear_n) begin
        q <= 4'd0;
    end else if (!load_n) begin
        q <= d;
    end else if (en & ci) begin
        q <= q + 1'b1;
    end
end

assign co = &{ q, ci };

endmodule

// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054156_connected.v
// -----------------------------------------------------------------------------

// Broad connected artifact for the reconstructed 054156 digital schematic.
module jt054156_connected(
    input  wire        pin_clk,
    input  wire        pin_nres,
    input  wire [13:1] pin_ab,
    input  wire [15:0] pin_db_in,
    input  wire [23:0] pin_vd_in,

    input  wire        pin_nrcs,
    input  wire        pin_nccs,
    input  wire        pin_cram,
    input  wire        pin_dac,
    input  wire        pin_lds,
    input  wire        pin_uds,
    input  wire        pin_nrd,
    input  wire        pin_nvcs,
    input  wire        pin_test,
    input  wire        pin_enhs,
    input  wire        pin_envs,

    output wire        pin_dclk,
    output wire        pin_nhsy,
    output wire        pin_nhbl,
    output wire        pin_nvsy,
    output wire        pin_nvbl,
    output wire        pin_irq,
    output wire        pin_firq,
    output wire        pin_nmi,
    output wire        pin_s2h,
    output wire        pin_s4h,
    output wire        pin_z1h,
    output wire        pin_z2h,
    output wire        pin_z4h,

    output wire [16:0] pin_va,
    output wire        pin_vd_dir_low,
    output wire        pin_vd_dir_mid,
    output wire        pin_vd_dir_high,
    output wire        pin_oe0,
    output wire        pin_oe1,
    output wire        pin_oe2,
    output wire        pin_we0,
    output wire        pin_we1,
    output wire        pin_we2,
    output wire        pin_csz1,
    output wire        pin_cs1,
    output wire        pin_csz2,
    output wire        pin_cs2,

    output wire        pin_db_l_oe,
    output wire        pin_db_u_oe,
    output wire        pin_nre,
    output wire [15:0] pin_db_out,
    output wire [23:0] pin_vd_out,
    output wire [18:0] pin_ca,
    output wire [7:0]  pin_col,
    output wire [1:0]  pin_vrc,
    output wire        pin_sz,
    output wire        pin_namp,

    output wire [8:0]  hcnt,
    output wire [8:0]  vcnt,
    output wire [8:3]  scrollx,
    output wire [10:0] scrolly,
    output wire [2:0]  pagey
);

wire        dclk2, dclk3, dclk3_buf, hload_n;
wire        pin_nrd_inv;
wire        test0, test1, test2;
wire        r0_2or6;
wire        reset1_n, reset2_n, reset3_n, reset4_n, reset5_n;
wire        reset6_n, reset7_n, reset8_n, reset9_n, reset10_n;
wire        reset11_n, reset12_n, reset13_n, reset14_n, reset15_n;
wire        reset16_n, reset17_n, reset18_n, reset19_n, reset20_n;
wire        hcnt0f, hcnt1f, p40b_y, n107b_y, n29_co, m25_co;
wire        r34_xq, n8b_y, n9a_q;
wire        p140_q, p140_xq, p140_q_n, p140_xq_n;
wire        n186_x0, n186_x0_n, n186_x1, n186_x1_n;
wire        n186_x2, n186_x3, n186_x2_n, n186_x3_n;
wire        n186_x2t_n, n186_x3t_n;
wire        n186_x2t_buf_n, n186_x3t_buf_n;

wire        access_l_n, access_u_n;
wire        l125a_y, p113b_y, p170b_y;
wire        regc_db0_buf, regc_db1_buf, p110b_y;
wire [7:0]  db_in_buf, db_in_buf2, db_in_buf3, db_in_buf4;
wire [7:0]  reg0_db, reg2_db, reg4_db, reg6_db, reg8_db, rega_db;
wire [5:0]  regc_db;
wire [5:0]  reg10_d, reg12_d, reg14_d, reg16_d;
wire [5:0]  reg18_d, reg1a_d, reg1c_d, reg1e_d;
wire [10:0] reg20_d, reg22_d, reg24_d, reg26_d;
wire [11:0] reg28_d, reg2a_d, reg2c_d, reg2e_d;
wire [5:0]  reg30_d, reg32_d;
wire [7:0]  reg34u_d, reg34l_d;
wire [1:0]  reg36_d;
wire [15:0] reg38_d;
wire [11:0] reg3a_d;
wire [10:0] reg3c_d;
wire        reg0_wr_n, reg2_wr_n, reg4_wr_n, reg6_wr_n;
wire        reg8_wr_n, rega_wr_n, regc_wr_n;
wire        reg10_wr_n, reg12_wr_n, reg14_wr_n, reg16_wr_n;
wire        reg18_wr_n, reg1a_wr_n, reg1c_wr_n, reg1e_wr_n;
wire        reg20u_wr_n, reg20l_wr_n, reg22u_wr_n, reg22l_wr_n;
wire        reg24u_wr_n, reg24l_wr_n, reg26u_wr_n, reg26l_wr_n;
wire        reg28u_wr_n, reg28l_wr_n, reg2au_wr_n, reg2al_wr_n;
wire        reg2cu_wr_n, reg2cl_wr_n, reg2eu_wr_n, reg2el_wr_n;
wire        reg30_wr_n, reg32_wr_n, reg34u_wr_n, reg34l_wr_n;
wire        reg36_wr_n, reg38u_wr_n, reg38l_wr_n;
wire        reg3au_wr_n, reg3al_wr_n, reg3cu_wr_n, reg3cl_wr_n;
wire [3:0]  n53_x_n;

wire [10:0] ab_ram, ab_mux_ram;
wire [2:0]  pagex;
wire        lat_ab_reg, lat_ab_ram;
wire        ab_mux_2_3, ab_mux_3_4, ab_mux_4_5, ab_mux_5_6;
wire        ab_mux_6_7, ab_mux_7_8, ab_mux_8_9, ab_mux_9_10;
wire        ab_mux_10_11, ab_mux_11_12, ab_mux_12_13;
wire        reg4_db3_n, reg4_db3_buf, regc_db1_ab_buf, regc_db1_n;

wire [2:0]  hs_mux, hb_mux, vs_mux, vb_mux, hsize_mux, vsize_mux;
wire        scrolly_en_mux;
wire        tick_a, tick_b, tick_c, tick_d;
wire        n186_x2t_buf2_n, n186_x2t_buf2;
wire        n186_x3t_buf2_n, n186_x3t_buf2;
wire        n186_x2t_buf3_n, n186_x2t_buf3;
wire        n186_x3t_buf3_n, n186_x3t_buf3;

wire        k209a, h181a, m191a, m201_xq, m212a_y, k206a_y, k210b_y;
wire [23:0] vd_latch_n;
wire        k207a_y, f78b_y;
wire [23:0] vd_reg;
wire [8:3]  scrollx_xor;
wire [2:0]  scrolly_xor;
wire        vflip_en_mux, hflip_en_mux, h36_y, f11a_y;
wire [3:0]  lu, col;
wire        ca17, ca18;
wire        sel_sa, sel_sb;

wire pin_ab1  = pin_ab[1];
wire pin_ab11 = pin_ab[11];
wire pin_ab12 = pin_ab[12];
wire hcnt0    = hcnt[0];
wire hcnt2    = hcnt[2];
wire [15:8] pin_db_hi_in  = pin_db_in[15:8];
wire [2:0]  pin_db_in_2_0 = pin_db_in[2:0];
wire [8:2]  hcnt_8_2    = hcnt[8:2];
wire [2:0]  reg6_db_2_0 = reg6_db[2:0];
wire [7:4]  reg8_db_7_4 = reg8_db[7:4];
wire [3:0]  reg8_db_3_0 = reg8_db[3:0];
wire [7:1]  rega_db_7_1 = rega_db[7:1];
wire [7:0]  reg3al_d    = reg3a_d[7:0];
wire [11:8] reg3au_d    = reg3a_d[11:8];
wire [8:0]  scrolly_8_0 = scrolly[8:0];
wire [2:0]  scrolly_2_0 = scrolly[2:0];
wire [2:0]  reg4_db_2_0 = reg4_db[2:0];

wire reg0_db0 = reg0_db[0];
wire reg0_db2 = reg0_db[2];
wire reg0_db3 = reg0_db[3];
wire reg0_db4 = reg0_db[4];
wire reg0_db5 = reg0_db[5];
wire reg0_db6 = reg0_db[6];
wire reg0_db7 = reg0_db[7];
wire reg4_db3 = reg4_db[3];
wire reg4_db5 = reg4_db[5];
wire reg4_db6 = reg4_db[6];
wire reg6_db3 = reg6_db[3];
wire reg6_db4 = reg6_db[4];
wire reg6_db5 = reg6_db[5];
wire reg6_db6 = reg6_db[6];
wire reg6_db7 = reg6_db[7];
wire regc_db0 = regc_db[0];
wire regc_db1 = regc_db[1];

assign pin_nrd_inv = ~pin_nrd; // p195b_pin_nrd_inv
jt054156_reset_source u_reset_source(
    .pin_clk    ( pin_clk    ),
    .pin_nres   ( pin_nres   ),
    .reset1_n   ( reset1_n   ),
    .reset2_n   ( reset2_n   ),
    .reset3_n   ( reset3_n   ),
    .reset4_n   ( reset4_n   ),
    .reset5_n   ( reset5_n   ),
    .reset6_n   ( reset6_n   ),
    .reset7_n   ( reset7_n   ),
    .reset8_n   ( reset8_n   ),
    .reset9_n   ( reset9_n   ),
    .reset10_n  ( reset10_n  ),
    .reset11_n  ( reset11_n  ),
    .reset12_n  ( reset12_n  ),
    .reset13_n  ( reset13_n  ),
    .reset14_n  ( reset14_n  ),
    .reset15_n  ( reset15_n  ),
    .reset16_n  ( reset16_n  ),
    .reset17_n  ( reset17_n  ),
    .reset18_n  ( reset18_n  ),
    .reset19_n  ( reset19_n  ),
    .reset20_n  ( reset20_n  ),
    .reset_root (            )
);

assign r0_2or6 = reg0_db6 | reg0_db2; // r15a_r0_2or6
// Inlined jt054156_page06_test_source u_test_source
reg u_test_source__test0;
reg u_test_source__test1;
reg u_test_source__unused_p115_q;
always @(posedge pin_test) begin
    {u_test_source__test0,u_test_source__test1,u_test_source__unused_p115_q} <= {pin_db_in_2_0[0],pin_db_in_2_0[1],pin_db_in_2_0[2]}; // m194, m197, p115
end
assign test2 = pin_test & u_test_source__unused_p115_q; // p108b
assign test0 = u_test_source__test0;
assign test1 = u_test_source__test1;
// End inlined jt054156_page06_test_source u_test_source

jt054156_hv_timing u_hv_timing(
    .pin_clk          ( pin_clk          ),
    .reset1_n        ( reset1_n         ),
    .reset10_n       ( reset10_n        ),
    .reset15_n       ( reset15_n        ),
    .reset19_n       ( reset19_n        ),
    .reg0_db0        ( reg0_db0         ),
    .reg0_db2        ( reg0_db2         ),
    .reg0_db3        ( reg0_db3         ),
    .reg0_db4        ( reg0_db4         ),
    .reg0_db6        ( reg0_db6         ),
    .reg6_db         ( reg6_db_2_0      ),
    .test0           ( test0            ),
    .test1           ( test1            ),
    .test2           ( test2            ),
    .pin_test        ( pin_test         ),
    .pin_enhs        ( pin_enhs         ),
    .pin_envs        ( pin_envs         ),
    .r0_2or6         ( r0_2or6          ),
    .dclk2           ( dclk2            ),
    .dclk3           ( dclk3            ),
    .pin_dclk        ( pin_dclk         ),
    .dclk3_buf       ( dclk3_buf        ),
    .hload_n         ( hload_n          ),
    .hcnt            ( hcnt             ),
    .vcnt            ( vcnt             ),
    .pin_nhsy        ( pin_nhsy         ),
    .pin_nhbl        ( pin_nhbl         ),
    .pin_nvsy        ( pin_nvsy         ),
    .pin_nvbl        ( pin_nvbl         ),
    .pin_irq         ( pin_irq          ),
    .pin_firq        ( pin_firq         ),
    .pin_nmi         ( pin_nmi          ),
    .hcnt0f          ( hcnt0f           ),
    .hcnt1f          ( hcnt1f           ),
    .p40b_y          ( p40b_y           ),
    .n107b_y         ( n107b_y          ),
    .n29_co          ( n29_co           ),
    .m25_co          ( m25_co           ),
    .r34_xq          ( r34_xq           ),
    .n8b_y           ( n8b_y            ),
    .n9a_q           ( n9a_q            ),
    .p140_q          ( p140_q           ),
    .p140_xq         ( p140_xq          ),
    .p140_q_n        ( p140_q_n         ),
    .p140_xq_n       ( p140_xq_n        ),
    .n186_x0         ( n186_x0          ),
    .n186_x0_n       ( n186_x0_n        ),
    .n186_x1         ( n186_x1          ),
    .n186_x1_n       ( n186_x1_n        ),
    .n186_x2         ( n186_x2          ),
    .n186_x3         ( n186_x3          ),
    .n186_x2_n       ( n186_x2_n        ),
    .n186_x3_n       ( n186_x3_n        ),
    .n186_x2t_n      ( n186_x2t_n       ),
    .n186_x3t_n      ( n186_x3t_n       ),
    .n186_x2t_buf_n  ( n186_x2t_buf_n   ),
    .n186_x3t_buf_n  ( n186_x3t_buf_n   ),
    .pin_s2h         ( pin_s2h          ),
    .pin_s4h         ( pin_s4h          )
);

jt054156_cpu_frontend u_cpu_frontend(
    .pin_ab        ( pin_ab        ),
    .pin_db_in     ( pin_db_in     ),
    .pin_nrcs      ( pin_nrcs      ),
    .hload_n       ( hload_n       ),
    .pin_cram      ( pin_cram      ),
    .pin_lds       ( pin_lds       ),
    .pin_uds       ( pin_uds       ),
    .pin_nrd       ( pin_nrd       ),
    .pin_nvcs      ( pin_nvcs      ),
    .reset2_n      ( reset2_n      ),
    .reset3_n      ( reset3_n      ),
    .reset4_n      ( reset4_n      ),
    .reset6_n      ( reset6_n      ),
    .reset7_n      ( reset7_n      ),
    .reset8_n      ( reset8_n      ),
    .reset9_n      ( reset9_n      ),
    .reset11_n     ( reset11_n     ),
    .reset12_n     ( reset12_n     ),
    .reset13_n     ( reset13_n     ),
    .reset14_n     ( reset14_n     ),
    .reset16_n     ( reset16_n     ),
    .reset17_n     ( reset17_n     ),
    .reset18_n     ( reset18_n     ),
    .reset20_n     ( reset20_n     ),
    .access_l_n    ( access_l_n    ),
    .access_u_n    ( access_u_n    ),
    .pin_db_l_oe   ( pin_db_l_oe   ),
    .pin_db_u_oe   ( pin_db_u_oe   ),
    .pin_nre       ( pin_nre       ),
    .l125a_y       ( l125a_y       ),
    .p113b_y       ( p113b_y       ),
    .p170b_y       ( p170b_y       ),
    .regc_db0_buf  ( regc_db0_buf  ),
    .regc_db1_buf  ( regc_db1_buf  ),
    .p110b_y       ( p110b_y       ),
    .db_in_buf     ( db_in_buf     ),
    .db_in_buf2    ( db_in_buf2    ),
    .db_in_buf3    ( db_in_buf3    ),
    .db_in_buf4    ( db_in_buf4    ),
    .reg0_db       ( reg0_db       ),
    .reg2_db       ( reg2_db       ),
    .reg4_db       ( reg4_db       ),
    .reg6_db       ( reg6_db       ),
    .reg8_db       ( reg8_db       ),
    .rega_db       ( rega_db       ),
    .regc_db       ( regc_db       ),
    .reg10_d       ( reg10_d       ),
    .reg12_d       ( reg12_d       ),
    .reg14_d       ( reg14_d       ),
    .reg16_d       ( reg16_d       ),
    .reg18_d       ( reg18_d       ),
    .reg1a_d       ( reg1a_d       ),
    .reg1c_d       ( reg1c_d       ),
    .reg1e_d       ( reg1e_d       ),
    .reg20_d       ( reg20_d       ),
    .reg22_d       ( reg22_d       ),
    .reg24_d       ( reg24_d       ),
    .reg26_d       ( reg26_d       ),
    .reg28_d       ( reg28_d       ),
    .reg2a_d       ( reg2a_d       ),
    .reg2c_d       ( reg2c_d       ),
    .reg2e_d       ( reg2e_d       ),
    .reg30_d       ( reg30_d       ),
    .reg32_d       ( reg32_d       ),
    .reg34u_d      ( reg34u_d      ),
    .reg34l_d      ( reg34l_d      ),
    .reg36_d       ( reg36_d       ),
    .reg38_d       ( reg38_d       ),
    .reg3a_d       ( reg3a_d       ),
    .reg3c_d       ( reg3c_d       ),
    .reg0_wr_n     ( reg0_wr_n     ),
    .reg2_wr_n     ( reg2_wr_n     ),
    .reg4_wr_n     ( reg4_wr_n     ),
    .reg6_wr_n     ( reg6_wr_n     ),
    .reg8_wr_n     ( reg8_wr_n     ),
    .rega_wr_n     ( rega_wr_n     ),
    .regc_wr_n     ( regc_wr_n     ),
    .reg10_wr_n    ( reg10_wr_n    ),
    .reg12_wr_n    ( reg12_wr_n    ),
    .reg14_wr_n    ( reg14_wr_n    ),
    .reg16_wr_n    ( reg16_wr_n    ),
    .reg18_wr_n    ( reg18_wr_n    ),
    .reg1a_wr_n    ( reg1a_wr_n    ),
    .reg1c_wr_n    ( reg1c_wr_n    ),
    .reg1e_wr_n    ( reg1e_wr_n    ),
    .reg20u_wr_n   ( reg20u_wr_n   ),
    .reg20l_wr_n   ( reg20l_wr_n   ),
    .reg22u_wr_n   ( reg22u_wr_n   ),
    .reg22l_wr_n   ( reg22l_wr_n   ),
    .reg24u_wr_n   ( reg24u_wr_n   ),
    .reg24l_wr_n   ( reg24l_wr_n   ),
    .reg26u_wr_n   ( reg26u_wr_n   ),
    .reg26l_wr_n   ( reg26l_wr_n   ),
    .reg28u_wr_n   ( reg28u_wr_n   ),
    .reg28l_wr_n   ( reg28l_wr_n   ),
    .reg2au_wr_n   ( reg2au_wr_n   ),
    .reg2al_wr_n   ( reg2al_wr_n   ),
    .reg2cu_wr_n   ( reg2cu_wr_n   ),
    .reg2cl_wr_n   ( reg2cl_wr_n   ),
    .reg2eu_wr_n   ( reg2eu_wr_n   ),
    .reg2el_wr_n   ( reg2el_wr_n   ),
    .reg30_wr_n    ( reg30_wr_n    ),
    .reg32_wr_n    ( reg32_wr_n    ),
    .reg34u_wr_n   ( reg34u_wr_n   ),
    .reg34l_wr_n   ( reg34l_wr_n   ),
    .reg36_wr_n    ( reg36_wr_n    ),
    .reg38u_wr_n   ( reg38u_wr_n   ),
    .reg38l_wr_n   ( reg38l_wr_n   ),
    .reg3au_wr_n   ( reg3au_wr_n   ),
    .reg3al_wr_n   ( reg3al_wr_n   ),
    .reg3cu_wr_n   ( reg3cu_wr_n   ),
    .reg3cl_wr_n   ( reg3cl_wr_n   ),
    .n53_x_n       ( n53_x_n       )
);

// Inlined jt054156_page01_ab_latch_en u_ab_latch_en
wire u_ab_latch_en__unused_p174a_nq;
wire u_ab_latch_en__unused_p179a_nq;
wire u_ab_latch_en__unused_p165b_y;
wire u_ab_latch_en__unused_p144a_y;
wire u_ab_latch_en__unused_p188b_y;
wire u_ab_latch_en__unused_k209b_y;
reg     u_ab_latch_en__p174a_q;
reg     u_ab_latch_en__p179a_q;

wire    u_ab_latch_en__p174b_y, u_ab_latch_en__p164_y, u_ab_latch_en__p188a_y, u_ab_latch_en__p189a_y;
assign u_ab_latch_en__p174b_y = ~pin_clk; // p174b
assign u_ab_latch_en__p164_y = ~pin_nccs; // p164
always @(posedge u_ab_latch_en__p174b_y or negedge u_ab_latch_en__p164_y) begin
    if (!u_ab_latch_en__p164_y) begin
        u_ab_latch_en__p174a_q <= 1'b1;
    end else begin
        u_ab_latch_en__p174a_q <= pin_dclk;
    end
end // p174a

assign u_ab_latch_en__unused_p174a_nq = ~u_ab_latch_en__p174a_q; // p174a
assign u_ab_latch_en__unused_p165b_y = pin_dclk & u_ab_latch_en__unused_p174a_nq; // p165b
assign u_ab_latch_en__unused_p144a_y = reg4_db5 & pin_cram; // p144a
assign lat_ab_reg = ~|{u_ab_latch_en__unused_p165b_y,u_ab_latch_en__unused_p144a_y}; // p144b
assign u_ab_latch_en__p188a_y = ~pin_clk; // p188a
assign u_ab_latch_en__p189a_y = ~pin_nvcs; // p189a
always @(posedge u_ab_latch_en__p188a_y or negedge u_ab_latch_en__p189a_y) begin
    if (!u_ab_latch_en__p189a_y) begin
        u_ab_latch_en__p179a_q <= 1'b1;
    end else begin
        u_ab_latch_en__p179a_q <= pin_dclk;
    end
end // p179a

assign u_ab_latch_en__unused_p179a_nq = ~u_ab_latch_en__p179a_q; // p179a
assign u_ab_latch_en__unused_p188b_y = pin_dclk & u_ab_latch_en__unused_p179a_nq; // p188b
assign u_ab_latch_en__unused_k209b_y = ~reg0_db7; // k209b
assign lat_ab_ram = ~|{u_ab_latch_en__unused_p188b_y,u_ab_latch_en__unused_k209b_y}; // k199a
// End inlined jt054156_page01_ab_latch_en u_ab_latch_en

// Inlined jt054156_page01_ab_source u_ab_source
reg [10:0] u_ab_source__ab_ram;
reg [10:0] u_ab_source__ab_mux_ram;
reg [3:0] u_ab_source__e15_q;
reg     u_ab_source__e46_q;
reg     u_ab_source__e48_q;
reg     u_ab_source__e50_q;
reg [3:0] u_ab_source__e6_q;
reg [3:0] u_ab_source__f25_q;
reg [3:0] u_ab_source__f39_q;

wire [3:0] u_ab_source__f17_x, u_ab_source__f13_x, u_ab_source__g37_x, u_ab_source__f21_x;
wire [3:0] u_ab_source__e15_nq, u_ab_source__e6_nq, u_ab_source__f25_nq, u_ab_source__f39_nq;
wire    u_ab_source__h49a_x, u_ab_source__h51b_x, u_ab_source__h51a_x;
wire    u_ab_source__g49b_x, u_ab_source__g51b_x, u_ab_source__g51a_x;
wire    u_ab_source__e48_xq, u_ab_source__e46_xq, u_ab_source__e50_xq;
assign reg4_db3_n = ~reg4_db3; // h109b
assign reg4_db3_buf = ~reg4_db3_n; // h50b

/* verilator lint_off LATCH */
always @(*) begin
    if (!lat_ab_reg) begin
        u_ab_source__e15_q = u_ab_source__f17_x;
    end
end // e15
/* verilator lint_on LATCH */

assign u_ab_source__e15_nq = ~u_ab_source__e15_q; // e15
assign { ab_mux_5_6, ab_mux_4_5, ab_mux_3_4, ab_mux_2_3 } = u_ab_source__e15_nq;


/* verilator lint_off LATCH */
always @(*) begin
    if (!lat_ab_reg) begin
        u_ab_source__e6_q = u_ab_source__f13_x;
    end
end // e6
/* verilator lint_on LATCH */

assign u_ab_source__e6_nq = ~u_ab_source__e6_q; // e6
assign { ab_mux_9_10, ab_mux_8_9, ab_mux_7_8, ab_mux_6_7 } = u_ab_source__e6_nq;

assign u_ab_source__h49a_x = reg4_db3_n ? ~pin_ab[10] : ~pin_ab[11]; // h49a
/* verilator lint_off LATCH */
always @(*) begin
    if (!lat_ab_reg) begin
        u_ab_source__e48_q = u_ab_source__h49a_x;
    end
end // e48
/* verilator lint_on LATCH */

assign u_ab_source__e48_xq = ~u_ab_source__e48_q; // e48
assign ab_mux_10_11 = u_ab_source__e48_xq;

assign u_ab_source__h51b_x = reg4_db3_n ? ~pin_ab[11] : ~pin_ab[12]; // h51b
/* verilator lint_off LATCH */
always @(*) begin
    if (!lat_ab_reg) begin
        u_ab_source__e46_q = u_ab_source__h51b_x;
    end
end // e46
/* verilator lint_on LATCH */

assign u_ab_source__e46_xq = ~u_ab_source__e46_q; // e46
assign ab_mux_11_12 = u_ab_source__e46_xq;

assign u_ab_source__h51a_x = reg4_db3_n ? ~pin_ab[12] : ~pin_ab[13]; // h51a
/* verilator lint_off LATCH */
always @(*) begin
    if (!lat_ab_reg) begin
        u_ab_source__e50_q = u_ab_source__h51a_x;
    end
end // e50
/* verilator lint_on LATCH */

assign u_ab_source__e50_xq = ~u_ab_source__e50_q; // e50
assign ab_mux_12_13 = u_ab_source__e50_xq;

/* verilator lint_off LATCH */
always @(*) begin
    if (!lat_ab_ram) begin
        u_ab_source__ab_ram[3:0] = pin_ab[5:2];
    end
end // f32
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!lat_ab_ram) begin
        u_ab_source__ab_ram[7:4] = pin_ab[9:6];
    end
end // f46
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!lat_ab_ram) begin
        u_ab_source__ab_ram[8] = pin_ab[10];
    end
end // g60
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!lat_ab_ram) begin
        u_ab_source__ab_ram[9] = pin_ab[11];
    end
end // g62
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!lat_ab_ram) begin
        u_ab_source__ab_ram[10] = pin_ab[12];
    end
end // g64
/* verilator lint_on LATCH */
assign regc_db1_ab_buf = regc_db1; // h109a
assign regc_db1_n = ~regc_db1_ab_buf; // g48a

/* verilator lint_off LATCH */
always @(*) begin
    if (!lat_ab_ram) begin
        u_ab_source__f25_q = u_ab_source__g37_x;
    end
end // f25
/* verilator lint_on LATCH */

assign u_ab_source__f25_nq = ~u_ab_source__f25_q; // f25
assign u_ab_source__ab_mux_ram[3:0] = u_ab_source__f25_nq;


/* verilator lint_off LATCH */
always @(*) begin
    if (!lat_ab_ram) begin
        u_ab_source__f39_q = u_ab_source__f21_x;
    end
end // f39
/* verilator lint_on LATCH */

assign u_ab_source__f39_nq = ~u_ab_source__f39_q; // f39
assign u_ab_source__ab_mux_ram[7:4] = u_ab_source__f39_nq;

assign u_ab_source__g49b_x = regc_db1_ab_buf ? ~pin_ab[8] : ~pin_ab[9]; // g49b
/* verilator lint_off LATCH */
always @(*) begin
    if (!lat_ab_ram) begin
        u_ab_source__ab_mux_ram[8] = u_ab_source__g49b_x;
    end
end // g56
/* verilator lint_on LATCH */
assign u_ab_source__g51b_x = regc_db1_ab_buf ? ~pin_ab[9] : ~pin_ab[10]; // g51b
/* verilator lint_off LATCH */
always @(*) begin
    if (!lat_ab_ram) begin
        u_ab_source__ab_mux_ram[9] = u_ab_source__g51b_x;
    end
end // g54
/* verilator lint_on LATCH */
assign u_ab_source__g51a_x = regc_db1_ab_buf ? ~pin_ab[10] : ~pin_ab[11]; // g51a
/* verilator lint_off LATCH */
always @(*) begin
    if (!lat_ab_ram) begin
        u_ab_source__ab_mux_ram[10] = u_ab_source__g51a_x;
    end
end // g58
/* verilator lint_on LATCH */
assign ab_ram = u_ab_source__ab_ram;
assign ab_mux_ram = u_ab_source__ab_mux_ram;
// End inlined jt054156_page01_ab_source u_ab_source

jt054156_scroll_timing_ctrl u_scroll_timing(
    .pin_dclk          ( pin_dclk          ),
    .hcnt              ( hcnt_8_2          ),
    .hcnt0             ( hcnt0             ),
    .hcnt2             ( hcnt2             ),
    .p140_xq           ( p140_xq           ),
    .pin_nhsy          ( pin_nhsy          ),
    .reset20_n         ( reset20_n         ),
    .pin_test          ( pin_test          ),
    .vcnt              ( vcnt              ),
    .pin_vd_in         ( pin_vd_in         ),
    .tick_a            ( tick_a            ),
    .tick_b            ( tick_b            ),
    .tick_c            ( tick_c            ),
    .tick_d            ( tick_d            ),
    .reg0_db0          ( reg0_db0          ),
    .reg0_db4          ( reg0_db4          ),
    .reg0_db5          ( reg0_db5          ),
    .reg8_db           ( reg8_db_7_4       ),
    .rega_db           ( rega_db           ),
    .reg10_d           ( reg10_d           ),
    .reg12_d           ( reg12_d           ),
    .reg14_d           ( reg14_d           ),
    .reg16_d           ( reg16_d           ),
    .reg18_d           ( reg18_d           ),
    .reg1a_d           ( reg1a_d           ),
    .reg1c_d           ( reg1c_d           ),
    .reg1e_d           ( reg1e_d           ),
    .reg20_d           ( reg20_d           ),
    .reg22_d           ( reg22_d           ),
    .reg24_d           ( reg24_d           ),
    .reg26_d           ( reg26_d           ),
    .reg28_d           ( reg28_d           ),
    .reg2a_d           ( reg2a_d           ),
    .reg2c_d           ( reg2c_d           ),
    .reg2e_d           ( reg2e_d           ),
    .reg3al_d          ( reg3al_d          ),
    .reg3au_d          ( reg3au_d          ),
    .reg3cl_d          ( reg3c_d           ),
    .n186_x2t_n        ( n186_x2t_n        ),
    .n186_x3t_n        ( n186_x3t_n        ),
    .n186_x2t_buf_n    ( n186_x2t_buf_n    ),
    .n186_x3t_buf_n    ( n186_x3t_buf_n    ),
    .scrollx           ( scrollx           ),
    .scrolly           ( scrolly           ),
    .hs_mux            ( hs_mux            ),
    .hb_mux            ( hb_mux            ),
    .vs_mux            ( vs_mux            ),
    .vb_mux            ( vb_mux            ),
    .hsize_mux         ( hsize_mux         ),
    .vsize_mux         ( vsize_mux         ),
    .pagex             ( pagex             ),
    .pagey             ( pagey             ),
    .pin_z1h           ( pin_z1h           ),
    .pin_z2h           ( pin_z2h           ),
    .pin_z4h           ( pin_z4h           ),
    .pin_sz            ( pin_sz            ),
    .scrolly_en_mux    ( scrolly_en_mux    ),
    .n186_x2t_buf2_n   ( n186_x2t_buf2_n   ),
    .n186_x2t_buf2     ( n186_x2t_buf2     ),
    .n186_x3t_buf2_n   ( n186_x3t_buf2_n   ),
    .n186_x3t_buf2     ( n186_x3t_buf2     ),
    .n186_x2t_buf3_n   ( n186_x2t_buf3_n   ),
    .n186_x2t_buf3     ( n186_x2t_buf3     ),
    .n186_x3t_buf3_n   ( n186_x3t_buf3_n   ),
    .n186_x3t_buf3     ( n186_x3t_buf3     )
);

// Inlined jt054156_page06_linescroll_ctrl u_linescroll_ctrl
wire u_linescroll_ctrl__unused_h74_y;
wire u_linescroll_ctrl__unused_h75a_y;
wire u_linescroll_ctrl__unused_h72a_y;
wire u_linescroll_ctrl__unused_h77b_y;
wire u_linescroll_ctrl__unused_n71a_y;
wire u_linescroll_ctrl__unused_n75a_y;
wire u_linescroll_ctrl__unused_n171_nq;
wire u_linescroll_ctrl__unused_n178_nq;
wire u_linescroll_ctrl__unused_j181b_y;
wire [3:0] u_linescroll_ctrl__unused_n174_x_n;
wire [3:0] u_linescroll_ctrl__unused_rega_odd_n;
wire [3:0] u_linescroll_ctrl__unused_tick_mask_n;
reg     u_linescroll_ctrl__n171_q;
reg     u_linescroll_ctrl__n178_q;

assign u_linescroll_ctrl__unused_h74_y = scrolly_2_0[0] ^ reg0_db5; // h74
assign u_linescroll_ctrl__unused_h75a_y = scrolly_2_0[1] ^ reg0_db5; // h75a
assign u_linescroll_ctrl__unused_h72a_y = scrolly_2_0[2] ^ reg0_db5; // h72a
assign u_linescroll_ctrl__unused_h77b_y = ~|{u_linescroll_ctrl__unused_h74_y,u_linescroll_ctrl__unused_h75a_y,u_linescroll_ctrl__unused_h72a_y}; // h77b
assign u_linescroll_ctrl__unused_n71a_y = pin_nhsy & pin_sz; // n71a
assign u_linescroll_ctrl__unused_n75a_y = u_linescroll_ctrl__unused_h77b_y & u_linescroll_ctrl__unused_n71a_y; // n75a
assign u_linescroll_ctrl__unused_rega_odd_n[0] = ~rega_db_7_1[1]; // h160a
assign u_linescroll_ctrl__unused_rega_odd_n[1] = ~rega_db_7_1[3]; // h161b
assign u_linescroll_ctrl__unused_rega_odd_n[2] = ~rega_db_7_1[5]; // j177a
assign u_linescroll_ctrl__unused_rega_odd_n[3] = ~rega_db_7_1[7]; // j180a
assign u_linescroll_ctrl__unused_tick_mask_n[0] = ~|{u_linescroll_ctrl__unused_n75a_y,u_linescroll_ctrl__unused_rega_odd_n[0]}; // n164b
assign u_linescroll_ctrl__unused_tick_mask_n[1] = ~|{u_linescroll_ctrl__unused_n75a_y,u_linescroll_ctrl__unused_rega_odd_n[1]}; // n163a
assign u_linescroll_ctrl__unused_tick_mask_n[2] = ~|{u_linescroll_ctrl__unused_n75a_y,u_linescroll_ctrl__unused_rega_odd_n[2]}; // n169b
assign u_linescroll_ctrl__unused_tick_mask_n[3] = ~|{u_linescroll_ctrl__unused_n75a_y,u_linescroll_ctrl__unused_rega_odd_n[3]}; // n170b
always @(posedge pin_dclk) begin
    {u_linescroll_ctrl__n171_q,u_linescroll_ctrl__n178_q} <= {n186_x3,n186_x2}; // n171, n178
end

assign u_linescroll_ctrl__unused_n171_nq = ~u_linescroll_ctrl__n171_q; // n171
assign u_linescroll_ctrl__unused_n178_nq = ~u_linescroll_ctrl__n178_q; // n178
assign u_linescroll_ctrl__unused_j181b_y = ~&{pin_sz,n186_x1_n}; // j181b
assign u_linescroll_ctrl__unused_n174_x_n = ~u_linescroll_ctrl__unused_j181b_y ? ~(4'b0001 << { u_linescroll_ctrl__unused_n178_nq, u_linescroll_ctrl__unused_n171_nq }) : 4'hf; // n174
assign tick_a = u_linescroll_ctrl__unused_tick_mask_n[0] | u_linescroll_ctrl__unused_n174_x_n[0]; // n165b
assign tick_b = u_linescroll_ctrl__unused_tick_mask_n[1] | u_linescroll_ctrl__unused_n174_x_n[1]; // n164a
assign tick_c = u_linescroll_ctrl__unused_tick_mask_n[2] | u_linescroll_ctrl__unused_n174_x_n[2]; // n167b
assign tick_d = u_linescroll_ctrl__unused_tick_mask_n[3] | u_linescroll_ctrl__unused_n174_x_n[3]; // n167a
// End inlined jt054156_page06_linescroll_ctrl u_linescroll_ctrl

jt054156_vram_ctrl u_vram_ctrl(
    .reset2_n        ( reset2_n        ),
    .pin_clk         ( pin_clk         ),
    .pin_cram        ( pin_cram        ),
    .pin_nvcs        ( pin_nvcs        ),
    .pin_nrd_inv     ( pin_nrd_inv     ),
    .pin_sz          ( pin_sz          ),
    .pin_ab          ( pin_ab          ),
    .n53_x_n         ( n53_x_n         ),
    .reg0_db         ( reg0_db         ),
    .reg6_db         ( reg6_db         ),
    .reg8_db         ( reg8_db_3_0     ),
    .regc_db         ( regc_db         ),
    .regc_db0_buf    ( regc_db0_buf    ),
    .regc_db1_buf    ( regc_db1_buf    ),
    .reg30_d         ( reg30_d         ),
    .reg32_d         ( reg32_d         ),
    .dclk3           ( dclk3           ),
    .hcnt0           ( hcnt0           ),
    .n186_x0_n       ( n186_x0_n       ),
    .n186_x2_n       ( n186_x2_n       ),
    .n186_x3_n       ( n186_x3_n       ),
    .n186_x2t_n      ( n186_x2t_n      ),
    .n186_x3t_n      ( n186_x3t_n      ),
    .p140_q          ( p140_q          ),
    .p140_xq         ( p140_xq         ),
    .scrollx         ( scrollx         ),
    .scrolly         ( scrolly_8_0     ),
    .pagex           ( pagex           ),
    .pagey           ( pagey           ),
    .ab_ram          ( ab_ram          ),
    .ab_mux_ram      ( ab_mux_ram      ),
    .p113b_y         ( p113b_y         ),
    .p170b_y         ( p170b_y         ),
    .pin_va          ( pin_va          ),
    .pin_vd_dir_low  ( pin_vd_dir_low  ),
    .pin_vd_dir_mid  ( pin_vd_dir_mid  ),
    .pin_vd_dir_high ( pin_vd_dir_high ),
    .pin_oe0         ( pin_oe0         ),
    .pin_oe1         ( pin_oe1         ),
    .pin_oe2         ( pin_oe2         ),
    .pin_we0         ( pin_we0         ),
    .pin_we1         ( pin_we1         ),
    .pin_we2         ( pin_we2         ),
    .pin_csz1        ( pin_csz1        ),
    .pin_cs1         ( pin_cs1         ),
    .pin_csz2        ( pin_csz2        ),
    .pin_cs2         ( pin_cs2         ),
    .k209a           ( k209a           ),
    .h181a           ( h181a           ),
    .m191a           ( m191a           ),
    .pin_namp        ( pin_namp        ),
    .m201_xq         ( m201_xq         ),
    .m212a_y         ( m212a_y         ),
    .k206a_y         ( k206a_y         ),
    .k210b_y         ( k210b_y         )
);

// Inlined jt054156_page11_vd_latch u_vd_latch
reg [23:0] u_vd_latch__vd_latch;
assign k207a_y = reg0_db7 | m191a; // k207a
assign f78b_y = ~k207a_y; // f78b
/* verilator lint_off LATCH */
always @(*) begin
    if (!f78b_y) begin
        u_vd_latch__vd_latch[3:0] = pin_vd_in[3:0];
    end
end // f53
/* verilator lint_on LATCH */

assign vd_latch_n[3:0] = ~u_vd_latch__vd_latch[3:0]; // f53
/* verilator lint_off LATCH */
always @(*) begin
    if (!f78b_y) begin
        u_vd_latch__vd_latch[7:4] = pin_vd_in[7:4];
    end
end // c73
/* verilator lint_on LATCH */

assign vd_latch_n[7:4] = ~u_vd_latch__vd_latch[7:4]; // c73
/* verilator lint_off LATCH */
always @(*) begin
    if (!f78b_y) begin
        u_vd_latch__vd_latch[11:8] = pin_vd_in[11:8];
    end
end // c66
/* verilator lint_on LATCH */

assign vd_latch_n[11:8] = ~u_vd_latch__vd_latch[11:8]; // c66
/* verilator lint_off LATCH */
always @(*) begin
    if (!f78b_y) begin
        u_vd_latch__vd_latch[15:12] = pin_vd_in[15:12];
    end
end // b61
/* verilator lint_on LATCH */

assign vd_latch_n[15:12] = ~u_vd_latch__vd_latch[15:12]; // b61
/* verilator lint_off LATCH */
always @(*) begin
    if (!f78b_y) begin
        u_vd_latch__vd_latch[19:16] = pin_vd_in[19:16];
    end
end // e53
/* verilator lint_on LATCH */

assign vd_latch_n[19:16] = ~u_vd_latch__vd_latch[19:16]; // e53
/* verilator lint_off LATCH */
always @(*) begin
    if (!f78b_y) begin
        u_vd_latch__vd_latch[23:20] = pin_vd_in[23:20];
    end
end // b53
/* verilator lint_on LATCH */

assign vd_latch_n[23:20] = ~u_vd_latch__vd_latch[23:20]; // b53
// End inlined jt054156_page11_vd_latch u_vd_latch

jt054156_db_output u_db_output(
    .vd_latch_n ( vd_latch_n ),
    .regc_db0   ( regc_db0   ),
    .regc_db1   ( regc_db1   ),
    .reg6_db5   ( reg6_db5   ),
    .pin_uds    ( pin_uds    ),
    .pin_ab1    ( pin_ab1    ),
    .pin_ab11   ( pin_ab11   ),
    .pin_ab12   ( pin_ab12   ),
    .pin_db_out ( pin_db_out ),
    .p54a_y     (            ),
    .m53a_y     (            ),
    .m53b_y     (            ),
    .n25a_y     (            ),
    .n57b_y     (            ),
    .p43a_x     (            ),
    .p41_x      (            ),
    .p39a_x     (            ),
    .l54a_y     (            ),
    .l54b_y     (            ),
    .l78a_y     (            ),
    .l78b_y     (            ),
    .k79b_y     (            ),
    .k78b_y     (            ),
    .l105b_y    (            ),
    .l104a_y    (            ),
    .l53a_y     (            ),
    .l53b_y     (            )
);

// Inlined jt054156_page11_vd_out u_vd_out
wire u_vd_out__unused_p113a_y;
wire u_vd_out__unused_p121a_y;
wire u_vd_out__unused_f120b_y;
wire u_vd_out__unused_f122a_y;
wire u_vd_out__p109a_y, u_vd_out__p114b_y, u_vd_out__p112b_y, u_vd_out__p125a_y, u_vd_out__p118b_y, u_vd_out__p118a_x, u_vd_out__p112a_y;

// Inlined jt054156_page11_vd_out_ctrl u_vd_out_ctrl
assign u_vd_out__p114b_y = regc_db1; // p114b
assign u_vd_out__p112b_y = ~u_vd_out__p114b_y; // p112b
assign u_vd_out__p125a_y = regc_db0; // p125a
assign u_vd_out__p118b_y = ~u_vd_out__p125a_y; // p118b
assign u_vd_out__p109a_y = ~pin_ab12; // p109a
assign u_vd_out__p118a_x = ~(u_vd_out__p114b_y ? (u_vd_out__p125a_y ? u_vd_out__p114b_y : u_vd_out__p114b_y) : (u_vd_out__p125a_y ? u_vd_out__p109a_y : pin_ab1)); // p118a
assign u_vd_out__p112a_y = ~u_vd_out__p118a_x; // p112a
assign u_vd_out__unused_p113a_y = reg6_db5 & u_vd_out__p112a_y; // p113a
assign u_vd_out__unused_p121a_y = &{l125a_y,reg6_db5,u_vd_out__p112b_y}; // p121a
// End inlined jt054156_page11_vd_out_ctrl u_vd_out_ctrl

// Inlined jt054156_page11_vd_out_mux u_vd_out_mux
wire [3:0] u_vd_out_mux__f108_x, u_vd_out_mux__f114_x, u_vd_out_mux__f123_x, u_vd_out_mux__g124_x;

assign pin_vd_out[18] = u_vd_out_mux__f108_x[0];
assign pin_vd_out[10] = u_vd_out_mux__f108_x[0];
assign pin_vd_out[16] = u_vd_out_mux__f108_x[1];
assign pin_vd_out[8]  = u_vd_out_mux__f108_x[1];
assign pin_vd_out[19] = u_vd_out_mux__f108_x[2];
assign pin_vd_out[11] = u_vd_out_mux__f108_x[2];
assign pin_vd_out[17] = u_vd_out_mux__f108_x[3];
assign pin_vd_out[9]  = u_vd_out_mux__f108_x[3];

assign pin_vd_out[22] = u_vd_out_mux__f114_x[0];
assign pin_vd_out[14] = u_vd_out_mux__f114_x[0];
assign pin_vd_out[20] = u_vd_out_mux__f114_x[1];
assign pin_vd_out[12] = u_vd_out_mux__f114_x[1];
assign pin_vd_out[23] = u_vd_out_mux__f114_x[2];
assign pin_vd_out[15] = u_vd_out_mux__f114_x[2];
assign pin_vd_out[21] = u_vd_out_mux__f114_x[3];
assign pin_vd_out[13] = u_vd_out_mux__f114_x[3];

assign pin_vd_out[2] = u_vd_out_mux__f123_x[0];
assign pin_vd_out[0] = u_vd_out_mux__f123_x[1];
assign pin_vd_out[3] = u_vd_out_mux__f123_x[2];
assign pin_vd_out[1] = u_vd_out_mux__f123_x[3];

assign pin_vd_out[6] = u_vd_out_mux__g124_x[0];
assign pin_vd_out[4] = u_vd_out_mux__g124_x[1];
assign pin_vd_out[7] = u_vd_out_mux__g124_x[2];
assign pin_vd_out[5] = u_vd_out_mux__g124_x[3];

assign u_vd_out__unused_f120b_y = ~u_vd_out__unused_p113a_y; // f120b
assign u_vd_out__unused_f122a_y = ~u_vd_out__unused_p121a_y; // f122a
assign u_vd_out_mux__f108_x[0] = u_vd_out__unused_p113a_y ? pin_db_hi_in[10] : db_in_buf2[2]; // f108
assign u_vd_out_mux__f108_x[1] = u_vd_out__unused_p113a_y ? pin_db_hi_in[8] : db_in_buf2[0]; // f108
assign u_vd_out_mux__f108_x[2] = u_vd_out__unused_p113a_y ? pin_db_hi_in[11] : db_in_buf2[3]; // f108
assign u_vd_out_mux__f108_x[3] = u_vd_out__unused_p113a_y ? pin_db_hi_in[9] : db_in_buf2[1]; // f108
assign u_vd_out_mux__f114_x[0] = u_vd_out__unused_p113a_y ? pin_db_hi_in[14] : db_in_buf2[6]; // f114
assign u_vd_out_mux__f114_x[1] = u_vd_out__unused_p113a_y ? pin_db_hi_in[12] : db_in_buf2[4]; // f114
assign u_vd_out_mux__f114_x[2] = u_vd_out__unused_p113a_y ? pin_db_hi_in[15] : db_in_buf2[7]; // f114
assign u_vd_out_mux__f114_x[3] = u_vd_out__unused_p113a_y ? pin_db_hi_in[13] : db_in_buf2[5]; // f114
assign u_vd_out_mux__f123_x[0] = u_vd_out__unused_p121a_y ? pin_db_hi_in[10] : db_in_buf2[2]; // f123
assign u_vd_out_mux__f123_x[1] = u_vd_out__unused_p121a_y ? pin_db_hi_in[8] : db_in_buf2[0]; // f123
assign u_vd_out_mux__f123_x[2] = u_vd_out__unused_p121a_y ? pin_db_hi_in[11] : db_in_buf2[3]; // f123
assign u_vd_out_mux__f123_x[3] = u_vd_out__unused_p121a_y ? pin_db_hi_in[9] : db_in_buf2[1]; // f123
assign u_vd_out_mux__g124_x[0] = u_vd_out__unused_p121a_y ? pin_db_hi_in[14] : db_in_buf2[6]; // g124
assign u_vd_out_mux__g124_x[1] = u_vd_out__unused_p121a_y ? pin_db_hi_in[12] : db_in_buf2[4]; // g124
assign u_vd_out_mux__g124_x[2] = u_vd_out__unused_p121a_y ? pin_db_hi_in[15] : db_in_buf2[7]; // g124
assign u_vd_out_mux__g124_x[3] = u_vd_out__unused_p121a_y ? pin_db_hi_in[13] : db_in_buf2[5]; // g124
// End inlined jt054156_page11_vd_out_mux u_vd_out_mux
// End inlined jt054156_page11_vd_out u_vd_out

// Inlined jt054156_page12_select_source u_page12_select_source
wire u_page12_select_source__unused_h154_y;
wire u_page12_select_source__unused_h149a_y;
wire u_page12_select_source__unused_h161a_y;
wire u_page12_select_source__unused_h154_h149a_y;
wire u_page12_select_source__unused_d44_y;
wire u_page12_select_source__unused_d5a_y;
assign u_page12_select_source__unused_h154_y = n186_x1 | pin_dac; // h154
assign u_page12_select_source__unused_h149a_y = reg4_db6 ^ reg4_db5; // h149a
assign u_page12_select_source__unused_h161a_y = ~pin_cram; // h161a
assign u_page12_select_source__unused_h154_h149a_y = u_page12_select_source__unused_h154_y & u_page12_select_source__unused_h149a_y; // h154_h149a
assign u_page12_select_source__unused_d44_y = ~|{u_page12_select_source__unused_h154_h149a_y,u_page12_select_source__unused_h161a_y}; // d44
assign u_page12_select_source__unused_d5a_y = u_page12_select_source__unused_d44_y; // d5a
assign sel_sa = ~u_page12_select_source__unused_d5a_y; // d6b
assign sel_sb = u_page12_select_source__unused_d5a_y;
// End inlined jt054156_page12_select_source u_page12_select_source

// Inlined jt054156_page12_outputs u_page12_outputs
wire [8:3]  u_page12_outputs__scrollx_l;
wire [2:0]  u_page12_outputs__scrolly_l;
wire [2:0]  u_page12_outputs__scrolly_t2b_x, u_page12_outputs__scrolly_mux;
wire [3:0]  u_page12_outputs__d19_a, u_page12_outputs__d19_b, u_page12_outputs__c43_q;
wire [1:0]  u_page12_outputs__lut_addr, u_page12_outputs__lut_addr_n;
wire [11:0] u_page12_outputs__pin_ca_low;
wire [18:12] u_page12_outputs__pin_ca_high;
wire [3:0]  u_page12_outputs__d19_x;
wire        u_page12_outputs__e52a_y, u_page12_outputs__h162_y, u_page12_outputs__e14a_y, u_page12_outputs__h156_q;
wire        u_page12_outputs__n186_x3_dly, u_page12_outputs__n186_x3_dly_n;
wire        u_page12_outputs__j18a_y, u_page12_outputs__j6a_y, u_page12_outputs__c13b_y;
wire        u_page12_outputs__vd_reg_10_18, u_page12_outputs__vd_reg_8_16, u_page12_outputs__vd_reg_11_19, u_page12_outputs__vd_reg_9_17;
wire        u_page12_outputs__vd_reg_14_22, u_page12_outputs__vd_reg_12_20, u_page12_outputs__vd_reg_15_23, u_page12_outputs__vd_reg_13_21;
wire        u_page12_outputs__h37a_y, u_page12_outputs__h38b_y, u_page12_outputs__h38a_x, u_page12_outputs__h33a_x, u_page12_outputs__j33a_x;
wire        u_page12_outputs__b11a_x, u_page12_outputs__b13a_x, u_page12_outputs__b7b_y, u_page12_outputs__b8b_y;
wire        u_page12_outputs__g171b_y, u_page12_outputs__g172b_y, u_page12_outputs__g165_x, u_page12_outputs__b12b_y;
wire [2:0]  u_page12_outputs__g165_a, u_page12_outputs__g165_b, u_page12_outputs__g165_c, u_page12_outputs__g165_d;

assign pin_ca[11:0]  = u_page12_outputs__pin_ca_low;
assign pin_ca[18:12] = u_page12_outputs__pin_ca_high;

assign u_page12_outputs__g165_a = { reg8_db_3_0[0], u_page12_outputs__g171b_y,     n186_x2       };
assign u_page12_outputs__g165_b = { reg8_db_3_0[1], u_page12_outputs__g171b_y,     u_page12_outputs__g172b_y       };
assign u_page12_outputs__g165_c = { reg8_db_3_0[2], u_page12_outputs__n186_x3_dly, n186_x2       };
assign u_page12_outputs__g165_d = { reg8_db_3_0[3], u_page12_outputs__n186_x3_dly, u_page12_outputs__g172b_y       };

assign u_page12_outputs__d19_a[0] = scrollx_xor[5];
assign u_page12_outputs__d19_b[0] = scrolly_xor[2];
assign u_page12_outputs__d19_a[1] = scrollx_xor[3];
assign u_page12_outputs__d19_b[1] = scrolly_xor[0];
assign u_page12_outputs__d19_a[2] = scrollx_xor[6];
assign u_page12_outputs__d19_b[2] = vd_reg[0];
assign u_page12_outputs__d19_a[3] = scrollx_xor[4];
assign u_page12_outputs__d19_b[3] = scrolly_xor[1];

assign u_page12_outputs__c43_q = vd_reg[7:4];

// Inlined jt054156_page12_scroll_capture u_scroll_capture
reg u_scroll_capture__h156_q;
reg u_scroll_capture__n186_x3_dly;
reg [3:0] u_scroll_capture__c25_q, u_scroll_capture__c15_q, u_scroll_capture__h3_q;
reg     u_scroll_capture__c7_q, u_scroll_capture__e22_q, u_scroll_capture__f8_q;
reg     u_scroll_capture__h14_q, u_scroll_capture__h17_q, u_scroll_capture__h20_q;
wire [3:0] u_scroll_capture__c25_d, u_scroll_capture__c15_d, u_scroll_capture__h3_d;
assign u_scroll_capture__c25_d = { scrollx[6], scrollx[5], scrollx[4], scrollx[3] };
assign u_scroll_capture__c15_d = { u_scroll_capture__e22_q,     u_scroll_capture__c25_q[3],   u_scroll_capture__c25_q[2],   u_scroll_capture__c25_q[1]   };
assign u_scroll_capture__h3_d  = { u_scroll_capture__h20_q,     u_scroll_capture__h17_q,      u_scroll_capture__h14_q,      u_scroll_capture__f8_q       };

assign u_page12_outputs__scrollx_l[3] = u_scroll_capture__c7_q;
assign u_page12_outputs__scrollx_l[4] = u_scroll_capture__c15_q[0];
assign u_page12_outputs__scrollx_l[5] = u_scroll_capture__c15_q[1];
assign u_page12_outputs__scrollx_l[6] = u_scroll_capture__c15_q[2];
assign u_page12_outputs__scrollx_l[7] = u_scroll_capture__c15_q[3];
assign u_page12_outputs__scrollx_l[8] = u_scroll_capture__h3_q[0];

assign u_page12_outputs__scrolly_l[0] = u_scroll_capture__h3_q[1];
assign u_page12_outputs__scrolly_l[1] = u_scroll_capture__h3_q[2];
assign u_page12_outputs__scrolly_l[2] = u_scroll_capture__h3_q[3];

assign u_page12_outputs__e52a_y = ~n186_x0; // e52a
assign u_page12_outputs__h162_y = ~n186_x3; // h162
always @(posedge u_page12_outputs__e52a_y) begin
    u_scroll_capture__h156_q <= u_page12_outputs__h162_y; // h156
end
always @(posedge n186_x0) begin
    u_scroll_capture__n186_x3_dly <= u_scroll_capture__h156_q; // g151
end

assign u_page12_outputs__n186_x3_dly_n = ~u_scroll_capture__n186_x3_dly; // g151
assign u_page12_outputs__e14a_y = u_page12_outputs__e52a_y; // e14a
always @(posedge u_page12_outputs__e14a_y) begin
    u_scroll_capture__c25_q <= u_scroll_capture__c25_d; // c25
end
always @(posedge u_page12_outputs__e14a_y) begin
    {u_scroll_capture__e22_q,u_scroll_capture__f8_q} <= {scrollx[7],scrollx[8]}; // e22, f8
end
assign u_page12_outputs__j18a_y = scrolly_2_0[0] | pin_test; // j18a
always @(posedge u_page12_outputs__e14a_y) begin
    {u_scroll_capture__h14_q,u_scroll_capture__h17_q,u_scroll_capture__h20_q} <= {u_page12_outputs__j18a_y,scrolly_2_0[1],scrolly_2_0[2]}; // h14, h17, h20
end
always @(posedge n186_x0) begin
    u_scroll_capture__c7_q <= u_scroll_capture__c25_q[0]; // c7
end
always @(posedge n186_x0) begin
    {u_scroll_capture__c15_q,u_scroll_capture__h3_q} <= {u_scroll_capture__c15_d,u_scroll_capture__h3_d}; // c15, h3
end
assign u_page12_outputs__j6a_y = ~pin_test; // j6a
assign u_page12_outputs__scrolly_t2b_x[0] = pin_test ? ~u_scroll_capture__h3_q[1] : ~scrolly_2_0[0]; // j8b
assign u_page12_outputs__scrolly_t2b_x[1] = pin_test ? ~u_scroll_capture__h3_q[2] : ~scrolly_2_0[1]; // j10b
assign u_page12_outputs__scrolly_t2b_x[2] = pin_test ? ~u_scroll_capture__h3_q[3] : ~scrolly_2_0[2]; // j9a
assign u_page12_outputs__scrolly_mux[0] = ~u_page12_outputs__scrolly_t2b_x[0]; // j8a
assign u_page12_outputs__scrolly_mux[1] = ~u_page12_outputs__scrolly_t2b_x[1]; // j7b
assign u_page12_outputs__scrolly_mux[2] = ~u_page12_outputs__scrolly_t2b_x[2]; // j6b
assign scrollx_xor[3] = u_scroll_capture__c7_q ^ h36_y; // c5a
assign scrollx_xor[4] = u_scroll_capture__c15_q[0] ^ h36_y; // c11a
assign scrollx_xor[5] = u_scroll_capture__c15_q[1] ^ h36_y; // c13a
assign scrollx_xor[6] = u_scroll_capture__c15_q[2] ^ h36_y; // c10
assign scrollx_xor[7] = u_scroll_capture__c15_q[3] ^ h36_y; // b10
assign scrollx_xor[8] = u_scroll_capture__h3_q[0] ^ h36_y; // b8a
assign scrolly_xor[0] = u_page12_outputs__scrolly_mux[0] ^ h36_y; // j15a
assign scrolly_xor[1] = u_page12_outputs__scrolly_mux[1] ^ h36_y; // j14
assign scrolly_xor[2] = u_page12_outputs__scrolly_mux[2] ^ h36_y; // j11a
assign u_page12_outputs__h156_q = u_scroll_capture__h156_q;
assign u_page12_outputs__n186_x3_dly = u_scroll_capture__n186_x3_dly;
// End inlined jt054156_page12_scroll_capture u_scroll_capture

// Inlined jt054156_page06_flip_en_mux u_flip_en_mux
wire u_flip_en_mux__g169a_y;

assign u_flip_en_mux__g169a_y = ~n186_x2; // g169a
jt054156_t5a u_g130(
    .a1 ( reg2_db[3]     ),
    .a2 ( reg2_db[1]     ),
    .s1 ( u_flip_en_mux__g169a_y       ),
    .s2 ( n186_x2       ),
    .s5 ( u_page12_outputs__n186_x3_dly_n ),
    .s6 ( u_page12_outputs__n186_x3_dly   ),
    .s3 ( u_flip_en_mux__g169a_y       ),
    .s4 ( n186_x2       ),
    .b1 ( reg2_db[7]     ),
    .b2 ( reg2_db[5]     ),
    .x  ( vflip_en_mux   )
);

jt054156_t5a u_g132a(
    .a1 ( reg2_db[2]     ),
    .a2 ( reg2_db[0]     ),
    .s1 ( u_flip_en_mux__g169a_y       ),
    .s2 ( n186_x2       ),
    .s5 ( u_page12_outputs__n186_x3_dly_n ),
    .s6 ( u_page12_outputs__n186_x3_dly   ),
    .s3 ( u_flip_en_mux__g169a_y       ),
    .s4 ( n186_x2       ),
    .b1 ( reg2_db[6]     ),
    .b2 ( reg2_db[4]     ),
    .x  ( hflip_en_mux   )
);
// End inlined jt054156_page06_flip_en_mux u_flip_en_mux

assign u_page12_outputs__g171b_y = ~u_page12_outputs__n186_x3_dly; // g171b
assign u_page12_outputs__g172b_y = ~n186_x2; // g172b
assign u_page12_outputs__g165_x = ~(|{ &u_page12_outputs__g165_a, &u_page12_outputs__g165_b, &u_page12_outputs__g165_c, &u_page12_outputs__g165_d }); // g165
assign u_page12_outputs__b12b_y = ~u_page12_outputs__g165_x; // b12b
// Inlined jt054156_page12_vd_capture u_vd_capture
reg [3:0] u_vd_capture__d43_q, u_vd_capture__c43_q, u_vd_capture__c56_q, u_vd_capture__b43_q, u_vd_capture__d31_q, u_vd_capture__b15_q;
assign vd_reg[ 3: 0] = u_vd_capture__d43_q;
assign vd_reg[ 7: 4] = u_vd_capture__c43_q;
assign vd_reg[11: 8] = u_vd_capture__c56_q;
assign vd_reg[15:12] = u_vd_capture__b43_q;
assign vd_reg[19:16] = u_vd_capture__d31_q;
assign vd_reg[23:20] = u_vd_capture__b15_q;

always @(posedge n186_x0) begin
    {u_vd_capture__d43_q,u_vd_capture__c43_q,u_vd_capture__c56_q,u_vd_capture__b43_q,u_vd_capture__d31_q,u_vd_capture__b15_q} <= {pin_vd_in[3:0],pin_vd_in[7:4],pin_vd_in[11:8],pin_vd_in[15:12],pin_vd_in[19:16],pin_vd_in[23:20]}; // d43, c43, c56, b43, d31, b15
end
assign u_page12_outputs__c13b_y = ~reg6_db4; // c13b
assign u_page12_outputs__vd_reg_10_18 = reg6_db4 ? u_vd_capture__c56_q[2] : u_vd_capture__d31_q[2]; // c35
assign u_page12_outputs__vd_reg_8_16 = reg6_db4 ? u_vd_capture__c56_q[0] : u_vd_capture__d31_q[0]; // c35
assign u_page12_outputs__vd_reg_11_19 = reg6_db4 ? u_vd_capture__c56_q[3] : u_vd_capture__d31_q[3]; // c35
assign u_page12_outputs__vd_reg_9_17 = reg6_db4 ? u_vd_capture__c56_q[1] : u_vd_capture__d31_q[1]; // c35
assign u_page12_outputs__vd_reg_14_22 = reg6_db4 ? u_vd_capture__b43_q[2] : u_vd_capture__b15_q[2]; // b35
assign u_page12_outputs__vd_reg_12_20 = reg6_db4 ? u_vd_capture__b43_q[0] : u_vd_capture__b15_q[0]; // b35
assign u_page12_outputs__vd_reg_15_23 = reg6_db4 ? u_vd_capture__b43_q[3] : u_vd_capture__b15_q[3]; // b35
assign u_page12_outputs__vd_reg_13_21 = reg6_db4 ? u_vd_capture__b43_q[1] : u_vd_capture__b15_q[1]; // b35
// End inlined jt054156_page12_vd_capture u_vd_capture

// Inlined jt054156_page06_attr_lu_col u_attr_lu_col
wire u_attr_lu_col__vd_reg_22;
wire u_attr_lu_col__vd_reg_23;
wire u_attr_lu_col__b26a_x, u_attr_lu_col__b31_x;
wire u_attr_lu_col__reg4_db0_buf, u_attr_lu_col__reg4_db0_n, u_attr_lu_col__reg4_db1_n, u_attr_lu_col__reg4_db2_n;

// Inlined jt054156_page06_lu_source u_lu_source
wire u_attr_lu_col__u_lu_source__reg4_db1;
wire u_attr_lu_col__u_lu_source__reg4_db2;
wire u_attr_lu_col__u_lu_source__reg4_db1_n, u_attr_lu_col__u_lu_source__reg4_db2_n;
wire u_attr_lu_col__u_lu_source__j90_x, u_attr_lu_col__u_lu_source__j92a_x, u_attr_lu_col__u_lu_source__j95_x, u_attr_lu_col__u_lu_source__j97a_x;

assign u_attr_lu_col__u_lu_source__reg4_db1_n = ~u_attr_lu_col__u_lu_source__reg4_db1; // b13b
assign u_attr_lu_col__u_lu_source__reg4_db2_n = ~u_attr_lu_col__u_lu_source__reg4_db2; // b14b
assign u_attr_lu_col__b26a_x = ~(u_attr_lu_col__u_lu_source__reg4_db2 ? (u_attr_lu_col__u_lu_source__reg4_db1 ? u_attr_lu_col__vd_reg_23 : u_attr_lu_col__vd_reg_23) : (u_attr_lu_col__u_lu_source__reg4_db1 ? u_page12_outputs__vd_reg_9_17 : u_page12_outputs__vd_reg_11_19)); // b26a
assign u_page12_outputs__lut_addr[1] = ~u_attr_lu_col__b26a_x; // b60b
assign u_page12_outputs__lut_addr_n[1] = ~u_page12_outputs__lut_addr[1]; // j79a
assign u_attr_lu_col__b31_x = ~(u_attr_lu_col__u_lu_source__reg4_db2 ? (u_attr_lu_col__u_lu_source__reg4_db1 ? u_attr_lu_col__vd_reg_22 : u_attr_lu_col__vd_reg_22) : (u_attr_lu_col__u_lu_source__reg4_db1 ? u_page12_outputs__vd_reg_8_16 : u_page12_outputs__vd_reg_10_18)); // b31
assign u_page12_outputs__lut_addr[0] = ~u_attr_lu_col__b31_x; // b60a
assign u_page12_outputs__lut_addr_n[0] = ~u_page12_outputs__lut_addr[0]; // j81a
assign u_attr_lu_col__u_lu_source__j90_x = ~(u_page12_outputs__lut_addr[1] ? (u_page12_outputs__lut_addr[0] ? reg38_d[15] : reg38_d[11]) : (u_page12_outputs__lut_addr[0] ? reg38_d[7] : reg38_d[3])); // j90
assign lu[3] = ~u_attr_lu_col__u_lu_source__j90_x; // j57a
assign u_attr_lu_col__u_lu_source__j92a_x = ~(u_page12_outputs__lut_addr[1] ? (u_page12_outputs__lut_addr[0] ? reg38_d[14] : reg38_d[10]) : (u_page12_outputs__lut_addr[0] ? reg38_d[6] : reg38_d[2])); // j92a
assign lu[2] = ~u_attr_lu_col__u_lu_source__j92a_x; // j57b
assign u_attr_lu_col__u_lu_source__j95_x = ~(u_page12_outputs__lut_addr[1] ? (u_page12_outputs__lut_addr[0] ? reg38_d[13] : reg38_d[9]) : (u_page12_outputs__lut_addr[0] ? reg38_d[5] : reg38_d[1])); // j95
assign lu[1] = ~u_attr_lu_col__u_lu_source__j95_x; // a58a
assign u_attr_lu_col__u_lu_source__j97a_x = ~(u_page12_outputs__lut_addr[1] ? (u_page12_outputs__lut_addr[0] ? reg38_d[12] : reg38_d[8]) : (u_page12_outputs__lut_addr[0] ? reg38_d[4] : reg38_d[0])); // j97a
assign lu[0] = ~u_attr_lu_col__u_lu_source__j97a_x; // b68a
assign u_attr_lu_col__u_lu_source__reg4_db1 = reg4_db_2_0[1];
assign u_attr_lu_col__u_lu_source__reg4_db2 = reg4_db_2_0[2];
// End inlined jt054156_page06_lu_source u_lu_source

// Inlined jt054156_page06_col_ca_select u_col_ca_select
wire u_attr_lu_col__u_col_ca_select__reg4_db0;
wire u_attr_lu_col__u_col_ca_select__reg4_db1;
wire u_attr_lu_col__u_col_ca_select__reg4_db2;
wire [1:0] u_attr_lu_col__u_col_ca_select__lu;
wire u_attr_lu_col__u_col_ca_select__col3_x, u_attr_lu_col__u_col_ca_select__col2_x, u_attr_lu_col__u_col_ca_select__col1_x, u_attr_lu_col__u_col_ca_select__col0_x;
wire u_attr_lu_col__u_col_ca_select__ca18_x, u_attr_lu_col__u_col_ca_select__ca17_x;

assign u_attr_lu_col__reg4_db0_buf = u_attr_lu_col__u_col_ca_select__reg4_db0; // a59b
assign u_attr_lu_col__reg4_db0_n = ~u_attr_lu_col__reg4_db0_buf; // a48a
assign u_attr_lu_col__reg4_db1_n = ~u_attr_lu_col__u_col_ca_select__reg4_db1; // b29a
assign u_attr_lu_col__reg4_db2_n = ~u_attr_lu_col__u_col_ca_select__reg4_db2; // b34b
assign u_attr_lu_col__u_col_ca_select__col3_x = u_attr_lu_col__reg4_db0_buf ? ~u_page12_outputs__vd_reg_11_19 : ~u_attr_lu_col__u_col_ca_select__lu[1]; // a47b
assign col[3] = ~u_attr_lu_col__u_col_ca_select__col3_x; // a47a
assign u_attr_lu_col__u_col_ca_select__col2_x = u_attr_lu_col__reg4_db0_buf ? ~u_page12_outputs__vd_reg_10_18 : ~u_attr_lu_col__u_col_ca_select__lu[0]; // b41a
assign col[2] = ~u_attr_lu_col__u_col_ca_select__col2_x; // b42b
assign u_attr_lu_col__u_col_ca_select__col1_x = u_attr_lu_col__u_col_ca_select__reg4_db1 ? ~u_page12_outputs__vd_reg_9_17 : ~u_attr_lu_col__u_col_ca_select__lu[1]; // a15a
assign col[1] = ~u_attr_lu_col__u_col_ca_select__col1_x; // a16b
assign u_attr_lu_col__u_col_ca_select__col0_x = u_attr_lu_col__u_col_ca_select__reg4_db1 ? ~u_page12_outputs__vd_reg_8_16 : ~u_attr_lu_col__u_col_ca_select__lu[0]; // b33a
assign col[0] = ~u_attr_lu_col__u_col_ca_select__col0_x; // b30a
assign u_attr_lu_col__u_col_ca_select__ca18_x = u_attr_lu_col__u_col_ca_select__reg4_db2 ? ~u_attr_lu_col__vd_reg_23 : ~u_attr_lu_col__vd_reg_23; // b25b
assign ca18 = ~u_attr_lu_col__u_col_ca_select__ca18_x; // b7a
assign u_attr_lu_col__u_col_ca_select__ca17_x = u_attr_lu_col__u_col_ca_select__reg4_db2 ? ~u_attr_lu_col__vd_reg_22 : ~u_attr_lu_col__vd_reg_22; // b29b
assign ca17 = ~u_attr_lu_col__u_col_ca_select__ca17_x; // a1b
assign u_attr_lu_col__u_col_ca_select__reg4_db0 = reg4_db_2_0[0];
assign u_attr_lu_col__u_col_ca_select__reg4_db1 = reg4_db_2_0[1];
assign u_attr_lu_col__u_col_ca_select__reg4_db2 = reg4_db_2_0[2];
assign u_attr_lu_col__u_col_ca_select__lu = lu[1:0];
// End inlined jt054156_page06_col_ca_select u_col_ca_select
assign u_attr_lu_col__vd_reg_22 = vd_reg[22];
assign u_attr_lu_col__vd_reg_23 = vd_reg[23];
// End inlined jt054156_page06_attr_lu_col u_attr_lu_col

// Inlined jt054156_page12_flip_en_mux u_flip_en
assign u_page12_outputs__h37a_y = ~reg6_db6; // h37a
assign u_page12_outputs__h38b_y = ~reg6_db7; // h38b
assign u_page12_outputs__h38a_x = ~(reg6_db7 ? (reg6_db6 ? u_page12_outputs__vd_reg_15_23 : u_page12_outputs__vd_reg_13_21) : (reg6_db6 ? col[3] : col[1])); // h38a
assign h36_y = ~|{vflip_en_mux,u_page12_outputs__h38a_x}; // h36
assign u_page12_outputs__h33a_x = ~(reg6_db7 ? (reg6_db6 ? u_page12_outputs__vd_reg_14_22 : u_page12_outputs__vd_reg_12_20) : (reg6_db6 ? col[2] : col[0])); // h33a
assign f11a_y = ~|{hflip_en_mux,u_page12_outputs__h33a_x}; // f11a
// End inlined jt054156_page12_flip_en_mux u_flip_en

// Inlined jt054156_page12_ca_low u_ca_low
wire u_ca_low__b11a_a;
wire u_ca_low__b11a_b;
wire u_ca_low__b13a_a;
wire u_ca_low__b13a_b;
wire u_ca_low__d43_qc;
wire u_ca_low__d43_qd;
wire u_ca_low__reg34l_d0;
jt054156_p24 u_d19(
    .a1 ( u_page12_outputs__d19_a[0] ),
    .b1 ( u_page12_outputs__d19_b[0] ),
    .a2 ( u_page12_outputs__d19_a[1] ),
    .b2 ( u_page12_outputs__d19_b[1] ),
    .a3 ( u_page12_outputs__d19_a[2] ),
    .b3 ( u_page12_outputs__d19_b[2] ),
    .a4 ( u_page12_outputs__d19_a[3] ),
    .b4 ( u_page12_outputs__d19_b[3] ),
    .sa ( u_page12_outputs__g165_x ),
    .sb ( u_page12_outputs__b12b_y ),
    .x1 ( u_page12_outputs__d19_x[0] ),
    .x2 ( u_page12_outputs__d19_x[1] ),
    .x3 ( u_page12_outputs__d19_x[2] ),
    .x4 ( u_page12_outputs__d19_x[3] )
);

jt054156_t2b u_b11a(
    .a  ( u_ca_low__b11a_a ),
    .b  ( u_ca_low__b11a_b ),
    .s1 ( u_page12_outputs__g165_x ),
    .s2 ( u_page12_outputs__b12b_y ),
    .x  ( u_page12_outputs__b11a_x )
);

assign u_page12_outputs__b7b_y = ~u_page12_outputs__b11a_x; // b7b
jt054156_t2b u_b13a(
    .a  ( u_ca_low__b13a_a ),
    .b  ( u_ca_low__b13a_b ),
    .s1 ( u_page12_outputs__g165_x ),
    .s2 ( u_page12_outputs__b12b_y ),
    .x  ( u_page12_outputs__b13a_x )
);

assign u_page12_outputs__b8b_y = ~u_page12_outputs__b13a_x; // b8b
jt054156_p24 u_d13(
    .a1 ( u_page12_outputs__d19_x[0]   ),
    .b1 ( ab_mux_4_5 ),
    .a2 ( u_page12_outputs__d19_x[1]   ),
    .b2 ( ab_mux_2_3 ),
    .a3 ( u_page12_outputs__d19_x[2]   ),
    .b3 ( ab_mux_5_6 ),
    .a4 ( u_page12_outputs__d19_x[3]   ),
    .b4 ( ab_mux_3_4 ),
    .sa ( sel_sa     ),
    .sb ( sel_sb     ),
    .x1 ( u_page12_outputs__pin_ca_low[2]  ),
    .x2 ( u_page12_outputs__pin_ca_low[0]  ),
    .x3 ( u_page12_outputs__pin_ca_low[3]  ),
    .x4 ( u_page12_outputs__pin_ca_low[1]  )
);

jt054156_p24 u_d7(
    .a1 ( u_page12_outputs__b7b_y       ),
    .b1 ( ab_mux_8_9  ),
    .a2 ( u_page12_outputs__b8b_y       ),
    .b2 ( ab_mux_6_7  ),
    .a3 ( u_ca_low__d43_qc      ),
    .b3 ( ab_mux_9_10 ),
    .a4 ( u_ca_low__d43_qd      ),
    .b4 ( ab_mux_7_8  ),
    .sa ( sel_sa      ),
    .sb ( sel_sb      ),
    .x1 ( u_page12_outputs__pin_ca_low[6]   ),
    .x2 ( u_page12_outputs__pin_ca_low[4]   ),
    .x3 ( u_page12_outputs__pin_ca_low[7]   ),
    .x4 ( u_page12_outputs__pin_ca_low[5]   )
);

jt054156_p24 u_d25(
    .a1 ( u_page12_outputs__c43_q[0]     ),
    .b1 ( ab_mux_12_13 ),
    .a2 ( u_page12_outputs__c43_q[1]     ),
    .b2 ( ab_mux_10_11 ),
    .a3 ( u_page12_outputs__c43_q[2]     ),
    .b3 ( u_ca_low__reg34l_d0    ),
    .a4 ( u_page12_outputs__c43_q[3]     ),
    .b4 ( ab_mux_11_12 ),
    .sa ( sel_sa       ),
    .sb ( sel_sb       ),
    .x1 ( u_page12_outputs__pin_ca_low[10]   ),
    .x2 ( u_page12_outputs__pin_ca_low[8]    ),
    .x3 ( u_page12_outputs__pin_ca_low[11]   ),
    .x4 ( u_page12_outputs__pin_ca_low[9]    )
);
assign u_ca_low__b11a_a = scrollx_xor[7];
assign u_ca_low__b11a_b = vd_reg[1];
assign u_ca_low__b13a_a = scrollx_xor[8];
assign u_ca_low__b13a_b = vd_reg[2];
assign u_ca_low__d43_qc = vd_reg[2];
assign u_ca_low__d43_qd = vd_reg[3];
assign u_ca_low__reg34l_d0 = reg34l_d[0];
// End inlined jt054156_page12_ca_low u_ca_low

// Inlined jt054156_page12_ca_col_high u_ca_col_high
wire u_ca_col_high__lu2;
wire u_ca_col_high__lu3;
wire u_ca_col_high__h23a_y, u_ca_col_high__j24a_y;

assign u_ca_col_high__h23a_y = sel_sb; // h23a
assign u_ca_col_high__j24a_y = ~u_ca_col_high__h23a_y; // j24a
assign u_page12_outputs__pin_ca_high[14] = u_ca_col_high__h23a_y ? vd_reg[19] : reg34l_d[3]; // e27
assign u_page12_outputs__pin_ca_high[12] = u_ca_col_high__h23a_y ? vd_reg[17] : reg34l_d[1]; // e27
assign u_page12_outputs__pin_ca_high[15] = u_ca_col_high__h23a_y ? vd_reg[20] : reg34l_d[4]; // e27
assign u_page12_outputs__pin_ca_high[13] = u_ca_col_high__h23a_y ? vd_reg[18] : reg34l_d[2]; // e27
assign u_page12_outputs__pin_ca_high[18] = u_ca_col_high__h23a_y ? ca18 : reg34l_d[7]; // g7
assign u_page12_outputs__pin_ca_high[16] = u_ca_col_high__h23a_y ? vd_reg[21] : reg34l_d[5]; // g7
assign pin_col[0] = u_ca_col_high__h23a_y ? col[0] : reg34u_d[0]; // g7
assign u_page12_outputs__pin_ca_high[17] = u_ca_col_high__h23a_y ? ca17 : reg34l_d[6]; // g7
assign pin_col[3] = u_ca_col_high__h23a_y ? col[3] : reg34u_d[3]; // h27
assign pin_col[1] = u_ca_col_high__h23a_y ? col[1] : reg34u_d[1]; // h27
assign pin_col[4] = u_ca_col_high__h23a_y ? u_page12_outputs__vd_reg_12_20 : reg34u_d[4]; // h27
assign pin_col[2] = u_ca_col_high__h23a_y ? col[2] : reg34u_d[2]; // h27
assign pin_col[7] = u_ca_col_high__h23a_y ? u_page12_outputs__vd_reg_15_23 : reg34u_d[7]; // j27
assign pin_col[5] = u_ca_col_high__h23a_y ? u_page12_outputs__vd_reg_13_21 : reg34u_d[5]; // j27
assign pin_vrc[0] = u_ca_col_high__h23a_y ? u_ca_col_high__lu2 : reg36_d[0]; // j27
assign pin_col[6] = u_ca_col_high__h23a_y ? u_page12_outputs__vd_reg_14_22 : reg34u_d[6]; // j27
assign u_page12_outputs__j33a_x = u_ca_col_high__h23a_y ? ~u_ca_col_high__lu3 : ~reg36_d[1]; // j33a
assign pin_vrc[1] = ~u_page12_outputs__j33a_x; // j7a
assign u_ca_col_high__lu2 = lu[2];
assign u_ca_col_high__lu3 = lu[3];
// End inlined jt054156_page12_ca_col_high u_ca_col_high
// End inlined jt054156_page12_outputs u_page12_outputs

endmodule


// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054156_cpu_ctrl.v
// -----------------------------------------------------------------------------

// Connected CPU-side control decode currently reconstructed from pages 1 and 9.

module jt054156_cpu_ctrl(
    input  wire [13:1] pin_ab,
    input  wire        pin_nrcs,
    input  wire        hload_n,
    input  wire        pin_cram,
    input  wire        pin_lds,
    input  wire        pin_uds,
    input  wire        pin_nrd,
    input  wire        pin_nvcs,
    input  wire        reg6_db5,
    input  wire        regc_db0,
    input  wire        regc_db1,

    output wire        access_l_n,
    output wire        access_u_n,
    output wire        pin_db_l_oe,
    output wire        pin_db_u_oe,
    output wire        pin_nre,
    output wire        l125a_y,
    output wire        p113b_y,
    output wire        p170b_y,
    output wire        regc_db0_buf,
    output wire        regc_db1_buf,
    output wire        p110b_y,

    output wire        reg10_wr_n,
    output wire        reg12_wr_n,
    output wire        reg14_wr_n,
    output wire        reg16_wr_n,
    output wire        reg18_wr_n,
    output wire        reg1a_wr_n,
    output wire        reg1c_wr_n,
    output wire        reg1e_wr_n,
    output wire        reg0_wr_n,
    output wire        reg2_wr_n,
    output wire        reg4_wr_n,
    output wire        reg6_wr_n,
    output wire        reg8_wr_n,
    output wire        rega_wr_n,
    output wire        regc_wr_n,
    output wire        reg20u_wr_n,
    output wire        reg20l_wr_n,
    output wire        reg22u_wr_n,
    output wire        reg22l_wr_n,
    output wire        reg24u_wr_n,
    output wire        reg24l_wr_n,
    output wire        reg26u_wr_n,
    output wire        reg26l_wr_n,
    output wire        reg28u_wr_n,
    output wire        reg28l_wr_n,
    output wire        reg2au_wr_n,
    output wire        reg2al_wr_n,
    output wire        reg2cu_wr_n,
    output wire        reg2cl_wr_n,
    output wire        reg2eu_wr_n,
    output wire        reg2el_wr_n,
    output wire        reg30_wr_n,
    output wire        reg32_wr_n,
    output wire        reg34u_wr_n,
    output wire        reg34l_wr_n,
    output wire        reg36_wr_n,
    output wire        reg38u_wr_n,
    output wire        reg38l_wr_n,
    output wire        reg3au_wr_n,
    output wire        reg3al_wr_n,
    output wire        reg3cu_wr_n,
    output wire        reg3cl_wr_n,

    output wire [3:0]  n53_x_n
);

wire reg10_dec_n, reg12_dec_n, reg14_dec_n, reg16_dec_n;
wire reg18_dec_n, reg1a_dec_n, reg1c_dec_n, reg1e_dec_n;
wire reg20_dec_n, reg22_dec_n, reg24_dec_n, reg26_dec_n;
wire reg28_dec_n, reg2a_dec_n, reg2c_dec_n, reg2e_dec_n;
wire ab74_0_nrcs, ab74_3_nrcs;
wire m6b_y;

// Inlined jt054156_page01_ab_decode u_ab_decode
wire u_ab_decode__vcc, u_ab_decode__gnd;
wire u_ab_decode__ab1, u_ab_decode__ab2, u_ab_decode__ab3, u_ab_decode__ab4, u_ab_decode__ab5, u_ab_decode__ab6, u_ab_decode__ab7;
wire u_ab_decode__ab8, u_ab_decode__ab9, u_ab_decode__ab10, u_ab_decode__ab11, u_ab_decode__ab12, u_ab_decode__ab13;
wire u_ab_decode__ab4_n, u_ab_decode__ab4_buf, u_ab_decode__ab5_n, u_ab_decode__ab5_buf, u_ab_decode__ab6_n;
wire u_ab_decode__hload_buf, u_ab_decode__hload_n_buf;
wire u_ab_decode__n17b_y;
wire u_ab_decode__ab_hi_or;
wire u_ab_decode__ab74_1_en_n, u_ab_decode__ab74_2_en_n, u_ab_decode__ab74_3_en_n;
wire [7:0] u_ab_decode__reg1x_dec_n;
wire [7:0] u_ab_decode__reg2x_dec_n;

assign u_ab_decode__vcc  = 1'b1;
assign u_ab_decode__gnd  = 1'b0;

assign u_ab_decode__ab1  = pin_ab[1];
assign u_ab_decode__ab2  = pin_ab[2];
assign u_ab_decode__ab3  = pin_ab[3];
assign u_ab_decode__ab4  = pin_ab[4];
assign u_ab_decode__ab5  = pin_ab[5];
assign u_ab_decode__ab6  = pin_ab[6];
assign u_ab_decode__ab7  = pin_ab[7];
assign u_ab_decode__ab8  = pin_ab[8];
assign u_ab_decode__ab9  = pin_ab[9];
assign u_ab_decode__ab10 = pin_ab[10];
assign u_ab_decode__ab11 = pin_ab[11];
assign u_ab_decode__ab12 = pin_ab[12];
assign u_ab_decode__ab13 = pin_ab[13];

assign u_ab_decode__ab4_n = ~u_ab_decode__ab4; // l11b
assign u_ab_decode__ab4_buf = ~u_ab_decode__ab4_n; // m4a
assign u_ab_decode__ab5_n = ~u_ab_decode__ab5; // l10a
assign u_ab_decode__ab5_buf = ~u_ab_decode__ab5_n; // m5b
assign u_ab_decode__ab6_n = ~u_ab_decode__ab6; // l10b
assign u_ab_decode__hload_buf = ~hload_n; // r122a
assign u_ab_decode__hload_n_buf = ~u_ab_decode__hload_buf; // r110a
assign u_ab_decode__n17b_y = ~|{u_ab_decode__hload_n_buf,pin_nrcs,u_ab_decode__ab7}; // n17b
assign u_ab_decode__ab_hi_or = |{u_ab_decode__ab8,u_ab_decode__ab9,u_ab_decode__ab10,u_ab_decode__ab11,u_ab_decode__ab12,u_ab_decode__ab13,u_ab_decode__gnd,u_ab_decode__gnd}; // j50
assign u_ab_decode__ab74_2_en_n = ~&{u_ab_decode__n17b_y,u_ab_decode__ab4_n,u_ab_decode__ab5_buf,u_ab_decode__ab6_n}; // m8b
assign u_ab_decode__ab74_1_en_n = ~&{u_ab_decode__n17b_y,u_ab_decode__ab4_buf,u_ab_decode__ab5_n,u_ab_decode__ab6_n}; // m7a
assign u_ab_decode__ab74_3_en_n = ~&{u_ab_decode__n17b_y,u_ab_decode__ab4_buf,u_ab_decode__ab5_buf,u_ab_decode__ab6_n}; // m5a
assign m6b_y = ~&{u_ab_decode__n17b_y,u_ab_decode__ab4_n,u_ab_decode__ab5_n,u_ab_decode__ab6_n}; // m6b
assign u_ab_decode__reg2x_dec_n = u_ab_decode__vcc & ~u_ab_decode__ab74_2_en_n & ~u_ab_decode__ab_hi_or ? ~(8'b0000_0001 << { u_ab_decode__ab3, u_ab_decode__ab2, u_ab_decode__ab1 }) : 8'hff; // k26
assign u_ab_decode__reg1x_dec_n = u_ab_decode__vcc & ~u_ab_decode__ab74_1_en_n & ~u_ab_decode__ab_hi_or ? ~(8'b0000_0001 << { u_ab_decode__ab3, u_ab_decode__ab2, u_ab_decode__ab1 }) : 8'hff; // l26
assign ab74_3_nrcs = ~|{u_ab_decode__ab74_3_en_n,u_ab_decode__ab_hi_or}; // l9b
assign ab74_0_nrcs = ~|{m6b_y,u_ab_decode__ab_hi_or}; // m12a
assign reg10_dec_n = u_ab_decode__reg1x_dec_n[0];
assign reg12_dec_n = u_ab_decode__reg1x_dec_n[1];
assign reg14_dec_n = u_ab_decode__reg1x_dec_n[2];
assign reg16_dec_n = u_ab_decode__reg1x_dec_n[3];
assign reg18_dec_n = u_ab_decode__reg1x_dec_n[4];
assign reg1a_dec_n = u_ab_decode__reg1x_dec_n[5];
assign reg1c_dec_n = u_ab_decode__reg1x_dec_n[6];
assign reg1e_dec_n = u_ab_decode__reg1x_dec_n[7];

assign reg20_dec_n = u_ab_decode__reg2x_dec_n[0];
assign reg22_dec_n = u_ab_decode__reg2x_dec_n[1];
assign reg24_dec_n = u_ab_decode__reg2x_dec_n[2];
assign reg26_dec_n = u_ab_decode__reg2x_dec_n[3];
assign reg28_dec_n = u_ab_decode__reg2x_dec_n[4];
assign reg2a_dec_n = u_ab_decode__reg2x_dec_n[5];
assign reg2c_dec_n = u_ab_decode__reg2x_dec_n[6];
assign reg2e_dec_n = u_ab_decode__reg2x_dec_n[7];
// End inlined jt054156_page01_ab_decode u_ab_decode

// Inlined jt054156_page09_access_ctrl u_access_ctrl
wire u_access_ctrl__pin_ab3;
wire u_access_ctrl__unused_reg6_db5_n;
wire u_access_ctrl__unused_p172a_y;
wire u_access_ctrl__unused_p169a_y;
wire u_access_ctrl__unused_p125b_y;
wire u_access_ctrl__n23b_y;

assign l125a_y = pin_lds ^ reg6_db5; // l125a
assign u_access_ctrl__unused_reg6_db5_n = ~reg6_db5; // p121b
assign regc_db1_buf = regc_db1; // p111b
assign regc_db0_buf = regc_db0; // p124a
assign p110b_y = ~regc_db0_buf; // p110b
assign p113b_y = ~&{regc_db1_buf,p110b_y}; // p113b
assign u_access_ctrl__unused_p172a_y = p113b_y & pin_uds; // p172a
assign u_access_ctrl__unused_p169a_y = p113b_y & l125a_y; // p169a
assign p170b_y = p113b_y & l125a_y; // p170b
assign u_access_ctrl__unused_p125b_y = u_access_ctrl__unused_reg6_db5_n & l125a_y; // p125b
assign u_access_ctrl__n23b_y = pin_cram | pin_nrcs; // n23b
assign access_l_n = u_access_ctrl__n23b_y | l125a_y; // l23b
assign access_u_n = u_access_ctrl__n23b_y | pin_uds; // l19a
assign pin_nre = |{m6b_y,u_access_ctrl__pin_ab3,l125a_y}; // l111a
assign pin_db_l_oe = |{pin_nvcs,pin_nrd,u_access_ctrl__unused_p125b_y}; // p193a
assign pin_db_u_oe = |{pin_nvcs,pin_nrd,pin_uds}; // p186a
assign u_access_ctrl__pin_ab3 = pin_ab[3];
// End inlined jt054156_page09_access_ctrl u_access_ctrl

// Inlined jt054156_page01_reg_wr_decode u_reg_wr_decode
assign reg10_wr_n = reg10_dec_n | access_l_n; // l47a
assign reg12_wr_n = reg12_dec_n | access_l_n; // l45b
assign reg14_wr_n = reg14_dec_n | access_l_n; // k45b
assign reg16_wr_n = reg16_dec_n | access_l_n; // l43b
assign reg18_wr_n = reg18_dec_n | access_l_n; // l49a
assign reg1a_wr_n = reg1a_dec_n | access_l_n; // l43a
assign reg1c_wr_n = reg1c_dec_n | access_l_n; // l45a
assign reg1e_wr_n = reg1e_dec_n | access_l_n; // k47b
assign reg20u_wr_n = reg20_dec_n | access_u_n; // k45a
assign reg20l_wr_n = reg20_dec_n | access_l_n; // l51a
assign reg22u_wr_n = reg22_dec_n | access_u_n; // k49b
assign reg22l_wr_n = reg22_dec_n | access_l_n; // l47b
assign reg24u_wr_n = reg24_dec_n | access_u_n; // k47a
assign reg24l_wr_n = reg24_dec_n | access_l_n; // l49b
assign reg26u_wr_n = reg26_dec_n | access_u_n; // k51b
assign reg26l_wr_n = reg26_dec_n | access_l_n; // l51b
assign reg28u_wr_n = reg28_dec_n | access_u_n; // k49a
assign reg28l_wr_n = reg28_dec_n | access_l_n; // k51a
assign reg2au_wr_n = reg2a_dec_n | access_u_n; // k23a
assign reg2al_wr_n = reg2a_dec_n | access_l_n; // k43a
assign reg2cu_wr_n = reg2c_dec_n | access_u_n; // k17a
assign reg2cl_wr_n = reg2c_dec_n | access_l_n; // k21a
assign reg2eu_wr_n = reg2e_dec_n | access_u_n; // k19a
assign reg2el_wr_n = reg2e_dec_n | access_l_n; // k23b
// End inlined jt054156_page01_reg_wr_decode u_reg_wr_decode

// Inlined jt054156_page01_low_reg_wr_decode u_low_reg_wr_decode
wire [3:1] u_low_reg_wr_decode__pin_ab;
wire u_low_reg_wr_decode__ab1_l_n, u_low_reg_wr_decode__ab1_l, u_low_reg_wr_decode__ab2_l_n, u_low_reg_wr_decode__ab2_l, u_low_reg_wr_decode__ab3_l_n, u_low_reg_wr_decode__ab3_l;
wire u_low_reg_wr_decode__ab1_r_n, u_low_reg_wr_decode__ab1_r, u_low_reg_wr_decode__ab2_r_n, u_low_reg_wr_decode__ab2_r, u_low_reg_wr_decode__ab3_r_n, u_low_reg_wr_decode__ab3_r;
wire u_low_reg_wr_decode__access_l_n_buf;
wire u_low_reg_wr_decode__reg0_dec_n, u_low_reg_wr_decode__reg2_dec_n, u_low_reg_wr_decode__reg4_dec_n, u_low_reg_wr_decode__reg6_dec_n;
wire u_low_reg_wr_decode__reg8_dec_n, u_low_reg_wr_decode__rega_dec_n, u_low_reg_wr_decode__regc_dec_n;
wire u_low_reg_wr_decode__reg30_dec_n, u_low_reg_wr_decode__reg32_dec_n, u_low_reg_wr_decode__reg34_dec_n, u_low_reg_wr_decode__reg36_dec_n;
wire u_low_reg_wr_decode__reg38_dec_n, u_low_reg_wr_decode__reg3a_dec_n, u_low_reg_wr_decode__reg3c_dec_n;

assign u_low_reg_wr_decode__ab3_l_n = ~u_low_reg_wr_decode__pin_ab[3]; // l16b
assign u_low_reg_wr_decode__ab3_l = ~u_low_reg_wr_decode__ab3_l_n; // m18b
assign u_low_reg_wr_decode__ab2_l_n = ~u_low_reg_wr_decode__pin_ab[2]; // l20b
assign u_low_reg_wr_decode__ab2_l = ~u_low_reg_wr_decode__ab2_l_n; // m17b
assign u_low_reg_wr_decode__ab1_l_n = ~u_low_reg_wr_decode__pin_ab[1]; // m18a
assign u_low_reg_wr_decode__ab1_l = ~u_low_reg_wr_decode__ab1_l_n; // m17a
assign u_low_reg_wr_decode__access_l_n_buf = access_l_n; // p111a
assign u_low_reg_wr_decode__reg0_dec_n = ~&{ab74_0_nrcs,u_low_reg_wr_decode__ab3_l_n,u_low_reg_wr_decode__ab2_l_n,u_low_reg_wr_decode__ab1_l_n}; // m19b
assign u_low_reg_wr_decode__reg2_dec_n = ~&{ab74_0_nrcs,u_low_reg_wr_decode__ab3_l_n,u_low_reg_wr_decode__ab2_l_n,u_low_reg_wr_decode__ab1_l}; // m15a
assign u_low_reg_wr_decode__reg4_dec_n = ~&{ab74_0_nrcs,u_low_reg_wr_decode__ab3_l_n,u_low_reg_wr_decode__ab2_l,u_low_reg_wr_decode__ab1_l_n}; // m19a
assign u_low_reg_wr_decode__reg6_dec_n = ~&{ab74_0_nrcs,u_low_reg_wr_decode__ab3_l_n,u_low_reg_wr_decode__ab2_l,u_low_reg_wr_decode__ab1_l}; // m21b
assign u_low_reg_wr_decode__reg8_dec_n = ~&{ab74_0_nrcs,u_low_reg_wr_decode__ab3_l,u_low_reg_wr_decode__ab2_l_n,u_low_reg_wr_decode__ab1_l_n}; // m15b
assign u_low_reg_wr_decode__rega_dec_n = ~&{ab74_0_nrcs,u_low_reg_wr_decode__ab3_l,u_low_reg_wr_decode__ab2_l_n,u_low_reg_wr_decode__ab1_l}; // m21a
assign u_low_reg_wr_decode__regc_dec_n = ~&{ab74_0_nrcs,u_low_reg_wr_decode__ab3_l,u_low_reg_wr_decode__ab2_l,u_low_reg_wr_decode__ab1_l_n}; // m13a
assign reg0_wr_n = u_low_reg_wr_decode__reg0_dec_n | u_low_reg_wr_decode__access_l_n_buf; // n123b
assign reg2_wr_n = u_low_reg_wr_decode__reg2_dec_n | u_low_reg_wr_decode__access_l_n_buf; // l23a
assign reg4_wr_n = u_low_reg_wr_decode__reg4_dec_n | u_low_reg_wr_decode__access_l_n_buf; // m108a
assign reg6_wr_n = u_low_reg_wr_decode__reg6_dec_n | u_low_reg_wr_decode__access_l_n_buf; // n108a
assign reg8_wr_n = u_low_reg_wr_decode__reg8_dec_n | u_low_reg_wr_decode__access_l_n_buf; // l21b
assign rega_wr_n = u_low_reg_wr_decode__rega_dec_n | u_low_reg_wr_decode__access_l_n_buf; // n108b
assign regc_wr_n = u_low_reg_wr_decode__regc_dec_n | u_low_reg_wr_decode__access_l_n_buf; // l21a
assign u_low_reg_wr_decode__ab3_r_n = ~u_low_reg_wr_decode__pin_ab[3]; // k10a
assign u_low_reg_wr_decode__ab3_r = ~u_low_reg_wr_decode__ab3_r_n; // k4a
assign u_low_reg_wr_decode__ab2_r_n = ~u_low_reg_wr_decode__pin_ab[2]; // k9a
assign u_low_reg_wr_decode__ab2_r = ~u_low_reg_wr_decode__ab2_r_n; // k3a
assign u_low_reg_wr_decode__ab1_r_n = ~u_low_reg_wr_decode__pin_ab[1]; // l9a
assign u_low_reg_wr_decode__ab1_r = ~u_low_reg_wr_decode__ab1_r_n; // k4b
assign u_low_reg_wr_decode__reg30_dec_n = ~&{ab74_3_nrcs,u_low_reg_wr_decode__ab3_r_n,u_low_reg_wr_decode__ab2_r_n,u_low_reg_wr_decode__ab1_r_n}; // k5a
assign u_low_reg_wr_decode__reg32_dec_n = ~&{ab74_3_nrcs,u_low_reg_wr_decode__ab3_r_n,u_low_reg_wr_decode__ab2_r_n,u_low_reg_wr_decode__ab1_r}; // k5b
assign u_low_reg_wr_decode__reg34_dec_n = ~&{ab74_3_nrcs,u_low_reg_wr_decode__ab3_r_n,u_low_reg_wr_decode__ab2_r,u_low_reg_wr_decode__ab1_r_n}; // k7b
assign u_low_reg_wr_decode__reg36_dec_n = ~&{ab74_3_nrcs,u_low_reg_wr_decode__ab3_r_n,u_low_reg_wr_decode__ab2_r,u_low_reg_wr_decode__ab1_r}; // k7a
assign u_low_reg_wr_decode__reg38_dec_n = ~&{ab74_3_nrcs,u_low_reg_wr_decode__ab3_r,u_low_reg_wr_decode__ab2_r_n,u_low_reg_wr_decode__ab1_r_n}; // k9b
assign u_low_reg_wr_decode__reg3a_dec_n = ~&{ab74_3_nrcs,u_low_reg_wr_decode__ab3_r,u_low_reg_wr_decode__ab2_r_n,u_low_reg_wr_decode__ab1_r}; // k11b
assign u_low_reg_wr_decode__reg3c_dec_n = ~&{ab74_3_nrcs,u_low_reg_wr_decode__ab3_r,u_low_reg_wr_decode__ab2_r,u_low_reg_wr_decode__ab1_r_n}; // k11a
assign reg30_wr_n = u_low_reg_wr_decode__reg30_dec_n | access_l_n; // k15b
assign reg32_wr_n = u_low_reg_wr_decode__reg32_dec_n | access_l_n; // k17b
assign reg34u_wr_n = u_low_reg_wr_decode__reg34_dec_n | access_u_n; // j19b
assign reg34l_wr_n = u_low_reg_wr_decode__reg34_dec_n | access_l_n; // j17b
assign reg36_wr_n = u_low_reg_wr_decode__reg36_dec_n | access_l_n; // k19b
assign reg38u_wr_n = u_low_reg_wr_decode__reg38_dec_n | access_u_n; // j20a
assign reg38l_wr_n = u_low_reg_wr_decode__reg38_dec_n | access_l_n; // j23b
assign reg3au_wr_n = u_low_reg_wr_decode__reg3a_dec_n | access_u_n; // j21b
assign reg3al_wr_n = u_low_reg_wr_decode__reg3a_dec_n | access_l_n; // j22a
assign reg3cu_wr_n = u_low_reg_wr_decode__reg3c_dec_n | access_u_n; // k15a
assign reg3cl_wr_n = u_low_reg_wr_decode__reg3c_dec_n | access_l_n; // k21b
assign u_low_reg_wr_decode__pin_ab = pin_ab[3:1];
// End inlined jt054156_page01_low_reg_wr_decode u_low_reg_wr_decode

// Inlined jt054156_page09_addr_decode u_addr_decode
wire [13:11] u_addr_decode__pin_ab;
assign n53_x_n = ~u_addr_decode__pin_ab[13] ? ~(4'b0001 << { u_addr_decode__pin_ab[11], u_addr_decode__pin_ab[12] }) : 4'hf; // n53
assign u_addr_decode__pin_ab = pin_ab[13:11];
// End inlined jt054156_page09_addr_decode u_addr_decode

endmodule


// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054156_cpu_frontend.v
// -----------------------------------------------------------------------------

// Connected CPU-side frontend reconstructed from the currently validated
// page-1, page-2, and page-9 schematic regions.

module jt054156_cpu_frontend(
    input  wire [13:1] pin_ab,
    input  wire [15:0] pin_db_in,

    input  wire        pin_nrcs,
    input  wire        hload_n,
    input  wire        pin_cram,
    input  wire        pin_lds,
    input  wire        pin_uds,
    input  wire        pin_nrd,
    input  wire        pin_nvcs,

    input  wire        reset2_n,
    input  wire        reset3_n,
    input  wire        reset4_n,
    input  wire        reset6_n,
    input  wire        reset7_n,
    input  wire        reset8_n,
    input  wire        reset9_n,
    input  wire        reset11_n,
    input  wire        reset12_n,
    input  wire        reset13_n,
    input  wire        reset14_n,
    input  wire        reset16_n,
    input  wire        reset17_n,
    input  wire        reset18_n,
    input  wire        reset20_n,

    output wire        access_l_n,
    output wire        access_u_n,
    output wire        pin_db_l_oe,
    output wire        pin_db_u_oe,
    output wire        pin_nre,
    output wire        l125a_y,
    output wire        p113b_y,
    output wire        p170b_y,
    output wire        regc_db0_buf,
    output wire        regc_db1_buf,
    output wire        p110b_y,

    output wire [7:0]  db_in_buf,
    output wire [7:0]  db_in_buf2,
    output wire [7:0]  db_in_buf3,
    output wire [7:0]  db_in_buf4,
    output wire [7:0]  reg0_db,
    output wire [7:0]  reg2_db,
    output wire [7:0]  reg4_db,
    output wire [7:0]  reg6_db,
    output wire [7:0]  reg8_db,
    output wire [7:0]  rega_db,
    output wire [5:0]  regc_db,
    output wire [5:0]  reg10_d,
    output wire [5:0]  reg12_d,
    output wire [5:0]  reg14_d,
    output wire [5:0]  reg16_d,
    output wire [5:0]  reg18_d,
    output wire [5:0]  reg1a_d,
    output wire [5:0]  reg1c_d,
    output wire [5:0]  reg1e_d,
    output wire [10:0] reg20_d,
    output wire [10:0] reg22_d,
    output wire [10:0] reg24_d,
    output wire [10:0] reg26_d,
    output wire [11:0] reg28_d,
    output wire [11:0] reg2a_d,
    output wire [11:0] reg2c_d,
    output wire [11:0] reg2e_d,
    output wire [5:0]  reg30_d,
    output wire [5:0]  reg32_d,
    output wire [7:0]  reg34u_d,
    output wire [7:0]  reg34l_d,
    output wire [1:0]  reg36_d,
    output wire [15:0] reg38_d,
    output wire [11:0] reg3a_d,
    output wire [10:0] reg3c_d,

    output wire        reg0_wr_n,
    output wire        reg2_wr_n,
    output wire        reg4_wr_n,
    output wire        reg6_wr_n,
    output wire        reg8_wr_n,
    output wire        rega_wr_n,
    output wire        regc_wr_n,
    output wire        reg10_wr_n,
    output wire        reg12_wr_n,
    output wire        reg14_wr_n,
    output wire        reg16_wr_n,
    output wire        reg18_wr_n,
    output wire        reg1a_wr_n,
    output wire        reg1c_wr_n,
    output wire        reg1e_wr_n,
    output wire        reg20u_wr_n,
    output wire        reg20l_wr_n,
    output wire        reg22u_wr_n,
    output wire        reg22l_wr_n,
    output wire        reg24u_wr_n,
    output wire        reg24l_wr_n,
    output wire        reg26u_wr_n,
    output wire        reg26l_wr_n,
    output wire        reg28u_wr_n,
    output wire        reg28l_wr_n,
    output wire        reg2au_wr_n,
    output wire        reg2al_wr_n,
    output wire        reg2cu_wr_n,
    output wire        reg2cl_wr_n,
    output wire        reg2eu_wr_n,
    output wire        reg2el_wr_n,
    output wire        reg30_wr_n,
    output wire        reg32_wr_n,
    output wire        reg34u_wr_n,
    output wire        reg34l_wr_n,
    output wire        reg36_wr_n,
    output wire        reg38u_wr_n,
    output wire        reg38l_wr_n,
    output wire        reg3au_wr_n,
    output wire        reg3al_wr_n,
    output wire        reg3cu_wr_n,
    output wire        reg3cl_wr_n,

    output wire [3:0]  n53_x_n
);

wire db_mux_0_8;
wire db_mux_1_9;
wire db_mux_2_10;
wire db_mux_3_11;
wire db_mux_4_12;
wire db_mux_5_13;
wire db_mux_6_14;
wire db_mux_7_15;
wire [7:0]  pin_db_low_in = pin_db_in[7:0];
wire [15:8] pin_db_hi_in  = pin_db_in[15:8];

// Page 2 labels these direct lower-byte inputs as DB*_IN rather than
// PIN_DB*_IN.  No separate DB input pins or source nets have been found, so
// keep the leaf schematic labels but tie them to the lower CPU DB pins here.
wire [7:0] db_in = pin_db_low_in;

// Inlined jt054156_page01_db_buf u_db_buf
assign db_in_buf[0] = pin_db_low_in[0]; // g138a
assign db_in_buf[1] = pin_db_low_in[1]; // g138b
assign db_in_buf[2] = pin_db_low_in[2]; // g137a
assign db_in_buf[3] = pin_db_low_in[3]; // g139b
assign db_in_buf[4] = pin_db_low_in[4]; // d174b
assign db_in_buf[5] = pin_db_low_in[5]; // d173a
assign db_in_buf[6] = pin_db_low_in[6]; // g139a
assign db_in_buf[7] = pin_db_low_in[7]; // g137b
assign db_in_buf2[0] = pin_db_low_in[0]; // h134b
assign db_in_buf2[1] = pin_db_low_in[1]; // h133a
assign db_in_buf2[2] = pin_db_low_in[2]; // f122b
assign db_in_buf2[3] = pin_db_low_in[3]; // g135a
assign db_in_buf2[4] = pin_db_low_in[4]; // g136a
assign db_in_buf2[5] = pin_db_low_in[5]; // g136b
assign db_in_buf2[6] = pin_db_low_in[6]; // f121a
assign db_in_buf2[7] = pin_db_low_in[7]; // f121b
assign db_in_buf3[0] = pin_db_low_in[0]; // g182b
assign db_in_buf3[1] = pin_db_low_in[1]; // h174b
assign db_in_buf3[2] = pin_db_low_in[2]; // g173b
assign db_in_buf3[3] = pin_db_low_in[3]; // g173a
assign db_in_buf3[4] = pin_db_low_in[4]; // g189b
assign db_in_buf3[5] = pin_db_low_in[5]; // g185b
assign db_in_buf3[6] = pin_db_low_in[6]; // h155a
assign db_in_buf3[7] = pin_db_low_in[7]; // h134a
assign db_in_buf4[0] = pin_db_low_in[0]; // h132b
assign db_in_buf4[1] = pin_db_low_in[1]; // h132a
assign db_in_buf4[2] = pin_db_low_in[2]; // k108b
assign db_in_buf4[3] = pin_db_low_in[3]; // h133b
assign db_in_buf4[4] = pin_db_low_in[4]; // h159a
assign db_in_buf4[5] = pin_db_low_in[5]; // h160b
assign db_in_buf4[6] = pin_db_low_in[6]; // h149b
assign db_in_buf4[7] = pin_db_low_in[7]; // h135a
// End inlined jt054156_page01_db_buf u_db_buf

jt054156_cpu_ctrl u_cpu_ctrl(
    .pin_ab        ( pin_ab        ),
    .pin_nrcs      ( pin_nrcs      ),
    .hload_n       ( hload_n       ),
    .pin_cram      ( pin_cram      ),
    .pin_lds       ( pin_lds       ),
    .pin_uds       ( pin_uds       ),
    .pin_nrd       ( pin_nrd       ),
    .pin_nvcs      ( pin_nvcs      ),
    .reg6_db5      ( reg6_db[5]    ),
    .regc_db0      ( regc_db[0]    ),
    .regc_db1      ( regc_db[1]    ),
    .access_l_n    ( access_l_n    ),
    .access_u_n    ( access_u_n    ),
    .pin_db_l_oe   ( pin_db_l_oe   ),
    .pin_db_u_oe   ( pin_db_u_oe   ),
    .pin_nre       ( pin_nre       ),
    .l125a_y       ( l125a_y       ),
    .p113b_y       ( p113b_y       ),
    .p170b_y       ( p170b_y       ),
    .regc_db0_buf  ( regc_db0_buf  ),
    .regc_db1_buf  ( regc_db1_buf  ),
    .p110b_y       ( p110b_y       ),
    .reg0_wr_n     ( reg0_wr_n     ),
    .reg2_wr_n     ( reg2_wr_n     ),
    .reg4_wr_n     ( reg4_wr_n     ),
    .reg6_wr_n     ( reg6_wr_n     ),
    .reg8_wr_n     ( reg8_wr_n     ),
    .rega_wr_n     ( rega_wr_n     ),
    .regc_wr_n     ( regc_wr_n     ),
    .reg10_wr_n    ( reg10_wr_n    ),
    .reg12_wr_n    ( reg12_wr_n    ),
    .reg14_wr_n    ( reg14_wr_n    ),
    .reg16_wr_n    ( reg16_wr_n    ),
    .reg18_wr_n    ( reg18_wr_n    ),
    .reg1a_wr_n    ( reg1a_wr_n    ),
    .reg1c_wr_n    ( reg1c_wr_n    ),
    .reg1e_wr_n    ( reg1e_wr_n    ),
    .reg20u_wr_n   ( reg20u_wr_n   ),
    .reg20l_wr_n   ( reg20l_wr_n   ),
    .reg22u_wr_n   ( reg22u_wr_n   ),
    .reg22l_wr_n   ( reg22l_wr_n   ),
    .reg24u_wr_n   ( reg24u_wr_n   ),
    .reg24l_wr_n   ( reg24l_wr_n   ),
    .reg26u_wr_n   ( reg26u_wr_n   ),
    .reg26l_wr_n   ( reg26l_wr_n   ),
    .reg28u_wr_n   ( reg28u_wr_n   ),
    .reg28l_wr_n   ( reg28l_wr_n   ),
    .reg2au_wr_n   ( reg2au_wr_n   ),
    .reg2al_wr_n   ( reg2al_wr_n   ),
    .reg2cu_wr_n   ( reg2cu_wr_n   ),
    .reg2cl_wr_n   ( reg2cl_wr_n   ),
    .reg2eu_wr_n   ( reg2eu_wr_n   ),
    .reg2el_wr_n   ( reg2el_wr_n   ),
    .reg30_wr_n    ( reg30_wr_n    ),
    .reg32_wr_n    ( reg32_wr_n    ),
    .reg34u_wr_n   ( reg34u_wr_n   ),
    .reg34l_wr_n   ( reg34l_wr_n   ),
    .reg36_wr_n    ( reg36_wr_n    ),
    .reg38u_wr_n   ( reg38u_wr_n   ),
    .reg38l_wr_n   ( reg38l_wr_n   ),
    .reg3au_wr_n   ( reg3au_wr_n   ),
    .reg3al_wr_n   ( reg3al_wr_n   ),
    .reg3cu_wr_n   ( reg3cu_wr_n   ),
    .reg3cl_wr_n   ( reg3cl_wr_n   ),
    .n53_x_n       ( n53_x_n       )
);

// Inlined jt054156_page02_db_mux u_db_mux
wire u_db_mux__reg6_db5;
wire u_db_mux__reg6_db5_n;

assign u_db_mux__reg6_db5_n = ~u_db_mux__reg6_db5; // h131a
assign db_mux_6_14 = u_db_mux__reg6_db5 ? db_in_buf3[6] : pin_db_hi_in[14]; // h125
assign db_mux_4_12 = u_db_mux__reg6_db5 ? db_in_buf3[4] : pin_db_hi_in[12]; // h125
assign db_mux_7_15 = u_db_mux__reg6_db5 ? db_in_buf3[7] : pin_db_hi_in[15]; // h125
assign db_mux_5_13 = u_db_mux__reg6_db5 ? db_in_buf3[5] : pin_db_hi_in[13]; // h125
assign db_mux_2_10 = u_db_mux__reg6_db5 ? db_in_buf3[2] : pin_db_hi_in[10]; // f129
assign db_mux_0_8 = u_db_mux__reg6_db5 ? db_in_buf3[0] : pin_db_hi_in[8]; // f129
assign db_mux_3_11 = u_db_mux__reg6_db5 ? db_in_buf3[3] : pin_db_hi_in[11]; // f129
assign db_mux_1_9 = u_db_mux__reg6_db5 ? db_in_buf3[1] : pin_db_hi_in[9]; // f129
assign u_db_mux__reg6_db5 = reg6_db[5];
// End inlined jt054156_page02_db_mux u_db_mux

// Inlined jt054156_page02_low_regs u_low_regs
reg [7:0] u_low_regs__reg0_db;
reg [7:0] u_low_regs__reg2_db;
reg [7:0] u_low_regs__reg4_db;
reg [7:0] u_low_regs__reg6_db;
reg [7:0] u_low_regs__reg8_db;
reg [7:0] u_low_regs__rega_db;
reg [5:0] u_low_regs__regc_db;
wire    u_low_regs__reset20_buf_n;
reg [3:0] u_low_regs__reg4_hi_q;
assign u_low_regs__reset20_buf_n = reset20_n; // f120a
always @(posedge reg0_wr_n or negedge reset11_n) begin
    if (!reset11_n) begin
        u_low_regs__reg0_db[3:0] <= 4'd0;
    end else begin
        u_low_regs__reg0_db[3:0] <= db_in_buf4[3:0];
    end
end // j122
always @(posedge reg0_wr_n or negedge reset11_n) begin
    if (!reset11_n) begin
        u_low_regs__reg0_db[7:4] <= 4'd0;
    end else begin
        u_low_regs__reg0_db[7:4] <= db_in_buf4[7:4];
    end
end // j150
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_low_regs__reset20_buf_n) begin
        u_low_regs__reg2_db[3:0] = 4'd0;
    end else if (!reg2_wr_n) begin
        u_low_regs__reg2_db[3:0] = db_in_buf2[3:0];
    end
end // g116
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_low_regs__reset20_buf_n) begin
        u_low_regs__reg2_db[7:4] = 4'd0;
    end else if (!reg2_wr_n) begin
        u_low_regs__reg2_db[7:4] = db_in_buf2[7:4];
    end
end // g108
/* verilator lint_on LATCH */
always @(posedge reg4_wr_n or negedge reset11_n) begin
    if (!reset11_n) begin
        u_low_regs__reg4_db[3:0] <= 4'd0;
    end else begin
        u_low_regs__reg4_db[3:0] <= db_in_buf4[3:0];
    end
end // h110
always @(posedge reg4_wr_n or negedge reset11_n) begin
    if (!reset11_n) begin
        u_low_regs__reg4_hi_q <= 4'd0;
    end else begin
        u_low_regs__reg4_hi_q <= db_in_buf4[7:4];
    end
end // j137
assign u_low_regs__reg4_db[4] = u_low_regs__reg4_hi_q[0];
assign u_low_regs__reg4_db[5] = u_low_regs__reg4_hi_q[1];
assign u_low_regs__reg4_db[6] = u_low_regs__reg4_hi_q[2];
assign u_low_regs__reg4_db[7] = u_low_regs__reg4_hi_q[3];

always @(posedge reg6_wr_n or negedge reset11_n) begin
    if (!reset11_n) begin
        u_low_regs__reg6_db[3:0] <= 4'd0;
    end else begin
        u_low_regs__reg6_db[3:0] <= pin_db_low_in[3:0];
    end
end // k138
always @(posedge reg6_wr_n or negedge reset11_n) begin
    if (!reset11_n) begin
        u_low_regs__reg6_db[7:4] <= 4'd0;
    end else begin
        u_low_regs__reg6_db[7:4] <= pin_db_low_in[7:4];
    end
end // j109
always @(posedge reg8_wr_n or negedge reset2_n) begin
    if (!reset2_n) begin
        u_low_regs__reg8_db[3:0] <= 4'd0;
    end else begin
        u_low_regs__reg8_db[3:0] <= db_in[3:0];
    end
end // h163
always @(posedge reg8_wr_n or negedge reset2_n) begin
    if (!reset2_n) begin
        u_low_regs__reg8_db[7:4] <= 4'd0;
    end else begin
        u_low_regs__reg8_db[7:4] <= db_in[7:4];
    end
end // m165
always @(posedge rega_wr_n or negedge reset11_n) begin
    if (!reset11_n) begin
        u_low_regs__rega_db[3:0] <= 4'd0;
    end else begin
        u_low_regs__rega_db[3:0] <= pin_db_low_in[3:0];
    end
end // h136
always @(posedge rega_wr_n or negedge reset11_n) begin
    if (!reset11_n) begin
        u_low_regs__rega_db[7:4] <= 4'd0;
    end else begin
        u_low_regs__rega_db[7:4] <= pin_db_low_in[7:4];
    end
end // j164
always @(posedge regc_wr_n or negedge reset2_n) begin
    if (!reset2_n) begin
        u_low_regs__regc_db[3:0] <= 4'd0;
    end else begin
        u_low_regs__regc_db[3:0] <= db_in[3:0];
    end
end // l205
always @(posedge regc_wr_n or negedge reset2_n) begin
    if (!reset2_n) begin
        u_low_regs__regc_db[4] <= 1'b0;
    end else begin
        u_low_regs__regc_db[4] <= db_in[4];
    end
end // k193
always @(posedge regc_wr_n or negedge reset2_n) begin
    if (!reset2_n) begin
        u_low_regs__regc_db[5] <= 1'b0;
    end else begin
        u_low_regs__regc_db[5] <= db_in[5];
    end
end // k190
assign reg0_db = u_low_regs__reg0_db;
assign reg2_db = u_low_regs__reg2_db;
assign reg4_db = u_low_regs__reg4_db;
assign reg6_db = u_low_regs__reg6_db;
assign reg8_db = u_low_regs__reg8_db;
assign rega_db = u_low_regs__rega_db;
assign regc_db = u_low_regs__regc_db;
// End inlined jt054156_page02_low_regs u_low_regs

// Inlined jt054156_page02_mid_regs u_mid_regs
reg [5:0] u_mid_regs__reg10_d;
reg [5:0] u_mid_regs__reg12_d;
reg [5:0] u_mid_regs__reg14_d;
reg [5:0] u_mid_regs__reg16_d;
reg [5:0] u_mid_regs__reg18_d;
reg [5:0] u_mid_regs__reg1a_d;
reg [5:0] u_mid_regs__reg1c_d;
reg [5:0] u_mid_regs__reg1e_d;
reg [10:0] u_mid_regs__reg20_d;
reg [10:0] u_mid_regs__reg22_d;
reg [10:0] u_mid_regs__reg24_d;
reg [10:0] u_mid_regs__reg26_d;
reg [11:0] u_mid_regs__reg28_d;
reg [11:0] u_mid_regs__reg2a_d;
reg [11:0] u_mid_regs__reg2c_d;
reg [11:0] u_mid_regs__reg2e_d;
wire    u_mid_regs__reset13_reg12_buf_n;
wire    u_mid_regs__reset4_reg1e_buf_n;
wire    u_mid_regs__reset14_reg20l_buf_n;
wire    u_mid_regs__reset14_reg20u_buf_n;
wire    u_mid_regs__reset8_reg22l_buf_n;
wire    u_mid_regs__reset8_reg22u_buf_n;
wire    u_mid_regs__reset12_reg24l_buf_n;
wire    u_mid_regs__reset13_reg24u_buf_n;
wire    u_mid_regs__reset9_reg26l_buf_n;
wire    u_mid_regs__reset9_reg26u_buf_n;
wire    u_mid_regs__reset17_reg28l_buf_n;
wire    u_mid_regs__reset17_reg28u_n;
wire    u_mid_regs__reset17_reg2a_buf_n;
wire    u_mid_regs__reset16_reg2cl_buf_n;
wire    u_mid_regs__reset16_reg2el_buf_n;
wire    u_mid_regs__reset16_reg2eu_n;
wire [3:0] u_mid_regs__db_mux_0_3;
assign u_mid_regs__db_mux_0_3 = { db_mux_3_11, db_mux_2_10, db_mux_1_9, db_mux_0_8 };

assign u_mid_regs__reset13_reg12_buf_n = reset13_n; // k156a
assign u_mid_regs__reset4_reg1e_buf_n = reset4_n; // a79a
assign u_mid_regs__reset14_reg20l_buf_n = reset14_n; // n150a
assign u_mid_regs__reset14_reg20u_buf_n = reset14_n; // k135a
assign u_mid_regs__reset8_reg22l_buf_n = reset8_n; // n162a
assign u_mid_regs__reset8_reg22u_buf_n = reset8_n; // l159a
assign u_mid_regs__reset12_reg24l_buf_n = reset12_n; // k136b
assign u_mid_regs__reset13_reg24u_buf_n = reset13_n; // k125b
assign u_mid_regs__reset9_reg26l_buf_n = reset9_n; // k155a
assign u_mid_regs__reset9_reg26u_buf_n = reset9_n; // k124a
assign u_mid_regs__reset17_reg28l_buf_n = reset17_n; // b70b
assign u_mid_regs__reset17_reg2a_buf_n = reset17_n; // b70a
assign u_mid_regs__reset16_reg2cl_buf_n = reset16_n; // a59a
assign u_mid_regs__reset16_reg2el_buf_n = reset16_n; // b69b
assign u_mid_regs__reset17_reg28u_n = reset17_n;
assign u_mid_regs__reset16_reg2eu_n = reset16_n;

/* verilator lint_off LATCH */
always @(*) begin
    if (!reset14_n) begin
        u_mid_regs__reg10_d[3:0] = 4'd0;
    end else if (!reg10_wr_n) begin
        u_mid_regs__reg10_d[3:0] = db_in[3:0];
    end
end // l135
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset14_n) begin
        u_mid_regs__reg10_d[4] = 1'b0;
    end else if (!reg10_wr_n) begin
        u_mid_regs__reg10_d[4] = db_in[4];
    end
end // l170a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset14_n) begin
        u_mid_regs__reg10_d[5] = 1'b0;
    end else if (!reg10_wr_n) begin
        u_mid_regs__reg10_d[5] = db_in[5];
    end
end // l173
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset13_reg12_buf_n) begin
        u_mid_regs__reg12_d[3:0] = 4'd0;
    end else if (!reg12_wr_n) begin
        u_mid_regs__reg12_d[3:0] = db_in[3:0];
    end
end // l143
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset13_reg12_buf_n) begin
        u_mid_regs__reg12_d[4] = 1'b0;
    end else if (!reg12_wr_n) begin
        u_mid_regs__reg12_d[4] = db_in[4];
    end
end // l165a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset13_reg12_buf_n) begin
        u_mid_regs__reg12_d[5] = 1'b0;
    end else if (!reg12_wr_n) begin
        u_mid_regs__reg12_d[5] = db_in[5];
    end
end // l168
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset12_n) begin
        u_mid_regs__reg14_d[3:0] = 4'd0;
    end else if (!reg14_wr_n) begin
        u_mid_regs__reg14_d[3:0] = db_in[3:0];
    end
end // k127
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset12_n) begin
        u_mid_regs__reg14_d[4] = 1'b0;
    end else if (!reg14_wr_n) begin
        u_mid_regs__reg14_d[4] = db_in[4];
    end
end // k159a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset12_n) begin
        u_mid_regs__reg14_d[5] = 1'b0;
    end else if (!reg14_wr_n) begin
        u_mid_regs__reg14_d[5] = db_in[5];
    end
end // k157
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset9_n) begin
        u_mid_regs__reg16_d[3:0] = 4'd0;
    end else if (!reg16_wr_n) begin
        u_mid_regs__reg16_d[3:0] = db_in[3:0];
    end
end // l127
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset9_n) begin
        u_mid_regs__reg16_d[4] = 1'b0;
    end else if (!reg16_wr_n) begin
        u_mid_regs__reg16_d[4] = db_in[4];
    end
end // l175a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset9_n) begin
        u_mid_regs__reg16_d[5] = 1'b0;
    end else if (!reg16_wr_n) begin
        u_mid_regs__reg16_d[5] = db_in[5];
    end
end // l163
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset18_n) begin
        u_mid_regs__reg18_d[3:0] = 4'd0;
    end else if (!reg18_wr_n) begin
        u_mid_regs__reg18_d[3:0] = db_in_buf3[3:0];
    end
end // c190
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset18_n) begin
        u_mid_regs__reg18_d[4] = 1'b0;
    end else if (!reg18_wr_n) begin
        u_mid_regs__reg18_d[4] = db_in_buf3[4];
    end
end // g197a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset18_n) begin
        u_mid_regs__reg18_d[5] = 1'b0;
    end else if (!reg18_wr_n) begin
        u_mid_regs__reg18_d[5] = db_in_buf3[5];
    end
end // g195
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset18_n) begin
        u_mid_regs__reg1a_d[3:0] = 4'd0;
    end else if (!reg1a_wr_n) begin
        u_mid_regs__reg1a_d[3:0] = db_in_buf3[3:0];
    end
end // c170
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset18_n) begin
        u_mid_regs__reg1a_d[4] = 1'b0;
    end else if (!reg1a_wr_n) begin
        u_mid_regs__reg1a_d[4] = db_in_buf3[4];
    end
end // f202
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset18_n) begin
        u_mid_regs__reg1a_d[5] = 1'b0;
    end else if (!reg1a_wr_n) begin
        u_mid_regs__reg1a_d[5] = db_in_buf3[5];
    end
end // g192a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset18_n) begin
        u_mid_regs__reg1c_d[3:0] = 4'd0;
    end else if (!reg1c_wr_n) begin
        u_mid_regs__reg1c_d[3:0] = db_in_buf3[3:0];
    end
end // c179
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset18_n) begin
        u_mid_regs__reg1c_d[4] = 1'b0;
    end else if (!reg1c_wr_n) begin
        u_mid_regs__reg1c_d[4] = db_in_buf3[4];
    end
end // f199a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset18_n) begin
        u_mid_regs__reg1c_d[5] = 1'b0;
    end else if (!reg1c_wr_n) begin
        u_mid_regs__reg1c_d[5] = db_in_buf3[5];
    end
end // f197
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset4_reg1e_buf_n) begin
        u_mid_regs__reg1e_d[3:0] = 4'd0;
    end else if (!reg1e_wr_n) begin
        u_mid_regs__reg1e_d[3:0] = db_in_buf3[3:0];
    end
end // b194
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset4_reg1e_buf_n) begin
        u_mid_regs__reg1e_d[4] = 1'b0;
    end else if (!reg1e_wr_n) begin
        u_mid_regs__reg1e_d[4] = db_in_buf3[4];
    end
end // a200a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset4_reg1e_buf_n) begin
        u_mid_regs__reg1e_d[5] = 1'b0;
    end else if (!reg1e_wr_n) begin
        u_mid_regs__reg1e_d[5] = db_in_buf3[5];
    end
end // b203
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset14_reg20l_buf_n) begin
        u_mid_regs__reg20_d[3:0] = 4'd0;
    end else if (!reg20l_wr_n) begin
        u_mid_regs__reg20_d[3:0] = db_in[3:0];
    end
end // m135
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset14_reg20l_buf_n) begin
        u_mid_regs__reg20_d[7:4] = 4'd0;
    end else if (!reg20l_wr_n) begin
        u_mid_regs__reg20_d[7:4] = db_in[7:4];
    end
end // n110
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset14_reg20u_buf_n) begin
        u_mid_regs__reg20_d[8] = 1'b0;
    end else if (!reg20u_wr_n) begin
        u_mid_regs__reg20_d[8] = db_mux_0_8;
    end
end // k100a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset14_reg20u_buf_n) begin
        u_mid_regs__reg20_d[9] = 1'b0;
    end else if (!reg20u_wr_n) begin
        u_mid_regs__reg20_d[9] = db_mux_1_9;
    end
end // k103
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset14_reg20u_buf_n) begin
        u_mid_regs__reg20_d[10] = 1'b0;
    end else if (!reg20u_wr_n) begin
        u_mid_regs__reg20_d[10] = db_mux_2_10;
    end
end // k105a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset8_reg22l_buf_n) begin
        u_mid_regs__reg22_d[3:0] = 4'd0;
    end else if (!reg22l_wr_n) begin
        u_mid_regs__reg22_d[3:0] = db_in[3:0];
    end
end // n152
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset8_reg22l_buf_n) begin
        u_mid_regs__reg22_d[7:4] = 4'd0;
    end else if (!reg22l_wr_n) begin
        u_mid_regs__reg22_d[7:4] = db_in[7:4];
    end
end // n127
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset8_reg22u_buf_n) begin
        u_mid_regs__reg22_d[8] = 1'b0;
    end else if (!reg22u_wr_n) begin
        u_mid_regs__reg22_d[8] = db_mux_0_8;
    end
end // l105a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset8_reg22u_buf_n) begin
        u_mid_regs__reg22_d[9] = 1'b0;
    end else if (!reg22u_wr_n) begin
        u_mid_regs__reg22_d[9] = db_mux_1_9;
    end
end // k90
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset8_reg22u_buf_n) begin
        u_mid_regs__reg22_d[10] = 1'b0;
    end else if (!reg22u_wr_n) begin
        u_mid_regs__reg22_d[10] = db_mux_2_10;
    end
end // k87a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset12_reg24l_buf_n) begin
        u_mid_regs__reg24_d[3:0] = 4'd0;
    end else if (!reg24l_wr_n) begin
        u_mid_regs__reg24_d[3:0] = db_in[3:0];
    end
end // m143
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset12_reg24l_buf_n) begin
        u_mid_regs__reg24_d[7:4] = 4'd0;
    end else if (!reg24l_wr_n) begin
        u_mid_regs__reg24_d[7:4] = db_in[7:4];
    end
end // m119
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset13_reg24u_buf_n) begin
        u_mid_regs__reg24_d[8] = 1'b0;
    end else if (!reg24u_wr_n) begin
        u_mid_regs__reg24_d[8] = db_mux_0_8;
    end
end // k92a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset13_reg24u_buf_n) begin
        u_mid_regs__reg24_d[9] = 1'b0;
    end else if (!reg24u_wr_n) begin
        u_mid_regs__reg24_d[9] = db_mux_1_9;
    end
end // k95a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset13_reg24u_buf_n) begin
        u_mid_regs__reg24_d[10] = 1'b0;
    end else if (!reg24u_wr_n) begin
        u_mid_regs__reg24_d[10] = db_mux_2_10;
    end
end // k98
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset9_reg26l_buf_n) begin
        u_mid_regs__reg26_d[3:0] = 4'd0;
    end else if (!reg26l_wr_n) begin
        u_mid_regs__reg26_d[3:0] = db_in[3:0];
    end
end // m155
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset9_reg26l_buf_n) begin
        u_mid_regs__reg26_d[7:4] = 4'd0;
    end else if (!reg26l_wr_n) begin
        u_mid_regs__reg26_d[7:4] = db_in[7:4];
    end
end // m127
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset9_reg26u_buf_n) begin
        u_mid_regs__reg26_d[8] = 1'b0;
    end else if (!reg26u_wr_n) begin
        u_mid_regs__reg26_d[8] = db_mux_0_8;
    end
end // k85
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset9_reg26u_buf_n) begin
        u_mid_regs__reg26_d[9] = 1'b0;
    end else if (!reg26u_wr_n) begin
        u_mid_regs__reg26_d[9] = db_mux_1_9;
    end
end // k82a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset9_reg26u_buf_n) begin
        u_mid_regs__reg26_d[10] = 1'b0;
    end else if (!reg26u_wr_n) begin
        u_mid_regs__reg26_d[10] = db_mux_2_10;
    end
end // k80
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset17_reg28l_buf_n) begin
        u_mid_regs__reg28_d[3:0] = 4'd0;
    end else if (!reg28l_wr_n) begin
        u_mid_regs__reg28_d[3:0] = db_in_buf[3:0];
    end
end // e121
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset17_reg28l_buf_n) begin
        u_mid_regs__reg28_d[7:4] = 4'd0;
    end else if (!reg28l_wr_n) begin
        u_mid_regs__reg28_d[7:4] = db_in_buf[7:4];
    end
end // c127
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset17_reg28u_n) begin
        u_mid_regs__reg28_d[11:8] = 4'd0;
    end else if (!reg28u_wr_n) begin
        u_mid_regs__reg28_d[11:8] = u_mid_regs__db_mux_0_3;
    end
end // e80
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset17_reg2a_buf_n) begin
        u_mid_regs__reg2a_d[3:0] = 4'd0;
    end else if (!reg2al_wr_n) begin
        u_mid_regs__reg2a_d[3:0] = db_in_buf[3:0];
    end
end // d121
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset17_reg2a_buf_n) begin
        u_mid_regs__reg2a_d[7:4] = 4'd0;
    end else if (!reg2al_wr_n) begin
        u_mid_regs__reg2a_d[7:4] = db_in_buf[7:4];
    end
end // b109
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset17_reg2a_buf_n) begin
        u_mid_regs__reg2a_d[11:8] = 4'd0;
    end else if (!reg2au_wr_n) begin
        u_mid_regs__reg2a_d[11:8] = u_mid_regs__db_mux_0_3;
    end
end // e72
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset16_reg2cl_buf_n) begin
        u_mid_regs__reg2c_d[3:0] = 4'd0;
    end else if (!reg2cl_wr_n) begin
        u_mid_regs__reg2c_d[3:0] = db_in_buf[3:0];
    end
end // e135
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset16_reg2cl_buf_n) begin
        u_mid_regs__reg2c_d[7:4] = 4'd0;
    end else if (!reg2cl_wr_n) begin
        u_mid_regs__reg2c_d[7:4] = db_in_buf[7:4];
    end
end // a172
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset16_n) begin
        u_mid_regs__reg2c_d[11:8] = 4'd0;
    end else if (!reg2cu_wr_n) begin
        u_mid_regs__reg2c_d[11:8] = u_mid_regs__db_mux_0_3;
    end
end // d56
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset16_reg2el_buf_n) begin
        u_mid_regs__reg2e_d[3:0] = 4'd0;
    end else if (!reg2el_wr_n) begin
        u_mid_regs__reg2e_d[3:0] = db_in_buf[3:0];
    end
end // f135
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset16_reg2el_buf_n) begin
        u_mid_regs__reg2e_d[7:4] = 4'd0;
    end else if (!reg2el_wr_n) begin
        u_mid_regs__reg2e_d[7:4] = db_in_buf[7:4];
    end
end // b179
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_mid_regs__reset16_reg2eu_n) begin
        u_mid_regs__reg2e_d[11:8] = 4'd0;
    end else if (!reg2eu_wr_n) begin
        u_mid_regs__reg2e_d[11:8] = u_mid_regs__db_mux_0_3;
    end
end // e60
/* verilator lint_on LATCH */
assign reg10_d = u_mid_regs__reg10_d;
assign reg12_d = u_mid_regs__reg12_d;
assign reg14_d = u_mid_regs__reg14_d;
assign reg16_d = u_mid_regs__reg16_d;
assign reg18_d = u_mid_regs__reg18_d;
assign reg1a_d = u_mid_regs__reg1a_d;
assign reg1c_d = u_mid_regs__reg1c_d;
assign reg1e_d = u_mid_regs__reg1e_d;
assign reg20_d = u_mid_regs__reg20_d;
assign reg22_d = u_mid_regs__reg22_d;
assign reg24_d = u_mid_regs__reg24_d;
assign reg26_d = u_mid_regs__reg26_d;
assign reg28_d = u_mid_regs__reg28_d;
assign reg2a_d = u_mid_regs__reg2a_d;
assign reg2c_d = u_mid_regs__reg2c_d;
assign reg2e_d = u_mid_regs__reg2e_d;
// End inlined jt054156_page02_mid_regs u_mid_regs

// Inlined jt054156_page02_high_regs u_high_regs
reg [5:0] u_high_regs__reg30_d;
reg [5:0] u_high_regs__reg32_d;
reg [7:0] u_high_regs__reg34u_d;
reg [7:0] u_high_regs__reg34l_d;
reg [1:0] u_high_regs__reg36_d;
reg [15:0] u_high_regs__reg38_d;
reg [11:0] u_high_regs__reg3a_d;
reg [10:0] u_high_regs__reg3c_d;
wire    u_high_regs__reset13_3032_buf_n;
wire    u_high_regs__reset7_34l_buf_n;
wire    u_high_regs__reset7_34u_buf_n;
wire    u_high_regs__reset6_38l_buf_n;
wire    u_high_regs__reset6_38u_buf_n;
wire    u_high_regs__reset3_3a_buf_n;
wire    u_high_regs__reset13_3cl_buf_n;
wire    u_high_regs__reset13_3cu_buf_n;
wire [3:0] u_high_regs__db_mux_0_3;
wire [3:0] u_high_regs__db_mux_4_7;
wire [3:0] u_high_regs__reg34u_hi_d;
reg [3:0] u_high_regs__reg34u_hi_q;
assign u_high_regs__db_mux_0_3 = { db_mux_3_11, db_mux_2_10, db_mux_1_9, db_mux_0_8 };
assign u_high_regs__db_mux_4_7 = { db_mux_7_15, db_mux_6_14, db_mux_5_13, db_mux_4_12 };
assign u_high_regs__reg34u_hi_d = { db_mux_7_15, db_mux_4_12, db_mux_5_13, db_mux_6_14 };

assign u_high_regs__reset13_3032_buf_n = reset13_n; // h162b
assign u_high_regs__reset7_34l_buf_n = reset7_n; // f11b
assign u_high_regs__reset7_34u_buf_n = reset7_n; // j40b
assign u_high_regs__reset6_38l_buf_n = reset6_n; // h79a
assign u_high_regs__reset6_38u_buf_n = reset6_n; // h79b
assign u_high_regs__reset3_3a_buf_n = reset3_n; // e79b
assign u_high_regs__reset13_3cl_buf_n = reset13_n; // k154b
assign u_high_regs__reset13_3cu_buf_n = reset13_n; // h159b
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset13_3032_buf_n) begin
        u_high_regs__reg30_d[3:0] = 4'd0;
    end else if (!reg30_wr_n) begin
        u_high_regs__reg30_d[3:0] = db_in[3:0];
    end
end // h190
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset13_3032_buf_n) begin
        u_high_regs__reg30_d[4] = 1'b0;
    end else if (!reg30_wr_n) begin
        u_high_regs__reg30_d[4] = db_in[4];
    end
end // h187a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset13_3032_buf_n) begin
        u_high_regs__reg30_d[5] = 1'b0;
    end else if (!reg30_wr_n) begin
        u_high_regs__reg30_d[5] = db_in[5];
    end
end // h185
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset13_3032_buf_n) begin
        u_high_regs__reg32_d[3:0] = 4'd0;
    end else if (!reg32_wr_n) begin
        u_high_regs__reg32_d[3:0] = db_in[3:0];
    end
end // j195
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset13_3032_buf_n) begin
        u_high_regs__reg32_d[4] = 1'b0;
    end else if (!reg32_wr_n) begin
        u_high_regs__reg32_d[4] = db_in[4];
    end
end // j190
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset13_3032_buf_n) begin
        u_high_regs__reg32_d[5] = 1'b0;
    end else if (!reg32_wr_n) begin
        u_high_regs__reg32_d[5] = db_in[5];
    end
end // j192a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset7_34l_buf_n) begin
        u_high_regs__reg34l_d[7:4] = 4'd0;
    end else if (!reg34l_wr_n) begin
        u_high_regs__reg34l_d[7:4] = db_in_buf2[7:4];
    end
end // g17
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset7_34l_buf_n) begin
        u_high_regs__reg34l_d[3:0] = 4'd0;
    end else if (!reg34l_wr_n) begin
        u_high_regs__reg34l_d[3:0] = db_in_buf2[3:0];
    end
end // e33
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset7_34u_buf_n) begin
        u_high_regs__reg34u_hi_q = 4'd0;
    end else if (!reg34u_wr_n) begin
        u_high_regs__reg34u_hi_q = u_high_regs__reg34u_hi_d;
    end
end // j42
/* verilator lint_on LATCH */
assign u_high_regs__reg34u_d[4] = u_high_regs__reg34u_hi_q[2];
assign u_high_regs__reg34u_d[5] = u_high_regs__reg34u_hi_q[1];
assign u_high_regs__reg34u_d[6] = u_high_regs__reg34u_hi_q[0];
assign u_high_regs__reg34u_d[7] = u_high_regs__reg34u_hi_q[3];

/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset7_34u_buf_n) begin
        u_high_regs__reg34u_d[3:0] = 4'd0;
    end else if (!reg34u_wr_n) begin
        u_high_regs__reg34u_d[3:0] = u_high_regs__db_mux_0_3;
    end
end // h41
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset7_n) begin
        u_high_regs__reg36_d[0] = 1'b0;
    end else if (!reg36_wr_n) begin
        u_high_regs__reg36_d[0] = db_in_buf2[0];
    end
end // j37a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!reset7_n) begin
        u_high_regs__reg36_d[1] = 1'b0;
    end else if (!reg36_wr_n) begin
        u_high_regs__reg36_d[1] = db_in_buf2[1];
    end
end // j35
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset6_38l_buf_n) begin
        u_high_regs__reg38_d[7:4] = 4'd0;
    end else if (!reg38l_wr_n) begin
        u_high_regs__reg38_d[7:4] = db_in_buf2[7:4];
    end
end // h100
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset6_38l_buf_n) begin
        u_high_regs__reg38_d[3:0] = 4'd0;
    end else if (!reg38l_wr_n) begin
        u_high_regs__reg38_d[3:0] = db_in_buf2[3:0];
    end
end // h87
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset6_38u_buf_n) begin
        u_high_regs__reg38_d[15:12] = 4'd0;
    end else if (!reg38u_wr_n) begin
        u_high_regs__reg38_d[15:12] = u_high_regs__db_mux_4_7;
    end
end // j100
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset6_38u_buf_n) begin
        u_high_regs__reg38_d[11:8] = 4'd0;
    end else if (!reg38u_wr_n) begin
        u_high_regs__reg38_d[11:8] = u_high_regs__db_mux_0_3;
    end
end // j82
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset3_3a_buf_n) begin
        u_high_regs__reg3a_d[3:0] = 4'd0;
    end else if (!reg3al_wr_n) begin
        u_high_regs__reg3a_d[3:0] = db_in_buf3[3:0];
    end
end // e169
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset3_3a_buf_n) begin
        u_high_regs__reg3a_d[7:4] = 4'd0;
    end else if (!reg3al_wr_n) begin
        u_high_regs__reg3a_d[7:4] = db_in_buf3[7:4];
    end
end // g154
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset3_3a_buf_n) begin
        u_high_regs__reg3a_d[11:8] = 4'd0;
    end else if (!reg3au_wr_n) begin
        u_high_regs__reg3a_d[11:8] = u_high_regs__db_mux_0_3;
    end
end // f60
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset13_3cl_buf_n) begin
        u_high_regs__reg3c_d[3:0] = 4'd0;
    end else if (!reg3cl_wr_n) begin
        u_high_regs__reg3c_d[3:0] = db_in[3:0];
    end
end // m110
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset13_3cl_buf_n) begin
        u_high_regs__reg3c_d[7:4] = 4'd0;
    end else if (!reg3cl_wr_n) begin
        u_high_regs__reg3c_d[7:4] = db_in[7:4];
    end
end // k115
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset13_3cu_buf_n) begin
        u_high_regs__reg3c_d[8] = 1'b0;
    end else if (!reg3cu_wr_n) begin
        u_high_regs__reg3c_d[8] = db_mux_0_8;
    end
end // h63a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset13_3cu_buf_n) begin
        u_high_regs__reg3c_d[9] = 1'b0;
    end else if (!reg3cu_wr_n) begin
        u_high_regs__reg3c_d[9] = db_mux_1_9;
    end
end // h58a
/* verilator lint_on LATCH */
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_high_regs__reset13_3cu_buf_n) begin
        u_high_regs__reg3c_d[10] = 1'b0;
    end else if (!reg3cu_wr_n) begin
        u_high_regs__reg3c_d[10] = db_mux_2_10;
    end
end // h61
/* verilator lint_on LATCH */
assign reg30_d = u_high_regs__reg30_d;
assign reg32_d = u_high_regs__reg32_d;
assign reg34u_d = u_high_regs__reg34u_d;
assign reg34l_d = u_high_regs__reg34l_d;
assign reg36_d = u_high_regs__reg36_d;
assign reg38_d = u_high_regs__reg38_d;
assign reg3a_d = u_high_regs__reg3a_d;
assign reg3c_d = u_high_regs__reg3c_d;
// End inlined jt054156_page02_high_regs u_high_regs

endmodule


// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054156_db_output.v
// -----------------------------------------------------------------------------

// Connected DB-output path tying page-6 selector controls to the page-11 DB
// output mux bank.
module jt054156_db_output(
    input  wire [23:0] vd_latch_n,
    input  wire        regc_db0,
    input  wire        regc_db1,
    input  wire        reg6_db5,
    input  wire        pin_uds,
    input  wire        pin_ab1,
    input  wire        pin_ab11,
    input  wire        pin_ab12,
    output wire [15:0] pin_db_out,

    output wire        p54a_y,
    output wire        m53a_y,
    output wire        m53b_y,
    output wire        n25a_y,
    output wire        n57b_y,
    output wire        p43a_x,
    output wire        p41_x,
    output wire        p39a_x,

    output wire        l54a_y,
    output wire        l54b_y,
    output wire        l78a_y,
    output wire        l78b_y,
    output wire        k79b_y,
    output wire        k78b_y,
    output wire        l105b_y,
    output wire        l104a_y,
    output wire        l53a_y,
    output wire        l53b_y
);

wire p124b_y, p110a_y, r111b_y;
wire n25b_y, n26a_y, m118a_y, m118b_y;
wire p50a_y, p50b_y, p51a_y, p51b_y;
wire p52a_y, p52b_y, p38_y, p29a_y;

// Inlined jt054156_page06_db_out_ctrl u_page06_ctrl
// Inlined jt054156_page06_db_out_p54a u_p54a
assign p124b_y = regc_db0; // p124b
assign p110a_y = regc_db1; // p110a
assign r111b_y = ~regc_db1; // r111b
assign p54a_y = ~|{p124b_y,r111b_y,pin_ab11}; // p54a
assign n57b_y = ~&{pin_ab11,p110a_y}; // n57b
// End inlined jt054156_page06_db_out_p54a u_p54a

// Inlined jt054156_page06_db_out_selectors u_selectors
wire u_selectors__gnd = 1'b0;

assign p51b_y = ~p110a_y; // p51b
assign p50b_y = ~p124b_y; // p50b
assign p52a_y = ~pin_ab11; // p52a
assign p43a_x = ~(p110a_y ? (p124b_y ? u_selectors__gnd : p52a_y) : (p124b_y ? pin_uds : pin_uds)); // p43a
assign p51a_y = ~p110a_y; // p51a
assign p50a_y = ~p124b_y; // p50a
assign p52b_y = ~pin_ab12; // p52b
assign p41_x = ~(p110a_y ? (p124b_y ? u_selectors__gnd : p52b_y) : (p124b_y ? p52b_y : pin_ab1)); // p41
assign p38_y = p124b_y ^ p110a_y; // p38
assign p29a_y = ~p38_y; // p29a
assign p39a_x = p38_y ? ~p52b_y : ~pin_ab1; // p39a
// End inlined jt054156_page06_db_out_selectors u_selectors

// Inlined jt054156_page06_db_out_m53 u_m53
assign n25b_y = ~p43a_x; // n25b
assign n26a_y = ~p41_x; // n26a
assign n25a_y = ~p39a_x; // n25a
assign m118b_y = ~reg6_db5; // m118b
assign m118a_y = ~reg6_db5; // m118a
assign m53a_y = reg6_db5 ? ~n57b_y : ~n25b_y; // m53a
assign m53b_y = reg6_db5 ? ~n25a_y : ~n26a_y; // m53b
// End inlined jt054156_page06_db_out_m53 u_m53
// End inlined jt054156_page06_db_out_ctrl u_page06_ctrl

// Inlined jt054156_page11_db_out_mux u_page11_mux
wire u_page11_mux__vcc = 1'b1;

assign l54a_y = ~m53a_y; // l54a
assign l54b_y = ~m53b_y; // l54b
assign l78a_y = l54a_y; // l78a
assign l78b_y = ~l54a_y; // l78b
assign k79b_y = l54b_y; // k79b
assign k78b_y = ~l54b_y; // k78b
assign l105b_y = p54a_y; // l105b
assign l104a_y = ~p54a_y; // l104a
assign l53a_y = n25a_y; // l53a
assign l53b_y = ~n25a_y; // l53b
jt054156_t5a u_k60a(
    .a1 ( vd_latch_n[16] ),
    .a2 ( vd_latch_n[16] ),
    .s1 ( k79b_y         ),
    .s2 ( k78b_y         ),
    .s5 ( l78a_y         ),
    .s6 ( l78b_y         ),
    .s3 ( k79b_y         ),
    .s4 ( k78b_y         ),
    .b1 ( vd_latch_n[8]  ),
    .b2 ( vd_latch_n[0]  ),
    .x  ( pin_db_out[0]  )
);

jt054156_t5a u_k63(
    .a1 ( vd_latch_n[17] ),
    .a2 ( vd_latch_n[17] ),
    .s1 ( k79b_y         ),
    .s2 ( k78b_y         ),
    .s5 ( l78a_y         ),
    .s6 ( l78b_y         ),
    .s3 ( k79b_y         ),
    .s4 ( k78b_y         ),
    .b1 ( vd_latch_n[9]  ),
    .b2 ( vd_latch_n[1]  ),
    .x  ( pin_db_out[1]  )
);

jt054156_t5a u_l65a(
    .a1 ( vd_latch_n[18] ),
    .a2 ( vd_latch_n[18] ),
    .s1 ( k79b_y         ),
    .s2 ( k78b_y         ),
    .s5 ( l78a_y         ),
    .s6 ( l78b_y         ),
    .s3 ( k79b_y         ),
    .s4 ( k78b_y         ),
    .b1 ( vd_latch_n[10] ),
    .b2 ( vd_latch_n[2]  ),
    .x  ( pin_db_out[2]  )
);

jt054156_t5a u_k70a(
    .a1 ( vd_latch_n[19] ),
    .a2 ( vd_latch_n[19] ),
    .s1 ( k79b_y         ),
    .s2 ( k78b_y         ),
    .s5 ( l78a_y         ),
    .s6 ( l78b_y         ),
    .s3 ( k79b_y         ),
    .s4 ( k78b_y         ),
    .b1 ( vd_latch_n[11] ),
    .b2 ( vd_latch_n[3]  ),
    .x  ( pin_db_out[3]  )
);

jt054156_t5a u_k68(
    .a1 ( vd_latch_n[20] ),
    .a2 ( vd_latch_n[20] ),
    .s1 ( k79b_y         ),
    .s2 ( k78b_y         ),
    .s5 ( l78a_y         ),
    .s6 ( l78b_y         ),
    .s3 ( k79b_y         ),
    .s4 ( k78b_y         ),
    .b1 ( vd_latch_n[12] ),
    .b2 ( vd_latch_n[4]  ),
    .x  ( pin_db_out[4]  )
);

jt054156_t5a u_k65a(
    .a1 ( vd_latch_n[21] ),
    .a2 ( vd_latch_n[21] ),
    .s1 ( k79b_y         ),
    .s2 ( k78b_y         ),
    .s5 ( l78a_y         ),
    .s6 ( l78b_y         ),
    .s3 ( k79b_y         ),
    .s4 ( k78b_y         ),
    .b1 ( vd_latch_n[13] ),
    .b2 ( vd_latch_n[5]  ),
    .x  ( pin_db_out[5]  )
);

jt054156_t5a u_l68(
    .a1 ( vd_latch_n[22] ),
    .a2 ( vd_latch_n[22] ),
    .s1 ( k79b_y         ),
    .s2 ( k78b_y         ),
    .s5 ( l78a_y         ),
    .s6 ( l78b_y         ),
    .s3 ( k79b_y         ),
    .s4 ( k78b_y         ),
    .b1 ( vd_latch_n[14] ),
    .b2 ( vd_latch_n[6]  ),
    .x  ( pin_db_out[6]  )
);

jt054156_t5a u_l70a(
    .a1 ( vd_latch_n[23] ),
    .a2 ( vd_latch_n[23] ),
    .s1 ( k79b_y         ),
    .s2 ( k78b_y         ),
    .s5 ( l78a_y         ),
    .s6 ( l78b_y         ),
    .s3 ( k79b_y         ),
    .s4 ( k78b_y         ),
    .b1 ( vd_latch_n[15] ),
    .b2 ( vd_latch_n[7]  ),
    .x  ( pin_db_out[7]  )
);

jt054156_t5a u_k58(
    .a1 ( u_page11_mux__vcc            ),
    .a2 ( vd_latch_n[16] ),
    .s1 ( l53b_y         ),
    .s2 ( l53a_y         ),
    .s5 ( l104a_y        ),
    .s6 ( l105b_y        ),
    .s3 ( l53b_y         ),
    .s4 ( l53a_y         ),
    .b1 ( vd_latch_n[8]  ),
    .b2 ( vd_latch_n[0]  ),
    .x  ( pin_db_out[8]  )
);

jt054156_t5a u_k53(
    .a1 ( u_page11_mux__vcc            ),
    .a2 ( vd_latch_n[17] ),
    .s1 ( l53b_y         ),
    .s2 ( l53a_y         ),
    .s5 ( l104a_y        ),
    .s6 ( l105b_y        ),
    .s3 ( l53b_y         ),
    .s4 ( l53a_y         ),
    .b1 ( vd_latch_n[9]  ),
    .b2 ( vd_latch_n[1]  ),
    .x  ( pin_db_out[9]  )
);

jt054156_t5a u_l63(
    .a1 ( u_page11_mux__vcc             ),
    .a2 ( vd_latch_n[18]  ),
    .s1 ( l53b_y          ),
    .s2 ( l53a_y          ),
    .s5 ( l104a_y         ),
    .s6 ( l105b_y         ),
    .s3 ( l53b_y          ),
    .s4 ( l53a_y          ),
    .b1 ( vd_latch_n[10]  ),
    .b2 ( vd_latch_n[2]   ),
    .x  ( pin_db_out[10]  )
);

jt054156_t5a u_k75a(
    .a1 ( u_page11_mux__vcc             ),
    .a2 ( vd_latch_n[19]  ),
    .s1 ( l53b_y          ),
    .s2 ( l53a_y          ),
    .s5 ( l104a_y         ),
    .s6 ( l105b_y         ),
    .s3 ( l53b_y          ),
    .s4 ( l53a_y          ),
    .b1 ( vd_latch_n[11]  ),
    .b2 ( vd_latch_n[3]   ),
    .x  ( pin_db_out[11]  )
);

jt054156_t5a u_k73(
    .a1 ( u_page11_mux__vcc             ),
    .a2 ( vd_latch_n[20]  ),
    .s1 ( l53b_y          ),
    .s2 ( l53a_y          ),
    .s5 ( l104a_y         ),
    .s6 ( l105b_y         ),
    .s3 ( l53b_y          ),
    .s4 ( l53a_y          ),
    .b1 ( vd_latch_n[12]  ),
    .b2 ( vd_latch_n[4]   ),
    .x  ( pin_db_out[12]  )
);

jt054156_t5a u_k55a(
    .a1 ( u_page11_mux__vcc             ),
    .a2 ( vd_latch_n[21]  ),
    .s1 ( l53b_y          ),
    .s2 ( l53a_y          ),
    .s5 ( l104a_y         ),
    .s6 ( l105b_y         ),
    .s3 ( l53b_y          ),
    .s4 ( l53a_y          ),
    .b1 ( vd_latch_n[13]  ),
    .b2 ( vd_latch_n[5]   ),
    .x  ( pin_db_out[13]  )
);

jt054156_t5a u_l73(
    .a1 ( u_page11_mux__vcc             ),
    .a2 ( vd_latch_n[22]  ),
    .s1 ( l53b_y          ),
    .s2 ( l53a_y          ),
    .s5 ( l104a_y         ),
    .s6 ( l105b_y         ),
    .s3 ( l53b_y          ),
    .s4 ( l53a_y          ),
    .b1 ( vd_latch_n[14]  ),
    .b2 ( vd_latch_n[6]   ),
    .x  ( pin_db_out[14]  )
);

jt054156_t5a u_l75a(
    .a1 ( u_page11_mux__vcc             ),
    .a2 ( vd_latch_n[23]  ),
    .s1 ( l53b_y          ),
    .s2 ( l53a_y          ),
    .s5 ( l104a_y         ),
    .s6 ( l105b_y         ),
    .s3 ( l53b_y          ),
    .s4 ( l53a_y          ),
    .b1 ( vd_latch_n[15]  ),
    .b2 ( vd_latch_n[7]   ),
    .x  ( pin_db_out[15]  )
);
// End inlined jt054156_page11_db_out_mux u_page11_mux

endmodule


// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054156_hv_timing.v
// -----------------------------------------------------------------------------

// Connected horizontal/vertical timing fragment.
//
// This ties the reconstructed page-3 horizontal block, page-4 vertical
// counter/output block, and page-6/page-7 N186 timing source together.

module jt054156_hv_timing(
    input  wire       pin_clk,
    input  wire       reset1_n,
    input  wire       reset10_n,
    input  wire       reset15_n,
    input  wire       reset19_n,
    input  wire       reg0_db0,
    input  wire       reg0_db2,
    input  wire       reg0_db3,
    input  wire       reg0_db4,
    input  wire       reg0_db6,
    input  wire [2:0] reg6_db,
    input  wire       test0,
    input  wire       test1,
    input  wire       test2,
    input  wire       pin_test,
    input  wire       pin_enhs,
    input  wire       pin_envs,
    input  wire       r0_2or6,

    output wire       dclk2,
    output wire       dclk3,
    output wire       pin_dclk,
    output wire       dclk3_buf,
    output wire       hload_n,
    output wire [8:0] hcnt,
    output wire [8:0] vcnt,
    output wire       pin_nhsy,
    output wire       pin_nhbl,
    output wire       pin_nvsy,
    output wire       pin_nvbl,
    output wire       pin_irq,
    output wire       pin_firq,
    output wire       pin_nmi,
    output wire       hcnt0f,
    output wire       hcnt1f,
    output wire       p40b_y,
    output wire       n107b_y,
    output wire       n29_co,
    output wire       m25_co,
    output wire       r34_xq,
    output wire       n8b_y,
    output wire       n9a_q,
    output wire       p140_q,
    output wire       p140_xq,
    output wire       p140_q_n,
    output wire       p140_xq_n,
    output wire       n186_x0,
    output wire       n186_x0_n,
    output wire       n186_x1,
    output wire       n186_x1_n,
    output wire       n186_x2,
    output wire       n186_x3,
    output wire       n186_x2_n,
    output wire       n186_x3_n,
    output wire       n186_x2t_n,
    output wire       n186_x3t_n,
    output wire       n186_x2t_buf_n,
    output wire       n186_x3t_buf_n,
    output wire       pin_s2h,
    output wire       pin_s4h
);

wire hcnt0 = hcnt[0];
wire hcnt1 = hcnt[1];
wire n13a_q, n13a_nq, n23a_y, m11_y;

// Inlined jt054156_page06_reg0_inv u_reg0_inv
assign p40b_y = ~reg0_db2; // p40b
assign n107b_y = ~reg0_db3; // n107b
// End inlined jt054156_page06_reg0_inv u_reg0_inv

// Inlined jt054156_page03_horizontal u_horizontal
wire u_horizontal__unused_p56_co;
wire u_horizontal__unused_p84_co;
wire u_horizontal__unused_p126a_y;
wire u_horizontal__unused_p48a_y;
// Inlined jt054156_page03_hcnt u_hcnt
wire       u_hcnt__p49b_y;
wire [3:0] u_hcnt__p56_d, u_hcnt__p84_d, u_hcnt__r80_d;
wire [3:0] u_hcnt__p56_q, u_hcnt__p84_q, u_hcnt__r80_q;

assign u_hcnt__p56_d = 4'b0000;
assign u_hcnt__p84_d = { 4{ u_horizontal__unused_p48a_y } };
assign u_hcnt__r80_d = { 4{ u_horizontal__unused_p48a_y } };

assign hcnt[3:0] = u_hcnt__p56_q;
assign hcnt[7:4] = u_hcnt__p84_q;
assign hcnt[8]   = u_hcnt__r80_q[0];

assign dclk3_buf = dclk3; // r114a
assign u_horizontal__unused_p126a_y = p140_q; // p126a
assign u_hcnt__p49b_y = ~reg0_db6; // p49b
assign u_horizontal__unused_p48a_y = u_hcnt__p49b_y & p40b_y; // p48a
jt054156_c43 u_p56(
    .ck      ( dclk3_buf ),
    .d       ( u_hcnt__p56_d     ),
    .load_n  ( hload_n   ),
    .en      ( u_horizontal__unused_p126a_y   ),
    .ci      ( u_horizontal__unused_p126a_y   ),
    .clear_n ( reset15_n ),
    .q       ( u_hcnt__p56_q     ),
    .co      ( u_horizontal__unused_p56_co    )
);

jt054156_c43 u_p84(
    .ck      ( dclk3_buf ),
    .d       ( u_hcnt__p84_d     ),
    .load_n  ( hload_n   ),
    .en      ( u_horizontal__unused_p56_co    ),
    .ci      ( u_horizontal__unused_p56_co    ),
    .clear_n ( reset15_n ),
    .q       ( u_hcnt__p84_q     ),
    .co      ( u_horizontal__unused_p84_co    )
);

jt054156_c43 u_r80(
    .ck      ( dclk3_buf ),
    .d       ( u_hcnt__r80_d     ),
    .load_n  ( hload_n   ),
    .en      ( u_horizontal__unused_p84_co    ),
    .ci      ( u_horizontal__unused_p84_co    ),
    .clear_n ( reset15_n ),
    .q       ( u_hcnt__r80_q     ),
    .co      (           )
);
// End inlined jt054156_page03_hcnt u_hcnt

// Inlined jt054156_page03_hload u_hload
wire u_hload__unused_r43b_y;
wire u_hload__unused_r48_nq;
wire u_hload__unused_r51a_x;
wire u_hload__unused_r45b_x;
reg     u_hload__r48_q;

wire    u_hload__hcnt5, u_hload__hcnt7, u_hload__hcnt8;
wire    u_hload__r54b_y, u_hload__r58a_y, u_hload__r44a_y, u_hload__r47b_y, u_hload__r45a_y;
assign u_hload__hcnt5 = hcnt[5];
assign u_hload__hcnt7 = hcnt[7];
assign u_hload__hcnt8 = hcnt[8];

assign u_hload__r54b_y = ~u_hload__hcnt8; // r54b
assign u_hload__r58a_y = &{u_hload__r54b_y,u_hload__hcnt5,u_hload__hcnt7,u_horizontal__unused_p56_co}; // r58a
assign u_hload__r44a_y = ~reg0_db6; // r44a
assign u_hload__unused_r51a_x = reg0_db6 ? ~u_horizontal__unused_p84_co : ~u_hload__r58a_y; // r51a
assign u_hload__unused_r43b_y = pin_enhs | p40b_y; // r43b
always @(posedge dclk3_buf or negedge reg0_db2) begin
    if (!reg0_db2) begin
        u_hload__r48_q <= 1'b1;
    end else begin
        u_hload__r48_q <= u_hload__unused_r43b_y;
    end
end // r48

assign u_hload__unused_r48_nq = ~u_hload__r48_q; // r48
assign u_hload__r47b_y = ~&{u_hload__unused_r43b_y,u_hload__unused_r48_nq}; // r47b
assign u_hload__r45a_y = ~reg0_db2; // r45a
assign u_hload__unused_r45b_x = reg0_db2 ? ~u_hload__r47b_y : ~u_hload__unused_r51a_x; // r45b
assign hload_n = ~u_hload__unused_r45b_x; // r52b
// End inlined jt054156_page03_hload u_hload

// Inlined jt054156_page03_nhsy u_nhsy
wire u_nhsy__unused_r43a_y;
reg u_nhsy__unused_r55_q;
reg     u_nhsy__r34_q;

wire    u_nhsy__hcnt2, u_nhsy__hcnt3, u_nhsy__hcnt5, u_nhsy__hcnt6, u_nhsy__hcnt7, u_nhsy__hcnt8;
wire    u_nhsy__r29a_y, u_nhsy__r37a_x, u_nhsy__r46a_y, u_nhsy__r53a_y, u_nhsy__r74a_y;
assign u_nhsy__hcnt2 = hcnt[2];
assign u_nhsy__hcnt3 = hcnt[3];
assign u_nhsy__hcnt5 = hcnt[5];
assign u_nhsy__hcnt6 = hcnt[6];
assign u_nhsy__hcnt7 = hcnt[7];
assign u_nhsy__hcnt8 = hcnt[8];

assign pin_nhsy = u_nhsy__r37a_x;

assign u_nhsy__r74a_y = ~&{u_nhsy__hcnt3,u_nhsy__hcnt5,u_nhsy__hcnt6}; // r74a
assign u_nhsy__r53a_y = u_nhsy__r74a_y & u_nhsy__unused_r55_q; // r53a
always @(posedge u_nhsy__hcnt2 or negedge u_nhsy__hcnt7) begin
    if (!u_nhsy__hcnt7) begin
        u_nhsy__unused_r55_q <= 1'b1;
    end else begin
        u_nhsy__unused_r55_q <= u_nhsy__r53a_y;
    end
end // r55
assign u_nhsy__r46a_y = reg0_db2 | u_nhsy__unused_r55_q; // r46a
assign u_nhsy__unused_r43a_y = ~&{u_nhsy__r46a_y,pin_enhs}; // r43a
assign u_nhsy__r29a_y = ~r0_2or6; // r29a
assign u_nhsy__r37a_x = ~((u_nhsy__r29a_y & u_nhsy__hcnt8) | (r0_2or6 & u_nhsy__unused_r43a_y) | (u_nhsy__hcnt8 & u_nhsy__unused_r43a_y)); // r37a
always @(posedge dclk2 or negedge reset15_n) begin
    if (!reset15_n) begin
        u_nhsy__r34_q <= 1'b0;
    end else begin
        u_nhsy__r34_q <= pin_nhsy;
    end
end // r34

assign r34_xq = ~u_nhsy__r34_q; // r34
// End inlined jt054156_page03_nhsy u_nhsy

// Inlined jt054156_page03_nhbl u_nhbl
reg u_nhbl__n9a_q;
wire u_nhbl__unused_n80a_y;
wire u_nhbl__unused_n85b_x;
wire u_nhbl__unused_n81b_x;
wire    u_nhbl__hcnt2, u_nhbl__hcnt3, u_nhbl__hcnt4, u_nhbl__hcnt5, u_nhbl__hcnt7;
wire    u_nhbl__n104b_y, u_nhbl__n72b_y, u_nhbl__n71b_y, u_nhbl__n6_y, u_nhbl__p8a_y, u_nhbl__p11b_x;
wire    u_nhbl__n76b_y, u_nhbl__r74b_y, u_nhbl__r72a_y, u_nhbl__n95a_y, u_nhbl__n80b_y, u_nhbl__n107a_y, u_nhbl__n105_y;
wire    u_nhbl__p46_y, u_nhbl__p15b_y;
reg     u_nhbl__m104_q, u_nhbl__p16a_q;
reg     u_nhbl__n88_q, u_nhbl__n91a_q;
assign u_nhbl__hcnt2 = hcnt[2];
assign u_nhbl__hcnt3 = hcnt[3];
assign u_nhbl__hcnt4 = hcnt[4];
assign u_nhbl__hcnt5 = hcnt[5];
assign u_nhbl__hcnt7 = hcnt[7];

assign u_nhbl__n104b_y = ~u_nhbl__hcnt7; // n104b
assign u_nhbl__unused_n80a_y = ~&{u_nhbl__n104b_y,u_nhbl__hcnt4,u_nhbl__hcnt3}; // n80a
always @(posedge u_nhbl__hcnt2 or negedge reset10_n) begin
    if (!reset10_n) begin
        u_nhbl__n88_q <= 1'b0;
    end else begin
        u_nhbl__n88_q <= u_nhbl__unused_n80a_y;
    end
end // n88
always @(posedge u_nhbl__hcnt4 or negedge reset10_n) begin
    if (!reset10_n) begin
        u_nhbl__n91a_q <= 1'b0;
    end else begin
        u_nhbl__n91a_q <= u_nhbl__hcnt7;
    end
end // n91a
assign u_nhbl__n76b_y = ~reg0_db3; // n76b
assign u_nhbl__r74b_y = u_nhbl__hcnt3 | u_nhbl__n76b_y; // r74b
assign u_nhbl__r72a_y = ~&{u_nhbl__r74b_y,u_nhbl__hcnt5,u_nhbl__hcnt7}; // r72a
assign u_nhbl__n95a_y = u_nhbl__hcnt3 & reg0_db3; // n95a
assign u_nhbl__n80b_y = ~|{u_nhbl__hcnt4,u_nhbl__n95a_y}; // n80b
assign u_nhbl__n107a_y = ~u_nhbl__hcnt7; // n107a
assign u_nhbl__n105_y = u_nhbl__n107a_y; // n105
always @(posedge u_nhbl__hcnt2 or negedge u_nhbl__n105_y or negedge reset10_n) begin
    if (!u_nhbl__n105_y) begin
        u_nhbl__m104_q <= 1'b1;
    end else if (!reset10_n) begin
        u_nhbl__m104_q <= 1'b0;
    end else begin
        u_nhbl__m104_q <= u_nhbl__n80b_y;
    end
end // m104
assign u_nhbl__p46_y = u_nhbl__m104_q; // p46
assign u_nhbl__p15b_y = u_nhbl__r72a_y & u_nhbl__p16a_q; // p15b
always @(posedge u_nhbl__hcnt2 or negedge u_nhbl__p46_y) begin
    if (!u_nhbl__p46_y) begin
        u_nhbl__p16a_q <= 1'b1;
    end else begin
        u_nhbl__p16a_q <= u_nhbl__p15b_y;
    end
end // p16a
jt054156_t2b u_n85b(
    .a  ( u_nhbl__hcnt2      ),
    .b  ( u_nhbl__hcnt3      ),
    .s1 ( reg0_db3   ),
    .s2 ( n107b_y ),
    .x  ( u_nhbl__unused_n85b_x     )
);

assign u_nhbl__n72b_y = ~u_nhbl__unused_n85b_x; // n72b
jt054156_t2b u_n81b(
    .a  ( u_nhbl__n88_q      ),
    .b  ( u_nhbl__n91a_q     ),
    .s1 ( reg0_db3   ),
    .s2 ( n107b_y ),
    .x  ( u_nhbl__unused_n81b_x     )
);

assign u_nhbl__n71b_y = ~u_nhbl__unused_n81b_x; // n71b
assign u_nhbl__n6_y = u_nhbl__n71b_y; // n6
// Inlined jt054156_page03_n8b_term u_n8b_term
wire u_nhbl__u_n8b_term__unused_n82a_y;
wire u_nhbl__u_n8b_term__hcnt3, u_nhbl__u_n8b_term__hcnt4, u_nhbl__u_n8b_term__hcnt5, u_nhbl__u_n8b_term__hcnt6, u_nhbl__u_n8b_term__hcnt7;
wire u_nhbl__u_n8b_term__n83b_y, u_nhbl__u_n8b_term__n84a_y, u_nhbl__u_n8b_term__n96b_y;

assign u_nhbl__u_n8b_term__hcnt3 = hcnt[3];
assign u_nhbl__u_n8b_term__hcnt4 = hcnt[4];
assign u_nhbl__u_n8b_term__hcnt5 = hcnt[5];
assign u_nhbl__u_n8b_term__hcnt6 = hcnt[6];
assign u_nhbl__u_n8b_term__hcnt7 = hcnt[7];

assign u_nhbl__u_n8b_term__n96b_y = u_nhbl__u_n8b_term__hcnt7 & u_nhbl__u_n8b_term__hcnt6; // n96b
assign u_nhbl__u_n8b_term__n84a_y = ~&{u_nhbl__u_n8b_term__n96b_y,u_nhbl__u_n8b_term__hcnt5,reg0_db3}; // n84a
assign u_nhbl__u_n8b_term__n83b_y = ~&{u_nhbl__u_n8b_term__n96b_y,u_nhbl__u_n8b_term__hcnt4,u_nhbl__u_n8b_term__hcnt3,reg0_db3}; // n83b
assign u_nhbl__u_n8b_term__unused_n82a_y = u_nhbl__u_n8b_term__n84a_y & u_nhbl__u_n8b_term__n83b_y; // n82a
assign n8b_y = n29_co & u_nhbl__u_n8b_term__unused_n82a_y; // n8b
// End inlined jt054156_page03_n8b_term u_n8b_term

always @(posedge u_nhbl__n72b_y or negedge u_nhbl__n6_y) begin
    if (!u_nhbl__n6_y) begin
        u_nhbl__n9a_q <= 1'b1;
    end else begin
        u_nhbl__n9a_q <= n8b_y;
    end
end // n9a
assign u_nhbl__p8a_y = ~reg0_db6; // p8a
assign u_nhbl__p11b_x = reg0_db6 ? ~u_nhbl__n9a_q : ~u_nhbl__p16a_q; // p11b
assign pin_nhbl = ~u_nhbl__p11b_x; // r8b
assign n9a_q = u_nhbl__n9a_q;
// End inlined jt054156_page03_nhbl u_nhbl
// End inlined jt054156_page03_horizontal u_horizontal

// Inlined jt054156_page04_vcnt u_vcnt
wire u_vcnt__unused_n8a_y;
wire u_vcnt__unused_p37a_y;
reg u_vcnt__n13a_q;
wire u_vcnt__unused_r16b_y;
wire u_vcnt__unused_r13a_y;
wire u_vcnt__unused_r30a_nq;
wire u_vcnt__unused_r29b_y;
wire u_vcnt__unused_p26a_y;
wire u_vcnt__unused_r30b_y;
wire u_vcnt__unused_p26b_y;
wire u_vcnt__unused_n18a_y;
wire u_vcnt__unused_p36b_y;
wire u_vcnt__unused_p30_y;
wire u_vcnt__unused_p23a_x;
wire u_vcnt__unused_p23b_y;
wire u_vcnt__unused_r15b_y;
wire u_vcnt__unused_r17a_y;
wire u_vcnt__unused_n5a_y;
wire u_vcnt__unused_p28_x;
reg     u_vcnt__r30a_q;

reg     u_vcnt__vcnt0;
wire [3:0] u_vcnt__n29_q, u_vcnt__m25_q;
wire [3:0] u_vcnt__n29_d, u_vcnt__m25_d;
wire    u_vcnt__n26b_y, u_vcnt__p36a_y, u_vcnt__p8b_y, u_vcnt__p9a_x, u_vcnt__p10b_y;
assign vcnt[0]   = u_vcnt__vcnt0;
assign vcnt[4:1] = u_vcnt__n29_q;
assign vcnt[8:5] = u_vcnt__m25_q;
assign u_vcnt__n29_d     = { p40b_y, p40b_y, 1'b0, u_vcnt__n26b_y };
assign u_vcnt__m25_d     = { 4{ p40b_y } };

assign u_vcnt__unused_n5a_y = ~vcnt[8]; // n5a
assign m11_y = &{vcnt[5],vcnt[6],vcnt[7],u_vcnt__unused_n5a_y}; // m11
assign u_vcnt__unused_r30b_y = ~|{pin_nhsy,r34_xq}; // r30b
assign u_vcnt__unused_p26b_y = u_vcnt__unused_r30b_y | test2; // p26b
assign u_vcnt__unused_n8a_y = ~&{m11_y,n29_co}; // n8a
assign u_vcnt__unused_p37a_y = ~p40b_y; // p37a
assign u_vcnt__n26b_y = reg0_db6 & p40b_y; // n26b
assign u_vcnt__p36a_y = ~|{reg0_db6,u_vcnt__unused_p37a_y}; // p36a
assign n23a_y = vcnt[1] & vcnt[2]; // n23a
always @(posedge n23a_y or negedge vcnt[8]) begin
    if (!vcnt[8]) begin
        u_vcnt__n13a_q <= 1'b0;
    end else begin
        u_vcnt__n13a_q <= vcnt[4];
    end
end // n13a

assign n13a_nq = ~u_vcnt__n13a_q; // n13a
assign u_vcnt__unused_r16b_y = reg0_db2 | u_vcnt__n13a_q; // r16b
assign u_vcnt__unused_r13a_y = u_vcnt__unused_r16b_y & pin_envs; // r13a
always @(posedge dclk2 or negedge reset15_n) begin
    if (!reset15_n) begin
        u_vcnt__r30a_q <= 1'b0;
    end else begin
        u_vcnt__r30a_q <= u_vcnt__unused_r13a_y;
    end
end // r30a

assign u_vcnt__unused_r30a_nq = ~u_vcnt__r30a_q; // r30a
assign u_vcnt__unused_r29b_y = ~&{u_vcnt__unused_r30a_nq,u_vcnt__unused_r13a_y}; // r29b
assign u_vcnt__p8b_y = ~r0_2or6; // p8b
assign u_vcnt__p9a_x = r0_2or6 ? ~u_vcnt__unused_r29b_y : ~u_vcnt__p36a_y; // p9a
assign u_vcnt__p10b_y = ~u_vcnt__p9a_x; // p10b
assign u_vcnt__unused_p26a_y = u_vcnt__p36a_y | u_vcnt__p10b_y; // p26a
assign u_vcnt__unused_n18a_y = u_vcnt__unused_p26b_y; // n18a
assign u_vcnt__unused_p36b_y = reset15_n & u_vcnt__unused_p26a_y; // p36b
assign u_vcnt__unused_p30_y = u_vcnt__unused_p36b_y; // p30
assign u_vcnt__unused_p23b_y = ~test2; // p23b
assign u_vcnt__unused_p23a_x = test2 ? ~u_vcnt__unused_p26b_y : ~u_vcnt__unused_p26b_y; // p23a
assign u_vcnt__unused_r15b_y = ~u_vcnt__unused_p23a_x; // r15b
assign u_vcnt__unused_r17a_y = u_vcnt__unused_r15b_y; // r17a
assign u_vcnt__unused_p28_x = u_vcnt__unused_n18a_y ^ u_vcnt__vcnt0; // p28
always @(posedge dclk2 or negedge u_vcnt__unused_p30_y) begin
    if (!u_vcnt__unused_p30_y) begin
        u_vcnt__vcnt0 <= 1'b0;
    end else begin
        u_vcnt__vcnt0 <= u_vcnt__unused_p28_x;
    end
end // p32a
jt054156_c43 u_n29(
    .ck      ( dclk2     ),
    .d       ( u_vcnt__n29_d     ),
    .load_n  ( u_vcnt__unused_r17a_y    ),
    .en      ( u_vcnt__unused_n18a_y    ),
    .ci      ( u_vcnt__vcnt0     ),
    .clear_n ( reset15_n ),
    .q       ( u_vcnt__n29_q     ),
    .co      ( n29_co    )
);

jt054156_c43 u_m25(
    .ck      ( dclk2     ),
    .d       ( u_vcnt__m25_d     ),
    .load_n  ( u_vcnt__unused_r17a_y    ),
    .en      ( u_vcnt__unused_n18a_y    ),
    .ci      ( n29_co    ),
    .clear_n ( reset15_n ),
    .q       ( u_vcnt__m25_q     ),
    .co      ( m25_co    )
);
assign n13a_q = u_vcnt__n13a_q;
// End inlined jt054156_page04_vcnt u_vcnt

// Inlined jt054156_page04_sync_irq u_sync_irq
reg u_sync_irq__pin_irq;
reg u_sync_irq__pin_firq;
reg u_sync_irq__pin_nmi;
wire u_sync_irq__unused_p9b_y;
wire u_sync_irq__unused_p11a_x;
wire u_sync_irq__unused_p15a_y;
reg u_sync_irq__unused_p20_q;
wire u_sync_irq__unused_r7b_y;
wire u_sync_irq__unused_r13b_y;
wire u_sync_irq__unused_r7a_y;
wire u_sync_irq__unused_r6b_y;
wire u_sync_irq__unused_r5a_x;
wire u_sync_irq__unused_r129_y;
reg u_sync_irq__unused_r131a_q;
wire u_sync_irq__unused_r131a_nq;
wire u_sync_irq__unused_r178_y;
reg u_sync_irq__unused_r169a_q;
wire u_sync_irq__unused_r169a_nq;
wire    u_sync_irq__gnd = 1'b0;
assign u_sync_irq__unused_p9b_y = ~reg0_db6; // p9b
assign u_sync_irq__unused_p11a_x = reg0_db6 ? ~vcnt[8] : ~m11_y; // p11a
assign u_sync_irq__unused_p15a_y = ~u_sync_irq__unused_p11a_x; // p15a
always @(posedge n23a_y or negedge reset15_n) begin
    if (!reset15_n) begin
        u_sync_irq__unused_p20_q <= 1'b0;
    end else begin
        u_sync_irq__unused_p20_q <= u_sync_irq__unused_p15a_y;
    end
end // p20

assign pin_nvbl = ~u_sync_irq__unused_p20_q; // p20
assign u_sync_irq__unused_r7b_y = ~vcnt[8]; // r7b
assign u_sync_irq__unused_r13b_y = reg0_db2 & n13a_nq; // r13b
assign u_sync_irq__unused_r7a_y = u_sync_irq__unused_r13b_y & pin_envs; // r7a
assign u_sync_irq__unused_r6b_y = ~r0_2or6; // r6b
assign u_sync_irq__unused_r5a_x = r0_2or6 ? ~u_sync_irq__unused_r7a_y : ~u_sync_irq__unused_r7b_y; // r5a
assign pin_nvsy = ~u_sync_irq__unused_r5a_x; // r11b
always @(posedge n23a_y or negedge reg6_db[0]) begin
    if (!reg6_db[0]) begin
        u_sync_irq__pin_irq <= 1'b1;
    end else begin
        u_sync_irq__pin_irq <= u_sync_irq__gnd;
    end
end // p136a
always @(posedge vcnt[0] or negedge reg6_db[1]) begin
    if (!reg6_db[1]) begin
        u_sync_irq__pin_firq <= 1'b1;
    end else begin
        u_sync_irq__pin_firq <= u_sync_irq__gnd;
    end
end // p137
assign u_sync_irq__unused_r129_y = u_sync_irq__unused_r131a_nq; // r129
always @(posedge vcnt[1] or negedge reset1_n) begin
    if (!reset1_n) begin
        u_sync_irq__unused_r131a_q <= 1'b0;
    end else begin
        u_sync_irq__unused_r131a_q <= u_sync_irq__unused_r129_y;
    end
end // r131a

assign u_sync_irq__unused_r131a_nq = ~u_sync_irq__unused_r131a_q; // r131a
assign u_sync_irq__unused_r178_y = u_sync_irq__unused_r169a_nq; // r178
always @(posedge u_sync_irq__unused_r131a_q or negedge reset1_n) begin
    if (!reset1_n) begin
        u_sync_irq__unused_r169a_q <= 1'b0;
    end else begin
        u_sync_irq__unused_r169a_q <= u_sync_irq__unused_r178_y;
    end
end // r169a

assign u_sync_irq__unused_r169a_nq = ~u_sync_irq__unused_r169a_q; // r169a
always @(posedge u_sync_irq__unused_r169a_q or negedge reg6_db[2]) begin
    if (!reg6_db[2]) begin
        u_sync_irq__pin_nmi <= 1'b1;
    end else begin
        u_sync_irq__pin_nmi <= u_sync_irq__gnd;
    end
end // l184a
assign pin_irq = u_sync_irq__pin_irq;
assign pin_firq = u_sync_irq__pin_firq;
assign pin_nmi = u_sync_irq__pin_nmi;
// End inlined jt054156_page04_sync_irq u_sync_irq

jt054156_n186_timing u_n186_timing(
    .pin_clk          ( pin_clk          ),
    .hcnt0            ( hcnt0            ),
    .hcnt1            ( hcnt1            ),
    .hload_n          ( hload_n          ),
    .reset15_n        ( reset15_n        ),
    .reset19_n        ( reset19_n        ),
    .reg0_db0         ( reg0_db0         ),
    .reg0_db4         ( reg0_db4         ),
    .test0            ( test0            ),
    .test1            ( test1            ),
    .pin_test         ( pin_test         ),
    .hcnt0f           ( hcnt0f           ),
    .hcnt1f           ( hcnt1f           ),
    .n169a_y          (                  ),
    .n166a_y          (                  ),
    .p155_q           (                  ),
    .p155_nq          (                  ),
    .p159_q           (                  ),
    .p159_nq          (                  ),
    .p165a_y          (                  ),
    .p152a_y          (                  ),
    .p150a_y          (                  ),
    .p146_y           (                  ),
    .p151_y           (                  ),
    .dclk2            ( dclk2            ),
    .dclk3            ( dclk3            ),
    .pin_dclk         ( pin_dclk         ),
    .n186_x0          ( n186_x0          ),
    .n186_x0_n        ( n186_x0_n        ),
    .n186_x1          ( n186_x1          ),
    .n186_x1_n        ( n186_x1_n        ),
    .n186_x2          ( n186_x2          ),
    .n186_x3          ( n186_x3          ),
    .n186_x2_n        ( n186_x2_n        ),
    .n186_x3_n        ( n186_x3_n        ),
    .n186_x2t_n       ( n186_x2t_n       ),
    .n186_x3t_n       ( n186_x3t_n       ),
    .n186_x2t_buf_n   ( n186_x2t_buf_n   ),
    .n186_x3t_buf_n   ( n186_x3t_buf_n   ),
    .p140_q           ( p140_q           ),
    .p140_xq          ( p140_xq          ),
    .p140_q_n         ( p140_q_n         ),
    .p140_xq_n        ( p140_xq_n        ),
    .p145b_y          (                  ),
    .p135b_y          (                  ),
    .pin_s2h          ( pin_s2h          ),
    .pin_s4h          ( pin_s4h          )
);

endmodule


// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054156_n186_timing.v
// -----------------------------------------------------------------------------

// Cross-page connected N186 timing fragment with page-7 HCNTF source.
module jt054156_n186_timing(
    input  wire pin_clk,
    input  wire hcnt0,
    input  wire hcnt1,
    input  wire hload_n,
    input  wire reset15_n,
    input  wire reset19_n,
    input  wire reg0_db0,
    input  wire reg0_db4,
    input  wire test0,
    input  wire test1,
    input  wire pin_test,
    output wire hcnt0f,
    output wire hcnt1f,
    output wire n169a_y,
    output wire n166a_y,
    output wire p155_q,
    output wire p155_nq,
    output wire p159_q,
    output wire p159_nq,
    output wire p165a_y,
    output wire p152a_y,
    output wire p150a_y,
    output wire p146_y,
    output wire p151_y,
    output wire dclk2,
    output wire dclk3,
    output wire pin_dclk,
    output wire n186_x0,
    output wire n186_x0_n,
    output wire n186_x1,
    output wire n186_x1_n,
    output wire n186_x2,
    output wire n186_x3,
    output wire n186_x2_n,
    output wire n186_x3_n,
    output wire n186_x2t_n,
    output wire n186_x3t_n,
    output wire n186_x2t_buf_n,
    output wire n186_x3t_buf_n,
    output wire p140_q,
    output wire p140_xq,
    output wire p140_q_n,
    output wire p140_xq_n,
    output wire p145b_y,
    output wire p135b_y,
    output wire pin_s2h,
    output wire pin_s4h
);

wire [1:0] hcnt;

assign hcnt = { hcnt1, hcnt0 };

// Inlined jt054156_page07_hcntf u_hcntf
assign n169a_y = reg0_db4; // n169a
assign n166a_y = reg0_db4; // n166a
assign hcnt0f = hcnt[0] ^ n166a_y; // n181
assign hcnt1f = hcnt[1] ^ n166a_y; // n73
// End inlined jt054156_page07_hcntf u_hcntf

// Inlined jt054156_page06_n186 u_n186
// Inlined jt054156_page06_p155_p159 u_p155_p159
reg u_p155_p159__p155_q;
reg u_p155_p159__p159_q;
assign p165a_y = ~pin_clk; // p165a
always @(posedge p165a_y or negedge reset19_n) begin
    if (!reset19_n) begin
        u_p155_p159__p159_q <= 1'b0;
    end else begin
        u_p155_p159__p159_q <= p152a_y;
    end
end // p159

assign p159_nq = ~u_p155_p159__p159_q; // p159
always @(posedge p165a_y or negedge reset19_n) begin
    if (!reset19_n) begin
        u_p155_p159__p155_q <= 1'b0;
    end else begin
        u_p155_p159__p155_q <= p151_y;
    end
end // p155

assign p155_nq = ~u_p155_p159__p155_q; // p155
assign p152a_y = p159_nq; // p152a
assign p150a_y = ~p152a_y; // p150a
assign p146_y = u_p155_p159__p155_q; // p146
assign p151_y = p150a_y ^ p146_y; // p151
assign dclk2 = u_p155_p159__p159_q; // r127a
assign pin_dclk = u_p155_p159__p159_q; // p172b
assign dclk3 = u_p155_p159__p159_q;
assign p155_q = u_p155_p159__p155_q;
assign p159_q = u_p155_p159__p159_q;
// End inlined jt054156_page06_p155_p159 u_p155_p159

// Inlined jt054156_page06_p140 u_p140
reg u_p140__p140_q;
assign p145b_y = ~p155_q; // p145b
assign p135b_y = p155_q & hload_n; // p135b
always @(posedge p145b_y or negedge reset15_n) begin
    if (!reset15_n) begin
        u_p140__p140_q <= 1'b0;
    end else begin
        u_p140__p140_q <= p135b_y;
    end
end // p140

assign p140_xq = ~u_p140__p140_q; // p140
assign p140_q_n = ~u_p140__p140_q; // n184a
assign p140_xq_n = ~p140_xq; // n184b
assign p140_q = u_p140__p140_q;
// End inlined jt054156_page06_p140 u_p140

// Inlined jt054156_page06_n186_source u_source
wire u_source__n185a_y, u_source__n185b_y;
wire u_source__tied_low = 1'b0;

assign u_source__n185b_y = ~hcnt0; // n185b
assign u_source__n185a_y = ~reg0_db0; // n185a

assign n186_x0 = ~n186_x0_n; // n183a
assign n186_x1 = ~n186_x1_n; // j189b
assign pin_s2h = ~n186_x2; // n214a
assign pin_s4h = ~n186_x3; // p195a
// End inlined jt054156_page06_n186_source u_source

// Inlined jt054156_page06_n186_select u_select
wire u_select__m217b_y, u_select__m211b_y;
wire u_select__m208a_x0, u_select__m208a_x1;

assign n186_x2_n = ~n186_x2; // g184a
assign n186_x3_n = ~n186_x3; // n214b
assign u_select__m217b_y = ~n186_x2; // m217b
assign u_select__m211b_y = ~pin_test; // m211b

assign n186_x3t_n = ~u_select__m208a_x0; // j208a
assign n186_x2t_n = ~u_select__m208a_x1; // m211a
assign n186_x3t_buf_n = n186_x3t_n; // j181a
assign n186_x2t_buf_n = n186_x2t_n; // j182b
// End inlined jt054156_page06_n186_select u_select
// End inlined jt054156_page06_n186 u_n186

endmodule


// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054156_package.v
// -----------------------------------------------------------------------------

// Package-facing wrapper for the reconstructed 054156 digital schematic.
//
// The core reconstruction keeps DB and VD split into input/output buses plus
// pad-control rails. This wrapper maps those rails onto true bidirectional
// package pins. DB output-enable polarity is inferred active-low from the
// page-9 CPU-read gate equations. VD direction polarity is kept parameterized
// because the schematic shows internal direction nets but not the pad cell.
module jt054156_package #(
    parameter DB_OE_DRIVE_VALUE  = 1'b0,
    parameter VD_DIR_DRIVE_VALUE = 1'b0
)(
    input  wire        pin_clk,
    input  wire        pin_nres,
    input  wire [13:1] pin_ab,
    inout  wire [15:0] pin_db,
    inout  wire [23:0] pin_vd,

    input  wire        pin_nrcs,
    input  wire        pin_nccs,
    input  wire        pin_cram,
    input  wire        pin_dac,
    input  wire        pin_lds,
    input  wire        pin_uds,
    input  wire        pin_nrd,
    input  wire        pin_nvcs,
    input  wire        pin_test,
    input  wire        pin_enhs,
    input  wire        pin_envs,

    output wire        pin_dclk,
    output wire        pin_nhsy,
    output wire        pin_nhbl,
    output wire        pin_nvsy,
    output wire        pin_nvbl,
    output wire        pin_irq,
    output wire        pin_firq,
    output wire        pin_nmi,
    output wire        pin_s2h,
    output wire        pin_s4h,
    output wire        pin_z1h,
    output wire        pin_z2h,
    output wire        pin_z4h,

    output wire [16:0] pin_va,
    output wire        pin_oe0,
    output wire        pin_oe1,
    output wire        pin_oe2,
    output wire        pin_we0,
    output wire        pin_we1,
    output wire        pin_we2,
    output wire        pin_csz1,
    output wire        pin_cs1,
    output wire        pin_csz2,
    output wire        pin_cs2,
    output wire        pin_nre,
    output wire [18:0] pin_ca,
    output wire [7:0]  pin_col,
    output wire [1:0]  pin_vrc,
    output wire        pin_sz,
    output wire        pin_namp
);

wire [15:0] pin_db_in, pin_db_out;
wire [23:0] pin_vd_in, pin_vd_out;
wire        pin_db_l_oe, pin_db_u_oe;
wire        pin_vd_dir_low, pin_vd_dir_mid, pin_vd_dir_high;
wire [8:0]  hcnt, vcnt;
wire [8:3]  scrollx;
wire [10:0] scrolly;
wire [2:0]  pagey;

wire        db_l_drive = pin_db_l_oe == DB_OE_DRIVE_VALUE;
wire        db_u_drive = pin_db_u_oe == DB_OE_DRIVE_VALUE;
wire        vd_l_drive = pin_vd_dir_low  == VD_DIR_DRIVE_VALUE;
wire        vd_m_drive = pin_vd_dir_mid  == VD_DIR_DRIVE_VALUE;
wire        vd_h_drive = pin_vd_dir_high == VD_DIR_DRIVE_VALUE;

assign pin_db[ 7:0] = db_l_drive ? pin_db_out[ 7:0] : 8'hzz;
assign pin_db[15:8] = db_u_drive ? pin_db_out[15:8] : 8'hzz;
assign pin_db_in[ 7:0] = db_l_drive ? 8'h00 : pin_db[ 7:0];
assign pin_db_in[15:8] = db_u_drive ? 8'h00 : pin_db[15:8];

assign pin_vd[ 7:0]  = vd_l_drive ? pin_vd_out[ 7:0]  : 8'hzz;
assign pin_vd[15:8]  = vd_m_drive ? pin_vd_out[15:8]  : 8'hzz;
assign pin_vd[23:16] = vd_h_drive ? pin_vd_out[23:16] : 8'hzz;
assign pin_vd_in[ 7:0]  = vd_l_drive ? 8'h00 : pin_vd[ 7:0];
assign pin_vd_in[15:8]  = vd_m_drive ? 8'h00 : pin_vd[15:8];
assign pin_vd_in[23:16] = vd_h_drive ? 8'h00 : pin_vd[23:16];

jt054156_connected u_connected(
    .pin_clk         ( pin_clk         ),
    .pin_nres        ( pin_nres        ),
    .pin_ab          ( pin_ab          ),
    .pin_db_in       ( pin_db_in       ),
    .pin_vd_in       ( pin_vd_in       ),
    .pin_nrcs        ( pin_nrcs        ),
    .pin_nccs        ( pin_nccs        ),
    .pin_cram        ( pin_cram        ),
    .pin_dac         ( pin_dac         ),
    .pin_lds         ( pin_lds         ),
    .pin_uds         ( pin_uds         ),
    .pin_nrd         ( pin_nrd         ),
    .pin_nvcs        ( pin_nvcs        ),
    .pin_test        ( pin_test        ),
    .pin_enhs        ( pin_enhs        ),
    .pin_envs        ( pin_envs        ),
    .pin_dclk        ( pin_dclk        ),
    .pin_nhsy        ( pin_nhsy        ),
    .pin_nhbl        ( pin_nhbl        ),
    .pin_nvsy        ( pin_nvsy        ),
    .pin_nvbl        ( pin_nvbl        ),
    .pin_irq         ( pin_irq         ),
    .pin_firq        ( pin_firq        ),
    .pin_nmi         ( pin_nmi         ),
    .pin_s2h         ( pin_s2h         ),
    .pin_s4h         ( pin_s4h         ),
    .pin_z1h         ( pin_z1h         ),
    .pin_z2h         ( pin_z2h         ),
    .pin_z4h         ( pin_z4h         ),
    .pin_va          ( pin_va          ),
    .pin_vd_dir_low  ( pin_vd_dir_low  ),
    .pin_vd_dir_mid  ( pin_vd_dir_mid  ),
    .pin_vd_dir_high ( pin_vd_dir_high ),
    .pin_oe0         ( pin_oe0         ),
    .pin_oe1         ( pin_oe1         ),
    .pin_oe2         ( pin_oe2         ),
    .pin_we0         ( pin_we0         ),
    .pin_we1         ( pin_we1         ),
    .pin_we2         ( pin_we2         ),
    .pin_csz1        ( pin_csz1        ),
    .pin_cs1         ( pin_cs1         ),
    .pin_csz2        ( pin_csz2        ),
    .pin_cs2         ( pin_cs2         ),
    .pin_db_l_oe     ( pin_db_l_oe     ),
    .pin_db_u_oe     ( pin_db_u_oe     ),
    .pin_nre         ( pin_nre         ),
    .pin_db_out      ( pin_db_out      ),
    .pin_vd_out      ( pin_vd_out      ),
    .pin_ca          ( pin_ca          ),
    .pin_col         ( pin_col         ),
    .pin_vrc         ( pin_vrc         ),
    .pin_sz          ( pin_sz          ),
    .pin_namp        ( pin_namp        ),
    .hcnt            ( hcnt            ),
    .vcnt            ( vcnt            ),
    .scrollx         ( scrollx         ),
    .scrolly         ( scrolly         ),
    .pagey           ( pagey           )
);

endmodule


// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054156_page12_vd_capture.v
// -----------------------------------------------------------------------------

// Page-12 VD input capture and second/third VRAM-byte pair muxes.
//
// D43/C43/C56/B43/D31/B15 capture PIN_VD[23:0]_IN on N186_X0. C35 and B35
// select between the second and third captured VRAM bytes under REG6_DB4.
module jt054156_page12_vd_capture(
    input  wire        n186_x0,
    input  wire        reg6_db4,
    input  wire [23:0] pin_vd_in,
    output wire [23:0] vd_reg,
    output wire        c13b_y,
    output wire        vd_reg_10_18,
    output wire        vd_reg_8_16,
    output wire        vd_reg_11_19,
    output wire        vd_reg_9_17,
    output wire        vd_reg_14_22,
    output wire        vd_reg_12_20,
    output wire        vd_reg_15_23,
    output wire        vd_reg_13_21
);

reg [3:0] d43_q, c43_q, c56_q, b43_q, d31_q, b15_q;
assign vd_reg[ 3: 0] = d43_q;
assign vd_reg[ 7: 4] = c43_q;
assign vd_reg[11: 8] = c56_q;
assign vd_reg[15:12] = b43_q;
assign vd_reg[19:16] = d31_q;
assign vd_reg[23:20] = b15_q;

always @(posedge n186_x0) begin
    {d43_q,c43_q,c56_q,b43_q,d31_q,b15_q} <= {pin_vd_in[3:0],pin_vd_in[7:4],pin_vd_in[11:8],pin_vd_in[15:12],pin_vd_in[19:16],pin_vd_in[23:20]}; // d43, c43, c56, b43, d31, b15
end
assign c13b_y = ~reg6_db4; // c13b
assign vd_reg_10_18 = reg6_db4 ? c56_q[2] : d31_q[2]; // c35
assign vd_reg_8_16 = reg6_db4 ? c56_q[0] : d31_q[0]; // c35
assign vd_reg_11_19 = reg6_db4 ? c56_q[3] : d31_q[3]; // c35
assign vd_reg_9_17 = reg6_db4 ? c56_q[1] : d31_q[1]; // c35
assign vd_reg_14_22 = reg6_db4 ? b43_q[2] : b15_q[2]; // b35
assign vd_reg_12_20 = reg6_db4 ? b43_q[0] : b15_q[0]; // b35
assign vd_reg_15_23 = reg6_db4 ? b43_q[3] : b15_q[3]; // b35
assign vd_reg_13_21 = reg6_db4 ? b43_q[1] : b15_q[1]; // b35
endmodule
// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054156_reset_source.v
// -----------------------------------------------------------------------------

// Reset distributor around page-6 P183 and page-2 RESET16/RESET17 buffers.

module jt054156_reset_source(
    input  wire pin_clk,
    input  wire pin_nres,

    output wire reset1_n,
    output wire reset2_n,
    output wire reset3_n,
    output wire reset4_n,
    output wire reset5_n,
    output wire reset6_n,
    output wire reset7_n,
    output wire reset8_n,
    output wire reset9_n,
    output wire reset10_n,
    output wire reset11_n,
    output wire reset12_n,
    output wire reset13_n,
    output wire reset14_n,
    output wire reset15_n,
    output wire reset16_n,
    output wire reset17_n,
    output wire reset18_n,
    output wire reset19_n,
    output wire reset20_n,
    output reg reset_root
);

wire    p169b_y, r113a_y, k156b_y, j108a_y, a78b_y;
wire    tied_high = 1'b1;
always @(posedge pin_clk or negedge pin_nres) begin
    if (!pin_nres) begin
        reset_root <= 1'b0;
    end else begin
        reset_root <= tied_high;
    end
end // p183
assign reset19_n = reset_root; // p166a
assign p169b_y = reset_root; // p169b
assign r113a_y = p169b_y; // r113a
assign reset11_n = r113a_y; // r117a
assign reset10_n = r113a_y; // n75b
assign reset15_n = r113a_y;

assign k156b_y = reset_root; // k156b
assign reset9_n = k156b_y; // k162b
assign reset8_n = k156b_y; // k162a
assign reset12_n = k156b_y; // k155b
assign reset14_n = k156b_y; // j156a
assign reset13_n = k156b_y;

assign j108a_y = reset_root; // j108a
assign reset7_n = j108a_y; // j40a
assign reset20_n = j108a_y;

assign a78b_y = reset_root; // a78b
assign reset18_n = a78b_y; // a79b
assign reset4_n = a78b_y;

assign reset1_n = reset_root; // r131b
assign reset3_n = reset_root; // a77b
assign reset2_n = reset_root; // l189a
assign reset5_n = reset_root; // a78a
assign reset6_n = reset_root; // h78a
// Page 2 local reset buffers.
assign reset17_n = reset5_n; // a77a
assign reset16_n = reset4_n; // a76a
endmodule
// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054156_scroll_timing_ctrl.v
// -----------------------------------------------------------------------------

// Connected scroll timing fragment tying page-5 START/SIZE muxes into the
// page-7 horizontal and page-8 vertical scroll paths.
module jt054156_scroll_timing_ctrl(
    input  wire        pin_dclk,
    input  wire [8:2]  hcnt,
    input  wire        hcnt0,
    input  wire        hcnt2,
    input  wire        p140_xq,
    input  wire        pin_nhsy,
    input  wire        reset20_n,
    input  wire        pin_test,
    input  wire [8:0]  vcnt,
    input  wire [23:0] pin_vd_in,
    input  wire        tick_a,
    input  wire        tick_b,
    input  wire        tick_c,
    input  wire        tick_d,
    input  wire        reg0_db0,
    input  wire        reg0_db4,
    input  wire        reg0_db5,
    input  wire [7:4]  reg8_db,
    input  wire [7:0]  rega_db,
    input  wire [5:0]  reg10_d,
    input  wire [5:0]  reg12_d,
    input  wire [5:0]  reg14_d,
    input  wire [5:0]  reg16_d,
    input  wire [5:0]  reg18_d,
    input  wire [5:0]  reg1a_d,
    input  wire [5:0]  reg1c_d,
    input  wire [5:0]  reg1e_d,
    input  wire [10:0] reg20_d,
    input  wire [10:0] reg22_d,
    input  wire [10:0] reg24_d,
    input  wire [10:0] reg26_d,
    input  wire [11:0] reg28_d,
    input  wire [11:0] reg2a_d,
    input  wire [11:0] reg2c_d,
    input  wire [11:0] reg2e_d,
    input  wire [7:0]  reg3al_d,
    input  wire [11:8] reg3au_d,
    input  wire [10:0] reg3cl_d,
    input  wire        n186_x2t_n,
    input  wire        n186_x3t_n,
    input  wire        n186_x2t_buf_n,
    input  wire        n186_x3t_buf_n,
    output wire [8:3]  scrollx,
    output wire [10:0] scrolly,
    output wire [2:0]  hs_mux,
    output wire [2:0]  hb_mux,
    output wire [2:0]  vs_mux,
    output wire [2:0]  vb_mux,
    output wire [2:0]  hsize_mux,
    output wire [2:0]  vsize_mux,
    output wire [2:0]  pagex,
    output wire [2:0]  pagey,
    output wire        pin_z1h,
    output wire        pin_z2h,
    output wire        pin_z4h,
    output wire        pin_sz,
    output wire        scrolly_en_mux,
    output wire        n186_x2t_buf2_n,
    output wire        n186_x2t_buf2,
    output wire        n186_x3t_buf2_n,
    output wire        n186_x3t_buf2,
    output wire        n186_x2t_buf3_n,
    output wire        n186_x2t_buf3,
    output wire        n186_x3t_buf3_n,
    output wire        n186_x3t_buf3
);

wire [2:0]  page5_hs_mux, page5_vs_mux;
wire [11:0] src_a, src_b, src_c, src_d;
wire [11:0] line_a, line_b, line_c, line_d, hofs;
wire [11:3] ha, hb, hc, hd, hmux, hmux_x;
wire [10:0] scrolly_mux, reg3cl_gated, yofs_scan, layer_scroll;
wire [8:0]  vcnt_phase;
wire [8:2]  hcnt_phase;
wire [2:0]  ha_pre, hb_pre, hc_pre, hd_pre;
wire [2:0]  ha_low, hb_low, hc_low, hd_low;

assign hsize_mux    = page5_hs_mux;
assign vsize_mux    = page5_vs_mux;
// Inlined jt054156_page05_start_size_mux u_start_size
wire u_start_size__m189a_y_n, u_start_size__m189b_y, u_start_size__m164a_y_n, u_start_size__m188b_y;
wire u_start_size__c210_x, u_start_size__c212a_x, u_start_size__c203a_x, u_start_size__c201_x, u_start_size__c187a_x, u_start_size__c198a_x;
wire u_start_size__m185_x, u_start_size__m182a_x, u_start_size__l115a_x, u_start_size__l120a_x, u_start_size__l123_x, u_start_size__l118_x;

assign n186_x3t_buf2_n = n186_x3t_n; // b214a
assign n186_x3t_buf2 = ~n186_x3t_n; // a214b
assign n186_x2t_buf2_n = n186_x2t_n; // a200b
assign n186_x2t_buf2 = ~n186_x2t_n; // a213a
assign u_start_size__m189a_y_n = n186_x2t_buf_n; // m189a
assign u_start_size__m189b_y = ~n186_x2t_buf_n; // m189b
assign u_start_size__m164a_y_n = n186_x3t_buf_n; // m164a
assign u_start_size__m188b_y = ~n186_x3t_buf_n; // m188b
assign n186_x3t_buf3_n = n186_x3t_buf_n; // l159b
assign n186_x3t_buf3 = ~n186_x3t_buf_n; // l160b
assign n186_x2t_buf3_n = n186_x2t_buf_n; // l162b
assign n186_x2t_buf3 = ~n186_x2t_buf_n; // l161b
jt054156_t5a u_c210(
    .a1 ( reg18_d[5]       ),
    .a2 ( reg1a_d[5]       ),
    .s1 ( n186_x2t_buf2_n ),
    .s2 ( n186_x2t_buf2   ),
    .s5 ( n186_x3t_buf2_n ),
    .s6 ( n186_x3t_buf2   ),
    .s3 ( n186_x2t_buf2_n ),
    .s4 ( n186_x2t_buf2   ),
    .b1 ( reg1c_d[5]       ),
    .b2 ( reg1e_d[5]       ),
    .x  ( u_start_size__c210_x           )
);

assign page5_hs_mux[2] = ~u_start_size__c210_x; // b211b
jt054156_t5a u_c212a(
    .a1 ( reg18_d[4]       ),
    .a2 ( reg1a_d[4]       ),
    .s1 ( n186_x2t_buf2_n ),
    .s2 ( n186_x2t_buf2   ),
    .s5 ( n186_x3t_buf2_n ),
    .s6 ( n186_x3t_buf2   ),
    .s3 ( n186_x2t_buf2_n ),
    .s4 ( n186_x2t_buf2   ),
    .b1 ( reg1c_d[4]       ),
    .b2 ( reg1e_d[4]       ),
    .x  ( u_start_size__c212a_x          )
);

assign page5_hs_mux[1] = ~u_start_size__c212a_x; // b211a
jt054156_t5a u_c203a(
    .a1 ( reg18_d[3]       ),
    .a2 ( reg1a_d[3]       ),
    .s1 ( n186_x2t_buf2_n ),
    .s2 ( n186_x2t_buf2   ),
    .s5 ( n186_x3t_buf2_n ),
    .s6 ( n186_x3t_buf2   ),
    .s3 ( n186_x2t_buf2_n ),
    .s4 ( n186_x2t_buf2   ),
    .b1 ( reg1c_d[3]       ),
    .b2 ( reg1e_d[3]       ),
    .x  ( u_start_size__c203a_x          )
);

assign page5_hs_mux[0] = ~u_start_size__c203a_x; // b210a
jt054156_t5a u_c201(
    .a1 ( reg18_d[2]       ),
    .a2 ( reg1a_d[2]       ),
    .s1 ( n186_x2t_buf2_n ),
    .s2 ( n186_x2t_buf2   ),
    .s5 ( n186_x3t_buf2_n ),
    .s6 ( n186_x3t_buf2   ),
    .s3 ( n186_x2t_buf2_n ),
    .s4 ( n186_x2t_buf2   ),
    .b1 ( reg1c_d[2]       ),
    .b2 ( reg1e_d[2]       ),
    .x  ( u_start_size__c201_x           )
);

assign hb_mux[2] = ~u_start_size__c201_x; // b205a
jt054156_t5a u_c187a(
    .a1 ( reg18_d[1]       ),
    .a2 ( reg1a_d[1]       ),
    .s1 ( n186_x2t_buf2_n ),
    .s2 ( n186_x2t_buf2   ),
    .s5 ( n186_x3t_buf2_n ),
    .s6 ( n186_x3t_buf2   ),
    .s3 ( n186_x2t_buf2_n ),
    .s4 ( n186_x2t_buf2   ),
    .b1 ( reg1c_d[1]       ),
    .b2 ( reg1e_d[1]       ),
    .x  ( u_start_size__c187a_x          )
);

assign hb_mux[1] = ~u_start_size__c187a_x; // b71b
jt054156_t5a u_c198a(
    .a1 ( reg18_d[0]       ),
    .a2 ( reg1a_d[0]       ),
    .s1 ( n186_x2t_buf2_n ),
    .s2 ( n186_x2t_buf2   ),
    .s5 ( n186_x3t_buf2_n ),
    .s6 ( n186_x3t_buf2   ),
    .s3 ( n186_x2t_buf2_n ),
    .s4 ( n186_x2t_buf2   ),
    .b1 ( reg1c_d[0]       ),
    .b2 ( reg1e_d[0]       ),
    .x  ( u_start_size__c198a_x          )
);

assign hb_mux[0] = ~u_start_size__c198a_x; // b69a
jt054156_t5a u_m185(
    .a1 ( reg10_d[5] ),
    .a2 ( reg12_d[5] ),
    .s1 ( u_start_size__m189a_y_n  ),
    .s2 ( u_start_size__m189b_y    ),
    .s5 ( u_start_size__m164a_y_n  ),
    .s6 ( u_start_size__m188b_y    ),
    .s3 ( u_start_size__m189a_y_n  ),
    .s4 ( u_start_size__m189b_y    ),
    .b1 ( reg14_d[5] ),
    .b2 ( reg16_d[5] ),
    .x  ( u_start_size__m185_x     )
);

assign page5_vs_mux[2] = ~u_start_size__m185_x; // m204a
jt054156_t5a u_m182a(
    .a1 ( reg10_d[4] ),
    .a2 ( reg12_d[4] ),
    .s1 ( u_start_size__m189a_y_n  ),
    .s2 ( u_start_size__m189b_y    ),
    .s5 ( u_start_size__m164a_y_n  ),
    .s6 ( u_start_size__m188b_y    ),
    .s3 ( u_start_size__m189a_y_n  ),
    .s4 ( u_start_size__m189b_y    ),
    .b1 ( reg14_d[4] ),
    .b2 ( reg16_d[4] ),
    .x  ( u_start_size__m182a_x    )
);

assign page5_vs_mux[1] = ~u_start_size__m182a_x; // m205b
jt054156_t5a u_l115a(
    .a1 ( reg10_d[3]       ),
    .a2 ( reg12_d[3]       ),
    .s1 ( n186_x2t_buf3_n ),
    .s2 ( n186_x2t_buf3   ),
    .s5 ( n186_x3t_buf3_n ),
    .s6 ( n186_x3t_buf3   ),
    .s3 ( n186_x2t_buf3_n ),
    .s4 ( n186_x2t_buf3   ),
    .b1 ( reg14_d[3]       ),
    .b2 ( reg16_d[3]       ),
    .x  ( u_start_size__l115a_x          )
);

assign page5_vs_mux[0] = ~u_start_size__l115a_x; // k126b
jt054156_t5a u_l120a(
    .a1 ( reg10_d[2]       ),
    .a2 ( reg12_d[2]       ),
    .s1 ( n186_x2t_buf3_n ),
    .s2 ( n186_x2t_buf3   ),
    .s5 ( n186_x3t_buf3_n ),
    .s6 ( n186_x3t_buf3   ),
    .s3 ( n186_x2t_buf3_n ),
    .s4 ( n186_x2t_buf3   ),
    .b1 ( reg14_d[2]       ),
    .b2 ( reg16_d[2]       ),
    .x  ( u_start_size__l120a_x          )
);

assign vb_mux[2] = ~u_start_size__l120a_x; // l162a
jt054156_t5a u_l123(
    .a1 ( reg10_d[1]       ),
    .a2 ( reg12_d[1]       ),
    .s1 ( n186_x2t_buf3_n ),
    .s2 ( n186_x2t_buf3   ),
    .s5 ( n186_x3t_buf3_n ),
    .s6 ( n186_x3t_buf3   ),
    .s3 ( n186_x2t_buf3_n ),
    .s4 ( n186_x2t_buf3   ),
    .b1 ( reg14_d[1]       ),
    .b2 ( reg16_d[1]       ),
    .x  ( u_start_size__l123_x           )
);

assign vb_mux[1] = ~u_start_size__l123_x; // l161a
jt054156_t5a u_l118(
    .a1 ( reg10_d[0]       ),
    .a2 ( reg12_d[0]       ),
    .s1 ( n186_x2t_buf3_n ),
    .s2 ( n186_x2t_buf3   ),
    .s5 ( n186_x3t_buf3_n ),
    .s6 ( n186_x3t_buf3   ),
    .s3 ( n186_x2t_buf3_n ),
    .s4 ( n186_x2t_buf3   ),
    .b1 ( reg14_d[0]       ),
    .b2 ( reg16_d[0]       ),
    .x  ( u_start_size__l118_x           )
);

assign vb_mux[0] = ~u_start_size__l118_x; // l160a
// End inlined jt054156_page05_start_size_mux u_start_size

// Inlined jt054156_page07_hscroll u_hscroll
wire u_hscroll__unused_hofs_g172a_y;
wire u_hscroll__unused_hofs_g162a_y;
wire u_hscroll__unused_xsrc_e110_y;
wire u_hscroll__unused_xsrc_d110a_y;
wire u_hscroll__unused_xsrc_d164a_y;
wire u_hscroll__unused_xsrc_e162_y;
wire u_hscroll__unused_n169a_y;
wire u_hscroll__unused_g84_co;
wire u_hscroll__unused_f84_s3;
wire u_hscroll__unused_f84_s4;
wire u_hscroll__unused_f84_co;
wire u_hscroll__unused_f191_s;
wire u_hscroll__unused_zout_dclk_n;
wire [2:0] u_hscroll__unused_zout_mux_x;
wire [2:0] u_hscroll__unused_zout_mux;
wire u_hscroll__c125a_y, u_hscroll__c126b_y, u_hscroll__c126a_y, u_hscroll__c162a_y;

assign u_hscroll__c125a_y = n186_x3t_buf2_n; // c125a
assign u_hscroll__c126b_y = ~n186_x3t_buf2_n; // c126b
assign u_hscroll__c126a_y = n186_x2t_buf2_n; // c126a
assign u_hscroll__c162a_y = ~n186_x2t_buf2_n; // c162a
// Inlined jt054156_page07_xsrc u_xsrc
wire [3:0] u_xsrc__vd_low_d  = { pin_vd_in[3], pin_vd_in[2], pin_vd_in[1], pin_vd_in[0]  };
wire [3:0] u_xsrc__vd_mid_d  = { pin_vd_in[7], pin_vd_in[6], pin_vd_in[5], pin_vd_in[4]  };
wire [3:0] u_xsrc__vd_high_d = { pin_vd_in[19], pin_vd_in[18], pin_vd_in[17], pin_vd_in[16] };
reg [3:0] u_xsrc__e111_q, u_xsrc__c113_q, u_xsrc__d92_q;
reg [3:0] u_xsrc__d111_q, u_xsrc__a113_q, u_xsrc__e88_q;
reg [3:0] u_xsrc__d135_q, u_xsrc__a190_q, u_xsrc__d64_q;
reg [3:0] u_xsrc__g141_q, u_xsrc__a180_q, u_xsrc__e98_q;
wire [3:0] u_xsrc__e129_x, u_xsrc__c135_x, u_xsrc__d102_x;
wire [3:0] u_xsrc__d129_x, u_xsrc__b117_x, u_xsrc__d80_x;
wire [3:0] u_xsrc__d145_x, u_xsrc__b163_x, u_xsrc__d74_x;
wire [3:0] u_xsrc__f151_x, u_xsrc__b169_x, u_xsrc__d86_x;
assign line_a = { u_xsrc__d92_q[3:0], u_xsrc__c113_q[3:0], u_xsrc__e111_q[3:0] };
assign line_b = { u_xsrc__e88_q[3:0], u_xsrc__a113_q[3:0], u_xsrc__d111_q[3:0] };
assign line_c = { u_xsrc__d64_q[3:0], u_xsrc__a190_q[3:0], u_xsrc__d135_q[3:0] };
assign line_d = { u_xsrc__e98_q[3:0], u_xsrc__a180_q[3:0], u_xsrc__g141_q[3:0] };

assign src_a[3:0]  = { u_xsrc__e129_x[1], u_xsrc__e129_x[3], u_xsrc__e129_x[0], u_xsrc__e129_x[2] };
assign src_a[7:4]  = { u_xsrc__c135_x[1], u_xsrc__c135_x[3], u_xsrc__c135_x[0], u_xsrc__c135_x[2] };
assign src_a[11:8] = { u_xsrc__d102_x[1], u_xsrc__d102_x[3], u_xsrc__d102_x[0], u_xsrc__d102_x[2] };

assign src_b[3:0]  = { u_xsrc__d129_x[1], u_xsrc__d129_x[3], u_xsrc__d129_x[0], u_xsrc__d129_x[2] };
assign src_b[7:4]  = { u_xsrc__b117_x[1], u_xsrc__b117_x[3], u_xsrc__b117_x[0], u_xsrc__b117_x[2] };
assign src_b[11:8] = { u_xsrc__d80_x[1],  u_xsrc__d80_x[3],  u_xsrc__d80_x[0],  u_xsrc__d80_x[2]  };

assign src_c[3:0]  = { u_xsrc__d145_x[1], u_xsrc__d145_x[3], u_xsrc__d145_x[0], u_xsrc__d145_x[2] };
assign src_c[7:4]  = { u_xsrc__b163_x[1], u_xsrc__b163_x[3], u_xsrc__b163_x[0], u_xsrc__b163_x[2] };
assign src_c[11:8] = { u_xsrc__d74_x[1],  u_xsrc__d74_x[3],  u_xsrc__d74_x[0],  u_xsrc__d74_x[2]  };

assign src_d[3:0]  = { u_xsrc__f151_x[1], u_xsrc__f151_x[3], u_xsrc__f151_x[0], u_xsrc__f151_x[2] };
assign src_d[7:4]  = { u_xsrc__b169_x[1], u_xsrc__b169_x[3], u_xsrc__b169_x[0], u_xsrc__b169_x[2] };
assign src_d[11:8] = { u_xsrc__d86_x[1],  u_xsrc__d86_x[3],  u_xsrc__d86_x[0],  u_xsrc__d86_x[2]  };

assign u_hscroll__unused_xsrc_e110_y = ~rega_db[0]; // e110
assign u_hscroll__unused_xsrc_d110a_y = ~rega_db[2]; // d110a
assign u_hscroll__unused_xsrc_d164a_y = ~rega_db[4]; // d164a
assign u_hscroll__unused_xsrc_e162_y = ~rega_db[6]; // e162
always @(posedge tick_a) begin
    {u_xsrc__e111_q,u_xsrc__c113_q,u_xsrc__d92_q} <= {u_xsrc__vd_low_d,u_xsrc__vd_mid_d,u_xsrc__vd_high_d}; // e111, c113, d92
end
always @(posedge tick_b) begin
    {u_xsrc__d111_q,u_xsrc__a113_q,u_xsrc__e88_q} <= {u_xsrc__vd_low_d,u_xsrc__vd_mid_d,u_xsrc__vd_high_d}; // d111, a113, e88
end
always @(posedge tick_c) begin
    {u_xsrc__d135_q,u_xsrc__a190_q,u_xsrc__d64_q} <= {u_xsrc__vd_low_d,u_xsrc__vd_mid_d,u_xsrc__vd_high_d}; // d135, a190, d64
end
always @(posedge tick_d) begin
    {u_xsrc__g141_q,u_xsrc__a180_q,u_xsrc__e98_q} <= {u_xsrc__vd_low_d,u_xsrc__vd_mid_d,u_xsrc__vd_high_d}; // g141, a180, e98
end
assign u_xsrc__e129_x[0] = rega_db[0] ? reg28_d[1] : u_xsrc__e111_q[1]; // e129
assign u_xsrc__e129_x[1] = rega_db[0] ? reg28_d[3] : u_xsrc__e111_q[3]; // e129
assign u_xsrc__e129_x[2] = rega_db[0] ? reg28_d[0] : u_xsrc__e111_q[0]; // e129
assign u_xsrc__e129_x[3] = rega_db[0] ? reg28_d[2] : u_xsrc__e111_q[2]; // e129
assign u_xsrc__c135_x[0] = rega_db[0] ? reg28_d[5] : u_xsrc__c113_q[1]; // c135
assign u_xsrc__c135_x[1] = rega_db[0] ? reg28_d[7] : u_xsrc__c113_q[3]; // c135
assign u_xsrc__c135_x[2] = rega_db[0] ? reg28_d[4] : u_xsrc__c113_q[0]; // c135
assign u_xsrc__c135_x[3] = rega_db[0] ? reg28_d[6] : u_xsrc__c113_q[2]; // c135
assign u_xsrc__d102_x[0] = rega_db[0] ? reg28_d[9] : u_xsrc__d92_q[1]; // d102
assign u_xsrc__d102_x[1] = rega_db[0] ? reg28_d[11] : u_xsrc__d92_q[3]; // d102
assign u_xsrc__d102_x[2] = rega_db[0] ? reg28_d[8] : u_xsrc__d92_q[0]; // d102
assign u_xsrc__d102_x[3] = rega_db[0] ? reg28_d[10] : u_xsrc__d92_q[2]; // d102
assign u_xsrc__d129_x[0] = rega_db[2] ? reg2a_d[1] : u_xsrc__d111_q[1]; // d129
assign u_xsrc__d129_x[1] = rega_db[2] ? reg2a_d[3] : u_xsrc__d111_q[3]; // d129
assign u_xsrc__d129_x[2] = rega_db[2] ? reg2a_d[0] : u_xsrc__d111_q[0]; // d129
assign u_xsrc__d129_x[3] = rega_db[2] ? reg2a_d[2] : u_xsrc__d111_q[2]; // d129
assign u_xsrc__b117_x[0] = rega_db[2] ? reg2a_d[5] : u_xsrc__a113_q[1]; // b117
assign u_xsrc__b117_x[1] = rega_db[2] ? reg2a_d[7] : u_xsrc__a113_q[3]; // b117
assign u_xsrc__b117_x[2] = rega_db[2] ? reg2a_d[4] : u_xsrc__a113_q[0]; // b117
assign u_xsrc__b117_x[3] = rega_db[2] ? reg2a_d[6] : u_xsrc__a113_q[2]; // b117
assign u_xsrc__d80_x[0] = rega_db[2] ? reg2a_d[9] : u_xsrc__e88_q[1]; // d80
assign u_xsrc__d80_x[1] = rega_db[2] ? reg2a_d[11] : u_xsrc__e88_q[3]; // d80
assign u_xsrc__d80_x[2] = rega_db[2] ? reg2a_d[8] : u_xsrc__e88_q[0]; // d80
assign u_xsrc__d80_x[3] = rega_db[2] ? reg2a_d[10] : u_xsrc__e88_q[2]; // d80
assign u_xsrc__d145_x[0] = rega_db[4] ? reg2c_d[1] : u_xsrc__d135_q[1]; // d145
assign u_xsrc__d145_x[1] = rega_db[4] ? reg2c_d[3] : u_xsrc__d135_q[3]; // d145
assign u_xsrc__d145_x[2] = rega_db[4] ? reg2c_d[0] : u_xsrc__d135_q[0]; // d145
assign u_xsrc__d145_x[3] = rega_db[4] ? reg2c_d[2] : u_xsrc__d135_q[2]; // d145
assign u_xsrc__b163_x[0] = rega_db[4] ? reg2c_d[5] : u_xsrc__a190_q[1]; // b163
assign u_xsrc__b163_x[1] = rega_db[4] ? reg2c_d[7] : u_xsrc__a190_q[3]; // b163
assign u_xsrc__b163_x[2] = rega_db[4] ? reg2c_d[4] : u_xsrc__a190_q[0]; // b163
assign u_xsrc__b163_x[3] = rega_db[4] ? reg2c_d[6] : u_xsrc__a190_q[2]; // b163
assign u_xsrc__d74_x[0] = rega_db[4] ? reg2c_d[9] : u_xsrc__d64_q[1]; // d74
assign u_xsrc__d74_x[1] = rega_db[4] ? reg2c_d[11] : u_xsrc__d64_q[3]; // d74
assign u_xsrc__d74_x[2] = rega_db[4] ? reg2c_d[8] : u_xsrc__d64_q[0]; // d74
assign u_xsrc__d74_x[3] = rega_db[4] ? reg2c_d[10] : u_xsrc__d64_q[2]; // d74
assign u_xsrc__f151_x[0] = rega_db[6] ? reg2e_d[1] : u_xsrc__g141_q[1]; // f151
assign u_xsrc__f151_x[1] = rega_db[6] ? reg2e_d[3] : u_xsrc__g141_q[3]; // f151
assign u_xsrc__f151_x[2] = rega_db[6] ? reg2e_d[0] : u_xsrc__g141_q[0]; // f151
assign u_xsrc__f151_x[3] = rega_db[6] ? reg2e_d[2] : u_xsrc__g141_q[2]; // f151
assign u_xsrc__b169_x[0] = rega_db[6] ? reg2e_d[5] : u_xsrc__a180_q[1]; // b169
assign u_xsrc__b169_x[1] = rega_db[6] ? reg2e_d[7] : u_xsrc__a180_q[3]; // b169
assign u_xsrc__b169_x[2] = rega_db[6] ? reg2e_d[4] : u_xsrc__a180_q[0]; // b169
assign u_xsrc__b169_x[3] = rega_db[6] ? reg2e_d[6] : u_xsrc__a180_q[2]; // b169
assign u_xsrc__d86_x[0] = rega_db[6] ? reg2e_d[9] : u_xsrc__e98_q[1]; // d86
assign u_xsrc__d86_x[1] = rega_db[6] ? reg2e_d[11] : u_xsrc__e98_q[3]; // d86
assign u_xsrc__d86_x[2] = rega_db[6] ? reg2e_d[8] : u_xsrc__e98_q[0]; // d86
assign u_xsrc__d86_x[3] = rega_db[6] ? reg2e_d[10] : u_xsrc__e98_q[2]; // d86
// End inlined jt054156_page07_xsrc u_xsrc

// Inlined jt054156_page07_hofs u_hofs
wire u_hofs__gnd = 1'b0;

assign u_hscroll__unused_hofs_g172a_y = reg0_db4; // g172a
assign u_hscroll__unused_hofs_g162a_y = ~u_hscroll__unused_hofs_g172a_y; // g162a
assign hofs[10] = u_hscroll__unused_hofs_g172a_y ? reg3au_d[10] : u_hofs__gnd; // f72
assign hofs[8] = u_hscroll__unused_hofs_g172a_y ? reg3au_d[8] : u_hofs__gnd; // f72
assign hofs[11] = u_hscroll__unused_hofs_g172a_y ? reg3au_d[11] : u_hofs__gnd; // f72
assign hofs[9] = u_hscroll__unused_hofs_g172a_y ? reg3au_d[9] : u_hofs__gnd; // f72
assign hofs[6] = u_hscroll__unused_hofs_g172a_y ? reg3al_d[6] : u_hofs__gnd; // f157
assign hofs[4] = u_hscroll__unused_hofs_g172a_y ? reg3al_d[4] : u_hofs__gnd; // f157
assign hofs[7] = u_hscroll__unused_hofs_g172a_y ? reg3al_d[7] : u_hofs__gnd; // f157
assign hofs[5] = u_hscroll__unused_hofs_g172a_y ? reg3al_d[5] : u_hofs__gnd; // f157
assign hofs[2] = u_hscroll__unused_hofs_g172a_y ? reg3al_d[2] : u_hofs__gnd; // e163
assign hofs[0] = u_hscroll__unused_hofs_g172a_y ? reg3al_d[0] : u_hofs__gnd; // e163
assign hofs[3] = u_hscroll__unused_hofs_g172a_y ? reg3al_d[3] : u_hofs__gnd; // e163
assign hofs[1] = u_hscroll__unused_hofs_g172a_y ? reg3al_d[1] : u_hofs__gnd; // e163
// End inlined jt054156_page07_hofs u_hofs

// Inlined jt054156_page07_hadd u_hadd
wire u_hadd__gnd = 1'b0;

wire [1:0] u_hadd__e190_s, u_hadd__e143_s, u_hadd__c154_s, u_hadd__a135_s, u_hadd__c92_s;
wire [1:0] u_hadd__d165_s, u_hadd__d155_s, u_hadd__b135_s, u_hadd__b127_s, u_hadd__c100_s;
wire [1:0] u_hadd__d190_s, u_hadd__e154_s, u_hadd__a143_s, u_hadd__b143_s, u_hadd__c84_s;
wire [1:0] u_hadd__f167_s, u_hadd__f143_s, u_hadd__b155_s, u_hadd__a164_s, u_hadd__b100_s;
wire       u_hadd__e190_co, u_hadd__e143_co, u_hadd__c154_co, u_hadd__a135_co, u_hadd__c92_co;
wire       u_hadd__d165_co, u_hadd__d155_co, u_hadd__b135_co, u_hadd__b127_co, u_hadd__c100_co;
wire       u_hadd__d190_co, u_hadd__e154_co, u_hadd__a143_co, u_hadd__b143_co, u_hadd__c84_co;
wire       u_hadd__f167_co, u_hadd__f143_co, u_hadd__b155_co, u_hadd__a164_co, u_hadd__b100_co;

assign ha_pre = { u_hadd__e143_s[0], u_hadd__e190_s };
assign hb_pre = { u_hadd__d155_s[0], u_hadd__d165_s };
assign hc_pre = { u_hadd__e154_s[0], u_hadd__d190_s };
assign hd_pre = { u_hadd__f143_s[0], u_hadd__f167_s };

assign ha[3] = u_hadd__e143_s[1];
assign hb[3] = u_hadd__d155_s[1];
assign hc[3] = u_hadd__e154_s[1];
assign hd[3] = u_hadd__f143_s[1];

assign { u_hadd__e190_co, u_hadd__e190_s } = { 1'b0, src_a[1:0] } + { 1'b0, hofs[1:0] } + { 2'b0, u_hadd__gnd }; // e190
assign { u_hadd__e143_co, u_hadd__e143_s } = { 1'b0, src_a[3:2] } + { 1'b0, hofs[3:2] } + { 2'b0, u_hadd__e190_co }; // e143
assign { u_hadd__c154_co, u_hadd__c154_s } = { 1'b0, src_a[5:4] } + { 1'b0, hofs[5:4] } + { 2'b0, u_hadd__e143_co }; // c154
assign ha[5:4] = u_hadd__c154_s;

assign { u_hadd__a135_co, u_hadd__a135_s } = { 1'b0, src_a[7:6] } + { 1'b0, hofs[7:6] } + { 2'b0, u_hadd__c154_co }; // a135
assign ha[7:6] = u_hadd__a135_s;

assign { u_hadd__c92_co, u_hadd__c92_s } = { 1'b0, src_a[9:8] } + { 1'b0, hofs[9:8] } + { 2'b0, u_hadd__a135_co }; // c92
assign ha[9:8] = u_hadd__c92_s;

assign ha[11:10] = src_a[11:10] + hofs[11:10] + { 1'b0, u_hadd__c92_co }; // b92
assign { u_hadd__d165_co, u_hadd__d165_s } = { 1'b0, src_b[1:0] } + { 1'b0, hofs[1:0] } + { 2'b0, u_hadd__gnd }; // d165
assign { u_hadd__d155_co, u_hadd__d155_s } = { 1'b0, src_b[3:2] } + { 1'b0, hofs[3:2] } + { 2'b0, u_hadd__d165_co }; // d155
assign { u_hadd__b135_co, u_hadd__b135_s } = { 1'b0, src_b[5:4] } + { 1'b0, hofs[5:4] } + { 2'b0, u_hadd__d155_co }; // b135
assign hb[5:4] = u_hadd__b135_s;

assign { u_hadd__b127_co, u_hadd__b127_s } = { 1'b0, src_b[7:6] } + { 1'b0, hofs[7:6] } + { 2'b0, u_hadd__b135_co }; // b127
assign hb[7:6] = u_hadd__b127_s;

assign { u_hadd__c100_co, u_hadd__c100_s } = { 1'b0, src_b[9:8] } + { 1'b0, hofs[9:8] } + { 2'b0, u_hadd__b127_co }; // c100
assign hb[9:8] = u_hadd__c100_s;

assign hb[11:10] = src_b[11:10] + hofs[11:10] + { 1'b0, u_hadd__c100_co }; // b84
assign { u_hadd__d190_co, u_hadd__d190_s } = { 1'b0, src_c[1:0] } + { 1'b0, hofs[1:0] } + { 2'b0, u_hadd__gnd }; // d190
assign { u_hadd__e154_co, u_hadd__e154_s } = { 1'b0, src_c[3:2] } + { 1'b0, hofs[3:2] } + { 2'b0, u_hadd__d190_co }; // e154
assign { u_hadd__a143_co, u_hadd__a143_s } = { 1'b0, src_c[5:4] } + { 1'b0, hofs[5:4] } + { 2'b0, u_hadd__e154_co }; // a143
assign hc[5:4] = u_hadd__a143_s;

assign { u_hadd__b143_co, u_hadd__b143_s } = { 1'b0, src_c[7:6] } + { 1'b0, hofs[7:6] } + { 2'b0, u_hadd__a143_co }; // b143
assign hc[7:6] = u_hadd__b143_s;

assign { u_hadd__c84_co, u_hadd__c84_s } = { 1'b0, src_c[9:8] } + { 1'b0, hofs[9:8] } + { 2'b0, u_hadd__b143_co }; // c84
assign hc[9:8] = u_hadd__c84_s;

assign hc[11:10] = src_c[11:10] + hofs[11:10] + { 1'b0, u_hadd__c84_co }; // b72
assign { u_hadd__f167_co, u_hadd__f167_s } = { 1'b0, src_d[1:0] } + { 1'b0, hofs[1:0] } + { 2'b0, u_hadd__gnd }; // f167
assign { u_hadd__f143_co, u_hadd__f143_s } = { 1'b0, src_d[3:2] } + { 1'b0, hofs[3:2] } + { 2'b0, u_hadd__f167_co }; // f143
assign { u_hadd__b155_co, u_hadd__b155_s } = { 1'b0, src_d[5:4] } + { 1'b0, hofs[5:4] } + { 2'b0, u_hadd__f143_co }; // b155
assign hd[5:4] = u_hadd__b155_s;

assign { u_hadd__a164_co, u_hadd__a164_s } = { 1'b0, src_d[7:6] } + { 1'b0, hofs[7:6] } + { 2'b0, u_hadd__b155_co }; // a164
assign hd[7:6] = u_hadd__a164_s;

assign { u_hadd__b100_co, u_hadd__b100_s } = { 1'b0, src_d[9:8] } + { 1'b0, hofs[9:8] } + { 2'b0, u_hadd__a164_co }; // b100
assign hd[9:8] = u_hadd__b100_s;

assign hd[11:10] = src_d[11:10] + hofs[11:10] + { 1'b0, u_hadd__b100_co }; // a96
// End inlined jt054156_page07_hadd u_hadd

// Inlined jt054156_page07_hlow u_hlow
wire u_hlow__vcc = 1'b1;

wire       u_hlow__reg0_db4_n, u_hlow__reg0_db0_n;
wire       u_hlow__g184b_y, u_hlow__g189a_y;
wire       u_hlow__f195a_y, u_hlow__f176a_y, u_hlow__f176b_y, u_hlow__f188a_y;
wire [2:0] u_hlow__corr_a, u_hlow__corr_b, u_hlow__corr_c, u_hlow__corr_d;
wire       u_hlow__e209a_co, u_hlow__d175a_co, u_hlow__d212a_co, u_hlow__f186_co;

assign u_hlow__corr_a = { u_hlow__f195a_y, u_hlow__f176b_y, u_hlow__g184b_y };
assign u_hlow__corr_b = { u_hlow__f188a_y, u_hlow__f176a_y, u_hlow__g184b_y };
assign u_hlow__corr_c = { u_hlow__g184b_y, u_hlow__g184b_y, u_hlow__g184b_y };
assign u_hlow__corr_d = { u_hlow__vcc, u_hlow__reg0_db4_n, u_hlow__g189a_y };

assign u_hlow__g184b_y = reg0_db4; // g184b
assign u_hlow__g189a_y = reg0_db4; // g189a
assign u_hlow__reg0_db0_n = ~reg0_db0; // f175a
assign u_hlow__reg0_db4_n = ~reg0_db4; // g181a
assign u_hlow__f195a_y = ~(reg0_db0 ^ u_hlow__g184b_y); // f195a
assign u_hlow__f176b_y = u_hlow__g184b_y & u_hlow__reg0_db0_n; // f176b
assign u_hlow__f176a_y = u_hlow__reg0_db0_n & u_hlow__reg0_db4_n; // f176a
assign u_hlow__f188a_y = reg0_db0 & u_hlow__reg0_db4_n; // f188a
assign ha_low[0] = u_hlow__corr_a[0] ^ ha_pre[0]; // e209a
assign u_hlow__e209a_co = u_hlow__corr_a[0] & ha_pre[0]; // e209a
assign ha_low[2:1] = ha_pre[2:1] + u_hlow__corr_a[2:1] + { 1'b0, u_hlow__e209a_co }; // e198
assign hb_low[0] = u_hlow__corr_b[0] ^ hb_pre[0]; // d175a
assign u_hlow__d175a_co = u_hlow__corr_b[0] & hb_pre[0]; // d175a
assign hb_low[2:1] = hb_pre[2:1] + u_hlow__corr_b[2:1] + { 1'b0, u_hlow__d175a_co }; // d179
assign hc_low[0] = u_hlow__corr_c[0] ^ hc_pre[0]; // d212a
assign u_hlow__d212a_co = u_hlow__corr_c[0] & hc_pre[0]; // d212a
assign hc_low[2:1] = hc_pre[2:1] + u_hlow__corr_c[2:1] + { 1'b0, u_hlow__d212a_co }; // d198
assign hd_low[0] = u_hlow__corr_d[0] ^ hd_pre[0]; // f186
assign u_hlow__f186_co = u_hlow__corr_d[0] & hd_pre[0]; // f186
assign hd_low[2:1] = hd_pre[2:1] + u_hlow__corr_d[2:1] + { 1'b0, u_hlow__f186_co }; // f178
// End inlined jt054156_page07_hlow u_hlow

// Inlined jt054156_page07_scrollx u_scrollx
// Inlined jt054156_page07_hmux u_hmux
jt054156_t5a u_c151a(
    .a1 ( ha[3]            ),
    .a2 ( hb[3]            ),
    .s1 ( u_hscroll__c126a_y ),
    .s2 ( u_hscroll__c162a_y   ),
    .s5 ( u_hscroll__c125a_y ),
    .s6 ( u_hscroll__c126b_y   ),
    .s3 ( u_hscroll__c126a_y ),
    .s4 ( u_hscroll__c162a_y   ),
    .b1 ( hc[3]            ),
    .b2 ( hd[3]            ),
    .x  ( hmux_x[3]        )
);

assign hmux[3] = ~hmux_x[3]; // b71a
jt054156_t5a u_c146a(
    .a1 ( ha[4]            ),
    .a2 ( hb[4]            ),
    .s1 ( u_hscroll__c126a_y ),
    .s2 ( u_hscroll__c162a_y   ),
    .s5 ( u_hscroll__c125a_y ),
    .s6 ( u_hscroll__c126b_y   ),
    .s3 ( u_hscroll__c126a_y ),
    .s4 ( u_hscroll__c162a_y   ),
    .b1 ( hc[4]            ),
    .b2 ( hd[4]            ),
    .x  ( hmux_x[4]        )
);

assign hmux[4] = ~hmux_x[4]; // c110b
jt054156_t5a u_c149(
    .a1 ( ha[5]            ),
    .a2 ( hb[5]            ),
    .s1 ( u_hscroll__c126a_y ),
    .s2 ( u_hscroll__c162a_y   ),
    .s5 ( u_hscroll__c125a_y ),
    .s6 ( u_hscroll__c126b_y   ),
    .s3 ( u_hscroll__c126a_y ),
    .s4 ( u_hscroll__c162a_y   ),
    .b1 ( hc[5]            ),
    .b2 ( hd[5]            ),
    .x  ( hmux_x[5]        )
);

assign hmux[5] = ~hmux_x[5]; // c109b
jt054156_t5a u_c144(
    .a1 ( ha[6]            ),
    .a2 ( hb[6]            ),
    .s1 ( u_hscroll__c126a_y ),
    .s2 ( u_hscroll__c162a_y   ),
    .s5 ( u_hscroll__c125a_y ),
    .s6 ( u_hscroll__c126b_y   ),
    .s3 ( u_hscroll__c126a_y ),
    .s4 ( u_hscroll__c162a_y   ),
    .b1 ( hc[6]            ),
    .b2 ( hd[6]            ),
    .x  ( hmux_x[6]        )
);

assign hmux[6] = ~hmux_x[6]; // c109a
jt054156_t5a u_c141a(
    .a1 ( ha[7]            ),
    .a2 ( hb[7]            ),
    .s1 ( u_hscroll__c126a_y ),
    .s2 ( u_hscroll__c162a_y   ),
    .s5 ( u_hscroll__c125a_y ),
    .s6 ( u_hscroll__c126b_y   ),
    .s3 ( u_hscroll__c126a_y ),
    .s4 ( u_hscroll__c162a_y   ),
    .b1 ( hc[7]            ),
    .b2 ( hd[7]            ),
    .x  ( hmux_x[7]        )
);

assign hmux[7] = ~hmux_x[7]; // b125a
jt054156_t5a u_c110a(
    .a1 ( ha[8]            ),
    .a2 ( hb[8]            ),
    .s1 ( u_hscroll__c126a_y ),
    .s2 ( u_hscroll__c162a_y   ),
    .s5 ( u_hscroll__c125a_y ),
    .s6 ( u_hscroll__c126b_y   ),
    .s3 ( u_hscroll__c126a_y ),
    .s4 ( u_hscroll__c162a_y   ),
    .b1 ( hc[8]            ),
    .b2 ( hd[8]            ),
    .x  ( hmux_x[8]        )
);

assign hmux[8] = ~hmux_x[8]; // c108b
jt054156_t5a u_c123(
    .a1 ( ha[9]            ),
    .a2 ( hb[9]            ),
    .s1 ( u_hscroll__c126a_y ),
    .s2 ( u_hscroll__c162a_y   ),
    .s5 ( u_hscroll__c125a_y ),
    .s6 ( u_hscroll__c126b_y   ),
    .s3 ( u_hscroll__c126a_y ),
    .s4 ( u_hscroll__c162a_y   ),
    .b1 ( hc[9]            ),
    .b2 ( hd[9]            ),
    .x  ( hmux_x[9]        )
);

assign hmux[9] = ~hmux_x[9]; // c108a
jt054156_t5a u_c165(
    .a1 ( ha[10]           ),
    .a2 ( hb[10]           ),
    .s1 ( u_hscroll__c126a_y ),
    .s2 ( u_hscroll__c162a_y   ),
    .s5 ( u_hscroll__c125a_y ),
    .s6 ( u_hscroll__c126b_y   ),
    .s3 ( u_hscroll__c126a_y ),
    .s4 ( u_hscroll__c162a_y   ),
    .b1 ( hc[10]           ),
    .b2 ( hd[10]           ),
    .x  ( hmux_x[10]       )
);

assign hmux[10] = ~hmux_x[10]; // b202b
jt054156_t5a u_c167a(
    .a1 ( ha[11]           ),
    .a2 ( hb[11]           ),
    .s1 ( u_hscroll__c126a_y ),
    .s2 ( u_hscroll__c162a_y   ),
    .s5 ( u_hscroll__c125a_y ),
    .s6 ( u_hscroll__c126b_y   ),
    .s3 ( u_hscroll__c126a_y ),
    .s4 ( u_hscroll__c162a_y   ),
    .b1 ( hc[11]           ),
    .b2 ( hd[11]           ),
    .x  ( hmux_x[11]       )
);

assign hmux[11] = ~hmux_x[11]; // b202a
// End inlined jt054156_page07_hmux u_hmux

// Inlined jt054156_page07_scrollx_add u_scrollx_add
wire       u_scrollx__u_scrollx_add__tied_low;
wire [3:0] u_scrollx__u_scrollx_add__g84_a, u_scrollx__u_scrollx_add__g84_b, u_scrollx__u_scrollx_add__g84_s;
wire [3:0] u_scrollx__u_scrollx_add__f84_a, u_scrollx__u_scrollx_add__f84_b, u_scrollx__u_scrollx_add__f84_s;
wire       u_scrollx__u_scrollx_add__f214_co;

assign u_scrollx__u_scrollx_add__tied_low = 1'b0;

assign u_scrollx__u_scrollx_add__g84_a = { hmux[6],       hmux[5],       hmux[4],       hmux[3]       };
assign u_scrollx__u_scrollx_add__g84_b = { hcnt_phase[5], hcnt_phase[4], hcnt_phase[3], hcnt_phase[2] };
assign u_scrollx__u_scrollx_add__f84_a = { hmux[10],      hmux[9],       hmux[8],       hmux[7]       };
assign u_scrollx__u_scrollx_add__f84_b = { u_scrollx__u_scrollx_add__tied_low,      hcnt_phase[8], hcnt_phase[7], hcnt_phase[6] };

assign scrollx[3] = u_scrollx__u_scrollx_add__g84_s[0];
assign scrollx[4] = u_scrollx__u_scrollx_add__g84_s[1];
assign scrollx[5] = u_scrollx__u_scrollx_add__g84_s[2];
assign scrollx[6] = u_scrollx__u_scrollx_add__g84_s[3];
assign scrollx[7] = u_scrollx__u_scrollx_add__f84_s[0];
assign scrollx[8] = u_scrollx__u_scrollx_add__f84_s[1];

assign u_hscroll__unused_f84_s3 = u_scrollx__u_scrollx_add__f84_s[2];
assign u_hscroll__unused_f84_s4 = u_scrollx__u_scrollx_add__f84_s[3];

assign u_hscroll__unused_n169a_y = reg0_db4; // n169a
assign hcnt_phase[2] = hcnt[2] ^ u_hscroll__unused_n169a_y; // n77
assign hcnt_phase[3] = hcnt[3] ^ u_hscroll__unused_n169a_y; // n78a
assign hcnt_phase[4] = hcnt[4] ^ u_hscroll__unused_n169a_y; // n86a
assign hcnt_phase[5] = hcnt[5] ^ u_hscroll__unused_n169a_y; // n97a
assign hcnt_phase[6] = hcnt[6] ^ u_hscroll__unused_n169a_y; // n100a
assign hcnt_phase[7] = hcnt[7] ^ u_hscroll__unused_n169a_y; // n102
assign hcnt_phase[8] = hcnt[8] ^ u_hscroll__unused_n169a_y; // n99
assign { u_hscroll__unused_g84_co, u_scrollx__u_scrollx_add__g84_s } = { 1'b0, u_scrollx__u_scrollx_add__g84_a } + { 1'b0, u_scrollx__u_scrollx_add__g84_b } + { 4'b0, u_scrollx__u_scrollx_add__tied_low }; // g84
assign { u_hscroll__unused_f84_co, u_scrollx__u_scrollx_add__f84_s } = { 1'b0, u_scrollx__u_scrollx_add__f84_a } + { 1'b0, u_scrollx__u_scrollx_add__f84_b } + { 4'b0, u_hscroll__unused_g84_co }; // f84
assign u_hscroll__unused_f191_s = hmux[11] ^ u_hscroll__unused_f84_co ^ u_scrollx__u_scrollx_add__tied_low; // f191
assign hs_mux[0] = u_hscroll__unused_f84_s3 & hb_mux[0]; // f78a
assign hs_mux[1] = u_hscroll__unused_f84_s4 & hb_mux[1]; // f82a
assign hs_mux[2] = u_hscroll__unused_f191_s & hb_mux[2]; // f204a
assign pagex[0] = hs_mux[0] ^ hs_mux[0]; // f214
assign u_scrollx__u_scrollx_add__f214_co = hs_mux[0] & hs_mux[0]; // f214
assign pagex[2:1] = hs_mux[2:1] + hs_mux[2:1] + { 1'b0, u_scrollx__u_scrollx_add__f214_co }; // f206
// End inlined jt054156_page07_scrollx_add u_scrollx_add
// End inlined jt054156_page07_scrollx u_scrollx

// Inlined jt054156_page07_zout u_zout
reg u_zout__pin_z1h;
reg u_zout__pin_z2h;
reg u_zout__pin_z4h;
wire    u_zout__e183_y, u_zout__d188_y, u_zout__g187_y;
wire    u_zout__e180b_y, u_zout__e178b_y, u_zout__e178a_y;
assign u_hscroll__unused_zout_dclk_n = ~pin_dclk; // n170a
assign u_zout__e183_y = p140_xq; // e183
assign u_zout__e180b_y = ~u_zout__e183_y; // e180b
assign u_zout__d188_y = p140_xq; // d188
assign u_zout__e178b_y = ~u_zout__d188_y; // e178b
assign u_zout__g187_y = hcnt0; // g187
assign u_zout__e178a_y = ~u_zout__g187_y; // e178a
assign u_hscroll__unused_zout_mux_x[0] = ~(u_zout__g187_y ? (u_zout__e183_y ? ha_low[0] : hd_low[0]) : (u_zout__d188_y ? hc_low[0] : hb_low[0])); // e180a
assign u_hscroll__unused_zout_mux[0] = ~u_hscroll__unused_zout_mux_x[0]; // e177a
always @(posedge u_hscroll__unused_zout_dclk_n) begin
    u_zout__pin_z1h <= u_hscroll__unused_zout_mux[0]; // k187
end
assign u_hscroll__unused_zout_mux_x[1] = ~(u_zout__g187_y ? (u_zout__e183_y ? ha_low[1] : hd_low[1]) : (u_zout__d188_y ? hc_low[1] : hb_low[1])); // e187a
assign u_hscroll__unused_zout_mux[1] = ~u_hscroll__unused_zout_mux_x[1]; // e179a
always @(posedge u_hscroll__unused_zout_dclk_n) begin
    u_zout__pin_z2h <= u_hscroll__unused_zout_mux[1]; // j183
end
assign u_hscroll__unused_zout_mux_x[2] = ~(u_zout__g187_y ? (u_zout__e183_y ? ha_low[2] : hd_low[2]) : (u_zout__d188_y ? hc_low[2] : hb_low[2])); // e185
assign u_hscroll__unused_zout_mux[2] = ~u_hscroll__unused_zout_mux_x[2]; // e179b
always @(posedge u_hscroll__unused_zout_dclk_n) begin
    u_zout__pin_z4h <= u_hscroll__unused_zout_mux[2]; // j186
end
assign pin_z1h = u_zout__pin_z1h;
assign pin_z2h = u_zout__pin_z2h;
assign pin_z4h = u_zout__pin_z4h;
// End inlined jt054156_page07_zout u_zout
// End inlined jt054156_page07_hscroll u_hscroll

// Inlined jt054156_page08_scrolly u_scrolly
wire u_scrolly__unused_n186_x2t_buf3_n;
wire u_scrolly__unused_n186_x2t_buf3;
wire u_scrolly__unused_n186_x3t_buf3_n;
wire u_scrolly__unused_n186_x3t_buf3;
wire u_scrolly__n186_x2t_buf;
wire u_scrolly__n186_x3t_buf;

// Inlined jt054156_page08_scrolly_mux u_scrolly_mux
wire [10:0] u_scrolly_mux__t5a_x;

assign u_scrolly__unused_n186_x3t_buf3_n = n186_x3t_buf_n; // n160a
assign u_scrolly__unused_n186_x3t_buf3 = ~n186_x3t_buf_n; // n161b
assign u_scrolly__unused_n186_x2t_buf3_n = n186_x2t_buf_n; // n161a
assign u_scrolly__unused_n186_x2t_buf3 = ~n186_x2t_buf_n; // n162b
jt054156_t5a u_k110(
    .a1 ( reg20_d[10]      ),
    .a2 ( reg22_d[10]      ),
    .s1 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s2 ( u_scrolly__unused_n186_x2t_buf3   ),
    .s5 ( u_scrolly__unused_n186_x3t_buf3_n ),
    .s6 ( u_scrolly__unused_n186_x3t_buf3   ),
    .s3 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s4 ( u_scrolly__unused_n186_x2t_buf3   ),
    .b1 ( reg24_d[10]      ),
    .b2 ( reg26_d[10]      ),
    .x  ( u_scrolly_mux__t5a_x[10]        )
);

assign scrolly_mux[10] = ~u_scrolly_mux__t5a_x[10]; // k137b
jt054156_t5a u_k112a(
    .a1 ( reg20_d[9]      ),
    .a2 ( reg22_d[9]      ),
    .s1 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s2 ( u_scrolly__unused_n186_x2t_buf3   ),
    .s5 ( u_scrolly__unused_n186_x3t_buf3_n ),
    .s6 ( u_scrolly__unused_n186_x3t_buf3   ),
    .s3 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s4 ( u_scrolly__unused_n186_x2t_buf3   ),
    .b1 ( reg24_d[9]      ),
    .b2 ( reg26_d[9]      ),
    .x  ( u_scrolly_mux__t5a_x[9]        )
);

assign scrolly_mux[9] = ~u_scrolly_mux__t5a_x[9]; // k135b
jt054156_t5a u_l109(
    .a1 ( reg20_d[8]      ),
    .a2 ( reg22_d[8]      ),
    .s1 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s2 ( u_scrolly__unused_n186_x2t_buf3   ),
    .s5 ( u_scrolly__unused_n186_x3t_buf3_n ),
    .s6 ( u_scrolly__unused_n186_x3t_buf3   ),
    .s3 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s4 ( u_scrolly__unused_n186_x2t_buf3   ),
    .b1 ( reg24_d[8]      ),
    .b2 ( reg26_d[8]      ),
    .x  ( u_scrolly_mux__t5a_x[8]        )
);

assign scrolly_mux[8] = ~u_scrolly_mux__t5a_x[8]; // k124b
jt054156_t5a u_l113(
    .a1 ( reg20_d[7]      ),
    .a2 ( reg22_d[7]      ),
    .s1 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s2 ( u_scrolly__unused_n186_x2t_buf3   ),
    .s5 ( u_scrolly__unused_n186_x3t_buf3_n ),
    .s6 ( u_scrolly__unused_n186_x3t_buf3   ),
    .s3 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s4 ( u_scrolly__unused_n186_x2t_buf3   ),
    .b1 ( reg24_d[7]      ),
    .b2 ( reg26_d[7]      ),
    .x  ( u_scrolly_mux__t5a_x[7]        )
);

assign scrolly_mux[7] = ~u_scrolly_mux__t5a_x[7]; // k109b
jt054156_t5a u_n124a(
    .a1 ( reg20_d[6]      ),
    .a2 ( reg22_d[6]      ),
    .s1 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s2 ( u_scrolly__unused_n186_x2t_buf3   ),
    .s5 ( u_scrolly__unused_n186_x3t_buf3_n ),
    .s6 ( u_scrolly__unused_n186_x3t_buf3   ),
    .s3 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s4 ( u_scrolly__unused_n186_x2t_buf3   ),
    .b1 ( reg24_d[6]      ),
    .b2 ( reg26_d[6]      ),
    .x  ( u_scrolly_mux__t5a_x[6]        )
);

assign scrolly_mux[6] = ~u_scrolly_mux__t5a_x[6]; // r128b
jt054156_t5a u_n118(
    .a1 ( reg20_d[5]      ),
    .a2 ( reg22_d[5]      ),
    .s1 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s2 ( u_scrolly__unused_n186_x2t_buf3   ),
    .s5 ( u_scrolly__unused_n186_x3t_buf3_n ),
    .s6 ( u_scrolly__unused_n186_x3t_buf3   ),
    .s3 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s4 ( u_scrolly__unused_n186_x2t_buf3   ),
    .b1 ( reg24_d[5]      ),
    .b2 ( reg26_d[5]      ),
    .x  ( u_scrolly_mux__t5a_x[5]        )
);

assign scrolly_mux[5] = ~u_scrolly_mux__t5a_x[5]; // r116a
jt054156_t5a u_n120a(
    .a1 ( reg20_d[4]      ),
    .a2 ( reg22_d[4]      ),
    .s1 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s2 ( u_scrolly__unused_n186_x2t_buf3   ),
    .s5 ( u_scrolly__unused_n186_x3t_buf3_n ),
    .s6 ( u_scrolly__unused_n186_x3t_buf3   ),
    .s3 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s4 ( u_scrolly__unused_n186_x2t_buf3   ),
    .b1 ( reg24_d[4]      ),
    .b2 ( reg26_d[4]      ),
    .x  ( u_scrolly_mux__t5a_x[4]        )
);

assign scrolly_mux[4] = ~u_scrolly_mux__t5a_x[4]; // r116b
jt054156_t5a u_n145a(
    .a1 ( reg20_d[3]      ),
    .a2 ( reg22_d[3]      ),
    .s1 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s2 ( u_scrolly__unused_n186_x2t_buf3   ),
    .s5 ( u_scrolly__unused_n186_x3t_buf3_n ),
    .s6 ( u_scrolly__unused_n186_x3t_buf3   ),
    .s3 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s4 ( u_scrolly__unused_n186_x2t_buf3   ),
    .b1 ( reg24_d[3]      ),
    .b2 ( reg26_d[3]      ),
    .x  ( u_scrolly_mux__t5a_x[3]        )
);

assign scrolly_mux[3] = ~u_scrolly_mux__t5a_x[3]; // r145b
jt054156_t5a u_n148(
    .a1 ( reg20_d[2]      ),
    .a2 ( reg22_d[2]      ),
    .s1 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s2 ( u_scrolly__unused_n186_x2t_buf3   ),
    .s5 ( u_scrolly__unused_n186_x3t_buf3_n ),
    .s6 ( u_scrolly__unused_n186_x3t_buf3   ),
    .s3 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s4 ( u_scrolly__unused_n186_x2t_buf3   ),
    .b1 ( reg24_d[2]      ),
    .b2 ( reg26_d[2]      ),
    .x  ( u_scrolly_mux__t5a_x[2]        )
);

assign scrolly_mux[2] = ~u_scrolly_mux__t5a_x[2]; // r145a
jt054156_t5a u_n140a(
    .a1 ( reg20_d[1]      ),
    .a2 ( reg22_d[1]      ),
    .s1 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s2 ( u_scrolly__unused_n186_x2t_buf3   ),
    .s5 ( u_scrolly__unused_n186_x3t_buf3_n ),
    .s6 ( u_scrolly__unused_n186_x3t_buf3   ),
    .s3 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s4 ( u_scrolly__unused_n186_x2t_buf3   ),
    .b1 ( reg24_d[1]      ),
    .b2 ( reg26_d[1]      ),
    .x  ( u_scrolly_mux__t5a_x[1]        )
);

assign scrolly_mux[1] = ~u_scrolly_mux__t5a_x[1]; // r144a
jt054156_t5a u_n143(
    .a1 ( reg20_d[0]      ),
    .a2 ( reg22_d[0]      ),
    .s1 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s2 ( u_scrolly__unused_n186_x2t_buf3   ),
    .s5 ( u_scrolly__unused_n186_x3t_buf3_n ),
    .s6 ( u_scrolly__unused_n186_x3t_buf3   ),
    .s3 ( u_scrolly__unused_n186_x2t_buf3_n ),
    .s4 ( u_scrolly__unused_n186_x2t_buf3   ),
    .b1 ( reg24_d[0]      ),
    .b2 ( reg26_d[0]      ),
    .x  ( u_scrolly_mux__t5a_x[0]        )
);

assign scrolly_mux[0] = ~u_scrolly_mux__t5a_x[0]; // r144b
// End inlined jt054156_page08_scrolly_mux u_scrolly_mux

// Inlined jt054156_page08_scrolly_ctrl u_scrolly_ctrl
wire u_scrolly_ctrl__unused_m180_x;
wire u_scrolly_ctrl__unused_m79a_y;
reg u_scrolly_ctrl__unused_r60_q;
wire u_scrolly_ctrl__unused_r60_nq;
wire u_scrolly_ctrl__unused_r114b_y;
wire u_scrolly_ctrl__unused_p164b_y;
wire    u_scrolly_ctrl__gnd = 1'b0;
assign u_scrolly__n186_x3t_buf = ~n186_x3t_buf_n; // m187a
assign u_scrolly__n186_x2t_buf = ~n186_x2t_buf_n; // m188a
assign u_scrolly_ctrl__unused_m180_x = ~(n186_x3t_buf_n ? (n186_x2t_buf_n ? reg8_db[7] : reg8_db[6]) : (n186_x2t_buf_n ? reg8_db[5] : reg8_db[4])); // m180
assign u_scrolly_ctrl__unused_m79a_y = ~pin_test; // m79a
always @(posedge hcnt2 or negedge pin_nhsy or negedge reset20_n) begin
    if (!pin_nhsy) begin
        u_scrolly_ctrl__unused_r60_q <= 1'b1;
    end else if (!reset20_n) begin
        u_scrolly_ctrl__unused_r60_q <= 1'b0;
    end else begin
        u_scrolly_ctrl__unused_r60_q <= u_scrolly_ctrl__gnd;
    end
end // r60

assign u_scrolly_ctrl__unused_r60_nq = ~u_scrolly_ctrl__unused_r60_q; // r60
assign pin_sz = u_scrolly_ctrl__unused_m79a_y & u_scrolly_ctrl__unused_r60_q; // n103a
assign u_scrolly_ctrl__unused_r114b_y = pin_test | u_scrolly_ctrl__unused_r60_nq; // r114b
assign u_scrolly_ctrl__unused_p164b_y = ~u_scrolly_ctrl__unused_r114b_y; // p164b
assign scrolly_en_mux = ~&{u_scrolly_ctrl__unused_m180_x,u_scrolly_ctrl__unused_p164b_y}; // p171a
// End inlined jt054156_page08_scrolly_ctrl u_scrolly_ctrl

// Inlined jt054156_page08_scrolly_add u_scrolly_add
wire u_scrolly_add__unused_h77a_y;
wire u_scrolly_add__unused_l79a_y;
wire u_scrolly_add__unused_l104b_y;
wire u_scrolly_add__unused_l79b_y;
wire u_scrolly_add__unused_j71_co;
wire u_scrolly_add__unused_k163_s4;
wire u_scrolly_add__unused_k163_co;
wire u_scrolly_add__unused_k197_co;
wire u_scrolly_add__unused_l197_co;
wire u_scrolly_add__gnd = 1'b0;

wire       u_scrolly_add__m65a_co, u_scrolly_add__m68_co, u_scrolly_add__m55_co, u_scrolly_add__l55_co, u_scrolly_add__j58_co;
wire       u_scrolly_add__m80_co, u_scrolly_add__l80_co;
wire [1:0] u_scrolly_add__m68_s, u_scrolly_add__m55_s, u_scrolly_add__l55_s, u_scrolly_add__j58_s, u_scrolly_add__j71_s, u_scrolly_add__l197_s;
wire [1:0] u_scrolly_add__j71_b;
wire [3:0] u_scrolly_add__m80_a, u_scrolly_add__m80_b, u_scrolly_add__m80_s;
wire [3:0] u_scrolly_add__l80_a, u_scrolly_add__l80_b, u_scrolly_add__l80_s;
wire [3:0] u_scrolly_add__k163_a, u_scrolly_add__k163_b, u_scrolly_add__k163_s;

assign u_scrolly_add__j71_b = { u_scrolly_add__gnd, u_scrolly_add__gnd };

assign yofs_scan[2:1] = u_scrolly_add__m68_s;
assign yofs_scan[4:3] = u_scrolly_add__m55_s;
assign yofs_scan[6:5] = u_scrolly_add__l55_s;
assign yofs_scan[8:7] = u_scrolly_add__j58_s;
assign yofs_scan[10:9] = u_scrolly_add__j71_s;

assign u_scrolly_add__m80_a  = yofs_scan[3:0];
assign u_scrolly_add__m80_b  = layer_scroll[3:0];
assign u_scrolly_add__l80_a  = yofs_scan[7:4];
assign u_scrolly_add__l80_b  = layer_scroll[7:4];
assign u_scrolly_add__k163_a = { u_scrolly_add__gnd, yofs_scan[10:8] };
assign u_scrolly_add__k163_b = { u_scrolly_add__gnd, layer_scroll[10:8] };

assign scrolly[3:0]  = u_scrolly_add__m80_s;
assign scrolly[7:4]  = u_scrolly_add__l80_s;
assign scrolly[10:8] = u_scrolly_add__k163_s[2:0];
assign u_scrolly_add__unused_k163_s4       = u_scrolly_add__k163_s[3];

assign u_scrolly_add__unused_h77a_y = reg0_db5; // h77a
assign u_scrolly_add__unused_l79a_y = reg0_db5; // l79a
assign u_scrolly_add__unused_l104b_y = reg0_db5; // l104b
assign u_scrolly_add__unused_l79b_y = reg0_db5; // l79b
assign reg3cl_gated[10] = reg3cl_d[10] & u_scrolly_add__unused_h77a_y; // h66a
assign reg3cl_gated[9] = reg3cl_d[9] & u_scrolly_add__unused_h77a_y; // h66b
assign reg3cl_gated[8] = reg3cl_d[8] & u_scrolly_add__unused_h77a_y; // h57b
assign reg3cl_gated[7] = reg3cl_d[7] & u_scrolly_add__unused_h77a_y; // j66a
assign reg3cl_gated[6] = reg3cl_d[6] & u_scrolly_add__unused_h77a_y; // k78a
assign reg3cl_gated[5] = reg3cl_d[5] & u_scrolly_add__unused_l79a_y; // j66b
assign reg3cl_gated[4] = reg3cl_d[4] & u_scrolly_add__unused_l79a_y; // m63a
assign reg3cl_gated[3] = reg3cl_d[3] & u_scrolly_add__unused_l79a_y; // m64b
assign reg3cl_gated[2] = reg3cl_d[2] & u_scrolly_add__unused_l79a_y; // m78b
assign reg3cl_gated[1] = reg3cl_d[1] & u_scrolly_add__unused_l79a_y; // m77a
assign reg3cl_gated[0] = reg3cl_d[0] & u_scrolly_add__unused_l79a_y; // m76b
assign vcnt_phase[8] = vcnt[8] ^ u_scrolly_add__unused_l104b_y; // l14a
assign vcnt_phase[7] = vcnt[7] ^ u_scrolly_add__unused_l104b_y; // l11a
assign vcnt_phase[6] = vcnt[6] ^ u_scrolly_add__unused_l104b_y; // l18
assign vcnt_phase[5] = vcnt[5] ^ u_scrolly_add__unused_l104b_y; // l16a
assign vcnt_phase[4] = vcnt[4] ^ u_scrolly_add__unused_l79b_y; // m49a
assign vcnt_phase[3] = vcnt[3] ^ u_scrolly_add__unused_l79b_y; // n27a
assign vcnt_phase[2] = vcnt[2] ^ u_scrolly_add__unused_l79b_y; // n69a
assign vcnt_phase[1] = vcnt[1] ^ u_scrolly_add__unused_l79b_y; // m51
assign vcnt_phase[0] = vcnt[0] ^ u_scrolly_add__unused_l79b_y; // m23
assign yofs_scan[0] = reg3cl_gated[0] ^ vcnt_phase[0]; // m65a
assign u_scrolly_add__m65a_co = reg3cl_gated[0] & vcnt_phase[0]; // m65a
assign { u_scrolly_add__m68_co, u_scrolly_add__m68_s } = { 1'b0, reg3cl_gated[2:1] } + { 1'b0, vcnt_phase[2:1] } + { 2'b0, u_scrolly_add__m65a_co }; // m68
assign { u_scrolly_add__m55_co, u_scrolly_add__m55_s } = { 1'b0, reg3cl_gated[4:3] } + { 1'b0, vcnt_phase[4:3] } + { 2'b0, u_scrolly_add__m68_co }; // m55
assign { u_scrolly_add__l55_co, u_scrolly_add__l55_s } = { 1'b0, reg3cl_gated[6:5] } + { 1'b0, vcnt_phase[6:5] } + { 2'b0, u_scrolly_add__m55_co }; // l55
assign { u_scrolly_add__j58_co, u_scrolly_add__j58_s } = { 1'b0, reg3cl_gated[8:7] } + { 1'b0, vcnt_phase[8:7] } + { 2'b0, u_scrolly_add__l55_co }; // j58
assign { u_scrolly_add__unused_j71_co, u_scrolly_add__j71_s } = { 1'b0, reg3cl_gated[10:9] } + { 1'b0, u_scrolly_add__j71_b } + { 2'b0, u_scrolly_add__j58_co }; // j71
assign layer_scroll[10] = scrolly_mux[10] & scrolly_en_mux; // k153a
assign layer_scroll[9] = scrolly_mux[9] & scrolly_en_mux; // k136a
assign layer_scroll[8] = scrolly_mux[8] & scrolly_en_mux; // k125a
assign layer_scroll[7] = scrolly_mux[7] & scrolly_en_mux; // k108a
assign layer_scroll[6] = scrolly_mux[6] & scrolly_en_mux; // r121b
assign layer_scroll[5] = scrolly_mux[5] & scrolly_en_mux; // r111a
assign layer_scroll[4] = scrolly_mux[4] & scrolly_en_mux; // r112b
assign layer_scroll[3] = scrolly_mux[3] & scrolly_en_mux; // r118a
assign layer_scroll[2] = scrolly_mux[2] & scrolly_en_mux; // r119b
assign layer_scroll[1] = scrolly_mux[1] & scrolly_en_mux; // r120a
assign layer_scroll[0] = scrolly_mux[0] & scrolly_en_mux; // r117b
assign { u_scrolly_add__m80_co, u_scrolly_add__m80_s } = { 1'b0, u_scrolly_add__m80_a } + { 1'b0, u_scrolly_add__m80_b } + { 4'b0, u_scrolly_add__gnd }; // m80
assign { u_scrolly_add__l80_co, u_scrolly_add__l80_s } = { 1'b0, u_scrolly_add__l80_a } + { 1'b0, u_scrolly_add__l80_b } + { 4'b0, u_scrolly_add__m80_co }; // l80
assign { u_scrolly_add__unused_k163_co, u_scrolly_add__k163_s } = { 1'b0, u_scrolly_add__k163_a } + { 1'b0, u_scrolly_add__k163_b } + { 4'b0, u_scrolly_add__l80_co }; // k163
assign vs_mux[0] = scrolly[8] & vb_mux[0]; // l183b
assign vs_mux[1] = scrolly[9] & vb_mux[1]; // l182a
assign vs_mux[2] = scrolly[10] & vb_mux[2]; // l188b
assign pagey[0] = vs_mux[0] ^ vs_mux[0]; // k197
assign u_scrolly_add__unused_k197_co = vs_mux[0] & vs_mux[0]; // k197
assign { u_scrolly_add__unused_l197_co, u_scrolly_add__l197_s } = { 1'b0, vs_mux[2:1] } + { 1'b0, vs_mux[2:1] } + { 2'b0, u_scrolly_add__unused_k197_co }; // l197
assign pagey[2:1] = u_scrolly_add__l197_s;
// End inlined jt054156_page08_scrolly_add u_scrolly_add
// End inlined jt054156_page08_scrolly u_scrolly

endmodule


// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054156_vram_addr_ctrl.v
// -----------------------------------------------------------------------------

// Connected VRAM-address fragment using the page-6 K209A/H181A control source
// and the page-10 VA output mux banks.
module jt054156_vram_addr_ctrl(
    input  wire        reset2_n,
    input  wire        reg0_db0,
    input  wire        reg0_db4,
    input  wire        reg0_db7,
    input  wire        p140_xq,
    input  wire        hcnt0,
    input  wire [3:0]  reg8_db,
    input  wire [5:2]  regc_db,
    input  wire        regc_db0,
    input  wire        regc_db1_buf,
    input  wire        n186_x2t_n,
    input  wire        n186_x3t_n,
    input  wire        pin_sz,
    input  wire        n186_x2_n,
    input  wire        n186_x3_n,
    input  wire [8:3]  scrollx,
    input  wire [8:0]  scrolly,
    input  wire [2:0]  pagex,
    input  wire [2:0]  pagey,
    input  wire [10:0] ab_ram,
    input  wire [10:0] ab_mux_ram,
    input  wire [5:0]  reg30_d,
    input  wire [5:0]  reg32_d,
    output wire [16:0] pin_va,
    output wire        k209a,
    output wire        h181a,
    output wire        h176a_y,
    output wire        g170a_y,
    output wire        k207b_y,
    output wire        m191a,
    output wire        pin_namp,
    output wire        m201_xq,
    output wire        m200a_y,
    output wire        m200b_y
);

wire g174a_y, g175b_y, g175a_x, h183_y, j182a_y, h180_x, h184a_y;

// Inlined jt054156_page06_m191a_source u_m191a_source
wire u_m191a_source__unused_m190b_x;
wire u_m191a_source__unused_m205a_y;
wire u_m191a_source__unused_j203a_y;
wire u_m191a_source__unused_k200a_y;
wire u_m191a_source__unused_g185a_y;
wire u_m191a_source__unused_g182a_y;
wire u_m191a_source__unused_j189a_y;
wire u_m191a_source__unused_k200b_y;
wire u_m191a_source__unused_k201a_x;
reg     u_m191a_source__m201_q;

wire [2:0] u_m191a_source__k201a_a, u_m191a_source__k201a_b, u_m191a_source__k201a_c, u_m191a_source__k201a_d;
wire [2:0] u_m191a_source__m191a_a, u_m191a_source__m191a_b;
assign u_m191a_source__k201a_a = { regc_db[3], u_m191a_source__unused_k200b_y, u_m191a_source__unused_j203a_y };
assign u_m191a_source__k201a_b = { u_m191a_source__unused_k200b_y,   u_m191a_source__unused_k200a_y, regc_db[2] };
assign u_m191a_source__k201a_c = { regc_db[5], u_m191a_source__unused_j203a_y, u_m191a_source__unused_j189a_y };
assign u_m191a_source__k201a_d = { u_m191a_source__unused_j189a_y,   u_m191a_source__unused_k200a_y, regc_db[4] };

assign u_m191a_source__m191a_a = { m201_xq, p140_xq, reg0_db0 };
assign u_m191a_source__m191a_b = { m201_xq, hcnt0,   m200b_y  };

assign m200a_y = ~reg0_db0; // m200a
assign u_m191a_source__unused_m190b_x = reg0_db0 ? ~hcnt0 : ~p140_xq; // m190b
assign u_m191a_source__unused_m205a_y = ~u_m191a_source__unused_m190b_x; // m205a
assign u_m191a_source__unused_j203a_y = ~n186_x2t_n; // j203a
assign u_m191a_source__unused_k200a_y = ~u_m191a_source__unused_j203a_y; // k200a
assign u_m191a_source__unused_g185a_y = ~(n186_x3t_n ^ reg0_db4); // g185a
assign u_m191a_source__unused_g182a_y = u_m191a_source__unused_g185a_y ^ reg0_db4; // g182a
assign u_m191a_source__unused_j189a_y = ~|{reg0_db0,u_m191a_source__unused_g182a_y}; // j189a
assign u_m191a_source__unused_k200b_y = ~u_m191a_source__unused_j189a_y; // k200b
assign u_m191a_source__unused_k201a_x = ~(|{ &u_m191a_source__k201a_a, &u_m191a_source__k201a_b, &u_m191a_source__k201a_c, &u_m191a_source__k201a_d }); // k201a
always @(posedge u_m191a_source__unused_m205a_y or negedge reset2_n) begin
    if (!reset2_n) begin
        u_m191a_source__m201_q <= 1'b1;
    end else begin
        u_m191a_source__m201_q <= u_m191a_source__unused_k201a_x;
    end
end // m201

assign m201_xq = ~u_m191a_source__m201_q; // m201
assign m200b_y = ~reg0_db0; // m200b
assign m191a = ~(&{ |u_m191a_source__m191a_a, |u_m191a_source__m191a_b }); // m191a
assign pin_namp = m191a; // n211a
// End inlined jt054156_page06_m191a_source u_m191a_source

// Inlined jt054156_page06_va_ctrl u_va_ctrl
assign g174a_y = ~n186_x3t_n; // g174a
assign g175b_y = ~n186_x2t_n; // g175b
assign g175a_x = ~(n186_x3t_n ? (n186_x2t_n ? reg8_db[3] : reg8_db[2]) : (n186_x2t_n ? reg8_db[1] : reg8_db[0])); // g175a
assign h183_y = ~|{g175a_x,pin_sz}; // h183
assign j182a_y = regc_db0; // j182a
assign h180_x = regc_db1_buf ^ j182a_y; // h180
assign k209a = reg0_db7 | m191a; // k209a
assign h184a_y = ~k209a; // h184a
assign h181a = k209a ? ~h180_x : ~h183_y; // h181a
// End inlined jt054156_page06_va_ctrl u_va_ctrl

// Inlined jt054156_page10_vram_addr u_vram_addr
// Inlined jt054156_page10_va_low u_va_low
wire [10:0] u_va_low__pin_va;
wire u_va_low__unused_k209a_low_buf;
wire u_va_low__unused_k209a_low_n;
wire u_va_low__unused_h181a_low_buf;
wire u_va_low__unused_h181a_low_n;
wire u_va_low__unused_k209a_high_buf;
wire u_va_low__unused_k209a_high_n;
wire u_va_low__unused_h181a_high_buf;
wire u_va_low__unused_h181a_high_n;
wire [10:0] u_va_low__va_mux_x;
wire [10:0] u_va_low__va_a1, u_va_low__va_a2;

assign u_va_low__va_a1[0] = scrolly[0];
assign u_va_low__va_a1[1] = scrolly[1];
assign u_va_low__va_a1[2] = scrolly[2];
assign u_va_low__va_a1[3] = scrolly[3];
assign u_va_low__va_a1[4] = scrolly[4];
assign u_va_low__va_a1[5] = scrolly[5];
assign u_va_low__va_a1[6] = scrolly[6];
assign u_va_low__va_a1[7] = scrolly[7];
assign u_va_low__va_a1[8] = h176a_y;
assign u_va_low__va_a1[9] = g170a_y;
assign u_va_low__va_a1[10] = k207b_y;

assign u_va_low__va_a2[0] = scrollx[3];
assign u_va_low__va_a2[1] = scrollx[4];
assign u_va_low__va_a2[2] = scrollx[5];
assign u_va_low__va_a2[3] = scrollx[6];
assign u_va_low__va_a2[4] = scrollx[7];
assign u_va_low__va_a2[5] = scrollx[8];
assign u_va_low__va_a2[6] = scrolly[3];
assign u_va_low__va_a2[7] = scrolly[4];
assign u_va_low__va_a2[8] = scrolly[5];
assign u_va_low__va_a2[9] = scrolly[6];
assign u_va_low__va_a2[10] = scrolly[7];

assign u_va_low__unused_k209a_low_buf = k209a; // g49a
assign u_va_low__unused_k209a_low_n = ~k209a; // g26b
assign u_va_low__unused_h181a_low_buf = h181a; // g25a
assign u_va_low__unused_h181a_low_n = ~h181a; // g25b
assign u_va_low__unused_k209a_high_buf = k209a; // g78a
assign u_va_low__unused_k209a_high_n = ~k209a; // g67a
assign u_va_low__unused_h181a_high_buf = h181a; // g66b
assign u_va_low__unused_h181a_high_n = ~h181a; // f71a
assign h176a_y = pin_sz & scrolly[8]; // h176a
assign g170a_y = pin_sz & n186_x2_n; // g170a
assign k207b_y = pin_sz & n186_x3_n; // k207b
jt054156_t5a u_g29a(
    .a1 ( u_va_low__va_a1[0]       ),
    .a2 ( u_va_low__va_a2[0]       ),
    .s1 ( u_va_low__unused_h181a_low_n    ),
    .s2 ( u_va_low__unused_h181a_low_buf  ),
    .s5 ( u_va_low__unused_k209a_low_n    ),
    .s6 ( u_va_low__unused_k209a_low_buf  ),
    .s3 ( u_va_low__unused_h181a_low_n    ),
    .s4 ( u_va_low__unused_h181a_low_buf  ),
    .b1 ( ab_ram[0]      ),
    .b2 ( ab_mux_ram[0]  ),
    .x  ( u_va_low__va_mux_x[0]    )
);

assign u_va_low__pin_va[0] = ~u_va_low__va_mux_x[0]; // g140a
jt054156_t5a u_g32(
    .a1 ( u_va_low__va_a1[1]       ),
    .a2 ( u_va_low__va_a2[1]       ),
    .s1 ( u_va_low__unused_h181a_low_n    ),
    .s2 ( u_va_low__unused_h181a_low_buf  ),
    .s5 ( u_va_low__unused_k209a_low_n    ),
    .s6 ( u_va_low__unused_k209a_low_buf  ),
    .s3 ( u_va_low__unused_h181a_low_n    ),
    .s4 ( u_va_low__unused_h181a_low_buf  ),
    .b1 ( ab_ram[1]      ),
    .b2 ( ab_mux_ram[1]  ),
    .x  ( u_va_low__va_mux_x[1]    )
);

assign u_va_low__pin_va[1] = ~u_va_low__va_mux_x[1]; // g140b
jt054156_t5a u_g34a(
    .a1 ( u_va_low__va_a1[2]       ),
    .a2 ( u_va_low__va_a2[2]       ),
    .s1 ( u_va_low__unused_h181a_low_n    ),
    .s2 ( u_va_low__unused_h181a_low_buf  ),
    .s5 ( u_va_low__unused_k209a_low_n    ),
    .s6 ( u_va_low__unused_k209a_low_buf  ),
    .s3 ( u_va_low__unused_h181a_low_n    ),
    .s4 ( u_va_low__unused_h181a_low_buf  ),
    .b1 ( ab_ram[2]      ),
    .b2 ( ab_mux_ram[2]  ),
    .x  ( u_va_low__va_mux_x[2]    )
);

assign u_va_low__pin_va[2] = ~u_va_low__va_mux_x[2]; // d173b
jt054156_t5a u_g27(
    .a1 ( u_va_low__va_a1[3]       ),
    .a2 ( u_va_low__va_a2[3]       ),
    .s1 ( u_va_low__unused_h181a_low_n    ),
    .s2 ( u_va_low__unused_h181a_low_buf  ),
    .s5 ( u_va_low__unused_k209a_low_n    ),
    .s6 ( u_va_low__unused_k209a_low_buf  ),
    .s3 ( u_va_low__unused_h181a_low_n    ),
    .s4 ( u_va_low__unused_h181a_low_buf  ),
    .b1 ( ab_ram[3]      ),
    .b2 ( ab_mux_ram[3]  ),
    .x  ( u_va_low__va_mux_x[3]    )
);

assign u_va_low__pin_va[3] = ~u_va_low__va_mux_x[3]; // g170b
jt054156_t5a u_g41(
    .a1 ( u_va_low__va_a1[4]       ),
    .a2 ( u_va_low__va_a2[4]       ),
    .s1 ( u_va_low__unused_h181a_low_n    ),
    .s2 ( u_va_low__unused_h181a_low_buf  ),
    .s5 ( u_va_low__unused_k209a_low_n    ),
    .s6 ( u_va_low__unused_k209a_low_buf  ),
    .s3 ( u_va_low__unused_h181a_low_n    ),
    .s4 ( u_va_low__unused_h181a_low_buf  ),
    .b1 ( ab_ram[4]      ),
    .b2 ( ab_mux_ram[4]  ),
    .x  ( u_va_low__va_mux_x[4]    )
);

assign u_va_low__pin_va[4] = ~u_va_low__va_mux_x[4]; // g180
jt054156_t5a u_g43a(
    .a1 ( u_va_low__va_a1[5]       ),
    .a2 ( u_va_low__va_a2[5]       ),
    .s1 ( u_va_low__unused_h181a_low_n    ),
    .s2 ( u_va_low__unused_h181a_low_buf  ),
    .s5 ( u_va_low__unused_k209a_low_n    ),
    .s6 ( u_va_low__unused_k209a_low_buf  ),
    .s3 ( u_va_low__unused_h181a_low_n    ),
    .s4 ( u_va_low__unused_h181a_low_buf  ),
    .b1 ( ab_ram[5]      ),
    .b2 ( ab_mux_ram[5]  ),
    .x  ( u_va_low__va_mux_x[5]    )
);

assign u_va_low__pin_va[5] = ~u_va_low__va_mux_x[5]; // g181b
jt054156_t5a u_g46(
    .a1 ( u_va_low__va_a1[6]       ),
    .a2 ( u_va_low__va_a2[6]       ),
    .s1 ( u_va_low__unused_h181a_low_n    ),
    .s2 ( u_va_low__unused_h181a_low_buf  ),
    .s5 ( u_va_low__unused_k209a_low_n    ),
    .s6 ( u_va_low__unused_k209a_low_buf  ),
    .s3 ( u_va_low__unused_h181a_low_n    ),
    .s4 ( u_va_low__unused_h181a_low_buf  ),
    .b1 ( ab_ram[6]      ),
    .b2 ( ab_mux_ram[6]  ),
    .x  ( u_va_low__va_mux_x[6]    )
);

assign u_va_low__pin_va[6] = ~u_va_low__va_mux_x[6]; // d187a
jt054156_t5a u_g68a(
    .a1 ( u_va_low__va_a1[7]       ),
    .a2 ( u_va_low__va_a2[7]       ),
    .s1 ( u_va_low__unused_h181a_high_n   ),
    .s2 ( u_va_low__unused_h181a_high_buf ),
    .s5 ( u_va_low__unused_k209a_high_n   ),
    .s6 ( u_va_low__unused_k209a_high_buf ),
    .s3 ( u_va_low__unused_h181a_high_n   ),
    .s4 ( u_va_low__unused_h181a_high_buf ),
    .b1 ( ab_ram[7]      ),
    .b2 ( ab_mux_ram[7]  ),
    .x  ( u_va_low__va_mux_x[7]    )
);

assign u_va_low__pin_va[7] = ~u_va_low__va_mux_x[7]; // d174a
jt054156_t5a u_g71(
    .a1 ( u_va_low__va_a1[8]       ),
    .a2 ( u_va_low__va_a2[8]       ),
    .s1 ( u_va_low__unused_h181a_high_n   ),
    .s2 ( u_va_low__unused_h181a_high_buf ),
    .s5 ( u_va_low__unused_k209a_high_n   ),
    .s6 ( u_va_low__unused_k209a_high_buf ),
    .s3 ( u_va_low__unused_h181a_high_n   ),
    .s4 ( u_va_low__unused_h181a_high_buf ),
    .b1 ( ab_ram[8]      ),
    .b2 ( ab_mux_ram[8]  ),
    .x  ( u_va_low__va_mux_x[8]    )
);

assign u_va_low__pin_va[8] = ~u_va_low__va_mux_x[8]; // d175b
jt054156_t5a u_g73a(
    .a1 ( u_va_low__va_a1[9]       ),
    .a2 ( u_va_low__va_a2[9]       ),
    .s1 ( u_va_low__unused_h181a_high_n   ),
    .s2 ( u_va_low__unused_h181a_high_buf ),
    .s5 ( u_va_low__unused_k209a_high_n   ),
    .s6 ( u_va_low__unused_k209a_high_buf ),
    .s3 ( u_va_low__unused_h181a_high_n   ),
    .s4 ( u_va_low__unused_h181a_high_buf ),
    .b1 ( ab_ram[9]      ),
    .b2 ( ab_mux_ram[9]  ),
    .x  ( u_va_low__va_mux_x[9]    )
);

assign u_va_low__pin_va[9] = ~u_va_low__va_mux_x[9]; // b126b
jt054156_t5a u_g76(
    .a1 ( u_va_low__va_a1[10]      ),
    .a2 ( u_va_low__va_a2[10]      ),
    .s1 ( u_va_low__unused_h181a_high_n   ),
    .s2 ( u_va_low__unused_h181a_high_buf ),
    .s5 ( u_va_low__unused_k209a_high_n   ),
    .s6 ( u_va_low__unused_k209a_high_buf ),
    .s3 ( u_va_low__unused_h181a_high_n   ),
    .s4 ( u_va_low__unused_h181a_high_buf ),
    .b1 ( ab_ram[10]     ),
    .b2 ( ab_mux_ram[10] ),
    .x  ( u_va_low__va_mux_x[10]   )
);

assign u_va_low__pin_va[10] = ~u_va_low__va_mux_x[10]; // b126a
assign pin_va[10:0] = u_va_low__pin_va;
// End inlined jt054156_page10_va_low u_va_low

// Inlined jt054156_page10_va_high u_va_high
wire [16:11] u_va_high__pin_va;
wire u_va_high__unused_k209a_n;
wire u_va_high__unused_pin_sz_n;
wire [16:11] u_va_high__va_mux_x;
wire [5:0]   u_va_high__a1_src, u_va_high__a2_src;

assign u_va_high__a1_src[0] = pagex[0];
assign u_va_high__a1_src[1] = pagex[1];
assign u_va_high__a1_src[2] = pagex[2];
assign u_va_high__a1_src[3] = pagey[0];
assign u_va_high__a1_src[4] = pagey[1];
assign u_va_high__a1_src[5] = pagey[2];

assign u_va_high__a2_src = reg30_d;

assign u_va_high__unused_k209a_n = ~k209a; // h218b
assign u_va_high__unused_pin_sz_n = ~pin_sz; // h218a
assign u_va_high__va_mux_x[11] = ~(k209a ? (pin_sz ? u_va_high__a1_src[0] : u_va_high__a2_src[0]) : (pin_sz ? reg32_d[0] : reg32_d[0])); // h214a
assign u_va_high__pin_va[11] = ~u_va_high__va_mux_x[11]; // g214a
assign u_va_high__va_mux_x[12] = ~(k209a ? (pin_sz ? u_va_high__a1_src[1] : u_va_high__a2_src[1]) : (pin_sz ? reg32_d[1] : reg32_d[1])); // h209a
assign u_va_high__pin_va[12] = ~u_va_high__va_mux_x[12]; // g205a
assign u_va_high__va_mux_x[13] = ~(k209a ? (pin_sz ? u_va_high__a1_src[2] : u_va_high__a2_src[2]) : (pin_sz ? reg32_d[2] : reg32_d[2])); // h212
assign u_va_high__pin_va[13] = ~u_va_high__va_mux_x[13]; // g205b
assign u_va_high__va_mux_x[14] = ~(k209a ? (pin_sz ? u_va_high__a1_src[3] : u_va_high__a2_src[3]) : (pin_sz ? reg32_d[3] : reg32_d[3])); // h203a
assign u_va_high__pin_va[14] = ~u_va_high__va_mux_x[14]; // g200a
assign u_va_high__va_mux_x[15] = ~(k209a ? (pin_sz ? u_va_high__a1_src[4] : u_va_high__a2_src[4]) : (pin_sz ? reg32_d[4] : reg32_d[4])); // h201
assign u_va_high__pin_va[15] = ~u_va_high__va_mux_x[15]; // g200b
assign u_va_high__va_mux_x[16] = ~(k209a ? (pin_sz ? u_va_high__a1_src[5] : u_va_high__a2_src[5]) : (pin_sz ? reg32_d[5] : reg32_d[5])); // h198a
assign u_va_high__pin_va[16] = ~u_va_high__va_mux_x[16]; // g201b
assign pin_va[16:11] = u_va_high__pin_va;
// End inlined jt054156_page10_va_high u_va_high
// End inlined jt054156_page10_vram_addr u_vram_addr

endmodule


// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054156_vram_ctrl.v
// -----------------------------------------------------------------------------

// Connected VRAM control/address fragment.
//
// This ties the shared page-6 M191A source into both the page-10 VRAM address
// muxes and the page-9 VRAM data strobe/chip-select control path.

module jt054156_vram_ctrl(
    input  wire        reset2_n,
    input  wire        pin_clk,
    input  wire        pin_cram,
    input  wire        pin_nvcs,
    input  wire        pin_nrd_inv,
    input  wire        pin_sz,
    input  wire [13:1] pin_ab,
    input  wire [3:0]  n53_x_n,
    input  wire [7:0]  reg0_db,
    input  wire [7:0]  reg6_db,
    input  wire [3:0]  reg8_db,
    input  wire [5:0]  regc_db,
    input  wire        regc_db0_buf,
    input  wire        regc_db1_buf,
    input  wire [5:0]  reg30_d,
    input  wire [5:0]  reg32_d,
    input  wire        dclk3,
    input  wire        hcnt0,
    input  wire        n186_x0_n,
    input  wire        n186_x2_n,
    input  wire        n186_x3_n,
    input  wire        n186_x2t_n,
    input  wire        n186_x3t_n,
    input  wire        p140_q,
    input  wire        p140_xq,
    input  wire [8:3]  scrollx,
    input  wire [8:0]  scrolly,
    input  wire [2:0]  pagex,
    input  wire [2:0]  pagey,
    input  wire [10:0] ab_ram,
    input  wire [10:0] ab_mux_ram,
    input  wire        p113b_y,
    input  wire        p170b_y,

    output wire [16:0] pin_va,
    output wire        pin_vd_dir_low,
    output wire        pin_vd_dir_mid,
    output wire        pin_vd_dir_high,
    output wire        pin_oe0,
    output wire        pin_oe1,
    output wire        pin_oe2,
    output wire        pin_we0,
    output wire        pin_we1,
    output wire        pin_we2,
    output wire        pin_csz1,
    output wire        pin_cs1,
    output wire        pin_csz2,
    output wire        pin_cs2,
    output wire        k209a,
    output wire        h181a,
    output wire        m191a,
    output wire        pin_namp,
    output wire        m201_xq,
    output wire        m212a_y,
    output wire        k206a_y,
    output wire        k210b_y
);

wire h176a_y, g170a_y, k207b_y;
wire m200a_y, m200b_y;
wire n194b_y, n190b_y, n191a_y;
wire n195a_y, n200b_y, n196b_y;

jt054156_vram_addr_ctrl u_addr_ctrl(
    .reset2_n      ( reset2_n      ),
    .reg0_db0      ( reg0_db[0]    ),
    .reg0_db4      ( reg0_db[4]    ),
    .reg0_db7      ( reg0_db[7]    ),
    .p140_xq       ( p140_xq       ),
    .hcnt0         ( hcnt0         ),
    .reg8_db       ( reg8_db       ),
    .regc_db       ( regc_db[5:2]  ),
    .regc_db0      ( regc_db[0]    ),
    .regc_db1_buf  ( regc_db1_buf  ),
    .n186_x2t_n    ( n186_x2t_n    ),
    .n186_x3t_n    ( n186_x3t_n    ),
    .pin_sz        ( pin_sz        ),
    .n186_x2_n     ( n186_x2_n     ),
    .n186_x3_n     ( n186_x3_n     ),
    .scrollx       ( scrollx       ),
    .scrolly       ( scrolly       ),
    .pagex         ( pagex         ),
    .pagey         ( pagey         ),
    .ab_ram        ( ab_ram        ),
    .ab_mux_ram    ( ab_mux_ram    ),
    .reg30_d       ( reg30_d       ),
    .reg32_d       ( reg32_d       ),
    .pin_va        ( pin_va        ),
    .k209a         ( k209a         ),
    .h181a         ( h181a         ),
    .h176a_y       ( h176a_y       ),
    .g170a_y       ( g170a_y       ),
    .k207b_y       ( k207b_y       ),
    .m191a         ( m191a         ),
    .pin_namp      ( pin_namp      ),
    .m201_xq       ( m201_xq       ),
    .m200a_y       ( m200a_y       ),
    .m200b_y       ( m200b_y       )
);

// Inlined jt054156_page09_vram_ctrl u_page09_ctrl
wire u_page09_ctrl__reg0_db0;
wire u_page09_ctrl__reg0_db1;
wire u_page09_ctrl__reg0_db7;
wire u_page09_ctrl__reg6_db3;
wire u_page09_ctrl__j208b_y, u_page09_ctrl__j209a_y, u_page09_ctrl__j207a_y, u_page09_ctrl__j209b_y;

// Inlined jt054156_page09_vram_t5a_source u_t5a_source
wire u_t5a_source__pin_ab1;
wire u_t5a_source__pin_ab12;
wire u_t5a_source__unused_n57a_y;
wire u_t5a_source__unused_n58b_y;
wire u_t5a_source__unused_n59a_y;
wire u_t5a_source__unused_n60b_y;
wire u_t5a_source__unused_n59b_y;
wire u_t5a_source__unused_n69b_y;
wire u_t5a_source__unused_n58a_y;
wire u_t5a_source__unused_n68a_y;
wire u_t5a_source__unused_n60a_x;
wire u_t5a_source__unused_n65a_x;
wire u_t5a_source__unused_n63_x;
assign u_t5a_source__unused_n58b_y = ~u_t5a_source__pin_ab12; // n58b
assign u_t5a_source__unused_n57a_y = ~u_t5a_source__pin_ab1; // n57a
assign u_t5a_source__unused_n59a_y = ~regc_db0_buf; // n59a
assign u_t5a_source__unused_n60b_y = ~regc_db1_buf; // n60b
assign u_t5a_source__unused_n59b_y = ~regc_db0_buf; // n59b
assign u_t5a_source__unused_n69b_y = ~regc_db1_buf; // n69b
assign u_t5a_source__unused_n58a_y = ~regc_db0_buf; // n58a
assign u_t5a_source__unused_n68a_y = ~regc_db1_buf; // n68a
assign u_t5a_source__unused_n60a_x = ~(regc_db1_buf ? (regc_db0_buf ? n53_x_n[2] : n53_x_n[2]) : (regc_db0_buf ? u_t5a_source__unused_n58b_y : u_t5a_source__pin_ab1)); // n60a
assign n195a_y = ~u_t5a_source__unused_n60a_x; // n195a
assign u_t5a_source__unused_n65a_x = ~(regc_db1_buf ? (regc_db0_buf ? n53_x_n[0] : n53_x_n[0]) : (regc_db0_buf ? u_t5a_source__unused_n58b_y : u_t5a_source__unused_n57a_y)); // n65a
assign n200b_y = ~u_t5a_source__unused_n65a_x; // n200b
assign u_t5a_source__unused_n63_x = ~(regc_db1_buf ? (regc_db0_buf ? n53_x_n[1] : n53_x_n[1]) : (regc_db0_buf ? u_t5a_source__unused_n58b_y : u_t5a_source__unused_n57a_y)); // n63
assign n196b_y = ~u_t5a_source__unused_n63_x; // n196b
assign u_t5a_source__pin_ab1 = pin_ab[1];
assign u_t5a_source__pin_ab12 = pin_ab[12];
// End inlined jt054156_page09_vram_t5a_source u_t5a_source

// Inlined jt054156_page09_vram_timing_source u_timing_source
wire u_timing_source__unused_k216a_y;
wire u_timing_source__unused_k217b_y;
wire u_timing_source__unused_m212b_y;
wire u_timing_source__unused_n200a_y;
wire u_timing_source__unused_n192b_x;
wire u_timing_source__unused_n193a_x;
wire u_timing_source__unused_n213b_y;
reg u_timing_source__unused_n208_q;
wire u_timing_source__unused_n208_nq;
wire u_timing_source__unused_n201a_y;
reg u_timing_source__unused_n196a_q;
wire u_timing_source__unused_n196a_nq;
wire u_timing_source__unused_n213a_y;
reg u_timing_source__unused_n202a_q;
wire u_timing_source__unused_n202a_nq;
wire u_timing_source__unused_n201b_y;
wire    u_timing_source__vcc = 1'b1;
assign u_timing_source__unused_n200a_y = ~u_page09_ctrl__reg0_db0; // n200a
assign u_timing_source__unused_n192b_x = u_page09_ctrl__reg0_db0 ? ~dclk3 : ~pin_clk; // n192b
assign u_timing_source__unused_n193a_x = u_page09_ctrl__reg0_db0 ? ~p140_q : ~dclk3; // n193a
assign u_timing_source__unused_n213b_y = ~u_timing_source__unused_n193a_x; // n213b
assign u_timing_source__unused_n201a_y = ~|{pin_nvcs,pin_nrd_inv}; // n201a
always @(posedge n186_x0_n or negedge u_timing_source__unused_n201a_y) begin
    if (!u_timing_source__unused_n201a_y) begin
        u_timing_source__unused_n196a_q <= 1'b0;
    end else begin
        u_timing_source__unused_n196a_q <= u_timing_source__unused_n201a_y;
    end
end // n196a

assign u_timing_source__unused_n196a_nq = ~u_timing_source__unused_n196a_q; // n196a
always @(posedge u_timing_source__unused_n192b_x or negedge u_timing_source__unused_n201b_y) begin
    if (!u_timing_source__unused_n201b_y) begin
        u_timing_source__unused_n208_q <= 1'b0;
    end else begin
        u_timing_source__unused_n208_q <= u_timing_source__unused_n213b_y;
    end
end // n208

assign u_timing_source__unused_n208_nq = ~u_timing_source__unused_n208_q; // n208
assign u_timing_source__unused_m212b_y = m191a; // m212b
assign m212a_y = u_timing_source__unused_n208_q & u_timing_source__unused_m212b_y; // m212a
assign u_timing_source__unused_n213a_y = ~m212a_y; // n213a
always @(posedge u_timing_source__unused_n213a_y or negedge u_timing_source__unused_n201a_y) begin
    if (!u_timing_source__unused_n201a_y) begin
        u_timing_source__unused_n202a_q <= 1'b0;
    end else begin
        u_timing_source__unused_n202a_q <= u_timing_source__vcc;
    end
end // n202a

assign u_timing_source__unused_n202a_nq = ~u_timing_source__unused_n202a_q; // n202a
assign u_timing_source__unused_n201b_y = u_timing_source__unused_n196a_q & u_timing_source__unused_n202a_nq; // n201b
assign u_timing_source__unused_k216a_y = ~u_page09_ctrl__reg0_db7; // k216a
assign k210b_y = u_timing_source__unused_m212b_y & u_timing_source__unused_k216a_y; // k210b
assign u_timing_source__unused_k217b_y = ~u_timing_source__unused_m212b_y; // k217b
assign k206a_y = ~|{u_timing_source__unused_k217b_y,pin_nrd_inv}; // k206a
// End inlined jt054156_page09_vram_timing_source u_timing_source

// Inlined jt054156_page09_vram_strobes u_strobes
wire u_strobes__k201b_y, u_strobes__j205a_y, u_strobes__j205b_y;
wire u_strobes__reg0_db1_n;

assign n194b_y = ~|{pin_cram,pin_nvcs,p113b_y,n195a_y}; // n194b
assign n190b_y = ~|{pin_cram,pin_nvcs,p170b_y,n200b_y}; // n190b
assign n191a_y = ~|{pin_cram,pin_nvcs,pin_nrd_inv,n196b_y}; // n191a
assign u_strobes__reg0_db1_n = ~u_page09_ctrl__reg0_db1; // j217b
assign pin_vd_dir_low = ~&{n194b_y,k206a_y}; // k206b
assign u_strobes__k201b_y = ~&{pin_nrd_inv,n194b_y}; // k201b
assign pin_oe0 = k210b_y & u_strobes__k201b_y; // g203b
assign pin_we0 = ~&{n194b_y,m212a_y}; // k212b
assign pin_vd_dir_mid = ~&{n190b_y,k206a_y}; // j204a
assign u_strobes__j205a_y = ~&{n190b_y,pin_nrd_inv}; // j205a
assign pin_oe1 = k210b_y & u_strobes__j205a_y; // g201a
assign u_page09_ctrl__j208b_y = ~&{n190b_y,u_page09_ctrl__reg0_db1}; // j208b
assign u_page09_ctrl__j209a_y = ~&{n190b_y,u_strobes__reg0_db1_n}; // j209a
assign pin_we1 = ~&{n190b_y,m212a_y}; // j210a
assign pin_vd_dir_high = ~&{n191a_y,k206a_y}; // j204b
assign u_strobes__j205b_y = ~&{n191a_y,pin_nrd_inv}; // j205b
assign pin_oe2 = k210b_y & u_strobes__j205b_y; // g203a
assign u_page09_ctrl__j207a_y = ~&{n191a_y,u_page09_ctrl__reg0_db1}; // j207a
assign u_page09_ctrl__j209b_y = ~&{n191a_y,u_strobes__reg0_db1_n}; // j209b
assign pin_we2 = ~&{n191a_y,m212a_y}; // j210b
// End inlined jt054156_page09_vram_strobes u_strobes

// Inlined jt054156_page09_vram_cs u_cs
wire u_cs__unused_k214b_y;
wire u_cs__unused_k211a_y;
wire u_cs__unused_k213b_y;
wire u_cs__unused_k213a_y;
wire u_cs__unused_g202b_y;
assign u_cs__unused_k214b_y = u_page09_ctrl__reg0_db7 & u_page09_ctrl__reg0_db1; // k214b
assign u_cs__unused_k211a_y = pin_sz | u_cs__unused_k214b_y; // k211a
assign u_cs__unused_k213b_y = ~&{u_page09_ctrl__reg6_db3,u_cs__unused_k211a_y}; // k213b
assign u_cs__unused_k213a_y = u_page09_ctrl__reg6_db3 & u_cs__unused_k211a_y; // k213a
assign u_cs__unused_g202b_y = ~k210b_y; // g202b
assign pin_csz1 = k210b_y ? u_cs__unused_k213b_y : u_page09_ctrl__j208b_y; // g208
assign pin_cs1 = k210b_y ? u_cs__unused_k213a_y : u_page09_ctrl__j209a_y; // g208
assign pin_csz2 = k210b_y ? u_cs__unused_k213b_y : u_page09_ctrl__j207a_y; // g208
assign pin_cs2 = k210b_y ? u_cs__unused_k213a_y : u_page09_ctrl__j209b_y; // g208
// End inlined jt054156_page09_vram_cs u_cs
assign u_page09_ctrl__reg0_db0 = reg0_db[0];
assign u_page09_ctrl__reg0_db1 = reg0_db[1];
assign u_page09_ctrl__reg0_db7 = reg0_db[7];
assign u_page09_ctrl__reg6_db3 = reg6_db[3];
// End inlined jt054156_page09_vram_ctrl u_page09_ctrl

endmodule

