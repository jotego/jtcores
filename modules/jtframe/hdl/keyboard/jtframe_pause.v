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
    Date: 10-5-2021 */

module jtframe_pause(
    input      rst, clk,
               key_pause, joy_pause, osd_pause, service,
               lvbl,
    output     game_pause
);

reg  toggle=0,
     adv_toggle=0, lvbl_l=0, service_l=0, service_event=0, restore=0;

always @(posedge clk) begin
    toggle = |{key_pause, joy_pause, osd_pause, adv_toggle };
end

always @(posedge clk) begin
    lvbl_l     <= lvbl;
    service_l  <= service;
    adv_toggle <= 0;
    if( service && !service_l ) service_event <= game_pause;
    if( !lvbl && lvbl_l ) begin
        adv_toggle    <= service_event | restore;
        restore       <= service_event;
        service_event <= 0;
    end
end

jtframe_toggle #(.W(1)) u_toggle(
    .rst    ( rst        ),
    .clk    ( clk        ),
    .toggle ( toggle     ),
    .q      ( game_pause )
);

endmodule        