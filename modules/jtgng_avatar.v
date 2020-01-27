/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 12-11-2019 */

module jtgng_avatar #(parameter
    VERTICAL    = 1,   // 1 if the game is vertical, 0 otherwise
    DW          = 8,   // Most games are 8-bit wide, Bionic Commando is 12-bit wide
    AVATAR_MAX  = 4'd8
) (
    input               rst,
    input               clk,
    (* direct_enable *) input cen,
    input               LVBL,
    input               pause,
    output  reg [ 3:0]  avatar_idx,
    // output data
    input      [   8:0] pre_scan,
    input      [DW-1:0] dma_dout,
    output reg [DW-1:0] muxed_dout
);

// Avatar counter is used in both MiST and MiSTer

wire [ 7:0] avatar_id;
reg  [ 7:0] avatar_data;
reg  [ 9:0] avatar_cnt = 0;
wire [ 9:0] avatar_next = avatar_cnt+10'd1;
localparam CNTMAX = 10'd2*10'd60;

// Each avatar is made of 9 sprites, which are ordered one after the other in memory
// the sprite ID is calculated by combining the current Avatar on display and the
// position inside the object buffer, which is virtual during avatar display

// multiples avatar_idx by 9 = x8+1
// wire [7:0] avatar_idx9 = { 1'd0, avatar_idx, 3'd0 } + {4'd0, avatar_idx};
// 
// always @(posedge clk)
//     avatar_id <= pre_scan[5:2] > 4'd8 ? 8'h63 :
//         ( {4'd0, pre_scan[5:2]} + avatar_idx9 );

wire [3:0] id_next =avatar_idx + 4'd1;
reg lastLVBL;
always @(posedge clk, posedge rst) 
    if( rst ) begin
        avatar_idx <= 4'd0;
        avatar_cnt <= 10'd0;
    end else begin
        lastLVBL <= LVBL;
        if( !LVBL && lastLVBL ) begin
            `ifndef SIMULATION
            if(avatar_next==CNTMAX) begin
                avatar_cnt <= 10'd0;
                avatar_idx <= id_next==AVATAR_MAX ? 4'd0 : id_next;
            end else begin
                avatar_cnt<= avatar_next;
            end
            `else 
            avatar_idx <= id_next==AVATAR_MAX ? 4'd0 : id_next;
            `endif
        end
    end

`ifdef MISTER
    // Avatar data output is always defined for MiSTer
    `define AVATAR_DATA
`endif

`ifdef AVATAR_DATA
jtframe_ram #(.aw(8), .synfile("avatar_obj.hex"),.cen_rd(1))u_avatars(
    .clk    ( clk           ),
    .cen    ( pause         ),  // tiny power saving when not in pause
    .data   ( 8'd0          ),
    .addr   ( {avatar_idx, pre_scan[5:2] } ),
    .we     ( 1'b0          ),
    .q      ( avatar_id     )
);

reg [7:0] avatar_y, avatar_x;

localparam [7:0] Y0 = VERTICAL ? 8'h70 : 8'hb8;
localparam [7:0] X0 = VERTICAL ? 8'h08 : 8'h68;


always @(*) begin
    if(pre_scan[8:6]==3'd0) begin
        case( pre_scan[5:2] )
            4'd0,4'd1,4'd2: avatar_y = Y0;
            4'd3,4'd4,4'd5: avatar_y = Y0 + 8'h10;
            4'd6,4'd7,4'd8: avatar_y = Y0 + 8'h20;
            default: avatar_y <= 8'hf8;
        endcase
        case( pre_scan[5:2] )
            4'd0,4'd3,4'd6: avatar_x = X0;
            4'd1,4'd4,4'd7: avatar_x = X0 + 8'h10;
            4'd2,4'd5,4'd8: avatar_x = X0 + 8'h20;
            default: avatar_x = 8'hf8;
        endcase
    end
    else begin
        avatar_y = 8'hf8;
        avatar_x = 8'hf8;
    end
end

always @(*) begin
    case( pre_scan[1:0] )
        2'd0: avatar_data <= avatar_id; // pre_scan[8:6]==3'd0 ? avatar_id : 8'hff;
        2'd1: avatar_data <= 8'd0;
        // avatar_id code 8'hff means blank sprite
        2'd2: avatar_data <= avatar_id==8'hff ? 8'hf0 : avatar_y;
        2'd3: avatar_data <= avatar_id==8'hff ? 8'hff : avatar_x;
    endcase
end

always @(*) begin
    muxed_dout <= pause ? { {DW-8{1'b0}}, avatar_data} : dma_dout;
end

`else 
always @(*) begin
    muxed_dout = dma_dout;
end
`endif

endmodule