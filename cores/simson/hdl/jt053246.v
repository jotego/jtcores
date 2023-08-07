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
    Date: 30-7-2023 */

// Based on 051960 (previous generation of sprite hardware)
// and MAME documentation

// 256 sprites, 8x 16-bit data per sprite
// Sprite table = 256*8*2=4096 = (0x1000)
// DMA transfer takes 297.5us, and occurs 1 line after VS finishes
// The PCB may detect end of the DMA transfer and set
// an interrupt on it

// The chip can operate in either 8-bit or 16-bit mode, so it can
// connect to an 8-bit CPU (and RAM) or a 16-bit system
// Is the 8-bit mode set by an MMR?
// DMA A0 line max speed is 3MHz (166ns low, 166ns high)
// in 8-bit mode, not all 8 positions have low & high bytes read
// if all were read, DMA should last for 682.67us but it is 596.9us
// so 14 out of 16 bytes are read for each object
// MSB is read first, so the order is
// 1,0,3,2,5,4,7,6,9,8,B,A,D,C
// Note that F,E are missing. Could they be enabled with some MMR?

// In X-Men (16-bit mode) DMA lasts for 298.7us, half the time
// than in 8-bit mode (accounting for some inaccuracy in the measurement)

module jt053246(    // sprite logic
    input             rst,
    input             clk,
    input             pxl2_cen,
    input             pxl_cen,

    // CPU interface
    input             cs,
    input             cpu_we,
    input      [ 2:1] cpu_addr,
    input      [15:0] cpu_dout,
    input      [ 1:0] cpu_dsn,

    // ROM check by CPU
    output reg [21:1] rmrd_addr,

    // External RAM
    output reg [13:1] dma_addr, // up to 16 kB
    input      [15:0] dma_data,
    output reg        dma_bsy,

    // ROM addressing 22 bits in total
    output reg [15:0] code,
    // There are 22 bits communicating both chips on the PCB
    output reg [ 9:0] attr,     // OC pins
    output            hflip,
    output            vflip,
    output reg [ 8:0] hpos,
    output     [ 3:0] ysub,
    output reg [ 9:0] hzoom,
    output reg        hz_keep,

    // base video
    input      [ 8:0] hdump,    // Not inputs in the original, but
    input      [ 8:0] vdump,    // generated internally.
                                // Hdump goes from 20 to 19F, 384 pixels
                                // Vdump goes from F8 to 1FF, 264 lines
    input             vs,
    input             hs,
    input             lvbl,

    // shadow
    input      [ 8:0] pxl,
    output reg [ 1:0] shd,

    // indr module / 051937
    output reg        dr_start,
    input             dr_busy,

    // Debug
    input      [ 7:0] debug_bus,
    input      [ 7:0] st_addr,
    output reg [ 7:0] st_dout
);

localparam [2:0] REG_XOFF  = 0, // X offset
                 REG_YOFF  = 1, // Y offset
                 REG_CFG   = 2; // interrupt control, ROM read

wire        vb_rd, dma_we;
reg  [ 9:0] xoffset, yoffset;
reg  [ 7:0] cfg;
reg  [ 1:0] reserved;

reg  [ 9:0] vzoom;
reg  [ 2:0] hstep, hcode;
reg  [ 1:0] scan_sub;
reg  [ 8:0] ydiff, ydiff_b, vlatch;
reg  [ 9:0] y, x, ymove;
reg  [ 7:0] scan_obj; // max 256 objects
reg         dma_clr, inzone, hs_l, done, hdone, busy_l;
wire [15:0] scan_even, scan_odd;
reg  [15:0] dma_bufd;
reg  [ 3:0] size;
wire [15:0] dma_din;
wire [11:1] dma_wr_addr;
reg  [11:1] dma_bufa;
wire [11:2] scan_addr;
wire        last_obj;
reg  [18:0] yz_add;
reg         dma_ok, vmir, hmir, sq, pre_vf, pre_hf, indr, hsl,
            vmir_eff, flicker, vs_l;
