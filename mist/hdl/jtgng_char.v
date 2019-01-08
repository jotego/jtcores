/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */
    
module jtgng_char(
    input            clk,    // 24 MHz
    input            cen6  /* synthesis direct_enable = 1 */,   //  6 MHz
    input   [10:0]   AB,
    input   [ 7:0]   V128, // V128-V1
    input   [ 7:0]   H128, // Hfix-H1
    input            char_cs,
    input            flip,
    input   [ 7:0]   din,
    output  [ 7:0]   dout,
    input            rd,
    output           MRDY_b,

    // ROM
    output reg [12:0] char_addr,
    input  [15:0] chrom_data,
    output reg [ 3:0] char_pal,
    output reg [ 1:0] char_col
);

parameter Hoffset=8'd5;

wire [7:0] Hfix = H128 + Hoffset; // Corrects pixel output offset

reg [10:0]  addr;
wire sel_scan = ~Hfix[2];
reg we;

wire [9:0] scan = { {10{flip}}^{V128[7:3],Hfix[7:3]}};

always @(*)
    if( !sel_scan ) begin
        addr = AB;
        we   = char_cs && !rd;
    end else begin
        we   = 1'b0; // line order is important here
        addr = { ~Hfix[0], scan };
    end

jtgng_ram #(.aw(11),.simfile("char_ram.hex")) u_ram(
    .clk    ( clk      ),
    .cen    ( cen6     ),
    .data   ( din      ),
    .addr   ( addr     ),
    .we     ( we       ),
    .q      ( dout     )
);


assign MRDY_b = !( char_cs && sel_scan ); // hold CPU

reg [7:0] addr_lsb;
// reg [9:0] AC; // ADDRESS - CHARACTER

reg char_hflip;
reg half_addr;

// Draw pixel on screen
reg [15:0] chd;
reg [4:0] char_attr0, char_attr1;

always @(posedge clk) if(cen6) begin
    // new tile starts 8+5=13 pixels off
    // 8 pixels from delay in ROM reading
    // 4 pixels from processing the x,y,z and attr info.    
    case( Hfix[2:0] ) // read data from memory when the CPU is forbidden to write on it
        // Set input for ROM reading
        3'd1: addr_lsb <= dout;
        3'd2: begin
            char_attr1 <= char_attr0;
            char_attr0 <= dout[4:0];
            char_addr  <= { {dout[7:6], addr_lsb}, 
                {3{dout[5] /*vflip*/ ^ flip}}^V128[2:0] };
        end
        default:;
    endcase
    // The two case-statements cannot be joined because of the default statement
    // which needs to apply in all cases except the two outlined before it.
    case( Hfix[2:0] )
        3'd3: begin
            chd <= !char_hflip ? {chrom_data[7:0],chrom_data[15:8]} : chrom_data;
            char_hflip <= char_attr1[4] ^ flip;
        end
        3'd7: 
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
    if( Hfix[2:0]==3'd4 ) char_pal   <= char_attr1[3:0]; 
    // 1-pixel delay in order to latch signals:
    char_col <= char_hflip ? { chd[0], chd[4] } : { chd[3], chd[7] };
end

endmodule // jtgng_char