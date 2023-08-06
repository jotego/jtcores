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
reg  [ 9:0] y, x;
reg  [ 7:0] dma_prio, scan_obj; // max 256 objects
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
reg         dma_ok, vmir, hmir, sq, pre_vf, pre_hf, indr, hsl;
wire        busy_g, cpu_bsy;
wire        ghf, gvf, dma_en;

assign ghf     = cfg[0]; // global flip
assign gvf     = cfg[1];
assign cpu_bsy = cfg[3];
assign dma_en  = cfg[4];
assign vflip   = pre_vf & ~vmir;
assign hflip   = pre_hf & ~hmir;

assign dma_din     = dma_clr ? 16'h0 : dma_bufd;
assign dma_we      = dma_clr | dma_ok;
assign dma_wr_addr = dma_clr ? dma_addr[11:1] : dma_bufa;

assign scan_addr   = { scan_obj, scan_sub };
assign ysub        = ydiff[3:0];
assign busy_g      = busy_l | dr_busy;
assign last_obj    = &scan_obj;


always @(posedge clk) begin
    /* verilator lint_off WIDTH */
    yz_add <= vzoom*ydiff_b; // vzoom < 10'h40 enlarge, >10'h40 reduce
    /* verilator lint_on WIDTH */
end

always @* begin
    case( size[3:2] )
        1: ydiff_b = 9'h08;
        2: ydiff_b = 9'h18;
        3: ydiff_b = 9'h28;
        default: ydiff_b = 0;
    endcase
    ydiff_b= ydiff_b + y[8:0] + vlatch;
    /* verilator lint_off WIDTH */
    ydiff  = /*ydiff_b +*/ yz_add>>6;
    /* verilator lint_on WIDTH */
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
            dma_prio <= 0;
        end else if( dma_bsy ) begin // copy by priority order
            dma_bsy  <= 1;
            dma_bufd <= dma_data;
            if( dma_addr[3:1]==0 ) begin
                dma_bufa <= { dma_data[7:0], 3'd0 }; // is dma_prio==0 special?
                dma_ok <= dma_data[15];
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
    end else if( cen2 ) begin
        hs_l <= hs;
        busy_l <= dr_busy;
        dr_start <= 0;
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
                    if( !scan_even[15] ) begin
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
                    vzoom <= scan_even[9:0];
                    hzoom <= sq ? scan_even[9:0] : scan_odd[9:0];
                end
                3: begin
                    //{ vmir, hmir, reserved, shd, attr } <= scan_even;
                    { vmir, hmir, reserved, shd, attr } <= {2'd0,scan_even[13:0]};
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
                        dr_start <= inzone;
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

endmodule
