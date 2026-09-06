/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later */

// jtmnymny_tms5200.v — TMS5200 VSP, from the TI data manual (DSAP005265)
// CPU interface (RS/WS/READY/INT), command set, 16-byte FIFO, TS/BL/BE
// status, frame parser (table 3 / figure 5 coding) and 10-stage LPC
// lattice, 8 interpolation periods per 25ms frame, 125us sample period.
// Speak External only: the 1B11142 board has no VSM, so VSM commands
// (Read Byte, Read&Branch, Load Address, Speak) complete with correct
// READY handshake but do nothing.
// Parameter ROMs in jtmnymny_tms5200_tables.vh, from the TMS5200NL die
// decap (digshadow, March 2013, siliconpr0n.org). Lattice/LFSR/interp
// behaviour per the data manual and US patent 4,335,277, decap-verified.
// Bus convention: TI numbers D0 as MSB; on the 1B11142 the PIA is wired
// pin-matched so conventional bit order applies throughout (commands in
// din[6:4], FIFO bits consumed LSB-first, status on dout[7:5]=TS,BL,BE).

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

// coefficient tables: energytbl, pitchtbl, ktbl (K1-K10), chirptbl
`include "jtmnymny_tms5200_tables.vh"

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
// parser FSM
localparam [3:0] P_IDLE=0, P_ENERGY=1, P_REPEAT=2, P_PITCH=3, P_K=4,
                 P_APPLY=5;
reg  [ 3:0] pst;
reg  [ 5:0] pacc;       // bit accumulator, LSB-first fill then reverse
reg  [ 2:0] pgot, plen;
reg  [ 3:0] kidx;
// field widths per figure 5: K1,K2=5; K3..K7=4; K8..K10=3
function [2:0] kwidth(input [3:0] n);
    kwidth = n<2 ? 3'd5 : n<7 ? 3'd4 : 3'd3;
endfunction
// bits arrive LSB-first within each field
wire [5:0] pval = pacc;

integer i;

// ---------------------------------------------------------- interface
reg         ws_l, rs_l;
reg  [ 2:0] acc;
reg         wr_pend, rd_pend;
reg  [ 7:0] wr_data;

assign dout_oe = !rs_n;

wire int_set = (old_ts & ~ts) | (~old_bl & bl) | (~old_be & be);

// ---------------------------------------------------------- synthesis
reg  signed [13:0] u [0:10];    // forward path
reg  signed [13:0] b [0:9];     // backward path
reg  [ 6:0] pitch_cnt;
reg  [12:0] lfsr;
reg  [ 3:0] lat;                // lattice stage sequencer
integer     lf;
wire        voiced = t_pitch != 0;
// unvoiced level is half the chirp peak (patent/decap): +/-0x40
wire signed [ 7:0] excite = voiced ? chirp(pitch_cnt) :
                            lfsr[12] ? -8'sd64 : 8'sd64;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        // power-up clear (manual 7)
        {ts, spk_ext}  <= 0;
        {bl, be}       <= 2'b11;
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
        pst  <= P_IDLE;
        {pacc, pgot, plen, kidx} <= 0;
        pitch_cnt <= 0;
        lfsr <= 13'h1fff;
        lat  <= 4'd15;
        snd  <= 0;
        sample <= 0;
    end else begin
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
                            count   <= count+5'd1;
                            wr_pend <= 0;
                            ready_n <= 0;
                        end
                    end else begin
                        case( wr_data[6:4] )    // table 2
                            3'b110: begin       // SPEAK EXTERNAL
                                spk_ext <= 1;
                                {wptr, rptr, count, bitsel} <= 0;
                                {bl, be} <= 2'b11;
                                stop_pend <= 0;
                                pst <= P_IDLE;
                            end
                            3'b111: begin       // RESET
                                {ts, spk_ext} <= 0;
                                {wptr, rptr, count, bitsel} <= 0;
                                {bl, be} <= 2'b11;
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
                ts  <= 1;
                ic  <= 0;
                {tcnt, scnt} <= 0;
                pst <= P_ENERGY;    // parse the first frame immediately
                pgot <= 0; pacc <= 0;
            end
            // buffer empty: abnormal termination (manual 5.2/6.5)
            if( ts && buf_empty && pst!=P_IDLE ) begin
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

        // frame boundary: commit targets, start parsing the next frame
        if( ts && frame_tick ) begin
            if( stop_pend ) begin
                // stop code: interpolate to zero energy this frame, then
                // TS clears at the next boundary (manual TS description)
                ts        <= 0;
                spk_ext   <= 0;
                stop_pend <= 0;
                pst       <= P_IDLE;
            end else begin
                pst  <= P_ENERGY;
                pgot <= 0; pacc <= 0;
            end
        end

        // parameter interpolation once per interpolation period, with the
        // decap-verified shift sequence (IC0 snaps to the target)
        if( ts && ic_tick ) begin
            c_energy <= c_energy + ((t_energy-c_energy)>>>interp_shift(ic));
            c_pitch  <= c_pitch  + ((t_pitch -c_pitch )>>>interp_shift(ic));
            for(i=0;i<10;i=i+1)
                c_k[i] <= c_k[i] + ((t_k[i]-c_k[i])>>>interp_shift(ic));
        end

        // ------------------------------------------------- frame parser
        // one FIFO bit per cen: 50 bits max against 16k cen per frame,
        // well inside IC0 as on the real chip
        if( ts && cen && pst!=P_IDLE && pst!=P_APPLY && !buf_empty ) begin
            // pop one bit, LSB-first
            if( bitsel==7 ) begin
                bitsel <= 0;
                rptr   <= rptr+4'd1;
                count  <= count-5'd1;
            end else bitsel <= bitsel+3'd1;
            pacc <= {fifo_bit, pacc[5:1]}; // fields are LSB-first
            pgot <= pgot+3'd1;
            case( pst )
                P_ENERGY: if( pgot==3 ) begin
                    i_energy <= {fifo_bit, pacc[5:3]};
                    pgot <= 0; pacc <= 0;
                    if( {fifo_bit, pacc[5:3]}==4'b0000 ) begin
                        pst <= P_APPLY;      // silent frame
                    end else if( {fifo_bit, pacc[5:3]}==4'b1111 ) begin
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
                    i_pitch <= {fifo_bit, pacc[5:1]};
                    pgot <= 0; pacc <= 0;
                    kidx <= 0;
                    // repeat frame: keep previous Ks (manual 8.1 case 1)
                    pst  <= rpt ? P_APPLY : P_K;
                end
                P_K: if( pgot == kwidth(kidx)-3'd1 ) begin
                    // right-align the LSB-first field
                    i_k[kidx] <= {fifo_bit, pacc[5:2]} >>
                                 (3'd5-kwidth(kidx));
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
        if( pst==P_APPLY ) begin
            // decode indices through the mask ROMs into targets
            t_energy <= stop_pend ? 10'sd0 : energytbl(i_energy);
            t_pitch  <= pitchtbl(i_pitch);
            if( !rpt && i_energy!=0 && !stop_pend ) begin
                for(i=0;i<10;i=i+1)
                    t_k[i] <= (i>=4 && i_pitch==0) ? 10'sd0
                                                   : ktbl(i[3:0], i_k[i]);
            end
            rpt <= 0;
            pst <= P_IDLE;
        end

        // --------------------------------------------- lattice, 1 stage
        // per clk right after each sample tick (11 clks per 125us sample)
        if( ts && sample_tick ) begin
            // Y(11) = energy * (excitation<<6) >> 9 (patent table I)
            u[10] <= (c_energy * (excite <<< 6)) >>> 9;
            lat   <= 4'd9;
            // pitch period counter
            if( voiced ) begin
                pitch_cnt <= pitch_cnt >= c_pitch[6:0] ? 7'd0
                                                       : pitch_cnt+7'd1;
            end else pitch_cnt <= 0;
            // 13-bit LFSR, taps 12,3,2,0, clocked 20x per sample (per T)
            begin : lfsr_upd
                reg [12:0] r;
                r = lfsr;
                for(lf=0;lf<20;lf=lf+1)
                    r = {r[11:0], r[12]^r[3]^r[2]^r[0]};
                lfsr <= r;
            end
        end else if( lat != 4'd15 ) begin
            // ui-1 = ui - ki*bi-1 ; bi = bi-1 + ki*ui-1  (>>9 multiplies)
            u[lat] <= u[lat+1] - ((c_k[lat]*b[lat]) >>> 9);
            if( lat != 4'd9 )
                b[lat+1] <= b[lat] + ((c_k[lat]*(u[lat+1]
                            - ((c_k[lat]*b[lat]) >>> 9))) >>> 9);
            if( lat == 4'd0 ) begin
                b[0]   <= u[1] - ((c_k[0]*b[0]) >>> 9);
                snd    <= u[1] - ((c_k[0]*b[0]) >>> 9);
                sample <= 1;
                lat    <= 4'd15;
            end else lat <= lat-4'd1;
        end
    end
end

`ifdef SIMULATION
reg wsl2, rsl2;
always @(posedge clk) begin
    wsl2<=ws_n; rsl2<=rs_n;
    if( wsl2 && !ws_n ) $display("TMS wr %02x (spkext=%b cnt=%0d)", din, spk_ext, count);
    if( rsl2 && !rs_n ) $display("TMS rd status %02x", {ts,bl,be,5'd0});
    if( ts && !old_ts ) $display("TMS TALK START");
    if( !ts && old_ts ) $display("TMS TALK END (be=%b)", be);
end
`endif

endmodule
