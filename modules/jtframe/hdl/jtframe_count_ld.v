/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-7-2025 */

module jtframe_count_ld #(
    parameter // keep order
            W=10,
            ONE_SHOT=0  // set to 1 to start counting when ld goes high
                        // and continue until tc is set
)(
    // keep port order
    input  rst, clk, cen,
           en, ld, // ld takes priority over _en_ and does not require _cen_
    input      [W-1:0] cnt0,
    output reg [W-1:0] cnt=0,
    output reg         tc       // tc=&cnt
);

reg  bsy;
wire [W-1:0] nx_cnt = ld ? cnt0 : cnt+1'd1;
wire count_up = (ONE_SHOT==0 || bsy) && en;

always @(posedge clk) begin
    if( rst ) begin
        cnt  <= 0;
        tc   <= 0;
        bsy  <= 0;
    end else if(cen) begin
        if( count_up | ld ) begin
            cnt <=  nx_cnt;
            tc  <= &nx_cnt;
            if(&nx_cnt ) bsy <= 0;
            if( ld     ) bsy <= 1;
        end
        if( !bsy && ONE_SHOT==1 ) tc <= 0;
    end
end

endmodule