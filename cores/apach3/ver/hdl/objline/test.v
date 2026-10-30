/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1, pxl_cen=0, rom_ok=0;
always #5 clk=~clk;
reg [8:0] h=380, v=10;
wire [13:1] ram_addr;
wire [8:1] ctrl_addr;
wire [20:3] rom_addr;
wire rom_cs, overflow;
wire [9:0] pxl;
integer scenario, phase, i, bank, reads;

jtapach3_obj u_obj (
    .rst       ( rst              ),
    .clk       ( clk              ),
    .pxl_cen   ( pxl_cen          ),
    .h         ( h                ),
    .v         ( v                ),
    .ram_addr  ( ram_addr         ),
    .ram_data  ( 16'hffff         ),
    .ctrl_addr ( ctrl_addr        ),
    .ctrl_data ( 16'd0            ),
    .rom_addr  ( rom_addr         ),
    .rom_cs    ( rom_cs           ),
    .rom_data  ( 64'h123456789abc ),
    .rom_ok    ( rom_ok           ),
    .pxl       ( pxl              ),
    .overflow  ( overflow         )
);

task tick;
    begin @(negedge clk); end
endtask

initial begin
    force u_obj.clut_color=8'h35;
    for (scenario=0;scenario<16;scenario=scenario+1) begin
        rst=1; h=380; v=10; pxl_cen=0; rom_ok=0;
        repeat (5) tick();
        rst=0;
        u_obj.loaded=1;
        u_obj.state=0;
        u_obj.frame_valid=1;
        u_obj.frame_ready=1;
        u_obj.object_count=0;
        u_obj.drawing=1;
        u_obj.dr_state=0;
        u_obj.fast_pending=0;
        u_obj.rom_owner=0;
        bank=u_obj.u_buffer.line;
        for (i=0;i<1024;i=i+1) u_obj.u_buffer.u_line.u_ram.mem[i]=0;
        u_obj.color_valid=2'b10;
        u_obj.color_x1=0;
        repeat (6) tick();
        u_obj.color_valid=2'b10;
        u_obj.color_x1=319;
        repeat (6) tick();
        u_obj.state=scenario<8 ? 6 : 0;
        if (scenario>=8) begin
            u_obj.dr_state=1;
            u_obj.fast_pending=1;
            u_obj.fast_wait=1;
            u_obj.rom_owner=1;
            u_obj.fast_request=18'h12345;
        end
        u_obj.request_addr=18'h12345;
        u_obj.return_state=16;
        h=396;
        for (phase=0;phase<8;phase=phase+1) begin
            pxl_cen=phase==0;
            if (phase==(scenario%8)) begin
                u_obj.color_valid=2'b01;
                u_obj.color_x0=37;
            end
            tick();
        end
        h=397;
        for (phase=0;phase<8;phase=phase+1) begin
            pxl_cen=phase==0;
            tick();
            if (!rom_cs || rom_addr!=18'h12345) $fatal(1,"ROM request cancelled before boundary");
        end
        if (!overflow) $fatal(1,"missing deadline indicator");
        if (u_obj.u_buffer.u_line.u_ram.mem[bank*512+0] !== 9'h135) $fatal(1,"completed pixel lost");
        if (u_obj.u_buffer.u_line.u_ram.mem[bank*512+37] !== 9'h135) $fatal(1,"pipeline tail lost phase=%0d",scenario);
        h=398; pxl_cen=1; tick(); pxl_cen=0;
        repeat (2) tick();
        if (pxl[8:0] !== 9'h135) $fatal(1,"first pixel lost at early swap: %h",pxl);
        repeat (5) tick();
        h=399; pxl_cen=1; tick(); pxl_cen=0;
        repeat (7) tick();
        h=0; v=11; pxl_cen=1; tick();
        pxl_cen=0;
        repeat (12+scenario) begin
            tick();
            if (!rom_cs || rom_addr!=18'h12345) $fatal(1,"ROM request changed across boundary");
            if (u_obj.write_enable) $fatal(1,"late pixel reached new line");
        end
        rom_ok=1; tick(); rom_ok=0;
        repeat (6) tick();
        if (rom_cs || u_obj.launch_pending) $fatal(1,"new line failed to restart");
        for (i=0;i<512;i=i+1)
            if (u_obj.u_buffer.u_line.u_ram.mem[(1-bank)*512+i] !== 0) $fatal(1,"new buffer contaminated at %0d",i);
        h=317; pxl_cen=1; tick(); pxl_cen=0;
        repeat (2) tick();
        if (pxl[8:0] !== 9'h135) $fatal(1,"last pixel lost at early swap: %h",pxl);
        h=35; pxl_cen=1; tick(); pxl_cen=0;
        repeat (2) tick();
        if (pxl[8:0] !== 9'h135) $fatal(1,"partial line not displayed: %h",pxl);
    end
    $display("PASS partial sprite lines, double buffering, eight pipeline phases and both delayed ROM owners");
    $finish;
end
initial begin
    #1000000;
    $fatal(1,"timeout");
end
endmodule
