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
    Date: 13-1-2020 */
    

// Scroll 1 is 512x512, 8x8 tiles
// Scroll 2 is 1024x1024 16x16 tiles
// Scroll 3 is 2048x2048 32x32 tiles

module jtcps1_scroll(
    input              rst,
    input              clk,
    input              pxl_cen,
    input              flip,

    input      [ 8:0]  vrender, // 1 line ahead of vdump
    input      [ 8:0]  vdump,
    input      [ 8:0]  hdump,
    input              preVB,
    input              VB,
    input              HB,
    input              HS,
    // control registers
    input      [15:0]  hpos1,
    input      [15:0]  vpos1,
    input      [15:0]  hpos2,
    input      [15:0]  vpos2,
    input      [15:0]  hpos3,
    input      [15:0]  vpos3,
    input      [15:0]  hstar0,
    input      [15:0]  vstar0,
    input      [15:0]  hstar1,
    input      [15:0]  vstar1,

    input              start,

    output     [ 7:0]  tile_addr,
    input      [15:0]  tile_data,

    // ROM banks
    input      [ 5:0]  game,
    input      [15:0]  bank_offset,
    input      [15:0]  bank_mask,

    output     [19:0]  rom_addr,    // up to 1 MB
    output             rom_half,    // selects which half to read
    input      [31:0]  rom_data,
    output             rom_cs,
    input              rom_ok,

    output     [12:0]  star0_addr,
    input      [31:0]  star0_data,
    input              star0_ok,
    output             star0_cs,

    output     [12:0]  star1_addr,
    input      [31:0]  star1_data,
    input              star1_ok,
    output             star1_cs,

    input      [ 3:0]  gfx_en,

    output reg [10:0]  scr1_pxl,
    output reg [10:0]  scr2_pxl,
    output reg [10:0]  scr3_pxl,

    output     [ 6:0]  star0_pxl,
    output     [ 6:0]  star1_pxl,
    input      [ 7:0]  debug_bus
);

reg         pre_start, sub_start, busy, done;
wire [10:0] buf_data;
wire [ 8:0] buf_addr;
wire        buf_wr;

reg  [15:0] hpos, vpos;
reg  [ 2:0] st;
wire        sub_done;

reg         rd_half, wr_half;

wire [ 9:0] addr0 = { wr_half, buf_addr ^ {9{flip}} }; // write
wire [ 9:0] addr1 = { rd_half, hdump }; // read
wire [10:0] pre1_pxl, pre2_pxl, pre3_pxl;

wire       wr1 = buf_wr & st[0],
           wr2 = buf_wr & st[1],
           wr3 = buf_wr & st[2];

reg [3:0]  clrsh;
wire       wrclr, pxl_latch;

assign     pxl_latch = pxl_cen; //clrsh[2];
assign     wrclr     = 1'b0; //clrsh[3];

always @(posedge clk, posedge rst) begin
    if ( rst ) clrsh <= 4'b1;
    else begin
        if( pxl_cen || !clrsh[0] ) clrsh <= { clrsh[2:0], clrsh[3] };
    end
end

jtframe_dual_ram #(.DW(11), .AW(10)) u_line1(
    .clk0   ( clk       ),
    .clk1   ( clk       ),
    // Port 0: write
    .data0  ( buf_data  ),
    .addr0  ( addr0     ),
    .we0    ( wr1       ),
    .q0     (           ),
    // Port 1: read
    .data1  ( ~11'd0    ),
    .addr1  ( addr1     ),
    .we1    ( wrclr     ),
    .q1     ( pre1_pxl  )
);

jtframe_dual_ram #(.DW(11), .AW(10)) u_line2(
    .clk0   ( clk       ),
    .clk1   ( clk       ),
    // Port 0: write
    .data0  ( buf_data  ),
    .addr0  ( addr0     ),
    .we0    ( wr2       ),
    .q0     (           ),
    // Port 1: read
    .data1  ( ~11'd0    ),
    .addr1  ( addr1     ),
    .we1    ( wrclr     ),
    .q1     ( pre2_pxl  )
);

jtframe_dual_ram #(.DW(11), .AW(10)) u_line3(
    .clk0   ( clk       ),
    .clk1   ( clk       ),
    // Port 0: write
    .data0  ( buf_data  ),
    .addr0  ( addr0     ),
    .we0    ( wr3       ),
    .q0     (           ),
    // Port 1: read
    .data1  ( ~11'd0    ),
    .addr1  ( addr1     ),
    .we1    ( wrclr     ),
    .q1     ( pre3_pxl  )
);

