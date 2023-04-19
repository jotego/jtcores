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

/* verilator lint_off SELRANGE */
/* verilator lint_off WIDTH */

module jtgng_tile4 #(parameter
    PALETTE     =  1, // 1 for palette PROMs
    ROM_AW      = 17,
    LAYOUT      =  0, // 0:1943, 1: Bionic Commando SCR1, 2: Biocom SCR2
                      // 3: Tiger Road
                      // 4: Black Tiger
                      // 5: Legendary Wings / Section Z (3 palette bits)
                      // 6: Trojan SCR1
                      // 7: Trojan SCR2
                      // 8: Side Arms
                      // 9: Street Fighter
                      //10: The Speed Rumbler
    SIMFILE_MSB = "",
    SIMFILE_LSB = "",
    DW          = LAYOUT==9 ? 16:8,
    AS8MASK     =  1'b1, // only used by layout 0
    PXLW        = (LAYOUT==3 || LAYOUT==8) ? 9 :
               (  (LAYOUT==5 || LAYOUT==7) ? 7 :
                  (PALETTE                 ? 6 : 8))
) (
    input              clk,
    input              cen6,
    input       [4:0]  HS,
    input       [4:0]  SV,
    input    [DW-1:0]  attr,
    input    [DW-1:0]  id,
    input              SCxON,
    input              flip,
    // Palette PROMs
    input   [7:0]      prog_addr,
    input              prom_hi_we,
    input              prom_lo_we,
    input   [3:0]      prom_din,
    // Gfx ROM
    output reg  [ROM_AW-1:0] scr_addr,
    input             [15:0] rom_data,
    output [PXLW-1:0] scr_pxl
);

localparam ATTW =(  LAYOUT==3 || LAYOUT==8 ) ? 5 :
                 (( LAYOUT==5 || LAYOUT==7 ) ? 3 : 4);

`ifdef SIMULATION
initial $display("INFO: LAYOUT %2d for %m", LAYOUT);
initial begin
    scr_addr = {ROM_AW{1'b0}};
end
`endif

reg  [7:0]      addr_lsb;
reg  [ATTW-1:0] scr_attr0;
reg             scr_hflip0, scr_hflip1;

reg scr_hflip, scr_vflip, aux;

// Not sure about having ^flip in so many places
// Need to double check all games but BioCom
always @(*) begin
    case(LAYOUT)
        default: begin
            scr_hflip = attr[6]^flip;
            scr_vflip = attr[7]/*^flip*/;
        end
        1: begin // Bionic Commando SCROLL 1. No ^flip on schematics
            aux = ~&attr[7:6];
            scr_hflip = attr[7]&aux;
            scr_vflip = attr[6]&aux;
        end
        2: begin // Bionic Commando SCROLL 2. No ^flip on schematics
            scr_hflip = attr[7];
            scr_vflip = attr[6];
        end
        3: begin // Tiger Road
            // attribute bits:
            // 3-0 palette
            // 4   SCRWIN
            // 5   HFLIP
            // 7-6 ID
            scr_hflip = attr[5]^flip;
            scr_vflip = flip;
        end
        4: begin // Black Tiger
            scr_hflip = attr[7]^flip;
            scr_vflip = 1'b0;
        end
        5: begin // Legendary Wings / Section Z
            scr_hflip = attr[3]^flip;
            scr_vflip = attr[4];
        end
        6: begin // Trojan SCR1
            scr_hflip = attr[4]^flip;
            scr_vflip = 0;
        end
        7: begin // Trojan SCR2
            scr_hflip = attr[4]^flip;
            scr_vflip = attr[5];
        end
        8: begin // Side Arms
            scr_hflip = attr[1]^flip;
            scr_vflip = attr[2];
        end
        9: begin // Street Fighter
            scr_hflip = attr[8]^flip;
            scr_vflip = attr[9];
        end
        10: begin // The Speed Rumbler
            scr_hflip = flip;
            scr_vflip = attr[3];
        end
    endcase
