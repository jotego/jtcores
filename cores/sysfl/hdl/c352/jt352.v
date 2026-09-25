/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Andrea Bogazzi. email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 19-9-2026
*/

// Namco C352 PCM chip. Follows MAME's c352.cpp (superctr's RE model)
// 32 voices, 8-bit linear / mu-law samples, noise LFSR, 4 output channels
// One 32-voice update every 288 cen ticks (cen = 24.192 MHz -> 84 kHz)
// System FL only wires the front pair: snd_l/snd_r = FL/FR
// FM (0x400) and LOOPTRG (0x1000) flags are stored but unused, as in MAME

module jt352(
    input             rst,
    input             clk,
    input             cen,       // 24.192 MHz equivalent
    // CPU interface, 16 bits, 0x1000 byte window
    input             cs,
    input      [15:1] addr,
    input             rnw,
    input      [ 1:0] dsn,
    input      [15:0] din,
    output reg [15:0] dout,
    // sample ROM
    output reg [23:0] rom_addr,
    input      [ 7:0] rom_data,
    output reg        rom_cs,
    input             rom_ok,
    // audio output
    output reg signed [15:0] snd_l,
    output reg signed [15:0] snd_r,
    output reg        sample,
    // debug
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

localparam [2:0] IDLE=0, LOAD=1, FETCH=2, MIX=3, PUT=4, INTP=5;
// flag bits
localparam BUSY=15, KON=14, KOFF=13, LHIST=11, PH_RL=9, PH_FL=8,
           PH_FR=7, LDIR=6, LINK=5, NOISE=4, MULAW=3, FILT=2, LOOP=1, REV=0;

// per voice state
reg [23:0] pos_a  [0:31];
reg [15:0] cnt_a  [0:31], smp_a [0:31], lst_a [0:31],
           volf_a [0:31], volr_a[0:31], freq_a[0:31], flag_a[0:31],
           bank_a [0:31], strt_a[0:31], wend_a[0:31], loop_a[0:31];
reg [ 7:0] cv0_a  [0:31], cv1_a [0:31], cv2_a [0:31], cv3_a [0:31];

(* ramstyle = "MLAB, no_rw_check" *) reg [15:0] mulaw_t[0:255];
reg  [15:0] lfsr, ctrl, nc;
reg  [ 8:0] div_cnt;
reg  [ 4:0] vch;
reg  [ 2:0] st;
reg         pend, do_ramp, fwait;
// working copy of the voice being updated
reg  [23:0] w_pos;
reg  [15:0] w_flg, w_smp, w_lst, w_volf, w_volr, w_end, w_loop, w_strt;
reg  [ 7:0] w_cv0, w_cv1, w_cv2, w_cv3;
reg signed [23:0] acc0, acc1, acc2, acc3;
integer k;

// mu-law expansion table, exact MAME generation
reg [15:0] jj;
initial begin
    jj = 0;
    for( k=0; k<128; k=k+1 ) begin
        mulaw_t[k] = jj<<5;
        if     ( k< 16 ) jj = jj+16'd1;
        else if( k< 24 ) jj = jj+16'd2;
        else if( k< 48 ) jj = jj+16'd4;
        else if( k<100 ) jj = jj+16'd8;
        else             jj = jj+16'd16;
    end
    for( k=0; k<128; k=k+1 ) mulaw_t[k+128] = (~mulaw_t[k]) & 16'hffe0;
end

wire [10:0] off = addr[11:1];
wire [ 4:0] rdv = off[7:3];
wire [16:0] nc_w    = {1'b0,cnt_a[vch]} + {1'b0,freq_a[vch]};
wire        busy_w  = flag_a[vch][BUSY];
wire        ramp_w  = ((nc_w ^ {1'b0,cnt_a[vch]}) & 17'h18000) != 0;
wire [15:0] lfsr_nx = (lfsr>>1) ^ (lfsr[0] ? 16'hfff6 : 16'h0);

// sample fetch: pos walk and flag update (valid during FETCH)
reg  [15:0] fs, nf;
reg  [23:0] np;
always @* begin
    fs = w_flg[MULAW] ? mulaw_t[rom_data] : {rom_data,8'h0};
    nf = w_flg;
    np = w_pos;
    if( w_flg[LOOP] && w_flg[REV] ) begin // ping-pong loop
        if( w_flg[LDIR] && w_pos[15:0]==w_loop )
            nf[LDIR] = 0;
        else if( !w_flg[LDIR] && w_pos[15:0]==w_end )
            nf[LDIR] = 1;
        np = nf[LDIR] ? w_pos-24'd1 : w_pos+24'd1;
    end else if( w_pos[15:0]==w_end ) begin
        if( w_flg[LINK] && w_flg[LOOP] ) begin
            np = {w_strt[7:0],w_loop}; // start acts as new bank
            nf[LHIST] = 1;
        end else if( w_flg[LOOP] ) begin
            np = {w_pos[23:16],w_loop};
            nf[LHIST] = 1;
        end else begin
            nf[KOFF] = 1;
            nf[BUSY] = 0;
            fs       = 0;
        end
    end else begin
        np = w_flg[REV] ? w_pos-24'd1 : w_pos+24'd1;
    end
end

// volume ramp, one step per 0x8000 counter crossing
wire [7:0] tg0 = w_volf[15:8], tg1 = w_volf[7:0],
           tg2 = w_volr[15:8], tg3 = w_volr[7:0];
wire [7:0] ncv0 = !do_ramp ? w_cv0 : w_cv0>tg0 ? w_cv0-8'd1 : w_cv0<tg0 ? w_cv0+8'd1 : w_cv0;
wire [7:0] ncv1 = !do_ramp ? w_cv1 : w_cv1>tg1 ? w_cv1-8'd1 : w_cv1<tg1 ? w_cv1+8'd1 : w_cv1;
wire [7:0] ncv2 = !do_ramp ? w_cv2 : w_cv2>tg2 ? w_cv2-8'd1 : w_cv2<tg2 ? w_cv2+8'd1 : w_cv2;
wire [7:0] ncv3 = !do_ramp ? w_cv3 : w_cv3>tg3 ? w_cv3-8'd1 : w_cv3<tg3 ? w_cv3+8'd1 : w_cv3;

// linear interpolation between samples unless FILTER is set
wire signed [16:0] sdiff = $signed({w_smp[15],w_smp}) - $signed({w_lst[15],w_lst});
wire signed [33:0] iprod = $signed({1'b0,nc}) * sdiff;
wire        [15:0] s_int = w_lst + iprod[31:16];
wire        [15:0] s_mix = w_flg[FILT] ? w_smp : s_int;
reg         [15:0] s_mixr;   // pipeline stage between the two multiplies
wire signed [16:0] s_p   = $signed({s_mixr[15],s_mixr});
wire signed [16:0] s_n   = -s_p;
// RR takes the FR phase flag, as in MAME
wire signed [16:0] m0 = w_flg[PH_FL]? s_n:s_p,
                   m1 = w_flg[PH_FR]? s_n:s_p,
                   m2 = w_flg[PH_RL]? s_n:s_p;
wire signed [25:0] t0 = m0 * $signed({1'b0,ncv0});
wire signed [25:0] t1 = m1 * $signed({1'b0,ncv1});
wire signed [25:0] t2 = m2 * $signed({1'b0,ncv2});
wire signed [25:0] t3 = m1 * $signed({1'b0,ncv3});

// flags after a keyon execute pass
wire [15:0] konf[0:31];
genvar g;
generate
    for( g=0; g<32; g=g+1 ) begin : gkon
        assign konf[g] = flag_a[g][KON] ?
            ((flag_a[g]|16'h8000) & 16'hb7ff) : flag_a[g];
    end
endgenerate

always @* begin
    if( off<11'h100 )
        case( off[2:0] )
        3'd0: dout = volf_a[rdv];
        3'd1: dout = volr_a[rdv];
        3'd2: dout = freq_a[rdv];
        3'd3: dout = flag_a[rdv];
        3'd4: dout = bank_a[rdv];
        3'd5: dout = strt_a[rdv];
        3'd6: dout = wend_a[rdv];
        3'd7: dout = loop_a[rdv];
        endcase
    else
        dout = off==11'h200 ? ctrl : 16'h0;
end

always @* st_dout = debug_bus[5] ? flag_a[debug_bus[4:0]][15:8]
                                 : flag_a[debug_bus[4:0]][ 7:0];

always @(posedge clk) begin
    if( rst ) begin
        for( k=0; k<32; k=k+1 ) begin
            pos_a[k]  <= 0; cnt_a[k]  <= 0; smp_a[k]  <= 0; lst_a[k] <= 0;
            volf_a[k] <= 0; volr_a[k] <= 0; freq_a[k] <= 0; flag_a[k]<= 0;
            bank_a[k] <= 0; strt_a[k] <= 0; wend_a[k] <= 0; loop_a[k]<= 0;
            cv0_a[k]  <= 0; cv1_a[k]  <= 0; cv2_a[k]  <= 0; cv3_a[k] <= 0;
        end
        lfsr    <= 16'h1234;
        ctrl    <= 0;    div_cnt <= 0;    pend  <= 0;
        st      <= IDLE; vch     <= 0;    nc    <= 0;
        rom_cs  <= 0;    rom_addr<= 0;    fwait <= 0;
        snd_l   <= 0;    snd_r   <= 0;    sample<= 0;
        acc0    <= 0;    acc1    <= 0;    acc2  <= 0; acc3 <= 0;
        do_ramp <= 0;
        w_pos <= 0; w_flg <= 0; w_smp <= 0; w_lst <= 0; w_volf <= 0;
        w_volr<= 0; w_end <= 0; w_loop<= 0; w_strt<= 0;
        w_cv0 <= 0; w_cv1 <= 0; w_cv2 <= 0; w_cv3 <= 0;
    end else begin
        sample <= 0;
        if( cen ) begin
            if( div_cnt==9'd287 ) begin
                div_cnt <= 0;
                pend    <= 1;
            end else
                div_cnt <= div_cnt+9'd1;
        end
        case( st )
        IDLE: if( pend ) begin
            pend <= 0;
            vch  <= 0;
            acc0 <= 0; acc1 <= 0; acc2 <= 0; acc3 <= 0;
            st   <= LOAD;
        end
        LOAD: begin
            w_pos  <= pos_a [vch];  w_flg  <= flag_a[vch];
            w_smp  <= smp_a [vch];  w_lst  <= lst_a [vch];
            w_volf <= volf_a[vch];  w_volr <= volr_a[vch];
            w_strt <= strt_a[vch];  w_end  <= wend_a[vch];
            w_loop <= loop_a[vch];
            w_cv0  <= cv0_a [vch];  w_cv1  <= cv1_a [vch];
            w_cv2  <= cv2_a [vch];  w_cv3  <= cv3_a [vch];
            nc     <= nc_w[15:0];
            do_ramp<= ramp_w;
            if( !busy_w ) begin // silent voice, nothing to add
                if( vch==5'd31 ) st <= PUT; else vch <= vch+5'd1;
            end else if( nc_w[16] ) begin
                w_lst <= smp_a[vch];
                if( flag_a[vch][NOISE] ) begin
                    lfsr  <= lfsr_nx;
                    w_smp <= lfsr_nx;
                    st    <= INTP;
                end else begin
                    rom_cs   <= 1;
                    rom_addr <= pos_a[vch];
                    fwait    <= 0;
                    st       <= FETCH;
                end
            end else
                st <= INTP;
        end
        FETCH: begin // voice walk stalls until the ROM byte arrives
            fwait <= 1;
            if( rom_ok && fwait ) begin
                rom_cs <= 0;
                w_smp  <= fs;
                w_pos  <= np;
                w_flg  <= nf;
                st     <= INTP;
            end
        end
        INTP: begin
            s_mixr <= s_mix;
            st     <= MIX;
        end
        MIX: begin
            acc0 <= acc0 + $signed({{6{t0[25]}},t0[25:8]});
            acc1 <= acc1 + $signed({{6{t1[25]}},t1[25:8]});
            acc2 <= acc2 + $signed({{6{t2[25]}},t2[25:8]});
            acc3 <= acc3 + $signed({{6{t3[25]}},t3[25:8]});
            cnt_a[vch]  <= nc;
            smp_a[vch]  <= w_smp;
            lst_a[vch]  <= w_lst;
            pos_a[vch]  <= w_pos;
            flag_a[vch] <= w_flg;
            cv0_a[vch]  <= ncv0;
            cv1_a[vch]  <= ncv1;
            cv2_a[vch]  <= ncv2;
            cv3_a[vch]  <= ncv3;
            if( vch==5'd31 ) st <= PUT;
            else begin
                vch <= vch+5'd1;
                st  <= LOAD;
            end
        end
        PUT: begin // rear accumulators acc2/acc3 kept for debug, FL wires FL/FR
            snd_l  <= acc0[18:3];
            snd_r  <= acc1[18:3];
            sample <= 1;
            st     <= IDLE;
        end
        default: st <= IDLE;
        endcase
        // CPU access. Register writes win over a colliding voice update
        if( cs && !rnw ) begin
            if( off<11'h100 ) begin
                case( off[2:0] )
                3'd0: begin
                    if(!dsn[1]) volf_a[rdv][15:8] <= din[15:8];
                    if(!dsn[0]) volf_a[rdv][ 7:0] <= din[ 7:0];
                end
                3'd1: begin
                    if(!dsn[1]) volr_a[rdv][15:8] <= din[15:8];
                    if(!dsn[0]) volr_a[rdv][ 7:0] <= din[ 7:0];
                end
                3'd2: begin
                    if(!dsn[1]) freq_a[rdv][15:8] <= din[15:8];
                    if(!dsn[0]) freq_a[rdv][ 7:0] <= din[ 7:0];
                end
                3'd3: begin
                    if(!dsn[1]) flag_a[rdv][15:8] <= din[15:8];
                    if(!dsn[0]) flag_a[rdv][ 7:0] <= din[ 7:0];
                end
                3'd4: begin
                    if(!dsn[1]) bank_a[rdv][15:8] <= din[15:8];
                    if(!dsn[0]) bank_a[rdv][ 7:0] <= din[ 7:0];
                end
                3'd5: begin
                    if(!dsn[1]) strt_a[rdv][15:8] <= din[15:8];
                    if(!dsn[0]) strt_a[rdv][ 7:0] <= din[ 7:0];
                end
                3'd6: begin
                    if(!dsn[1]) wend_a[rdv][15:8] <= din[15:8];
                    if(!dsn[0]) wend_a[rdv][ 7:0] <= din[ 7:0];
                end
                3'd7: begin
                    if(!dsn[1]) loop_a[rdv][15:8] <= din[15:8];
                    if(!dsn[0]) loop_a[rdv][ 7:0] <= din[ 7:0];
                end
                endcase
            end else if( off==11'h200 ) begin
                if(!dsn[1]) ctrl[15:8] <= din[15:8];
                if(!dsn[0]) ctrl[ 7:0] <= din[ 7:0];
            end else if( off==11'h202 && dsn==2'b00 ) begin
                // keyon/keyoff execute, 16-bit access only
                for( k=0; k<32; k=k+1 ) begin
                    if( flag_a[k][KON] ) begin
                        pos_a[k]  <= {bank_a[k][7:0],strt_a[k]};
                        smp_a[k]  <= 0;
                        lst_a[k]  <= 0;
                        cnt_a[k]  <= 16'hffff;
                        cv0_a[k]  <= 0; cv1_a[k] <= 0;
                        cv2_a[k]  <= 0; cv3_a[k] <= 0;
                        flag_a[k] <= konf[k];
                    end
                    if( konf[k][KOFF] ) begin
                        flag_a[k] <= konf[k] & 16'h5fff;
                        cnt_a[k]  <= 16'hffff;
                    end
                end
            end
        end
    end
end

endmodule
