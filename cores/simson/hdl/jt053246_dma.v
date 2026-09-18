/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-2-2024 */

module jt053246_dma(
    input             rst,
    input             clk,
    input             pxl2_cen,

    input             mode8,
    input             dma_en,
    input             dma_trig,
    input             k44_en,   // enable k053244/5 mode (default k053246/7)
    input             simson,

    input             hs,
    input             lvbl,

    // External RAM
    output     [13:1] dma_addr, // up to 16 kB
    input      [15:0] dma_data,
    output reg        dma_bsy,    

    output            dma_weh,
    output            dma_wel,
    output     [11:1] dma_wr_addr,
    output     [15:0] dma_din,
    output reg        flicker
);

parameter K55673=0, K55673_DESC_SORT=0, EDGE_TRIGGER=0;
// ESTRIDE_LOG2: log2 of external words per entry, ENTRY_LOG2: log2 of entries
// Default 8 words/512 entries. Moo Mesa: 32 words (A6/A7 not connected), 256 entries
parameter ESTRIDE_LOG2 = 3, ENTRY_LOG2 = 9;
localparam GAPBITS   = ESTRIDE_LOG2>3 ? ESTRIDE_LOG2-3 : 0;
localparam ENTRY_TOP = 3+ENTRY_LOG2; // top bit of the entry field inside cnt
localparam PADBITS   = 13-ENTRY_LOG2-GAPBITS-3;

wire        dma_we, hs_pos;
reg  [ 1:0] lvbl_sh;
reg  [11:1] dma_bufa;
reg  [15:0] dma_bufd;
wire [ 7:0] sort_24x, sort_673;
reg         dma_clr, dma_wait, dma_ok, dma_44, hsl;
reg  [13:1] cnt;

assign dma_wel = dma_we & ~dma_wr_addr[1];
assign dma_weh = dma_we &  dma_wr_addr[1];

assign dma_din     = dma_clr ? 16'h0 : dma_bufd;
assign dma_we      = dma_clr | dma_ok;
assign dma_wr_addr = dma_clr ? cnt[11:1] : dma_bufa;
assign hs_pos  = hs & ~hsl;

assign dma_addr = GAPBITS==0 ? cnt[13:1] :
    { {PADBITS{1'b0}}, cnt[ENTRY_TOP:4], {GAPBITS{1'b0}}, cnt[3:1] };

assign sort_673 = dma_data[7:0]^{8{K55673_DESC_SORT[0]}};
assign sort_24x ={ ~k44_en & dma_data[7], k44_en ? dma_data[6:0] : ~dma_data[6:0]};

// DMA logic
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dma_44 <= 0;
    end else begin
        if( dma_bsy  ) dma_44 <= 0;
        if( dma_trig ) dma_44 <= 1;
    end
end

reg trigger_two_lines_after_lvbl, trigger_at_dmaen, trigger, dmaen_l;

always @* begin
    trigger_two_lines_after_lvbl = dma_en && (lvbl_sh==2'b10 && hs_pos);
    trigger_at_dmaen = ~dma_en & dmaen_l;
    trigger = EDGE_TRIGGER==1 ? trigger_at_dmaen : trigger_two_lines_after_lvbl;
end

always @(posedge clk) if(pxl2_cen) begin
    dmaen_l <= dma_en;
end

always @(posedge clk) begin
    if( rst ) begin
        dma_bsy  <= 0;
        dma_clr  <= 0;
        dma_wait <= 0;
        cnt      <= 0;
        dma_bufa <= 0;
        dma_bufd <= 0;
        dma_bsy  <= 0;
        dma_wait <= 0;
        hsl      <= 0;
        flicker  <= 0;
    end else if( pxl2_cen ) begin
        hsl <= hs;
        if( hs_pos ) begin
            lvbl_sh    <= lvbl_sh<<1;
            lvbl_sh[0] <= lvbl;
        end
        if(!dma_bsy && (trigger || dma_44) ) begin
            dma_bsy  <= 1;
            dma_clr  <= 1;
            dma_wait <= !k44_en && mode8; // 8-bit speed: 595us, 16-bit: 297.5us
            flicker  <= ~flicker;
            cnt      <= 0;
        end
        if( !dma_bsy ) begin
            cnt      <= 0;
            dma_bufa <= 0;
            dma_ok   <= 0;
        end else if( dma_clr ) begin // copy by priority order
            cnt[11:1] <= cnt[11:1] + 1'd1;
            dma_clr <= ~&{ cnt[11]|k44_en, cnt[10:1] };
            if( k44_en ) cnt[11]<=0;
            if( &cnt[11:1] && dma_wait ) cnt[11:1] <= 'h218; // extra 126us wait
        end else if(dma_wait) begin // extra time to match the original speed
            { dma_wait, cnt[11:1] } <= { 1'b1, cnt[11:1] } + 1'd1;
        end else begin
            dma_bufd <= dma_data;
            if( k44_en ) cnt[13:11] <= 0;
            if( cnt[3:1]==0 ) begin
                // the sprite at priority 0 in the Simpsons creates a problem in scene simson/4
                // I was skipping it before, but priority 0 is used in Vendetta and it must take priority
                // over the rest (see scene vendetta/3)
                // LUT half as big for 053244 and reversed order
                dma_bufa <= { K55673==1 ? sort_673 : sort_24x, 3'd0 };
                dma_ok   <= dma_data[15] && (dma_data[7:0]!=0 || !simson);
            end
            cnt[ENTRY_TOP:1] <= cnt[ENTRY_TOP:1] + 1'd1;
            dma_bufa[ 3:1] <= cnt[3:1];
            if( cnt[3:1]==6 ) begin
                cnt[ENTRY_TOP:1] <= cnt[ENTRY_TOP:1] + 2; // skip 7
                dma_bsy <= !(&cnt[10:2] && (k44_en || &cnt[ENTRY_TOP:4]));
            end
        end
    end
end

endmodule
