/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 17-12-2022 */
/* verilator tracing_off */
module jtframe_edge #(parameter
    QSET=1,         // q value when set
    ATRST=~QSET[0]  // q value at rst event
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

    always @(posedge clk) begin
        if( rst ) begin
            q <= ATRST;
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

    always @(posedge clk) begin
        if( rst ) begin
            pulse <= INVERT[0];
            sigin_l <= 0;
        end else if(cen) begin
            sigin_l <= sigin;
            pulse <= (NEGEDGE==1 ? ~sigin & sigin_l : sigin & ~sigin_l)^INVERT[0];
        end
    end

endmodule
