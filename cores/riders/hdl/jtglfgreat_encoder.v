/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR addr PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 21-8-2025 */

module jtglfgreat_encoder(
    input             clk, rst,
    // SDRAM
    output     [20:2] pscmap_addr,
    input      [31:0] pscmap_data,
    input             pscmap_ok,
    output reg        pscmap_cs,
    // Compressed tilemap in VRAM
    output     [17:1] t2x2_addr,
    output     [15:0] t2x2_din,
    output reg        t2x2_we,
    // Decoder
    output reg [12:0] dec_addr,
    input      [71:0] dec_dout,
    output     [71:0] dec_din,
    output reg        dec_we
);

// tilemap reader
reg  [ 8:0] y, x;
reg  [ 3:0] st;
wire [71:0] tile2x2;
reg         bank, done, search;
reg  [17:0] tile0,tile1,tile2,tile3;
//  Tile
//         X
//        0  1
//      ------
//  Y 0 | 0  1
//    1 | 2  3

// encoder
reg  [12:0] last;
reg  [ 1:0] search_st;
reg         deleted, found, full;

assign pscmap_addr = {bank,y,x};
assign t2x2_addr   = {bank,y[8:1],y[8:1]};
assign t2x2_din    = {3'd0,dec_addr};
assign dec_din     = tile2x2;
assign tile2x2     = {tile3,tile2,tile1,tile0};

function [17:0] extract(input [31:0]a);
    extract[15:0] = a[15:0];
    case({y[0],x[0]})
        2'b00: extract[17:16] = a[16+:2];
        2'b01: extract[17:16] = a[18+:2];
        2'b10: extract[17:16] = a[20+:2];
        2'b11: extract[17:16] = a[22+:2];
    endcase
endfunction

// Tilemap read time 2^19 * 8 clocks = 87.4 ms
always @(posedge clk) begin
    if( rst ) begin
        st        <= 0;
        x         <= 0;
        y         <= 0;
        bank      <= 0;
        done      <= 0;
        search    <= 1;
        pscmap_cs <= 0;
        tile0     <= 0; tile1 <= 0; tile2 <= 0; tile3 <= 0;
    end else if(!done && deleted) begin
        t2x2_we <= 0;
        case(st)
            0: begin pscmap_cs <= 1; st <= 1; end
            1: if( pscmap_ok ) begin tile0 <= extract(pscmap_data); {y[0],x[0]}  <= 2'b01;  st <= 2; end
            2: if( pscmap_ok ) begin tile1 <= extract(pscmap_data); {y[0],x[0]}  <= 2'b11;  st <= 3; end
            3: if( pscmap_ok ) begin tile3 <= extract(pscmap_data); {y[0],x[0]}  <= 2'b10;  st <= 4; end
            4: if( pscmap_ok ) begin tile2 <= extract(pscmap_data); {y[0],x[0]}  <= 2'b00;  pscmap_cs<= 0; st <= 5; end
            5: begin search <= 1; st <= 6; end
            6: if( found ) begin
                t2x2_we <= 1;
                x[8:1] <= x[8:1]+1'd1;
                if(&x[8:1]) begin
                    {bank,y[8:1]} <= {bank,y[8:1]}+1'd1;
                    if(&{bank,y[8:1]}) begin
                        done <= 1;
                        $display("Tilemap compression finished");
                    end
                    t2x2_we <= 0;
                end
                search <= 0;
                st <= 0;
            end
        endcase
    end
end

wire match = dec_dout==tile2x2;

always @(posedge clk) begin
    if( rst ) begin
        found     <= 0;
        search_st <= 0;
        dec_addr  <= 0;
        last      <= 0;
        full      <= 0;
        dec_we    <= 0;
        deleted   <= 0;
    end else begin
        if(!deleted) begin
            dec_we <= 1;
            if(dec_we) {deleted,dec_addr} <= {deleted,dec_addr}+1'd1;
        end else begin
            found  <= 0;
            dec_we <= 0;
            case(search_st)
                0: if(search && !found) begin
                   dec_addr  <= 0;
                   search_st <= 1;
                end
                1: search_st <= 2;
                2: search_st <= 3;
                3: begin
                    if(match) begin
                        found <= 1;
                        search_st <= 0;
                    end else begin
                        dec_addr  <= dec_addr+1'd1;
                        search_st <= 1;
                        if(&dec_addr) begin
                            found    <= 1; // stored the new one
                            dec_we   <= 1;
                            dec_addr <= last;
                            if( !full ) begin
                                {full,last} <= {full,last}+1'd1;
                                search_st <= 0;
                            end
                        end
                    end
                end
            endcase
        end
    end
end

endmodule
