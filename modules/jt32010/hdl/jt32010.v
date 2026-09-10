/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Texas Instruments TMS320C10 (TMS32010) digital signal processor.
 *
 * Harvard architecture: a 12-bit program address space holding 16-bit
 * instruction words, and a separate 8-bit data address space holding 16-bit
 * words. On the C10 the data space is 144 words of on-chip RAM (0x00-0x7f
 * "page 0", 0x80-0x8f "page 1"), which this module contains.
 *
 * Timing model
 * ------------
 * The real part divides CLKIN by four to make one machine cycle, and most
 * instructions take one machine cycle. This core is clocked by `cen` at the
 * CLKIN rate and spends four `cen` pulses on each machine cycle, so the
 * instruction stream advances at hardware rate. The four phases are:
 *
 *   ph0  present a program-memory address
 *   ph1  latch the instruction word, advance PC
 *   ph2  present the data-memory address
 *   ph3  the data word has arrived: compute, and write back
 *
 * Multi-cycle instructions repeat the four phases. `mcyc` counts which
 * machine cycle of the current instruction is running.
 *
 * `bio` follows MAME's bio() callback rather than the physical pin: drive it
 * high to make BIOZ branch. The real BIO pin is active low.
 */
module jt32010(
    input             rst,
    input             clk,
    input             cen,          // CLKIN rate, nominally 14 MHz

    input             hold,         // freeze the core (models the HALT input)
    input             irq,          // INT line; a high level latches a pending interrupt
    input             bio,          // polled by BIOZ. High = branch taken

    // program memory
    output     [11:0] rom_addr,
    input      [15:0] rom_data,

    // I/O ports (IN / OUT instructions)
    output      [2:0] pa,           // port address
    output reg [15:0] pdout,
    input      [15:0] pdin,
    output reg        pwr,          // one-cen write strobe
    output reg        prd,          // one-cen read strobe

    // trace taps for the MAME comparison bench. No effect on behaviour.
    output            dbg_fetch,    // one cen pulse as each instruction is latched
    output     [11:0] dbg_pc,       // address of the instruction being fetched
    output     [15:0] dbg_ir,
    output     [15:0] dbg_str,
    output     [31:0] dbg_acc,
    output     [31:0] dbg_preg,
    output     [15:0] dbg_treg,
    output     [15:0] dbg_ar0,
    output     [15:0] dbg_ar1,
    output     [11:0] dbg_stk0,
    output     [11:0] dbg_stk1,
    output     [11:0] dbg_stk2,
    output     [11:0] dbg_stk3
);

// ---------------------------------------------------------------- registers
reg  [11:0] pc;
reg  [15:0] ir;                     // instruction word
reg  [15:0] str;                    // status register
reg  [31:0] acc, preg;
reg  [15:0] treg;
reg  [15:0] ar0, ar1;
reg  [11:0] stk0, stk1, stk2, stk3;
reg         intf;                   // interrupt pending latch
reg  [15:0] hold_in;                // captured IN port data
reg  [15:0] ram_q;                  // data RAM read port, see "data RAM" below

localparam OV_B = 15, OVM_B = 14, INTM_B = 13, ARP_B = 8, DP_B = 0;

wire        ov   = str[OV_B];
wire        ovm  = str[OVM_B];
wire        intm = str[INTM_B];
wire        arp  = str[ARP_B];
wire        dp   = str[DP_B];

// The unused status bits read back as ones. MAME models this by OR-ing 0x1efe
// in after every write; the DSP program can see it through SST, so keep it.
localparam [15:0] STR_ONES = 16'h1efe;

wire [15:0] arp_reg = arp ? ar1 : ar0;

// ------------------------------------------------------------ phase counter
reg        take_l;                  // branch decision, held for the second cycle
reg  [1:0] ph;                      // phase within the machine cycle
reg  [1:0] mcyc;                    // machine cycle within the instruction
reg  [1:0] ncyc;                    // machine cycles this instruction needs

wire step = cen & ~hold;

// --------------------------------------------------------------- decode
wire [7:0] op   = ir[15:8];
wire [7:0] opl  = ir[7:0];
wire [4:0] op7f = ir[4:0];
wire       ext  = op == 8'h7f;

wire ind = opl[7];                  // indirect addressing through AR[ARP]

