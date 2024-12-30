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

    Author: Jose Tejada Gomez. https://patreon.com/jotego
    Version: 1.0
    Date: 23-3-2022 */

module jtngp_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             lcd_neg,

    input             scr_order,
    input      [ 2:0] oowc,
    input             oow,          // outside of window
    input             mode,

    // CPU access
    input      [ 8:1] cpu_addr,
    output reg [15:0] cpu_din,
    input      [15:0] cpu_dout,
    input      [ 1:0] we,
    input             pal_cs,

    input             LHBL,
    input             LVBL,

    input       [6:0] scr1_pxl, // only bits 2:0 used for scroll in monochrome
    input       [6:0] scr2_pxl,
    input       [8:0] obj_pxl,

    // priority output
    output reg  [1:0] lyr,      // active layer: 00 sprite, 01 scr1, 10 scr2, 11 background
    output reg  [2:0] pxl,
    output reg  [3:0] col,
    output reg        pal,

    output      [3:0] red,
    output      [3:0] green,
    output      [3:0] blue,
    input       [7:0] debug_bus
    // gfx_en is handled at the scroll and obj modules
);

wire [ 1:0] prio = obj_pxl[4:3];
wire [ 3:0] scr_eff;    // bit 3 set for background tilemap
wire [ 2:0] scr1_mode, scr2_mode;
reg  [ 3:0] raw;
reg         bg_en;
wire [ 2:0] obj_palout, scr1_palout, scr2_palout;
wire        scr1_blank, scr2_blank, scr_blank, obj_blank;

// monochrome palette
reg [2:0]  obj_pal0 [1:3];
reg [2:0]  obj_pal1 [1:3];
reg [2:0] scr1_pal0 [1:3];
reg [2:0] scr1_pal1 [1:3];
reg [2:0] scr2_pal0 [1:3];
reg [2:0] scr2_pal1 [1:3];
reg [2:0] bg_pal;
reg [1:0] bg_cfg;
reg       obj_sel;

assign  scr1_blank = scr1_pxl[1:0]==0,
        scr2_blank = scr2_pxl[1:0]==0,
        obj_blank  = obj_pxl[1:0]==0 || prio==0,
        scr_blank  = scr1_blank && scr2_blank,
        obj_palout = obj_pxl[2] ? obj_pal1[obj_pxl[1:0]] : obj_pal0[obj_pxl[1:0]],
        scr1_palout= scr1_pxl[2] ? scr1_pal1[scr1_pxl[1:0]] : scr1_pal0[scr1_pxl[1:0]],
        scr2_palout= scr2_pxl[2] ? scr2_pal1[scr2_pxl[1:0]] : scr2_pal0[scr2_pxl[1:0]],
        scr1_mode  = mode ? scr1_palout : scr1_pxl[2:0],
        scr2_mode  = mode ? scr2_palout : scr2_pxl[2:0],
        scr_eff    = scr_blank ? {1'b1, bg_en ? bg_pal : 3'd0 } :
                     scr_order ?
            ( !scr2_blank ? {1'b0,scr2_mode} : {1'b1,scr1_mode} ):
            ( !scr1_blank ? {1'b0,scr1_mode} : {1'b1,scr2_mode} );

assign  red        = raw,
        blue       = raw,
        green      = raw;

