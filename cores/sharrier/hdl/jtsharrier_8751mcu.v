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

    Original author: Jose Tejada Gomez. Twitter: @topapate
    Forked and modified for jtsharrier by: niknak
    Version: 1.0
    Date: 2-8-2026 */

/*  JTSHARRIER — i8751 MCU wrapper with INSTRUCTION RETIMING.

    Forked from JTFRAME's jtframe_8751mcu.v (Jose Tejada, GPL-3).
    JTFRAME's original is unchanged and still used by the other 9 cores.

    WHY THIS FORK EXISTS
    --------------------
    The Oregano mc8051 FSM does not follow MCS-51 machine-cycle counts. For most
    games that does not show, but Space Harrier's boot countdown is paced by the
    MCU's own ROM checksum loop, so the difference is visible on screen. It is
    not a MOVX issue: MOVX reads are correctly timed and MOVX writes are if
    anything too fast. The FSM costs +1 machine cycle on most instructions and
    +2 on direct addressing, while `DJNZ Rn` is exactly right:

        instruction      real   Oregano FSM states
        MOV A,direct       1        3
        ADD A,direct       1        3
        INC DPTR           2        4
        LCALL/RET/PUSH     2        3
        MOVX A,@DPTR       2        2      <- correct
        MOVX @DPTR,A       2        1      <- too FAST
        DJNZ Rn            2        2      <- correct

    With DIVCEN=1 the stock wrapper runs one FSM state per machine cycle, so the
    MCU's ROM-checksum loop (which paces the boot countdown) takes 252 machine
    cycles where real hardware takes 168 — exactly x1.500, matching what was
    measured on the cabinet. The boot phase is `djnz Rn` delay loops, so it comes
    out at x1.000, which is why only the countdown was affected.

    HOW THIS FIXES IT
    -----------------
    The FSM is left completely alone. Instead:
      * it is stepped every 3 `cen` ticks rather than every 12, so even the
        longest instruction (4 states) fits inside one machine cycle;
      * at each instruction boundary the fetched opcode is looked up in the real
        MCS-51 cycle table below, and the core is then STALLED until that many
        machine cycles (12 `cen` each) have actually elapsed.
    Net effect: every instruction consumes exactly its real machine-cycle count,
    whether the FSM is too slow (usual case) or too fast (MOVX writes).

    Because `cen` is already gated upstream by `mcu_ok` (jtsharrier_main.v),
    a stalled external bus access freezes both the step divider and the elapsed
    counter, so real bus waits still extend the instruction as on hardware.

    KNOWN LIMIT: interrupt ENTRY. When the FSM takes an interrupt it runs a
    4-state sequence instead of executing the fetched opcode, so that one entry
    is padded against the wrong opcode's budget. The error is a few machine
    cycles, once per interrupt (60/s), and the displaced instruction re-fetches
    normally after RETI. Not worth modelling; documented so it is not a mystery.

    The timer/serial units are not retimed — they count machine cycles directly
    and are given their own `cen_tmr` at the true /12 rate. This MCU does use
    timer 0 (`setb tr0`, and it reads `tl0`).
*/

module jtsharrier_8751mcu(
    input         rst,
    input         clk,
    input         cen,          // 8 MHz, already gated by mcu_ok

    input         int0n,
    input         int1n,

    input  [ 7:0] p0_i,
    input  [ 7:0] p1_i,
    input  [ 7:0] p2_i,
    input  [ 7:0] p3_i,

    output [ 7:0] p0_o,
    output [ 7:0] p1_o,
    output [ 7:0] p2_o,
    output [ 7:0] p3_o,

    // external memory
    input      [ 7:0] x_din,
    output reg [ 7:0] x_dout,
    output reg [15:0] x_addr,
    output reg        x_wr,
    output reg        x_acc,

    // ROM programming
    input         clk_rom,
    input [11:0]  prog_addr,
    input [ 7:0]  prom_din,
    input         prom_we
);

parameter ROMBIN="",
          SYNC_XDATA = 0,
          SYNC_INT = 0,
          SYNC_P0 = 0,
          SYNC_P1 = 0,
          SYNC_P2 = 0,
          SYNC_P3 = 0;
