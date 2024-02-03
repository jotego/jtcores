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
// than in 8-bit mode (595us, accounting for some inaccuracy in the measurement)

// This implementation has a first phase that clears out the internal buffer
// and then sprites are copied by their priority code into memory, so they
// naturally fall in order.
// The original one likely has the same clear phase but executed right after
// the vs edge and lasting for a whole line.
// The DMA timing has been matched with the original, despite of the different
// buffer-clear logic

module jt053246(    // sprite logic
    input             rst,
    input             clk,
    input             pxl2_cen,
    input             pxl_cen,

    input             k44_en,   // enable k053244/5 mode (default k053246/7)
    // CPU interface
    input             cs,
    input             cpu_we,
    input      [ 3:1] cpu_addr, // bit 3 only in k44 mode
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
reg  [ 1:0] reserved, vs_sh;

reg  [ 9:0] vzoom;
reg  [ 2:0] hstep, hcode;
reg  [ 1:0] scan_sub;
reg  [ 8:0] vlatch, ymove;
reg  [ 9:0] y, y2, x, ydiff, ydiff_b;
reg  [ 7:0] scan_obj; // max 256 objects
reg         dma_44, dma_clr, dma_wait, inzone, hs_l, done, hdone;
wire [15:0] scan_even, scan_odd;
reg  [15:0] dma_bufd;
reg  [ 3:0] size;
wire [15:0] dma_din;
wire [11:1] dma_wr_addr;
reg  [11:1] dma_bufa;
wire [11:2] scan_addr;
wire        last_obj, hs_pos;
reg  [18:0] yz_add;
reg         dma_ok, vmir, hmir, sq, pre_vf, pre_hf, indr, hsl,
            vmir_eff, flicker, vs_l;
wire        cpu_bsy;
wire        ghf, gvf, mode8, dma_en;
reg  [ 8:0] full_h, vscl, hscl, full_w;
reg  [ 8:0] zoffset[0:255];

assign ghf     = cfg[0]; // global flip
assign gvf     = cfg[1];
assign mode8   = cfg[2]; // guess, use it for 8-bit access for ROM checking (Parodius)
assign cpu_bsy = cfg[3];
assign dma_en  = cfg[4];
assign vflip   = pre_vf ^ vmir_eff;
assign hflip   = pre_hf ^ hmir;
assign hs_pos  = hs & ~hsl;

assign dma_din     = dma_clr ? 16'h0 : dma_bufd;
assign dma_we      = dma_clr | dma_ok;
assign dma_wr_addr = dma_clr ? dma_addr[11:1] : dma_bufa;
assign dma_44      = k44_en && cs && cpu_addr==3 && !cpu_dsn[0];

assign scan_addr   = { scan_obj, scan_sub };
assign ysub        = ydiff[3:0];
assign last_obj    = &scan_obj;

always @(posedge clk) begin
    /* verilator lint_off WIDTH */
    yz_add  <= vzoom*ydiff_b; // vzoom < 10'h40 enlarge, >10'h40 reduce
                              // opposite to the one in Aliens, which always
                              // shrunk for non-zero zoom values
    /* verilator lint_on WIDTH */
end

function [8:0] zmove( input [1:0] sz, input[8:0] scl );
    case( sz )
        0: zmove = scl>>2;
        1: zmove = scl>>1;
        2: zmove = scl;
        3: zmove = scl<<1;
    endcase
endfunction

always @* begin
    ymove  = zmove( size[3:2], vscl );
    y2     = y + {1'b0,ymove};
    ydiff_b= y2 + { vlatch[8], vlatch } - 10'd8;
    ydiff  = yz_add[6+:10];
    // assuming  mirroring applies to a single 16x16 tile, not the whole size
    vmir_eff = vmir && size[3:2]==0 && !ydiff[3];
    case( size[3:2] )
        0: inzone = ydiff_b[9]==ydiff[9] && ydiff[9:4]==0; // 16
        1: inzone = ydiff_b[9]==ydiff[9] && ydiff[9:5]==0; // 32
        2: inzone = ydiff_b[9]==ydiff[9] && ydiff[9:6]==0; // 64
        3: inzone = ydiff_b[9]==ydiff[9] && ydiff[9:7]==0; // 128
    endcase
    if( y2[9] ) inzone=0;
    case( size[1:0] )
        0: hdone = 1;
        1: hdone = hstep==1;
        2: hdone = hstep==3;
        3: hdone = hstep==7;
    endcase
    if( y[9] ) inzone=0;
end

// DMA logic
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dma_bsy  <= 0;
        dma_clr  <= 0;
        dma_wait <= 0;
        dma_addr <= 0;
        dma_bufa <= 0;
        dma_bufd <= 0;
        dma_bsy  <= 0;
        dma_wait <= 0;
        hsl      <= 0;
        flicker  <= 0;
    end else if( pxl2_cen ) begin
        hsl <= hs;
        if( hs_pos ) begin
            vs_sh    <= vs_sh<<1;
            vs_sh[0] <= vs;
        end
        if( (vs_sh==2'b10 && hs_pos) || dma_44 ) begin
            dma_bsy  <= dma_en | dma_44;
            dma_clr  <= 1;
            dma_wait <= 1;
            flicker  <= ~flicker;
            dma_addr <= 0;
        end
        // this implementation matches 8-bit speed, ie 595us vs 297.5us for 16-bit mode
        if( !dma_bsy ) begin
            dma_addr <= 0;
            dma_bufa <= 0;
            dma_ok   <= 0;
        end else if( dma_clr ) begin // copy by priority order
            { dma_clr, dma_addr[11:1] } <= { 1'b1, dma_addr[11:1] } + 1'd1;
            if( &dma_addr[11:1] ) dma_addr[11:1] <= 'h218; // extra 126us wait
        end else if(dma_wait) begin // extra time to match the original speed
            { dma_wait, dma_addr[11:1] } <= { 1'b1, dma_addr[11:1] } + 1'd1;
        end else begin
            dma_bufd <= dma_data;
            if( dma_addr[3:1]==0 ) begin
                dma_bufa <= { dma_data[7:0], 3'd0 };
                dma_ok <= dma_data[15] && dma_data[7:0]!=0; // priority 0 is skipped. See Simpsons scene 4
            end
            { dma_bsy, dma_addr[12:1] } <= { 1'b1, dma_addr[12:1] } + 1'd1;
            dma_bufa[3:1] <= dma_addr[3:1];
            if( dma_addr[3:1]==6 ) begin
                { dma_bsy, dma_addr[12:1] } <= { 1'b1, dma_addr[12:1] } + 13'd2; // skip 7
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
        indr     <= 0;
    end else if( cen2 ) begin
        hs_l <= hs;
        vs_l <= vs;
        dr_start <= 0;
        if( hs && !hs_l && vdump>9'h10D && vdump<9'h1f1) begin
            done     <= 0;
            scan_obj <= 0;
            scan_sub <= 0;
            vlatch   <= vdump;
            if( scan_obj!=0 ) $display("Obj scan did not finish. Last obj %X",scan_obj);
        end else if( !done ) begin
            {indr, scan_sub} <= {indr, scan_sub} + 1'd1;
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
                    x <=  x + 10'h28;
                    y <=  y /*- yoffset[8:0]*/ + 10'h380;
                    vzoom <= scan_even[9:0];
                    hzoom <= sq ? scan_even[9:0] : scan_odd[9:0];
                end
                3: begin
                    if( k44_en )
                        { vmir, hmir, shd[0], attr[6:0] } <= scan_even[9:0];
                    else
                        { vmir, hmir, reserved, shd, attr } <= scan_even;
                end
                4: begin
                    // Add the vertical offset to the code, must wait for zoom
                    // calculations, so it cannot be done at step 3
                    case( size[3:2] ) // could be + or |
                        1: {code[5],code[3],code[1]} <= {code[5],code[3],code[1]} + { 2'd0, ydiff[4]^vflip   };
                        2: {code[5],code[3],code[1]} <= {code[5],code[3],code[1]} + { 1'd0, ydiff[5:4]^{2{vflip}} };
                        3: {code[5],code[3],code[1]} <= {code[5],code[3],code[1]} + ( ydiff[6:4]^{3{vflip}});
                    endcase
                    // will !x[9] create problems in large sprites?
                    // it is needed to prevent the police car from showing up
                    // at the end of level 1 in Simpsons (see scene 3)
                    if( !inzone || x[9]) begin
                        { indr, scan_sub } <= 0;
                        scan_obj <= scan_obj + 1'd1;
                        if( last_obj ) done <= 1;
                    end
                end
                default: begin // in draw state
                    {indr, scan_sub} <= 5; // stay here
                    if( (!dr_start && !dr_busy) || !inzone ) begin
                        case( size[1:0] )
                            0: {code[4],code[2],code[0]} <= hcode;
                            1: {code[4],code[2],code[0]} <= hcode + {2'd0,hstep[0]^hflip};
                            2: {code[4],code[2],code[0]} <= hcode + {1'd0,hstep[1:0]^{2{hflip}}};
                            3: {code[4],code[2],code[0]} <= hcode + (hstep[2:0]^{3{hflip}});
                        endcase
                        if( hstep==0 ) begin
                            hpos <= x[8:0] - zmove( size[1:0], hscl );
                        end else begin
                            hpos <= hpos + 9'h10;
                            hz_keep <= 1;
                        end
                        hstep <= hstep + 1'd1;
                        dr_start <= inzone;
                        if( hdone || !inzone ) begin
                            { indr, scan_sub } <= 0;
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
            case( {cpu_addr[3] & k44_en, cpu_addr[2:1]} )
                0: begin
                    if( !cpu_dsn[0] ) xoffset[ 7:0] <= cpu_dout[7:0];
                    if( !cpu_dsn[1] ) xoffset[ 9:8] <= cpu_dout[9:8];
                end
                1: begin
                    if( !cpu_dsn[0] ) yoffset[7:0] <= cpu_dout[7:0];
                    if( !cpu_dsn[1] ) yoffset[9:8] <= cpu_dout[9:8];
                end
                2: begin
                    if( !cpu_dsn[0] && !k44_en ) rmrd_addr[8:1] <= cpu_dout[7:0];
                    if( !cpu_dsn[1] ) cfg <= cpu_dout[15:8];
                end
                3: if( !k44_en ) begin // related to dma_en, see above
                    if( !cpu_dsn[0] ) rmrd_addr[16: 9] <= cpu_dout[ 7:0];
                    if( !cpu_dsn[1] ) rmrd_addr[21:17] <= cpu_dout[12:8];
                end
                // k44_en only
                4: begin
                    if( !cpu_dsn[0] ) rmrd_addr[ 8: 1] <= cpu_dout[ 7:0];
                    if( !cpu_dsn[1] ) rmrd_addr[16: 9] <= cpu_dout[15:8];
                end
                5: begin
                    if( !cpu_dsn[0] ) rmrd_addr[21:17] <= cpu_dout[ 4:0];
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

initial zoffset ='{                             //  octal count
    511, 511, 511, 511, 511, 410, 341, 293,     //   0-  7
    256, 228, 205, 186, 171, 158, 146, 137,     //  10- 17
    128, 120, 114, 108, 102,  98,  93,  89,     //  20- 27
     85,  82,  79,  76,  73,  71,  68,  66,     //  30- 37
     64,  62,  60,  59,  57,  55,  54,  53,     //  40- 47
     51,  50,  49,  48,  47,  46,  45,  44,     //  50- 57
     43,  42,  41,  40,  39,  39,  38,  37,     //  60- 67
     37,  36,  35,  35,  34,  34,  33,  33,     //  70- 77
     32,  32,  31,  31,  30,  30,  29,  29,     // 100-107
     28,  28,  28,  27,  27,  27,  26,  26,     // 110-117
     26,  25,  25,  25,  24,  24,  24,  24,     // 120-127
     23,  23,  23,  23,  22,  22,  22,  22,     // 130-137
     21,  21,  21,  21,  20,  20,  20,  20,     // 140-147
     20,  20,  19,  19,  19,  19,  19,  18,     // 150-157
     18,  18,  18,  18,  18,  18,  17,  17,     // 160-167
     17,  17,  17,  17,  17,  16,  16,  16,     // 170-177
     16,  16,  16,  16,  16,  15,  15,  15,     // 200-207
     15,  15,  15,  15,  15,  15,  14,  14,     // 210-217
     14,  14,  14,  14,  14,  14,  14,  14,     // 220-122
     13,  13,  13,  13,  13,  13,  13,  13,     // 230-237
     13,  13,  13,  13,  12,  12,  12,  12,     // 240-247
     12,  12,  12,  12,  12,  12,  12,  12,     // 250-257
     12,  12,  12,  11,  11,  11,  11,  11,     // 260-267
     11,  11,  11,  11,  11,  11,  11,  11,     // 270-277
     11,  11,  11,  11,  10,  10,  10,  10,     // 300-307
     10,  10,  10,  10,  10,  10,  10,  10,     // 310-317
     10,  10,  10,  10,  10,  10,  10,  10,     // 320-327
      9,   9,   9,   9,   9,   9,   9,   9,     // 330-337
      9,   9,   9,   9,   9,   9,   9,   9,     // 340-347
      9,   9,   9,   9,   9,   9,   9,   9,     // 350-357
      9,   8,   8,   8,   8,   8,   8,   8,     // 360-367
      8,   8,   8,   8,   8,   8,   8,   8      // 370-377
};

always @(posedge clk) begin
    vscl <= zoffset[ vzoom[7:0] ];
    hscl <= zoffset[ hzoom[7:0] ];
end

endmodule
