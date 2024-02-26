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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 16-8-2020 */

// Street Fighter: Main CPU
// 8MHz 68000 CPU

// PAL devices
// SF13 - Location 8B, board C, address decoder
// according to dump from https://www.jammarcade.net/wiki/index.php?title=Street_Fighter
//       /o12 = /i4 & i7 & i8 & i9
//        o14 = i2 & i4 & /i17
//        o15 = i5 & i6
//        o16 = /i3 & i5
//       /o19 = /i1 & /i3


module jtsf_main #(
    parameter MAINW = 19,
              RAMW  = 15
) (
    input              rst,
    input              clk,
    output             cpu_cen,
    // Timing
    output reg         flip,
    input       [ 8:0] V,
    input              LHBL,
    input              LVBL,
    // Sound
    output reg  [ 7:0] snd_latch,
    output reg         snd_nmi_n,
    // Characters
    input       [15:0] char_dout,
    output      [15:0] cpu_dout,
    output reg         char_cs,
    input              char_busy,
    output             UDSWn,
    output             LDSWn,
    // scroll
    output reg  [15:0] scr1posh,
    output reg  [15:0] scr2posh,
    // GFX enable signals
    output reg         charon,
    output reg         scr1on,
    output reg         scr2on,
    output reg         objon,
    // cabinet I/O
    input       [ 9:0] joystick1,
    input       [ 9:0] joystick2,
    input       [ 1:0] cab_1p,
    input       [ 1:0] coin,
    input              service,
    input              game_id,
    // BUS sharing
    output      [13:1] cpu_AB,
    output      [15:0] dmaout,
    input       [12:0] obj_AB,
    output             RnW,
    output reg         OKOUT,
    input              obj_br,   // Request bus
    output             bus_ack,  // bus acknowledge
    input              blcnten,  // bus line counter enable
    // MCU interfcae
    output reg [15:0]  mcu_din,
    input      [ 7:0]  mcu_dout,
    input              mcu_wr,
    input              mcu_acc,
    input      [15:1]  mcu_addr,
    input              mcu_brn, // RQBSQn
    output reg         mcu_DMAONn,
    input              mcu_ds,
    // Palette
    output             col_uw,
    output             col_lw,
    // Memory address for SDRAM
    output   [MAINW:1] addr,
    // RAM access
    output reg         ram_cs,
    output  [RAMW-1:0] ram_addr,
    input       [15:0] ram_data,
    output      [15:0] ram_din,
    output      [ 1:0] ram_dsn,
    output             ram_we,
    input              ram_ok,
    // ROM access
    output reg         rom_cs,
    input       [15:0] rom_data,
    input              rom_ok,
    // DIP switches
    input              dip_pause,
    input       [15:0] dipsw_a,
    input       [15:0] dipsw_b
);

wire [23:1] A;
wire        cen8, cen8b;
reg  [15:0] cabinet_input, cpu_din;
wire [15:0] objram;
wire        BRn, BGACKn, BGn;
reg         io_cs, obj_cs, col_cs,
            misc_cs, snd_cs;
reg         scr1pos_cs, scr2pos_cs;
wire        ASn, CPUbus;
wire        BUSn, UDSn, LDSn;
wire        clk_obj, objram_ldw, objram_udw;
reg         BERRn;
wire [ 8:0] Aobj, obj_subAB;
wire        mcu_master, reg_cen;
reg  [ 1:0] dsn_dly;

// obj RAM is split so only the 1kB used inside the 8kB is in BRAM
// potentially, there could be a problem if tryng to access 16 bits
// in the boundary. But that doesn't happen in software so I'm leaving
// it that way.
assign Aobj      = { A[12:6], A[2:1] };
assign obj_subAB = { obj_AB[11:5], obj_AB[1:0] };

assign cpu_cen  = cen8;
// high during DMA transfer
assign UDSWn    = RnW | UDSn;
assign LDSWn    = RnW | LDSn;
assign CPUbus   = BGACKn; // main CPU in control of the bus

