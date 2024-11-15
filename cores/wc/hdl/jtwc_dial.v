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
    Date: 15-11-2024 */

module jtwc_dial(
    input            rst,
    input            clk,

    input      [1:0] addr,
    input      [7:0] din,
    input            we,

    input      [1:0] dial_x,
    input      [1:0] dial_y,    
    output reg [7:0] axis,
    // debug
    input      [7:0] debug_bus,
    output reg [7:0] st_dout
);

reg  [ 7:0] offsetx, offsety;
wire [ 7:0] dx, dy;
wire [11:0] posx, posy;
wire        dirx, diry;

function [7:0] delta(input [7:0]axis, input [7:0]offset, input dir);
begin
    reg [7:0] step;
    step = axis-offset;
    delta = step==0 ? 8'h80 : {dir,~dir,{6{~dir}}^step[7:2]};
end
endfunction

assign dx = delta(posx[11-:8],offsetx,dirx);
assign dy = delta(posy[11-:8],offsety,diry);

always @(posedge clk) begin
    case(debug_bus[2:0])
        0: st_dout <= posx[11-:8];
        1: st_dout <= posy[11-:8];
        2: st_dout <= {3'd0,diry,3'd0,dirx};
        4: st_dout <= dx;
        5: st_dout <= dy;
        6: st_dout <= offsetx;
        7: st_dout <= offsety;
        default: st_dout <= 0;
    endcase
end

always @(posedge clk) begin
    if(rst) begin
        offsetx <= 0;
        offsety <= 0;
    end else begin
        axis <= addr[0] ? dx : dy;
        if(we) case(addr)
            0: offsetx <= posx[11-:8];
            1: offsety <= posy[11-:8];
            default:;
        endcase
    end
end

jt4701_axis u_x1p(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .sigin      ( dial_x    ),
    .flag_clrn  ( 1'b0      ),
    .flagn      (           ),
    .axis       ( posx      ),
    .dir        ( dirx      ),
    .step       (           ) 
);

jt4701_axis u_xyp(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .sigin      ( dial_y    ),
    .flag_clrn  ( 1'b0      ),
    .flagn      (           ),
    .axis       ( posy      ),
    .dir        ( diry      ),
    .step       (           ) 
);

endmodule