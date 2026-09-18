/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-11-2022 */
/* verilator lint_off MODDUP */
module jtframe_lfbuf_ddr_ctrl #(parameter
    CLK96   = 0,   // assume 48-ish MHz operation by default
    VW      = 8,
    HW      = 9
)(
    input               rst,    // hold in reset for >150 us
    input               clk,
    input               pxl_cen,

    input               lhbl,
    input               ln_done,
    input               fb_keep,
    input      [VW-1:0] vrender,
    input      [VW-1:0] ln_v,
    input               vs,
    // data written to external memory
    input               frame,
    input               fb_blank,
    output reg [HW-1:0] fb_addr,
    input      [  15:0] fb_din,
    output reg          fb_clr,
    output reg          fb_done,
    output              fb_busy,

    // data read from external memory to screen buffer
    // during h blank
    output     [  15:0] fb_dout,
    output reg [HW-1:0] rd_addr,
    output reg          line,
    output              scr_we,

    output              ddram_clk,
    input               ddram_busy,
    output      [7:0]   ddram_burstcnt,
    output     [31:3]   ddram_addr,
    input      [63:0]   ddram_dout,
    input               ddram_dout_ready,
    output reg          ddram_rd,
    output     [63:0]   ddram_din,
    output      [7:0]   ddram_be,
    output reg          ddram_we,

    // Status
    input       [7:0]   st_addr,
    output reg  [7:0]   st_dout
);

localparam AW=HW+VW+1;
localparam [1:0] IDLE=0, READ=1, WRITE=2;
localparam [15:0] LFBUF_CLR = `ifndef JTFRAME_LFBUF_CLR 0 `else `JTFRAME_LFBUF_CLR `endif ;

reg           lhbl_l, ln_done_l, do_wr, rd_wait;
reg  [   1:0] st;
reg  [AW-1:0] act_addr;
wire [HW-1:0] nx_rd_addr;
reg  [HW-1:0] hblen, hlim, hcnt, wr_addr;
wire          fb_over, wr_over, fb_rd_bank, fb_wr_bank, ddram_keep_blank;
reg  [VW-1:0] wr_v;
reg           swap_pend, wr_bank, wr_blank;
reg           data_held;
reg  [15:0]   held_data;
wire [15:0]   write_data;