wire is_add   = op[7:4] == 4'h0;
wire is_sub   = op[7:4] == 4'h1;
wire is_lac   = op[7:4] == 4'h2;
wire is_sar   = op[7:1] == 7'h18;               // 0x30,0x31
wire is_lar   = op[7:1] == 7'h1c;               // 0x38,0x39
wire is_in    = op[7:3] == 5'h08;               // 0x40-0x47
wire is_out   = op[7:3] == 5'h09;               // 0x48-0x4f
wire is_sacl  = op == 8'h50;
wire is_sach  = op[7:3] == 5'h0b;               // 0x58-0x5f
wire is_addh  = op == 8'h60;
wire is_adds  = op == 8'h61;
wire is_subh  = op == 8'h62;
wire is_subs  = op == 8'h63;
wire is_subc  = op == 8'h64;
wire is_zalh  = op == 8'h65;
wire is_zals  = op == 8'h66;
wire is_tblr  = op == 8'h67;
wire is_mar   = op == 8'h68;
wire is_dmov  = op == 8'h69;
wire is_lt    = op == 8'h6a;
wire is_ltd   = op == 8'h6b;
wire is_lta   = op == 8'h6c;
wire is_mpy   = op == 8'h6d;
wire is_ldpk  = op == 8'h6e;
wire is_ldp   = op == 8'h6f;
wire is_lark  = op[7:1] == 7'h38;               // 0x70,0x71
wire is_xor   = op == 8'h78;
wire is_and   = op == 8'h79;
wire is_or    = op == 8'h7a;
wire is_lst   = op == 8'h7b;
wire is_sst   = op == 8'h7c;
wire is_tblw  = op == 8'h7d;
wire is_lack  = op == 8'h7e;
wire is_mpyk  = op[7:5] == 3'b100;              // 0x80-0x9f
wire is_banz  = op == 8'hf4;
wire is_bv    = op == 8'hf5;
wire is_bioz  = op == 8'hf6;
wire is_call  = op == 8'hf8;
wire is_br    = op == 8'hf9;
wire is_blz   = op == 8'hfa;
wire is_blez  = op == 8'hfb;
wire is_bgz   = op == 8'hfc;
wire is_bgez  = op == 8'hfd;
wire is_bnz   = op == 8'hfe;
wire is_bz    = op == 8'hff;

