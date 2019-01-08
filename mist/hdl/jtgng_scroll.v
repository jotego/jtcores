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

module jtgng_scroll(
    input              clk,     // 24 MHz
    input              cen6  /* synthesis direct_enable = 1 */,    //  6 MHz
    input       [10:0] AB,
    input       [ 7:0] V128, // V128-V1
    input       [ 8:0] H, // H256-H1
    input              scr_cs,
    input              scrpos_cs,
    input              flip,
    input       [ 7:0] din,
    output      [ 7:0] dout,
    input              rd,
    output             MRDY_b,
    output      [ 2:0] HSlow,

    // ROM
    output reg  [14:0] scr_addr,
    input       [23:0] scrom_data,
    output reg  [ 2:0] scr_pal,
    output reg  [ 2:0] scr_col,
    output reg         scrwin
);

parameter Hoffset=9'd5;

reg  [10:0]  addr;
reg  [ 8:0] HS, VS;
wire [ 7:0] VF = {8{flip}}^V128;
wire [ 7:0] HF = {8{flip}}^Hfix[7:0];
reg  [ 8:0] hpos=9'd0, vpos=9'd0;

wire [8:0] Hfix = H + Hoffset; // Corrects pixel output offset
wire H7 = (~Hfix[8] & (~flip ^ HF[6])) ^HF[7];

reg [2:0] HSaux;

always @(*) begin
    VS = vpos + {1'b0, VF};
    { HS[8:3], HSaux } = hpos + { ~Hfix[8], H7, HF[6:0]};
    HS[2:0] = HSaux ^ {3{flip}};
end

assign HSlow = HS[2:0];

reg we;
wire sel_scan = ~HS[2];

wire [9:0] scan = { HS[8:4], VS[8:4] };


always @(*)
    if( !sel_scan ) begin
        addr = AB;
        we   = scr_cs && !rd;
    end else begin
        we   = 1'b0; // line order is important here
        addr = { ~HS[0], scan }; 
    end


always @(posedge clk) if(cen6) begin
    if( scrpos_cs && AB[3]) 
    case(AB[1:0])
        2'd0: hpos[7:0] <= din;
        2'd1: hpos[8]   <= din[0];
        2'd2: vpos[7:0] <= din;
        2'd3: vpos[8]   <= din[0];
    endcase 
end

jtgng_ram #(.aw(11),.simfile("scr_ram.hex")) u_ram(
    .clk    ( clk      ),
    .cen    ( cen6     ),
    .data   ( din      ),
    .addr   ( addr     ),
    .we     ( we       ),
    .q      ( dout     )
);

assign MRDY_b = !( scr_cs && sel_scan ); // halt CPU

reg scr_hflip;
reg [7:0] addr_lsb;

reg [4:0] scr_attr0, scr_attr1;

// Set input for ROM reading
always @(posedge clk) if(cen6) begin
    case( HS[2:0] )
        3'd1: addr_lsb <= dout;
        3'd2: begin
            scr_attr1 <= scr_attr0;
            scr_attr0 <= dout[4:0];
            scr_addr <= {   dout[7:6], addr_lsb, // AS
                            HS[3]^dout[4] /*scr_hflip*/, 
                            {4{dout[5] /*vflip*/}}^VS[3:0] /*vert_addr*/ };
        end
        default:;
    endcase
end

// Draw pixel on screen
reg [7:0] x,y,z;

always @(posedge clk) if(cen6) begin
    // new tile starts 8+5=13 pixels off
    // 8 pixels from delay in ROM reading
    // 4 pixels from processing the x,y,z and attr info.
    if( HS[2:0]==3'd3 ) begin
            { z,y,x } <= scrom_data;     
            scr_hflip <= scr_attr1[4] ^ flip; // must be ready when z,y,x are.
        end
    else
        begin
            if( scr_hflip ) begin
                x <= {1'b0, x[7:1]};
                y <= {1'b0, y[7:1]};
                z <= {1'b0, z[7:1]};
            end
            else  begin
                x <= {x[6:0], 1'b0};
                y <= {y[6:0], 1'b0};
                z <= {z[6:0], 1'b0};
            end
        end
    if( HS[2:0]==3'd4 ) begin // 1 pixel after new z,y,x is loaded from ROM
        // because output to scr_col takes one more pixel
        scr_pal   <= scr_attr1[2:0];
        scrwin    <= scr_attr1[3]; 
    end
    scr_col <= scr_hflip ? { x[0], y[0], z[0] } : { x[7], y[7], z[7] };
end

endmodule // jtgng_scroll