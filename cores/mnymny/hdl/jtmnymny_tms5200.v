/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later */

// jtmnymny_tms5200.v — TMS5200 VSP, from the TI data manual (DSAP005265)

module jtmnymny_tms5200(
    input               rst,
    input               clk,
    input               cen,        // 649.2 kHz on 1B11142 (RC osc)
    // CPU interface
    input               rs_n,       // read select
    input               ws_n,       // write select
    input       [ 7:0]  din,
    output reg  [ 7:0]  dout,
    output              dout_oe,
    output reg          ready_n,    // low = transfer can complete
    output reg          int_n,
    // audio
    output reg signed [13:0] snd,
    output reg          sample
);

// parameter ROMs from the TMS5200NL die decap (see the hex files)
reg [9:0] lpc_rom  [0:255];
reg [7:0] chirp_rom[0:63];
initial begin
    $readmemh("jtmnymny_tms5200_lpc.hex",   lpc_rom);
    $readmemh("jtmnymny_tms5200_chirp.hex", chirp_rom);
end
// registered read ports
reg  [ 7:0] lpc_a;
reg  [ 9:0] lpc_q;
reg  [ 5:0] chirp_a;
reg  [ 7:0] chirp_q;
always @(posedge clk) begin
    lpc_q   <= lpc_rom[lpc_a];
    chirp_q <= chirp_rom[chirp_a];
end
// LPC ROM layout offsets
localparam [7:0] A_ENERGY=8'h00, A_PITCH=8'h10, A_K1=8'h50, A_K2=8'h70,
                 A_K3=8'h90; // K3..K7 16 apart, K8..K10 8 apart from E0
// K base address per index 0..9
function [7:0] kbase(input [3:0] n);
    kbase = n==0 ? A_K1 : n==1 ? A_K2 :
            n<7  ? A_K3 + ({4'd0,n[3:0]}-8'd2)*8'h10 :
                   8'hE0 + ({4'd0,n[3:0]}-8'd7)*8'h08;
endfunction
// interpolation shifts per interpolation period IC0..IC7 (decap-verified)
function [2:0] interp_shift(input [2:0] icp);
    case( icp )
        3'd0: interp_shift = 3'd0;  // IC0 snaps to the target
        3'd1,3'd2,3'd3: interp_shift = 3'd3;
        3'd4,3'd5: interp_shift = 3'd2;
        default: interp_shift = 3'd1;
    endcase
endfunction

// ------------------------------------------------------------- timing
// cen/4 = bit time (6.25us), 20 bit times = sample (125us),
// 25 samples = interpolation period (3.125ms), 8 periods = frame (25ms)
reg  [ 1:0] phi=0;
reg  [ 4:0] tcnt=0;     // bit time within sample, 0-19
reg  [ 4:0] scnt=0;     // sample within interpolation period, 0-24
reg  [ 2:0] ic=0;       // interpolation period, 0-7
wire        bit_tick    = cen && phi==3;
wire        sample_tick = bit_tick && tcnt==19;
wire        ic_tick     = sample_tick && scnt==24;
wire        frame_tick  = ic_tick && ic==7;

// ---------------------------------------------------------------- FIFO
reg  [ 7:0] fifo[0:15];
reg  [ 3:0] wptr, rptr;
reg  [ 4:0] count;      // 0-16 bytes
reg         fifo_push, fifo_pop, fifo_clr; // single-writer count events
reg  [ 2:0] bitsel;     // bit within head byte, LSB first
wire        fifo_bit  = fifo[rptr][bitsel];
wire        buf_low   = count <= 5'd8;
wire        buf_empty = count == 0;

// ------------------------------------------------------------- status
reg         ts, bl, be, spk_ext;
reg         old_ts, old_bl, old_be;

// ------------------------------------------------------- frame decode
// coded (index) parameters: current frame targets
reg  [ 3:0] i_energy;
reg  [ 5:0] i_pitch;
reg  [ 4:0] i_k [0:9];
// decoded 10-bit values: interpolation current and target
reg  signed [ 9:0] c_energy, t_energy, c_pitch, t_pitch;
reg  signed [ 9:0] c_k[0:9], t_k[0:9];
reg         stop_pend, rpt;
reg         inhibit, olde, oldp, sil;
// parser FSM
localparam [3:0] P_IDLE=0, P_ENERGY=1, P_REPEAT=2, P_PITCH=3, P_K=4,
                 P_APPLY=5, P_LOOKUP=6;
reg  [ 3:0] pst;
wire        parsing;
reg  [ 5:0] pacc;       // bit accumulator, LSB-first fill then reverse
reg  [ 2:0] pgot, plen;
reg  [ 3:0] kidx;
reg  [ 3:0] lukidx;
reg         lukwait;
// field widths per figure 5: K1,K2=5; K3..K7=4; K8..K10=3
function [2:0] kwidth(input [3:0] n);
    kwidth = n<2 ? 3'd5 : n<7 ? 3'd4 : 3'd3;
