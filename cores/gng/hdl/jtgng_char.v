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
    Date: 27-10-2017 */

// Generic 2-bit per pixel no-scroll tile generator
/* verilator lint_off WIDTH */

module jtgng_char #(parameter
    ROM_AW   = 13,
    PALW     = 4,
    LAYOUT   = 0, // 3: Tiger Road, 8: Side Arms, 9: Street Fighter,
                  // 10: The Speed Rumbler
                  // 11: Exed Exes
    PALETTE  = 0, // 1 if the palette PROM is used
    DW       = LAYOUT==9 ? 16 : 8,
    ABW      = (LAYOUT==8 || LAYOUT==9 || LAYOUT==10 ) ? 12 : 11,
    HW       = (LAYOUT==8 || LAYOUT==9 || LAYOUT==10 ) ?  9 : 8,
    PXLW     = (PALETTE?4:PALW+2),
    HOFFSET  = 8'd0,
    // bit field information
    IDMSB1   = 7,   // MSB of tile ID is
    IDMSB0   = 6,   //   { dout_high[IDMSB1:IDMSB0], dout_low }
    VFLIP    = 5,
    HFLIP    = 4,
    VFLIP_EN = 1, // 1 for enable VFLIP bit
    HFLIP_EN = 1, // 1 for enable HFLIP bit
    HFLIP_XOR= 1'b0, // Additional bit for ^ with HFLIP value
    VFLIP_XOR= 1'b0, // Additional bit for ^ with VFLIP value
    PALETTE_SIMFILE = "../../../rom/1943/bm5.7f", // only for simulation
    SIMID    = 0    // char_lo/hi.bin for simulation files
) (
    input            clk,
    input            pxl_cen  /* synthesis direct_enable = 1 */,
    input  [ABW-1:0] AB,
    input     [ 7:0] V, // V128-V1
    input   [HW-1:0] H, // Hfix-H1
    input            flip,
    input   [DW-1:0] din,
    output  [DW-1:0] dout,
    // Bus arbitrion
    input            char_cs,
    input            wr_n,
    input     [ 1:0] dseln, // Select upper or lower byte for 16-bit access
    output           busy,
    // PROM access
    input     [ 7:0] prog_addr,
    input     [ 3:0] prog_din,
    input            prom_we,
    // ROM
    output reg [ROM_AW-1:0] char_addr,
    input      [15:0]       rom_data,
    input                   rom_ok,
    // Output pixel
    input                   char_on,    // low makes the output FF
    output reg [PXLW-1:0]   char_pxl
);

localparam CHARW    = PALETTE?4:PALW+2;
localparam DATAREAD = 3'd1;

reg  [PALW-1:0] char_pal;
reg  [     1:0] char_col;

wire [   7:0] dout_low, dout_high;
wire [HW-1:0] Hfix;

assign Hfix = H + HOFFSET[HW-1:0]; // Corrects pixel output offset
assign busy = H[2:1]!=3 && char_cs;