wire        busy_g, cpu_bsy;
wire        ghf, gvf, dma_en;
reg  [ 8:0] full_h, vscl;

assign ghf     = cfg[0]; // global flip
assign gvf     = cfg[1];
assign cpu_bsy = cfg[3];
assign dma_en  = cfg[4];
assign vflip   = pre_vf ^ vmir_eff;
assign hflip   = pre_hf ^ hmir;

assign dma_din     = dma_clr ? 16'h0 : dma_bufd;
assign dma_we      = dma_clr | dma_ok;
assign dma_wr_addr = dma_clr ? dma_addr[11:1] : dma_bufa;

assign scan_addr   = { scan_obj, scan_sub };
assign ysub        = ydiff[3:0];
assign busy_g      = busy_l | dr_busy;
assign last_obj    = &scan_obj;


always @(posedge clk) begin
    /* verilator lint_off WIDTH */
    yz_add  <= vzoom*ydiff_b; // vzoom < 10'h40 enlarge, >10'h40 reduce
    /* verilator lint_on WIDTH */
end

always @* begin
    case( size[3:2] )
        0: full_h = vscl>>1;
        1: full_h = vscl;
        2: full_h = vscl<<1;
        3: full_h = vscl<<2;
    endcase
    ymove = full_h>>1;
    // case( size[3:2] )
    //     1: ymove = 10'h08;
    //     2: ymove = 10'h18;
    //     3: ymove = 10'h38;
    //     default: ymove = 0;
    // endcase
    ydiff_b= ymove + y[8:0] + vlatch - 9'd8;
    ydiff  = /*ydiff_b +*/ yz_add[6+:9];
    // assuming  mirroring applies to a single 16x16 tile, not the whole size
    vmir_eff = vmir && size[3:2]==0 && !ydiff[3];
    case( size[3:2] )
        0: inzone = ydiff_b[8:5]==0 && ydiff[8:4]==0; // 16
        1: inzone = ydiff_b[8:6]==0 && ydiff[8:5]==0; // 32
        2: inzone = ydiff_b[8:7]==0 && ydiff[8:6]==0; // 64
        3: inzone = ydiff_b[8  ]==0 && ydiff[8:7]==0; // 128
    endcase
    case( size[1:0] )
        0: hdone = 1;
        1: hdone = hstep==1;
        2: hdone = hstep==3;
        3: hdone = hstep==7;
    endcase
end

