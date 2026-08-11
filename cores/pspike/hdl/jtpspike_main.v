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

    // video configuration
    output reg    [ 3:0] gfxbank0, gfxbank1,
    output reg    [ 2:0] charbank,
    output reg    [ 1:0] objbank,
    output reg           flip,
    output reg    [ 8:0] scry,

    // sound interface
    output reg    [ 7:0] snd_latch,
    output reg           snd_wr,
    input                snd_pending,

    // cabinet
    input         [ 3:0] cab_1p, coin,
    input         [ 6:0] joystick1, joystick2,
    input                service,
    input         [15:0] dipsw
);

`ifndef NOMAIN
// 10 MHz out of 57.2727 MHz
localparam [5:0] CEN_NUM = 6'd11;
localparam [6:0] CEN_DEN = 7'd63;

wire [23:1] A;
reg  [15:0] cpu_din;
wire [ 2:0] cpu_fc;
wire        cpu_as_n, cpu_uds_n, cpu_lds_n, cpu_rnw;
wire        cen10, cen10b, dtack_n, inta_n, irq_n;
wire        bus_cs, bus_busy, cpu_bus, lo_we, hi_we;
wire        ram_cs, vram_cs, rascr_cs, oram_cs, lut_cs, pal_cs, io_cs;
wire        ffblk;
reg  [15:0] cab_dout;
reg         rom_ok_dly;

assign main_addr = A[19:1];
assign main_rnw  = cpu_rnw;
assign main_dsn  = { cpu_uds_n, cpu_lds_n };

// DSn delimits writes; reads start as soon as /AS falls so the data is
// ready in time for /DTACK
assign cpu_bus   = ~cpu_as_n && (cpu_rnw || main_dsn!=2'b11);
assign hi_we     = ~cpu_rnw & ~cpu_uds_n;
assign lo_we     = ~cpu_rnw & ~cpu_lds_n;

// address decoding
assign ffblk     = &A[23:16];
assign rom_cs    =  cpu_bus & ~|A[23:18];
assign ram_cs    =  cpu_bus & A[23:16]==8'h10;
assign lut_cs    =  cpu_bus & A[23:16]==8'h20 & ~|A[15:14];
assign vram_cs   =  cpu_bus & ffblk & A[15:12]==4'h8;
assign oram_cs   =  cpu_bus & ffblk & A[15:12]==4'hc & ~|A[11:10];
assign rascr_cs  =  cpu_bus & ffblk & A[15:12]==4'hd;
assign pal_cs    =  cpu_bus & ffblk & A[15:12]==4'he;
assign io_cs     =  cpu_bus & ffblk & A[15:12]==4'hf;

assign ram_we    = { ram_cs   & hi_we, ram_cs   & lo_we };
assign vram_we   = { vram_cs  & hi_we, vram_cs  & lo_we };
assign rascr_we  = { rascr_cs & hi_we, rascr_cs & lo_we };
assign oram_we   = { oram_cs  & hi_we, oram_cs  & lo_we };
assign lut_we    = { lut_cs   & hi_we, lut_cs   & lo_we };
assign pal_we    = { pal_cs   & hi_we, pal_cs   & lo_we };

assign bus_cs    = rom_cs;
assign bus_busy  = rom_cs & ~rom_ok_dly;

always @(posedge clk) rom_ok_dly <= rom_ok;

// cabinet inputs. Everything is active low, matching the arcade ports
always @* begin
    case( A[3:1] )
        3'd0: cab_dout = { 1'b1, service, 2'b11, cab_1p[1:0], coin[1:0],
                           1'b1, joystick2 };
        3'd1: cab_dout = { 9'h1ff, joystick1 };
        3'd2: cab_dout = dipsw;
        default: cab_dout = { 15'h7fff, snd_pending };
    endcase
end

always @* begin
    cpu_din = 16'hffff;
    case( 1'b1 )
        rom_cs:   cpu_din = rom_data;
        ram_cs:   cpu_din = ram_dout;
        lut_cs:   cpu_din = lut_dout;
        vram_cs:  cpu_din = vram_dout;
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
        charbank  <= 0;
        objbank   <= 0;
        flip      <= 0;
        scry      <= 0;
        snd_latch <= 0;
        snd_wr    <= 0;
    end else begin
        snd_wr <= 0;
        if( io_cs && ~|A[11:4] ) case( A[3:1] )
            3'd0: if( lo_we ) { flip, charbank, objbank } <= // fff001
                              { main_dout[7], main_dout[4:2], main_dout[1:0] };
            3'd1: if( lo_we ) { gfxbank0, gfxbank1 } <= main_dout[7:0]; // fff003
            3'd2: if( hi_we ) scry <= main_dout[8:0];                   // fff004
            3'd3: if( lo_we ) begin                                     // fff007
                snd_latch <= main_dout[7:0];
                snd_wr    <= 1;
            end
            default:;
        endcase
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

jtframe_68kdtack_cen #(.W(7)) u_dtack(
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

`ifdef SIMULATION
// Program-space fetch stream, to be diffed against the MAME boot trace.
// Prefetch makes this a superset of MAME's PC list.
integer main_tr;
reg         asn_l, prog_cyc;
reg  [23:1] pc_l;
reg  [15:0] op_l;
wire        prog_rd = cpu_fc[1] & ~cpu_fc[0] & cpu_rnw;

initial main_tr = $fopen("pspike_main_fpga.tr","w");

always @(posedge clk) begin
    asn_l <= cpu_as_n;
    if( !cpu_as_n && prog_rd ) begin
        prog_cyc <= 1;
        pc_l     <= A;
        op_l     <= cpu_din;
    end
    if( !asn_l && cpu_as_n ) begin
        if( prog_cyc && main_tr!=0 ) $fwrite(main_tr,"%06X: %04X\n",{pc_l,1'b0},op_l);
        prog_cyc <= 0;
    end
end

final if( main_tr!=0 ) $fclose(main_tr);
`endif

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
assign ram_we    = 0;
assign vram_we   = 0;
assign rascr_we  = 0;
assign oram_we   = 0;
assign lut_we    = 0;
assign pal_we    = 0;

integer fregs, b0, b1, b2, b3;

initial begin
    gfxbank0  = 0; gfxbank1 = 0;
    charbank  = 0; objbank  = 0;
    flip      = 0; scry     = 0;
    snd_latch = 0; snd_wr   = 0;
    fregs = $fopen("regs.bin","rb");
    if( fregs != 0 ) begin
        b0 = $fgetc(fregs);   // palette bank: [1:0] obj, [4:2] char, [7] flip
        b1 = $fgetc(fregs);   // gfx bank:     [7:4] bank0, [3:0] bank1
        b2 = $fgetc(fregs);   // scroll Y, high
        b3 = $fgetc(fregs);   // scroll Y, low
        $fclose(fregs);
        objbank  = b0[1:0];
        charbank = b0[4:2];
        flip     = b0[7];
        gfxbank0 = b1[7:4];
        gfxbank1 = b1[3:0];
        scry     = { b2[0], b3[7:0] };
        $display("%m scene regs: palbank=%02X gfxbank=%02X scrolly=%03X",
                 b0[7:0], b1[7:0], scry);
    end else begin
        $display("%m WARNING: regs.bin not found, video registers stay at zero");
    end
end
`endif

endmodule
