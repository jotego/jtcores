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
    Date: 29-8-2023 */

// Based on Skutis' RE work on die shots
// and MAME documentation

// 16 kB external RAM holding 76 sprites, 16 bytes each
// but separated $50 (80 bytes) from each other
// $3000 (3/4) of the RAM contain the data
// the latter $1000 keeps a prioritized copy in packets of 8 bytes
// or max $200 objects (512) in total
// but the priority seem to be encoded in one byte, so
// max objects is $100 = 256

// DMA clear phase lasts for 2 lines
// DMA copying takes 6.41 lines after DMA clear
// that's 400.625us -> 2461 pxl
// that's about 4 pxl/read -> 32 pxl/sprite

// the RAM is copied during the first x lines of VBLANK
// the process is only done if the sprite logic is enabled
// and it gets halted while the CPU tries to write to the memory
// only active sprites (bit 7 of byte 0 set) are copied

// sprite tiles are 16x16x4


module jt00778x#(parameter CW=17)(    // sprite logic
    input             rst,
    input             clk,
    input             pxl_cen,

    // CPU interface
    // input             cs,
    // input             cpu_we,
    // input      [ 7:0] cpu_dout,
    // input      [10:0] cpu_addr,
    // output     [ 7:0] cpu_din,

    // ROM addressing
    output reg [CW-1:0] code,
    output reg [ 3:0] attr,
    output reg        hflip,
    output reg [ 8:0] hpos,
    output reg [ 1:0] hsize,

    // DMA memory
    output     [13:1] oram_addr,
    input      [15:0] oram_dout,
    output reg [15:0] oram_din,
    output reg        oram_we,
    // control
    input             dma_on,
    output reg        dma_bsy,
    input      [ 8:0] hdump,    // Not inputs in the original, but
    input      [ 8:0] vdump,    // generated internally.
                                // Hdump goes from 20 to 19F, 384 pixels
                                // Vdump goes from F8 to 1FF, 264 lines
    input             vs,
    input             hs,
    input             lvbl,
    input      [ 9:0] obj_dx, obj_dy,
    // output            flip,

    // draw module
    output reg        dr_start,
    input             dr_busy,

    input      [ 7:0] debug_bus
    // output reg [ 7:0] st_dout
);

reg         beflag, lvbl_l, obj_en, vflip,
            dma_clr, dma_cen;
reg  [13:1] cpr_addr; // copy read  address
reg  [10:1] cpw_addr; // copy write address
wire [ 4:1] nx_cpra;
wire [15:0] scan_dout;
reg  [ 1:0] vsize;
reg  [ 2:0] scan_sub, lut_sub;
reg         inzone, hs_l, done, busy_l, skip;
reg  [ 8:0] ydiff, y, vlatch;
reg  [ 7:0] scan_obj, lut_obj, lut_dst;
reg  [ 6:0] ydf;
wire        flip = 0, busy_g;