assign col_uw   = col_cs & ~UDSWn;
assign col_lw   = col_cs & ~LDSWn;
assign addr     = A[MAINW:1];
assign cpu_AB   = A[13:1];
wire [15:1] mcu_addr_s;
wire [ 7:0] mcu_dout_s;
wire        mcu_wr_s, mcu_ds_s, mcu_acc_s;
wire [23:1] Aeff   = CPUbus ? A : { 2'b11, {6{mcu_addr_s[15]}}, mcu_addr_s };

// obj_cs gates the object RAM clock for CPU access, this
// helps with the hold time for the write (MiSTer target)
assign clk_obj    = obj_cs & clk;
assign objram_udw = ~UDSWn;
assign objram_ldw = ~LDSWn;

assign mcu_master = ~mcu_brn & bus_ack;

assign BUSn       = ASn | (LDSn & UDSn);

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

jtframe_sync #(.W(15+8+1+1+1)) u_mcus(
    .clk_in ( clk       ),
    .clk_out( clk       ),
    .raw    ( {mcu_addr, mcu_dout, mcu_wr, mcu_ds, mcu_acc } ),
    .sync   ( {mcu_addr_s, mcu_dout_s, mcu_wr_s, mcu_ds_s, mcu_acc_s } )
);

reg regs_cs;
wire bus_wrn = mcu_master ? ~mcu_wr : RnW;

always @(*) begin
    rom_cs     = 0;
    ram_cs     = 0;
    col_cs     = 0;
    io_cs      = 0;
    char_cs    = 0;
    OKOUT      = 0;
    misc_cs    = 0;
    snd_cs     = 0;
    obj_cs     = 0;
    // mcu_mcu_DMAONn = 1;   // for once, I leave the original active low setting
    scr1pos_cs = 0;
    scr2pos_cs = 0;
    snd_nmi_n  = 1;

    BERRn      = 1;
    mcu_DMAONn = 1;
    regs_cs    = 0;

    if( (!CPUbus && mcu_acc_s) ||  (!ASn && BGACKn && (RnW || {UDSn,LDSn}!=3)) ) begin
        case(Aeff[23:20])
            4'h0: rom_cs  = 1;  // reading from the ROM may fail from the MCU, but it shouldn't matter
            4'h8: char_cs = 1;
            4'hb: col_cs  = 1;
            4'hf: if( Aeff[15]) begin  // 32kB!
                if( Aeff[14:13]==2'b11 && Aeff[5:3]==3'd0 ) begin // FE - object RAM
                    obj_cs = 1;
                end else begin
                    ram_cs = 1;
                end
            end
            4'hc: if(Aeff[19:16]==4'd0) begin
                io_cs   =!Aeff[4] &&  bus_wrn;
                regs_cs = Aeff[4] && !bus_wrn;
            end
            //default: BERRn = ASn;
            default:;
        endcase
    end

    // output registers
    if( regs_cs ) begin
        case( Aeff[3:1] )
            // 3'd1: coin_cs    = 1;  // coin counters
            3'd2: scr1pos_cs = 1;
            3'd4: scr2pos_cs = 1;
            3'd5: begin
                misc_cs = 1;
                OKOUT   = 1;
            end
            3'd6: if( !ram_dsn[0] ) begin
                snd_cs    = 1; // c0001d
                snd_nmi_n = 0;
            end
            3'd7: begin // Triggers the MCU
                mcu_DMAONn = 0;
            end
            default:;
        endcase
    end
end

// MCU and shared bus
assign ram_addr = Aeff[15:1];
assign ram_din  = mcu_master ? {2{mcu_dout_s}} : cpu_dout;
assign ram_dsn  = mcu_master ? { mcu_ds_s, ~mcu_ds_s } : {UDSWn, LDSWn};
assign ram_we   = mcu_master ? (ram_cs & mcu_wr_s) : !RnW;
assign reg_cen  = mcu_master ? 1'b1 : cpu_cen; // only used for internal registers

always @(posedge clk) mcu_din <= cpu_din;

// SCROLL 1/2 H POSITION, it can be written by both the CPU and the MCU
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scr1posh <= 16'd0;
        scr2posh <= 16'd0;
    end else if( reg_cen ) begin
        if( scr1pos_cs ) begin
            if(!ram_dsn[1]) scr1posh[15:8] <= ram_din[15:8];
            if(!ram_dsn[0]) scr1posh[ 7:0] <= ram_din[ 7:0];
        end
        if( scr2pos_cs ) begin
            if(!ram_dsn[1]) scr2posh[15:8] <= ram_din[15:8];
            if(!ram_dsn[0]) scr2posh[ 7:0] <= ram_din[ 7:0];
        end
    end
end

