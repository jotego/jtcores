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
    Date: 26-9-2023 */

// Implementation of C123 tilemaps
// based on MAME's namo_c123tmap.cpp and Atari's schematics
// 6 layers = 4 scroll + 2 fix
// 8x8 pixels, 8 bpp

module jtshouse_scr(
    input             rst,
    input             clk,

    input             pxl_cen,
    input             hs,
    input       [8:0] hdump,
    input       [8:0] vdump,
    input             flip,

    input             cs,
    input       [4:0] addr,
    input             rnw,
    input       [7:0] din,
    output reg  [7:0] dout,

    // Tile map readout (BRAM)
    output     [14:1] tmap_addr,
    input      [15:0] tmap_data,
    // Mask readout (SDRAM)
    output reg        mask_cs,
    input             mask_ok,
    output reg [16:0] mask_addr,
    input      [ 7:0] mask_data,
    // Tile readout (SDRAM)
    output            scr_cs,
    input             scr_ok,
    output     [19:0] scr_addr,
    input      [ 7:0] scr_data,
    // Pixel output
    output     [10:0] pxl,
    output     [ 2:0] prio,
    // IOCTL dump
    input      [ 4:0] ioctl_addr,
    output     [ 7:0] ioctl_din,
    // Debug
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

// MMR
// 0~F scroll positions
// tilemap 3 bits - scroll X/Y 1 bit - upper/lower byte sel 1 bit
// 10~17 priority
// 18~1F color

reg  [ 7:0] mmr[0:31];
reg  [ 7:0] maskin[0:5];
reg  [15:0] hpos, vpos, nx_hpos, nx_vpos;
reg  [13:0] mux;
reg  [ 2:0] nx_prio, nx_pal, tcntl;
wire [ 2:0] tcnt, idx;
reg  [13:0] info[0:5];
// mapped by priority
reg  [ 7:0] maskll[0:7];
reg  [13:0] infoll[0:7];
reg  [ 2:0] vin[0:5], hin[0:5];
reg  [ 2:0] vll[0:7], hll[0:7];
reg  [ 2:0] vmux, hmux;
reg  [ 2:0] lyr   [0:7]; // maps the priority 0-7 to the layer 0-5
reg  [ 8:0] hcnt;
reg  [10:0] bpxl;
reg  [ 2:0] bprio;
reg         hs_l, done, alt_cen;
wire        buf_we, rom_ok;
integer     i, j;

assign idx = flip ? 3'd7 : 3'd0;
// using tcntl prevents a glitch as tcnt changes 1 tick before hpos/vpos
assign tmap_addr = tcntl<3 ? { tcntl[1:0],       vpos[3+:6], hpos[3+:6] }: // 3 + 12 = 14 bits
                   tcntl<4 ? { tcntl[1:0], 1'b0, vpos[3+:5], hpos[3+:6] }:
                             { 3'd7, tcntl[0],   vpos[3+:5], hpos[3+:5] }; // not sure about this one
assign scr_addr  = { mux[13:0], vmux[2:0], hmux[2:0] };
assign scr_cs    = 1;
assign tcnt      = hcnt[2:0];
assign ioctl_din = mmr[ioctl_addr];
assign buf_we    = alt_cen & ~done;
assign rom_ok    = scr_ok & (mask_ok | ~mask_cs);

`ifdef SIMULATION
integer f, fcnt;
reg [7:0] mmr_init[0:31];
initial begin
    f=$fopen("rest.bin","rb");
    if( f!=0 ) begin
        fcnt=$fread(mmr_init,f);
        $display("INFO: Read %d bytes for %m.mmr",fcnt);
    end
    $fclose(f);
end
`endif

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hs_l <= 0;
        hcnt <= 0;
        done <= 0;
    end else begin
        alt_cen <= 0;
        if(pxl_cen) begin
            hs_l    <= hs;
            alt_cen <= rom_ok;
            if( hcnt < 9'h1a0 && rom_ok) hcnt <= hcnt+9'd1;
            if( hs & ~hs_l ) hcnt <= 9'h80;
            done <= hcnt==9'h19f;
        end
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        for(i=0;i<32;i=i+1) `ifndef SIMULATION
            mmr[i]<=0; // ignore latch warning by Quartus here
        `else
            mmr[i]<=mmr_init[i];
        `endif
    end else begin
        dout    <= mmr[addr];
        st_dout <= mmr[debug_bus[4:0]];
        if( cs & ~rnw ) mmr[addr]<=din;
    end
end

always @* begin
    if( tcnt>3 )
        { nx_vpos, nx_hpos } = { 7'd0, vdump, 7'd0, hcnt };
    else
        { nx_vpos, nx_hpos } = { {mmr[{tcnt,2'd2}], mmr[{tcnt,2'd3}]}+{7'd0,vdump},
                                 {mmr[{tcnt,2'd0}], mmr[{tcnt,2'd1}]}+{7'd0,hcnt} };
    if( flip ) begin
        nx_hpos = -nx_hpos;
        nx_vpos = -nx_vpos;
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        vpos      <= 0;
        hpos      <= 0;
        tcntl     <= 0;
        mask_cs   <= 0;
        mask_addr <= 0;
        mux       <= 0;
        bpxl      <= 0;
        bprio     <= 0;
        nx_prio   <= 0;
        nx_pal    <= 0;
        for( i=0; i< 6; i=i+1 ) begin
            maskin[i] <= 0;
            info  [i] <= 0;
        end
        for( i=0; i< 8; i=i+1 ) begin
            maskll[i] <= 0;
            infoll[i] <= 0;
            lyr   [i] <= 0;
            hll   [i] <= 0;
            vll   [i] <= 0;
        end
    end else begin
        { vpos, hpos } <= { nx_vpos, nx_hpos };
        tcntl <= tcnt;
        if( alt_cen ) begin
            // pipeline
            // 0:                  output: tmap_addr
            // 1: input: tmap_data output: mask_addr
            // 2: input: map_data
            if( tcnt<6 ) begin
                mask_addr  <= { tmap_data[13:0], vpos[2:0] }; // 17 bits
                mask_cs    <= 1;
                info[tcnt] <= tmap_data[13:0];
                hin[tcnt]  <= hpos[2:0];
                vin[tcnt]  <= vpos[2:0];
            end else begin
                mask_cs    <= 0;
            end
            if( tcnt>=2 && tcnt<7 ) maskin[tcnt-3'd2] <= mask_data; // assumes mask_ok=1
            if( tcnt==7 ) begin
                for( j=0; j<8; j=j+1 ) maskll[j] <= 0;
                for( i=0; i<6; i=i+1 ) begin
                    if( !mmr[{2'b10,i[2:0]}][3] ) begin
                        maskll[mmr[{2'b10,i[2:0]}][2:0]] <= maskin[i] ;
                        infoll[mmr[{2'b10,i[2:0]}][2:0]] <= info[i];
                        hll   [mmr[{2'b10,i[2:0]}][2:0]] <= hin[i];
                        vll   [mmr[{2'b10,i[2:0]}][2:0]] <= vin[i];
                        lyr   [mmr[{2'b10,i[2:0]}][2:0]] <= i[2:0];
                    end
                end
            end else begin
                for( i=0; i<6; i=i+1 ) maskll[i] <= flip ? maskll[i]<<1 : maskll[i]>>1;
            end
            // Keep the order:
            if( maskll[7][idx] ) begin mux <= infoll[7]; vmux<=vll[7]; hmux<=hll[7]+hcnt[2:0]; nx_prio <= 7; nx_pal <= mmr[{2'b11,lyr[7]}][2:0]; end
            if( maskll[6][idx] ) begin mux <= infoll[6]; vmux<=vll[6]; hmux<=hll[6]+hcnt[2:0]; nx_prio <= 6; nx_pal <= mmr[{2'b11,lyr[6]}][2:0]; end
            if( maskll[5][idx] ) begin mux <= infoll[5]; vmux<=vll[5]; hmux<=hll[5]+hcnt[2:0]; nx_prio <= 5; nx_pal <= mmr[{2'b11,lyr[5]}][2:0]; end
            if( maskll[4][idx] ) begin mux <= infoll[4]; vmux<=vll[4]; hmux<=hll[4]+hcnt[2:0]; nx_prio <= 4; nx_pal <= mmr[{2'b11,lyr[4]}][2:0]; end
            if( maskll[3][idx] ) begin mux <= infoll[3]; vmux<=vll[3]; hmux<=hll[3]+hcnt[2:0]; nx_prio <= 3; nx_pal <= mmr[{2'b11,lyr[3]}][2:0]; end
            if( maskll[2][idx] ) begin mux <= infoll[2]; vmux<=vll[2]; hmux<=hll[2]+hcnt[2:0]; nx_prio <= 2; nx_pal <= mmr[{2'b11,lyr[2]}][2:0]; end
            if( maskll[1][idx] ) begin mux <= infoll[1]; vmux<=vll[1]; hmux<=hll[1]+hcnt[2:0]; nx_prio <= 1; nx_pal <= mmr[{2'b11,lyr[1]}][2:0]; end
            if( maskll[0][idx] ) begin mux <= infoll[0]; vmux<=vll[0]; hmux<=hll[0]+hcnt[2:0]; nx_prio <= 0; nx_pal <= mmr[{2'b11,lyr[0]}][2:0]; end
            { bpxl, bprio } <= { nx_pal, scr_data, nx_prio };
        end
    end
end

jtframe_linebuf #(.DW(14)) u_buffer(
    .clk        ( clk       ),
    .LHBL       ( ~hs       ),
    .wr_addr    ( hcnt      ),
    .wr_data    ({bpxl,bprio}),
    .we         ( buf_we    ),
    .rd_addr    ( hdump     ),
    .rd_data    ({pxl,prio} ),
    .rd_gated   (           )
);

endmodule