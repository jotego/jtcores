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
    Date: 18-12-2022 */

module jtkarnov_obj(
    input              rst,
    input              clk,
    input              pxl_cen,

    input              hs,
    input              flip,
    input       [ 8:0] hdump,
    input       [ 8:0] vrender,

    // Object buffer DMA (does not halt the CPU)
    output      [11:1] dma_addr,
    input              dma_start,
    output             dma_we,

    output      [11:1] ram_addr,
    input       [15:0] ram_data,

    output      [18:2] rom_addr,
    input       [31:0] rom_data,
    output             rom_cs,
    input              rom_ok,

    input       [ 7:0] debug_bus,
    output      [ 7:0] pxl
);

reg  [ 8:0] obj_cnt;
reg         cen=0, done, match, tall;
reg  [ 1:0] st;

reg         dr_draw, adv;
wire        dr_busy;
reg  [11:0] dr_code;
reg  [ 8:0] dr_xpos, xpos, ypos, ydiff, vf;
reg  [ 3:0] dr_ysub, dr_pal;
reg         hflip, vflip, dr_hflip, dr_vflip;

assign ram_addr = dma_we ? dma_addr : { obj_cnt, st };

always @* begin
    vf = vrender^{1'd0,{8{flip}}};
    ydiff = ypos-vf;
    match = ram_data[4] ? ydiff[8:5]==0 : ydiff[8:4]==0;
end

always @(posedge clk) cen <= ~cen;

always @* begin
    case( st )
        0: adv = !ram_data[15];
        1: adv = !ram_data[0] || !match;
        2: adv = ram_data[8:0]>='h100 && ram_data[8:0]<'h1F0;
        3: adv = !dr_busy;
    endcase
end

always @(posedge clk, posedge rst ) begin
    if(rst ) begin
        st       <= 0;
        done     <= 0;
        dr_draw <= 0;
    end else begin
        dr_draw <= 0;
        if( hs ) begin
            st   <= 0;
            done <= 0;
        end else if( !done && cen ) begin
            st <= st + 1'd1;
            case( st )
                0: begin
                    ypos <= 9'h100 - ram_data[8:0];
                end
                1: begin
                    tall  <= ram_data[4];
                    hflip <= ~ram_data[2];
                    vflip <= ~ram_data[1];
                end
                2: begin
                    xpos <= 9'h100-ram_data[8:0];
                end
                3: begin
                    if( !dr_busy ) begin
                        dr_code  <= ram_data[11:0];
                        if( tall ) dr_code[0] <= vflip^ydiff[4];
                        dr_pal   <= ram_data[15:12];
                        dr_xpos  <= xpos + (flip ? -25: -7);
                        dr_ysub  <= ydiff[3:0];
                        dr_hflip <= hflip;
                        dr_vflip <= vflip;
                        dr_draw  <= 1;
                    end else begin
                        st <= st;
                    end
                end
            endcase
            if( adv ) begin
                obj_cnt <= obj_cnt+1'd1;
                done    <= &obj_cnt;
                st      <= 0;
            end
        end
    end
end

jtframe_objdraw #(.HJUMP(1)) u_objdraw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),

    .draw       ( dr_draw   ),
    .busy       ( dr_busy   ),
    .code       ( dr_code   ),
    .xpos       ( dr_xpos   ),
    .ysub       ( dr_ysub   ),

    // No zoom
    .hzoom      ( 6'd0      ),
    .hz_keep    ( 1'b0      ),

    .hflip      ( dr_hflip  ),
    .vflip      ( dr_vflip  ),
    .pal        ( dr_pal    ),

    .rom_addr   ( rom_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( rom_data  ),

    .pxl        ( pxl       )
);

jtframe_bram_dma u_dma(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( pxl_cen   ),
    .addr   ( dma_addr  ),
    .start  ( dma_start ),
    .we     ( dma_we    )
);


endmodule