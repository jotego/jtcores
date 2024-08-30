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

// See JTSIMSON's README.md

module jt053246(    // sprite logic
    input             rst,
    input             clk,
    input             pxl2_cen,
    input             pxl_cen,

    input             simson,   // enables temporary hack for The Simpsons
    // input             xmen,     // enables yoffset for xmen
    // CPU interface
    input             cs,
    input             cpu_we,
    input      [ 3:0] cpu_addr, // bit 3 only in k44 mode
    input      [15:0] cpu_dout,
    input      [ 1:0] cpu_dsn,  // only used for MMR in 16-bit mode

    // ROM check by CPU
    output     [21:1] rmrd_addr,

    // External RAM
    output     [13:1] dma_addr, // up to 16 kB
    input      [15:0] dma_data,
    output            dma_bsy,

    // ROM addressing 22 bits in total
    output reg [15:0] code,
    // There are 22 bits communicating both chips on the PCB
    output reg [ 9:0] attr,     // OC pins
    output            hflip,
    output reg        vflip,
    output reg [ 8:0] hpos,
    output     [ 3:0] ysub,
    output reg [11:0] hzoom,
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
    output     [ 7:0] st_dout
);
parameter XMEN = 0;

localparam [2:0] REG_XOFF  = 0, // X offset
                 REG_YOFF  = 1, // Y offset
                 REG_CFG   = 2; // interrupt control, ROM read

reg  [18:0] yz_add;
reg  [11:0] vzoom;
reg  [ 9:0] y, y2, x, ydiff, ydiff_b, xadj, yadj, ywrap, yw0;
reg  [ 8:0] vlatch, ymove, full_h, vscl, hscl, full_w;
reg  [ 7:0] scan_obj; // max 256 objects
reg  [ 3:0] size;
reg  [ 2:0] hstep, hcode, hsum, vsum;
reg  [ 1:0] scan_sub, reserved;
reg         inzone, hs_l, done, hdone,
            vmir, hmir, sq, pre_vf, pre_hf, indr,
            hmir_eff, vmir_eff, vs_l, hhalf;
wire [15:0] scan_even, scan_odd, dma_din;
wire [11:2] scan_addr;
wire [11:1] dma_wr_addr;
wire [ 9:0] xoffset, yoffset;
wire [ 7:0] cfg;
wire [ 1:0] nx_mir, hsz, vsz;
wire        dma_wel, dma_weh, last_obj, vb_rd,
            cpu_bsy, ghf, gvf, mode8, dma_en, flicker;
reg  [ 8:0] zoffset [0:255];
reg  [ 3:0] pzoffset[0:15 ];

assign ghf       = cfg[0]; // global flip
assign gvf       = cfg[1];
assign mode8     = cfg[2]; // guess, use it for 8-bit access on 46/47 pair
assign cpu_bsy   = cfg[3];
assign dma_en    = cfg[4];
assign hflip     = ghf ^ pre_hf ^ hmir_eff;
assign scan_addr = { scan_obj, scan_sub };
assign ysub      = ydiff[3:0];
assign last_obj  = &scan_obj[7:0];
assign nx_mir    = scan_even[15:14];
assign {vsz,hsz} = size;

(* direct_enable *) reg cen2=0;
always @(negedge clk) cen2 <= ~cen2;

always @(posedge clk) begin
    xadj <= xoffset - 10'd61 /*{debug_bus,2'd0}*/;
    yadj <= yoffset + (XMEN==1   ? 10'h107 :
                       simson    ? 10'h11f : 10'h10f); // Vendetta (and Parodius)
    vscl <= zoffset[ vzoom[7:0] ];
    hscl <= zoffset[ hzoom[7:0] ];
    /* verilator lint_off WIDTH */
    yz_add  <= vzoom[9:0]*ydiff_b; // vzoom < 10'h40 enlarge, >10'h40 reduce
                                   // opposite to the one in Aliens, which always
                                   // shrunk for non-zero zoom values
    /* verilator lint_on WIDTH */
    yw0   = y + yadj;
    ywrap = yw0 > 10'h200 ? yw0 + 10'h1A0 : yw0;
end

function [8:0] zmove( input [1:0] sz, input[8:0] scl );
    case( sz )
        0: zmove = scl>>2;
        1: zmove = scl>>1;
        2: zmove = scl;
        3: zmove = scl<<1;
    endcase
endfunction

