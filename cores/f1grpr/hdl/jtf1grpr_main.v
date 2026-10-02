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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 27-8-2026 */

// Main 68000 at 10MHz (XTAL 20/2), IRQ1 on vblank.
//
//   000000-03ffff  ROM
//   100000-2fffff  ROM, "user1"
//   a00000-bfffff  ROM, "user2" - the source the CPU copies into rozgfx
//   c00000-c3ffff  rozgfx  RAM, 2048 tiles of 16x16x4 for the 053936
//   d00000-d01fff  rozvram RAM, 64x64 map          (mirrored at +6000)
//   e00000-e03fff  SPR-1 CG RAM, the tile-code lookup
//   e04000-e07fff  SPR-2 CG RAM
//   f00000-f003ff  SPR-1 VRAM, the 512-word sprite list
//   f10000-f103ff  SPR-2 VRAM
//   ff8000-ffbfff  work RAM
//   ffc000-ffcfff  RAM shared with the sub 68000
//   ffd000-ffdfff  fg VRAM, 8bpp characters
//   ffe000-ffefff  palette
//   fff000 r INPUTS   fff001 w gfxctrl
//   fff002 r WHEEL    fff002-fff005 w fg scroll x/y
//   fff004 r DSW1     fff006 r DSW2
//   fff009 r sound-latch pending  w sound latch
//   fff020-fff023  w GGA
//   fff040-fff05f  w 053936 control      fff050 r DSW3

module jtf1grpr_main(
    input                rst,
    input                clk,
    input                LVBL,
    input                dip_pause,

    // 68000 bus
    output        [21:1] main_addr,
    output        [15:0] main_dout,
    output               main_rnw,
    output        [ 1:0] main_dsn,
    output               rom_cs,
    input         [15:0] rom_data,
    input                rom_ok,
    // a00000-bfffff lives in its own SDRAM bank slot
    output        [20:1] user2_addr,
    output               user2_cs,
    input         [15:0] user2_data,
    input                user2_ok,

    // BRAM chip selects. Byte write enables are built here
    output        [ 1:0] ram_we, shared_we, fgvram_we, pal_we,
                         rozgfx_we, rozvram_we,
                         lut0_we, lut1_we, oram0_we, oram1_we,
    input         [15:0] ram_dout, shared_dout, fgvram_dout, pal_dout,
                         rozgfx_dout, rozvram_dout,
                         lut0_dout, lut1_dout, oram0_dout, oram1_dout,

    // video configuration
    output               gga_cs, gga_we, gga_addr,
    output reg    [ 7:0] gfxctrl,
    output reg           flip,
    output reg    [ 8:0] fg_scrx, fg_scry,
    output reg           roz_we,
    output reg    [ 4:1] roz_addr,

    // sound interface
    output reg    [ 7:0] snd_latch,
    output reg           snd_wr,
    input                snd_pending,

    // cabinet
    input         [ 3:0] cab_1p, coin,
    input         [ 5:0] joystick1, joystick2,
    input         [ 7:0] wheel,
    input                service, tilt, dip_test,
    input         [31:0] dipsw
);

