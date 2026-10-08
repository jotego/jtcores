/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-4-2026 */

module jtcps3_sound(
    input               rst,
    input               clk,
    input               cen,
    // SH-2 register window at 0x040E0000-0x040E02FF
    input               snd_cs,
    input       [ 9:1]  cpu_addr,
    input       [31:0]  cpu_dout,
    input               cpu_rnw,
    input       [ 3:0]  cpu_we_n,
    output      [31:0]  cpu_din,
    // Sample ROM bus placeholder from sound.md (`SND_A`, `SND_AD`)
    output reg          rom_cs,
    output reg  [23:0]  rom_addr,
    input       [ 7:0]  rom_data,
    input               rom_ok,
    // Mixed PCM output placeholder
    output reg signed [15:0] snd_left,
    output reg signed [15:0] snd_right
);

localparam [23:0] OFFSET =  24'h400000;

localparam [7:0] VOICE_LAST = 8'h7f;
localparam [7:0] KEY_ADDR   = 8'h80;
localparam [7:0] REG_LAST   = 8'hbf;

localparam [8:0] PRIV_BASE  = 9'h100;
localparam [4:0] ST_REG1    = 5'd0;
localparam [4:0] ST_REG2    = 5'd1;
localparam [4:0] ST_REG3    = 5'd2;
localparam [4:0] ST_REG4    = 5'd3;
localparam [4:0] ST_REG5    = 5'd4;
localparam [4:0] ST_REG7    = 5'd5;
localparam [4:0] ST_POS     = 5'd6;
localparam [4:0] ST_FRAC    = 5'd7;
localparam [4:0] ST_FETCH   = 5'd9;
localparam [4:0] ST_SAMPLE  = 5'd10;
localparam [4:0] ST_MIX     = 5'd11;
localparam [4:0] ST_ACC     = 5'd12;
localparam [4:0] ST_WPOS    = 5'd20;
localparam [4:0] ST_WFRAC   = 5'd21;
localparam [4:0] ST_NEXT    = 5'd23;
localparam [8:0] SYNC_LAST  = 9'd383;