jtgng_tilemap #(
    .DW      ( DW       ),
    .DATAREAD( DATAREAD ),
    .SIMID   ( 0        ),
    .LAYOUT  ( LAYOUT   ),
    .SCANW   ( ABW-1    )
) u_tilemap(
    .clk        ( clk         ),
    .pxl_cen    ( pxl_cen     ),
    .Asel       ( AB[ABW-1]   ), // Selects upper or lower byte for  8-bit access
    .dseln      ( dseln       ), // Selects upper or lower byte for 16-bit access
    .AB         ( AB[ABW-2:0] ),
    .V          ( V           ),
    .H          ( Hfix        ),
    .flip       ( flip        ),
    .din        ( din         ),
    .dout       ( dout        ),
    .layout     ( 1'b0        ),
    // Bus arbitrion
    .cs         ( char_cs     ),
    .wr_n       ( wr_n        ),
    // Current tile
    .dout_low   ( dout_low    ),
    .dout_high  ( dout_high   )
);

reg [7:0] addr_lsb;
reg char_hflip;
reg half_addr;

// Draw pixel on screen
reg [15:0] chd;
reg [PALW:0] char_attr0, char_attr1; // MSB is HFLIP
reg [PALW-1:0] char_attr2;

reg [15:0] good_data;

`ifdef SIMULATION
initial $display("INFO: LAYOUT %2d for %m", LAYOUT);
`endif

// avoid getting the data too early
always @(posedge clk) begin
    if( Hfix[2:0]>(DATAREAD+3'd1) && rom_ok ) good_data <= rom_data;
end

// avoid errors if *FLIP_EN is assigned 0 or 1 (i.e. 32'd0, 32'd1)
wire vflip_en = VFLIP_EN[0];
wire hflip_en = HFLIP_EN[0];

wire hflip_next = char_attr1[PALW];
reg  dout_hflip, dout_vflip;

always @(*) begin
    dout_hflip = (dout_high[HFLIP] & hflip_en) ^ HFLIP_XOR;
    dout_vflip = (dout_high[VFLIP] & vflip_en) ^ VFLIP_XOR;

    dout_hflip = dout_hflip ^ flip;
    dout_vflip = dout_vflip ^ flip;
end

always @(posedge clk) if(pxl_cen) begin
    // new tile starts 8+5=13 pixels off
    // 8 pixels from delay in ROM reading
    // 4 pixels from processing the x,y,z and attr info.
    if( Hfix[2:0]==DATAREAD ) begin // read data from memory when the CPU does not have write access
        // Set input for ROM reading
        char_attr1 <= char_attr0;
        case( LAYOUT )
            default:  begin
                char_addr  <= { {dout_high[IDMSB1:IDMSB0], dout_low},
                {3{dout_vflip}}^V[2:0] };
                char_attr0 <= { dout_hflip, dout_high[PALW-1:0] };
            end
            3:  begin // Tiger Road
                char_addr  <= { { dout_high[5], dout_high[7:6], dout_low},
                {3{dout_vflip}}^V[2:0] };
                char_attr0 <= { dout_hflip, dout_high[PALW-1:0] };
            end
            9:  begin // Street Fighter
                char_addr  <= { { dout_high[1:0], dout_low},
                {3{dout_vflip}}^V[2:0] };
                char_attr0 <= { dout_hflip, dout_high[7:4] };
            end
            10:  begin // The Speed Rumbler
                char_addr  <= { { dout_high[1:0], dout_low}, V[2:0] ^ {3{dout_vflip}} };
                char_attr0 <= { dout_hflip, dout_high[6:2] };
            end
            11:  begin // Exed Exes
                char_addr  <= { { dout_high[7], dout_low}, V[2:0] ^ {3{dout_vflip}} };
                char_attr0 <= { flip, dout_high[5:0] };
            end
        endcase
    end
    // The two case-statements cannot be joined because of the default statement
    // which needs to apply in all cases except the two outlined before it.
    case( Hfix[2:0] )
        (DATAREAD+3'd1): begin
            chd <= !hflip_next ? {good_data[7:0],good_data[15:8]} : good_data;
            char_hflip <= hflip_next;
            char_attr2 <= char_attr1[PALW-1:0];
        end
        (DATAREAD+3'd5):
            chd[7:0] <= chd[15:8];
        default:
            begin
                if( char_hflip ) begin
                    chd[7:4] <= {1'b0, chd[7:5]};
                    chd[3:0] <= {1'b0, chd[3:1]};
                end
                else  begin
                    chd[7:4] <= {chd[6:4], 1'b0};
                    chd[3:0] <= {chd[2:0], 1'b0};
                end
            end
    endcase
    // 1-pixel delay in order to latch signals:
    char_col <= char_hflip ? { chd[0], chd[4] } : { chd[3], chd[7] };
    char_pal <= char_attr2;
end

generate
    if( PALETTE==0 ) begin
        // Add the same delay as if there was a palette PROM
        always @(posedge clk) if(pxl_cen)
            char_pxl <= char_on ? {char_pal, char_col} : {CHARW{1'b1}};
    end else begin
        wire [7:0] colour_addr = { {6-PALW{1'b0}}, char_pal, char_col };
        wire [3:0] prom_data;
        jtframe_prom #(.AW(8),.DW(4),.SIMFILE(PALETTE_SIMFILE)) u_vprom(
            .clk    ( clk            ),
            .cen    ( pxl_cen        ),
            .data   ( prog_din       ),
            .rd_addr( colour_addr    ),
            .wr_addr( prog_addr      ),
            .we     ( prom_we        ),
            .q      ( prom_data      )
        );
        always @(*) char_pxl = char_on ? prom_data : {PXLW{1'b1}};
    end
endgenerate

endmodule // jtgng_char
/* verilator lint_on WIDTH */
