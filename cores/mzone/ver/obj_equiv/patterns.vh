// SPDX-License-Identifier: GPL-3.0-or-later
// Logical pixel pattern and palette are independent of the renderer's shifter.
function [3:0] pen;
    input [7:0] code;
    input [3:0] row;
    input integer x;
    begin
        if(code==0 || ((code+row+x)%4)==0) pen=0;
        else pen=1+((code*3+row*5+x*7)%15);
    end
endfunction
function [3:0] palette;
    input [3:0] pal, p;
    begin
        // Zero remains transparent; some nonzero pens also map to zero.
        // This distinguishes palette-before-buffer from palette-after-buffer.
        palette=p==0 || ((pal+p)%7)==0 ? 0 : 1+((p+pal*3-1)%15);
    end
endfunction
function [31:0] graphics;
    input [12:0] a;
    integer k, group, bitpos;
    reg [3:0] p;
    begin
        graphics=0;
        for(k=0;k<8;k=k+1) begin
            p=pen(a[12:5],{a[4],a[2:0]},(a[3]?8:0)+k);
            group=(k/4)*16;
            bitpos=k%4;
            graphics[group+7-bitpos]=p[0];
            graphics[group+3-bitpos]=p[1];
            graphics[group+15-bitpos]=p[2];
            graphics[group+11-bitpos]=p[3];
        end
    end
endfunction
