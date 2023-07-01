/*  This file is part of JTFRAME.
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
    Date: 17-12-2022 */

module jtframe_edge #(parameter
    QSET=1    // q value when set
)(
    input       rst,
    input       clk,
    input       edgeof,
    input       clr,
    output reg  q
);

    reg edge_l=0;

    always @(posedge clk) begin
        edge_l <= edgeof;
    end

    always @(posedge clk,posedge rst) begin
        if( rst ) begin
            q <= ~QSET[0];
        end else begin
            if( clr )
                q <= ~QSET[0];
            else if( edgeof & ~edge_l ) q <= QSET[0];
        end
    end

endmodule

//////////////////////////////////////////

module jtframe_edge_pulse #(parameter
    INVERT=0,
    NEGEDGE=0
)(
    input       rst,
    input       clk,
    input       cen,
    input       sigin,
    output reg  pulse
);

    reg sigin_l;

    always @(posedge clk,posedge rst) begin
        if( rst ) begin
            pulse <= INVERT[0];
            sigin_l <= 0;
        end else if(cen) begin
            sigin_l <= sigin;
            pulse <= (NEGEDGE==1 ? ~sigin & sigin_l : sigin & ~sigin_l)^INVERT[0];
        end
    end

endmodule

