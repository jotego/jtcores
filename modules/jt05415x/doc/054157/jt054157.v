// Simplified Verilog deliverable for Konami 054157.
// Derived from modules/jt05415x/doc/054157/jt054157_all.v for jtcores issue #37; tracked/adapted in jtcores issue #53.
// Simple continuous-assignment cells are inlined with schematic instance comments.


// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054157_page04_decode_integrated.v
// -----------------------------------------------------------------------------

// Page 4 integrated decode-cone wrapper.
//
// Composes the visually checked page-4 N4N/N8B decode cones into one local
// boundary. The ACOL2/ACOL3/BCOL2/BCOL3/CCOL2/CCOL3/PIN57/PIN51/PIN53/PIN55/PIN52/PIN58/PIN56/PIN54/DCOL3/DCOL4 selector/data
// rails are traced to local HOF*_F and FDS outputs.

module jt054157_page04_decode_integrated(
    input  wire [2:0] hofsa_f,
    input  wire [2:0] hofs_b_f,
    input  wire [2:0] hofsc_f,
    input  wire [2:0] hofsd_f,
    input  wire [3:0] m63_q,
    input  wire [3:0] p43_q,
    input  wire [3:0] j82_q,
    input  wire [3:0] k75_q,
    input  wire [3:0] p70_q,
    input  wire [3:0] r70_q,
    input  wire [3:0] j98_q,
    input  wire [3:0] k85_q,
    input  wire [3:0] j70_q,
    input  wire [3:0] l95_q,
    input  wire [3:0] n70_q,
    input  wire [3:0] n55_q,
    input  wire [3:0] f164_q,
    input  wire [3:0] g206_q,
    input  wire [3:0] e141_q,
    input  wire [3:0] e180_q,
    input  wire [3:0] e153_q,
    input  wire [3:0] d180_q,
    input  wire [3:0] f153_q,
    input  wire [3:0] f195_q,
    input  wire [3:0] d141_q,
    input  wire [3:0] d131_q,
    input  wire [3:0] c180_q,
    input  wire [3:0] b180_q,
    input  wire [3:0] b153_q,
    input  wire [3:0] a139_q,
    input  wire [3:0] c123_q,
    input  wire [3:0] c153_q,
    input  wire [3:0] j15_q,
    input  wire [3:0] h15_q,
    input  wire [3:0] m83_q,
    input  wire [3:0] n96_q,
    output wire       acol2,
    output wire       bcol2,
    output wire       ccol2,
    output wire       ccol3,
    output wire       acol3,
    output wire       bcol3,
    output wire       pin57,
    output wire       pin51,
    output wire       pin53,
    output wire       pin55,
    output wire       pin52,
    output wire       pin58,
    output wire       pin56,
    output wire       pin54,
    output wire       dcol3,
    output wire       dcol4
);

wire       acol2_hofsa0_l, acol2_hofsa0_h;
wire       acol2_hofsa1_l, acol2_hofsa1_h;
wire       acol2_hofsa2_l, acol2_hofsa2_h;
wire       acol3_hofsa0_l, acol3_hofsa0_h;
wire       acol3_hofsa1_l, acol3_hofsa1_h;
wire       acol3_hofsa2_l, acol3_hofsa2_h;
wire       bcol2_hofsb0_l, bcol2_hofsb0_h;
wire       bcol2_hofsb1_l, bcol2_hofsb1_h;
wire       bcol2_hofsb2_l, bcol2_hofsb2_h;
wire       bcol3_hofsb0_l, bcol3_hofsb0_h;
wire       bcol3_hofsb1_l, bcol3_hofsb1_h;
wire       bcol3_hofsb2_l, bcol3_hofsb2_h;
wire       ccol2_hofsc0_l, ccol2_hofsc0_h;
wire       ccol2_hofsc1_l, ccol2_hofsc1_h;
wire       ccol2_hofsc2_l, ccol2_hofsc2_h;
wire       ccol3_hofsc0_l, ccol3_hofsc0_h;
wire       ccol3_hofsc1_l, ccol3_hofsc1_h;
wire       ccol3_hofsc2_l, ccol3_hofsc2_h;
wire       pin57_hofsd0_l, pin57_hofsd0_h;
wire       pin57_hofsd1_l, pin57_hofsd1_h;
wire       pin57_hofsd2_l, pin57_hofsd2_h;
wire       pin51_hofsa0_l, pin51_hofsa0_h;
wire       pin51_hofsa1_l, pin51_hofsa1_h;
wire       pin51_hofsa2_l, pin51_hofsa2_h;
wire       pin53_hofsb0_l, pin53_hofsb0_h;
wire       pin53_hofsb1_l, pin53_hofsb1_h;
wire       pin53_hofsb2_l, pin53_hofsb2_h;
wire       pin55_hofsc0_l, pin55_hofsc0_h;
wire       pin55_hofsc1_l, pin55_hofsc1_h;
wire       pin55_hofsc2_l, pin55_hofsc2_h;
wire       pin52_hofsa0_l, pin52_hofsa0_h;
wire       pin52_hofsa1_l, pin52_hofsa1_h;
wire       pin52_hofsa2_l, pin52_hofsa2_h;
wire       pin58_hofsd0_l, pin58_hofsd0_h;
wire       pin58_hofsd1_l, pin58_hofsd1_h;
wire       pin58_hofsd2_l, pin58_hofsd2_h;
wire       pin56_hofsc0_l, pin56_hofsc0_h;
wire       pin56_hofsc1_l, pin56_hofsc1_h;
wire       pin56_hofsc2_l, pin56_hofsc2_h;
wire       pin54_hofsb0_l, pin54_hofsb0_h;
wire       pin54_hofsb1_l, pin54_hofsb1_h;
wire       pin54_hofsb2_l, pin54_hofsb2_h;
wire       dcol3_hofsd0_l, dcol3_hofsd0_h;
wire       dcol3_hofsd1_l, dcol3_hofsd1_h;
wire       dcol3_hofsd2_l, dcol3_hofsd2_h;
wire       dcol4_hofsd0_l, dcol4_hofsd0_h;
wire       dcol4_hofsd1_l, dcol4_hofsd1_h;
wire       dcol4_hofsd2_l, dcol4_hofsd2_h;
wire [3:0] p39a_d, p39b_d, p37a_d, p37b_d;
wire [3:0] p33b_d, p33a_d, p35b_d, p35a_d;
wire [3:0] p88b_d, p90b_d, p89a_d, p91a_d;
wire [3:0] p80a_d, p82a_d, p82b_d, p87a_d;
wire [3:0] r37b_d, r47a_d, r47b_d, r51b_d;
wire [3:0] r37a_d, r49a_d, r49b_d, r51a_d;
wire [3:0] r97a_d, r99a_d, r98b_d, r100b_d;
wire [3:0] r82a_d, r86b_d, r84a_d, r86a_d;
wire [3:0] p97b_d, p97a_d, p99b_d, p99a_d;
wire [3:0] p106a_d, p104b_d, p104a_d, p106b_d;
wire [3:0] p11a_d, p14a_d, p16b_d, p18b_d;
wire [3:0] p16a_d, p18a_d, p23b_d, p23a_d;
wire [3:0] g178b_d, g178a_d, g180b_d, g180a_d;
wire [3:0] g183b_d, g183a_d, g185b_d, g185a_d;
wire [3:0] e204b_d, e206a_d, d210b_d, d210a_d;
wire [3:0] e204a_d, e208a_d, e207b_d, e209b_d;
wire [3:0] e191a_d, e192b_d, e193a_d, e195a_d;
wire [3:0] e194b_d, e196b_d, e197a_d, e198b_d;
wire [3:0] f178b_d, f180b_d, f176a_d, f179a_d;
wire [3:0] f186a_d, f188a_d, f186b_d, f188b_d;
wire [3:0] d193b_d, d193a_d, d195b_d, d197b_d;
wire [3:0] d195a_d, d197a_d, d199b_d, d199a_d;
wire [3:0] a163b_d, a165b_d, a178b_d, a178a_d;
wire [3:0] b176b_d, b176a_d, a163a_d, a165a_d;
wire [3:0] b191b_d, b191a_d, b193b_d, b193a_d;
wire [3:0] b195b_d, b195a_d, b197b_d, b197a_d;
wire [3:0] c192a_d, c194a_d, c193b_d, c195b_d;
wire [3:0] c196a_d, c198a_d, c197b_d, c199b_d;
wire [3:0] r6a_d, r8a_d, r8b_d, r13a_d;
wire [3:0] r18b_d, r20b_d, r18a_d, r20a_d;
wire [3:0] m102b_d, m100b_d, m101a_d, m93a_d;
wire [3:0] m106b_d, m105a_d, m104b_d, m103a_d;

assign acol2_hofsa0_l = ~hofsa_f[0]; // k40b
assign acol2_hofsa0_h = ~acol2_hofsa0_l; // p28a
assign acol2_hofsa1_l = ~hofsa_f[1]; // k39a
assign acol2_hofsa1_h = ~acol2_hofsa1_l; // p29a
assign acol2_hofsa2_l = ~hofsa_f[2]; // k40a
assign acol2_hofsa2_h = ~acol2_hofsa2_l; // p29b
assign acol3_hofsa0_l = ~hofsa_f[0]; // k74b
assign acol3_hofsa0_h = ~acol3_hofsa0_l; // r85b
assign acol3_hofsa1_l = ~hofsa_f[1]; // k73b
assign acol3_hofsa1_h = ~acol3_hofsa1_l; // r84b
assign acol3_hofsa2_l = ~hofsa_f[2]; // k106b
assign acol3_hofsa2_h = ~acol3_hofsa2_l; // p93b
assign bcol2_hofsb0_l = ~hofs_b_f[0]; // k39b
assign bcol2_hofsb0_h = ~bcol2_hofsb0_l; // r36a
assign bcol2_hofsb1_l = ~hofs_b_f[1]; // k38b
assign bcol2_hofsb1_h = ~bcol2_hofsb1_l; // r46a
assign bcol2_hofsb2_l = ~hofs_b_f[2]; // k38a
assign bcol2_hofsb2_h = ~bcol2_hofsb2_l; // r46b
assign bcol3_hofsb0_l = ~hofs_b_f[0]; // k107b
assign bcol3_hofsb0_h = ~bcol3_hofsb0_l; // r103b
assign bcol3_hofsb1_l = ~hofs_b_f[1]; // k106a
assign bcol3_hofsb1_h = ~bcol3_hofsb1_l; // r102b
assign bcol3_hofsb2_l = ~hofs_b_f[2]; // k107a
assign bcol3_hofsb2_h = ~bcol3_hofsb2_l; // r102a
assign ccol2_hofsc0_l = ~hofsc_f[0]; // l11a
assign ccol2_hofsc0_h = ~ccol2_hofsc0_l; // p10a
assign ccol2_hofsc1_l = ~hofsc_f[1]; // l11b
assign ccol2_hofsc1_h = ~ccol2_hofsc1_l; // p12b
assign ccol2_hofsc2_l = ~hofsc_f[2]; // l12b
assign ccol2_hofsc2_h = ~ccol2_hofsc2_l; // p11b
assign ccol3_hofsc0_l = ~hofsc_f[0]; // l83a
assign ccol3_hofsc0_h = ~ccol3_hofsc0_l; // r88b
assign ccol3_hofsc1_l = ~hofsc_f[1]; // l83b
assign ccol3_hofsc1_h = ~ccol3_hofsc1_l; // r88a
assign ccol3_hofsc2_l = ~hofsc_f[2]; // l107b
assign ccol3_hofsc2_h = ~ccol3_hofsc2_l; // r101a
assign pin57_hofsd0_l = ~hofsd_f[0]; // g169a
assign pin57_hofsd0_h = ~pin57_hofsd0_l; // g177a
assign pin57_hofsd1_l = ~hofsd_f[1]; // g170a
assign pin57_hofsd1_h = ~pin57_hofsd1_l; // g182b
assign pin57_hofsd2_l = ~hofsd_f[2]; // g177b
assign pin57_hofsd2_h = ~pin57_hofsd2_l; // g182a
assign pin51_hofsa0_l = ~hofsa_f[0]; // d167a
assign pin51_hofsa0_h = ~pin51_hofsa0_l; // e211b
assign pin51_hofsa1_l = ~hofsa_f[1]; // e166a
assign pin51_hofsa1_h = ~pin51_hofsa1_l; // e211a
assign pin51_hofsa2_l = ~hofsa_f[2]; // d167b
assign pin51_hofsa2_h = ~pin51_hofsa2_l; // e210a
assign pin53_hofsb0_l = ~hofs_b_f[0]; // e166b
assign pin53_hofsb0_h = ~pin53_hofsb0_l; // e200b
assign pin53_hofsb1_l = ~hofs_b_f[1]; // e167a
assign pin53_hofsb1_h = ~pin53_hofsb1_l; // e200a
assign pin53_hofsb2_l = ~hofs_b_f[2]; // e165a
assign pin53_hofsb2_h = ~pin53_hofsb2_l; // e199a
assign pin55_hofsc0_l = ~hofsc_f[0]; // f176b
assign pin55_hofsc0_h = ~pin55_hofsc0_l; // f182b
assign pin55_hofsc1_l = ~hofsc_f[1]; // f177b
assign pin55_hofsc1_h = ~pin55_hofsc1_l; // f181a
assign pin55_hofsc2_l = ~hofsc_f[2]; // g170b
assign pin55_hofsc2_h = ~pin55_hofsc2_l; // f182a
assign pin52_hofsa0_l = ~hofsa_f[0]; // d166b
assign pin52_hofsa0_h = ~pin52_hofsa0_l; // d202a
assign pin52_hofsa1_l = ~hofsa_f[1]; // d166a
assign pin52_hofsa1_h = ~pin52_hofsa1_l; // d201a
assign pin52_hofsa2_l = ~hofsa_f[2]; // d165a
assign pin52_hofsa2_h = ~pin52_hofsa2_l; // d202b
assign pin58_hofsd0_l = ~hofsd_f[0]; // b175b
assign pin58_hofsd0_h = ~pin58_hofsd0_l; // a180b
assign pin58_hofsd1_l = ~hofsd_f[1]; // c176b
assign pin58_hofsd1_h = ~pin58_hofsd1_l; // a180a
assign pin58_hofsd2_l = ~hofsd_f[2]; // a181a
assign pin58_hofsd2_h = ~pin58_hofsd2_l; // a181b
assign pin56_hofsc0_l = ~hofsc_f[0]; // c200a
assign pin56_hofsc0_h = ~pin56_hofsc0_l; // a193b
assign pin56_hofsc1_l = ~hofsc_f[1]; // c201b
assign pin56_hofsc1_h = ~pin56_hofsc1_l; // a193a
assign pin56_hofsc2_l = ~hofsc_f[2]; // c177b
assign pin56_hofsc2_h = ~pin56_hofsc2_l; // b175a
assign pin54_hofsb0_l = ~hofs_b_f[0]; // d165b
assign pin54_hofsb0_h = ~pin54_hofsb0_l; // c202b
assign pin54_hofsb1_l = ~hofs_b_f[1]; // d201b
assign pin54_hofsb1_h = ~pin54_hofsb1_l; // c202a
assign pin54_hofsb2_l = ~hofs_b_f[2]; // d164a
assign pin54_hofsb2_h = ~pin54_hofsb2_l; // c201a
assign dcol3_hofsd0_l = ~hofsd_f[0]; // l10a
assign dcol3_hofsd0_h = ~dcol3_hofsd0_l; // r6b
assign dcol3_hofsd1_l = ~hofsd_f[1]; // l10b
assign dcol3_hofsd1_h = ~dcol3_hofsd1_l; // r5a
assign dcol3_hofsd2_l = ~hofsd_f[2]; // l9a
assign dcol3_hofsd2_h = ~dcol3_hofsd2_l; // r7b
assign dcol4_hofsd0_l = ~hofsd_f[0]; // l105a
assign dcol4_hofsd0_h = ~dcol4_hofsd0_l; // m94b
assign dcol4_hofsd1_l = ~hofsd_f[1]; // l106a
assign dcol4_hofsd1_h = ~dcol4_hofsd1_l; // m93b
assign dcol4_hofsd2_l = ~hofsd_f[2]; // l106b
assign dcol4_hofsd2_h = ~dcol4_hofsd2_l; // m107a
assign p39a_d = { m63_q[3], acol2_hofsa2_l, acol2_hofsa1_l, acol2_hofsa0_l };
assign p39b_d = { m63_q[2], acol2_hofsa2_l, acol2_hofsa1_l, acol2_hofsa0_h };
assign p37a_d = { m63_q[1], acol2_hofsa2_l, acol2_hofsa1_h, acol2_hofsa0_l };
assign p37b_d = { m63_q[0], acol2_hofsa2_l, acol2_hofsa1_h, acol2_hofsa0_h };
assign p33b_d = { p43_q[3], acol2_hofsa2_h, acol2_hofsa1_l, acol2_hofsa0_l };
assign p33a_d = { p43_q[2], acol2_hofsa2_h, acol2_hofsa1_l, acol2_hofsa0_h };
assign p35b_d = { p43_q[1], acol2_hofsa2_h, acol2_hofsa1_h, acol2_hofsa0_l };
assign p35a_d = { p43_q[0], acol2_hofsa2_h, acol2_hofsa1_h, acol2_hofsa0_h };

assign p88b_d = { j82_q[3], acol3_hofsa2_l, acol3_hofsa1_l, acol3_hofsa0_l };
assign p90b_d = { j82_q[2], acol3_hofsa2_l, acol3_hofsa1_l, acol3_hofsa0_h };
assign p89a_d = { j82_q[1], acol3_hofsa2_l, acol3_hofsa1_h, acol3_hofsa0_l };
assign p91a_d = { j82_q[0], acol3_hofsa2_l, acol3_hofsa1_h, acol3_hofsa0_h };
assign p80a_d = { k75_q[3], acol3_hofsa2_h, acol3_hofsa1_l, acol3_hofsa0_l };
assign p82a_d = { k75_q[2], acol3_hofsa2_h, acol3_hofsa1_l, acol3_hofsa0_h };
assign p82b_d = { k75_q[1], acol3_hofsa2_h, acol3_hofsa1_h, acol3_hofsa0_l };
assign p87a_d = { k75_q[0], acol3_hofsa2_h, acol3_hofsa1_h, acol3_hofsa0_h };

assign r37b_d = { p70_q[3], bcol2_hofsb2_l, bcol2_hofsb1_l, bcol2_hofsb0_l };
assign r47a_d = { p70_q[2], bcol2_hofsb2_l, bcol2_hofsb1_l, bcol2_hofsb0_h };
assign r47b_d = { p70_q[1], bcol2_hofsb2_l, bcol2_hofsb1_h, bcol2_hofsb0_l };
assign r51b_d = { p70_q[0], bcol2_hofsb2_l, bcol2_hofsb1_h, bcol2_hofsb0_h };
assign r37a_d = { r70_q[3], bcol2_hofsb2_h, bcol2_hofsb1_l, bcol2_hofsb0_l };
assign r49a_d = { r70_q[2], bcol2_hofsb2_h, bcol2_hofsb1_l, bcol2_hofsb0_h };
assign r49b_d = { r70_q[1], bcol2_hofsb2_h, bcol2_hofsb1_h, bcol2_hofsb0_l };
assign r51a_d = { r70_q[0], bcol2_hofsb2_h, bcol2_hofsb1_h, bcol2_hofsb0_h };

assign r97a_d = { j98_q[3], ccol3_hofsc2_l, ccol3_hofsc1_l, ccol3_hofsc0_l };
assign r99a_d = { j98_q[2], ccol3_hofsc2_l, ccol3_hofsc1_l, ccol3_hofsc0_h };
assign r98b_d = { j98_q[1], ccol3_hofsc2_l, ccol3_hofsc1_h, ccol3_hofsc0_l };
assign r100b_d = { j98_q[0], ccol3_hofsc2_l, ccol3_hofsc1_h, ccol3_hofsc0_h };
assign r82a_d = { k85_q[3], ccol3_hofsc2_h, ccol3_hofsc1_l, ccol3_hofsc0_l };
assign r86b_d = { k85_q[2], ccol3_hofsc2_h, ccol3_hofsc1_l, ccol3_hofsc0_h };
assign r84a_d = { k85_q[1], ccol3_hofsc2_h, ccol3_hofsc1_h, ccol3_hofsc0_l };
assign r86a_d = { k85_q[0], ccol3_hofsc2_h, ccol3_hofsc1_h, ccol3_hofsc0_h };

assign p97b_d = { j70_q[3], bcol3_hofsb2_l, bcol3_hofsb1_l, bcol3_hofsb0_l };
assign p97a_d = { j70_q[2], bcol3_hofsb2_l, bcol3_hofsb1_l, bcol3_hofsb0_h };
assign p99b_d = { j70_q[1], bcol3_hofsb2_l, bcol3_hofsb1_h, bcol3_hofsb0_l };
assign p99a_d = { j70_q[0], bcol3_hofsb2_l, bcol3_hofsb1_h, bcol3_hofsb0_h };
assign p106a_d = { l95_q[3], bcol3_hofsb2_h, bcol3_hofsb1_l, bcol3_hofsb0_l };
assign p104b_d = { l95_q[2], bcol3_hofsb2_h, bcol3_hofsb1_l, bcol3_hofsb0_h };
assign p104a_d = { l95_q[1], bcol3_hofsb2_h, bcol3_hofsb1_h, bcol3_hofsb0_l };
assign p106b_d = { l95_q[0], bcol3_hofsb2_h, bcol3_hofsb1_h, bcol3_hofsb0_h };

assign p11a_d = { n70_q[3], ccol2_hofsc2_l, ccol2_hofsc1_l, ccol2_hofsc0_l };
assign p14a_d = { n70_q[2], ccol2_hofsc2_l, ccol2_hofsc1_l, ccol2_hofsc0_h };
assign p16b_d = { n70_q[1], ccol2_hofsc2_l, ccol2_hofsc1_h, ccol2_hofsc0_l };
assign p18b_d = { n70_q[0], ccol2_hofsc2_l, ccol2_hofsc1_h, ccol2_hofsc0_h };
assign p16a_d = { n55_q[3], ccol2_hofsc2_h, ccol2_hofsc1_l, ccol2_hofsc0_l };
assign p18a_d = { n55_q[2], ccol2_hofsc2_h, ccol2_hofsc1_l, ccol2_hofsc0_h };
assign p23b_d = { n55_q[1], ccol2_hofsc2_h, ccol2_hofsc1_h, ccol2_hofsc0_l };
assign p23a_d = { n55_q[0], ccol2_hofsc2_h, ccol2_hofsc1_h, ccol2_hofsc0_h };

assign g178b_d = { f164_q[3], pin57_hofsd2_l, pin57_hofsd1_l, pin57_hofsd0_l };
assign g178a_d = { f164_q[2], pin57_hofsd2_l, pin57_hofsd1_l, pin57_hofsd0_h };
assign g180b_d = { f164_q[1], pin57_hofsd2_l, pin57_hofsd1_h, pin57_hofsd0_l };
assign g180a_d = { f164_q[0], pin57_hofsd2_l, pin57_hofsd1_h, pin57_hofsd0_h };
assign g183b_d = { g206_q[3], pin57_hofsd2_h, pin57_hofsd1_l, pin57_hofsd0_l };
assign g183a_d = { g206_q[2], pin57_hofsd2_h, pin57_hofsd1_l, pin57_hofsd0_h };
assign g185b_d = { g206_q[1], pin57_hofsd2_h, pin57_hofsd1_h, pin57_hofsd0_l };
assign g185a_d = { g206_q[0], pin57_hofsd2_h, pin57_hofsd1_h, pin57_hofsd0_h };

assign e204b_d = { e141_q[3], pin51_hofsa2_l, pin51_hofsa1_l, pin51_hofsa0_l };
assign e206a_d = { e141_q[2], pin51_hofsa2_l, pin51_hofsa1_l, pin51_hofsa0_h };
assign d210b_d = { e141_q[1], pin51_hofsa2_l, pin51_hofsa1_h, pin51_hofsa0_l };
assign d210a_d = { e141_q[0], pin51_hofsa2_l, pin51_hofsa1_h, pin51_hofsa0_h };
assign e204a_d = { e180_q[3], pin51_hofsa2_h, pin51_hofsa1_l, pin51_hofsa0_l };
assign e208a_d = { e180_q[2], pin51_hofsa2_h, pin51_hofsa1_l, pin51_hofsa0_h };
assign e207b_d = { e180_q[1], pin51_hofsa2_h, pin51_hofsa1_h, pin51_hofsa0_l };
assign e209b_d = { e180_q[0], pin51_hofsa2_h, pin51_hofsa1_h, pin51_hofsa0_h };

assign e191a_d = { e153_q[3], pin53_hofsb2_l, pin53_hofsb1_l, pin53_hofsb0_l };
assign e192b_d = { e153_q[2], pin53_hofsb2_l, pin53_hofsb1_l, pin53_hofsb0_h };
assign e193a_d = { e153_q[1], pin53_hofsb2_l, pin53_hofsb1_h, pin53_hofsb0_l };
assign e195a_d = { e153_q[0], pin53_hofsb2_l, pin53_hofsb1_h, pin53_hofsb0_h };
assign e194b_d = { d180_q[3], pin53_hofsb2_h, pin53_hofsb1_l, pin53_hofsb0_l };
assign e196b_d = { d180_q[2], pin53_hofsb2_h, pin53_hofsb1_l, pin53_hofsb0_h };
assign e197a_d = { d180_q[1], pin53_hofsb2_h, pin53_hofsb1_h, pin53_hofsb0_l };
assign e198b_d = { d180_q[0], pin53_hofsb2_h, pin53_hofsb1_h, pin53_hofsb0_h };

assign f178b_d = { f153_q[3], pin55_hofsc2_l, pin55_hofsc1_l, pin55_hofsc0_l };
assign f180b_d = { f153_q[2], pin55_hofsc2_l, pin55_hofsc1_l, pin55_hofsc0_h };
assign f176a_d = { f153_q[1], pin55_hofsc2_l, pin55_hofsc1_h, pin55_hofsc0_l };
assign f179a_d = { f153_q[0], pin55_hofsc2_l, pin55_hofsc1_h, pin55_hofsc0_h };
assign f186a_d = { f195_q[3], pin55_hofsc2_h, pin55_hofsc1_l, pin55_hofsc0_l };
assign f188a_d = { f195_q[2], pin55_hofsc2_h, pin55_hofsc1_l, pin55_hofsc0_h };
assign f186b_d = { f195_q[1], pin55_hofsc2_h, pin55_hofsc1_h, pin55_hofsc0_l };
assign f188b_d = { f195_q[0], pin55_hofsc2_h, pin55_hofsc1_h, pin55_hofsc0_h };

assign d193b_d = { d141_q[3], pin52_hofsa2_l, pin52_hofsa1_l, pin52_hofsa0_l };
assign d193a_d = { d141_q[2], pin52_hofsa2_l, pin52_hofsa1_l, pin52_hofsa0_h };
assign d195b_d = { d141_q[1], pin52_hofsa2_l, pin52_hofsa1_h, pin52_hofsa0_l };
assign d197b_d = { d141_q[0], pin52_hofsa2_l, pin52_hofsa1_h, pin52_hofsa0_h };
assign d195a_d = { d131_q[3], pin52_hofsa2_h, pin52_hofsa1_l, pin52_hofsa0_l };
assign d197a_d = { d131_q[2], pin52_hofsa2_h, pin52_hofsa1_l, pin52_hofsa0_h };
assign d199b_d = { d131_q[1], pin52_hofsa2_h, pin52_hofsa1_h, pin52_hofsa0_l };
assign d199a_d = { d131_q[0], pin52_hofsa2_h, pin52_hofsa1_h, pin52_hofsa0_h };

assign a163b_d = { c180_q[3], pin58_hofsd2_l, pin58_hofsd1_l, pin58_hofsd0_l };
assign a165b_d = { c180_q[2], pin58_hofsd2_l, pin58_hofsd1_l, pin58_hofsd0_h };
assign a178b_d = { c180_q[1], pin58_hofsd2_l, pin58_hofsd1_h, pin58_hofsd0_l };
assign a178a_d = { c180_q[0], pin58_hofsd2_l, pin58_hofsd1_h, pin58_hofsd0_h };
assign b176b_d = { b180_q[3], pin58_hofsd2_h, pin58_hofsd1_l, pin58_hofsd0_l };
assign b176a_d = { b180_q[2], pin58_hofsd2_h, pin58_hofsd1_l, pin58_hofsd0_h };
assign a163a_d = { b180_q[1], pin58_hofsd2_h, pin58_hofsd1_h, pin58_hofsd0_l };
assign a165a_d = { b180_q[0], pin58_hofsd2_h, pin58_hofsd1_h, pin58_hofsd0_h };

assign b191b_d = { b153_q[3], pin56_hofsc2_l, pin56_hofsc1_l, pin56_hofsc0_l };
assign b191a_d = { b153_q[2], pin56_hofsc2_l, pin56_hofsc1_l, pin56_hofsc0_h };
assign b193b_d = { b153_q[1], pin56_hofsc2_l, pin56_hofsc1_h, pin56_hofsc0_l };
assign b193a_d = { b153_q[0], pin56_hofsc2_l, pin56_hofsc1_h, pin56_hofsc0_h };
assign b195b_d = { a139_q[3], pin56_hofsc2_h, pin56_hofsc1_l, pin56_hofsc0_l };
assign b195a_d = { a139_q[2], pin56_hofsc2_h, pin56_hofsc1_l, pin56_hofsc0_h };
assign b197b_d = { a139_q[1], pin56_hofsc2_h, pin56_hofsc1_h, pin56_hofsc0_l };
assign b197a_d = { a139_q[0], pin56_hofsc2_h, pin56_hofsc1_h, pin56_hofsc0_h };

assign c192a_d = { c123_q[3], pin54_hofsb2_l, pin54_hofsb1_l, pin54_hofsb0_l };
assign c194a_d = { c123_q[2], pin54_hofsb2_l, pin54_hofsb1_l, pin54_hofsb0_h };
assign c193b_d = { c123_q[1], pin54_hofsb2_l, pin54_hofsb1_h, pin54_hofsb0_l };
assign c195b_d = { c123_q[0], pin54_hofsb2_l, pin54_hofsb1_h, pin54_hofsb0_h };
assign c196a_d = { c153_q[3], pin54_hofsb2_h, pin54_hofsb1_l, pin54_hofsb0_l };
assign c198a_d = { c153_q[2], pin54_hofsb2_h, pin54_hofsb1_l, pin54_hofsb0_h };
assign c197b_d = { c153_q[1], pin54_hofsb2_h, pin54_hofsb1_h, pin54_hofsb0_l };
assign c199b_d = { c153_q[0], pin54_hofsb2_h, pin54_hofsb1_h, pin54_hofsb0_h };

assign r6a_d  = { j15_q[3], dcol3_hofsd2_l, dcol3_hofsd1_l, dcol3_hofsd0_l };
assign r8a_d  = { j15_q[2], dcol3_hofsd2_l, dcol3_hofsd1_l, dcol3_hofsd0_h };
assign r8b_d  = { j15_q[1], dcol3_hofsd2_l, dcol3_hofsd1_h, dcol3_hofsd0_l };
assign r13a_d = { j15_q[0], dcol3_hofsd2_l, dcol3_hofsd1_h, dcol3_hofsd0_h };
assign r18b_d = { h15_q[3], dcol3_hofsd2_h, dcol3_hofsd1_l, dcol3_hofsd0_l };
assign r20b_d = { h15_q[2], dcol3_hofsd2_h, dcol3_hofsd1_l, dcol3_hofsd0_h };
assign r18a_d = { h15_q[1], dcol3_hofsd2_h, dcol3_hofsd1_h, dcol3_hofsd0_l };
assign r20a_d = { h15_q[0], dcol3_hofsd2_h, dcol3_hofsd1_h, dcol3_hofsd0_h };

assign m102b_d = { m83_q[3], dcol4_hofsd2_l, dcol4_hofsd1_l, dcol4_hofsd0_l };
assign m100b_d = { m83_q[2], dcol4_hofsd2_l, dcol4_hofsd1_l, dcol4_hofsd0_h };
assign m101a_d = { m83_q[1], dcol4_hofsd2_l, dcol4_hofsd1_h, dcol4_hofsd0_l };
assign m93a_d  = { m83_q[0], dcol4_hofsd2_l, dcol4_hofsd1_h, dcol4_hofsd0_h };
assign m106b_d = { n96_q[3], dcol4_hofsd2_h, dcol4_hofsd1_l, dcol4_hofsd0_l };
assign m105a_d = { n96_q[2], dcol4_hofsd2_h, dcol4_hofsd1_l, dcol4_hofsd0_h };
assign m104b_d = { n96_q[1], dcol4_hofsd2_h, dcol4_hofsd1_h, dcol4_hofsd0_l };
assign m103a_d = { n96_q[0], dcol4_hofsd2_h, dcol4_hofsd1_h, dcol4_hofsd0_h };

// Inlined jt054157_page04_acol2_decode u_acol2
wire [7:0] u_acol2__unused_p30_terms;
assign u_acol2__unused_p30_terms[7] = ~&{p39a_d[3],p39a_d[2],p39a_d[1],p39a_d[0]}; // p39a
assign u_acol2__unused_p30_terms[6] = ~&{p39b_d[3],p39b_d[2],p39b_d[1],p39b_d[0]}; // p39b
assign u_acol2__unused_p30_terms[5] = ~&{p37a_d[3],p37a_d[2],p37a_d[1],p37a_d[0]}; // p37a
assign u_acol2__unused_p30_terms[4] = ~&{p37b_d[3],p37b_d[2],p37b_d[1],p37b_d[0]}; // p37b
assign u_acol2__unused_p30_terms[3] = ~&{p33b_d[3],p33b_d[2],p33b_d[1],p33b_d[0]}; // p33b
assign u_acol2__unused_p30_terms[2] = ~&{p33a_d[3],p33a_d[2],p33a_d[1],p33a_d[0]}; // p33a
assign u_acol2__unused_p30_terms[1] = ~&{p35b_d[3],p35b_d[2],p35b_d[1],p35b_d[0]}; // p35b
assign u_acol2__unused_p30_terms[0] = ~&{p35a_d[3],p35a_d[2],p35a_d[1],p35a_d[0]}; // p35a
assign acol2 = ~&{u_acol2__unused_p30_terms[7],u_acol2__unused_p30_terms[6],u_acol2__unused_p30_terms[5],u_acol2__unused_p30_terms[4],u_acol2__unused_p30_terms[3],u_acol2__unused_p30_terms[2],u_acol2__unused_p30_terms[1],u_acol2__unused_p30_terms[0]}; // p30
// End inlined jt054157_page04_acol2_decode u_acol2

// Inlined jt054157_page04_bcol2_decode u_bcol2
wire [7:0] u_bcol2__unused_r43_terms;
assign u_bcol2__unused_r43_terms[7] = ~&{r37b_d[3],r37b_d[2],r37b_d[1],r37b_d[0]}; // r37b
assign u_bcol2__unused_r43_terms[6] = ~&{r47a_d[3],r47a_d[2],r47a_d[1],r47a_d[0]}; // r47a
assign u_bcol2__unused_r43_terms[5] = ~&{r47b_d[3],r47b_d[2],r47b_d[1],r47b_d[0]}; // r47b
assign u_bcol2__unused_r43_terms[4] = ~&{r51b_d[3],r51b_d[2],r51b_d[1],r51b_d[0]}; // r51b
assign u_bcol2__unused_r43_terms[3] = ~&{r37a_d[3],r37a_d[2],r37a_d[1],r37a_d[0]}; // r37a
assign u_bcol2__unused_r43_terms[2] = ~&{r49a_d[3],r49a_d[2],r49a_d[1],r49a_d[0]}; // r49a
assign u_bcol2__unused_r43_terms[1] = ~&{r49b_d[3],r49b_d[2],r49b_d[1],r49b_d[0]}; // r49b
assign u_bcol2__unused_r43_terms[0] = ~&{r51a_d[3],r51a_d[2],r51a_d[1],r51a_d[0]}; // r51a
assign bcol2 = ~&{u_bcol2__unused_r43_terms[7],u_bcol2__unused_r43_terms[6],u_bcol2__unused_r43_terms[5],u_bcol2__unused_r43_terms[4],u_bcol2__unused_r43_terms[3],u_bcol2__unused_r43_terms[2],u_bcol2__unused_r43_terms[1],u_bcol2__unused_r43_terms[0]}; // r43
// End inlined jt054157_page04_bcol2_decode u_bcol2

// Inlined jt054157_page04_ccol2_decode u_ccol2
wire [7:0] u_ccol2__unused_p20_terms;
assign u_ccol2__unused_p20_terms[7] = ~&{p11a_d[3],p11a_d[2],p11a_d[1],p11a_d[0]}; // p11a
assign u_ccol2__unused_p20_terms[6] = ~&{p14a_d[3],p14a_d[2],p14a_d[1],p14a_d[0]}; // p14a
assign u_ccol2__unused_p20_terms[5] = ~&{p16b_d[3],p16b_d[2],p16b_d[1],p16b_d[0]}; // p16b
assign u_ccol2__unused_p20_terms[4] = ~&{p18b_d[3],p18b_d[2],p18b_d[1],p18b_d[0]}; // p18b
assign u_ccol2__unused_p20_terms[3] = ~&{p16a_d[3],p16a_d[2],p16a_d[1],p16a_d[0]}; // p16a
assign u_ccol2__unused_p20_terms[2] = ~&{p18a_d[3],p18a_d[2],p18a_d[1],p18a_d[0]}; // p18a
assign u_ccol2__unused_p20_terms[1] = ~&{p23b_d[3],p23b_d[2],p23b_d[1],p23b_d[0]}; // p23b
assign u_ccol2__unused_p20_terms[0] = ~&{p23a_d[3],p23a_d[2],p23a_d[1],p23a_d[0]}; // p23a
assign ccol2 = ~&{u_ccol2__unused_p20_terms[7],u_ccol2__unused_p20_terms[6],u_ccol2__unused_p20_terms[5],u_ccol2__unused_p20_terms[4],u_ccol2__unused_p20_terms[3],u_ccol2__unused_p20_terms[2],u_ccol2__unused_p20_terms[1],u_ccol2__unused_p20_terms[0]}; // p20
// End inlined jt054157_page04_ccol2_decode u_ccol2

