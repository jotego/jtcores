/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1, flush=0, start=0, bank=0, pop=0;
always #5 clk=~clk;
reg [8:0] length=0;
reg [8:0] target_y=17;
wire [9:0] ram_addr;
reg [207:0] ram_data;
wire busy, valid;
wire [207:0] data;
wire [8:0] index;
integer scenario, received, cycles, expected_index, expected_count, k;
reg stalled;
reg [216:0] held;
function [207:0] entry;
    input [9:0] address;
    begin
        entry={{6{32'h394ab517}},6'h2d,address};
        entry[135:128]=address[8:0]%5==0 ? 8'd40 : 8'd0;
        entry[143:136]=address[8:0]%5==0 ? 8'd80 : 8'd240;
    end
endfunction
jtapach3_objlist u_list (
    .rst      ( rst      ),
    .clk      ( clk      ),
    .flush    ( flush    ),
    .start    ( start    ),
    .bank     ( bank     ),
    .length   ( length   ),
    .target_y ( target_y ),
    .ram_addr ( ram_addr ),
    .ram_data ( ram_data ),
    .busy     ( busy     ),
    .valid    ( valid    ),
    .data     ( data     ),
    .index    ( index    ),
    .pop      ( pop      )
);
always @(posedge clk) ram_data<=entry(ram_addr);
initial begin
    repeat (5) @(negedge clk); rst=0;
    for (scenario=0;scenario<12;scenario=scenario+1) begin
        bank=scenario[0];
        target_y=scenario[2] ? 50 : 17;
        case (scenario%4)
            0: length=0;
            1: length=1;
            2: length=88;
            3: length=342;
        endcase
        start=1; @(negedge clk); start=0;
        received=0; cycles=0; stalled=0;
        expected_index=length-1;
        expected_count=0;
        for (k=0;k<length;k=k+1) if (k%5!=0 || (target_y>=40 && target_y<80)) expected_count=expected_count+1;
        while (busy || valid) begin
            pop=scenario[1] || cycles%17<9;
            if (stalled && {index,data}!==held) $fatal(1,"sprite list changed while stalled");
            if (valid && pop) begin
                while (expected_index>=0 && expected_index%5==0 && (target_y<40 || target_y>=80)) expected_index=expected_index-1;
                if (received>=expected_count || index!==expected_index || data!==entry({bank,index}))
                    $fatal(1,"sprite list ordering/data scenario=%0d item=%0d index=%0d",scenario,received,index);
                received=received+1;
                expected_index=expected_index-1;
            end
            held={index,data}; stalled=valid && !pop;
            @(negedge clk); cycles=cycles+1;
            if (cycles>2000) $fatal(1,"sprite list timeout");
        end
        if (received!=expected_count) $fatal(1,"sprite list lost entries");
    end
    length=342; start=1; @(negedge clk); start=0; pop=0;
    repeat (7) @(negedge clk);
    flush=1; @(negedge clk); flush=0;
    if (busy || valid) $fatal(1,"sprite list flush failed");
    $display("PASS reverse sprite lists with line filtering: both banks, 0/1/88/342 entries, full-rate reads, stalls and flush");
    $finish;
end
endmodule
