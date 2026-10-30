/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Sega Model 2 core for MiSTer FPGA
// Copyright (C) 2026 alphanu1
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version. See LICENSE for the full text.
//
// ---------------------------------------------------------------------------
//
// i960KB instruction cache — 512 bytes, direct-mapped, 16-byte lines.
//
// UNLIKE EVERY OTHER BLOCK IN P1, THIS ONE HAS NO ORACLE AND NEEDS NONE.
// MAME does not model an instruction cache at all: its `m_cache` is an address
// space accessor, and the IAC that would invalidate the real cache — 0x89,
// "invalidate internal instruction cache" — is logged rather than executed.
//
// So this is architecturally invisible. It changes cycle counts and nothing
// else, and it cannot diverge from the reference because the reference has
// nothing to diverge from. Two consequences worth stating:
//
//  - It is verified by TRANSPARENCY, not by lockstep. The only requirement is
//    that a fetch returns the same word external memory would have returned.
//    The harness checks exactly that, and checks it on every fetch rather than
//    only on misses.
//  - The assumption underneath is that instruction memory does not change
//    under the cache. Model 2 executes from ROM (0x00000000-0x001fffff and
//    0x02000000-0x03ffffff), so there is no self-modifying code and no DMA into
//    the instruction stream. **If that ever stops being true, this block
//    becomes wrong and silently so** — hence `inval` exists even though nothing
//    drives it yet.
//
// Geometry: 512 B / 16 B = 32 lines. addr[3:2] selects the word within a line,
// addr[8:4] the line, addr[31:9] is the tag.
//
// M10K rather than MLAB for the data, which is the opposite of the register
// cache's decision and for the opposite reason: 4,096 bits is a third of one
// M10K but would take about seven MLABs, and §5.6's pressure is on M10K blocks
// rather than on bits. One block for the whole instruction cache is a good
// trade; seven MLABs of LUT is not. The tag array stays in flip-flops because
// it is read and compared combinationally on every fetch.

