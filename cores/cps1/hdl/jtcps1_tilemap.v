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


// Scroll 1 is 512x512, 8x8 tiles
// Scroll 2 is 1024x1024 16x16 tiles
// Scroll 3 is 2048x2048 32x32 tiles

module jtcps1_tilemap(
    input              rst,
    input              clk,
    input              flip,

    input      [ 8:0]  vrender, // 1 line ahead of vdump
    input      [ 2:0]  size,    // hot one encoding. bit 0=8x8, bit 1=16x16, bit 2=32x32
    // control registers
    input      [15:0]  hpos,
    input      [15:0]  vpos,

    input              start,
    input              stop,
    output reg         done,

    // ROM banks
    input      [ 5:0]  game,
    input      [15:0]  bank_offset,
    input      [15:0]  bank_mask,

    output reg [ 7:0]  tile_addr,
    input      [15:0]  tile_data,


    output reg [19:0]  rom_addr,    // up to 1 MB
    output reg         rom_half,    // selects which half to read
    input      [31:0]  rom_data,
    output reg         rom_cs,
    input              rom_ok,

    output reg [ 8:0]  buf_addr,
    output reg [10:0]  buf_data,
    output reg         buf_wr
);

reg [10:0] vn;
reg [10:0] hn;
reg [31:0] pxl_data;

reg [ 5:0] st;

reg [15:0] code;

reg  [ 3:0] offset, mask;
reg         unmapped;

reg         rom_ok_dly;
wire        rom_ok_and;

wire [ 3:0] pre_offset1, pre_mask1;
wire [ 3:0] pre_offset2, pre_mask2;
wire [ 3:0] pre_offset3, pre_mask3;
wire        pre_unmapped1;
wire        pre_unmapped2;
wire        pre_unmapped3;

assign rom_ok_and = rom_ok & rom_ok_dly;

`ifdef SIMULATION
reg  [ 2:0] layer;
always @(*) begin
    case(size)
        3'b1:  begin
            layer  = 3'b001;
        end
        3'b10: begin
            layer  = 3'b010;
        end
        3'b100: begin
            layer  = 3'b011;
        end
        default: begin
            layer  = 3'b000;
        end
    endcase
end
`endif


`ifndef CPS2
    reg [9:0] mapper_in;

    jtcps1_gfx_mappers u_mapper1(
        .clk        ( clk             ),
        .rst        ( rst             ),
        .game       ( game            ),
        .bank_offset( bank_offset     ),
        .bank_mask  ( bank_mask       ),

        .layer      ( 3'd1            ),
        .cin        ( mapper_in       ),    // pins 2-9, 11,13,15,17,18

        .offset     ( pre_offset1     ),
        .mask       ( pre_mask1       ),
        .unmapped   ( pre_unmapped1   )
    );

    jtcps1_gfx_mappers u_mapper2(
        .clk        ( clk             ),
        .rst        ( rst             ),
        .game       ( game            ),
        .bank_offset( bank_offset     ),
        .bank_mask  ( bank_mask       ),

        .layer      ( 3'd2            ),
        .cin        ( mapper_in       ),    // pins 2-9, 11,13,15,17,18

        .offset     ( pre_offset2     ),
        .mask       ( pre_mask2       ),
        .unmapped   ( pre_unmapped2   )
    );

    jtcps1_gfx_mappers u_mapper3(
        .clk        ( clk             ),
        .rst        ( rst             ),
        .game       ( game            ),
        .bank_offset( bank_offset     ),
        .bank_mask  ( bank_mask       ),

        .layer      ( 3'd3            ),
        .cin        ( mapper_in       ),    // pins 2-9, 11,13,15,17,18

        .offset     ( pre_offset3     ),
        .mask       ( pre_mask3       ),
        .unmapped   ( pre_unmapped3   )
);
`else
    assign pre_offset1   = 4'd0;
    assign pre_offset2   = 4'd0;
    assign pre_offset3   = 4'd0;
    assign pre_mask1     = 4'hf;
    assign pre_mask2     = 4'hf;
    assign pre_mask3     = 4'hf;
    assign pre_unmapped1 = 1'b0;
    assign pre_unmapped2 = 1'b0;
    assign pre_unmapped3 = 1'b0;
