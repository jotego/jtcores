/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 18-1-2021 */

module jtcps2_main(
    input              rst,
    input              clk,
    input              clk_rom,
    output             cpu_cen,
    // Timing
    input   [8:0]      V,
    input              LVBL,
    input              LHBL,
    input              skip_en,
    // PPU
    output reg         ppu1_cs,
    output reg         ppu2_cs,
    output reg         objcfg_cs,
    output             ppu_rstn,
    input   [15:0]     mmr_dout,
    input              raster,

    output             UDSWn,
    output             LDSWn,
    // Keys
    input   [7:0]      prog_din,
    input              key_we,
    // cabinet I/O
    input   [1:0]      joymode,
    input   [9:0]      joystick1, joystick2, joystick3, joystick4,
    input   [1:0]      dial_x, dial_y,
    input   [3:0]      cab_1p,
    input   [3:0]      coin,
    input              service,
    input              tilt,
    input   [31:0]     dipsw,      // bit 0 used to enable the spinner on Eco Fighters
    // BUS sharing
    input              busreq,
    output             busack,
    output             RnW,
    // For RAM/ROM:
    output      [17:1] addr,
    output      [15:0] cpu_dout,
    // RAM access
    output             ram_cs,
    output             vram_cs,
    output             oram_cs,
    output reg         obank,
    output reg  [15:0] oram_base,
    input       [15:0] ram_data,
    input              ram_ok,
    // ROM access
    output reg         rom_cs,
    output reg  [21:1] rom_addr,
    input       [15:0] rom_data,
    input              rom_ok,
    // DIP switches
    input              dip_test,
    input              dip_pause,

    // EEPROM
    output reg         eeprom_sclk,
    output reg         eeprom_sdi,
    input              eeprom_sdo,
    output reg         eeprom_scs,

    // QSound
    output reg         z80_rstn,
    input       [ 7:0] main2qs_din,
    output reg  [23:1] main2qs_addr,
    output reg         main2qs_cs,
    input              main2qs_busakn,
    input              main2qs_waitn,
    input       [12:0] volume,
    // Debug
    input       [ 7:0] debug_bus,
    output reg  [ 7:0] st_dout
);

localparam [1:0] BUT6   = 2'b00,
                 PUZZL2 = 2'b01,
                 ECOFGT = 2'b10;

wire [23:1] A;
wire [ 2:0] FC;
wire        BERRn = 1'b1;
wire        rom_ok2;
wire        cen16, cen16b;

reg  [15:0] in0, in1, in2;
reg         in0_cs, in1_cs, in2_cs, vol_cs, out_cs, obank_cs;

wire [15:0] rom_dec;

wire        dec_en;
wire        BRn, BGACKn, BGn;
wire        ASn;
reg         io_cs, eeprom_cs,
            sys_cs, paddle_en;
reg         pre_ram_cs, pre_vram_cs, pre_oram_cs,
            reg_ram_cs, reg_vram_cs, reg_oram_cs;
