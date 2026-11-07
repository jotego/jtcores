/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-6-2023 */

module jtframe_rtc(
    input            rst,
    input            clk,
    input            cen,   // 1024 Hz clock enable
    input      [7:0] din,
    input      [2:0] we,    // overwrite hour, min, sec
    output reg [7:0] sec, min, hour, // BCD
    // IOCTL dump
    input      [1:0] ioctl_addr,
    input      [7:0] ioctl_dout,
    output reg [7:0] ioctl_din,
    input            ioctl_wr
);

reg [9:0] cnt;

always @(posedge clk) begin
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
        if( ioctl_wr ) case(ioctl_addr)
            0: sec  <= ioctl_dout;
            1: min  <= ioctl_dout;
            2: hour <= ioctl_dout;
            default:;
        endcase
        case( ioctl_addr )
            0: ioctl_din <= sec;
            1: ioctl_din <= min;
            2: ioctl_din <= hour;
            3: ioctl_din <= 0;
        endcase
    end
end

endmodule