// special registers
always @(posedge clk) begin
    if( rst ) begin
        flip         <= 0;
        snd_latch    <= 8'b0;
        charon       <= 1;
        scr1on       <= 1;
        scr2on       <= 1;
        objon        <= 1;
    end
    else if(reg_cen) begin
        if( misc_cs) begin
            if( !ram_dsn[0] ) begin
                flip   <= ram_din[2];
                charon <= ram_din[3];
                scr1on <= ram_din[6];
                scr2on <= ram_din[5];
                objon  <= ram_din[7];
            end
        end
        if( snd_cs ) begin
            snd_latch <= ram_din[7:0];
        end
    end
end

// Cabinet input
localparam BUT1=4, BUT2=5, BUT3=6, BUT4=7, BUT5=8, BUT6=9;

always @(posedge clk) begin
    case( Aeff[3:1] )
        3'd0: cabinet_input <= { // IN0 in MAME
                4'hf, // 15-12
                1'b1, // 11
                joystick2[BUT3], // 10
                joystick1[BUT3], // 9
                joystick2[BUT6], // 8
                5'h1f,           // 7-3
                joystick1[BUT6], // 2
                coin       // 1-0
            };
        3'd1: cabinet_input <= game_id==0 ? { // IN1 in MAME
            joystick2[BUT5],
            joystick2[BUT4],
            joystick2[BUT2],
            joystick2[BUT1],
            joystick2[3:0],
            joystick1[BUT5],
            joystick1[BUT4],
            joystick1[BUT2],
            joystick1[BUT1],
            joystick1[3:0]
        } : {
            1'b1,
            joystick1[BUT6],
            joystick1[BUT5],
            joystick1[BUT4],
            1'b1,
            joystick1[BUT3],
            joystick1[BUT2],
            joystick1[BUT1],
            4'b1111,
            joystick1[3:0]
        };
        3'd2: cabinet_input <= game_id==0 ? 16'hffff : { // IN2 in MAME
            1'b1,
            joystick2[BUT6],
            joystick2[BUT5],
            joystick2[BUT4],
            1'b1,
            joystick2[BUT3],
            joystick2[BUT2],
            joystick2[BUT1],
            4'b1111,
            joystick2[3:0]
        };
        3'd4: cabinet_input <= dipsw_b;
        3'd5: cabinet_input <= dipsw_a;
        3'd6: cabinet_input <= { // SYS
            8'hff,
            LVBL, // freeze when high
            4'hf,
            service,
            cab_1p
        };
        default: cabinet_input <= 16'hffff;
    endcase
end

// Data bus input
always @(*) begin
    case( {obj_cs, ram_cs, char_cs, io_cs} )
        4'b1000:  cpu_din = objram;
        4'b0100:  cpu_din = ram_data;
        4'b0010:  cpu_din = char_dout;
        4'b0001:  cpu_din = cabinet_input;
        default: cpu_din = rom_data;
    endcase
end

// DTACKn generation
wire       int1, int2;
wire [2:0] FC;
wire       inta_n;
wire       bus_cs =   |{ rom_cs, char_cs, ram_cs };
reg        bus_busy;
wire       DTACKn;

always @* begin
    bus_busy = |{ rom_cs & ~rom_ok, char_busy, ram_cs & ~ram_ok };
    if( BUSn ) bus_busy=0;
end

