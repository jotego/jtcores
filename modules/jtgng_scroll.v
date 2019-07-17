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
    input              cen3,
    input       [10:0] AB,
    input       [ 7:0] V128, // V128-V1
    input       [ 8:0] H, // H256-H1
    input              scr_cs,
    input              scrpos_cs,
    input              flip,
    input       [ 7:0] din,
    output reg  [ 7:0] dout,
    input              rd,
    output             MRDY_b,
    output             busy,

    // ROM
    output reg  [14:0] scr_addr,
    input       [23:0] rom_data,
    input              rom_ok,
    output      [ 2:0] scr_pal,
    output      [ 2:0] scr_col,
    output             scrwin
);

parameter Hoffset=9'd5;

reg [2:0] scr_pal0, scr_col0;
reg scrwin0;

assign scr_pal = scr_pal0;
assign scr_col = scr_col0;
assign scrwin  = scrwin0;


wire [8:0] Hfix = H + Hoffset; // Corrects pixel output offset
reg  [ 8:0] HS, VS;
wire [ 7:0] VF = {8{flip}}^V128;
wire [ 7:0] HF = {8{flip}}^Hfix[7:0];
reg  [ 8:0] hpos=9'd0, vpos=9'd0;

wire H7 = (~Hfix[8] & (~flip ^ HF[6])) ^HF[7];

reg [2:0] HSaux;

always @(*) begin
    VS = vpos + {1'b0, VF};
    { HS[8:3], HSaux } = hpos + { ~Hfix[8], H7, HF[6:0]};
    HS[2:0] = HSaux ^ {3{flip}};
end

wire [9:0] scan = { HS[8:4], VS[8:4] };
wire sel_scan = ~HS[2];
assign busy = sel_scan;

wire [9:0]  addr = sel_scan ? scan : AB[9:0];
wire we = !sel_scan && scr_cs && !rd;
wire we_low  = we && !AB[10];
wire we_high = we &&  AB[10];

always @(posedge clk) if(cen6) begin
    if( scrpos_cs && AB[3])
    case(AB[1:0])
        2'd0: hpos[7:0] <= din;
        2'd1: hpos[8]   <= din[0];
        2'd2: vpos[7:0] <= din;
        2'd3: vpos[8]   <= din[0];
    endcase
end

wire [7:0] dout_low, dout_high;
always @(posedge clk) begin : dout_latch
    reg last_AB10, last_sel;
    last_sel  <= sel_scan;
    last_AB10 <= AB[10];
    if( !last_sel )
        dout <= last_AB10 ? dout_high : dout_low;
end

jtgng_ram #(.aw(10),.cen_rd(1),.simfile("scrlow.bin")) u_ram_low(
    .clk    ( clk      ),
    .cen    ( cen6     ),
    .data   ( din      ),
    .addr   ( addr     ),
    .we     ( we_low   ),
    .q      ( dout_low )
);

jtgng_ram #(.aw(10),.cen_rd(1)) u_ram_high(
    .clk    ( clk      ),
    .cen    ( cen6     ),
    .data   ( din      ),
    .addr   ( addr     ),
    .we     ( we_high  ),
    .q      ( dout_high)
);

assign MRDY_b = !( scr_cs && sel_scan ); // halt CPU

reg scr_hflip;
reg [7:0] addr_lsb;

reg [4:0] scr_attr0, scr_attr1;

// Set input for ROM reading
always @(posedge clk) if(cen6) begin
    if( HS[2:0]==3'd1 ) begin // dout_high/low data corresponds to this tile
            // from HS[2:0] = 1,2,3...0. because RAM output is latched
        scr_attr1 <= scr_attr0;
        scr_attr0 <= dout_high[4:0];
        scr_addr  <= {   dout_high[7:6], dout_low, // AS
                        HS[3]^dout_high[4] /*scr_hflip*/,
                        {4{dout_high[5] /*vflip*/}}^VS[3:0] /*vert_addr*/ };
    end
end

// Draw pixel on screen
reg [7:0] x,y,z;
reg [3:0] scr_attr2;

reg [23:0] good_data;
always @(posedge clk) begin
    if( HS[2:0] > 3'd2 && rom_ok )
        good_data <= rom_data;
end

always @(posedge clk) if(cen6) begin
    // new tile starts 8+5=13 pixels off
    // 8 pixels from delay in ROM reading
    // 4 pixels from processing the x,y,z and attr info.
    if( HS[2:0]==3'd2 ) begin
            { z,y,x } <= good_data;
            scr_hflip <= scr_attr1[4] ^ flip; // must be ready when z,y,x are.
            scr_attr2 <= scr_attr1[3:0];
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
    scr_col0  <= scr_hflip ? { x[0], y[0], z[0] } : { x[7], y[7], z[7] };
    scr_pal0  <= scr_attr2[2:0];
    scrwin0   <= scr_attr2[3];
end

endmodule // jtgng_scroll