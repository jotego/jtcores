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
    Date: 19-2-2019 */

// 1943 Scroll Generation
// Schematics pages 8/15...

module jtsf_scroll #( parameter
    LAYOUT          = 9,   // 9=SF
    ROM_AW          = 17,
    PXLW            = 8,
    HOFFSET         = 0,
    // MAP SIZE
    MAPDW           = 32  // data width
)(
    input                rst,
    input                clk,
    input                pxl2_cen,
    input         [ 7:0] V, // V-V1
    input         [ 8:0] H, // H256-H1

    input         [15:0] hpos,
    input                SCxON,
    input                flip,
    // Map ROM
    output reg      [16:2] map_addr,
    input      [MAPDW-1:0] map_data,
    input                  map_ok,
    // Gfx ROM
    output  [ROM_AW-1:0] scr_addr,
    input         [15:0] scr_data,
    input                scr_ok,
    output    [PXLW-1:0] scr_pxl
);

localparam [2:0] MAPRD = 3'd0;

wire [8:0] hscan;
wire [7:0] vscan, new_pxl;
// reg  [1:0] sdram_ok;
wire       data_ok, tile_cen;

reg  [3:0] HS;
reg  [7:0] SV, PIC;
reg  [8:0] SH;

reg [4:0] SVmap; // SV latched at the time the map_addr is set
reg [7:0] HF;
reg [9:0] SCHF;
reg       H7;

assign    data_ok  = !((!map_ok&&HS[2:0]==MAPRD) || (!scr_ok&&HS[1:0]==2'd1));

always @(*) begin // Street Fighter
    { PIC, SH } = {7'd0, hscan^{9{flip}}} + hpos;
end

// Street Fighter 16x16
always @(posedge clk) begin
    SV <= {8{flip}}^vscan[7:0];
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        map_addr <= 0;
        HS[3:0]  <= 4'd0;
        SVmap    <= 5'd0;
    end else begin
        HS[2:0] <= SH[2:0] ^ {3{flip}};
        // always update the map at the same pixel count
        if( SH[2:0]==3'd6 ) begin
            HS[3] <= SH[3] /*^flip*/;
            // Map address shifted left because of 32-bit read
            map_addr <= { PIC[5:0], SH[8:4], SV[7:4] }; // 6+5+4+1=16
            SVmap    <= SV[4:0];
        end
    end
end


reg [MAPDW/2-1:0] dout_high, dout_low;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        { dout_high, dout_low } <= {MAPDW{1'b0}};
    end else begin
        if( map_ok && SH[2:0]==MAPRD ) begin
            dout_high <= map_data[MAPDW/2-1:0];
            dout_low  <= map_data[MAPDW-1:MAPDW/2];
        end
    end
end

jtgng_tile4 #(
    .PALETTE        ( 0             ),
    .ROM_AW         ( ROM_AW        ),
    .LAYOUT         ( LAYOUT        ))
u_tile4(
    .clk        (  clk          ),
    .cen6       (  tile_cen     ),
    .HS         (  {1'd0,HS}    ),
    .SV         (  SVmap        ),
    .attr       (  dout_high    ),
    .id         (  dout_low     ),
    .SCxON      ( SCxON         ),
    .flip       ( flip          ),
    // Palette PROMs
    .prog_addr  (               ),
    .prom_hi_we (               ),
    .prom_lo_we (               ),
    .prom_din   (               ),
    // Gfx ROM
    .scr_addr   ( scr_addr      ),
    .rom_data   ( scr_data      ),
    .scr_pxl    ( new_pxl       )
);

jtframe_tilebuf #(
    .HW     ( 9       ),
    .HOFFSET( HOFFSET ),
    .HOVER  ( 9'h1E7  ) // [2:0] must be 7 or the counter gets locked by sdram_ok
) u_buffer(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .scan_cen   ( tile_cen  ),
    .hdump      ( H         ),
    .vdump      ( V         ),
    .hscan      ( hscan     ),
    .vscan      ( vscan     ),
    .rom_ok     ( data_ok   ),
    .pxl_data   ( new_pxl   ),
    .pxl_dump   ( scr_pxl   )
);

endmodule