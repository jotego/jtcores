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
    Date: 18-9-2026
*/

// Intel i960KA integer core (Namco System FL). Behavior follows MAME's i960.cpp
// multi-cycle sequencer, one 32-bit bus port, direct-mapped instruction cache
// bus: bus_cs asserts a request, the transaction ends when cen & bus_ok
// see README.md for the protocol diagram, ISA coverage and simplifications

module jt960 #(parameter
    // instruction cache size in 256B blocks, power of 2 up to 64. The KA has
    // 512B (2); System FL runs its code from RAM and needs 2kB at a 60.48 MHz
    // base to keep full game pace on the SDRAM bus
    ICACHE_BLK = 16
)(
    input             rst,
    input             clk,
    input             cen,
    // memory bus
    output reg [31:2] addr,
    input      [31:0] din,
    output reg [31:0] dout,
    output reg [ 3:0] dsn,      // active-low byte lanes
    output reg        bus_cs,
    output reg        bus_wr,
    output            fetch,     // bus request is an instruction fetch
    input             bus_ok,
    // external interrupts, level sensitive, active low (I960_IRQ0..3)
    input      [ 3:0] irq_n,
    output reg        halted    // fault/unimplemented opcode reached
);

`include "i960/jt960.vh"

localparam [5:0]
    RST_SAT  = 6'd0,  RST_PRCB = 6'd1,  RST_IP   = 6'd2,  RST_FP   = 6'd3,
    FETCH    = 6'd4,  XWORD    = 6'd5,  EXE      = 6'd6,
    MRD1     = 6'd8,  MRD2     = 6'd9,  MWR1     = 6'd10, MWR2     = 6'd11,
    MOVM     = 6'd7,
    MDWAIT   = 6'd12, MD_RDH   = 6'd14,
    CALL_RIP = 6'd13, CALL_FIN = 6'd15,
    RET_RPC  = 6'd16, RET_RAC  = 6'd17, RET_POP  = 6'd18,
    RET_FIN  = 6'd20, FLUSH_NX = 6'd21,
    INT_TAB  = 6'd22, INT_ISP  = 6'd23, INT_VEC  = 6'd24,
    INT_WPC  = 6'd25, INT_WAC  = 6'd26, INT_WVC  = 6'd27,
    CALLS_PT = 6'd28, CALLS_EN = 6'd29,
    SYN_RD   = 6'd30, SYN_WR   = 6'd31, SYNQ_RD  = 6'd32, SYNQ_WR  = 6'd33,
    IAC_EXE  = 6'd34, IAC_W0   = 6'd35, IAC_W1   = 6'd36,
    AT_RD    = 6'd37, AT_WR    = 6'd38,
    HALT     = 6'd39;

localparam [1:0] SEQ_MEM=2'd0, SEQ_FILL=2'd1, SEQ_SPILL=2'd2, SEQ_FLUSH=2'd3;

// register file: r0-r15 current local frame, r16-r31 = g0-g15 (g15=FP)
reg  [31:0] r[0:31];
reg  [31:0] AC, PCS, SAT, PRCB, IP, PIP, ICR, IR, xdisp;
reg  [31:0] tmp, tmp_pc, tmp_ac, int_tab, int_stk, ctgt, syn_src, syn_dst;
reg  [31:0] mad, mlo, whi, md_s1;
reg  [31:0] iac0, iac1, iac2, iac3;
reg  [ 7:0] int_vec;
reg  [ 5:0] st;
reg  [ 4:0] mcnt, mreg, cnt;
integer     i3;
reg  [ 2:0] ctype, rtype, flush_f, mvcnt;
reg  [ 1:0] msz, seq, int_line;
reg         msig, wsrc_rc, in_int, iac_mode;
reg  signed [15:0] rpos;    // frame-cache depth, per MAME rcache_pos
integer     j2;

// instruction cache: 16B lines, data and {word valid, tag} in block RAM,
// line valid in flip-flops. A bus write clears the line it indexes, IAC clears all
localparam ILW = $clog2(ICACHE_BLK*16),     // line index bits
           ITW = 28-ILW;                    // tag bits
reg  [31:0]    icd[0:ICACHE_BLK*64-1];
reg  [ITW+4:0] ict[0:ICACHE_BLK*16-1];  // {valid, word valid, tag}
reg  [31:0]    icd_q, icw_d;
reg  [ITW+4:0] ict_q, itw_d;
reg  [31:2]    ic_ra, icw_a;
reg            icw, icinv, sweeping, ic_clr;
reg  [ILW-1:0] icinv_a, swa;
wire [ILW-1:0] icx    = IP[ILW+3:4];
wire [ILW-1:0] wcx    = addr[ILW+3:4];
wire           ic_rdy = ic_ra == IP[31:2];  // RAM outputs belong to IP
wire           ic_tag = !sweeping && ict_q[ITW+4] && ict_q[ITW-1:0]==IP[31:ILW+4];
wire           ic_hit = ic_rdy && ic_tag && ict_q[ITW+IP[3:2]];
wire [3:0]     ic_wv  = (ic_tag ? ict_q[ITW+:4] : 4'd0) | (4'd1<<IP[3:2]);

// mid-cen pipeline stage: sampled every clk, consumed at the next cen edge.
// cpu_cen has a minimum two-clock spacing, so the sample settles one clock
// early; s1_ok covers the icache turn-around clock where it would be stale
reg  [31:0] s1_ir, s1_pip, s1_ipn, s1_a, s1_b, s1_c;
reg  [ 7:0] s1_vec;
reg  [ 4:0] s1_cls, s1_mreg;
reg  [ 2:0] s1_mcnt, s1_mdop;
reg  [ 1:0] s1_msz, s1_line;
reg         s1_fuse, s1_irqt, s1_msig, s1_pair, s1_ok;

// register-file port A: the engine states that consume wdata own it, the
// dispatch operands own it everywhere else (t1 is dead in those states)
wire        eng_rd = st==MOVM || st==MWR1 || st==MWR2 || st==MD_RDH;
wire [ 4:0] pa_a;

// the FETCH-hit path is taken at this cen edge (stage sample is fresh)
wire hit_go = st==FETCH && !bus_cs && !s1_irqt && ic_hit && s1_ok;
// on a taken hit the next word is read ahead, so sequential code never waits
wire [31:0]    ic_nx  = cen && hit_go ? IP+32'd4 : IP;

// line valid lives in ict; ic_clr starts a background sweep (IAC 89/93, rst)
// and completed bus writes invalidate their line one clock later
always @(posedge clk) begin
    icd_q <= icd[ic_nx[ILW+3:2]];
    ict_q <= ict[ic_nx[ILW+3:4]];
    ic_ra <= ic_nx[31:2];
    if( rst ) begin
        sweeping <= 1;
        swa      <= 0;
        icinv    <= 0;
    end else begin
        icinv <= cen && bus_cs && bus_ok && bus_wr;
        if( cen && bus_cs && bus_ok && bus_wr ) icinv_a <= wcx;
        if( ic_clr ) begin
            sweeping <= 1;
            swa      <= 0;
        end
        if( icw ) begin
            icd[icw_a[ILW+3:2]] <= icw_d;
            ict[icw_a[ILW+3:4]] <= itw_d;
        end else if( icinv )
            ict[icinv_a] <= 0;
        else if( sweeping && !ic_clr ) begin
            ict[swa] <= 0;
            swa      <= swa + 1'd1;
            if( &swa ) sweeping <= 0;
        end
    end
end

// decoder
wire [ 4:0] dec_cls;
wire        dec_ndisp, dec_msig, dec_pair;
wire [ 1:0] dec_msz;
wire [ 2:0] dec_mcnt, dec_mdop;
wire [ 4:0] dec_mreg;
wire        ic_use = st==FETCH && !bus_cs && ic_hit;
wire [31:0] dec_in = ic_use ? icd_q : IR;
// MEMB long-displacement predecode for the bus-return word: din never enters u_dec
wire        din_ndisp = din[31] && din[12] && (din[13] || din[13:10]==4'b0101);
// single-word instructions hitting the cache execute in the FETCH cycle
wire        fuse;
wire [31:0] IRe    = fuse ? icd_q : IR;
wire [31:0] PIPe   = fuse ? IP    : PIP;
wire [31:0] IPn    = fuse ? IP+32'd4 : IP;
assign pa_a = eng_rd ? mreg : IRe[4:0];

jt960_dec u_dec(
    .ir        ( dec_in    ),
    .opclass   ( dec_cls   ),
    .need_disp ( dec_ndisp ),
    .msz       ( dec_msz   ),
    .mcnt      ( dec_mcnt  ),
    .msig      ( dec_msig  ),
    .mreg      ( dec_mreg  ),
    .mdop      ( dec_mdop  ),
    .mdpair    ( dec_pair  )
);

// operand extraction, from the stage registers
wire [ 4:0] dstf = s1_ir[23:19];
wire [31:0] t1   = s1_ir[11] ? {27'd0, s1_ir[ 4: 0]} : s1_a;
wire [31:0] t2   = s1_ir[12] ? {27'd0, s1_ir[18:14]} : s1_b;
wire [31:0] t3   = s1_c;
// COBR operands: src1 in the dst field, src2 always a register
wire [31:0] c1   = s1_ir[13] ? {27'd0, s1_ir[23:19]} : s1_c;
wire [31:0] c2   = s1_b;
wire        cobr = s1_cls==OC_COBR;

// ALU
wire [31:0] alu_res, alu_ac;
wire        alu_we, alu_bad;

jt960_alu u_alu(
    .ir     ( s1_ir          ),
    .t1     ( cobr ? c1 : t1),
    .t2     ( cobr ? c2 : t2),
    .t3     ( t3            ),
    .ac     ( AC            ),
    .res    ( alu_res       ),
    .res_we ( alu_we        ),
    .ac_nx  ( alu_ac        ),
    .bad    ( alu_bad       )
);

// branch targets, disp includes bits 1:0 as in MAME, bcc/cmpXbcc mask the target
wire [31:0] sx24  = {{8{s1_ir[23]}}, s1_ir[23:0]};
wire [31:0] sx13  = {{19{s1_ir[12]}}, s1_ir[12:0]};
wire [31:0] tgt24 = s1_pip + sx24;
wire [31:0] tgt13 = s1_pip + sx13;
wire [ 2:0] ccmsk = s1_ir[26:24];
wire        cctru = ccmsk==3'd0 ? AC[2:0]==3'd0 : |(AC[2:0]&ccmsk);
wire        isbb  = s1_ir[31:24]==8'h30 || s1_ir[31:24]==8'h37;
wire        cbtak = isbb ? alu_ac[1] : |(alu_ac[2:0]&ccmsk);

// effective address
wire [31:0] rabase = s1_b;
wire [31:0] rindex = s1_a << s1_ir[9:7];
reg  [31:0] ea;

always @* begin
    if( !s1_ir[12] ) begin // MEMA
        ea = s1_ir[13] ? rabase + {20'd0, s1_ir[11:0]} : {20'd0, s1_ir[11:0]};
    end else case( s1_ir[13:10] ) // MEMB
        4'h5:    ea = s1_pip + 32'd8 + xdisp;
        4'h7:    ea = rabase + rindex;
        4'hc:    ea = xdisp;
        4'hd:    ea = xdisp + rabase;
        4'he:    ea = xdisp + rindex;
        4'hf:    ea = xdisp + rabase + rindex;
        default: ea = rabase; // 4'h4
    endcase
end

// memory engine: one 32-bit word per 1-2 bus beats, unaligned supported
// the first beat is issued in the dispatch cycle
wire [ 7:0] lanes  = (msz==2'd0 ? 8'h01 : msz==2'd1 ? 8'h03 : 8'h0f) << mad[1:0];
wire [ 7:0] lanes_d= (s1_msz==2'd0 ? 8'h01 : s1_msz==2'd1 ? 8'h03 : 8'h0f) << ea[1:0];
wire        mcross = |lanes[7:4];
// one shared rotator per direction: dispatch and engine are state-disjoint
wire [63:0] rd64s  = (st==MRD2 ? {din, mlo} : {32'd0, din}) >> {mad[1:0], 3'd0};

function [31:0] mext(input [31:0] w);
    case( msz )
        2'd0:    mext = {{24{msig & w[ 7]}}, w[ 7:0]};
        2'd1:    mext = {{16{msig & w[15]}}, w[15:0]};
        default: mext = w;
    endcase
endfunction

// local register cache, whole frame per clock. RIP (r2) is the call IP
wire [511:0] rc_q, rc_d;
wire [ 31:0] rc_fa;
wire signed [15:0] rposm1 = rpos - 16'sd1;
wire [ 1:0] rc_frame = st==CALL_RIP ? rpos[1:0] : st==RET_POP ? rposm1[1:0] : flush_f[1:0];
wire        rc_we    = cen && st==CALL_RIP && rpos < 16'sd4;
wire [31:0] rc_dout  = rc_q[mreg[3:0]*32 +: 32];

genvar g;
generate
    for( g=0; g<16; g=g+1 ) begin : u_rcd
        assign rc_d[g*32 +: 32] = g==2 ? IP : r[g];
    end
endgenerate

jt960_rcache u_rcache(
    .clk    ( clk       ),
    .frame  ( rc_frame  ),
    .we     ( rc_we     ),
    .din    ( rc_d      ),
    .dout   ( rc_q      ),
    .fa_we  ( rc_we     ),
    .fa_din ( {r[31][31:6], 6'd0} ),
    .fa_dout( rc_fa     )
);

wire [31:0] wdata = wsrc_rc ? rc_dout : s1_a;

// multiply/divide
wire [31:0] md_r0, md_r1;
wire        md_busy, md_done;
// dispatch happening at this cen edge: plain EXE, or fused into a FETCH hit
wire        exe_go   = st==EXE || (hit_go && s1_fuse);
// ediv reads src2+1 through the wdata port in MD_RDH, one cen after dispatch
wire        md_start = (exe_go && s1_cls==OC_MD && s1_mdop!=MD_EDIV)
                       || st==MD_RDH;
wire [63:0] wr64     = {32'd0, exe_go ? t3 : wdata} <<
                       {(exe_go ? ea[1:0] : mad[1:0]), 3'd0};

jt960_muldiv u_md(
    .rst    ( rst      ),
    .clk    ( clk      ),
    .cen    ( cen      ),
    .start  ( md_start ),
    .op     ( s1_mdop  ),
    .s1     ( st==MD_RDH ? md_s1 : t1 ),
    .s2     ( t2       ),
    .s2h    ( wdata    ),
    .r0     ( md_r0    ),
    .r1     ( md_r1    ),
    .busy   ( md_busy  ),
    .done   ( md_done  )
);

// interrupts: rising edge on a line latches it pending, cleared when taken
// vector per line comes from ICR (set via synmov to ff000004)
wire [3:0] pend;
reg  [3:0] pend_g;  // cen-aligned view of the pending latches
reg  [3:0] irq_clr;

always @(posedge clk) begin
    if( rst ) pend_g <= 0;
    else if( cen ) pend_g <= pend;
end

genvar k;
generate
    for( k=0; k<4; k=k+1 ) begin : u_irqlatch
        jtframe_edge u_edge(
            .rst    ( rst        ),
            .clk    ( clk        ),
            .edgeof ( ~irq_n[k]  ),
            .clr    ( irq_clr[k] ),
            .q      ( pend[k]    )
        );
    end
endgenerate

wire [4:0] cpu_pri = PCS[20:16];
reg        irq_take;
reg [ 7:0] sel_vec, vk;
reg [ 1:0] sel_line;
integer    j;

always @* begin
    irq_take = 0;
    sel_vec  = 8'd0;
    sel_line = 2'd0;
    vk       = 8'd0;
    for( j=0; j<4; j=j+1 ) begin
        vk = ICR[8*j +: 8];
        if( pend_g[j] && vk!=8'd0 && vk>sel_vec &&
            (cpu_pri < vk[7:3] || vk[7:3]==5'd31) ) begin
            irq_take = 1;
            sel_vec  = vk;
            sel_line = j[1:0];
        end
    end
    irq_clr = 4'd0;
    if( st==INT_TAB ) irq_clr[int_line] = 1'b1;
end

assign fuse  = st==FETCH && !bus_cs && !irq_take && ic_hit && !dec_ndisp;

always @(posedge clk) begin
    s1_ir   <= IRe;
    s1_pip  <= PIPe;
    s1_ipn  <= IPn;
    s1_a    <= r[pa_a];
    s1_b    <= r[IRe[18:14]];
    s1_c    <= r[IRe[23:19]];
    s1_cls  <= dec_cls;
    s1_mreg <= dec_mreg;
    s1_mcnt <= dec_mcnt;
    s1_mdop <= dec_mdop;
    s1_msz  <= dec_msz;
    s1_msig <= dec_msig;
    s1_pair <= dec_pair;
    s1_fuse <= fuse;
    s1_irqt <= irq_take;
    s1_vec  <= sel_vec;
    s1_line <= sel_line;
    s1_ok   <= ic_nx[31:2]==ic_ra && !icw && !icinv;
end
assign fetch = st==FETCH || st==XWORD;

// call helpers
wire [31:0] newsp  = ctype==3'd7 ? int_stk : r[1];
wire [31:0] newfp  = (newsp + 32'd63) & 32'hffff_ffc0;
wire [ 2:0] flush_lim = rpos>=16'sd4 ? 3'd4 : rpos<=16'sd0 ? 3'd0 : {1'b0,rpos[1:0]};
wire        unused = &{md_busy, rd64s[63:32], 1'b0};

// instruction dispatch, from EXE or fused into an icache-hit FETCH
task do_exe;
begin
    st <= FETCH;
    case( s1_cls )
    OC_NOP:  ;
    OC_B:    IP <= tgt24;
    OC_BCC:  if( cctru ) IP <= tgt24 & 32'hffff_fffc;
    OC_BAL:  begin r[30] <= s1_ipn; IP <= tgt24; end
    OC_FAULT: if( cctru ) begin
            // faultno branches like bno in MAME; a taken faultcc halts
            if( ccmsk==3'd0 ) IP <= tgt24;
            else st <= HALT;
        end
    OC_TEST: r[dstf] <= {31'd0, cctru};
    OC_COBR: begin
        AC <= alu_ac;
        if( cbtak ) IP <= isbb ? tgt13 : tgt13 & 32'hffff_fffc;
    end
    OC_ALU: begin
        AC <= alu_ac;
        if( alu_bad || (alu_we && s1_ir[13]) ) st <= HALT; // literal dst
        else if( alu_we ) r[dstf] <= alu_res;
    end
    OC_MODPC: begin
        PCS <= (PCS & ~t2) | (t3 & t2);
        if( s1_ir[13] ) st <= HALT;
        else r[dstf] <= PCS;
    end
    OC_MOVM: begin // one register per cen, like the KA
        r[s1_mreg] <= t1;
        if( s1_mcnt > 3'd1 ) begin
            mreg  <= s1_ir[4:0] + 5'd1;
            mvcnt <= 3'd1;
            st    <= MOVM;
        end
    end
    OC_MD:  if( s1_mdop==MD_EDIV ) begin
        md_s1 <= t1;                // src1 held over the MD_RDH cen
        mreg <= s1_ir[18:14]+5'd1;  // odd register via the wdata port
        st   <= MD_RDH;
    end else st <= MDWAIT;  // started through md_start
    OC_LDA: r[dstf] <= ea;
    OC_BX:  IP <= ea;
    OC_BALX: begin r[dstf] <= s1_ipn; IP <= ea; end
    OC_LD, OC_ST: begin
        mad     <= ea;
        mreg    <= s1_mreg;
        mcnt    <= {2'd0, s1_mcnt};
        msz     <= s1_msz;
        msig    <= s1_msig;
        wsrc_rc <= 0;
        seq     <= SEQ_MEM;
        st      <= s1_cls==OC_LD ? MRD1 : MWR1;
        if( s1_cls==OC_LD ) rd32(ea); else wr32(ea, wr64[31:0]);
        dsn     <= ~lanes_d[3:0];
        whi     <= wr64[63:32];
    end
    OC_CALL:  begin ctgt <= tgt24; ctype <= 3'd0; st <= CALL_RIP; end
    OC_CALLX: begin ctgt <= ea;    ctype <= 3'd0; st <= CALL_RIP; end
    OC_CALLS: st <= CALLS_PT;
    OC_RET: begin
        rtype <= r[0][2:0];
        case( r[0][2:0] )
        3'd0:    st <= RET_POP;
        3'd7:    st <= RET_RPC;
        default: st <= HALT;
        endcase
    end
    OC_FLUSH: begin flush_f <= 0; st <= FLUSH_NX; end
    OC_SYNMOV, OC_SYNMOVQ: begin
        syn_dst  <= t1;
        syn_src  <= t2;
        cnt      <= 0;
        iac_mode <= s1_cls==OC_SYNMOVQ && t1==32'hff00_0010;
        st       <= s1_cls==OC_SYNMOV ? SYN_RD : SYNQ_RD;
    end
    OC_ATADD, OC_ATMOD: begin
        mad <= {t1[31:2], 2'd0};
        st  <= AT_RD;
    end
    default: st <= HALT;    // OC_BAD
    endcase
end
endtask

task rd32( input [31:0] a );
begin
    bus_cs <= 1;
    bus_wr <= 0;
    addr   <= a[31:2];
    dsn    <= 4'd0;
end
endtask

task wr32( input [31:0] a, input [31:0] d );
begin
    bus_cs <= 1;
    bus_wr <= 1;
    addr   <= a[31:2];
    dout   <= d;
    dsn    <= 4'd0;
end
endtask

// engine loop-or-finish, shared by read and write ends
task mnext( input [5:0] again );
begin
    if( mcnt<=5'd1 ) begin
        case( seq )
        SEQ_FILL:  st <= RET_FIN;
        SEQ_SPILL: st <= CALL_FIN;
        SEQ_FLUSH: begin flush_f <= flush_f+3'd1; st <= FLUSH_NX; end
        default:   st <= FETCH;
        endcase
    end else begin
        mcnt <= mcnt-5'd1;
        mreg <= mreg+5'd1;
        mad  <= mad+32'd4;
        st   <= again;
    end
end
endtask

always @(posedge clk) begin
    if( rst ) begin
        st     <= RST_SAT;
        bus_cs <= 0;    bus_wr <= 0;
        addr   <= 30'd0; dout  <= 32'd0; dsn <= 4'hf;
        halted <= 0;
        AC     <= 32'd0;
        PCS    <= 32'h001f_2002;       // supervisor, interrupted, priority 31
        ICR    <= 32'hff00_0000;
        SAT<=0; PRCB<=0; IP<=0; PIP<=0; IR<=0; xdisp<=0;
        rpos   <= 16'sd0;
        in_int <= 0; iac_mode<=0; wsrc_rc<=0; msig<=0;
        msz<=2'd2; mcnt<=0; mreg<=0; cnt<=0; seq<=SEQ_MEM;
        ctype<=0; rtype<=0; flush_f<=0; int_line<=0; int_vec<=0;
        mad<=0; mlo<=0; whi<=0; tmp<=0; tmp_pc<=0; tmp_ac<=0;
        int_tab<=0; int_stk<=0; ctgt<=0; syn_src<=0; syn_dst<=0;
        iac0<=0; iac1<=0; iac2<=0; iac3<=0;
        for( j2=0; j2<32; j2=j2+1 ) r[j2] <= 32'd0;
        icw    <= 0;
        ic_clr <= 0;
    end else begin
      icw    <= 0;
      if( cen ) begin
        ic_clr <= 0;
        case( st )
        // reset sequence, per MAME device_reset
        RST_SAT: if( !bus_cs ) rd32(32'd0);
            else if( bus_ok ) begin bus_cs<=0; SAT <=din; st<=RST_PRCB; end
        RST_PRCB: if( !bus_cs ) rd32(32'd4);
            else if( bus_ok ) begin bus_cs<=0; PRCB<=din; st<=RST_IP;   end
        RST_IP: if( !bus_cs ) rd32(32'd12);
            else if( bus_ok ) begin bus_cs<=0; IP  <=din; st<=RST_FP;   end
        RST_FP: if( !bus_cs ) rd32(PRCB+32'd24);
            else if( bus_ok ) begin
                bus_cs <= 0;
                r[31]  <= din;          // FP = interrupt stack base
                r[ 1]  <= din+32'd64;   // SP
                st     <= FETCH;
            end
        // fetch: interrupts checked at instruction boundaries
        FETCH: if( !bus_cs ) begin
                if( s1_irqt ) begin
                    int_vec  <= s1_vec;
                    int_line <= s1_line;
                    in_int   <= 1;
                    st       <= INT_TAB;
                end else if( ic_hit && s1_ok ) begin
                    IR  <= icd_q;
                    PIP <= IP;
                    IP  <= IP + 32'd4;
                    if( s1_fuse ) do_exe; else st <= XWORD;
                end else if( ic_rdy && !ic_hit ) rd32(IP); // real miss, else wait
            end else if( bus_ok ) begin
                bus_cs   <= 0;
                IR       <= din;
                PIP      <= IP;
                IP       <= IP + 32'd4;
                icw      <= 1;
                icw_a    <= IP[31:2];
                icw_d    <= din;
                itw_d    <= { 1'b1, ic_wv, IP[31:ILW+4] };
                st       <= din_ndisp ? XWORD : EXE;
            end
        XWORD: if( !bus_cs ) begin
                if( ic_hit ) begin
                    xdisp <= icd_q;
                    IP    <= IP + 32'd4;
                    st    <= EXE;
                end else if( ic_rdy ) rd32(IP);
            end else if( bus_ok ) begin
                bus_cs   <= 0;
                xdisp    <= din;
                IP       <= IP + 32'd4;
                icw      <= 1;
                icw_a    <= IP[31:2];
                icw_d    <= din;
                itw_d    <= { 1'b1, ic_wv, IP[31:ILW+4] };
                st       <= EXE;
            end
        // single dispatch cycle
        EXE: do_exe;
        MOVM: begin
            r[s1_mreg + {2'd0, mvcnt}] <= s1_ir[11] ? {27'd0, s1_ir[4:0]} : wdata;
            mreg  <= mreg + 5'd1;
            mvcnt <= mvcnt + 3'd1;
            if( mvcnt == s1_mcnt-3'd1 ) st <= FETCH;
        end
        MD_RDH: st <= MDWAIT;
        MDWAIT: if( md_done ) begin
            r[dstf] <= md_r0;
            if( s1_pair ) r[dstf+5'd1] <= md_r1;
            st <= FETCH;
        end
        // memory engine, low then optional high beat per word
        MRD1: if( !bus_cs ) begin rd32(mad); dsn <= ~lanes[3:0]; end
            else if( bus_ok ) begin
                bus_cs <= 0;
                if( mcross ) begin
                    mlo <= din;
                    st  <= MRD2;
                end else begin
                    r[mreg] <= mext(rd64s[31:0]);
                    mnext(MRD1);
                end
            end
        MRD2: if( !bus_cs ) begin rd32(mad+32'd4); dsn <= ~lanes[7:4]; end
            else if( bus_ok ) begin
                bus_cs  <= 0;
                r[mreg] <= mext(rd64s[31:0]);
                mnext(MRD1);
            end
        MWR1: if( !bus_cs ) begin
                wr32(mad, wr64[31:0]);
                dsn <= ~lanes[3:0];
                whi <= wr64[63:32];
            end else if( bus_ok ) begin
                bus_cs <= 0;
                if( mcross ) st <= MWR2;
                else mnext(MWR1);
            end
        MWR2: if( !bus_cs ) begin
                wr32(mad+32'd4, whi);
                dsn <= ~lanes[7:4];
            end else if( bus_ok ) begin
                bus_cs <= 0;
                mnext(MWR1);
            end
        // call: save RIP, spill or cache the local frame, allocate a new one
        CALL_RIP: begin
            r[2] <= IP; // RIP
            if( rpos >= 16'sd4 ) begin
                mad     <= {r[31][31:6], 6'd0};
                mreg    <= 0;
                mcnt    <= 5'd16;
                msz     <= 2'd2;
                wsrc_rc <= 0;
                seq     <= SEQ_SPILL;
                st      <= MWR1;
            end else st <= CALL_FIN;    // frame copied by rc_we
        end
        CALL_FIN: begin
            rpos  <= rpos + 16'sd1;
            r[ 0] <= {r[31][31:3], 3'd0} | {29'd0, ctype}; // PFP | type
            r[31] <= newfp;
            r[ 1] <= newfp + 32'd64;
            IP    <= ctgt;
            st    <= in_int ? INT_WPC : FETCH;
        end
        // ret: type 0 local, type 7 interrupt return
        RET_RPC: if( !bus_cs ) rd32(r[31]-32'd16);
            else if( bus_ok ) begin bus_cs<=0; tmp_pc<=din; st<=RET_RAC; end
        RET_RAC: if( !bus_cs ) rd32(r[31]-32'd12);
            else if( bus_ok ) begin bus_cs<=0; tmp_ac<=din; st<=RET_POP; end
        RET_POP: begin
            r[31] <= {r[0][31:6], 6'd0};
            rpos  <= rposm1 < 16'sd0 ? 16'sd0 : rposm1;
            if( rposm1 >= 16'sd4 || rposm1 < 16'sd0 ) begin
                mad  <= {r[0][31:6], 6'd0};
                mreg <= 0;
                mcnt <= 5'd16;
                msz  <= 2'd2;
                msig <= 0;
                seq  <= SEQ_FILL;
                st   <= MRD1;
            end else begin
                for( i3=0; i3<16; i3=i3+1 ) r[i3] <= rc_q[i3*32 +: 32];
                st <= RET_FIN;
            end
        end
        RET_FIN: begin
            IP <= r[2]; // restored RIP
            if( rtype==3'd7 ) begin
                AC  <= tmp_ac;
                PCS <= tmp_pc;
            end
            st <= FETCH;
        end
        // flushreg: write cached frames back to their stack addresses
        FLUSH_NX: begin
            if( flush_f >= flush_lim ) begin
                rpos <= 16'sd0;
                st   <= FETCH;
            end else begin
                mad     <= rc_fa;
                mreg    <= 0;
                mcnt    <= 5'd16;
                msz     <= 2'd2;
                wsrc_rc <= 1;
                seq     <= SEQ_FLUSH;
                st      <= MWR1;
            end
        end
        // interrupt entry, per MAME take_interrupt + do_call(type 7)
        INT_TAB: if( !bus_cs ) rd32(PRCB+32'd20);
            else if( bus_ok ) begin bus_cs<=0; int_tab<=din; st<=INT_ISP; end
        INT_ISP: if( !bus_cs ) rd32(PRCB+32'd24);
            else if( bus_ok ) begin bus_cs<=0; tmp<=din; st<=INT_VEC; end
        INT_VEC: if( !bus_cs ) rd32(int_tab + 32'd36 + {22'd0,int_vec-8'd8,2'd0});
            else if( bus_ok ) begin
                bus_cs  <= 0;
                ctgt    <= din;
                ctype   <= 3'd7;
                // nested interrupts keep the current stack
                int_stk <= (((PCS[13] ? r[1] : tmp) + 32'd63) & 32'hffff_ffc0)
                           + 32'd64;
                st      <= CALL_RIP;
            end
        INT_WPC: if( !bus_cs ) wr32(r[31]-32'd16, PCS);
            else if( bus_ok ) begin bus_cs<=0; st<=INT_WAC; end
        INT_WAC: if( !bus_cs ) wr32(r[31]-32'd12, AC);
            else if( bus_ok ) begin bus_cs<=0; st<=INT_WVC; end
        INT_WVC: if( !bus_cs ) wr32(r[31]-32'd8, {24'd0, int_vec-8'd8});
            else if( bus_ok ) begin
                bus_cs <= 0;
                PCS    <= (PCS & ~32'h001f_0401) | {11'd0,int_vec[7:3],16'd0}
                          | 32'h0000_2002;
                in_int <= 0;
                st     <= FETCH;
            end
        // calls through the system procedure table, local entries only
        CALLS_PT: if( !bus_cs ) rd32(SAT+32'd152);
            else if( bus_ok ) begin bus_cs<=0; tmp<=din; st<=CALLS_EN; end
        CALLS_EN: if( !bus_cs ) rd32(tmp + 32'd48 + {t1[29:0],2'd0});
            else if( bus_ok ) begin
                bus_cs <= 0;
                if( din[1:0]!=2'd0 ) st <= HALT; // supervisor calls unsupported
                else begin
                    ctgt  <= din;
                    ctype <= 3'd0;
                    st    <= CALL_RIP;
                end
            end
        // synmov/synmovq: ff000004 = ICR, ff000010 = IAC message
        SYN_RD: if( !bus_cs ) rd32(syn_src);
            else if( bus_ok ) begin bus_cs<=0; tmp<=din; st<=SYN_WR; end
        SYN_WR: if( syn_dst==32'hff00_0004 ) begin
                ICR      <= tmp;
                AC[2:0]  <= 3'b010;
                st       <= FETCH;
            end else if( !bus_cs ) wr32(syn_dst, tmp);
            else if( bus_ok ) begin
                bus_cs  <= 0;
                AC[2:0] <= 3'b010;
                st      <= FETCH;
            end
        SYNQ_RD: if( !bus_cs ) rd32(syn_src + {27'd0,cnt[2:0],2'd0});
            else if( bus_ok ) begin
                bus_cs <= 0;
                if( iac_mode ) begin
                    case( cnt[1:0] )
                    2'd0: iac0<=din;
                    2'd1: iac1<=din;
                    2'd2: iac2<=din;
                    2'd3: iac3<=din;
                    endcase
                    if( cnt[1:0]==2'd3 ) st <= IAC_EXE;
                    else cnt <= cnt+5'd1;
                end else begin
                    tmp <= din;
                    st  <= SYNQ_WR;
                end
            end
        SYNQ_WR: if( !bus_cs ) wr32(syn_dst + {27'd0,cnt[2:0],2'd0}, tmp);
            else if( bus_ok ) begin
                bus_cs <= 0;
                if( cnt[1:0]==2'd3 ) begin
                    AC[2:0] <= 3'b010;
                    st      <= FETCH;
                end else begin
                    cnt <= cnt+5'd1;
                    st  <= SYNQ_RD;
                end
            end
        IAC_EXE: begin
            AC[2:0] <= 3'b010;
            st      <= FETCH;
            case( iac0[31:24] )
            8'h93: begin SAT<=iac1; PRCB<=iac2; IP<=iac3; ic_clr<=1; end // reinit
            8'h89: ic_clr <= 1;    // invalidate instruction cache
            8'h80: st <= IAC_W0;   // store SAT & PRCB to memory
            default: ;             // 40/41/8f/91/92 ignored
            endcase
        end
        IAC_W0: if( !bus_cs ) wr32(iac1, SAT);
            else if( bus_ok ) begin bus_cs<=0; st<=IAC_W1; end
        IAC_W1: if( !bus_cs ) wr32(iac1+32'd4, PRCB);
            else if( bus_ok ) begin bus_cs<=0; st<=FETCH; end
        // atadd/atmod: read-modify-write, non-atomic (single bus master)
        AT_RD: if( !bus_cs ) rd32(mad);
            else if( bus_ok ) begin bus_cs<=0; tmp<=din; st<=AT_WR; end
        AT_WR: if( !bus_cs )
                wr32(mad, s1_cls==OC_ATADD ? tmp+t2 : (t3 & t2)|(tmp & ~t2));
            else if( bus_ok ) begin
                bus_cs  <= 0;
                r[dstf] <= tmp;
                st      <= FETCH;
            end
        HALT: halted <= 1;
        default: st <= HALT;
        endcase
      end
    end
end

endmodule
