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
    Date: 4-2-2024 */

module jt053246_dma(
    input             rst,
    input             clk,
    input             pxl2_cen,

    input             dma_en,
    input             dma_trig,
    input             k44_en,   // enable k053244/5 mode (default k053246/7)

    input             hs,
    input             vs,

    // External RAM
    output reg [13:1] dma_addr, // up to 16 kB
    input      [15:0] dma_data,
    output reg        dma_bsy,    

    output            dma_weh,
    output            dma_wel,
    output     [11:1] dma_wr_addr,
    output     [15:0] dma_din,
    output reg        flicker
);

wire        dma_we, hs_pos;
reg  [ 1:0] vs_sh;
reg  [11:1] dma_bufa;
reg  [15:0] dma_bufd;
reg         dma_clr, dma_wait, dma_ok, dma_44, hsl;

assign dma_wel = dma_we & ~dma_wr_addr[1];
assign dma_weh = dma_we &  dma_wr_addr[1];

assign dma_din     = dma_clr ? 16'h0 : dma_bufd;
assign dma_we      = dma_clr | dma_ok;
assign dma_wr_addr = dma_clr ? dma_addr[11:1] : dma_bufa;
assign hs_pos  = hs & ~hsl;

// DMA logic
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dma_44 <= 0;
    end else begin
        if( dma_bsy ) dma_44 <= 0;
        if( dma_trig ) dma_44 <= 1;
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dma_bsy  <= 0;
        dma_clr  <= 0;
        dma_wait <= 0;
        dma_addr <= 0;
        dma_bufa <= 0;
        dma_bufd <= 0;
        dma_bsy  <= 0;
        dma_wait <= 0;
        hsl      <= 0;
        flicker  <= 0;
    end else if( pxl2_cen ) begin
        hsl <= hs;
        if( hs_pos ) begin
            vs_sh    <= vs_sh<<1;
            vs_sh[0] <= vs;
        end
        if(!dma_bsy && ((vs_sh==2'b10 && hs_pos) || dma_44) ) begin
            dma_bsy  <= dma_en | dma_44;
            dma_clr  <= 1;
            dma_wait <= !k44_en;
            flicker  <= ~flicker;
            dma_addr <= 0;
        end
        // this implementation matches 8-bit speed, ie 595us vs 297.5us for 16-bit mode
        if( !dma_bsy ) begin
            dma_addr <= 0;
            dma_bufa <= 0;
            dma_ok   <= 0;
        end else if( dma_clr ) begin // copy by priority order
            dma_addr[11:1] <= dma_addr[11:1] + 1'd1;
            dma_clr <= ~&{ dma_addr[11]|k44_en, dma_addr[10:1] };
            if( k44_en ) dma_addr[11]<=0;
            if( &dma_addr[11:1] ) dma_addr[11:1] <= 'h218; // extra 126us wait
        end else if(dma_wait) begin // extra time to match the original speed
            { dma_wait, dma_addr[11:1] } <= { 1'b1, dma_addr[11:1] } + 1'd1;
        end else begin
            dma_bufd <= dma_data;
            if( k44_en ) dma_addr[13:11] <= 0;
            if( dma_addr[3:1]==0 ) begin
                // the sprite at priority 0 in the Simpsons creates a problem in scene simson/4
                // I was skipping it before, but priority 0 is used in Vendetta and it must take priority
                // over the rest (see scene vendetta/3)
                dma_bufa <= { ~k44_en & dma_data[7], k44_en ? -dma_data[6:0] : dma_data[6:0], 3'd0 }; // LUT half as big for 053244 and reversed order
                dma_ok <= dma_data[15];
            end
            dma_addr[12:1] <= dma_addr[12:1] + 1'd1;
            dma_bufa[3:1] <= dma_addr[3:1];
            if( dma_addr[3:1]==6 ) begin
                dma_addr[12:1] <= dma_addr[12:1] + 12'd2; // skip 7
                dma_bsy <= !(&dma_addr[10:2] && (k44_en || &dma_addr[12:11]));
            end
        end
    end
end

endmodule