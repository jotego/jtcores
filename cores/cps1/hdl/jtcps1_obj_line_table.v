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
    Date: 13-1-2020 */


module jtcps1_obj_line_table(
    input              rst,
    input              clk,
    input              flip,

    input      [ 8:0]  vrender, // 1 line ahead of vdump
    input              start,

    // ROM banks
    input      [ 5:0]  game,
    input      [15:0]  bank_offset,
    input      [15:0]  bank_mask,

    // interface with frame table
    output reg [ 9:0]  frame_addr,
    input      [15:0]  frame_data,

    // interface with renderer
    output reg         dr_start,
    input              dr_idle,

    output reg [15:0]  dr_code,
    output reg [15:0]  dr_attr,
    output reg [ 8:0]  dr_hpos
);

reg  [ 9:0] mapper_in;
reg  [ 8:0] vrenderf;

reg  [15:0] obj_code, obj_attr, obj_x, obj_y;
reg  [15:0] last_x, last_y, last_code, last_attr;
reg  [15:0] pre_code;
wire [15:0] eff_x;

wire  repeated = (obj_x==last_x) && (obj_y==last_y) &&
                 (obj_code==last_code) && (obj_attr==last_attr);

reg         first, done;
wire [ 3:0] tile_n, tile_m;
reg  [ 3:0] n, npos, m, mflip;  // tile expansion n==horizontal, m==verital
wire [ 3:0] vsub;
wire        inzone, vflip, inzone_lsb;
wire [15:0] match;
reg  [ 2:0] wait_cycle;
reg         last_tile;
wire [ 3:0] offset, mask;
wire [ 9:0] ext_y;
wire        unmapped;

assign      tile_m     = obj_attr[15:12];
assign      tile_n     = obj_attr[11: 8];
assign      vflip      = obj_attr[6];
wire        hflip      = obj_attr[5];
//          pal        = obj_attr[4:0];
assign      eff_x      = obj_x + { 8'b0, npos, 4'd0}; // effective x value for multi tile objects
`ifdef CPS2
    assign  ext_y      = obj_y[9:0];
`else
    assign  ext_y      = { obj_y[8], obj_y[8:0]};
`endif

wire [15:0] code_mn;
reg  [ 4:0] st;

jtcps1_gfx_mappers u_mapper(
    .clk        ( clk             ),
    .rst        ( rst             ),
    .game       ( game            ),
    .bank_offset( bank_offset     ),
    .bank_mask  ( bank_mask       ),

    .layer      ( 3'b0            ),
    .cin        ( mapper_in       ),    // pins 2-9, 11,13,15,17,18

    .offset     ( offset          ),
    .mask       ( mask            ),
    .unmapped   ( unmapped        )
);

jtcps1_obj_tile_match u_tile_match(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( 1'b1      ),

    .obj_code   ( obj_code  ),
    .tile_m     ( tile_m    ),
    .tile_n     ( tile_n    ),
    .n          ( n         ),

    .vflip      ( vflip     ),
    .vrenderf   ( vrenderf  ),
    .obj_y      ( ext_y     ),
    .vsub       ( vsub      ),
    .inzone     ( inzone    ),
    .code_mn    ( code_mn   )
);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        frame_addr <= ~10'd0;
        st         <= 0;
        done       <= 1'b0;
        first      <= 1'b1;
        obj_attr   <= 16'd0;
        obj_x      <= 16'd0;
        pre_code   <= 16'd0;
        obj_y      <= 16'd0;
        dr_start   <= 0;
        dr_code    <= 16'h0;
        dr_attr    <= 16'h0;
        dr_hpos    <=  9'd0;
    end else begin
        st <= st+5'd1;
        case( st )
            0: begin
                if( !start ) begin
                    st       <= 5'd0;
                    dr_start <= 0;
                end else begin
                    frame_addr <= 10'd0;
                    wait_cycle <= 3'b011;
                    last_tile  <= 1'b0;
                    done       <= 0;
                    first      <= 1'b1;
                    vrenderf   <= vrender ^ {1'b0,{8{flip}}};
                end
            end
            1: begin
                wait_cycle <= { 1'b0, wait_cycle[2:1] };
                frame_addr <= frame_addr-10'd1;
                if( !wait_cycle[0] ) begin
                    n          <= 4'd0;
                    // npos is the X offset of the tile. When the sprite is flipped
                    // npos order is reversed
                    npos       <= frame_data[5] /* flip */ ? frame_data[11: 8] /* tile_n */ : 4'd0;
                    last_attr  <= obj_attr;
                    obj_attr   <= frame_data;
                    wait_cycle <= 3'b011; // leave it ready for next round
                    //if( frame_data[15:8] == 8'hff ) st<=10; // end of valid table entries
                end else st<=1;
                if(last_tile) begin
                    st   <= 0; // done
                end
            end
            2: begin
                last_code  <= pre_code;
                pre_code   <= frame_data;
                mapper_in  <= frame_data[15:6];
                frame_addr <= frame_addr-10'd1;
            end
            3: begin
                last_y     <= obj_y;
                obj_y      <= frame_data;
                //frame_addr <= frame_addr-10'd1;
            end
            4: begin
                // Note that obj_code uses "offset", which was calculated with the
                // frame_data value of st 2, but because the mapper takes an extra
                // clock cycle to produce the output, the result is collected here
                last_x     <= obj_x;
                obj_x      <= { 7'd0, frame_data[8:0] };
                //frame_addr <= frame_addr-10'd1;
                if( frame_addr[9:2]==8'd0 ) last_tile <= 1'b1;
                st <= 5;
            end
            5: begin
                obj_code   <= { (pre_code[15:12]&mask) | offset, pre_code[11:0] };
                if( unmapped  || (pre_code[15:12]&~mask)!=0 )
                    st <= 1; // skip
            end
            6: begin // check whether sprite is visible
                if( (repeated && !first ) || !inzone ) begin
                    st<= 1; // try next one
                end
                else begin
                    first <= 1'b0;
                end
            end
            7: begin
                // 7: line_buf[ {vrenderf[0], line_cnt, 2'd1} ] <= code_mn;
                // 8: line_buf[ {vrenderf[0], line_cnt, 2'd2} ] <= eff_x;
                if( !dr_idle ) begin
                    st <= 7;
                end else begin
                    dr_attr <= { 4'd0, vsub, obj_attr[7:0] };
                    dr_code <= code_mn;
                    dr_hpos <= eff_x[8:0] - 9'd1;
                    dr_start <= 1;
                end
            end
            8: begin
                dr_start <= 0;
            end
            9: begin
                /*if( line_cnt==7'h7f ) begin
                    st   <= 0; // line full
                    done <= 1;
                end else begin*/
                    //if( eff_x>9'h30 && eff_x<9'd448) line_cnt <= line_cnt+7'd1;
                    if( n == tile_n ) begin
                        st <= 1; // next element
                    end else begin // prepare for next tile
                        n <= n + 4'd1;
                        npos <= hflip ? npos-4'd1 : npos+4'd1;
                        st <= 7;
                    end
                //end
            end
        endcase
    end
end

endmodule
