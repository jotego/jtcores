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
    Date: 10-3-2021 */

module jts16_char(
    input              rst,
    input              clk,
    input              pxl2_cen,  // pixel clock enable (2x)
    input              pxl_cen,   // pixel clock enable
    input              alt_en,

    // CPU interface
    input              char_cs,
    input      [11:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  dswn,
    output     [15:0]  cpu_din,

    // SDRAM interface
    input              char_ok,
    output     [13:2]  char_addr, // 9 addr + 3 vertical + 2 (x32 bits) = 14 bits
    input      [31:0]  char_data,

    // In-RAM data
    output             scr_start,
    output reg [ 9:0]  rowscr1,
    output reg [ 9:0]  rowscr2,
    output reg         altscr1,
    output reg         altscr2,

    input      [ 8:0]  scr1_hscan,
    input      [ 8:0]  scr2_hscan,
    output reg [ 8:0]  colscr1,
    output reg [ 8:0]  colscr2,

    output reg         col_busy1,
    output reg         col_busy2,

    // Video signal
    input              flip,
    input      [ 8:0]  vrender,
    input      [ 8:0]  vdump,
    input      [ 8:0]  hdump,
    output     [ 6:0]  pxl,       // 1 priority + 3 palette + 3 colour = 7
    input      [ 7:0]  debug_bus
);

parameter MODEL=0;  // 0 = S16A, 1 = S16B

wire [15:0] scan;
reg  [10:0] scan_addr;
wire [ 1:0] we;
reg  [ 8:0] code, vf, vfr, hf;

assign we = ~dswn & {2{char_cs}};

jtframe_dual_ram16 #(
    .AW(11),
    .SIMFILE_LO("char_lo.bin"),
    .SIMFILE_HI("char_hi.bin")
) u_ram(
    .clk0   ( clk       ),
    .clk1   ( clk       ),

    // CPU writes
    .addr0  ( cpu_addr  ),
    .data0  ( cpu_dout  ),
    .we0    ( we        ),
    .q0     ( cpu_din   ),

    // Video reads
    .addr1  ( scan_addr ),
    .data1  (           ),
    .we1    ( 2'b0      ),
    .q1     ( scan      )
);

localparam [4:0] ROWREAD=8;
localparam [8:0] FLIPOFFSET = 9'ha3;

assign char_addr = { code, vf[2:0] };
assign scr_start = hdump[8:4]==ROWREAD+1;

// Flip
always @(posedge clk) begin
    vf  <= flip ? 9'd223-vdump : vdump;
    vfr <= flip ? 9'd223-vrender : vrender; // row scroll must be read sync'ed with scroll layers
    hf  <= flip ? FLIPOFFSET-hdump : hdump;
end

// Row scroll
reg [8:0] hscan_mux;
reg       row_rd, row_rdl,
          col_rd, col_rdl,
          hdump0l;

always @(*) begin
    scan_addr = { vf[7:3], hf[8:3]+6'd2 };
    hscan_mux = hdump[0] ? scr2_hscan : scr1_hscan;
    hscan_mux = hscan_mux + 1'd1;
    row_rd = hdump[8:4] == ROWREAD && hdump[2:0]>=6;
    col_rd = hdump[2:0] < 6;
    // Reads row scroll during blanking
    if ( row_rd ) begin
        scan_addr = MODEL ? { 5'h1f, hdump[3], vfr[7:3] } :
                            { 5'h1f, vfr[7:3], hdump[3] };
    end
    // Reads column scroll while hdump < 6
    if( col_rd ) begin
        scan_addr = MODEL ? { 5'h1e, hdump[0], hscan_mux[8:4] } :
                            { 5'h1e, hscan_mux[8:4], hdump[0] };
    end
end


always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rowscr1 <= 0;
        rowscr2 <= 0;
        colscr1 <= 0;
        colscr2 <= 0;
        col_busy1 <= 0;
        col_busy2 <= 0;
    end else begin
        col_busy1 <= col_rdl && !hdump0l;
        col_busy2 <= col_rdl &&  hdump0l;
        row_rdl <= row_rd;
        col_rdl <= col_rd;
        hdump0l <= hdump[0];
        if ( row_rdl && row_rd ) begin
            if( !hdump[3] ) begin
                rowscr1 <= scan[9:0];
                altscr1 <= MODEL[0] & scan[15];
            end else begin
                rowscr2 <= scan[9:0];
                altscr2 <= MODEL[0] & scan[15];
            end
        end
        if( col_rdl && col_rd ) begin
            if( !hdump0l ) colscr1 <= scan[8:0];
            if(  hdump0l ) colscr2 <= scan[8:0];
        end
    end
end

// SDRAM runs at pxl_cen x 8, so new data from SDRAM takes about a
// pxl_cen time to arrive. Data has information for four pixels

reg [23:0] pxl_data;
reg [ 3:0] attr, attr0;

assign pxl = { attr,
    flip ? { pxl_data[16], pxl_data[ 8], pxl_data[0] } :
           { pxl_data[23], pxl_data[15], pxl_data[7] } };

function [7:0] shift;
    input [7:0] din;
    input flip;
    shift = flip ? din>>1 : din << 1;
endfunction

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        code     <= 9'd0;
        attr     <= 4'd0;
        attr0    <= 4'd0;
        pxl_data <= 24'd0;
    end else begin
        if( pxl_cen ) begin
            if( hdump[2:0]==7 ) begin
                code     <= MODEL && !alt_en ? scan[8:0] : {1'b0,scan[7:0]};
                pxl_data <= char_data[23:0];
                attr0    <= MODEL ?
                    ( alt_en ?
                        {scan[15],scan[10:8]}
                      : {scan[15],scan[11:9]}   // Most of S16B games
                    ) : scan[11:8];             // S16A
                attr     <= attr0;
            end else begin
                pxl_data[23:16] <= shift( pxl_data[23:16], flip );
                pxl_data[15: 8] <= shift( pxl_data[15: 8], flip );
                pxl_data[ 7: 0] <= shift( pxl_data[ 7: 0], flip );
            end
        end
    end
end

endmodule