// RETIME=0 restores the stock behaviour (one FSM state per machine cycle), so
// the old timing can be reproduced without reverting the fork.
`ifdef RETIME0
parameter RETIME = 0;
`else
parameter RETIME = 1;
`endif

localparam [2:0] FETCH = 3'b001;   // t_state: STARTUP,FETCH,EXEC1,EXEC2,EXEC3
localparam       MCYC  = 12;       // cen ticks per machine cycle (8MHz/12)

wire [ 7:0] rom_data, ram_data, ram_q;
reg  [15:0] rom_addr;
wire [ 6:0] ram_addr;
wire        ram_we;
reg  [ 7:0] xin_sync, p0_s, p1_s, p2_s, p3_s;   // input data must be sampled with cen
wire [ 2:0] state;
wire        cen_eff, cen_tmr;

always @(posedge clk) if(cen_eff) begin
    xin_sync <= x_din;
    p0_s     <= p0_i;
    p1_s     <= p1_i;
    p2_s     <= p2_i;
    p3_s     <= p3_i;
end

// ---------------------------------------------------------------------------
// Real MCS-51 machine cycles per opcode. Straight from the instruction set;
// every 8051 derivative shares it. Only three values occur: 1, 2 and 4.
// ---------------------------------------------------------------------------
function [2:0] mcyc(input [7:0] op);
    case(op)
        8'h84, 8'hA4:                  mcyc = 3'd4;  // DIV AB, MUL AB
        // 2-cycle: jumps, calls, returns, bit jumps, CJNE/DJNZ(direct),
        // MOVX, MOVC, stack ops, 16-bit loads, and the direct/immediate forms
        // that carry a second operand fetch.
        8'h01,8'h11,8'h21,8'h31,8'h41,8'h51,8'h61,8'h71,       // ACALL/AJMP
        8'h81,8'h91,8'hA1,8'hB1,8'hC1,8'hD1,8'hE1,8'hF1,
        8'h02,8'h12,8'h22,8'h32,                               // LJMP LCALL RET RETI
        8'h10,8'h20,8'h30,                                     // JBC JB JNB
        8'h40,8'h50,8'h60,8'h70,8'h80,                         // JC JNC JZ JNZ SJMP
        8'h73,                                                 // JMP @A+DPTR
        8'h43,8'h53,8'h63,8'h75,                               // ORL/ANL/XRL dir,#d ; MOV dir,#d
        8'h72,8'h82,8'h92,8'hA0,8'hB0,                         // bit ops with C
        8'h83,8'h93,                                           // MOVC
        8'h85,8'h86,8'h87,                                     // MOV dir,dir / dir,@Ri
        8'h88,8'h89,8'h8A,8'h8B,8'h8C,8'h8D,8'h8E,8'h8F,       // MOV dir,Rn
        8'h90,                                                 // MOV DPTR,#d16
        8'hA3,                                                 // INC DPTR
        8'hA6,8'hA7,                                           // MOV @Ri,dir
        8'hA8,8'hA9,8'hAA,8'hAB,8'hAC,8'hAD,8'hAE,8'hAF,       // MOV Rn,dir
        8'hB4,8'hB5,8'hB6,8'hB7,                               // CJNE A,#/dir ; @Ri,#
        8'hB8,8'hB9,8'hBA,8'hBB,8'hBC,8'hBD,8'hBE,8'hBF,       // CJNE Rn,#d
        8'hC0,8'hD0,                                           // PUSH POP
        8'hD5,                                                 // DJNZ dir,rel
        8'hD8,8'hD9,8'hDA,8'hDB,8'hDC,8'hDD,8'hDE,8'hDF,       // DJNZ Rn,rel
        8'hE0,8'hE2,8'hE3,8'hF0,8'hF2,8'hF3:                   // MOVX
                                       mcyc = 3'd2;
        default:                       mcyc = 3'd1;
    endcase
endfunction

// ---------------------------------------------------------------------------
// Clock-enable generation
// ---------------------------------------------------------------------------
reg  [3:0] divcnt=0;      // free-running /12, machine-cycle reference
reg  [7:0] stepcnt=0;     // ticks since the last FSM step
reg  [7:0] elapsed=0;     // cen ticks since the current instruction started
reg  [7:0] budget=MCYC;   // cen ticks the current instruction is entitled to
reg        cen_stock=0;

// STEP SPREADING. The step interval is proportional to the instruction's cycle
// budget, so a short instruction's bus accesses spread over its whole duration
// rather than bunching at the front and then idling.
wire [7:0] step_iv   = {2'd0, budget[7:2]};        // budget/4
wire       at_fetch  = state==FETCH;
wire       step_due  = stepcnt >= (step_iv-8'd1);
// hold at the instruction boundary until the real cycle count has been paid
wire       paid      = elapsed >= budget;
wire       cen_step  = cen & step_due & (!at_fetch | paid);

always @(posedge clk) begin
    if( rst ) begin
        divcnt  <= 0; stepcnt <= 8'd0;
        elapsed <= 0; budget  <= MCYC;
        cen_stock <= 0;
    end else begin
        cen_stock <= 0;
        if( cen ) begin
            divcnt  <= divcnt==4'd11 ? 4'd0 : divcnt+4'd1;
            stepcnt <= step_due ? 8'd0 : stepcnt+8'd1;
            cen_stock <= divcnt==4'd1;
            if( !(elapsed[7] & elapsed[6]) ) elapsed <= elapsed + 8'd1; // saturate
            // A step taken while in FETCH consumes the opcode: that IS the
            // start of an instruction, including 1-state ones that never
            // leave FETCH.
            if( step_due && at_fetch && paid ) begin
                budget  <= {3'd0, mcyc(rom_data)} * MCYC;
                // The fetch tick is itself the first tick of the new
                // instruction, so elapsed starts at 1, not 0. Starting at 0
                // makes `paid` read one tick stale, the boundary step is
                // refused, and the instruction overruns by a whole step
                // interval (3 ticks) -- measured as +16.1% on every
                // instruction before this was corrected.
                elapsed <= 8'd1;
                stepcnt <= 8'd0;   // restart the spread for the new budget
            end
        end
    end
end

assign cen_eff = RETIME==1 ? cen_step  : cen_stock;
assign cen_tmr = RETIME==1 ? (cen & divcnt==4'd1) : cen_stock;

wire int0n_s, int1n_s;

jtframe_sync #(.W(2)) u_sync(
    .clk_in (   clk               ), // not resampled
    .clk_out(   clk               ),
    .raw    ( {int1n, int0n }     ),
    .sync   ( {int1n_s, int0n_s } )
);

// You need to clock gate for reading or the MCU won't work
jtframe_dual_ram_cen #(.AW(12),.SIMFILE(ROMBIN)) u_prom(
    .clk0   ( clk_rom   ),
    .cen0   ( 1'b1      ),
    .clk1   ( clk       ),
    .cen1   ( cen_eff   ),
    // Port 0
    .data0  ( prom_din  ),
    .addr0  ( prog_addr ),
    .we0    ( prom_we   ),
    .q0     (           ),
    // Port 1
    .data1  (           ),
    .addr1  ( rom_addr[11:0]  ),
    .we1    ( 1'b0      ),
    .q1     ( rom_data  )
);

jtframe_ram_rst #(.AW(7),.CEN_RD(1)) u_ramu(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .cen        ( cen_eff           ),
    .addr       ( ram_addr          ),
    .data       ( ram_data          ),
    .we         ( ram_we            ),
    .q          ( ram_q             )
);

wire [ 7:0] pre_dout;
wire [15:0] pre_addr, pre_rom;
wire        pre_wr, pre_acc;

always @(posedge clk) begin
    x_addr   <= pre_addr;
    x_wr     <= pre_wr;
    x_dout   <= pre_dout;
    x_acc    <= pre_acc;
    rom_addr <= pre_rom;
end
/* verilator tracing_off */
mc8051_core u_mcu(
    .reset      ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_eff   ),
    .cen_tmr    ( cen_tmr   ),   // timer/serial count real machine cycles
    .state_o    ( state     ),   // FSM state, drives the retiming above
    // code ROM
    .rom_data_i ( rom_data  ),
    .rom_adr_o  ( pre_rom   ),
    // internal RAM
    .ram_data_i ( ram_q     ),
    .ram_data_o ( ram_data  ),
    .ram_adr_o  ( ram_addr  ),
    .ram_wr_o   ( ram_we    ),
    .ram_en_o   (           ),
    // external memory: connected to main CPU
    .datax_i    ( SYNC_XDATA ? xin_sync : x_din ),
    .datax_o    ( pre_dout  ),
    .adrx_o     ( pre_addr  ),
    .wrx_o      ( pre_wr    ),
    .memx_o     ( pre_acc   ),
    // interrupts
    .int0_i     ( SYNC_INT ? int0n_s : int0n ),
    .int1_i     ( SYNC_INT ? int1n_s : int1n ),
    // counters
    .all_t0_i   ( 1'b0      ),
    .all_t1_i   ( 1'b0      ),
    // serial interface
    .all_rxd_i  ( 1'b0      ),
    .all_rxd_o  (           ),
    .all_rxdwr_o(           ),
    .all_txd_o  (           ),
    // Ports
    .p0_i       ( SYNC_P0 ? p0_s : p0_i ),
    .p0_o       ( p0_o      ),

    .p1_i       ( SYNC_P1 ? p1_s : p1_i ),
    .p1_o       ( p1_o      ),

    .p2_i       ( SYNC_P2 ? p2_s : p2_i ),
    .p2_o       ( p2_o      ),

    .p3_i       ( SYNC_P3 ? p3_s : p3_i ),
    .p3_o       ( p3_o      )
);

endmodule