wire [7:0] reg_addr    = cpu_addr[9:2];
wire       mmr_cs      = snd_cs && (reg_addr <= REG_LAST);
wire       mmr_wr      = mmr_cs && ~cpu_rnw;
wire       key_wr      = mmr_wr && (reg_addr == KEY_ADDR);
wire [31:0] cpu_q, cfg_q;
wire [31:0] cpu_dout16 = cpu_addr[1] ? { 16'd0, cpu_dout[15:0] } :
                                      { cpu_dout[15:0], 16'd0 };
wire [31:0] cpu_q16    = { 16'd0, cpu_addr[1] ? cpu_q[15:0] : cpu_q[31:16] };
wire [ 3:0] cpu_we16   = cpu_addr[1] ? { 2'b00, ~cpu_we_n[1:0] } :
                                      { ~cpu_we_n[1:0], 2'b00 };
wire [3:0] cpu_we      = mmr_wr ? cpu_we16 : 4'd0;
wire [3:0] cpu_we_regs = ((reg_addr == KEY_ADDR) || (reg_addr > REG_LAST)) ? 4'd0 : cpu_we;
wire [10:2] cpu_ram_addr = { 1'd0, cpu_addr[9:2] };

reg  [ 3:0] voice;
reg  [ 4:0] st;
reg  [15:0] key_bitmap, key_rst;
reg         voice_on, loop_en, voice_play;
reg         key_wr_l;
reg         cen_alt;
reg  [ 4:0] sync_pending;
wire [ 4:0] next_up, next_down;
reg  [ 8:0] sync_cnt;
reg  [31:0] key_dout_l;
reg  [ 3:0] key_we_l;
reg  [23:0] start, end_addr, loop_addr;
reg  [15:0] step;
reg  signed [15:0] vol_l, vol_r;
reg  [31:0] pos_nx, frac_nx;
reg  signed [ 7:0] sample;
reg  signed [27:0] acc_l, acc_r;
reg  signed [23:0] mux_l, mux_r, pre_l, pre_r;
wire [10:2] cfg_addr;
wire [31:0] cfg_data;
wire [ 3:0] cfg_we;
wire        fsm_step   = cen_alt;
wire        sync_pulse = cen && (sync_cnt == SYNC_LAST);
wire        sync_ready = sync_pending!=0 || sync_pulse;

function [10:2] voice_reg_addr;
    input [3:0] ch;
    input [2:0] regnum;
begin
    voice_reg_addr = { 2'd0, ch, regnum };
end
endfunction

function [10:2] voice_pos_addr;
    input [3:0] ch;
begin
    voice_pos_addr = { PRIV_BASE[8:5], ch, 1'b0 };
end
endfunction

function [10:2] voice_frac_addr;
    input [3:0] ch;
begin
    voice_frac_addr = { PRIV_BASE[8:5], ch, 1'b1 };
end
endfunction

function signed [15:0] sat16;
    input signed [27:0] din;
    reg   signed [27:0] scaled;
begin
    scaled = din >>> 8;
    if( scaled > 28'sd32767 ) begin
        sat16 = 16'sh7fff;
    end else if( scaled < -28'sd32768 ) begin
        sat16 = -16'sh8000;
    end else begin
        sat16 = scaled[15:0];
    end
end
endfunction

function [23:0] decode_addr24;
    input [31:0] din;
    reg   [31:0] full_addr, offs_addr;
begin
    full_addr    = { din[15:0], din[31:16] };
    offs_addr     = full_addr - { 8'd0, OFFSET };
    decode_addr24 = offs_addr[23:0];
end
endfunction

assign next_up   = &sync_pending ? sync_pending      : sync_pending + 1'd1;
assign next_down = |sync_pending ? sync_pending-1'd1 : sync_pending;

assign cfg_addr = (st == ST_REG1 ) ? voice_reg_addr ( voice, 3'd1 ) :
                  (st == ST_REG2 ) ? voice_reg_addr ( voice, 3'd2 ) :
                  (st == ST_REG3 ) ? voice_reg_addr ( voice, 3'd3 ) :
                  (st == ST_REG4 ) ? voice_reg_addr ( voice, 3'd4 ) :
                  (st == ST_REG5 ) ? voice_reg_addr ( voice, 3'd5 ) :
                  (st == ST_REG7 ) ? voice_reg_addr ( voice, 3'd7 ) :
                  (st == ST_POS  ) ? voice_pos_addr ( voice       ) :
                  (st == ST_FRAC ) ? voice_frac_addr( voice       ) :
                  (st == ST_WPOS ) ? voice_pos_addr ( voice       ) :
                  (st == ST_WFRAC) ? voice_frac_addr( voice       ) :
                                     voice_reg_addr ( voice, 3'd1 );

assign cfg_data = (st == ST_WPOS ) ? pos_nx  :
                  (st == ST_WFRAC) ? frac_nx :
                                     32'd0;

assign cfg_we   = (fsm_step && (st == ST_WPOS )) ? 4'hf :
                  (fsm_step && (st == ST_WFRAC)) ? 4'hf :
                                                   4'd0;

assign cpu_din  = mmr_cs ? (reg_addr == KEY_ADDR ? { 16'd0, cpu_addr[1] ? 16'd0 : key_bitmap } : cpu_q16) : 32'd0;

jtframe_dual_ram32 #(
    .AW(11)
) u_regs(
    // CPU access
    .clk0   ( clk         ),
    .data0  ( cpu_dout16   ),
    .addr0  ( cpu_ram_addr ),
    .we0    ( cpu_we_regs ),
    .q0     ( cpu_q       ),
    // sound generator access
    .clk1   ( clk         ),
    .data1  ( cfg_data    ),
    .addr1  ( cfg_addr    ),
    .we1    ( cfg_we      ),
    .q1     ( cfg_q       )
);

always @* begin
    pre_l = sample * vol_l;
    pre_r = sample * vol_r;
end

reg [15:0] key_nx;

always @* begin
    key_nx = key_bitmap;
    if( key_wr_l ) begin
        if( key_we_l[2] ) key_nx[ 7:0] = key_dout_l[23:16];
        if( key_we_l[3] ) key_nx[15:8] = key_dout_l[31:24];
    end
end

// Consumed at ST_FETCH
reg [31:0] pos_step_c;
reg [31:0] frac_base_c;
reg [23:0] abs_addr_c;
reg        at_end_c;
reg [31:0] pos_work_c;
reg        play_now_c;

always @* begin
    pos_step_c  = pos_nx + (frac_nx >> 12);
    frac_base_c = { 20'd0, frac_nx[11:0] };
    abs_addr_c  = start + pos_step_c[23:0];
    at_end_c    = (abs_addr_c >= end_addr);
    pos_work_c  = pos_step_c;
    play_now_c  = 1'b0;

    if( voice_on ) begin
        if( at_end_c ) begin
            if( loop_en ) begin
                pos_work_c = pos_step_c + { 8'd0, loop_addr } - { 8'd0, end_addr };
                abs_addr_c = start + pos_work_c[23:0];
                play_now_c = 1'b1;
            end
        end else begin
            play_now_c = 1'b1;
        end
    end
end

always @(posedge clk) begin
    if( rst ) begin
        voice        <= 4'd0;
        st           <= ST_REG1;
        voice_on     <= 1'b0;
        loop_en      <= 1'b0;
        voice_play   <= 1'b0;
        start        <= 24'd0;
        end_addr     <= 24'd0;
        loop_addr    <= 24'd0;
        rom_addr     <= 24'd0;
        rom_cs       <= 1'd0;
        step         <= 16'd0;
        vol_l        <= 16'sd0;
        vol_r        <= 16'sd0;
        pos_nx       <= 32'd0;
        frac_nx      <= 32'd0;
        sample       <= 8'sd0;
        acc_l        <= 28'sd0;
        acc_r        <= 28'sd0;
        snd_left     <= 16'sd0;
        snd_right    <= 16'sd0;
        key_bitmap   <= 16'd0;
        key_rst      <= 16'd0;
        key_wr_l     <= 1'b0;
        cen_alt      <= 1'b0;
        sync_pending <= 0;
        sync_cnt     <= 9'd0;
        key_dout_l   <= 32'd0;
        key_we_l     <= 4'd0;
    end else begin
        cen_alt   <= ~cen_alt;
        key_wr_l  <= key_wr;
        key_dout_l<= cpu_dout16;
        key_we_l  <= cpu_we;
        key_rst   <= key_rst | (~key_bitmap & key_nx);
        key_bitmap<= key_nx;

        if( cen ) begin
            if( sync_pulse ) begin
                sync_cnt     <= 9'd0;
                sync_pending <= next_up;
            end else begin
                sync_cnt <= sync_cnt + 9'd1;
            end
        end

        if( fsm_step ) case( st )
            ST_REG1: begin
                start <= decode_addr24(cfg_q);
                st    <= ST_REG2;
            end
            ST_REG2: begin
                loop_en <= cfg_q[0];
                st      <= ST_REG3;
            end
            ST_REG3: begin
                step            <= cfg_q[31:16];
                loop_addr[15:0] <= cfg_q[15:0];
                st              <= ST_REG4;
            end
            ST_REG4: begin
                loop_addr <= decode_addr24({ loop_addr[15:0], cfg_q[15:0] });
                st        <= ST_REG5;
            end
            ST_REG5: begin
                end_addr <= decode_addr24(cfg_q);
                st       <= ST_REG7;
            end
            ST_REG7: begin
                vol_l <= cfg_q[15:0];
                vol_r <= cfg_q[31:16];
                st    <= ST_POS;
            end
            ST_POS: begin
                if( key_rst[voice] ) begin
                    pos_nx <= 32'd0;
                end else begin
                    pos_nx <= cfg_q;
                end
                st <= ST_FRAC;
            end
            ST_FRAC: begin
                voice_on   <= key_nx[voice];
                if( key_rst[voice] ) begin
                    frac_nx        <= 32'd0;
                    key_rst[voice] <= 1'b0;
                end else begin
                    frac_nx <= cfg_q;
                end
                st <= ST_FETCH;
            end
            ST_FETCH: begin
                rom_addr   <= abs_addr_c;
                rom_cs     <= play_now_c;
                pos_nx     <= pos_work_c;
                voice_play <= play_now_c;
                if( play_now_c ) begin
                    frac_nx <= frac_base_c + { 16'd0, step };
                end else begin
                    frac_nx <= frac_base_c;
                end
                st <= ST_SAMPLE;
            end
            ST_SAMPLE: begin
                if( !voice_play ) begin
                    rom_cs <= 1'b0;
                    sample <= 8'd0;
                    st     <= ST_MIX;
                end else if( rom_ok ) begin
                    rom_cs <= 1'b0;
                    sample <= rom_data;
                    st     <= ST_MIX;
                end
            end
            ST_MIX: begin
                mux_l <= pre_l;
                mux_r <= pre_r;
                st    <= ST_ACC;
            end
            ST_ACC: begin
                if( voice != 4'd0 || sync_ready ) begin
                    if( voice == 4'd0 ) begin
                        snd_left  <= sat16(acc_l);
                        snd_right <= sat16(acc_r);
                        acc_l     <= { {4{mux_l[23]}}, mux_l };
                        acc_r     <= { {4{mux_r[23]}}, mux_r };
                        sync_pending <= next_down;
                    end else begin
                        acc_l <= acc_l + { {4{mux_l[23]}}, mux_l };
                        acc_r <= acc_r + { {4{mux_r[23]}}, mux_r };
                    end
                    st <= ST_WPOS;
                end
            end
            ST_WPOS : st <= ST_WFRAC;
            ST_WFRAC: st <= ST_NEXT;
            default: begin
                voice <= voice + 4'd1;
                st    <= ST_REG1;
            end
        endcase
    end
end

endmodule
