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

wire [3:0] buf_r, buf_g, buf_b;


reg [4:0] prescan_b, prescan_r, prescan_g;
reg scanline;
reg [3:0] last_r, last_g, last_b;

function [4:0] ext; // extends by duplicating MSB
    input [3:0] a;
    ext = { a, a[3] };
endfunction

wire [5:0] mix_r = ext(last_r) + ext(buf_r);
wire [5:0] mix_g = ext(last_g) + ext(buf_g);
wire [5:0] mix_b = ext(last_b) + ext(buf_b);

always @(posedge clk_vga) begin
    {last_r, last_g, last_b} <= { buf_r, buf_g, buf_b };
    // pixel mixing
    if( !double || !en_mixing ) begin
        prescan_r <= ext(buf_r);
        prescan_g <= ext(buf_g);
        prescan_b <= ext(buf_b);
    end
    else begin
        prescan_r <= mix_r[5:1];
        prescan_g <= mix_g[5:1];
        prescan_b <= mix_b[5:1];
    end
    // 25% less bright scan lines = scale by 3/4
    vga_red   <= prescan_r;
    vga_green <= prescan_g;
    vga_blue  <= prescan_b;
    // vga_red   <= scanline ? 
    //     ({1'b0,prescan_r,1'b0} + {2'b0, prescan_r}) >> 2 : prescan_r;
    // vga_green <= scanline ? 
    //     ({1'b0,prescan_g,1'b0} + {2'b0, prescan_g}) >> 2 : prescan_g;
    // vga_blue  <= scanline ? 
    //     ({1'b0,prescan_b,1'b0} + {2'b0, prescan_b}) >> 2 : prescan_b;
end

//`ifndef SIM_SYNCONLY
jtgng_dual_clk_ram ram_rg (
    .addr_a  ( {wr_sel, 1'b0, wr_addr} ),
    .addr_b  ( {rd_sel, 1'b0, rd_addr} ),
    .clka    ( clk_rgb                 ),
    .clka_en ( cen6                    ),
    .clkb    ( clk_vga                 ),
    .clkb_en ( 1'b1                    ),
    .data_a  ( {red,green}             ),
    .data_b  ( {red,green}             ), // unused
    .we_a    ( 1'b1                    ),
    .we_b    ( 1'b0                    ),
    .q_b     ( {buf_r, buf_g}          ),
    .q_a     (                         )
);

wire [3:0] nc;

jtgng_dual_clk_ram ram_b (
    .addr_a  ( {wr_sel, 1'b1, wr_addr} ),
    .addr_b  ( {rd_sel, 1'b1, rd_addr} ),
    .clka    ( clk_rgb                 ),
    .clka_en ( cen6                    ),
    .clkb    ( clk_vga                 ),
    .clkb_en ( 1'b1                    ),
    .data_a  ( {4'b0, blue}            ),
    .data_b  ( {4'b0, blue}            ), // unused
    .we_a    ( 1'b1                    ),
    .we_b    ( 1'b0                    ),
    .q_b     ( {nc,buf_b}              ),
    .q_a     (                         )    
);
//`endif

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

reg LHBL_vga, last_LHBL_vga;
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