// Line buffers
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scr1_pxl <= 11'h1ff;
        scr2_pxl <= 11'h1ff;
        scr3_pxl <= 11'h1ff;
    end else if(pxl_latch) begin
        if( hdump>9'd63 && hdump<9'd448 ) begin // active area
            `ifndef NOSCROLL1
            scr1_pxl <= pre1_pxl;
            `endif
            `ifndef NOSCROLL2
            scr2_pxl <= pre2_pxl;
            `endif
            `ifndef NOSCROLL3
            scr3_pxl <= pre3_pxl;
            `endif
        end else begin
            scr1_pxl <= 11'h1ff;
            scr2_pxl <= 11'h1ff;
            scr3_pxl <= 11'h1ff;
        end
    end
end

reg req_start, last_HB, last_start;
wire pedg_HB = !HB && last_HB;

// Tilemap sequencer
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        busy      <= 1'b0;
        st        <= 3'b1;
        sub_start <= 1'b0;
        pre_start <= 1'b0;
        req_start <= 1'b0;
        done      <= 1'b0;
        last_HB   <= 1'b0;
        last_start<= 1'b0;
        rd_half   <= 1'b0;
        wr_half   <= 1'b1;
    end else begin
        done       <= 1'b0;
        last_HB    <= HB;
        last_start <= start;
        if( start && !last_start ) begin
            rd_half   <= ~wr_half;
        end
        if( pedg_HB && (!preVB || !VB) ) begin
            req_start <= 1'b1;
        end
        if( req_start  && !busy ) begin
            req_start <= 1'b0;
            busy      <= 1'b1;
            st        <= 3'b1;
            pre_start <= 1'b1;
            hpos      <= hpos1;
            vpos      <= vpos1;
        end else if( busy ) begin
            pre_start <= 1'b0;
            sub_start <= pre_start;
            case( st )
                3'b001: begin
                    if( sub_done ) begin
                        hpos      <= hpos2;
                        vpos      <= vpos2;
                        pre_start <= 1'b1;
                        st        <= 3'b10;
                    end
                end
                3'b010: begin
                    if( sub_done ) begin
                        hpos      <= hpos3;
                        vpos      <= vpos3;
                        pre_start <= 1'b1;
                        st        <= 3'b100;
                    end
                end
                3'b100: begin
                    if( sub_done ) begin
                        done <= 1'b1;
                        busy <= 1'b0;
                        wr_half   <= ~wr_half;
                    end
                end
                default:;
            endcase
        end
    end
end

jtcps1_tilemap u_tilemap(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .flip       ( flip          ),

    .vrender    ( vrender       ),
    .size       ( st            ),
    // control registers
    .game       ( game          ),
    .bank_offset( bank_offset   ),
    .bank_mask  ( bank_mask     ),

    .hpos       ( hpos          ),
    .vpos       ( vpos          ),

    .start      ( sub_start     ),
    .stop       ( pedg_HB       ),
    .done       ( sub_done      ),

    .tile_addr  ( tile_addr     ),
    .tile_data  ( tile_data     ),

    .rom_addr   ( rom_addr      ),    // up to 1 MB
    .rom_half   ( rom_half      ),    // selects which half to read
    .rom_data   ( rom_data      ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        ),

    .buf_addr   ( buf_addr      ),
    .buf_wr     ( buf_wr        ),
    .buf_data   ( buf_data      )
);

jtcps1_stars u_star0(
    .rst            ( rst         ),
    .clk            ( clk         ),
    .pxl_cen        ( pxl_cen     ),
    .HS             ( HS          ),
    .VB             ( VB          ),
    .flip           ( flip        ),
    .vdump          ( vdump       ),
    .hdump          ( hdump       ),
    .hpos           ( hstar0[8:0] ),
    .vpos           ( vstar0[8:0] ),
    .rom_cs         ( star0_cs    ),
    .rom_addr       ( star0_addr  ),
    .rom_ok         ( star0_ok    ),
    .rom_data       ( star0_data  ),
    .pxl            ( star0_pxl   ),
    .debug_bus      ( debug_bus   )
);

jtcps1_stars u_star1(
    .rst            ( rst         ),
    .clk            ( clk         ),
    .pxl_cen        ( pxl_cen     ),
    .HS             ( HS          ),
    .VB             ( VB          ),
    .flip           ( flip        ),
    .vdump          ( vdump       ),
    .hdump          ( hdump       ),
    .hpos           ( hstar1[8:0] ),
    .vpos           ( vstar1[8:0] ),
    .rom_cs         ( star1_cs    ),
    .rom_addr       ( star1_addr  ),
    .rom_ok         ( star1_ok    ),
    .rom_data       ( star1_data  ),
    .pxl            ( star1_pxl   ),
    .debug_bus      ( debug_bus   )
);

endmodule
