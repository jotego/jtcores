/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 3-10-2026 */

module jtnarc_vsr(
    input              rst,
    input              clk,
    input              start,
    input       [ 8:0] src,
    input       [ 8:0] dst,
    output reg         busy,
    output             idle_pt,
    input              gnt,
    output reg         flush,
    input              flush_done,
    output      [19:4] rd_addr,
    output reg         rd,
    input      [127:0] dout,
    input              rd_ok,
    output      [19:4] wr_addr,
    output reg         we,
    output     [127:0] din,
    input              we_ok,
    input              inval,
    input       [ 8:0] inval_p
);

reg  [ 8:0] xsrc, xdst;
reg  [ 6:0] col;
reg         wph, gap, bv;
reg  [ 8:0] btag;
wire        done = (rd && rd_ok) || (we && we_ok);

assign rd_addr = { xsrc, col };
assign wr_addr = { xdst, col };
assign idle_pt = busy && gap && !flush;

always @(posedge clk) begin
    if( rst ) begin
        busy  <= 0;
        flush <= 0;
        rd    <= 0;
        we    <= 0;
        col   <= 0;
        xsrc  <= 0;
        xdst  <= 0;
        wph   <= 0;
        gap   <= 0;
        bv    <= 0;
        btag  <= 0;
    end else begin
        if( start && !busy ) begin
            busy  <= 1;
            xsrc  <= src;
            xdst  <= dst;
            col   <= 0;
            wph   <= bv && btag==src;
            gap   <= 1;
            flush <= !(bv && btag==src);
            if( !(bv && btag==src) ) bv <= 0;
        end
        if( inval && inval_p==btag ) bv <= 0;
        if( busy && gnt ) begin
            if( flush ) begin
                if( flush_done ) flush <= 0;
            end else if( done ) begin
                rd  <= 0;
                we  <= 0;
                gap <= 1;
                col <= col+7'd1;
                if( &col ) begin
                    wph <= 1;
                    if( !wph ) begin
                        bv   <= 1;
                        btag <= xsrc;
                    end
                    if( wph ) busy <= 0;
                end
            end else if( gap ) begin
                gap <= 0;
                rd  <= ~wph;
                we  <=  wph;
            end
        end
    end
end

wire        buf_we = rd & rd_ok;

jtframe_dual_ram #(.DW(128),.AW(7)) u_buf(
    .clk0  ( clk    ),
    .data0 ( dout   ),
    .addr0 ( col    ),
    .we0   ( buf_we ),
    .q0    (        ),
    .clk1  ( clk    ),
    .data1 ( 128'd0 ),
    .addr1 ( col    ),
    .we1   ( 1'b0   ),
    .q1    ( din    )
);

endmodule
