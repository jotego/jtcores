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
    Date: 10-8-2026 */

module jtpspike_main(
    input                rst,
    input                clk,
    input                LVBL,
    input                dip_pause,

    // 68000 bus
    output        [19:1] main_addr,
    output        [15:0] main_dout,
    output               main_rnw,
    output        [ 1:0] main_dsn,
    output               rom_cs,
    input         [15:0] rom_data,
    input                rom_ok,

    // BRAM chip selects. Byte write enables are built here
    output        [ 1:0] ram_we, vram_we, rascr_we, oram_we, lut_we, pal_we,
    input         [15:0] ram_dout, vram_dout, rascr_dout,
                         oram_dout, lut_dout, pal_dout,
    // second copies, turbofrc onwards. TODO: the turbofrc address map is not
    // decoded yet, so these stay idle. Scene replay does not need it
    output        [ 1:0] ram2_we, vram1_we, oram1_we, lut1_we,
    input         [15:0] ram2_dout, vram1_dout, lut1_dout,

    input                turbofrc, karatblz, aerofgt,

    // video configuration
    output        [31:0] gfxbank,   // eight 4-bit banks
    output reg    [ 2:0] charbank,
    output reg    [ 1:0] objbank,
    output reg           flip,
    output reg    [ 8:0] scry,
    output reg    [ 8:0] scrx1, scry1, scrx0,

    // sound interface
    output               gga_cs, gga_we, gga_addr,
    output reg    [ 7:0] snd_latch,
    output reg           snd_wr,
    input                snd_pending,

    // cabinet
    input         [ 3:0] cab_1p, coin,
    input         [ 7:0] joystick1, joystick2, joystick3, joystick4,
    input                service, tilt, dip_test,
    input         [15:0] dipsw
);

// used by both branches: the real decoder and the scene replay stub
reg  [ 3:0] gfxbank0, gfxbank1;
reg  [15:0] bankw[0:1];

// used by both branches: the scene stub packs gfxbank the same way
wire        two;   // turbofrc family: two layers, two sprite chips
assign      two = turbofrc | aerofgt | karatblz;

