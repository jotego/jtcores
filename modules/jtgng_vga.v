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
    Date: 27-10-2017 */

`timescale 1ns/1ps

module jtgng_vga(
    input               clk_rgb,    // 24MHz
    input               cen6,
    input               clk_vga,    // 25MHz
    input               rst,
    input   [3:0]       red,
    input   [3:0]       green,
    input   [3:0]       blue,
    input               LHBL,
    input               LVBL,
    input               en_mixing,
    output  reg [4:0]   vga_red,
    output  reg [4:0]   vga_green,
    output  reg [4:0]   vga_blue,
    output  reg         vga_hsync,
    output  reg         vga_vsync
);

reg [7:0] wr_addr, rd_addr;
reg wr_sel, rd_sel;
reg double;

wire [11:0] buf0_rgb, buf1_rgb;
wire [14:0] dbl0_rgb, dbl1_rgb;

reg scanline;

jtgng_vgapxl u_pxl0( // pixel doubler
    .clk    ( clk_vga   ),
    .double (  double   ),
    .en_mix ( en_mixing ),
    .rgb_in ( buf0_rgb  ),
    .rgb_out( dbl0_rgb  )
);

jtgng_vgapxl u_pxl1( // pixel doubler
    .clk    ( clk_vga   ),
    .double (  double   ),
    .en_mix ( en_mixing ),
    .rgb_in ( buf1_rgb  ),
    .rgb_out( dbl1_rgb  )
);

function [4:0] avg; // Average of two 5-bit numbers
    input [4:0] a;
    input [4:0] b;
    reg [5:0] sum;
    begin
        sum = { 1'b0, a } + {1'b0,b};
        avg = sum[5:1];
    end
endfunction

always @(posedge clk_vga) begin
    if( !scanline || !en_mixing)
        {vga_red, vga_green,vga_blue} <= !rd_sel ? dbl1_rgb : dbl0_rgb;
    else begin // mix the two lines
        vga_red  <= avg( dbl1_rgb[14:10], dbl0_rgb[14:10]);
        vga_green<= avg( dbl1_rgb[ 9:5 ], dbl0_rgb[ 9:5 ]);
        vga_blue <= avg( dbl1_rgb[ 4:0 ], dbl0_rgb[ 4:0 ]);
    end
end

reg LHBL_vga, last_LHBL_vga;

// wr_sel is gated with LBHL just to prevent overwritting the address zero
jtgng_dual_clk_ram #(.dw(12),.aw(8)) ram0 (
    .addr_a  ( wr_addr            ),
    .addr_b  ( rd_addr            ),
    .clka    ( clk_rgb            ),
    .clka_en ( cen6               ),
    .clkb    ( clk_vga            ),
    .clkb_en ( 1'b1               ),
    .data_a  ( {red,green,blue}   ),
    .data_b  ( 12'd0              ), // unused
    .we_a    ( wr_sel&&LHBL_vga   ),
    .we_b    ( 1'b0               ),
    .q_b     ( buf0_rgb           ),
    .q_a     (                    )
);

jtgng_dual_clk_ram #(.dw(12),.aw(8)) ram1 (
    .addr_a  ( wr_addr            ),
    .addr_b  ( rd_addr            ),
    .clka    ( clk_rgb            ),
    .clka_en ( cen6               ),
    .clkb    ( clk_vga            ),
    .clkb_en ( 1'b1               ),
    .data_a  ( {red,green,blue}   ),
    .data_b  ( 12'd0              ), // unused
    .we_a    ( !wr_sel && LHBL_vga),
    .we_b    ( 1'b0               ),
    .q_b     ( buf1_rgb           ),
    .q_a     (                    )
);


reg last_LHBL;

always @(posedge clk_rgb)
    if( rst ) begin
        wr_addr <= 8'd0;
        wr_sel <= 1'b0;
    end else begin
        last_LHBL <= LHBL;
        if( !LHBL ) begin
            wr_addr <= 8'd0;
            if( last_LHBL!=LHBL ) wr_sel <= ~wr_sel;
        end else
            if(cen6) wr_addr <= wr_addr + 1'b1;
    end

reg LVBL_vga, last_LVBL_vga;
reg vsync_req;
reg wait_hsync;

always @(posedge clk_vga) begin
    LHBL_vga <= LHBL;
    last_LHBL_vga <= LHBL_vga;

    LVBL_vga <= LVBL;
    last_LVBL_vga <= LVBL_vga;

    vsync_req <= !vga_vsync ? 1'b0 : vsync_req || (!LVBL_vga && last_LVBL_vga);
end

reg [6:0] cnt;
reg [1:0] state;
reg centre_done, finish;
reg vsync_cnt;

reg rd_sel_aux;

localparam SYNC=2'd0, FRONT=2'd1, LINE=2'd2, BACK=2'd3;

always @(posedge clk_vga) begin
    if( rst ) begin
        rd_addr <= 8'd0;
        state <= SYNC;
        cnt <= 7'd96;
        centre_done <= 1'b0;
        wait_hsync  <= 1'b0;
        vsync_cnt   <= 1'b0;
        vga_vsync   <= 1'b1;
        vga_hsync   <= 1'b1;
        rd_sel_aux  <= 1'b0;
        rd_sel      <= 1'b0;
        scanline    <= 1'b0;
    end
    else
    case( state )
        SYNC: begin
            rd_addr <= 8'd0;
            vga_hsync <= 1'b0;
            if( vsync_req ) begin
                vga_vsync <= 1'b0;
                vsync_cnt <= 1'b0;
            end
            cnt <= cnt - 1'b1;
            if( wait_hsync && (LHBL_vga && !last_LHBL_vga) ||
               !wait_hsync && cnt==7'd0 ) begin
                state<=FRONT;
                cnt  <=7'd16;
                wait_hsync <= ~wait_hsync;
                rd_sel_aux <= ~rd_sel_aux;
                if( rd_sel_aux ) rd_sel <= ~rd_sel;
            end
        end
        FRONT: begin
            rd_addr <= 8'd0;
            vga_hsync <= 1'b1;
            cnt <= cnt - 1'b1;
            if( cnt==7'd0 ) begin
                state       <=LINE;
                double      <=1'b0;
                finish      <=1'b0;
                cnt         <=7'd63;
                centre_done <= 1'b0;
                scanline    <= ~scanline;
            end
        end
        LINE: begin
            case( {finish, centre_done})
                2'b00:
                    if(cnt!=7'd0)
                        cnt<=cnt-1'b1; // blank space on left
                    else
                        {centre_done,rd_addr,double}<={rd_addr,double}+1'b1;
                2'b01: begin
                    finish <= cnt==7'd60;
                    cnt <= cnt+1'b1;
                end
                2'b11: begin
                    state <= BACK;
                    cnt   <= 7'd48;
                end
                default:;
            endcase
        end
        BACK: begin
            if( cnt==7'd0 ) begin
                state<=SYNC;
                cnt <= 7'd96;
                {vga_vsync, vsync_cnt} <= {vsync_cnt, 1'b1};
            end
            else cnt <= cnt - 1'b1;
        end
    endcase
end

endmodule // jtgng_vga