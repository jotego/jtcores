/*  This file is part of JTCORES. GPLv3. See jtcninja_game.v header.

    Main 68000 subsystem for the Data East cninja.cpp family.

    Everything board-specific - address map, read mux (including the maincpu
    data-line descramble), cabinet port layout, soundlatch strobe, interrupt
    level and acknowledge - lives in one decoder per board:

        jtcninja_decoder    jtcbuster_decoder
        jtdarkseal_decoder  jtvaportra_decoder

    All four are instantiated and driven by their board boolean; a disabled
    decoder holds every output idle, so the merge is an OR (AND for IPLn, which
    is active low). See jtcninja_decoder_ports.inc for the contract.

    What is common and stays here: the 68000 and its clock enables, the bus
    qualifier, DTACK, the work-RAM write strobe, and the vblank latch.
*/
module jtcninja_main(
    input             rst,
    input             clk,
    input             LVBL,
    input             LHBL,
    // CPU bus (19-bit word address: 768kB main ROM needs A[19:1])
    output     [ 1:0] work_we,     // 68k work RAM (mem.yaml bram)
    input      [15:0] work_dout,
    output     [19:1] cpu_addr,
    output     [15:0] cpu_dout,
    output            UDSWn,
    output            LDSWn,
    output            RnW,
    // Program ROM (BA2). Work RAM is internal BRAM, not SDRAM.
    output            rom_cs,
    input      [15:0] rom_data,
    input             rom_ok,
    // Tilegen register banks (deco16ic x2)
    output            pf0_cs,
    output            pf1_cs,
    input      [15:0] pf0_dout,
    input      [15:0] pf1_dout,
    // Sprites
    output            objram_cs,
    output            obj_copy,
    input      [15:0] obj_dout,
    // Palette
    output            pal_cs,
    input      [15:0] pal_dout,
    // Protection (DECO 104) - also reads inputs/dips and the sound latch
    output            prot_cs,
    input      [15:0] prot_dout,
    // Board select, one boolean per game (MRA header -> jtcninja_header)
    input             ds,       // Dark Seal / Gate of Doom
    input             cb,       // Crude Buster / Two Crude
    input             vp,       // Vapor Trail / Kuhga
    input             cn,       // Caveman Ninja / Joe & Mac
    input             er,       // The Cliffhanger - Edward Randy
    // Board registers read by the colour mixer
    output            prot_pri,
    output     [15:0] vprio0,
    output     [15:0] vprio1,
    // Soundlatch written from the main bus (every board except cninja, which
    // goes through the DECO 104)
    output            snd_wr,
    output     [ 7:0] snd_dout,
    input      [`JTFRAME_BUTTONS+3:0] joystick1,
    input      [`JTFRAME_BUTTONS+3:0] joystick2,
    input      [ 3:0] cab_1p,
    input      [ 3:0] coin,
    input      [15:0] dipsw,
    // misc
    input      [ 8:0] vdump,      // beam position for raster/vblank interrupts
    input             dip_pause
);

