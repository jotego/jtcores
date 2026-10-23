/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-10-2026 */

module nsc8105_tb;
reg rst=1, clk=0, run=0, reset_req=0, dip_pause=1;
reg [5:0] cnt=0;
wire cen=cnt[3:0]==0;
wire [14:0] rom_addr;
wire rom_cs, shared_we;
wire [10:0] shared_addr;
wire [7:0] shared_din, debug_view;
reg [7:0] rom_data, shared_dout;
wire rom_ok=cnt>=8;
wire [3:0] dac;
reg [7:0] rom[0:32767], ram[0:2047], expected[0:255];
integer p=0, i, j, cc, slot=0, branches=0, retired=0;
integer ticks=0, last_tick=0, mr=0, waits=0, current=-1, elapsed, nominal;
reg taken;

always #5 clk=~clk;
always @(posedge clk) begin
    cnt<=cnt+6'd1;
    rom_data<=rom[rom_addr];
    shared_dout<=ram[shared_addr];
    if(shared_we) ram[shared_addr]<=shared_din;
    if(!dut.core_rst) begin
        if(dut.instruction_end) begin
            nominal=cycles(current);
            if(ticks!=nominal)
                $fatal(1,"NSC physical cycles raw=%h expected=%0d actual=%0d",current,nominal,ticks);
            retired=retired+1;
        end
        if(dut.step) begin
            if(dut.opcode_fetch) begin
                current=dut.din;
                ticks=0;
            end
            ticks=ticks+1;
        end
    end
end

function integer cycles;
    input [7:0] op;
    begin
        case(op)
            8'hcd,8'h4d: cycles=3;
            8'h4f,8'hcf: cycles=4;
            8'hff: cycles=6;
            8'h77: cycles=5;
            8'hec: cycles=5;
            8'hfc: cycles=5;
            8'hb2,8'hbb: cycles=6;
            8'h30,8'h36: cycles=4;
            8'hae: cycles=7;
            default: cycles=op[7:4]==2 ? 4 : 2;
        endcase
    end
endfunction

function [7:0] encode;
    input [7:0] op;
    begin encode={op[6],op[7],op[5:2],op[0],op[1]}; end
endfunction

task bytecode;
    input [7:0] value;
    begin rom[p]=value; p=p+1; end
endtask

task op;
    input [7:0] value;
    begin bytecode(encode(value)); end
endtask

task wordcode;
    input [15:0] value;
    begin bytecode(value[15:8]); bytecode(value[7:0]); end
endtask

task savecc;
    input [7:0] offset;
    begin op(8'h07); op(8'hb7); wordcode(16'hf800+offset); end
endtask

jtseicro_mcu dut(
    .rst         ( rst         ),
    .cpu_rst     ( rst         ),
    .clk         ( clk         ),
    .cen         ( cen         ),
    .release_clk ( cnt[5]      ),
    .run         ( run         ),
    .reset_req   ( reset_req   ),
    .dip_pause   ( dip_pause   ),
    .nsc8105     ( 1'b1        ),
    .nvram_en    ( 1'b0        ),
    .nvram_dout  ( 8'hff       ),
    .dipsw       ( 24'hfae3f5  ),
    .rom_addr    ( rom_addr    ),
    .rom_cs      ( rom_cs      ),
    .rom_data    ( rom_data    ),
    .rom_ok      ( rom_ok      ),
    .shared_addr ( shared_addr ),
    .shared_din  ( shared_din  ),
    .shared_we   ( shared_we   ),
    .shared_dout ( shared_dout ),
    .dac         ( dac         ),
    .debug_view  ( debug_view  )
);

initial begin
    for(i=0;i<32768;i=i+1) rom[i]=8'h02;
    for(i=0;i<2048;i=i+1) ram[i]=0;
    ram[2046]=8'h80;
    ram[2047]=0;
    ram[48]=0;
    ram[49]=2;
    op(8'h8e); wordcode(16'h007f);
    op(8'h30); op(8'h35);
    op(8'hce); wordcode(16'h1234);
    op(8'h0d); bytecode(8'hec); bytecode(1); savecc(0);
    op(8'hff); wordcode(16'hf810);
    op(8'hce); wordcode(16'h1334);
    op(8'h0d); bytecode(8'hec); bytecode(1); savecc(1);
    op(8'hce); wordcode(16'hffff);
    bytecode(8'hec); bytecode(1); savecc(2);
    op(8'hff); wordcode(16'hf812);
    op(8'hce); wordcode(16'hf820);
    op(8'h0d); bytecode(8'hb2); bytecode(8'h82); bytecode(0); savecc(3);
    bytecode(8'hbb); bytecode(8'h80); bytecode(0); savecc(4);
    bytecode(8'hbb); bytecode(1); bytecode(0); savecc(5);
    op(8'h6d); bytecode(0);
    op(8'h86); bytecode(8'hd0); op(8'h06);
    op(8'hce); wordcode(16'h7fff);
    bytecode(8'hfc); wordcode(16'hf830); savecc(6);
    op(8'hff); wordcode(16'hf814);
    for(i=0;i<16;i=i+1) begin
        cc=8'hd0|i;
        for(j=0;j<16;j=j+1) begin
            case(j)
                0: taken=1;
                1: taken=0;
                2: taken=!(cc[0] || cc[2]);
                3: taken=cc[0] || cc[2];
                4: taken=!cc[0];
                5: taken=cc[0];
                6: taken=!cc[2];
                7: taken=cc[2];
                8: taken=!cc[1];
                9: taken=cc[1];
                10: taken=!cc[3];
                11: taken=cc[3];
                12: taken=!(cc[3]^cc[1]);
                13: taken=cc[3]^cc[1];
                14: taken=!(cc[2] || (cc[3]^cc[1]));
                15: taken=cc[2] || (cc[3]^cc[1]);
            endcase
            expected[slot]=taken ? cc[7:0] : 8'h5a;
            op(8'h86); bytecode(cc[7:0]); op(8'h06);
            op(8'h20+j); bytecode(2);
            op(8'h86); bytecode(8'h5a);
            op(8'hb7); wordcode(16'hf900+slot);
            slot=slot+1;
        end
    end
    op(8'h86); bytecode(8'hc3); op(8'hb7); wordcode(16'hf807);
    op(8'h20); bytecode(8'hfe);
    repeat(20) @(negedge clk); rst=0; run=1;
    wait(ram[7]==8'hc3);
    if(ram[0]!==8'hd0 || ram[1]!==8'hd1 || ram[2]!==8'hf4 ||
       ram[3]!==8'hf9 || ram[4]!==8'hf8 || ram[5]!==8'hf4 || ram[6]!==8'hda)
        $fatal(1,"NSC flags %h %h %h %h %h %h %h",ram[0],ram[1],ram[2],ram[3],ram[4],ram[5],ram[6]);
    if({ram[16],ram[17]}!==16'h1235 || {ram[18],ram[19]}!==0 ||
       {ram[20],ram[21]}!==16'h8001 || ram[32]!==8'h82)
        $fatal(1,"NSC extra instruction results");
    for(i=0;i<256;i=i+1) begin
        if(ram[256+i]!==expected[i]) $fatal(1,"NSC branch %h expected=%h actual=%h",i,expected[i],ram[256+i]);
        branches=branches+1;
    end
    $display("PASS YAML NSC8105: extra instructions, flags, unchanged operands, %0d branches, %0d timed instructions",branches,retired);
    $finish;
end
initial begin #20000000; $fatal(1,"NSC timeout addr=%h",dut.addr); end
endmodule
