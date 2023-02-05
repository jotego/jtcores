/*  This file is part of JTKICKER.
    JTKICKER program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTKICKER program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTKICKER.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 30-12-2021 */

module jtsbaskt_obj(
    input               rst,
    input               clk,        // 48 MHz
    input               clk24,      // 24 MHz

    input               pxl_cen,

    // CPU interface
    input         [9:0] cpu_addr,
    input         [7:0] cpu_dout,
    input               obj_cs,
    input               cpu_rnw,
    output        [7:0] obj_dout,
    input               obj_frame,

    // video inputs
    input               hinit,
    input               LHBL,
    input               LVBL,
    input         [7:0] vrender,
    input         [8:0] hdump,
    input               flip,

    // PROMs
    input         [3:0] prog_data,
    input         [7:0] prog_addr,
    input               prog_en,

    // SDRAM
    output       [13:0] rom_addr,
    input        [31:0] rom_data,
    output              rom_cs,
    input               rom_ok,

    output        [3:0] pxl,
    input         [7:0] debug_bus
);

parameter [7:0] HOFFSET = 8'd6;

reg fr; // write frame

wire        obj_we;
wire [ 9:0] scan_addr;
wire [ 7:0] scan_dout, tbl_dout;
wire        fr_we;
reg         cen2, hinit_x;

assign obj_we    = obj_cs & ~cpu_rnw;
assign scan_addr = { 1'b0, obj_frame, hdump[7:0] };
assign fr_we     = vrender == 8'h40 && pxl_cen && LHBL;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        fr <= 0;
        cen2 <= 0;
    end else begin
        if( vrender==8 && hinit && pxl_cen ) fr <= ~fr;
        cen2 <= ~cen2;
        if( hinit ) hinit_x <= 1;
        else if(cen2) hinit_x <= 0;
    end
end

// even address
jtframe_dual_ram #(.aw(10),.simfile("obj.bin")) u_hi(
    // Port 0, CPU
    .clk0   ( clk24         ),
    .data0  ( cpu_dout      ),
    .addr0  ( cpu_addr      ),
    .we0    ( obj_we        ),
    .q0     ( obj_dout      ),
    // Port 1
    .clk1   ( clk           ),
    .data1  (               ),
    .addr1  ( scan_addr     ),
    .we1    ( 1'b0          ),
    .q1     ( scan_dout     )
);

// frame buffer for 64 sprites (256 bytes)
wire [8:0] rd_addr;

jtframe_dual_ram #(.aw(9)) u_low(
    // Port 0, write
    .clk0   ( clk           ),
    .data0  ( scan_dout     ),
    .addr0  ({ fr,hdump[7:0]^8'h3}), // reorder: y,x,attr,code
    .we0    ( fr_we         ),
    .q0     (               ),
    // Port 1
    .clk1   ( clk           ),
    .data1  (               ),
    .addr1  ( rd_addr       ),
    .we1    ( 1'b0          ),
    .q1     ( tbl_dout      )
);

// scan the current frame
reg  [5:0] obj_cnt;
reg  [1:0] sub;
reg  [7:0] xpos;
reg  [8:0] code;
reg  [3:0] ysub;
wire [7:0] ydiff;
reg  [1:0] rd_st;
reg  [3:0] pal;
reg        hflip, vflip;

wire       inzone;
wire       busy;
reg        done, draw;

assign rd_addr = { ~fr, obj_cnt, sub };
assign ydiff   = vrender-tbl_dout;
assign inzone  = ydiff < 8'h10;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        done    <= 0;
        obj_cnt <= 0;
        sub     <= 0;
        rd_st   <= 0;
        draw    <= 0;
    end else if( cen2 ) begin
        if( busy ) draw <= 0;
        if( hinit ) begin
            done    <= 0;
            obj_cnt <= 0;
            sub     <= 0;
            rd_st   <= 0;
        end else if( !done ) begin
            rd_st <= rd_st + 2'd1;
            case( rd_st )
                0: begin
                    if( inzone ) begin
                        sub  <= 1;
                        ysub <= ydiff[3:0];
                    end else begin
                        obj_cnt <= obj_cnt + 6'd1;
                        if( &obj_cnt ) done <= 1;
                        rd_st <= 0;
                    end
                end
                1: begin
                    xpos <= tbl_dout;
                    sub  <= 2;
                end
                2: begin
                    sub     <= 3;
                    pal     <= tbl_dout[3:0];
                    code[8] <= tbl_dout[5];
                    vflip   <= tbl_dout[7];
                    hflip   <= tbl_dout[6];
                end
                3: if( !busy ) begin
                    code[7:0] <= tbl_dout;
                    sub       <= 0;
                    obj_cnt   <= obj_cnt + 6'd1;
                    draw      <= 1;
                    if( &obj_cnt ) done <= 1;
                end else begin
                    rd_st <= 3;
                end
            endcase
        end
    end
end

jtkicker_objdraw #(
    .BYPASS_PROM( 0         ),
    .PACKED     ( 1         ),
    .HOFFSET    ( HOFFSET   )
) u_draw (
    .rst        ( rst       ),
    .clk        ( clk       ),        // 48 MHz

    .pxl_cen    ( pxl_cen   ),
    .cen2       ( cen2      ),
    // video inputs
    .LHBL       ( LHBL      ),
    .hinit_x    ( hinit_x   ),
    .hdump      ( hdump     ),

    // control
    .draw       ( draw      ),
    .busy       ( busy      ),

    // Object table data
    .code       ( code      ),
    .xpos       ( xpos      ),
    .pal        ( pal       ),
    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .ysub       ( ysub      ),

    // PROMs
    .prog_data  ( prog_data ),
    .prog_addr  ( prog_addr ),
    .prog_en    ( prog_en   ),

    // SDRAM
    .rom_cs     ( rom_cs    ),
    .rom_addr   ( rom_addr  ),
    .rom_data   ( rom_data  ),
    .rom_ok     ( rom_ok    ),

    .pxl        ( pxl       ),
    .debug_bus  (           )
);

endmodule