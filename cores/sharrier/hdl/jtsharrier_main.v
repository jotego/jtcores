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

    Author: niknak
    Version: 1.0
    Date: 2-8-2026 */

/*  JTSHARRIER — Space Harrier main 68000 + i8751 MCU bus arbitration

    Memory map (word addresses, A = full 24-bit byte address):
      000000-03FFFF  Program ROM        rom_cs
      040000-043FFF  Work RAM (16K)     ram_cs
      100000-107FFF  Scroll tile RAM    vram_cs  (SDRAM xram; tilemap reads via map1/map2)
      108000-108FFF  Text + scroll regs char_cs  (jts16 tilemap internal BRAM + MMR)
      110000-110FFF  Palette RAM (4K)   pal_cs   (jts16_colmix internal RAM)
      124000-127FFF  Sub shared RAM     subram_cs
      130000-130FFF  Sprite RAM (4K)    objram_cs
      140000-140027  PPI0/inputs/PPI1   ppi0_cs/inp_cs/ppi1_cs
      140031         ADC0804            adc_cs
      C68000-C68FFF  Road RAM           road_cs

    i8751 MCU (315-5163), model from MAME segahang.cpp:
      * INT0 = screen vblank.
      * p1[2:0] inverted = 68000 IPL level (active-low pins).
      * p1[6]->A20, p1[5]->A18, p1[4]->A17, p1[3]->A16 (A19=0) select a window
        into MAIN program space; the MCU reads/writes there via MOVX, byte at a
        time, with 68000 big-endian lane order. It mostly pokes protection into
        work RAM (0x040000-0x043FFF).
      * Arbitration: the MCU bus-requests the 68000 (jtframe_68kdma); when granted
        (BGACKn low) its address/data drive the shared decode below, so the
        existing chip-selects route the access. MCU cen is stalled until SDRAM
        read data is ready (mcu_ok).
*/

module jtsharrier_main(
    input              rst,
    input              clk,
    input              cen,        // 10 MHz enable (from jtframe_frac_cen)
    input              cenb,

    input              vbl,        // vertical blank -> MCU INT0
    input              mcu_en,     // i8751 present (header flag)
    input              mcu_cen,    // 8 MHz MCU enable

    // MCU program ROM load (from the download 'mcu' region)
    input      [11:0]  prog_addr,
    input      [ 7:0]  prog_data,
    input              mcu_we,

    // ROM
    output reg         rom_cs,
    output      [17:1] rom_addr,
    input       [15:0] rom_data,
    input              rom_ok,

    // Chip selects to the rest of the core
    output reg         ram_cs,
    output reg         vram_cs,
    output reg         char_cs,
    output reg         pal_cs,
    output reg         subram_cs,
    output reg         objram_cs,
    output reg         road_cs,
    output reg         ppi0_cs,
    output reg         ppi1_cs,
    output reg         inp_cs,
    output reg         adc_cs,

    // Read-back data from those blocks
    input       [15:0] ram_data,
    input       [15:0] vram_data,
    input              vram_ok,
    input       [15:0] char_dout,   // text/registers readback from jts16 tilemap
    input       [15:0] pal_data,
    input       [15:0] subram_data,
    input       [15:0] obj_data,
    input       [15:0] road_data,
    input       [ 7:0] io_data,    // PPI/inputs/ADC read mux (8-bit, on D0-7)

    // CPU bus out
    output      [15:0] cpu_dout,
    output      [23:1] cpu_addr,
    output             RnW,
    output      [ 1:0] dsn,        // {UDSWn, LDSWn} - WRITE strobes, RnW-qualified
    output             cpu_we
);

// ---------------------------------------------------------------------------
// 68000 core + MCU bus mux
// ---------------------------------------------------------------------------
wire [23:1] A, cpu_A;
wire        ASn, VPAn;
wire        UDSn, LDSn, cpu_rnw;              // muxed (CPU or MCU)
wire        cpu_UDSn, cpu_LDSn, cpu_rnw_raw;  // raw from 68000
wire [15:0] cpu_dout_raw, cpu_din;
wire [ 2:0] FC;
wire [ 2:0] IPLn;
wire        DTACKn, BRn, BGACKn, BGn;

// MCU signals
wire        mcu_bus;                 // MCU owns the bus
wire [ 7:0] mcu_ctrl, mcu_dout;      // p1 output, MOVX write data
wire        mcu_wr, mcu_acc;
wire [15:0] mcu_addr;
reg  [ 7:0] mcu_din;

// MCU window -> main-space high byte (SH: raw address, no resource remap)
wire [23:16] mcu_top = { 3'b000, mcu_ctrl[6], 1'b0, mcu_ctrl[5], mcu_ctrl[4], mcu_ctrl[3] };

assign mcu_bus = mcu_en & ~BGACKn;   // granted the bus

// Address / control mux
assign A       = mcu_bus ? { mcu_top, mcu_addr[15:1] } : cpu_A;
assign cpu_rnw = mcu_bus ? ~mcu_wr        : cpu_rnw_raw;
assign UDSn    = mcu_bus ? ~mcu_addr[0]   : cpu_UDSn;   // odd MCU offset -> even (high) byte
assign LDSn    = mcu_bus ?  mcu_addr[0]   : cpu_LDSn;
assign cpu_dout= mcu_bus ? {2{mcu_dout}}  : cpu_dout_raw;

