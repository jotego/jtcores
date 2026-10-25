/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps
module jt74161( // ref: 74??161
    input            cet,   // pin: 10
    input            cep,   // pin: 7
    input            ld_b,  // pin: 9
    input            clk,   // pin: 2
    input            cl_b,  // pin: 1
    input      [3:0] d,     // pin: 6,5,4,3
    output     [3:0] q,     // pin: 11,12,13,14
    output           ca,    // pin: 15
    input            VDD,   // pin: 16
    input            VSS    // pin: 8
 );

    assign ca = &{q, cet};

    reg [3:0] qq=0;
    assign #30 q = qq;
    always @(posedge clk or negedge cl_b)
        if( !cl_b )
            qq <= 4'd0;
        else begin
            if(!ld_b) qq <= d;
            else if( cep&&cet ) qq <= qq+4'd1;
        end

endmodule
module jt74138( // ref: 74??138
    input        e1_b,  // pin: 4
    input        e2_b,	// pin: 5
    input        e3,    // pin: 6
    input  [2:0] a,     // pin: 3,2,1
    output [7:0] y_b,   // pin: 7,9,10,11,12,13,14,15
    input        VDD,   // pin: 16
    input        VSS    // pin: 8
);
    reg [7:0] yb_nodly;
    always @(*)
        if( e1_b || e2_b || !e3 )
            yb_nodly <= 8'hff;
        else yb_nodly = ~ ( 8'b1 << a );
    assign #30 y_b = yb_nodly;
endmodule
