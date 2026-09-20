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

// jt37702 smoke test. Hand-assembled program in the internal ROM image with
// random wait states on the external bus. Covers: reset vector fetch,
// 16-bit and 8-bit accumulator modes (SEP/CLM), high byte preservation,
// absolute/indexed/direct/indirect addressing, misaligned 16-bit external
// access, MVN block move, LDM/SEB/CLB/BBS, MPY/DIV/XAB (89 prefix),
// PSH/PUL, JSR/RTS, port 6 write + port 7 read, one ADC single conversion,
// a timer A0 interrupt and an external INT0, both through the vector table.
//
// results: the program writes $A5 to $5000 on PASS, $F1 on FAIL
// $5002 write asks the TB to pulse irq0

`timescale 1ns/1ps

module jt37702_tb;

reg         rst, clk, cen=0;
wire [23:0] addr;
wire [15:0] dout;
wire [ 1:0] dsn;
wire        bus_cs, rnw, stp;
wire        rom_cs;
wire [13:1] rom_addr;
reg         rom_okr;
reg         irq0=0, irq1=0, irq2=0;
reg  [ 7:0] rom8[0:16383];
reg  [15:0] ext [0:32767];   // external bus, addr[15:1] when bank 0
reg  [ 1:0] wcnt=0;
reg  [ 7:0] irqcnt=0;
integer     cur, k;

wire [15:0] rom_data = {rom8[{rom_addr,1'b1}], rom8[{rom_addr,1'b0}]};
wire        rom_ok   = rom_okr;
wire        bus_ok   = bus_cs && wcnt==0;
wire [15:0] din      = ext[addr[15:1]];
wire        wr_go    = cen && bus_cs && !rnw && bus_ok;

jt37702 uut(
    .rst      ( rst      ),
    .clk      ( clk      ),
    .cen      ( cen      ),
    .tcen     ( cen      ),
    .addr     ( addr     ),
    .bus_cs   ( bus_cs   ),
    .rnw      ( rnw      ),
    .dout     ( dout     ),
    .din      ( din      ),
    .dsn      ( dsn      ),
    .bus_ok   ( bus_ok   ),
    .rom_cs   ( rom_cs   ),
    .rom_addr ( rom_addr ),
    .rom_data ( rom_data ),
    .rom_ok   ( rom_ok   ),
    .p4_din   ( 8'h00    ),
    .p5_din   ( 8'h00    ),
    .p6_din   ( 8'h00    ),
    .p7_din   ( 8'hA3    ),
    .p8_din   ( 8'h00    ),
    .p4_dout  (          ),
    .p5_dout  (          ),
    .p6_dout  (          ),
    .p7_dout  (          ),
    .p8_dout  (          ),
    .p4_diro  (          ),
    .p5_diro  (          ),
    .p6_diro  (          ),
    .p7_diro  (          ),
    .p8_diro  (          ),
    .an       ( {8'h00,8'h00,8'h77,8'hFF,8'hFF,8'hFF,8'hFF,8'hFF} ),
    .irq0     ( irq0     ),
    .irq1     ( irq1     ),
    .irq2     ( irq2     ),
    .tain     ( 5'd0     ),
    .stp      ( stp      )
);

wire [7:0] p6_dout = uut.p6_dout;
wire [7:0] p6_diro = uut.p6_diro;

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

always @(posedge clk) cen <= ~cen;

// registered rom_ok, one cen after rom_cs
always @(posedge clk) if( cen ) rom_okr <= rom_cs;

// random wait states on the external bus
always @(posedge clk) begin
    if( cen && bus_cs ) begin
        if( wcnt!=0 )     wcnt <= wcnt-2'd1;
        else if( bus_ok ) wcnt <= $random;
    end
end

// external memory writes + test hooks
always @(posedge clk) if( wr_go ) begin
    if( !dsn[0] ) ext[addr[15:1]][ 7:0] <= dout[ 7:0];
    if( !dsn[1] ) ext[addr[15:1]][15:8] <= dout[15:8];
    case( addr )
        24'h005002: irqcnt <= 8'd20;         // request an irq0 pulse
        24'h005000: begin
            if( dout[7:0]==8'hA5 ) begin
                #1 run_checks;
            end else begin
                $display("FAIL: program took the failure branch");
                $finish;
            end
        end
        default:;
    endcase
end

// delayed irq0 pulse, a few cen wide
always @(posedge clk) if( cen ) begin
    if( irqcnt!=0 ) irqcnt <= irqcnt-8'd1;
    irq0 <= irqcnt>8'd5 && irqcnt<8'd15;
end

task run_checks;
begin
    k = 0;
    if( p6_dout!==8'h5A ) begin $display("FAIL: P6 output %x != 5A", p6_dout); k=1; end
    if( p6_diro!==8'hFF ) begin $display("FAIL: P6 dir %x != FF", p6_diro); k=1; end
    if( ext[16'h4000>>1][7:0]!==8'h56 ) begin
        $display("FAIL: external byte write, $4000=%x", ext[16'h4000>>1][7:0]); k=1;
    end
    if( ext[16'h4100>>1]!==16'h1234 ) begin
        $display("FAIL: external word write, $4100=%x", ext[16'h4100>>1]); k=1;
    end
    if( k==0 ) $display("PASS");
    $finish;
end
endtask

task B(input [7:0] v); begin rom8[cur[13:0]]=v; cur=cur+1; end endtask
// each check is 5 bytes: BEQ +3 / JMP $C300
task CHKEQ; begin B(8'hf0); B(8'h03); B(8'h4c); B(8'h00); B(8'hc3); end endtask

initial begin
    for(k=0;k<16384;k=k+1) rom8[k]=8'h00;
    for(k=0;k<32768;k=k+1) ext[k]=16'h0000;

    // main program, org $C000 (rom offset 0). reset: m=0, x=0 (16 bit)
    cur = 0;
    B(8'ha9); B(8'h34); B(8'h12);           // LDA #$1234
    B(8'h8d); B(8'h00); B(8'h01);           // STA $0100 (internal RAM)
    B(8'ha9); B(8'h00); B(8'h00);           // LDA #$0000
    B(8'had); B(8'h00); B(8'h01);           // LDA $0100
    B(8'hc9); B(8'h34); B(8'h12);           // CMP #$1234
    CHKEQ;
    B(8'ha2); B(8'h04); B(8'h00);           // LDX #$0004
    B(8'h9d); B(8'h00); B(8'h01);           // STA $0100,X -> $0104
    B(8'had); B(8'h04); B(8'h01);           // LDA $0104
    B(8'hc9); B(8'h34); B(8'h12);           // CMP #$1234
    CHKEQ;
    B(8'h8d); B(8'h00); B(8'h41);           // STA $4100 (external, aligned)
    B(8'ha9); B(8'h00); B(8'h00);           // LDA #$0000
    B(8'had); B(8'h00); B(8'h41);           // LDA $4100
    B(8'hc9); B(8'h34); B(8'h12);           // CMP #$1234
    CHKEQ;
    B(8'h8d); B(8'h03); B(8'h41);           // STA $4103 (external, misaligned)
    B(8'ha9); B(8'h00); B(8'h00);           // LDA #$0000
    B(8'had); B(8'h03); B(8'h41);           // LDA $4103
    B(8'hc9); B(8'h34); B(8'h12);           // CMP #$1234
    CHKEQ;
    B(8'ha2); B(8'h00); B(8'h01);           // LDX #$0100
    B(8'ha0); B(8'h30); B(8'h01);           // LDY #$0130
    B(8'ha9); B(8'h02); B(8'h00);           // LDA #$0002
    B(8'h54); B(8'h00); B(8'h00);           // MVN $00,$00 (2 bytes 100->130)
    B(8'had); B(8'h30); B(8'h01);           // LDA $0130
    B(8'hc9); B(8'h34); B(8'h12);           // CMP #$1234
    CHKEQ;
    B(8'ha9); B(8'h34); B(8'h12);           // LDA #$1234 (MVN left $FFFF)
    B(8'he2); B(8'h20);                     // SEP #$20 -> m=1
    B(8'ha9); B(8'h56);                     // LDA #$56
    B(8'h8d); B(8'h00); B(8'h40);           // STA $4000 (external byte)
    B(8'ha9); B(8'h00);                     // LDA #$00
    B(8'had); B(8'h00); B(8'h40);           // LDA $4000
    B(8'hc9); B(8'h56);                     // CMP #$56
    CHKEQ;
    B(8'hd8);                               // CLM -> m=0
    B(8'hc9); B(8'h56); B(8'h12);           // CMP #$1256 (A high preserved)
    CHKEQ;
    B(8'ha9); B(8'h00); B(8'h01);           // LDA #$0100
    B(8'h5b);                               // TAD (DPR=$0100)
    B(8'he2); B(8'h20);                     // SEP #$20 -> m=1
    B(8'h64); B(8'h10); B(8'h77);           // LDM #$77,$10 -> $0110
    B(8'ha5); B(8'h10);                     // LDA $10
    B(8'hc9); B(8'h77);                     // CMP #$77
    CHKEQ;
    B(8'h04); B(8'h10); B(8'h0f);           // SEB #$0F,$10 -> $7F
    B(8'h14); B(8'h10); B(8'h03);           // CLB #$03,$10 -> $7C
    B(8'ha5); B(8'h10);                     // LDA $10
    B(8'hc9); B(8'h7c);                     // CMP #$7C
    CHKEQ;
    B(8'h24); B(8'h10); B(8'h40); B(8'h03); // BBS #$40,$10,+3 (taken)
    B(8'h4c); B(8'h00); B(8'hc3);           // JMP fail
    B(8'h64); B(8'h20); B(8'h04);           // LDM #$04,$20 (pointer lo)
    B(8'h64); B(8'h21); B(8'h01);           // LDM #$01,$21 (pointer=$0104)
    B(8'ha0); B(8'h00); B(8'h00);           // LDY #$0000
    B(8'hb1); B(8'h20);                     // LDA ($20),Y -> $34
    B(8'hc9); B(8'h34);                     // CMP #$34
    CHKEQ;
    B(8'hb2); B(8'h20);                     // LDA ($20) -> $34
    B(8'hc9); B(8'h34);                     // CMP #$34
    CHKEQ;
    B(8'ha9); B(8'h0d);                     // LDA #$0D
    B(8'h89); B(8'h09); B(8'h0a);           // MPY #$0A -> A=$82 B=$00
    B(8'hc9); B(8'h82);                     // CMP #$82
    CHKEQ;
    B(8'h89); B(8'h29); B(8'h07);           // DIV #$07 -> A=$12 B=$04
    B(8'hc9); B(8'h12);                     // CMP #$12
    CHKEQ;
    B(8'h89); B(8'h28);                     // XAB -> A=$04 B=$12
    B(8'hc9); B(8'h04);                     // CMP #$04
    CHKEQ;
    B(8'heb); B(8'h03);                     // PSH #$03 (A,B)
    B(8'ha9); B(8'h00);                     // LDA #$00
    B(8'hfb); B(8'h03);                     // PUL #$03
    B(8'hc9); B(8'h04);                     // CMP #$04
    CHKEQ;
    B(8'h20); B(8'h40); B(8'hc3);           // JSR $C340 (INA; RTS)
    B(8'hc9); B(8'h05);                     // CMP #$05
    CHKEQ;
    B(8'ha9); B(8'hff);                     // LDA #$FF
    B(8'h8d); B(8'h10); B(8'h00);           // STA $0010 (P6 dir)
    B(8'ha9); B(8'h5a);                     // LDA #$5A
    B(8'h8d); B(8'h0e); B(8'h00);           // STA $000E (P6 data)
    B(8'had); B(8'h0f); B(8'h00);           // LDA $000F (P7 input)
    B(8'hc9); B(8'ha3);                     // CMP #$A3
    CHKEQ;
    B(8'ha9); B(8'h45);                     // LDA #$45 (start ADC, ch 5)
    B(8'h8d); B(8'h1e); B(8'h00);           // STA $001E
    B(8'had); B(8'h1e); B(8'h00);           // adwait: LDA $001E
    B(8'h29); B(8'h40);                     // AND #$40
    B(8'hd0); B(8'hf9);                     // BNE adwait (-7)
    B(8'had); B(8'h2a); B(8'h00);           // LDA $002A (result ch5)
    B(8'hc9); B(8'h77);                     // CMP #$77
    CHKEQ;
    B(8'ha9); B(8'h00);                     // LDA #$00
    B(8'h8d); B(8'h56); B(8'h00);           // STA $0056 (TA0 mode: timer /2)
    B(8'ha9); B(8'h20);                     // LDA #$20
    B(8'h8d); B(8'h46); B(8'h00);           // STA $0046 (TA0 reload lo)
    B(8'ha9); B(8'h00);                     // LDA #$00
    B(8'h8d); B(8'h47); B(8'h00);           // STA $0047 (TA0 reload hi)
    B(8'ha9); B(8'h05);                     // LDA #$05
    B(8'h8d); B(8'h75); B(8'h00);           // STA $0075 (TA0 int prio 5)
    B(8'h64); B(8'h11); B(8'h00);           // LDM #$00,$11 (flag)
    B(8'ha9); B(8'h01);                     // LDA #$01
    B(8'h8d); B(8'h40); B(8'h00);           // STA $0040 (count start TA0)
    B(8'h58);                               // CLI
    B(8'ha5); B(8'h11);                     // tw: LDA $11
    B(8'hf0); B(8'hfc);                     // BEQ tw (-4)
    B(8'ha9); B(8'h06);                     // LDA #$06
    B(8'h8d); B(8'h7d); B(8'h00);           // STA $007D (INT0 prio 6)
    B(8'h64); B(8'h12); B(8'h00);           // LDM #$00,$12 (flag)
    B(8'h8d); B(8'h02); B(8'h50);           // STA $5002 (TB raises irq0)
    B(8'ha5); B(8'h12);                     // iw: LDA $12
    B(8'hf0); B(8'hfc);                     // BEQ iw (-4)
    B(8'ha9); B(8'ha5);                     // LDA #$A5
    B(8'h8d); B(8'h00); B(8'h50);           // STA $5000 (PASS)
    B(8'h80); B(8'hfe);                     // BRA self
    if( cur > 'h300 ) begin
        $display("TB error: main program overruns the fail handler");
        $finish;
    end

    // fail handler, $C300
    cur = 'h300;
    B(8'ha9); B(8'hf1);                     // LDA #$F1
    B(8'h8d); B(8'h00); B(8'h50);           // STA $5000
    B(8'h80); B(8'hfe);                     // BRA self

    // subroutine, $C340
    cur = 'h340;
    B(8'h3a);                               // INA
    B(8'h60);                               // RTS

    // timer A0 ISR, $C360
    cur = 'h360;
    B(8'ha9); B(8'h00);                     // LDA #$00
    B(8'h8d); B(8'h40); B(8'h00);           // STA $0040 (stop timers)
    B(8'he6); B(8'h11);                     // INC $11
    B(8'h40);                               // RTI

    // INT0 ISR, $C380
    cur = 'h380;
    B(8'he6); B(8'h12);                     // INC $12
    B(8'h40);                               // RTI

    // vectors (rom offset = address - $C000)
    rom8[14'h3fee] = 8'h60; rom8[14'h3fef] = 8'hc3; // TA0    -> $C360
    rom8[14'h3ff4] = 8'h80; rom8[14'h3ff5] = 8'hc3; // INT0   -> $C380
    rom8[14'h3ffe] = 8'h00; rom8[14'h3fff] = 8'hc0; // RESET  -> $C000

    rst = 1;
    repeat(10) @(posedge clk);
    rst = 0;
end

// optional instruction trace: vvp ... +trace
always @(posedge clk) if( cen && uut.back && uut.u_cpu.st==6'd1 ) begin
    if( $test$plusargs("trace") )
        $display("%x: %x  A=%x B=%x X=%x Y=%x S=%x P=%x%x",
            {uut.u_cpu.pg, uut.u_cpu.pc}, uut.bdin[7:0],
            uut.u_cpu.a, uut.u_cpu.b, uut.u_cpu.x, uut.u_cpu.y,
            uut.u_cpu.s, uut.u_cpu.ipl, uut.u_cpu.ps);
end

// timeout and STP guards
initial begin
    repeat(4_000_000) @(posedge clk);
    $display("FAIL: timeout");
    $finish;
end

always @(posedge clk) if( stp ) begin
    $display("FAIL: unexpected STP");
    $finish;
end

endmodule
