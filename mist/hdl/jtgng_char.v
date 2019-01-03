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
    input            cen6,   //  6 MHz
    input   [10:0]   AB,
    input   [ 7:0]   V128, // V128-V1
    input   [ 7:0]   H128, // H128-H1
    input            char_cs,
    input            flip,
    input   [ 7:0]   din,
    output reg [7:0] dout,
    input            rd,
    output           MRDY_b,

    // ROM
    output reg [12:0] char_addr,
    input  [15:0] chrom_data,
    output [ 3:0] char_pal,
    output [ 1:0] char_col
);

reg [10:0]  addr;
reg [7:0] ram[0:2047];
wire sel = ~H128[2];
reg we;

wire [9:0] scan = { {10{flip}}^{V128[7:3],H128[7:3]}};

always @(*)
    if( !sel ) begin
        addr = AB;
        we   = char_cs && !rd;
    end else begin
        we   = 1'b0; // line order is important here
        addr = { H128[0], scan };
    end

`ifdef SIMULATION
initial $readmemh("char_ram.hex",ram);
`endif

// RAM
always @(posedge clk) //if(cen6) 
begin
    dout <= ram[addr];
    if( we ) ram[addr] <= din;
end

assign MRDY_b = !( char_cs && ( &H128[2:1]==1'b0 ) );

reg [7:0] aux;
reg [9:0] AC; // ADDRESS - CHARACTER
reg char_hflip_prev;

reg [2:0] vert_addr;

reg char_vflip;
reg char_hflip;
reg half_addr;
reg [3:0] pal_aux;

// Set input for ROM reading
always @(posedge clk) if(cen6) begin
    case( H128[2:0] )
        3'd1: aux <= dout;
        3'd2: begin
            AC       <= {dout[7:6], aux};
            char_hflip <= dout[4] ^ flip;
            char_vflip <= dout[5] ^ flip;
            pal_aux <= dout[3:0];           
            vert_addr <= {3{char_vflip}}^V128[2:0];
            char_addr <= { {dout[7:6], aux}, {3{dout[5] ^ flip}}^V128[2:0] };
        end
        default:;
    endcase
    //char_addr <= { AC, vert_addr };
end

// Draw pixel on screen
reg [15:0] chd;
reg [1:0] pxl_aux;

// delays pixel data so it comes out on a multiple of 8
jtgng_sh #(.width(4),.stages(5)) pal_sh(.clk(clk),.clk_en(cen6),.din(pal_aux),.drop(char_pal));
//jtgng_sh #(.width(2),.stages(3)) pxl_sh(.clk(clk),.din(pxl_aux),.drop(char_col));
assign char_col = pxl_aux;


always @(posedge clk) if(cen6) begin
    case( H128[2:0] )
        3'd6: begin
            chd <= char_hflip ? {chrom_data[7:0],chrom_data[15:8]} : chrom_data;
            char_hflip_prev <= char_hflip;
        end
        3'd2: 
            chd[7:0] <= chd[15:8];
        default:
            begin
                if( char_hflip_prev ) begin
                    chd[7:4] <= {1'b0, chd[7:5]};
                    chd[3:0] <= {1'b0, chd[3:1]};
                end
                else  begin
                    chd[7:4] <= {chd[6:4], 1'b0};
                    chd[3:0] <= {chd[2:0], 1'b0};
                end
            end
    endcase
    pxl_aux <= char_hflip_prev ? { chd[0], chd[4] } : { chd[3], chd[7] };
end

endmodule // jtgng_char