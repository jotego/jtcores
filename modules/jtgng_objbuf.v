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

parameter OBJMAX=10'h180;
parameter OBJMAX_LINE = 5'd24;

localparam LIMIT = 5'd31-OBJMAX_LINE;

// sprite buffer
reg          fill;
reg  [4:0]   post_scan;
reg          line_obj_we;

localparam lineA=1'b0, lineB=1'b1;
wire [7:0] q_a, q_b;
assign objbuf_data = line==lineA ? q_b : q_a;
wire [6:0] hscan = { objcnt, pxlcnt[1:0] };

reg trf_state;

always @(posedge clk) if(cen6) begin
    if( HINIT ) VF <= {8{flip}} ^ V;
end
//wire [7:0] VFx = (~(VF+8'd4))+8'd1;

localparam SEARCH=1'b0, TRANSFER=1'b1;

always @(posedge clk)
    if( rst )
        line <= lineA;
    else if(cen6) begin
        if( HINIT ) line <= ~line;
    end

reg pre_scan_msb;

always @(posedge clk)
    if( rst ) begin
        trf_state <= SEARCH;
        line_obj_we <= 1'b0;
    end
    else if(cen6) begin
        case( trf_state )
            SEARCH: begin
                line_obj_we <= 1'b0;
                if( !LVBL || fill ) begin
                    {pre_scan_msb, pre_scan} <= 10'd2;
                    post_scan<= 5'd31; // store obj data in reverse order
                    // so we can print them in straight order while taking
                    // advantage of horizontal blanking to avoid graphich clash
                    if(HINIT) fill <= 1'd0;
                end
                else begin
                    if( ram_dout<=(VF+'d3) && (ram_dout+8'd12)>=VF  ) begin
                        pre_scan[1:0] <= 2'd0;
                        line_obj_we <= 1'b1;
                        trf_state <= TRANSFER;
                    end
                    else begin
                        if( {pre_scan_msb,pre_scan}>=OBJMAX ) begin
                            fill <= 1'b1;
                        end else begin
                            {pre_scan_msb,pre_scan} <= {pre_scan_msb,pre_scan} + 10'd4;
                        end
                    end
                end
            end
            TRANSFER: begin
                // line_obj_we <= 1'b0;
                if( post_scan == LIMIT ) begin // Transfer done before the end of the line
                    line_obj_we <= 1'b0;
                    trf_state <= SEARCH;
                    fill <= 1'd1;
                end
                else
                if( pre_scan[1:0]==2'b11 ) begin
                    post_scan <= post_scan-1'b1;
                    pre_scan <= pre_scan + 9'd3;
                    trf_state  <= SEARCH;
                    line_obj_we <= 1'b0;
                end
                else begin
                    pre_scan[1:0] <= pre_scan[1:0]+1'b1;
                end
            end
        endcase
    end

reg [6:0] address_a, address_b;
reg we_a, we_b;
reg [7:0] data_a, data_b;

always @(*) begin
    if( line == lineA ) begin
        address_a = { post_scan, pre_scan[1:0] };
        address_b = hscan;
        data_a    = ram_dout;
        data_b    = 8'hf8;
        we_a      = line_obj_we;
        we_b      = 1'b1;
    end
    else begin
        address_a = hscan;
        address_b = { post_scan, pre_scan[1:0] };
        data_a    = 8'hf8;
        data_b    = ram_dout;
        we_a      = 1'b1;
        we_b      = line_obj_we;
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