end

// Set input for ROM reading
always @(posedge clk) if(cen6) begin
    if( HS[2:0]==3'd1 ) begin // attr/low data corresponds to this tile
            // from HS[2:0] = 1,2,3...0. because RAM output is latched
        case( LAYOUT )
        0: begin // 1943, 32x32 tiles
            scr_attr0 <= attr[5:2];
            scr_addr[ROM_AW-1:1] <= { attr[0] & AS8MASK, id, // AS
                            HS[4:3]^{2{scr_hflip}},
                            SV^{5{scr_vflip}} }; /*vert_addr*/
            scr_addr[0] <= HS[2]^scr_hflip;
            end
        1: begin // Bionic Commando, scroll 1, 16x16 tiles
            scr_attr0 <= { attr[7]&attr[6], attr[5:3] };
            scr_addr  <= { attr[2:0], id, // AS
                            SV[3:0]^{4{scr_vflip}},
                            HS[3]^scr_hflip,    // it was bit 5 originally
                            HS[2]^scr_hflip };  // swapped for cache performance
            end
        2: begin // Bionic Commando, scroll 2, 8x8 tiles
            scr_attr0 <= { 1'b0, attr[5:3] }; // MSB doesn't connect to anything on the higher levels
            scr_addr  <= { attr[2:0], id, // AS
                            SV[2:0]^{3{scr_vflip}},
                            HS[2]^scr_hflip };
            end
        3: begin // Tiger Road, 32x32 tiles
            scr_attr0 <= attr[4:0];
            scr_addr  <= { attr[7:6], id, // 2+8+2+5+1=18 bits
                            HS[4:3]^{2{scr_hflip^flip}},
                            SV[4:0],
                            HS[2]^scr_hflip };
            end
        4: begin // Black Tiger, 16x16 tiles
            scr_attr0  <= attr[6:3];
            scr_addr   <= { attr[2:0], id, // AS
                        HS[3]^scr_hflip,
                        SV[3:0]^{4{flip}},
                        HS[2]^scr_hflip };
        end
        5: begin // Legendary Wings, Section Z, 16x16 tiles
            scr_attr0  <= attr[2:0];
            scr_addr   <= { attr[7:5], id, // AS=3+8+6=17 bits
                        HS[3]^(scr_hflip^flip),
                        SV[3:0]^{4{scr_vflip}},
                        HS[2]^scr_hflip };
        end
        6: begin // Trojan, 16x16 tiles - SCR1
            scr_attr0  <= attr[3:0];
            scr_addr   <= { attr[7:5], id, // AS=3+8+6=17 bits
                        HS[3]^(scr_hflip^flip),
                        SV[3:0],
                        HS[2]^scr_hflip };
        end
        7: begin // Trojan, 16x16 tiles - SCR2
            scr_attr0  <= attr[2:0];
            scr_addr   <= { attr[7], id, // AS=1+8+6=15 bits
                        HS[3]^(scr_hflip^flip),
                        SV[3:0]^{4{scr_vflip}},
                        HS[2]^scr_hflip };
        end
        8: begin // Side Arms, 32x32 tiles, 256kBytes in 16 bits = 2^17 words
            scr_attr0 <= attr[7:3];
            scr_addr  <= { attr[0], id, // AS=1+8+2+5+1=17 bits
                            HS[4:3]^{2{scr_hflip^flip}},
                            SV[4:0]^{5{scr_vflip}},
                            HS[2]^scr_hflip };
        end
        9: begin // Street Fighter, 16x16 tiles
            scr_attr0 <= attr[3:0]; // how many bits?
            scr_addr  <= { id[ROM_AW-7:0], // AS=16+6=22 bits max
                       HS[3]^(scr_hflip^flip),
                       SV[3:0]^{4{scr_vflip}},
                       HS[2]^scr_hflip };
        end
        10: begin // The Speed Rumbler
            scr_attr0  <= {attr[4], attr[7:5]};
            scr_addr   <= { attr[2:0], id, // AS=3+8+6=17 bits
                       HS[3]^(scr_hflip^flip),
                       SV[3:0]^{4{scr_vflip}},
                       HS[2]^scr_hflip };
        end
        endcase
        scr_hflip0 <= scr_hflip;
    end
    else if(HS[1:0]==2'b1) begin
        case( LAYOUT )
            // Bionic Commando scroll 1
            1: if(HS[2:0]==3'b101 ) begin
                scr_addr[1:0] <= HS[3:2]^{2{scr_hflip0}};
            end
            // 1943, Bionic Commando scroll 2, Tiger Road, Side Arms
            0,2,3,8: if(HS[2:0]==3'b101 ) begin
                scr_addr[0] <= HS[2]^scr_hflip0;
            end
            4,5,6,7,9,10: begin // 16x16 Black Tiger, Section Z, Legendary Wings, Trojan, Street Fighter
                scr_addr[5] <= HS[3]^(scr_hflip0^flip);
                scr_addr[0] <= HS[2]^scr_hflip0;
            end
        endcase // LAYOUT
    end
end

// Draw pixel on screen
reg [     3:0] w,x,y,z;
reg [     3:0] scr_col0;
reg [ATTW-1:0] scr_attr1, scr_pal0;

// Character data delay
// clock count      stage
// -1               Assign map address
// 1                read map data
// 5                read tile rom data
// 6                assign to scr_col
// 7                read from PROM
// Total delay = 1 (+8) pixels

always @(posedge clk) if(cen6) begin
    if( HS[1:0]==2'd1 ) begin
            { z,y,x,w } <= rom_data;
            scr_hflip1  <= scr_hflip0; // must be ready when z,y,x are.
            scr_attr1   <= scr_attr0;
        end
    else
        begin
            if( scr_hflip1 ) begin
                w <= {1'b0, w[3:1]};
                x <= {1'b0, x[3:1]};
                y <= {1'b0, y[3:1]};
                z <= {1'b0, z[3:1]};
            end
            else  begin
                w <= {w[2:0], 1'b0};
                x <= {x[2:0], 1'b0};
                y <= {y[2:0], 1'b0};
                z <= {z[2:0], 1'b0};
            end
        end
    scr_col0  <= scr_hflip1 ? { w[0], x[0], y[0], z[0] } : { w[3], x[3], y[3], z[3] };
    scr_pal0  <= scr_attr1;
end

generate
    if( PALETTE ) begin
        wire [7:0] pal_addr = SCxON ? { scr_pal0, scr_col0 } : 8'hFF;

        // Palette
        jtframe_prom #(.AW(8),.DW(2),.SIMFILE(SIMFILE_MSB)) u_prom_msb(
            .clk    ( clk            ),
            .cen    ( cen6           ),
            .data   ( prom_din[1:0]  ),
            .rd_addr( pal_addr       ),
            .wr_addr( prog_addr      ),
            .we     ( prom_hi_we     ),
            .q      ( scr_pxl[5:4]   )
        );

        jtframe_prom #(.AW(8),.DW(4),.SIMFILE(SIMFILE_LSB)) u_prom_lsb(
            .clk    ( clk            ),
            .cen    ( cen6           ),
            .data   ( prom_din       ),
            .rd_addr( pal_addr       ),
            .wr_addr( prog_addr      ),
            .we     ( prom_lo_we     ),
            .q      ( scr_pxl[3:0]   )
        );
    end else begin
        reg [PXLW-1:0] pxl_dly; // to have the same delay as the palette case
        always @(posedge clk)
            pxl_dly <= { scr_pal0, SCxON ? scr_col0 : 4'hf };
        assign scr_pxl = pxl_dly;
    end
endgenerate

endmodule

/* verilator lint_on SELRANGE */
/* verilator lint_on WIDTH */
