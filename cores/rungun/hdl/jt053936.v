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
    Date: 12-7-2025 */

// Based on Furrtek's module (see the original in the doc folder)

module jt053936(
    input           rst, clk, cen,

    input    [15:0] din,
    input    [ 4:1] addr,

    input           hs, vs,
    input           cs, dtackn, // cs always writes
    input    [ 1:0] dsn,
    output          dma_n,

    input           nloe,
    output    [2:0] lh,
    output    [8:0] la,

    input           noe,
    output   [12:0] x,
    output          xh,
    output   [12:0] y,
    output          yh,
    output      reg nob,
    // IOCTL dump
    input      [4:0] ioctl_addr,
    output reg [7:0] ioctl_din,
);
    reg  [15:0] mmr[0:15]; // used (real) registers are aliased as wires
    wire [15:0] io_mux, xhstep, xvstep, yhstep, yvstep, xcnt0, ycnt0;
    wire [ 9:0] xmin,  xmax, hcnt0, h;
    wire [ 8:0] ymin,  ymax, vcnt0, ln0, v, ln;
    wire [ 1:0] xmul,  ymul;
    wire [ 5:0] xclip, yclip;
    wire        ln_en, ob_n;
    wire [ 1:0] ob_cfg, ob_dly;
    wire        nulwin, tick_hs, tick_vs, xout, yout, xyout;
    integer k;

    assign io_mux = mmr[ioctl_addr[4:1]];
    assign xcnt0  = mmr[ 0];
    assign ycnt0  = mmr[ 1];
    assign xvstep = mmr[ 2]; // Registers 2~5 are read from the
    assign yvstep = mmr[ 3]; // external RAM when ln_en is set
    assign xhstep = mmr[ 4]; //
    assign yhstep = mmr[ 5]; //
    assign xmul   = mmr[ 6][ 7: 6];
    assign ymul   = mmr[ 6][15:14];
    assign xclip  = mmr[ 6][ 5: 0];
    assign yclip  = mmr[ 6][13: 8];
    assign ln_en  = mmr[ 7][6];
    assign ob_n   = mmr[ 7][5];
    assign ob_cfg = mmr[ 7][4:3];
    assign nulwin = mmr[ 7][2];
    assign ob_dly = mmr[ 7][1:0];
    assign xmin   = mmr[ 8][9:0];
    assign xmax   = mmr[ 9][9:0];
    assign ymax   = mmr[10][8:0];
    assign ymin   = mmr[11][8:0];
    assign hcnt0  = mmr[12][9:0];
    assign vcnt0  = mmr[13][8:0];
    assign ln0    = mmr[14][8:0];

    assign dma_n  = !ln_en;
    assign xyout  = xout & yout;

    jt053936_ticks u_ticks(clk,hs,vs,tick_hs,tick_vs);
    jt053936_video_counters u_vid(clk,cen, hs_edge,vs_edge,vcnt0,ln0,hcnt0,v,ln,h);
    jt053936_window #(10) u_hwin(clk,cen,hs_edge,h,xmin,xmax,xout);
    jt053936_window #( 9) u_vwin(clk,cen,vs_edge,v,ymin,ymax,yout);

    task mmr_write();
        if( !dsn[0] ) mmr[addr][ 7:0] <= din[ 7:0];
        if( !dsn[1] ) mmr[addr][15:8] <= din[15:8];
    endtask

    always @(posedge clk) begin
        if( rst ) begin
            for(k=0;k<16;k=k+1) mmr[k] <= 0;
        end else begin
            k = 0; // for Quartus linter
            if(cs) case(addr)
                2,3,4,5: if(!ln_en) mmr_write;
                default: mmr_write;
            endcase
            // add logic for ln_en reads into mmr[2~5]
        end
    end

    always @(posedge clk) begin
        ioctl_din <= ioctl_addr[0] ? io_mux[15:8] : io_mux[7:0];
    end
endmodule

/////////////////////////////////////////////////////
module jt053936_ticks(
    // keep port order
    input      clk,hs,vs,
    output reg tick_hs,tick_vs
);
    reg [1:0] hs_l, vs_l;

    wire vs_edge = vs_l[0] & ~vs_l[1];
    wire hs_edge = hs_l[0] & ~hs_l[1];

    always @(posedge clk) if(cen) begin
        hs_l <= {hs_l[0],hs};
        vs_l <= {vs_l[0],vs};

        tick_hs <= hs_edge;
        tick_vs <= vs_edge;
    end
endmodule

/////////////////////////////////////////////////////
module jt053936_video_counters(
    input            clk, cen, hs_edge, vs_edge,
    input      [8:0] v0, ln0,
    input      [9:0] h0,
    output reg [8:0] v, ln,
    output reg [9:0] h
);
    always @(posedge clk) if(cen) begin
        h  <= hs_edge ?  h0 : h0+10'd1;
        v  <= vs_edge ?  v0 : hs_edge ?  v+9'd1 :  v;
        ln <= vs_edge ? ln0 : hs_edge ? ln+9'd1 : ln;
    end
endmodule

/////////////////////////////////////////////////////
module jt053936_window #(parameter W=9)(
    input         clk, cen, s_edge, nulwin,
    input [W-1:0] cnt, min,  max,
    output reg    outside
);

localparam [1:0] MAX=2'b01,MIN=2'b10,BOTH=2'b00,NONE=2'b11;

wire [1:0] hit;

assign hit = {cnt==min,cnt==max};

always @(posedge clk) if(cen) begin
    case(hit)
        MIN:  outside <= 0;
        MAX:  outside <= 1;
        BOTH: outside <= 0;
        NONE: if(s_edge) outside <= nulwin;
    endcase
end

endmodule
