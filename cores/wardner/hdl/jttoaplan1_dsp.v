/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Toaplan TP-009 / Twin Cobra DSP subsystem.
 *
 * Wraps the TMS320C10 with the glue the arcade board puts around it: the
 * window through which the DSP reaches the host CPU's memory, the polled BIO
 * handshake, and the interlock that stops the host CPU while the DSP works.
 *
 * How the two processors share the bus
 * ------------------------------------
 * They never run together. Writing a 1 to the run bit does three things at
 * once: it lets the DSP out of reset, raises its interrupt, and asserts the
 * host CPU's HALT line. The DSP then walks the host's address space as the
 * only master. When its routine is done it writes a zero into the first few
 * words of host work RAM, which arms an "execute" flag, and then writes zero
 * to its port 3 - and *that* is what drops the host's HALT line again.
 *
 * Because of that interlock there is no bus arbitration to build: while
 * halt_main is high the host is stopped, so the DSP's accesses cannot collide
 * with it.
 *
 * The address decode is the only part that differs between boards. Wardner
 * drives a Z80 whose RAM is byte-wide, so it uses an 11-bit word index inside
 * a 4 KB window; Twin Cobra drives a 68000 and uses a 13-bit index inside a
 * 16 KB window. Set TWINCOBR to pick. Only the Wardner decode has been
 * exercised in simulation so far.
 */
module jttoaplan1_dsp #(parameter TWINCOBR=0) (
    input             rst,
    input             clk,
    input             cen,          // 14 MHz, the DSP's CLKIN

    input             dsp_on,       // run bit from the board's LS259
    output reg        halt_main,    // hold the host CPU

    // window into host memory. host_sel names which of the host's RAMs the
    // DSP is pointing at; the address is a 16-bit word index into it.
    output     [12:0] host_addr,
    output reg [ 1:0] host_sel,
    output     [15:0] host_dout,
    input      [15:0] host_din,
    output            host_we,

    // DSP program ROM
    output     [11:0] rom_addr,
    input      [15:0] rom_data,

    // observation points for the transaction bench
    output            dbg_bio,
    output            dbg_exec,
    output            dbg_rd,       // a host read completed this cen
    output            dbg_wr,       // a host write completed this cen
    output            dbg_p0,       // the window was re-pointed
    output            dbg_p3,       // a control word went to port 3
    output     [15:0] dbg_pdout,
    output            dbg_pwr,      // the core's raw port-write strobe
    output      [1:0] dbg_sel_new,  // decode of the word being written to port 0
    output     [12:0] dbg_addr_new,
    // the DSP core's own trace taps, passed through for instruction-level
    // comparison against the reference model
    output            dbg_fetch,
    output     [11:0] dbg_pc,
    output     [15:0] dbg_str,
    output     [31:0] dbg_acc,
    output     [31:0] dbg_preg,
    output     [15:0] dbg_treg,
    output     [15:0] dbg_ar0,
    output     [15:0] dbg_ar1,
    output     [11:0] dbg_stk0,
    output     [11:0] dbg_stk1,
    output     [11:0] dbg_stk2,
    output     [11:0] dbg_stk3,
    output     [15:0] dbg_romdata
);
assign dbg_romdata = rom_data;

// host_sel encoding
localparam [1:0] SEL_WORK = 2'd0,   // Z80 work RAM      (0x7000 on Wardner)
                 SEL_OBJ  = 2'd1,   // sprite RAM        (0x8000)
                 SEL_PAL  = 2'd2,   // palette RAM       (0xa000)
                 SEL_NONE = 2'd3;

reg  [12:0] addr_l;                 // latched word index
reg         bio, execute;
reg         on_l;

wire [ 2:0] pa;
wire [15:0] pdout, pdin;
wire        pwr, prd;