assign oram_addr = !dma_bsy ? { 3'b110, `ifdef NOLUTFB
                scan_obj, scan_sub[1:0] `else lut_obj, ~lut_sub[1:0] `endif } :
                oram_we ? { 3'b110, cpw_addr } : cpr_addr;
assign nx_cpra   = {1'd0, cpr_addr[3:1]} + 4'd1;
assign busy_g    = busy_l | dr_busy;

`ifdef SIMULATION
wire [13:0] cpr_afull = {cpr_addr,1'b0};
wire [13:0] cpw_afull = { 3'b110, cpw_addr,1'b0};
`endif

// DMA logic
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dma_clr  <= 0;
        oram_we  <= 0;
        dma_bsy <= 0;
        cpr_addr <= 0;
        cpw_addr <= 0;
        dma_cen  <= 0; // 3 MHz
        obj_en   <= 0;
        oram_din <= 0;
        beflag   <= 0;
        lvbl_l   <= 0;
    end else if( pxl_cen ) begin
        lvbl_l <= lvbl;
        if( !lvbl && lvbl_l ) begin
            dma_bsy <= 1;
            obj_en  <= ~dma_on;
        end
        dma_cen <= ~dma_cen; // not really a cen, must be combined with pxl_cen
        if( lvbl ) begin
            dma_clr  <= 1;
            cpr_addr <= 0;
            cpw_addr <= 0;
            oram_we  <= 0;
            oram_din <= 0;
            beflag   <= 0;
        end else if( dma_bsy ) begin
            if( dma_clr && dma_cen ) begin
                { dma_clr, cpw_addr } <= { 1'b1, cpw_addr } + 1'h1;
                oram_we <= 1;
            end else if( !dma_clr ) begin // direct copy
                if( !dma_cen ) begin
                    case( cpr_addr[3:1] )
                        0: begin
                            cpw_addr[10:3] <= oram_dout[7:0];
                            oram_din <= 0;
                            beflag   <= oram_dout[15] && obj_en;
                        end
                        2: begin // flags
                            cpw_addr[2:1] <= 3;
                            oram_din <= { 1'b1,5'd0, oram_dout[9:0] };
                            oram_we  <= beflag;
                            // if(beflag) $display("OBJ %X flags %X (hsize=%d, vsize=%d)",
                            //     cpw_addr[10:3], { 1'b1,5'd0, oram_dout[9:0] },
                            //     8'h10<<oram_dout[5:4], 8'h10<<oram_dout[7:6] );
                        end
                        3: begin // code
                            cpw_addr[2:1] <= 0;
                            oram_din <= oram_dout;
                            oram_we  <= beflag;
                            // if(beflag) $display("        code %X", oram_dout );
                        end
                        4: oram_din[15:8] <= oram_dout[7:0];
                        5: begin // x
                            cpw_addr[2:1] <= 2;
                            oram_din[7:0] <= oram_dout[15:8];
                            oram_we  <= beflag;
                            // if(beflag) $display("        x =  %X", {oram_din[15:8],oram_dout[15:8]} );
                        end
                        6: oram_din[15:8] <= oram_dout[7:0];
                        7: begin // y
                            cpw_addr[2:1] <= 1;
                            oram_din[7:0] <= oram_dout[15:8];
                            oram_we  <= beflag;
                            // if(beflag) $display("        y =  %X", {oram_din[15:8],oram_dout[15:8]} );
                        end
                    endcase
                end else begin
                    cpr_addr[3:1] <= nx_cpra[3:1];
                    if( nx_cpra[4] ) begin
                        cpr_addr[13:4] <= cpr_addr[13:4]+10'h5;
                        dma_bsy <= cpr_addr<'h17d7;
                    end
                    oram_we <= 0;
                end
            end
        end
    end
end

reg bsy_l;

`ifndef NOLUTFB
    // frame buffer for look-up table, plus clean up
    reg lut_done, lut_clr, lut_we;
    wire [15:0] lut_din = lut_done ? 16'h4000 : oram_dout;
    wire        lut_clr_end;

    assign lut_clr_end = &{lut_dst, lut_sub[1:0] };

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            lut_done <= 0;
            lut_clr  <= 0;
            lut_obj  <= 0;
            lut_sub  <= 0;
            lut_dst  <= 0;
            lut_we   <= 0;
        end else if(cen2) begin
            bsy_l <= dma_bsy;
            if( !dma_bsy && bsy_l ) begin
                lut_done <= 0;
                lut_clr  <= 0;
                lut_obj  <= 0;
                lut_sub  <= 0;
                lut_dst  <= 0;
                lut_we   <= 0;
            end else if( !lut_done ) begin
                lut_sub <= lut_sub + 1'd1;
                lut_we  <= 1;
                case( lut_sub )
                    0: begin
                        if( !oram_dout[15] ) begin
                            lut_sub  <= 0;
                            lut_obj  <= lut_obj+1'd1;
                            lut_done <= &lut_obj;
                        end
                    end
                    3: begin
                        lut_dst <= lut_dst+1'd1;
                        lut_sub <= 0;
                        lut_obj <= lut_obj+1'd1;
                        lut_done <= &lut_obj;
                    end
                endcase
            end else if( !lut_clr ) begin
                lut_we <= ~lut_clr_end;
                { lut_dst, lut_sub[1:0] } <= { lut_dst, lut_sub[1:0] } + 1'd1;
                lut_clr <= lut_clr_end;
            end else begin
                lut_we <= 0;
            end
        end
    end

    jtframe_dual_ram16 u_copy(
        // Port 0: LUT writting
        .clk0   ( clk            ),
        .data0  ( lut_din        ),
        .addr0  ({lut_dst,~lut_sub[1:0]}),
        .we0    ( {2{lut_we}}    ),
        .q0     (                ),
        // Port 1: scan
        .clk1   ( clk            ),
        .data1  ( 16'd0          ),
        .addr1  ({scan_obj,scan_sub[1:0]}),
        .we1    ( 2'b0           ),
        .q1     ( scan_dout      )
    );
`else
    assign scan_dout = oram_dout;
`endif

(* direct_enable *) reg cen2=0;
always @(negedge clk) cen2 <= ~cen2;

// Table scan
always @* begin
    ydiff = vlatch - y;
    case( vsize )
        0: inzone = ydiff[8:4]==0; //  16
        1: inzone = ydiff[8:5]==0; //  32
        2: inzone = ydiff[8:6]==0; //  64
        3: inzone = ydiff[8:7]==0; // 128
    endcase
end

// code
// EDCBEA9876543210VVVV   16 pixel wide
// EDCBEA987654321VVVVH   32 pixel wide
// EDCBEA98765432VVVVHH   64 pixel wide
// EDCBEA9876543VVVVHHH   64 pixel wide
// EDCBEA987654321VVVVH   32x16
// EDCBEA98765432VVVVVH   32x32
// EDCBEA987654VVVVVVHH   64x64

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hs_l     <= 0;
        scan_obj <= 0;
        scan_sub <= 0;
        code     <= 0;
        attr     <= 0;
        vflip    <= 0;
        hflip    <= 0;
        busy_l   <= 0;
    end else if( cen2 ) begin
        hs_l <= hs;
        busy_l <= dr_busy;
        dr_start <= 0;
        if( hs && !hs_l && vdump>9'h10D && vdump<9'h1f1) begin
            done     <= 0;
            scan_obj <= 0;
            scan_sub <= 0;
            vlatch   <= (vdump^{1'b1,{8{flip}}});
        end else if( !done ) begin
            scan_sub <= scan_sub + 1'd1;
            case( scan_sub )
                1: y <= scan_dout[8:0]-obj_dy[8:0]+9'h1f-9'h20;
                2: hpos <= (scan_dout[8:0]-obj_dx[8:0])+ 9'h69;
                3: begin
                    skip <= ~scan_dout[15];
                    if( scan_dout[14] ) begin
                        done <= 1;
                    end
                    { vflip, hflip, vsize, hsize, attr } <= scan_dout[9:0];
                end
                4: begin
                    code[CW-1:4] <= scan_dout[0+:CW-4];
                    code[3:0] <= 0;
                    ydf <= ydiff[6:0]^{7{vflip}};
                end
                5: begin
                    // Add the vertical offset to the code
                    case( vsize )
                        0: code[ {3'd0,hsize} +: 4 ] <= ydf[3:0];
                        1: code[ {3'd0,hsize} +: 5 ] <= ydf[4:0];
                        2: code[ {3'd0,hsize} +: 6 ] <= ydf[5:0];
                        3: code[ {3'd0,hsize} +: 7 ] <= ydf[6:0];
                    endcase
                    if( !inzone || skip ) begin
                        scan_sub <= 1;
                        scan_obj <= scan_obj + 1'd1;
                        if( &scan_obj ) done <= 1;
                    end
                end
                6: begin
                    scan_sub <= 6;
                    if( !busy_g || !inzone ) begin
                        dr_start <= inzone;
                        scan_sub <= 1;
                        scan_obj <= scan_obj + 1'd1;
                        if( &scan_obj ) done <= 1;
                    end
                end
            endcase
        end
    end
end

endmodule