// The four decoders drive these even under NOMAIN, where every `en` is 0.
wire [ 2:0] cn_ipl, cb_ipl, ds_ipl, vp_ipl, er_ipl;
wire [15:0] cn_din, cb_din, ds_din, vp_din, er_din;
wire        cn_rom, cb_rom, ds_rom, vp_rom, er_rom;
wire        cn_ram, cb_ram, ds_ram, vp_ram, er_ram;
wire        cn_pal, cb_pal, ds_pal, vp_pal, er_pal;
wire        cn_obj, cb_obj, ds_obj, vp_obj, er_obj;
wire        cn_pf0, cb_pf0, ds_pf0, vp_pf0, er_pf0;
wire        cn_pf1, cb_pf1, ds_pf1, vp_pf1, er_pf1;
wire        cn_prot,cb_prot,ds_prot,vp_prot,er_prot;
wire        cn_copy,cb_copy,ds_copy,vp_copy,er_copy;
wire        cn_sndw,cb_sndw,ds_sndw,vp_sndw,er_sndw;
wire [ 7:0] cn_sndd,cb_sndd,ds_sndd,vp_sndd,er_sndd;
wire        cn_ack, cb_ack, ds_ack, vp_ack, er_ack;
wire        cn_wu,  cb_wu,  ds_wu,  vp_wu,  er_wu;
wire        cb_pri;                       // cbuster TC-4 m_pri
wire [15:0] vp_prio0, vp_prio1;           // vaportra m_priority[0..1]
wire [ 2:0] IPLn = cn_ipl & cb_ipl & ds_ipl & vp_ipl & er_ipl;  // idle = 3'b111
wire        vbl_ack  = cn_ack | cb_ack | ds_ack | vp_ack | er_ack;
wire        vbl_wu   = cn_wu  | cb_wu  | ds_wu  | vp_wu  | er_wu;
wire        ram_cs   = cn_ram | cb_ram | ds_ram | vp_ram | er_ram;
wire [15:0] din_mux  = cn_din | cb_din | ds_din | vp_din | er_din;

assign rom_cs    = cn_rom | cb_rom | ds_rom | vp_rom | er_rom;
assign pal_cs    = cn_pal | cb_pal | ds_pal | vp_pal | er_pal;
assign objram_cs = cn_obj | cb_obj | ds_obj | vp_obj | er_obj;
assign pf0_cs    = cn_pf0 | cb_pf0 | ds_pf0 | vp_pf0 | er_pf0;
assign pf1_cs    = cn_pf1 | cb_pf1 | ds_pf1 | vp_pf1 | er_pf1;
assign prot_cs   = cn_prot| cb_prot| ds_prot| vp_prot| er_prot;
assign obj_copy  = cn_copy| cb_copy| ds_copy| vp_copy| er_copy;
assign snd_wr    = cn_sndw| cb_sndw| ds_sndw| vp_sndw| er_sndw;
assign snd_dout  = cn_sndd| cb_sndd| ds_sndd| vp_sndd| er_sndd;