always @* begin
    // layer mixing
    pxl     = scr_eff[2:0];
    lyr     = scr_blank ? 2'b11 : // background
       (scr_eff[3] ^ scr_order) ? 2'b10 : 2'b01;
    col     = scr_order ?
        (!scr2_blank ? scr2_pxl[6-:4] : scr1_pxl[6-:4]):
        (!scr1_blank ? scr1_pxl[6-:4] : scr2_pxl[6-:4]);
    pal     = scr_order ?
        (!scr2_blank ? scr2_pxl[2] : scr1_pxl[2]):
        (!scr1_blank ? scr1_pxl[2] : scr2_pxl[2]);
    obj_sel = 0;
    if( !obj_blank ) begin
        case( prio )
            3: obj_sel = 1;
            2: if( scr_eff[3] || scr_blank ) obj_sel = 1;
            1: if( scr_blank ) obj_sel = 1;
            default: ;  // do not draw the object
        endcase
    end
    if( oow )  begin
        lyr = 3;
        pxl = oowc;
    end else if( obj_sel ) begin
        lyr = 2'b00;
        col = obj_pxl[8-:4];
        pal = obj_pxl[2];
        pxl = mode ? obj_palout : {1'b0, obj_pxl[1:0]};
    end
end

always @(posedge clk) if(pxl_cen) begin
    raw <= LVBL ? { pxl[2:0], pxl[2] }^{4{~lcd_neg}} : 4'd0;
end

`ifdef SIMULATION
reg [7:0] zeroval[0:24];
integer f,cnt;

initial begin
    f = $fopen("pal.bin","rb");
    if( f!=0 ) begin
        cnt = $fread(zeroval,f);
        $display("Read %0d bytes from pal.bin",cnt);
        $fclose(f);
    end else begin
        $display("Could not open pal.bin");
    end
end
`endif

// palette writes
always @(posedge clk, posedge rst) begin
    if( rst ) begin
         obj_pal0[1] <= 7;  obj_pal0[2] <= 7;  obj_pal0[3] <= 7;
         obj_pal1[1] <= 7;  obj_pal1[2] <= 7;  obj_pal1[3] <= 7;
        scr1_pal0[1] <= 7; scr1_pal0[2] <= 7; scr1_pal0[3] <= 7;
        scr1_pal1[1] <= 7; scr1_pal1[2] <= 7; scr1_pal1[3] <= 7;
        scr2_pal0[1] <= 7; scr2_pal0[2] <= 7; scr2_pal0[3] <= 7;
        scr2_pal1[1] <= 7; scr2_pal1[2] <= 7; scr2_pal1[3] <= 7;
          bg_pal     <= 7;
          bg_cfg     <= 0;
`ifdef SIMULATION
        if( cnt==25 ) begin
             obj_pal0[1] <= zeroval[   1][2:0];
             obj_pal0[2] <= zeroval[   2][2:0];
             obj_pal0[3] <= zeroval[   3][2:0];
             obj_pal1[1] <= zeroval[ 4+1][2:0];
             obj_pal1[2] <= zeroval[ 4+2][2:0];
             obj_pal1[3] <= zeroval[ 4+3][2:0];
            scr1_pal0[1] <= zeroval[ 8+1][2:0];
            scr1_pal0[2] <= zeroval[ 8+2][2:0];
            scr1_pal0[3] <= zeroval[ 8+3][2:0];
            scr1_pal1[1] <= zeroval[12+1][2:0];
            scr1_pal1[2] <= zeroval[12+2][2:0];
            scr1_pal1[3] <= zeroval[12+3][2:0];
            scr2_pal0[1] <= zeroval[16+1][2:0];
            scr2_pal0[2] <= zeroval[16+2][2:0];
            scr2_pal0[3] <= zeroval[16+3][2:0];
            scr2_pal1[1] <= zeroval[20+1][2:0];
            scr2_pal1[2] <= zeroval[20+2][2:0];
            scr2_pal1[3] <= zeroval[20+3][2:0];
              bg_pal     <= zeroval[20+4][2:0];
              bg_cfg     <= zeroval[20+4][7:6];
        end
`endif
    end else begin
        cpu_din <= 0;
        bg_en   <= bg_cfg==2'b10;
        case( cpu_addr[4:1] )
            4'b0_000: cpu_din[10:8] <= obj_pal0[1];
            4'b0_001: begin
                cpu_din[ 2:0] <= obj_pal0[2];
                cpu_din[10:8] <= obj_pal0[3];
            end
            4'b0_010: cpu_din[10:8] <= obj_pal1[1];
            4'b0_011: begin
                cpu_din[ 2:0] <= obj_pal1[2];
                cpu_din[10:8] <= obj_pal1[3];
            end
            // Scroll 1
            4'b0_100: cpu_din[10:8] <= scr1_pal0[1];
            4'b0_101: begin
                cpu_din[ 2:0] <= scr1_pal0[2];
                cpu_din[10:8] <= scr1_pal0[3];
            end
            4'b0_110: cpu_din[10:8] <= scr1_pal1[1];
            4'b0_111: begin
                cpu_din[ 2:0] <= scr1_pal1[2];
                cpu_din[10:8] <= scr1_pal1[3];
            end
            // Scroll 2
            4'b1_000: cpu_din[10:8] <= scr2_pal0[1];
            4'b1_001: begin
                cpu_din[ 2:0] <= scr2_pal0[2];
                cpu_din[10:8] <= scr2_pal0[3];
            end
            4'b1_010: cpu_din[10:8] <= scr2_pal1[1];
            4'b1_011: begin
                cpu_din[ 2:0] <= scr2_pal1[2];
                cpu_din[10:8] <= scr2_pal1[3];
            end
            // Background
            4'b1_100: {cpu_din[7:6], cpu_din[2:0]} <= {bg_cfg,bg_pal};
            default:;
        endcase

        if( pal_cs ) case( cpu_addr[4:1] )
            4'b0_000: if( we[1] ) obj_pal0[1] <= cpu_dout[10:8];
            4'b0_001: begin
                if( we[0] ) obj_pal0[2] <= cpu_dout[ 2:0];
                if( we[1] ) obj_pal0[3] <= cpu_dout[10:8];
            end
            4'b0_010: if( we[1] ) obj_pal1[1] <= cpu_dout[10:8];
            4'b0_011: begin
                if( we[0] ) obj_pal1[2] <= cpu_dout[ 2:0];
                if( we[1] ) obj_pal1[3] <= cpu_dout[10:8];
            end
            // Scroll 1
            4'b0_100: if( we[1] ) scr1_pal0[1] <= cpu_dout[10:8];
            4'b0_101: begin
                if( we[0] ) scr1_pal0[2] <= cpu_dout[ 2:0];
                if( we[1] ) scr1_pal0[3] <= cpu_dout[10:8];
            end
            4'b0_110: if( we[1] ) scr1_pal1[1] <= cpu_dout[10:8];
            4'b0_111: begin
                if( we[0] ) scr1_pal1[2] <= cpu_dout[ 2:0];
                if( we[1] ) scr1_pal1[3] <= cpu_dout[10:8];
            end
            // Scroll 2
            4'b1_000: if( we[1] ) scr2_pal0[1] <= cpu_dout[10:8];
            4'b1_001: begin
                if( we[0] ) scr2_pal0[2] <= cpu_dout[ 2:0];
                if( we[1] ) scr2_pal0[3] <= cpu_dout[10:8];
            end
            4'b1_010: if( we[1] ) scr2_pal1[1] <= cpu_dout[10:8];
            4'b1_011: begin
                if( we[0] ) scr2_pal1[2] <= cpu_dout[ 2:0];
                if( we[1] ) scr2_pal1[3] <= cpu_dout[10:8];
            end
            // Background
            4'b1_100: if( we[0] ) {bg_cfg, bg_pal} <= {cpu_dout[7:6],cpu_dout[2:0]};
            default:;
        endcase
    end
end

endmodule