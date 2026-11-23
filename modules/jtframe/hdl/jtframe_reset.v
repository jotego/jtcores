/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-12-2020 */

module jtframe_reset(
    input       clk_sys,
    input       clk_rom,
    input       pxl_cen,

    input       sdram_init,
    input       ioctl_rom,
    input       dwnld_busy, // the game leaves reset only after a first download
    input       dip_flip,
    input       soft_rst,
    input       rst_req,
    input       pll_locked,

    // clk_sys:
    output  reg rst,
    output  reg rst_n,
    // clk_rom:
    output  reg game_rst,
    output  reg game_rst_n
);

localparam MAIN_RSTW = 4,
           GAME_RSTW = 8;

reg [MAIN_RSTW-1:0] rst_cnt;
reg [GAME_RSTW-1:0] game_rst_cnt;
reg [MAIN_RSTW-1:0] rst_rom; // rst in clk_rom domain
reg                 rst_rom_sync;
reg [1:0]           rst_req_sync;
reg                 loaded=0, busy_l=0;

always @(posedge clk_sys, negedge pll_locked) begin
    if( !pll_locked ) begin
        rst_cnt <= {MAIN_RSTW{1'b1}};
        rst     <= 1;
        rst_n   <= 0;
    end else begin
        rst_cnt <= rst_cnt >> 1;
        if( !rst_cnt[0] ) begin
            rst     <= 0;
            rst_n   <= 1;
        end
    end
end

`ifdef JTFRAME_FLIP_RESET
    reg last_dip_flip, rst_flip;
    always @(posedge clk_sys) begin
        last_dip_flip <= dip_flip;
        rst_flip      <= last_dip_flip!=dip_flip;
    end
`else
    wire rst_flip = 0;
`endif

// Game reset generation
always @(posedge clk_sys ) rst_req_sync <= { rst_req_sync[0], rst_req };

// The SDRAM holds stale data until the first ROM download ends. A game running
// from it would leave random RAM and register contents, which the game reset
// does not clear. On MiSTer, the core runs for a variable time after the FPGA is
// programmed, before the HPS starts the download.
always @(posedge clk_sys ) begin
    busy_l <= dwnld_busy;
    if( busy_l && !dwnld_busy ) loaded <= 1;
end

always @(posedge clk_sys ) begin
    if( ioctl_rom | rst | rst_req_sync[1] | !loaded
    | rst_flip | soft_rst | sdram_init)
        rst_rom <= {MAIN_RSTW{1'b1}};
    else if(pxl_cen) begin
        rst_rom <= rst_rom >> 1;
    end
end

always @(negedge clk_rom) begin
    rst_rom_sync <= rst_rom[0];
end

always @(negedge clk_rom) begin
    if( rst_rom_sync ) begin
        game_rst_cnt   <= {GAME_RSTW{1'b1}};
        game_rst_n     <= 0;
        game_rst       <= 1;
    end else begin
        if( game_rst_cnt[0] ) begin
            game_rst_cnt <= game_rst_cnt >> 1;
            game_rst_n   <= 0;
            game_rst     <= 1;
        end else begin
            game_rst_n <= 1;
            game_rst   <= 0;
        end
    end
end

endmodule