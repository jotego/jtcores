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
    Date: 11-1-2019 */

module jtgng_objbuf(
    input               rst,
    input               clk,     // 24 MHz
    input               cen6,    //  6 MHz
    // screen
    input               HINIT,
    input               LVBL,
    input       [7:0]   V,
    output reg  [7:0]   VF,
    input               flip,
    // sprite data scan
    output reg  [8:0]   pre_scan,
    input       [7:0]   ram_dout,
    // sprite data buffer
    output      [7:0]   objbuf_data,
    input       [4:0]   objcnt,
    input       [3:0]   pxlcnt,
    output reg          line
);

// sprite buffer
reg          fill;
reg  [4:0]   post_scan;
reg          line_obj_we;

localparam lineA=1'b0, lineB=1'b1;
wire [7:0] q_a, q_b;
assign objbuf_data = line==lineA ? q_b : q_a;
wire [6:0] hscan = { objcnt, pxlcnt[1:0] };

reg [1:0] trf_state, trf_next;

always @(posedge clk) if(cen6) begin
    if( HINIT ) VF <= {8{flip}} ^ V;
end
//wire [7:0] VFx = (~(VF+8'd4))+8'd1;

localparam SEARCH=2'd1, WAIT=2'd2, TRANSFER=2'd3, FILL=2'd0;

always @(posedge clk)
    if( rst )
        line <= lineA;
    else if(cen6) begin
        if( HINIT ) line <= ~line;
    end


always @(posedge clk)
    if( rst ) begin
        trf_state <= SEARCH;
        line_obj_we <= 1'b0;
    end
    else if(cen6) begin
        case( trf_state )
            SEARCH: begin
                if( !LVBL ) begin
                    pre_scan <= 9'd2;
                    post_scan<= 5'd31; // store obj data in reverse order
                    // so we can print them in straight order while taking
                    // advantage of horizontal blanking to avoid graphich clash
                    fill <= 1'd0;
                end
                else begin
                    line_obj_we <= 1'b0;
                    if( ram_dout<=(VF+'d3) && (ram_dout+8'd12)>=VF  ) begin
                        pre_scan[1:0] <= 2'd0;
                        trf_next  <= TRANSFER;
                        trf_state <= WAIT;
                    end
                    else begin
                        if( pre_scan>=9'h17E ) begin
                            trf_next  <= FILL;
                            trf_state <= WAIT;
                            pre_scan <= 9'h180;
                            fill <= 1'b1;
                        end else begin
                            pre_scan <= pre_scan + 9'd4;
                            trf_state <= WAIT;
                            trf_next  <= SEARCH;
                        end
                    end
                end
            end
            WAIT: begin
                trf_state <= trf_next;
                if( trf_next==TRANSFER || trf_next==FILL ) line_obj_we <= 1'b1;
            end
            TRANSFER: begin
                line_obj_we <= 1'b0;
                if( post_scan == 5'h07 ) begin // Transfer done before the end of the line
                    if( HINIT ) begin
                        trf_state <= SEARCH;
                        pre_scan <= 9'd2;
                        post_scan <= 5'd31;
                        fill <= 1'd0;
                    end
                end
                else
                if( pre_scan[1:0]==2'b11 ) begin
                    post_scan <= post_scan-1'b1;
                    pre_scan <= pre_scan + 9'd3;
                    trf_state <= WAIT;
                    trf_next  <= SEARCH;
                end
                else begin
                    pre_scan[1:0] <= pre_scan[1:0]+1'b1;
                    trf_state <= WAIT;
                end
            end
            FILL: begin
                trf_state <= WAIT;
                if( &pre_scan[1:0] && post_scan==5'd8 ) begin
                    post_scan<= 5'd31;
                    pre_scan <= 9'd2;
                    trf_next <= SEARCH;
                    line_obj_we <= 1'b0;
                    fill <= 1'd0;
                end
                else begin
                    if( pre_scan[1:0]==2'b11 ) post_scan <= post_scan - 1'b1;
                    pre_scan <= pre_scan + 1'b1;
                    trf_next <= FILL;
                    line_obj_we <= 1'b0;
                end
            end
        endcase
    end

reg [6:0] address_a, address_b;
reg we_a, we_b;
reg [7:0] data_a, data_b;

always @(*) begin
    data_a = fill ? 8'hf8 : ram_dout;
    data_b = fill ? 8'hf8 : ram_dout;
    if( line == lineA ) begin
        address_a = { post_scan, pre_scan[1:0] };
        address_b = hscan;
        we_a = line_obj_we;
        we_b = 1'b0;
    end
    else begin
        address_a = hscan;
        address_b = { post_scan, pre_scan[1:0] };
        we_a = 1'b0;
        we_b = line_obj_we;
    end
end

jtgng_ram #(.aw(7),.simfile("obj_buf.hex")) objbuf_a(
    .clk   ( clk       ),
    .cen   ( cen6      ),
    .addr  ( address_a ),
    .data  ( data_a    ),
    .we    ( we_a      ),
    .q     ( q_a       )
);

jtgng_ram #(.aw(7),.simfile("obj_buf.hex")) objbuf_b(
    .clk   ( clk       ),
    .cen   ( cen6      ),
    .addr  ( address_b ),
    .data  ( data_b    ),
    .we    ( we_b      ),
    .q     ( q_b       )
);


endmodule // jtgng_objbuf