// DMA logic
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dma_bsy  <= 0;
        dma_clr  <= 0;
        dma_addr <= 0;
        dma_bufa <= 0;
        dma_bufd <= 0;
        dma_bsy  <= 0;
        hsl      <= 0;
    end else if( pxl2_cen ) begin
        hsl <= hs;
        if( vdump==9'h1f8 ) begin
            dma_clr <= dma_en;
            dma_addr <= 0;
        end else if( dma_clr ) begin
            { dma_clr, dma_addr[11:1] } <= { 1'b1, dma_addr[11:1] } + 1'd1;
        end
        if( vdump==9'h102 && hs && !hsl ) begin
            dma_bsy  <= dma_en;
            dma_addr <= 0;
            dma_bufa <= 0;
            dma_clr  <= 0;
            dma_ok   <= 0;
        end else if( dma_bsy ) begin // copy by priority order
            dma_bsy  <= 1;
            dma_bufd <= dma_data;
            if( dma_addr[3:1]==0 ) begin
                dma_bufa <= { dma_data[7:0], 3'd0 };
                dma_ok <= dma_data[15] && dma_data[7:0]!=0; // priority 0 is skipped. See Simpsons scene 4
            end
            { dma_bsy, dma_addr } <= { 1'b1, dma_addr } + 1'd1;
            dma_bufa[3:1] <= dma_addr[3:1];
            if( dma_addr[3:1]==6 ) begin
                { dma_bsy, dma_addr } <= { 1'b1, dma_addr } + 14'd2; // skip 7
            end
        end
    end
end

(* direct_enable *) reg cen2=0;
always @(negedge clk) cen2 <= ~cen2;

// Table scan
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hs_l     <= 0;
        scan_obj <= 0;
        scan_sub <= 0;
        hstep    <= 0;
        code     <= 0;
        attr     <= 0;
        pre_vf   <= 0;
        pre_hf   <= 0;
        vzoom    <= 0;
        hzoom    <= 0;
        hz_keep  <= 0;
        busy_l   <= 0;
        indr     <= 0;
        flicker  <= 0;
    end else if( cen2 ) begin
        hs_l <= hs;
        vs_l <= vs;
        busy_l <= dr_busy;
        dr_start <= 0;
        if( vs && !vs_l ) flicker <= ~flicker;
        if( hs && !hs_l && vdump>9'h10D && vdump<9'h1f1) begin
            done     <= 0;
            scan_obj <= 0;
            scan_sub <= 0;
            vlatch   <= vdump;
        end else if( !done ) begin
            scan_sub <= scan_sub + 1'd1;
            case( {indr, scan_sub} )
                0: begin
                    { sq, pre_vf, pre_hf, size } <= scan_even[14:8];
                    code    <= scan_odd;
                    hstep   <= 0;
                    hz_keep <= 0;
                    if( !scan_even[15] || (scan_obj[6:0]==debug_bus[6:0] && flicker)) begin
                        scan_sub <= 0;
                        scan_obj <= scan_obj + 1'd1;
                        if( last_obj ) done <= 1;
                    end
                end
                1: begin
                    y <= gvf ? -scan_even[9:0] : scan_even[9:0];
                    x <= ghf ? -scan_odd[ 9:0] : scan_odd[ 9:0];
                    hcode <= {code[4],code[2],code[0]};
                    hstep <= 0;
                end
                2: begin
                    //x <=  x - xoffset[8:0] // + { {2{debug_bus[7]}}, debug_bus };
                    x <=  x + 10'h20;
                    y <=  y /*- yoffset[8:0]*/ + 10'h380;
                    vzoom <= debug_bus[7] ? 10'h40 : scan_even[9:0];
                    hzoom <= sq ? scan_even[9:0] : scan_odd[9:0];
                end
                3: begin
                    { vmir, hmir, reserved, shd, attr } <= scan_even;
                    // Add the vertical offset to the code
                    case( size[3:2] ) // could be + or |
                        1: {code[5],code[3],code[1]} <= {code[5],code[3],code[1]} + { 2'd0, ydiff[4]^vflip   };
                        2: {code[5],code[3],code[1]} <= {code[5],code[3],code[1]} + { 1'd0, ydiff[5:4]^{2{vflip}} };
                        3: {code[5],code[3],code[1]} <= {code[5],code[3],code[1]} + ( ydiff[6:4]^{3{vflip}});
                    endcase
                    if( !inzone ) begin
                        scan_sub <= 0;
                        scan_obj <= scan_obj + 1'd1;
                        if( last_obj ) done <= 1;
                    end else begin
                        indr     <= 1;
                        scan_sub <= 3;
                    end
                end
                default: begin // in draw state
                    scan_sub <= 3;
                    if( (!dr_start && !busy_g) || !inzone ) begin
                        case( size[1:0] )
                            0: {code[4],code[2],code[0]} <= hcode;
                            1: {code[4],code[2],code[0]} <= hcode + {2'd0,hstep[0]^hflip};
                            2: {code[4],code[2],code[0]} <= hcode + {1'd0,hstep[1:0]^{2{hflip}}};
                            3: {code[4],code[2],code[0]} <= hcode + (hstep[2:0]^{3{hflip}});
                        endcase
                        if( hstep==0 ) begin
                            case( size[1:0])
                                1: hpos <= x[8:0] - 9'h08;//{ 2'd0, debug_bus[2:0],3'd0};
                                2: hpos <= x[8:0] - 9'h18;//{ 2'd0, debug_bus[5:3],3'd0};
                                3: hpos <= x[8:0] - 9'h28;//{ 2'd0, debug_bus[7:6],4'd0};
                                default: hpos <= x[8:0]; //{debug_bus[7], debug_bus };
                            endcase
                        end else begin
                            hpos <= hpos + 9'h10;
                            hz_keep <= 1;
                        end
                        hstep <= hstep + 1'd1;
                        // would !x[9] create problems in large sprites
                        // it is needed to prevent the police car from showing up
                        // at the end of level 1 in Simpsons (see scene 3)
                        dr_start <= inzone && !x[9];
                        if( hdone || !inzone ) begin
                            scan_sub <= 0;
                            scan_obj <= scan_obj + 1'd1;
                            indr     <= 0;
                            if( last_obj ) done <= 1;
                        end
                    end
                end
            endcase
        end
    end
end

`ifdef SIMULATION
reg [7:0] mmr_init[0:7];
integer f,fcnt=0;

initial begin
    f=$fopen("obj_mmr.bin","rb");
    if( f!=0 ) begin
        fcnt=$fread(mmr_init,f);
        $fclose(f);
        $display("Read %1d bytes for 053246 MMR", fcnt);
        mmr_init[5][4] = 1; // enable DMA, which will be low if the game was paused for the dump
    end
end
`endif

// Register map
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        xoffset <= 0; yoffset <= 0; cfg <= 0;
`ifdef SIMULATION
        if( fcnt!=0 ) begin
            xoffset <= { mmr_init[1][1:0], mmr_init[0] };
            yoffset <= { mmr_init[3][1:0], mmr_init[2] };
            cfg     <= mmr_init[5];
        end
`endif
        st_dout <= 0;
    end else begin
        if( cs ) begin // note that the write signal is not checked
            case( cpu_addr )
                0: begin
                    if( !cpu_dsn[0] ) xoffset[ 7:0] <= cpu_dout[7:0];
                    if( !cpu_dsn[1] ) xoffset[ 9:8] <= cpu_dout[9:8];
                end
                1: begin
                    if( !cpu_dsn[0] ) yoffset[7:0] <= cpu_dout[7:0];
                    if( !cpu_dsn[1] ) yoffset[9:8] <= cpu_dout[9:8];
                end
                2: begin
                    if( !cpu_dsn[0] ) rmrd_addr[8:1] <= cpu_dout[7:0];
                    if( !cpu_dsn[1] ) cfg <= cpu_dout[15:8];
                end
                3: begin
                    if( !cpu_dsn[0] ) rmrd_addr[16: 9] <= cpu_dout[ 7:0];
                    if( !cpu_dsn[1] ) rmrd_addr[21:17] <= cpu_dout[12:8];
                end
            endcase
        end
        case( st_addr[2:0])
            0: st_dout <= xoffset[7:0];
            1: st_dout <= {6'd0,xoffset[9:8]};
            2: st_dout <= yoffset[7:0];
            3: st_dout <= {6'd0,yoffset[9:8]};
            5: st_dout <= cfg;
            default: st_dout <= 0;
        endcase
    end
end

wire dma_wel = dma_we & ~dma_wr_addr[1];
wire dma_weh = dma_we &  dma_wr_addr[1];

jtframe_dual_ram16 #(.AW(10)) u_even( // 10:0 -> 2kB
    // Port 0: DMA
    .clk0   ( clk            ),
    .data0  ( dma_din        ),
    .addr0  (dma_wr_addr[11:2]),
    .we0    ( {2{dma_wel}}   ),
    .q0     (                ),
    // Port 1: scan
    .clk1   ( clk            ),
    .data1  ( 16'd0          ),
    .addr1  ( scan_addr      ),
    .we1    ( 2'b0           ),
    .q1     ( scan_even      )
);

jtframe_dual_ram16 #(.AW(10)) u_odd( // 10:0 -> 2kB
    // Port 0: DMA
    .clk0   ( clk            ),
    .data0  ( dma_din        ),
    .addr0  (dma_wr_addr[11:2]),
    .we0    ( {2{dma_weh}}   ),
    .q0     (                ),
    // Port 1: scan
    .clk1   ( clk            ),
    .data1  ( 16'd0          ),
    .addr1  ( scan_addr      ),
    .we1    ( 2'b0           ),
    .q1     ( scan_odd       )
);

always @(posedge clk) begin
    case( vzoom[7:0] )
        1:   vscl <= 511;
        2:   vscl <= 511;
        3:   vscl <= 511;
        4:   vscl <= 511;
        5:   vscl <= 410;
        6:   vscl <= 341;
        7:   vscl <= 293;
        8:   vscl <= 256;
        9:   vscl <= 228;
        10:  vscl <= 205;
        11:  vscl <= 186;
        12:  vscl <= 171;
        13:  vscl <= 158;
        14:  vscl <= 146;
        15:  vscl <= 137;
        16:  vscl <= 128;
        17:  vscl <= 120;
        18:  vscl <= 114;
        19:  vscl <= 108;
        20:  vscl <= 102;
        21:  vscl <= 98;
        22:  vscl <= 93;
        23:  vscl <= 89;
        24:  vscl <= 85;
        25:  vscl <= 82;
        26:  vscl <= 79;
        27:  vscl <= 76;
        28:  vscl <= 73;
        29:  vscl <= 71;
        30:  vscl <= 68;
        31:  vscl <= 66;
        32:  vscl <= 64;
        33:  vscl <= 62;
        34:  vscl <= 60;
        35:  vscl <= 59;
        36:  vscl <= 57;
        37:  vscl <= 55;
        38:  vscl <= 54;
        39:  vscl <= 53;
        40:  vscl <= 51;
        41:  vscl <= 50;
        42:  vscl <= 49;
        43:  vscl <= 48;
        44:  vscl <= 47;
        45:  vscl <= 46;
        46:  vscl <= 45;
        47:  vscl <= 44;
        48:  vscl <= 43;
        49:  vscl <= 42;
        50:  vscl <= 41;
        51:  vscl <= 40;
        52:  vscl <= 39;
        53:  vscl <= 39;
        54:  vscl <= 38;
        55:  vscl <= 37;
        56:  vscl <= 37;
        57:  vscl <= 36;
        58:  vscl <= 35;
        59:  vscl <= 35;
        60:  vscl <= 34;
        61:  vscl <= 34;
        62:  vscl <= 33;
        63:  vscl <= 33;
        64:  vscl <= 32;
        65:  vscl <= 32;
        66:  vscl <= 31;
        67:  vscl <= 31;
        68:  vscl <= 30;
        69:  vscl <= 30;
        70:  vscl <= 29;
        71:  vscl <= 29;
        72:  vscl <= 28;
        73:  vscl <= 28;
        74:  vscl <= 28;
        75:  vscl <= 27;
        76:  vscl <= 27;
        77:  vscl <= 27;
        78:  vscl <= 26;
        79:  vscl <= 26;
        80:  vscl <= 26;
        81:  vscl <= 25;
        82:  vscl <= 25;
        83:  vscl <= 25;
        84:  vscl <= 24;
        85:  vscl <= 24;
        86:  vscl <= 24;
        87:  vscl <= 24;
        88:  vscl <= 23;
        89:  vscl <= 23;
        90:  vscl <= 23;
        91:  vscl <= 23;
        92:  vscl <= 22;
        93:  vscl <= 22;
        94:  vscl <= 22;
        95:  vscl <= 22;
        96:  vscl <= 21;
        97:  vscl <= 21;
        98:  vscl <= 21;
        99:  vscl <= 21;
        100: vscl <= 20;
        101: vscl <= 20;
        102: vscl <= 20;
        103: vscl <= 20;
        104: vscl <= 20;
        105: vscl <= 20;
        106: vscl <= 19;
        107: vscl <= 19;
        108: vscl <= 19;
        109: vscl <= 19;
        110: vscl <= 19;
        111: vscl <= 18;
        112: vscl <= 18;
        113: vscl <= 18;
        114: vscl <= 18;
        115: vscl <= 18;
        116: vscl <= 18;
        117: vscl <= 18;
        118: vscl <= 17;
        119: vscl <= 17;
        120: vscl <= 17;
        121: vscl <= 17;
        122: vscl <= 17;
        123: vscl <= 17;
        124: vscl <= 17;
        125: vscl <= 16;
        126: vscl <= 16;
        127: vscl <= 16;
        128: vscl <= 16;
        129: vscl <= 16;
        130: vscl <= 16;
        131: vscl <= 16;
        132: vscl <= 16;
        133: vscl <= 15;
        134: vscl <= 15;
        135: vscl <= 15;
        136: vscl <= 15;
        137: vscl <= 15;
        138: vscl <= 15;
        139: vscl <= 15;
        140: vscl <= 15;
        141: vscl <= 15;
        142: vscl <= 14;
        143: vscl <= 14;
        144: vscl <= 14;
        145: vscl <= 14;
        146: vscl <= 14;
        147: vscl <= 14;
        148: vscl <= 14;
        149: vscl <= 14;
        150: vscl <= 14;
        151: vscl <= 14;
        152: vscl <= 13;
        153: vscl <= 13;
        154: vscl <= 13;
        155: vscl <= 13;
        156: vscl <= 13;
        157: vscl <= 13;
        158: vscl <= 13;
        159: vscl <= 13;
        160: vscl <= 13;
        161: vscl <= 13;
        162: vscl <= 13;
        163: vscl <= 13;
        164: vscl <= 12;
        165: vscl <= 12;
        166: vscl <= 12;
        167: vscl <= 12;
        168: vscl <= 12;
        169: vscl <= 12;
        170: vscl <= 12;
        171: vscl <= 12;
        172: vscl <= 12;
        173: vscl <= 12;
        174: vscl <= 12;
        175: vscl <= 12;
        176: vscl <= 12;
        177: vscl <= 12;
        178: vscl <= 12;
        179: vscl <= 11;
        180: vscl <= 11;
        181: vscl <= 11;
        182: vscl <= 11;
        183: vscl <= 11;
        184: vscl <= 11;
        185: vscl <= 11;
        186: vscl <= 11;
        187: vscl <= 11;
        188: vscl <= 11;
        189: vscl <= 11;
        190: vscl <= 11;
        191: vscl <= 11;
        192: vscl <= 11;
        193: vscl <= 11;
        194: vscl <= 11;
        195: vscl <= 11;
        196: vscl <= 10;
        197: vscl <= 10;
        198: vscl <= 10;
        199: vscl <= 10;
        200: vscl <= 10;
        201: vscl <= 10;
        202: vscl <= 10;
        203: vscl <= 10;
        204: vscl <= 10;
        205: vscl <= 10;
        206: vscl <= 10;
        207: vscl <= 10;
        208: vscl <= 10;
        209: vscl <= 10;
        210: vscl <= 10;
        211: vscl <= 10;
        212: vscl <= 10;
        213: vscl <= 10;
        214: vscl <= 10;
        215: vscl <= 10;
        216: vscl <= 9;
        217: vscl <= 9;
        218: vscl <= 9;
        219: vscl <= 9;
        220: vscl <= 9;
        221: vscl <= 9;
        222: vscl <= 9;
        223: vscl <= 9;
        224: vscl <= 9;
        225: vscl <= 9;
        226: vscl <= 9;
        227: vscl <= 9;
        228: vscl <= 9;
        229: vscl <= 9;
        230: vscl <= 9;
        231: vscl <= 9;
        232: vscl <= 9;
        233: vscl <= 9;
        234: vscl <= 9;
        235: vscl <= 9;
        236: vscl <= 9;
        237: vscl <= 9;
        238: vscl <= 9;
        239: vscl <= 9;
        240: vscl <= 9;
        241: vscl <= 8;
        242: vscl <= 8;
        243: vscl <= 8;
        244: vscl <= 8;
        245: vscl <= 8;
        246: vscl <= 8;
        247: vscl <= 8;
        248: vscl <= 8;
        249: vscl <= 8;
        250: vscl <= 8;
        251: vscl <= 8;
        252: vscl <= 8;
        253: vscl <= 8;
        254: vscl <= 8;
        255: vscl <= 8;
    endcase
end

endmodule