`ifndef NOMAIN
// 10 MHz (XTAL 20/2) out of clk48 = 57.272720MHz (pll7159)
localparam [6:0] CEN_NUM = 7'd11;
localparam [7:0] CEN_DEN = 8'd63;    // 57.272720 * 11/63 = 9.999999MHz

wire [23:1] A;
reg  [15:0] cpu_din;
wire [ 2:0] cpu_fc;
wire        cpu_as_n, cpu_uds_n, cpu_lds_n, cpu_rnw;
wire        cen10, cen10b, dtack_n, inta_n, irq_n;
wire        bus_cs, bus_busy, cpu_bus, lo_we, hi_we;
wire        ram_cs, vram_cs, rascr_cs, oram_cs, lut_cs, pal_cs, io_cs;
wire        ram2_cs, vram1_cs, lut1_cs;
wire        ps_rom, ps_ram, ps_lut, ps_vram, ps_oram, ps_rascr, ps_pal, ps_io;
wire        tf_rom, tf_ram, tf_ram2, tf_vram0, tf_vram1, tf_lut0, tf_lut1,
            tf_oram, tf_rascr, tf_pal, tf_io;
wire [ 3:0] tf_hi;
wire        af_rom, af_ram, af_ram2, af_vram0, af_vram1, af_lut0, af_lut1,
            af_oram, af_rascr, af_pal, af_io;
wire        kb_rom, kb_ram, kb_ram2, kb_vram0, kb_vram1, kb_lut0, kb_lut1,
            kb_oram, kb_pal, kb_io;

wire        ffblk;
reg  [15:0] cab_dout;
wire        rom_ok_dly;

assign main_addr = A[19:1];
assign main_rnw  = cpu_rnw;
assign main_dsn  = { cpu_uds_n, cpu_lds_n };

// DSn delimits writes; reads start as soon as /AS falls so the data is
// ready in time for /DTACK
assign cpu_bus   = ~cpu_as_n && (cpu_rnw || main_dsn!=2'b11);
assign hi_we     = ~cpu_rnw & ~cpu_uds_n;
assign lo_we     = ~cpu_rnw & ~cpu_lds_n;

// Address decoding. pspikes uses the full 24 bits, turbofrc masks to 20 and
// packs everything into 0c0000-0fffff
assign ffblk     = &A[23:16];
assign ps_rom    = ~|A[23:18];
assign ps_ram    = A[23:16]==8'h10;
assign ps_lut    = A[23:16]==8'h20 & ~|A[15:14];
assign ps_vram   = ffblk & A[15:12]==4'h8;
assign ps_oram   = ffblk & A[15:12]==4'hc & ~|A[11:10];
assign ps_rascr  = ffblk & A[15:12]==4'hd;
assign ps_pal    = ffblk & A[15:12]==4'he;
assign ps_io     = ffblk & A[15:12]==4'hf;

assign tf_hi     = A[19:16];
assign tf_rom    = tf_hi <  4'hc;
assign tf_ram    = tf_hi == 4'hc;
assign tf_vram0  = tf_hi == 4'hd & A[15:13]==3'd0;
assign tf_vram1  = tf_hi == 4'hd & A[15:13]==3'd1;
assign tf_lut0   = tf_hi == 4'he & A[15:14]==2'd0;
assign tf_lut1   = tf_hi == 4'he & A[15:14]==2'd1;
assign tf_ram2   = tf_hi == 4'hf & A[15:14]==2'b10;          // 0f8000-0fbfff
assign tf_oram   = tf_hi == 4'hf & A[15:11]==5'b11000;       // 0fc000-0fc7ff
assign tf_rascr  = tf_hi == 4'hf & A[15:12]==4'hd;
assign tf_pal    = tf_hi == 4'hf & A[15:11]==5'b11100;       // 0fe000-0fe7ff
assign tf_io     = tf_hi == 4'hf & A[15:12]==4'hf;

// karatblz: no raster RAM, layer 0 scroll X is a register. 64kB sprite LUTs
assign kb_rom    = ~|A[23:19];
assign kb_vram0  = A[19:16]==4'h8 & A[15:13]==3'd0;          // 080000-081fff
assign kb_vram1  = A[19:16]==4'h8 & A[15:13]==3'd1;          // 082000-083fff
assign kb_lut0   = A[19:16]==4'ha;                           // 0a0000-0affff
assign kb_lut1   = A[19:16]==4'hb;                           // 0b0000-0bffff
assign kb_ram    = A[19:16]==4'hc;                           // 0c0000-0cffff
assign kb_ram2   = A[19:16]==4'hf & A[15:14]==2'b10;         // 0f8000-0fbfff
assign kb_oram   = A[19:16]==4'hf & A[15:11]==5'b11000;      // 0fc000-0fc7ff
assign kb_pal    = A[19:16]==4'hf & A[15:11]==5'b11100;      // 0fe000-0fe7ff
assign kb_io     = A[19:16]==4'hf & A[15:12]==4'hf;          // 0ff000-0ff40f

// aerofgtb is turbofrc's layout with palette, I/O and raster RAM moved
assign af_rom    = ~|A[23:19];
assign af_ram    = A[23:16]==8'h0c;
assign af_vram0  = A[23:16]==8'h0d & A[15:13]==3'd0;
assign af_vram1  = A[23:16]==8'h0d & A[15:13]==3'd1;
assign af_lut0   = A[23:16]==8'h0e & A[15:14]==2'd0;
assign af_lut1   = A[23:16]==8'h0e & A[15:14]==2'd1;
assign af_ram2   = A[23:16]==8'h0f & A[15:14]==2'b10;        // 0f8000-0fbfff
assign af_oram   = A[23:16]==8'h0f & A[15:11]==5'b11000;     // 0fc000-0fc7ff
assign af_pal    = A[23:16]==8'h0f & A[15:11]==5'b11010;     // 0fd000-0fd7ff
assign af_io     = A[23:16]==8'h0f & A[15:12]==4'he;         // 0fe000-0fe00f
assign af_rascr  = A[23:16]==8'h0f & A[15:12]==4'hf;         // 0ff000-0fffff

assign rom_cs    = cpu_bus & (karatblz ? kb_rom : aerofgt ? af_rom : turbofrc ? tf_rom   : ps_rom  );
assign ram_cs   = cpu_bus & (karatblz ? kb_ram : aerofgt ? af_ram : turbofrc ? tf_ram : ps_ram);
assign ram2_cs   = cpu_bus & (karatblz ? kb_ram2 : aerofgt ? af_ram2  : turbofrc & tf_ram2 );
assign lut_cs   = cpu_bus & (karatblz ? kb_lut0 : aerofgt ? af_lut0 : turbofrc ? tf_lut0 : ps_lut);
assign lut1_cs   = cpu_bus & (karatblz ? kb_lut1 : aerofgt ? af_lut1  : turbofrc & tf_lut1 );
assign vram_cs  = cpu_bus & (karatblz ? kb_vram0 : aerofgt ? af_vram0 : turbofrc ? tf_vram0 : ps_vram);
assign vram1_cs  = cpu_bus & (karatblz ? kb_vram1 : aerofgt ? af_vram1 : turbofrc & tf_vram1);
assign oram_cs  = cpu_bus & (karatblz ? kb_oram : aerofgt ? af_oram : turbofrc ? tf_oram : ps_oram);
assign rascr_cs = cpu_bus & (aerofgt ? af_rascr : turbofrc ? tf_rascr : ps_rascr);
assign pal_cs   = cpu_bus & (karatblz ? kb_pal : aerofgt ? af_pal : turbofrc ? tf_pal : ps_pal);
assign io_cs    = cpu_bus & (karatblz ? kb_io : aerofgt ? af_io : turbofrc ? tf_io : ps_io);
// GGA is io+0x400 on every game: fff400 pspikes, 0ff400 turbofrc, 0fe400 aerofgtb.
// Write only, low byte of the word (umask 00ff). A[1] picks data / address latch.
assign gga_cs   = io_cs & A[10];
assign gga_we   = gga_cs & lo_we;
assign gga_addr = A[1];

assign ram_we    = { ram_cs   & hi_we, ram_cs   & lo_we };
assign vram_we   = { vram_cs  & hi_we, vram_cs  & lo_we };
assign rascr_we  = { rascr_cs & hi_we, rascr_cs & lo_we };
assign oram_we   = { oram_cs  & hi_we, oram_cs  & lo_we };
assign lut_we    = { lut_cs   & hi_we, lut_cs   & lo_we };
assign pal_we    = { pal_cs   & hi_we, pal_cs   & lo_we };
assign ram2_we   = { ram2_cs  & hi_we, ram2_cs  & lo_we };
assign vram1_we  = { vram1_cs & hi_we, vram1_cs & lo_we };
assign lut1_we   = { lut1_cs  & hi_we, lut1_cs  & lo_we };
// the second sprite chip's copy is written in lockstep with the first
assign oram1_we  = oram_we;
// turbofrc writes all eight banks as two words, four nibbles each.
// pspikes has two, from fff003: [7:4] for code[12]=0 and [3:0] for the rest
assign gfxbank   = two ? { bankw[1], bankw[0] }
                            : { 24'd0, gfxbank1, gfxbank0 };

assign bus_cs    = rom_cs;
assign bus_busy  = rom_cs & ~rom_ok_dly;

// NOT "ok_dly <= rom_ok": rom_ok can still be high from the PREVIOUS access
// when rom_cs rises for a new one, which releases DTACK a cycle early and
// latches stale data. jtframe_okdly ands cs with ok before delaying.
jtframe_okdly #(.W(1)) u_okdly(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cs     ( rom_cs    ),
    .ok     ( rom_ok    ),
    .ok_dly ( rom_ok_dly)
);

// Cabinet inputs, all active low to match the arcade ports.
//
// The two families do NOT share a layout. pspikes puts player 2 in IN0 and
// player 1 in IN1. turbofrc is a three player game: IN0 is player 1 plus the
// system bits, IN1 player 2, IN2 player 3 with START3 in bit 7.
// karatblz is a four player game and moves DSW and the pending bit:
//   0ff000 IN0  0ff002 IN1  0ff004 IN2  0ff006 IN3
//   0ff008 DSW  0ff00b sound latch pending
always @* begin
    if( karatblz ) case( A[4:1] )
        4'd0: cab_dout = { coin[2], service, tilt, dip_test, cab_1p[1:0],
                           coin[1:0], joystick1 };
        4'd1: cab_dout = { 8'hff, joystick2 };
        4'd2: cab_dout = { 8'hff, joystick3 };
        4'd4: cab_dout = dipsw;
        4'd5: cab_dout = { 15'h7fff, snd_pending };
        4'd3: cab_dout = { 8'hff, joystick4 };   // IN3 player 4
        default: cab_dout = 16'hffff;
    endcase else
    case( A[4:1] )
        4'd0: cab_dout = two ?
              { coin[2], service, tilt, dip_test, cab_1p[1:0], coin[1:0],
                joystick1 } :
              { 1'b1, service, 2'b11, cab_1p[1:0], coin[1:0], joystick2 };
        4'd1: cab_dout = two ? { 8'hff, joystick2 } : { 8'hff, joystick1 };
        4'd2: cab_dout = dipsw;
        4'd4: cab_dout = { 7'h7f, cab_1p[2], joystick3 };  // IN2 / DSW2
        default: cab_dout = { 15'h7fff, snd_pending };
    endcase
end

always @* begin
    cpu_din = 16'hffff;
    case( 1'b1 )
        rom_cs:   cpu_din = rom_data;
        ram_cs:   cpu_din = ram_dout;
        lut_cs:   cpu_din = lut_dout;
        lut1_cs:  cpu_din = lut1_dout;
        ram2_cs:  cpu_din = ram2_dout;
        vram_cs:  cpu_din = vram_dout;
        vram1_cs: cpu_din = vram1_dout;
        oram_cs:  cpu_din = oram_dout;
        rascr_cs: cpu_din = rascr_dout;
        pal_cs:   cpu_din = pal_dout;
        io_cs:    cpu_din = cab_dout;
        default:;
    endcase
end

// video and sound registers
always @(posedge clk) begin
    if( rst ) begin
        gfxbank0  <= 0;
        gfxbank1  <= 0;
        bankw[0]  <= 0;
        bankw[1]  <= 0;
        charbank  <= 0;
        objbank   <= 0;
        flip      <= 0;
        scry      <= 0;
        scrx1     <= 0;
        scrx0     <= 0;
        scry1     <= 0;
        snd_latch <= 0;
        snd_wr    <= 0;
    end else begin
        snd_wr <= 0;
        if( io_cs && ~|A[11:5] ) begin
            if( karatblz ) case( A[4:1] )
                // 0ff000 flip (bit 7)      0ff002 gfxbank: bit0 -> bank0, bit3 -> bank1
                // 0ff007 sound latch       0ff008/a/c/e scroll X0/Y0/X1/Y1
                4'd0: if( hi_we ) flip <= main_dout[15];
                4'd1: if( hi_we ) begin
                    bankw[0][3:0] <= { 3'd0, main_dout[ 8] };
                    bankw[0][7:4] <= { 3'd0, main_dout[11] };
                end
                4'd3: if( lo_we ) begin
                    snd_latch <= main_dout[7:0];
                    snd_wr    <= 1;
                end
                4'd5: if( hi_we ) scry  <= main_dout[8:0];
                4'd6: if( hi_we ) scrx1 <= main_dout[8:0];
                4'd7: if( hi_we ) scry1 <= main_dout[8:0];
                4'd4: if( hi_we ) scrx0 <= main_dout[8:0];   // 0ff008
                default:;
            endcase else
            if( !two ) case( A[3:1] )
                3'd0: if( lo_we ) { flip, charbank, objbank } <= // fff001
                                  { main_dout[7], main_dout[4:2], main_dout[1:0] };
                3'd1: if( lo_we ) { gfxbank0, gfxbank1 } <= main_dout[7:0]; // fff003
                3'd2: if( hi_we ) scry <= main_dout[8:0];                   // fff004
                3'd3: if( lo_we ) begin                                     // fff007
                    snd_latch <= main_dout[7:0];
                    snd_wr    <= 1;
                end
                default:;
            endcase else case( A[4:1] )
                4'd0: if( lo_we ) flip  <= main_dout[7];    // 0ff001
                4'd1: if( hi_we ) scry  <= main_dout[8:0];  // 0ff002
                4'd2: if( hi_we ) scrx1 <= main_dout[8:0];  // 0ff004
                4'd3: if( hi_we ) scry1 <= main_dout[8:0];  // 0ff006
                4'd4: if( hi_we ) bankw[0] <= main_dout;    // 0ff008 banks 0-3
                4'd5: if( hi_we ) bankw[1] <= main_dout;    // 0ff00a banks 4-7
                // 0ff00e / 0fe00e is an EVEN byte: high byte of the word, so
                // UDS and main_dout[15:8]. karatblz and pspikes latch on an
                // ODD byte (0ff007 / fff007) and use LDS instead.
                4'd7: if( hi_we ) begin
                    snd_latch <= main_dout[15:8];
                    snd_wr    <= 1;
                end
                default:;
            endcase
        end
    end
end

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

// all the vectors point to the same handler, so autovector level 1 is enough
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
    // unused
    .fave       (           ),
    .fworst     (           )
);

`else
// Scene replay. The CPU is out of the picture, so hold the bus idle with
// cpu_rnw high and every write enable low, and take the video configuration
// from the registers MAME captured - they live in 68000 registers, not RAM,
// so they are not part of the RAM dumps.
assign main_addr = 0;
assign main_dout = 0;
assign main_rnw  = 1;
assign main_dsn  = 2'b11;
assign rom_cs    = 0;
assign gga_cs    = 0;
assign gga_we    = 0;
assign gga_addr  = 0;
// the scene registers feed the same bank packing the live decoder uses
assign gfxbank   = two ? { bankw[1], bankw[0] }
                            : { 24'd0, gfxbank1, gfxbank0 };
assign ram_we    = 0;
assign ram2_we   = 0;
assign vram1_we  = 0;
assign oram1_we  = 0;
assign lut1_we   = 0;
assign vram_we   = 0;
assign rascr_we  = 0;
assign oram_we   = 0;
assign lut_we    = 0;
assign pal_we    = 0;

integer fregs, k;
reg [7:0] rb [0:11];

initial begin
    gfxbank0  = 0; gfxbank1 = 0;
    charbank  = 0; objbank  = 0;
    flip      = 0; scry     = 0;
    scrx1     = 0; scry1    = 0;
    bankw[0]  = 0; bankw[1] = 0;
    snd_latch = 0; snd_wr   = 0;
    for( k=0; k<12; k=k+1 ) rb[k] = 8'h0;
    fregs = $fopen("regs.bin","rb");
    if( fregs == 0 ) begin
        $display("%m WARNING: regs.bin not found, video registers stay at zero");
    end else begin
        k = 0;
        while( k<12 && !$feof(fregs) ) begin
            rb[k] = $fgetc(fregs);
            k = k+1;
        end
        $fclose(fregs);
        if( k >= 12 ) begin
            // turbofrc: flip, scrollY0, scrollX1, scrollY1, spare, two bank words
            flip     = rb[0][7];
            scry     = { rb[1][0], rb[2] };
            scrx1    = { rb[3][0], rb[4] };
            scry1    = { rb[5][0], rb[6] };
            bankw[0] = { rb[8],  rb[9]  };
            bankw[1] = { rb[10], rb[11] };
            $display("%m scene regs (turbofrc): scry=%03X scrx1=%03X scry1=%03X banks=%04X/%04X",
                     scry, scrx1, scry1, bankw[0], bankw[1]);
        end else begin
            // pspikes: palette bank, gfx bank, scroll Y
            objbank  = rb[0][1:0];
            charbank = rb[0][4:2];
            flip     = rb[0][7];
            gfxbank0 = rb[1][7:4];
            gfxbank1 = rb[1][3:0];
            scry     = { rb[2][0], rb[3] };
            $display("%m scene regs (pspikes): palbank=%02X gfxbank=%02X scrolly=%03X",
                     rb[0], rb[1], scry);
        end
    end
end
`endif

endmodule
