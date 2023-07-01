/*  This file is part of JT_FRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 25-9-2019 */

module jtframe_resync(
    input         clk,
    input         pxl_cen,
    input         hs_in,
    input         vs_in,
    input         LVBL,
    input         LHBL,
    input  [3:0]  hoffset,
    input  [3:0]  voffset,
    output reg    hs_out,
    output reg    vs_out
);

parameter CNTW = 10; // max 1024 pixels/lines

reg [CNTW-1:0]   hs_pos[0:1], vs_hpos[0:1], vs_vpos[0:1],// relative positions of the original sync pulses
                 hs_len[0:1], vs_len[0:1],               // count the length of the original sync pulses
                 hs_cnt,      vs_cnt,                    // count the position of the original sync pulses
                 hs_hold,     vs_hold;
reg              last_LHBL, last_LVBL, last_hsin, last_vsin;

wire             hb_edge, hs_edge, hs_n_edge, vb_edge, vs_edge, vs_n_edge;
reg              field;

wire [CNTW-1:0]  hpos_off = { {CNTW-4{hoffset[3]}}, hoffset[3:0]  };
wire [CNTW-1:0]  htrip = hs_pos[field] + hpos_off;
wire [CNTW-1:0]  vs_htrip = vs_hpos[field] + hpos_off;
wire [CNTW-1:0]  vs_vtrip = vs_vpos[field] + { {CNTW-4{voffset[3]}}, voffset[3:0]  };

assign hb_edge = LHBL && !last_LHBL;
assign hs_edge = hs_in && !last_hsin;
assign hs_n_edge = !hs_in && last_hsin;
assign vb_edge = LVBL && !last_LVBL;
assign vs_edge = vs_in && !last_vsin;
assign vs_n_edge = !vs_in && last_vsin;

always @(posedge clk) if(pxl_cen) begin
    last_LHBL <= LHBL;
    last_LVBL <= LVBL;
    last_hsin <= hs_in;
    last_vsin <= vs_in;

    hs_cnt <= hb_edge ? {CNTW{1'b0}} : hs_cnt+1'b1;
    if( vb_edge ) begin
        vs_cnt <= {CNTW{1'b0}};
        field <= ~field;
    end else if(hb_edge)
        vs_cnt <= vs_cnt+1'b1;

    // Horizontal
    if( hs_edge ) hs_pos[field] <= hs_cnt;
    if( hs_n_edge ) hs_len[field] <= hs_cnt - hs_pos[field];

    if( hs_cnt == htrip ) begin
        hs_out <= 1;
        hs_hold <= hs_len[field] - 1'b1;
    end else begin
        if( |hs_hold ) hs_hold <= hs_hold - 1'b1;
        if( hs_hold == 0 ) hs_out <= 0;
    end

    // Vertical
    if( vs_edge ) begin
        vs_hpos[field] <= hs_cnt;
        vs_vpos[field] <= vs_cnt;
    end
    if( vs_n_edge ) vs_len[field] <= vs_cnt - vs_vpos[field];

    if( hs_cnt == vs_htrip ) begin
        if( vs_cnt == vs_vtrip ) begin
            vs_hold <= vs_len[field] - 1'b1;
            vs_out <= 1;
        end else begin
            if( |vs_hold ) vs_hold <= vs_hold - 1'b1;
            if( vs_hold == 0 ) vs_out <= 0;
        end
    end

end

`ifdef SIMULATION
initial begin
    hs_cnt = {CNTW{1'b0}};
    vs_cnt = {CNTW{1'b0}};
    hs_out = 0;
    vs_out = 0;
end
`endif

endmodule
