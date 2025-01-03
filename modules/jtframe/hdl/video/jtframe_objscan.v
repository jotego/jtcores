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
    Date: 2-1-2025 */

module jtframe_objscan #(parameter
    OBJW=6,
    STW=4,
    HREPW=3,
    // do not modify:
    AW=OBJW+STW
)(
    input               clk,
    input               hs,
    input               blankn,
    input        [ 8:0] vrender,
    output reg   [ 8:0] vlatch,
    
    input               draw_step,
    input               skip,
    input               inzone,

    // support for multiple horizontal tiles
    input      [HREPW-1:0] hsize,  // number of extra tiles to repeat (default zero)
    output     [HREPW-1:0] haddr,  // tile code portion (goes to rom_addr)
    output reg [HREPW-1:0] hsub=0, // H position delta
    input                  hflip,

    input               dr_busy,
    output reg          dr_draw = 0,

    output     [AW-1:0] addr,
    output reg[STW-1:0] step
);

reg             cen=0,hs_l=0,done=0, hs_latched;
reg [OBJW-1:0]  objcnt;
reg [HREPW-1:0] hcnt; // current tile repetition

assign addr  = {objcnt,step};
assign haddr = hcnt^{HREPW{hflip}};

always @(posedge clk) begin
    cen <= ~cen;
end

always @(posedge clk) if(cen) begin
    hs_l    <= hs;
    dr_draw <= 0;
    if( hs && !hs_l && blankn ) begin
        done   <= 0;
        objcnt <= 0;
        step   <= 0;
        vlatch <= vrender;
    end else if( !done ) begin
        step  <= step + 1'd1;
        if(step==0) begin
            hcnt<=0;
        end
        if(skip) begin
            step <= 0;
            {done,objcnt} <= {1'd0,objcnt}+1'd1;
        end
        if(draw_step) begin            
            step <= step;
            if( !dr_busy || !inzone ) begin
                if(inzone) begin
                    dr_draw <= 1;
                    hsub    <= hcnt;
                end
                if(hcnt!=hsize) begin
                    hcnt<=hcnt+1'd1;
                end else begin
                    step  <= 0;
                    {done,objcnt} <= {1'd0,objcnt}+1'd1;
                end
            end
        end
    end
end

endmodule