module jt960_icache #(
  parameter int unsigned LINES = 32,          // 32 x 16 B = 512 B
  // R817: HIT UNDER FILL. 1: a request for a line already in the cache is
  // answered while a fill is in flight, and the fill runs on to completion and
  // installs its line. 0: R548's behaviour -- the hit waits for the fill's
  // outstanding word and the fill is ABANDONED, its line never installed.
  parameter bit          HUF   = 1'b1,
  // R817: CRITICAL WORD FIRST, EARLY RESTART. 1: a fill starts at the word
  // asked for and wraps, and that word is answered as it arrives (from the
  // bus, through a register), the line completing behind it. 0: the fill
  // starts at word 0 and answers only when the line is complete (S_DONE).
  // Needs HUF: the requester runs on while the line completes.
  // Both default on, as i960_top uses them, so every bench of the module
  // alone tests the configuration that ships.
  parameter bit          ER    = 1'b1
) (
  input  logic        clk,
  input  logic        rst_n,

  input  logic        snoop,
  input  logic [31:2] snoop_addr,
  input  logic        inval,                  // invalidate everything

  // ------- fetch side
  input  logic        req,
  // Demand or speculative. Only a demand request may ABORT a fill in progress:
  // that is what lets a redirect pre-empt a line nothing wants any more. A
  // speculative one must not, or a prefetch issued while a demand fill is in
  // flight kills the fill the sequencer is waiting on and it waits forever.
  input  logic        req_demand,
  // [31:2], not [31:0]: instructions are dword-aligned so the low two bits are
  // always zero. Declaring the full width leaves them unread, which is the
  // pattern the lint is kept un-suppressed to catch.
  input  logic [31:2] addr,
  output logic [31:0] data,
  // The address this `valid` answers. With a single outstanding request the
  // requester may assume every valid is its own; with a prefetch queue two can
  // be in flight and a speculative hit completes while a demand fetch is still
  // being waited for. `valid` alone cannot separate them.
  output logic [31:2] vaddr,
  output logic        valid,                  // `data` is good this cycle
  output logic        busy,

  // ------- refill side. One 4-word line burst per miss.
  output logic        bus_req,
  output logic [31:0] bus_addr,   // combinational — see the fill state
  input  logic [31:0] bus_rdata,
  input  logic        bus_ack
);

  localparam int unsigned IDX_W = $clog2(LINES);
  localparam int unsigned TAG_W = 32 - IDX_W - 4;

  // Data store: LINES x 4 words. Never cleared in reset — clearing an array in
  // reset forces it out of RAM into flip-flops, measured on this toolchain.
  // Validity lives in the tag array, which is where a reset can be afforded.
  (* ramstyle = "M10K" *) logic [31:0] cdata [0:LINES*4-1];

  // Pinned to logic, and this is not a tidy-up. Quartus inferred the tag array
  // into an altsyncram -- a 10 Kbit M10K block for 736 bits -- and the header
  // above states the tags stay in flip-flops precisely because `hit` compares
  // them COMBINATIONALLY on every fetch. A synchronous RAM read is not
  // combinational, so the inferred version and the simulated version were not
  // the same circuit: verilator models the array combinationally and cannot
  // see this, which is the standing rule about memory inference exactly.
  // Found only once the fitter report started printing M10K.
  // R552: THE TAGS ARE LUT-RAM, NOT FLIP-FLOPS. The note above kept them in
  // registers because they are read and compared combinationally on every
  // fetch -- but a Cyclone V MLAB reads asynchronously, which is exactly that.
  // As registers they were 736 flip-flops and most of this block's 734 ALMs,
  // in a design that no longer fits. cvalid stays in registers: reset and
  // invalidate clear it all at once, which a RAM cannot do.
  // MLAB, NOT M10K, AND THE DIFFERENCE IS THE WHOLE POINT OF THE NOTE ABOVE:
  // an M10K read is synchronous and was not the simulated circuit; an MLAB
  // read is asynchronous and is. The fit report must show this array in MLAB
  // (it is checked, R552) -- if Quartus ever puts it in an M10K again, pin it
  // back to "logic".
  // R768: AND THE VALID BIT LIVES IN IT TOO. cvalid was a flip-flop per line
  // with its own write enable and a LINES-way read mux -- the "per-line logic"
  // that took a 2 KB cache from 190 to 592 ALM and out of the device (R693).
  // As bit TAG_W of the same LUT-RAM word it is read with the tag, in the same
  // cycle, so `hit` is exactly as combinational as before. A RAM cannot be
  // cleared all at once, so reset (and inval) SWEEP it, one line a cycle,
  // with the cache busy -- the bridge's data cache does the same (dc_sweep).
  // Each place that cleared cvalid[x] is now a write of {invalid} to line x;
  // they are mutually exclusive with each other and with the completed fill's
  // tag write, so one write port serves them all.
  (* ramstyle = "MLAB, no_rw_check" *) logic [TAG_W:0] ctag  [0:LINES-1];

  logic [IDX_W-1:0] idx;
  logic [1:0]       word;
  logic [TAG_W-1:0] tag;

  assign idx  = addr[IDX_W+3:4];
  assign word = addr[3:2];
  assign tag  = addr[31:IDX_W+4];

  logic hit;
  wire [TAG_W:0] ctag_rd = ctag[idx];
  wire snoop_hit = snoop && (snoop_addr[IDX_W+3:4] == idx);
  assign hit = ctag_rd[TAG_W] && (ctag_rd[TAG_W-1:0] == tag) && !snoop_hit;

  typedef enum logic [1:0] { S_IDLE, S_FILL, S_DONE, S_SWEEP } state_e;   // R768: S_SWEEP
  state_e state;

  logic [1:0]       fill_word;
  logic [1:0]       fill_cnt;    // R817: words acknowledged so far (ER: the fill wraps)
  logic [31:0]      byp_q;       // R817: the early-restart answer, from the bus
  logic             byp_sel;     //       `data` is byp_q this cycle
  wire              fill_last = ER ? (fill_cnt == 2'd3) : (fill_word == 2'd3);
  logic [IDX_W-1:0] fill_idx;
  logic [TAG_W-1:0] fill_tag;
  // R952: the line's base address IS {fill_tag, fill_idx, 0} -- every write of
  // the three (the miss, the redirect, the sweep's pending request, reset)
  // took them from the same address -- so it is that concatenation, not a
  // 28-bit register of its own beside them.
  wire  [31:0]      fill_base = {fill_tag, fill_idx, 4'd0};

  assign busy = (state != S_IDLE);

  // Registered read of the data array. A hit costs one cycle, which is what a
  // pipelined fetch stage wants anyway.
  logic [31:0] cdata_q;
  logic        rd_we;
  logic [IDX_W+1:0] rd_waddr, rd_raddr;
  logic [31:2]      req_addr_q;   // the address `valid` answers
  logic             req_accept;   // a request is being taken this cycle
  logic [31:0] rd_wdata;

  always_ff @(posedge clk) begin
    if (rd_we) cdata[rd_waddr] <= rd_wdata;
    cdata_q <= cdata[rd_raddr];
  end

  // THE READ ADDRESS IS LIVE WHEN A REQUEST IS TAKEN AND LATCHED AFTERWARDS.
  //
  // `cdata_q` is registered from this every cycle. Using the live `addr`
  // throughout means the data follows wherever the requester has since moved
  // rather than the request being answered -- correct only while the requester
  // holds one address until answered, which a prefetch queue does not. Using
  // the latched address throughout is also wrong: it is a cycle late, so a hit
  // reads with the previous request's address.
  //
  // Both were measured. Live-only latched the wrong word into the prefetch
  // queue; latched-only produced 856 block-harness mismatches.
  assign req_accept = req && ((state == S_IDLE) || (state == S_DONE) ||
                              ((state == S_FILL) && req_demand &&
                               ((idx != fill_idx) || (tag != fill_tag))));
  assign rd_raddr = req_accept ? {idx, word}
                               : {req_addr_q[IDX_W+3:4], req_addr_q[3:2]};
  assign vaddr    = req_addr_q;

  // Combinational so the address tracks fill_word within the same cycle the
  // data for it is acked.
  assign bus_addr = fill_base + {28'd0, fill_word, 2'b00};

  // A redirect asking for a line other than the one being filled. Combinational
  // so it can be acted on in the same cycle an acknowledge arrives.
  logic redir_now;
  assign redir_now = (state == S_FILL) && req && req_demand &&
                     ((idx != fill_idx) || (tag != fill_tag));
  // R817: a request in S_FILL for ANOTHER line that is already in the cache.
  // With HUF it is answered now, from the read port the fill does not use --
  // the fill writes through the other port -- and the fill carries on.
  //
  // WHY. Every taken branch prefetches the word after it (i960_top predicts
  // sequential). When that word starts a line the cache does not hold, the
  // prefetch starts a fill; the branch then asks for its target, a hit, and
  // R548's redirect waited for the fill's outstanding word and abandoned it.
  // The line was never installed, so the next time round the loop did it
  // all again: a loop whose branch is the last word of its line paid a fill's
  // first word every iteration, however large the cache. Measured on the
  // real CPU, bridge and SDRAM (tb_m2_cpu_real, boot code, 8 KB): 24,692 of
  // 24,730 fills abandoned, 1.52 of the 1.53 fetch-wait cycles an instruction.
  wire huf_hit  = HUF && redir_now && hit;
  wire redir_mx = redir_now && !huf_hit;     // a redirect that restarts the fill
  // Someone is waiting on the fill in flight. Cleared when a hit-under-fill
  // answers the requester instead; set again by a request for the fill's own
  // line. A fill nobody waits for installs its line and returns to S_IDLE
  // without a `valid` -- R812's vaddr check would discard one, but none is
  // the cleaner contract.
  logic             fill_wanted;
  wire same_now = (state == S_FILL) && req && req_demand &&
                  (idx == fill_idx) && (tag == fill_tag);

  // Where a redirect is going, held from when it arrives until an acknowledge
  // makes it safe to move the address. See S_FILL.
  logic             redir_q;
  // R550: the deferred redirect's target was a hit WHEN IT ARRIVED. Kept as one
  // bit instead of re-reading ctag[redir_idx] at the acknowledge -- that was a
  // 32-way, 23-bit mux (~100 ALMs, and the design is out of LABs). It cannot go
  // stale: the only line written during a fill is fill_idx's, invalidated when
  // the fill began, so a target on it was never a hit.
  logic             redir_hit;
  logic [31:2]      redir_addr;
  // R952: slices of redir_addr, which was written with them (the same addr)
  // every time -- 28 registers that only ever held a copy.
  wire  [IDX_W-1:0] redir_idx = redir_addr[IDX_W+3:4];
  wire  [TAG_W-1:0] redir_tag = redir_addr[31:IDX_W+4];
  // A deferred redirect still in force this cycle. The newest request wins:
  // one for the line being filled, or a hit answered under the fill, makes a
  // redirect still waiting for its acknowledge stale. Without this a requester
  // that moved on -- possible only once hits are answered under a fill, so the
  // CPU keeps running and prefetching -- had its request for the fill's own
  // line overtaken by the stale redirect's restart, and waited forever. Found
  // by tb_m2_ifetch_replay on the game's code: a prefetch of 0x1360 deferred
  // while 0x1900 filled, then a demand for 0x1900.
  wire redir_live = redir_q && !same_now && !huf_hit;
  assign rd_waddr = {fill_idx, fill_word};
  assign rd_wdata = bus_rdata;
  assign rd_we    = (state == S_FILL) && bus_ack;

  assign data = byp_sel ? byp_q : cdata_q;

  // R552: the tag write, from a block with no reset so the array can be an
  // MLAB. The condition is exactly the FSM's completed-fill branch: the last
  // word acknowledged with no redirect standing.
  wire tag_we = (state == S_FILL) && bus_ack && !redir_mx && !redir_live
             && fill_last;
  // R817 (ER): the word this acknowledge delivers is the one the requester
  // waits for -- the fill's own, or a request for its line arriving now.
  wire [1:0] ans_word = same_now ? addr[3:2] : req_addr_q[3:2];
  wire er_ans = ER && (state == S_FILL) && bus_ack && (fill_wanted || same_now)
             && !huf_hit && !redir_mx && !redir_live && (fill_word == ans_word);
  // R768: the invalidates, from the same conditions the FSM below acts on.
  logic [IDX_W-1:0] sweep_idx;
  // A request arriving during a sweep is REMEMBERED and served when it ends:
  // a requester may present an address for one cycle only (tb_i960_icache
  // does), and dropping it would stall it forever.
  logic             sw_pend;
  logic [31:2]      sw_addr;
  wire inv_idle  = ((state == S_IDLE) || (state == S_DONE)) && req && !hit;
  wire inv_redir = (state == S_FILL) && bus_ack && (redir_mx || redir_live)
                && !((redir_mx && hit) || (!redir_now && redir_live && redir_hit));
  wire inv_sweep = (state == S_SWEEP);
  wire [IDX_W-1:0] inv_idx = inv_sweep ? sweep_idx
                           : inv_redir ? (redir_now ? idx : redir_idx) : idx;
  always_ff @(posedge clk) begin
    if (inv_sweep) ctag[sweep_idx] <= '0;
    else if (snoop) ctag[snoop_addr[IDX_W+3:4]] <= '0;
    else if (tag_we)                            ctag[fill_idx] <= {1'b1, fill_tag};
    else if (inv_idle || inv_redir || inv_sweep) ctag[inv_idx]  <= '0;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bus_req    <= 1'b0;
      valid      <= 1'b0;
      req_addr_q <= '0;
      fill_word <= 2'd0;
      fill_cnt  <= 2'd0;
      byp_q     <= 32'd0;
      byp_sel   <= 1'b0;
      fill_idx  <= '0;
      fill_tag  <= '0;
      redir_q    <= 1'b0;
      redir_hit  <= 1'b0;
      redir_addr <= '0;
      fill_wanted <= 1'b1;
      sweep_idx  <= '0;
      sw_pend    <= 1'b0;
      sw_addr    <= '0;
      state      <= S_SWEEP;   // R768: clear every line's valid bit
    end else begin
      valid   <= 1'b0;
      byp_sel <= 1'b0;

      if (inval) begin   // R768: a sweep, as at reset
        sweep_idx <= '0;
        sw_pend   <= 1'b0;
        bus_req   <= 1'b0;
        state     <= S_SWEEP;
      end else if (snoop && state == S_FILL && snoop_addr[IDX_W+3:4] == fill_idx) begin
        bus_req <= 1'b0;
        redir_q <= 1'b0;
        state   <= S_IDLE;
      end else

      case (state)
        S_IDLE: begin
          if (req) begin
            req_addr_q <= addr;
            if (hit) begin
              // cdata_q is registered from rd_raddr this cycle, so it is good
              // next cycle — which is when `valid` asserts.
              valid <= 1'b1;
            end else begin
              fill_idx  <= idx;
              fill_tag  <= tag;
              fill_word <= ER ? addr[3:2] : 2'd0;
              fill_cnt  <= 2'd0;
              fill_wanted <= 1'b1;
              // Invalidate BEFORE filling. cvalid is only set on completion,
              // but the data array is written word by word during the fill, so
              // a line valid under a different tag has its data destroyed while
              // still advertising a hit. Harmless while fills always completed;
              // required once they can be abandoned.
              state     <= S_FILL;   // R768: invalidated by inv_idle
            end
          end
        end

        S_FILL: begin
          // Request is HELD across the whole line and the address is
          // combinational, so a memory that acks every cycle delivers one word
          // per cycle. The previous version registered both and dropped the
          // request after each word, which measured ~3.7 cycles per word and
          // made instruction fetch 58% of all cycles in the CPU.
          bus_req <= 1'b1;

          // A request for the line already being filled is SATISFIED by that
          // fill, so it becomes the request this `valid` answers. Without it
          // the answer still names the address the fill started on, and a
          // redirect within the same line receives the wrong word. Placed
          // before the abort below so a different-line request overrides it.
          // DEMAND only. A same-line request is satisfied by this fill and so
          // becomes the request the valid answers -- but a SPECULATIVE one must
          // not rename an answer a demand fetch is waiting for. This rule was
          // written for a redirect within a line and predates speculative
          // requests existing; with a prefetch issuing its own requests it let
          // `vaddr` name one address while `data` carried another's word.
          if (same_now) begin
            req_addr_q  <= addr;
            fill_wanted <= 1'b1;
            redir_q     <= 1'b0;   // R817: supersedes a deferred redirect
          end
          // A redirect -- taken branch or mispredicted prefetch -- can ask for
          // a different line mid-fill. Restart on it rather than making the
          // requester wait out a line nothing wants.
          //
          // RESOLVED ON THE ACKNOWLEDGE, because `bus_addr` is combinational
          // from `fill_base` and `bus_req` is HELD across the line. Moving
          // `fill_base` the instant a redirect arrives moves the address under
          // a fetch the memory has already taken; that fetch's data then lands
          // and `rd_we` writes it at {fill_idx, fill_word} -- word 0 of the NEW
          // line. The line is tagged for the redirect target and holds the
          // abandoned address's word. Study R45.
          //
          // Measured against the real bridge: a prefetch of 0x920 was in flight
          // when the boot's copy loop branched back to 0x910, so 0x910 answered
          // with 0x920's contents -- `bx (g14)`, a return -- and the loop
          // returned instead of iterating.
          //
          // TWO REGIMES HAVE TO WORK AND THAT IS WHAT MAKES THIS FIDDLY. Against
          // a memory that acknowledges in the same cycle it is asked, nothing is
          // ever outstanding and the redirect must take effect AT ONCE:
          // deferring it there consumes an acknowledge the completion path
          // needed, which test_i960_icache catches. Against the bridge, acks are
          // many cycles apart and the redirect must WAIT. So the immediate path
          // is taken when an acknowledge is already present this cycle, and the
          // deferred path when it is not.
          //
          // The abandoned word is not discarded -- it is still written to the
          // old line, which is correct data for a line nothing is waiting on.
          // R548: AND A REDIRECT TO A LINE ALREADY IN THE CACHE IS A HIT. This
          // path used to refill the target unconditionally -- invalidating a
          // valid line and fetching it again. Every loop iterates by branching
          // back while the prefetch fills the NEXT line, so every loop line
          // was refetched every pass: the boot copy's 0x910 8,193 times, the
          // loop at 0x16b0 258,048 times in 2 M instructions, and a 16x larger
          // cache changed the cycle count by exactly nothing. Instruction fetch
          // was 27% of all CPU cycles under contention. The fill is abandoned
          // (its line is already invalid, set at the fill's start) and the
          // target is answered from the array through S_DONE, which reads
          // req_addr_q -- the same completion path a finished fill takes.
          if (huf_hit) begin
            // R817: answer the hit now (cdata_q is read at {idx, word} this
            // cycle: req_accept) and let the fill run on. It installs its line
            // on completion; nobody waits for it, so no `valid` then.
            req_addr_q  <= addr;
            valid       <= 1'b1;
            fill_wanted <= 1'b0;
            redir_q     <= 1'b0;   // a redirect still pending is superseded
            if (bus_ack) begin
              fill_cnt <= fill_cnt + 2'd1;
              if (fill_last) begin
                bus_req <= 1'b0;
                state   <= S_IDLE;   // tag written by tag_we
              end else
                fill_word <= fill_word + 2'd1;
            end
          end else if (bus_ack && ((redir_now && hit) || (!redir_now && redir_live && redir_hit))) begin
            redir_q    <= 1'b0;
            bus_req    <= 1'b0;
            req_addr_q <= redir_now ? addr : redir_addr;
            state      <= S_DONE;
          end else if (bus_ack && (redir_now || redir_live)) begin
            // Safe here: the outstanding fetch has just been answered, so
            // moving the address starts a new transaction rather than
            // corrupting one in progress.
            redir_q     <= 1'b0;
            fill_idx    <= redir_now ? idx  : redir_idx;
            fill_tag    <= redir_now ? tag  : redir_tag;
            fill_word   <= !ER ? 2'd0 : redir_now ? addr[3:2] : redir_addr[3:2];
            fill_cnt    <= 2'd0;
            fill_wanted <= 1'b1;
            // R768: invalidated by inv_redir
            req_addr_q  <= redir_now ? addr : redir_addr;
          end else if (redir_now) begin
            // A fetch is outstanding. Remember where we are going and keep the
            // address still until it is answered.
            redir_q    <= 1'b1;
            redir_hit  <= hit;          // R550
            redir_addr <= addr;   // R952: redir_idx / redir_tag are its slices
          end else if (bus_ack) begin
            fill_cnt <= fill_cnt + 2'd1;
            if (er_ans) begin
              // R817: the word waited for, straight from the bus.
              byp_q       <= bus_rdata;
              byp_sel     <= 1'b1;
              valid       <= 1'b1;
              fill_wanted <= 1'b0;
            end
            if (fill_last) begin
              bus_req          <= 1'b0;
              // R552 / R768: ctag (tag and valid) is written by tag_we
              // R817: S_DONE answers the fill's requester; a fill nobody
              // waits for any more just ends.
              // A request for this line arriving in this very cycle renames
              // it (above) and must be answered too: the old fill_wanted
              // is what is read here.
              if( (fill_wanted || same_now) && !er_ans ) state <= S_DONE;
              else state <= S_IDLE;
            end else begin
              fill_word <= fill_word + 2'd1;
            end
          end
        end

        S_DONE: begin
          // One cycle for the registered read of the just-filled line -- but a
          // request can arrive during it now that the requester no longer waits
          // for `busy`. Answering it with `valid` regardless hands over the
          // just-filled line's data read at the NEW address.
          if (req && !hit) begin
            req_addr_q  <= addr;
            fill_idx    <= idx;
            fill_tag    <= tag;
            fill_word   <= ER ? addr[3:2] : 2'd0;
            fill_cnt    <= 2'd0;
            fill_wanted <= 1'b1;
            state       <= S_FILL;   // R768: invalidated by inv_idle
          end else begin
            // R812: a hit arriving now is read at ITS address (req_accept), so
            // `vaddr` must name it too -- the requester now checks it.
            if (req) req_addr_q <= addr;
            valid <= 1'b1;
            state <= S_IDLE;
          end
        end

        // R768: one line's valid bit a cycle; requests wait (busy, no accept).
        S_SWEEP: begin
          if (req) begin sw_pend <= 1'b1; sw_addr <= addr; end
          sweep_idx <= sweep_idx + 1'b1;
          if (sweep_idx == IDX_W'(LINES - 1)) begin
            // Everything is invalid now, so a remembered request is a miss.
            if (sw_pend || req) begin
              req_addr_q <= req ? addr : sw_addr;
              fill_idx   <= req ? idx : sw_addr[IDX_W+3:4];
              fill_tag   <= req ? tag : sw_addr[31:IDX_W+4];
              fill_word  <= !ER ? 2'd0 : req ? addr[3:2] : sw_addr[3:2];
              fill_cnt   <= 2'd0;
              sw_pend    <= 1'b0;
              fill_wanted <= 1'b1;
              state      <= S_FILL;
            end else
              state      <= S_IDLE;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
