/*  jtmnymny_main.v — Zaccaria 1B11141 Z80uP I/O board
    Decode follows the 3C LS138 / 4C LS139 / 4D LS155 / 4F LS32 structure.
    GPL3 — see jtcores LICENSE
*/

module jtmnymny_main(
    input               rst,
    input               clk,
    input               cpu_cen,
    input               LVBL,
    // main program ROM (SDRAM)
    output reg          rom_cs,
    output      [15:0]  rom_addr,
    input       [ 7:0]  rom_data,
    input               rom_ok,
    // video section (RAMs live in the video module)
    output      [11:0]  cpu_addr,
    output      [ 7:0]  cpu_dout,
    output              cpu_wrn,
    output reg          vram_cs,      // /SABBKG 6000-67FF
    output reg          attr_cs,      // 6800-683F
    output reg          objram_cs,    // rest of the 6800-68FF page
    output              ram_we,       // 7000-77FF work/NV RAM
    input       [ 7:0]  vram_dout,
    input       [ 7:0]  attr_dout,
    input       [ 7:0]  objram_dout,
    input       [ 7:0]  ram_dout,
    // 3G LS259 latch
    output reg          flip_x,       // VCMA
    output reg          flip_y,       // HCMA
    output reg          ressound,
    output reg          coin_cnt,
    output reg          nmi_mask,     // INTST
    // sound board
    output reg  [ 7:0]  snd_latch,    // 2H LS374, S0..S7
    input               acs,
    // cabinet inputs
    input       [ 7:0]  p1_in,        // 8255 port A
    input       [ 7:0]  p2_in,        // 8255 port B
    input       [ 3:0]  sys_in,       // 8255 PC0-3: 1P start, 2P start, service1, service2
    input       [ 7:0]  coins_in,     // prot2 offset 0 (includes acs on bit 3)
    input       [ 7:0]  dipsw_a,
    input       [ 7:0]  dipsw_b,
    input       [ 7:0]  dipsw_c
);

wire [15:0] A;
wire [ 7:0] cpu_din, ppi_dout;
wire        mreq_n, rfsh_n, rd_n, wr_n, nmi_n, m1_n, iorq_n;
reg         ram_cs, ppi_cs, misc_cs, dsw_cs;   // misc_cs = 6C00 (prot2 + LS259)
wire        objpage_cs;
wire [ 7:4] prot;
reg  [ 7:0] dsw_mux, din_mux;
reg  [ 1:0] dsw_sel;
wire [ 7:0] portc_dout;

assign cpu_addr = A[11:0];
assign cpu_wrn  = wr_n;
// 2764 A12 pin strapped to Z80 A15 on the ROM module
assign rom_addr = { A[14:12], A[15], A[11:0] };
assign nmi_n    = ~(nmi_mask & ~LVBL);
assign ram_we   = ram_cs & ~wr_n;

wire blk_rom = A[14:12]<3'd6;          // LS138: /CS1../CS6, A15 not decoded
wire blk_vid = A[14:12]==3'd6;
wire blk_ram = A[14:12]==3'd7;

always @* begin
    rom_cs    = 0;
    vram_cs   = 0;
    attr_cs   = 0;
    objram_cs = 0;
    misc_cs   = 0;
    dsw_cs    = 0;
    ram_cs    = 0;
    ppi_cs    = 0;
    if( !mreq_n && rfsh_n ) begin
        rom_cs    = blk_rom;
        vram_cs   = blk_vid && !A[11];
        attr_cs   = blk_vid &&  A[11] && !A[10] && !A[8] && A[7:6]==0;
        objram_cs = blk_vid &&  A[11] && !A[10] && !( !A[8] && A[7:6]==0 );
        misc_cs   = blk_vid &&  A[11] &&  A[10] && !A[9];
        dsw_cs    = blk_vid &&  A[11] &&  A[10] &&  A[9];
        ram_cs    = blk_ram && !A[11];               // 2A/2B + 2C/2D (NVRAM half)
        ppi_cs    = blk_ram &&  A[11] && !A[10];
        // 7C00 (A11 & A10) = watchdog kick, no data
    end
end

// PAL16L8 at 1A on the ROM board, dumped equations (doc/pld/equations.md)
jtmnymny_prot u_prot(
    .A      ( A[14:0]   ),
    .rd_n   ( rd_n      ),
    .rfsh_n ( rfsh_n    ),
    .dout   ( prot      )
);

// 3G LS259, E = /WRMIX. Bit order per MAME mainlatch (pin map TBC on sheet 1)
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        { nmi_mask, coin_cnt, ressound, flip_y, flip_x } <= 0;
    end else if( cpu_cen && misc_cs && !wr_n ) begin
        case( A[2:0] )
            3'd0: flip_x   <= cpu_dout[0];
            3'd1: flip_y   <= cpu_dout[0];
            3'd2: ressound <= cpu_dout[0];
            3'd6: coin_cnt <= cpu_dout[0];
            3'd7: nmi_mask <= cpu_dout[0];
            default:;
        endcase
    end
end

// 2H LS374 sound latch, /WRSOUND
always @(posedge clk, posedge rst) begin
    if( rst )
        snd_latch <= 0;
    else if( cpu_cen && dsw_cs && !wr_n )
        snd_latch <= cpu_dout;
end

// DIP row select from 8255 PC4-6 (active low, diode matrix on sheet 2)
always @* begin
    case( portc_dout[6:4] )
        3'b110:  dsw_sel = 2'd0;    // 0xE0 -> SW 5I
        3'b101:  dsw_sel = 2'd1;    // 0xD0 -> SW 4I
        3'b011:  dsw_sel = 2'd2;    // 0xB0 -> SW 3I
        default: dsw_sel = 2'd0;
    endcase
    dsw_mux = dsw_sel==2'd0 ? dipsw_a :
              dsw_sel==2'd1 ? dipsw_b : dipsw_c;
end

always @* begin
    din_mux = rom_cs    ? rom_data    :
              ram_cs    ? ram_dout    :
              vram_cs   ? ( A[10] ? { prot, vram_dout[3:0] } : vram_dout ) :
              attr_cs   ? attr_dout   :
              objram_cs ? objram_dout :
              misc_cs   ? { prot, coins_in[3:0] } :
              dsw_cs    ? dsw_mux     :
              ppi_cs    ? ppi_dout    : 8'hff;
end

jt8255 u_ppi(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .addr       ( A[1:0]        ),
    .din        ( cpu_dout      ),
    .dout       ( ppi_dout      ),
    .rdn        ( rd_n          ),
    .wrn        ( wr_n          ),
    .csn        ( ~ppi_cs       ),
    .porta_din  ( p1_in         ),
    .portb_din  ( p2_in         ),
    .portc_din  ( {4'hf, sys_in}),
    .porta_dout (               ),
    .portb_dout (               ),
    .portc_dout ( portc_dout    )
);

jtframe_z80_romwait u_cpu(
    .rst_n      ( ~rst          ),
    .clk        ( clk           ),
    .cen        ( cpu_cen       ),
    .cpu_cen    (               ),
    .int_n      ( 1'b1          ),
    .nmi_n      ( nmi_n         ),
    .busrq_n    ( 1'b1          ),
    .m1_n       ( m1_n          ),
    .mreq_n     ( mreq_n        ),
    .iorq_n     ( iorq_n        ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    .rfsh_n     ( rfsh_n        ),
    .halt_n     (               ),
    .busak_n    (               ),
    .A          ( A             ),
    .din        ( din_mux       ),
    .dout       ( cpu_dout      ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        )
);

endmodule