// Inlined jt054157_page04_ccol3_decode u_ccol3
wire [7:0] u_ccol3__unused_r89_terms;
assign u_ccol3__unused_r89_terms[7] = ~&{r97a_d[3],r97a_d[2],r97a_d[1],r97a_d[0]}; // r97a
assign u_ccol3__unused_r89_terms[6] = ~&{r99a_d[3],r99a_d[2],r99a_d[1],r99a_d[0]}; // r99a
assign u_ccol3__unused_r89_terms[5] = ~&{r98b_d[3],r98b_d[2],r98b_d[1],r98b_d[0]}; // r98b
assign u_ccol3__unused_r89_terms[4] = ~&{r100b_d[3],r100b_d[2],r100b_d[1],r100b_d[0]}; // r100b
assign u_ccol3__unused_r89_terms[3] = ~&{r82a_d[3],r82a_d[2],r82a_d[1],r82a_d[0]}; // r82a
assign u_ccol3__unused_r89_terms[2] = ~&{r86b_d[3],r86b_d[2],r86b_d[1],r86b_d[0]}; // r86b
assign u_ccol3__unused_r89_terms[1] = ~&{r84a_d[3],r84a_d[2],r84a_d[1],r84a_d[0]}; // r84a
assign u_ccol3__unused_r89_terms[0] = ~&{r86a_d[3],r86a_d[2],r86a_d[1],r86a_d[0]}; // r86a
assign ccol3 = ~&{u_ccol3__unused_r89_terms[7],u_ccol3__unused_r89_terms[6],u_ccol3__unused_r89_terms[5],u_ccol3__unused_r89_terms[4],u_ccol3__unused_r89_terms[3],u_ccol3__unused_r89_terms[2],u_ccol3__unused_r89_terms[1],u_ccol3__unused_r89_terms[0]}; // r89
// End inlined jt054157_page04_ccol3_decode u_ccol3

// Inlined jt054157_page04_acol3_decode u_acol3
wire [7:0] u_acol3__unused_p84_terms;
assign u_acol3__unused_p84_terms[7] = ~&{p88b_d[3],p88b_d[2],p88b_d[1],p88b_d[0]}; // p88b
assign u_acol3__unused_p84_terms[6] = ~&{p90b_d[3],p90b_d[2],p90b_d[1],p90b_d[0]}; // p90b
assign u_acol3__unused_p84_terms[5] = ~&{p89a_d[3],p89a_d[2],p89a_d[1],p89a_d[0]}; // p89a
assign u_acol3__unused_p84_terms[4] = ~&{p91a_d[3],p91a_d[2],p91a_d[1],p91a_d[0]}; // p91a
assign u_acol3__unused_p84_terms[3] = ~&{p80a_d[3],p80a_d[2],p80a_d[1],p80a_d[0]}; // p80a
assign u_acol3__unused_p84_terms[2] = ~&{p82a_d[3],p82a_d[2],p82a_d[1],p82a_d[0]}; // p82a
assign u_acol3__unused_p84_terms[1] = ~&{p82b_d[3],p82b_d[2],p82b_d[1],p82b_d[0]}; // p82b
assign u_acol3__unused_p84_terms[0] = ~&{p87a_d[3],p87a_d[2],p87a_d[1],p87a_d[0]}; // p87a
assign acol3 = ~&{u_acol3__unused_p84_terms[7],u_acol3__unused_p84_terms[6],u_acol3__unused_p84_terms[5],u_acol3__unused_p84_terms[4],u_acol3__unused_p84_terms[3],u_acol3__unused_p84_terms[2],u_acol3__unused_p84_terms[1],u_acol3__unused_p84_terms[0]}; // p84
// End inlined jt054157_page04_acol3_decode u_acol3

// Inlined jt054157_page04_bcol3_decode u_bcol3
wire [7:0] u_bcol3__unused_p101_terms;
assign u_bcol3__unused_p101_terms[7] = ~&{p97b_d[3],p97b_d[2],p97b_d[1],p97b_d[0]}; // p97b
assign u_bcol3__unused_p101_terms[6] = ~&{p97a_d[3],p97a_d[2],p97a_d[1],p97a_d[0]}; // p97a
assign u_bcol3__unused_p101_terms[5] = ~&{p99b_d[3],p99b_d[2],p99b_d[1],p99b_d[0]}; // p99b
assign u_bcol3__unused_p101_terms[4] = ~&{p99a_d[3],p99a_d[2],p99a_d[1],p99a_d[0]}; // p99a
assign u_bcol3__unused_p101_terms[3] = ~&{p106a_d[3],p106a_d[2],p106a_d[1],p106a_d[0]}; // p106a
assign u_bcol3__unused_p101_terms[2] = ~&{p104b_d[3],p104b_d[2],p104b_d[1],p104b_d[0]}; // p104b
assign u_bcol3__unused_p101_terms[1] = ~&{p104a_d[3],p104a_d[2],p104a_d[1],p104a_d[0]}; // p104a
assign u_bcol3__unused_p101_terms[0] = ~&{p106b_d[3],p106b_d[2],p106b_d[1],p106b_d[0]}; // p106b
assign bcol3 = ~&{u_bcol3__unused_p101_terms[7],u_bcol3__unused_p101_terms[6],u_bcol3__unused_p101_terms[5],u_bcol3__unused_p101_terms[4],u_bcol3__unused_p101_terms[3],u_bcol3__unused_p101_terms[2],u_bcol3__unused_p101_terms[1],u_bcol3__unused_p101_terms[0]}; // p101
// End inlined jt054157_page04_bcol3_decode u_bcol3

// Inlined jt054157_page04_pin57_decode u_pin57
wire [7:0] u_pin57__unused_g187_terms;
assign u_pin57__unused_g187_terms[7] = ~&{g178b_d[3],g178b_d[2],g178b_d[1],g178b_d[0]}; // g178b
assign u_pin57__unused_g187_terms[6] = ~&{g178a_d[3],g178a_d[2],g178a_d[1],g178a_d[0]}; // g178a
assign u_pin57__unused_g187_terms[5] = ~&{g180b_d[3],g180b_d[2],g180b_d[1],g180b_d[0]}; // g180b
assign u_pin57__unused_g187_terms[4] = ~&{g180a_d[3],g180a_d[2],g180a_d[1],g180a_d[0]}; // g180a
assign u_pin57__unused_g187_terms[3] = ~&{g183b_d[3],g183b_d[2],g183b_d[1],g183b_d[0]}; // g183b
assign u_pin57__unused_g187_terms[2] = ~&{g183a_d[3],g183a_d[2],g183a_d[1],g183a_d[0]}; // g183a
assign u_pin57__unused_g187_terms[1] = ~&{g185b_d[3],g185b_d[2],g185b_d[1],g185b_d[0]}; // g185b
assign u_pin57__unused_g187_terms[0] = ~&{g185a_d[3],g185a_d[2],g185a_d[1],g185a_d[0]}; // g185a
assign pin57 = ~&{u_pin57__unused_g187_terms[7],u_pin57__unused_g187_terms[6],u_pin57__unused_g187_terms[5],u_pin57__unused_g187_terms[4],u_pin57__unused_g187_terms[3],u_pin57__unused_g187_terms[2],u_pin57__unused_g187_terms[1],u_pin57__unused_g187_terms[0]}; // g187
// End inlined jt054157_page04_pin57_decode u_pin57

// Inlined jt054157_page04_pin51_decode u_pin51
wire [7:0] u_pin51__unused_d207_terms;
assign u_pin51__unused_d207_terms[7] = ~&{e204b_d[3],e204b_d[2],e204b_d[1],e204b_d[0]}; // e204b
assign u_pin51__unused_d207_terms[6] = ~&{e206a_d[3],e206a_d[2],e206a_d[1],e206a_d[0]}; // e206a
assign u_pin51__unused_d207_terms[5] = ~&{d210b_d[3],d210b_d[2],d210b_d[1],d210b_d[0]}; // d210b
assign u_pin51__unused_d207_terms[4] = ~&{d210a_d[3],d210a_d[2],d210a_d[1],d210a_d[0]}; // d210a
assign u_pin51__unused_d207_terms[3] = ~&{e204a_d[3],e204a_d[2],e204a_d[1],e204a_d[0]}; // e204a
assign u_pin51__unused_d207_terms[2] = ~&{e208a_d[3],e208a_d[2],e208a_d[1],e208a_d[0]}; // e208a
assign u_pin51__unused_d207_terms[1] = ~&{e207b_d[3],e207b_d[2],e207b_d[1],e207b_d[0]}; // e207b
assign u_pin51__unused_d207_terms[0] = ~&{e209b_d[3],e209b_d[2],e209b_d[1],e209b_d[0]}; // e209b
assign pin51 = ~&{u_pin51__unused_d207_terms[7],u_pin51__unused_d207_terms[6],u_pin51__unused_d207_terms[5],u_pin51__unused_d207_terms[4],u_pin51__unused_d207_terms[3],u_pin51__unused_d207_terms[2],u_pin51__unused_d207_terms[1],u_pin51__unused_d207_terms[0]}; // d207
// End inlined jt054157_page04_pin51_decode u_pin51

// Inlined jt054157_page04_pin53_decode u_pin53
wire [7:0] u_pin53__unused_e201_terms;
assign u_pin53__unused_e201_terms[7] = ~&{e191a_d[3],e191a_d[2],e191a_d[1],e191a_d[0]}; // e191a
assign u_pin53__unused_e201_terms[6] = ~&{e192b_d[3],e192b_d[2],e192b_d[1],e192b_d[0]}; // e192b
assign u_pin53__unused_e201_terms[5] = ~&{e193a_d[3],e193a_d[2],e193a_d[1],e193a_d[0]}; // e193a
assign u_pin53__unused_e201_terms[4] = ~&{e195a_d[3],e195a_d[2],e195a_d[1],e195a_d[0]}; // e195a
assign u_pin53__unused_e201_terms[3] = ~&{e194b_d[3],e194b_d[2],e194b_d[1],e194b_d[0]}; // e194b
assign u_pin53__unused_e201_terms[2] = ~&{e196b_d[3],e196b_d[2],e196b_d[1],e196b_d[0]}; // e196b
assign u_pin53__unused_e201_terms[1] = ~&{e197a_d[3],e197a_d[2],e197a_d[1],e197a_d[0]}; // e197a
assign u_pin53__unused_e201_terms[0] = ~&{e198b_d[3],e198b_d[2],e198b_d[1],e198b_d[0]}; // e198b
assign pin53 = ~&{u_pin53__unused_e201_terms[7],u_pin53__unused_e201_terms[6],u_pin53__unused_e201_terms[5],u_pin53__unused_e201_terms[4],u_pin53__unused_e201_terms[3],u_pin53__unused_e201_terms[2],u_pin53__unused_e201_terms[1],u_pin53__unused_e201_terms[0]}; // e201
// End inlined jt054157_page04_pin53_decode u_pin53

// Inlined jt054157_page04_pin55_decode u_pin55
wire [7:0] u_pin55__unused_f183_terms;
assign u_pin55__unused_f183_terms[7] = ~&{f178b_d[3],f178b_d[2],f178b_d[1],f178b_d[0]}; // f178b
assign u_pin55__unused_f183_terms[6] = ~&{f180b_d[3],f180b_d[2],f180b_d[1],f180b_d[0]}; // f180b
assign u_pin55__unused_f183_terms[5] = ~&{f176a_d[3],f176a_d[2],f176a_d[1],f176a_d[0]}; // f176a
assign u_pin55__unused_f183_terms[4] = ~&{f179a_d[3],f179a_d[2],f179a_d[1],f179a_d[0]}; // f179a
assign u_pin55__unused_f183_terms[3] = ~&{f186a_d[3],f186a_d[2],f186a_d[1],f186a_d[0]}; // f186a
assign u_pin55__unused_f183_terms[2] = ~&{f188a_d[3],f188a_d[2],f188a_d[1],f188a_d[0]}; // f188a
assign u_pin55__unused_f183_terms[1] = ~&{f186b_d[3],f186b_d[2],f186b_d[1],f186b_d[0]}; // f186b
assign u_pin55__unused_f183_terms[0] = ~&{f188b_d[3],f188b_d[2],f188b_d[1],f188b_d[0]}; // f188b
assign pin55 = ~&{u_pin55__unused_f183_terms[7],u_pin55__unused_f183_terms[6],u_pin55__unused_f183_terms[5],u_pin55__unused_f183_terms[4],u_pin55__unused_f183_terms[3],u_pin55__unused_f183_terms[2],u_pin55__unused_f183_terms[1],u_pin55__unused_f183_terms[0]}; // f183
// End inlined jt054157_page04_pin55_decode u_pin55

// Inlined jt054157_page04_pin52_decode u_pin52
wire [7:0] u_pin52__unused_d203_terms;
assign u_pin52__unused_d203_terms[7] = ~&{d193b_d[3],d193b_d[2],d193b_d[1],d193b_d[0]}; // d193b
assign u_pin52__unused_d203_terms[6] = ~&{d193a_d[3],d193a_d[2],d193a_d[1],d193a_d[0]}; // d193a
assign u_pin52__unused_d203_terms[5] = ~&{d195b_d[3],d195b_d[2],d195b_d[1],d195b_d[0]}; // d195b
assign u_pin52__unused_d203_terms[4] = ~&{d197b_d[3],d197b_d[2],d197b_d[1],d197b_d[0]}; // d197b
assign u_pin52__unused_d203_terms[3] = ~&{d195a_d[3],d195a_d[2],d195a_d[1],d195a_d[0]}; // d195a
assign u_pin52__unused_d203_terms[2] = ~&{d197a_d[3],d197a_d[2],d197a_d[1],d197a_d[0]}; // d197a
assign u_pin52__unused_d203_terms[1] = ~&{d199b_d[3],d199b_d[2],d199b_d[1],d199b_d[0]}; // d199b
assign u_pin52__unused_d203_terms[0] = ~&{d199a_d[3],d199a_d[2],d199a_d[1],d199a_d[0]}; // d199a
assign pin52 = ~&{u_pin52__unused_d203_terms[7],u_pin52__unused_d203_terms[6],u_pin52__unused_d203_terms[5],u_pin52__unused_d203_terms[4],u_pin52__unused_d203_terms[3],u_pin52__unused_d203_terms[2],u_pin52__unused_d203_terms[1],u_pin52__unused_d203_terms[0]}; // d203
// End inlined jt054157_page04_pin52_decode u_pin52

// Inlined jt054157_page04_pin58_decode u_pin58
wire [7:0] u_pin58__unused_a167_terms;
assign u_pin58__unused_a167_terms[7] = ~&{a163b_d[3],a163b_d[2],a163b_d[1],a163b_d[0]}; // a163b
assign u_pin58__unused_a167_terms[6] = ~&{a165b_d[3],a165b_d[2],a165b_d[1],a165b_d[0]}; // a165b
assign u_pin58__unused_a167_terms[5] = ~&{a178b_d[3],a178b_d[2],a178b_d[1],a178b_d[0]}; // a178b
assign u_pin58__unused_a167_terms[4] = ~&{a178a_d[3],a178a_d[2],a178a_d[1],a178a_d[0]}; // a178a
assign u_pin58__unused_a167_terms[3] = ~&{b176b_d[3],b176b_d[2],b176b_d[1],b176b_d[0]}; // b176b
assign u_pin58__unused_a167_terms[2] = ~&{b176a_d[3],b176a_d[2],b176a_d[1],b176a_d[0]}; // b176a
assign u_pin58__unused_a167_terms[1] = ~&{a163a_d[3],a163a_d[2],a163a_d[1],a163a_d[0]}; // a163a
assign u_pin58__unused_a167_terms[0] = ~&{a165a_d[3],a165a_d[2],a165a_d[1],a165a_d[0]}; // a165a
assign pin58 = ~&{u_pin58__unused_a167_terms[7],u_pin58__unused_a167_terms[6],u_pin58__unused_a167_terms[5],u_pin58__unused_a167_terms[4],u_pin58__unused_a167_terms[3],u_pin58__unused_a167_terms[2],u_pin58__unused_a167_terms[1],u_pin58__unused_a167_terms[0]}; // a167
// End inlined jt054157_page04_pin58_decode u_pin58

// Inlined jt054157_page04_pin56_decode u_pin56
wire [7:0] u_pin56__unused_b199_terms;
assign u_pin56__unused_b199_terms[7] = ~&{b191b_d[3],b191b_d[2],b191b_d[1],b191b_d[0]}; // b191b
assign u_pin56__unused_b199_terms[6] = ~&{b191a_d[3],b191a_d[2],b191a_d[1],b191a_d[0]}; // b191a
assign u_pin56__unused_b199_terms[5] = ~&{b193b_d[3],b193b_d[2],b193b_d[1],b193b_d[0]}; // b193b
assign u_pin56__unused_b199_terms[4] = ~&{b193a_d[3],b193a_d[2],b193a_d[1],b193a_d[0]}; // b193a
assign u_pin56__unused_b199_terms[3] = ~&{b195b_d[3],b195b_d[2],b195b_d[1],b195b_d[0]}; // b195b
assign u_pin56__unused_b199_terms[2] = ~&{b195a_d[3],b195a_d[2],b195a_d[1],b195a_d[0]}; // b195a
assign u_pin56__unused_b199_terms[1] = ~&{b197b_d[3],b197b_d[2],b197b_d[1],b197b_d[0]}; // b197b
assign u_pin56__unused_b199_terms[0] = ~&{b197a_d[3],b197a_d[2],b197a_d[1],b197a_d[0]}; // b197a
assign pin56 = ~&{u_pin56__unused_b199_terms[7],u_pin56__unused_b199_terms[6],u_pin56__unused_b199_terms[5],u_pin56__unused_b199_terms[4],u_pin56__unused_b199_terms[3],u_pin56__unused_b199_terms[2],u_pin56__unused_b199_terms[1],u_pin56__unused_b199_terms[0]}; // b199
// End inlined jt054157_page04_pin56_decode u_pin56

// Inlined jt054157_page04_pin54_decode u_pin54
wire [7:0] u_pin54__unused_c203_terms;
assign u_pin54__unused_c203_terms[7] = ~&{c192a_d[3],c192a_d[2],c192a_d[1],c192a_d[0]}; // c192a
assign u_pin54__unused_c203_terms[6] = ~&{c194a_d[3],c194a_d[2],c194a_d[1],c194a_d[0]}; // c194a
assign u_pin54__unused_c203_terms[5] = ~&{c193b_d[3],c193b_d[2],c193b_d[1],c193b_d[0]}; // c193b
assign u_pin54__unused_c203_terms[4] = ~&{c195b_d[3],c195b_d[2],c195b_d[1],c195b_d[0]}; // c195b
assign u_pin54__unused_c203_terms[3] = ~&{c196a_d[3],c196a_d[2],c196a_d[1],c196a_d[0]}; // c196a
assign u_pin54__unused_c203_terms[2] = ~&{c198a_d[3],c198a_d[2],c198a_d[1],c198a_d[0]}; // c198a
assign u_pin54__unused_c203_terms[1] = ~&{c197b_d[3],c197b_d[2],c197b_d[1],c197b_d[0]}; // c197b
assign u_pin54__unused_c203_terms[0] = ~&{c199b_d[3],c199b_d[2],c199b_d[1],c199b_d[0]}; // c199b
assign pin54 = ~&{u_pin54__unused_c203_terms[7],u_pin54__unused_c203_terms[6],u_pin54__unused_c203_terms[5],u_pin54__unused_c203_terms[4],u_pin54__unused_c203_terms[3],u_pin54__unused_c203_terms[2],u_pin54__unused_c203_terms[1],u_pin54__unused_c203_terms[0]}; // c203
// End inlined jt054157_page04_pin54_decode u_pin54

// Inlined jt054157_page04_dcol3_decode u_dcol3
wire [7:0] u_dcol3__unused_r15_terms;
assign u_dcol3__unused_r15_terms[7] = ~&{r6a_d[3],r6a_d[2],r6a_d[1],r6a_d[0]}; // r6a
assign u_dcol3__unused_r15_terms[6] = ~&{r8a_d[3],r8a_d[2],r8a_d[1],r8a_d[0]}; // r8a
assign u_dcol3__unused_r15_terms[5] = ~&{r8b_d[3],r8b_d[2],r8b_d[1],r8b_d[0]}; // r8b
assign u_dcol3__unused_r15_terms[4] = ~&{r13a_d[3],r13a_d[2],r13a_d[1],r13a_d[0]}; // r13a
assign u_dcol3__unused_r15_terms[3] = ~&{r18b_d[3],r18b_d[2],r18b_d[1],r18b_d[0]}; // r18b
assign u_dcol3__unused_r15_terms[2] = ~&{r20b_d[3],r20b_d[2],r20b_d[1],r20b_d[0]}; // r20b
assign u_dcol3__unused_r15_terms[1] = ~&{r18a_d[3],r18a_d[2],r18a_d[1],r18a_d[0]}; // r18a
assign u_dcol3__unused_r15_terms[0] = ~&{r20a_d[3],r20a_d[2],r20a_d[1],r20a_d[0]}; // r20a
assign dcol3 = ~&{u_dcol3__unused_r15_terms[7],u_dcol3__unused_r15_terms[6],u_dcol3__unused_r15_terms[5],u_dcol3__unused_r15_terms[4],u_dcol3__unused_r15_terms[3],u_dcol3__unused_r15_terms[2],u_dcol3__unused_r15_terms[1],u_dcol3__unused_r15_terms[0]}; // r15
// End inlined jt054157_page04_dcol3_decode u_dcol3

// Inlined jt054157_page04_dcol4_decode u_dcol4
wire [7:0] u_dcol4__unused_m97_terms;
assign u_dcol4__unused_m97_terms[7] = ~&{m102b_d[3],m102b_d[2],m102b_d[1],m102b_d[0]}; // m102b
assign u_dcol4__unused_m97_terms[6] = ~&{m100b_d[3],m100b_d[2],m100b_d[1],m100b_d[0]}; // m100b
assign u_dcol4__unused_m97_terms[5] = ~&{m101a_d[3],m101a_d[2],m101a_d[1],m101a_d[0]}; // m101a
assign u_dcol4__unused_m97_terms[4] = ~&{m93a_d[3],m93a_d[2],m93a_d[1],m93a_d[0]}; // m93a
assign u_dcol4__unused_m97_terms[3] = ~&{m106b_d[3],m106b_d[2],m106b_d[1],m106b_d[0]}; // m106b
assign u_dcol4__unused_m97_terms[2] = ~&{m105a_d[3],m105a_d[2],m105a_d[1],m105a_d[0]}; // m105a
assign u_dcol4__unused_m97_terms[1] = ~&{m104b_d[3],m104b_d[2],m104b_d[1],m104b_d[0]}; // m104b
assign u_dcol4__unused_m97_terms[0] = ~&{m103a_d[3],m103a_d[2],m103a_d[1],m103a_d[0]}; // m103a
assign dcol4 = ~&{u_dcol4__unused_m97_terms[7],u_dcol4__unused_m97_terms[6],u_dcol4__unused_m97_terms[5],u_dcol4__unused_m97_terms[4],u_dcol4__unused_m97_terms[3],u_dcol4__unused_m97_terms[2],u_dcol4__unused_m97_terms[1],u_dcol4__unused_m97_terms[0]}; // m97
// End inlined jt054157_page04_dcol4_decode u_dcol4

endmodule


// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054157_page05_left_load_integrated.v
// -----------------------------------------------------------------------------

// Page 5 left-output package wrapper with page-6 load clocks connected.
//
// This wrapper connects the audited page-6 load matrix outputs
// G23B/J2B/G21B/J13A/G25A/J39A/G7B/J2A into the audited page-5 left-output
// package wrapper. The page-5 data and D24 input groups remain explicit until
// the long color/data rails are dot-traced.

module jt054157_page05_left_load_integrated(
    input  wire       k114a,
    input  wire       j121b,
    input  wire       c114b,
    input  wire       loada,
    input  wire       loadb,
    input  wire       loadc,
    input  wire       loadd,
    input  wire       h109_qa,
    input  wire       h109_qb,
    input  wire       h109_qc,
    input  wire       h109_qd,

    input  wire [3:0] dcol_d,
    input  wire [3:0] ccol_d,
    input  wire [3:0] bcol_d,
    input  wire [3:0] acol_d,

    input  wire [3:0] r33b_d24,
    input  wire [3:0] r35b_d24,
    input  wire [3:0] n51b_d24,
    input  wire [3:0] n27a_d24,
    input  wire [3:0] n51a_d24,
    input  wire [3:0] n27b_d24,
    input  wire [3:0] n29b_d24,
    input  wire [3:0] n29a_d24,

    output wire       g23b,
    output wire       j2b,
    output wire       g21b,
    output wire       j13a,
    output wire       g25a,
    output wire       j39a,
    output wire       g7b,
    output wire       j2a,

    output wire       pin122,
    output wire       pin123,
    output wire       pin124,
    output wire       pin128,
    output wire       pin129,
    output wire       pin131,
    output wire       pin135,
    output wire       pin136,
    output wire       pin137,
    output wire       pin143,
    output wire       pin144,
    output wire       pin145,

    output wire [3:0] n15_q,
    output wire [3:0] n3_q,
    output wire [3:0] n31_q,
    output wire [3:0] n41_q,
    output wire [3:0] m29_q,
    output wire [3:0] m41_q,
    output wire [3:0] m15_q,
    output wire [3:0] m3_q,

    output wire       r33b_x,
    output wire       r35b_x,
    output wire       n51b_x,
    output wire       n27a_x,
    output wire       n51a_x,
    output wire       n27b_x,
    output wire       n29b_x,
    output wire       n29a_x,

    output wire       pin_122_out,
    output wire       pin_123_out,
    output wire       pin_124_out,
    output wire       pin_128_out,
    output wire       pin_129_out,
    output wire       pin_131_out,
    output wire       pin_135_out,
    output wire       pin_136_out,
    output wire       pin_137_out,
    output wire       pin_143_out,
    output wire       pin_144_out,
    output wire       pin_145_out
);

jt054157_page06_load_matrix_integrated u_load_matrix(
    .k114a   ( k114a   ),
    .j121b   ( j121b   ),
    .c114b   ( c114b   ),
    .loada   ( loada   ),
    .loadb   ( loadb   ),
    .loadc   ( loadc   ),
    .loadd   ( loadd   ),
    .h109_qa ( h109_qa ),
    .h109_qb ( h109_qb ),
    .h109_qc ( h109_qc ),
    .h109_qd ( h109_qd ),
    .c51a_y  (          ),
    .j125a_y (          ),
    .f129b_y (          ),
    .f132a_y (          ),
    .n83b_y  (          ),
    .c51b_y  (          ),
    .c62b_y  (          ),
    .j38b_y  (          ),
    .j47b_y  (          ),
    .c62a_y  (          ),
    .b98b_y  (          ),
    .b99a_y  (          ),
    .c100a_y (          ),
    .c100b_y (          ),
    .b109b_y (          ),
    .c113a_y (          ),
    .f135a   (          ),
    .f133b   (          ),
    .f137a   (          ),
    .f131b   (          ),
    .c139a   (          ),
    .c133b   (          ),
    .c133a   (          ),
    .d119a   (          ),
    .m39a    (          ),
    .m51a    (          ),
    .m39b    (          ),
    .m51b    (          ),
    .c45b    (          ),
    .c47b    (          ),
    .c49b    (          ),
    .c13a    (          ),
    .c82b    (          ),
    .c78a    (          ),
    .c80a    (          ),
    .c64a    (          ),
    .j2b     ( j2b     ),
    .j13a    ( j13a    ),
    .j39a    ( j39a    ),
    .j2a     ( j2a     ),
    .j13b    (          ),
    .j51b    (          ),
    .j51a    (          ),
    .j49a    (          ),
    .g23b    ( g23b    ),
    .g21b    ( g21b    ),
    .g25a    ( g25a    ),
    .g7b     ( g7b     ),
    .b81a    (          ),
    .b81b    (          ),
    .a99b    (          ),
    .b54a    (          ),
    .b97a    (          ),
    .b83a    (          ),
    .b96b    (          ),
    .b83b    (          ),
    .c96b    (          ),
    .c96a    (          ),
    .c93a    (          ),
    .c82a    (          ),
    .g86b    (          ),
    .g100a   (          ),
    .g92b    (          ),
    .g90b    (          ),
    .b111a   (          ),
    .b111b   (          ),
    .a121a   (          ),
    .b109a   (          ),
    .c139b   (          ),
    .c135a   (          ),
    .c137b   (          ),
    .c137a   (          )
);

// Inlined jt054157_page05_left_package_integrated u_page05_left_package
// Inlined jt054157_page05_left_outputs u_page05_left_outputs
reg [3:0] u_page05_left_outputs__n15_q;
reg [3:0] u_page05_left_outputs__n3_q;
reg [3:0] u_page05_left_outputs__n31_q;
reg [3:0] u_page05_left_outputs__n41_q;
reg [3:0] u_page05_left_outputs__m29_q;
reg [3:0] u_page05_left_outputs__m41_q;
reg [3:0] u_page05_left_outputs__m15_q;
reg [3:0] u_page05_left_outputs__m3_q;
always @(posedge g23b) begin
    u_page05_left_outputs__n15_q <= dcol_d; // n15
end
always @(posedge j2b) begin
    u_page05_left_outputs__n3_q <= u_page05_left_outputs__n15_q; // n3
end
assign pin122 = u_page05_left_outputs__n3_q[3];

assign r33b_x = ~((r33b_d24[3] & r33b_d24[2]) | (r33b_d24[1] & r33b_d24[0])); // r33b
assign pin123 = ~r33b_x; // p10b
assign r35b_x = ~((r35b_d24[3] & r35b_d24[2]) | (r35b_d24[1] & r35b_d24[0])); // r35b
assign pin124 = ~r35b_x; // r34a
always @(posedge g21b) begin
    u_page05_left_outputs__n31_q <= ccol_d; // n31
end
always @(posedge j13a) begin
    u_page05_left_outputs__n41_q <= u_page05_left_outputs__n31_q; // n41
end
assign pin128 = u_page05_left_outputs__n41_q[3];

assign n51b_x = ~((n51b_d24[3] & n51b_d24[2]) | (n51b_d24[1] & n51b_d24[0])); // n51b
assign pin129 = ~n51b_x; // m26b
assign n27a_x = ~((n27a_d24[3] & n27a_d24[2]) | (n27a_d24[1] & n27a_d24[0])); // n27a
assign pin131 = ~n27a_x; // n2a
always @(posedge g25a) begin
    u_page05_left_outputs__m29_q <= bcol_d; // m29
end
always @(posedge j39a) begin
    u_page05_left_outputs__m41_q <= u_page05_left_outputs__m29_q; // m41
end
assign pin135 = u_page05_left_outputs__m41_q[3];

assign n51a_x = ~((n51a_d24[3] & n51a_d24[2]) | (n51a_d24[1] & n51a_d24[0])); // n51a
assign pin136 = ~n51a_x; // m26a
assign n27b_x = ~((n27b_d24[3] & n27b_d24[2]) | (n27b_d24[1] & n27b_d24[0])); // n27b
assign pin137 = ~n27b_x; // m25a
always @(posedge g7b) begin
    u_page05_left_outputs__m15_q <= acol_d; // m15
end
always @(posedge j2a) begin
    u_page05_left_outputs__m3_q <= u_page05_left_outputs__m15_q; // m3
end
assign pin143 = u_page05_left_outputs__m3_q[3];

assign n29b_x = ~((n29b_d24[3] & n29b_d24[2]) | (n29b_d24[1] & n29b_d24[0])); // n29b
assign pin144 = ~n29b_x; // n13b
assign n29a_x = ~((n29a_d24[3] & n29a_d24[2]) | (n29a_d24[1] & n29a_d24[0])); // n29a
assign pin145 = ~n29a_x; // m13b
assign n15_q = u_page05_left_outputs__n15_q;
assign n3_q = u_page05_left_outputs__n3_q;
assign n31_q = u_page05_left_outputs__n31_q;
assign n41_q = u_page05_left_outputs__n41_q;
assign m29_q = u_page05_left_outputs__m29_q;
assign m41_q = u_page05_left_outputs__m41_q;
assign m15_q = u_page05_left_outputs__m15_q;
assign m3_q = u_page05_left_outputs__m3_q;
// End inlined jt054157_page05_left_outputs u_page05_left_outputs

// Inlined jt054157_page05_left_package_output_map u_page05_left_package_output_map
assign pin_122_out = pin122;
assign pin_123_out = pin123;
assign pin_124_out = pin124;
assign pin_128_out = pin128;
assign pin_129_out = pin129;
assign pin_131_out = pin131;
assign pin_135_out = pin135;
assign pin_136_out = pin136;
assign pin_137_out = pin137;
assign pin_143_out = pin143;
assign pin_144_out = pin144;
assign pin_145_out = pin145;
// End inlined jt054157_page05_left_package_output_map u_page05_left_package_output_map
// End inlined jt054157_page05_left_package_integrated u_page05_left_package

endmodule


// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054157_page06_load_matrix_integrated.v
// -----------------------------------------------------------------------------

// Page 6 integrated load/decode matrix.
//
// Composes the three visually checked page-6 decode slices and wires the
// confirmed C51A handoff from the K114A/J125A slice into the C51A/J121B
// lower decode slice. J121B, C114B, LOADA..D, and H109_QA..QD remain explicit
// boundary rails until their page-level producers are tied into a full top.

module jt054157_page06_load_matrix_integrated(
    input  wire k114a,
    input  wire j121b,
    input  wire c114b,
    input  wire loada,
    input  wire loadb,
    input  wire loadc,
    input  wire loadd,
    input  wire h109_qa,
    input  wire h109_qb,
    input  wire h109_qc,
    input  wire h109_qd,

    output wire c51a_y,
    output wire j125a_y,
    output wire f129b_y,
    output wire f132a_y,
    output wire n83b_y,
    output wire c51b_y,
    output wire c62b_y,
    output wire j38b_y,
    output wire j47b_y,
    output wire c62a_y,
    output wire b98b_y,
    output wire b99a_y,
    output wire c100a_y,
    output wire c100b_y,
    output wire b109b_y,
    output wire c113a_y,

    output wire f135a,
    output wire f133b,
    output wire f137a,
    output wire f131b,
    output wire c139a,
    output wire c133b,
    output wire c133a,
    output wire d119a,
    output wire m39a,
    output wire m51a,
    output wire m39b,
    output wire m51b,
    output wire c45b,
    output wire c47b,
    output wire c49b,
    output wire c13a,
    output wire c82b,
    output wire c78a,
    output wire c80a,
    output wire c64a,
    output wire j2b,
    output wire j13a,
    output wire j39a,
    output wire j2a,
    output wire j13b,
    output wire j51b,
    output wire j51a,
    output wire j49a,
    output wire g23b,
    output wire g21b,
    output wire g25a,
    output wire g7b,
    output wire b81a,
    output wire b81b,
    output wire a99b,
    output wire b54a,
    output wire b97a,
    output wire b83a,
    output wire b96b,
    output wire b83b,
    output wire c96b,
    output wire c96a,
    output wire c93a,
    output wire c82a,
    output wire g86b,
    output wire g100a,
    output wire g92b,
    output wire g90b,
    output wire b111a,
    output wire b111b,
    output wire a121a,
    output wire b109a,
    output wire c139b,
    output wire c135a,
    output wire c137b,
    output wire c137a
);

// Inlined jt054157_page06_j125_load_decode u_j125_load_decode
wire u_j125_load_decode__h142b_y, u_j125_load_decode__h70a_y, u_j125_load_decode__h141b_y, u_j125_load_decode__h56a_y;
wire u_j125_load_decode__h143_y, u_j125_load_decode__h73_y, u_j125_load_decode__h145_y, u_j125_load_decode__h63_y;
wire u_j125_load_decode__h149b_y, u_j125_load_decode__h49b_y, u_j125_load_decode__j119a_y, u_j125_load_decode__h56b_y;
wire u_j125_load_decode__h147_y, u_j125_load_decode__h51_y, u_j125_load_decode__j123_y, u_j125_load_decode__h61_y;
wire u_j125_load_decode__k27a_y, u_j125_load_decode__h49a_y, u_j125_load_decode__j40b_y, u_j125_load_decode__h50b_y;
wire u_j125_load_decode__l27_y, u_j125_load_decode__h46_y, u_j125_load_decode__j36_y, u_j125_load_decode__h44_y;

assign c51a_y = k114a; // c51a
assign j125a_y = k114a; // j125a
assign f129b_y = j125a_y; // f129b
assign u_j125_load_decode__h142b_y = ~loadd; // h142b
assign u_j125_load_decode__h143_y = u_j125_load_decode__h142b_y; // h143
assign f135a = f129b_y & u_j125_load_decode__h143_y; // f135a
assign u_j125_load_decode__h70a_y = ~loadc; // h70a
assign u_j125_load_decode__h73_y = u_j125_load_decode__h70a_y; // h73
assign f133b = f129b_y & u_j125_load_decode__h73_y; // f133b
assign u_j125_load_decode__h141b_y = ~loadb; // h141b
assign u_j125_load_decode__h145_y = u_j125_load_decode__h141b_y; // h145
assign f137a = f129b_y & u_j125_load_decode__h145_y; // f137a
assign u_j125_load_decode__h56a_y = ~loada; // h56a
assign u_j125_load_decode__h63_y = u_j125_load_decode__h56a_y; // h63
assign f131b = f129b_y & u_j125_load_decode__h63_y; // f131b
assign f132a_y = j125a_y; // f132a
assign u_j125_load_decode__h149b_y = ~loadd; // h149b
assign u_j125_load_decode__h147_y = u_j125_load_decode__h149b_y; // h147
assign c139a = f132a_y & u_j125_load_decode__h147_y; // c139a
assign u_j125_load_decode__h49b_y = ~loadc; // h49b
assign u_j125_load_decode__h51_y = u_j125_load_decode__h49b_y; // h51
assign c133b = f132a_y & u_j125_load_decode__h51_y; // c133b
assign u_j125_load_decode__j119a_y = ~loadb; // j119a
assign u_j125_load_decode__j123_y = u_j125_load_decode__j119a_y; // j123
assign c133a = f132a_y & u_j125_load_decode__j123_y; // c133a
assign u_j125_load_decode__h56b_y = ~loada; // h56b
assign u_j125_load_decode__h61_y = u_j125_load_decode__h56b_y; // h61
assign d119a = f132a_y & u_j125_load_decode__h61_y; // d119a
assign n83b_y = j125a_y; // n83b
assign u_j125_load_decode__k27a_y = ~loadd; // k27a
assign u_j125_load_decode__l27_y = u_j125_load_decode__k27a_y; // l27
assign m39a = n83b_y & u_j125_load_decode__l27_y; // m39a
assign u_j125_load_decode__h49a_y = ~loadc; // h49a
assign u_j125_load_decode__h46_y = u_j125_load_decode__h49a_y; // h46
assign m51a = n83b_y & u_j125_load_decode__h46_y; // m51a
assign u_j125_load_decode__j40b_y = ~loadb; // j40b
assign u_j125_load_decode__j36_y = u_j125_load_decode__j40b_y; // j36
assign m39b = n83b_y & u_j125_load_decode__j36_y; // m39b
assign u_j125_load_decode__h50b_y = ~loada; // h50b
assign u_j125_load_decode__h44_y = u_j125_load_decode__h50b_y; // h44
assign m51b = n83b_y & u_j125_load_decode__h44_y; // m51b
// End inlined jt054157_page06_j125_load_decode u_j125_load_decode