// ---------------------------------------------------------- address decode
// Wardner: seg = data & 0xe000, with 0x6000 folded onto 0x7000; because
// 0x7000 & 0xe000 is itself 0x6000, both land on the same three top bits.
// The offset is (data & 0x07ff) shifted up one to reach an even byte, which
// is simply the word index.
//
// Twin Cobra: seg = (data & 0xe000) << 3 and offset = (data & 0x1fff) << 1,
// i.e. the same three select bits over a 13-bit word index.
wire [ 2:0] seg_sel = pdout[15:13];
wire [12:0] off_new = TWINCOBR ? pdout[12:0] : {2'd0, pdout[10:0]};

reg  [1:0] sel_new;
always @* begin
    case( seg_sel )
        3'b011:  sel_new = SEL_WORK;    // 0x6000 and 0x7000
        3'b100:  sel_new = SEL_OBJ;     // 0x8000
        3'b101:  sel_new = SEL_PAL;     // 0xa000
        default: sel_new = SEL_NONE;    // MAME logs these and returns zero
    endcase
end

// While the run bit is low the DSP is frozen, and its port strobes hold their
// last value because the core is not stepping. The wrapper must therefore be
// gated by exactly the same condition as the core, or a stale strobe would be
// re-executed on every cen.
wire dsp_step = cen & dsp_on;

// The host is released when the DSP writes a zero into word 0 or 1 of work
// RAM. MAME tests the byte offset for "< 3", and the offset is always even,
// so that is word index 0 or 1. The window used is the latched one, set by an
// earlier write to port 0.
wire exec_hit = (host_sel == SEL_WORK) && (addr_l[12:1] == 12'd0) && (pdout == 16'd0);

assign host_addr = addr_l;
assign host_dout = pdout;
assign host_we   = dsp_step & pwr & (pa == 3'd1) & (host_sel != SEL_NONE);
assign pdin      = (pa == 3'd1 && host_sel != SEL_NONE) ? host_din : 16'd0;

assign dbg_bio  = bio;
assign dbg_exec = execute;
assign dbg_rd   = dsp_step & prd & (pa == 3'd1);
assign dbg_wr   = host_we;
assign dbg_p0   = dsp_step & pwr & (pa == 3'd0);
assign dbg_p3   = dsp_step & pwr & (pa == 3'd3);
assign dbg_pdout    = pdout;
assign dbg_pwr      = pwr;
assign dbg_sel_new  = sel_new;
assign dbg_addr_new = off_new;

// ------------------------------------------------------------- the handshake
// Raising the run bit interrupts the DSP and stops the host. MAME sets the
// pending flag on the transition, so a single-cen pulse is generated here
// rather than holding the line.
wire on_rise = dsp_on & ~on_l;
reg  irq_pulse;

always @(posedge clk) begin
    if( rst ) begin
        addr_l    <= 13'd0;
        host_sel  <= SEL_NONE;
        bio       <= 1'b0;
        execute   <= 1'b0;
        halt_main <= 1'b0;
        on_l      <= 1'b0;
        irq_pulse <= 1'b0;
    end else begin
        on_l      <= dsp_on;
        irq_pulse <= 1'b0;

        if( on_rise ) begin
            irq_pulse <= 1'b1;
            halt_main <= 1'b1;      // the host stops here
        end

        if( dsp_step ) begin
            if( pwr ) begin
                case( pa )
                3'd0: begin         // port 0: point the window
                    addr_l   <= off_new;
                    host_sel <= sel_new;
                end
                3'd1: begin         // port 1: write through to host memory
                    // the write itself is host_we, driven combinationally
                    if( exec_hit ) execute <= 1'b1;
                end
                3'd3: begin         // port 3: BIO, and the host release
                    if( pdout[15] ) bio <= 1'b0;
                    if( pdout == 16'd0 ) begin
                        if( execute ) begin
                            halt_main <= 1'b0;   // the host runs again
                            execute   <= 1'b0;
                        end
                        bio <= 1'b1;
                    end
                end
                default:;
                endcase
            end
        end
    end
end

jt32010 u_dsp(
    .rst      ( rst        ),
    .clk      ( clk        ),
    .cen      ( cen        ),
    .hold     ( ~dsp_on    ),       // the run bit gates the DSP's clock
    .irq      ( irq_pulse  ),
    .bio      ( bio        ),
    .rom_addr ( rom_addr   ),
    .rom_data ( rom_data   ),
    .pa       ( pa         ),
    .pdout    ( pdout      ),
    .pdin     ( pdin       ),
    .pwr      ( pwr        ),
    .prd      ( prd        ),
    .dbg_fetch( dbg_fetch  ),
    .dbg_pc   ( dbg_pc     ),
    .dbg_ir   (            ),
    .dbg_str  ( dbg_str    ),
    .dbg_acc  ( dbg_acc    ),
    .dbg_preg ( dbg_preg   ),
    .dbg_treg ( dbg_treg   ),
    .dbg_ar0  ( dbg_ar0    ),
    .dbg_ar1  ( dbg_ar1    ),
    .dbg_stk0 ( dbg_stk0   ),
    .dbg_stk1 ( dbg_stk1   ),
    .dbg_stk2 ( dbg_stk2   ),
    .dbg_stk3 ( dbg_stk3   )
);

endmodule
