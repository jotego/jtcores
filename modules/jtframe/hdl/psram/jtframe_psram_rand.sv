/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2022 */

// Random access controller for PSRAM
// Designed for Alliance Memory AS1C8M16PL-70BIN
// The memory has 70ns random access time -> 14.2MHz
// This is enough to produce two accesses per pixel
// in most retro systems wher the pixel clock is less than 7 MHz

module jtframe_psram_rand#( parameter
                        CLK96 = 0   // assume 48-ish MHz operation by default
) (
    input               rst,
    input               clk,
    input       [ 23:1] addr,       // 8 M x 16 bit = 16 MByte
    input       [ 15:0] din,
    output reg  [ 15:0] dout,
    input       [  1:0] dsn,
    input               cs,
    input               we,
    output reg          ok,
    // PSRAM chip 0
    output              psram_clk,
    output              psram_cre,
    output reg [   1:0] psram_cen,
    output reg [ 21:16] psram_addr,
    inout      [  15:0] psram_adq,
    output reg [   1:0] psram_dsn,
    output reg          psram_oen,
    output reg          psram_wen
);

reg  [1:0] cen_cnt=0;
reg        cen, st;
reg [15:0] adq_reg;

// simulators don't like inout signals inside always blocks
assign psram_adq = adq_reg;

// go with default, asynchronous access
assign psram_cre  = 0;
assign psram_clk  = 0;

// clock enable signal at 24 MHz
always @(posedge clk) begin
    cen_cnt <= cen_cnt + 1'd1;
    cen     <= CLK96 ? cen_cnt==0 : cen_cnt[0];
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ok <= 0;
    end else begin
        if( !cs )
            ok <= 0;
        else if( cen ) ok <= st;
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st         <= 0;
        adq_reg    <= 16'hzzzz;
        dout       <= 0;
        psram_addr <= 0;
    end else if(cen) begin
        st <= cs ? ~st : 0;
        if( cs ) begin
            psram_cen  <= addr[23] ? 2'b10 : 2'b01;
            psram_addr <= addr[22:17];
            adq_reg    <= !st ? addr[16:1] : we ? din : 16'hzzzz;
            psram_dsn  <= we ? dsn : 2'd0;
            psram_oen  <= ~(st & ~we & cs);
            psram_wen  <= ~(st &  we & cs);
            if( st & ~we ) dout <= psram_adq;
        end else begin
            psram_cen <= 3;
            psram_dsn <= 3;
            psram_oen <= 1;
            psram_wen <= 1;
            adq_reg   <= 16'hzzzz;
        end
    end
end

endmodule