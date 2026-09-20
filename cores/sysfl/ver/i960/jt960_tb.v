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

// jt960 smoke test. Hand-assembled program in a 4kB memory with random wait
// states. Covers: reset IMI fetch, mov/lda/addo/subo/shlo, ld/st (word, byte,
// signed byte, quad), MEMA/MEMB addressing with 32-bit displacement,
// cmpob branches, call/ret with frame cache, recursion deep enough to spill
// and fill frames through memory, mulo/divo, modpc, synmov to the ICR and an
// external IRQ0 taken through the interrupt table (call type 7 + ret).
//
// memory map: 0x000 IMI (SAT=0x400, PRCB=0x300, IP=0x80)
//   0x300 PRCB (+20 int table = 0x500, +24 stack base = 0x700)
//   0x080 main, 0x150 fail, 0x170 subr, 0x190 recur, 0x1c0 IRQ handler
//   0x200-0x2ff results, 0x2f4 write raises IRQ0, 0x224 write clears it,
//   0x2fc write ends the test, 0x2f8 write marks failure
//
// program (see initial block):
//   g0=5; g1=g0+0x40; g2=g0+g1; g3=g2-1; g4=g3<<4
//   [0x200]=g4; g5=[0x200]; if(g4!=g5) fail
//   r4=0x11; call subr (r4=g4; g6=r4+1); [0x214]=r4; [0x204]=g6
//   byte [0x209]=g0; g7=byte[0x209]; [0x20c]=g7
//   g8=lda 0x12345; [0x210]=g8; g7=sext(byte[0x2e0]); [0x228]=g7
//   stq g0..g3 -> 0x240; ldq 0x240 -> r8..r11; [0x22c]=r10
//   g9=10; g10=g4*g9; [0x218]=g10; g11=g10/g9; [0x21c]=g11
//   g1=6; call recur (recurse until g1==0); [0x230]=g1; [0x234]=r4
//   modpc: priority 31 -> 0; synmov ICR=0x42 (IRQ0 vector)
//   [0x2f4]=x (raises IRQ0); wait until [0x220]!=0; [0x2fc]=x; spin
//   handler: r5=1; [0x220]=r5; [0x224]=r5 (clears IRQ0); ret

