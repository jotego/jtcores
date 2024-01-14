/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-11-2022 */

module jtframe_lfbuf_ctrl #(parameter
    CLK96   =   0,   // assume 48-ish MHz operation by default
    VW      =   8,
    HW      =   9
)(
    input               rst,    // hold in reset for >150 us
    input               clk,
    input               pxl_cen,

    input               lhbl,
    input               vs,
    input               ln_done,
    input      [VW-1:0] vrender,
    input      [VW-1:0] ln_v,
    // data written to external memory
    input               frame,
    output reg [HW-1:0] fb_addr,
    input      [  15:0] fb_din,
    output reg          fb_clr,
    output reg          fb_done,

    // data read from external memory to screen buffer
    // during h blank
    output     [  15:0] fb_dout,
    output reg [HW-1:0] rd_addr,
    output reg          line,
    output              scr_we,

    // cell RAM (PSRAM) signals
    output reg [ 21:16] cr_addr,
    inout      [  15:0] cr_adq,
    input               cr_wait,
    output              cr_clk,
    output reg          cr_advn,
    output reg          cr_cre,
    output     [   1:0] cr_cen, // chip enable
    output reg          cr_oen,
    output reg          cr_wen,
    output     [   1:0] cr_dsn
);

localparam [3:0] INIT       = { 3'd0, 1'd0 },
                 IDLE       = { 3'd1, 1'd0 },
                 WRITE_ADDR = { 3'd2, 1'd0 },
                 WRITEOUT   = { 3'd2, 1'd1 },
                 READ_ADDR  = { 3'd4, 1'd0 },
                 READIN     = { 3'd4, 1'd1 };

localparam AW = HW+VW;

localparam [21:0] BUS_CFG = {
    2'd0, // reserved
    2'd2, // bus configuration register
    2'd0, // reserved
    1'b0, // synchronous burst access
    1'b0, // variable latency
    3'd3, // default latency counter
    1'b0, // wait is active high
    1'b0, // reserved
    1'b0, // 1=wait set 1 clock ahead of data
    2'd0, // reserved
    2'd1, // drive strength (default)
    1'b1, // no burst wrap
    3'd7  // continuous burst
}, REF_CFG = {
    2'd0, // reserved
    2'd0, // refresh configuration register
    13'd0, // reserved
    1'b1, // deep power power down disabled
    1'd0, // reserved
    3'b100 // array not refreshed
    // 1'b1, // use bottom half of the array (or all of it)
    // AW == 21 ? 2'd0 : // full array    (4096 x 16 bits = 64Mbit per chip half)
    // AW == 20 ? 2'd1 : // half the array(2048 x 16 bits)
    // AW == 19 ? 2'd2 : // 1/4 the array (1024 x 16 bits)
    //            2'd3   // 1/8 the array (512k x 16 bits)
};

reg    [ 3:0] st;
reg    [ 4:0] cntup; // use a larger count to capture data using Signal Tap
wire   [ 7:0] vram; // current row (v) being processed through the external RAM
reg    [15:0] adq_reg;
reg  [HW-1:0] hblen, hlim, hcnt, wr_addr;
reg           lhbl_l, do_wr, wait1,
              csn, ln_done_l, vsl, startup;
wire          fb_over;
wire          wring;