// Inlined jt054157_page06_c51_j121_load_decode u_c51_j121_load_decode
wire u_c51_j121_load_decode__c65b_y, u_c51_j121_load_decode__c8b_y, u_c51_j121_load_decode__c64b_y, u_c51_j121_load_decode__c7a_y;
wire u_c51_j121_load_decode__c57_y, u_c51_j121_load_decode__c11_y, u_c51_j121_load_decode__c55_y, u_c51_j121_load_decode__c9_y;
wire u_c51_j121_load_decode__c84b_y, u_c51_j121_load_decode__c59b_y, u_c51_j121_load_decode__c84a_y, u_c51_j121_load_decode__c59a_y;
wire u_c51_j121_load_decode__c91_y, u_c51_j121_load_decode__c66_y, u_c51_j121_load_decode__c89_y, u_c51_j121_load_decode__c60_y;
wire u_c51_j121_load_decode__j1b_y, u_c51_j121_load_decode__h12a_y, u_c51_j121_load_decode__j50b_y, u_c51_j121_load_decode__h12b_y;
wire u_c51_j121_load_decode__j7_y, u_c51_j121_load_decode__h13_y, u_c51_j121_load_decode__j41_y, u_c51_j121_load_decode__j9_y;
wire u_c51_j121_load_decode__j1a_y, u_c51_j121_load_decode__j48a_y, u_c51_j121_load_decode__j49b_y, u_c51_j121_load_decode__h50a_y;
wire u_c51_j121_load_decode__j11_y, u_c51_j121_load_decode__j45_y, u_c51_j121_load_decode__j43_y, u_c51_j121_load_decode__h42_y;

assign c51b_y = c51a_y; // c51b
assign u_c51_j121_load_decode__c65b_y = ~loadd; // c65b
assign u_c51_j121_load_decode__c57_y = u_c51_j121_load_decode__c65b_y; // c57
assign c45b = c51b_y & u_c51_j121_load_decode__c57_y; // c45b
assign u_c51_j121_load_decode__c8b_y = ~loadc; // c8b
assign u_c51_j121_load_decode__c11_y = u_c51_j121_load_decode__c8b_y; // c11
assign c47b = c51b_y & u_c51_j121_load_decode__c11_y; // c47b
assign u_c51_j121_load_decode__c64b_y = ~loadb; // c64b
assign u_c51_j121_load_decode__c55_y = u_c51_j121_load_decode__c64b_y; // c55
assign c49b = c51b_y & u_c51_j121_load_decode__c55_y; // c49b
assign u_c51_j121_load_decode__c7a_y = ~loada; // c7a
assign u_c51_j121_load_decode__c9_y = u_c51_j121_load_decode__c7a_y; // c9
assign c13a = c51b_y & u_c51_j121_load_decode__c9_y; // c13a
assign c62b_y = c51a_y; // c62b
assign u_c51_j121_load_decode__c84b_y = ~loadd; // c84b
assign u_c51_j121_load_decode__c91_y = u_c51_j121_load_decode__c84b_y; // c91
assign c82b = c62b_y & u_c51_j121_load_decode__c91_y; // c82b
assign u_c51_j121_load_decode__c59b_y = ~loadc; // c59b
assign u_c51_j121_load_decode__c66_y = u_c51_j121_load_decode__c59b_y; // c66
assign c78a = c62b_y & u_c51_j121_load_decode__c66_y; // c78a
assign u_c51_j121_load_decode__c84a_y = ~loadb; // c84a
assign u_c51_j121_load_decode__c89_y = u_c51_j121_load_decode__c84a_y; // c89
assign c80a = c62b_y & u_c51_j121_load_decode__c89_y; // c80a
assign u_c51_j121_load_decode__c59a_y = ~loada; // c59a
assign u_c51_j121_load_decode__c60_y = u_c51_j121_load_decode__c59a_y; // c60
assign c64a = c62b_y & u_c51_j121_load_decode__c60_y; // c64a
assign j38b_y = j121b; // j38b
assign u_c51_j121_load_decode__j1b_y = ~loadd; // j1b
assign u_c51_j121_load_decode__j7_y = u_c51_j121_load_decode__j1b_y; // j7
assign j2b = j38b_y & u_c51_j121_load_decode__j7_y; // j2b
assign u_c51_j121_load_decode__h12a_y = ~loadc; // h12a
assign u_c51_j121_load_decode__h13_y = u_c51_j121_load_decode__h12a_y; // h13
assign j13a = j38b_y & u_c51_j121_load_decode__h13_y; // j13a
assign u_c51_j121_load_decode__j50b_y = ~loadb; // j50b
assign u_c51_j121_load_decode__j41_y = u_c51_j121_load_decode__j50b_y; // j41
assign j39a = j38b_y & u_c51_j121_load_decode__j41_y; // j39a
assign u_c51_j121_load_decode__h12b_y = ~loada; // h12b
assign u_c51_j121_load_decode__j9_y = u_c51_j121_load_decode__h12b_y; // j9
assign j2a = j38b_y & u_c51_j121_load_decode__j9_y; // j2a
assign j47b_y = j121b; // j47b
assign u_c51_j121_load_decode__j1a_y = ~loadd; // j1a
assign u_c51_j121_load_decode__j11_y = u_c51_j121_load_decode__j1a_y; // j11
assign j13b = j47b_y & u_c51_j121_load_decode__j11_y; // j13b
assign u_c51_j121_load_decode__j48a_y = ~loadc; // j48a
assign u_c51_j121_load_decode__j45_y = u_c51_j121_load_decode__j48a_y; // j45
assign j51b = j47b_y & u_c51_j121_load_decode__j45_y; // j51b
assign u_c51_j121_load_decode__j49b_y = ~loadb; // j49b
assign u_c51_j121_load_decode__j43_y = u_c51_j121_load_decode__j49b_y; // j43
assign j51a = j47b_y & u_c51_j121_load_decode__j43_y; // j51a
assign u_c51_j121_load_decode__h50a_y = ~loada; // h50a
assign u_c51_j121_load_decode__h42_y = u_c51_j121_load_decode__h50a_y; // h42
assign j49a = j47b_y & u_c51_j121_load_decode__h42_y; // j49a
// End inlined jt054157_page06_c51_j121_load_decode u_c51_j121_load_decode

// Inlined jt054157_page06_c114b_h109_decode u_c114b_h109_decode
wire u_c114b_h109_decode__g93a_y, u_c114b_h109_decode__g94b_y, u_c114b_h109_decode__f67a_y, u_c114b_h109_decode__c8a_y;
wire u_c114b_h109_decode__g84_y, u_c114b_h109_decode__g82_y, u_c114b_h109_decode__g55_y, u_c114b_h109_decode__c5_y;
wire u_c114b_h109_decode__b94a_y, u_c114b_h109_decode__b94b_y, u_c114b_h109_decode__a103b_y, u_c114b_h109_decode__b79a_y;
wire u_c114b_h109_decode__b91_y, u_c114b_h109_decode__b85_y, u_c114b_h109_decode__a101_y, u_c114b_h109_decode__b66_y;
wire u_c114b_h109_decode__b105b_y, u_c114b_h109_decode__b93a_y, u_c114b_h109_decode__b105a_y, u_c114b_h109_decode__b93b_y;
wire u_c114b_h109_decode__b103_y, u_c114b_h109_decode__b87_y, u_c114b_h109_decode__b101_y, u_c114b_h109_decode__b89_y;
wire u_c114b_h109_decode__c104a_y, u_c114b_h109_decode__c107b_y, u_c114b_h109_decode__c107a_y, u_c114b_h109_decode__c93b_y;
wire u_c114b_h109_decode__c105_y, u_c114b_h109_decode__c102_y, u_c114b_h109_decode__c98_y, u_c114b_h109_decode__c87_y;
wire u_c114b_h109_decode__g94a_y, u_c114b_h109_decode__g106b_y, u_c114b_h109_decode__f94a_y, u_c114b_h109_decode__c94b_y;
wire u_c114b_h109_decode__g88_y, u_c114b_h109_decode__g104_y, u_c114b_h109_decode__f92_y, u_c114b_h109_decode__c85_y;
wire u_c114b_h109_decode__a122b_y, u_c114b_h109_decode__c113b_y, u_c114b_h109_decode__a121b_y, u_c114b_h109_decode__b100b_y;
wire u_c114b_h109_decode__a119_y, u_c114b_h109_decode__c111_y, u_c114b_h109_decode__a117_y, u_c114b_h109_decode__b106_y;
wire u_c114b_h109_decode__c110b_y, u_c114b_h109_decode__c110a_y, u_c114b_h109_decode__c109a_y, u_c114b_h109_decode__c109b_y;
wire u_c114b_h109_decode__c121_y, u_c114b_h109_decode__c117_y, u_c114b_h109_decode__c119_y, u_c114b_h109_decode__c115_y;

assign c62a_y = c114b; // c62a
assign u_c114b_h109_decode__g93a_y = ~h109_qa; // g93a
assign u_c114b_h109_decode__g84_y = u_c114b_h109_decode__g93a_y; // g84
assign g23b = c62a_y & u_c114b_h109_decode__g84_y; // g23b
assign u_c114b_h109_decode__g94b_y = ~h109_qb; // g94b
assign u_c114b_h109_decode__g82_y = u_c114b_h109_decode__g94b_y; // g82
assign g21b = c62a_y & u_c114b_h109_decode__g82_y; // g21b
assign u_c114b_h109_decode__f67a_y = ~h109_qc; // f67a
assign u_c114b_h109_decode__g55_y = u_c114b_h109_decode__f67a_y; // g55
assign g25a = c62a_y & u_c114b_h109_decode__g55_y; // g25a
assign u_c114b_h109_decode__c8a_y = ~h109_qd; // c8a
assign u_c114b_h109_decode__c5_y = u_c114b_h109_decode__c8a_y; // c5
assign g7b = c62a_y & u_c114b_h109_decode__c5_y; // g7b
assign b98b_y = c114b; // b98b
assign u_c114b_h109_decode__b94a_y = ~h109_qa; // b94a
assign u_c114b_h109_decode__b91_y = u_c114b_h109_decode__b94a_y; // b91
assign b81a = b98b_y & u_c114b_h109_decode__b91_y; // b81a
assign u_c114b_h109_decode__b94b_y = ~h109_qb; // b94b
assign u_c114b_h109_decode__b85_y = u_c114b_h109_decode__b94b_y; // b85
assign b81b = b98b_y & u_c114b_h109_decode__b85_y; // b81b
assign u_c114b_h109_decode__a103b_y = ~h109_qc; // a103b
assign u_c114b_h109_decode__a101_y = u_c114b_h109_decode__a103b_y; // a101
assign a99b = b98b_y & u_c114b_h109_decode__a101_y; // a99b
assign u_c114b_h109_decode__b79a_y = ~h109_qd; // b79a
assign u_c114b_h109_decode__b66_y = u_c114b_h109_decode__b79a_y; // b66
assign b54a = b98b_y & u_c114b_h109_decode__b66_y; // b54a
assign b99a_y = c114b; // b99a
assign u_c114b_h109_decode__b105b_y = ~h109_qa; // b105b
assign u_c114b_h109_decode__b103_y = u_c114b_h109_decode__b105b_y; // b103
assign b97a = b99a_y & u_c114b_h109_decode__b103_y; // b97a
assign u_c114b_h109_decode__b93a_y = ~h109_qb; // b93a
assign u_c114b_h109_decode__b87_y = u_c114b_h109_decode__b93a_y; // b87
assign b83a = b99a_y & u_c114b_h109_decode__b87_y; // b83a
assign u_c114b_h109_decode__b105a_y = ~h109_qc; // b105a
assign u_c114b_h109_decode__b101_y = u_c114b_h109_decode__b105a_y; // b101
assign b96b = b99a_y & u_c114b_h109_decode__b101_y; // b96b
assign u_c114b_h109_decode__b93b_y = ~h109_qd; // b93b
assign u_c114b_h109_decode__b89_y = u_c114b_h109_decode__b93b_y; // b89
assign b83b = b99a_y & u_c114b_h109_decode__b89_y; // b83b
assign c100a_y = c114b; // c100a
assign u_c114b_h109_decode__c104a_y = ~h109_qa; // c104a
assign u_c114b_h109_decode__c105_y = u_c114b_h109_decode__c104a_y; // c105
assign c96b = c100a_y & u_c114b_h109_decode__c105_y; // c96b
assign u_c114b_h109_decode__c107b_y = ~h109_qb; // c107b
assign u_c114b_h109_decode__c102_y = u_c114b_h109_decode__c107b_y; // c102
assign c96a = c100a_y & u_c114b_h109_decode__c102_y; // c96a
assign u_c114b_h109_decode__c107a_y = ~h109_qc; // c107a
assign u_c114b_h109_decode__c98_y = u_c114b_h109_decode__c107a_y; // c98
assign c93a = c100a_y & u_c114b_h109_decode__c98_y; // c93a
assign u_c114b_h109_decode__c93b_y = ~h109_qd; // c93b
assign u_c114b_h109_decode__c87_y = u_c114b_h109_decode__c93b_y; // c87
assign c82a = c100a_y & u_c114b_h109_decode__c87_y; // c82a
assign c100b_y = c114b; // c100b
assign u_c114b_h109_decode__g94a_y = ~h109_qa; // g94a
assign u_c114b_h109_decode__g88_y = u_c114b_h109_decode__g94a_y; // g88
assign g86b = c100b_y & u_c114b_h109_decode__g88_y; // g86b
assign u_c114b_h109_decode__g106b_y = ~h109_qb; // g106b
assign u_c114b_h109_decode__g104_y = u_c114b_h109_decode__g106b_y; // g104
assign g100a = c100b_y & u_c114b_h109_decode__g104_y; // g100a
assign u_c114b_h109_decode__f94a_y = ~h109_qc; // f94a
assign u_c114b_h109_decode__f92_y = u_c114b_h109_decode__f94a_y; // f92
assign g92b = c100b_y & u_c114b_h109_decode__f92_y; // g92b
assign u_c114b_h109_decode__c94b_y = ~h109_qd; // c94b
assign u_c114b_h109_decode__c85_y = u_c114b_h109_decode__c94b_y; // c85
assign g90b = c100b_y & u_c114b_h109_decode__c85_y; // g90b
assign b109b_y = c114b; // b109b
assign u_c114b_h109_decode__a122b_y = ~h109_qa; // a122b
assign u_c114b_h109_decode__a119_y = u_c114b_h109_decode__a122b_y; // a119
assign b111a = b109b_y & u_c114b_h109_decode__a119_y; // b111a
assign u_c114b_h109_decode__c113b_y = ~h109_qb; // c113b
assign u_c114b_h109_decode__c111_y = u_c114b_h109_decode__c113b_y; // c111
assign b111b = b109b_y & u_c114b_h109_decode__c111_y; // b111b
assign u_c114b_h109_decode__a121b_y = ~h109_qc; // a121b
assign u_c114b_h109_decode__a117_y = u_c114b_h109_decode__a121b_y; // a117
assign a121a = b109b_y & u_c114b_h109_decode__a117_y; // a121a
assign u_c114b_h109_decode__b100b_y = ~h109_qd; // b100b
assign u_c114b_h109_decode__b106_y = u_c114b_h109_decode__b100b_y; // b106
assign b109a = b109b_y & u_c114b_h109_decode__b106_y; // b109a
assign c113a_y = c114b; // c113a
assign u_c114b_h109_decode__c110b_y = ~h109_qa; // c110b
assign u_c114b_h109_decode__c121_y = u_c114b_h109_decode__c110b_y; // c121
assign c139b = c113a_y & u_c114b_h109_decode__c121_y; // c139b
assign u_c114b_h109_decode__c110a_y = ~h109_qb; // c110a
assign u_c114b_h109_decode__c117_y = u_c114b_h109_decode__c110a_y; // c117
assign c135a = c113a_y & u_c114b_h109_decode__c117_y; // c135a
assign u_c114b_h109_decode__c109a_y = ~h109_qc; // c109a
assign u_c114b_h109_decode__c119_y = u_c114b_h109_decode__c109a_y; // c119
assign c137b = c113a_y & u_c114b_h109_decode__c119_y; // c137b
assign u_c114b_h109_decode__c109b_y = ~h109_qd; // c109b
assign u_c114b_h109_decode__c115_y = u_c114b_h109_decode__c109b_y; // c115
assign c137a = c113a_y & u_c114b_h109_decode__c115_y; // c137a
// End inlined jt054157_page06_c114b_h109_decode u_c114b_h109_decode

endmodule


// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054157_page09_hofs_readout_db_package_integrated.v
// -----------------------------------------------------------------------------

// Page-9/HOF to readout DB package integration wrapper.
//
// Composes the audited page-9/HOF package path with the page-10/11
// readout DB package wrapper. CPU register/control rails recovered by
// the HOF path, including PIN116, are fed into the page-11 readout side. The two page-9
// DB direction rails are expanded into active-high package OE bits;
// DB_DIR_DRIVE_VALUE keeps the unresolved pad-direction polarity explicit.

module jt054157_page09_hofs_readout_db_package_integrated #(
    parameter DB_DIR_DRIVE_VALUE = 1'b0
)(
    input  wire       pin_clk,
    input  wire       pin_nres,
    input  wire       pin64,
    input  wire       pin112,
    input  wire       pin_ab1,
    input  wire       pin_ab2,
    input  wire [7:0] pin_db_in,
    input  wire       pin113,
    input  wire       pin_z4h,
    input  wire       pin_z2h,
    input  wire       pin_z1h,
    input  wire       pin_col0,
    input  wire       pin_col1,
    input  wire       pin_col2,
    input  wire       pin_col3,
    input  wire       pin_col4,
    input  wire       pin_col5,
    input  wire       pin_col6,
    input  wire       pin_col7,

    input  wire       hcnt1_raw,
    input  wire       hcnt0_raw,

    output wire       nres_sync,
    output wire       nres_sync2,
    output wire [3:0] reg_wr_n,
    output wire       reg0_d0,
    output wire       reg0_d3,
    output wire       reg0_d4,
    output wire       reg2_d0,
    output wire       reg2_d2,
    output wire       reg2_d4,
    output wire       reg2_d6,
    output wire       reg4_d3,
    output wire       reg4_d3_buf,
    output wire       reg4_d3_buf2,
    output wire       reg4_d3_buf3,
    output wire       g124a,
    output wire       reg4_d4_buf,
    output wire       reg4_d4_buf2,
    output wire       reg4_d4_buf3,
    output wire       reg4_d5,
    output wire       reg4_d6,
    output wire       reg6_d5,
    output wire       k114a,
    output wire       j136a,
    output wire       j152a,
    output wire       j121b,
    output wire       j152b,
    output wire       l135a,
    output wire       loada,
    output wire       loadb,
    output wire       loadc,
    output wire       loadd,
    output wire [2:0] hcnt,
    output wire [3:0] j172_x_n,
    output wire [2:0] hofsd,
    output wire [2:0] hofsc,
    output wire [2:0] hofs_b,
    output wire [2:0] hofsa,
    output wire [2:0] hofsd_f,
    output wire [2:0] hofsc_f,
    output wire [2:0] hofs_b_f,
    output wire [2:0] hofsa_f,
    output wire       pin114,
    output wire       pin115,
    output wire       pin116,
    output wire       pin117,
    output wire       pin118,
    output wire       pin119,
    output wire       pin125,
    output wire       pin126,
    output wire       pin127,
    output wire       pin132,
    output wire       pin133,
    output wire       pin134,
    output wire       pin138,
    output wire       pin141,
    output wire       pin142,
    output wire       c114b,
    output wire       j135a,
    output wire       m118a,
    output wire [3:0] h109_q,
    output wire pin_114_out,
    output wire pin_115_out,
    output wire pin_116_out,
    output wire pin_117_out,
    output wire pin_118_out,
    output wire pin_119_out,
    output wire pin_125_out,
    output wire pin_126_out,
    output wire pin_127_out,
    output wire pin_132_out,
    output wire pin_133_out,
    output wire pin_134_out,
    output wire pin_138_out,
    output wire pin_141_out,
    output wire pin_142_out,

    input  wire       pin95,
    input  wire       pin_crom,
    input  wire       pin_uds,
    input  wire       pin_lds,

    output wire       pin101,
    output wire       pin102,
    output wire       pin103,
    output wire       pin104,
    output wire       pin105,
    output wire       pin106,
    output wire       pin107,
    output wire       pin108,
    output wire       p162a,
    output wire       pin_db_lower_dir,
    output wire       pin_db_upper_dir,

    output wire       m120a_y,
    output wire       m111a_y,
    output wire       p148,
    output wire       l130b_y,
    output wire       l132b_y,
    output wire       m121a_x,
    output wire       n111a_y,
    output wire [3:0] m181_x_n,
    output wire       m187b_y,
    output wire       m185b_y,
    output wire       m187a_y,
    output wire       m185a_y,
    output wire       n108b_y,
    output wire       p146b_y,
    output wire       r144a_y,
    output wire       p146a_y,
    output wire       r144b_y,
    output wire       n113b_y,
    output wire       l114a_y,
    output wire       l118b_y,
    output wire       l126b_y,
    output wire       l108b_y,
    output wire       p159a_y,
    output wire       p162a_y,
    output wire       p150b_y,
    output wire       p149a_y,
    output wire       l130a_y,
    output wire       p160b_y,
    output wire       r161a_y,
    output wire       l132a_y,
    output wire       p141b_y,
    output wire       l127_y,
    output wire       n65b_y,
    output wire       n65a_y,
    output wire       m109a_y,
    output wire       m76a_q,
    output wire       m73_q,
    output wire       k124b_y,
    output wire       k137b_y,
    output wire       k126b_x,
    output wire       k135b_x,
    output wire       k124a_y,
    output wire       l118a_y,
    output wire       l119b_y,
    output wire       l112_y,
    output wire       l108a_q,
    output wire       k119a_q,
    output wire       l116a_y,
    output wire       l117b_y,
    output wire       l115b_y,
    output wire       l119a_y,
    output wire       l121b_y,
    output wire       l121b,
    output wire pin_101_out,
    output wire pin_102_out,
    output wire pin_103_out,
    output wire pin_104_out,
    output wire pin_105_out,
    output wire pin_106_out,
    output wire pin_107_out,
    output wire pin_108_out,

    input  wire       pin34_in,
    input  wire       pin3_in,
    input  wire       pin12_in,
    input  wire       pin16_in,
    input  wire       pin35_in,
    input  wire       pin4_in,
    input  wire       pin13_in,
    input  wire       pin17_in,
    input  wire       pin23_in,
    input  wire       pin5_in,
    input  wire       pin14_in,
    input  wire       pin18_in,
    input  wire       pin24_in,
    input  wire       pin6_in,
    input  wire       pin15_in,
    input  wire       pin19_in,
    input  wire       pin155_in,
    input  wire       pin156_in,
    input  wire       pin48_in,
    input  wire       pin25_in,
    input  wire       pin157_in,
    input  wire       pin158_in,
    input  wire       pin7_in,
    input  wire       pin21_in,
    input  wire       pin159_in,
    input  wire       pin49_in,
    input  wire       pin36_in,
    input  wire       pin9_in,
    input  wire       pin37_in,
    input  wire       pin8_in,
    input  wire       pin22_in,
    input  wire       pin2_in,
    input  wire       pin27_in,
    input  wire       pin28_in,
    input  wire       pin11_in,
    input  wire       pin38_in,
    input  wire       pin39_in,
    input  wire       pin42_in,
    input  wire       pin43_in,
    input  wire       pin29_in,
    input  wire       pin44_in,
    input  wire       pin31_in,
    input  wire       pin45_in,
    input  wire       pin32_in,
    input  wire       pin46_in,
    input  wire       pin33_in,
    input  wire       pin47_in,
    output wire [15:0] readout_d,

    input  wire       pin99,
    output wire [15:0] pin_db_out,
    output wire [ 7:0] pins_vc_dir,
    output wire        pin_076_out,
    output wire        pin_076_oe,
    output wire        pin_077_out,
    output wire        pin_077_oe,
    output wire        pin_078_out,
    output wire        pin_078_oe,
    output wire        pin_079_out,
    output wire        pin_079_oe,
    output wire        pin_082_out,
    output wire        pin_082_oe,
    output wire        pin_083_out,
    output wire        pin_083_oe,
    output wire        pin_084_out,
    output wire        pin_084_oe,
    output wire        pin_085_out,
    output wire        pin_085_oe,
    output wire        pin_086_out,
    output wire        pin_086_oe,
    output wire        pin_087_out,
    output wire        pin_087_oe,
    output wire        pin_088_out,
    output wire        pin_088_oe,
    output wire        pin_089_out,
    output wire        pin_089_oe,
    output wire        pin_091_out,
    output wire        pin_091_oe,
    output wire        pin_092_out,
    output wire        pin_092_oe,
    output wire        pin_093_out,
    output wire        pin_093_oe,
    output wire        pin_094_out,
    output wire        pin_094_oe
);

// Inlined jt054157_page09_hofs_package_integrated u_page09_hofs_package
wire u_page09_hofs_package__k144_xq;

// Inlined jt054157_hofs_package_integrated u_hofs_package
// Inlined jt054157_hofs_pipeline_pin_counter_integrated u_hofs_pipeline_pin_counter
wire u_hofs_package__u_hofs_pipeline_pin_counter__j161a, u_hofs_package__u_hofs_pipeline_pin_counter__j161b, u_hofs_package__u_hofs_pipeline_pin_counter__k155, u_hofs_package__u_hofs_pipeline_pin_counter__k157, u_hofs_package__u_hofs_pipeline_pin_counter__k161;
wire u_hofs_package__u_hofs_pipeline_pin_counter__j156a, u_hofs_package__u_hofs_pipeline_pin_counter__k137a, u_hofs_package__u_hofs_pipeline_pin_counter__k153b, u_hofs_package__u_hofs_pipeline_pin_counter__k159a, u_hofs_package__u_hofs_pipeline_pin_counter__k153a;

// Inlined jt054157_page01_pin_counter u_pin_counter
reg u_pin_counter__pin114;
reg [3:0] u_pin_counter__h109_q;
wire [1:0] u_pin_counter__j154_x_n, u_pin_counter__j138a_x_n, u_pin_counter__k139a_x_n;
wire [3:0] u_pin_counter__h119_x_n;
wire    u_pin_counter__j162b_y;
wire    u_pin_counter__j158_nq;
wire    u_pin_counter__j120b_y, u_pin_counter__k125b_y;
wire    u_pin_counter__gnd = 1'b0;

assign pin116 = ~u_pin_counter__j154_x_n[0]; // m156a
assign u_pin_counter__j162b_y = ~u_pin_counter__j154_x_n[1]; // j162b
always @(posedge pin116) begin
    u_pin_counter__pin114 <= u_pin_counter__j162b_y; // j158
end

assign u_pin_counter__j158_nq = ~u_pin_counter__pin114; // j158

assign c114b = ~u_pin_counter__j138a_x_n[0]; // c114b
assign j135a = ~u_pin_counter__j138a_x_n[1]; // j135a

