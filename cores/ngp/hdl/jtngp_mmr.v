/*  This file is part of JTNGP.
    JTNGP program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTNGP program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTNGP.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. https://patreon.com/jotego
    Version: 1.0
    Date: 23-3-2022 */

module jtngp_mmr(
    input             clk,
    input             rst,
    input      [ 9:0] hcnt,
    input      [ 7:0] vdump,
    input             LVBL,
    // CPU access
    input      [12:1] cpu_addr,
    output reg [15:0] cpu_din,
    input      [15:0] cpu_dout,
    input      [ 1:0] dsn,
    input             regs_cs,
    // video access
    output reg [ 7:0] hoffset,
    output reg [ 7:0] voffset,
    output reg [ 7:0] scr1_hpos,
    output reg [ 7:0] scr1_vpos,
    output reg [ 7:0] scr2_hpos,
    output reg [ 7:0] scr2_vpos,
    output reg [ 7:0] view_width,
    output reg [ 7:0] view_height, // it influences when interrupts occur too
    output reg [ 7:0] view_startx,
    output reg [ 7:0] view_starty,
    output reg        scr_order
);

wire [9:0] hdiff = 10'd514-hcnt;

`define SETREG(a,b) begin if(!dsn[1]) a<=cpu_dout[15:8]; if(!dsn[0]) b<=cpu_dout[7:0]; cpu_din<={a,b}; end

`ifdef SIMULATION
reg [7:0] zeroval[0:63];
integer f,cnt;

initial begin
    f = $fopen("regsram.bin","rb");
    if( f!=0 ) begin
        cnt = $fread(zeroval,f);
        $display("Read %d from regsram.bin",cnt);
        $fclose(f);
        scr_order   = zeroval[6'h30][7];
        view_startx = zeroval[6'h02];
        view_starty = zeroval[6'h03];
        view_width  = zeroval[6'h04];
        view_height = zeroval[6'h05];
        hoffset     = zeroval[6'h20];
        voffset     = zeroval[6'h21];
        scr1_hpos   = zeroval[6'h32];
        scr1_vpos   = zeroval[6'h33];
        scr2_hpos   = zeroval[6'h34];
        scr2_vpos   = zeroval[6'h35];
        $display("View window (%0d,%0d) size = %0dx%0d",view_startx,view_starty,view_width,view_height);
        $display("Sprite offset = %0d,%0d",hoffset,voffset);
        $display("SCR1 %d,%d",scr1_hpos,scr1_vpos);
        $display("SCR2 %d,%d",scr2_hpos,scr2_vpos);
    end else begin
        $display("Could not open regsram.bin");
    end
end
`endif

always @(posedge clk, posedge rst) begin
    if( rst
`ifdef SIMULATION
    && cnt==0 // do not delete the values loaded from sim files
`endif
    ) begin
        hoffset     <= 0;
        voffset     <= 0;
        scr1_hpos   <= 0;
        scr1_vpos   <= 0;
        scr2_hpos   <= 0;
        scr2_vpos   <= 0;
        scr_order   <= 0; // 0 = plane 1 above, 1 = plane 2 above
        view_width  <= 8'hff;
        view_height <= 8'hff;
        view_startx <= 0;
        view_starty <= 0;
        cpu_din     <= 0;
    end else begin
        if( regs_cs ) begin
            case( cpu_addr[7:1] )
                7'h02>>1: `SETREG(view_starty,view_startx)
                7'h04>>1: `SETREG(view_height,view_width)
                7'h08>>1: cpu_din <= { vdump, hdiff[9:2] };
                7'h10>>1: cpu_din <= { 8'h0, 1'b0 /* char over*/, ~LVBL, 6'd0 };
                7'h20>>1: `SETREG(voffset,hoffset) // offset for sprite position
                7'h30>>1: begin // scroll layer order
                    if(!dsn[0]) scr_order<=cpu_dout[7];
                    cpu_din <= {8'h0,scr_order,7'h0};
                end
                7'h32>>1: `SETREG(scr1_vpos, scr1_hpos)
                7'h34>>1: `SETREG(scr2_vpos, scr2_hpos)
                default:;
            endcase
        end
    end
end

endmodule
