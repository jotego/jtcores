/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Author: Rafael Eduardo Paiva Feener. Copyright: Jose Tejada Gomez
 * Version: 1.0
 * Date: 17-6-2026 */

module jtmoo_main(
    input                rst,
    input                clk, // 48 MHz
    input                cen_16,
    input                int1,

    output        [20:1] main_addr,
    output        [ 1:0] ram_dsn,
    output        [15:0] cpu_dout,
    output               cpu_we,
    output reg           pal_cs,   // palette RAM, seen through the K054338
    output reg           pcu_cs,   // K053251
    output reg           k338_cs,  // K054338 registers
    // Sound interface
    output               pair_we,   // K054321 PAIR~{CS} write
    input         [ 7:0] pair_dout, // K054321 PAIR~{CS} read
    output reg           sndon,     // K054321 SDON irq trigger

    output reg           rom_cs,
    output reg           ram_cs,
    output reg           vram_cs,
    output               oram_cs,  // object RAM CPU window, 0x190000-0x19FFFF
    output reg           scr_cs,

    input         [15:0] oram_dout,
    input         [15:0] vram_dout,
    input         [15:0] pal_dout,
    input         [15:0] ram_dout,
    input         [15:0] rom_data,
    input                ram_ok,
    input                rom_ok,
    input                vdtac,
    output               ram_we,

    output reg           cco_cs,
    output               rw,
    input         [ 7:0] vtimer_mmr,

    // video configuration
    output        [ 1:0] oram_we,
    output reg           objreg_cs,
    output reg           scrreg_cs,
    output reg           objcha_n,
    output reg           rmrd_cs,  // graphics ROM read-back window
    input                dma_bsy,
    // EEPROM
    output        [ 6:0] nv_addr,
    input         [ 7:0] nv_dout,
    output        [ 7:0] nv_din,
    output               nv_we,
    // Cabinet
    input         [ 6:0] joystick1,
    input         [ 6:0] joystick2,
    input         [ 6:0] joystick3,
    input         [ 6:0] joystick4,
    input         [ 3:0] cab_1p,
    input         [ 3:0] coin,
    input         [ 3:0] service,
    input         [ 3:0] dipsw,
    input                dip_pause,
    input                dip_test,
    output        [ 7:0] st_dout,
    input         [ 7:0] debug_bus
);
`ifndef NOMAIN
wire [23:1] A, a_mx, prot_addr;
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, RnW, ASn, VPAn, DTACKn, asn_mx;
wire [ 2:0] FC;
reg  [ 2:0] IPLn;
reg         cab_cs, HALTn, io_cs, obj_cs, none_cs,
            eep_di, eep_clk, eep_cs, intdma_enb,
            pair_cs, reg_cs, prot_cs, vpa, oram_wr, dec_en;
reg  [15:0] cpu_din, cab_dout, cur_ctrl2;
reg  [ 7:0] io_dout;
wire        eep_rdy, eep_do, bus_cs, bus_busy, BUSn;
wire        intdma;
wire [15:0] cpu_dout_68k, prot_dout, prot_din, prot_regdout;
wire [ 1:0] dsn_mx, prot_dsn;
wire        prot_asn, prot_wrn, prot_brn, prot_bgackn, BGn;

// 053990 takes the bus for its DMA, same as jtriders_main
assign a_mx     = prot_bgackn ? A            : prot_addr;
assign asn_mx   = prot_bgackn ? ASn          : prot_asn;
assign dsn_mx   = prot_bgackn ? {UDSn, LDSn} : prot_dsn;
assign rw       = prot_bgackn ? RnW          : prot_wrn;

assign main_addr= a_mx[20:1];
assign ram_dsn  = dsn_mx;
assign ram_we   = ram_cs & ~rw & ~&ram_dsn;
assign bus_cs   = rom_cs | ram_cs | rmrd_cs;
assign bus_busy = (rom_cs & ~rom_ok) | (ram_cs & ~ram_ok) | (rmrd_cs & ~vdtac);
assign BUSn     = asn_mx | (dsn_mx[1] & dsn_mx[0]);
assign VPAn     = ~vpa;

assign cpu_we   = prot_bgackn ? ~RnW : ~prot_wrn;
assign cpu_dout = prot_bgackn ? cpu_dout_68k : prot_din;
assign oram_we  = ~ram_dsn & {2{~rw & oram_wr}};
assign oram_cs  =  oram_wr & ~BUSn;
assign prot_dout= cpu_din;

assign st_dout  = { 1'b0, prot_bgackn, intdma, int1, dma_bsy, IPLn };
assign pair_we  = pair_cs && !RnW && !LDSn;

always @* begin
    rom_cs   = 0;
    ram_cs   = 0;
    rmrd_cs  = 0;
    vpa      = 0;
    oram_wr  = 0;
    scr_cs   = 0;
    dec_en   = 0;
    scrreg_cs= 0;
    k338_cs  = 0;
    obj_cs   = 0;
    objreg_cs= 0;
    reg_cs   = 0;
    pcu_cs   = 0;
    prot_cs  = 0;
    cco_cs   = 0;
    sndon    = 0;
    pair_cs  = 0;
    vram_cs  = 0;
    cab_cs   = 0;
    io_cs    = 0;
    pal_cs   = 0;
    if(!ASn && A[23]) vpa = 1;
    if(!asn_mx && a_mx[22:21]==0) begin
        // 055373 PAL
        casez( a_mx[20:14] )
            7'b110_01??: oram_wr  = 1;     // ORAMWE
            7'b110_1100: rmrd_cs  = ~BUSn; // PRE_DTACK
            7'b110_1000: scr_cs   = ~BUSn; // LYR_PRIO
            7'b110_00??: ram_cs   = ~BUSn;
            7'b011_0???: dec_en   = 1;     // PALE
            7'b00?_????: rom_cs   = 1;     // ~OE1
            7'b10?_????: rom_cs   = 1;     // ~OE2
            7'b111_0000: pal_cs   =~BUSn;  // RAMCS
            default:;
        endcase
    end
    if(dec_en) begin
        case (a_mx[16:13])
            4'h0: scrreg_cs = ~BUSn; // ROMCS
            4'h1: objreg_cs = ~BUSn; // REG
            4'h2: obj_cs    = ~BUSn; // CRCS
            4'h5: k338_cs   = 1;     // REGCS
            4'h6: pcu_cs    = 1;     // PCUCS
            4'h7: prot_cs   = ~BUSn; // OBJ_REG_SEL
            4'h8: cco_cs    = ~BUSn & ~dsn_mx[0]; // CCO, only DB0-7 connected
            4'hA: sndon     = ~BUSn; // SDON
            4'hB: pair_cs   = ~BUSn; // PAIRCS
            4'hC: vram_cs   = ~BUSn; // BNKSCR
            4'hD: cab_cs    = ~BUSn; // IOCS
            4'hE: io_cs     = ~BUSn; // IOCSB
            4'hF: reg_cs    = ~BUSn; // REG_WRITE
            default:;
        endcase
    end
`ifdef SIMULATION
    none_cs = ~BUSn & ~|{rom_cs, ram_cs, pal_cs, io_cs, prot_cs, k338_cs, rmrd_cs,
        cab_cs, vram_cs, scr_cs, scrreg_cs, obj_cs, objreg_cs, sndon, pcu_cs, reg_cs, cco_cs};
`endif
end

// IRQ5 latches at DMA end
jtframe_edge #(.QSET(0)) u_ff(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .edgeof     (~dma_bsy   ),
    .clr        (~intdma_enb),
    .q          ( intdma    )
);

always @(posedge clk) begin
    IPLn <= 3'b111;
    if(!intdma)
        IPLn <= 3'b010;
    else if (int1)
        IPLn <= 3'b011;

    HALTn   <= dip_pause & ~rst;
    cpu_din <= rom_cs  ? rom_data        :
               ram_cs  ? ram_dout        :
               (obj_cs|oram_cs) ? oram_dout :
               (vram_cs | scr_cs | scrreg_cs | rmrd_cs) ? vram_dout :
               (pal_cs|k338_cs) ? pal_dout :
               reg_cs  ? cur_ctrl2       :
               cco_cs  ? {8'd0,vtimer_mmr}:
               prot_cs ? prot_regdout    :
               pair_cs ? {8'd0,pair_dout}:
               io_cs   ? {8'd0,io_dout  }:
               cab_cs  ? cab_dout        : 16'hffff;
end

always @(posedge clk) begin
    cab_dout <= A[1] ? { cab_1p[3], joystick4, cab_1p[1], joystick2 }:
                       { cab_1p[2], joystick3, cab_1p[0], joystick1 };
    io_dout  <= A[1] ? { dipsw, dip_test, 1'b1, eep_rdy, eep_do }:
                       { service , coin };
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        eep_di  <= 0;
        eep_cs  <= 0;
        eep_clk <= 0;
        intdma_enb <= 1;
        objcha_n   <= 1;
        cur_ctrl2  <= 0;
    end else begin
        if( reg_cs & ~rw ) begin
            if( !dsn_mx[0] ) begin
                cur_ctrl2[ 7:0] <= cpu_dout[7:0];
                { intdma_enb, eep_clk, eep_cs, eep_di } <= {cpu_dout[5],cpu_dout[2:0]};
            end
            if( !dsn_mx[1] ) begin
                cur_ctrl2[15:8] <= cpu_dout[15:8];
                objcha_n <= ~cpu_dout[8];
            end
        end
    end
end

jtmoo_prot u_prot(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen_16        ),

    .cs         ( prot_cs       ),
    .addr       ( main_addr[4:1]),
    .dsn        ( ram_dsn       ),
    .din        ( cpu_dout      ),
    .cpu_we     ( cpu_we        ),
    .dtack_n    ( DTACKn        ),
    .dout       ( prot_regdout  ),

    // DMA
    .bus_asn    ( prot_asn      ),
    .bus_addr   ( prot_addr     ),
    .bus_din    ( prot_din      ),
    .bus_dout   ( prot_dout     ),
    .bus_dsn    ( prot_dsn      ),
    .bus_wrn    ( prot_wrn      ),

    .BRn        ( prot_brn      ),
    .BGn        ( BGn           ),
    .BGACKn     ( prot_bgackn   )
);

/* verilator tracing_off */
jt5911 #(.SIMFILE("nvram.bin")) u_eeprom(
    .rst        ( rst       ),
    .clk        ( clk       ),
    // chip interface
    .sclk       ( eep_clk   ),
    .sdi        ( eep_di    ),
    .sdo        ( eep_do    ),
    .rdy        ( eep_rdy   ),
    .scs        ( eep_cs    ),
    // Dump access
    .mem_addr   ( nv_addr   ),
    .mem_din    ( nv_din    ),
    .mem_we     ( nv_we     ),
    .mem_dout   ( nv_dout   ),
    // NVRAM contents changed
    .dump_clr   ( 1'b0      ),
    .dump_flag  (           )
);

/* verilator tracing_on */
// rmrd_cs: 4-stage 74LS174 wait chain at 16 MHz
jtframe_68kdtack_cen #(.W(6),.RECOVERY(1)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( asn_mx    ),
    .DSn        ( dsn_mx    ),
    .num        ( 5'd1      ),  // numerator
    .den        ( 6'd3      ),  // denominator, 3 (16MHz)
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( rmrd_cs   ),
    // Frequency report
    .fave       (           ),
    .fworst     (           )
);

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .RESETn     (             ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),

    // Buses
    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout_68k),

    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( VPAn        ),
    .FC         ( FC          ),

    .BERRn      ( 1'b1        ),
    // Bus arbitration
    .HALTn      ( HALTn       ),
    .BRn        ( prot_brn    ),
    .BGACKn     ( prot_bgackn ),
    .BGn        ( BGn         ),

    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        )
);
`else
    initial begin
        objcha_n  = 1;
        objreg_cs = 0;
        pal_cs    = 0;
        pcu_cs    = 0;
        k338_cs   = 0;
        rmrd_cs   = 0;
        scr_cs    = 0;
        scrreg_cs = 0;
        cco_cs    = 0;
        ram_cs    = 0;
        rom_cs    = 0;
        sndon     = 0;
        vram_cs   = 0;
    end
    assign
        cpu_dout  = 0,
        cpu_we    = 0,
        main_addr = 0,
        ram_dsn   = 2'b11,
        ram_we    = 0,
        rw        = 1,
        oram_we   = 0,
        st_dout   = 0,
        nv_addr   = 0,
        nv_din    = 0,
        pair_we   = 0,
        oram_cs   = 0,
        nv_we     = 0;
`endif
endmodule
