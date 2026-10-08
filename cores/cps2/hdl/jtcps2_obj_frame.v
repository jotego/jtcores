/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-1-2021 */


module jtcps2_obj_frame(
    input              rst,
    input              clk,
    input              pxl_cen,

    input      [ 8:0]  vdump,
    input              LVBL,
    input              obank,

    // Interface with SDRAM for ORAM data
    output     [12:0]  oram_addr,
    output             oram_clr,
    output             oram_cs,
    input              oram_ok,

    // Interface with ORAM frame buffer
    output reg         oframe_we,
    output reg         obank_frame
);

localparam W=5;

wire         frame, frame_edge;
reg          wtok, last_frame;
reg          done;
reg  [ 11:0] oram_cnt;
reg  [W-1:0] line_cnt;
reg          wrbank;

assign frame      = vdump==0;
assign frame_edge = frame && !last_frame;
assign oram_addr  = { obank, oram_cnt };
assign oram_clr   = done;
assign oram_cs    = ~done;

always @(posedge clk, posedge rst ) begin
    if( rst ) begin
        obank_frame <= 0;
    end else begin
        last_frame <= frame;
        if( frame_edge )
            obank_frame <= ~obank_frame;
    end
end

always @(posedge clk, posedge rst ) begin
    if( rst ) begin
        done        <= 0;
        oram_cnt    <= 0;
        line_cnt    <= 0;
        oframe_we   <= 0;
        wtok        <= 1;
    end else begin
        if( vdump==9'h40 ) done <= 0;

        if( done ) begin
            oram_cnt    <= 0;
            line_cnt    <= 0;
            oframe_we   <= 0;
            wtok        <= 1;
        end else begin
            if( oram_ok && line_cnt[0] ) begin
                wtok <= 0;
                oframe_we <= oram_ok & wtok;
            end else begin
                oframe_we <= 0;
            end

            if( pxl_cen & ~&line_cnt & ~done) begin
                if( line_cnt == 'h10 ) begin
                    line_cnt <= 0;
                    wtok     <= 1;
                    { done, oram_cnt } <= { 1'b0, oram_cnt }+1'b1;
                end else begin
                    line_cnt <= line_cnt+1'b1;
                end
            end
        end
    end
end

`ifdef SIMULATION
initial begin
    oram_cnt = 0;
    line_cnt = 0;
end
`endif

endmodule