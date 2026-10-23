/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

`timescale 1ns/1ps
module m6802_decode_tb;
reg clk=0, rst=1, nsc=0;
reg [3:0] divider=0;
reg [7:0] raw=0, din;
wire [15:0] addr;
wire [7:0] dout;
wire done, wr, vma, ni, opcode_fetch;
integer mode, code, ticks, checked=0;
reg [7:0] canonical;
reg expected;
always #5 clk=~clk;
always @(posedge clk) begin
    divider<=divider+4'd1;
    case(addr)
        16'hfffe: din<=8'h80;
        16'hffff: din<=0;
        16'h8000: din<=raw;
        default: din<=8'h01;
    endcase
end
function legal;
    input [7:0] op;
    begin
        legal=0;
        if(op[7]) case(op[3:0])
            0,1,2,4,5,6,8,9,10,11,14: legal=1;
            12: legal=!op[6] || op==8'hfc;
            7,15: legal=op[5:4]!=0;
            13: legal=!op[6];
            default:;
        endcase
        else if(op[7:4]>=4) case(op[3:0])
            0,3,4,6,7,8,9,10,12,13,15: legal=1;
            14: legal=op[7:4]>=6;
            default:;
        endcase
        else if(op[7:4]==2) legal=1;
        else case(op)
            8'h01,8'h06,8'h07,8'h08,8'h09,8'h0a,8'h0b,8'h0c,8'h0d,8'h0e,8'h0f,
            8'h10,8'h11,8'h16,8'h17,8'h19,8'h1b,
            8'h30,8'h31,8'h32,8'h33,8'h34,8'h35,8'h36,8'h37,
            8'h39,8'h3b,8'h3e,8'h3f: legal=1;
            default:;
        endcase
    end
endfunction
initial begin
    for(mode=0;mode<2;mode=mode+1) begin
        for(code=0;code<256;code=code+1) begin
            @(negedge clk); rst=1; nsc=mode!=0; raw=code;
            canonical=nsc ? (raw & 8'h3c) | ((raw & 8'h80)>>1) |
                ((raw & 8'h40)<<1) | ((raw & 8'h02)>>1) | ((raw & 8'h01)<<1) : raw;
            expected=legal(canonical) || (nsc &&
                (canonical==8'h71 || canonical==8'h7b || canonical==8'hec));
            repeat(4) @(negedge clk);
            rst=0;
            ticks=0;
            while(!cpu.ni && ticks<1000) begin @(negedge clk); ticks=ticks+1; end
            if(ticks==1000) $fatal(1,"Opcode eligibility did not reach fetch");
            while(cpu.ni && !cpu.illegal && ticks<2000) begin @(negedge clk); ticks=ticks+1; end
            if(ticks==2000 || expected===cpu.illegal)
                $fatal(1,"Opcode eligibility NSC=%0d raw=%h canonical=%h expected=%b illegal=%b",mode,raw,canonical,expected,cpu.illegal);
            rst=1;
            checked=checked+1;
        end
    end
    $display("PASS YAML opcode eligibility: %0d raw bytes/modes, procedure slots rejected, FC compatibility isolated",checked);
    $finish;
end
jt6802 #(
    .FC_COMPAT       ( 1            )
) cpu(
    .irq             ( 1'b0         ),
    .nmi             ( 1'b0         ),
    .ext_halt        ( 1'b0         ),
    .ba              (              ),
    .rst             ( rst          ),
    .cpu_rst         ( rst          ),
    .clk             ( clk          ),
    .cen             ( divider==0   ),
    .enable          ( 1'b1         ),
    .ready           ( 1'b1         ),
    .mr_n            ( 1'b1         ),
    .nsc8105         ( nsc          ),
    .din             ( din          ),
    .addr            ( addr         ),
    .dout            ( dout         ),
    .e               (              ),
    .vma             ( vma          ),
    .wr              ( wr           ),
    .done            ( done         ),
    .instruction_end ( ni           ),
    .opcode_fetch    ( opcode_fetch )
);
endmodule