jtframe_68kdtack_cen u_dtack( // 48 -> 8MHz
    .rst        ( rst        ),
    .clk        ( clk        ),
    .num        ( 4'd1       ),
    .den        ( 5'd6       ),
    .cpu_cen    ( cen8       ),
    .cpu_cenb   ( cen8b      ),
    .bus_cs     ( bus_cs     ),
    .bus_busy   ( bus_busy   ),
    .bus_legit  ( char_busy  ),
    .ASn        ( ASn        ),
    .DSn        ({UDSn,LDSn} ),
    .DTACKn     ( DTACKn     ),
    .wait2      ( 1'd0       ),
    .wait3      ( 1'd0       ),
    // unused
    .frst       ( 1'd0       ),
    .fave       (            ),
    .fworst     (            )
);

// OBJ RAM is implemented in BRAM
// It was originally part of the SDRAM but the OBJ DMA module does not
// take into account the SDRAM ok signal and was getting garbage when compiling
// with sound enabled. Plus the ADPCM chips seemed to be missing data and thus
// some noise was heard
// Up to commit 6327e7 OBJ RAM was in SDRAM, just for reference

jtframe_dual_ram #(.AW(9)) u_objlow(
    .clk0       ( clk_obj       ),
    .clk1       ( clk           ),
    // Port 0: CPU
    .data0      ( cpu_dout[7:0] ),
    .addr0      ( Aobj          ),
    .we0        ( objram_ldw    ),
    .q0         ( objram[7:0]   ),
    // Port 1
    .data1      ( 8'd0          ),
    .addr1      ( obj_subAB     ),
    .we1        ( 1'b0          ),
    .q1         ( dmaout[7:0]   )
);

jtframe_dual_ram #(.AW(9)) u_objhi(
    .clk0       ( clk_obj       ),
    .clk1       ( clk           ),
    // Port 0: CPU
    .data0      ( cpu_dout[15:8]),
    .addr0      ( Aobj          ),
    .we0        ( objram_udw    ),
    .q0         ( objram[15:8]  ),
    // Port 1
    .data1      ( 8'd0          ),
    .addr1      ( obj_subAB     ),
    .we1        ( 1'b0          ),
    .q1         ( dmaout[15:8]  )
);

// interrupt generation
jtsf_intgen u_intgen(
    .clk        ( clk       ),
    .rst        ( rst       ),
    .cpu_cen    ( cen8      ),
    .V          ( V[7:0]    ),
    .int1       ( int1      ),
    .int2       ( int2      ),
    .inta_n     ( inta_n    ),
    .FC         ( FC        ),
    .ASn        ( ASn       ),
    .dip_pause  ( dip_pause )
);

wire [1:0] dev_br = { ~mcu_brn, obj_br };
assign bus_ack = ~BGACKn;

jtframe_68kdma #(.BW(2)) u_arbitration(
    .clk        (  clk          ),
    .rst        (  rst          ),
    .cen        (  cen8b        ),
    .cpu_BRn    (  BRn          ),
    .cpu_BGACKn (  BGACKn       ),
    .cpu_BGn    (  BGn          ),
    .cpu_ASn    (  ASn          ),
    .cpu_DTACKn (  DTACKn       ),
    .dev_br     (  dev_br       )
);

fx68k u_cpu(
    .clk        ( clk         ),
    .extReset   ( rst         ),
    .pwrUp      ( rst         ),
    .enPhi1     ( cen8       ),
    .enPhi2     ( cen8b      ),
    .HALTn      ( 1'b1        ),

    // Buses
    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),


    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( inta_n      ),
    .FC0        ( FC[0]       ),
    .FC1        ( FC[1]       ),
    .FC2        ( FC[2]       ),

    .BERRn      ( BERRn       ),
    // Bus arbitrion
    .BRn        ( BRn         ),
    .BGACKn     ( BGACKn      ),
    .BGn        ( BGn         ),

    .DTACKn     ( DTACKn      ),
    .IPL0n      ( 1'b1        ),
    .IPL1n      ( int1        ),
    .IPL2n      ( int2        ),

    // Unused
    .oRESETn    (             ),
    .oHALTEDn   (             ),
    .VMAn       (             ),
    .E          (             )
);

// `ifdef SIMULATION
//     wire sdram_error;
//
//     jtframe_din_check #(.AW(17)) u_sdram_check(
//         .rst        ( rst           ),
//         .clk        ( clk           ),
//         .cen        ( cpu_cen       ),
//         .rom_cs     (  rom_cs       ),
//         .rom_ok     ( rom_ok        ),
//         .rom_addr   (  rom_addr     ),
//         .rom_data   (  rom_data     ),
//         .error      ( sdram_error   )
//     );
// `endif

endmodule

module jtsf_intgen(
    input           clk,
    input           rst,
    input           cpu_cen,
    input     [7:0] V,
    input     [2:0] FC,
    input           ASn,
    input           dip_pause,

    output          int1,
    output          int2,
    output          inta_n
);

reg  int_n, int_rqb, int_rqb_last;
wire int_rqb_edge;

assign inta_n       = ~&{ FC[2], FC[1], FC[0], ~ASn }; // interrupt ack.
assign int2         = 1;
assign int1         = int_n;
assign int_rqb_edge = int_rqb && !int_rqb_last;  // based on Side Arms: Pos edge

always @(posedge clk)
    if(rst) begin
        int_n <= 1'b1;
    end else if(cpu_cen) begin
        int_rqb_last <= int_rqb;
        if( V==8'h6F || V==8'hEF ) int_rqb <= 0;
        if( V==8'h70 || V==8'hF0 ) int_rqb <= 1;
        if( !inta_n )
            int_n <= 1'b1;
        else
            if ( int_rqb_edge && dip_pause ) int_n <= 0;
    end

endmodule