`timescale 1ns/1ps

module test;

reg         clk = 0, rst = 1, vb = 0, initeo = 0;
reg  [ 1:0] cab_1p = 2'b11;
reg         coin = 1, service = 1, dip_pause = 1;
reg  [ 5:0] joystick1 = 6'h3f, joystick2 = 6'h3f;
reg  [ 1:0] board = 0;
wire        tpp1rom = board==2'd1 || board==2'd3,
            boot    = board==2'd2,
            tpp1ram = board==2'd1 || board==2'd2,
            tnx1    = board==2'd3;
reg         use_prot = 0;
reg  [ 7:0] blprot_data = 0;
reg  [ 7:0] blrom[0:255];
reg  [ 7:0] blcopy[0:29];
reg  [ 7:0] bl_exp[0:63];
reg  [ 7:0] romtest[0:1];
wire [ 7:0] blprot_addr, prot_q, prot_mux;
reg         busrq_n = 1, dma_cs = 0;
reg  [10:0] dma_addr = 0;
reg  [ 7:0] ay_dout = 8'ha5, prot_dout = 8'h00;
reg  [ 7:0] decb[0:32767];
reg  [ 7:0] rom[0:32767];
reg  [15:0] map[0:65535];
reg  [ 7:0] dec[0:32767];
reg  [ 7:0] main_data = 0;
reg         main_ok = 0;
reg  [14:0] last_addr = 0;
reg  [ 5:0] sd_cnt = 0, sd_lat = 5;
reg         skip_on = 0, zap_on = 0;
reg  [15:0] skip_pc = 0, zap_pc = 0;
integer     skips = 0, zaps = 0;
reg  [ 7:0] wmem[0:65535];
wire        cpu_cen, psg_cen, reset_n, busak_n, csv, csbw_n, dwrbk_n, memwr0, bdir, bc1,
            prot_cs, prot_we, prot_addr, main_cs, busy;
wire [12:0] ad;
wire [ 7:0] dd, cpu_dout;
wire [14:0] main_addr;
wire [15:0] fave, fworst, fave2, fworst2;

integer nmi_vb = -1, dma_vb = -1;
integer errors = 0, i, k, vbcnt = 0, nmicnt = 0, boots = 0, txtw = 0, openrd = 0;
integer vb_hi = 2000, vb_lo = 18000;
reg     vb_run = 0, eo_run = 1;

always #10.417 clk = ~clk;

assign busy = main_cs & ~main_ok;

jtframe_gated_cen #(.W(1),.NUM(1),.DEN(12),.MFREQ(48000)) u_cen(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .busy   ( busy      ),
    .cen    ( cpu_cen   ),
    .fave   ( fave      ),
    .fworst ( fworst    )
);

always @(posedge clk) begin
    last_addr <= main_addr;
    if( !main_cs || main_addr != last_addr ) begin
        sd_cnt  <= 0;
        main_ok <= 0;
        sd_lat  <= $urandom_range(40,5);
    end else begin
        if( sd_cnt != 6'h3f ) sd_cnt <= sd_cnt + 6'd1;
        if( sd_cnt == sd_lat - 6'd1 ) begin
            main_data <= (skip_on && (uut.A==skip_pc+16'd1 || uut.A==skip_pc+16'd2)) ? 8'hff :
                         (zap_on && uut.A==zap_pc+16'd1) ? 8'h00 : rom[main_addr];
            main_ok   <= 1;
        end
    end
end

jtframe_gated_cen #(.W(1),.NUM(1),.DEN(24),.MFREQ(48000)) u_psgcen(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .busy   ( 1'b0      ),
    .cen    ( psg_cen   ),
    .fave   ( fave2     ),
    .fworst ( fworst2   )
);

reg        dma_run = 0;
integer    dma_done = 0, n;
reg vb_l2 = 0;
always @(posedge clk) if( dma_run && vb && !vb_l2 ) begin
    busrq_n <= 0;
end
always @(posedge clk) vb_l2 <= vb;
always begin
    wait( dma_run && !busak_n );
    for( n=0; n<1024; n=n+1 ) begin
        dma_addr = { 1'b1, n[9:0] };
        dma_cs   = 1;
        repeat(4) @(posedge clk);
    end
    dma_cs   = 0;
    busrq_n  = 1;
    dma_done = dma_done + 1;
    wait( busak_n );
end

integer ncsbw = 0, ndwrbk = 0, nbgw = 0, dwr_err = 0, phi_min = 99, phi_gap = 0;
reg     bgw_pend = 0, csbw_l = 1, dwrbk_l = 1, bgwr_l = 1;
always @(posedge clk) begin
    csbw_l  <= csbw_n;
    dwrbk_l <= dwrbk_n;
    bgwr_l  <= uut.wr_n;
    if( uut.phi_cen ) begin
        if( phi_gap < phi_min && !rst && reset_n ) phi_min = phi_gap;
        phi_gap = 1;
    end else phi_gap = phi_gap + 1;
    if( !uut.wr_n && bgwr_l && !uut.mreq_n && uut.csb ) begin
        if( bgw_pend && (ncsbw!=1 || ndwrbk!=1) ) dwr_err = dwr_err + 1;
        bgw_pend = 1;
        nbgw   = nbgw + 1;
        ncsbw  = 0;
        ndwrbk = 0;
    end
    if( !csbw_n && csbw_l ) ncsbw = ncsbw + 1;
    if( !dwrbk_n && dwrbk_l ) ndwrbk = ndwrbk + 1;
end

jtpopeye_main uut(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .psg_cen    ( psg_cen   ),
    .vb         ( vb        ),
    .initeo     ( initeo    ),
    .tpp1rom    ( tpp1rom   ),
    .boot       ( boot      ),
    .tpp1ram    ( tpp1ram   ),
    .tnx1       ( tnx1      ),
    .reset_n    ( reset_n   ),
    .cab_1p     ( cab_1p    ),
    .coin       ( coin      ),
    .service    ( service   ),
    .dip_pause  ( dip_pause ),
    .joystick1  ( joystick1 ),
    .joystick2  ( joystick2 ),
    .busrq_n    ( busrq_n   ),
    .busak_n    ( busak_n   ),
    .dma_cs     ( dma_cs    ),
    .dma_addr   ( dma_addr  ),
    .ad         ( ad        ),
    .dd         ( dd        ),
    .cpu_dout   ( cpu_dout  ),
    .csv        ( csv       ),
    .csbw_n     ( csbw_n    ),
    .dwrbk_n    ( dwrbk_n   ),
    .memwr0     ( memwr0    ),
    .bdir       ( bdir      ),
    .bc1        ( bc1       ),
    .ay_dout    ( ay_dout   ),
    .prot_cs    ( prot_cs   ),
    .prot_we    ( prot_we   ),
    .prot_addr  ( prot_addr ),
    .prot_dout  ( prot_mux  ),
    .blprot_addr( blprot_addr ),
    .blprot_data( blprot_data ),
    .main_cs    ( main_cs   ),
    .main_addr  ( main_addr ),
    .main_data  ( main_data ),
    .main_ok    ( main_ok   )
);

assign prot_mux = use_prot ? prot_q : prot_dout;

jtpopeye_prot u_prot(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .reset_n    ( reset_n   ),
    .cs         ( prot_cs   ),
    .we         ( prot_we   ),
    .addr       ( prot_addr ),
    .din        ( cpu_dout  ),
    .dout       ( prot_q    )
);

always @(posedge clk) blprot_data <= blrom[blprot_addr];

task fail(input [8*64-1:0] msg); begin
    errors = errors + 1;
    $display("FAIL: %0s", msg);
end endtask

always begin
    wait(vb_run);
    vb = 0;
    repeat(vb_lo) @(posedge clk);
    vb = 1;
    vbcnt = vbcnt + 1;
    if( eo_run ) initeo = ~initeo;
    repeat(vb_hi) @(posedge clk);
end

reg nmi_l = 1, rstn_l = 0, wr_l = 1, rd_l = 1, trace = 0;
reg seen[0:65535];
integer ntr = 0;
initial for( i=0; i<65536; i=i+1 ) seen[i] = 0;
always @(posedge clk) if( trace && ntr<400 ) begin
    rd_l <= uut.rd_n;
    if( !uut.u_cpu.m1_n && !uut.rd_n && rd_l && !seen[uut.A] ) begin
        seen[uut.A] = 1;
        $display("  M1 %04X  t=%0d vb=%0d", uut.A, $time/1000, vbcnt);
        ntr = ntr + 1;
    end
    if( !uut.iorq_n && !uut.rd_n && rd_l ) begin $display("  IN  %02X -> %02X", uut.A[7:0], uut.din); ntr = ntr + 1; end
    if( !uut.iorq_n && !uut.wr_n && wr_l ) begin $display("  OUT %02X <- %02X", uut.A[7:0], uut.cpu_dout); ntr = ntr + 1; end
    if( !uut.mreq_n && !uut.rd_n && rd_l && uut.u_cpu.m1_n && uut.A[15] ) begin $display("  RD  %04X -> %02X", uut.A, uut.din); ntr = ntr + 1; end
end
reg [15:0] fetch_l = 16'hffff;
always @(posedge clk) begin
    nmi_l  <= uut.nmi_n;
    rstn_l <= reset_n;
    wr_l   <= uut.wr_n;
    if( !uut.nmi_n && nmi_l ) begin
        if( nmicnt==0 ) nmi_vb = vbcnt;
        nmicnt = nmicnt + 1;
    end
    if( !busak_n && dma_run && dma_vb<0 ) dma_vb = vbcnt;
    if( reset_n && !uut.u_cpu.m1_n && uut.A==16'h0000 && fetch_l!=16'h0000 ) boots = boots + 1;
    if( reset_n && !uut.u_cpu.m1_n ) fetch_l <= uut.A;
    if( !uut.wr_n && wr_l && !uut.mreq_n ) wmem[uut.A] = uut.cpu_dout;
end

task load_prog(input [8*16-1:0] fname); begin
    rst = 1;
    vb_run = 0;
    vb = 0;
    $readmemh(fname, rom);
    for( k=0; k<65536; k=k+1 ) wmem[k] = 8'hxx;
    repeat(50) @(posedge clk);
    fetch_l = 16'hffff;
    rst = 0;
    nmicnt = 0;
    boots  = 0;
    vbcnt  = 0;
end endtask

reg  [15:0] a_l = 0, a_rd = 0;
reg  [ 7:0] din_l = 0, din_rd = 0;
reg         rdn_l = 1, mreq_l = 1, m1_l = 1, mon = 0;
reg  [15:0] m1_last = 16'hffff;
reg  [ 7:0] rdram[0:4095];
reg         rdram_v[0:4095];
reg  [15:0] m1seq[0:7], nmiseq[0:3];
integer     vb_seen = 0, verbose = 0, blst = 0, blsterr = 0, hang_rep = 1, nm1 = 0, nnmi = -1, romrd = 0, romerr = 0, blrd = 0, blerr = 0, protn = 0,
            romtest_ok = 0, ramtest_ok = 0, ramtest_bad = 0, romtest_bad = 0, boot_ok = 0, boot_bad = 0;
reg  [15:0] ramok_pc, ramhang_pc, romok_pc, romhang_pc, bootok_pc, bootbad_pc;

always @(posedge clk) begin
    din_l  <= uut.din;
    a_l    <= uut.A;
    rdn_l  <= uut.rd_n;
    mreq_l <= uut.mreq_n;
    m1_l   <= uut.u_cpu.m1_n;
end

always @(posedge clk) if( mon && reset_n ) begin
    if( prot_cs ) protn = protn + 1;
    if( uut.rd_n && !rdn_l && !mreq_l ) begin
        if( skip_on && (a_l==skip_pc+16'd1 || a_l==skip_pc+16'd2) ) begin
            if( a_l==skip_pc+16'd2 ) skip_on = 0;
        end else if( zap_on && a_l==zap_pc+16'd1 ) begin
            zap_on = 0;
        end else if( !a_l[15] ) begin
            romrd = romrd + 1;
            if( din_l !== decb[a_l[14:0]] ) begin
                if( romerr < 8 ) $display("    ROM read A=%04X CPU saw %02X, spec %02X (M1=%0d)", a_l, din_l, decb[a_l[14:0]], ~m1_l);
                romerr = romerr + 1;
            end
        end
        if( a_l[15:12]==4'h8 ) begin
            rdram[a_l[11:0]]   = din_l;
            rdram_v[a_l[11:0]] = 1;
        end
        if( board==2'd2 && a_l[15:5]==11'h700 && m1_l && !(m1_last>=16'he000 && m1_last<16'he01e) ) begin
            blst = blst + 1;
            if( din_l[2] !== 1'b0 ) blsterr = blsterr + 1;
        end else if( board==2'd2 && a_l>=16'he000 && a_l<16'he01e ) begin
            blrd = blrd + 1;
            if( din_l !== blcopy[a_l[4:0]] ) begin
                if( blerr < 8 ) $display("    blprot read A=%04X M1=%0d CPU saw %02X, ROM copy at 58CD+ has %02X", a_l, ~m1_l, din_l, blcopy[a_l[4:0]]);
                blerr = blerr + 1;
            end
        end
        if( !m1_l ) begin
            if( nm1 < 8 ) m1seq[nm1] = a_l;
            nm1 = nm1 + 1;
            if( a_l==16'h0066 && nnmi<0 ) nnmi = 0;
            if( skip_pc!=0 && a_l==skip_pc ) begin skip_on = 1; skips = skips + 1; end
            if( zap_pc!=0 && a_l==zap_pc ) begin zap_on = 1; zaps = zaps + 1; end
            if( nnmi>=0 && nnmi<4 ) begin nmiseq[nnmi] = a_l; nnmi = nnmi + 1; end
            if( a_l==ramok_pc   ) ramtest_ok  = ramtest_ok  + 1;
            if( a_l==ramhang_pc && (hang_rep==0 || m1_last==a_l) ) ramtest_bad = ramtest_bad + 1;
            if( a_l==romok_pc   ) romtest_ok  = romtest_ok  + 1;
            if( a_l==romhang_pc && m1_last==a_l ) romtest_bad = romtest_bad + 1;
            if( a_l==bootok_pc  ) boot_ok     = boot_ok     + 1;
            if( a_l==bootbad_pc ) boot_bad    = boot_bad    + 1;
            m1_last = a_l;
        end
    end
end

task mon_start; begin
    for( k=0; k<4096; k=k+1 ) rdram_v[k] = 0;
    nm1 = 0; nnmi = -1; skips = 0; skip_on = 0; zaps = 0; zap_on = 0; blst = 0; blsterr = 0; m1_last = 16'hffff; romrd = 0; romerr = 0; blrd = 0; blerr = 0; protn = 0;
    romtest_ok = 0; ramtest_ok = 0; ramtest_bad = 0; romtest_bad = 0; boot_ok = 0; boot_bad = 0;
    mon = 1;
end endtask

task load_board(input [1:0] bd); begin
    board = bd;
    case( bd )
        2'd1: begin $readmemh("dec1.hex", decb); $readmemh("rom1.hex", rom); end
        2'd2: begin $readmemh("dec2.hex", decb); $readmemh("rom2.hex", rom); end
        2'd3: begin $readmemh("dec3.hex", decb); $readmemh("rom3.hex", rom); end
        default: begin $readmemh("dec.hex", decb); $readmemh("rom.hex", rom); end
    endcase
end endtask

task check_reset_seq(input [1:0] bd); begin
    $display("    first M1 fetches: %04X %04X %04X %04X %04X", m1seq[0], m1seq[1], m1seq[2], m1seq[3], m1seq[4]);
    if( bd==2'd3 ) begin
        if( m1seq[0]!==16'h0000 || m1seq[1]!==16'h0003 || m1seq[2]!==16'h0005 || m1seq[3]!==16'h0006 || m1seq[4]!==16'h0007 )
            fail("reset fetch sequence (expect 0000 0003 0005 0006 0007)");
    end else begin
        if( m1seq[0]!==16'h0000 || m1seq[1]!==16'h0002 || m1seq[2]!==16'h0003 || m1seq[3]!==16'h0004 || m1seq[4]!==16'h1b09 )
            fail("reset fetch sequence (expect 0000 0002 0003 0004 1B09)");
    end
end endtask

task check_nmi_seq; begin
    if( nnmi < 4 ) begin
        fail("no NMI fetch at 0066");
    end else begin
        $display("    NMI fetches: %04X %04X %04X %04X", nmiseq[0], nmiseq[1], nmiseq[2], nmiseq[3]);
        if( nmiseq[1]!==16'h0067 || nmiseq[2]!==16'h0069 || nmiseq[3]!==16'h006a )
            fail("NMI fetch sequence (expect 0066 0067 0069 006A)");
    end
end endtask

task run_game(input [1:0] bd, input svc, input integer maxvb); begin
    service = ~svc;
    load_board(bd);
    load_prog(bd==2'd1 ? "rom1.hex" : bd==2'd2 ? "rom2.hex" : bd==2'd3 ? "rom3.hex" : "rom.hex");
    use_prot = 1;
    mon_start;
    vb_hi = 99000;
    vb_lo = 781759 - 99000;
    vb_run = 1;
    txtw = 0;
    dma_run = 1;
    dma_done = 0;
    while( vbcnt < maxvb && (svc ? (ramtest_ok==0 && ramtest_bad==0) || (romok_pc!=0 && romtest_ok==0 && romtest_bad==0)
                                 : (txtw < 16 || nmicnt < 3 || dma_done < 3)) ) begin
        @(posedge clk);
        if( csv && memwr0 && !uut.wr_n && wr_l ) txtw = txtw + 1;
        if( vbcnt != vb_seen ) begin
            vb_seen = vbcnt;
            if( verbose ) begin $display("      VB %0d last M1 %04X", vbcnt, m1_last); $fflush; end
        end
    end
    repeat(20000) @(posedge clk);
    $display("    boots=%0d NMIs=%0d VB edges=%0d DMA transfers=%0d text writes=%0d prot accesses (clk)=%0d",
        boots, nmicnt, vbcnt, dma_done, txtw, protn);
    $display("    ROM reads checked=%0d, differ from the spec decrypt=%0d", romrd, romerr);
    if( skip_pc!=0 ) $display("    bench time skip: LD HL,E88B at %04X read as LD HL,FFFF %0d time(s) (5 s delay loop)", skip_pc, skips);
    if( zap_pc!=0 ) $display("    bench time skip: LD A,80 at %04X read as LD A,00 %0d time(s) (128-frame wait before the ROM test)", zap_pc, zaps);
    if( romerr != 0 || romrd < 1000 ) fail("ROM data seen by the CPU");
    if( boots != 1 ) fail("unexpected reset");
    check_reset_seq(bd);
    vb_run = 0;
    dma_run = 0;
    use_prot = 0;
    service = 1;
    mon = 0;
end endtask

reg [15:0] ad_full;
integer    part = -1, rexp, rbad, rsel, ncase, nset;
integer    nmi_at, rlow_at[0:7], rhigh_at[0:7], nl, nh, w_csb, w_dwr, w_csbw, w_csv, ndwr;

initial begin
    $readmemh("map.hex", map);
    $readmemh("dec.hex", dec);
    $readmemh("rom.hex", rom);

    $readmemh("blprot.hex", blrom);
    $readmemh("blcopy.hex", blcopy);
    $readmemh("bl_exp.hex", bl_exp);
    $readmemh("romtest.hex", romtest);
    $readmemh("dec.hex", decb);
    if( !$value$plusargs("part=%d", part) ) part = -1;
    if( $test$plusargs("verbose") ) verbose = 1;
    if( $test$plusargs("only_d") ) begin
        trace = 1;
        $readmemh("rom.hex", rom);
        load_prog("rom.hex");
        vb_hi = 99000;
        vb_lo = 781759 - 99000;
        vb_run = 1;
        while( vbcnt < 2 ) @(posedge clk);
        $finish;
    end
    if( part<0 || part==0 ) begin
    $display("(a) AD mapping vs JT 2020 jtpopeye_main unscramble, 65536 addresses");
    rst = 1;
    repeat(4) @(posedge clk);
    k = 0;
    for( i=0; i<65536; i=i+1 ) begin
        force uut.A = i[15:0];
        #1;
        ad_full = { uut.ad_hi, uut.ad };
        if( ad_full !== map[i] ) begin
            if( k<8 ) $display("   A=%04X AD=%04X JT2020=%04X", i[15:0], ad_full, map[i]);
            k = k + 1;
        end
        release uut.A;
    end
    if( k!=0 ) fail("(a) address mapping differs"); else $display("    PASS: all 65536 match");

    $display("(b) ROM data path vs JT 2020 jtpopeye_main rom_good, 32768 bytes of popeyeu");
    k = 0;
    for( i=0; i<32768; i=i+1 ) begin
        force uut.A = i[15:0];
        #1;
        force uut.main_data = rom[uut.main_addr];
        #1;
        if( uut.rom_dd !== dec[i] ) begin
            if( k<8 ) $display("   A=%04X DUT=%02X JT2020=%02X", i[15:0], uut.rom_dd, dec[i]);
            k = k + 1;
        end
        release uut.main_data;
        release uut.A;
    end
    if( k!=0 ) fail("(b) data swap differs"); else $display("    PASS: all 32768 match");
    $write("    decrypted 0000-000F:");
    for( i=0; i<16; i=i+1 ) $write(" %02X", dec[i]);
    $display("");

    $display("(c1) NMI: I=1 enables, handler toggles I=0/I=1, disables after 3 NMIs");
    load_prog("c_nmi.hex");
    vb_run = 1;
    nmi_at = -1;
    while( vbcnt < 1 ) @(posedge clk);
    for( k=0; k<20 && uut.nmi_n; k=k+1 ) @(posedge clk);
    nmi_at = k;
    $display("    nmi_n fell %0d clk after the first VB rise", nmi_at);
    if( nmi_at > 3 ) fail("(c1) NMI not at VB rise");
    while( vbcnt < 6 ) @(posedge clk);
    $display("    VB edges=%0d NMI edges=%0d count in RAM=%02X nmi_n=%b q3kr=%b", vbcnt, nmicnt, wmem[16'h8800], uut.nmi_n, uut.q3kr);
    if( nmicnt != 3 || wmem[16'h8800] !== 8'h03 ) fail("(c1) expected 3 NMIs");
    if( uut.q3kr !== 1'b0 || uut.nmi_n !== 1'b1 ) fail("(c1) NMI should end disabled");
    $display("    boots=%0d", boots);
    if( boots != 1 ) fail("(c1) unexpected reset");

    $display("(c1b) dip_pause=0 blocks the NMI");
    load_prog("c_nmi.hex");
    dip_pause = 0;
    vb_run = 1;
    while( vbcnt < 3 ) @(posedge clk);
    $display("    VB edges=%0d NMI edges=%0d", vbcnt, nmicnt);
    if( nmicnt != 0 ) fail("(c1b) NMI during pause");
    dip_pause = 1;
    while( vbcnt < 4 ) @(posedge clk);
    repeat(5000) @(posedge clk);
    if( nmicnt != 1 ) fail("(c1b) NMI after pause");

    $display("(c2) watchdog: I=2 (NMI off, watchdog on)");
    load_prog("c_wd.hex");
    vb_run = 1;
    nl = 0; nh = 0;
    while( !reset_n ) @(posedge clk);
    while( vbcnt < 26 ) begin
        @(posedge clk);
        if( !reset_n && rstn_l && nl<8 ) begin rlow_at[nl]  = vbcnt; nl = nl + 1; end
        if( reset_n && !rstn_l && nh<8 ) begin rhigh_at[nh] = vbcnt; nh = nh + 1; end
    end
    $write("    reset asserted at VB edge:");  for( k=0; k<nl; k=k+1 ) $write(" %0d", rlow_at[k]);  $display("");
    $write("    reset released at VB edge:");  for( k=0; k<nh; k=k+1 ) $write(" %0d", rhigh_at[k]); $display("");
    $display("    boots=%0d", boots);
    if( nl<3 || rlow_at[0]!=4 || rhigh_at[0]!=8 || rlow_at[1]!=12 || rhigh_at[1]!=16 || rlow_at[2]!=20 )
        fail("(c2) watchdog timing");

    $display("(c3) I=3 (NMI on): watchdog held clear, one NMI (handler only RETN)");
    load_prog("c_wdnmi.hex");
    vb_run = 1;
    nl = 0;
    while( vbcnt < 12 ) begin
        @(posedge clk);
        if( !reset_n && rstn_l ) nl = nl + 1;
    end
    $display("    resets=%0d NMI edges=%0d cnt2l=%0d", nl, nmicnt, uut.cnt2l);
    if( nl!=0 || nmicnt!=1 ) fail("(c3)");

    $display("(c4) I=0: no watchdog, no NMI; I/O, AY, video strobes, DMA read");
    joystick1 = 6'b101110;
    joystick2 = 6'b110101;
    cab_1p    = 2'b10;
    service   = 0;
    load_prog("c_io.hex");
    eo_run = 0;
    initeo = 1;
    vb_run = 1;
    w_csb = 0; w_dwr = 0; w_csbw = 0; w_csv = 0; ndwr = 0;
    while( wmem[16'h880f] !== 8'hc3 && vbcnt < 40 ) begin
        @(posedge clk);
        if( uut.csb ) w_csb = w_csb + 1;
        if( !csbw_n ) w_csbw = w_csbw + 1;
        if( !dwrbk_n ) begin
            w_dwr = w_dwr + 1;
            if( dd !== 8'h99 || ad[12] !== 1'b0 ) fail("(c4) DWRBK data/address");
        end
        if( csv & memwr0 ) begin
            w_csv = w_csv + 1;
            if( dd !== 8'h66 ) fail("(c4) CSV data");
        end
        if( bdir && bc1 && cpu_dout!==8'h07 ) fail("(c4) AY latch");
        if( bdir && !bc1 && cpu_dout!==8'h3c ) fail("(c4) AY write");
        if( prot_cs && prot_we && (prot_addr!==1'b0 || cpu_dout!==8'h77) ) fail("(c4) prot write");
    end
    if( wmem[16'h880f] !== 8'hc3 ) fail("(c4) program did not finish");
    $display("    port0=%02X port1=%02X port2=%02X port3=%02X prot=%02X",
        wmem[16'h8800], wmem[16'h8801], wmem[16'h8802], wmem[16'h8803], wmem[16'h8804]);
    if( wmem[16'h8800] !== 8'h11 ) fail("(c4) port 0 (2P main joystick)");
    if( wmem[16'h8801] !== 8'h06 ) fail("(c4) port 1 (4M sub joystick)");
    if( wmem[16'h8802] !== 8'h54 ) fail("(c4) port 2 (3P system)");
    if( wmem[16'h8803] !== 8'ha5 ) fail("(c4) port 3 (AY read)");
    if( wmem[16'h8804] !== 8'h00 ) fail("(c4) prot read");
    $display("    clk widths: CSB=%0d CSBW=%0d DWRBK=%0d CSV&MEMWR0=%0d (expect DWRBK=CSB-1, CSBW=CSB+1)", w_csb, w_csbw, w_dwr, w_csv);
    if( w_dwr != w_csb-1 || w_dwr < 1 ) fail("(c4) DWRBK width");
    if( w_csbw != w_csb + 1 ) fail("(c4) CSBW width");
    if( w_csv == 0 ) fail("(c4) no CSV write");

    dma_cs = 1;
    k = 0;
    for( i=0; i<2000; i=i+1 ) begin
        @(posedge clk);
        if( uut.ram_cs && !(uut.memrq && uut.sel8) ) k = k + 1;
    end
    dma_cs = 0;
    $display("    dma_cs high without BUSAK for 2000 clk: ram_cs high %0d clk", k);
    if( k!=0 ) fail("(c4) dma_cs must be gated by BUSAK");
    busrq_n = 0;
    while( busak_n ) @(posedge clk);
    k = 0;
    for( i=0; i<256; i=i+1 ) begin
        ad_full = map[16'h8c00+i];
        if( ad_full[10] !== 1'b1 ) fail("(c4) DMA AD10");
        dma_addr = ad_full[10:0];
        dma_cs   = 1;
        repeat(2) @(posedge clk);
        if( dd !== (i[7:0]^8'h5a) ) k = k + 1;
    end
    dma_cs  = 0;
    busrq_n = 1;
    $display("    DMA read of 8C00-8CFF through dma_addr: %0d mismatches", k);
    if( k!=0 ) fail("(c4) DMA read");
    joystick1 = 6'h3f; joystick2 = 6'h3f; cab_1p = 2'b11; service = 1; eo_run = 1;

    $display("(c5) coin one-shot");
    load_prog("c_wdnmi.hex");
    vb_run = 0;
    repeat(200) @(posedge clk);
    coin = 0;
    k = 0;
    while( uut.u_cab.coin_cnt == 0 ) @(posedge clk);
    while( uut.u_cab.coin_cnt != 0 ) begin
        @(posedge clk);
        if( psg_cen ) k = k + 1;
        if( k == 200 ) coin = 1;
    end
    $display("    DD7 high for %0d psg_cen = %0.1f ms at 2 MHz", k, k/2000.0);
    if( k < 188795 || k > 188805 ) fail("(c5) coin pulse length");

    $display("(d) popeyeu program, real ROM, field = 781759 clk, VB = 99000 clk");
    $readmemh("rom.hex", rom);
    load_prog("rom.hex");
    vb_hi = 99000;
    vb_lo = 781759 - 99000;
    vb_run = 1;
    txtw = 0;
    openrd = 0;
    dma_run = 1;
    dma_done = 0;
    while( (txtw < 16 || nmicnt < 3 || dma_done < 3) && vbcnt < 40 ) begin
        @(posedge clk);
        if( csv && memwr0 && !uut.wr_n && wr_l ) begin
            if( txtw < 16 ) $display("    text write #%0d: A=%04X data=%02X  (VB edges %0d, NMIs %0d)", txtw, uut.A, cpu_dout, vbcnt, nmicnt);
            txtw = txtw + 1;
        end
        if( !uut.rd_n && !uut.mreq_n && uut.rfsh_n && uut.din===8'hff && uut.ad_hi[15] && !uut.ram_cs && !uut.prot_cs && openrd<4 ) begin
            $display("    open-bus read at %04X", uut.A);
            openrd = openrd + 1;
        end
    end
    $display("    boots=%0d NMIs=%0d VB edges=%0d", boots, nmicnt, vbcnt);
    $display("    first NMI at VB edge %0d, first BUSAK at VB edge %0d, DMA transfers=%0d", nmi_vb, dma_vb, dma_done);
    if( txtw < 16 ) fail("(d) no text RAM writes");
    if( nmicnt < 3 ) fail("(d) game did not enable NMI");
    if( bgw_pend && (ncsbw!=1 || ndwrbk!=1) ) dwr_err = dwr_err + 1;
    $display("    C000-DFFF writes=%0d, writes without exactly one CSBW and one DWRBK=%0d, min phi_cen spacing=%0d clk", nbgw, dwr_err, phi_min);
    if( dwr_err != 0 || phi_min < 2 ) fail("(d) DWRBK/CSBW per write");
    end

    if( part<0 || part==1 ) begin
    $display("(e) ROM data path per board vs the spec decrypt, 32768 addresses each");
    for( nset=1; nset<4; nset=nset+1 ) begin
        load_board(nset[1:0]);
        rst = 1;
        repeat(4) @(posedge clk);
        rst = 0;
        repeat(4) @(posedge clk);
        k = 0;
        for( i=0; i<32768; i=i+1 ) begin
            force uut.A = i[15:0];
            #1;
            force uut.main_data = rom[uut.main_addr];
            #1;
            if( uut.rom_dd !== decb[i] ) begin
                if( k<8 ) $display("   board %0d A=%04X DUT=%02X spec=%02X", nset, i[15:0], uut.rom_dd, decb[i]);
                k = k + 1;
            end
            release uut.main_data;
            release uut.A;
        end
        $display("    board %0d: %0d mismatches; 0000-0007 =%02X %02X %02X %02X %02X %02X %02X %02X", nset, k,
            decb[0], decb[1], decb[2], decb[3], decb[4], decb[5], decb[6], decb[7]);
        if( k!=0 ) fail("(e) ROM data path");
    end
    board = 0;
    end

    if( part<0 || part==2 ) begin
    $display("(f) work RAM select and DMA read per board (write every 13th byte of 8000-8FFF, read back, DMA 8C00-8CFF)");
    for( nset=0; nset<4; nset=nset+1 ) begin
        load_board(nset[1:0]);
        case( nset )
            0: load_prog("c_ram0.hex");
            1: load_prog("c_ram1.hex");
            2: load_prog("c_ram2.hex");
            default: load_prog("c_ram3.hex");
        endcase
        $readmemh("p_ram.hex", decb);
        mon_start;
        while( !(rdram_v[4095]===1'b1) ) @(posedge clk);
        repeat(100) @(posedge clk);
        mon = 0;
        rbad = 0; rsel = 0;
        for( i=0; i<4096; i=i+13 ) begin
            case( nset )
                0: rexp = i>=12'h800;
                3: rexp = i<12'h800 || i>=12'hc00;
                default: rexp = i<12'h400 || i>=12'hc00;
            endcase
            rsel = rsel + rexp;
            if( rexp ) rexp = ((i>>8)+128) ^ (i&255) ^ 8'h5a; else rexp = 8'hff;
            if( rdram_v[i]!==1'b1 || rdram[i]!==rexp[7:0] ) begin
                if( rbad<4 ) $display("    board %0d %04X read %02X expected %02X", nset, i+16'h8000, rdram[i], rexp[7:0]);
                rbad = rbad + 1;
            end
        end
        busrq_n = 0;
        while( busak_n ) @(posedge clk);
        k = 0;
        for( i=0; i<256; i=i+1 ) begin
            ad_full  = map[16'h8c00+i];
            dma_addr = ad_full[10:0];
            dma_cs   = 1;
            repeat(2) @(posedge clk);
            if( ((i+12'hc00)%13)==0 && dd !== ((8'h8c ^ i[7:0]) ^ 8'h5a) ) k = k + 1;
        end
        dma_cs  = 0;
        busrq_n = 1;
        $display("    board %0d: %0d bytes are RAM, %0d read-back mismatches, DMA 8C00-8CFF mismatches %0d", nset, rsel, rbad, k);
        if( rbad!=0 ) fail("(f) RAM select");
        if( k!=0 ) fail("(f) DMA read");
    end
    board = 0;
    end

    if( part<0 || part==3 ) begin
    $display("(g) bootleg: CALL E000 into the blprot PROMs vs the 7K formula");
    board = 2;
    $readmemh("c_bl.hex", decb);
    load_prog("c_bl.hex");
    mon_start;
    ncase = bl_exp[0];
    while( wmem[16'h8080] === 8'hxx && boots < 2 ) @(posedge clk);
    repeat(100) @(posedge clk);
    mon = 0;
    k = 0;
    for( i=0; i<ncase; i=i+1 ) begin
        if( wmem[16'h8000+i] !== bl_exp[i+1] ) begin
            if( k<8 ) $display("    case %0d: CPU got %02X, 7K formula %02X", i, wmem[16'h8000+i], bl_exp[i+1]);
            k = k + 1;
        end
    end
    $display("    %0d calls, %0d results differ; %0d reads of E000-E01D, %0d differ from the ROM copy at 58CD; prot_cs high %0d clk",
        ncase, k, blrd, blerr, protn);
    $display("    data read of E001 = %02X (bit 2 must be 0); status reads %0d, with bit 2 set %0d", wmem[16'h8080], blst, blsterr);
    if( k!=0 || ncase<20 ) fail("(g) bootleg shifter results");
    if( blerr!=0 || blrd < ncase*20 ) fail("(g) blprot bytes");
    if( protn!=0 ) fail("(g) prot_cs must stay low on the bootleg");
    if( wmem[16'h8080][2] !== 1'b0 || blst!=1 || blsterr!=0 ) fail("(g) E001 status bit 2");
    board = 0;
    end

    if( part<0 || part==4 ) begin
    $display("(h1) popeyej (board 1) boot: reset/NMI vectors, ROM checksum, attract");
    bootok_pc = 16'h1b20; bootbad_pc = 16'h7470; ramok_pc = 0; ramhang_pc = 0; romok_pc = 0; romhang_pc = 0;
    run_game(2'd1, 0, 40);
    check_nmi_seq;
    $display("    boot ROM checksum: reached 1B20 %0d times, 7470 %0d times", boot_ok, boot_bad);
    if( boot_ok==0 || boot_bad!=0 ) fail("(h1) boot ROM checksum");
    if( txtw < 16 || nmicnt < 3 || dma_done < 3 ) fail("(h1) game did not run");
    end

    if( part<0 || part==5 ) begin
    $display("(h2) popeyej (board 1) service mode: the game's own RAM test (8000, 8C00) and ROM test");
    bootok_pc = 0; bootbad_pc = 0; ramok_pc = 16'h74f4; ramhang_pc = 16'h74f2; romok_pc = 16'h753f; romhang_pc = 16'h753d;
    skip_pc = 16'h74b1;
    zap_pc  = 16'h7501;
    run_game(2'd1, 1, 80);
    skip_pc = 0;
    zap_pc  = 0;
    $display("    RAM test: pass point 74F4 %0d, hang 74F2 %0d; ROM test: pass point 753F %0d, hang 753D %0d (gen.py predicts %0d bad chips)",
        ramtest_ok, ramtest_bad, romtest_ok, romtest_bad, romtest[0]);
    if( ramtest_ok==0 || ramtest_bad!=0 ) fail("(h2) RAM test");
    if( romtest_ok==0 || romtest_bad!=0 || romtest[0]!=0 ) fail("(h2) ROM test");
    end

    if( part<0 || part==6 ) begin
    $display("(h3) popeyebl (board 2) boot: reset/NMI vectors, attract with the blprot shifter");
    bootok_pc = 16'h1b20; bootbad_pc = 16'h7470; ramok_pc = 0; ramhang_pc = 0; romok_pc = 0; romhang_pc = 0;
    run_game(2'd2, 0, 40);
    check_nmi_seq;
    $display("    reached 1B20 %0d times, 7470 %0d times; prot_cs high %0d clk", boot_ok, boot_bad, protn);
    $display("    blprot: %0d routine reads, %0d differ from the ROM copy at 58CD; E0xx status reads %0d, with bit 2 set %0d", blrd, blerr, blst, blsterr);
    if( blerr!=0 || blsterr!=0 ) fail("(h3) blprot reads");
    if( boot_ok==0 || boot_bad!=0 ) fail("(h3) boot");
    if( protn!=0 ) fail("(h3) prot_cs on the bootleg");
    if( txtw < 16 || nmicnt < 3 || dma_done < 3 ) fail("(h3) game did not run");
    end

    if( part<0 || part==7 ) begin
    $display("(h4) popeyebl (board 2) service mode: RAM test (8000, 8C00); ROM test outcome as gen.py predicts");
    bootok_pc = 0; bootbad_pc = 0; ramok_pc = 16'h74f4; ramhang_pc = 16'h74f2; romok_pc = 16'h753f; romhang_pc = 16'h753d;
    skip_pc = 16'h74b1;
    zap_pc  = 16'h7501;
    run_game(2'd2, 1, 80);
    skip_pc = 0;
    zap_pc  = 0;
    $display("    RAM test: pass point 74F4 %0d, hang 74F2 %0d; ROM test: pass point 753F %0d, hang 753D %0d (gen.py predicts %0d bad chips)",
        ramtest_ok, ramtest_bad, romtest_ok, romtest_bad, romtest[1]);
    if( ramtest_ok==0 || ramtest_bad!=0 ) fail("(h4) RAM test");
    if( (romtest[1]==0) ? (romtest_ok==0 || romtest_bad!=0) : (romtest_ok!=0 || romtest_bad==0) ) fail("(h4) ROM test outcome");
    end

    if( part<0 || part==8 ) begin
    $display("(h5) skyskipr (board 3) boot: reset/NMI vectors, attract");
    bootok_pc = 16'h0022; bootbad_pc = 16'h4109; ramok_pc = 0; ramhang_pc = 0; romok_pc = 0; romhang_pc = 0;
    run_game(2'd3, 0, 40);
    check_nmi_seq;
    $display("    reached 0022 %0d times, 4109 %0d times", boot_ok, boot_bad);
    if( boot_ok==0 || boot_bad!=0 ) fail("(h5) boot");
    if( txtw < 16 || nmicnt < 3 || dma_done < 3 ) fail("(h5) game did not run");
    end

    if( part<0 || part==9 ) begin
    $display("(h6) skyskipr (board 3) service mode: the game's own RAM test (8000, 8400, 8C00)");
    bootok_pc = 0; bootbad_pc = 0; ramok_pc = 16'h419e; ramhang_pc = 16'h4193; romok_pc = 0; romhang_pc = 0; hang_rep = 0;
    skip_pc = 16'h4144;
    run_game(2'd3, 1, 80);
    skip_pc = 0;
    $display("    RAM test: pass point 419E %0d, error print 4193 %0d", ramtest_ok, ramtest_bad);
    if( ramtest_ok==0 || ramtest_bad!=0 ) fail("(h6) RAM test");
    end

    if( errors==0 ) $display("PASS"); else $display("FAIL (%0d errors)", errors);
    $finish;
end

endmodule