`ifdef SIMULATION
wire   rding   = st[3]; `endif
assign wring   = st[2];
assign cr_cen  = { 1'b1, csn }; // I call it csn to avoid the confusion with the common cen (clock enable) signal
assign cr_dsn  = 0;
assign fb_dout =  cr_oen ? 16'd0 : cr_adq;
assign cr_adq  = !cr_advn ? adq_reg : !cr_oen ? 16'hzzzz : fb_din;
assign cr_clk  = clk;
assign fb_over = &fb_addr;
assign vram    = lhbl ? ln_v : vrender;
assign scr_we  = cr_wait & ~cr_oen;

always @( posedge clk, posedge rst ) begin
    if( rst ) begin
        hblen  <= 0;
        hlim   <= 0;
        hcnt   <= 0;
        lhbl_l <= 0;
        vsl    <= 0;
        cntup  <= 0;
        startup<= 0;
    end else if(pxl_cen) begin
        lhbl_l  <= lhbl;
        vsl     <= vs;
        hcnt    <= hcnt+1'd1;
        startup <= &cntup;
        if( ~lhbl & lhbl_l ) begin // enters blanking
            hcnt   <= 0;
            hlim   <= hcnt - hblen; // H limit below which we allow do_wr events
        end
        if( lhbl & ~lhbl_l ) begin // leaves blanking
            hblen <= hcnt;
        end
        if( vs & ~vsl & ~&cntup ) cntup <= cntup+1'd1;
    end
end

always @( posedge clk, posedge rst ) begin
    if( rst ) begin
        do_wr <= 0;
    end else begin
        ln_done_l <= ln_done;
        if( ln_done & ~ln_done_l    ) do_wr <= 1;
        if( st==WRITEOUT && fb_over ) do_wr <= 0;
    end
end

reg [4:0] init_seq[0:15];
reg [4:0] init_cnt;

initial begin
    //                cen,  cre, advn,  oen,  wen
    init_seq[ 0] =  { 1'b1, 1'b1, 1'b1, 1'b1, 1'b1 };
    init_seq[ 1] =  { 1'b0, 1'b1, 1'b0, 1'b1, 1'b1 };  // latch address
    init_seq[ 2] =  { 1'b0, 1'b0, 1'b1, 1'b1, 1'b1 };
    init_seq[ 3] =  { 1'b0, 1'b0, 1'b1, 1'b1, 1'b0 };  // write starts
    init_seq[ 4] =  { 1'b0, 1'b0, 1'b1, 1'b1, 1'b0 };
    init_seq[ 5] =  { 1'b0, 1'b0, 1'b1, 1'b1, 1'b0 };  // cfg written
    //                cen,  cre, advn,  oen,  wen
    init_seq[ 6] =  { 1'b1, 1'b0, 1'b1, 1'b1, 1'b1 }; // read
    init_seq[ 7] =  { 1'b0, 1'b0, 1'b0, 1'b1, 1'b1 };
    init_seq[ 8] =  { 1'b0, 1'b0, 1'b1, 1'b1, 1'b1 };
    init_seq[ 9] =  { 1'b0, 1'b0, 1'b1, 1'b1, 1'b1 };
    init_seq[10] =  { 1'b0, 1'b0, 1'b1, 1'b0, 1'b1 };
    init_seq[11] =  { 1'b0, 1'b0, 1'b1, 1'b0, 1'b1 };
    init_seq[12] =  { 1'b0, 1'b0, 1'b1, 1'b0, 1'b1 };
    init_seq[13] =  { 1'b1, 1'b0, 1'b1, 1'b1, 1'b1 };
    //                cen,  cre, advn,  oen,  wen
    init_seq[14] =  { 1'b1, 1'b0, 1'b1, 1'b1, 1'b1 }; // idle
    init_seq[15] =  { 1'b1, 1'b0, 1'b1, 1'b1, 1'b1 };
end

always @( posedge clk, posedge rst ) begin
    if( rst ) begin
        st       <= INIT;
        cr_advn  <= 0;
        cr_oen   <= 0;
        cr_cre   <= 0;
        csn      <= 0;
        fb_addr  <= 0;
        fb_clr   <= 0;
        fb_done  <= 0;
        rd_addr  <= 0;
        line     <= 0;
        wait1    <= 0;
        init_cnt <= 0;
    end else begin
        fb_done <= 0;
        wait1   <= 0;
        cr_advn <= 1;
        if( fb_clr ) begin
            // the line is cleared outside the state machine so a
            // read operation can happen independently
            fb_addr <= fb_addr + 1'd1;
            if( fb_over ) begin
                fb_clr  <= 0;
            end
        end
        if( !startup ) begin
            csn <= 1;
        end else case( st )
            INIT: begin
                if( init_cnt==0  ) { cr_addr, adq_reg } <= REF_CFG;
                if( init_cnt==15 ) { cr_addr, adq_reg } <= BUS_CFG;
                init_cnt <= init_cnt + 1'd1;
                { csn, cr_cre, cr_advn, cr_oen, cr_wen } <= init_seq[init_cnt[3:0]];
                if( &init_cnt ) st <= IDLE;
            end
            // Wait for requests
            IDLE: begin
                csn     <= 1;
                cr_wen  <= 1;
                cr_cre  <= 0;
                adq_reg <= { vram[VW-6:0], {16+5-VW{1'b0}} };
                cr_addr <= { lhbl ^ frame, vram[VW-1-:5]  };
                if( lhbl_l & ~lhbl ) begin
                    // it doesn't matter if vrender changes after the LHBL edge
                    // is set as it is latched in { cr_addr, adq_reg }
                    csn     <= 0;
                    rd_addr <= 0;
                    cr_oen  <= 1;
                    st      <= READ_ADDR;
                end
                if( do_wr && !fb_clr &&
                    hcnt<hlim && lhbl ) begin // do not start too late so it doesn't run over H blanking
                    csn     <= 0;
                    fb_addr <= 0;
                    wr_addr <= 0;
                    cr_oen  <= 1;
                    st      <= WRITE_ADDR;
                end
            end
            WRITE_ADDR, READ_ADDR: begin
                adq_reg[HW-1:0] <= wring ? wr_addr : rd_addr;
                csn             <= 0;
                cr_advn         <= 0;
                cr_oen          <= 1;
                cr_wen          <= ~wring;
                st              <= wring ? WRITEOUT : READIN;
                wait1           <= 1; // give time to cr_wait to react
            end
            WRITEOUT: if( cr_wait && !wait1 ) begin // Write line from internal BRAM to PSRAM
                if ( ~&fb_addr ) fb_addr <= fb_addr + 1'd1;
                wr_addr <= fb_addr;
                if( &wr_addr ) begin // This violates the max 4us time, but it is ok as refresh is not required
                    st      <= IDLE;
                    csn     <= 1;
                    fb_addr <= fb_addr + 1'd1;
                    wr_addr <= wr_addr + 1'd1;
                    fb_clr  <= 1;
                    line    <= ~line;
                    fb_done <= 1;
                end
            end
            READIN: begin // Read line from PSRAM
                cr_oen <= 0;
                if( cr_wait && !wait1 ) begin
                    rd_addr <= rd_addr + 1'd1;
                    if( &rd_addr ) begin // 4us max /csn violated, but ok
                        csn    <= 1;
                        st     <= IDLE;
                    end
                end
            end
            default: st <= IDLE;
        endcase
    end
end

endmodule