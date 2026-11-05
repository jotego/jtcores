/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 5-11-2026 */

module jtymz280b(
    input                  rst,
    input                  clk,
    input                  cen,       // One pulse per YMZ master clock; engine runs on clk.
    input                  cs,
    input                  wr,
    input                  rd,
    input                  addr,
    input          [ 7:0]  din,
    output         [ 7:0]  dout,
    output                 cpu_ready, // wr/rd are single-clk strobes, accepted only when ready.
    output                 irq,
    output reg     [23:0]  rom_addr,
    output reg             rom_cs,
    output reg             rom_we,
    output reg     [ 7:0]  rom_dout,
    input          [ 7:0]  rom_data,
    input                  rom_ok,    // Hold ack/data until rom_cs falls; requests may be cancelled.
    output reg signed [15:0] snd_l,
    output reg signed [15:0] snd_r,
    output reg             sample,
    output reg             overrun
);

localparam [3:0] IDLE=0, VOICE=1, FETCH=2, WAIT_LO=3,
                 FETCH_HI=4, WAIT_HI=5, DECODE=6, ADVANCE=7,
                 MIX=8, NEXT=9, EXT_WAIT=10;

reg [3:0] state;
reg [2:0] ch;
reg [1:0] active_mode;
reg [7:0] reg_sel, status, irq_mask;
reg key_enable, irq_enable, ext_enable;
reg [7:0] divider;
reg frame_pending;
wire tick = cen && divider==191;
wire accept = cs && cpu_ready;
wire data_wr = accept && wr && addr;
wire status_rd = accept && rd && addr;
wire [2:0] cpu_ch = reg_sel[4:2];

reg [8:0] fnum [0:7];
reg [1:0] mode [0:7];
reg [7:0] level [0:7];
reg [3:0] pan [0:7];
reg [7:0] keyon, looping, playing, loop_saved;
reg [24:0] start_addr [0:7], stop_addr [0:7];
reg [24:0] loop_start [0:7], loop_end [0:7], position [0:7];
reg [9:0] phase [0:7];
reg signed [15:0] signal_data [0:7], loop_signal [0:7];
reg [14:0] step_data [0:7], loop_step [0:7];
reg signed [15:0] prev_data [0:7], curr_data [0:7];
reg [7:0] byte_lo, byte_hi;
reg signed [27:0] acc_l, acc_r, mix_l, mix_r;
reg signed [24:0] voice_l, voice_r;
reg [23:0] ext_address, ext_request;
reg [7:0] ext_hi, ext_mid, ext_latch, ext_data;
reg ext_pending, ext_write;

assign cpu_ready = !ext_pending && state!=EXT_WAIT;
assign dout = addr ? status : ext_enable ? ext_latch : 8'hff;
assign irq = irq_enable && |(status & irq_mask);

wire [3:0] nibble = position[ch][0] ? byte_lo[3:0] : byte_lo[7:4];
wire signed [15:0] decoded_signal;
wire [14:0] decoded_step;
jtymz280b_adpcm u_adpcm(
    .nibble     ( nibble           ),
    .signal_in  ( signal_data[ch]  ),
    .step_in    ( step_data[ch]    ),
    .signal_out ( decoded_signal   ),
    .step_out   ( decoded_step     )
);

