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

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 19-07-2024 */

// Module for assigning controller signals in the order they are used
module jtframe_pocket_ctrlmux(
    input             rst,
    input             clk,
    // Pocket buttons and USB controllers
    input      [15:0] cont1,
    input      [15:0] cont2,
    input      [15:0] cont3,
    input      [15:0] cont4,
    // SNAC controllers
    input      [15:0] snac1,
    input      [15:0] snac2,
    input      [15:0] snac3,
    input      [15:0] snac4,
    // Assigned controllers output
    output reg [15:0] plyr1,
    output reg [15:0] plyr2,
    output reg [15:0] plyr3,
    output reg [15:0] plyr4,
    // Debug
    input      [ 7:0] debug_bus
    // output     [ 7:0] debug_show
);

localparam [2:0] CONT1 = 3'd0;
localparam [2:0] CONT2 = 3'd1;
localparam [2:0] CONT3 = 3'd2;
localparam [2:0] CONT4 = 3'd3;
localparam [2:0] SNAC1 = 3'd4;
localparam [2:0] SNAC2 = 3'd5;
localparam [2:0] SNAC3 = 3'd6;
localparam [2:0] SNAC4 = 3'd7;

reg   [2:0] act_p1, act_p2, act_p3, act_p4;
reg   [3:0] paired;
reg         cont1_set, cont2_set, cont3_set, cont4_set,
            snac1_set, snac2_set, snac3_set, snac4_set;

always @( posedge clk or posedge rst) begin
    if( rst) begin
        {act_p1, act_p2, act_p3, act_p4} <= 12'b0;
        {cont1_set, cont2_set, cont3_set, cont4_set} <= 4'b0;
        {snac1_set, snac2_set, snac3_set, snac4_set} <= 4'b0;
        paired   <= 4'b0;
    end else begin
        if( cont1[4] && !cont1_set ) begin
            if(!paired[0] )      begin act_p1 <= CONT1; cont1_set <= 1; paired[0] <= 1; end
            else if(!paired[1] ) begin act_p2 <= CONT1; cont1_set <= 1; paired[1] <= 1; end
            else if(!paired[2] ) begin act_p3 <= CONT1; cont1_set <= 1; paired[2] <= 1; end
            else if(!paired[3] ) begin act_p4 <= CONT1; cont1_set <= 1; paired[3] <= 1; end
        end

        if( cont2[4] && !cont2_set ) begin
            if(!paired[0] )      begin act_p1 <= CONT2; cont2_set <= 1; paired[0] <= 1; end
            else if(!paired[1] ) begin act_p2 <= CONT2; cont2_set <= 1; paired[1] <= 1; end
            else if(!paired[2] ) begin act_p3 <= CONT2; cont2_set <= 1; paired[2] <= 1; end
            else if(!paired[3] ) begin act_p4 <= CONT2; cont2_set <= 1; paired[3] <= 1; end
        end

        if( cont3[4] && !cont3_set ) begin
            if(!paired[0] )      begin act_p1 <= CONT3; cont3_set <= 1; paired[0] <= 1; end
            else if(!paired[1] ) begin act_p2 <= CONT3; cont3_set <= 1; paired[1] <= 1; end
            else if(!paired[2] ) begin act_p3 <= CONT3; cont3_set <= 1; paired[2] <= 1; end
            else if(!paired[3] ) begin act_p4 <= CONT3; cont3_set <= 1; paired[3] <= 1; end
        end

        if( cont4[4] && !cont4_set ) begin
            if(!paired[0] )      begin act_p1 <= CONT4; cont4_set <= 1; paired[0] <= 1; end
            else if(!paired[1] ) begin act_p2 <= CONT4; cont4_set <= 1; paired[1] <= 1; end
            else if(!paired[2] ) begin act_p3 <= CONT4; cont4_set <= 1; paired[2] <= 1; end
            else if(!paired[3] ) begin act_p4 <= CONT4; cont4_set <= 1; paired[3] <= 1; end
        end

        if( snac1[4] && !snac1_set ) begin
            if( !paired[0] )      begin act_p1 <= SNAC1; snac1_set <= 1; paired[0] <= 1; end
            else if(!paired[1] ) begin act_p2 <= SNAC1; snac1_set <= 1; paired[1] <= 1; end
            else if(!paired[2] ) begin act_p3 <= SNAC1; snac1_set <= 1; paired[2] <= 1; end
            else if(!paired[3] ) begin act_p4 <= SNAC1; snac1_set <= 1; paired[3] <= 1; end
        end

        if( snac2[4] && !snac2_set ) begin
            if(!paired[0] )      begin act_p1 <= SNAC2; snac2_set <= 1; paired[0] <= 1; end
            else if(!paired[1] ) begin act_p2 <= SNAC2; snac2_set <= 1; paired[1] <= 1; end
            else if(!paired[2] ) begin act_p3 <= SNAC2; snac2_set <= 1; paired[2] <= 1; end
            else if(!paired[3] ) begin act_p4 <= SNAC2; snac2_set <= 1; paired[3] <= 1; end
        end

        if( snac3[4] && !snac3_set ) begin
            if(!paired[0] )      begin act_p1 <= SNAC3; snac3_set <= 1; paired[0] <= 1; end
            else if(!paired[1] ) begin act_p2 <= SNAC3; snac3_set <= 1; paired[1] <= 1; end
            else if(!paired[2] ) begin act_p3 <= SNAC3; snac3_set <= 1; paired[2] <= 1; end
            else if(!paired[3] ) begin act_p4 <= SNAC3; snac3_set <= 1; paired[3] <= 1; end
        end

        if( snac4[4] && !snac4_set ) begin
            if(!paired[0] )      begin act_p1 <= SNAC4; snac4_set <= 1; paired[0] <= 1; end
            else if(!paired[1] ) begin act_p2 <= SNAC4; snac4_set <= 1; paired[1] <= 1; end
            else if(!paired[2] ) begin act_p3 <= SNAC4; snac4_set <= 1; paired[2] <= 1; end
            else if(!paired[3] ) begin act_p4 <= SNAC4; snac4_set <= 1; paired[3] <= 1; end
        end
    end
end

function [15:0] controller( input [15:0] c1, input [15:0] c2, input [15:0] c3, input [15:0] c4,
                            input [15:0] c5, input [15:0] c6, input [15:0] c7, input [15:0] c8,
                            input [ 2:0] act );
    case ( act )
        CONT1: controller = c1;
        CONT2: controller = c2;
        CONT3: controller = c3;
        CONT4: controller = c4;
        SNAC1: controller = c5;
        SNAC2: controller = c6;
        SNAC3: controller = c7;
        SNAC4: controller = c8;
        default : controller = 16'b0;
    endcase
endfunction

always @( posedge clk ) begin

    plyr1 <= controller( cont1, cont2, cont3, cont4, snac1, snac2, snac3, snac4, act_p1 );
    plyr2 <= controller( cont1, cont2, cont3, cont4, snac1, snac2, snac3, snac4, act_p2 );
    plyr3 <= controller( cont1, cont2, cont3, cont4, snac1, snac2, snac3, snac4, act_p3 );
    plyr4 <= controller( cont1, cont2, cont3, cont4, snac1, snac2, snac3, snac4, act_p4 );

    if( !paired[1] ) plyr2 <= 16'b0;
    if( !paired[2] ) plyr3 <= 16'b0;
    if( !paired[3] ) plyr4 <= 16'b0;
end

endmodule 