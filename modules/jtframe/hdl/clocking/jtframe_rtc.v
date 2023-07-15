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
    along with JTFRAME. If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 22-6-2023 */

module jtframe_rtc(
    input            rst,
    input            clk,
    input            cen,   // 1024 Hz clock enable
    input      [7:0] din,
    input      [2:0] we,    // overwrite hour, min, sec
    output reg [7:0] sec, min, hour // BCD
);

reg [9:0] cnt;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        { hour, min, sec } <= `ifndef JTFRAME_SIM_RTC 0 `else `JTFRAME_SIM_RTC `endif;
        cnt <= 0;
    end else begin
        if( cen ) begin
            cnt <= cnt+10'd1;
            if( cnt==0 ) begin
                sec[3:0] <= sec[3:0]+4'd1;
                if( sec[3:0]==9 ) begin // 9 seconds
                    sec[3:0] <= 0;
                    sec[7:4] <= sec[7:4]+4'd1;
                    if( sec[7:4]==5 ) begin // 59 seconds
                        sec[7:4] <= 0;
                        min[3:0] <= min[3:0]+4'd1;
                        if( min[3:0]==9 ) begin // 9 minutes
                            min[3:0] <= 0;
                            min[7:4] <= min[7:4]+4'd1;
                            if( min[7:4]==5 ) begin // 59 minutes
                                min[7:4] <= 0;
                                hour[3:0] <= hour[3:0]+4'd1;
                                if( hour[3:0]==9 || hour==8'h23 ) begin // 9 or 23 hours
                                    hour[3:0] <= 0;
                                    hour[7:4] <= hour==8'h23 ? 4'd0 : hour[7:4]+4'd1;
                                end
                            end
                        end
                    end
                end
            end
        end
        if( we[0] ) sec  <= din;
        if( we[1] ) min  <= din;
        if( we[2] ) hour <= din;
    end
end

endmodule