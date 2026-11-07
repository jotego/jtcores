/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-4-2026 */

module jtcps3_paldma(
    input               rst,
    input               clk,

    // MMR registers
    input       [31:0]  src,
    input       [16:0]  dst,
    input       [31:0]  fade,
    input       [15:0]  len,
    input               len_hi,
    input               go,

    // Source memory
    output reg          src_rd,
    output reg  [25:1]  src_addr,
    input       [15:0]  src_dout,
    input               src_ok,

    // Destination memory
    output reg  [17:1]  dst_addr,
    output reg  [15:0]  dst_din,
    output reg  [ 1:0]  dst_we,

    output reg          busy,
    output reg          done
);

localparam [1:0] ST_IDLE  = 2'd0,
                 ST_READ  = 2'd1,
                 ST_WRITE = 2'd2,
                 ST_DONE  = 2'd3;
reg  [ 1:0] state;
reg         go_l, ok_l;
reg  [24:0] src_base, src_pos;
reg  [16:0] dst_base, dst_pos;
reg  [16:0] dma_len;
reg  [31:0] fade_l;
reg  [15:0] src_data_l;
wire        data_rdy = src_ok & ~ok_l;

function [4:0] fade_chan;
    input [4:0] c;
    input [6:0] f;
    reg   [9:0] mul;
    begin
        mul       = c * f[4:0]; // default value to prevent latch warning
        fade_chan = c;
        if( f[6] ) begin
            if( f[5] ) begin
                mul = (10'd31 - {5'd0,c}) * (10'd31 - {5'd0,f[4:0]});
                fade_chan = 5'd31 - mul[9:5];
            end else begin
                mul = c * f[4:0];
                fade_chan = mul[9:5];
            end
        end
    end
endfunction

function [15:0] apply_fade;
    input [15:0] colour;
    input [31:0] fade_cfg;
    reg   [4:0] r, g, b;
    begin
        r = fade_chan(colour[ 4: 0], fade_cfg[30:24]);
        g = fade_chan(colour[ 9: 5], fade_cfg[22:16]);
        b = fade_chan(colour[14:10], fade_cfg[ 6: 0]);
        apply_fade = { colour[15], b, g, r };
    end
endfunction

always @(posedge clk) begin
    if( rst ) begin
        state      <= ST_IDLE;
        go_l       <= 1'b0;
        ok_l       <= 1'b0;
        src_base   <= 25'd0;
        src_pos    <= 25'd0;
        dst_base   <= 17'd0;
        dst_pos    <= 17'd0;
        dma_len    <= 17'd0;
        fade_l     <= 32'd0;
        src_data_l <= 16'd0;
        src_rd     <= 1'b0;
        src_addr   <= 25'd0;
        dst_addr   <= 17'd0;
        dst_din    <= 16'd0;
        dst_we     <= 2'd0;
        busy       <= 1'b0;
        done       <= 1'b0;
    end else begin
        go_l   <= go;
        ok_l   <= src_ok;
        src_rd <= 1'b0;
        dst_we <= 2'd0;
        done   <= 1'b0;

        case( state )
            ST_IDLE: begin
                busy <= 1'b0;
                if( go_l ) begin
                    if( {len_hi, len} == 17'd0 ) begin
                        done <= 1'b1;
                    end else begin
                        // CPS3 stores palette DMA sources in the contiguous
                        // m_user5 gfx stream. jtcps3_game maps that logical
                        // address to the physical SDRAM layout.
                        src_base <= src[24:0] - 25'h0200000;
                        dst_base <= dst;
                        dma_len  <= {len_hi, len};
                        fade_l   <= fade;
                        src_pos  <= 25'd0;
                        dst_pos  <= 17'd0;
                        busy     <= 1'b1;
                        state    <= ST_READ;
                    end
                end
            end

            ST_READ: begin
                src_rd   <= 1'b1;
                src_addr <= (src_base + src_pos) ^ 25'd1;
                if( data_rdy ) begin
                    src_data_l <= src_dout;
                    state      <= ST_WRITE;
                end
            end

            ST_WRITE: begin
                dst_addr <= (dst_base + dst_pos) ^ 17'd1;
                dst_din  <= apply_fade(src_data_l, fade_l);
                dst_we   <= 2'b11;

                if( dst_pos + 17'd1 >= dma_len ) begin
                    state <= ST_DONE;
                end else begin
                    src_pos <= src_pos + 25'd1;
                    dst_pos <= dst_pos + 17'd1;
                    state   <= ST_READ;
                end
            end

            ST_DONE: begin
                busy  <= 1'b0;
                done  <= 1'b1;
                state <= ST_IDLE;
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule
