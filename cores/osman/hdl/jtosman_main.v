/*  This file is part of JTCORES. GPLv3. See jtosman_game.v header.
    Author: Andrea Bogazzi.

    Osman main CPU: Data East 156 = encrypted 26-bit ARM (7.000 MHz). Wraps the
    vendored Amber a23 core (hdl/amber, OpenCores) and bridges its Wishbone master
    to the simpl156 mitchell156_map. ARM ROM is deco156-encrypted, decrypted AT
    FETCH (jtosman_deco156); the raw ROM sits in SDRAM.

    Pacing: a23 has no cen input, but i_system_rdy freezes the pipeline
    (a23_fetch: o_fetch_stall=!i_system_rdy...). Gate with cen_arm -> 7 MHz.

    mitchell156_map (byte addr): 000000-07FFFF ROM(32b) | 100000 okisfx | 140000
    okimusic | 180000-187FFF main RAM(16b) | 190000-191FFF sprite RAM(16b) |
    1A0000-1A0FFF palette(16b) | 1B0000 R:IN1 W:eeprom_w | 1C0000 pf ctrl |
    1D0000 pf name | 1E0000 rowscroll | 1F0000 ctrl(nop) | 200000 IN0 |
    201000-201FFF systemram(32b, mirror 2000).
    eeprom_w: okimusic bank=d[2:0], clk=d[5], di=d[4], cs=d[6].
    IRQ = vblank (ARM_IRQ_LINE), level; IN0[7] = live vblank (boot polls it).
    NOTE(boot-trace TODO): reverse=true 32-bit ROM may need byteswap32 like
    nslasher — verify the reset-vector fetch and flip ROM_BYTESWAP if wrong.
*/
module jtosman_main(
    input             rst,
    input             clk,
    input             cen_arm,
    input             LVBL,       // vblank level (active low visible) -> IRQ + IN0[7]
    input             jm,         // header: joemacr map (device block @0x100000)

    // program ROM (SDRAM, 32-bit, deco156 decrypt-at-fetch)
    output reg        rom_cs,
    output   [18:2]   rom_addr,
    input    [31:0]   rom_data,
    input             rom_ok,

    // CPU bus (16-bit device side) -> video
    output   [16:1]   cpu_addr,
    output   [15:0]   cpu_dout,
    output            cpu_rnw,
    output   [ 1:0]   dsn,
    output reg        pf_cs,
    output reg        pfram_cs,
    output reg        pal_cs,
    output reg        oram_cs,
    output reg        rowscr_cs,
    output            obj_copy,
    input    [15:0]   pf_dout,
    input    [15:0]   pal_dout,
    input    [15:0]   oram_dout,
    output reg        flip,

    // sound command to the two OKIs (main-driven; no sound CPU)
    output reg        oki1_wr,    // 0x100000
    output reg        oki2_wr,    // 0x140000
    output reg [ 7:0] oki_din,
    output reg [ 2:0] oki2_bank,  // eeprom_w[2:0]
    input      [ 7:0] oki1_dout,  // okim6295 status read
    input      [ 7:0] oki2_dout,

    // cabinet (JTFRAME order, active-low)
    input    [ 6:0]   joystick1,
    input    [ 6:0]   joystick2,
    input    [ 3:0]   cab_1p,
    input    [ 3:0]   coin,
    input             service,
    input             dip_test,

    input    [ 8:0]   vdump
);

`ifdef NOMAIN
// Scene replay: CPU stubbed off so the SIMSCENE-preloaded video BRAMs (palette /
// pf name / control regs, loaded in jtosman_video) are what gets rendered. Hold
// cpu_rnw high and every chip-select low so nothing overwrites the scene.
assign rom_addr = 17'd0;
assign cpu_addr = 16'd0;
assign cpu_dout = 16'd0;
assign cpu_rnw  = 1'b1;
assign dsn      = 2'b11;
assign obj_copy = 1'b0;
initial begin
    rom_cs=0; pf_cs=0; pfram_cs=0; pal_cs=0; oram_cs=0; rowscr_cs=0;
    oki1_wr=0; oki2_wr=0; oki_din=0; oki2_bank=0; flip=0;
end
`else

// ---- a23 Wishbone master ----
wire [31:0] wb_adr, wb_wdat;
reg  [31:0] wb_rdat;
wire [ 3:0] wb_sel;
wire        wb_we, wb_cyc, wb_stb, wb_tga;
reg         wb_ack;

wire        acc = wb_cyc & wb_stb;
wire        wr  = acc &  wb_we;
wire        rd  = acc & ~wb_we;

// vblank: LVBL is active-low visible -> vblank when LVBL==0. IN0 bit7 active-HIGH.
wire        vbl = ~LVBL;

// ---- address decode (byte page = wb_adr[23:16]). Same devices on both maps,
//      only the page assignment moves: mitchell156_map, or joemacr_map when jm ----
wire [ 7:0] page = wb_adr[23:16];
wire is_rom    = wb_adr[23:19]==5'd0;           // 000000-07FFFF
wire is_okisfx = page==(jm?8'h18:8'h10);        // 180000 / 100000
wire is_okimus = page==(jm?8'h1c:8'h14);        // 1C0000 / 140000
wire is_mram   = page==(jm?8'h10:8'h18);        // 100000 / 180000-187FFF (16-bit, 32 KB)
wire is_oram   = page==(jm?8'h11:8'h19);        // 110000 / 190000-191FFF (16-bit, 8 KB)
wire is_pal    = page==(jm?8'h12:8'h1a);        // 120000 / 1A0000-1A0FFF (16-bit, 4 KB)
wire is_io     = page==(jm?8'h13:8'h1b);        // 130000 / 1B0000 R:IN1 W:eeprom_w
wire is_pfctl  = page==(jm?8'h14:8'h1c);        // 140000 / 1C0000-1C001F pf control
wire is_pfram  = page==(jm?8'h15:8'h1d);        // 150000 / 1D0000-1D5FFF pf name tables
wire is_rowscr = page==(jm?8'h16:8'h1e);        // 160000 / 1E0000-1E5FFF rowscroll
wire is_ctrl   = page==(jm?8'h17:8'h1f);        // 170000 / 1F0000 control (nop)
wire is_in0    = page==8'h20 & ~wb_adr[12];     // 200000 IN0
wire is_sram   = page==8'h20 &  wb_adr[12];     // 201000-201FFF systemram (32-bit)

wire is_video  = is_pfctl | is_pfram | is_rowscr | is_pal | is_oram;
wire is_bram   = is_mram | is_sram | is_video;  // 1-cycle BRAM read latency

// ---- EEPROM internal signals (jt9346 lives here) ----
reg  ee_sclk, ee_sdi, ee_scs;
wire ee_sdo;

// ---- inputs (simpl156). JTFRAME delivers cabinet inputs ACTIVE-LOW (idle=1) — do NOT invert
// (verified vs MAME: idle IN0=0x018f, IN1=0xffff). Unused bits read 0. dip_test is the OSD
// service toggle (active-high) so it IS inverted into the active-low service bit.
// IN0: b0 coin1, b1 coin2, b2 service1, b3 service(no-toggle), b7 vblank(HIGH), b8 eeprom DO
wire [15:0] in0 = { 7'd0, ee_sdo, vbl, 3'd0, dip_test, service, coin[1], coin[0] };
// IN1: P1 UDLR b0-3 + btn1-3 b4-6 + start1 b7 ; P2 b8-15. Bit order via JTFRAME_JOY_RLDU.
wire [15:0] in1 = { cab_1p[1], joystick2, cab_1p[0], joystick1 };

