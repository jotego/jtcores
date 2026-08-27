/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 1-5-2022 */

/* The priority is controlled by a PAL, which was dumped and converted
   here http://wiki.pldarchive.co.uk/index.php?title=Vigilante_(M75)

i1,2,3,4  = obj_pxl[3:0]
i5,6      = scr1_pxl[7:6]
i7,8,9,11 = scr1_pxl[3:0]
i13       = ~ROME

Selects the objects.
    0 = transparent colour
    scr1_pxl[7:6]==3 && scr1_pxl[3], SCR1 wins
/OBJS = /o14 = /i1 & /i2 & /i3 & /i4 +
      i5 & i6 & i7

Selects the backgrounds, this equations seems wrong
/CPS =/o15 = /i1 & /i2 & /i3 & /i4 +
       i5 & i6 & i7

Scr1 or Scr2?
    SCR1 wins if non zero and scr1_pxl[7:6]!=0 and ~ROME==1
PSEL = /o16 = /i5 & /i6 & /i7 & /i8 & /i9 & /i11 & /i13

*/

module jtvigil_colmix(
    input            rst,
    input            clk,

    input            pxl_cen,
    input            LHBL,
    input            LVBL,

    input      [7:0] scr1_pxl,
    input      [2:0] scr2col,
    input      [3:0] scr2_pxl,
    input      [7:0] obj_pxl,
    input            scr2enb,

    input     [ 8:0] v,
    input      [7:0] debug_bus,
    // Palette RAM
    output    [10:0] pal_addr,
    input     [ 7:0] pal_dout,

    // Debug
    input      [3:0] gfx_en,

    output reg [4:0] red,
    output reg [4:0] green,
    output reg [4:0] blue
);

localparam OBJ=0, SCR=1;

wire        obj_blank, scr1_blank, scr1_wins;
reg         sel;
reg  [ 2:0] sub;
reg  [ 7:0] pal_base;
reg  [ 4:0] pre_r, pre_g, pre_b;

assign obj_blank  = obj_pxl[3:0]==0 || !gfx_en[3];
assign scr1_blank = scr1_pxl[3:0]==0 || !gfx_en[0];
assign scr1_wins  = !scr1_blank && scr1_pxl[7:6]==3 && scr1_pxl[3];
assign pal_addr   = { sel, sub[2:1], pal_base };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        sub   <= 0;
        red   <= 0;
        green <= 0;
        blue  <= 0;
    end else begin
        sub <= pxl_cen ? 3'd0 : sub + 3'd1;
        `ifndef GRAY
        if( sub[0] )
            case( sub[2:1] )
            0: pre_r <= pal_dout[4:0];
            1: pre_g <= pal_dout[4:0];
            2: pre_b <= pal_dout[4:0];
            default:;
        endcase
        `else
            pre_r <= { pal_addr[3:0], 1'b0 };
            pre_g <= { pal_addr[3:0], 1'b0 };
            pre_b <= { pal_addr[3:0], 1'b0 };
        `endif
        if( pxl_cen ) begin
            { red, green, blue } <= ( !LVBL || !LHBL ) ? 15'd0 : {pre_r, pre_g, pre_b};
            if( obj_blank || scr1_wins ) begin
                sel      <= SCR[0];
                pal_base <=
                    (scr2enb || scr1_pxl[7] || scr1_pxl[6] ) ? scr1_pxl :
                    scr1_blank ? { scr2col[2:1], v[7], scr2col[0], scr2_pxl } : scr1_pxl;
            end else begin
                sel      <= OBJ[0];
                pal_base <= obj_pxl;
            end
        end
    end
end

endmodule