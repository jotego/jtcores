/* SPDX-FileCopyrightText: 2026 JOTEGO
 * SPDX-License-Identifier: GPL-3.0-or-later */

`timescale 1ns/1ps
module test;
reg nsc8105, frisky;
reg [7:0] opcode_raw;
wire [7:0] opcode;
reg [7:0] expected;
integer k;

jtseicro_opcode dut(
    .nsc8105   ( nsc8105   ),
    .frisky    ( frisky    ),
    .opcode_raw( opcode_raw),
    .opcode    ( opcode    )
);

function [7:0] permute;
    input [7:0] raw;
    begin permute={raw[6],raw[7],raw[5:2],raw[0],raw[1]}; end
endfunction

function [7:0] expected_decode;
    input [7:0] raw;
    input nsc;
    input fr;
    begin
        if(!nsc && fr && raw==8'hfc)
            expected_decode=8'h13;
        else
            expected_decode=nsc ? permute(raw) : raw;
    end
endfunction

task check_byte;
    input [7:0] raw;
    input nsc;
    input fr;
    begin
        nsc8105=nsc;
        frisky=fr;
        opcode_raw=raw;
        expected=expected_decode(raw,nsc,fr);
        #1;
        if(opcode!==expected)
            $fatal(1,"decode raw=%02h nsc=%b frisky=%b got=%02h expected=%02h",raw,nsc,fr,opcode,expected);
    end
endtask

initial begin
    // Exhaustively check pure raw passthrough or NSC bit permutation, with
    // only the documented runtime-specific Frisky raw-FC dispatch exception.
    for(k=0;k<256;k=k+1) check_byte(k[7:0],1'b0,1'b0);
    for(k=0;k<256;k=k+1) check_byte(k[7:0],1'b0,1'b1);
    for(k=0;k<256;k=k+1) check_byte(k[7:0],1'b1,1'b0);
    for(k=0;k<256;k=k+1) check_byte(k[7:0],1'b1,1'b1);

    // Representative undefined and extension bytes retain their raw mapping;
    // this test does not assign behavior to otherwise-unspecified opcodes.
    check_byte(8'h00,1'b0,1'b0);
    check_byte(8'h03,1'b0,1'b0);
    check_byte(8'h12,1'b0,1'b0);
    check_byte(8'h13,1'b0,1'b0);
    check_byte(8'h71,1'b0,1'b0);
    check_byte(8'h7b,1'b0,1'b0);
    check_byte(8'hec,1'b0,1'b0);
    check_byte(8'hfc,1'b0,1'b0);
    check_byte(8'hfc,1'b0,1'b1);
    check_byte(8'hfc,1'b1,1'b0);
    check_byte(8'hfc,1'b1,1'b1);
    check_byte(8'hb2,1'b1,1'b0);
    check_byte(8'hbb,1'b1,1'b0);
    check_byte(8'hec,1'b1,1'b0);

    if(expected_decode(8'hfc,1'b0,1'b1)!==8'h13 ||
       expected_decode(8'hfc,1'b0,1'b0)!==8'hfc ||
       expected_decode(8'hfc,1'b1,1'b1)!==permute(8'hfc))
        $fatal(1,"Frisky FC dispatch escaped its standard-mode gate");

    $display("PASS Seicro decoder: exhaustive passthrough/permutation and Frisky FC gate");
    $finish;
end
endmodule
