/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Author: Rafael Eduardo Paiva Feener. Copyright: Jose Tejada Gomez
 * Version: 1.0
 * Date: 17-6-2026 */

module jtmoo_main(
    input                rst,
    input                clk, // 48 MHz
    input                cen_16,
    input                LVBL,
    input                bucky,
    input                int1,

    output        [20:1] main_addr,
    output        [ 1:0] ram_dsn,
    output        [15:0] cpu_dout,
    // 8-bit interface
    output               cpu_we,
    output reg           pal_cs,
    output reg           pcu_cs,
    output reg           col_cs,
    // Sound interface
    output               pair_we,   // K054321 PAIR~{CS} write
    input         [ 7:0] pair_dout, // K054321 PAIR~{CS} read
    output reg           sndon,     // K054321 SDON irq trigger

    output reg           rom_cs,
    output reg           ram_cs,
    output reg           vram_cs,
    output reg           obj_cs,
    output reg           scr_cs,

    input         [15:0] oram_dout,
    input         [15:0] vram_dout,
    input         [15:0] pal_dout,
    input         [15:0] ram_dout,
    input         [15:0] rom_data,
    input                ram_ok,
    input                rom_ok,
    input                vdtac,
    input                tile_irqn,
    output               ram_we,

    output reg           cco_cs,
    output               rw,
    input         [ 7:0] vtimer_mmr,

    // video configuration
    output        [ 1:0] oram_we,
    output reg           objreg_cs,
    output reg           scrreg_cs,
    output reg           objcha_n,
    output               rmrd,
    output reg           blnk_sel,
    input                dma_bsy,
    // EEPROM
    output      [ 6:0]   nv_addr,
    input       [ 7:0]   nv_dout,
    output      [ 7:0]   nv_din,
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
wire [23:1] A;
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, RnW, allFC, ASn, VPAn, DTACKn;
wire [ 2:0] FC;
reg  [ 2:0] IPLn;
reg  [ 3:0] dtac_reg=0;
reg         cab_cs, iowr_hi, iowr_lo, HALTn,
            eep_di, eep_clk, eep_cs, intdma_enb,
            sndon_r, pair_cs, reg_cs;
reg  [15:0] cpu_din, cab_dout;
reg  [ 7:0] io_dout;
wire [ 7:0] hip_dout;
wire        eep_rdy, eep_do, bus_cs, bus_busy, BUSn;
wire        dtac_mux, intdma, IPLn1;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif
/* verilator tracing_on */
assign main_addr= A[20:1];
assign ram_dsn  = {UDSn, LDSn};
assign ram_we   = ram_cs & ~RnW & ~&ram_dsn;
assign bus_cs   = rom_cs | ram_cs;
assign bus_busy = (rom_cs & ~rom_ok) | (ram_cs & ~ram_ok);
assign BUSn     = ASn | (LDSn & UDSn);
assign VPAn     = ~vpa;

assign cpu_we   = ~RnW;
assign oram_we  = ~ram_dsn & {2{rw & oram_wr}};

assign st_dout  = 0; //{ rmrd, 1'd0, prio, div8, game_id };
// assign VPAn     = ~&{ FC[1:0], ~ASn };
assign dtac_mux = DTACKn /*| ~vdtac | ~dtac_reg[0]*/;
assign IPLn1    = ~intdma | tile_irqn;
assign pair_we  = pair_cs && !RnW && !LDSn;
// Temporary scroll wrapper does not implement tile ROM readout yet.
assign rmrd     = 1'b0;

assign rw = RnW | prot_wrn;

reg none_cs, hip_cs, io_cs;
reg [1:0] bank;
reg vpa, oram_wr, pre_dtac, prio, dec_en;
always @* begin
    rom_cs   = 0;
    ram_cs   = 0;
    vpa      = 0;
    oram_wr  = 0;
    scr_cs   = 0;
    pre_dtac = 0;
    prio     = 0;
    dec_en   = 0;
    scrreg_cs= 0;
    col_cs   = 0;
    obj_cs   = 0;
    objreg_cs= 0;
    reg_cs   = 0;
    pcu_cs   = 0;
    prot_cs  = 0;
    cco_cs   = 0;
    hip_cs   = 0;
    sndon    = 0;
    pair_cs  = 0;
    vram_cs  = 0; // tilesys_cs
    cab_cs   = 0;
    io_cs    = 0;
    pal_cs   = 0;
    if(!ASn) begin
        if(A[23]) begin
            vpa = 1;
        end else if(A[22:21]==0) begin
            // 055373 - PAL20L10 (from PAL equations)
            casez( A[20:14] )
                7'b110_01??: oram_wr  = 1;     // ORAMWE
                7'b110_1100: pre_dtac = ~BUSn; // PRE_DTACK / tile ROM read window
                7'b110_1000: begin             // LYR_PRIO / tile RAM window
                    prio   = 1;
                    scr_cs = ~BUSn;
                end
                7'b110_00??: ram_cs   = ~BUSn;
                7'b011_0???: dec_en   = 1;     // PALE
                7'b00?_????: rom_cs   = 1;     // ~OE1 in sch
                7'b10?_????: rom_cs   = 1;     // ~OE2 in sch
                7'b111_0???: col_cs   =~BUSn;  // RAMCS in sch // to colmix 054338
                default:;
            endcase
            // o23 = !A[20] | !A[19] | (!A[18] & !A[17])
        end
    end
    if(dec_en) begin
        case (A[16:13])
            4'h0: scrreg_cs = 1;     // ROMCS in sch // to scroll
            4'h1: objreg_cs = 1;     // REG
            4'h2: obj_cs    = 1;     // CRCS
            4'h5: pal_cs    = 1;     // REGCS // to colmix 054338
            4'h6: pcu_cs    = 1;     // PCUCS // to colmix 053251
            4'h7: prot_cs   = ~BUSn; // OBJ_REG_SEL

            4'h8: cco_cs  = ~BUSn; // /CCO
            4'h9: hip_cs  = ~BUSn & bucky; // COLCS
            4'hA: sndon   = ~BUSn; // SDON
            4'hB: pair_cs = ~BUSn; // PAIRCS
            4'hC: vram_cs = ~BUSn; // BNKSCR
            4'hD: cab_cs  = ~BUSn; // IOCS
            4'hE: io_cs   = ~BUSn; // IOCSB
            4'hF: reg_cs  = ~BUSn; // REG_WRITE
            default:;
        endcase
    end
`ifdef SIMULATION
    none_cs = ~BUSn & ~|{rom_cs, ram_cs, pal_cs, io_cs, prot_cs,
        cab_cs, vram_cs, scr_cs, scrreg_cs, obj_cs, objreg_cs, sndon, pcu_cs, reg_cs};
`endif
end

jtframe_edge #(.QSET(0)) u_ff(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .edgeof     ( dma_bsy   ),
    .clr        (~intdma_enb),
    .q          ( intdma    ) // IRQ in schematics
);

