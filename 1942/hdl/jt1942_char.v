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
    Date: 20-1-2019 */

// 1942 Character Generation CHARA-GENE
// Schematics pages 7/8

`timescale 1ns/1ps

module jt1942_char(
    input            clk,    // 24 MHz
    input            cen6  /* synthesis direct_enable = 1 */,   //  6 MHz
    input            cen3,
    input   [10:0]   AB,
    input   [ 7:0]   V128, // V128-V1
    input   [ 7:0]   H128, // Hfix-H1
    input            char_cs, // DOCS in schematics
    input            flip,
    input   [ 7:0]   din,
    output  [ 7:0]   dout,
    input            rd_n,
    output           busy,  // bus busy
    output [3:0]     char_pxl,
    input            pause,
    // Palette PROM F1
    input   [7:0]    prog_addr,
    input            prom_f1_we,
    input   [3:0]    prom_din,
    // ROM
    output reg [11:0] char_addr,
    input      [15:0] char_data
);

parameter HOFFSET=8'd5;
reg [5:0] char_pal;
reg [1:0] char_col;

wire [7:0] Hfix = H128 + HOFFSET; // Corrects pixel output offset

reg sel_scan;
always @(posedge clk)
    if(cen6) begin
        if( Hfix[2:0] == 3'b111 )
            sel_scan <= 1'b1;
        if( Hfix[2:0] == 3'b011 )
            sel_scan <= 1'b0;
    end

assign busy = sel_scan; // CPU access forbidden during this time
wire [9:0] scan = { {10{flip}}^{V128[7:3],Hfix[7:3]}};
wire [9:0] addr = sel_scan ? scan : AB[9:0];
wire we = !sel_scan && char_cs && rd_n;
wire [7:0] mem_low, mem_high, mem_msg;
wire we_low  = we && !AB[10];
wire we_high = we &&  AB[10];
reg [7:0] dout_low, dout_high;
assign dout = AB[10] ? dout_high : dout_low;

jtgng_ram #(.aw(10),.simfile("zeros1k.bin")) u_ram_low(
    .clk    ( clk      ),
    .cen    ( cen6     ),
    .data   ( din      ),
    .addr   ( addr     ),
    .we     ( we_low   ),
    .q      ( mem_low  )
);

jtgng_ram #(.aw(10),.simfile("zeros1k.bin")) u_ram_high(
    .clk    ( clk      ),
    .cen    ( cen6     ),
    .data   ( din      ),
    .addr   ( addr     ),
    .we     ( we_high  ),
    .q      ( mem_high )
);

jtgng_ram #(.aw(10),.synfile("msg.hex"),.simfile("msg.bin")) u_ram_msg(
    .clk    ( clk      ),
    .cen    ( cen6     ),
    .data   ( 8'd0     ),
    .addr   ( scan     ),
    .we     ( 1'b0     ),
    .q      ( mem_msg  )
);

always @(*) begin
    dout_low  = pause ? mem_msg : mem_low;
    dout_high = pause ? 8'h2    : mem_high;
end

// Draw pixel on screen
reg [15:0] chd;
reg [5:0] char_attr0, char_attr1, char_attr2;

always @(posedge clk) if(cen6) begin
    // new tile starts 8+5=13 pixels off
    // 8 pixels from delay in ROM reading
    // 4 pixels from processing the x,y,z and attr info.
    if( Hfix[2:0]==3'd1 ) begin // read data from memory when the CPU is forbidden to write on it
        // Set input for ROM reading
        char_attr1 <= char_attr0;
        char_attr0 <= dout_high[5:0];
        char_addr  <= { {dout_high[7], dout_low},
            {3{dout_high[6] ^ flip /*vflip*/  }}^V128[2:0] };
    end
    // The two case-statements cannot be joined because of the default statement
    // which needs to apply in all cases except the two outlined before it.
    case( Hfix[2:0] )
        3'd2: begin
            chd <= !flip ? {char_data[7:0],char_data[15:8]} : char_data;
            char_attr2 <= char_attr1;
        end
        3'd6:
            chd[7:0] <= chd[15:8];
        default:
            begin
                if( flip ) begin
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
    char_col <= flip ? { chd[0], chd[4] } : { chd[3], chd[7] };
    char_pal <= char_attr2;
end

// palette ROM
jtgng_prom #(.aw(8),.dw(4),.simfile("../../../rom/1942/sb-0.f1")) u_vprom(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prom_din       ),
    .rd_addr( {char_pal,char_col}   ),
    .wr_addr( prog_addr      ),
    .we     ( prom_f1_we     ),
    .q      ( char_pxl       )
);


endmodule // jtgng_char