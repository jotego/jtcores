/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Boot bench for the Wardner main CPU. Runs the real program ROM with the DSP
 * subsystem attached and logs what the Z80 does to the outside world, so the
 * boot sequence can be read off rather than guessed at.
 *
 * The clocks keep the board's ratios exactly: the main Z80 runs from a 24 MHz
 * crystal divided by four, everything else from a 14 MHz crystal, so 6 and 14
 * MHz are enables 7 and 3 apart, and 7 and 3.5 MHz are 6 and 12 apart. Those
 * dividers describe a 42 MHz reference, but the clock below is 100 MHz, so the
 * whole board runs 100/42 = 2.381 times faster than the real one. Every ratio
 * is preserved, so the game behaves identically - only the time axis is
 * compressed, which is why this bench can reach attract mode at all. Divide a
 * bench millisecond by 0.42 to get board time; the milestones printed at the
 * end of a run give both.
 */
`timescale 1ns/1ps

module tb_main;

reg         clk = 0, rst = 1;
reg  [3:0]  c6 = 0, c14 = 0, cpx = 0;
reg  [3:0]  c35 = 0;
reg         cen6 = 0, cen14 = 0, cen_pxl = 0, cen3p5 = 0;

// ---- raster: 446 x 286 at 7 MHz, which is 54.878 Hz
reg [8:0] hcnt = 0, vcnt = 0;
reg       LVBL = 1;

wire [17:0] rom_addr;
reg  [ 7:0] rom_data;
wire        rom_cs;

wire        dsp_on, dsp_halt;
wire [12:0] dsp_addr;
wire [ 1:0] dsp_sel;
wire [15:0] dsp_dout, dsp_din;
wire        dsp_we;
wire [11:0] drom_addr;
reg  [15:0] drom_data;

wire        dbg_iowr, dbg_iord, dbg_m1;
// sound subsystem
wire [14:0] srom_addr;
reg  [ 7:0] srom_data;
wire        srom_cs;
wire [10:0] shr_addr;
wire [ 7:0] shr_dout, shr_din;
wire        shr_we;
wire signed [15:0] snd;
wire        snd_sample, s_fmwr, s_fmaddr, s_m1;
wire [ 7:0] s_fmdata;
wire [15:0] s_pc;
integer     nfm = 0, fmlog, nkeyon = 0, nsamp = 0, npk = 0;
reg  [ 7:0] fmreg = 0;              // last YM3812 register address written
integer     pk = 0;                 // largest |snd| seen
time        keyon_t = 0;            // when the first note was keyed on
integer     wavf = 0;               // raw 16-bit sample capture
wire [ 7:0] dbg_port, dbg_data;
wire [15:0] dbg_pc_addr;

reg  [ 7:0] rom[0:262143];
reg  [15:0] drom[0:4095];
reg  [ 7:0] srom[0:32767];
integer     fh, nio = 0, maxio;
reg         seen_poke = 0, seen_video = 0, seen_irq = 0;
reg  [31:0] joy1v, sysv, dswav, dswbv;
// ---- video state, for the snapshot
wire [15:0] tx_scrx, tx_scry, bg_scrx, bg_scry, fg_scrx, fg_scry;
wire        flip, bg_bank, fg_bank, video_on;
reg  [10:0] tx_vaddr = 0, pal_vaddr = 0, obj_vaddr = 0;
reg  [12:0] bg_vaddr = 0;
reg  [11:0] fg_vaddr = 0;
wire [15:0] tx_vq, bg_vq, fg_vq, pal_vq, obj_vq;
reg         freeze = 0;
// Snapshot targets. +snap= takes a comma separated list of bench milliseconds,
// so one boot can leave several snapshots behind instead of one boot each.
reg [511:0] snapstr;
integer     snapn = 0;
integer     snapms_l[0:15];
reg  [63:0] runtime;
reg [255:0] mainf, dspf, sndf;

initial begin
    if( !$value$plusargs("main=%s", mainf) ) mainf = "main.hex";
    if( !$value$plusargs("dsp=%s",  dspf)  ) dspf  = "dsp_real.hex";
    if( !$value$plusargs("snd=%s",  sndf)  ) sndf  = "snd.hex";
    if( !$value$plusargs("maxio=%d", maxio) ) maxio = 4000;
    if( !$value$plusargs("fmlog=%d", fmlog) ) fmlog = 400;
    if( $test$plusargs("wav") ) wavf = $fopen("snd.raw", "wb");
    if( !$value$plusargs("joy1=%d", joy1v) ) joy1v = 0;
    if( !$value$plusargs("sys=%d",  sysv)  ) sysv  = 0;
    if( !$value$plusargs("dswa=%d", dswav) ) dswav = 0;
    if( !$value$plusargs("dswb=%d", dswbv) ) dswbv = 0;
    if( !$value$plusargs("snap=%s", snapstr) ) snapstr = 0;
    parse_snaps;
    if( !$value$plusargs("runms=%d", runtime) ) runtime = 3000;
    if( !$value$plusargs("pcsample=%d", pcsample) ) pcsample = 0;
    $readmemh( mainf, rom );
    $readmemh( dspf,  drom );
    $readmemh( sndf,  srom );
    fh = $fopen("boot.log", "w");
    #200 rst = 0;
end

always #5 clk = ~clk;   // 100 MHz: the 42 MHz reference run 2.381x fast

always @(posedge clk) begin
    cen6  <= 0; cen14 <= 0; cen_pxl <= 0; cen3p5 <= 0;
    c6  <= c6  == 4'd6  ? 0 : c6  + 1'd1;  if( c6  == 4'd6  ) cen6    <= 1;
    c14 <= c14 == 4'd2  ? 0 : c14 + 1'd1;  if( c14 == 4'd2  ) cen14   <= 1;
    cpx <= cpx == 4'd5  ? 0 : cpx + 1'd1;  if( cpx == 4'd5  ) cen_pxl <= 1;   // 42/6  = 7 MHz pixel
    c35 <= c35 == 4'd11 ? 0 : c35 + 1'd1;  if( c35 == 4'd11 ) cen3p5  <= 1;   // 42/12 = 3.5 MHz
end

always @(posedge clk) if( cen_pxl ) begin
    if( hcnt == 9'd445 ) begin
        hcnt <= 0;
        vcnt <= vcnt == 9'd285 ? 9'd0 : vcnt + 1'd1;
        LVBL <= (vcnt + 1'd1) < 9'd240;
    end else hcnt <= hcnt + 1'd1;
end

// ---- memories. The program ROM answers in one clock; the DSP's follows its
//      own clock enable, and freezes with it when the run bit is low.
always @(posedge clk) rom_data <= rom[rom_addr];
always @(posedge clk) srom_data <= srom[srom_addr];
always @(posedge clk) if( cen14 && dsp_on ) drom_data <= drom[drom_addr];

// ---- log every port access, and stop at the first poke of the DSP run bit.
//      The strobes stay high for the whole bus cycle, so they are edged here.
reg iowr_l = 0, iord_l = 0, m1_l = 0;
// Sample the program counter periodically so long stalls can be attributed to
// a place in the code rather than guessed at.
reg [31:0] m1cnt = 0, pcsample;
always @(posedge clk) begin
    m1_l <= dbg_m1;
    if( !rst && dbg_m1 && !m1_l ) begin
        m1cnt <= m1cnt + 1;
        if( pcsample != 0 && (m1cnt % pcsample) == 0 )
            $fdisplay(fh, "%08t  PC ~%04x  (M1 #%0d)", $time, dbg_pc_addr, m1cnt);
    end
end
always @(posedge clk) begin
    iowr_l <= dbg_iowr;
    iord_l <= dbg_iord;
    if( !rst && dbg_iowr && !iowr_l ) begin
        $fdisplay(fh, "%08t  OUT %02x,%02x", $time, dbg_port, dbg_data);
        nio <= nio + 1;
        // mainlatch bit 6 turns the display on: the game only does that once
        // it is through its power-on tests
        if( dbg_port == 8'h5c && dbg_data[3:1] == 3'd6 && dbg_data[0] && !seen_video ) begin
            seen_video <= 1;
            $display("tb_main: display enabled at %0t ms  (POST complete)", $time/1000000000);
        end
        // mainlatch bit 2 enables the vertical blanking interrupt
        if( dbg_port == 8'h5c && dbg_data[3:1] == 3'd2 && dbg_data[0] && !seen_irq ) begin
            seen_irq <= 1;
            $display("tb_main: vblank interrupt enabled at %0t ms", $time/1000000000);
        end
        if( dbg_port == 8'h5a && dbg_data[3:1] == 3'd0 && dbg_data[0] ) begin
            if( !seen_poke ) begin
                $fdisplay(fh, "--- DSP run bit set: the Z80 has handed over ---");
                $display("tb_main: DSP handshake reached after %0d port writes, t=%0t",
                         nio, $time);
                seen_poke <= 1;
            end
        end
    end
    if( !rst && dbg_iord && !iord_l && dbg_port != 8'h58 )
        $fdisplay(fh, "%08t  IN  %02x", $time, dbg_port);
    if( nio > maxio ) finish_run("port write limit");
end

// work RAM now lives in mem.yaml, so the bench supplies it
wire [10:0] sh_addr;
wire [15:0] sh_din, work_dout;
wire [ 1:0] work_bwe;

wire [ 1:0] obj_bwe, pal_bwe, tx_bwe, bg_bwe, fg_bwe;
wire [15:0] objram_dout, pal_dout, txram_dout, bgram_dout, fgram_dout, cpu16;
wire [ 7:0] main_dout, shared_dout;
wire [10:0] mshr_addr, tx_a;
wire [12:0] bg_a;
wire [11:0] fg_a;
wire        mshr_we;

jtframe_dual_ram16 #(.AW(11)) u_work(
    .clk0(clk), .addr0(sh_addr), .data0(sh_din), .we0(work_bwe), .q0(work_dout),
    .clk1(clk), .addr1(11'd0  ), .data1(16'd0 ), .we1(2'd0    ), .q1()         );
jtframe_dual_ram16 #(.AW(11)) u_objram(
    .clk0(clk), .addr0(sh_addr),   .data0(sh_din), .we0(obj_bwe), .q0(objram_dout),
    .clk1(clk), .addr1(obj_vaddr), .data1(16'd0 ), .we1(2'd0   ), .q1(obj_vq)     );
jtframe_dual_ram16 #(.AW(11)) u_pal(
    .clk0(clk), .addr0(sh_addr),   .data0(sh_din), .we0(pal_bwe), .q0(pal_dout),
    .clk1(clk), .addr1(pal_vaddr), .data1(16'd0 ), .we1(2'd0   ), .q1(pal_vq)  );
jtframe_dual_ram #(.AW(11),.DW(8)) u_shared(
    .clk0(clk), .addr0(mshr_addr), .data0(main_dout), .we0(mshr_we), .q0(shared_dout),
    .clk1(clk), .addr1(shr_addr),  .data1(shr_dout),  .we1(shr_we),  .q1(shr_din)    );
jtframe_dual_ram16 #(.AW(11)) u_txram(
    .clk0(clk), .addr0(tx_a),     .data0(cpu16), .we0(tx_bwe), .q0(txram_dout),
    .clk1(clk), .addr1(tx_vaddr), .data1(16'd0), .we1(2'd0  ), .q1(tx_vq)      );
jtframe_dual_ram16 #(.AW(13)) u_bgram(
    .clk0(clk), .addr0(bg_a),     .data0(cpu16), .we0(bg_bwe), .q0(bgram_dout),
    .clk1(clk), .addr1(bg_vaddr), .data1(16'd0), .we1(2'd0  ), .q1(bg_vq)      );
jtframe_dual_ram16 #(.AW(12)) u_fgram(
    .clk0(clk), .addr0(fg_a),     .data0(cpu16), .we0(fg_bwe), .q0(fgram_dout),
    .clk1(clk), .addr1(fg_vaddr), .data1(16'd0), .we1(2'd0  ), .q1(fg_vq)      );

jtwardner_main u_main(
    .rst(rst), .clk(clk), .cen6(cen6), .LVBL(LVBL),
    .rom_addr(rom_addr), .rom_data(rom_data), .rom_cs(rom_cs), .rom_ok(1'b1),
    .dsp_on(dsp_on), .dsp_halt(dsp_halt | freeze), .dsp_addr(dsp_addr),
    .dsp_sel(dsp_sel), .dsp_dout(dsp_dout), .dsp_din(dsp_din), .dsp_we(dsp_we),
    .sh_addr(sh_addr), .sh_din(sh_din), .work_bwe(work_bwe), .work_dout(work_dout),
    .obj_bwe(obj_bwe), .pal_bwe(pal_bwe),
    .objram_dout(objram_dout), .pal_dout(pal_dout),
    .mshr_addr(mshr_addr), .mshr_we(mshr_we), .shared_dout(shared_dout),
    .cpu16(cpu16), .cpu_dout(main_dout),
    .tx_a(tx_a), .bg_a(bg_a), .fg_a(fg_a),
    .tx_bwe(tx_bwe), .bg_bwe(bg_bwe), .fg_bwe(fg_bwe),
    .txram_dout(txram_dout), .bgram_dout(bgram_dout), .fgram_dout(fgram_dout),
    .tx_scrx(tx_scrx), .tx_scry(tx_scry), .bg_scrx(bg_scrx), .bg_scry(bg_scry),
    .fg_scrx(fg_scrx), .fg_scry(fg_scry),
    .flip(flip), .bg_bank(bg_bank), .fg_bank(fg_bank), .video_on(video_on),
    .dipsw_a(dswav[7:0]), .dipsw_b(dswbv[7:0]), .joy1(joy1v[7:0]), .joy2(8'h00),
    .cab_sys(sysv[7:0]),
    .dbg_iowr(dbg_iowr), .dbg_iord(dbg_iord), .dbg_port(dbg_port),
    .dbg_data(dbg_data), .dbg_pc_addr(dbg_pc_addr), .dbg_m1(dbg_m1)
);

jtwardner_sound u_snd(
    .rst(rst), .clk(clk), .cen3p5(cen3p5),
    .rom_addr(srom_addr), .rom_data(srom_data), .rom_cs(srom_cs), .rom_ok(1'b1),
    .shr_addr(shr_addr), .shr_dout(shr_dout), .shr_din(shr_din), .shr_we(shr_we),
    .snd(snd), .sample(snd_sample),
    .dbg_fmwr(s_fmwr), .dbg_fmdata(s_fmdata), .dbg_fmaddr(s_fmaddr),
    .dbg_pc_addr(s_pc), .dbg_m1(s_m1)
);

// Log the sound CPU's writes to the YM3812, and watch for a note being keyed
// on. The chip takes a register address on port 0 then its value on port 1, so
// the address has to be remembered to know what a data byte means. Registers
// B0-B8 hold block and F-number for the nine channels, and bit 5 is that
// channel's key-on: it is the one write that makes the chip audible at all.
reg s_fmwr_l = 0;
always @(posedge clk) begin
    s_fmwr_l <= s_fmwr;
    if( !rst && s_fmwr && !s_fmwr_l ) begin
        nfm <= nfm + 1;
        if( nfm < fmlog )
            $fdisplay(fh, "%08t  FM  %s=%02x", $time, s_fmaddr ? "data" : "reg ", s_fmdata);
        if( !s_fmaddr ) fmreg <= s_fmdata;
        if( s_fmaddr && fmreg >= 8'hb0 && fmreg <= 8'hb8 && s_fmdata[5] ) begin
            if( nkeyon == 0 ) begin
                keyon_t = $time;
                $display("tb_main: first key-on at %0d bench ms (%0d ms of board time), reg %02x = %02x",
                         $time/1000000, ($time/1000000)*100/42, fmreg, s_fmdata);
            end
            nkeyon <= nkeyon + 1;
        end
    end
end

// Listen to the mixed output. jtopl2's `sample` is the slot counter passing
// zero, so it is a level held for a whole operator period, not a pulse: it has
// to be edged or every clock inside that period counts as another sample. One
// edge is one output sample. The file is raw signed 16-bit little endian and
// the rate is measured at the end rather than assumed.
reg snd_sample_l = 0;
always @(posedge clk) begin
    snd_sample_l <= snd_sample;
    if( !rst && snd_sample && !snd_sample_l ) begin
        nsamp <= nsamp + 1;
        if( snd != 0 ) npk <= npk + 1;
        if( (snd < 0 ? -snd : snd) > pk ) pk <= snd < 0 ? -snd : snd;
        if( wavf != 0 ) $fwrite(wavf, "%c%c", snd[7:0], snd[15:8]);
    end
end

probe u_probe();

jttoaplan1_dsp u_dsp(
    .rst(rst), .clk(clk), .cen(cen14),
    .dsp_on(dsp_on), .halt_main(dsp_halt),
    .host_addr(dsp_addr), .host_sel(dsp_sel), .host_dout(dsp_dout),
    .host_din(dsp_din), .host_we(dsp_we),
    .rom_addr(drom_addr), .rom_data(drom_data),
    .dbg_bio(), .dbg_exec(), .dbg_rd(), .dbg_wr(), .dbg_p0(), .dbg_p3(),
    .dbg_pdout(), .dbg_pwr(), .dbg_sel_new(), .dbg_addr_new()
);

task finish_run(input [255:0] why);
begin
    $fclose(fh);
    $display("tb_main: stopped at %0d bench ms = %0d ms of board time (%0s) after %0d port writes",
             $time/1000000, ($time/1000000)*100/42, why, nio);
    $display("  DSP handshake reached : %s", seen_poke  ? "yes" : "NO");
    $display("  vblank irq enabled    : %s", seen_irq   ? "yes" : "NO");
    $display("  display enabled       : %s", seen_video ? "yes" : "NO");
    $display("  YM3812 writes         : %0d", nfm);
    if( nkeyon == 0 )
        $display("  note key-ons          :  NONE - nothing was ever made audible");
    else
        $display("  note key-ons          : %0d, first at %0d bench ms (%0d ms board)",
                 nkeyon, keyon_t/1000000, (keyon_t/1000000)*100/42);
    $display("  audio samples         : %0d, %0d non-zero, peak |snd| = %0d",
             nsamp, npk, pk);
    // samples per board second. Board ms = bench ms * 100/42, so the rate is
    // nsamp * 1000 / board_ms = nsamp * 420 / bench_ms.
    if( nsamp != 0 && $time > 0 )
        $display("                          %0d Hz at board speed",
                 (nsamp*420)/($time/1000000));
    if( wavf != 0 ) begin
        $fclose(wavf);
        $display("  raw audio             : snd.raw, signed 16-bit LE");
    end
    u_probe.report;
    $finish;
end
endtask

// ---- snapshot: freeze the main CPU at +snap=<ms>, let three frames pass so
//      nothing is mid-update, then read every video RAM out through the same
//      ports the video engine will use and write them as hex, one word a line.
task dump_words(input string fname, input integer n, input integer which);
    integer f, i;
    begin
        f = $fopen(fname, "w");
        if( f == 0 ) begin
            $display("tb_main: cannot open %0s for writing", fname);
            $finish;
        end
        for( i=0; i<n; i=i+1 ) begin
            case( which )
                0: tx_vaddr  = i; 1: bg_vaddr = i; 2: fg_vaddr = i;
                3: pal_vaddr = i; 4: obj_vaddr = i;
            endcase
            @(posedge clk); @(posedge clk);       // registered read
            case( which )
                0: $fdisplay(f, "%04x", tx_vq);  1: $fdisplay(f, "%04x", bg_vq);
                2: $fdisplay(f, "%04x", fg_vq);  3: $fdisplay(f, "%04x", pal_vq);
                4: $fdisplay(f, "%04x", obj_vq);
            endcase
        end
        $fclose(f);
    end
endtask

// Read the +snap= list. Any character that is not a digit ends a number, which
// covers both the commas and the null padding the plusarg is left-justified in.
task parse_snaps;
    integer ci, acc, seen;
    reg [7:0] ch;
    begin
        snapn = 0; acc = 0; seen = 0;
        for( ci=63; ci>=0; ci=ci-1 ) begin
            ch = snapstr[ci*8 +: 8];
            if( ch >= "0" && ch <= "9" ) begin
                acc = acc*10 + (ch - "0"); seen = 1;
            end else if( seen ) begin
                if( snapn < 16 ) snapms_l[snapn] = acc;
                snapn = snapn + 1; acc = 0; seen = 0;
            end
        end
        if( seen && snapn < 16 ) begin snapms_l[snapn] = acc; snapn = snapn + 1; end
        if( snapn > 16 ) begin
            $display("tb_main: at most 16 +snap= targets, %0d given", snapn);
            $finish;
        end
    end
endtask

integer sf, si;
string  sdir;
time    snapt;
initial if( snapn != 0 ) begin
    for( si=0; si<snapn; si=si+1 ) begin
        // 64 bit, because a target beyond 4295 ms overflows a 32 bit product of
        // milliseconds and 1e6 and lands somewhere else entirely.
        snapt = snapms_l[si] * 64'd1_000_000;
        if( snapt > $time ) #(snapt - $time);
        freeze = 1;                             // hold the main CPU's HALT line
        sdir   = $sformatf("snap%0d", snapms_l[si]);
        $display("tb_main: main CPU frozen at %0d bench ms (%0d ms of board time, t=%0t) for %0s",
                 snapms_l[si], (snapms_l[si]*100)/42, $time, sdir);
        #(3 * 18_222_000);                      // let any in-flight write settle
        dump_words($sformatf("%0s/snap_tx.hex",  sdir), 2048, 0);
        dump_words($sformatf("%0s/snap_bg.hex",  sdir), 8192, 1);
        dump_words($sformatf("%0s/snap_fg.hex",  sdir), 4096, 2);
        dump_words($sformatf("%0s/snap_pal.hex", sdir), 2048, 3);
        dump_words($sformatf("%0s/snap_obj.hex", sdir), 2048, 4);
        sf = $fopen($sformatf("%0s/snap_regs.txt", sdir), "w");
        if( sf == 0 ) begin
            $display("tb_main: cannot write into %0s/ - run.sh creates it", sdir);
            $finish;
        end
        $fdisplay(sf, "tx_scrx=0x%04x", tx_scrx); $fdisplay(sf, "tx_scry=0x%04x", tx_scry);
        $fdisplay(sf, "bg_scrx=0x%04x", bg_scrx); $fdisplay(sf, "bg_scry=0x%04x", bg_scry);
        $fdisplay(sf, "fg_scrx=0x%04x", fg_scrx); $fdisplay(sf, "fg_scry=0x%04x", fg_scry);
        $fdisplay(sf, "flip=%0d", flip); $fdisplay(sf, "bg_bank=%0d", bg_bank);
        $fdisplay(sf, "fg_bank=%0d", fg_bank); $fdisplay(sf, "video_on=%0d", video_on);
        $fclose(sf);
        $display("tb_main: %0s written", sdir);
        freeze = 0;                             // let the game run on
    end
    finish_run("all snapshots taken");
end

// Wall clock limit, counted in whole milliseconds of simulated time so the
// arithmetic stays well inside 32 bits.
integer ms;
initial begin
    for( ms=0; ms<runtime; ms=ms+1 ) #1_000_000;   // 1 ms in ns units
    finish_run("time limit");
end

endmodule