`ifndef NOMAIN
wire [23:1] A;
wire [ 2:0] FC;
wire        BGn;
wire        ASn, UDSn, LDSn, BUSn, VPAn;
reg  [15:0] cpu_din;
wire        cpu_cen, cpu_cenb;
wire        DTACKn;
reg         ok_dly;
reg         vbl_irq;
reg  [ 8:0] vdump_l;
reg  [ 2:0] warmup;

assign UDSWn    = RnW | UDSn;
assign LDSWn    = RnW | LDSn;
// A real memory access is: address valid, at least one data strobe asserted, and
// NOT an interrupt acknowledge. FC==7 marks an IACK, which drives the same strobes
// with A=0xffffx but is not a memory cycle - VPAn below autovectors it. No region
// happens to match that address today, but the selects include partial decodes
// (vaportra's mirrored sprite RAM), and a partial decode that did match would
// start an SDRAM burst during the acknowledge.
assign BUSn     = ASn | (LDSn & UDSn) | &FC;
assign VPAn     = ~&{ FC, ~ASn };
assign cpu_addr = A[19:1];
// Work RAM lives in BRAM, NOT SDRAM: the 68000 must clear it during init fast
// enough to reach the boot handshake before the first VBLANK.
assign work_we  = {2{ram_cs & ~RnW}} & ~{UDSn,LDSn};
// flip is owned by jtcninja_video (deco16ic control reg); not driven here.

// Vblank interrupt. Every board raises it the same way and at the same line;
// only the IPL level and the acknowledge address differ, and those belong to
// the decoders. Swallow the first few vblanks after reset: the sim ROM download
// desyncs CPU reset from the free-running vtimer, so without this the first
// vblank can land during the masked init and preempt it. edrandy opts out
// (vbl_warmup=0): it expects a pending vblank at a known point in its init.
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ok_dly  <= 0;
        vdump_l <= 0;
        vbl_irq <= 0;
        warmup  <= 3'd4;
    end else begin
        ok_dly  <= rom_ok;
        vdump_l <= vdump;
        if( vdump==9'd248 && vdump_l!=9'd248 ) begin   // first blank line
            if( warmup!=3'd0 && vbl_wu ) warmup <= warmup - 3'd1;
            else               vbl_irq <= 1;
        end
        if( vbl_ack ) vbl_irq <= 0;
    end
end

always @(posedge clk) cpu_din <= din_mux;

// Only the SDRAM-backed ROM read stalls the bus; work RAM is BRAM.
// Require BOTH the current rom_ok AND its 1-clk delay (ok_dly, for the registered
// cpu_din). ok_dly alone let a FRESH read (rom_ok=0) proceed while ok_dly was
// still 1 from the PREVIOUS read, so the CPU latched stale data. It only bit
// non-sequential reads landing in that window - notably an autovector fetch
// after an IACK, which read 0xFFFF and jumped to a bad handler.
wire bus_cs   = rom_cs;
wire bus_busy = rom_cs & ~(ok_dly & rom_ok);

jtframe_68kdtack_cen #(.W(8)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 7'd1      ), // 12 MHz
    .den        ( 8'd4      ),
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       (           ),
    .fworst     (           )
);

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),
    // Buses
    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),
    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( VPAn        ),
    .FC         ( FC          ),
    .BERRn      ( 1'b1        ),
    // Bus arbitration
    .RESETn     (             ),
    .HALTn      ( dip_pause   ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        ( BGn         ),
    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        )
);

`ifdef SIMULATION
`ifdef PCTRACE
// 68k program-fetch dump -> main_fpga.tr, one line per completed program-space
// bus cycle ("PC: opword"). A superset of MAME's PCs because of prefetch, so
// diff it as an in-order subsequence against the MAME trace.
integer pctr; reg asn_q, prog_cyc; reg [23:1] pc_l; reg [15:0] op_l;
wire prog_rd = FC[1] & ~FC[0] & RnW;
initial pctr = $fopen("main_fpga.tr","w");
always @(posedge clk) begin
    asn_q <= ASn;
    if( !ASn && prog_rd ) begin prog_cyc<=1; pc_l<=A; op_l<=cpu_din; end
    if( !asn_q && ASn ) begin
        if( prog_cyc && pctr!=0 ) $fwrite(pctr,"%06X: %04X\n",{pc_l,1'b0},op_l);
        prog_cyc<=0;
    end
end
final if( pctr!=0 ) $fclose(pctr);
`endif

// Heartbeat: per-frame liveness + cumulative palette/tilegen/sprite write
// counts (compare to MAME: full boot writes 4096 palette + ~50k tilegen).
integer frcnt = 0, palw = 0, tilew = 0, objw = 0, vbl_set = 0;
reg palcs_l, tilecs_l, objcs_l, vbl_irq_l;
always @(posedge clk) begin   // edge-detect the actual write (DS-asserted)
    palcs_l  <= pal_cs;
    tilecs_l <= pf0_cs|pf1_cs;
    objcs_l  <= objram_cs;
    vbl_irq_l<= vbl_irq;
    if( pal_cs & ~palcs_l & ~RnW )                palw  = palw  + 1;
    if( (pf0_cs|pf1_cs) & ~tilecs_l & ~RnW )      tilew = tilew + 1;
    if( objram_cs & ~objcs_l & ~RnW )             objw  = objw  + 1;
    if( vbl_irq & ~vbl_irq_l )                    vbl_set = vbl_set + 1;