`timescale 1ns/1ps

module jt960_tb;

reg         rst, clk, cen;
wire [31:2] addr;
wire [31:0] dout;
wire [ 3:0] dsn;
wire        bus_cs, bus_wr, halted;
reg  [ 3:0] irq_n;
reg  [31:0] mem[0:1023];
reg  [ 1:0] wcnt;
integer     i, errors;

wire        bus_ok = bus_cs && wcnt==0;
wire [31:0] din    = mem[addr[11:2]];
wire        wr_go  = cen && bus_cs && bus_wr && bus_ok;

jt960 uut(
    .rst    ( rst    ),
    .clk    ( clk    ),
    .cen    ( cen    ),
    .addr   ( addr   ),
    .din    ( din    ),
    .dout   ( dout   ),
    .dsn    ( dsn    ),
    .bus_cs ( bus_cs ),
    .bus_wr ( bus_wr ),
    .bus_ok ( bus_ok ),
    .irq_n  ( irq_n  ),
    .halted ( halted )
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

always @(posedge clk) cen <= ~cen;

// random wait states, reloaded after each completed access
always @(posedge clk) begin
    if( cen && bus_cs ) begin
        if( wcnt!=0 )        wcnt <= wcnt-2'd1;
        else if( bus_ok )    wcnt <= $random;
    end
end

// memory writes with byte lanes + test hooks
always @(posedge clk) if( wr_go ) begin
    if( !dsn[0] ) mem[addr[11:2]][ 7: 0] <= dout[ 7: 0];
    if( !dsn[1] ) mem[addr[11:2]][15: 8] <= dout[15: 8];
    if( !dsn[2] ) mem[addr[11:2]][23:16] <= dout[23:16];
    if( !dsn[3] ) mem[addr[11:2]][31:24] <= dout[31:24];
    case( {addr,2'd0} )
    32'h2f4: irq_n[0] <= 0;     // raise IRQ0
    32'h224: irq_n[0] <= 1;     // handler acknowledge
    32'h2f8: begin
        $display("FAIL: program took the failure branch");
        $finish;
    end
    32'h2fc: begin
        #1 run_checks;
        $finish;
    end
    default:;
    endcase
end

always @(posedge clk) if( halted ) begin
    $display("FAIL: CPU halted on a fault/unimplemented opcode");
    $finish;
end

initial begin
    #4000000;
    $display("FAIL: timeout");
    $finish;
end

// ------------------------------------------------------------- assembler
localparam [31:0] START=32'h080, FAIL=32'h150, SUBR=32'h170,
                  RECUR=32'h190, HANDLER=32'h1c0;

reg [31:0] pc, waitl;

task w( input [31:0] op );
begin
    mem[pc[11:2]] = op;
    pc = pc+4;
end
endtask

function [31:0] REGF( input [7:0] mj, input [3:0] sb, input [4:0] dst,
                      input m3, input m2, input m1,
                      input [4:0] s2, input [4:0] s1 );
    REGF = {mj, dst, s2, m3, m2, m1, sb, 2'b00, s1};
endfunction

function [31:0] CTRL( input [7:0] mj, input [31:0] tgt, input [31:0] p );
    CTRL = {mj, tgt[23:0]-p[23:0]};
endfunction

function [31:0] COBR( input [7:0] mj, input [4:0] s1, input [4:0] s2,
                      input m1, input [31:0] tgt, input [31:0] p );
    COBR = {mj, s1, s2, m1, tgt[12:0]-p[12:0]};
endfunction

function [31:0] MEMA( input [7:0] mj, input [4:0] dst, input [4:0] abase,
                      input md, input [11:0] off );
    MEMA = {mj, dst, abase, md, 1'b0, off};
endfunction

function [31:0] MEMBC( input [7:0] mj, input [4:0] dst ); // mode c + disp word
    MEMBC = {mj, dst, 5'd0, 4'hc, 3'd0, 2'b00, 5'd0};
endfunction

task run_checks;
begin
    errors = 0;
    chk( 32'h200, 32'h490       );
    chk( 32'h204, 32'h491       );
    chk( 32'h20c, 32'd5         );
    chk( 32'h210, 32'h12345     );
    chk( 32'h214, 32'h11        );
    chk( 32'h218, 32'h2da0      );
    chk( 32'h21c, 32'h490       );
    chk( 32'h228, 32'hffffff80  );
    chk( 32'h22c, 32'h4a        );
    chk( 32'h230, 32'd0         );
    chk( 32'h234, 32'h11        );
    chk( 32'h220, 32'd1         );
    if( mem[32'h208>>2][15:8] != 8'd5 ) begin
        $display("FAIL: byte store at 209 = %x", mem[32'h208>>2][15:8]);
        errors = errors+1;
    end
    if( errors==0 ) $display("PASS");
    else            $display("FAIL: %0d checks failed", errors);
end
endtask

task chk( input [31:0] a, input [31:0] v );
begin
    if( mem[a[11:2]] !== v ) begin
        $display("FAIL: [%x] = %x, expected %x", a, mem[a[11:2]], v);
        errors = errors+1;
    end
end
endtask

initial begin
    cen   = 0;
    wcnt  = 1;
    irq_n = 4'hf;
    for( i=0; i<1024; i=i+1 ) mem[i] = 0;
    // initial memory image
    mem['h000>>2] = 32'h400;    // SAT
    mem['h004>>2] = 32'h300;    // PRCB
    mem['h00c>>2] = START;      // initial IP
    mem['h314>>2] = 32'h500;    // PRCB+20: interrupt table
    mem['h318>>2] = 32'h700;    // PRCB+24: stack base
    mem['h60c>>2] = HANDLER;    // int table entry for vector 0x42
    mem['h2f0>>2] = 32'h42;     // ICR value: IRQ0 -> vector 0x42 (priority 8)
    mem['h2e0>>2] = 32'h80;     // signed byte load operand
    // main
    pc = START;
    w( REGF(8'h5c,4'hc,5'd16,0,0,1,5'd0,5'd5)          ); // mov   5,g0
    w( MEMA(8'h8c,5'd17,5'd16,1,12'h040)               ); // lda   0x40(g0),g1
    w( REGF(8'h59,4'h0,5'd18,0,0,0,5'd17,5'd16)        ); // addo  g0,g1,g2
    w( REGF(8'h59,4'h2,5'd19,0,0,1,5'd18,5'd1)         ); // subo  1,g2,g3
    w( REGF(8'h59,4'hc,5'd20,0,0,1,5'd19,5'd4)         ); // shlo  4,g3,g4
    w( MEMA(8'h92,5'd20,5'd0,0,12'h200)                ); // st    g4,0x200
    w( MEMA(8'h90,5'd21,5'd0,0,12'h200)                ); // ld    0x200,g5
    w( COBR(8'h35,5'd20,5'd21,0,FAIL,pc)               ); // cmpobne g4,g5,fail
    w( REGF(8'h5c,4'hc,5'd4,0,0,1,5'd0,5'd17)          ); // mov   0x11,r4
    w( CTRL(8'h09,SUBR,pc)                             ); // call  subr
    w( MEMA(8'h92,5'd4,5'd0,0,12'h214)                 ); // st    r4,0x214
    w( MEMA(8'h92,5'd22,5'd0,0,12'h204)                ); // st    g6,0x204
    w( MEMA(8'h82,5'd16,5'd0,0,12'h209)                ); // stob  g0,0x209
    w( MEMA(8'h80,5'd23,5'd0,0,12'h209)                ); // ldob  0x209,g7
    w( MEMA(8'h92,5'd23,5'd0,0,12'h20c)                ); // st    g7,0x20c
    w( MEMBC(8'h8c,5'd24)                              ); // lda   0x12345,g8
    w( 32'h12345                                       );
    w( MEMA(8'h92,5'd24,5'd0,0,12'h210)                ); // st    g8,0x210
    w( MEMA(8'hc0,5'd23,5'd0,0,12'h2e0)                ); // ldib  0x2e0,g7
    w( MEMA(8'h92,5'd23,5'd0,0,12'h228)                ); // st    g7,0x228
    w( MEMA(8'hb2,5'd16,5'd0,0,12'h240)                ); // stq   g0,0x240
    w( MEMA(8'hb0,5'd8,5'd0,0,12'h240)                 ); // ldq   0x240,r8
    w( MEMA(8'h92,5'd10,5'd0,0,12'h22c)                ); // st    r10,0x22c
    w( REGF(8'h5c,4'hc,5'd25,0,0,1,5'd0,5'd10)         ); // mov   10,g9
    w( REGF(8'h70,4'h1,5'd26,0,0,0,5'd20,5'd25)        ); // mulo  g9,g4,g10
    w( MEMA(8'h92,5'd26,5'd0,0,12'h218)                ); // st    g10,0x218
    w( REGF(8'h70,4'hb,5'd27,0,0,0,5'd26,5'd25)        ); // divo  g9,g10,g11
    w( MEMA(8'h92,5'd27,5'd0,0,12'h21c)                ); // st    g11,0x21c
    w( REGF(8'h5c,4'hc,5'd17,0,0,1,5'd0,5'd6)          ); // mov   6,g1
    w( CTRL(8'h09,RECUR,pc)                            ); // call  recur
    w( MEMA(8'h92,5'd17,5'd0,0,12'h230)                ); // st    g1,0x230
    w( MEMA(8'h92,5'd4,5'd0,0,12'h234)                 ); // st    r4,0x234
    w( MEMBC(8'h8c,5'd26)                              ); // lda   0x1f0000,g10
    w( 32'h001f0000                                    );
    w( REGF(8'h5c,4'hc,5'd27,0,0,1,5'd0,5'd0)          ); // mov   0,g11
    w( REGF(8'h65,4'h5,5'd27,0,0,0,5'd26,5'd0)         ); // modpc g11,g10 (pri=0)
    w( MEMBC(8'h8c,5'd29)                              ); // lda   ff000004,g13
    w( 32'hff000004                                    );
    w( MEMA(8'h8c,5'd30,5'd0,0,12'h2f0)                ); // lda   0x2f0,g14
    w( REGF(8'h60,4'h0,5'd0,0,0,0,5'd30,5'd29)         ); // synmov g13,g14
    w( MEMA(8'h92,5'd16,5'd0,0,12'h2f4)                ); // st    g0,0x2f4 (IRQ!)
    waitl = pc;
    w( MEMA(8'h90,5'd25,5'd0,0,12'h220)                ); // ld    0x220,g9
    w( COBR(8'h32,5'd0,5'd25,1,waitl,pc)               ); // cmpobe 0,g9,waitl
    w( MEMA(8'h92,5'd16,5'd0,0,12'h2fc)                ); // st    g0,0x2fc (done)
    w( CTRL(8'h08,pc,pc)                               ); // b     .
    // fail
    pc = FAIL;
    w( MEMA(8'h8c,5'd29,5'd0,0,12'hbad)                ); // lda   0xbad,g13
    w( MEMA(8'h92,5'd29,5'd0,0,12'h2f8)                ); // st    g13,0x2f8
    w( CTRL(8'h08,pc,pc)                               ); // b     .
    // subr: r4=g4, g6=r4+1
    pc = SUBR;
    w( REGF(8'h5c,4'hc,5'd4,0,0,0,5'd0,5'd20)          ); // mov   g4,r4
    w( REGF(8'h59,4'h0,5'd22,0,0,1,5'd4,5'd1)          ); // addo  1,r4,g6
    w( CTRL(8'h0a,pc,pc)                               ); // ret
    // recur: while(g1!=0){g1--; recur();}
    pc = RECUR;
    w( COBR(8'h32,5'd0,5'd17,1,RECUR+12,pc)            ); // cmpobe 0,g1,+ret
    w( REGF(8'h59,4'h2,5'd17,0,0,1,5'd17,5'd1)         ); // subo  1,g1,g1
    w( CTRL(8'h09,RECUR,pc)                            ); // call  recur
    w( CTRL(8'h0a,pc,pc)                               ); // ret
    // IRQ handler
    pc = HANDLER;
    w( REGF(8'h5c,4'hc,5'd5,0,0,1,5'd0,5'd1)           ); // mov   1,r5
    w( MEMA(8'h92,5'd5,5'd0,0,12'h220)                 ); // st    r5,0x220
    w( MEMA(8'h92,5'd5,5'd0,0,12'h224)                 ); // st    r5,0x224 (ack)
    w( CTRL(8'h0a,pc,pc)                               ); // ret
    // reset
    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
end

endmodule