reg         dsn_dly, one_wait;
wire [11:0] spin1p, spin2p;
wire        dir1p,  dir2p;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign cpu_cen   = cen16;
// As RAM and VRAM share contiguous spaces in the SDRAM
// it is important to prevent overlapping
assign addr      = ram_cs ? {2'b0, A[15:1] } : A[17:1];

// high during DMA transfer
wire BUSn, UDSn, LDSn;

assign BUSn  = ASn | (UDSn & LDSn);
assign UDSWn = RnW | UDSn;
assign LDSWn = RnW | LDSn;

// ram_cs and vram_cs signals go down before DSWn signals
// that causes a false read request to the SDRAM. In order
// to avoid that a little bit of logic is needed:
assign ram_cs   = ~BUSn & (dsn_dly ? reg_ram_cs  : pre_ram_cs);
assign vram_cs  = ~BUSn & (dsn_dly ? reg_vram_cs : pre_vram_cs);
assign oram_cs  = ~BUSn & (dsn_dly ? reg_oram_cs : pre_oram_cs);
assign ppu_rstn = 1'b1;

always @(posedge clk) begin
    case( debug_bus[1:0] )
        2: st_dout <= spin1p[7:0];
        3: st_dout <= {4'd0, spin1p[11:8] };
        default: st_dout <= { 2'd0, dir2p, dir1p, 2'd0, dipsw[0], paddle_en };
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        reg_ram_cs  <= 0;
        reg_vram_cs <= 0;
        reg_oram_cs <= 0;
        dsn_dly     <= 1;
    end else if(cen16) begin
        reg_ram_cs  <= pre_ram_cs;
        reg_vram_cs <= pre_vram_cs;
        reg_oram_cs <= pre_oram_cs;
        dsn_dly     <= &{UDSWn,LDSWn}; // low if any DSWn was low
    end
end

always @(*) begin // below 5MB and above 8MB
    one_wait = !ASn && BGACKn && (A[23:20]<4'h5 || A[23:20]>=4'h8);
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rom_cs      <= 1'b0;
        pre_ram_cs  <= 1'b0;
        pre_vram_cs <= 1'b0;
        pre_oram_cs <= 1'b0;
        io_cs        <= 1'b0;
        rom_addr     <= 21'd0;
        objcfg_cs    <= 0;
        main2qs_cs   <= 0;
        main2qs_addr <= 23'd0;
    end else begin
        if( !ASn && BGACKn ) begin // PAL PRG1 12H
            rom_addr    <= A[21:1];
            rom_cs      <= A[23:22] == 2'b00;
            pre_ram_cs  <= &A[23:16];
            pre_vram_cs <= A[23:18] == 6'b1001_00 && A[17:16]!=2'b11;
            pre_oram_cs <= A[23:20] == 4'h7 && A[19:16]==oram_base[11:8];
            io_cs       <= A[23:19] == 5'b1000_0;
            // OBJ engine
            objcfg_cs   <= ((dec_en && A[23:20] == 4'h4) || (!dec_en && A[23:4] == ~20'h0)) && !RnW;
            // QSound
            main2qs_cs   <= A[23:20] == 4'h6  && A[19:17]==3'd0; // 60'0000-61'FFFF
            main2qs_addr <= A;
        end else begin
            rom_cs      <= 0;
            pre_ram_cs  <= 0;
            pre_vram_cs <= 0;
            pre_oram_cs <= 0;
            io_cs       <= 0;
            main2qs_cs  <= 0;
            objcfg_cs   <= 0;
        end
    end
end

// I/O
always @(*) begin
    ppu1_cs   = io_cs && A[8:6] == 3'b100; // CPS-A
    ppu2_cs   = io_cs && A[8:6] == 3'b101; // CPS-B
    in0_cs    = io_cs && A[8:3] == 6'h0;
    in1_cs    = io_cs && A[8:3] == 6'b00_0010;
    in2_cs    = io_cs && A[8:3] == 6'b00_0100;
    vol_cs    = io_cs && A[8:3] == 6'b000_110; // QSound volume
    out_cs    = io_cs && A[8:3] == 6'b0_0100_0 && !RnW && !LDSWn;
    eeprom_cs = io_cs && A[8:3] == 6'b0_0100_0 && !RnW;
    obank_cs  = io_cs && A[8:3] == 6'b0_1110_0 && !RnW && !LDSWn;
    sys_cs    = in0_cs | in1_cs | in2_cs | eeprom_cs;
end

// EEPROM control in CPS 1.5 games
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        eeprom_scs  <= 0;
        eeprom_sclk <= 0;
        eeprom_sdi  <= 0;
        z80_rstn    <= 0;
        obank       <= 0;
        paddle_en   <= 0;
        oram_base   <= 16'h0;
    end
    else if(cpu_cen) begin
        if( eeprom_cs ) begin
            if( !UDSWn ) begin
                eeprom_sdi  <= cpu_dout[12];
                eeprom_sclk <= cpu_dout[13];
                eeprom_scs  <= cpu_dout[14];
                if( joymode==ECOFGT ) paddle_en <= cpu_dout[8]^debug_bus[0];
            end
            if( !LDSWn && joymode==PUZZL2 ) begin
                paddle_en <= ~cpu_dout[1];
            end
        end
        if( out_cs ) begin
            z80_rstn <= cpu_dout[3];
        end
        if( obank_cs ) obank <= cpu_dout[0];
        if( objcfg_cs && A[3:1]==0 ) begin
            if( !UDSWn ) oram_base[15:8] <= cpu_dout[15:8];
            if( !LDSWn ) oram_base[ 7:0] <= cpu_dout[ 7:0];
        end
    end
end

always @(posedge clk) begin
    // This still doesn't cover all cases
    // Base system, 4 players, 4 buttons
    in0 <= { joystick2[7:0], joystick1[7:0] };
    in1 <= { joystick4[7:0], joystick3[7:0] };
    in2 <= { coin, cab_1p, ~5'b0, service, dip_test, eeprom_sdo };
    case( joymode )
        default:;
        BUT6: begin
            in0[15] <= 1'b1;
            in0[ 7] <= 1'b1;
            in1     <= 16'hffff;
            in1[2:0] <= joystick1[9:7];
            in1[5:4] <= joystick2[8:7];
            in2[ 14] <= joystick2[9];
        end
        PUZZL2: if(paddle_en) in0 <= { spin2p[7:0], spin1p[7:0] };
        ECOFGT: begin
            in1[4] <= dipsw[0];
            if( ~dipsw[0] ) begin
                if( paddle_en ) begin
                    in0 <= { spin2p[7:0], spin1p[7:0] };
                end else begin
                    in0[13] <= dir2p;
                    in0[ 5] <= dir1p;
                end
            end
        end
    endcase
end

jt4701_axis u_spin1p(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .sigin      ( dial_x    ),
    .flag_clrn  ( 1'b1      ),
    .flagn      (           ),
    .axis       ( spin1p    ),
    .dir        ( dir1p     ),
    .step       (           )
);

jt4701_axis u_spin2p(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .sigin      ( dial_y    ),
    .flag_clrn  ( 1'b1      ),
    .flagn      (           ),
    .axis       ( spin2p    ),
    .dir        ( dir2p     ),
    .step       (           )
);


reg [15:0] sys_data;

always @(posedge clk) begin
    sys_data <= in0_cs ? in0 : (
                in1_cs ? in1 : (
                in2_cs ? in2 : 16'hFFFF ));
end

// Data bus input
reg  [15:0] cpu_din;

always @(posedge clk) begin
    if(rst) begin
        cpu_din <= 16'hffff;
    end else begin
        cpu_din <= sys_cs ? sys_data : (
                   (ram_cs | vram_cs | oram_cs ) ? ram_data : (
                    rom_cs      ? rom_dec  : (
                    ppu2_cs     ? mmr_dout : (
                    vol_cs      ? {3'b111, volume }    : (
                    main2qs_cs  ? {8'hff, main2qs_din} :
                                16'hFFFF )))));

    end
end

// DTACKn generation
wire       inta_n;
wire       bus_cs =   |{ rom_cs, pre_ram_cs, pre_vram_cs, pre_oram_cs, main2qs_cs };
wire       bus_busy = |{ rom_cs & ~(rom_ok&rom_ok2),
                    (pre_ram_cs|pre_vram_cs|pre_oram_cs) & ~ram_ok,
                    main2qs_cs & ~main2qs_waitn };

wire       DTACKn;
reg        last_LVBL;

reg qs_busakn_s;

always @(posedge clk, posedge rst) begin
    if( rst )
        qs_busakn_s <= 1;
    else if(cpu_cen)
        qs_busakn_s <= main2qs_busakn;
end

reg fail_cnt_ok;

jtcps2_dtack u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen16      ( cen16     ),
    .cen16b     ( cen16b    ),

    .ASn        ( ASn       ),
    .UDSn       ( UDSn      ),
    .LDSn       ( LDSn      ),
    .one_wait   ( one_wait  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .busack     ( busack    ),

    .main2qs_cs ( main2qs_cs  ),
    .qs_busakn_s( qs_busakn_s ),

    .DTACKn     ( DTACKn    )
);

jtcps2_decrypt u_decrypt(
    .rst        ( 1'b0      ), // must be on during ROM download
    .clk        ( clk_rom   ),

    // Key download
    .prog_din   ( prog_din  ),
    .prog_we    ( key_we    ),

    // Control
    .fc         ( FC        ),

    .dec_en     ( dec_en    ),

    // Decoding
    .addr       ( A         ),
    .rom_ok     ( rom_ok    ),
    .rom_ok_out ( rom_ok2   ),
    .din        ( rom_data  ),
    .dout       ( rom_dec   )
);

// interrupt generation
wire       int1, // VBLANK
           int2, // Raster
           skip_but;
assign  skip_but = ~&cab_1p;
//assign inta_n = ~&{ FC, ~BGACKn }; // interrupt ack. according to Loic's DL-1827 schematic
assign inta_n = ~&{ FC, A[19:16] }; // ctrl like M68000's manual
wire   vpa_n = ~&{ FC, ~ASn };

jtframe_virq u_virq(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .LVBL       ( LVBL      ),
    .dip_pause  ( dip_pause ),
    .skip_en    ( skip_en   ),
    .skip_but   ( skip_but  ),
    .clr        ( ~inta_n   ),
    .custom_in  ( raster    ),
    .blin_n     ( int1      ),
    .blout_n    (           ),
    .custom_n   ( int2      )
);

assign busack = ~BGACKn;

jtframe_68kdma #(.BW(1)) u_arbitration(
    .clk        (  clk          ),
    .cen        ( cen16b        ),
    .rst        (  rst          ),
    .cpu_BRn    (  BRn          ),
    .cpu_BGACKn (  BGACKn       ),
    .cpu_BGn    (  BGn          ),
    .cpu_ASn    (  ASn          ),
    .cpu_DTACKn (  DTACKn       ),
    .dev_br     (  busreq       ) // following DL-1827 logic
);

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .RESETn     (             ),
    .cpu_cen    ( cen16       ),
    .cpu_cenb   ( cen16b      ),

    // Buses
    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),


    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( vpa_n       ),
    .FC         ( FC          ),

    .BERRn      ( BERRn       ),
    // Bus arbitrion
    .HALTn      ( dip_pause   ),
    .BRn        ( BRn         ),
    .BGACKn     ( BGACKn      ),
    .BGn        ( BGn         ),

    .DTACKn     ( DTACKn      ),
    .IPLn       ( { int2, int1, 1'b1 } ) // Raster, VBLANK
);

endmodule
