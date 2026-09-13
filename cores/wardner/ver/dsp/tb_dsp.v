/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Transaction bench for the Toaplan DSP subsystem. A model of the host CPU
 * raises the run bit, waits to be released, then drops it again, while every
 * host-visible event is logged in the same format as ref32010.c's toaplan
 * mode so the two can be diffed.
 */
`timescale 1ns/1ps

module tb_dsp;

reg         clk = 0, rst = 1;
reg         cen = 0;
reg         dsp_on = 0;

wire        halt_main;
wire [12:0] host_addr;
wire [ 1:0] host_sel;
wire [15:0] host_dout;
reg  [15:0] host_din;
wire        host_we;
wire [11:0] rom_addr;
reg  [15:0] rom_data;

wire        dbg_bio, dbg_exec, dbg_rd, dbg_wr, dbg_p0, dbg_p3, dbg_pwr;
reg  [31:0] itrace;
wire [15:0] dbg_pdout;
wire [ 1:0] dbg_sel_new;
wire [12:0] dbg_addr_new;

reg  [15:0] rom[0:4095];
reg  [15:0] work[0:2047];
reg  [15:0] obj [0:2047];
reg  [15:0] pal [0:2047];

integer     k, fh;
integer     viol = 0;        // property violations, counted near the bottom
reg  [31:0] acts, act, tail, tailn, abortn, abcnt;
reg  [31:0] abortwr, hseed, freecens;
reg         aborted, dbg_wr_d;
reg  [ 1:0] st;
reg [255:0] progfile;

localparam ST_START=2'd0, ST_WAIT=2'd1, ST_TAIL=2'd2, ST_NEXT=2'd3;

initial begin
    if( !$value$plusargs("prog=%s", progfile) ) progfile = "dsp.hex";
    if( !$value$plusargs("acts=%d", acts)     ) acts = 4;
    if( !$value$plusargs("tail=%d", tailn)   ) tailn = 900;
    if( !$value$plusargs("abort=%d", abortn) ) abortn = 0;
    if( !$value$plusargs("abortwr=%d", abortwr) ) abortwr = 0;
    if( !$value$plusargs("hseed=%d", hseed) ) hseed = 0;
    if( !$value$plusargs("free=%d", freecens) ) freecens = 0;
    if( !$value$plusargs("itrace=%d", itrace) ) itrace = 0;
    abcnt = 0; aborted = 0;
    $readmemh( progfile, rom );
    for( k=0; k<2048; k=k+1 ) begin
        work[k] = k * 16'h1234 + hseed[15:0] * 16'h5f5f;
        obj [k] = k * 16'h0055 + hseed[15:0] * 16'h1111;
        pal [k] = k * 16'h0007 + hseed[15:0] * 16'h2222;
    end
    fh  = $fopen("rtl.tlog", "w");
    act = 0; tail = 0; st = ST_START;
    #40 rst = 0;
end

always #5 clk = ~clk;
always @(posedge clk) cen <= ~cen;       // 14 MHz-equivalent enable

// ---------------------------------------------------------------- memories
always @(posedge clk) rom_data <= rom[rom_addr];

always @(posedge clk) begin
    case( host_sel )
        2'd0: host_din <= work[host_addr[10:0]];
        2'd1: host_din <= obj [host_addr[10:0]];
        2'd2: host_din <= pal [host_addr[10:0]];
        default: host_din <= 16'd0;
    endcase
    if( host_we ) begin
        case( host_sel )
            2'd0: work[host_addr[10:0]] <= host_dout;
            2'd1: obj [host_addr[10:0]] <= host_dout;
            2'd2: pal [host_addr[10:0]] <= host_dout;
            default:;
        endcase
    end
end

// ------------------------------------------------------------ host CPU model
// Raise the run bit, wait to be released, idle a while, drop it again.
always @(posedge clk) begin
    if( rst ) begin
        dsp_on <= 1'b0; st <= ST_START; act <= 0; tail <= 0;
    end else begin
        // The sharpest form of the abuse: the core sets its port strobe on a
        // cen edge and clears it on the next one, so the only moment a strobe
        // can be left stranded is the clock in between. Freeze the DSP exactly
        // there. A wrapper that does not gate on the run bit will then replay
        // that write on every following cen.
        // The core raises its port strobe on one cen edge and clears it on the
        // next, so the strobe is live across the low-cen clock in between.
        // Freezing the DSP exactly there strands it. A wrapper that does not
        // gate on the run bit then replays that write on every following cen.
        dbg_wr_d <= dbg_wr;
        if( abortwr != 0 && dbg_pwr && !cen && !aborted && st == ST_WAIT ) begin
            dsp_on  <= 1'b0;
            aborted <= 1'b1;
            abcnt   <= 0;
        end else if( abortwr != 0 && aborted && !dsp_on ) begin
            abcnt <= abcnt + 1;
            if( abcnt > 32'd200 ) dsp_on <= 1'b1;
        end
      if( cen ) begin
        case( st )
        ST_START: begin
            if( freecens == 0 ) $fdisplay(fh, "A %0d", act);
            dsp_on  <= 1'b1;
            tail    <= 0;
            aborted <= 1'b0;
            st      <= ST_WAIT;
        end
        ST_WAIT: begin
            // halt_main rises a clock after dsp_on; wait for it to fall again
            tail <= tail + 1;
            // Free-run mode: hold the run bit and simply let the DSP go, so
            // that code paths which never release the host are compared too.
            if( freecens != 0 ) begin
                if( tail > freecens ) begin
                    $fclose(fh);
                    if( viol == 0 ) $display("tb_dsp: free run done, 0 property violations");
                    else            $display("tb_dsp: free run done, %0d PROPERTY VIOLATIONS", viol);
                    $finish;
                end
            end else begin
            // Optional abuse: drop the run bit in the middle of the DSP's work
            // and put it back. The host cannot really do this - it is halted -
            // but the wrapper must not leak anything to host memory if it does.
            if( abortn != 0 ) begin
                if( tail == abortn )                 dsp_on <= 1'b0;
                if( tail == abortn + 32'd60 )        dsp_on <= 1'b1;
            end
            if( tail > 4 && !halt_main ) begin
                $fdisplay(fh, "H %0d", act);
                tail <= 0;
                st   <= ST_TAIL;
            end
            if( tail > 200000 ) begin
                $fdisplay(fh, "X stuck");
                $fclose(fh); $display("tb_dsp: STUCK, host never released");
                $finish;
            end
            end
        end
        ST_TAIL: begin
            tail <= tail + 1;
            if( tail > tailn ) begin    // let the DSP finish its epilogue
                dsp_on <= 1'b0;
                $fdisplay(fh, "E %0d", act);
                st <= ST_NEXT;
            end
        end
        ST_NEXT: begin
            act <= act + 1;
            if( act + 1 >= acts ) begin
                $fclose(fh);
                if( viol == 0 )
                    $display("tb_dsp: %0d activations completed, 0 property violations", acts);
                else
                    $display("tb_dsp: %0d activations completed, %0d PROPERTY VIOLATIONS", acts, viol);
                $finish;
            end
            st <= ST_START;
        end
        endcase
      end
    end
end

// -------------------------------------------------------------- transactions
// Port 0 and port 3 change wrapper state on the logging edge, so those two are
// reported from the decode outputs / one cycle later, matching the order the
// reference model prints them in.
reg p0_d, p3_d;
reg [15:0] p3_val;

// instruction-level trace, in the same format ref32010 prints. IKA32010 has no
// trace outputs, so its registers are read by hierarchical reference. An
// instruction word is latched on the CLKOUT falling edge of an instruction
// read, which is also the edge that completes the previous instruction, so the
// address is taken on that edge and the registers are printed a clock later.
// The word forced in place of a fetch when an interrupt is taken is skipped.
// MAME keeps the top of the stack in STACK[3] and IKA32010 in stack[0], so the
// stack is printed in reverse to match.
wire       ika_fetch = u_dsp.u_ika.o_CLKOUT_NCEN && u_dsp.u_ika.busctrl_mode[2:0] == 3'd1
                    && !u_dsp.u_ika.if_opcodereg_force_iack;
reg        fetch_d;
reg [11:0] fetch_pc;

always @(posedge clk) begin
    fetch_d  <= itrace != 0 && ika_fetch;
    fetch_pc <= rom_addr;
    if( fetch_d )
        $fdisplay(fh, "%03x %04x %08x %08x %04x %04x %04x %04x %03x %03x %03x %03x",
            fetch_pc, rom[fetch_pc], u_dsp.u_ika.alu_acc_output, u_dsp.u_ika.reg_p,
            u_dsp.u_ika.reg_t, u_dsp.u_ika.reg_ar[0], u_dsp.u_ika.reg_ar[1],
            u_dsp.u_ika.flag_output,
            u_dsp.u_ika.u_stack.stack[3], u_dsp.u_ika.u_stack.stack[2],
            u_dsp.u_ika.u_stack.stack[1], u_dsp.u_ika.u_stack.stack[0]);
end

always @(posedge clk) begin
    p0_d <= 1'b0;
    p3_d <= 1'b0;
    if( itrace != 0 ) begin end
    else if( dbg_p0 ) begin
        $fdisplay(fh, "p %0d %04x", dbg_sel_new, dbg_addr_new);
    end
    if( itrace == 0 && dbg_rd ) $fdisplay(fh, "r %0d %04x %04x", host_sel, host_addr, host_din);
    if( itrace == 0 && dbg_wr ) $fdisplay(fh, "w %0d %04x %04x", host_sel, host_addr, host_dout);
    if( itrace == 0 && dbg_p3 ) begin
        p3_d   <= 1'b1;
        p3_val <= dbg_pdout;
    end
    if( itrace == 0 && p3_d ) $fdisplay(fh, "c %04x %0d %0d %0d",
                         p3_val, dbg_bio, dbg_exec, halt_main);
end

// ------------------------------------------------------------- properties
// Two things the handshake must guarantee, checked continuously rather than
// inferred from the transaction log.
//
//  1. The host's HALT line may only drop as the result of a zero written to
//     port 3 while the release flag is armed. Any other path would let the
//     host restart in the middle of the DSP's work.
//  2. While the run bit is low the DSP is frozen, so its program counter must
//     not move.
reg        rel_ok_d, halt_d, dsp_on_d;
reg [11:0] rom_addr_d;

always @(posedge clk) begin
    // A legal release is a zero written to port 3 while the arm flag is
    // already set. dbg_exec still shows the pre-write value on this edge.
    rel_ok_d   <= dbg_p3 && (dbg_pdout == 16'd0) && dbg_exec;
    halt_d     <= halt_main;
    dsp_on_d   <= dsp_on;
    rom_addr_d <= rom_addr;
    if( !rst ) begin
        if( halt_d && !halt_main && !rel_ok_d ) begin
            $display("tb_dsp: VIOLATION - host released without an armed port 3 zero, t=%0t", $time);
            viol = viol + 1;
        end
        if( !dsp_on && !dsp_on_d && rom_addr !== rom_addr_d ) begin
            $display("tb_dsp: VIOLATION - DSP advanced while the run bit was low, t=%0t", $time);
            viol = viol + 1;
        end
        // Nothing may reach host memory while the DSP is switched off. This is
        // what catches a port strobe that is not gated by the run bit: the
        // strobes are registers inside the core, so they hold their last value
        // while it is frozen and would otherwise be re-executed every cen.
        if( !dsp_on && host_we ) begin
            $display("tb_dsp: VIOLATION - host write while the run bit was low, t=%0t", $time);
            viol = viol + 1;
        end
        if( !dsp_on && (dbg_p0 || dbg_p3 || dbg_rd) ) begin
            $display("tb_dsp: VIOLATION - port activity while the run bit was low, t=%0t", $time);
            viol = viol + 1;
        end
    end
end

jttoaplan1_dsp u_dsp(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .cen        ( cen          ),
    .dsp_on     ( dsp_on       ),
    .halt_main  ( halt_main    ),
    .host_addr  ( host_addr    ),
    .host_sel   ( host_sel     ),
    .host_dout  ( host_dout    ),
    .host_din   ( host_din     ),
    .host_we    ( host_we      ),
    .rom_addr   ( rom_addr     ),
    .rom_data   ( rom_data     ),
    .dbg_bio    ( dbg_bio      ),
    .dbg_exec   ( dbg_exec     ),
    .dbg_rd     ( dbg_rd       ),
    .dbg_wr     ( dbg_wr       ),
    .dbg_p0     ( dbg_p0       ),
    .dbg_p3     ( dbg_p3       ),
    .dbg_pdout  ( dbg_pdout    ),
    .dbg_pwr    ( dbg_pwr      ),
    .dbg_sel_new( dbg_sel_new  ),
    .dbg_addr_new(dbg_addr_new )
);

initial begin
    #200_000_000;
    $display("tb_dsp: TIMEOUT");
    $finish;
end

endmodule