always @(posedge clk) begin
    IPLn <= 3'b111;
    if(!intdma)
        IPLn <= 3'b010;
    else if (!int1)
        IPLn <= 3'b011;
    else if (!prot_irqn)
        IPLn <= 3'b100;

    HALTn   <= dip_pause & ~rst;
    cpu_din <= rom_cs  ? rom_data        :
               ram_cs  ? ram_dout        :
               obj_cs  ? oram_dout       :
               (vram_cs | scr_cs | scrreg_cs) ? vram_dout :
               pal_cs  ? pal_dout        :
               reg_cs  ? pal_dout        :
               prot_cs ? prot_din        :
               pair_cs ? {8'd0,pair_dout}:
               io_cs   ? {8'd0,io_dout  }:
               cab_cs  ? cab_dout        : 16'hffff;
end

reg fake_dma=0, cabcs_l;

always @(posedge clk) begin
    if( cpu_cen ) begin
        cabcs_l <= cab_cs;
        if( !cab_cs && !cabcs_l ) fake_dma <= ~fake_dma;
    end
    cab_dout <= A[1] ? { cab_1p[2], joystick3, cab_1p[0], joystick1 }:
                       { cab_1p[3], joystick4, cab_1p[1], joystick2 };
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
        blnk_sel   <= 0;
        dtac_reg   <= 0;
    end else begin
        dtac_reg <= {pre_dtac, dtac_reg[3:1]};
        if(RnW) begin
            if( !LDSn ) { intdma_enb, eep_clk, eep_cs, eep_di } <= {cpu_dout[5],cpu_dout[2:0]};
        end
        if( !UDSn & reg_cs ) begin
            objcha_n <= ~cpu_dout[8];
            blnk_sel <=  cpu_dout[9];
        end
    end
end

/* verilator tracing_on */
wire [23:1] prot_addr;
wire [15:0] prot_dout, prot_din;
wire [ 1:0] prot_dsn;
wire        prot_asn, prot_wrn, prot_irqn,
            prot_brn, prot_bgackn, BGn;
reg         prot_cs;
assign prot_dout  = cpu_din;
assign prot_irqn = 1;
jtriders_tmnt2 u_prot(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen_16        ),

    .cs         ( prot_cs       ),
    .addr       ( main_addr[4:1]),
    .dsn        ( ram_dsn       ),
    .din        ( cpu_dout      ), // = cpu_dout
    .cpu_we     ( cpu_we        ),
    .dtack_n    ( dtac_mux /*DTACKn*/        ),

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

// only used in Bucky O'Hare
jtk054000 u_hip(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cs     ( hip_cs    ),
    .addr   ( A[5:1]    ),
    .we     ( cpu_we    ),
    .din    ( cpu_dout[7:0] ),
    .dout   ( hip_dout  )
);

/* verilator tracing_on */
jt5911 #(.SIMFILE("nvram.bin")) u_eeprom(
    .rst        ( rst       ),
    .clk        ( clk       ),
    // chip interface
    .sclk       ( eep_clk   ),         // serial clock
    .sdi        ( eep_di    ),         // serial data in
    .sdo        ( eep_do    ),         // serial data out
    .rdy        ( eep_rdy   ),
    .scs        ( eep_cs    ),         // chip select, active high. Goes low in between instructions
    // Dump access
    .mem_addr   ( nv_addr   ),
    .mem_din    ( nv_din    ),
    .mem_we     ( nv_we     ),
    .mem_dout   ( nv_dout   ),
    // NVRAM contents changed
    .dump_clr   ( 1'b0      ),
    .dump_flag  (           )
);

// The board seems to control DTACKn with combinational logic
// DTACKn follows ASn with a delay of ~15.6ns
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
    .num        ( 5'd1      ),  // numerator
    .den        ( 6'd3      ),  // denominator, 3 (16MHz)
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
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
    .oEdb       ( cpu_dout    ),


    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( VPAn        ),
    .FC         ( FC          ),

    .BERRn      ( 1'b1        ),
    // Bus arbitrion
    .HALTn      ( HALTn       ),
    .BRn        ( prot_brn    /*1'b1*/),
    .BGACKn     ( prot_bgackn /*1'b1*/),
    .BGn        ( BGn         ),

    .DTACKn     ( dtac_mux    ),
    .IPLn       ( IPLn        ) // VBLANK
);
`else
    reg [7:0] saved[0:0];
    integer f,fcnt=0;

    // initial begin
    //     f=$fopen("other.bin","rb");
    //     if( f!=0 ) begin
    //         fcnt=$fread(saved,f);
    //         $fclose(f);
    //         $display("Read %1d bytes for dimming configuration", fcnt);
    //         {dimmod,dimpol,dim} = {saved[0][5:4],saved[0][2:0]};
    //     end else begin
    //         {dimmod,dimpol,dim} = 0;
    //     end
    // end
    initial begin
        obj_cs    = 0;
        objcha_n  = 1;
        objreg_cs = 0;
        pal_cs    = 0;
        pcu_cs    = 0;
        reg_cs    = 0;
        ram_cs    = 0;
        rom_cs    = 0;
        sndon     = 0;
        vram_cs   = 0;
    end
    assign
        cpu_dout  = 0,
        cpu_we    = 0,
        main_addr = 0,
        ram_dsn   = 0,
        st_dout   = 0,
        nv_addr   = 0,
        nv_din    = 0,
        pair_we   = 0,
        nv_we     = 0;
`endif
endmodule