wire is_dint  = ext & (op7f == 5'h01);
wire is_eint  = ext & (op7f == 5'h02);
wire is_abs   = ext & (op7f == 5'h08);
wire is_zac   = ext & (op7f == 5'h09);
wire is_rovm  = ext & (op7f == 5'h0a);
wire is_sovm  = ext & (op7f == 5'h0b);
wire is_cala  = ext & (op7f == 5'h0c);
wire is_ret   = ext & (op7f == 5'h0d);
wire is_pac   = ext & (op7f == 5'h0e);
wire is_apac  = ext & (op7f == 5'h0f);
wire is_spac  = ext & (op7f == 5'h10);
wire is_push  = ext & (op7f == 5'h1c);
wire is_pop   = ext & (op7f == 5'h1d);

wire is_cond  = is_banz | is_bv | is_bioz | is_blz | is_blez |
                is_bgz  | is_bgez | is_bnz | is_bz;

// Instructions that consume the addressing field, and so must run the AR and
// ARP post-modification exactly once.
wire uses_dma = is_add | is_sub | is_lac | is_lar | is_sar | is_sacl |
                is_sach | is_addh | is_adds | is_subh | is_subs | is_subc |
                is_zalh | is_zals | is_tblr | is_mar | is_dmov | is_lt |
                is_ltd | is_lta | is_mpy | is_ldp | is_xor | is_and |
                is_or | is_lst | is_sst | is_tblw | is_in | is_out;

// ------------------------------------------------------- data address
// Direct addressing uses the low seven opcode bits inside the page named by
// DP. Indirect uses the low byte of the current AR. SST is the exception:
// its direct form is forced to page 1.
wire [7:0] dma = ind    ? arp_reg[7:0]     :
                 is_sst ? {1'b1, opl[6:0]} :
                          {dp,   opl[6:0]};

// AR post-modification, indirect only. Bit 5 increments, bit 4 decrements,
// and only the low nine bits take part. Both bits set means no change.
reg  [8:0] ar_mod;
always @* begin
    case( opl[5:4] )
        2'b10:   ar_mod = arp_reg[8:0] + 9'd1;
        2'b01:   ar_mod = arp_reg[8:0] - 9'd1;
        default: ar_mod = arp_reg[8:0];
    endcase
end
wire [15:0] ar_new  = {arp_reg[15:9], ar_mod};
wire        ar_upd  = ind & (opl[5] | opl[4]);
// LST must not repoint ARP; SST does not update it either.
wire        arp_upd = ind & ~opl[3] & ~is_lst & ~is_sst;

// SAR stores the auxiliary register *after* the post-modification, so a
// "SAR AR0,*+" with ARP=0 writes the incremented value.
wire [15:0] sar_src_pre = op[0] ? ar1 : ar0;
wire        sar_self    = ar_upd & (op[0] == arp);
wire [15:0] sar_src     = sar_self ? ar_new : sar_src_pre;

// ------------------------------------------------------- program address
// Combinational, so the word is back on the next clock edge. TBLR reads the
// program space at the accumulator's address in its second machine cycle.
assign rom_addr = (mcyc != 2'd0 && is_tblr) ? acc[11:0] : pc;

// ------------------------------------------------------------- the shifter
// MAME's getdata(shift,signext): take the data word, optionally sign extend
// to 32 bits, then shift left. ADD/SUB/LAC take a 0-15 shift from the opcode;
// SUBH uses 16 and SUBC 15, both without sign extension.
wire [3:0]  op_shift = ir[11:8];
wire [4:0]  shamt    = is_subh ? 5'd16 :
                       is_subc ? 5'd15 :
                       (is_add | is_sub | is_lac) ? {1'b0, op_shift} : 5'd0;
wire        signext  = is_add | is_sub | is_lac;
wire [31:0] dext     = signext ? {{16{ram_q[15]}}, ram_q} : {16'd0, ram_q};
wire [31:0] dshift   = dext << shamt;

// ------------------------------------------------------------------- ALU
// One 32-bit add/subtract shared by every arithmetic instruction, with the
// two overflow tests MAME uses.
reg  [31:0] alu_b;
reg         alu_sub;
wire [31:0] alu_r   = alu_sub ? acc - alu_b : acc + alu_b;
wire [31:0] add_ovf_v = ~(acc ^ alu_b) & (acc ^ alu_r);
wire [31:0] sub_ovf_v =  (acc ^ alu_b) & (acc ^ alu_r);
wire        add_ovf = add_ovf_v[31];
wire        sub_ovf = sub_ovf_v[31];
wire        alu_ovf = alu_sub ? sub_ovf : add_ovf;
wire [31:0] alu_sat = acc[31] ? 32'h8000_0000 : 32'h7fff_ffff;

always @* begin
    alu_sub = 1'b0;
    alu_b   = dshift;
    case( 1'b1 )
        is_sub, is_subh, is_subs: begin alu_sub = 1'b1; alu_b = dshift; end
        is_spac:                  begin alu_sub = 1'b1; alu_b = preg;   end
        is_apac, is_lta, is_ltd:  begin                 alu_b = preg;   end
        default:;
    endcase
end
wire alu_used = is_add | is_sub | is_adds | is_subs | is_subh |
                is_apac | is_spac | is_lta | is_ltd;

// ADDH adds into the accumulator's high half only, with a 16-bit overflow test
wire [15:0] addh_r   = acc[31:16] + ram_q;
wire [15:0] addh_ovf_v = ~(acc[31:16] ^ ram_q) & (acc[31:16] ^ addh_r);
wire        addh_ovf = addh_ovf_v[15];
wire [15:0] addh_sat = acc[31] ? 16'h8000 : 16'h7fff;

// SUBC, a conditional-subtract divide step
wire [31:0] subc_d   = acc - dshift;
wire [31:0] subc_ovf_v = (acc ^ dshift) & (acc ^ subc_d);
wire        subc_ovf = subc_ovf_v[31];

// ABS, with the one saturation case
wire [31:0] acc_neg  = -acc;

// multiplier, and the product MAME special-cases
wire signed [15:0] mul_a = is_mpyk ? $signed(treg) : $signed(ram_q);
wire signed [15:0] mul_b = is_mpyk ? $signed({{3{ir[12]}}, ir[12:0]}) : $signed(treg);
wire        [31:0] mul_r = mul_a * mul_b;
wire        [31:0] mul_f = (!is_mpyk && mul_r == 32'h4000_0000) ? 32'hc000_0000 : mul_r;

// SACH shifts the accumulator left 0-7 and stores the high half
wire [31:0] sach_s = acc << ir[10:8];

// branch conditions
reg take;
always @* begin
    case( 1'b1 )
        is_banz: take = |arp_reg[8:0];
        is_bv:   take = ov;
        is_bioz: take = bio;
        is_blz:  take = acc[31];
        is_blez: take = acc[31] | (acc == 32'd0);
        is_bgz:  take = ~acc[31] & (acc != 32'd0);
        is_bgez: take = ~acc[31];
        is_bnz:  take = acc != 32'd0;
        is_bz:   take = acc == 32'd0;
        default: take = 1'b0;
    endcase
end

// machine cycles this instruction needs
reg [1:0] cyc_need;
always @* begin
    case( 1'b1 )
        is_tblr, is_tblw:                  cyc_need = 2'd3;
        is_br, is_call, is_in, is_out,
        is_cala, is_ret, is_push, is_pop:  cyc_need = 2'd2;
        default: cyc_need = (is_cond && take) ? 2'd2 : 2'd1;
    endcase
end

// An interrupt is taken between instructions, but never straight after MPY,
// MPYK or EINT, whose results the handler must not disturb.
wire int_block = (op == 8'h6d) || (op[7:5] == 3'b100) || (ir == 16'h7f82);
wire take_int  = intf & ~intm & ~int_block;

// what a store writes
reg [15:0] store_d;
always @* begin
    case( 1'b1 )
        is_sar:  store_d = sar_src;
        is_sacl: store_d = acc[15:0];
        is_sach: store_d = sach_s[31:16];
        is_sst:  store_d = str;
        is_in:   store_d = hold_in;
        is_tblr: store_d = hold_in;         // reused to hold the program word
        default: store_d = 16'd0;
    endcase
end
wire store_c0 = is_sar | is_sacl | is_sach | is_sst;   // written in machine cycle 0
wire store_c2 = is_in | is_tblr;                       // written in a later cycle

// ------------------------------------------------------------- data RAM
// 144 words on the C10. Reads outside that range give zero and writes are
// dropped, matching the address map MAME installs.
//
// The read address is combinational: `dma` is valid from ph2 (the instruction
// word was latched at the end of ph1), so the word is registered into ram_q at
// the end of ph2 and is ready for the ALU in ph3. Writes are also decided
// combinationally in ph3 and commit on that same edge, which keeps a store and
// the following instruction's load one clean cycle apart.
reg  [15:0] ram[0:255];

// Power-up contents. A real BRAM comes up at a known state and the DSP program
// initialises what it uses; this also keeps simulation free of X propagation.
integer ri;
initial begin
    for( ri=0; ri<256; ri=ri+1 ) ram[ri] = 16'd0;
    ram_q = 16'd0;
end

// A store belonging to a multi-cycle instruction commits after the auxiliary
// register has already been post-modified, so the address it should use is
// captured here, while it is still the pre-modification one.
reg  [7:0]  dma_l;
always @(posedge clk) if( step && ph==2'd2 && mcyc==2'd0 ) dma_l <= dma;

wire        ph3_c0 = (ph==2'd3) && (mcyc==2'd0);
wire        ph3_lc = (ph==2'd3) && (mcyc!=2'd0) && (mcyc==ncyc-2'd1);

wire        dmov_wr   = is_dmov | is_ltd;   // these write one address higher
wire        ram_wr    = step & ( (ph3_c0 & (store_c0 | dmov_wr)) |
                                 (ph3_lc & store_c2) );
wire [7:0]  ram_waddr = dmov_wr ? dma_l + 8'd1 : dma_l;
wire [15:0] ram_wdata = dmov_wr ? ram_q : store_d;

always @(posedge clk) begin
    if( step ) ram_q <= (dma <= 8'h8f) ? ram[dma] : 16'd0;
    if( ram_wr && ram_waddr <= 8'h8f ) ram[ram_waddr] <= ram_wdata;
end

// --------------------------------------------------------- status register
// Several instructions touch more than one status bit in the same step: LDP
// sets DP while the addressing mode repoints ARP, and any arithmetic
// instruction can raise OV alongside an ARP update. The whole register is
// therefore built as one value and written once.
wire ov_set = (alu_used & alu_ovf) | (is_addh & addh_ovf) | (is_subc & subc_ovf);

reg [15:0] str_nxt;
always @* begin
    str_nxt = str;
    if( uses_dma && arp_upd ) str_nxt[ARP_B]  = opl[0];
    if( is_ldp             )  str_nxt[DP_B]   = ram_q[0];
    if( is_ldpk            )  str_nxt[DP_B]   = opl[0];
    if( is_dint            )  str_nxt[INTM_B] = 1'b1;
    if( is_eint            )  str_nxt[INTM_B] = 1'b0;
    if( is_rovm            )  str_nxt[OVM_B]  = 1'b0;
    if( is_sovm            )  str_nxt[OVM_B]  = 1'b1;
    if( ov_set             )  str_nxt[OV_B]   = 1'b1;
    if( is_bv && take      )  str_nxt[OV_B]   = 1'b0;   // BV consumes the flag
    if( is_lst             )  str_nxt = (str   &  (16'd1<<INTM_B)) |
                                        (ram_q & ~(16'd1<<INTM_B));
    str_nxt = str_nxt | STR_ONES;
end

assign pa        = ir[10:8];
assign dbg_fetch = step & (ph==2'd1) & (mcyc==2'd0);
assign dbg_pc    = pc;
assign dbg_ir    = ir;
assign dbg_str   = str;
assign dbg_acc   = acc;
assign dbg_preg  = preg;
assign dbg_treg  = treg;
assign dbg_ar0   = ar0;
assign dbg_ar1   = ar1;
assign dbg_stk0  = stk0;
assign dbg_stk1  = stk1;
assign dbg_stk2  = stk2;
assign dbg_stk3  = stk3;

// --------------------------------------------------------------- sequencer
always @(posedge clk) begin
    if( rst ) begin
        pc     <= 12'd0;
        ir     <= 16'h7f80;         // NOP, so the interrupt block test is false
        str    <= STR_ONES | (16'd1<<OVM_B) | (16'd1<<INTM_B);   // 0x7efe
        acc    <= 32'd0;
        preg   <= 32'd0;
        treg   <= 16'd0;
        ar0    <= 16'd0;
        ar1    <= 16'd0;
        stk0   <= 12'd0; stk1 <= 12'd0; stk2 <= 12'd0; stk3 <= 12'd0;
        intf   <= 1'b0;
        ph     <= 2'd0;
        mcyc   <= 2'd0;
        take_l <= 1'b0;
        ncyc   <= 2'd1;
        prd    <= 1'b0;
        pwr    <= 1'b0;
        pdout    <= 16'd0;
        hold_in  <= 16'd0;
    end else begin
        if( irq ) intf <= 1'b1;     // pending interrupts latch; the pin cannot clear them
        if( step ) begin
            ph     <= ph + 2'd1;
            prd    <= 1'b0;
            pwr    <= 1'b0;

            case( ph )
            // -------------------------------------------------------- ph0
            2'd0: begin
                // The program address is combinational from pc, so an
                // interrupt has to redirect PC here and then repeat this
                // phase, otherwise the fetch would still use the old address.
                if( mcyc == 2'd0 && take_int ) begin
                    stk0 <= stk1; stk1 <= stk2; stk2 <= stk3; stk3 <= pc;
                    pc   <= 12'd2;
                    intf <= 1'b0;
                    str  <= (str | (16'd1<<INTM_B)) | STR_ONES;
                    ph   <= 2'd0;       // redo this phase with the new PC
                end
            end

            // -------------------------------------------------------- ph1
            2'd1: begin
                if( mcyc == 2'd0 ) begin
                    ir <= rom_data;
                    pc <= pc + 12'd1;
                end else begin
                    // second or third machine cycle
                    if( is_tblr ) hold_in <= rom_data;
                    if( is_in   ) hold_in <= pdin;
                end
            end

            // -------------------------------------------------------- ph2
            2'd2: begin
                // `dma` is valid now; the RAM read is issued combinationally.
            end

            // -------------------------------------------------------- ph3
            2'd3: begin
                if( mcyc == 2'd0 ) begin
                    ncyc   <= cyc_need;
                    mcyc   <= (cyc_need == 2'd1) ? 2'd0 : 2'd1;
                    // BANZ decrements the register it just tested and BV
                    // clears the flag it just tested, so the decision has to
                    // be held rather than recomputed in the second cycle.
                    take_l <= take;

                    // ---- status register, and the auxiliary register
                    //      post-modification that feeds part of it
                    str <= str_nxt;
                    if( uses_dma && ar_upd ) begin
                        if( arp ) ar1 <= ar_new; else ar0 <= ar_new;
                    end

                    // ---- accumulator and flags
                    if( alu_used ) begin
                        acc <= alu_r;
                        if( alu_ovf && ovm ) acc <= alu_sat;
                    end
                    if( is_addh ) begin
                        acc[31:16] <= addh_r;
                        if( addh_ovf && ovm ) acc[31:16] <= addh_sat;
                    end
                    if( is_subc )
                        acc <= subc_d[31] ? {acc[30:0], 1'b0} : {subc_d[30:0], 1'b1};
                    if( is_lac  ) acc <= dshift;
                    if( is_lack ) acc <= {24'd0, opl};
                    if( is_zac  ) acc <= 32'd0;
                    if( is_zalh ) acc <= {ram_q, 16'd0};
                    if( is_zals ) acc <= {16'd0, ram_q};
                    if( is_and  ) acc <= acc & {16'd0, ram_q};
                    if( is_or   ) acc[15:0] <= acc[15:0] | ram_q;
                    if( is_xor  ) acc[15:0] <= acc[15:0] ^ ram_q;
                    if( is_pac  ) acc <= preg;
                    if( is_abs && acc[31] ) begin
                        acc <= acc_neg;
                        if( ovm && acc_neg == 32'h8000_0000 ) acc <= 32'h7fff_ffff;
                    end

                    // ---- T, P and the auxiliary registers
                    if( is_lt | is_lta | is_ltd ) treg <= ram_q;
                    if( is_mpy | is_mpyk )        preg <= mul_f;
                    if( is_lar  ) begin if( op[0] ) ar1 <= ram_q; else ar0 <= ram_q; end
                    if( is_lark ) begin if( op[0] ) ar1 <= {8'd0, opl}; else ar0 <= {8'd0, opl}; end

                    // ---- OUT drives the port with the word just read
                    if( is_out ) begin
                        pdout <= ram_q;
                        pwr   <= 1'b1;
                    end
                    if( is_in ) prd <= 1'b1;

                    // ---- branches that are not taken skip their operand word
                    if( is_cond && !take ) pc <= pc + 12'd1;

                    // ---- BANZ always decrements, after the test
                    if( is_banz ) begin
                        if( arp ) ar1 <= {ar1[15:9], ar1[8:0]-9'd1};
                        else      ar0 <= {ar0[15:9], ar0[8:0]-9'd1};
                    end

                    // ---- stack operations that complete in one cycle here
                    if( is_push ) begin
                        stk0 <= stk1; stk1 <= stk2; stk2 <= stk3;
                        stk3 <= acc[11:0];
                    end
                    if( is_pop ) begin
                        acc  <= {20'd0, stk3};
                        stk3 <= stk2; stk2 <= stk1; stk1 <= stk0;
                    end
                    if( is_ret ) begin
                        pc   <= stk3;
                        stk3 <= stk2; stk2 <= stk1; stk1 <= stk0;
                    end
                    if( is_cala ) begin
                        stk0 <= stk1; stk1 <= stk2; stk2 <= stk3; stk3 <= pc;
                        pc   <= acc[11:0];
                    end
                end else begin
                    // ------------------------------------ later machine cycles
                    if( mcyc == 2'd1 ) begin
                        // taken conditional branch, BR: jump to the operand
                        if( (is_cond && take_l) || is_br ) pc <= rom_data[11:0];
                        if( is_call ) begin
                            stk0 <= stk1; stk1 <= stk2; stk2 <= stk3;
                            stk3 <= pc + 12'd1;
                            pc   <= rom_data[11:0];
                        end
                        // TBLR/TBLW copy the stack down one, a microcode quirk
                        if( is_tblr | is_tblw ) stk0 <= stk1;
                    end
                    if( mcyc == ncyc - 2'd1 ) begin
                        // final cycle: retire the instruction. The store, if
                        // any, is issued combinationally on this same edge.
                        mcyc <= 2'd0;
                    end else begin
                        mcyc <= mcyc + 2'd1;
                    end
                end
            end
            endcase
        end
    end
end

endmodule
