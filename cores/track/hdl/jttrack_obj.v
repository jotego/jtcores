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
    Date: 19-3-2022 */

// The row scroll is stored in 2-byte words in the
// upper part of the sprite tables
// From the second byte, only the LSB is used
// The two LSBs of the 1st byte are not used
// The lower byte is latched into device B7
// and the upper byte directly feed the 085 scroll adder (device C5)
// Note that the signal called 256V is actually unrelated to
// the vertical counter

module jttrack_obj(
    input               rst,
    input               clk,        // 48 MHz
    input               clk24,      // 24 MHz

    input               pxl_cen,

    // CPU interface
    input        [10:0] cpu_addr,
    input         [7:0] cpu_dout,
    input               obj_cs,
    input               cpu_rnw,
    output        [7:0] obj_dout,

    // video inputs
    input               hinit,
    input               LHBL,
    input               LVBL,
    input         [8:0] vdump,
    input         [8:0] hdump,
    input               flip,

    // Row scroll
    output reg    [8:0] hpos,

    // PROMs
    input         [3:0] prog_data,
    input         [7:0] prog_addr,
    input               prog_en,

    // SDRAM
    output       [13:0] rom_addr,
    input        [31:0] rom_data,
    output              rom_cs,
    input               rom_ok,

    output        [3:0] pxl
);

parameter [7:0] HOFFSET = 8'd5;
localparam [5:0] MAXOBJ = 6'd23;

wire [ 7:0] obj1_dout, obj2_dout,
            rd1_dout, rd2_dout;
wire        obj1_we, obj2_we;
reg  [ 6:0] scan_addr;
reg  [ 9:0] eff_scan;
wire [ 3:0] pal_data;

assign obj_dout = cpu_addr[10] ? obj2_dout : obj1_dout;
assign obj1_we  = obj_cs & ~cpu_addr[10] & ~cpu_rnw;
assign obj2_we  = obj_cs &  cpu_addr[10] & ~cpu_rnw;

// four 4-bit RAM chips connected as one 16-bit RAM
// in the original
jtframe_dual_ram #(.simfile("obj_lo.bin")) u_lo(
    // Port 0, CPU
    .clk0   ( clk24         ),
    .data0  ( cpu_dout      ),
    .addr0  ( cpu_addr[9:0] ),
    .we0    ( obj1_we       ),
    .q0     ( obj1_dout     ),
    // Port 1
    .clk1   ( clk           ),
    .data1  (               ),
    .addr1  ( eff_scan      ),
    .we1    ( 1'b0          ),
    .q1     ( rd1_dout      )
);

jtframe_dual_ram #(.simfile("obj_hi.bin")) u_hi(
    // Port 0, CPU
    .clk0   ( clk24         ),
    .data0  ( cpu_dout      ),
    .addr0  ( cpu_addr[9:0] ),
    .we0    ( obj2_we       ),
    .q0     ( obj2_dout     ),
    // Port 1
    .clk1   ( clk           ),
    .data1  (               ),
    .addr1  ( eff_scan      ),
    .we1    ( 1'b0          ),
    .q1     ( rd2_dout      )
);

reg        cen2=0;
wire       done;
reg        inzone;
reg        hinit_x;
reg  [2:0] scan_st;

reg  [7:0] dr_attr, dr_xpos;
reg  [7:0] dr_code;
reg  [3:0] dr_v;
reg        dr_start;
wire [7:0] ydiff;
reg  [7:0] dr_y, ypos;
wire [7:0] vdf;
wire       adj;

reg        hflip, vflip;
wire       dr_busy;
wire [3:0] pal;

assign vdf    = vdump[7:0] ^ {8{flip}};
assign ydiff  = vdf-dr_y-8'd1;
assign done   = scan_addr[5:1]==5'h1f;
assign pal    = dr_attr[3:0];
assign adj    = 0;

always @* begin
    eff_scan = { 3'd0, scan_addr};
    hflip = dr_attr[6];
    vflip = dr_attr[7];
    dr_y   = ~ypos + ( adj ? ( flip ? 8'hff : 8'h1 ) : 8'h0 );
end

always @(posedge clk) begin
    cen2 <= ~cen2;
    if( hinit ) hinit_x <= 1;
    else if(cen2) hinit_x <= 0;
end

// Table scan
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scan_st  <= 0;
        dr_start <= 0;
    end else if( cen2 ) begin
        dr_start <= 0;
        case( scan_st )
            0: if( hinit_x ) begin
                scan_addr <= { 2'b10, vdf[7:3] };
                scan_st   <= 6;
            end
            1: if(!dr_busy) begin
                dr_attr      <= rd1_dout;
                dr_xpos      <= rd2_dout;
                scan_st      <= 2;
                scan_addr[0] <= 1;
            end
            2: begin
                ypos    <= rd1_dout;
                dr_code <= rd2_dout;
                scan_st <= 3;
            end
            3: begin
                dr_v    <= ydiff[3:0];
                inzone  <= dr_y>=vdf && dr_y<(vdf+8'h10);
                scan_st <= 4;
            end
            4: begin
                scan_st   <= 5;
                dr_start  <= inzone;
                scan_addr <= { scan_addr[6:1]-6'd1,1'b0};
            end
            5: begin // give time to dr_busy to rise
                dr_start <= 0;
                scan_st  <= done ? 0 : 1;
            end
            // --------------------------
            // Reads the row scroll value
            6: begin
                hpos      <= { rd2_dout[0], rd1_dout };
                scan_addr <= 7'd31<<1;
                scan_st   <= 1;
            end
        endcase
    end
end

jtkicker_objdraw #(
    .BYPASS_PROM    ( 0        ),
    .HOFFSET        ( HOFFSET  )
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
    .draw       ( dr_start  ),
    .busy       ( dr_busy   ),

    // Object table data
    .code       ( { 1'b0, dr_code } ),
    .xpos       ( dr_xpos   ),
    .pal        ( pal       ),
    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .ysub       ( dr_v      ),

    // PROMs
    .prog_data  ( prog_data ),
    .prog_addr  ( prog_addr ),
    .prog_en    ( prog_en   ),

    // SDRAM
    .rom_cs     ( rom_cs    ),
    .rom_addr   ( rom_addr  ),
    .rom_data   ( rom_data  ),
    .rom_ok     ( rom_ok    ),

    .pxl        ( pxl       )
);

endmodule