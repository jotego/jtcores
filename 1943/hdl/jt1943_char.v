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
    Date: 18-2-2019 */

// 1943 Character Generation

`timescale 1ns/1ps

module jt1943_char(
    input            clk,    // 24 MHz
    input            cen6  /* synthesis direct_enable = 1 */,   //  6 MHz
    input            cen3,
    input            cpu_cen,
    input            CHON,
    input   [10:0]   AB,
    input   [ 7:0]   V128, // V128-V1
    input   [ 8:0]   H, // Hfix-H1
    input            char_cs, // DOCS in schematics
    input            flip,
    input   [ 7:0]   din,
    output  [ 7:0]   dout,
    input            rd_n,
    input            wr_n,
    output           cpu_wait,
    output  [ 3:0]   char_pxl,
    // Pause screen
    input            pause,
    input   [2:0]    avatar_idx,
    // Palette PROM F1
    input   [ 7:0]   prog_addr,
    input            prom_7f_we,
    input   [ 3:0]   prom_din,
    // ROM
    output reg [13:0] char_addr, // 32 kBytes
    input      [15:0] char_data
);

parameter HOFFSET=8'd5;
reg [4:0] char_pal;
reg [1:0] char_col;

// H goes from 80h to 1FFh
wire [8:0] Hfix_prev = H+HOFFSET;
wire [8:0] Hfix = !Hfix_prev[8] && H[8] ? Hfix_prev|9'h80 : Hfix_prev; // Corrects pixel output offset

reg sel_scan;
// wire sel_scan = ~Hfix[2];
wire [9:0] scan = { {10{flip}}^{V128[7:3],Hfix[7:3]}};
wire [9:0] addr = sel_scan ? scan : AB[9:0];
wire we = !sel_scan && char_cs && !wr_n;
wire [7:0] mem_low, mem_high, mem_msg, mem_msg_av;
wire we_low  = we && !AB[10];
wire we_high = we &&  AB[10];
reg [7:0] dout_low, dout_high;
assign dout = AB[10] ? dout_high : dout_low;

jtgng_ram #(.aw(10),.simfile("zeros1k.bin")) u_ram_low(
    .clk    ( clk      ),
    .cen    ( cpu_cen  ),
    .data   ( din      ),
    .addr   ( addr     ),
    .we     ( we_low   ),
    .q      ( mem_low  )
);

jtgng_ram #(.aw(10),.simfile("zeros1k.bin")) u_ram_high(
    .clk    ( clk      ),
    .cen    ( cpu_cen  ),
    .data   ( din      ),
    .addr   ( addr     ),
    .we     ( we_high  ),
    .q      ( mem_high )
);

// Pause screen message
wire cen_pause = cen6 & pause;
reg [7:0] msg_sel;

jtgng_ram #(.aw(10),.synfile("msg.hex"),.simfile("msg.bin")) u_ram_msg(
    .clk    ( clk       ),
    .cen    ( cen_pause ),
    .data   ( 8'd0      ),
    .addr   ( scan      ),
    .we     ( 1'b0      ),
    .q      ( mem_msg   )
);

reg       av_col;
`ifdef AVATARS
wire [7:0] av_scan = { avatar_idx, scan[9:5] };

jtgng_ram #(.aw(8),.synfile("msg_av.hex")) u_ram_msg_av(
    .clk    ( clk         ),
    .cen    ( cen_pause   ),
    .data   ( 8'd0        ),
    .addr   ( av_scan     ),
    .we     ( 1'b0        ),
    .q      ( mem_msg_av  )
);

always @(*) begin
    av_col    = scan[4:0] == 5'd9;
    msg_sel   = av_col ? mem_msg_av : mem_msg;
end
`else 
always @(*) msg_sel = mem_msg;
`endif

always @(*) begin
    dout_low  = pause ? msg_sel : mem_low;
    dout_high = pause ? 8'h2    : mem_high;
end

// The original board gates the CPU clock instead of using wait_n
// assign wait_n = !( char_cs && sel_scan ); // hold CPU
assign cpu_wait = sel_scan;
always @(posedge clk)
    if(cen6) begin
        if( Hfix[2:0] == 3'b111 )
            sel_scan <= 1'b1;
        if( Hfix[2:0] == 3'b011 )
            sel_scan <= 1'b0;
    end

// Draw pixel on screen
reg [15:0] chd;
reg [4:0] char_attr0, char_attr2;

// Character data delay
// clock count      stage
// 0                Read shared memory
// 1                set SDRAM request
// 1+8              pixel data into chd
// 2+8              data into char_col
// 3+8              data read from PROM -> output
// Total = 5 (+8) pixels

always @(posedge clk) if(cen6) begin
    // new tile starts 8+5=13 pixels off
    // 8 pixels from delay in ROM reading
    // 4 pixels from processing the x,y,z and attr info.
    if( Hfix[2:0]==3'd1 ) begin // read data from memory when the CPU is forbidden to write on it
        // Set input for ROM reading
        char_attr0 <= dout_high[4:0];
        char_addr  <= { {dout_high[7:5], dout_low}, V128[2:0] };
    end
    // The two case-statements cannot be joined because of the default statement
    // which needs to apply in all cases except the two outlined before it.
    case( Hfix[2:0] )
        3'd1: begin
            chd <= !flip ? {char_data[7:0],char_data[15:8]} : char_data;
            char_attr2 <= char_attr0;
        end
        3'd5:
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
wire [7:0] prom_addr = {1'b0, char_pal,char_col };
wire [3:0] prom_data;
assign char_pxl = (CHON | pause) ? prom_data : 4'hF;

jtgng_prom #(.aw(8),.dw(4),.simfile("../../../rom/1943/bm5.7f")) u_vprom(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prom_din       ),
    .rd_addr( prom_addr      ),
    .wr_addr( prog_addr      ),
    .we     ( prom_7f_we     ),
    .q      ( prom_data      )
);


endmodule // jtgng_char