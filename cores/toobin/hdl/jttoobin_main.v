/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Andrea Bogazzi. andreabogazzi79@gmail.com
    Version: 1.0
    Date: 25-06-2026 */

// Toobin' main CPU (board has a 68010; fx68k = 68000 is opcode-compatible, verified).
// Address decode transcribed from the PCB decoder sheet (LS139/LS138/LS20), which
// matches MAME's register map exactly. See doc/SCHEMATIC_DECODE.md.
//   ROM   : BA23=0                         -> 0x000000-0x07ffff (partial, mirrors)
//   region: A23=1,A22=0 (0x8xxxxx)  /  A23=1,A22=1 (0xC0xxxx video)
module jttoobin_main(
    input                rst,
    input                clk,
    input                LVBL,
    input                LHBL,
    input         [ 8:0] vdump,

    // SDRAM program ROM (main bus) — also feeds the BRAM addr bindings in mem.yaml
    output        [18:1] rom_addr,
    output reg           rom_cs,
    input         [15:0] rom_data,
    input                rom_ok,

    // CPU bus exposed to BRAMs / video
    output        [13:1] cpu_addr,
    output        [ 1:0] cpu_dsn,
    output        [15:0] cpu_dout,
    output               cpu_rnw,

    // work RAM (BRAM)
    output        [ 1:0] ram_we,
    input         [15:0] ram_dout,

    // EEPROM (BRAM, low byte)
    output reg           eeprom_cs,
    output               nvram_we,
    input         [ 7:0] nvram_dout,

    // video RAM (BRAM, dual-port; engine reads the other port)
    output reg           pf_cs,
    output        [ 1:0] pf_we,
    input         [15:0] pf_dout,
    output reg           al_cs,
    output        [ 1:0] al_we,
    input         [15:0] al_dout,
    output reg           mob_cs,
    output        [ 1:0] mob_we,
    input         [15:0] mob_dout,
    output reg           cram_cs,     // palette (0xc10000)
    output        [ 1:0] pal_we,
    input         [15:0] pal_dout,

    // registers exported to the video pipeline
    output reg    [15:0] xscroll,
    output reg    [15:0] yscroll,
    output reg    [15:0] slip,
    output reg    [ 4:0] intensity,

    // JSA-I sound comm (stubbed until the sound CPU lands)
    output reg    [ 7:0] snd_cmd,
    output reg           snd_cmdwr,
    output reg           snd_rstn,
    input         [ 7:0] snd_resp,
    input                snd_rdy,

    // cabinet (paddle quadrature wired later; inputs stubbed idle for boot)
    input         [15:0] dipsw,
    input                dip_pause,
    input                service,
    output        [ 7:0] st_dout,
    input         [ 7:0] debug_bus
);
`ifndef NOMAIN
wire [23:1] A;
wire [ 2:0] FC;
wire [15:0] fave;
reg  [15:0] cpu_din;
// raw IPL lines (set_interrupt_mixer false): IPL0 = /IRQ scanline, IPL1 = /P2TALK sound, IPL2 = pull-up.
wire [ 2:0] IPLn = { 1'b1, 1'b1 /*~sound_irq later*/, ~scanline_irq };
wire        cpu_cen, cpu_cenb, dtackn, VPAn, bus_busy, bus_cs;
wire        UDSn, LDSn, RnW, ASn, BUSn;
reg         HALTn;

// Region top level — PARTIAL decode (A22 is a mirror don't-care, MAME mirror 0x450000).
// Peripherals (0x82xxxx) carry A17=1 and are reached via the A22=1 mirror too — the POST
// tests work RAM through 0xffc000 (A22=1) and kicks the watchdog at 0xff8000. Video (0xc0xxxx)
// is A22=1, A17=0. So A17 — not A22 — splits peripheral from video.
wire io_cs  = A[23] &  A[17];            // peripheral region (+ its A22/A18/A16 mirrors)
wire vid_cs = A[23] &  A[22] & ~A[17];   // video RAM region
wire p82    = io_cs;
// 0x828000-0x829fff register/io block (A15=1,A14=0,A13=0)
wire reg_blk= p82 & A[15] & ~A[14] & ~A[13];
reg         reg_wr, ctl_cs, inp_cs, aud_cs, leta_cs;
reg         wdog_cs, audwr_cs, sreset_cs, unlock_cs, hscr_cs, vscr_cs;
reg         z300_cs, intline_cs, slip_cs, irqack_cs;

assign cpu_addr = A[13:1];
assign rom_addr = A[18:1];
assign cpu_dsn  = {UDSn, LDSn};
assign cpu_rnw  = RnW;
assign BUSn     = ASn | (LDSn & UDSn);
// VPA on interrupt-ack / CPU space (FC=7) -> autovector (12K LS20)
assign VPAn     = ~( &FC & ~ASn );
assign bus_cs   = rom_cs;
assign bus_busy = rom_cs & ~rom_ok;

assign ram_we   = ~cpu_dsn & {2{ram_cs  & ~RnW}};
assign pf_we    = ~cpu_dsn & {2{pf_cs   & ~RnW}};
assign al_we    = ~cpu_dsn & {2{al_cs   & ~RnW}};
assign mob_we   = ~cpu_dsn & {2{mob_cs  & ~RnW}};
assign pal_we   = ~cpu_dsn & {2{cram_cs & ~RnW}};
assign nvram_we = eeprom_cs & ~RnW & ~LDSn;   // byte device, low byte
assign st_dout  = 0;

reg ram_cs;
always @* begin
    rom_cs    = !BUSn && !A[23];                                   // ROM, mirrors
    ram_cs    = !BUSn && p82 && A[15] &&  A[14];                   // 0x82c000-0x82ffff
    eeprom_cs = !ASn  && p82 && A[15] && ~A[14] && A[13];          // 0x82a000
    leta_cs   = !ASn  && p82 && ~A[15] && A[14] && A[13];          // 0x826000

    // video RAM (0xC0xxxx), split on A16/A15
    pf_cs     = !ASn && vid_cs && ~A[16] && ~A[15];                // 0xc00000 playfield
    cram_cs   = !ASn && vid_cs &&  A[16] && ~A[15];                // 0xc10000 palette
    // 0xc08000 alpha (low 6KB) + 0xc09800 MO (top 2KB) — split A[12]&A[11] (VERIFY #17)
    al_cs     = !ASn && vid_cs && ~A[16] && A[15] && ~(A[12] & A[11]);
    mob_cs    = !ASn && vid_cs && ~A[16] && A[15] &&  (A[12] & A[11]);

    // register/io block 0x828000-0x829fff
    reg_wr    = reg_blk && ~A[12] && ~A[11];   // 0x828000-0x8287ff strobes (7M LS138)
    ctl_cs    = reg_blk && ~A[12] &&  A[11];   // 0x828800 controls (paddles)
    inp_cs    = reg_blk &&  A[12] && ~A[11];   // 0x829000 inputs
    aud_cs    = reg_blk &&  A[12] &&  A[11];   // 0x829801 audio response

    // 7M LS138 strobe sub-decode by A[10:8]
    wdog_cs   = reg_wr && A[10:8]==3'd0;        // 0x828000
    audwr_cs  = reg_wr && A[10:8]==3'd1;        // 0x828101
    z300_cs   = reg_wr && A[10:8]==3'd3;        // 0x828300 + 10K LS139 sub
    sreset_cs = reg_wr && A[10:8]==3'd4;        // 0x828400
    unlock_cs = reg_wr && A[10:8]==3'd5;        // 0x828500 (eeprom unlock; not needed in BRAM)
    hscr_cs   = reg_wr && A[10:8]==3'd6;        // 0x828600
    vscr_cs   = reg_wr && A[10:8]==3'd7;        // 0x828700
    // 0x8283xx sub-block by A[7:6] (10K LS139)
    intline_cs= z300_cs && A[7:6]==2'b01;       // 0x828340 interrupt_scan
    slip_cs   = z300_cs && A[7:6]==2'b10;       // 0x828380 slip
    irqack_cs = z300_cs && A[7:6]==2'b11;       // 0x8283c0 scanline IRQ ack
end

// register latches (LS273-style; harmless during boot, consumed by video later)
wire wr = ~RnW;
always @(posedge clk) begin
    if( rst ) begin
        xscroll<=0; yscroll<=0; slip<=0; intensity<=0;
        snd_cmd<=0; snd_cmdwr<=0; snd_rstn<=1;
    end else begin
        snd_cmdwr <= 0;
        if( hscr_cs  & wr ) xscroll   <= cpu_dout;
        if( vscr_cs  & wr ) yscroll   <= cpu_dout;
        if( slip_cs  & wr ) slip      <= cpu_dout;
        if( z300_cs & A[7:6]==2'b00 & wr ) intensity <= ~cpu_dout[4:0]; // /ZLATCH intensity
        if( audwr_cs & wr & ~LDSn ) begin snd_cmd <= cpu_dout[7:0]; snd_cmdwr <= 1; end
        if( sreset_cs& wr ) snd_rstn  <= cpu_dout[0];
    end
end

// Scanline interrupt (CPU sheet): the 9-bit programmed line (BD8:0, latched on /INTLINE — low 6
// in the 20K LS174A, high 3 in the 7B SOS-1 spare latch) is compared EQUAL against the V counter
// by the cascaded 21K/22L LS85; the 15M LS74 latches the match and is cleared by /IRQACK. /IRQ -> IPL0.
reg  [8:0] intline_reg;
reg  [8:0] vdump_q;
reg        scanline_irq;
always @(posedge clk) begin
    if( rst ) intline_reg <= 0;
    else if( intline_cs & wr ) intline_reg <= cpu_dout[8:0];
end
always @(posedge clk) begin
    vdump_q <= vdump;
    if( rst )                  scanline_irq <= 0;
    else if( irqack_cs & wr )  scanline_irq <= 0;                  // 0x8283c0 ack
    else if( vdump!=vdump_q && vdump==intline_reg ) scanline_irq <= 1;  // V counter reached the line
end

// ---- inputs ---------------------------------------------------------------
// FF8800 (controls): paddle quadrature + throw, ACTIVE LOW. Idle = all 1.
// FF9000 (inputs), per the schematic memory map — all "0 = true", so NO inversion:
//   b12 self-test switch (0=ON; jtframe `service` is active-low, idle=1)
//   b13 HBLANK (0=true) = LHBL   b14 VBLANK (0=true) = LVBL
//   b15 sound-comm latch full (0=FULL) — no sound yet, report "not full" = 1
reg [15:0] ctl_din, inp_din;
always @* begin
    ctl_din = 16'hffff;   // TODO: map paddle quadrature (LETA/quad) — boot reads idle
    inp_din = 16'hffff;
    inp_din[12] = service;
    inp_din[13] = LHBL;
    inp_din[14] = LVBL;
    inp_din[15] = 1'b1;
end

always @(posedge clk) HALTn <= dip_pause & ~rst;

// combinational read mux: the BRAM/SDRAM outputs are already registered, so an extra
// cpu_din register only adds a read-after-write skew window (intermittent stale reads
// in the POST RAM walk). Read them straight.
always @* begin
    cpu_din  = rom_cs    ? rom_data            :
               ram_cs    ? ram_dout            :
               pf_cs     ? pf_dout             :
               al_cs     ? al_dout             :
               mob_cs    ? mob_dout            :
               cram_cs   ? pal_dout            :
               eeprom_cs ? {8'hff, nvram_dout} :
               ctl_cs    ? ctl_din             :
               inp_cs    ? inp_din             :
               aud_cs    ? {8'hff, snd_resp}   :
               16'hffff;
end

`ifdef SIMULATION
// ---- Boot-trace PC dumper (cpu-boot-trace skill) --------------------------
// Logs every program-space read (FC[1:0]==10, RnW=1) as "PC: word" -> a
// superset of MAME's instruction PCs (prefetch). Output: toobin_main_fpga.tr
integer    main_tr;
reg        asn_q, prog_cyc;
reg [23:1] pc_l;
reg [15:0] op_l;
wire       prog_rd = FC[1] & ~FC[0] & RnW;
initial begin
    main_tr = $fopen("toobin_main_fpga.tr","w");
    if( main_tr!=0 ) $fwrite(main_tr,"# toobin main 68000 program-fetch trace (FPGA sim)\n# PC : word\n");