assign fb_over    = &fb_addr;
assign wr_over    = &wr_addr;
assign scr_we     = st == READ && !ddram_busy && ddram_dout_ready && !rd_wait;
assign ddram_clk  = clk;
assign ddram_burstcnt = 8'h80;
assign ddram_addr = { 4'd3, {29-4-AW{1'd0}}, act_addr };
assign write_data = data_held ? held_data : fb_din;
assign ddram_din  = { 48'd0, write_data };
assign ddram_be   = ddram_keep_blank ? 8'h00 : 8'h03;
assign nx_rd_addr = rd_addr + 1'd1;
assign fb_dout    = ddram_dout[15:0];
assign fb_rd_bank = fb_keep ? 1'b0 : ~frame;
assign fb_wr_bank = fb_keep ? 1'b0 :  frame;
assign ddram_keep_blank = fb_keep && write_data == LFBUF_CLR;

// The line RAM prefetches one word ahead. Preserve the unaccepted word
// when DDR stalls, otherwise the synchronous RAM output advances past it.
always @(posedge clk) begin
    if( rst ) begin
        data_held <= 0;
        held_data <= 0;
    end else if( st!=WRITE || !ddram_busy ) begin
        data_held <= 0;
    end else if( !data_held ) begin
        data_held <= 1;
        held_data <= fb_din;
    end
end

always @(posedge clk) begin
    case( st_addr[3:0] )
        0: st_dout <= { 2'd0, ddram_we, ddram_rd, 2'd0, st };
        1: st_dout <= { 3'd0, frame, fb_done, ddram_dout_ready, ddram_busy, line };
        2: st_dout <= fb_din[7:0];
        3: st_dout <= fb_din[15:8];
        4: st_dout <= ddram_din[7:0];
        5: st_dout <= ddram_din[15:8];
        6: st_dout <= ddram_dout[7:0];
        7: st_dout <= ddram_dout[15:8];
        8: st_dout <= ln_v[7:0];
        9: st_dout <= vrender[7:0];
        default: st_dout <= 0;
    endcase
end

always @( posedge clk ) begin
    if( rst ) begin
        hblen  <= 0;
        hlim   <= 0;
        hcnt   <= 0;
        lhbl_l <= 0;
    end else if(pxl_cen) begin
        lhbl_l  <= lhbl;
        hcnt    <= hcnt+1'd1;
        if( ~lhbl & lhbl_l ) begin // enters blanking
            hcnt   <= 0;
            hlim   <= hcnt - hblen; // H limit below which we allow do_wr events
        end
        if( lhbl & ~lhbl_l ) begin // leaves blanking
            hblen <= hcnt;
        end
    end
end

// A frame bank must not become visible until all writes and clearing finish.
assign fb_busy = swap_pend || do_wr || st==WRITE || fb_clr;

always @( posedge clk ) begin
    if( rst ) begin
        ddram_we <= 0;
        ddram_rd <= 0;
        fb_addr  <= 0;
        wr_addr  <= 0;
        fb_clr   <= 0;
        fb_done  <= 0;
        act_addr <= 0;
        rd_addr  <= 0;
        line     <= 0;
        rd_wait  <= 0;
        ln_done_l<= 0;
        wr_v     <= 0;
        do_wr    <= 0;
        swap_pend<= 0;
        wr_bank  <= 0;
        wr_blank <= 0;
        st       <= IDLE;
    end else begin
        fb_done <= 0;
        ln_done_l <= ln_done;
        // swap line buffers as soon as the core finishes a line, and copy
        // the finished one to DDR while the next line is being drawn
        if (ln_done && !ln_done_l) swap_pend <= 1;
        if ((swap_pend || (ln_done && !ln_done_l)) && !do_wr && st!=WRITE && !fb_clr) begin
            swap_pend <= 0;
            line      <= ~line;
            wr_v      <= ln_v;
            wr_bank   <= fb_wr_bank;
            wr_blank  <= fb_blank;
            do_wr     <= 1;
            fb_done   <= 1;
        end
        if( fb_clr ) begin
            // the line is cleared outside the state machine so a
            // read operation can happen independently
            fb_addr <= fb_addr + 1'd1;
            if( fb_over ) begin
                fb_clr  <= 0;
            end
        end
        case( st )
            IDLE: begin
                ddram_we <= 0;
                ddram_rd <= 0;
                rd_wait  <= 0;
                if( lhbl_l & ~lhbl ) begin
                    act_addr <= { fb_rd_bank, vrender, {HW{1'd0}}  };
                    ddram_rd <= 1;
                    rd_addr  <= 0;
                    rd_wait  <= 1;
                    st       <= READ;
                end else if( do_wr && wr_blank ) begin
                    // Already acknowledged at the swap. Discard blank-line
                    // pixels and clear this buffer before it is reused.
                    do_wr    <= 0;
                    fb_addr  <= 0;
                    fb_clr   <= 1;
                end else if( do_wr && !fb_clr &&
                    hcnt<hlim && lhbl ) begin // do not start too late so it doesn't run over H blanking
                    fb_addr  <= 1;
                    wr_addr  <= 0;
                    act_addr <= { wr_bank, wr_v, {HW{1'd0}}  };
                    ddram_we <= 1;
                    do_wr    <= 0;
                    st       <= WRITE;
                end
            end
            READ: if(!ddram_busy) begin
                ddram_rd <= 0;
                if( rd_wait ) begin
                    if( !ddram_dout_ready ) begin
                        rd_wait <= 0;
                    end
                end else if( ddram_dout_ready ) begin
                    rd_addr <= nx_rd_addr;
                    if( &rd_addr ) begin
                        st <= IDLE;
                    end else if( &rd_addr[6:0] ) begin
                        act_addr[HW-1:0] <= nx_rd_addr;
                        ddram_rd <= 1;
                        rd_wait <= 1;
                    end
                end
            end
            WRITE: if(!ddram_busy) begin
                if( &wr_addr[6:0] ) begin
                    act_addr[HW-1:7] <= act_addr[HW-1:7]+1'd1;
                end
                wr_addr <= wr_addr + 1'd1;
                fb_addr <= fb_addr + 1'd1;
                if( wr_over ) begin
                    ddram_we <= 0;
                    fb_addr  <= 0;
                    fb_clr   <= 1;
                    st       <= IDLE;
                end
            end
            default: st <= IDLE;
        endcase
    end
end

endmodule