`ifndef NOMAIN
// 10MHz (XTAL 20/2) out of clk48 = 57.272720MHz (pll7159)
localparam [6:0] CEN_NUM = 7'd11;
localparam [7:0] CEN_DEN = 8'd63;    // 57.272720 * 11/63 = 9.999999MHz

wire [23:1] A;
reg  [15:0] cpu_din;
wire [ 2:0] cpu_fc;
wire        cpu_as_n, cpu_uds_n, cpu_lds_n, cpu_rnw;
wire        cen10, cen10b, dtack_n, inta_n, irq_n;
wire        bus_cs, bus_busy, cpu_bus, lo_we, hi_we;
wire        ram_cs, shared_cs, fgvram_cs, pal_cs, rozgfx_cs, rozvram_cs;
wire        lut0_cs, lut1_cs, oram0_cs, oram1_cs;
wire        io_cs, ffblk;
reg  [15:0] cab_dout;
wire        rom_ok_dly, user2_ok_dly;

assign main_addr  = A[21:1];
assign user2_addr = A[20:1];
assign main_rnw   = cpu_rnw;
assign main_dsn   = { cpu_uds_n, cpu_lds_n };

// DSn delimits writes; reads start as soon as /AS falls so the data is
// ready in time for /DTACK
assign cpu_bus = ~cpu_as_n && (cpu_rnw || main_dsn!=2'b11);
assign hi_we   = ~cpu_rnw & ~cpu_uds_n;
assign lo_we   = ~cpu_rnw & ~cpu_lds_n;

// Partial decode on A[23:20]: 0 is the boot ROM, 1-2 user1, a-b user2. Both
// ROM ranges are one SDRAM region kept at the 68000 offsets, so the address
// is a plain wire and the 768kB hole between them just goes unused
assign ffblk     = &A[23:16];
assign rom_cs    = cpu_bus & (A[23:18]==6'd0 ||              // 000000-03ffff
                              A[23:21]==3'b000 && A[20] ||  // 100000-1fffff
                              A[23:20]==4'h2);              // 200000-2fffff
assign user2_cs  = cpu_bus & A[23:21]==3'b101;              // a00000-bfffff
assign rozgfx_cs = cpu_bus & A[23:20]==4'hc & A[19:18]==2'd0;   // c00000-c3ffff
// mirror(0x6000) is a bit mask: A13 and A14 are both don't care, so the
// 8kB map repeats at d00000/d02000/d04000/d06000
assign rozvram_cs= cpu_bus & A[23:16]==8'hd0 & ~A[15];      // d00000-d07fff
assign lut0_cs   = cpu_bus & A[23:16]==8'he0 & A[15:14]==2'b00; // e00000-e03fff
assign lut1_cs   = cpu_bus & A[23:16]==8'he0 & A[15:14]==2'b01; // e04000-e07fff
assign oram0_cs  = cpu_bus & A[23:16]==8'hf0 & A[15:10]==6'd0;  // f00000-f003ff
assign oram1_cs  = cpu_bus & A[23:16]==8'hf1 & A[15:10]==6'd0;  // f10000-f103ff
assign ram_cs    = cpu_bus & ffblk & A[15:14]==2'b10;       // ff8000-ffbfff
assign shared_cs = cpu_bus & ffblk & A[15:12]==4'hc;
assign fgvram_cs = cpu_bus & ffblk & A[15:12]==4'hd;
assign pal_cs    = cpu_bus & ffblk & A[15:12]==4'he;
assign io_cs     = cpu_bus & ffblk & A[15:8]==8'hf0;   // fff000-fff0ff

// GGA at fff020, write only, low byte of the word. A[1] picks data / address
assign gga_cs    = io_cs & A[7:2]==6'b0010_00;         // fff020-fff023
assign gga_we    = gga_cs & lo_we;
assign gga_addr  = A[1];

assign ram_we    = { ram_cs    & hi_we, ram_cs    & lo_we };
assign shared_we = { shared_cs & hi_we, shared_cs & lo_we };
assign fgvram_we = { fgvram_cs & hi_we, fgvram_cs & lo_we };
assign pal_we    = { pal_cs    & hi_we, pal_cs    & lo_we };
assign rozgfx_we = { rozgfx_cs & hi_we, rozgfx_cs & lo_we };
assign rozvram_we= { rozvram_cs& hi_we, rozvram_cs& lo_we };
assign lut0_we   = { lut0_cs   & hi_we, lut0_cs   & lo_we };
assign lut1_we   = { lut1_cs   & hi_we, lut1_cs   & lo_we };
assign oram0_we  = { oram0_cs  & hi_we, oram0_cs  & lo_we };
assign oram1_we  = { oram1_cs  & hi_we, oram1_cs  & lo_we };

// The region jumper only has six legal codes and the vblank IRQ soft-resets
// the game on anything else, so the MRA carries a 3-bit index instead
reg [4:0] region;
always @* begin
    case( dipsw[26:24] )
        3'd0: region = 5'h00;   // Japan
        3'd1: region = 5'h01;   // USA & Canada
        3'd2: region = 5'h02;   // Korea
        3'd3: region = 5'h04;   // Hong Kong
        3'd4: region = 5'h08;   // Taiwan
        default: region = 5'h10;// World
    endcase
end

// Cabinet reads. jtframe delivers the joystick as 0=right 1=left 2=down
// 3=up 4+=buttons, active low; the INPUTS port wants UDLR then brake,
// accelerator, so the bottom nibble is reversed by hand
always @* begin
    cab_dout = 16'hffff;
    case( A[7:1] )
        7'h00: cab_dout = { 1'b1, ~service, 3'b111, cab_1p[0], coin[1:0],
                            2'b11, joystick1[4], joystick1[5],
                            joystick1[0], joystick1[1],
                            joystick1[2], joystick1[3] };
        7'h01: cab_dout = { 8'h0, wheel };
        // DSW1 is a full 16-bit port; DSW2 uses its high byte only and
        // DSW3 the low 5 bits. Bits with no switch behind them read as 0:
        // the boot code compares the whole DSW3 byte against the region
        // list and resets on every vblank if it does not match
        7'h02: cab_dout = dipsw[15:0];
        7'h03: cab_dout = { dipsw[23:16], 8'h0 };
        // fff009: the sound latch pending flag, 0xff or 0x00
        7'h04: cab_dout = { 8'hff, {8{snd_pending}} };
        7'h28: cab_dout = { 11'h0, region };       // DSW3 at fff050
        default:;
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        gfxctrl   <= 0;
        flip      <= 0;
        fg_scrx   <= 0;
        fg_scry   <= 0;
        snd_latch <= 0;
        snd_wr    <= 0;
        roz_we    <= 0;
        roz_addr  <= 0;
    end else begin
        snd_wr <= 0;
        roz_we <= 0;
        if( io_cs && !cpu_rnw ) begin
            case( A[7:1] )
                // MAME keeps bit 5 out of gfxctrl (it is the flip bit) and the
                // priority test compares the result against zero
                7'h00: if( lo_we ) begin
                    gfxctrl <= main_dout[7:0] & 8'hdf;
                    flip    <= main_dout[5];
                end
                7'h01: fg_scrx <= main_dout[8:0];
                7'h02: fg_scry <= main_dout[8:0];
                7'h04: if( lo_we ) begin snd_latch <= main_dout[7:0]; snd_wr <= 1; end
                default:;
            endcase
            // 053936 control, fff040-fff05f
            if( A[7:5]==3'b010 ) begin
                roz_we   <= 1;
                roz_addr <= A[4:1];
            end
        end
    end
end

always @(posedge clk) begin
    cpu_din <= rom_cs    ? rom_data     :
               user2_cs  ? user2_data   :
               ram_cs    ? ram_dout     :
               shared_cs ? shared_dout  :
               fgvram_cs ? fgvram_dout  :
               pal_cs    ? pal_dout     :
               rozgfx_cs ? rozgfx_dout  :
               rozvram_cs? rozvram_dout :
               lut0_cs   ? lut0_dout    :
               lut1_cs   ? lut1_dout    :
               oram0_cs  ? oram0_dout   :
               oram1_cs  ? oram1_dout   :
               io_cs     ? cab_dout     : 16'hffff;
end

assign bus_cs   = rom_cs | user2_cs;
assign bus_busy = (rom_cs & ~rom_ok_dly) | (user2_cs & ~user2_ok_dly);

jtframe_okdly #(.W(1)) u_romok(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .cs     ( rom_cs        ),
    .ok     ( rom_ok        ),
    .ok_dly ( rom_ok_dly    )
);

jtframe_okdly #(.W(1)) u_user2ok(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .cs     ( user2_cs      ),
    .ok     ( user2_ok      ),
    .ok_dly ( user2_ok_dly  )
);

fx68k u_cpu(
    .clk        ( clk       ),
    .enPhi1     ( cen10     ),
    .enPhi2     ( cen10b    ),
    .extReset   ( rst       ),
    .pwrUp      ( rst       ),
    .HALTn      ( dip_pause ),
    .BERRn      ( 1'b1      ),
    .oRESETn    (           ),
    .oHALTEDn   (           ),
    .eab        ( A         ),
    .iEdb       ( cpu_din   ),
    .oEdb       ( main_dout ),
    .ASn        ( cpu_as_n  ),
    .eRWn       ( cpu_rnw   ),
    .UDSn       ( cpu_uds_n ),
    .LDSn       ( cpu_lds_n ),
    .DTACKn     ( dtack_n   ),
    .BRn        ( 1'b1      ),
    .BGn        (           ),
    .BGACKn     ( 1'b1      ),
    .E          (           ),
    .VMAn       (           ),
    .VPAn       ( inta_n    ),
    .FC0        ( cpu_fc[0] ),
    .FC1        ( cpu_fc[1] ),
    .FC2        ( cpu_fc[2] ),
    .IPL0n      ( irq_n     ),
    .IPL1n      ( 1'b1      ),
    .IPL2n      ( 1'b1      )
);

assign inta_n = ~&{ cpu_fc, ~cpu_as_n };

jtframe_virq u_virq(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .LVBL       ( LVBL      ),
    .dip_pause  ( dip_pause ),
    .skip_en    ( 1'b0      ),
    .skip_but   ( 1'b0      ),
    .clr        ( ~inta_n   ),
    .custom_in  ( 1'b0      ),
    .blin_n     ( irq_n     ),
    .blout_n    (           ),
    .custom_n   (           )
);

jtframe_68kdtack_cen #(.W(8),.MFREQ(`JTFRAME_MCLK/2000)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cen10     ),
    .cpu_cenb   ( cen10b    ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( cpu_as_n  ),
    .DSn        ( main_dsn  ),
    .num        ( CEN_NUM   ),
    .den        ( CEN_DEN   ),
    .DTACKn     ( dtack_n   ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       (           ),
    .fworst     (           )
);

`else
// Scene replay: hold the bus idle with cpu_rnw high and every write enable low
assign main_addr = 0;
assign main_dout = 0;
assign main_rnw  = 1;
assign main_dsn  = 2'b11;
assign rom_cs    = 0;
assign user2_addr= 0;
assign user2_cs  = 0;
assign gga_cs    = 0;
assign gga_we    = 0;
assign gga_addr  = 0;
assign ram_we    = 0;
assign shared_we = 0;
assign fgvram_we = 0;
assign pal_we    = 0;
assign rozgfx_we = 0;
assign rozvram_we= 0;
assign lut0_we   = 0;
assign lut1_we   = 0;
assign oram0_we  = 0;
assign oram1_we  = 0;

// Scene replay: gfxctrl and the fg scroll live in 68000 registers, not RAM,
// so dump_burst.lua captures them into the tail of the dump and rest2bin.sh
// splits them out as regs.bin
integer fregs, k;
reg [7:0] rb [0:7];

initial begin
    gfxctrl = 0; flip = 0; fg_scrx = 0; fg_scry = 0;
    snd_latch = 0; snd_wr = 0; roz_we = 0; roz_addr = 0;
    for( k=0; k<8; k=k+1 ) rb[k] = 8'h0;
    fregs = $fopen("regs.bin","rb");
    if( fregs == 0 ) begin
        $display("%m WARNING: regs.bin not found, video registers stay at zero");
    end else begin
        k = 0;
        while( k<8 && !$feof(fregs) ) begin
            rb[k] = $fgetc(fregs);
            k = k+1;
        end
        $fclose(fregs);
        gfxctrl = rb[0];
        flip    = rb[0][5];
        fg_scrx = { rb[1][0], rb[2] };
        fg_scry = { rb[3][0], rb[4] };
        $display("%m scene regs: gfxctrl=%02X scrx=%03X scry=%03X",
                 gfxctrl, fg_scrx, fg_scry);
    end
end
`endif

endmodule
