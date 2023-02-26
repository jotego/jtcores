/*  This file is part of JTS16.
    JTS16 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTS16 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTS16.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 11-3-2021 */

module jts16_scr(
    input              rst,
    input              clk,
    input              pxl2_cen,  // pixel clock enable (2x)
    input              pxl_cen,   // pixel clock enable

    input              LHBL,
    input              alt_en,

    // MMR
    input      [15:0]  pages,
    input      [15:0]  hscr,
    input      [15:0]  vscr,
    input      [ 9:0]  rowscr,
    input              rowscr_en,

    // Column scroll
    output reg [ 8:0]  hcolscr,
    input      [ 8:0]  colscr,
    input              colscr_en,
    input              col_busy,

    // SDRAM interface
    input              map_ok,
    output reg [15:1]  map_addr, // 3(+1 S16B) pages + 11 addr = 14 (32 kB)
    input      [15:0]  map_data,

    input              scr_ok,
    output reg [17:2]  scr_addr, // 1 bank + 12 addr + 3 vertical + 1'b0 = 17 bits => 512kB
    input      [31:0]  scr_data,

    // Video signal
    input              flip,
    input      [ 8:0]  vrender,
    input      [ 8:0]  hdump,
    output     [10:0]  pxl,       // 1 priority + 7 palette + 3 colour = 11
    input      [ 7:0]  debug_bus,
    output reg         bad
);

/* verilator lint_off WIDTH */
parameter [9:0] PXL_DLY=0;
parameter [8:0] HB_END=9'h70, HSCAN0 = 9'h70; //HB_END-9'd24-PXL_DLY[8:0];
/* verilator lint_on WIDTH */
parameter       MODEL=0;  // 0 = S16A, 1 = S16B

reg  [10:0] scan_addr;
reg  [ 8:0] hscan;
wire [ 1:0] we;
wire [ 8:0] vrf;

reg  [8:0]  vscan;

// Map reader
reg  [8:0] hpos;
reg  [7:0] vpos;
reg  [3:0] page;
reg        hov, vov; // overflow bits

reg        done, draw;
reg  [7:0] busy;
reg        hsel;

reg  [9:0] eff_hscr;
reg  [8:0] eff_vscr;
reg  [8:0] hdly;

assign vrf      = flip ? 9'd223-vrender : vrender;

always @(*) begin
    eff_hscr = rowscr_en ? rowscr : hscr[9:0];
    eff_vscr = colscr_en ? colscr : vscr[8:0];
    if( rowscr_en || colscr_en ) eff_hscr = eff_hscr + 9'd8; // this is needed by Cotton
    if( MODEL==0 ) begin
        {hov, hpos } = {1'b0, hscan} - {1'b0, eff_hscr[8:0]} + PXL_DLY;// + { {2{debug_bus[7]}}, debug_bus};
        {vov, vpos } = vscan + {1'b0, eff_vscr[7:0]};
    end else begin
        {hov, hpos } = {1'b1, hscan} - eff_hscr[9:0] + PXL_DLY[9:0];
        {vov, vpos } = vscan + eff_vscr[8:0];
    end
    scan_addr = { vpos[7:3], hpos[8:3] };
    case( { vov, hov } )
        2'b10: page = pages[15:12]; // upper left
        2'b11: page = pages[11: 8]; // upper right
        2'b00: page = pages[ 7: 4]; // lower left
        2'b01: page = pages[ 3: 0]; // lower right
    endcase
    if( MODEL==0 ) page[3]=0; // Only 3-bit pages for System 16A
    hdly = flip ? 9'hb0 -hdump : hdump;
    //if( debug_bus!=0 ) page=debug_bus[3:0];
end

reg [1:0] map_st;
reg       last_LHBL, col_busyl;

always @(posedge clk) begin
    col_busyl <= col_busy;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        map_addr <= 0;
        draw     <= 0;
        map_st   <= 0;
    end else if(!done) begin
        map_st <= map_st+1'd1;
        draw   <= 0;
        case( map_st )
            0: hcolscr <= hscan;
            1: begin
                if( colscr_en && ((hscan[2:0]==0 && !col_busyl) || busy!=0 ))
                    map_st <= 1;
                else
                    map_addr <= { page, scan_addr };
            end
            3:
                if( !map_ok || busy!=0 || !scr_ok)
                    map_st <= 3;
                else
                    draw   <= 1;
            default:;
        endcase
    end else begin
        map_st <= 0;
        draw   <= 0;
    end
end

// SDRAM runs at pxl_cen x 8, so new data from SDRAM takes about a
// pxl_cen time to arrive. Data has information for four pixels

reg [23:0] pxl_data;
reg [ 7:0] attr;
reg [ 1:0] scr_good;

wire bank = map_data[13];
wire [10:0] buf_data;

assign buf_data = { attr, pxl_data[23], pxl_data[15], pxl_data[7] };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        attr     <= 0;
        pxl_data <= 0;

        last_LHBL <= 0;
        done      <= 0;
        busy      <= 0;
        hscan     <= 0;
        bad       <= 0;
        scr_addr  <= 0;
        vscan     <= 0;
    end else begin
        last_LHBL <= LHBL;
        scr_good  <= { scr_good[0] & scr_ok, scr_ok };
        if( scr_good==2'b01 ) pxl_data <= scr_data[23:0];

        if( !LHBL && last_LHBL ) begin
            vscan <= vrf;
            done  <= 0;
            busy  <= 0;
            bad   <= !done;
        end

        if( done ) begin
            hscan <= HSCAN0;
            bad   <= 0;
        end

        if( draw && !done ) begin
            attr     <= MODEL ? (
                        alt_en ?
                            { map_data[15], map_data[11:5] } // Just for three games
                          : { map_data[15], map_data[12:6] } // most S16B titles
                        ) : map_data[12:5]; // S16A
            busy     <= ~8'd0;
            scr_addr <= { MODEL ? map_data[12:0] : { bank, map_data[11:0] }, // code
                        vpos[2:0] };
            scr_good <= 2'd0;
        end else if( busy!=0 && &scr_good && pxl2_cen) begin // This could work
            // without pxl2_cen, but it stresses the SDRAM too much, causing
            // glitches in the char layer.
            pxl_data[23:16] <= pxl_data[23:16]<<1;
            pxl_data[15: 8] <= pxl_data[15: 8]<<1;
            pxl_data[ 7: 0] <= pxl_data[ 7: 0]<<1;
            if( hpos[2:0]==3'd7 )
                busy <= 8'h80;
            else
                busy <= busy<<1;
            hscan <= hscan + 1'd1;
            if( &hscan ) done <= 1;
        end
    end
end

jtframe_linebuf #(.DW(11),.AW(9)) u_linebuf(
    .clk    ( clk      ),
    .LHBL   ( LHBL     ),
    // New data writes
    .wr_addr( hscan    ),
    .wr_data( buf_data ),
    .we     ( busy[7]  ),
    // Old data reads (and erases)
    .rd_addr( hdly     ),
    .rd_data( pxl      ),
    .rd_gated(         )
);

endmodule