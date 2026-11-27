/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0, rst=1, vblk=1, v0=0;
reg [8:0] h=0;
wire palette_clr_n, color_clr_n, data_blank, bank_blank, bank_sel;
wire bank_sel_n, mux_fh_gn, mux_eg_gn;
wire cdt3_n, data_blank_q;
reg history[0:399];
reg blank_history[0:3];
reg sampled_history[0:7];
reg palette_expected, color_expected, blank_expected;
reg sampled_expected, cdt3_expected, cdt3_previous;
reg bank_blank_expected, bank_expected;
integer phase, palette_delay, frame, line, pixel, tick=0, i, checked=0;
integer cdt3_edges;

always #5 clk=~clk;

jtseicro_blanking dut(
    .rst           ( rst           ),
    .clk           ( clk           ),
    .vblk          ( vblk          ),
    .v0            ( v0            ),
    .h             ( h             ),
    .palette_clr_n ( palette_clr_n ),
    .color_clr_n   ( color_clr_n   ),
    .data_blank    ( data_blank    ),
    .cdt3_n        ( cdt3_n        ),
    .data_blank_q  ( data_blank_q  ),
    .bank_blank    ( bank_blank    ),
    .bank_sel      ( bank_sel      ),
    .bank_sel_n    ( bank_sel_n    ),
    .mux_fh_gn     ( mux_fh_gn     ),
    .mux_eg_gn     ( mux_eg_gn     )
);

task drive;
    input [8:0] next_h;
    input next_v0, next_vblk;
    begin
        @(negedge clk);
        h=next_h; v0=next_v0; vblk=next_vblk;
        repeat(7) @(negedge clk);
    end
endtask

task check;
    input expected_palette, expected_color;
    begin
        if(palette_clr_n!==expected_palette || color_clr_n!==expected_color)
            $fatal(1,"Blanking h=%0d v0=%b vblk=%b palette=%b/%b color=%b/%b",
                h,v0,vblk,palette_clr_n,expected_palette,color_clr_n,expected_color);
    end
endtask

task check_blank;
    input expected_blank;
    begin
        if(data_blank!==expected_blank)
            $fatal(1,"Data blank h=%0d vblk=%b actual=%b expected=%b",
                h,vblk,data_blank,expected_blank);
    end
endtask

task check_sampled_blank;
    input expected_blank;
    begin
        if(data_blank_q!==expected_blank)
            $fatal(1,"8N blank h=%0d vblk=%b actual=%b expected=%b",
                h,vblk,data_blank_q,expected_blank);
    end
endtask

task check_bank;
    input expected_blank, expected_bank;
    reg [1:0] expected_gn;
    begin
        case({expected_blank,expected_bank})
            2'b00: expected_gn=2'b10;
            2'b01: expected_gn=2'b01;
            2'b10: expected_gn=2'b00;
            2'b11: expected_gn=2'b00;
        endcase
        if(bank_blank!==expected_blank || bank_sel!==expected_bank)
            $fatal(1,"Bank h=%0d qualifier=%b/%b select=%b/%b",
                h,bank_blank,expected_blank,bank_sel,expected_bank);
        if({mux_fh_gn,mux_eg_gn}!==expected_gn)
            $fatal(1,"Mux enable h=%0d FH/EG /G=%b/%b expected=%b",
                h,mux_fh_gn,mux_eg_gn,expected_gn);
    end
endtask