// ---- deco156 ARM ROM descramble at fetch ----
wire [17:0] arm_word = { 1'b0, wb_adr[18:2] };  // 512 KB = 128K 32-bit words (a[16:0]; a[17]=0)
wire [17:0] dec_saddr;
wire [31:0] rom_dec;
// The 32-bit SDRAM word arrives as {hi16,lo16} with each 16-bit half byte-swapped vs MAME's
// LE32 view. Swap bytes within each half to feed deco156 the LE32 word it expects.
// Verified against MAME: dec(0)=ea000169 (=B 0x5AC, the reset vector).
wire [31:0] rom_raw = { rom_data[23:16], rom_data[31:24], rom_data[7:0], rom_data[15:8] };
jtosman_deco156 u_dec156(
    .a        ( arm_word  ),
    .dec_addr ( dec_saddr ),
    .raw      ( rom_raw   ),
    .dec      ( rom_dec   )
);
assign rom_addr = dec_saddr[16:0];   // scrambled SDRAM word address (512 KB region), -> port [18:2]

// ---- 93C46 EEPROM (jt9346), bit-banged via 0x1B0000 write ----
// Osman/Cannon Dancer do NOT init their own EEPROM: word[0]=0xffbe, word[0x20]=0x0088
// must be present or the game won't boot (simpl156.cpp note). Preload the osman image
// through the dump port at power-up (64 words, runs during reset). TODO: candance image;
// hardware NVRAM path via the MRA eeprom region.
reg  [15:0] eegold [0:63];
reg  [ 6:0] eeld = 7'd0;   // [6]=done
initial $readmemh("eeprom_osman.hex", eegold);
always @(posedge clk) if( !eeld[6] ) eeld <= eeld + 7'd1;
jt9346 #(.AW(6),.DW(16)) u_eeprom(
    .rst      ( rst     ),
    .clk      ( clk     ),
    .sclk     ( ee_sclk ),
    .sdi      ( ee_sdi  ),
    .sdo      ( ee_sdo  ),
    .scs      ( ee_scs  ),
    .dump_clk ( clk         ),
    .dump_addr( eeld[5:0]   ),
    .dump_we  ( ~eeld[6]    ),
    .dump_din ( eegold[eeld[5:0]] ),
    .dump_dout(         ),
    .dump_clr ( 1'b1    ),
    .dump_flag(         )
);

// ---- work RAM (BRAM), BYTE-writable (ARM uses STRB/STRH on game-state vars). ----
// mainram: 16-bit device on the low 16 bits (mem_mask&0xffff); the ARM addresses it at 32-bit
// spacing (MAME mainram_r is a u32 handler, offset=byte>>2) -> addr wb_adr[14:2], byte lanes
// wb_sel[1:0]. systemram: true 32-bit, byte lanes wb_sel[3:0] (two 16-bit halves).
wire [15:0] mram_q;
wire [31:0] sram_q;
jtframe_dual_ram16 #(.AW(13)) u_mainram(         // 8K x 16 (one per ARM word) = 32 KB
    .clk0(clk), .addr0(wb_adr[14:2]), .data0(wb_wdat[15:0]),
    .we0({2{is_mram&wr}} & wb_sel[1:0]), .q0(mram_q),
    .clk1(clk), .addr1(13'd0), .data1(16'd0), .we1(2'b0), .q1()
);
jtframe_dual_ram16 #(.AW(10)) u_sysram_lo(       // systemram low 16 bits
    .clk0(clk), .addr0(wb_adr[11:2]), .data0(wb_wdat[15:0]),
    .we0({2{is_sram&wr}} & wb_sel[1:0]), .q0(sram_q[15:0]),
    .clk1(clk), .addr1(10'd0), .data1(16'd0), .we1(2'b0), .q1()
);
jtframe_dual_ram16 #(.AW(10)) u_sysram_hi(       // systemram high 16 bits
    .clk0(clk), .addr0(wb_adr[11:2]), .data0(wb_wdat[31:16]),
    .we0({2{is_sram&wr}} & wb_sel[3:2]), .q0(sram_q[31:16]),
    .clk1(clk), .addr1(10'd0), .data1(16'd0), .we1(2'b0), .q1()
);

// ---- CPU bus to video ----
assign cpu_addr = wb_adr[16:1];
assign cpu_dout = wb_wdat[15:0];
assign cpu_rnw  = ~wb_we;
assign dsn      = ~wb_sel[1:0];
assign obj_copy = 1'b0;   // TODO: sprite DMA trigger (simpl156 copies spriteram each frame)

// ---- IRQ latch (HOLD_LINE semantics): assert on vblank rising edge, clear when the
//      ARM takes it (fetches the IRQ vector 0x18). One IRQ per frame, matching MAME's
//      set_input_line(ARM_IRQ_LINE, state?HOLD_LINE:CLEAR_LINE). A held level re-enters
//      the handler forever and the main loop never draws. ----
reg irq_l, vbl_l;
always @(posedge clk) begin
    if( rst ) begin irq_l <= 1'b0; vbl_l <= 1'b0; end
    else begin
        vbl_l <= vbl;
        if( vbl & ~vbl_l )                                   irq_l <= 1'b1;   // vblank start
        else if( is_rom & rd & wb_ack & wb_adr[23:2]==22'h6 ) irq_l <= 1'b0;  // vector 0x18 fetched
    end
end

// ---- video chip-selects (registered write path lives below) ----
always @* begin
    pf_cs     = is_pfctl  & acc;
    pfram_cs  = is_pfram  & acc;
    pal_cs    = is_pal    & acc;
    oram_cs   = is_oram   & acc;
    rowscr_cs = is_rowscr & acc;
    rom_cs    = is_rom    & rd;
end

// ---- BRAM read ack: 1-cycle settle ----
reg bram_rdy;
always @(posedge clk) begin
    if( rst ) bram_rdy <= 1'b0;
    else      bram_rdy <= acc & is_bram & ~bram_rdy;
end

// ---- read-data mux + Wishbone ack ----
always @* begin
    wb_rdat = 32'hffff_ffff;   // data-bus pull-ups
    wb_ack  = 1'b0;
    if( acc ) begin
        if( is_rom )      begin wb_rdat = rom_dec;                 wb_ack = rom_cs & rom_ok; end
        else if( is_mram )begin wb_rdat = {16'hffff, mram_q};      wb_ack = wr | bram_rdy;  end
        else if( is_sram )begin wb_rdat = sram_q;                  wb_ack = wr | bram_rdy;  end
        else if( is_pal ) begin wb_rdat = {16'hffff, pal_dout};    wb_ack = wr | bram_rdy;  end
        else if( is_oram )begin wb_rdat = {16'hffff, oram_dout};   wb_ack = wr | bram_rdy;  end
        else if( is_pfram|is_pfctl ) begin wb_rdat = {16'hffff, pf_dout}; wb_ack = wr | bram_rdy; end
        else if( is_in0 ) begin wb_rdat = {16'hffff, in0};         wb_ack = 1'b1; end
        else if( is_io )  begin wb_rdat = {16'hffff, in1};         wb_ack = 1'b1; end   // R:IN1
        // OKI status read (okim6295 read): {4'hf, per-channel busy}. The music sequencer polls
        // this to know when a phrase is done; a hardcoded 0 makes it re-trigger forever (noise).
        else if( is_okisfx ) begin wb_rdat = {24'hff_ffff, oki1_dout}; wb_ack = 1'b1; end
        else if( is_okimus ) begin wb_rdat = {24'hff_ffff, oki2_dout}; wb_ack = 1'b1; end
        else              begin wb_rdat = 32'hffff_ffff;           wb_ack = 1'b1; end   // rowscroll/ctrl/unmapped
    end
end

// ---- registered write side: OKI, eeprom_w, IRQ clear ----
always @(posedge clk) begin
    if( rst ) begin
        oki1_wr<=0; oki2_wr<=0; oki_din<=0; oki2_bank<=0;
        ee_sclk<=0; ee_sdi<=0; ee_scs<=0; flip<=0;
    end else begin
        oki1_wr <= 1'b0;
        oki2_wr <= 1'b0;
        if( wr & wb_ack ) begin
            if( is_okisfx ) begin oki1_wr <= 1'b1; oki_din <= wb_wdat[7:0]; end
            if( is_okimus ) begin oki2_wr <= 1'b1; oki_din <= wb_wdat[7:0]; end
            if( is_io & wb_sel[0] ) begin           // eeprom_w @ 0x1B0000
                oki2_bank <= wb_wdat[2:0];
                ee_sdi    <= wb_wdat[4];
                ee_sclk   <= wb_wdat[5];
                ee_scs    <= wb_wdat[6];
            end
        end
    end
end

// ---- lightweight boot trace: ONE line per frame (not per fetch), so a 600-frame sim
//      stays ~15 KB. maxPC = highest ROM PC reached this frame; curPC = PC at vblank;
//      irqs = IRQ vector fetches so far. Shows boot progress / where it settles. ----
`ifdef SIMULATION
// one line per frame: highest ROM PC reached this frame + PC at vblank. Shows the game is
// progressing (maxPC climbs through gameplay code) vs frozen.
integer bootf; reg vbl_s; reg [23:0] pcmax;
initial begin bootf=$fopen("osman_boot.log","w"); pcmax=0; vbl_s=0; end
always @(posedge clk) begin
    vbl_s <= vbl;
    if( is_rom & rd & wb_ack & wb_adr[23:0]>pcmax ) pcmax <= wb_adr[23:0];
    if( vbl & ~vbl_s ) begin
        if(bootf!=0) $fwrite(bootf, "maxPC=%06x curPC=%06x\n", pcmax, wb_adr[23:0]);
        pcmax <= 24'd0;
    end
end
`endif

`ifdef OSMAN_WRLOG
// Log every acked CPU write (byte addr, sel, 32-bit data) for the first ~4 frames, to diff the
// write stream against MAME's and find the first divergence. Bounded so it can't run away.
integer wrf; reg wvbl_s; reg [7:0] wfn;
initial begin wrf=$fopen("osman_wr.log","w"); wvbl_s=0; wfn=0; end
always @(posedge clk) begin
    wvbl_s <= vbl;
    if( vbl & ~wvbl_s ) wfn <= wfn + 8'd1;
    if( wr & wb_ack & wrf!=0 & wfn<8'd4 )
        $fwrite(wrf, "%06x %x %08x\n", wb_adr[23:0], wb_sel, wb_wdat);
end
`endif

`ifdef OSMAN_PCTRACE
integer arm_tr;
initial arm_tr = $fopen("osman_arm_fpga.tr","w");
always @(posedge clk) if( is_rom & rd & wb_ack & arm_tr!=0 )
    $fwrite(arm_tr, "%07X: %08X\n", {wb_adr[23:2],2'b00}, rom_dec);
`endif

a23_core u_arm(
    .i_clk        ( clk       ),
    .i_reset      ( rst       ),
    .i_irq        ( irq_l     ),
    .i_firq       ( 1'b0      ),
    .i_system_rdy ( 1'b1      ),   // UNGATED (nslasher pattern): the a23 L1 cache is CP15-disabled on
                                   // this bare ARM binary (~10 CPI) so gating to cen_arm crawls; run at
                                   // 48 MHz, game stays vblank-synced. TODO: ROM cache for real 7 MHz.
    .o_wb_adr     ( wb_adr    ),
    .o_wb_sel     ( wb_sel    ),
    .o_wb_we      ( wb_we     ),
    .i_wb_dat     ( wb_rdat   ),
    .o_wb_dat     ( wb_wdat   ),
    .o_wb_cyc     ( wb_cyc    ),
    .o_wb_stb     ( wb_stb    ),
    .i_wb_ack     ( wb_ack    ),
    .i_wb_err     ( 1'b0      ),
    .o_wb_tga     ( wb_tga    )
);
`endif

endmodule