assign pin115 = ~u_pin_counter__k139a_x_n[0]; // k123a
assign u_pin_counter__j120b_y = pin115; // j120b
assign u_pin_counter__k125b_y = ~u_pin_counter__k139a_x_n[1]; // k125b
assign m118a = u_pin_counter__k125b_y; // m118a
assign u_pin_counter__h119_x_n = ~u_pin_counter__k125b_y ? ~(4'b0001 << { u_pin_counter__j120b_y, u_pin_counter__pin114 }) : 4'hf; // h119
always @(posedge j135a) begin
    u_pin_counter__h109_q <= u_pin_counter__h119_x_n; // h109
end
assign pin114 = u_pin_counter__pin114;
assign h109_q = u_pin_counter__h109_q;
// End inlined jt054157_page01_pin_counter u_pin_counter

// Inlined jt054157_hofs_pipeline_integrated u_hofs_pipeline
wire u_hofs_package__u_hofs_pipeline__h109_qa;
wire u_hofs_package__u_hofs_pipeline__h109_qb;
wire u_hofs_package__u_hofs_pipeline__h109_qc;
wire u_hofs_package__u_hofs_pipeline__h109_qd;
assign u_hofs_package__u_hofs_pipeline__h109_qa = h109_q[3];
assign u_hofs_package__u_hofs_pipeline__h109_qb = h109_q[2];
assign u_hofs_package__u_hofs_pipeline__h109_qc = h109_q[1];
assign u_hofs_package__u_hofs_pipeline__h109_qd = h109_q[0];
wire       u_hofs_package__u_hofs_pipeline__k112_y, u_hofs_package__u_hofs_pipeline__k116_q, u_hofs_package__u_hofs_pipeline__k116_nq, u_hofs_package__u_hofs_pipeline__l152_nq;
wire       u_hofs_package__u_hofs_pipeline__l161a, u_hofs_package__u_hofs_pipeline__l159, u_hofs_package__u_hofs_pipeline__l161b, u_hofs_package__u_hofs_pipeline__l155_q, u_hofs_package__u_hofs_pipeline__l155_nq;
wire       u_hofs_package__u_hofs_pipeline__k142, u_hofs_package__u_hofs_pipeline__k138b, u_hofs_package__u_hofs_pipeline__k147a_q, u_hofs_package__u_hofs_pipeline__k147a_nq, u_hofs_package__u_hofs_pipeline__k135a, u_hofs_package__u_hofs_pipeline__k144_q, u_hofs_package__u_hofs_pipeline__k160b;
wire       u_hofs_package__u_hofs_pipeline__reg0_d0_buf, u_hofs_package__u_hofs_pipeline__k192, u_hofs_package__u_hofs_pipeline__k194;
wire       u_hofs_package__u_hofs_pipeline__reg6_d6, u_hofs_package__u_hofs_pipeline__reg6_d7;
wire       u_hofs_package__u_hofs_pipeline__l29a_y, u_hofs_package__u_hofs_pipeline__l30b_y, u_hofs_package__u_hofs_pipeline__l12a_y, u_hofs_package__u_hofs_pipeline__l30a_y;
wire       u_hofs_package__u_hofs_pipeline__g23b, u_hofs_package__u_hofs_pipeline__j2b, u_hofs_package__u_hofs_pipeline__g21b, u_hofs_package__u_hofs_pipeline__j13a, u_hofs_package__u_hofs_pipeline__g25a, u_hofs_package__u_hofs_pipeline__j39a, u_hofs_package__u_hofs_pipeline__g7b, u_hofs_package__u_hofs_pipeline__j2a;
wire [3:0] u_hofs_package__u_hofs_pipeline__hofs_col_d = { u_hofs_package__u_hofs_pipeline__l29a_y, u_hofs_package__u_hofs_pipeline__l30b_y, u_hofs_package__u_hofs_pipeline__l12a_y, u_hofs_package__u_hofs_pipeline__l30a_y };
wire [3:0] u_hofs_package__u_hofs_pipeline__k28_q, u_hofs_package__u_hofs_pipeline__k43_q, u_hofs_package__u_hofs_pipeline__k15_q, u_hofs_package__u_hofs_pipeline__l15_q, u_hofs_package__u_hofs_pipeline__l31_q, u_hofs_package__u_hofs_pipeline__l43_q, u_hofs_package__u_hofs_pipeline__k3_q, u_hofs_package__u_hofs_pipeline__h2_q;

// Inlined jt054157_page02_cpu_entry u_cpu_entry
wire    u_hofs_package__u_hofs_pipeline__u_cpu_entry__k108a_nq;

reg     u_hofs_package__u_hofs_pipeline__u_cpu_entry__k108a_q;
wire    u_hofs_package__u_hofs_pipeline__u_cpu_entry__k188a_y;
wire    u_hofs_package__u_hofs_pipeline__u_cpu_entry__m159a_y;
wire [3:0] u_hofs_package__u_hofs_pipeline__u_cpu_entry__l163_d;
reg [3:0] u_hofs_package__u_hofs_pipeline__u_cpu_entry__l163_q;
wire [3:0] u_hofs_package__u_hofs_pipeline__u_cpu_entry__k163_d;
reg [3:0] u_hofs_package__u_hofs_pipeline__u_cpu_entry__k163_q;
wire [3:0] u_hofs_package__u_hofs_pipeline__u_cpu_entry__l138_d;
reg [3:0] u_hofs_package__u_hofs_pipeline__u_cpu_entry__l138_q;
wire [3:0] u_hofs_package__u_hofs_pipeline__u_cpu_entry__m165_d;
reg [3:0] u_hofs_package__u_hofs_pipeline__u_cpu_entry__m165_q;
wire    u_hofs_package__u_hofs_pipeline__u_cpu_entry__reg4_d4_src;
assign u_hofs_package__u_hofs_pipeline__u_cpu_entry__l163_d = { pin_db_in[4], pin_db_in[3], 1'b0, pin_db_in[0] };
assign u_hofs_package__u_hofs_pipeline__u_cpu_entry__k163_d = { pin_db_in[0], pin_db_in[2], pin_db_in[4], pin_db_in[6] };
assign u_hofs_package__u_hofs_pipeline__u_cpu_entry__l138_d = { pin_db_in[6], pin_db_in[5], pin_db_in[4], pin_db_in[3] };
assign u_hofs_package__u_hofs_pipeline__u_cpu_entry__m165_d = { pin_db_in[7], pin_db_in[6], pin_db_in[5], 1'b0 };

always @(posedge pin_clk or negedge pin_nres) begin
    if (!pin_nres) begin
        u_hofs_package__u_hofs_pipeline__u_cpu_entry__k108a_q <= 1'b0;
    end else begin
        u_hofs_package__u_hofs_pipeline__u_cpu_entry__k108a_q <= 1'b1;
    end
end // k108a

assign u_hofs_package__u_hofs_pipeline__u_cpu_entry__k108a_nq = ~u_hofs_package__u_hofs_pipeline__u_cpu_entry__k108a_q; // k108a
assign nres_sync = u_hofs_package__u_hofs_pipeline__u_cpu_entry__k108a_q; // k125a
assign nres_sync2 = ~u_hofs_package__u_hofs_pipeline__u_cpu_entry__k108a_nq; // k115b
assign u_hofs_package__u_hofs_pipeline__u_cpu_entry__m159a_y = nres_sync; // m159a
assign u_hofs_package__u_hofs_pipeline__u_cpu_entry__k188a_y = pin64 | pin112; // k188a
assign reg_wr_n = ~u_hofs_package__u_hofs_pipeline__u_cpu_entry__k188a_y ? ~(4'b0001 << { pin_ab1, pin_ab2 }) : 4'hf; // l179
always @(posedge reg_wr_n[0] or negedge u_hofs_package__u_hofs_pipeline__u_cpu_entry__m159a_y) begin
    if (!u_hofs_package__u_hofs_pipeline__u_cpu_entry__m159a_y) begin
        u_hofs_package__u_hofs_pipeline__u_cpu_entry__l163_q <= 4'd0;
    end else begin
        u_hofs_package__u_hofs_pipeline__u_cpu_entry__l163_q <= u_hofs_package__u_hofs_pipeline__u_cpu_entry__l163_d;
    end
end // l163
assign reg0_d0 = u_hofs_package__u_hofs_pipeline__u_cpu_entry__l163_q[0];
assign reg0_d3 = u_hofs_package__u_hofs_pipeline__u_cpu_entry__l163_q[2];
assign reg0_d4 = u_hofs_package__u_hofs_pipeline__u_cpu_entry__l163_q[3];

always @(posedge reg_wr_n[1] or negedge u_hofs_package__u_hofs_pipeline__u_cpu_entry__m159a_y) begin
    if (!u_hofs_package__u_hofs_pipeline__u_cpu_entry__m159a_y) begin
        u_hofs_package__u_hofs_pipeline__u_cpu_entry__k163_q <= 4'd0;
    end else begin
        u_hofs_package__u_hofs_pipeline__u_cpu_entry__k163_q <= u_hofs_package__u_hofs_pipeline__u_cpu_entry__k163_d;
    end
end // k163
assign reg2_d6 = u_hofs_package__u_hofs_pipeline__u_cpu_entry__k163_q[0];
assign reg2_d4 = u_hofs_package__u_hofs_pipeline__u_cpu_entry__k163_q[1];
assign reg2_d2 = u_hofs_package__u_hofs_pipeline__u_cpu_entry__k163_q[2];
assign reg2_d0 = u_hofs_package__u_hofs_pipeline__u_cpu_entry__k163_q[3];

always @(posedge reg_wr_n[2] or negedge u_hofs_package__u_hofs_pipeline__u_cpu_entry__m159a_y) begin
    if (!u_hofs_package__u_hofs_pipeline__u_cpu_entry__m159a_y) begin
        u_hofs_package__u_hofs_pipeline__u_cpu_entry__l138_q <= 4'd0;
    end else begin
        u_hofs_package__u_hofs_pipeline__u_cpu_entry__l138_q <= u_hofs_package__u_hofs_pipeline__u_cpu_entry__l138_d;
    end
end // l138
assign reg4_d3 = u_hofs_package__u_hofs_pipeline__u_cpu_entry__l138_q[0]; // p66a
assign reg4_d3_buf = reg4_d3; // n83a
assign reg4_d3_buf2 = reg4_d3; // n106a
assign reg4_d3_buf3 = reg4_d3; // m27a
assign u_hofs_package__u_hofs_pipeline__u_cpu_entry__reg4_d4_src = u_hofs_package__u_hofs_pipeline__u_cpu_entry__l138_q[1];
assign reg4_d5     = u_hofs_package__u_hofs_pipeline__u_cpu_entry__l138_q[2];
assign reg4_d6     = u_hofs_package__u_hofs_pipeline__u_cpu_entry__l138_q[3];

assign g124a = u_hofs_package__u_hofs_pipeline__u_cpu_entry__reg4_d4_src; // g124a
assign reg4_d4_buf = g124a; // n142a
assign reg4_d4_buf2 = u_hofs_package__u_hofs_pipeline__u_cpu_entry__reg4_d4_src; // g112a
assign reg4_d4_buf3 = u_hofs_package__u_hofs_pipeline__u_cpu_entry__reg4_d4_src; // g113b
always @(posedge reg_wr_n[3] or negedge u_hofs_package__u_hofs_pipeline__u_cpu_entry__m159a_y) begin
    if (!u_hofs_package__u_hofs_pipeline__u_cpu_entry__m159a_y) begin
        u_hofs_package__u_hofs_pipeline__u_cpu_entry__m165_q <= 4'd0;
    end else begin
        u_hofs_package__u_hofs_pipeline__u_cpu_entry__m165_q <= u_hofs_package__u_hofs_pipeline__u_cpu_entry__m165_d;
    end
end // m165
assign reg6_d5 = u_hofs_package__u_hofs_pipeline__u_cpu_entry__m165_q[1];

assign u_hofs_package__u_hofs_pipeline__reg6_d6 = u_hofs_package__u_hofs_pipeline__u_cpu_entry__m165_q[2]; // n183a
assign u_hofs_package__u_hofs_pipeline__reg6_d7 = u_hofs_package__u_hofs_pipeline__u_cpu_entry__m165_q[3]; // n186a
// End inlined jt054157_page02_cpu_entry u_cpu_entry

// Inlined jt054157_page01_clock_fanout u_clock_fanout
reg u_clock_fanout__k116_q;
reg     u_clock_fanout__l152_q;

assign u_hofs_package__u_hofs_pipeline__k112_y = nres_sync2; // k112
always @(posedge pin_clk or negedge u_hofs_package__u_hofs_pipeline__k112_y) begin
    if (!u_hofs_package__u_hofs_pipeline__k112_y) begin
        u_clock_fanout__k116_q <= 1'b1;
    end else begin
        u_clock_fanout__k116_q <= u_hofs_package__u_hofs_pipeline__k116_nq;
    end
end // k116

assign u_hofs_package__u_hofs_pipeline__k116_nq = ~u_clock_fanout__k116_q; // k116
assign j136a = u_clock_fanout__k116_q; // j136a
assign k114a = u_hofs_package__u_hofs_pipeline__k116_nq; // k114a
assign j152a = k114a; // j152a
assign j121b = k114a; // j121b
assign j152b = j121b; // j152b
always @(posedge j152b or negedge reg0_d3) begin
    if (!reg0_d3) begin
        u_clock_fanout__l152_q <= 1'b1;
    end else begin
        u_clock_fanout__l152_q <= pin113;
    end
end // l152

assign u_hofs_package__u_hofs_pipeline__l152_nq = ~u_clock_fanout__l152_q; // l152
assign l135a = ~&{u_hofs_package__u_hofs_pipeline__l152_nq,pin113}; // l135a
assign u_hofs_package__u_hofs_pipeline__k116_q = u_clock_fanout__k116_q;
// End inlined jt054157_page01_clock_fanout u_clock_fanout

// Inlined jt054157_page01_lower_state u_lower_state
reg u_lower_state__l155_q;
reg u_lower_state__k147a_q;
reg u_lower_state__k144_q;
assign u_hofs_package__u_hofs_pipeline__l161a = u_hofs_package__u_hofs_pipeline_pin_counter__k159a; // u_hofs_package__u_hofs_pipeline__l161a
assign u_hofs_package__u_hofs_pipeline__l159 = u_hofs_package__u_hofs_pipeline__l161a ^ u_hofs_package__u_hofs_pipeline_pin_counter__k153b; // u_hofs_package__u_hofs_pipeline__l159
assign u_hofs_package__u_hofs_pipeline__l161b = l135a & u_hofs_package__u_hofs_pipeline__l159; // u_hofs_package__u_hofs_pipeline__l161b
always @(posedge j152b or negedge nres_sync) begin
    if (!nres_sync) begin
        u_lower_state__l155_q <= 1'b0;
    end else begin
        u_lower_state__l155_q <= u_hofs_package__u_hofs_pipeline__l161b;
    end
end // l155a

assign u_hofs_package__u_hofs_pipeline__l155_nq = ~u_lower_state__l155_q; // l155a
assign u_hofs_package__u_hofs_pipeline_pin_counter__k159a = u_lower_state__l155_q; // u_hofs_package__u_hofs_pipeline_pin_counter__k159a
assign u_hofs_package__u_hofs_pipeline__k142 = u_hofs_package__u_hofs_pipeline__k160b ^ u_hofs_package__u_hofs_pipeline_pin_counter__k137a; // u_hofs_package__u_hofs_pipeline__k142
assign u_hofs_package__u_hofs_pipeline__k138b = l135a & u_hofs_package__u_hofs_pipeline__k142; // u_hofs_package__u_hofs_pipeline__k138b
always @(posedge j152b or negedge nres_sync2) begin
    if (!nres_sync2) begin
        u_lower_state__k147a_q <= 1'b0;
    end else begin
        u_lower_state__k147a_q <= u_hofs_package__u_hofs_pipeline__k138b;
    end
end // k147a

assign u_hofs_package__u_hofs_pipeline__k147a_nq = ~u_lower_state__k147a_q; // k147a
assign u_hofs_package__u_hofs_pipeline_pin_counter__k137a = u_lower_state__k147a_q; // u_hofs_package__u_hofs_pipeline_pin_counter__k137a
assign u_hofs_package__u_hofs_pipeline_pin_counter__j156a = u_hofs_package__u_hofs_pipeline__k147a_nq; // u_hofs_package__u_hofs_pipeline_pin_counter__j156a
assign u_hofs_package__u_hofs_pipeline__k135a = l135a & u_hofs_package__u_hofs_pipeline__k142; // u_hofs_package__u_hofs_pipeline__k135a
always @(posedge j152b or negedge nres_sync2) begin
    if (!nres_sync2) begin
        u_lower_state__k144_q <= 1'b0;
    end else begin
        u_lower_state__k144_q <= u_hofs_package__u_hofs_pipeline__k135a;
    end
end // k144

assign u_page09_hofs_package__k144_xq = ~u_lower_state__k144_q; // k144
assign u_hofs_package__u_hofs_pipeline_pin_counter__k153a = u_lower_state__k144_q; // u_hofs_package__u_hofs_pipeline_pin_counter__k153a
assign u_hofs_package__u_hofs_pipeline__k160b = ~u_hofs_package__u_hofs_pipeline_pin_counter__k153a; // u_hofs_package__u_hofs_pipeline__k160b
assign u_hofs_package__u_hofs_pipeline_pin_counter__k153b = u_hofs_package__u_hofs_pipeline__k160b | u_hofs_package__u_hofs_pipeline_pin_counter__k137a; // u_hofs_package__u_hofs_pipeline_pin_counter__k153b
assign u_hofs_package__u_hofs_pipeline__l155_q = u_lower_state__l155_q;
assign u_hofs_package__u_hofs_pipeline__k147a_q = u_lower_state__k147a_q;
assign u_hofs_package__u_hofs_pipeline__k144_q = u_lower_state__k144_q;
// End inlined jt054157_page01_lower_state u_lower_state

// Inlined jt054157_page01_counter_raw u_counter_raw
wire u_counter_raw__hcnt2;
wire u_counter_raw__hcnt1;
wire u_counter_raw__hcnt0;
assign u_hofs_package__u_hofs_pipeline__reg0_d0_buf = reg0_d0; // k188b
assign u_hofs_package__u_hofs_pipeline_pin_counter__k155 = ~(u_hofs_package__u_hofs_pipeline__reg0_d0_buf ^ u_hofs_package__u_hofs_pipeline_pin_counter__k159a); // u_hofs_package__u_hofs_pipeline_pin_counter__k155
assign u_hofs_package__u_hofs_pipeline_pin_counter__k157 = ~(u_hofs_package__u_hofs_pipeline__reg0_d0_buf ^ u_hofs_package__u_hofs_pipeline_pin_counter__j156a); // u_hofs_package__u_hofs_pipeline_pin_counter__k157
assign u_hofs_package__u_hofs_pipeline_pin_counter__k161 = u_hofs_package__u_hofs_pipeline__reg0_d0_buf ^ u_hofs_package__u_hofs_pipeline_pin_counter__k159a; // u_hofs_package__u_hofs_pipeline_pin_counter__k161
assign u_counter_raw__hcnt2 = u_hofs_package__u_hofs_pipeline_pin_counter__k161; // h159a
assign u_hofs_package__u_hofs_pipeline__k192 = hcnt1_raw ^ u_hofs_package__u_hofs_pipeline_pin_counter__j156a; // u_hofs_package__u_hofs_pipeline__k192
assign u_counter_raw__hcnt1 = u_hofs_package__u_hofs_pipeline__k192; // k200a
assign u_hofs_package__u_hofs_pipeline__k194 = hcnt0_raw ^ u_hofs_package__u_hofs_pipeline_pin_counter__k153a; // u_hofs_package__u_hofs_pipeline__k194
assign u_counter_raw__hcnt0 = u_hofs_package__u_hofs_pipeline__k194; // k196b
assign u_hofs_package__u_hofs_pipeline_pin_counter__j161b = ~reg0_d4; // u_hofs_package__u_hofs_pipeline_pin_counter__j161b
assign u_hofs_package__u_hofs_pipeline_pin_counter__j161a = u_hofs_package__u_hofs_pipeline_pin_counter__k153a; // u_hofs_package__u_hofs_pipeline_pin_counter__j161a
assign hcnt[2] = u_counter_raw__hcnt2;
assign hcnt[1] = u_counter_raw__hcnt1;
assign hcnt[0] = u_counter_raw__hcnt0;
// End inlined jt054157_page01_counter_raw u_counter_raw

// Inlined jt054157_page01_load_ctrl u_load_ctrl
wire    u_load_ctrl__reg0_d0_buf;
wire [2:0] u_load_ctrl__hofsa_x, u_load_ctrl__hofsb_x, u_load_ctrl__hofsc_x, u_load_ctrl__hofsd_x;
wire    u_load_ctrl__j164a_y, u_load_ctrl__l190a_y, u_load_ctrl__k154_y, u_load_ctrl__j163_y;
wire [3:0] u_load_ctrl__j141_d;
reg [3:0] u_load_ctrl__load_q;
assign u_load_ctrl__j141_d = { u_load_ctrl__j163_y, u_load_ctrl__k154_y, u_load_ctrl__l190a_y, u_load_ctrl__j164a_y };

assign u_load_ctrl__reg0_d0_buf = reg0_d0; // k186a
assign u_load_ctrl__hofsa_x[0] = u_load_ctrl__reg0_d0_buf ^ hofsa[0]; // j170
assign u_load_ctrl__hofsa_x[1] = u_load_ctrl__reg0_d0_buf ^ hofsa[1]; // j180
assign u_load_ctrl__hofsa_x[2] = u_load_ctrl__reg0_d0_buf ^ hofsa[2]; // j166
assign u_load_ctrl__hofsb_x[0] = u_load_ctrl__reg0_d0_buf ^ hofs_b[0]; // h157
assign u_load_ctrl__hofsb_x[1] = u_load_ctrl__reg0_d0_buf ^ hofs_b[1]; // h163
assign u_load_ctrl__hofsb_x[2] = u_load_ctrl__reg0_d0_buf ^ hofs_b[2]; // h161
assign u_load_ctrl__hofsc_x[0] = u_load_ctrl__reg0_d0_buf ^ hofsc[0]; // l192
assign u_load_ctrl__hofsc_x[1] = u_load_ctrl__reg0_d0_buf ^ hofsc[1]; // l194
assign u_load_ctrl__hofsc_x[2] = u_load_ctrl__reg0_d0_buf ^ hofsc[2]; // l196
assign u_load_ctrl__hofsd_x[0] = u_load_ctrl__reg0_d0_buf ^ hofsd[0]; // j178
assign u_load_ctrl__hofsd_x[1] = u_load_ctrl__reg0_d0_buf ^ hofsd[1]; // j176
assign u_load_ctrl__hofsd_x[2] = u_load_ctrl__reg0_d0_buf ^ hofsd[2]; // j182
assign u_load_ctrl__j164a_y = ~&{u_load_ctrl__hofsd_x[0],u_load_ctrl__hofsd_x[1],u_load_ctrl__hofsd_x[2]}; // j164a
assign u_load_ctrl__l190a_y = ~&{u_load_ctrl__hofsc_x[0],u_load_ctrl__hofsc_x[1],u_load_ctrl__hofsc_x[2]}; // l190a
assign u_load_ctrl__k154_y = ~&{u_load_ctrl__hofsb_x[0],u_load_ctrl__hofsb_x[1],u_load_ctrl__hofsb_x[2]}; // k154
assign u_load_ctrl__j163_y = ~&{u_load_ctrl__hofsa_x[0],u_load_ctrl__hofsa_x[1],u_load_ctrl__hofsa_x[2]}; // j163
always @(posedge j136a) begin
    u_load_ctrl__load_q <= u_load_ctrl__j141_d; // j141
end
assign loadd = u_load_ctrl__load_q[0];
assign loadc = u_load_ctrl__load_q[1];
assign loadb = u_load_ctrl__load_q[2];
assign loada = u_load_ctrl__load_q[3];
// End inlined jt054157_page01_load_ctrl u_load_ctrl

// Inlined jt054157_page05_col_select u_col_select
wire u_hofs_package__u_hofs_pipeline__u_col_select__unused_m27b_y;
wire u_hofs_package__u_hofs_pipeline__u_col_select__unused_n25a_y;
wire u_hofs_package__u_hofs_pipeline__u_col_select__unused_m28b_y;
wire u_hofs_package__u_hofs_pipeline__u_col_select__unused_m192a_x;
wire u_hofs_package__u_hofs_pipeline__u_col_select__unused_n197_x;
wire u_hofs_package__u_hofs_pipeline__u_col_select__unused_m201a_x;
wire u_hofs_package__u_hofs_pipeline__u_col_select__unused_m197_x;
wire u_hofs_package__u_hofs_pipeline__u_col_select__unused_n201a_x;
wire u_hofs_package__u_hofs_pipeline__u_col_select__unused_m208_x;
wire u_hofs_package__u_hofs_pipeline__u_col_select__unused_n207a_x;
wire u_hofs_package__u_hofs_pipeline__u_col_select__n195b_y, u_hofs_package__u_hofs_pipeline__u_col_select__m191a_y;
wire u_hofs_package__u_hofs_pipeline__u_col_select__n194a_y, u_hofs_package__u_hofs_pipeline__u_col_select__n196b_y;
wire u_hofs_package__u_hofs_pipeline__u_col_select__n194b_y, u_hofs_package__u_hofs_pipeline__u_col_select__m212a_y;
wire u_hofs_package__u_hofs_pipeline__u_col_select__n193a_y, u_hofs_package__u_hofs_pipeline__u_col_select__m192b_y;
wire u_hofs_package__u_hofs_pipeline__u_col_select__n195a_y, u_hofs_package__u_hofs_pipeline__u_col_select__m196a_y;
wire u_hofs_package__u_hofs_pipeline__u_col_select__n212a_y, u_hofs_package__u_hofs_pipeline__u_col_select__m213a_y;
wire u_hofs_package__u_hofs_pipeline__u_col_select__n213b_y, u_hofs_package__u_hofs_pipeline__u_col_select__n213a_y;

wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__m192a_a_resolved = { pin_col2, u_hofs_package__u_hofs_pipeline__u_col_select__n195b_y, u_hofs_package__u_hofs_pipeline__reg6_d6  };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__m192a_b_resolved = { u_hofs_package__u_hofs_pipeline__u_col_select__m191a_y,  u_hofs_package__u_hofs_pipeline__u_col_select__n195b_y, pin_col2 };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__m192a_c_resolved = { pin_col4, u_hofs_package__u_hofs_pipeline__reg6_d7, u_hofs_package__u_hofs_pipeline__reg6_d6  };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__m192a_d_resolved = { u_hofs_package__u_hofs_pipeline__u_col_select__m191a_y,  u_hofs_package__u_hofs_pipeline__reg6_d7, pin_col4 };

wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__n197_a_resolved  = { pin_col1, u_hofs_package__u_hofs_pipeline__u_col_select__n194a_y, u_hofs_package__u_hofs_pipeline__reg6_d6  };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__n197_b_resolved  = { u_hofs_package__u_hofs_pipeline__u_col_select__n196b_y,  u_hofs_package__u_hofs_pipeline__u_col_select__n194a_y, pin_col1 };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__n197_c_resolved  = { pin_col4, u_hofs_package__u_hofs_pipeline__reg6_d7, u_hofs_package__u_hofs_pipeline__reg6_d6  };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__n197_d_resolved  = { u_hofs_package__u_hofs_pipeline__u_col_select__n196b_y,  u_hofs_package__u_hofs_pipeline__reg6_d7, pin_col4 };

wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__m201a_a_resolved = { pin_col0, u_hofs_package__u_hofs_pipeline__u_col_select__n194b_y, u_hofs_package__u_hofs_pipeline__reg6_d6  };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__m201a_b_resolved = { u_hofs_package__u_hofs_pipeline__u_col_select__m212a_y,  u_hofs_package__u_hofs_pipeline__u_col_select__n194b_y, pin_col0 };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__m201a_c_resolved = { pin_col2, u_hofs_package__u_hofs_pipeline__reg6_d7, u_hofs_package__u_hofs_pipeline__reg6_d6  };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__m201a_d_resolved = { u_hofs_package__u_hofs_pipeline__u_col_select__m212a_y,  u_hofs_package__u_hofs_pipeline__reg6_d7, pin_col2 };

wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__m197_a_resolved  = { pin_col4, u_hofs_package__u_hofs_pipeline__u_col_select__n193a_y, u_hofs_package__u_hofs_pipeline__reg6_d6  };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__m197_b_resolved  = { u_hofs_package__u_hofs_pipeline__u_col_select__m192b_y,  u_hofs_package__u_hofs_pipeline__u_col_select__n193a_y, pin_col6 };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__m197_c_resolved  = { pin_col0, u_hofs_package__u_hofs_pipeline__reg6_d7, u_hofs_package__u_hofs_pipeline__reg6_d6  };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__m197_d_resolved  = { u_hofs_package__u_hofs_pipeline__u_col_select__m192b_y,  u_hofs_package__u_hofs_pipeline__reg6_d7, pin_col2 };

wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__n201a_a_resolved = { pin_col7, u_hofs_package__u_hofs_pipeline__u_col_select__n195a_y, u_hofs_package__u_hofs_pipeline__reg6_d6  };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__n201a_b_resolved = { u_hofs_package__u_hofs_pipeline__u_col_select__m196a_y,  u_hofs_package__u_hofs_pipeline__u_col_select__n195a_y, pin_col5 };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__n201a_c_resolved = { pin_col7, u_hofs_package__u_hofs_pipeline__reg6_d7, u_hofs_package__u_hofs_pipeline__reg6_d6  };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__n201a_d_resolved = { u_hofs_package__u_hofs_pipeline__u_col_select__m196a_y,  u_hofs_package__u_hofs_pipeline__reg6_d7, pin_col7 };

wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__m208_a_resolved  = { pin_col6, u_hofs_package__u_hofs_pipeline__u_col_select__n212a_y, u_hofs_package__u_hofs_pipeline__reg6_d6  };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__m208_b_resolved  = { u_hofs_package__u_hofs_pipeline__u_col_select__m213a_y,  u_hofs_package__u_hofs_pipeline__u_col_select__n212a_y, pin_col4 };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__m208_c_resolved  = { pin_col6, u_hofs_package__u_hofs_pipeline__reg6_d7, u_hofs_package__u_hofs_pipeline__reg6_d6  };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__m208_d_resolved  = { u_hofs_package__u_hofs_pipeline__u_col_select__m213a_y,  u_hofs_package__u_hofs_pipeline__reg6_d7, pin_col6 };

wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__n207a_a_resolved = { pin_col3, u_hofs_package__u_hofs_pipeline__u_col_select__n213b_y, u_hofs_package__u_hofs_pipeline__reg6_d6  };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__n207a_b_resolved = { u_hofs_package__u_hofs_pipeline__u_col_select__n213a_y,  u_hofs_package__u_hofs_pipeline__u_col_select__n213b_y, pin_col3 };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__n207a_c_resolved = { pin_col5, u_hofs_package__u_hofs_pipeline__reg6_d7, u_hofs_package__u_hofs_pipeline__reg6_d6  };
wire [2:0] u_hofs_package__u_hofs_pipeline__u_col_select__n207a_d_resolved = { u_hofs_package__u_hofs_pipeline__u_col_select__n213a_y,  u_hofs_package__u_hofs_pipeline__reg6_d7, pin_col5 };

assign u_hofs_package__u_hofs_pipeline__u_col_select__n195b_y = ~u_hofs_package__u_hofs_pipeline__reg6_d7; // n195b
assign u_hofs_package__u_hofs_pipeline__u_col_select__m191a_y = ~u_hofs_package__u_hofs_pipeline__reg6_d6; // m191a
assign u_hofs_package__u_hofs_pipeline__u_col_select__n194a_y = ~u_hofs_package__u_hofs_pipeline__reg6_d7; // n194a
assign u_hofs_package__u_hofs_pipeline__u_col_select__n196b_y = ~u_hofs_package__u_hofs_pipeline__reg6_d6; // n196b
assign u_hofs_package__u_hofs_pipeline__u_col_select__n194b_y = ~u_hofs_package__u_hofs_pipeline__reg6_d7; // n194b
assign u_hofs_package__u_hofs_pipeline__u_col_select__m212a_y = ~u_hofs_package__u_hofs_pipeline__reg6_d6; // m212a
assign u_hofs_package__u_hofs_pipeline__u_col_select__n193a_y = ~u_hofs_package__u_hofs_pipeline__reg6_d7; // n193a
assign u_hofs_package__u_hofs_pipeline__u_col_select__m192b_y = ~u_hofs_package__u_hofs_pipeline__reg6_d6; // m192b
assign u_hofs_package__u_hofs_pipeline__u_col_select__n195a_y = ~u_hofs_package__u_hofs_pipeline__reg6_d7; // n195a
assign u_hofs_package__u_hofs_pipeline__u_col_select__m196a_y = ~u_hofs_package__u_hofs_pipeline__reg6_d6; // m196a
assign u_hofs_package__u_hofs_pipeline__u_col_select__n212a_y = ~u_hofs_package__u_hofs_pipeline__reg6_d7; // n212a
assign u_hofs_package__u_hofs_pipeline__u_col_select__m213a_y = ~u_hofs_package__u_hofs_pipeline__reg6_d6; // m213a
assign u_hofs_package__u_hofs_pipeline__u_col_select__n213b_y = ~u_hofs_package__u_hofs_pipeline__reg6_d7; // n213b
assign u_hofs_package__u_hofs_pipeline__u_col_select__n213a_y = ~u_hofs_package__u_hofs_pipeline__reg6_d6; // n213a
assign u_hofs_package__u_hofs_pipeline__u_col_select__unused_m192a_x = ~(|{ &u_hofs_package__u_hofs_pipeline__u_col_select__m192a_a_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__m192a_b_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__m192a_c_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__m192a_d_resolved }); // m192a
assign u_hofs_package__u_hofs_pipeline__u_col_select__unused_m27b_y = ~u_hofs_package__u_hofs_pipeline__u_col_select__unused_m192a_x; // m27b
assign u_hofs_package__u_hofs_pipeline__u_col_select__unused_n197_x = ~(|{ &u_hofs_package__u_hofs_pipeline__u_col_select__n197_a_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__n197_b_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__n197_c_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__n197_d_resolved }); // n197
assign u_hofs_package__u_hofs_pipeline__u_col_select__unused_n25a_y = ~u_hofs_package__u_hofs_pipeline__u_col_select__unused_n197_x; // n25a
assign u_hofs_package__u_hofs_pipeline__u_col_select__unused_m201a_x = ~(|{ &u_hofs_package__u_hofs_pipeline__u_col_select__m201a_a_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__m201a_b_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__m201a_c_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__m201a_d_resolved }); // m201a
assign u_hofs_package__u_hofs_pipeline__u_col_select__unused_m28b_y = ~u_hofs_package__u_hofs_pipeline__u_col_select__unused_m201a_x; // m28b
assign u_hofs_package__u_hofs_pipeline__u_col_select__unused_m197_x = ~(|{ &u_hofs_package__u_hofs_pipeline__u_col_select__m197_a_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__m197_b_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__m197_c_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__m197_d_resolved }); // m197
assign u_hofs_package__u_hofs_pipeline__l29a_y = ~u_hofs_package__u_hofs_pipeline__u_col_select__unused_m197_x; // l29a
assign u_hofs_package__u_hofs_pipeline__u_col_select__unused_n201a_x = ~(|{ &u_hofs_package__u_hofs_pipeline__u_col_select__n201a_a_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__n201a_b_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__n201a_c_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__n201a_d_resolved }); // n201a
assign u_hofs_package__u_hofs_pipeline__l30b_y = ~u_hofs_package__u_hofs_pipeline__u_col_select__unused_n201a_x; // l30b
assign u_hofs_package__u_hofs_pipeline__u_col_select__unused_m208_x = ~(|{ &u_hofs_package__u_hofs_pipeline__u_col_select__m208_a_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__m208_b_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__m208_c_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__m208_d_resolved }); // m208
assign u_hofs_package__u_hofs_pipeline__l12a_y = ~u_hofs_package__u_hofs_pipeline__u_col_select__unused_m208_x; // l12a
assign u_hofs_package__u_hofs_pipeline__u_col_select__unused_n207a_x = ~(|{ &u_hofs_package__u_hofs_pipeline__u_col_select__n207a_a_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__n207a_b_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__n207a_c_resolved, &u_hofs_package__u_hofs_pipeline__u_col_select__n207a_d_resolved }); // n207a
assign u_hofs_package__u_hofs_pipeline__l30a_y = ~u_hofs_package__u_hofs_pipeline__u_col_select__unused_n207a_x; // l30a
// End inlined jt054157_page05_col_select u_col_select

// Inlined jt054157_page05_06_07_hofs_path_integrated u_hofs_path
// Inlined jt054157_page07_h_offset u_h_offset
wire u_hofs_package__u_h_offset__unused_j205a_y;
wire u_hofs_package__u_h_offset__unused_j205b_y;
wire u_hofs_package__u_h_offset__unused_j204a_y;
reg [2:0] u_hofs_package__u_h_offset__unused_hofsd_q;
reg [2:0] u_hofs_package__u_h_offset__unused_hofsc_q;
reg [2:0] u_hofs_package__u_h_offset__unused_hofsa_q;
reg [2:0] u_hofs_package__u_h_offset__unused_hofs_b_q;
wire [2:0] u_hofs_package__u_h_offset__unused_hofsd_co;
wire [2:0] u_hofs_package__u_h_offset__unused_hofsc_co;
wire [2:0] u_hofs_package__u_h_offset__unused_hofsa_co;
wire [2:0] u_hofs_package__u_h_offset__unused_hofs_b_co;
wire    u_hofs_package__u_h_offset__k176a_y;
wire    u_hofs_package__u_h_offset__hofsd_s2, u_hofs_package__u_h_offset__hofsd_s1, u_hofs_package__u_h_offset__hofsd_s0;
wire    u_hofs_package__u_h_offset__hofsc_s2, u_hofs_package__u_h_offset__hofsc_s1, u_hofs_package__u_h_offset__hofsc_s0;
wire    u_hofs_package__u_h_offset__hofsa_s2, u_hofs_package__u_h_offset__hofsa_s1, u_hofs_package__u_h_offset__hofsa_s0;
wire    u_hofs_package__u_h_offset__hofs_b_s2, u_hofs_package__u_h_offset__hofs_b_s1, u_hofs_package__u_h_offset__hofs_b_s0;
assign u_hofs_package__u_h_offset__k176a_y = hcnt1_raw; // k176a
assign j172_x_n = ~j152a ? ~(4'b0001 << { hcnt0_raw, u_hofs_package__u_h_offset__k176a_y }) : 4'hf; // j172
assign u_hofs_package__u_h_offset__unused_j205a_y = pin_z4h; // j205a
assign u_hofs_package__u_h_offset__unused_j205b_y = pin_z2h; // j205b
assign u_hofs_package__u_h_offset__unused_j204a_y = pin_z1h; // j204a
always @(posedge j172_x_n[3]) begin
    {u_hofs_package__u_h_offset__unused_hofsd_q[2],u_hofs_package__u_h_offset__unused_hofsd_q[1],u_hofs_package__u_h_offset__unused_hofsd_q[0]} <= {u_hofs_package__u_h_offset__unused_j205a_y,u_hofs_package__u_h_offset__unused_j205b_y,u_hofs_package__u_h_offset__unused_j204a_y}; // h209, h206, j207
end
assign u_hofs_package__u_h_offset__hofsd_s0 = hcnt[0] ^ u_hofs_package__u_h_offset__unused_hofsd_q[0]; // k208
assign u_hofs_package__u_h_offset__unused_hofsd_co[0] = hcnt[0] & u_hofs_package__u_h_offset__unused_hofsd_q[0]; // k208
assign { u_hofs_package__u_h_offset__unused_hofsd_co[1], u_hofs_package__u_h_offset__hofsd_s1 } = { 1'b0, hcnt[1] } + { 1'b0, u_hofs_package__u_h_offset__unused_hofsd_q[1] } + { 1'b0, u_hofs_package__u_h_offset__unused_hofsd_co[0] }; // k212
assign { u_hofs_package__u_h_offset__unused_hofsd_co[2], u_hofs_package__u_h_offset__hofsd_s2 } = { 1'b0, hcnt[2] } + { 1'b0, u_hofs_package__u_h_offset__unused_hofsd_q[2] } + { 1'b0, u_hofs_package__u_h_offset__unused_hofsd_co[1] }; // h214
assign hofsd[0] = u_hofs_package__u_h_offset__hofsd_s0; // k200b
assign hofsd[1] = u_hofs_package__u_h_offset__hofsd_s1; // k210a
assign hofsd[2] = u_hofs_package__u_h_offset__hofsd_s2; // h212a
always @(posedge j172_x_n[2]) begin
    {u_hofs_package__u_h_offset__unused_hofsc_q[2],u_hofs_package__u_h_offset__unused_hofsc_q[1],u_hofs_package__u_h_offset__unused_hofsc_q[0]} <= {u_hofs_package__u_h_offset__unused_j205a_y,u_hofs_package__u_h_offset__unused_j205b_y,u_hofs_package__u_h_offset__unused_j204a_y}; // j197, j194, j191
end
assign u_hofs_package__u_h_offset__hofsc_s0 = hcnt[0] ^ u_hofs_package__u_h_offset__unused_hofsc_q[0]; // k197a
assign u_hofs_package__u_h_offset__unused_hofsc_co[0] = hcnt[0] & u_hofs_package__u_h_offset__unused_hofsc_q[0]; // k197a
assign { u_hofs_package__u_h_offset__unused_hofsc_co[1], u_hofs_package__u_h_offset__hofsc_s1 } = { 1'b0, hcnt[1] } + { 1'b0, u_hofs_package__u_h_offset__unused_hofsc_q[1] } + { 1'b0, u_hofs_package__u_h_offset__unused_hofsc_co[0] }; // k202
assign { u_hofs_package__u_h_offset__unused_hofsc_co[2], u_hofs_package__u_h_offset__hofsc_s2 } = { 1'b0, hcnt[2] } + { 1'b0, u_hofs_package__u_h_offset__unused_hofsc_q[2] } + { 1'b0, u_hofs_package__u_h_offset__unused_hofsc_co[1] }; // j200
assign hofsc[0] = u_hofs_package__u_h_offset__hofsc_s0; // l202a
assign hofsc[1] = u_hofs_package__u_h_offset__hofsc_s1; // l204b
assign hofsc[2] = u_hofs_package__u_h_offset__hofsc_s2; // l204a
always @(posedge j172_x_n[1]) begin
    {u_hofs_package__u_h_offset__unused_hofsa_q[2],u_hofs_package__u_h_offset__unused_hofsa_q[1],u_hofs_package__u_h_offset__unused_hofsa_q[0]} <= {u_hofs_package__u_h_offset__unused_j205a_y,u_hofs_package__u_h_offset__unused_j205b_y,u_hofs_package__u_h_offset__unused_j204a_y}; // h198, h201, j184
end
assign u_hofs_package__u_h_offset__hofsa_s0 = hcnt[0] ^ u_hofs_package__u_h_offset__unused_hofsa_q[0]; // j187
assign u_hofs_package__u_h_offset__unused_hofsa_co[0] = hcnt[0] & u_hofs_package__u_h_offset__unused_hofsa_q[0]; // j187
assign { u_hofs_package__u_h_offset__unused_hofsa_co[1], u_hofs_package__u_h_offset__hofsa_s1 } = { 1'b0, hcnt[1] } + { 1'b0, u_hofs_package__u_h_offset__unused_hofsa_q[1] } + { 1'b0, u_hofs_package__u_h_offset__unused_hofsa_co[0] }; // h194
assign { u_hofs_package__u_h_offset__unused_hofsa_co[2], u_hofs_package__u_h_offset__hofsa_s2 } = { 1'b0, hcnt[2] } + { 1'b0, u_hofs_package__u_h_offset__unused_hofsa_q[2] } + { 1'b0, u_hofs_package__u_h_offset__unused_hofsa_co[1] }; // h190
assign hofsa[0] = u_hofs_package__u_h_offset__hofsa_s0; // j168a
assign hofsa[1] = u_hofs_package__u_h_offset__hofsa_s1; // h204a
assign hofsa[2] = u_hofs_package__u_h_offset__hofsa_s2; // h167a
always @(posedge j172_x_n[0]) begin
    {u_hofs_package__u_h_offset__unused_hofs_b_q[2],u_hofs_package__u_h_offset__unused_hofs_b_q[1],u_hofs_package__u_h_offset__unused_hofs_b_q[0]} <= {u_hofs_package__u_h_offset__unused_j205a_y,u_hofs_package__u_h_offset__unused_j205b_y,u_hofs_package__u_h_offset__unused_j204a_y}; // h175, h187, h169
end
assign u_hofs_package__u_h_offset__hofs_b_s0 = hcnt[0] ^ u_hofs_package__u_h_offset__unused_hofs_b_q[0]; // h172a
assign u_hofs_package__u_h_offset__unused_hofs_b_co[0] = hcnt[0] & u_hofs_package__u_h_offset__unused_hofs_b_q[0]; // h172a
assign { u_hofs_package__u_h_offset__unused_hofs_b_co[1], u_hofs_package__u_h_offset__hofs_b_s1 } = { 1'b0, hcnt[1] } + { 1'b0, u_hofs_package__u_h_offset__unused_hofs_b_q[1] } + { 1'b0, u_hofs_package__u_h_offset__unused_hofs_b_co[0] }; // h183
assign { u_hofs_package__u_h_offset__unused_hofs_b_co[2], u_hofs_package__u_h_offset__hofs_b_s2 } = { 1'b0, hcnt[2] } + { 1'b0, u_hofs_package__u_h_offset__unused_hofs_b_q[2] } + { 1'b0, u_hofs_package__u_h_offset__unused_hofs_b_co[1] }; // h179
assign hofs_b[0] = u_hofs_package__u_h_offset__hofs_b_s0; // h165b
assign hofs_b[1] = u_hofs_package__u_h_offset__hofs_b_s1; // h167b
assign hofs_b[2] = u_hofs_package__u_h_offset__hofs_b_s2; // h165a
// End inlined jt054157_page07_h_offset u_h_offset

jt054157_page06_load_matrix_integrated u_load_matrix(
    .k114a   ( k114a   ),
    .j121b   ( j121b   ),
    .c114b   ( c114b   ),
    .loada   ( loada   ),
    .loadb   ( loadb   ),
    .loadc   ( loadc   ),
    .loadd   ( loadd   ),
    .h109_qa ( u_hofs_package__u_hofs_pipeline__h109_qa ),
    .h109_qb ( u_hofs_package__u_hofs_pipeline__h109_qb ),
    .h109_qc ( u_hofs_package__u_hofs_pipeline__h109_qc ),
    .h109_qd ( u_hofs_package__u_hofs_pipeline__h109_qd ),
    .c51a_y  (          ),
    .j125a_y (          ),
    .f129b_y (          ),
    .f132a_y (          ),
    .n83b_y  (          ),
    .c51b_y  (          ),
    .c62b_y  (          ),
    .j38b_y  (          ),
    .j47b_y  (          ),
    .c62a_y  (          ),
    .b98b_y  (          ),
    .b99a_y  (          ),
    .c100a_y (          ),
    .c100b_y (          ),
    .b109b_y (          ),
    .c113a_y (          ),
    .f135a   (          ),
    .f133b   (          ),
    .f137a   (          ),
    .f131b   (          ),
    .c139a   (          ),
    .c133b   (          ),
    .c133a   (          ),
    .d119a   (          ),
    .m39a    (          ),
    .m51a    (          ),
    .m39b    (          ),
    .m51b    (          ),
    .c45b    (          ),
    .c47b    (          ),
    .c49b    (          ),
    .c13a    (          ),
    .c82b    (          ),
    .c78a    (          ),
    .c80a    (          ),
    .c64a    (          ),
    .j2b     ( u_hofs_package__u_hofs_pipeline__j2b     ),
    .j13a    ( u_hofs_package__u_hofs_pipeline__j13a    ),
    .j39a    ( u_hofs_package__u_hofs_pipeline__j39a    ),
    .j2a     ( u_hofs_package__u_hofs_pipeline__j2a     ),
    .j13b    (          ),
    .j51b    (          ),
    .j51a    (          ),
    .j49a    (          ),
    .g23b    ( u_hofs_package__u_hofs_pipeline__g23b    ),
    .g21b    ( u_hofs_package__u_hofs_pipeline__g21b    ),
    .g25a    ( u_hofs_package__u_hofs_pipeline__g25a    ),
    .g7b     ( u_hofs_package__u_hofs_pipeline__g7b     ),
    .b81a    (          ),
    .b81b    (          ),
    .a99b    (          ),
    .b54a    (          ),
    .b97a    (          ),
    .b83a    (          ),
    .b96b    (          ),
    .b83b    (          ),
    .c96b    (          ),
    .c96a    (          ),
    .c93a    (          ),
    .c82a    (          ),
    .g86b    (          ),
    .g100a   (          ),
    .g92b    (          ),
    .g90b    (          ),
    .b111a   (          ),
    .b111b   (          ),
    .a121a   (          ),
    .b109a   (          ),
    .c139b   (          ),
    .c135a   (          ),
    .c137b   (          ),
    .c137a   (          )
);

// Inlined jt054157_page05_hofs_flips u_hofs_flips
reg [3:0] u_hofs_package__u_hofs_flips__k28_q;
reg [3:0] u_hofs_package__u_hofs_flips__k43_q;
reg [3:0] u_hofs_package__u_hofs_flips__k15_q;
reg [3:0] u_hofs_package__u_hofs_flips__l15_q;
reg [3:0] u_hofs_package__u_hofs_flips__l31_q;
reg [3:0] u_hofs_package__u_hofs_flips__l43_q;
reg [3:0] u_hofs_package__u_hofs_flips__k3_q;
reg [3:0] u_hofs_package__u_hofs_flips__h2_q;
wire    u_hofs_package__u_hofs_flips__hofsd_flip;
wire    u_hofs_package__u_hofs_flips__hofsc_flip;
wire    u_hofs_package__u_hofs_flips__hofs_b_flip;
wire    u_hofs_package__u_hofs_flips__hofsa_flip;
wire [2:0] u_hofs_package__u_hofs_flips__hofsd_x1b;
wire [2:0] u_hofs_package__u_hofs_flips__hofsc_x1b;
wire [2:0] u_hofs_package__u_hofs_flips__hofs_b_x1b;
wire [2:0] u_hofs_package__u_hofs_flips__hofsa_x1b;
always @(posedge u_hofs_package__u_hofs_pipeline__g23b) begin
    u_hofs_package__u_hofs_flips__k28_q <= u_hofs_package__u_hofs_pipeline__hofs_col_d; // k28
end
always @(posedge u_hofs_package__u_hofs_pipeline__j2b) begin
    u_hofs_package__u_hofs_flips__k43_q <= u_hofs_package__u_hofs_flips__k28_q; // k43
end
assign pin117 = u_hofs_package__u_hofs_flips__k43_q[2];
assign pin118 = u_hofs_package__u_hofs_flips__k43_q[1];
assign pin119 = u_hofs_package__u_hofs_flips__k43_q[0];

assign u_hofs_package__u_hofs_flips__hofsd_flip = reg2_d6 & u_hofs_package__u_hofs_flips__k43_q[3]; // g166b
assign u_hofs_package__u_hofs_flips__hofsd_x1b[2] = ~(hofsd[2] ^ u_hofs_package__u_hofs_flips__hofsd_flip); // g192
assign u_hofs_package__u_hofs_flips__hofsd_x1b[1] = ~(hofsd[1] ^ u_hofs_package__u_hofs_flips__hofsd_flip); // g173
assign u_hofs_package__u_hofs_flips__hofsd_x1b[0] = ~(hofsd[0] ^ u_hofs_package__u_hofs_flips__hofsd_flip); // g175
assign hofsd_f[2] = ~u_hofs_package__u_hofs_flips__hofsd_x1b[2]; // f205a
assign hofsd_f[1] = ~u_hofs_package__u_hofs_flips__hofsd_x1b[1]; // g168a
assign hofsd_f[0] = ~u_hofs_package__u_hofs_flips__hofsd_x1b[0]; // g168b
always @(posedge u_hofs_package__u_hofs_pipeline__g21b) begin
    u_hofs_package__u_hofs_flips__k15_q <= u_hofs_package__u_hofs_pipeline__hofs_col_d; // k15
end
always @(posedge u_hofs_package__u_hofs_pipeline__j13a) begin
    u_hofs_package__u_hofs_flips__l15_q <= u_hofs_package__u_hofs_flips__k15_q; // l15
end
assign pin125 = u_hofs_package__u_hofs_flips__l15_q[2];
assign pin126 = u_hofs_package__u_hofs_flips__l15_q[1];
assign pin127 = u_hofs_package__u_hofs_flips__l15_q[0];

assign u_hofs_package__u_hofs_flips__hofsc_flip = reg2_d4 & u_hofs_package__u_hofs_flips__l15_q[3]; // l176a
assign u_hofs_package__u_hofs_flips__hofsc_x1b[2] = ~(hofsc[2] ^ u_hofs_package__u_hofs_flips__hofsc_flip); // l207
assign u_hofs_package__u_hofs_flips__hofsc_x1b[1] = ~(hofsc[1] ^ u_hofs_package__u_hofs_flips__hofsc_flip); // l200
assign u_hofs_package__u_hofs_flips__hofsc_x1b[0] = ~(hofsc[0] ^ u_hofs_package__u_hofs_flips__hofsc_flip); // l198
assign hofsc_f[2] = ~u_hofs_package__u_hofs_flips__hofsc_x1b[2]; // l209a
assign hofsc_f[1] = ~u_hofs_package__u_hofs_flips__hofsc_x1b[1]; // l203b
assign hofsc_f[0] = ~u_hofs_package__u_hofs_flips__hofsc_x1b[0]; // l202b
always @(posedge u_hofs_package__u_hofs_pipeline__g25a) begin
    u_hofs_package__u_hofs_flips__l31_q <= u_hofs_package__u_hofs_pipeline__hofs_col_d; // l31
end
always @(posedge u_hofs_package__u_hofs_pipeline__j39a) begin
    u_hofs_package__u_hofs_flips__l43_q <= u_hofs_package__u_hofs_flips__l31_q; // l43
end
assign pin132 = u_hofs_package__u_hofs_flips__l43_q[2];
assign pin133 = u_hofs_package__u_hofs_flips__l43_q[1];
assign pin134 = u_hofs_package__u_hofs_flips__l43_q[0];

assign u_hofs_package__u_hofs_flips__hofs_b_flip = reg2_d2 & u_hofs_package__u_hofs_flips__l43_q[3]; // f137b
assign u_hofs_package__u_hofs_flips__hofs_b_x1b[2] = ~(hofs_b[2] ^ u_hofs_package__u_hofs_flips__hofs_b_flip); // f151
assign u_hofs_package__u_hofs_flips__hofs_b_x1b[1] = ~(hofs_b[1] ^ u_hofs_package__u_hofs_flips__hofs_b_flip); // g164
assign u_hofs_package__u_hofs_flips__hofs_b_x1b[0] = ~(hofs_b[0] ^ u_hofs_package__u_hofs_flips__hofs_b_flip); // f139
assign hofs_b_f[2] = ~u_hofs_package__u_hofs_flips__hofs_b_x1b[2]; // f136b
assign hofs_b_f[1] = ~u_hofs_package__u_hofs_flips__hofs_b_x1b[1]; // g169b
assign hofs_b_f[0] = ~u_hofs_package__u_hofs_flips__hofs_b_x1b[0]; // f134a
always @(posedge u_hofs_package__u_hofs_pipeline__g7b) begin
    u_hofs_package__u_hofs_flips__k3_q <= u_hofs_package__u_hofs_pipeline__hofs_col_d; // k3
end
always @(posedge u_hofs_package__u_hofs_pipeline__j2a) begin
    u_hofs_package__u_hofs_flips__h2_q <= u_hofs_package__u_hofs_flips__k3_q; // h2
end
assign pin138 = u_hofs_package__u_hofs_flips__h2_q[2];
assign pin141 = u_hofs_package__u_hofs_flips__h2_q[1];
assign pin142 = u_hofs_package__u_hofs_flips__h2_q[0];

assign u_hofs_package__u_hofs_flips__hofsa_flip = reg2_d0 & u_hofs_package__u_hofs_flips__h2_q[3]; // g166a
assign u_hofs_package__u_hofs_flips__hofsa_x1b[2] = ~(hofsa[2] ^ u_hofs_package__u_hofs_flips__hofsa_flip); // f174
assign u_hofs_package__u_hofs_flips__hofsa_x1b[1] = ~(hofsa[1] ^ u_hofs_package__u_hofs_flips__hofsa_flip); // f193
assign u_hofs_package__u_hofs_flips__hofsa_x1b[0] = ~(hofsa[0] ^ u_hofs_package__u_hofs_flips__hofsa_flip); // g171
assign hofsa_f[2] = ~u_hofs_package__u_hofs_flips__hofsa_x1b[2]; // e165b
assign hofsa_f[1] = ~u_hofs_package__u_hofs_flips__hofsa_x1b[1]; // e167b
assign hofsa_f[0] = ~u_hofs_package__u_hofs_flips__hofsa_x1b[0]; // e164a
assign u_hofs_package__u_hofs_pipeline__k28_q = u_hofs_package__u_hofs_flips__k28_q;
assign u_hofs_package__u_hofs_pipeline__k43_q = u_hofs_package__u_hofs_flips__k43_q;
assign u_hofs_package__u_hofs_pipeline__k15_q = u_hofs_package__u_hofs_flips__k15_q;
assign u_hofs_package__u_hofs_pipeline__l15_q = u_hofs_package__u_hofs_flips__l15_q;
assign u_hofs_package__u_hofs_pipeline__l31_q = u_hofs_package__u_hofs_flips__l31_q;
assign u_hofs_package__u_hofs_pipeline__l43_q = u_hofs_package__u_hofs_flips__l43_q;
assign u_hofs_package__u_hofs_pipeline__k3_q = u_hofs_package__u_hofs_flips__k3_q;
assign u_hofs_package__u_hofs_pipeline__h2_q = u_hofs_package__u_hofs_flips__h2_q;
// End inlined jt054157_page05_hofs_flips u_hofs_flips
// End inlined jt054157_page05_06_07_hofs_path_integrated u_hofs_path
// End inlined jt054157_hofs_pipeline_integrated u_hofs_pipeline
// End inlined jt054157_hofs_pipeline_pin_counter_integrated u_hofs_pipeline_pin_counter

// Inlined jt054157_hofs_package_output_map u_hofs_package_output_map
assign pin_114_out = pin114;
assign pin_115_out = pin115;
assign pin_116_out = pin116;
assign pin_117_out = pin117;
assign pin_118_out = pin118;
assign pin_119_out = pin119;
assign pin_125_out = pin125;
assign pin_126_out = pin126;
assign pin_127_out = pin127;
assign pin_132_out = pin132;
assign pin_133_out = pin133;
assign pin_134_out = pin134;
assign pin_138_out = pin138;
assign pin_141_out = pin141;
assign pin_142_out = pin142;
// End inlined jt054157_hofs_package_output_map u_hofs_package_output_map
// End inlined jt054157_hofs_package_integrated u_hofs_package

// Inlined jt054157_page09_package_integrated u_page09_package
// Inlined jt054157_page09_integrated u_page09
reg u_page09_package__u_page09__m76a_q;
reg u_page09_package__u_page09__m73_q;
reg u_page09_package__u_page09__l108a_q;
reg u_page09_package__u_page09__k119a_q;
assign m120a_y = ~reg4_d6; // m120a
assign m111a_y = ~&{m118a,u_page09_package__u_page09__k119a_q}; // m111a
assign p148 = pin_lds ^ reg6_d5; // p148
assign l130b_y = ~pin112; // l130b
assign l132b_y = pin_crom | l130b_y; // l132b
assign m121a_x = ~((reg4_d6 & pin95) | (m120a_y & m111a_y)); // m121a
assign n111a_y = ~m121a_x; // n111a
assign m181_x_n = ~l132b_y ? ~(4'b0001 << { pin_ab1, pin_ab2 }) : 4'hf; // m181
assign m187b_y = m181_x_n[0] & m181_x_n[1]; // m187b
assign m185b_y = m181_x_n[1] & m181_x_n[2]; // m185b
assign m187a_y = m181_x_n[2] & m181_x_n[3]; // m187a
assign m185a_y = m181_x_n[0] & m181_x_n[3]; // m185a
assign n108b_y = m187b_y | n111a_y; // n108b
assign p146b_y = m185b_y | p148; // p146b
assign r144a_y = m185b_y | pin_uds; // r144a
assign p146a_y = m187a_y | p148; // p146a
assign r144b_y = m187a_y | pin_uds; // r144b
assign n113b_y = m185a_y | n111a_y; // n113b
assign pin106 = p146b_y & l121b; // r140b
assign pin107 = r144a_y & l121b; // r142a
assign pin104 = p146a_y & l121b; // r142b
assign pin105 = r144b_y & l121b; // r140a
assign l114a_y = reg4_d6 | m118a; // l114a
assign l118b_y = ~&{l114a_y,pin95}; // l118b
assign l126b_y = ~&{pin112,reg4_d5}; // l126b
assign l108b_y = ~|{l118b_y,l126b_y}; // l108b
assign p159a_y = reg6_d5 & p148; // p159a
assign p162a_y = ~p159a_y; // p162a
assign p150b_y = ~reg6_d5; // p150b
assign p149a_y = p150b_y & p148; // p149a
assign l130a_y = |{pin95,pin_crom,pin112}; // l130a
assign p160b_y = p149a_y | l130a_y; // p160b
assign r161a_y = pin_uds | l130a_y; // r161a
assign l132a_y = ~&{reg4_d6,reg4_d5}; // l132a
assign p141b_y = pin_uds & pin_lds; // p141b
assign l127_y = |{pin_crom,l132a_y,p141b_y}; // l127
assign n65b_y = ~l127_y; // n65b
assign n65a_y = n65b_y; // n65a
assign m109a_y = j135a; // m109a
always @(posedge m118a or negedge n65a_y) begin
    if (!n65a_y) begin
        u_page09_package__u_page09__m76a_q <= 1'b1;
    end else begin
        u_page09_package__u_page09__m76a_q <= l127_y;
    end
end // m76a
always @(posedge m109a_y or negedge n65a_y) begin
    if (!n65a_y) begin
        u_page09_package__u_page09__m73_q <= 1'b1;
    end else begin
        u_page09_package__u_page09__m73_q <= u_page09_package__u_page09__m76a_q;
    end
end // m73
assign k124b_y = ~reg0_d4; // k124b
assign k137b_y = ~reg0_d4; // k137b
assign k126b_x = ~((reg0_d4 & k114a) | (k124b_y & pin_clk)); // k126b
assign k135b_x = ~((reg0_d4 & u_page09_hofs_package__k144_xq) | (k137b_y & k114a)); // k135b
assign k124a_y = ~k135b_x; // k124a
assign l118a_y = ~pin95; // l118a
assign l119b_y = ~|{pin_crom,l118a_y}; // l119b
assign l112_y = l119b_y; // l112
always @(posedge m118a or negedge l112_y) begin
    if (!l112_y) begin
        u_page09_package__u_page09__l108a_q <= 1'b0;
    end else begin
        u_page09_package__u_page09__l108a_q <= l119b_y;
    end
end // l108a
always @(posedge k126b_x or negedge u_page09_package__u_page09__l108a_q) begin
    if (!u_page09_package__u_page09__l108a_q) begin
        u_page09_package__u_page09__k119a_q <= 1'b0;
    end else begin
        u_page09_package__u_page09__k119a_q <= k124a_y;
    end
end // k119a
assign l116a_y = l118a_y | pin_crom; // l116a
assign l117b_y = ~reg4_d6; // l117b
assign l115b_y = l117b_y & pin116; // l115b
assign l119a_y = |{l116a_y,pin_crom,l115b_y}; // l119a
assign l121b_y = ~l119a_y; // l121b
assign pin101           = n108b_y;
assign pin102           = n113b_y;
assign pin103           = l108b_y;
assign pin108           = u_page09_package__u_page09__m73_q;
assign p162a            = p162a_y;
assign pin_db_lower_dir = p160b_y;
assign pin_db_upper_dir = r161a_y;
assign l121b            = l121b_y;
assign m76a_q = u_page09_package__u_page09__m76a_q;
assign m73_q = u_page09_package__u_page09__m73_q;
assign l108a_q = u_page09_package__u_page09__l108a_q;
assign k119a_q = u_page09_package__u_page09__k119a_q;
// End inlined jt054157_page09_integrated u_page09

// Inlined jt054157_page09_package_output_map u_page09_package_output_map
assign pin_101_out = pin101;
assign pin_102_out = pin102;
assign pin_103_out = pin103;
assign pin_104_out = pin104;
assign pin_105_out = pin105;
assign pin_106_out = pin106;
assign pin_107_out = pin107;
assign pin_108_out = pin108;
// End inlined jt054157_page09_package_output_map u_page09_package_output_map
// End inlined jt054157_page09_package_integrated u_page09_package
// End inlined jt054157_page09_hofs_package_integrated u_page09_hofs_package

wire        db_lower_drive = pin_db_lower_dir == DB_DIR_DRIVE_VALUE;
wire        db_upper_drive = pin_db_upper_dir == DB_DIR_DRIVE_VALUE;
wire [15:0] pin_db_oe     = {{8{db_upper_drive}}, {8{db_lower_drive}}};

// Inlined jt054157_readout_db_package_integrated u_readout_db_package
// Inlined jt054157_page10_11_readout_db_integrated u_readout_db
wire [3:0] u_readout_db__readout_d0_d3;
wire [3:0] u_readout_db__readout_d4_d7;
wire [3:0] u_readout_db__readout_d8_d11;
wire [3:0] u_readout_db__readout_d12_d15;
wire       u_readout_db__r111a_y;
wire       u_readout_db__n115b_y;
wire       u_readout_db__j122a_y;
wire       u_readout_db__g114a_y;
wire       u_readout_db__g110a_y;
wire       u_readout_db__h138a_y;
wire       u_readout_db__h94b_y;
wire       u_readout_db__h75b_y;
wire       u_readout_db__g107b_y;
wire       u_readout_db__g102b_y;
wire       u_readout_db__m129a_y;
wire       u_readout_db__j132a_y;
wire       u_readout_db__m117a_y;
wire       u_readout_db__j115b_y;

assign u_readout_db__readout_d0_d3   = readout_d[ 3: 0];
assign u_readout_db__readout_d4_d7   = readout_d[ 7: 4];
assign u_readout_db__readout_d8_d11  = readout_d[11: 8];
assign u_readout_db__readout_d12_d15 = readout_d[15:12];

assign u_readout_db__g110a_y = ~reg4_d4_buf3; // g110a
assign u_readout_db__h138a_y = ~u_readout_db__g110a_y; // h138a
assign u_readout_db__h94b_y = ~reg4_d4_buf3; // h94b
assign u_readout_db__h75b_y = ~u_readout_db__h94b_y; // h75b
assign u_readout_db__g107b_y = ~reg4_d4_buf3; // g107b
assign u_readout_db__g102b_y = ~u_readout_db__g107b_y; // g102b
assign u_readout_db__m129a_y = ~reg4_d3_buf2; // m129a
assign u_readout_db__j132a_y = ~u_readout_db__m129a_y; // j132a
assign u_readout_db__m117a_y = ~reg4_d3_buf2; // m117a
assign u_readout_db__j115b_y = ~u_readout_db__m117a_y; // j115b
// Inlined jt054157_page10_readout_integrated u_page10_readout
wire u_readout_db__u_page10_readout__f109a_y;
wire u_readout_db__u_page10_readout__f112a_y;
wire u_readout_db__u_page10_readout__f110b_y;
wire u_readout_db__u_page10_readout__f116b_y;
wire u_readout_db__u_page10_readout__g67a_y;
wire u_readout_db__u_page10_readout__f66a_y;
wire u_readout_db__u_page10_readout__h57a_y;
wire u_readout_db__u_page10_readout__f36b_y;
wire u_readout_db__u_page10_readout__h124b_y;
wire u_readout_db__u_page10_readout__h48b_y;
wire u_readout_db__u_page10_readout__h132a_y;
wire u_readout_db__u_page10_readout__g38a_y;
wire u_readout_db__u_page10_readout__f127a_y;
wire u_readout_db__u_page10_readout__f127b_y;
wire u_readout_db__u_page10_readout__g103b_y;
wire u_readout_db__u_page10_readout__h129b_x;
wire u_readout_db__u_page10_readout__h80a_x;
wire u_readout_db__u_page10_readout__h133b_x;
wire u_readout_db__u_page10_readout__h78b_x;
wire u_readout_db__u_page10_readout__h131b_x;
wire u_readout_db__u_page10_readout__h78a_x;
wire u_readout_db__u_page10_readout__h136a_x;
wire u_readout_db__u_page10_readout__h125b_x;
wire u_readout_db__u_page10_readout__j92a_x;
wire u_readout_db__u_page10_readout__h127b_x;
wire u_readout_db__u_page10_readout__j129b_y;
wire u_readout_db__u_page10_readout__j109a_y;
wire u_readout_db__u_page10_readout__j131a_y;
wire u_readout_db__u_page10_readout__j108a_y;
wire u_readout_db__u_page10_readout__j130a_y;
wire u_readout_db__u_page10_readout__h77b_y;
wire u_readout_db__u_page10_readout__h150b_y;
wire u_readout_db__u_page10_readout__j130b_y;
wire u_readout_db__u_page10_readout__j110b_y;
wire u_readout_db__u_page10_readout__j129a_y;

assign u_readout_db__u_page10_readout__h129b_x = ~((u_readout_db__h138a_y & pin38_in) | (u_readout_db__g110a_y & pin36_in)); // h129b
assign u_readout_db__u_page10_readout__j129b_y = ~u_readout_db__u_page10_readout__h129b_x; // j129b
assign u_readout_db__u_page10_readout__h80a_x = ~((u_readout_db__h75b_y & pin7_in) | (u_readout_db__h94b_y & pin9_in)); // h80a
assign u_readout_db__u_page10_readout__j109a_y = ~u_readout_db__u_page10_readout__h80a_x; // j109a
assign u_readout_db__u_page10_readout__h133b_x = ~((u_readout_db__h138a_y & pin39_in) | (u_readout_db__g110a_y & pin37_in)); // h133b
assign u_readout_db__u_page10_readout__j131a_y = ~u_readout_db__u_page10_readout__h133b_x; // j131a
assign u_readout_db__u_page10_readout__h78b_x = ~((u_readout_db__h75b_y & pin8_in) | (u_readout_db__h94b_y & pin11_in)); // h78b
assign u_readout_db__u_page10_readout__j108a_y = ~u_readout_db__u_page10_readout__h78b_x; // j108a
assign u_readout_db__u_page10_readout__h131b_x = ~((u_readout_db__h138a_y & pin42_in) | (u_readout_db__g110a_y & pin38_in)); // h131b
assign u_readout_db__u_page10_readout__j130a_y = ~u_readout_db__u_page10_readout__h131b_x; // j130a
assign u_readout_db__u_page10_readout__h78a_x = ~((u_readout_db__h75b_y & pin155_in) | (u_readout_db__h94b_y & pin12_in)); // h78a
assign u_readout_db__u_page10_readout__h77b_y = ~u_readout_db__u_page10_readout__h78a_x; // h77b
assign u_readout_db__u_page10_readout__h136a_x = ~((u_readout_db__h138a_y & pin43_in) | (u_readout_db__g110a_y & pin39_in)); // h136a
assign u_readout_db__u_page10_readout__h150b_y = ~u_readout_db__u_page10_readout__h136a_x; // h150b
assign u_readout_db__u_page10_readout__h125b_x = ~((u_readout_db__h138a_y & pin29_in) | (u_readout_db__g110a_y & pin42_in)); // h125b
assign u_readout_db__u_page10_readout__j130b_y = ~u_readout_db__u_page10_readout__h125b_x; // j130b
assign u_readout_db__u_page10_readout__j92a_x = ~((u_readout_db__h75b_y & pin157_in) | (u_readout_db__h94b_y & pin14_in)); // j92a
assign u_readout_db__u_page10_readout__j110b_y = ~u_readout_db__u_page10_readout__j92a_x; // j110b
assign u_readout_db__u_page10_readout__h127b_x = ~((u_readout_db__h138a_y & pin31_in) | (u_readout_db__g110a_y & pin43_in)); // h127b
assign u_readout_db__u_page10_readout__j129a_y = ~u_readout_db__u_page10_readout__h127b_x; // j129a
// Inlined jt054157_page10_readout_d0_d1 u_d0_d1
wire u_d0_d1__unused_f124b_y;
wire u_d0_d1__unused_f126a_y;
wire u_d0_d1__unused_f126b_y;
wire u_d0_d1__unused_g123b_y;
wire u_d0_d1__unused_g125b_y;
wire u_d0_d1__unused_g160a_y;
wire u_d0_d1__unused_g149a_y;
wire u_d0_d1__unused_g126_x;
wire u_d0_d1__unused_g139a_x;
wire u_d0_d1__readout_d0;
wire u_d0_d1__readout_d1;
wire [2:0] u_d0_d1__g126_a_resolved;
wire [2:0] u_d0_d1__g126_b_resolved;
wire [2:0] u_d0_d1__g126_c_resolved;
wire [2:0] u_d0_d1__g126_d_resolved;
wire [2:0] u_d0_d1__g139a_a_resolved;
wire [2:0] u_d0_d1__g139a_b_resolved;
wire [2:0] u_d0_d1__g139a_c_resolved;
wire [2:0] u_d0_d1__g139a_d_resolved;

assign u_d0_d1__g126_a_resolved  = { u_readout_db__g114a_y, u_d0_d1__unused_g123b_y, pin29_in  };
assign u_d0_d1__g126_b_resolved  = { pin44_in, u_d0_d1__unused_g123b_y, u_d0_d1__unused_g125b_y  };
assign u_d0_d1__g126_c_resolved  = { u_readout_db__g114a_y, u_readout_db__j122a_y, u_d0_d1__unused_f124b_y   };
assign u_d0_d1__g126_d_resolved  = { u_d0_d1__unused_f126a_y, u_readout_db__j122a_y, u_d0_d1__unused_g125b_y   };
assign u_d0_d1__g139a_a_resolved = { u_readout_db__g114a_y, u_d0_d1__unused_g160a_y, pin31_in  };
assign u_d0_d1__g139a_b_resolved = { pin45_in, u_d0_d1__unused_g160a_y, u_d0_d1__unused_g149a_y  };
assign u_d0_d1__g139a_c_resolved = { u_readout_db__g114a_y, u_readout_db__j122a_y, u_d0_d1__unused_f126b_y   };
assign u_d0_d1__g139a_d_resolved = { u_readout_db__u_page10_readout__f127a_y, u_readout_db__j122a_y, u_d0_d1__unused_g149a_y   };

assign u_readout_db__u_page10_readout__f109a_y = ~reg4_d4_buf2; // f109a
assign u_readout_db__u_page10_readout__f112a_y = ~u_readout_db__u_page10_readout__f109a_y; // f112a
assign u_readout_db__u_page10_readout__f110b_y = ~reg4_d4_buf2; // f110b
assign u_readout_db__u_page10_readout__f116b_y = ~u_readout_db__u_page10_readout__f110b_y; // f116b
assign u_d0_d1__unused_f124b_y = u_readout_db__u_page10_readout__f110b_y ? pin3_in : pin34_in; // f108b, f124b
assign u_d0_d1__unused_f126a_y = u_readout_db__u_page10_readout__f109a_y ? pin16_in : pin12_in; // f113a, f126a
assign u_d0_d1__unused_f126b_y = u_readout_db__u_page10_readout__f110b_y ? pin4_in : pin35_in; // f111b, f126b
assign u_d0_d1__unused_g123b_y = ~u_readout_db__j122a_y; // g123b
assign u_d0_d1__unused_g125b_y = ~u_readout_db__g114a_y; // g125b
assign u_d0_d1__unused_g126_x = ~(|{ &u_d0_d1__g126_a_resolved, &u_d0_d1__g126_b_resolved, &u_d0_d1__g126_c_resolved, &u_d0_d1__g126_d_resolved }); // g126
assign u_d0_d1__readout_d0 = ~u_d0_d1__unused_g126_x; // h155a
assign u_d0_d1__unused_g160a_y = ~u_readout_db__j122a_y; // g160a
assign u_d0_d1__unused_g149a_y = ~u_readout_db__g114a_y; // g149a
assign u_d0_d1__unused_g139a_x = ~(|{ &u_d0_d1__g139a_a_resolved, &u_d0_d1__g139a_b_resolved, &u_d0_d1__g139a_c_resolved, &u_d0_d1__g139a_d_resolved }); // g139a
assign u_d0_d1__readout_d1 = ~u_d0_d1__unused_g139a_x; // h156b
assign readout_d[0] = u_d0_d1__readout_d0;
assign readout_d[1] = u_d0_d1__readout_d1;
// End inlined jt054157_page10_readout_d0_d1 u_d0_d1
// Inlined jt054157_page10_readout_d2_d3 u_d2_d3
wire u_d2_d3__unused_f110a_x;
wire u_d2_d3__unused_f121a_x;
wire u_d2_d3__unused_f117a_x;
wire u_d2_d3__unused_f119a_x;
wire u_d2_d3__unused_f115a_x;
wire u_d2_d3__unused_f130a_y;
wire u_d2_d3__unused_f128a_y;
wire u_d2_d3__unused_f129a_y;
wire u_d2_d3__unused_f131a_y;
wire u_d2_d3__unused_g162a_y;
wire u_d2_d3__unused_g161b_y;
wire u_d2_d3__unused_g162b_y;
wire u_d2_d3__unused_g161a_y;
wire u_d2_d3__unused_g156_x;
wire u_d2_d3__unused_g151a_x;
wire u_d2_d3__readout_d2;
wire u_d2_d3__readout_d3;
wire [2:0] u_d2_d3__g156_a_resolved;
wire [2:0] u_d2_d3__g156_b_resolved;
wire [2:0] u_d2_d3__g156_c_resolved;
wire [2:0] u_d2_d3__g156_d_resolved;
wire [2:0] u_d2_d3__g151a_a_resolved;
wire [2:0] u_d2_d3__g151a_b_resolved;
wire [2:0] u_d2_d3__g151a_c_resolved;
wire [2:0] u_d2_d3__g151a_d_resolved;

assign u_d2_d3__g156_a_resolved  = { u_readout_db__g114a_y, u_d2_d3__unused_g162a_y, pin32_in  };
assign u_d2_d3__g156_b_resolved  = { pin46_in, u_d2_d3__unused_g162a_y, u_d2_d3__unused_g161b_y  };
assign u_d2_d3__g156_c_resolved  = { u_readout_db__g114a_y, u_readout_db__j122a_y, u_d2_d3__unused_f130a_y   };
assign u_d2_d3__g156_d_resolved  = { u_d2_d3__unused_f128a_y, u_readout_db__j122a_y, u_d2_d3__unused_g161b_y   };
assign u_d2_d3__g151a_a_resolved = { u_readout_db__g114a_y, u_d2_d3__unused_g162b_y, pin33_in  };
assign u_d2_d3__g151a_b_resolved = { pin47_in, u_d2_d3__unused_g162b_y, u_d2_d3__unused_g161a_y  };
assign u_d2_d3__g151a_c_resolved = { u_readout_db__g114a_y, u_readout_db__j122a_y, u_d2_d3__unused_f129a_y   };
assign u_d2_d3__g151a_d_resolved = { u_d2_d3__unused_f131a_y, u_readout_db__j122a_y, u_d2_d3__unused_g161a_y   };

assign u_d2_d3__unused_f110a_x = ~((u_readout_db__u_page10_readout__f112a_y & pin13_in) | (u_readout_db__u_page10_readout__f109a_y & pin17_in)); // f110a
assign u_readout_db__u_page10_readout__f127a_y = ~u_d2_d3__unused_f110a_x; // f127a
assign u_d2_d3__unused_f121a_x = ~((u_readout_db__u_page10_readout__f116b_y & pin23_in) | (u_readout_db__u_page10_readout__f110b_y & pin5_in)); // f121a
assign u_d2_d3__unused_f130a_y = ~u_d2_d3__unused_f121a_x; // f130a
assign u_d2_d3__unused_f117a_x = ~((u_readout_db__u_page10_readout__f112a_y & pin14_in) | (u_readout_db__u_page10_readout__f109a_y & pin18_in)); // f117a
assign u_d2_d3__unused_f128a_y = ~u_d2_d3__unused_f117a_x; // f128a
assign u_d2_d3__unused_f119a_x = ~((u_readout_db__u_page10_readout__f116b_y & pin24_in) | (u_readout_db__u_page10_readout__f110b_y & pin6_in)); // f119a
assign u_d2_d3__unused_f129a_y = ~u_d2_d3__unused_f119a_x; // f129a
assign u_d2_d3__unused_f115a_x = ~((u_readout_db__u_page10_readout__f112a_y & pin15_in) | (u_readout_db__u_page10_readout__f109a_y & pin19_in)); // f115a
assign u_d2_d3__unused_f131a_y = ~u_d2_d3__unused_f115a_x; // f131a
assign u_d2_d3__unused_g162a_y = ~u_readout_db__j122a_y; // g162a
assign u_d2_d3__unused_g161b_y = ~u_readout_db__g114a_y; // g161b
assign u_d2_d3__unused_g156_x = ~(|{ &u_d2_d3__g156_a_resolved, &u_d2_d3__g156_b_resolved, &u_d2_d3__g156_c_resolved, &u_d2_d3__g156_d_resolved }); // g156
assign u_d2_d3__readout_d2 = ~u_d2_d3__unused_g156_x; // h160b
assign u_d2_d3__unused_g162b_y = ~u_readout_db__j122a_y; // g162b
assign u_d2_d3__unused_g161a_y = ~u_readout_db__g114a_y; // g161a
assign u_d2_d3__unused_g151a_x = ~(|{ &u_d2_d3__g151a_a_resolved, &u_d2_d3__g151a_b_resolved, &u_d2_d3__g151a_c_resolved, &u_d2_d3__g151a_d_resolved }); // g151a
assign u_d2_d3__readout_d3 = ~u_d2_d3__unused_g151a_x; // h159b
assign readout_d[2] = u_d2_d3__readout_d2;
assign readout_d[3] = u_d2_d3__readout_d3;
// End inlined jt054157_page10_readout_d2_d3 u_d2_d3

// Inlined jt054157_page10_readout_d4_d5 u_d4_d5
wire u_d4_d5__unused_f113b_x;
wire u_d4_d5__unused_h65b_y;
wire u_d4_d5__unused_h126a_y;
wire u_d4_d5__unused_f115b_y;
wire u_d4_d5__unused_g37b_y;
wire u_d4_d5__unused_g103a_y;
wire u_d4_d5__unused_h60b_y;
wire u_d4_d5__unused_h140a_y;
wire u_d4_d5__unused_g112b_y;
wire u_d4_d5__unused_g110b_y;
wire u_d4_d5__unused_g150a_y;
wire u_d4_d5__unused_g149b_y;
wire u_d4_d5__unused_g118a_x;
wire u_d4_d5__unused_g135_x;
wire u_d4_d5__readout_d4;
wire u_d4_d5__readout_d5;
wire [2:0] u_d4_d5__g118a_a_resolved;
wire [2:0] u_d4_d5__g118a_b_resolved;
wire [2:0] u_d4_d5__g118a_c_resolved;
wire [2:0] u_d4_d5__g118a_d_resolved;
wire [2:0] u_d4_d5__g135_a_resolved;
wire [2:0] u_d4_d5__g135_b_resolved;
wire [2:0] u_d4_d5__g135_c_resolved;
wire [2:0] u_d4_d5__g135_d_resolved;

assign u_d4_d5__g118a_a_resolved = { u_readout_db__g114a_y, u_d4_d5__unused_g112b_y, pin34_in };
assign u_d4_d5__g118a_b_resolved = { u_d4_d5__unused_h126a_y, u_d4_d5__unused_g112b_y, u_d4_d5__unused_g110b_y };
assign u_d4_d5__g118a_c_resolved = { u_readout_db__g114a_y, u_readout_db__j122a_y, u_d4_d5__unused_f115b_y };
assign u_d4_d5__g118a_d_resolved = { u_d4_d5__unused_g103a_y, u_readout_db__j122a_y, u_d4_d5__unused_g110b_y };
assign u_d4_d5__g135_a_resolved  = { u_readout_db__g114a_y, u_d4_d5__unused_g150a_y, pin35_in };
assign u_d4_d5__g135_b_resolved  = { u_d4_d5__unused_h140a_y, u_d4_d5__unused_g150a_y, u_d4_d5__unused_g149b_y };
assign u_d4_d5__g135_c_resolved  = { u_readout_db__g114a_y, u_readout_db__j122a_y, u_readout_db__u_page10_readout__f127b_y };
assign u_d4_d5__g135_d_resolved  = { u_readout_db__u_page10_readout__g103b_y, u_readout_db__j122a_y, u_d4_d5__unused_g149b_y };

assign u_readout_db__u_page10_readout__g67a_y = ~reg4_d4_buf2; // g67a
assign u_readout_db__u_page10_readout__f66a_y = ~reg4_d4_buf2; // f66a
assign u_readout_db__u_page10_readout__h57a_y = ~u_readout_db__u_page10_readout__g67a_y; // h57a
assign u_readout_db__u_page10_readout__f36b_y = ~u_readout_db__u_page10_readout__f66a_y; // f36b
assign u_readout_db__u_page10_readout__h124b_y = ~reg4_d3_buf3; // h124b
assign u_readout_db__u_page10_readout__h48b_y = ~reg4_d3_buf3; // h48b
assign u_readout_db__u_page10_readout__h132a_y = ~u_readout_db__u_page10_readout__h124b_y; // h132a
assign u_readout_db__u_page10_readout__g38a_y = ~u_readout_db__u_page10_readout__h48b_y; // g38a
assign u_d4_d5__unused_h65b_y = u_readout_db__u_page10_readout__g67a_y ? pin48_in : pin48_in; // h65a, h65b
assign u_d4_d5__unused_h126a_y = u_readout_db__u_page10_readout__h124b_y ? pin36_in : u_d4_d5__unused_h65b_y; // h124a, h126a
assign u_d4_d5__unused_f113b_x = ~((pin25_in & u_readout_db__u_page10_readout__f112a_y) | (pin7_in & u_readout_db__u_page10_readout__f109a_y)); // f113b
assign u_d4_d5__unused_f115b_y = ~u_d4_d5__unused_f113b_x; // f115b
assign u_d4_d5__unused_g37b_y = u_readout_db__u_page10_readout__f66a_y ? pin21_in : pin3_in; // f39a, g37b
assign u_d4_d5__unused_g103a_y = u_readout_db__u_page10_readout__h48b_y ? pin9_in : u_d4_d5__unused_g37b_y; // g39a, g103a
assign u_d4_d5__unused_h60b_y = u_readout_db__u_page10_readout__g67a_y ? pin49_in : pin49_in; // h59a, h60b
assign u_d4_d5__unused_h140a_y = u_readout_db__u_page10_readout__h124b_y ? pin37_in : u_d4_d5__unused_h60b_y; // h127a, h140a
assign u_d4_d5__unused_g112b_y = ~u_readout_db__j122a_y; // g112b
assign u_d4_d5__unused_g110b_y = ~u_readout_db__g114a_y; // g110b
assign u_d4_d5__unused_g118a_x = ~(|{ &u_d4_d5__g118a_a_resolved, &u_d4_d5__g118a_b_resolved, &u_d4_d5__g118a_c_resolved, &u_d4_d5__g118a_d_resolved }); // g118a
assign u_d4_d5__readout_d4 = ~u_d4_d5__unused_g118a_x; // h153a
assign u_d4_d5__unused_g150a_y = ~u_readout_db__j122a_y; // g150a
assign u_d4_d5__unused_g149b_y = ~u_readout_db__g114a_y; // g149b
assign u_d4_d5__unused_g135_x = ~(|{ &u_d4_d5__g135_a_resolved, &u_d4_d5__g135_b_resolved, &u_d4_d5__g135_c_resolved, &u_d4_d5__g135_d_resolved }); // g135
assign u_d4_d5__readout_d5 = ~u_d4_d5__unused_g135_x; // h156a
assign readout_d[4] = u_d4_d5__readout_d4;
assign readout_d[5] = u_d4_d5__readout_d5;
// End inlined jt054157_page10_readout_d4_d5 u_d4_d5
// Inlined jt054157_page10_readout_d6_d7 u_d6_d7
wire u_d6_d7__unused_f121b_x;
wire u_d6_d7__unused_f39b_x;
wire u_d6_d7__unused_g39b_x;
wire u_d6_d7__unused_h66b_x;
wire u_d6_d7__unused_h133a_x;
wire u_d6_d7__unused_f119b_x;
wire u_d6_d7__unused_f37b_x;
wire u_d6_d7__unused_g51a_x;
wire u_d6_d7__unused_h57b_x;
wire u_d6_d7__unused_h129a_x;
wire u_d6_d7__unused_f117b_x;
wire u_d6_d7__unused_f36a_x;
wire u_d6_d7__unused_f51a_x;
wire u_d6_d7__unused_g26b_y;
wire u_d6_d7__unused_h59b_y;
wire u_d6_d7__unused_h140b_y;
wire u_d6_d7__unused_f128b_y;
wire u_d6_d7__unused_g38b_y;
wire u_d6_d7__unused_g102a_y;
wire u_d6_d7__unused_h58a_y;
wire u_d6_d7__unused_h131a_y;
wire u_d6_d7__unused_f125b_y;
wire u_d6_d7__unused_f38a_y;
wire u_d6_d7__unused_f67b_y;
wire u_d6_d7__unused_g150b_y;
wire u_d6_d7__unused_g148a_y;
wire u_d6_d7__unused_g123a_y;
wire u_d6_d7__unused_g124b_y;
wire u_d6_d7__unused_g144_x;
wire u_d6_d7__unused_g130a_x;
wire u_d6_d7__readout_d6;
wire u_d6_d7__readout_d7;
wire u_d6_d7__gnd = 1'b0;
wire [2:0] u_d6_d7__g144_a_resolved;
wire [2:0] u_d6_d7__g144_b_resolved;
wire [2:0] u_d6_d7__g144_c_resolved;
wire [2:0] u_d6_d7__g144_d_resolved;
wire [2:0] u_d6_d7__g130a_a_resolved;
wire [2:0] u_d6_d7__g130a_b_resolved;
wire [2:0] u_d6_d7__g130a_c_resolved;
wire [2:0] u_d6_d7__g130a_d_resolved;

assign u_d6_d7__g144_a_resolved  = { u_readout_db__g114a_y,        u_d6_d7__unused_g150b_y, u_d6_d7__gnd     };
assign u_d6_d7__g144_b_resolved  = { u_d6_d7__unused_h140b_y,        u_d6_d7__unused_g150b_y, u_d6_d7__unused_g148a_y };
assign u_d6_d7__g144_c_resolved  = { u_readout_db__j122a_y,        u_d6_d7__unused_f128b_y, u_d6_d7__unused_g148a_y };
assign u_d6_d7__g144_d_resolved  = { u_d6_d7__unused_g102a_y,        u_readout_db__j122a_y, u_d6_d7__unused_g148a_y };
assign u_d6_d7__g130a_a_resolved = { u_readout_db__g114a_y,        u_d6_d7__unused_g123a_y, u_d6_d7__gnd     };
assign u_d6_d7__g130a_b_resolved = { u_d6_d7__unused_h131a_y,        u_d6_d7__unused_g123a_y, u_d6_d7__unused_g124b_y };
assign u_d6_d7__g130a_c_resolved = { u_readout_db__j122a_y,        u_d6_d7__unused_f125b_y, u_d6_d7__unused_g124b_y };
assign u_d6_d7__g130a_d_resolved = { u_d6_d7__unused_f67b_y,         u_readout_db__j122a_y, u_d6_d7__unused_g124b_y };

assign u_d6_d7__unused_f121b_x = ~((pin25_in & u_readout_db__u_page10_readout__f112a_y) | (pin8_in & u_readout_db__u_page10_readout__f109a_y)); // f121b
assign u_readout_db__u_page10_readout__f127b_y = ~u_d6_d7__unused_f121b_x; // f127b
assign u_d6_d7__unused_f39b_x = ~((u_readout_db__u_page10_readout__f36b_y & pin4_in) | (u_readout_db__u_page10_readout__f66a_y & pin22_in)); // f39b
assign u_d6_d7__unused_g26b_y = ~u_d6_d7__unused_f39b_x; // g26b
assign u_d6_d7__unused_g39b_x = ~((u_readout_db__u_page10_readout__g38a_y & u_d6_d7__unused_g26b_y) | (u_readout_db__u_page10_readout__h48b_y & pin11_in)); // g39b
assign u_readout_db__u_page10_readout__g103b_y = ~u_d6_d7__unused_g39b_x; // g103b
assign u_d6_d7__unused_h66b_x = ~((u_readout_db__u_page10_readout__h57a_y & pin36_in) | (u_readout_db__u_page10_readout__g67a_y & u_d6_d7__gnd)); // h66b
assign u_d6_d7__unused_h59b_y = ~u_d6_d7__unused_h66b_x; // h59b
assign u_d6_d7__unused_h133a_x = ~((u_readout_db__u_page10_readout__h132a_y & u_d6_d7__unused_h59b_y) | (u_readout_db__u_page10_readout__h124b_y & pin38_in)); // h133a
assign u_d6_d7__unused_h140b_y = ~u_d6_d7__unused_h133a_x; // h140b
assign u_d6_d7__unused_f119b_x = ~((pin27_in & u_readout_db__u_page10_readout__f112a_y) | (u_d6_d7__gnd & u_readout_db__u_page10_readout__f109a_y)); // f119b
assign u_d6_d7__unused_f128b_y = ~u_d6_d7__unused_f119b_x; // f128b
assign u_d6_d7__unused_f37b_x = ~((u_readout_db__u_page10_readout__f36b_y & pin5_in) | (u_readout_db__u_page10_readout__f66a_y & u_d6_d7__gnd)); // f37b
assign u_d6_d7__unused_g38b_y = ~u_d6_d7__unused_f37b_x; // g38b
assign u_d6_d7__unused_g51a_x = ~((u_readout_db__u_page10_readout__g38a_y & u_d6_d7__unused_g38b_y) | (u_readout_db__u_page10_readout__h48b_y & pin12_in)); // g51a
assign u_d6_d7__unused_g102a_y = ~u_d6_d7__unused_g51a_x; // g102a
assign u_d6_d7__unused_h57b_x = ~((u_readout_db__u_page10_readout__h57a_y & pin37_in) | (u_readout_db__u_page10_readout__g67a_y & u_d6_d7__gnd)); // h57b
assign u_d6_d7__unused_h58a_y = ~u_d6_d7__unused_h57b_x; // h58a
assign u_d6_d7__unused_h129a_x = ~((u_readout_db__u_page10_readout__h132a_y & u_d6_d7__unused_h58a_y) | (u_readout_db__u_page10_readout__h124b_y & pin39_in)); // h129a
assign u_d6_d7__unused_h131a_y = ~u_d6_d7__unused_h129a_x; // h131a
assign u_d6_d7__unused_f117b_x = ~((pin28_in & u_readout_db__u_page10_readout__f112a_y) | (u_d6_d7__gnd & u_readout_db__u_page10_readout__f109a_y)); // f117b
assign u_d6_d7__unused_f125b_y = ~u_d6_d7__unused_f117b_x; // f125b
assign u_d6_d7__unused_f36a_x = ~((u_readout_db__u_page10_readout__f36b_y & pin6_in) | (u_readout_db__u_page10_readout__f66a_y & u_d6_d7__gnd)); // f36a
assign u_d6_d7__unused_f38a_y = ~u_d6_d7__unused_f36a_x; // f38a
assign u_d6_d7__unused_f51a_x = ~((u_readout_db__u_page10_readout__g38a_y & u_d6_d7__unused_f38a_y) | (u_readout_db__u_page10_readout__h48b_y & pin13_in)); // f51a
assign u_d6_d7__unused_f67b_y = ~u_d6_d7__unused_f51a_x; // f67b
assign u_d6_d7__unused_g150b_y = ~u_readout_db__j122a_y; // g150b
assign u_d6_d7__unused_g148a_y = ~u_readout_db__g114a_y; // g148a
assign u_d6_d7__unused_g144_x = ~(|{ &u_d6_d7__g144_a_resolved, &u_d6_d7__g144_b_resolved, &u_d6_d7__g144_c_resolved, &u_d6_d7__g144_d_resolved }); // g144
assign u_d6_d7__readout_d6 = ~u_d6_d7__unused_g144_x; // h153b
assign u_d6_d7__unused_g123a_y = ~u_readout_db__j122a_y; // g123a
assign u_d6_d7__unused_g124b_y = ~u_readout_db__g114a_y; // g124b
assign u_d6_d7__unused_g130a_x = ~(|{ &u_d6_d7__g130a_a_resolved, &u_d6_d7__g130a_b_resolved, &u_d6_d7__g130a_c_resolved, &u_d6_d7__g130a_d_resolved }); // g130a
assign u_d6_d7__readout_d7 = ~u_d6_d7__unused_g130a_x; // h149a
assign readout_d[6] = u_d6_d7__readout_d6;
assign readout_d[7] = u_d6_d7__readout_d7;
// End inlined jt054157_page10_readout_d6_d7 u_d6_d7

// Inlined jt054157_page10_readout_d8_d9 u_d8_d9
wire u_d8_d9__unused_j125b_x;
wire u_d8_d9__unused_j110a_x;
wire u_d8_d9__unused_j131b_x;
wire u_d8_d9__unused_j113b_x;
wire u_d8_d9__unused_g91a_x;
wire u_d8_d9__unused_g86a_x;
wire u_d8_d9__unused_n120b_y;
wire u_d8_d9__unused_p111a_y;
wire u_d8_d9__unused_m126a_y;
wire u_d8_d9__unused_p111b_y;
wire u_d8_d9__unused_p93a_y;
wire u_d8_d9__unused_p94b_y;
wire u_d8_d9__unused_p112a_y;
wire u_d8_d9__unused_p113b_y;
wire u_d8_d9__unused_p113a_y;
wire u_d8_d9__unused_p112b_y;
wire u_d8_d9__unused_p114_x;
wire u_d8_d9__unused_p118a_x;
wire u_d8_d9__readout_d8;
wire u_d8_d9__readout_d9;
wire [2:0] u_d8_d9__p114_a_resolved;
wire [2:0] u_d8_d9__p114_b_resolved;
wire [2:0] u_d8_d9__p114_c_resolved;
wire [2:0] u_d8_d9__p114_d_resolved;
wire [2:0] u_d8_d9__p118a_a_resolved;
wire [2:0] u_d8_d9__p118a_b_resolved;
wire [2:0] u_d8_d9__p118a_c_resolved;
wire [2:0] u_d8_d9__p118a_d_resolved;

assign u_d8_d9__p114_a_resolved  = { u_readout_db__n115b_y, u_d8_d9__unused_p112a_y, pin23_in };
assign u_d8_d9__p114_b_resolved  = { u_d8_d9__unused_n120b_y,        u_d8_d9__unused_p112a_y, u_d8_d9__unused_p113b_y  };
assign u_d8_d9__p114_c_resolved  = { u_readout_db__n115b_y, u_readout_db__r111a_y, u_d8_d9__unused_p93a_y   };
assign u_d8_d9__p114_d_resolved  = { u_d8_d9__unused_p111a_y,        u_readout_db__r111a_y, u_d8_d9__unused_p113b_y  };
assign u_d8_d9__p118a_a_resolved = { u_readout_db__n115b_y, u_d8_d9__unused_p113a_y, pin24_in };
assign u_d8_d9__p118a_b_resolved = { u_d8_d9__unused_m126a_y,        u_d8_d9__unused_p113a_y, u_d8_d9__unused_p112b_y  };
assign u_d8_d9__p118a_c_resolved = { u_readout_db__n115b_y, u_readout_db__r111a_y, u_d8_d9__unused_p94b_y   };
assign u_d8_d9__p118a_d_resolved = { u_d8_d9__unused_p111b_y,        u_readout_db__r111a_y, u_d8_d9__unused_p112b_y  };

assign u_d8_d9__unused_j125b_x = ~((u_readout_db__j132a_y & u_readout_db__u_page10_readout__j129b_y) | (u_readout_db__m129a_y & pin29_in)); // j125b
assign u_d8_d9__unused_n120b_y = ~u_d8_d9__unused_j125b_x; // n120b
assign u_d8_d9__unused_j110a_x = ~((u_readout_db__j115b_y & u_readout_db__u_page10_readout__j109a_y) | (u_readout_db__m117a_y & pin3_in)); // j110a
assign u_d8_d9__unused_p111a_y = ~u_d8_d9__unused_j110a_x; // p111a
assign u_d8_d9__unused_j131b_x = ~((u_readout_db__j132a_y & u_readout_db__u_page10_readout__j131a_y) | (u_readout_db__m129a_y & pin31_in)); // j131b
assign u_d8_d9__unused_m126a_y = ~u_d8_d9__unused_j131b_x; // m126a
assign u_d8_d9__unused_j113b_x = ~((u_readout_db__j115b_y & u_readout_db__u_page10_readout__j108a_y) | (u_readout_db__m117a_y & pin4_in)); // j113b
assign u_d8_d9__unused_p111b_y = ~u_d8_d9__unused_j113b_x; // p111b
assign u_d8_d9__unused_g91a_x = ~((pin16_in & u_readout_db__g102b_y) | (pin155_in & u_readout_db__g107b_y)); // g91a
assign u_d8_d9__unused_p93a_y = ~u_d8_d9__unused_g91a_x; // p93a
assign u_d8_d9__unused_g86a_x = ~((pin17_in & u_readout_db__g102b_y) | (pin156_in & u_readout_db__g107b_y)); // g86a
assign u_d8_d9__unused_p94b_y = ~u_d8_d9__unused_g86a_x; // p94b
assign u_d8_d9__unused_p112a_y = ~u_readout_db__r111a_y; // p112a
assign u_d8_d9__unused_p113b_y = ~u_readout_db__n115b_y; // p113b
assign u_d8_d9__unused_p114_x = ~(|{ &u_d8_d9__p114_a_resolved, &u_d8_d9__p114_b_resolved, &u_d8_d9__p114_c_resolved, &u_d8_d9__p114_d_resolved }); // p114
assign u_d8_d9__readout_d8 = ~u_d8_d9__unused_p114_x; // r169a
assign u_d8_d9__unused_p113a_y = ~u_readout_db__r111a_y; // p113a
assign u_d8_d9__unused_p112b_y = ~u_readout_db__n115b_y; // p112b
assign u_d8_d9__unused_p118a_x = ~(|{ &u_d8_d9__p118a_a_resolved, &u_d8_d9__p118a_b_resolved, &u_d8_d9__p118a_c_resolved, &u_d8_d9__p118a_d_resolved }); // p118a
assign u_d8_d9__readout_d9 = ~u_d8_d9__unused_p118a_x; // r170b
assign readout_d[8] = u_d8_d9__readout_d8;
assign readout_d[9] = u_d8_d9__readout_d9;
// End inlined jt054157_page10_readout_d8_d9 u_d8_d9

// Inlined jt054157_page10_readout_d10_d11 u_d10_d11
wire u_d10_d11__unused_j133b_x;
wire u_d10_d11__unused_j112a_x;
wire u_d10_d11__unused_j135b_x;
wire u_d10_d11__unused_h71a_x;
wire u_d10_d11__unused_j115a_x;
wire u_d10_d11__unused_g106a_x;
wire u_d10_d11__unused_g117b_x;
wire u_d10_d11__unused_m128a_y;
wire u_d10_d11__unused_r111b_y;
wire u_d10_d11__unused_n142b_y;
wire u_d10_d11__unused_h76a_y;
wire u_d10_d11__unused_p142a_y;
wire u_d10_d11__unused_r112b_y;
wire u_d10_d11__unused_r112a_y;
wire u_d10_d11__unused_p143b_y;
wire u_d10_d11__unused_p143a_y;
wire u_d10_d11__unused_r103a_y;
wire u_d10_d11__unused_n135b_y;
wire u_d10_d11__unused_r118a_x;
wire u_d10_d11__unused_p136a_x;
wire u_d10_d11__readout_d10;
wire u_d10_d11__readout_d11;
wire [2:0] u_d10_d11__r118a_a_resolved = { u_readout_db__n115b_y, u_d10_d11__unused_r112b_y, pin25_in        };
wire [2:0] u_d10_d11__r118a_b_resolved = { u_d10_d11__unused_m128a_y,        u_d10_d11__unused_r112b_y, u_d10_d11__unused_r112a_y        };
wire [2:0] u_d10_d11__r118a_c_resolved = { u_readout_db__n115b_y, u_readout_db__r111a_y, u_d10_d11__unused_r103a_y };
wire [2:0] u_d10_d11__r118a_d_resolved = { u_d10_d11__unused_r111b_y,        u_readout_db__r111a_y, u_d10_d11__unused_r112a_y };

wire [2:0] u_d10_d11__p136a_a_resolved = { u_readout_db__n115b_y, u_d10_d11__unused_p143b_y, pin25_in        };
wire [2:0] u_d10_d11__p136a_b_resolved = { u_d10_d11__unused_n142b_y,        u_d10_d11__unused_p143b_y, u_d10_d11__unused_p143a_y        };
wire [2:0] u_d10_d11__p136a_c_resolved = { u_readout_db__n115b_y, u_readout_db__r111a_y, u_d10_d11__unused_n135b_y };
wire [2:0] u_d10_d11__p136a_d_resolved = { u_d10_d11__unused_p142a_y,        u_readout_db__r111a_y, u_d10_d11__unused_p143a_y };

assign u_d10_d11__unused_j133b_x = ~((u_readout_db__j132a_y & u_readout_db__u_page10_readout__j130a_y) | (u_readout_db__m129a_y & pin32_in)); // j133b
assign u_d10_d11__unused_m128a_y = ~u_d10_d11__unused_j133b_x; // m128a
assign u_d10_d11__unused_j112a_x = ~((u_readout_db__j115b_y & u_readout_db__u_page10_readout__h77b_y) | (u_readout_db__m117a_y & pin5_in)); // j112a
assign u_d10_d11__unused_r111b_y = ~u_d10_d11__unused_j112a_x; // r111b
assign u_d10_d11__unused_j135b_x = ~((u_readout_db__j132a_y & u_readout_db__u_page10_readout__h150b_y) | (u_readout_db__m129a_y & pin33_in)); // j135b
assign u_d10_d11__unused_n142b_y = ~u_d10_d11__unused_j135b_x; // n142b
assign u_d10_d11__unused_h71a_x = ~((pin156_in & u_readout_db__g102b_y) | (pin13_in & u_readout_db__g107b_y)); // h71a
assign u_d10_d11__unused_h76a_y = ~u_d10_d11__unused_h71a_x; // h76a
assign u_d10_d11__unused_j115a_x = ~((u_readout_db__j115b_y & u_d10_d11__unused_h76a_y) | (u_readout_db__m117a_y & pin6_in)); // j115a
assign u_d10_d11__unused_p142a_y = ~u_d10_d11__unused_j115a_x; // p142a
assign u_d10_d11__unused_g106a_x = ~((pin18_in & u_readout_db__g102b_y) | (pin157_in & u_readout_db__g107b_y)); // g106a
assign u_d10_d11__unused_r103a_y = ~u_d10_d11__unused_g106a_x; // r103a
assign u_d10_d11__unused_g117b_x = ~((pin19_in & u_readout_db__g102b_y) | (pin158_in & u_readout_db__g107b_y)); // g117b
assign u_d10_d11__unused_n135b_y = ~u_d10_d11__unused_g117b_x; // n135b
assign u_d10_d11__unused_r112b_y = ~u_readout_db__r111a_y; // r112b
assign u_d10_d11__unused_r112a_y = ~u_readout_db__n115b_y; // r112a
assign u_d10_d11__unused_r118a_x = ~(|{ &u_d10_d11__r118a_a_resolved, &u_d10_d11__r118a_b_resolved, &u_d10_d11__r118a_c_resolved, &u_d10_d11__r118a_d_resolved }); // r118a
assign u_d10_d11__readout_d10 = ~u_d10_d11__unused_r118a_x; // r170a
assign u_d10_d11__unused_p143b_y = ~u_readout_db__r111a_y; // p143b
assign u_d10_d11__unused_p143a_y = ~u_readout_db__n115b_y; // p143a
assign u_d10_d11__unused_p136a_x = ~(|{ &u_d10_d11__p136a_a_resolved, &u_d10_d11__p136a_b_resolved, &u_d10_d11__p136a_c_resolved, &u_d10_d11__p136a_d_resolved }); // p136a
assign u_d10_d11__readout_d11 = ~u_d10_d11__unused_p136a_x; // r171b
assign readout_d[10] = u_d10_d11__readout_d10;
assign readout_d[11] = u_d10_d11__readout_d11;
// End inlined jt054157_page10_readout_d10_d11 u_d10_d11

// Inlined jt054157_page10_readout_d12_d13 u_d12_d13
wire u_d12_d13__unused_j127a_x;
wire u_d12_d13__unused_j118b_x;
wire u_d12_d13__unused_j127b_x;
wire u_d12_d13__unused_j116b_x;
wire u_d12_d13__unused_k73a_x;
wire u_d12_d13__unused_h93a_x;
wire u_d12_d13__unused_h92b_x;
wire u_d12_d13__unused_m131a_y;
wire u_d12_d13__unused_p132b_y;
wire u_d12_d13__unused_m132a_y;
wire u_d12_d13__unused_j109b_y;
wire u_d12_d13__unused_p132a_y;
wire u_d12_d13__unused_p134a_y;
wire u_d12_d13__unused_p133b_y;
wire u_d12_d13__unused_p133a_y;
wire u_d12_d13__unused_p134b_y;
wire u_d12_d13__unused_p92b_y;
wire u_d12_d13__unused_p94a_y;
wire u_d12_d13__unused_p127a_x;
wire u_d12_d13__unused_p123_x;
wire u_d12_d13__readout_d12;
wire u_d12_d13__readout_d13;
wire [2:0] u_d12_d13__p127a_a_resolved = { u_readout_db__n115b_y, u_d12_d13__unused_p134a_y, pin27_in };
wire [2:0] u_d12_d13__p127a_b_resolved = { u_d12_d13__unused_m131a_y,        u_d12_d13__unused_p134a_y, u_d12_d13__unused_p133b_y  };
wire [2:0] u_d12_d13__p127a_c_resolved = { u_readout_db__n115b_y, u_readout_db__r111a_y, u_d12_d13__unused_p92b_y };
wire [2:0] u_d12_d13__p127a_d_resolved = { u_d12_d13__unused_p132b_y,        u_readout_db__r111a_y, u_d12_d13__unused_p133b_y };

wire [2:0] u_d12_d13__p123_a_resolved  = { u_readout_db__n115b_y, u_d12_d13__unused_p133a_y, pin28_in };
wire [2:0] u_d12_d13__p123_b_resolved  = { u_d12_d13__unused_m132a_y,        u_d12_d13__unused_p133a_y, u_d12_d13__unused_p134b_y  };
wire [2:0] u_d12_d13__p123_c_resolved  = { u_readout_db__n115b_y, u_readout_db__r111a_y, u_d12_d13__unused_p94a_y };
wire [2:0] u_d12_d13__p123_d_resolved  = { u_d12_d13__unused_p132a_y,        u_readout_db__r111a_y, u_d12_d13__unused_p134b_y };

assign u_d12_d13__unused_j127a_x = ~((u_readout_db__j132a_y & u_readout_db__u_page10_readout__j130b_y) | (u_readout_db__m129a_y & pin23_in)); // j127a
assign u_d12_d13__unused_m131a_y = ~u_d12_d13__unused_j127a_x; // m131a
assign u_d12_d13__unused_j118b_x = ~((u_readout_db__j115b_y & u_readout_db__u_page10_readout__j110b_y) | (u_readout_db__m117a_y & pin155_in)); // j118b
assign u_d12_d13__unused_p132b_y = ~u_d12_d13__unused_j118b_x; // p132b
assign u_d12_d13__unused_j127b_x = ~((u_readout_db__j132a_y & u_readout_db__u_page10_readout__j129a_y) | (u_readout_db__m129a_y & pin24_in)); // j127b
assign u_d12_d13__unused_m132a_y = ~u_d12_d13__unused_j127b_x; // m132a
assign u_d12_d13__unused_h92b_x = ~((pin158_in & u_readout_db__g102b_y) | (pin15_in & u_readout_db__g107b_y)); // h92b
assign u_d12_d13__unused_j109b_y = ~u_d12_d13__unused_h92b_x; // j109b
assign u_d12_d13__unused_j116b_x = ~((u_readout_db__j115b_y & u_d12_d13__unused_j109b_y) | (u_readout_db__m117a_y & pin156_in)); // j116b
assign u_d12_d13__unused_p132a_y = ~u_d12_d13__unused_j116b_x; // p132a
assign u_d12_d13__unused_k73a_x = ~((pin21_in & u_readout_db__g102b_y) | (pin159_in & u_readout_db__g107b_y)); // k73a
assign u_d12_d13__unused_p92b_y = ~u_d12_d13__unused_k73a_x; // p92b
assign u_d12_d13__unused_h93a_x = ~((pin22_in & u_readout_db__g102b_y) | (pin2_in & u_readout_db__g107b_y)); // h93a
assign u_d12_d13__unused_p94a_y = ~u_d12_d13__unused_h93a_x; // p94a
assign u_d12_d13__unused_p134a_y = ~u_readout_db__r111a_y; // p134a
assign u_d12_d13__unused_p133b_y = ~u_readout_db__n115b_y; // p133b
assign u_d12_d13__unused_p127a_x = ~(|{ &u_d12_d13__p127a_a_resolved, &u_d12_d13__p127a_b_resolved, &u_d12_d13__p127a_c_resolved, &u_d12_d13__p127a_d_resolved }); // p127a
assign u_d12_d13__readout_d12 = ~u_d12_d13__unused_p127a_x; // p145b
assign u_d12_d13__unused_p133a_y = ~u_readout_db__r111a_y; // p133a
assign u_d12_d13__unused_p134b_y = ~u_readout_db__n115b_y; // p134b
assign u_d12_d13__unused_p123_x = ~(|{ &u_d12_d13__p123_a_resolved, &u_d12_d13__p123_b_resolved, &u_d12_d13__p123_c_resolved, &u_d12_d13__p123_d_resolved }); // p123
assign u_d12_d13__readout_d13 = ~u_d12_d13__unused_p123_x; // p144b
assign readout_d[12] = u_d12_d13__readout_d12;
assign readout_d[13] = u_d12_d13__readout_d13;
// End inlined jt054157_page10_readout_d12_d13 u_d12_d13

// Inlined jt054157_page10_readout_d14_d15 u_d14_d15
wire u_d14_d15__unused_j133a_x;
wire u_d14_d15__unused_j111b_x;
wire u_d14_d15__unused_j137b_x;
wire u_d14_d15__unused_j117a_x;
wire u_d14_d15__unused_g100b_x;
wire u_d14_d15__unused_g98a_x;
wire u_d14_d15__unused_h141a_x;
wire u_d14_d15__unused_j56a_x;
wire u_d14_d15__unused_h138b_x;
wire u_d14_d15__unused_h71b_x;
wire u_d14_d15__unused_m127a_y;
wire u_d14_d15__unused_r110a_y;
wire u_d14_d15__unused_p141a_y;
wire u_d14_d15__unused_r129b_y;
wire u_d14_d15__unused_h139a_y;
wire u_d14_d15__unused_j57b_y;
wire u_d14_d15__unused_h150a_y;
wire u_d14_d15__unused_h75a_y;
wire u_d14_d15__unused_r113b_y;
wire u_d14_d15__unused_r113a_y;
wire u_d14_d15__unused_r134a_y;
wire u_d14_d15__unused_r134b_y;
wire u_d14_d15__unused_r104b_y;
wire u_d14_d15__unused_r104a_y;
wire u_d14_d15__unused_r114_x;
wire u_d14_d15__unused_r129a_x;
wire u_d14_d15__readout_d14;
wire u_d14_d15__readout_d15;
wire u_d14_d15__gnd = 1'b0;

wire [2:0] u_d14_d15__r114_a_resolved  = { u_readout_db__n115b_y, u_d14_d15__unused_r113b_y, u_d14_d15__gnd     };
wire [2:0] u_d14_d15__r114_b_resolved  = { u_d14_d15__unused_m127a_y,        u_d14_d15__unused_r113b_y, u_d14_d15__unused_r113a_y };
wire [2:0] u_d14_d15__r114_c_resolved  = { u_readout_db__n115b_y, u_readout_db__r111a_y, u_d14_d15__unused_r104b_y };
wire [2:0] u_d14_d15__r114_d_resolved  = { u_d14_d15__unused_r110a_y,        u_readout_db__r111a_y, u_d14_d15__unused_r113a_y };

wire [2:0] u_d14_d15__r129a_a_resolved = { u_readout_db__n115b_y, u_d14_d15__unused_r134a_y, u_d14_d15__gnd     };
wire [2:0] u_d14_d15__r129a_b_resolved = { u_d14_d15__unused_p141a_y,        u_d14_d15__unused_r134a_y, u_d14_d15__unused_r134b_y };
wire [2:0] u_d14_d15__r129a_c_resolved = { u_readout_db__n115b_y, u_readout_db__r111a_y, u_d14_d15__unused_r104a_y };
wire [2:0] u_d14_d15__r129a_d_resolved = { u_d14_d15__unused_r129b_y,        u_readout_db__r111a_y, u_d14_d15__unused_r134b_y };

assign u_d14_d15__unused_h141a_x = ~((u_readout_db__h138a_y & pin32_in) | (u_readout_db__g110a_y & u_d14_d15__gnd)); // h141a
assign u_d14_d15__unused_h139a_y = ~u_d14_d15__unused_h141a_x; // h139a
assign u_d14_d15__unused_j133a_x = ~((u_readout_db__j132a_y & u_d14_d15__unused_h139a_y) | (u_readout_db__m129a_y & pin25_in)); // j133a
assign u_d14_d15__unused_m127a_y = ~u_d14_d15__unused_j133a_x; // m127a
assign u_d14_d15__unused_j56a_x = ~((u_readout_db__h75b_y & pin159_in) | (u_readout_db__h94b_y & u_d14_d15__gnd)); // j56a
assign u_d14_d15__unused_j57b_y = ~u_d14_d15__unused_j56a_x; // j57b
assign u_d14_d15__unused_j111b_x = ~((u_readout_db__j115b_y & u_d14_d15__unused_j57b_y) | (u_readout_db__m117a_y & pin157_in)); // j111b
assign u_d14_d15__unused_r110a_y = ~u_d14_d15__unused_j111b_x; // r110a
assign u_d14_d15__unused_h138b_x = ~((u_readout_db__h138a_y & pin33_in) | (u_readout_db__g110a_y & u_d14_d15__gnd)); // h138b
assign u_d14_d15__unused_h150a_y = ~u_d14_d15__unused_h138b_x; // h150a
assign u_d14_d15__unused_j137b_x = ~((u_readout_db__j132a_y & u_d14_d15__unused_h150a_y) | (u_readout_db__m129a_y & pin25_in)); // j137b
assign u_d14_d15__unused_p141a_y = ~u_d14_d15__unused_j137b_x; // p141a
assign u_d14_d15__unused_h71b_x = ~((u_readout_db__h75b_y & pin2_in) | (u_readout_db__h94b_y & u_d14_d15__gnd)); // h71b
assign u_d14_d15__unused_h75a_y = ~u_d14_d15__unused_h71b_x; // h75a
assign u_d14_d15__unused_j117a_x = ~((u_readout_db__j115b_y & u_d14_d15__unused_h75a_y) | (u_readout_db__m117a_y & pin158_in)); // j117a
assign u_d14_d15__unused_r129b_y = ~u_d14_d15__unused_j117a_x; // r129b
assign u_d14_d15__unused_g100b_x = ~((pin9_in & u_readout_db__g102b_y) | (u_d14_d15__gnd & u_readout_db__g107b_y)); // g100b
assign u_d14_d15__unused_r104b_y = ~u_d14_d15__unused_g100b_x; // r104b
assign u_d14_d15__unused_g98a_x = ~((pin11_in & u_readout_db__g102b_y) | (u_d14_d15__gnd & u_readout_db__g107b_y)); // g98a
assign u_d14_d15__unused_r104a_y = ~u_d14_d15__unused_g98a_x; // r104a
assign u_d14_d15__unused_r113b_y = ~u_readout_db__r111a_y; // r113b
assign u_d14_d15__unused_r113a_y = ~u_readout_db__n115b_y; // r113a
assign u_d14_d15__unused_r114_x = ~(|{ &u_d14_d15__r114_a_resolved, &u_d14_d15__r114_b_resolved, &u_d14_d15__r114_c_resolved, &u_d14_d15__r114_d_resolved }); // r114
assign u_d14_d15__readout_d14 = ~u_d14_d15__unused_r114_x; // p145a
assign u_d14_d15__unused_r134a_y = ~u_readout_db__r111a_y; // r134a
assign u_d14_d15__unused_r134b_y = ~u_readout_db__n115b_y; // r134b
assign u_d14_d15__unused_r129a_x = ~(|{ &u_d14_d15__r129a_a_resolved, &u_d14_d15__r129a_b_resolved, &u_d14_d15__r129a_c_resolved, &u_d14_d15__r129a_d_resolved }); // r129a
assign u_d14_d15__readout_d15 = ~u_d14_d15__unused_r129a_x; // p144a
assign readout_d[14] = u_d14_d15__readout_d14;
assign readout_d[15] = u_d14_d15__readout_d15;
// End inlined jt054157_page10_readout_d14_d15 u_d14_d15
// End inlined jt054157_page10_readout_integrated u_page10_readout

// Inlined jt054157_page11_integrated u_page11_db
// Inlined jt054157_page11_db_output_matrix u_db_output_matrix
wire u_db_output_matrix__unused_l133a_y;
wire u_db_output_matrix__unused_l136a_y;
reg [3:0] u_db_output_matrix__unused_p171_q;
wire [3:0] u_db_output_matrix__unused_p171_nq;
reg [3:0] u_db_output_matrix__unused_p152_q;
wire [3:0] u_db_output_matrix__unused_p152_nq;
reg [3:0] u_db_output_matrix__unused_k179_q;
wire [3:0] u_db_output_matrix__unused_k179_nq;
reg [3:0] u_db_output_matrix__unused_l183_q;
wire [3:0] u_db_output_matrix__unused_l183_nq;
wire u_db_output_matrix__pin_db0_out;
wire u_db_output_matrix__pin_db1_out;
wire u_db_output_matrix__pin_db2_out;
wire u_db_output_matrix__pin_db3_out;
wire u_db_output_matrix__pin_db4_out;
wire u_db_output_matrix__pin_db5_out;
wire u_db_output_matrix__pin_db6_out;
wire u_db_output_matrix__pin_db7_out;
wire u_db_output_matrix__pin_db8_out;
wire u_db_output_matrix__pin_db9_out;
wire u_db_output_matrix__pin_db10_out;
wire u_db_output_matrix__pin_db11_out;
wire u_db_output_matrix__pin_db12_out;
wire u_db_output_matrix__pin_db13_out;
wire u_db_output_matrix__pin_db14_out;
wire u_db_output_matrix__pin_db15_out;
assign u_db_output_matrix__unused_l133a_y = &{reg4_d6,reg4_d5,pin112,pin116}; // l133a
assign u_db_output_matrix__unused_l136a_y = u_db_output_matrix__unused_l133a_y; // l136a
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_db_output_matrix__unused_l136a_y) begin
        u_db_output_matrix__unused_p171_q = u_readout_db__readout_d8_d11;
    end
end // p171
/* verilator lint_on LATCH */

assign u_db_output_matrix__unused_p171_nq = ~u_db_output_matrix__unused_p171_q; // p171
assign u_db_output_matrix__pin_db8_out  = u_db_output_matrix__unused_p171_q[0];
assign u_db_output_matrix__pin_db9_out  = u_db_output_matrix__unused_p171_q[1];
assign u_db_output_matrix__pin_db10_out = u_db_output_matrix__unused_p171_q[2];
assign u_db_output_matrix__pin_db11_out = u_db_output_matrix__unused_p171_q[3];

/* verilator lint_off LATCH */
always @(*) begin
    if (!u_db_output_matrix__unused_l136a_y) begin
        u_db_output_matrix__unused_p152_q = u_readout_db__readout_d12_d15;
    end
end // p152
/* verilator lint_on LATCH */

assign u_db_output_matrix__unused_p152_nq = ~u_db_output_matrix__unused_p152_q; // p152
assign u_db_output_matrix__pin_db12_out = u_db_output_matrix__unused_p152_q[0];
assign u_db_output_matrix__pin_db13_out = u_db_output_matrix__unused_p152_q[1];
assign u_db_output_matrix__pin_db14_out = u_db_output_matrix__unused_p152_q[2];
assign u_db_output_matrix__pin_db15_out = u_db_output_matrix__unused_p152_q[3];

/* verilator lint_off LATCH */
always @(*) begin
    if (!u_db_output_matrix__unused_l136a_y) begin
        u_db_output_matrix__unused_k179_q = u_readout_db__readout_d0_d3;
    end
end // k179
/* verilator lint_on LATCH */

assign u_db_output_matrix__unused_k179_nq = ~u_db_output_matrix__unused_k179_q; // k179
/* verilator lint_off LATCH */
always @(*) begin
    if (!u_db_output_matrix__unused_l136a_y) begin
        u_db_output_matrix__unused_l183_q = u_readout_db__readout_d4_d7;
    end
end // l183
/* verilator lint_on LATCH */

assign u_db_output_matrix__unused_l183_nq = ~u_db_output_matrix__unused_l183_q; // l183
assign u_db_output_matrix__pin_db0_out = p162a ? u_db_output_matrix__unused_k179_q[0] : u_db_output_matrix__unused_p171_q[0]; // p188a, p195b_buf
assign u_db_output_matrix__pin_db1_out = p162a ? u_db_output_matrix__unused_k179_q[1] : u_db_output_matrix__unused_p171_q[1]; // p186a, p194a_buf
assign u_db_output_matrix__pin_db2_out = p162a ? u_db_output_matrix__unused_k179_q[2] : u_db_output_matrix__unused_p171_q[2]; // p188b, p194b
assign u_db_output_matrix__pin_db3_out = p162a ? u_db_output_matrix__unused_k179_q[3] : u_db_output_matrix__unused_p171_q[3]; // p184a, p193a_buf
assign u_db_output_matrix__pin_db4_out = p162a ? u_db_output_matrix__unused_l183_q[0] : u_db_output_matrix__unused_p152_q[0]; // p186b, p195a_buf
assign u_db_output_matrix__pin_db5_out = p162a ? u_db_output_matrix__unused_l183_q[1] : u_db_output_matrix__unused_p152_q[1]; // p181b, r171a_buf
assign u_db_output_matrix__pin_db6_out = p162a ? u_db_output_matrix__unused_l183_q[2] : u_db_output_matrix__unused_p152_q[2]; // p183b, r172b_buf
assign u_db_output_matrix__pin_db7_out = p162a ? u_db_output_matrix__unused_l183_q[3] : u_db_output_matrix__unused_p152_q[3]; // p179b, r172a_buf
assign pin_db_out[0] = u_db_output_matrix__pin_db0_out;
assign pin_db_out[1] = u_db_output_matrix__pin_db1_out;
assign pin_db_out[2] = u_db_output_matrix__pin_db2_out;
assign pin_db_out[3] = u_db_output_matrix__pin_db3_out;
assign pin_db_out[4] = u_db_output_matrix__pin_db4_out;
assign pin_db_out[5] = u_db_output_matrix__pin_db5_out;
assign pin_db_out[6] = u_db_output_matrix__pin_db6_out;
assign pin_db_out[7] = u_db_output_matrix__pin_db7_out;
assign pin_db_out[8] = u_db_output_matrix__pin_db8_out;
assign pin_db_out[9] = u_db_output_matrix__pin_db9_out;
assign pin_db_out[10] = u_db_output_matrix__pin_db10_out;
assign pin_db_out[11] = u_db_output_matrix__pin_db11_out;
assign pin_db_out[12] = u_db_output_matrix__pin_db12_out;
assign pin_db_out[13] = u_db_output_matrix__pin_db13_out;
assign pin_db_out[14] = u_db_output_matrix__pin_db14_out;
assign pin_db_out[15] = u_db_output_matrix__pin_db15_out;
// End inlined jt054157_page11_db_output_matrix u_db_output_matrix
// Inlined jt054157_page11_vc_dir u_vc_dir
wire u_vc_dir__unused_n120a_y;
wire u_vc_dir__unused_n110b_y;
wire u_vc_dir__unused_g111a_y;
wire u_vc_dir__unused_g108b_y;
wire u_vc_dir__unused_m130a_y;
wire u_vc_dir__unused_j114a_y;
wire u_vc_dir__unused_g111b_y;
wire u_vc_dir__unused_g108a_y;
wire u_vc_dir__unused_n111b_x;
wire u_vc_dir__unused_j120a_x;
wire u_vc_dir__unused_g109a_y;
wire u_vc_dir__unused_g109b_y;
wire u_vc_dir__unused_l121a_y;
wire u_vc_dir__unused_k129_y;
wire u_vc_dir__unused_l122b_y;
wire u_vc_dir__unused_l124a_y;
wire u_vc_dir__unused_l128a_y;
assign u_vc_dir__unused_n120a_y = ~pin_ab2; // n120a
assign u_vc_dir__unused_n110b_y = ~reg4_d3_buf2; // n110b
assign u_vc_dir__unused_g111a_y = ~pin_ab1; // g111a
assign u_vc_dir__unused_g108b_y = ~reg4_d4_buf3; // g108b
assign u_vc_dir__unused_n111b_x = ~((u_vc_dir__unused_n120a_y & u_vc_dir__unused_n110b_y) | (u_vc_dir__unused_g111a_y & reg4_d3_buf2)); // n111b
assign u_readout_db__r111a_y = ~u_vc_dir__unused_n111b_x; // r111a
assign u_vc_dir__unused_g109a_y = pin_ab1 ? reg4_d4_buf3 : u_vc_dir__unused_g108b_y; // g116a, g109a
assign u_readout_db__n115b_y = reg4_d3_buf2 & u_vc_dir__unused_g109a_y; // n115b
assign u_vc_dir__unused_m130a_y = ~pin_ab2; // m130a
assign u_vc_dir__unused_j114a_y = ~reg4_d3_buf3; // j114a
assign u_vc_dir__unused_j120a_x = ~((u_vc_dir__unused_m130a_y & reg4_d3_buf3) | (u_vc_dir__unused_g111b_y & u_vc_dir__unused_j114a_y)); // j120a
assign u_readout_db__j122a_y = ~u_vc_dir__unused_j120a_x; // j122a
assign u_vc_dir__unused_g111b_y = ~pin_ab1; // g111b
assign u_vc_dir__unused_g108a_y = ~reg4_d4_buf2; // g108a
assign u_vc_dir__unused_g109b_y = pin_ab1 ? reg4_d4_buf2 : u_vc_dir__unused_g108a_y; // g115b, g109b
assign u_readout_db__g114a_y = reg4_d3_buf3 & u_vc_dir__unused_g109b_y; // g114a
assign u_vc_dir__unused_l121a_y = reg4_d6 | m118a; // l121a
assign u_vc_dir__unused_k129_y = u_vc_dir__unused_l121a_y; // k129
assign u_vc_dir__unused_l122b_y = ~pin99; // l122b
assign u_vc_dir__unused_l124a_y = u_vc_dir__unused_l122b_y & u_vc_dir__unused_k129_y; // l124a
assign u_vc_dir__unused_l128a_y = &{u_vc_dir__unused_l124a_y,pin95,pin112,reg4_d5}; // l128a
assign pins_vc_dir[0] = ~u_vc_dir__unused_l128a_y; // a79a
assign pins_vc_dir[1] = ~u_vc_dir__unused_l128a_y; // a79b
assign pins_vc_dir[2] = ~u_vc_dir__unused_l128a_y; // a100a
assign pins_vc_dir[3] = ~u_vc_dir__unused_l128a_y; // a103a
assign pins_vc_dir[4] = ~u_vc_dir__unused_l128a_y; // a134a
assign pins_vc_dir[5] = ~u_vc_dir__unused_l128a_y; // c209a
assign pins_vc_dir[6] = ~u_vc_dir__unused_l128a_y; // c176a
assign pins_vc_dir[7] = ~u_vc_dir__unused_l128a_y; // c177a
// End inlined jt054157_page11_vc_dir u_vc_dir
// End inlined jt054157_page11_integrated u_page11_db
// End inlined jt054157_page10_11_readout_db_integrated u_readout_db

// Inlined jt054157_db_package_output_map u_db_package_output_map
assign pin_076_out = pin_db_out[0];
assign pin_077_out = pin_db_out[1];
assign pin_078_out = pin_db_out[2];
assign pin_079_out = pin_db_out[3];
assign pin_082_out = pin_db_out[4];
assign pin_083_out = pin_db_out[5];
assign pin_084_out = pin_db_out[6];
assign pin_085_out = pin_db_out[7];
assign pin_086_out = pin_db_out[8];
assign pin_087_out = pin_db_out[9];
assign pin_088_out = pin_db_out[10];
assign pin_089_out = pin_db_out[11];
assign pin_091_out = pin_db_out[12];
assign pin_092_out = pin_db_out[13];
assign pin_093_out = pin_db_out[14];
assign pin_094_out = pin_db_out[15];

assign pin_076_oe = pin_db_oe[0];
assign pin_077_oe = pin_db_oe[1];
assign pin_078_oe = pin_db_oe[2];
assign pin_079_oe = pin_db_oe[3];
assign pin_082_oe = pin_db_oe[4];
assign pin_083_oe = pin_db_oe[5];
assign pin_084_oe = pin_db_oe[6];
assign pin_085_oe = pin_db_oe[7];
assign pin_086_oe = pin_db_oe[8];
assign pin_087_oe = pin_db_oe[9];
assign pin_088_oe = pin_db_oe[10];
assign pin_089_oe = pin_db_oe[11];
assign pin_091_oe = pin_db_oe[12];
assign pin_092_oe = pin_db_oe[13];
assign pin_093_oe = pin_db_oe[14];
assign pin_094_oe = pin_db_oe[15];
// End inlined jt054157_db_package_output_map u_db_package_output_map
// End inlined jt054157_readout_db_package_integrated u_readout_db_package

endmodule


// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054157_page08_page09_hofs_readout_db_package_integrated.v
// -----------------------------------------------------------------------------

// Page-8 plus page-9/HOF/readout DB package integration wrapper.
//
// Composes the current HOF/page-9/readout DB package wrapper with the
// page-8 package output wrapper. Page-8 CPU register buffer rails are
// fed from the existing HOF/page-2 reconstruction. Page-8 PIN_DB0_IN
// through PIN_DB15_IN scalars are sourced from the shared CPU
// pin_db_in[15:0] bus. Page-9/HOF logic still consumes the low byte.
// Page-8 VC ROM-data pad OE is derived from the recovered page-11 VC
// direction rail; the non-VC page-8 bidirectional pad OE bits remain explicit.

module jt054157_page08_page09_hofs_readout_db_package_integrated #(
    parameter DB_DIR_DRIVE_VALUE = 1'b0,
    parameter VC_DIR_DRIVE_VALUE = 1'b1
)(
    input  wire       pin_clk,
    input  wire       pin_nres,
    input  wire       pin64,
    input  wire       pin112,
    input  wire       pin_ab1,
    input  wire       pin_ab2,
    input  wire [15:0] pin_db_in,
    input  wire       pin113,
    input  wire       pin_z4h,
    input  wire       pin_z2h,
    input  wire       pin_z1h,
    input  wire       pin_col0,
    input  wire       pin_col1,
    input  wire       pin_col2,
    input  wire       pin_col3,
    input  wire       pin_col4,
    input  wire       pin_col5,
    input  wire       pin_col6,
    input  wire       pin_col7,

    input  wire       hcnt1_raw,
    input  wire       hcnt0_raw,

    output wire       nres_sync,
    output wire       nres_sync2,
    output wire [3:0] reg_wr_n,
    output wire       reg0_d0,
    output wire       reg0_d3,
    output wire       reg0_d4,
    output wire       reg2_d0,
    output wire       reg2_d2,
    output wire       reg2_d4,
    output wire       reg2_d6,
    output wire       reg4_d3,
    output wire       reg4_d3_buf,
    output wire       reg4_d3_buf2,
    output wire       reg4_d3_buf3,
    output wire       g124a,
    output wire       reg4_d4_buf,
    output wire       reg4_d4_buf2,
    output wire       reg4_d4_buf3,
    output wire       reg4_d5,
    output wire       reg4_d6,
    output wire       reg6_d5,
    output wire       k114a,
    output wire       j136a,
    output wire       j152a,
    output wire       j121b,
    output wire       j152b,
    output wire       l135a,
    output wire       loada,
    output wire       loadb,
    output wire       loadc,
    output wire       loadd,
    output wire [2:0] hcnt,
    output wire [3:0] j172_x_n,
    output wire [2:0] hofsd,
    output wire [2:0] hofsc,
    output wire [2:0] hofs_b,
    output wire [2:0] hofsa,
    output wire [2:0] hofsd_f,
    output wire [2:0] hofsc_f,
    output wire [2:0] hofs_b_f,
    output wire [2:0] hofsa_f,
    output wire       pin114,
    output wire       pin115,
    output wire       pin116,
    output wire       pin117,
    output wire       pin118,
    output wire       pin119,
    output wire       pin125,
    output wire       pin126,
    output wire       pin127,
    output wire       pin132,
    output wire       pin133,
    output wire       pin134,
    output wire       pin138,
    output wire       pin141,
    output wire       pin142,
    output wire       c114b,
    output wire       j135a,
    output wire       m118a,
    output wire [3:0] h109_q,
    output wire pin_114_out,
    output wire pin_115_out,
    output wire pin_116_out,
    output wire pin_117_out,
    output wire pin_118_out,
    output wire pin_119_out,
    output wire pin_125_out,
    output wire pin_126_out,
    output wire pin_127_out,
    output wire pin_132_out,
    output wire pin_133_out,
    output wire pin_134_out,
    output wire pin_138_out,
    output wire pin_141_out,
    output wire pin_142_out,

    input  wire       pin95,
    input  wire       pin_crom,
    input  wire       pin_uds,
    input  wire       pin_lds,

    output wire       pin101,
    output wire       pin102,
    output wire       pin103,
    output wire       pin104,
    output wire       pin105,
    output wire       pin106,
    output wire       pin107,
    output wire       pin108,
    output wire       p162a,
    output wire       pin_db_lower_dir,
    output wire       pin_db_upper_dir,

    output wire       m120a_y,
    output wire       m111a_y,
    output wire       p148,
    output wire       l130b_y,
    output wire       l132b_y,
    output wire       m121a_x,
    output wire       n111a_y,
    output wire [3:0] m181_x_n,
    output wire       m187b_y,
    output wire       m185b_y,
    output wire       m187a_y,
    output wire       m185a_y,
    output wire       n108b_y,
    output wire       p146b_y,
    output wire       r144a_y,
    output wire       p146a_y,
    output wire       r144b_y,
    output wire       n113b_y,
    output wire       l114a_y,
    output wire       l118b_y,
    output wire       l126b_y,
    output wire       l108b_y,
    output wire       p159a_y,
    output wire       p162a_y,
    output wire       p150b_y,
    output wire       p149a_y,
    output wire       l130a_y,
    output wire       p160b_y,
    output wire       r161a_y,
    output wire       l132a_y,
    output wire       p141b_y,
    output wire       l127_y,
    output wire       n65b_y,
    output wire       n65a_y,
    output wire       m109a_y,
    output wire       m76a_q,
    output wire       m73_q,
    output wire       k124b_y,
    output wire       k137b_y,
    output wire       k126b_x,
    output wire       k135b_x,
    output wire       k124a_y,
    output wire       l118a_y,
    output wire       l119b_y,
    output wire       l112_y,
    output wire       l108a_q,
    output wire       k119a_q,
    output wire       l116a_y,
    output wire       l117b_y,
    output wire       l115b_y,
    output wire       l119a_y,
    output wire       l121b_y,
    output wire       l121b,
    output wire pin_101_out,
    output wire pin_102_out,
    output wire pin_103_out,
    output wire pin_104_out,
    output wire pin_105_out,
    output wire pin_106_out,
    output wire pin_107_out,
    output wire pin_108_out,

    input  wire       pin34_in,
    input  wire       pin3_in,
    input  wire       pin12_in,
    input  wire       pin16_in,
    input  wire       pin35_in,
    input  wire       pin4_in,
    input  wire       pin13_in,
    input  wire       pin17_in,
    input  wire       pin23_in,
    input  wire       pin5_in,
    input  wire       pin14_in,
    input  wire       pin18_in,
    input  wire       pin24_in,
    input  wire       pin6_in,
    input  wire       pin15_in,
    input  wire       pin19_in,
    input  wire       pin155_in,
    input  wire       pin156_in,
    input  wire       pin48_in,
    input  wire       pin25_in,
    input  wire       pin157_in,
    input  wire       pin158_in,
    input  wire       pin7_in,
    input  wire       pin21_in,
    input  wire       pin159_in,
    input  wire       pin49_in,
    input  wire       pin36_in,
    input  wire       pin9_in,
    input  wire       pin37_in,
    input  wire       pin8_in,
    input  wire       pin22_in,
    input  wire       pin2_in,
    input  wire       pin27_in,
    input  wire       pin28_in,
    input  wire       pin11_in,
    input  wire       pin38_in,
    input  wire       pin39_in,
    input  wire       pin42_in,
    input  wire       pin43_in,
    input  wire       pin29_in,
    input  wire       pin44_in,
    input  wire       pin31_in,
    input  wire       pin45_in,
    input  wire       pin32_in,
    input  wire       pin46_in,
    input  wire       pin33_in,
    input  wire       pin47_in,
    output wire [15:0] readout_d,

    input  wire       pin99,
    output wire [15:0] pin_db_out,
    output wire [ 7:0] pins_vc_dir,
    output wire        pin_076_out,
    output wire        pin_076_oe,
    output wire        pin_077_out,
    output wire        pin_077_oe,
    output wire        pin_078_out,
    output wire        pin_078_oe,
    output wire        pin_079_out,
    output wire        pin_079_oe,
    output wire        pin_082_out,
    output wire        pin_082_oe,
    output wire        pin_083_out,
    output wire        pin_083_oe,
    output wire        pin_084_out,
    output wire        pin_084_oe,
    output wire        pin_085_out,
    output wire        pin_085_oe,
    output wire        pin_086_out,
    output wire        pin_086_oe,
    output wire        pin_087_out,
    output wire        pin_087_oe,
    output wire        pin_088_out,
    output wire        pin_088_oe,
    output wire        pin_089_out,
    output wire        pin_089_oe,
    output wire        pin_091_out,
    output wire        pin_091_oe,
    output wire        pin_092_out,
    output wire        pin_092_oe,
    output wire        pin_093_out,
    output wire        pin_093_oe,
    output wire        pin_094_out,
    output wire        pin_094_oe,

    output wire       pin2_out,
    output wire       pin3_out,
    output wire       pin4_out,
    output wire       pin5_out,
    output wire       pin6_out,
    output wire       pin7_out,
    output wire       pin8_out,
    output wire       pin9_out,
    output wire       pin11_out,
    output wire       pin12_out,
    output wire       pin13_out,
    output wire       pin14_out,
    output wire       pin15_out,
    output wire       pin16_out,
    output wire       pin17_out,
    output wire       pin18_out,
    output wire       pin19_out,
    output wire       pin21_out,
    output wire       pin22_out,
    output wire       pin23_out,
    output wire       pin24_out,
    output wire       pin25_out,
    output wire       pin26_out,
    output wire       pin27_out,
    output wire       pin28_out,
    output wire       pin29_out,
    output wire       pin31_out,
    output wire       pin32_out,
    output wire       pin33_out,
    output wire       pin34_out,
    output wire       pin35_out,
    output wire       pin36_out,
    output wire       pin37_out,
    output wire       pin38_out,
    output wire       pin39_out,
    output wire       pin42_out,
    output wire       pin43_out,
    output wire       pin44_out,
    output wire       pin45_out,
    output wire       pin46_out,
    output wire       pin47_out,
    output wire       pin48_out,
    output wire       pin49_out,
    output wire       pin155_out,
    output wire       pin156_out,
    output wire       pin157_out,
    output wire       pin158_out,
    output wire       pin159_out,
    input  wire [15:0] page08_non_vc_pin_oe,
    output wire        pin_002_out,
    output wire        pin_002_oe,
    output wire        pin_003_out,
    output wire        pin_003_oe,
    output wire        pin_004_out,
    output wire        pin_004_oe,
    output wire        pin_005_out,
    output wire        pin_005_oe,
    output wire        pin_006_out,
    output wire        pin_006_oe,
    output wire        pin_007_out,
    output wire        pin_007_oe,
    output wire        pin_008_out,
    output wire        pin_008_oe,
    output wire        pin_009_out,
    output wire        pin_009_oe,
    output wire        pin_011_out,
    output wire        pin_011_oe,
    output wire        pin_012_out,
    output wire        pin_012_oe,
    output wire        pin_013_out,
    output wire        pin_013_oe,
    output wire        pin_014_out,
    output wire        pin_014_oe,
    output wire        pin_015_out,
    output wire        pin_015_oe,
    output wire        pin_016_out,
    output wire        pin_016_oe,
    output wire        pin_017_out,
    output wire        pin_017_oe,
    output wire        pin_018_out,
    output wire        pin_018_oe,
    output wire        pin_019_out,
    output wire        pin_019_oe,
    output wire        pin_021_out,
    output wire        pin_021_oe,
    output wire        pin_022_out,
    output wire        pin_022_oe,
    output wire        pin_023_out,
    output wire        pin_023_oe,
    output wire        pin_024_out,
    output wire        pin_024_oe,
    output wire        pin_025_out,
    output wire        pin_025_oe,
    output wire        pin_026_out,
    output wire        pin_026_oe,
    output wire        pin_027_out,
    output wire        pin_027_oe,
    output wire        pin_028_out,
    output wire        pin_028_oe,
    output wire        pin_029_out,
    output wire        pin_029_oe,
    output wire        pin_031_out,
    output wire        pin_031_oe,
    output wire        pin_032_out,
    output wire        pin_032_oe,
    output wire        pin_033_out,
    output wire        pin_033_oe,
    output wire        pin_034_out,
    output wire        pin_034_oe,
    output wire        pin_035_out,
    output wire        pin_035_oe,
    output wire        pin_036_out,
    output wire        pin_036_oe,
    output wire        pin_037_out,
    output wire        pin_037_oe,
    output wire        pin_038_out,
    output wire        pin_038_oe,
    output wire        pin_039_out,
    output wire        pin_039_oe,
    output wire        pin_042_out,
    output wire        pin_042_oe,
    output wire        pin_043_out,
    output wire        pin_043_oe,
    output wire        pin_044_out,
    output wire        pin_044_oe,
    output wire        pin_045_out,
    output wire        pin_045_oe,
    output wire        pin_046_out,
    output wire        pin_046_oe,
    output wire        pin_047_out,
    output wire        pin_047_oe,
    output wire        pin_048_out,
    output wire        pin_048_oe,
    output wire        pin_049_out,
    output wire        pin_049_oe,
    output wire        pin_155_out,
    output wire        pin_155_oe,
    output wire        pin_156_out,
    output wire        pin_156_oe,
    output wire        pin_157_out,
    output wire        pin_157_oe,
    output wire        pin_158_out,
    output wire        pin_158_oe,
    output wire        pin_159_out,
    output wire        pin_159_oe
);

wire [7:0] page09_pin_db_in = pin_db_in[7:0];

wire pin_db0_in = pin_db_in[0];
wire pin_db1_in = pin_db_in[1];
wire pin_db2_in = pin_db_in[2];
wire pin_db3_in = pin_db_in[3];
wire pin_db4_in = pin_db_in[4];
wire pin_db5_in = pin_db_in[5];
wire pin_db6_in = pin_db_in[6];
wire pin_db7_in = pin_db_in[7];
wire pin_db8_in = pin_db_in[8];
wire pin_db9_in = pin_db_in[9];
wire pin_db10_in = pin_db_in[10];
wire pin_db11_in = pin_db_in[11];
wire pin_db12_in = pin_db_in[12];
wire pin_db13_in = pin_db_in[13];
wire pin_db14_in = pin_db_in[14];
wire pin_db15_in = pin_db_in[15];

wire        page08_vc_pin_oe = pins_vc_dir[0] == VC_DIR_DRIVE_VALUE;
wire [47:0] page08_pin_oe;

assign page08_pin_oe[0] = page08_non_vc_pin_oe[0];
assign page08_pin_oe[1] = page08_vc_pin_oe;
assign page08_pin_oe[2] = page08_vc_pin_oe;
assign page08_pin_oe[3] = page08_vc_pin_oe;
assign page08_pin_oe[4] = page08_vc_pin_oe;
assign page08_pin_oe[5] = page08_non_vc_pin_oe[1];
assign page08_pin_oe[6] = page08_non_vc_pin_oe[2];
assign page08_pin_oe[7] = page08_vc_pin_oe;
assign page08_pin_oe[8] = page08_vc_pin_oe;
assign page08_pin_oe[9] = page08_vc_pin_oe;
assign page08_pin_oe[10] = page08_vc_pin_oe;
assign page08_pin_oe[11] = page08_non_vc_pin_oe[3];
assign page08_pin_oe[12] = page08_non_vc_pin_oe[4];
assign page08_pin_oe[13] = page08_vc_pin_oe;
assign page08_pin_oe[14] = page08_vc_pin_oe;
assign page08_pin_oe[15] = page08_vc_pin_oe;
assign page08_pin_oe[16] = page08_vc_pin_oe;
assign page08_pin_oe[17] = page08_non_vc_pin_oe[5];
assign page08_pin_oe[18] = page08_non_vc_pin_oe[6];
assign page08_pin_oe[19] = page08_vc_pin_oe;
assign page08_pin_oe[20] = page08_vc_pin_oe;
assign page08_pin_oe[21] = page08_vc_pin_oe;
assign page08_pin_oe[22] = page08_vc_pin_oe;
assign page08_pin_oe[23] = page08_non_vc_pin_oe[7];
assign page08_pin_oe[24] = page08_non_vc_pin_oe[8];
assign page08_pin_oe[25] = page08_vc_pin_oe;
assign page08_pin_oe[26] = page08_vc_pin_oe;
assign page08_pin_oe[27] = page08_vc_pin_oe;
assign page08_pin_oe[28] = page08_vc_pin_oe;
assign page08_pin_oe[29] = page08_non_vc_pin_oe[9];
assign page08_pin_oe[30] = page08_non_vc_pin_oe[10];
assign page08_pin_oe[31] = page08_vc_pin_oe;
assign page08_pin_oe[32] = page08_vc_pin_oe;
assign page08_pin_oe[33] = page08_vc_pin_oe;
assign page08_pin_oe[34] = page08_vc_pin_oe;
assign page08_pin_oe[35] = page08_non_vc_pin_oe[11];
assign page08_pin_oe[36] = page08_non_vc_pin_oe[12];
assign page08_pin_oe[37] = page08_vc_pin_oe;
assign page08_pin_oe[38] = page08_vc_pin_oe;
assign page08_pin_oe[39] = page08_vc_pin_oe;
assign page08_pin_oe[40] = page08_vc_pin_oe;
assign page08_pin_oe[41] = page08_non_vc_pin_oe[13];
assign page08_pin_oe[42] = page08_non_vc_pin_oe[14];
assign page08_pin_oe[43] = page08_vc_pin_oe;
assign page08_pin_oe[44] = page08_vc_pin_oe;
assign page08_pin_oe[45] = page08_vc_pin_oe;
assign page08_pin_oe[46] = page08_vc_pin_oe;
assign page08_pin_oe[47] = page08_non_vc_pin_oe[15];

jt054157_page09_hofs_readout_db_package_integrated #(
    .DB_DIR_DRIVE_VALUE ( DB_DIR_DRIVE_VALUE )
) u_page09_hofs_readout_db_package(
    .pin_clk          ( pin_clk          ),
    .pin_nres         ( pin_nres         ),
    .pin64            ( pin64            ),
    .pin112           ( pin112           ),
    .pin_ab1          ( pin_ab1          ),
    .pin_ab2          ( pin_ab2          ),
    .pin_db_in        ( page09_pin_db_in ),
    .pin113           ( pin113           ),
    .pin_z4h          ( pin_z4h          ),
    .pin_z2h          ( pin_z2h          ),
    .pin_z1h          ( pin_z1h          ),
    .pin_col0         ( pin_col0         ),
    .pin_col1         ( pin_col1         ),
    .pin_col2         ( pin_col2         ),
    .pin_col3         ( pin_col3         ),
    .pin_col4         ( pin_col4         ),
    .pin_col5         ( pin_col5         ),
    .pin_col6         ( pin_col6         ),
    .pin_col7         ( pin_col7         ),
    .hcnt1_raw        ( hcnt1_raw        ),
    .hcnt0_raw        ( hcnt0_raw        ),
    .nres_sync        ( nres_sync        ),
    .nres_sync2       ( nres_sync2       ),
    .reg_wr_n         ( reg_wr_n         ),
    .reg0_d0          ( reg0_d0          ),
    .reg0_d3          ( reg0_d3          ),
    .reg0_d4          ( reg0_d4          ),
    .reg2_d0          ( reg2_d0          ),
    .reg2_d2          ( reg2_d2          ),
    .reg2_d4          ( reg2_d4          ),
    .reg2_d6          ( reg2_d6          ),
    .reg4_d3          ( reg4_d3          ),
    .reg4_d3_buf      ( reg4_d3_buf      ),
    .reg4_d3_buf2     ( reg4_d3_buf2     ),
    .reg4_d3_buf3     ( reg4_d3_buf3     ),
    .g124a            ( g124a            ),
    .reg4_d4_buf      ( reg4_d4_buf      ),
    .reg4_d4_buf2     ( reg4_d4_buf2     ),
    .reg4_d4_buf3     ( reg4_d4_buf3     ),
    .reg4_d5          ( reg4_d5          ),
    .reg4_d6          ( reg4_d6          ),
    .reg6_d5          ( reg6_d5          ),
    .k114a            ( k114a            ),
    .j136a            ( j136a            ),
    .j152a            ( j152a            ),
    .j121b            ( j121b            ),
    .j152b            ( j152b            ),
    .l135a            ( l135a            ),
    .loada            ( loada            ),
    .loadb            ( loadb            ),
    .loadc            ( loadc            ),
    .loadd            ( loadd            ),
    .hcnt             ( hcnt             ),
    .j172_x_n         ( j172_x_n         ),
    .hofsd            ( hofsd            ),
    .hofsc            ( hofsc            ),
    .hofs_b           ( hofs_b           ),
    .hofsa            ( hofsa            ),
    .hofsd_f          ( hofsd_f          ),
    .hofsc_f          ( hofsc_f          ),
    .hofs_b_f         ( hofs_b_f         ),
    .hofsa_f          ( hofsa_f          ),
    .pin114           ( pin114           ),
    .pin115           ( pin115           ),
    .pin116           ( pin116           ),
    .pin117           ( pin117           ),
    .pin118           ( pin118           ),
    .pin119           ( pin119           ),
    .pin125           ( pin125           ),
    .pin126           ( pin126           ),
    .pin127           ( pin127           ),
    .pin132           ( pin132           ),
    .pin133           ( pin133           ),
    .pin134           ( pin134           ),
    .pin138           ( pin138           ),
    .pin141           ( pin141           ),
    .pin142           ( pin142           ),
    .c114b            ( c114b            ),
    .j135a            ( j135a            ),
    .m118a            ( m118a            ),
    .h109_q           ( h109_q           ),
    .pin_114_out      ( pin_114_out      ),
    .pin_115_out      ( pin_115_out      ),
    .pin_116_out      ( pin_116_out      ),
    .pin_117_out      ( pin_117_out      ),
    .pin_118_out      ( pin_118_out      ),
    .pin_119_out      ( pin_119_out      ),
    .pin_125_out      ( pin_125_out      ),
    .pin_126_out      ( pin_126_out      ),
    .pin_127_out      ( pin_127_out      ),
    .pin_132_out      ( pin_132_out      ),
    .pin_133_out      ( pin_133_out      ),
    .pin_134_out      ( pin_134_out      ),
    .pin_138_out      ( pin_138_out      ),
    .pin_141_out      ( pin_141_out      ),
    .pin_142_out      ( pin_142_out      ),
    .pin95            ( pin95            ),
    .pin_crom         ( pin_crom         ),
    .pin_uds          ( pin_uds          ),
    .pin_lds          ( pin_lds          ),
    .pin101           ( pin101           ),
    .pin102           ( pin102           ),
    .pin103           ( pin103           ),
    .pin104           ( pin104           ),
    .pin105           ( pin105           ),
    .pin106           ( pin106           ),
    .pin107           ( pin107           ),
    .pin108           ( pin108           ),
    .p162a            ( p162a            ),
    .pin_db_lower_dir ( pin_db_lower_dir ),
    .pin_db_upper_dir ( pin_db_upper_dir ),
    .m120a_y          ( m120a_y          ),
    .m111a_y          ( m111a_y          ),
    .p148             ( p148             ),
    .l130b_y          ( l130b_y          ),
    .l132b_y          ( l132b_y          ),
    .m121a_x          ( m121a_x          ),
    .n111a_y          ( n111a_y          ),
    .m181_x_n         ( m181_x_n         ),
    .m187b_y          ( m187b_y          ),
    .m185b_y          ( m185b_y          ),
    .m187a_y          ( m187a_y          ),
    .m185a_y          ( m185a_y          ),
    .n108b_y          ( n108b_y          ),
    .p146b_y          ( p146b_y          ),
    .r144a_y          ( r144a_y          ),
    .p146a_y          ( p146a_y          ),
    .r144b_y          ( r144b_y          ),
    .n113b_y          ( n113b_y          ),
    .l114a_y          ( l114a_y          ),
    .l118b_y          ( l118b_y          ),
    .l126b_y          ( l126b_y          ),
    .l108b_y          ( l108b_y          ),
    .p159a_y          ( p159a_y          ),
    .p162a_y          ( p162a_y          ),
    .p150b_y          ( p150b_y          ),
    .p149a_y          ( p149a_y          ),
    .l130a_y          ( l130a_y          ),
    .p160b_y          ( p160b_y          ),
    .r161a_y          ( r161a_y          ),
    .l132a_y          ( l132a_y          ),
    .p141b_y          ( p141b_y          ),
    .l127_y           ( l127_y           ),
    .n65b_y           ( n65b_y           ),
    .n65a_y           ( n65a_y           ),
    .m109a_y          ( m109a_y          ),
    .m76a_q           ( m76a_q           ),
    .m73_q            ( m73_q            ),
    .k124b_y          ( k124b_y          ),
    .k137b_y          ( k137b_y          ),
    .k126b_x          ( k126b_x          ),
    .k135b_x          ( k135b_x          ),
    .k124a_y          ( k124a_y          ),
    .l118a_y          ( l118a_y          ),
    .l119b_y          ( l119b_y          ),
    .l112_y           ( l112_y           ),
    .l108a_q          ( l108a_q          ),
    .k119a_q          ( k119a_q          ),
    .l116a_y          ( l116a_y          ),
    .l117b_y          ( l117b_y          ),
    .l115b_y          ( l115b_y          ),
    .l119a_y          ( l119a_y          ),
    .l121b_y          ( l121b_y          ),
    .l121b            ( l121b            ),
    .pin_101_out      ( pin_101_out      ),
    .pin_102_out      ( pin_102_out      ),
    .pin_103_out      ( pin_103_out      ),
    .pin_104_out      ( pin_104_out      ),
    .pin_105_out      ( pin_105_out      ),
    .pin_106_out      ( pin_106_out      ),
    .pin_107_out      ( pin_107_out      ),
    .pin_108_out      ( pin_108_out      ),
    .pin34_in         ( pin34_in         ),
    .pin3_in          ( pin3_in          ),
    .pin12_in         ( pin12_in         ),
    .pin16_in         ( pin16_in         ),
    .pin35_in         ( pin35_in         ),
    .pin4_in          ( pin4_in          ),
    .pin13_in         ( pin13_in         ),
    .pin17_in         ( pin17_in         ),
    .pin23_in         ( pin23_in         ),
    .pin5_in          ( pin5_in          ),
    .pin14_in         ( pin14_in         ),
    .pin18_in         ( pin18_in         ),
    .pin24_in         ( pin24_in         ),
    .pin6_in          ( pin6_in          ),
    .pin15_in         ( pin15_in         ),
    .pin19_in         ( pin19_in         ),
    .pin155_in        ( pin155_in        ),
    .pin156_in        ( pin156_in        ),
    .pin48_in         ( pin48_in         ),
    .pin25_in         ( pin25_in         ),
    .pin157_in        ( pin157_in        ),
    .pin158_in        ( pin158_in        ),
    .pin7_in          ( pin7_in          ),
    .pin21_in         ( pin21_in         ),
    .pin159_in        ( pin159_in        ),
    .pin49_in         ( pin49_in         ),
    .pin36_in         ( pin36_in         ),
    .pin9_in          ( pin9_in          ),
    .pin37_in         ( pin37_in         ),
    .pin8_in          ( pin8_in          ),
    .pin22_in         ( pin22_in         ),
    .pin2_in          ( pin2_in          ),
    .pin27_in         ( pin27_in         ),
    .pin28_in         ( pin28_in         ),
    .pin11_in         ( pin11_in         ),
    .pin38_in         ( pin38_in         ),
    .pin39_in         ( pin39_in         ),
    .pin42_in         ( pin42_in         ),
    .pin43_in         ( pin43_in         ),
    .pin29_in         ( pin29_in         ),
    .pin44_in         ( pin44_in         ),
    .pin31_in         ( pin31_in         ),
    .pin45_in         ( pin45_in         ),
    .pin32_in         ( pin32_in         ),
    .pin46_in         ( pin46_in         ),
    .pin33_in         ( pin33_in         ),
    .pin47_in         ( pin47_in         ),
    .readout_d        ( readout_d        ),
    .pin99            ( pin99            ),
    .pin_db_out       ( pin_db_out       ),
    .pins_vc_dir      ( pins_vc_dir      ),
    .pin_076_out      ( pin_076_out      ),
    .pin_076_oe       ( pin_076_oe       ),
    .pin_077_out      ( pin_077_out      ),
    .pin_077_oe       ( pin_077_oe       ),
    .pin_078_out      ( pin_078_out      ),
    .pin_078_oe       ( pin_078_oe       ),
    .pin_079_out      ( pin_079_out      ),
    .pin_079_oe       ( pin_079_oe       ),
    .pin_082_out      ( pin_082_out      ),
    .pin_082_oe       ( pin_082_oe       ),
    .pin_083_out      ( pin_083_out      ),
    .pin_083_oe       ( pin_083_oe       ),
    .pin_084_out      ( pin_084_out      ),
    .pin_084_oe       ( pin_084_oe       ),
    .pin_085_out      ( pin_085_out      ),
    .pin_085_oe       ( pin_085_oe       ),
    .pin_086_out      ( pin_086_out      ),
    .pin_086_oe       ( pin_086_oe       ),
    .pin_087_out      ( pin_087_out      ),
    .pin_087_oe       ( pin_087_oe       ),
    .pin_088_out      ( pin_088_out      ),
    .pin_088_oe       ( pin_088_oe       ),
    .pin_089_out      ( pin_089_out      ),
    .pin_089_oe       ( pin_089_oe       ),
    .pin_091_out      ( pin_091_out      ),
    .pin_091_oe       ( pin_091_oe       ),
    .pin_092_out      ( pin_092_out      ),
    .pin_092_oe       ( pin_092_oe       ),
    .pin_093_out      ( pin_093_out      ),
    .pin_093_oe       ( pin_093_oe       ),
    .pin_094_out      ( pin_094_out      ),
    .pin_094_oe       ( pin_094_oe       )
);

// Inlined jt054157_page08_package_integrated u_page08_package
// Inlined jt054157_page08_outputs_integrated u_page08_outputs
wire       u_page08_package__u_page08_outputs__p168a_y;
wire       u_page08_package__u_page08_outputs__p170b_y;
wire       u_page08_package__u_page08_outputs__p162b;
wire       u_page08_package__u_page08_outputs__p161a;
wire       u_page08_package__u_page08_outputs__l136b;
wire       u_page08_package__u_page08_outputs__l137b;
wire       u_page08_package__u_page08_outputs__n185b;
wire       u_page08_package__u_page08_outputs__n186b;
wire       u_page08_package__u_page08_outputs__n172b;
wire       u_page08_package__u_page08_outputs__n173b;
wire       u_page08_package__u_page08_outputs__db0_8;
wire       u_page08_package__u_page08_outputs__db1_9;
wire       u_page08_package__u_page08_outputs__db2_10;
wire       u_page08_package__u_page08_outputs__db3_11;
wire       u_page08_package__u_page08_outputs__db4_12;
wire       u_page08_package__u_page08_outputs__db5_13;
wire       u_page08_package__u_page08_outputs__db6_14;
wire       u_page08_package__u_page08_outputs__db7_15;

// Inlined jt054157_page08_left_source_rails u_left_source_rails
assign u_page08_package__u_page08_outputs__p168a_y = ~reg6_d5; // p168a
assign u_page08_package__u_page08_outputs__p170b_y = ~u_page08_package__u_page08_outputs__p168a_y; // p170b
assign u_page08_package__u_page08_outputs__p162b = ~((u_page08_package__u_page08_outputs__p170b_y & pin_db4_in) | (u_page08_package__u_page08_outputs__p168a_y & pin_db12_in)); // p166a
assign u_page08_package__u_page08_outputs__db4_12 = ~u_page08_package__u_page08_outputs__p162b; // u_page08_package__u_page08_outputs__p162b
assign u_page08_package__u_page08_outputs__p161a = ~((u_page08_package__u_page08_outputs__p170b_y & pin_db5_in) | (u_page08_package__u_page08_outputs__p168a_y & pin_db13_in)); // p164b
assign u_page08_package__u_page08_outputs__db5_13 = ~u_page08_package__u_page08_outputs__p161a; // u_page08_package__u_page08_outputs__p161a
assign u_page08_package__u_page08_outputs__l136b = ~((u_page08_package__u_page08_outputs__p170b_y & pin_db6_in) | (u_page08_package__u_page08_outputs__p168a_y & pin_db14_in)); // p164a
assign u_page08_package__u_page08_outputs__db6_14 = ~u_page08_package__u_page08_outputs__l136b; // u_page08_package__u_page08_outputs__l136b
assign u_page08_package__u_page08_outputs__l137b = ~((u_page08_package__u_page08_outputs__p170b_y & pin_db7_in) | (u_page08_package__u_page08_outputs__p168a_y & pin_db15_in)); // p166b
assign u_page08_package__u_page08_outputs__db7_15 = ~u_page08_package__u_page08_outputs__l137b; // u_page08_package__u_page08_outputs__l137b
assign u_page08_package__u_page08_outputs__n185b = ~((u_page08_package__u_page08_outputs__p170b_y & pin_db0_in) | (u_page08_package__u_page08_outputs__p168a_y & pin_db8_in)); // p182a
assign u_page08_package__u_page08_outputs__db0_8 = ~u_page08_package__u_page08_outputs__n185b; // u_page08_package__u_page08_outputs__n185b
assign u_page08_package__u_page08_outputs__n186b = ~((u_page08_package__u_page08_outputs__p170b_y & pin_db1_in) | (u_page08_package__u_page08_outputs__p168a_y & pin_db9_in)); // p180a
assign u_page08_package__u_page08_outputs__db1_9 = ~u_page08_package__u_page08_outputs__n186b; // u_page08_package__u_page08_outputs__n186b
assign u_page08_package__u_page08_outputs__n172b = ~((u_page08_package__u_page08_outputs__p170b_y & pin_db2_in) | (u_page08_package__u_page08_outputs__p168a_y & pin_db10_in)); // p169a
assign u_page08_package__u_page08_outputs__db2_10 = ~u_page08_package__u_page08_outputs__n172b; // u_page08_package__u_page08_outputs__n172b
assign u_page08_package__u_page08_outputs__n173b = ~((u_page08_package__u_page08_outputs__p170b_y & pin_db3_in) | (u_page08_package__u_page08_outputs__p168a_y & pin_db11_in)); // p168b
assign u_page08_package__u_page08_outputs__db3_11 = ~u_page08_package__u_page08_outputs__n173b; // u_page08_package__u_page08_outputs__n173b
// End inlined jt054157_page08_left_source_rails u_left_source_rails

// Inlined jt054157_page08_db_pin_buffers u_db_pin_buffers
assign pin44_out = pin_db0_in; // n192a
assign pin45_out = pin_db1_in; // n212b
assign pin46_out = pin_db2_in; // n193b
assign pin47_out = pin_db3_in; // n192b
assign pin48_out = pin_db4_in; // m189a
assign pin49_out = pin_db5_in; // m213b
// End inlined jt054157_page08_db_pin_buffers u_db_pin_buffers

// Inlined jt054157_page08_top_mux_outputs u_top_mux_outputs
wire u_page08_package__u_top_mux_outputs__unused_n134b_y;
wire u_page08_package__u_top_mux_outputs__unused_m119b_y;
wire u_page08_package__u_top_mux_outputs__unused_n118b_y;
wire u_page08_package__u_top_mux_outputs__unused_n119b_y;
wire u_page08_package__u_top_mux_outputs__unused_n121b_y;
wire u_page08_package__u_top_mux_outputs__unused_n122b_y;
assign u_page08_package__u_top_mux_outputs__unused_n134b_y = ~g124a; // n134b
assign u_page08_package__u_top_mux_outputs__unused_m119b_y = ~reg4_d3_buf; // m119b
assign u_page08_package__u_top_mux_outputs__unused_n118b_y = u_page08_package__u_top_mux_outputs__unused_n134b_y ? u_page08_package__u_page08_outputs__n185b : u_page08_package__u_page08_outputs__n172b; // n127b, n118b
assign u_page08_package__u_top_mux_outputs__unused_n119b_y = u_page08_package__u_top_mux_outputs__unused_n134b_y ? u_page08_package__u_page08_outputs__n186b : u_page08_package__u_page08_outputs__n173b; // n125b, n119b
assign u_page08_package__u_top_mux_outputs__unused_n121b_y = u_page08_package__u_top_mux_outputs__unused_n134b_y ? u_page08_package__u_page08_outputs__n172b : u_page08_package__u_page08_outputs__p162b; // n132b, n121b
assign u_page08_package__u_top_mux_outputs__unused_n122b_y = u_page08_package__u_top_mux_outputs__unused_n134b_y ? u_page08_package__u_page08_outputs__n173b : u_page08_package__u_page08_outputs__p161a; // n130b, n122b
assign pin155_out = u_page08_package__u_top_mux_outputs__unused_m119b_y ? u_page08_package__u_page08_outputs__db4_12 : u_page08_package__u_top_mux_outputs__unused_n118b_y; // m117b, h27b
assign pin156_out = u_page08_package__u_top_mux_outputs__unused_m119b_y ? u_page08_package__u_page08_outputs__db5_13 : u_page08_package__u_top_mux_outputs__unused_n119b_y; // m108b, h26a
assign pin157_out = u_page08_package__u_top_mux_outputs__unused_m119b_y ? u_page08_package__u_page08_outputs__db6_14 : u_page08_package__u_top_mux_outputs__unused_n121b_y; // m114a, h26b
assign pin158_out = u_page08_package__u_top_mux_outputs__unused_m119b_y ? u_page08_package__u_page08_outputs__db7_15 : u_page08_package__u_top_mux_outputs__unused_n122b_y; // m112a, h25a
// End inlined jt054157_page08_top_mux_outputs u_top_mux_outputs
// Inlined jt054157_page08_reg4d4_upper_mux_outputs u_reg4d4_upper_mux_outputs
assign pin159_out = reg4_d4_buf ? u_page08_package__u_page08_outputs__l136b : u_page08_package__u_page08_outputs__p162b; // m140a, h25b
assign pin2_out = reg4_d4_buf ? u_page08_package__u_page08_outputs__l137b : u_page08_package__u_page08_outputs__p161a; // m138a, h29a
// End inlined jt054157_page08_reg4d4_upper_mux_outputs u_reg4d4_upper_mux_outputs
// Inlined jt054157_page08_reg4d3_mid_mux_outputs u_reg4d3_mid_mux_outputs
wire u_page08_package__u_reg4d3_mid_mux_outputs__unused_n174b_y;
wire u_page08_package__u_reg4d3_mid_mux_outputs__unused_n112a_y;
wire u_page08_package__u_reg4d3_mid_mux_outputs__unused_n157b_y;
wire u_page08_package__u_reg4d3_mid_mux_outputs__unused_n158b_y;
wire u_page08_package__u_reg4d3_mid_mux_outputs__unused_n138b_y;
wire u_page08_package__u_reg4d3_mid_mux_outputs__unused_n117b_y;
assign u_page08_package__u_reg4d3_mid_mux_outputs__unused_n174b_y = ~g124a; // n174b
assign u_page08_package__u_reg4d3_mid_mux_outputs__unused_n112a_y = ~reg4_d3_buf; // n112a
assign u_page08_package__u_reg4d3_mid_mux_outputs__unused_n157b_y = u_page08_package__u_reg4d3_mid_mux_outputs__unused_n174b_y ? pin_db0_in : pin_db4_in; // n170b, n157b
assign u_page08_package__u_reg4d3_mid_mux_outputs__unused_n158b_y = u_page08_package__u_reg4d3_mid_mux_outputs__unused_n174b_y ? pin_db1_in : pin_db5_in; // n168b, n158b
assign u_page08_package__u_reg4d3_mid_mux_outputs__unused_n138b_y = u_page08_package__u_reg4d3_mid_mux_outputs__unused_n174b_y ? pin_db2_in : pin_db6_in; // n164b, n138b
assign u_page08_package__u_reg4d3_mid_mux_outputs__unused_n117b_y = u_page08_package__u_reg4d3_mid_mux_outputs__unused_n174b_y ? pin_db3_in : pin_db7_in; // n166b, n117b
assign pin3_out = u_page08_package__u_reg4d3_mid_mux_outputs__unused_n112a_y ? u_page08_package__u_page08_outputs__db0_8 : u_page08_package__u_reg4d3_mid_mux_outputs__unused_n157b_y; // n118a, h28b
assign pin4_out = u_page08_package__u_reg4d3_mid_mux_outputs__unused_n112a_y ? u_page08_package__u_page08_outputs__db1_9 : u_page08_package__u_reg4d3_mid_mux_outputs__unused_n158b_y; // n116a, h27a
assign pin5_out = u_page08_package__u_reg4d3_mid_mux_outputs__unused_n112a_y ? u_page08_package__u_page08_outputs__db2_10 : u_page08_package__u_reg4d3_mid_mux_outputs__unused_n138b_y; // n121a, h29b
assign pin6_out = u_page08_package__u_reg4d3_mid_mux_outputs__unused_n112a_y ? u_page08_package__u_page08_outputs__db3_11 : u_page08_package__u_reg4d3_mid_mux_outputs__unused_n117b_y; // n108a, h28a
// End inlined jt054157_page08_reg4d3_mid_mux_outputs u_reg4d3_mid_mux_outputs
// Inlined jt054157_page08_reg4d4_mid_mux_outputs u_reg4d4_mid_mux_outputs
assign pin7_out = reg4_d4_buf ? u_page08_package__u_page08_outputs__n185b : pin_db4_in; // m143a, h40b
assign pin8_out = reg4_d4_buf ? u_page08_package__u_page08_outputs__n186b : pin_db5_in; // m139b, h40a
// End inlined jt054157_page08_reg4d4_mid_mux_outputs u_reg4d4_mid_mux_outputs
// Inlined jt054157_page08_reg4d3_lower_mid_mux_outputs u_reg4d3_lower_mid_mux_outputs
wire u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_n132a_y;
wire u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_m124b_y;
wire u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_n114a_y;
wire u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_n113a_y;
wire u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_n115a_y;
wire u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_m120b_y;
assign u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_n132a_y = ~g124a; // n132a
assign u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_m124b_y = u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_n132a_y ? u_page08_package__u_page08_outputs__n185b : u_page08_package__u_page08_outputs__l136b; // n133a, m124b
assign u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_n114a_y = u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_n132a_y ? u_page08_package__u_page08_outputs__n186b : u_page08_package__u_page08_outputs__l137b; // n126a, n114a
assign u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_n113a_y = u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_n132a_y ? u_page08_package__u_page08_outputs__n172b : pin_db0_in; // n130a, n113a
assign u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_n115a_y = u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_n132a_y ? u_page08_package__u_page08_outputs__n173b : pin_db1_in; // n128a, n115a
assign u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_m120b_y = ~reg4_d3_buf; // m120b
assign pin9_out = u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_m120b_y ? pin_db4_in : u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_m124b_y; // m121b, h41a
assign pin11_out = u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_m120b_y ? pin_db5_in : u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_n114a_y; // m115b, h48a
assign pin12_out = u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_m120b_y ? pin_db6_in : u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_n113a_y; // m110b, h67a
assign pin13_out = u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_m120b_y ? pin_db7_in : u_page08_package__u_reg4d3_lower_mid_mux_outputs__unused_n115a_y; // m112b, h76b
// End inlined jt054157_page08_reg4d3_lower_mid_mux_outputs u_reg4d3_lower_mid_mux_outputs
// Inlined jt054157_page08_reg4d4_lower_mid_mux_outputs u_reg4d4_lower_mid_mux_outputs
assign pin14_out = reg4_d4_buf ? pin_db2_in : u_page08_package__u_page08_outputs__p162b; // m149a, h77a
assign pin15_out = reg4_d4_buf ? pin_db1_in : u_page08_package__u_page08_outputs__p161a; // m147a, j94b
// End inlined jt054157_page08_reg4d4_lower_mid_mux_outputs u_reg4d4_lower_mid_mux_outputs
// Inlined jt054157_page08_reg4d3_lower_mux_outputs u_reg4d3_lower_mux_outputs
wire u_page08_package__u_reg4d3_lower_mux_outputs__unused_m134b_y;
assign u_page08_package__u_reg4d3_lower_mux_outputs__unused_m134b_y = ~g124a; // m134b
assign pin16_out = u_page08_package__u_reg4d3_lower_mux_outputs__unused_m134b_y ? pin_db0_in : u_page08_package__u_page08_outputs__db0_8; // m128b, j94a
assign pin17_out = u_page08_package__u_reg4d3_lower_mux_outputs__unused_m134b_y ? pin_db1_in : u_page08_package__u_page08_outputs__db1_9; // m126b, l84b
assign pin18_out = u_page08_package__u_reg4d3_lower_mux_outputs__unused_m134b_y ? pin_db2_in : u_page08_package__u_page08_outputs__db2_10; // m132b, l84a
assign pin19_out = u_page08_package__u_reg4d3_lower_mux_outputs__unused_m134b_y ? pin_db3_in : u_page08_package__u_page08_outputs__db3_11; // m130b, l107a
// End inlined jt054157_page08_reg4d3_lower_mux_outputs u_reg4d3_lower_mux_outputs
// Inlined jt054157_page08_reg4d4_lower_right_outputs u_reg4d4_lower_right_outputs
assign pin42_out = reg4_d4_buf ? u_page08_package__u_page08_outputs__n172b : u_page08_package__u_page08_outputs__p162b; // m154b, m161a
assign pin43_out = reg4_d4_buf ? u_page08_package__u_page08_outputs__n173b : u_page08_package__u_page08_outputs__p161a; // m152b, m162a
// End inlined jt054157_page08_reg4d4_lower_right_outputs u_reg4d4_lower_right_outputs
// Inlined jt054157_page08_reg4d4_right_mid_outputs u_reg4d4_right_mid_outputs
assign pin34_out = reg4_d4_buf ? pin_db0_in : pin_db4_in; // m179a, m189b
assign pin35_out = reg4_d4_buf ? pin_db1_in : pin_db5_in; // m163a, n185a
// End inlined jt054157_page08_reg4d4_right_mid_outputs u_reg4d4_right_mid_outputs
// Inlined jt054157_page08_reg4d3_right_mid_outputs u_reg4d3_right_mid_outputs
wire u_page08_package__u_reg4d3_right_mid_outputs__unused_n170a_y;
wire u_page08_package__u_reg4d3_right_mid_outputs__unused_n176a_y;
wire u_page08_package__u_reg4d3_right_mid_outputs__unused_n177a_y;
wire u_page08_package__u_reg4d3_right_mid_outputs__unused_n176b_y;
wire u_page08_package__u_reg4d3_right_mid_outputs__unused_n177b_y;
wire u_page08_package__u_reg4d3_right_mid_outputs__unused_n161a_y;
assign u_page08_package__u_reg4d3_right_mid_outputs__unused_n170a_y = ~g124a; // n170a
assign u_page08_package__u_reg4d3_right_mid_outputs__unused_n176a_y = u_page08_package__u_reg4d3_right_mid_outputs__unused_n170a_y ? u_page08_package__u_page08_outputs__n185b : pin_db6_in; // n171a, n176a
assign u_page08_package__u_reg4d3_right_mid_outputs__unused_n177a_y = u_page08_package__u_reg4d3_right_mid_outputs__unused_n170a_y ? u_page08_package__u_page08_outputs__n186b : pin_db7_in; // n173a, n177a
assign u_page08_package__u_reg4d3_right_mid_outputs__unused_n176b_y = u_page08_package__u_reg4d3_right_mid_outputs__unused_n170a_y ? u_page08_package__u_page08_outputs__n172b : u_page08_package__u_page08_outputs__n185b; // n167a, n176b
assign u_page08_package__u_reg4d3_right_mid_outputs__unused_n177b_y = u_page08_package__u_reg4d3_right_mid_outputs__unused_n170a_y ? u_page08_package__u_page08_outputs__n173b : u_page08_package__u_page08_outputs__n186b; // n165a, n177b
assign u_page08_package__u_reg4d3_right_mid_outputs__unused_n161a_y = ~reg4_d3_buf; // n161a
assign pin36_out = u_page08_package__u_reg4d3_right_mid_outputs__unused_n161a_y ? pin_db4_in : u_page08_package__u_reg4d3_right_mid_outputs__unused_n176a_y; // n179a, n188a
assign pin37_out = u_page08_package__u_reg4d3_right_mid_outputs__unused_n161a_y ? pin_db5_in : u_page08_package__u_reg4d3_right_mid_outputs__unused_n177a_y; // n181a, n189a
assign pin38_out = u_page08_package__u_reg4d3_right_mid_outputs__unused_n161a_y ? pin_db6_in : u_page08_package__u_reg4d3_right_mid_outputs__unused_n176b_y; // n181b, n188b
assign pin39_out = u_page08_package__u_reg4d3_right_mid_outputs__unused_n161a_y ? pin_db7_in : u_page08_package__u_reg4d3_right_mid_outputs__unused_n177b_y; // n183b, n189b
// End inlined jt054157_page08_reg4d3_right_mid_outputs u_reg4d3_right_mid_outputs
// Inlined jt054157_page08_top_right_pin21_pin26_outputs u_top_right_pin21_pin26_outputs
wire u_page08_package__u_top_right_pin21_pin26_outputs__unused_n136b_y;
wire u_page08_package__u_top_right_pin21_pin26_outputs__unused_n139a_y;
wire u_page08_package__u_top_right_pin21_pin26_outputs__unused_n141b_y;
wire u_page08_package__u_top_right_pin21_pin26_outputs__unused_n140b_y;
wire u_page08_package__u_top_right_pin21_pin26_outputs__unused_n139b_y;
wire u_page08_package__u_top_right_pin21_pin26_outputs__unused_n136a_y;
assign pin21_out = reg4_d4_buf ? pin_db4_in : u_page08_package__u_page08_outputs__p162b; // m149b, m133a
assign pin22_out = reg4_d4_buf ? pin_db5_in : u_page08_package__u_page08_outputs__p161a; // m147b, m134a
assign u_page08_package__u_top_right_pin21_pin26_outputs__unused_n136b_y = ~g124a; // n136b
assign u_page08_package__u_top_right_pin21_pin26_outputs__unused_n139a_y = u_page08_package__u_top_right_pin21_pin26_outputs__unused_n136b_y ? u_page08_package__u_page08_outputs__n185b : pin_db2_in; // n149b, n139a
assign u_page08_package__u_top_right_pin21_pin26_outputs__unused_n141b_y = u_page08_package__u_top_right_pin21_pin26_outputs__unused_n136b_y ? u_page08_package__u_page08_outputs__n186b : pin_db3_in; // n145b, n141b
assign u_page08_package__u_top_right_pin21_pin26_outputs__unused_n140b_y = u_page08_package__u_top_right_pin21_pin26_outputs__unused_n136b_y ? u_page08_package__u_page08_outputs__n172b : pin_db4_in; // n147b, n140b
assign u_page08_package__u_top_right_pin21_pin26_outputs__unused_n139b_y = u_page08_package__u_top_right_pin21_pin26_outputs__unused_n136b_y ? u_page08_package__u_page08_outputs__n173b : pin_db5_in; // n143b, n139b
assign u_page08_package__u_top_right_pin21_pin26_outputs__unused_n136a_y = ~reg4_d3_buf; // n136a
assign pin23_out = u_page08_package__u_top_right_pin21_pin26_outputs__unused_n136a_y ? u_page08_package__u_page08_outputs__db4_12 : u_page08_package__u_top_right_pin21_pin26_outputs__unused_n139a_y; // m141b, m137a
assign pin24_out = u_page08_package__u_top_right_pin21_pin26_outputs__unused_n136a_y ? u_page08_package__u_page08_outputs__db5_13 : u_page08_package__u_top_right_pin21_pin26_outputs__unused_n141b_y; // m143b, m136a
assign pin25_out = u_page08_package__u_top_right_pin21_pin26_outputs__unused_n136a_y ? u_page08_package__u_page08_outputs__db6_14 : u_page08_package__u_top_right_pin21_pin26_outputs__unused_n140b_y; // m136b, m142a
assign pin26_out = u_page08_package__u_top_right_pin21_pin26_outputs__unused_n136a_y ? u_page08_package__u_page08_outputs__db7_15 : u_page08_package__u_top_right_pin21_pin26_outputs__unused_n139b_y; // m145b, m158a
// End inlined jt054157_page08_top_right_pin21_pin26_outputs u_top_right_pin21_pin26_outputs
// Inlined jt054157_page08_reg4d4_right_upper_outputs u_reg4d4_right_upper_outputs
assign pin27_out = reg4_d4_buf ? pin_db6_in : u_page08_package__u_page08_outputs__p162b; // m157b, m157a
assign pin28_out = reg4_d4_buf ? pin_db7_in : u_page08_package__u_page08_outputs__p161a; // m159b, m160a
// End inlined jt054157_page08_reg4d4_right_upper_outputs u_reg4d4_right_upper_outputs
// Inlined jt054157_page08_reg4d3_right_upper_outputs u_reg4d3_right_upper_outputs
wire u_page08_package__u_reg4d3_right_upper_outputs__unused_n137a_y;
wire u_page08_package__u_reg4d3_right_upper_outputs__unused_n157a_y;
wire u_page08_package__u_reg4d3_right_upper_outputs__unused_n156a_y;
wire u_page08_package__u_reg4d3_right_upper_outputs__unused_n153b_y;
wire u_page08_package__u_reg4d3_right_upper_outputs__unused_n144a_y;
wire u_page08_package__u_reg4d3_right_upper_outputs__unused_n154b_y;
assign u_page08_package__u_reg4d3_right_upper_outputs__unused_n137a_y = ~g124a; // n137a
assign u_page08_package__u_reg4d3_right_upper_outputs__unused_n157a_y = ~reg4_d3_buf; // n157a
assign u_page08_package__u_reg4d3_right_upper_outputs__unused_n156a_y = u_page08_package__u_reg4d3_right_upper_outputs__unused_n137a_y ? pin_db0_in : u_page08_package__u_page08_outputs__p162b; // n149a, n156a
assign u_page08_package__u_reg4d3_right_upper_outputs__unused_n153b_y = u_page08_package__u_reg4d3_right_upper_outputs__unused_n137a_y ? pin_db1_in : u_page08_package__u_page08_outputs__p161a; // n147a, n153b
assign u_page08_package__u_reg4d3_right_upper_outputs__unused_n144a_y = u_page08_package__u_reg4d3_right_upper_outputs__unused_n137a_y ? pin_db2_in : u_page08_package__u_page08_outputs__l136b; // n140a, n144a
assign u_page08_package__u_reg4d3_right_upper_outputs__unused_n154b_y = u_page08_package__u_reg4d3_right_upper_outputs__unused_n137a_y ? pin_db3_in : u_page08_package__u_page08_outputs__l137b; // n145a, n154b
assign pin29_out = u_page08_package__u_reg4d3_right_upper_outputs__unused_n157a_y ? u_page08_package__u_page08_outputs__n185b : u_page08_package__u_reg4d3_right_upper_outputs__unused_n156a_y; // n158a, n160a
assign pin31_out = u_page08_package__u_reg4d3_right_upper_outputs__unused_n157a_y ? u_page08_package__u_page08_outputs__n186b : u_page08_package__u_reg4d3_right_upper_outputs__unused_n153b_y; // n160b, n169a
assign pin32_out = u_page08_package__u_reg4d3_right_upper_outputs__unused_n157a_y ? u_page08_package__u_page08_outputs__n172b : u_page08_package__u_reg4d3_right_upper_outputs__unused_n144a_y; // n154a, n162a
assign pin33_out = u_page08_package__u_reg4d3_right_upper_outputs__unused_n157a_y ? u_page08_package__u_page08_outputs__n173b : u_page08_package__u_reg4d3_right_upper_outputs__unused_n154b_y; // n155b, n162b
// End inlined jt054157_page08_reg4d3_right_upper_outputs u_reg4d3_right_upper_outputs
// End inlined jt054157_page08_outputs_integrated u_page08_outputs

// Inlined jt054157_page08_package_output_map u_page08_package_output_map
assign pin_002_out = pin2_out;
assign pin_003_out = pin3_out;
assign pin_004_out = pin4_out;
assign pin_005_out = pin5_out;
assign pin_006_out = pin6_out;
assign pin_007_out = pin7_out;
assign pin_008_out = pin8_out;
assign pin_009_out = pin9_out;
assign pin_011_out = pin11_out;
assign pin_012_out = pin12_out;
assign pin_013_out = pin13_out;
assign pin_014_out = pin14_out;
assign pin_015_out = pin15_out;
assign pin_016_out = pin16_out;
assign pin_017_out = pin17_out;
assign pin_018_out = pin18_out;
assign pin_019_out = pin19_out;
assign pin_021_out = pin21_out;
assign pin_022_out = pin22_out;
assign pin_023_out = pin23_out;
assign pin_024_out = pin24_out;
assign pin_025_out = pin25_out;
assign pin_026_out = pin26_out;
assign pin_027_out = pin27_out;
assign pin_028_out = pin28_out;
assign pin_029_out = pin29_out;
assign pin_031_out = pin31_out;
assign pin_032_out = pin32_out;
assign pin_033_out = pin33_out;
assign pin_034_out = pin34_out;
assign pin_035_out = pin35_out;
assign pin_036_out = pin36_out;
assign pin_037_out = pin37_out;
assign pin_038_out = pin38_out;
assign pin_039_out = pin39_out;
assign pin_042_out = pin42_out;
assign pin_043_out = pin43_out;
assign pin_044_out = pin44_out;
assign pin_045_out = pin45_out;
assign pin_046_out = pin46_out;
assign pin_047_out = pin47_out;
assign pin_048_out = pin48_out;
assign pin_049_out = pin49_out;
assign pin_155_out = pin155_out;
assign pin_156_out = pin156_out;
assign pin_157_out = pin157_out;
assign pin_158_out = pin158_out;
assign pin_159_out = pin159_out;

assign pin_002_oe = page08_pin_oe[0];
assign pin_003_oe = page08_pin_oe[1];
assign pin_004_oe = page08_pin_oe[2];
assign pin_005_oe = page08_pin_oe[3];
assign pin_006_oe = page08_pin_oe[4];
assign pin_007_oe = page08_pin_oe[5];
assign pin_008_oe = page08_pin_oe[6];
assign pin_009_oe = page08_pin_oe[7];
assign pin_011_oe = page08_pin_oe[8];
assign pin_012_oe = page08_pin_oe[9];
assign pin_013_oe = page08_pin_oe[10];
assign pin_014_oe = page08_pin_oe[11];
assign pin_015_oe = page08_pin_oe[12];
assign pin_016_oe = page08_pin_oe[13];
assign pin_017_oe = page08_pin_oe[14];
assign pin_018_oe = page08_pin_oe[15];
assign pin_019_oe = page08_pin_oe[16];
assign pin_021_oe = page08_pin_oe[17];
assign pin_022_oe = page08_pin_oe[18];
assign pin_023_oe = page08_pin_oe[19];
assign pin_024_oe = page08_pin_oe[20];
assign pin_025_oe = page08_pin_oe[21];
assign pin_026_oe = page08_pin_oe[22];
assign pin_027_oe = page08_pin_oe[23];
assign pin_028_oe = page08_pin_oe[24];
assign pin_029_oe = page08_pin_oe[25];
assign pin_031_oe = page08_pin_oe[26];
assign pin_032_oe = page08_pin_oe[27];
assign pin_033_oe = page08_pin_oe[28];
assign pin_034_oe = page08_pin_oe[29];
assign pin_035_oe = page08_pin_oe[30];
assign pin_036_oe = page08_pin_oe[31];
assign pin_037_oe = page08_pin_oe[32];
assign pin_038_oe = page08_pin_oe[33];
assign pin_039_oe = page08_pin_oe[34];
assign pin_042_oe = page08_pin_oe[35];
assign pin_043_oe = page08_pin_oe[36];
assign pin_044_oe = page08_pin_oe[37];
assign pin_045_oe = page08_pin_oe[38];
assign pin_046_oe = page08_pin_oe[39];
assign pin_047_oe = page08_pin_oe[40];
assign pin_048_oe = page08_pin_oe[41];
assign pin_049_oe = page08_pin_oe[42];
assign pin_155_oe = page08_pin_oe[43];
assign pin_156_oe = page08_pin_oe[44];
assign pin_157_oe = page08_pin_oe[45];
assign pin_158_oe = page08_pin_oe[46];
assign pin_159_oe = page08_pin_oe[47];
// End inlined jt054157_page08_package_output_map u_page08_package_output_map
// End inlined jt054157_page08_package_integrated u_page08_package

endmodule


// -----------------------------------------------------------------------------
// Source: artifacts/hdl/jt054157_package.v
// -----------------------------------------------------------------------------

// Stub package-facing wrapper for the 054157 extraction.
//
// This wrapper preserves the physical pin boundary from the pinout
// spreadsheet. Page-level logic is still under reconstruction.
module jt054157_package(
    inout  wire pin_002,
    inout  wire pin_003,
    inout  wire pin_004,
    inout  wire pin_005,
    inout  wire pin_006,
    inout  wire pin_007,
    inout  wire pin_008,
    inout  wire pin_009,
    inout  wire pin_011,
    inout  wire pin_012,
    inout  wire pin_013,
    inout  wire pin_014,
    inout  wire pin_015,
    inout  wire pin_016,
    inout  wire pin_017,
    inout  wire pin_018,
    inout  wire pin_019,
    inout  wire pin_021,
    inout  wire pin_022,
    inout  wire pin_023,
    inout  wire pin_024,
    inout  wire pin_025,
    inout  wire pin_026,
    inout  wire pin_027,
    inout  wire pin_028,
    inout  wire pin_029,
    inout  wire pin_031,
    inout  wire pin_032,
    inout  wire pin_033,
    inout  wire pin_034,
    inout  wire pin_035,
    inout  wire pin_036,
    inout  wire pin_037,
    inout  wire pin_038,
    inout  wire pin_039,
    inout  wire pin_042,
    inout  wire pin_043,
    inout  wire pin_044,
    inout  wire pin_045,
    inout  wire pin_046,
    inout  wire pin_047,
    inout  wire pin_048,
    inout  wire pin_049,
    output wire pin_051,
    output wire pin_052,
    output wire pin_053,
    output wire pin_054,
    output wire pin_055,
    output wire pin_056,
    output wire pin_057,
    output wire pin_058,
    input  wire pin_061,
    input  wire pin_062,
    input  wire pin_063,
    input  wire pin_064,
    input  wire pin_065,
    input  wire pin_066,
    input  wire pin_067,
    input  wire pin_068,
    input  wire pin_069,
    input  wire pin_071,
    input  wire pin_072,
    input  wire pin_073,
    input  wire pin_074,
    input  wire pin_075,
    inout  wire pin_076,
    inout  wire pin_077,
    inout  wire pin_078,
    inout  wire pin_079,
    inout  wire pin_082,
    inout  wire pin_083,
    inout  wire pin_084,
    inout  wire pin_085,
    inout  wire pin_086,
    inout  wire pin_087,
    inout  wire pin_088,
    inout  wire pin_089,
    inout  wire pin_091,
    inout  wire pin_092,
    inout  wire pin_093,
    inout  wire pin_094,
    input  wire pin_095,
    input  wire pin_096,
    input  wire pin_097,
    input  wire pin_098,
    input  wire pin_099,
    output wire pin_101,
    output wire pin_102,
    output wire pin_103,
    output wire pin_104,
    output wire pin_105,
    output wire pin_106,
    output wire pin_107,
    output wire pin_108,
    input  wire pin_109,
    input  wire pin_111,
    input  wire pin_112,
    input  wire pin_113,
    output wire pin_114,
    output wire pin_115,
    output wire pin_116,
    output wire pin_117,
    output wire pin_118,
    output wire pin_119,
    output wire pin_122,
    output wire pin_123,
    output wire pin_124,
    output wire pin_125,
    output wire pin_126,
    output wire pin_127,
    output wire pin_128,
    output wire pin_129,
    output wire pin_131,
    output wire pin_132,
    output wire pin_133,
    output wire pin_134,
    output wire pin_135,
    output wire pin_136,
    output wire pin_137,
    output wire pin_138,
    output wire pin_141,
    output wire pin_142,
    output wire pin_143,
    output wire pin_144,
    output wire pin_145,
    output wire pin_146,
    output wire pin_147,
    output wire pin_148,
    output wire pin_149,
    output wire pin_151,
    output wire pin_152,
    output wire pin_153,
    output wire pin_154,
    inout  wire pin_155,
    inout  wire pin_156,
    inout  wire pin_157,
    inout  wire pin_158,
    inout  wire pin_159
);
// Page-level 054157 logic is not connected here yet. Keep the physical
// package boundary explicit while making the stub behavior direct:
// bidirectional pins float and output-only pins drive zero.
assign pin_002 = 1'bz;
assign pin_003 = 1'bz;
assign pin_004 = 1'bz;
assign pin_005 = 1'bz;
assign pin_006 = 1'bz;
assign pin_007 = 1'bz;
assign pin_008 = 1'bz;
assign pin_009 = 1'bz;
assign pin_011 = 1'bz;
assign pin_012 = 1'bz;
assign pin_013 = 1'bz;
assign pin_014 = 1'bz;
assign pin_015 = 1'bz;
assign pin_016 = 1'bz;
assign pin_017 = 1'bz;
assign pin_018 = 1'bz;
assign pin_019 = 1'bz;
assign pin_021 = 1'bz;
assign pin_022 = 1'bz;
assign pin_023 = 1'bz;
assign pin_024 = 1'bz;
assign pin_025 = 1'bz;
assign pin_026 = 1'bz;
assign pin_027 = 1'bz;
assign pin_028 = 1'bz;
assign pin_029 = 1'bz;
assign pin_031 = 1'bz;
assign pin_032 = 1'bz;
assign pin_033 = 1'bz;
assign pin_034 = 1'bz;
assign pin_035 = 1'bz;
assign pin_036 = 1'bz;
assign pin_037 = 1'bz;
assign pin_038 = 1'bz;
assign pin_039 = 1'bz;
assign pin_042 = 1'bz;
assign pin_043 = 1'bz;
assign pin_044 = 1'bz;
assign pin_045 = 1'bz;
assign pin_046 = 1'bz;
assign pin_047 = 1'bz;
assign pin_048 = 1'bz;
assign pin_049 = 1'bz;
assign pin_051 = 1'b0;
assign pin_052 = 1'b0;
assign pin_053 = 1'b0;
assign pin_054 = 1'b0;
assign pin_055 = 1'b0;
assign pin_056 = 1'b0;
assign pin_057 = 1'b0;
assign pin_058 = 1'b0;
assign pin_076 = 1'bz;
assign pin_077 = 1'bz;
assign pin_078 = 1'bz;
assign pin_079 = 1'bz;
assign pin_082 = 1'bz;
assign pin_083 = 1'bz;
assign pin_084 = 1'bz;
assign pin_085 = 1'bz;
assign pin_086 = 1'bz;
assign pin_087 = 1'bz;
assign pin_088 = 1'bz;
assign pin_089 = 1'bz;
assign pin_091 = 1'bz;
assign pin_092 = 1'bz;
assign pin_093 = 1'bz;
assign pin_094 = 1'bz;
assign pin_101 = 1'b0;
assign pin_102 = 1'b0;
assign pin_103 = 1'b0;
assign pin_104 = 1'b0;
assign pin_105 = 1'b0;
assign pin_106 = 1'b0;
assign pin_107 = 1'b0;
assign pin_108 = 1'b0;
assign pin_114 = 1'b0;
assign pin_115 = 1'b0;
assign pin_116 = 1'b0;
assign pin_117 = 1'b0;
assign pin_118 = 1'b0;
assign pin_119 = 1'b0;
assign pin_122 = 1'b0;
assign pin_123 = 1'b0;
assign pin_124 = 1'b0;
assign pin_125 = 1'b0;
assign pin_126 = 1'b0;
assign pin_127 = 1'b0;
assign pin_128 = 1'b0;
assign pin_129 = 1'b0;
assign pin_131 = 1'b0;
assign pin_132 = 1'b0;
assign pin_133 = 1'b0;
assign pin_134 = 1'b0;
assign pin_135 = 1'b0;
assign pin_136 = 1'b0;
assign pin_137 = 1'b0;
assign pin_138 = 1'b0;
assign pin_141 = 1'b0;
assign pin_142 = 1'b0;
assign pin_143 = 1'b0;
assign pin_144 = 1'b0;
assign pin_145 = 1'b0;
assign pin_146 = 1'b0;
assign pin_147 = 1'b0;
assign pin_148 = 1'b0;
assign pin_149 = 1'b0;
assign pin_151 = 1'b0;
assign pin_152 = 1'b0;
assign pin_153 = 1'b0;
assign pin_154 = 1'b0;
assign pin_155 = 1'bz;
assign pin_156 = 1'bz;
assign pin_157 = 1'bz;
assign pin_158 = 1'bz;
assign pin_159 = 1'bz;

endmodule

