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
    Date: 5-7-2025 */

module jtk053252(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             cs,
    input       [3:0] addr,
    input             rnw,
    input       [7:0] din,
    output reg  [7:0] dout,
    output reg  [9:0] hdump,
    output reg  [8:0] vdump,
    // IOCTL dump
    input      [3:0] ioctl_addr,
    output reg [7:0] ioctl_din
);

wire [9:0] htotal;
wire [8:0] hfporch, hbporch, vtotal;
wire [7:0] int1en, int2en, vfporch, vbporch, inttime, int1ack, int1ack;
wire [3:0] hswidth, vswidth;

reg  [9:0] hcnt, hb_end;
reg  [8:0] vcnt, vb_end;
wire       hover = hcnt==htotal;
wire       vover = vcnt==vtotal;

always @(posedge clk) begin
    hb_end <= hfporch+hbporch + {2'd0,hswidth,3'd0}+9'd7;
    vb_end <= vfporch+vbporch + {5'd0,vswidth}+9'd1;
end

always @(posedge clk) begin
    if(rst) begin
        hcnt <= 0;
        vcnt <= 0;
    end else if(pxl_cen) begin
        hcnt <= hover ? 10'd0 : hcnt+10'd1;
        if(hover) begin
            vcnt <= vover ? 9'd0: vcnt+9'd1;
            lhbl <= 0;
            if( vover ) lvbl <= 0;
        end
        if(hcnt==hb_end) lhbl <= 1;
        if(vcnt==vb_end) lvbl <= 1;
    end
end

jtk053252_mmr u_mmr(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .cs         ( cs        ),
    .addr       ( addr      ),
    .rnw        ( rnw       ),
    .din        ( din       ),
    .dout       ( dout      ),

    .htotal     ( htotal    ),
    .hfporch    ( hfporch   ),
    .hbporch    ( hbporch   ),
    .int1en     ( int1en    ),
    .int2en     ( int2en    ),
    .vtotal     ( vtotal    ),
    .vfporch    ( vfporch   ),
    .vbporch    ( vbporch   ),
    .vswidth    ( vswidth   ),
    .hswidth    ( hswidth   ),
    .inttime    ( inttime   ),
    .int1ack    ( int1ack   ),
    .int1ack    ( int1ack   ),

    // IOCTL dump
    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din ),
    // Debug
    .debug_bus  ( 8'd0      ),
    .st_dout    (           )
);

endmodule