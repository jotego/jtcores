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
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 2.2
    Date: 16-4-2026 */

module jtframe_cache_data #(parameter
    DW     = 8,
    ENDIAN = 0,
    AW0    = 0,
    ADDRW  = 8
)(
    input                   clk,
    input      [ADDRW-1:0]  req_addr,
    input      [15:0]       req_we,
    input      [127:0]      req_wdata,
    output     [127:0]      req_q,
    input      [ADDRW-1:0]  stream_addr,
    input      [15:0]       stream_we,
    input      [127:0]      stream_wdata,
    output     [127:0]      stream_q
);

localparam integer RAM32_AW     = ADDRW - AW0 + 2;
localparam integer RAM16_AW     = ADDRW - 1;
localparam integer RAM32_ENDIAN = DW == 32 ? ENDIAN : 0;

wire [15:0] req_q16, stream_q16;
wire [31:0] req_q0, req_q1, req_q2, req_q3;
wire [31:0] stream_q0, stream_q1, stream_q2, stream_q3;
wire [RAM32_AW-1:2] req_ram32_addr    = req_addr[ADDRW-1:AW0];
wire [RAM32_AW-1:2] stream_ram32_addr = stream_addr[ADDRW-1:AW0];
wire [RAM16_AW:1]   req_ram16_addr    = req_addr[ADDRW-1:1];
wire [RAM16_AW:1]   stream_ram16_addr = stream_addr[ADDRW-1:1];

assign req_q    = DW < 32 ? { 112'd0, req_q16 } :
                  { req_q3, req_q2, req_q1, req_q0 };
assign stream_q = DW < 32 ? { 112'd0, stream_q16 } :
                  { stream_q3, stream_q2, stream_q1, stream_q0 };

generate
if( DW >= 32 ) begin : g_data_ram32
    assign req_q16    = 16'd0;
    assign stream_q16 = 16'd0;
    jtframe_dual_ram32 #(
        .AW    ( RAM32_AW     ),
        .ENDIAN( RAM32_ENDIAN )
    ) u_data_ram0 (
        .clk0 ( clk                ),
        .data0( req_wdata[31:0]    ),
        .addr0( req_ram32_addr     ),
        .we0  ( req_we[3:0]        ),
        .q0   ( req_q0             ),
        .clk1 ( clk                ),
        .data1( stream_wdata[31:0] ),
        .addr1( stream_ram32_addr  ),
        .we1  ( stream_we[3:0]     ),
        .q1   ( stream_q0          )
    );
    if( DW >= 64 ) begin : g_data_ram64
        jtframe_dual_ram32 #(
            .AW    ( RAM32_AW ),
            .ENDIAN( 0        )
        ) u_data_ram1 (
            .clk0 ( clk                 ),
            .data0( req_wdata[63:32]    ),
            .addr0( req_ram32_addr      ),
            .we0  ( req_we[7:4]         ),
            .q0   ( req_q1              ),
            .clk1 ( clk                 ),
            .data1( stream_wdata[63:32] ),
            .addr1( stream_ram32_addr   ),
            .we1  ( stream_we[7:4]      ),
            .q1   ( stream_q1           )
        );
    end else begin : g_data_ram64_unused
        assign req_q1    = 32'd0;
        assign stream_q1 = 32'd0;
    end
    if( DW >= 128 ) begin : g_data_ram128
        jtframe_dual_ram32 #(
            .AW    ( RAM32_AW ),
            .ENDIAN( 0        )
        ) u_data_ram2 (
            .clk0 ( clk                 ),
            .data0( req_wdata[95:64]    ),
            .addr0( req_ram32_addr      ),
            .we0  ( req_we[11:8]        ),
            .q0   ( req_q2              ),
            .clk1 ( clk                 ),
            .data1( stream_wdata[95:64] ),
            .addr1( stream_ram32_addr   ),
            .we1  ( stream_we[11:8]     ),
            .q1   ( stream_q2           )
        );
        jtframe_dual_ram32 #(
            .AW    ( RAM32_AW ),
            .ENDIAN( 0        )
        ) u_data_ram3 (
            .clk0 ( clk                  ),
            .data0( req_wdata[127:96]    ),
            .addr0( req_ram32_addr       ),
            .we0  ( req_we[15:12]        ),
            .q0   ( req_q3               ),
            .clk1 ( clk                  ),
            .data1( stream_wdata[127:96] ),
            .addr1( stream_ram32_addr    ),
            .we1  ( stream_we[15:12]     ),
            .q1   ( stream_q3            )
        );
    end else begin : g_data_ram128_unused
        assign req_q2    = 32'd0;
        assign req_q3    = 32'd0;
        assign stream_q2 = 32'd0;
        assign stream_q3 = 32'd0;
    end
end else begin : g_data_ram16
    jtframe_dual_ram16 #(
        .AW    ( RAM16_AW ),
        .ENDIAN( 0        )
    ) u_data_ram (
        .clk0 ( clk                 ),
        .data0( req_wdata[15:0]     ),
        .addr0( req_ram16_addr      ),
        .we0  ( req_we[1:0]         ),
        .q0   ( req_q16             ),
        .clk1 ( clk                 ),
        .data1( stream_wdata[15:0]  ),
        .addr1( stream_ram16_addr   ),
        .we1  ( stream_we[1:0]      ),
        .q1   ( stream_q16          )
    );
    assign req_q0    = 32'd0;
    assign req_q1    = 32'd0;
    assign req_q2    = 32'd0;
    assign req_q3    = 32'd0;
    assign stream_q0 = 32'd0;
    assign stream_q1 = 32'd0;
    assign stream_q2 = 32'd0;
    assign stream_q3 = 32'd0;
end
endgenerate

endmodule