endfunction
// bits arrive LSB-first within each field
wire [5:0] pval = pacc;
assign parsing = pst==P_ENERGY || pst==P_REPEAT || pst==P_PITCH || pst==P_K;

integer i;

// ---------------------------------------------------------- interface
reg         ws_l, rs_l;
reg  [ 2:0] acc;
reg         wr_pend, rd_pend;
reg  [ 7:0] wr_data;

assign dout_oe = !rs_n;

wire int_set = (old_ts & ~ts) | (~old_bl & bl) | (~old_be & be);

// ---------------------------------------------------------- synthesis
reg  signed [17:0] u [0:10];    // forward path
reg  signed [17:0] b [0:9];     // backward path
reg  signed [ 9:0] prev_energy; // energy lags one sample (patent)
reg  [ 9:0] pitch_cnt;
reg  [12:0] lfsr;
reg  [ 3:0] lat;                // lattice stage sequencer
integer     lf;
wire        voiced = c_pitch != 0;
// patent multiply: 10-bit param x 15-bit wrapped state, >>9
function signed [17:0] mm(input signed [9:0] a, input signed [17:0] v);
    reg signed [24:0] pr;
    begin
        pr = a * $signed(v[14:0]);
        mm = pr >>> 9;
    end
endfunction
// unvoiced level is half the chirp peak (patent/decap): +/-0x40
// chirp_q lags chirp_a by 1 clk: addressed continuously from pitch_cnt
wire signed [ 7:0] excite = voiced ? $signed(chirp_q) :
                            lfsr[12] ? -8'sd64 : 8'sd64;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        // power-up clear (manual 7)
        {ts, spk_ext}  <= 0;
        {bl, be}       <= 2'b10;
        {wptr, rptr, count, bitsel} <= 0;
        {ws_l, rs_l}   <= 2'b11;
        {wr_pend, rd_pend} <= 0;
        ready_n <= 0;
        int_n   <= 1;
        dout    <= 0;
        acc     <= 0;
        {phi, tcnt, scnt, ic} <= 0;
        {old_ts, old_bl, old_be} <= 3'b011;
        {i_energy, i_pitch} <= 0;
        {c_energy, t_energy, c_pitch, t_pitch} <= 0;
        for(i=0;i<10;i=i+1) begin
            c_k[i] <= 0; t_k[i] <= 0; i_k[i] <= 0;
        end
        for(i=0;i<=10;i=i+1) u[i] <= 0;
        for(i=0;i<10;i=i+1)  b[i] <= 0;
        {stop_pend, rpt} <= 0;
        {inhibit, olde, oldp, sil} <= 0;
        prev_energy <= 0;
        pst  <= P_IDLE;
        {pacc, pgot, plen, kidx} <= 0;
        {lukidx, lukwait} <= 0;
        {lpc_a, chirp_a} <= 0;
        pitch_cnt <= 0;
        lfsr <= 13'h1fff;
        lat  <= 4'd15;
        snd  <= 0;
        sample <= 0;
    end else begin
        fifo_push = 0; fifo_pop = 0; fifo_clr = 0;
        sample <= 0;
        {old_ts, old_bl, old_be} <= {ts, bl, be};
        if( int_set ) int_n <= 0;
        if( cen ) phi <= phi+2'd1;

        ws_l <= ws_n;
        rs_l <= rs_n;

        // READY: stalls =<100ns after a select falls, released when the
        // transfer completes (manual 3.2, Appendix C)
        if( ws_l && !ws_n ) begin
            wr_pend <= 1;
            wr_data <= din;
            ready_n <= 1;
            acc     <= 3'd4;
        end
        if( rs_l && !rs_n ) begin
            rd_pend <= 1;
            ready_n <= 1;
            acc     <= 3'd4;
        end

        if( cen && acc!=0 ) begin
            acc <= acc-3'd1;
            if( acc==3'd1 ) begin
                if( rd_pend ) begin // status only: no VSM, no Read Byte data
                    dout    <= {ts, bl, be, 5'd0};
                    int_n   <= 1;   // status read clears INT (manual 3.3)
                    rd_pend <= 0;
                    ready_n <= 0;
                end
                if( wr_pend ) begin
                    if( spk_ext ) begin
                        if( count==5'd16 ) begin
                            acc <= 3'd4;    // FIFO full: hold READY high
                        end else begin
                            fifo[wptr] <= wr_data;
                            wptr    <= wptr+4'd1;
                            fifo_push = 1;
                            be      <= 0;
                            wr_pend <= 0;
                            ready_n <= 0;
                        end
                    end else begin
                        case( wr_data[6:4] )    // table 2
                            3'b110: begin       // SPEAK EXTERNAL
                                spk_ext <= 1;
                                {wptr, rptr, bitsel} <= 0;
                                fifo_clr = 1;
                                {bl, be} <= 2'b10;
                                stop_pend <= 0;
                                pst <= P_IDLE;
                            end
                            3'b111: begin       // RESET
                                {ts, spk_ext} <= 0;
                                {wptr, rptr, bitsel} <= 0;
                                fifo_clr = 1;
                                {bl, be} <= 2'b10;
                                stop_pend <= 0;
                                int_n <= 1;
                                pst   <= P_IDLE;
                            end
                            default: ;  // NOPs and VSM commands: no VSM
                        endcase
                        wr_pend <= 0;
                        ready_n <= 0;
                    end
                end
            end
        end

        if( spk_ext ) begin
            bl <= buf_low;
            // TS sets after 9 bytes are loaded (manual 5.2)
            if( !ts && count>=5'd9 ) begin
                ts   <= 1;
                ic   <= 0;
                {tcnt, scnt} <= 0;
                olde <= 1;          // coming out of silence
            end
            // buffer empty: abnormal termination (manual 5.2/6.5)
            if( ts && buf_empty && parsing ) begin
                be      <= 1;
                ts      <= 0;
                spk_ext <= 0;
                pst     <= P_IDLE;
            end
        end

        // ------------------------------------------------ speech timing
        if( ts && bit_tick ) begin
            tcnt <= tcnt==19 ? 5'd0 : tcnt+5'd1;
            if( sample_tick ) scnt <= scnt==24 ? 5'd0 : scnt+5'd1;
            if( ic_tick     ) ic   <= ic+3'd1;
        end

        // frame boundary (end of IC7): stop after the ramp, latch old flags
        if( ts && frame_tick ) begin
            if( stop_pend ) begin
                ts        <= 0;
                spk_ext   <= 0;
                stop_pend <= 0;
                pst       <= P_IDLE;
            end
            olde <= i_energy==0;
            oldp <= i_pitch==0;
        end
        // parse the next frame at the end of IC0 (chip: IP0, PC12)
        if( ts && ic_tick && ic==3'd0 && !stop_pend ) begin
            pst  <= P_ENERGY;
            pgot <= 0; pacc <= 0;
        end

        // parameter interpolation once per interpolation period, with the
        // decap-verified shift sequence; IC0 snaps, inhibit blocks IC1-7
        if( ts && ic_tick && (!inhibit || (ic+3'd1)==3'd0) ) begin
            c_energy <= c_energy + ((t_energy-c_energy)>>>interp_shift(ic+3'd1));
            c_pitch  <= c_pitch  + ((t_pitch -c_pitch )>>>interp_shift(ic+3'd1));
            for(i=0;i<10;i=i+1)
                c_k[i] <= c_k[i] + ((t_k[i]-c_k[i])>>>interp_shift(ic+3'd1));
        end

        // ------------------------------------------------- frame parser
        // one FIFO bit per cen: 50 bits max against 16k cen per frame,
        // well inside IC0 as on the real chip
        if( ts && cen && parsing && !buf_empty ) begin
            // pop one bit, LSB-first
            if( bitsel==7 ) begin
                bitsel <= 0;
                rptr   <= rptr+4'd1;
                fifo_pop = 1;
            end else bitsel <= bitsel+3'd1;
            pacc <= {pacc[4:0], fifo_bit}; // first-received bit = field MSB
            pgot <= pgot+3'd1;
            case( pst )
                P_ENERGY: if( pgot==3 ) begin
                    i_energy <= {pacc[2:0], fifo_bit};
                    pgot <= 0; pacc <= 0;
                    if( {pacc[2:0], fifo_bit}==4'b0000 ) begin
                        pst <= P_APPLY;      // silent frame
                    end else if( {pacc[2:0], fifo_bit}==4'b1111 ) begin
                        stop_pend <= 1;      // stop code
                        pst <= P_APPLY;
                    end else pst <= P_REPEAT;
                end
                P_REPEAT: begin
                    rpt  <= fifo_bit;
                    pgot <= 0; pacc <= 0;
                    pst  <= P_PITCH;
                end
                P_PITCH: if( pgot==5 ) begin
                    i_pitch <= {pacc[4:0], fifo_bit};
                    pgot <= 0; pacc <= 0;
                    kidx <= 0;
                    // repeat frame: keep previous Ks (manual 8.1 case 1)
                    pst  <= rpt ? P_APPLY : P_K;
                end
                P_K: if( pgot == kwidth(kidx)-3'd1 ) begin
                    i_k[kidx] <= kwidth(kidx)==3'd5 ? {pacc[3:0], fifo_bit} :
                                 kwidth(kidx)==3'd4 ? {1'b0, pacc[2:0], fifo_bit} :
                                                      {2'b0, pacc[1:0], fifo_bit};
                    pgot <= 0; pacc <= 0;
                    // unvoiced (pitch=0): K1-K4 only (manual 8.1 case 2)
                    if( kidx == (i_pitch==0 ? 4'd3 : 4'd9) )
                        pst <= P_APPLY;
                    else
                        kidx <= kidx+4'd1;
                end
                default:;
            endcase
        end
        // decode indices through the LPC ROM into targets, one value
        // per two clks (registered ROM read). lukidx: 0=energy, 1=pitch,
        // 2..11=K1..K10
        if( pst==P_APPLY ) begin
            lukidx  <= 0;
            lpc_a   <= A_ENERGY + {4'd0,i_energy};
            lukwait <= 1;
            sil     <= i_energy==0;
            inhibit <= ( oldp != (i_pitch==0)  ) ||
                       ( olde && i_energy!=0   ) ||
                       ( oldp && i_energy==0   );
            pst     <= P_LOOKUP;
        end
        if( pst==P_LOOKUP ) begin
            if( lukwait ) lukwait <= 0;  // ROM data settles
            else begin
                lukwait <= 1;
                case( lukidx )
                    4'd0: begin
                        t_energy <= stop_pend ? 10'sd0 : $signed(lpc_q);
                        lpc_a    <= A_PITCH + {2'd0,i_pitch};
                    end
                    4'd1: begin
                        t_pitch <= (sil || stop_pend) ? 10'sd0 : $signed(lpc_q);
                        lpc_a   <= kbase(0) + {3'd0,i_k[0]};
                    end
                    default: begin
                        if( !rpt && i_energy!=0 && !stop_pend )
                            t_k[lukidx-2] <=
                                (lukidx>=6 && i_pitch==0) ? 10'sd0
                                                          : $signed(lpc_q);
                        lpc_a <= kbase(lukidx-1) + {3'd0,i_k[lukidx>9?4'd9:lukidx-1]};
                    end
                endcase
                if( lukidx==4'd11 ) begin
                    rpt <= 0;
                    pst <= P_IDLE;
                end else lukidx <= lukidx+4'd1;
            end
        end

        // --------------------------------------------- lattice, 1 stage
        // per clk right after each sample tick (11 clks per 125us sample)
        if( ts && sample_tick ) begin
            // Y(11) = energy * (excitation<<6) >> 9 (patent table I)
            u[10] <= mm(prev_energy, {{10{excite[7]}}, excite} <<< 6);
            lat   <= 4'd9;
            // pitch period counter; chirp ROM addressed one sample ahead
            if( voiced ) begin
                pitch_cnt <= pitch_cnt >= c_pitch[9:0] ? 10'd0
                                                       : pitch_cnt+10'd1;
                chirp_a   <= pitch_cnt >= c_pitch[9:0] ? 6'd0 :
                             pitch_cnt >= 10'd62 ? 6'd63 : pitch_cnt[5:0]+6'd1;
            end else begin
                pitch_cnt <= 0;
                chirp_a   <= 0;
            end
            // 13-bit LFSR, taps 12,3,2,0, clocked 20x per sample (per T)
            begin : lfsr_upd
                reg [12:0] r;
                r = lfsr;
                for(lf=0;lf<20;lf=lf+1)
                    r = {r[11:0], r[12]^r[3]^r[2]^r[0]};
                lfsr <= r;
            end
        end else if( lat != 4'd15 ) begin : lattice
            // ui-1 = ui - ki*bi-1 ; bi = bi-1 + ki*ui-1
            reg signed [17:0] un;
            un = u[lat+1] - mm(c_k[lat], b[lat]);
            u[lat] <= un;
            if( lat != 4'd9 )
                b[lat+1] <= b[lat] + mm(c_k[lat], un);
            if( lat == 4'd0 ) begin
                b[0]   <= un;
                // analog output clips at 11 bits (patent/MAME clip_analog)
                snd    <= un > 18'sd2047  ? 14'sd8188  :
                          un < -18'sd2048 ? -14'sd8192 : {un[11:0], 2'd0};
                sample <= 1;
                prev_energy <= c_energy;
                lat    <= 4'd15;
            end else lat <= lat-4'd1;
        end

        // pitch counter reset when the ending frame was inhibited (RESETF3)
        if( ts && frame_tick && inhibit ) pitch_cnt <= 0;

        count <= fifo_clr ? 5'd0
               : count + {4'd0,fifo_push} - {4'd0,fifo_pop};
    end
end

endmodule