function [8:0] red_offset( input [11:0] zoom, input [ 8:0] offset1 [0:255], input [3:0] offset2[0:15]);
    case( zoom[11:8] )
        0:       red_offset =       offset1 [zoom[7:0]];
        1:       red_offset = {5'b0,offset2 [zoom[7:4]]};
        2:       red_offset =  9'd3;
        4,3:     red_offset =  9'd2;
        default: red_offset =  9'd1;
    endcase
endfunction 

always @* begin
    ymove  = zmove( vsz, vscl );
    y2     = y + {1'b0,ymove};
    ydiff_b= y2 + { vlatch[8], vlatch } - 10'd8;
    ydiff  = yz_add[6+:10];
    // test ver/game/scene/1 -> shadow, scan_obj 9
    // test ver/parodius/scene/9 -> "bomb", scan_obj 5
    case( vsz )
        0: vmir_eff = nx_mir[1] && !ydiff[3];
        1: vmir_eff = nx_mir[1] && !ydiff[4];
        2: vmir_eff = nx_mir[1] && !ydiff[5];
        3: vmir_eff = nx_mir[1] && !ydiff[6];
    endcase
    hmir_eff = hmir & hhalf;
    case( vsz )
        0: inzone = ydiff_b[9]==ydiff[9] && ydiff[9:4]==0; // 16
        1: inzone = ydiff_b[9]==ydiff[9] && ydiff[9:5]==0; // 32
        2: inzone = ydiff_b[9]==ydiff[9] && ydiff[9:6]==0; // 64
        3: inzone = ydiff_b[9]==ydiff[9] && ydiff[9:7]==0; // 128
    endcase
    if( y2[9] || yz_add[16] ) inzone=0;
    case( hsz )
        0: hdone = 1;
        1: hdone = hstep==1;
        2: hdone = hstep==3;
        3: hdone = hstep==7;
    endcase
    if( y[9] ) inzone=0;
    case( hsz )
        0: hsum = 0;
        1: hsum = hmir ? 3'd0                           : {2'd0,hstep[0]^hflip};
        2: hsum = hmir ? {2'd0,hstep[0]^hflip}          : {1'd0,hstep[1:0]^{2{hflip}}};
        3: hsum = hmir ? ({1'b0,hstep[1:0]^{2{hflip}}}) : hstep[2:0]^{3{hflip}};
    endcase
    case( vsz )
        0: vsum = 0;
        1: vsum = { 2'd0, ydiff[4]^vflip   };
        2: vsum = { 1'd0, ydiff[5:4]^{2{vflip}} };
        3: vsum = ydiff[6:4]^{3{vflip}};
    endcase
end

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
        vflip    <= 0;
        vzoom    <= 0;
        hzoom    <= 0;
        hz_keep  <= 0;
        indr     <= 0;
        hhalf    <= 0;
        shd      <= 0;
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
                    hhalf <= 0;
                    { sq, pre_vf, pre_hf, size } <= scan_even[14:8];
                    code    <= scan_odd;
                    hstep   <= 0;
                    hz_keep <= 0;
                    // if( !scan_even[15]  || scan_obj[6:0]!=5  ) begin
                    if( !scan_even[15] /*`ifndef JTFRAME_RELEASE || (scan_obj[6:0]==debug_bus[6:0] && flicker) `endif*/ ) begin
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
                    x <= x-xadj;
                    y <=  ywrap;
                    vzoom <= {2'b0, scan_even[9:0]};
                    hzoom <= sq ? {2'b0, scan_even[9:0]} : {2'b0, scan_odd[9:0]};
                end
                3: begin
                    { vmir, hmir } <= nx_mir;
                    { reserved, shd, attr } <= scan_even[13:0];
                    vflip <= pre_vf ^ gvf ^ vmir_eff;
                end
                4: begin
                    // Add the vertical offset to the code, must wait for zoom
                    // calculations, so it cannot be done at step 3
                    {code[5],code[3],code[1]} <= {code[5],code[3],code[1]} + vsum;
                    // will !x[9] create problems in large sprites?
                    // it is needed to prevent the police car from showing up
                    // at the end of level 1 in Simpsons (see scene 3)
                    if( ~inzone | x[9] ) begin
                        { indr, scan_sub } <= 0;
                        scan_obj <= scan_obj + 1'd1;
                        if( last_obj ) done <= 1;
                    end
                end
                default: begin // in draw state
                    case( hsz )
                        1: if(hstep>=1) hhalf <= 1;
                        2: if(hstep>=2) hhalf <= 1;
                        3: if(hstep>=4) hhalf <= 1;
                    endcase
                    {indr, scan_sub} <= 5; // stay here
                    if( (!dr_start && !dr_busy) || !inzone ) begin
                        {code[4],code[2],code[0]} <= hcode + hsum;
                        if( hstep==0 ) begin
                            hpos <= x[8:0] - zmove( hsz, hscl );
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
                            // hz_keep <= 0;
                            if( last_obj ) done <= 1;
                        end
                    end
                end
            endcase
        end
    end
end

jt053246_dma u_dma(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),

    .mode8      ( mode8     ),
    .dma_en     ( dma_en    ),
    .dma_trig   ( 1'b0      ),
    .k44_en     ( 1'b0      ),   // enable k053244/5 mode (default k053246/7)
    .simson     ( simson    ),

    .hs         ( hs        ),
    .vs         ( vs        ),

    // External RAM
    .dma_addr   ( dma_addr  ), // up to 16 kB
    .dma_data   ( dma_data  ),
    .dma_bsy    ( dma_bsy   ),

    .dma_weh    ( dma_weh   ),
    .dma_wel    ( dma_wel   ),
    .dma_wr_addr(dma_wr_addr),
    .dma_din    ( dma_din   ),

    .flicker    ( flicker   )  // debug
);

jt053246_mmr u_mmr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .k44_en     ( 1'b0      ),
    .cs         ( cs        ),
    .cpu_we     ( cpu_we    ),
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_dsn    ( cpu_dsn   ),
    .cfg        ( cfg       ),
    .xoffset    ( xoffset   ),
    .yoffset    ( yoffset   ),
    .rmrd_addr  ( rmrd_addr ),
    .st_addr    ( st_addr   ),
    .st_dout    ( st_dout   )
);

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

endmodule
