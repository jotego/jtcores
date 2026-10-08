/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 9-2-2025 */

module jtframe_wait_on_shared(
    input             rst, clk,  
                      mreq,    sreq,
    output reg        mwait=0, swait=0
);

reg sbsy=0, mbsy;

always @(posedge clk)
    if(rst) begin
        mwait <= 0;
        swait <= 0;
        sbsy  <= 0;
    end else begin
        mwait <= sbsy & mreq;
        swait <= sreq & mreq & ~sbsy;
        if( !swait )
            sbsy <= sreq & ~mreq;
    end
endmodule