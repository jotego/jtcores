/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 5-5-2021 */

module jtcps2_dtack(
    input       rst,
    input       clk,        // 48 MHz
    output reg  cen16,
    output reg  cen16b,

    input       ASn,
    input       LDSn,
    input       UDSn,
    input       one_wait,
    input       bus_cs,
    input       bus_busy,
    input       busack,

    input       main2qs_cs, // set to zero for CPS1
    input       qs_busakn_s,

    output reg  DTACKn
);

localparam FW=7;
localparam [FW:0] FS=3;

reg        last_ASn;
reg  [FW-1:0] fail_cnt;
wire [FW:0] next_cnt = {1'd0,fail_cnt} + FS;

reg        skipped, s3_over;
reg  [2:0] cen_cnt=0;
wire       recover  = (ASn || (!ASn && !DTACKn)) && fail_cnt!=0 && !busack;
wire       cnt_over = recover ? cen_cnt>=1 : cen_cnt>=2;

`ifdef SIMULATION
    initial begin
        fail_cnt = 0;
        s3_over  = 0;
        DTACKn   = 1;
    end
`endif

always @(posedge clk) begin
    if( cen_cnt==0 ) begin
        skipped <= 0;
    end else if( cnt_over ) begin
        skipped <= recover;
    end
    cen_cnt <= cnt_over  ? 3'd0 : (cen_cnt+3'd1);
    cen16   <= cen_cnt==0;
    cen16b  <= cen_cnt==1;

end

always @(posedge clk, posedge rst) begin : dtack_gen
    if( rst ) begin
        DTACKn      <= 1'b1;
        fail_cnt    <= 0;
        s3_over     <= 0;
    end else begin
        last_ASn <= ASn;
        if( (!ASn && last_ASn) || ASn
            || (main2qs_cs && qs_busakn_s) // wait for Z80 bus grant
            || (!ASn && (UDSn&&LDSn)) // read-modify-write
        ) begin // for falling edge of ASn
            DTACKn  <= 1;
            s3_over <= 0;
        end else if( !ASn  ) begin
            if( cen16 ) begin
                s3_over <= 1;
            end
            if( bus_cs ) begin
                // Average delay can be displayed in simulation by defining the
                // macro REPORT_DELAY
                if( bus_busy && s3_over && cen16 ) begin
                    fail_cnt<= next_cnt[FW] ? {FW{1'b1}} : next_cnt[FW-1:0];
                end
                if (!bus_busy && {UDSn,LDSn}!=3) begin
                    DTACKn <= 1'b0;
                end
            end else begin
                DTACKn <= 1'b0;
            end
        end

        if( skipped && fail_cnt!=0 ) fail_cnt <= fail_cnt-1'd1;
    end
end

`ifdef SIMULATION
// Note that the data for the first frame may be wrong because
// of SDRAM initialization
reg reported=0;
always @(posedge clk) begin
    if( ~reported & (next_cnt[FW]) ) begin
        $display("Warning: bus timing fail counter max'ed out at &t (%m)",$time);
        reported <= 1;
    end
end
`endif

endmodule