end
// data-space access tracer. Latch addr+value EVERY clk while the access is live so
// the emitted value is the SETTLED bus value (like the PC probe) — capturing only at
// AS-rising is wrong: ram_cs has dropped and cpu_din shows the mux else-branch.
integer    data_tr;
reg        dcyc, dwr;
reg [23:1] da_l;
reg [15:0] dd_l;
wire       data_sp = FC[0] & ~FC[1];          // data space (user/supervisor)
wire       ramreg  = ram_cs|al_cs|mob_cs|pf_cs|cram_cs|eeprom_cs;
initial    data_tr = $fopen("toobin_data.tr","w");
always @(posedge clk) begin
    asn_q <= ASn;
    if( !ASn && prog_rd ) begin
        prog_cyc <= 1;
        pc_l     <= A;
        op_l     <= cpu_din;
    end
    if( !ASn && data_sp && ramreg ) begin
        dcyc <= 1; dwr <= ~RnW; da_l <= A;
        dd_l <= RnW ? cpu_din : cpu_dout;     // latest settled value while access is live
    end
    if( !asn_q && ASn ) begin
        if( prog_cyc && main_tr!=0 ) $fwrite(main_tr,"%06X: %04X\n",{pc_l,1'b0},op_l);
        if( dcyc && data_tr!=0 )
            $fwrite(data_tr,"%s %06X %04X\n", dwr?"W":"R", {da_l,1'b0}, dd_l);
        prog_cyc <= 0; dcyc <= 0;
    end
end
final begin if(main_tr!=0)$fclose(main_tr); if(data_tr!=0)$fclose(data_tr); end
`endif

jtframe_68kdtack_cen #(.W(6),.RECOVERY(1)) u_dtack(
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
    .num        ( 5'd1      ),   // 48/6 = 8 MHz
    .den        ( 6'd6      ),
    .DTACKn     ( dtackn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       ( fave      ),
    .fworst     (           )
);

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .RESETn     (             ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),

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
    .HALTn      ( HALTn       ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    .DTACKn     ( dtackn      ),
    .IPLn       ( IPLn        )
);
`else
    initial rom_cs = 0;
    assign rom_addr=0, cpu_addr=0, cpu_dsn=3, cpu_dout=0, cpu_rnw=1,
           ram_we=0, pf_we=0, al_we=0, mob_we=0, pal_we=0, nvram_we=0, st_dout=0;
    initial begin
        eeprom_cs=0; pf_cs=0; al_cs=0; mob_cs=0; cram_cs=0;
        xscroll=0; yscroll=0; slip=0; intensity=0;
        snd_cmd=0; snd_cmdwr=0; snd_rstn=1;
    end
`endif
endmodule
