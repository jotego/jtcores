/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-11-2021 */

module jtkicker_objdraw #(
    parameter       BYPASS_PROM= 0,
                    PACKED     = 0,
    parameter [7:0] HOFFSET    = 8'd6
) (
    input               rst,
    input               clk,        // 48 MHz

    input               pxl_cen,
    input               cen2,

    // video inputs
    input               hinit_x,
    input               LHBL,
    input         [8:0] hdump,

    // control
    input               draw,
    output reg          busy,

    // Object table data
    input         [7:0] xpos,
    input         [3:0] ysub,
    input         [3:0] pal,
    input               hflip,
    input               vflip,
    input         [8:0] code,

    // PROMs
    input         [3:0] prog_data,
    input         [7:0] prog_addr,
    input               prog_en,

    // SDRAM
    output reg   [13:0] rom_addr,
    input        [31:0] rom_data,
    output reg          rom_cs,
    input               rom_ok,

    output        [3:0] pxl,
    input         [7:0] debug_bus
);

wire [ 3:0] buf_in;
reg  [ 7:0] buf_a;
reg         buf_we;
wire [ 7:0] pal_addr;
wire [ 8:0] hread;

reg  [31:0] pxl_data;
reg  [ 2:0] cnt;

reg  [ 3:0] cur_pal;
reg         cur_hflip;

assign pal_addr = { cur_pal, pxl_data[3:0] };
assign hread    = hdump - {1'd0,HOFFSET};

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        busy     <= 0;
        rom_cs   <= 0;
        rom_addr <= 0;
        pxl_data <= 0;
        buf_we   <= 0;
        buf_a    <= 0;
        cnt      <= 0;
    end else if( cen2 ) begin
        if( draw && !busy ) begin
            rom_addr <= { code, ysub^{4{vflip}}, 1'b0 };
            rom_cs   <= 1;
            cnt      <= 7;
            buf_a    <= xpos + (hflip ? 8'd15 : 8'h0);
            busy     <= 1;
            cur_pal  <= pal;
            cur_hflip<= hflip;
        end
        if( busy && (!rom_cs || rom_ok) ) begin
            if( cnt==7 && rom_cs ) begin
                pxl_data <= PACKED ? rom_data : {
                    rom_data[27], rom_data[31], rom_data[19], rom_data[23],
                    rom_data[26], rom_data[30], rom_data[18], rom_data[22],
                    rom_data[25], rom_data[29], rom_data[17], rom_data[21],
                    rom_data[24], rom_data[28], rom_data[16], rom_data[20],
                    rom_data[11], rom_data[15], rom_data[ 3], rom_data[ 7],
                    rom_data[10], rom_data[14], rom_data[ 2], rom_data[ 6],
                    rom_data[ 9], rom_data[13], rom_data[ 1], rom_data[ 5],
                    rom_data[ 8], rom_data[12], rom_data[ 0], rom_data[ 4]
                };
                buf_we <= 1;
                rom_cs <= 0;
            end else begin
                pxl_data <= pxl_data>>4;
                buf_a    <= cur_hflip ? buf_a-8'd1 : buf_a+8'd1;
                cnt      <= cnt - 3'd1;
            end
            if( cnt==0 ) begin
                if( rom_addr[0] ) begin
                    buf_we <= 0;
                    busy   <= 0;
                    rom_cs <= 0;
                end else begin
                    rom_addr[0] <= 1;
                    rom_cs      <= 1;
                end
            end
        end
    end
end

wire buf_clr;

assign buf_clr = pxl_cen && hread < { 1'b1, HOFFSET };

reg [7:0] buf_al;
reg       buf_wel;

jtframe_obj_buffer #(.AW(8),.DW(4), .ALPHA(0)) u_buffer(
    .clk    ( clk       ),
    .LHBL   ( ~hinit_x  ),  // change buffer right before writting the new line
    .flip   ( 1'b0      ),
    // New data writes
    .wr_data( buf_in    ),
    .wr_addr( buf_al    ),
    .we     ( buf_wel   ),
    // Old data reads (and erases)
    .rd_addr( hread[7:0]),
    .rd     ( buf_clr   ),  // data will be erased after the rd event
    .rd_data( pxl       )
);

generate
    if( BYPASS_PROM ) begin
        assign buf_in = pal_addr[3:0];
        always @* begin
            buf_al = buf_a;
            buf_wel = buf_we;
        end
    end else begin
        always @(posedge clk) begin
            buf_al <= buf_a;
            buf_wel <= buf_we;
        end

        jtframe_prom #(
            .DW     ( 4         ),
            .AW     ( 8         )
        //    SIMFILE = "477j08.f16",
        ) u_palette(
            .clk    ( clk       ),
            .cen    ( 1'b1      ),
            .data   ( prog_data ),
            .wr_addr( prog_addr ),
            .we     ( prog_en   ),

            .rd_addr( pal_addr  ),
            .q      ( buf_in    )
        );
    end
endgenerate

endmodule