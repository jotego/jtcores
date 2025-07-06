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
    output      [7:0] dout,

    output reg        lhbl, lvbl, hs, vs,
    // IOCTL dump
    input      [3:0] ioctl_addr,
    output     [7:0] ioctl_din
);

parameter [127:0] INIT=128'h00_00_00_54_0E_0C_07_01_00_01_37_00_21_00_FF_01;

wire [9:0] htotal, hs_beg;
wire [8:0] hfporch, hbporch, vtotal, vs_beg;
wire [7:0] int1en, int2en, vfporch, vbporch, inttime, int1ack, int2ack;
wire [3:0] hswidth, vswidth;

reg  [9:0] hcnt, hb_end, hs_end;
reg  [8:0] vcnt, vb_end, vs_end;
wire       hover = hcnt==htotal;
wire       vover = vcnt==vtotal;

assign vs_beg = {1'b0,vfporch};
assign hs_beg = {1'b0,hfporch};

always @(posedge clk) begin
    hs_end <= hfporch + {2'd0,hswidth,3'd0}+9'd7;
    hb_end <= hs_end  + hbporch;
    vs_end <= vfporch + {5'd0,vswidth};
    vb_end <= vs_end  + vbporch + 9'd1;
end

always @(posedge clk) begin
    if(rst) begin
        hcnt <= 0;
        vcnt <= 0;
        lvbl <= 0;
        lhbl <= 0;
        vs   <= 0;
        hs   <= 0;
    end else if(pxl_cen) begin
        hcnt <= hover ? 10'd0 : hcnt+10'd1;
        if(hover) begin
            vcnt <= vover ? 9'd0: vcnt+9'd1;
            lhbl <= 0;
            if( vover )       lvbl <= 0;
            if( vcnt==vb_end) lvbl <= 1;
            if( vcnt==vs_beg)   vs <= 1;
            if( vcnt==vs_end)   vs <= 0;
        end
        if(hcnt==hs_beg )  hs <= 1;
        if(hcnt==hs_end )  hs <= 0;
        if(hcnt==hb_end) lhbl <= 1;
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
    .int2ack    ( int2ack   ),

    // IOCTL dump
    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din ),
    // Debug
    .debug_bus  ( 8'd0      ),
    .st_dout    (           )
);

endmodule
