/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 10-05-2026 */

module jtcps3_busmux(
    input               rst,
    input               clk,

    input       [ 2:0]  cram_bank,

    // CPU character RAM window: 0x04100000-0x041fffff
    input               main_charram_rd,
    input               main_charram_we,
    input       [19:2]  main_charram_addr,
    input       [31:0]  main_charram_din,
    input       [ 3:0]  main_charram_dsn,
    output      [31:0]  main_charram_data,
    output              main_charram_ok,
    output              main_grant,

    // Character DMA tile-store path
    input               dma_tiles_rd,
    input               dma_tiles_we,
    input       [22:2]  dma_tiles_addr,
    input       [31:0]  dma_tiles_din,
    input       [ 3:0]  dma_tiles_dsn,
    output      [31:0]  dma_tiles_data,
    output              dma_tiles_ok,
    output              dma_grant,

    // Shared tiles_wr SDRAM lane
    output reg          tiles_wr_rd,
    output reg  [22:2]  tiles_wr_addr,
    output reg          tiles_wr_we,
    output reg  [31:0]  tiles_wr_din,
    output reg  [ 3:0]  tiles_wr_dsn,
    input       [31:0]  tiles_wr_data,
    input               tiles_wr_ok
);

localparam [1:0] OWNER_NONE = 2'd0,
                 OWNER_CPU  = 2'd1,
                 OWNER_DMA  = 2'd2;

reg  [1:0] owner;
wire       cpu_req     = main_charram_rd | main_charram_we;
wire       dma_req     = dma_tiles_rd;
wire       cpu_rd_req  = main_charram_rd & ~main_charram_we;
wire       dma_rd_req  = dma_tiles_rd    & ~dma_tiles_we;
wire [22:2] cpu_addr   = { cram_bank, main_charram_addr };
wire       lane_idle   = owner == OWNER_NONE && !tiles_wr_ok;
wire [1:0] idle_owner  = cpu_req ? OWNER_CPU :
                         dma_req ? OWNER_DMA : OWNER_NONE;
wire [1:0] active_owner= owner != OWNER_NONE ? owner :
                         lane_idle ? idle_owner : OWNER_NONE;
reg        owner_done, req_rd_l, req_we_l;
reg [22:2] req_addr_l;
reg [31:0] req_din_l, data_l;
reg [ 3:0] req_dsn_l;
wire       active_done = owner != OWNER_NONE && owner_done;
wire       active_rd   = owner != OWNER_NONE ? req_rd_l   :
                         active_owner == OWNER_CPU ? cpu_rd_req       : dma_rd_req;
wire       active_we   = owner != OWNER_NONE ? req_we_l   :
                         active_owner == OWNER_CPU ? main_charram_we  : dma_tiles_we;
wire [22:2] active_addr= owner != OWNER_NONE ? req_addr_l :
                         active_owner == OWNER_CPU ? cpu_addr         : dma_tiles_addr;
wire [31:0] active_din = owner != OWNER_NONE ? req_din_l  :
                         active_owner == OWNER_CPU ? main_charram_din : dma_tiles_din;
wire [ 3:0] active_dsn = owner != OWNER_NONE ? req_dsn_l  :
                         active_owner == OWNER_CPU ? main_charram_dsn : dma_tiles_dsn;
wire       cpu_match   = cpu_req &&
                         req_rd_l   == cpu_rd_req &&
                         req_we_l   == main_charram_we &&
                         req_addr_l == cpu_addr &&
                         (!req_we_l || (req_din_l == main_charram_din &&
                                        req_dsn_l == main_charram_dsn));
wire       dma_match   = dma_req &&
                         req_rd_l   == dma_rd_req &&
                         req_we_l   == dma_tiles_we &&
                         req_addr_l == dma_tiles_addr &&
                         (!req_we_l || (req_din_l == dma_tiles_din &&
                                        req_dsn_l == dma_tiles_dsn));
wire       owner_match = owner == OWNER_CPU ? cpu_match :
                         owner == OWNER_DMA ? dma_match : 1'b0;

assign main_grant = active_owner == OWNER_CPU;
assign dma_grant  = active_owner == OWNER_DMA;

assign main_charram_data = owner_done ? data_l : tiles_wr_data;
assign dma_tiles_data    = owner_done ? data_l : tiles_wr_data;
assign main_charram_ok   = owner == OWNER_CPU && owner_done;
assign dma_tiles_ok      = owner == OWNER_DMA && owner_done;

always @(posedge clk) begin
    if (rst) begin
        owner      <= OWNER_NONE;
        owner_done <= 1'b0;
        req_rd_l   <= 1'b0;
        req_we_l   <= 1'b0;
        req_addr_l <= 21'd0;
        req_din_l  <= 32'd0;
        req_dsn_l  <= 4'hf;
        data_l     <= 32'd0;
        tiles_wr_rd   <= 1'b0;
        tiles_wr_we   <= 1'b0;
        tiles_wr_addr <= 21'd0;
        tiles_wr_din  <= 32'd0;
        tiles_wr_dsn  <= 4'hf;
    end else begin
        tiles_wr_rd   <= active_owner != OWNER_NONE && !active_done && !tiles_wr_ok ? active_rd   : 1'b0;
        tiles_wr_we   <= active_owner != OWNER_NONE && !active_done && !tiles_wr_ok ? active_we   : 1'b0;
        tiles_wr_addr <= active_owner != OWNER_NONE && !active_done && !tiles_wr_ok ? active_addr : 21'd0;
        tiles_wr_din  <= active_owner != OWNER_NONE && !active_done && !tiles_wr_ok ? active_din  : 32'd0;
        tiles_wr_dsn  <= active_owner != OWNER_NONE && !active_done && !tiles_wr_ok ? active_dsn  : 4'hf;

        if (owner == OWNER_NONE) begin
            owner_done <= 1'b0;
            if (!tiles_wr_ok) begin
                owner <= idle_owner;
                if (idle_owner == OWNER_CPU) begin
                    req_rd_l   <= cpu_rd_req;
                    req_we_l   <= main_charram_we;
                    req_addr_l <= cpu_addr;
                    req_din_l  <= main_charram_din;
                    req_dsn_l  <= main_charram_dsn;
                end else if (idle_owner == OWNER_DMA) begin
                    req_rd_l   <= dma_rd_req;
                    req_we_l   <= dma_tiles_we;
                    req_addr_l <= dma_tiles_addr;
                    req_din_l  <= dma_tiles_din;
                    req_dsn_l  <= dma_tiles_dsn;
                end
            end
        end else if (owner_done) begin
            if (!owner_match) begin
                owner      <= OWNER_NONE;
                owner_done <= 1'b0;
            end
        end else if (tiles_wr_ok) begin
            owner_done <= 1'b1;
            data_l     <= tiles_wr_data;
        end
    end
end

endmodule
