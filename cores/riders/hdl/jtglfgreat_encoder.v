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
    output reg        done,
    // SDRAM
    output     [19:1] psclo_addr,
    input      [15:0] psclo_data,
    input             psclo_ok,
    output reg        psclo_cs,

    output     [17:1] pschi_addr,
    input      [15:0] pschi_data,
    input             pschi_ok,
    output            pschi_cs,
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
reg         bank, search;
reg  [17:0] tile0,tile1,tile2,tile3;
//  Tile
//         X
//        0  1
//      ------
//  Y 0 | 0  1
//    1 | 2  3

// encoder
reg  [71:0] last_data;
reg  [12:0] top, last_addr;
reg  [ 1:0] search_st;
reg         deleted, found, full;

assign psclo_addr = {bank,y,x};
assign pschi_addr = {bank,y,x[8:2]};
assign t2x2_addr  = {bank,y[8:1],x[8:1]};
assign t2x2_din   = {3'd0,dec_addr};
assign dec_din    = tile2x2;
assign tile2x2    = {tile3,tile2,tile1,tile0};
assign pschi_cs   = psclo_cs;

reg  [17:0] combined;

always @* begin
    combined[15:0] = psclo_data;
    case(x[1:0])
        2'b00: combined[17:16] = pschi_data[0+:2];
        2'b01: combined[17:16] = pschi_data[2+:2];
        2'b10: combined[17:16] = pschi_data[4+:2];
        2'b11: combined[17:16] = pschi_data[6+:2];
    endcase
end

wire hilo_ok = psclo_ok & pschi_ok;

// Tilemap read time 2^19 * 8 clocks = 87.4 ms
always @(posedge clk) begin
    if( rst ) begin
        st       <= 0;
        x        <= 0;
        y        <= 0;
        bank     <= 0;
        done     <= 0;
        search   <= 0;
        psclo_cs <= 0;
        tile0    <= 0; tile1 <= 0; tile2 <= 0; tile3 <= 0;
    end else if(!done && deleted) begin
        t2x2_we <= 0;
        search  <= 0;
        case(st)
            0: begin {y[0],x[0]} <= 2'b00; psclo_cs <= 1; st <= 1; end
            1: if( hilo_ok ) begin tile0 <= combined; {y[0],x[0]} <= 2'b01; st <= 2; end
            2: if( hilo_ok ) begin tile1 <= combined; {y[0],x[0]} <= 2'b10; st <= 3; end
            3: if( hilo_ok ) begin tile2 <= combined; {y[0],x[0]} <= 2'b11; st <= 4; end
            4: if( hilo_ok ) begin tile3 <= combined; {y[0],x[0]} <= 2'b00; psclo_cs <= 0; search <= 1; st <= 5; end
            5: if( found ) begin
                t2x2_we <= 1;
                x[8:1] <= x[8:1]+1'd1;
                if(&x[8:1]) begin
                    {bank,y[8:1]} <= {bank,y[8:1]}+1'd1;
                    if(&{bank,y[8:1]}) begin
                        done    <= 1;
                        t2x2_we <= 0;
                        $display("Tilemap compression finished");
                    end
                end
                st <= 0;
            end
        endcase
    end
end

wire match = dec_dout==tile2x2;
wire match_last = top!=0 && last_data==dec_din;

`ifdef SIMULATION
wire matched = match & search;
wire matched_last = match && search && !found && search_st==0;
`endif

always @(posedge clk) begin
    if( rst ) begin
        found     <= 0;
        search_st <= 0;
        dec_addr  <= 0;
        top       <= 0;
        last_data <= 0;
        last_addr <= 0;
        full      <= 0;
        dec_we    <= 0;
        deleted   <= 0;
    end else begin
        if(!deleted) begin
            dec_we <= 1;
            if(dec_we) {deleted,dec_addr} <= {deleted,dec_addr}+1'd1;
        end else if(!full) begin
            found  <= 0;
            dec_we <= 0;
            case(search_st)
                0: if(search && !found) begin
                   dec_addr  <= 0;
                   search_st <= 1;
                   if( match_last ) begin
                       found <= 1;
                       dec_addr <= last_addr;
                   end
                end
                1: search_st <= 2;
                2: search_st <= 3;
                3: begin
                    if(match) begin
                        found <= 1;
                        last_data <= dec_din;
                        search_st <= 0;
                        last_addr <= dec_addr;
                    end else begin
                        dec_addr  <= dec_addr+1'd1;
                        search_st <= 1;
                        if(&dec_addr || dec_addr>top) begin
                            found    <= 1; // stored the new one
                            last_data <= dec_din;
                            dec_we   <= 1;
                            dec_addr <= top;
                            last_addr <= top;
                            if( !full ) begin
                                {full,top} <= {full,top}+1'd1;
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