// IPL to the main CPU. The i8751 owns this line: its INT0 ISR (MCU 0x0345)
// pulses P1.2 low/high once per vblank -> ~P1&7 = 4 = IRQ4.
// Main spins at PC 0x1380 until its first IRQ4, and $40400 is only decremented
// by the IRQ4 handler, so the MCU's ROM self-test is what paces the boot
// countdown.
reg vbl_irq, vbl_hl;
wire inta4 = ~ASn & (&FC) & (cpu_A[3:1]==3'b100);   // 68000 acknowledging IRQ4
always @(posedge clk) begin
    vbl_hl <= vbl;
    if( rst ) vbl_irq <= 1'b0;
    else begin
        if( vbl & ~vbl_hl ) vbl_irq <= 1'b1;        // set on vblank edge
        else if( inta4 )    vbl_irq <= 1'b0;        // cleared when IRQ4 is taken
    end
end
// The MCU drives IPL outright when present. vbl_irq is the fallback for an
// MCU-less build; mcu_en is hardwired 1 here.
assign IPLn = mcu_en ? mcu_ctrl[2:0] : (vbl_irq ? 3'b011 : 3'b111);

wire        inta_n = ~&FC[1:0];            // FC==7 => interrupt acknowledge
assign      VPAn   = ~(~ASn & ~inta_n);    // autovector all interrupts

assign cpu_addr = A;
assign RnW      = cpu_rnw;
// dsn is the RnW-qualified write strobe {UDSWn,LDSWn}, as in jts16_main.v.
wire mcu_syncw = mcu_bus & mcu_wr & mcu_top==8'h04 & mcu_addr==16'h0384;

assign dsn      = { cpu_rnw | UDSn | mcu_syncw, cpu_rnw | LDSn | mcu_syncw };
assign cpu_we   = ~cpu_rnw & ~mcu_syncw;
assign rom_addr = A[17:1];

// DTACK: assert when the selected resource has data (SDRAM waits via *_ok)
wire        bus_cs   = rom_cs | ram_cs | vram_cs | char_cs | pal_cs |
                       subram_cs | objram_cs | road_cs |
                       ppi0_cs | ppi1_cs | inp_cs | adc_cs;
wire        bus_busy = (rom_cs & ~rom_ok) | (vram_cs & ~vram_ok);

// Bus-cycle watchdog. BERRn is tied high and only decoded regions get DTACK, so
// an access to an undecoded address would hang the 68000 mid-cycle. The game
// does reach them -- segahang.cpp no-ops 0x150000 and 0x170000 explicitly -- so
// a long cycle with no completion gets DTACK and finishes as a no-op, reading
// the cpu_din default 0xffff.
reg  [5:0]  bus_to;
wire        cpu_cyc = ~ASn & ~mcu_bus;      // main CPU owns the bus this cycle
always @(posedge clk) begin
    if( ~cpu_cyc )  bus_to <= 6'd0;
    else if( cen )  bus_to <= bus_to + 1'b1;
end
wire        bus_timeout = &bus_to;          // ~63 cen cycles, well past any real wait

assign      DTACKn = ~( (bus_cs & ~bus_busy) | (bus_timeout & ~bus_cs) );

/* verilator lint_off PINMISSING */
jtframe_m68k u_cpu(
    .clk    ( clk         ), .rst     ( rst          ),
    .cpu_cen( cen         ), .cpu_cenb( cenb         ),
    .eab    ( cpu_A       ), .iEdb    ( cpu_din      ), .oEdb ( cpu_dout_raw ),
    .eRWn   ( cpu_rnw_raw ), .LDSn    ( cpu_LDSn     ), .UDSn ( cpu_UDSn     ),
    .ASn    ( ASn         ), .VPAn    ( VPAn         ), .FC   ( FC           ),
    .BERRn  ( 1'b1        ), .HALTn   ( 1'b1         ),
    .BRn    ( BRn         ), .BGACKn  ( BGACKn       ), .BGn  ( BGn          ),
    .DTACKn ( DTACKn      ), .IPLn    ( IPLn         )
);
/* verilator lint_on PINMISSING */

// ---------------------------------------------------------------------------
// Address decode — captured on the active master's strobe
// ---------------------------------------------------------------------------
wire dec_stb = mcu_bus ? mcu_acc : ~ASn;

// vram_cs is qualified with !BUSn, as in jts16_main.v.
wire BUSn = (BGACKn & ASn) | (LDSn & UDSn);

always @(posedge clk) begin
    if( rst ) begin
        rom_cs<=0; ram_cs<=0; vram_cs<=0; char_cs<=0; pal_cs<=0;
        subram_cs<=0; objram_cs<=0; road_cs<=0;
        ppi0_cs<=0; ppi1_cs<=0; inp_cs<=0; adc_cs<=0;
    end else if( dec_stb ) begin
        rom_cs    <= A[23:18]==6'h00;                        // 000000-03FFFF
        ram_cs    <= A[23:14]==10'h010;                      // 040000-043FFF
        vram_cs   <= !BUSn && A[23:16]==8'h10 && A[15]==1'b0; // 100000-107FFF scroll RAM -> xram
        char_cs   <= A[23:12]==12'h108;                      // 108000-108FFF text/regs -> tilemap
        pal_cs    <= A[23:12]==12'h110;                      // 110000-110FFF
        subram_cs <= A[23:14]==10'b0001_0010_01;             // 124000-127FFF
        objram_cs <= A[23:12]==12'h130;                      // 130000-130FFF
        road_cs   <= A[23:12]==12'hC68;                      // C68000-C68FFF
        // Do not qualify these chip selects with !BUSn: that also gates DTACK,
        // which shifts main's timing and audibly changes a sound effect.
        ppi0_cs   <= A[23:8]==16'h1400 && A[6:4]==3'b000;    // 140000-140007
        inp_cs    <= A[23:8]==16'h1400 && A[6:4]==3'b001;    // 140010-140017
        ppi1_cs   <= A[23:8]==16'h1400 && A[6:4]==3'b010;    // 140020-140027
        adc_cs    <= A[23:8]==16'h1400 && A[6:4]==3'b011;    // 140030-140037
    end else begin
        rom_cs<=0; ram_cs<=0; vram_cs<=0; char_cs<=0; pal_cs<=0;
        subram_cs<=0; objram_cs<=0; road_cs<=0;
        ppi0_cs<=0; ppi1_cs<=0; inp_cs<=0; adc_cs<=0;
    end
end

// ---------------------------------------------------------------------------
// CPU data-in mux
// ---------------------------------------------------------------------------
assign cpu_din =
    rom_cs    ? rom_data      :
    ram_cs    ? ram_data      :
    vram_cs   ? vram_data     :
    char_cs   ? char_dout     :
    pal_cs    ? pal_data      :
    subram_cs ? subram_data   :
    objram_cs ? obj_data      :
    road_cs   ? road_data     :
    (ppi0_cs|ppi1_cs|inp_cs|adc_cs) ? {8'hff, io_data} : // I/O on D0-7
    16'hffff;

// ---------------------------------------------------------------------------
// i8751 MCU + bus-request DMA
// ---------------------------------------------------------------------------
wire int0n = ~vbl;                 // vblank -> INT0 (active low)
wire mcu_br = mcu_en & mcu_acc;    // request the bus when the MCU wants to access

// latch the byte the MCU reads while it owns the bus
always @(posedge clk) begin
    if( rst ) mcu_din <= 8'hff;
    else if( mcu_bus ) mcu_din <= LDSn ? cpu_din[15:8] : cpu_din[7:0];
end

// stall the MCU cen until SDRAM read data is ready (work RAM is BRAM = ready)
reg  mcu_ok, BGACKnl;
always @(posedge clk) begin
    BGACKnl <= BGACKn;
    if( !mcu_cen ) mcu_ok <= rst | (BRn & BGACKn) |
                             ( BGACKnl ? 1'b0 : rom_cs ? rom_ok : 1'b1 );
end
wire mcu_gated = mcu_cen & mcu_ok;

jtframe_68kdma u_dma(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .cpu_BRn    ( BRn       ),
    .cpu_BGACKn ( BGACKn    ),
    .cpu_BGn    ( BGn       ),
    .cpu_ASn    ( ASn       ),
    .cpu_DTACKn ( DTACKn    ),
    .dev_br     ( mcu_br    )
);

/* verilator lint_off PINMISSING */
// ROMBIN is simulation-only; on hardware the MCU PROM loads through prom_we.
jtsharrier_8751mcu #(
    .ROMBIN     ( "mcu.bin" ),
    .SYNC_XDATA ( 1 ),
    .SYNC_P1    ( 1 ),
    .SYNC_INT   ( 1 )
) u_mcu(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .cen        ( mcu_gated  ),

    .int0n      ( int0n      ),
    .int1n      ( 1'b1       ),

    .p0_i       ( mcu_din    ),
    .p1_i       ( mcu_ctrl   ),   // feed p1 output back (needed for read-modify of p1)
    .p2_i       ( 8'hff      ),
    .p3_i       ( { 5'h1f, int0n, 2'b11 } ),  // P3.2 = INT0 for jb-style polling

    .p0_o       (            ),
    .p1_o       ( mcu_ctrl   ),
    .p2_o       (            ),
    .p3_o       (            ),

    // external memory (MOVX) -> main bus
    .x_din      ( mcu_din    ),
    .x_dout     ( mcu_dout   ),
    .x_addr     ( mcu_addr   ),
    .x_wr       ( mcu_wr     ),
    .x_acc      ( mcu_acc    ),

    // program ROM load (from download 'mcu' region)
    .clk_rom    ( clk        ),
    .prog_addr  ( prog_addr  ),
    .prom_din   ( prog_data  ),
    .prom_we    ( mcu_we     )
);
/* verilator lint_on PINMISSING */

endmodule
