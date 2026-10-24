/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 3-10-2026 */

module jtnarc_aerase(
    input             rst,
    input             clk,
    input             en,
    input             vb,
    input             line_load,
    input      [ 8:0] line_y,
    output reg        start,
    output reg        rtm,
    output reg [ 7:0] row,
    input             busy
);

reg  [7:0] cur, erow, lrow;
reg        valid, pend, step, vb_l, fin, odd;

always @(posedge clk) begin
    if( rst ) begin
        cur   <= 0;
        erow  <= 0;
        lrow  <= 0;
        valid <= 0;
        pend  <= 0;
        step  <= 0;
        vb_l  <= 0;
        fin   <= 0;
        odd   <= 0;
        start <= 0;
        rtm   <= 0;
        row   <= 0;
    end else begin
        start <= 0;
        vb_l  <= vb;
        if( vb && !vb_l ) begin
            valid <= 0;
            lrow  <= cur;
            if( valid && en && odd ) fin <= 1;
        end
        if( fin && !pend && !line_load ) begin
            erow <= lrow;
            pend <= 1;
            step <= 0;
            fin  <= 0;
        end
        if( line_load ) odd <= line_y[0];
        if( line_load && (line_y[8:1]!=cur || !valid) ) begin
            cur   <= line_y[8:1];
            valid <= 1;
            if( valid && en && !pend ) begin
                erow <= cur;
                pend <= 1;
                step <= 0;
            end
        end
        if( pend && !busy && !start ) begin
            start <= 1;
            rtm   <= step;
            row   <= step ? erow : 8'hff;
            if( step ) pend <= 0;
            step  <= 1;
        end
    end
end

endmodule
