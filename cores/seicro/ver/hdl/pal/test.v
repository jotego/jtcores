/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

`timescale 1ns/1ps
module test;
reg [1:0] mode;
reg [19:1] pin;
wire [16:15] q;
reg [16:15] expected;
integer program_id, combination, checked=0;

jtseicro_pal dut(
    .mode ( mode ),
    .pin  ( pin  ),
    .q    ( q    )
);

initial begin
    pin=0;
    for(program_id=0;program_id<3;program_id=program_id+1) begin
        mode=program_id;
        for(combination=0;combination<65536;combination=combination+1) begin
            {pin[19:17],pin[14:11],pin[9:1]}=combination;
            if(program_id==0) begin
                expected[15]=pin[4] | pin[4] | (!pin[3]&pin[4]) |
                    (!pin[3]&pin[4]&pin[5]&!pin[11]) |
                    (pin[1]&pin[2]&pin[3]&pin[4]);
                expected[16]=pin[19] | (&pin[9:6]) | (&pin[9:6]) | !pin[3] |
                    (!pin[3]&(&pin[9:6])&pin[11]&pin[12]&pin[13]&pin[14]&
                     pin[17]&!pin[18]&!pin[19]) | !pin[3] |
                    (!pin[3]&(&pin[9:6])&pin[11]&pin[12]&pin[13]&pin[14]&
                     pin[17]&!pin[18]&!pin[19]);
            end else if(program_id==1) begin
                expected[15]=pin[4] | pin[4] | (!pin[3]&pin[4]) |
                    (!pin[3]&pin[4]&pin[5]&!pin[11]) |
                    (pin[1]&pin[2]&pin[3]&pin[4]);
                expected[16]=(&pin[9:6]) | (!pin[2]&pin[19]) |
                    (!pin[2]&(&pin[9:6])&!pin[11]&pin[19]) | !pin[3] |
                    (!pin[3]&(&pin[9:6])&pin[11]&pin[12]&pin[13]&pin[14]&
                     pin[17]&!pin[18]&!pin[19]);
            end else begin
                expected[15]=pin[4] | pin[4] | pin[4] |
                    (pin[1]&pin[3]&pin[4]);
                expected[16]=pin[19] | (!pin[3]&pin[19]) |
                    (pin[3]&pin[19]) | (!pin[2]&pin[3]&pin[11]&pin[19]);
            end
            #1;
            if(q!==expected)
                $fatal(1,"PAL mode=%0d inputs=%h actual=%b expected=%b",
                    program_id,pin,q,expected);
            checked=checked+1;
        end
    end
    $display("PASS PAL: %0d original-jedutil equation combinations",checked);
    $finish;
end
endmodule