`endif

reg  [1:0] group;
reg        vflip;
reg        hflip;
reg  [4:0] pal;

reg [19:0] rom_pre_addr, rom_masked_addr, rom_offset_addr;

always @(*) begin
    case (size)
        3'b001: rom_pre_addr = { 1'b0, code, vn[2:0] ^ {3{vflip}} };
        3'b010: rom_pre_addr = { code, vn[3:0] ^{4{vflip}} };
        default: rom_pre_addr = { code[13:0], vn[4:0] ^{5{vflip}}, hflip }; // 3'b100
    endcase
    rom_masked_addr = { mask, ~16'h0 } & rom_pre_addr;
    rom_offset_addr = { offset, 16'h0} | rom_masked_addr;
end


function [3:0] colour;
    input [31:0] c;
    input        flip;
    colour = flip ? { c[24], c[16], c[ 8], c[0] } :
                    { c[31], c[23], c[15], c[7] };
endfunction

// pixels in the blank area are not visible but it takes time to draw them
// so the start position is offset to avoid blanking
// wire [10:0] hn0  = size[0] ? 11'h38 : (size[1] ? 11'h30 : 11'h20 );
wire [ 8:0] buf0 = size[0] ?  9'h38 : (size[1] ?  9'h30 :  9'h20 );

always @(posedge clk or posedge rst) begin
    if(rst) begin
        rom_cs          <= 0;
        done            <= 0;
        st              <= 0;
        rom_addr        <= 0;
        rom_half        <= 0;
        code            <= 0;
        buf_addr        <= 0;
        buf_wr          <= 0;
        buf_data        <= 0;
        rom_ok_dly      <= 0;
    end else begin
        rom_ok_dly <= rom_ok;
        st <= st+6'd1;
        case( st )
            0: begin
                rom_cs   <= 1'b0;
                /* verilator lint_off WIDTH */
                vn       <= vpos[10:0] + {2'd0, vrender ^ { 1'b0, {8{flip}}} };
                /* verilator lint_on WIDTH */
                buf_addr <= buf0+9'h1ff- {4'd0,
                    size[0] ? {2'b0, hpos[2:0]} : (size[1] ? {1'b0,hpos[3:0]} : hpos[4:0]) };
                buf_wr    <= 1'b0;
                done      <= 1'b0;
                tile_addr <= size[0] ? 8'd0 : (size[1] ? (8'h80+{1'b0,hpos[9:4],1'b0}) : 8'd226 );
                if(!start) begin
                    st   <= 0;
                end
            end
            ///////////////////////
            1: tile_addr[0] <= 1'b1;
            2: begin
                `ifndef CPS2
                mapper_in    <= tile_data[15:6];
                `endif
                code         <= tile_data;
            end
            3: begin // attributes
                hflip   <= tile_data[5];
                group   <= tile_data[8:7];
                vflip   <= tile_data[6];
                pal     <= tile_data[4:0];
                st      <= 49;
            end
            50: begin
                offset   <= size==3'd1 ? pre_offset1   : ( size==3'd2 ? pre_offset2   : pre_offset3    );
                mask     <= size==3'd1 ? pre_mask1     : ( size==3'd2 ? pre_mask2     : pre_mask3      );
                unmapped <= size==3'd1 ? pre_unmapped1 : ( size==3'd2 ? pre_unmapped2 : pre_unmapped3  );
                st       <= 4;
            end
            4: begin
                rom_half <= hflip;
                rom_addr <= rom_offset_addr;
                rom_cs   <= 1'b1;
                tile_addr<= tile_addr+8'd1;
            end
            // 5: wait state
            6: if(rom_ok_and) begin
                pxl_data  <= rom_data;   // 32 bits = 32/4 = 8 pixels
                if(!size[0]) begin
                    rom_half <= ~rom_half; // not needed for scroll1
                end
                rom_cs <= 0;
            end else st<=6;
            7,8,9,10,    11,12,13,14,
            16,17,18,19, 20,21,22,23,
            25,26,27,28, 29,30,31,32,
            34,35,36,37, 38,39,40,41: begin
                if(!size[0]) rom_cs <= 1;
                buf_wr   <= 1'b1;
                buf_addr <= buf_addr+9'd1;
                buf_data <= { group, pal, unmapped ? 4'hf : colour(pxl_data, hflip) };
                pxl_data <= hflip ? pxl_data>>1 : pxl_data<<1;
            end
            15: begin
                buf_wr <= 1'b0;
                if( size[0] /*8*/) begin
                    st <= 6'd1; // scan again
                    rom_cs <= 0;
                end else if(rom_ok_and) begin
                    rom_cs <= 0;
                    pxl_data <= rom_data;
                    if(size[2] /*32*/) begin
                        rom_half    <= ~rom_half;
                        rom_addr[0] <= ~rom_addr[0];
                    end
                end else st<=st;
            end
            24: begin
                buf_wr <= 1'b0;
                if( size[1] /*16*/ ) begin
                    st <= 1; // scan again
                    rom_cs   <= 0;
                end else if(rom_ok_and) begin
                    rom_cs   <= 0;
                    pxl_data <= rom_data;
                    rom_half <= ~rom_half;
                end else st<=st;
            end
            33: begin
                if(rom_ok_and) begin
                    pxl_data <= rom_data;
                    rom_half <= ~rom_half;
                    rom_cs   <= 0;
                end else st<=st;
            end
            42: begin
                buf_wr <= 1'b0;
                rom_cs <= 1'b0;
                st     <= 6'd1; // 32x tile done
            end
        endcase
        if( stop || buf_addr == 9'd447 ) begin
            buf_addr<= 9'd0;
            buf_wr  <= 1'b0;
            done    <= 1'b1;
            st      <= 6'd0;
        end
    end
end

endmodule