end
always @(negedge LVBL) begin
    frcnt = frcnt + 1;
    $display("CNINJA hb: frame=%0d dcv=%03b A=%06x pal=%0d tile=%0d obj=%0d | IPLn=%b vbl_set=%0d",
             frcnt, {ds,cb,vp}, {A,1'b0}, palw, tilew, objw, IPLn, vbl_set);
end
`endif

assign prot_pri = cb_pri;
assign vprio0   = vp_prio0;
assign vprio1   = vp_prio1;
`else
    // NOMAIN scene replay: the CPU is fully tied off. Every decoder sees en=0,
    // so all the merged selects above read 0 and the board registers are left
    // for u_dumper to restore from the captured scene.
    wire [23:1] A       = 0;
    wire        UDSn    = 1, LDSn = 1, BUSn = 1;
    wire        vbl_irq = 0;
    assign cpu_addr = 0;
    assign cpu_dout = 0;
    assign work_we  = 0;
    assign UDSWn = 1; assign LDSWn = 1; assign RnW = 1;
    wire _unused_nomain = &{ 1'b0, din_mux, IPLn, rom_ok, dip_pause, work_dout,
                             rom_data, pf0_dout, pf1_dout, pal_dout, obj_dout,
                             prot_dout, joystick1, joystick2, cab_1p, coin,
                             dipsw, vdump, cb_pri, vp_prio0, vp_prio1, vbl_wu };
`endif

jtcninja_decoder u_cninja(
    .rst(rst), .clk(clk), .en(cn),
    .A(A), .cpu_dout(cpu_dout), .RnW(RnW), .UDSn(UDSn), .LDSn(LDSn), .busn(BUSn),
    .vdump(vdump), .LVBL(LVBL), .LHBL(LHBL),
    .vbl_irq(vbl_irq), .vbl_ack(cn_ack), .vbl_warmup(cn_wu), .IPLn(cn_ipl),
    .rom_cs(cn_rom), .ram_cs(cn_ram), .pal_cs(cn_pal), .objram_cs(cn_obj),
    .pf0_cs(cn_pf0), .pf1_cs(cn_pf1), .prot_cs(cn_prot), .obj_copy(cn_copy),
    .rom_data(rom_data), .work_dout(work_dout), .pf0_dout(pf0_dout),
    .pf1_dout(pf1_dout), .pal_dout(pal_dout), .obj_dout(obj_dout),
    .prot_dout(prot_dout), .cpu_din(cn_din),
    .joystick1(joystick1), .joystick2(joystick2), .cab_1p(cab_1p),
    .coin(coin), .dipsw(dipsw),
    .snd_wr(cn_sndw), .snd_dout(cn_sndd),
    .prot_pri(), .vprio0(), .vprio1()
);

jtcbuster_decoder u_cbuster(
    .rst(rst), .clk(clk), .en(cb),
    .A(A), .cpu_dout(cpu_dout), .RnW(RnW), .UDSn(UDSn), .LDSn(LDSn), .busn(BUSn),
    .vdump(vdump), .LVBL(LVBL), .LHBL(LHBL),
    .vbl_irq(vbl_irq), .vbl_ack(cb_ack), .vbl_warmup(cb_wu), .IPLn(cb_ipl),
    .rom_cs(cb_rom), .ram_cs(cb_ram), .pal_cs(cb_pal), .objram_cs(cb_obj),
    .pf0_cs(cb_pf0), .pf1_cs(cb_pf1), .prot_cs(cb_prot), .obj_copy(cb_copy),
    .rom_data(rom_data), .work_dout(work_dout), .pf0_dout(pf0_dout),
    .pf1_dout(pf1_dout), .pal_dout(pal_dout), .obj_dout(obj_dout),
    .prot_dout(prot_dout), .cpu_din(cb_din),
    .joystick1(joystick1), .joystick2(joystick2), .cab_1p(cab_1p),
    .coin(coin), .dipsw(dipsw),
    .snd_wr(cb_sndw), .snd_dout(cb_sndd),
    .prot_pri(cb_pri), .vprio0(), .vprio1()
);

jtdarkseal_decoder u_darkseal(
    .rst(rst), .clk(clk), .en(ds),
    .A(A), .cpu_dout(cpu_dout), .RnW(RnW), .UDSn(UDSn), .LDSn(LDSn), .busn(BUSn),
    .vdump(vdump), .LVBL(LVBL), .LHBL(LHBL),
    .vbl_irq(vbl_irq), .vbl_ack(ds_ack), .vbl_warmup(ds_wu), .IPLn(ds_ipl),
    .rom_cs(ds_rom), .ram_cs(ds_ram), .pal_cs(ds_pal), .objram_cs(ds_obj),
    .pf0_cs(ds_pf0), .pf1_cs(ds_pf1), .prot_cs(ds_prot), .obj_copy(ds_copy),
    .rom_data(rom_data), .work_dout(work_dout), .pf0_dout(pf0_dout),
    .pf1_dout(pf1_dout), .pal_dout(pal_dout), .obj_dout(obj_dout),
    .prot_dout(prot_dout), .cpu_din(ds_din),
    .joystick1(joystick1), .joystick2(joystick2), .cab_1p(cab_1p),
    .coin(coin), .dipsw(dipsw),
    .snd_wr(ds_sndw), .snd_dout(ds_sndd),
    .prot_pri(), .vprio0(), .vprio1()
);

jtvaportra_decoder u_vaportra(
    .rst(rst), .clk(clk), .en(vp),
    .A(A), .cpu_dout(cpu_dout), .RnW(RnW), .UDSn(UDSn), .LDSn(LDSn), .busn(BUSn),
    .vdump(vdump), .LVBL(LVBL), .LHBL(LHBL),
    .vbl_irq(vbl_irq), .vbl_ack(vp_ack), .vbl_warmup(vp_wu), .IPLn(vp_ipl),
    .rom_cs(vp_rom), .ram_cs(vp_ram), .pal_cs(vp_pal), .objram_cs(vp_obj),
    .pf0_cs(vp_pf0), .pf1_cs(vp_pf1), .prot_cs(vp_prot), .obj_copy(vp_copy),
    .rom_data(rom_data), .work_dout(work_dout), .pf0_dout(pf0_dout),
    .pf1_dout(pf1_dout), .pal_dout(pal_dout), .obj_dout(obj_dout),
    .prot_dout(prot_dout), .cpu_din(vp_din),
    .joystick1(joystick1), .joystick2(joystick2), .cab_1p(cab_1p),
    .coin(coin), .dipsw(dipsw),
    .snd_wr(vp_sndw), .snd_dout(vp_sndd),
    .prot_pri(), .vprio0(vp_prio0), .vprio1(vp_prio1)
);

jtedrandy_decoder u_edrandy(
    .rst(rst), .clk(clk), .en(er),
    .A(A), .cpu_dout(cpu_dout), .RnW(RnW), .UDSn(UDSn), .LDSn(LDSn), .busn(BUSn),
    .vdump(vdump), .LVBL(LVBL), .LHBL(LHBL),
    .vbl_irq(vbl_irq), .vbl_ack(er_ack), .vbl_warmup(er_wu), .IPLn(er_ipl),
    .rom_cs(er_rom), .ram_cs(er_ram), .pal_cs(er_pal), .objram_cs(er_obj),
    .pf0_cs(er_pf0), .pf1_cs(er_pf1), .prot_cs(er_prot), .obj_copy(er_copy),
    .rom_data(rom_data), .work_dout(work_dout), .pf0_dout(pf0_dout),
    .pf1_dout(pf1_dout), .pal_dout(pal_dout), .obj_dout(obj_dout),
    .prot_dout(prot_dout), .cpu_din(er_din),
    .joystick1(joystick1), .joystick2(joystick2), .cab_1p(cab_1p),
    .coin(coin), .dipsw(dipsw),
    .snd_wr(er_sndw), .snd_dout(er_sndd),
    .prot_pri(), .vprio0(), .vprio1()
);

// Board priority registers: cbuster's TC-4 m_pri and vaportra's m_priority.
// They live outside the deco16ic, so scene replay restores them here - the
// dumper turns into a reader under NOMAIN and drives the three outputs.
jtframe_simdumper #(.DW(33),.SEEK(32)) u_dumper(
    .clk        ( clk       ),
    .data       ( { prot_pri, vprio1, vprio0 } ),
    .ioctl_addr ( 3'd0      ),
    .ioctl_din  (           )
);
endmodule