initial begin
    for(phase=0;phase<2;phase=phase+1) begin
        @(negedge clk); rst=1;
        drive(128,phase[0],1);
        for(i=0;i<400;i=i+1) history[i]=1;
        for(i=0;i<4;i=i+1) blank_history[i]=1;
        for(i=0;i<8;i=i+1) sampled_history[i]=1;
        cdt3_previous=1;
        tick=0;
        palette_delay=phase==0 ? 400 : 16;
        @(negedge clk); rst=0;
        for(frame=0;frame<2;frame=frame+1) begin
            for(line=0;line<264;line=line+1) begin
                cdt3_edges=0;
                for(pixel=128;pixel<512;pixel=pixel+1) begin
                    palette_expected=!history[(tick+400-palette_delay)%400];
                    color_expected=!history[(tick+392)%400];
                    blank_expected=blank_history[tick%4];
                    sampled_expected=sampled_history[tick%8];
                    cdt3_expected=pixel<256 ? pixel%16!=7 : pixel%8!=7;
                    bank_blank_expected=(pixel>=136 && pixel<264) || (frame==0 && line==0 && pixel<136);
                    bank_expected=frame==0 && line==0 ? 0 : (pixel<136 ? !line[0] : line[0]);
                    drive(pixel[8:0],line[0]^phase[0],line<16 || line>=240);
                    check(palette_expected,color_expected);
                    check_blank(blank_expected);
                    check_sampled_blank(sampled_expected);
                    check_bank(bank_blank_expected,bank_expected);
                    if(cdt3_n!==cdt3_expected)
                        $fatal(1,"CDT3 h=%0d actual=%b expected=%b",
                            h,cdt3_n,cdt3_expected);
                    if(cdt3_n && !cdt3_previous) cdt3_edges=cdt3_edges+1;
                    cdt3_previous=cdt3_n;
                    history[tick%400]=vblk;
                    blank_history[tick%4]=vblk || !h[8];
                    sampled_history[tick%8]=vblk || !h[8];
                    tick=tick+1;
                    checked=checked+1;
                end
                if(cdt3_edges!==(frame==0 && line==0 ? 39 : 40))
                    $fatal(1,"CDT3 rising edges frame=%0d line=%0d count=%0d",
                        frame,line,cdt3_edges);
            end
        end
    end
    drive(0,0,0);
    check(0,0);
    drive(7,0,0);
    check(0,0);
    drive(8,0,0);
    check(0,1);
    drive(16,0,0);
    check(0,1);
    drive(16,1,0);
    check(1,1);
    drive(16,1,1);
    check(1,1);
    drive(7,1,1);
    check(1,1);
    drive(8,1,1);
    check(1,0);
    drive(16,1,1);
    check(0,0);
    @(negedge clk); rst=1;
    drive(16,1,0);
    check(0,0);
    @(negedge clk); rst=0;
    drive(16,1,0);
    check(0,0);
    drive(0,1,0);
    check(0,0);
    drive(16,1,0);
    check(1,0);
    @(negedge clk); rst=1;
    drive(260,0,0);
    check_blank(1);
    @(negedge clk); rst=0;
    drive(260,0,0);
    check_blank(1);
    drive(256,0,0);
    check_blank(1);
    drive(260,0,0);
    check_blank(0);
    drive(128,0,0);
    check_blank(0);
    drive(132,0,0);
    check_blank(1);
    drive(256,0,0);
    check_blank(1);
    drive(260,0,0);
    check_blank(0);
    drive(260,0,1);
    check_blank(0);
    drive(256,0,1);
    check_blank(0);
    drive(260,0,1);
    check_blank(1);
    drive(260,0,0);
    check_blank(1);
    drive(256,0,0);
    check_blank(1);
    drive(260,0,0);
    check_blank(0);
    @(negedge clk); rst=1;
    drive(140,0,0);
    check_bank(1,0);
    @(negedge clk); rst=0;
    drive(140,0,0);
    check_bank(1,0);
    drive(264,0,0);
    check_bank(1,0);
    drive(268,0,0);
    check_bank(1,0);
    drive(264,1,1);
    check_bank(1,0);
    drive(256,1,1);
    check_bank(1,0);
    drive(264,1,1);
    check_bank(0,0);
    drive(128,0,0);
    check_bank(0,0);
    drive(136,0,0);
    check_bank(0,0);
    drive(128,0,0);
    check_bank(0,0);
    drive(132,0,0);
    check_bank(0,0);
    drive(136,0,0);
    check_bank(1,1);
    drive(144,0,0);
    check_bank(1,1);
    drive(152,0,0);
    check_bank(1,1);
    drive(256,0,0);
    check_bank(1,1);
    drive(260,0,0);
    check_bank(1,1);
    drive(264,0,0);
    check_bank(0,1);
    drive(128,0,0);
    check_bank(0,1);
    drive(132,0,0);
    check_bank(0,1);
    drive(136,0,0);
    check_bank(1,0);
    @(negedge clk); rst=1;
    drive(264,0,0);
    check_sampled_blank(1);
    @(negedge clk); rst=0;
    drive(264,0,0);
    check_sampled_blank(1);
    drive(260,0,0);
    check_blank(0);
    check_sampled_blank(1);
    drive(263,0,0);
    check_sampled_blank(1);
    drive(264,0,0);
    check_sampled_blank(0);
    drive(260,0,1);
    check_blank(1);
    check_sampled_blank(0);
    drive(263,0,1);
    check_sampled_blank(0);
    drive(264,0,1);
    check_sampled_blank(1);
    drive(260,0,0);
    check_blank(0);
    check_sampled_blank(1);
    drive(263,0,0);
    check_sampled_blank(1);
    drive(264,0,0);
    check_sampled_blank(0);
    $display("PASS blanking: %0d pixels, data 4/8N 8/color 8/palette 16 or 400 pixel delays, CDT3 8/16-pixel strobes and 40 rising edges per line, bank switch H136, 7B mux enables, both V0 phases, frame wrap, edge sampling and FPGA initialization",checked);
    $finish;
end

initial begin
    #40000000;
    $fatal(1,"Blanking test timeout");
end

endmodule