wire [24:0] increment = active_mode==1 ? 25'd1 : active_mode==2 ? 25'd2 : 25'd4;
wire [25:0] advanced = {1'b0,position[ch]} + {1'b0,increment};
wire wrap_loop = looping[ch] && keyon[ch] && advanced >= {1'b0,loop_end[ch]};
wire [25:0] next_position = wrap_loop ? {1'b0,loop_start[ch]} : advanced;
wire end_voice = state==ADVANCE && next_position >= {1'b0,stop_addr[ch]};
wire [7:0] end_mask = end_voice && !data_wr ? (8'b1 << ch) : 8'd0;
wire [9:0] frequency = {1'b0,(mode[ch]==1 ? {1'b0,fnum[ch][7:0]} : fnum[ch])} + 10'd1;

reg [7:0] gain_l, gain_r;
reg [11:0] pan_product;
reg [11:0] pan_gain;
reg signed [25:0] interp_wide;
reg signed [15:0] interpolated;
reg signed [24:0] product_l, product_r;
always @* begin
    gain_l = level[ch];
    gain_r = level[ch];
    pan_product = 0;
    if(pan[ch]<8) begin
        pan_product = level[ch] * (pan[ch]==0 ? 12'd0 : {8'd0,pan[ch]}-12'd1);
    end else if(pan[ch]>8) begin
        pan_product = level[ch] * (12'd15-{8'd0,pan[ch]});
    end
    pan_gain = pan_product / 12'd7;
    if(pan[ch]<8) gain_r = pan_gain[7:0];
    else if(pan[ch]>8) gain_l = pan_gain[7:0];
    interp_wide = prev_data[ch] * $signed(11'd512-{2'd0,phase[ch][8:0]}) +
                  curr_data[ch] * $signed({2'd0,phase[ch][8:0]});
    interpolated = interp_wide[24:9];
    product_l = interpolated * $signed({1'b0,gain_l});
    product_r = interpolated * $signed({1'b0,gain_r});
end

function automatic signed [15:0] clip(input signed [27:0] value);
    reg signed [27:0] scaled;
    begin
        scaled = value >>> 9;
        clip = scaled>32767 ? 16'sh7fff : scaled < -32768 ? 16'sh8000 : scaled[15:0];
    end
endfunction

function automatic signed [15:0] decay(input signed [15:0] value);
    reg signed [20:0] magnitude;
    begin
        magnitude = $signed({{5{value[15]}},value});
        if(value[15]) magnitude = -magnitude;
        magnitude = (magnitude * 21'sd15) >>> 4;
        decay = value[15] ? -$signed(magnitude[15:0]) : $signed(magnitude[15:0]);
    end
endfunction

integer i;
always @(posedge clk) begin
    if(rst) begin
        state <= IDLE;
        ch <= 0;
        active_mode <= 0;
        divider <= 0;
        frame_pending <= 0;
        reg_sel <= 0;
        status <= 0;
        irq_mask <= 0;
        key_enable <= 0;
        irq_enable <= 0;
        ext_enable <= 0;
        keyon <= 0;
        looping <= 0;
        playing <= 0;
        loop_saved <= 0;
        rom_addr <= 0;
        rom_cs <= 0;
        rom_we <= 0;
        rom_dout <= 0;
        byte_lo <= 0;
        byte_hi <= 0;
        ext_address <= 0;
        ext_request <= 0;
        ext_hi <= 0;
        ext_mid <= 0;
        ext_latch <= 0;
        ext_data <= 0;
        ext_pending <= 0;
        ext_write <= 0;
        acc_l <= 0;
        acc_r <= 0;
        mix_l <= 0;
        mix_r <= 0;
        voice_l <= 0;
        voice_r <= 0;
        snd_l <= 0;
        snd_r <= 0;
        sample <= 0;
        overrun <= 0;
        for(i=0;i<8;i=i+1) begin
            fnum[i] <= 0;
            mode[i] <= 0;
            level[i] <= 0;
            pan[i] <= 0;
            start_addr[i] <= 0;
            stop_addr[i] <= 0;
            loop_start[i] <= 0;
            loop_end[i] <= 0;
            position[i] <= 0;
            phase[i] <= 10'd512;
            signal_data[i] <= 0;
            loop_signal[i] <= 0;
            step_data[i] <= 15'd127;
            loop_step[i] <= 15'd127;
            prev_data[i] <= 0;
            curr_data[i] <= 0;
        end
    end else begin
        sample <= tick;
        status <= (status_rd ? 8'd0 : status) | end_mask;
        if(cen) divider <= tick ? 8'd0 : divider+8'd1;
        if(tick) begin
            frame_pending <= 1;
            snd_l <= clip(mix_l);
            snd_r <= clip(mix_r);
            if(state!=IDLE || frame_pending) overrun <= 1;
        end
        if(!data_wr) case(state)
            IDLE: begin
                if(tick || frame_pending) begin
                    frame_pending <= 0;
                    ch <= 0;
                    acc_l <= 0;
                    acc_r <= 0;
                    state <= VOICE;
                end else if(ext_pending) begin
                    rom_addr <= ext_request;
                    rom_cs <= 1;
                    rom_we <= ext_write;
                    rom_dout <= ext_data;
                    state <= EXT_WAIT;
                end
            end
            VOICE: begin
                if(!playing[ch] && prev_data[ch]==0 && curr_data[ch]==0) begin
                    phase[ch] <= 10'd512;
                    voice_l <= 0;
                    voice_r <= 0;
                    state <= NEXT;
                end else if(phase[ch][9]) begin
                    phase[ch] <= phase[ch]-10'd512;
                    prev_data[ch] <= curr_data[ch];
                    if(playing[ch]) begin
                        active_mode <= mode[ch];
                        state <= FETCH;
                    end
                    else begin
                        curr_data[ch] <= decay(curr_data[ch]);
                        state <= MIX;
                    end
                end else state <= MIX;
            end
            FETCH: begin
                rom_addr <= position[ch][24:1];
                rom_cs <= 1;
                rom_we <= 0;
                state <= WAIT_LO;
            end
            WAIT_LO: if(rom_ok) begin
                byte_lo <= rom_data;
                rom_cs <= 0;
                state <= active_mode==3 ? FETCH_HI : DECODE;
            end
            FETCH_HI: begin
                rom_addr <= position[ch][24:1]+24'd1;
                rom_cs <= 1;
                state <= WAIT_HI;
            end
            WAIT_HI: if(rom_ok) begin
                byte_hi <= rom_data;
                rom_cs <= 0;
                state <= DECODE;
            end
            DECODE: begin
                case(active_mode)
                    1: begin
                        curr_data[ch] <= decoded_signal;
                        signal_data[ch] <= decoded_signal;
                        step_data[ch] <= decoded_step;
                    end
                    2: curr_data[ch] <= {byte_lo,8'd0};
                    3: curr_data[ch] <= {byte_hi,byte_lo};
                    default: curr_data[ch] <= 0;
                endcase
                state <= ADVANCE;
            end
            ADVANCE: begin
                position[ch] <= next_position[24:0];
                if(looping[ch] && !loop_saved[ch] && advanced=={1'b0,loop_start[ch]}) begin
                    loop_signal[ch] <= signal_data[ch];
                    loop_step[ch] <= step_data[ch];
                    loop_saved[ch] <= 1;
                end
                if(wrap_loop) begin
                    signal_data[ch] <= loop_signal[ch];
                    step_data[ch] <= loop_step[ch];
                end
                if(end_voice) playing[ch] <= 0;
                state <= MIX;
            end
            MIX: begin
                voice_l <= product_l;
                voice_r <= product_r;
                phase[ch] <= phase[ch]+frequency;
                state <= NEXT;
            end
            NEXT: begin
                acc_l <= acc_l + {{3{voice_l[24]}},voice_l};
                acc_r <= acc_r + {{3{voice_r[24]}},voice_r};
                if(ch==7) begin
                    mix_l <= acc_l + {{3{voice_l[24]}},voice_l};
                    mix_r <= acc_r + {{3{voice_r[24]}},voice_r};
                    state <= IDLE;
                end else begin
                    ch <= ch+3'd1;
                    state <= VOICE;
                end
            end
            EXT_WAIT: if(rom_ok) begin
                if(!ext_write) ext_latch <= rom_data;
                rom_cs <= 0;
                rom_we <= 0;
                ext_pending <= 0;
                state <= IDLE;
            end
            default: state <= IDLE;
        endcase

        if(accept && rd && !addr && ext_enable) begin
            ext_request <= ext_address;
            ext_address <= ext_address+24'd1;
            ext_pending <= 1;
            ext_write <= 0;
        end
        if(accept && wr && !addr) reg_sel <= din;
        if(data_wr) begin
            if(!reg_sel[7]) begin
                case(reg_sel & 8'he3)
                    8'h00: fnum[cpu_ch][7:0] <= din;
                    8'h01: begin
                        fnum[cpu_ch][8] <= din[0];
                        looping[cpu_ch] <= din[4];
                        if(din[6:5]!=0) mode[cpu_ch] <= din[6:5];
                        keyon[cpu_ch] <= din[7] && |din[6:5];
                        if(!keyon[cpu_ch] && din[7] && |din[6:5] && key_enable) begin
                            playing[cpu_ch] <= 1;
                            position[cpu_ch] <= start_addr[cpu_ch];
                            signal_data[cpu_ch] <= 0;
                            loop_signal[cpu_ch] <= 0;
                            step_data[cpu_ch] <= 15'd127;
                            loop_step[cpu_ch] <= 15'd127;
                            loop_saved[cpu_ch] <= 0;
                            prev_data[cpu_ch] <= 0;
                            curr_data[cpu_ch] <= 0;
                            phase[cpu_ch] <= 10'd512;
                            if(cpu_ch==ch && state!=IDLE && state!=EXT_WAIT && state!=NEXT) begin
                                rom_cs <= 0;
                                state <= VOICE;
                            end
                        end else if(keyon[cpu_ch] && (!din[7] || din[6:5]==0))
                        begin
                            playing[cpu_ch] <= 0;
                            if(cpu_ch==ch && state>=FETCH && state<=ADVANCE) begin
                                rom_cs <= 0;
                                state <= MIX;
                            end
                        end
                    end
                    8'h02: level[cpu_ch] <= din;
                    8'h03: pan[cpu_ch] <= din[3:0];
                    8'h20: start_addr[cpu_ch][24:17] <= din;
                    8'h21: loop_start[cpu_ch][24:17] <= din;
                    8'h22: loop_end[cpu_ch][24:17] <= din;
                    8'h23: stop_addr[cpu_ch][24:17] <= din;
                    8'h40: start_addr[cpu_ch][16:9] <= din;
                    8'h41: loop_start[cpu_ch][16:9] <= din;
                    8'h42: loop_end[cpu_ch][16:9] <= din;
                    8'h43: stop_addr[cpu_ch][16:9] <= din;
                    8'h60: start_addr[cpu_ch][8:1] <= din;
                    8'h61: loop_start[cpu_ch][8:1] <= din;
                    8'h62: loop_end[cpu_ch][8:1] <= din;
                    8'h63: stop_addr[cpu_ch][8:1] <= din;
                    default: ;
                endcase
            end else case(reg_sel)
                8'h84: ext_hi <= din;
                8'h85: ext_mid <= din;
                8'h86: begin
                    ext_address <= {ext_hi,ext_mid,din};
                    if(ext_enable) begin
                        ext_request <= {ext_hi,ext_mid,din};
                        ext_pending <= 1;
                        ext_write <= 0;
                    end
                end
                8'h87: if(ext_enable) begin
                    ext_request <= ext_address;
                    ext_address <= ext_address+24'd1;
                    ext_pending <= 1;
                    ext_write <= 1;
                    ext_data <= din;
                end
                8'hfe: irq_mask <= din;
                8'hff: begin
                    ext_enable <= din[6];
                    irq_enable <= din[4];
                    key_enable <= din[7];
                    if(key_enable && !din[7]) begin
                        playing <= 0;
                        if(state>=FETCH && state<=ADVANCE) begin
                            rom_cs <= 0;
                            state <= MIX;
                        end
                    end
                    else if(!key_enable && din[7]) playing <= playing | (keyon & looping);
                end
                default: ;
            endcase
        end
    end
end

endmodule
