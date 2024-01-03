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

    Author: Jose Tejada Gomez. https://patreon.com/jotego
    Version: 1.0
    Date: 23-3-2022 */

module jtngp_scr #( parameter
    SIMFILE_LO = "scr1_lo.bin",
    SIMFILE_HI = "scr1_hi.bin"
)(
    input             rst,
    input             clk,
    input             pxl_cen,

    input      [ 8:0] hdump,
    input      [ 7:0] vdump,
    input      [ 7:0] hpos,
    input      [ 7:0] vpos,
    // CPU access
    input      [10:1] cpu_addr,
    output     [15:0] cpu_din,
    input      [15:0] cpu_dout,
    input      [ 1:0] dsn,
    input             scr_cs,
    // Character RAM
    output reg [12:1] chram_addr,
    input      [15:0] chram_data,
    // video output
    input             en,
    output     [ 2:0] pxl
);

wire [ 1:0] we;
reg  [ 9:0] scan_addr;
wire [15:0] scan_dout;
reg  [15:0] pxl_data;
reg  [ 8:0] heff;
reg  [ 7:0] veff;
reg         hflip, pal, hflip0, pal0;

assign we = ~dsn & {2{scr_cs}};

always @* begin
    heff = hdump + hpos;
    veff = vdump + vpos;
    scan_addr = { veff[7:3], heff[7:3] };
end
`ifdef SIMULATION
reg [15:0] chk_d=0;
reg [ 9:0] chk_a=0;
always @(posedge clk) if(we!=0) { chk_a, chk_d } <= { cpu_addr, cpu_dout & {{8{we[1]}},{8{we[0]}}} };
`endif
// 2048 bytes = 32x32 characters
jtframe_dual_ram16 #(
    .AW         (  10         ),
    .SIMFILE_LO ( SIMFILE_LO  ),
    .SIMFILE_HI ( SIMFILE_HI  )
) u_ram(
    // Port 0
    .clk0   ( clk       ),
    .data0  ( cpu_dout  ),
    .addr0  ( cpu_addr  ),
    .we0    ( we        ),
    .q0     ( cpu_din   ),
    // Port 1
    .clk1   ( clk       ),
    .data1  (           ),
    .addr1  ( scan_addr ),
    .we1    ( 2'b0      ),
    .q1     ( scan_dout )
);

assign pxl = en ? { pal, hflip ? pxl_data[1:0] : pxl_data[15:14] } : 3'd0;

// scanner
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        chram_addr <= 0;
        hflip      <= 0;
        pal        <= 0;
        pxl_data   <= 0;
    end else if(pxl_cen) begin
        if( heff[1:0]==0 ) begin
            chram_addr <= { scan_dout[8:0], veff[2:0] ^ {3{scan_dout[14]}} };
            hflip0     <= scan_dout[15];
            pal0       <= scan_dout[13];
            pxl_data   <= chram_data;
            hflip      <= hflip0;
            pal        <= pal0;
            if( !heff[2] )
                pxl_data <= hflip ? {2{chram_data[15:8]}} : {2{chram_data[7:0]}};
        end else begin
            pxl_data   <= hflip ? pxl_data>>2 : pxl_data<<2;
        end
    end
end

endmodule