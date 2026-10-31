/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0, rst=1, pxl_cen=0;
always #5 clk=~clk;
reg [8:0] h=0, v=0;
reg [15:0] rotate_data=0;
reg rotate_we=0;
reg [7:0] road_z=0;
reg invalidate=0, road_invalidate=0, alter=0;
wire [8:1] road_x_addr;
wire [8:0] prom_addr;
reg [15:0] road_x_data=0;
reg [7:0] prom_data=0;
wire [15:1] ram_addr;
wire ram_cs;
reg [15:0] ram_data=0;
reg ram_ok=0;
wire [10:0] pxl;
wire overflow;
reg pending=0;
reg [14:0] pending_addr;
integer delay_count=0;
integer i, scenario, phase, px, row, hv, mag, pixel, stripe, want;
integer h_start, g_start, h_dx, h_dy, g_dx, g_dy, r, xoff, b, y, index, bank;
integer restore_file, restore_count;
reg [7:0] restore_expected [0:31];
`ifdef WAIT20
localparam WAIT=20;
`elsif WAIT12
localparam WAIT=12;
`elsif WAIT7
localparam WAIT=7;
`else
localparam WAIT=0;
`endif

jtapach3_ground u_ground (
    .rst         ( rst         ),
    .clk         ( clk         ),
    .pxl_cen     ( pxl_cen     ),
    .h           ( h           ),
    .v           ( v           ),
    .rotate_data ( rotate_data ),
    .rotate_we   ( rotate_we   ),
    .road_z      ( road_z      ),
    .invalidate  ( invalidate  ),
    .road_invalidate ( road_invalidate ),
    .road_x_addr ( road_x_addr ),
    .road_x_data ( road_x_data ),
    .prom_addr   ( prom_addr   ),
    .prom_data   ( prom_data   ),
    .ram_addr    ( ram_addr    ),
    .ram_cs      ( ram_cs      ),
    .ram_data    ( ram_data    ),
    .ram_ok      ( ram_ok      ),
    .pxl         ( pxl         ),
    .overflow    ( overflow    )
);

function [15:0] xvalue;
    input [7:0] row_number;
    integer value;
    begin
        value = ((row_number*19)%2048)-1024 + (alter ? 1 : 0);
        xvalue = value;
    end
endfunction
function [7:0] pvalue;
    input [7:0] row_number;
    begin pvalue = row_number*13+7; end
endfunction
function [7:0] gvalue;
    input [14:0] address;
    begin gvalue = (address*79+(address>>7)) ^ (alter ? 8'hff : 8'h00); end
endfunction

always @(posedge clk) begin
    road_x_data <= xvalue(road_x_addr);
    prom_data <= pvalue(prom_addr[7:0]);
    if (rst) begin
        ram_ok <= 0;
        pending <= 0;
    end else if (!ram_cs) begin
        ram_ok <= 0;
        pending <= 0;
    end else if (!pending && !ram_ok) begin
        pending <= 1;
        pending_addr <= ram_addr;
        delay_count <= WAIT + (ram_addr % 3);
    end else if (pending) begin
        if (ram_addr != pending_addr) $fatal(1,"RAM address changed while waiting");
        if (delay_count != 0) delay_count <= delay_count-1;
        else begin
            ram_data <= {8'h00,gvalue(pending_addr)};
            ram_ok <= 1;
            pending <= 0;
        end
    end
end

task write_rotate;
    input [15:0] value;
    begin
        @(negedge clk); rotate_data=value; rotate_we=1;
        @(negedge clk); rotate_we=0;
    end
endtask

task setup;
    begin
        write_rotate((h_start>>16)&255);
        write_rotate(0);
        write_rotate(h_dx);
        write_rotate(0);
        write_rotate(h_start);
        write_rotate(0);
        write_rotate(h_dy);
        write_rotate(0);
        write_rotate(g_dx);
        write_rotate((g_start>>8)&65535);
        write_rotate(g_start&255);
        write_rotate(g_dy);
    end
endtask

initial begin
    restore_file=$fopen("rest.bin","rb");
    restore_count=0;
    if (restore_file) begin
        restore_count=$fread(restore_expected,restore_file);
        $fclose(restore_file);
    end
    for (scenario=0;scenario<8;scenario=scenario+1) begin
        @(negedge clk); rst=1; pxl_cen=0; h=0; v=0;
        repeat (5) @(negedge clk);
        rst=0; road_z=23; alter=0; invalidate=0; road_invalidate=0;
        if (restore_count>=32) begin
            for (i=0;i<12;i=i+1)
                if (u_ground.rotate[i] !== {restore_expected[2*i+1],restore_expected[2*i]})
                    $fatal(1,"rotation restore %0d",i);
            if (u_ground.rotate_idx !== restore_expected[24][3:0]) $fatal(1,"rotation index restore");
            while (u_ground.rotate_idx != 0) write_rotate(0);
        end
        v=scenario==4 ? 279 : (scenario*41)%200;
        y=v==279 ? 0 : v+1;
        case(scenario)
            0: begin h_start=0; g_start=-40*256; h_dx=256; h_dy=0; g_dx=0; g_dy=0; end
            1: begin h_start=320*256; g_start=35*256; h_dx=256; h_dy=-100; g_dx=0; g_dy=17; end
            2: begin h_start=-700*256; g_start=280*256; h_dx=384; h_dy=10; g_dx=-4; g_dy=-4; end
            3: begin h_start=-100*256; g_start=-2*256; h_dx=128; h_dy=0; g_dx=5; g_dy=4; end
            4: begin h_start=700*256; g_start=120*256; h_dx=-256; h_dy=0; g_dx=2; g_dy=0; end
            5: begin h_start=0; g_start=-200*256; h_dx=256; h_dy=0; g_dx=0; g_dy=0; end
            6: begin h_start=0; g_start=54*256; h_dx=512; h_dy=0; g_dx=0; g_dy=0; end
            7: begin h_start=0; g_start=54*256; h_dx=0; h_dy=0; g_dx=0; g_dy=0; end
        endcase
        setup();
        bank=u_ground.u_buffer.line;
        for (i=0;i<3200;i=i+1) begin
            @(negedge clk);
            h=i/8; pxl_cen=(i%8)==0;
        end
        @(negedge clk); pxl_cen=0;
        if (overflow || u_ground.state != 0) $fatal(1,"line did not finish scenario=%0d state=%0d x=%0d",scenario,u_ground.state,u_ground.x);
        for (px=0;px<320;px=px+1) begin
            row=(g_start+y*g_dy+px*g_dx)>>>8;
            if (row<0) begin
                want=256+((row+128)<0 ? 0 : row+128);
            end else begin
                r=row>255 ? 255 : row;
                xoff=$signed(xvalue(r));
                hv=((h_start+y*h_dy+px*h_dx)>>>8)+xoff;
                hv=hv & 4095;
                if (hv>=2048) hv=hv-4096;
                mag=hv<0 ? ~hv : hv;
                pixel=0;
                if (mag<512) begin
                    b=gvalue((r<<7)|(mag>>2));
                    pixel=(b>>((mag&3)*2))&3;
                end
                stripe=((pvalue(r)+road_z)>>5)&3;
                want=512+(hv<0 ? 16 : 0)+(pixel<<2)+stripe;
            end
            index=bank*512+px;
            if (u_ground.u_buffer.u_line.mem[index] !== want[10:0])
                $fatal(1,"scenario=%0d x=%0d got=%h expected=%h",scenario,px,u_ground.u_buffer.u_line.mem[index],want[10:0]);
            @(negedge clk); h=px==0 ? 399 : px-1; v=px==0 ? (y==0 ? 279 : y-1) : y;
            repeat (2) @(negedge clk);
            if (pxl !== want[10:0]) $fatal(1,"display scenario=%0d x=%0d got=%h expected=%h",scenario,px,pxl,want[10:0]);
        end
        if (scenario==7) begin
            @(negedge clk); alter=1; invalidate=1; road_invalidate=1;
            @(negedge clk); invalidate=0; road_invalidate=0; v=y-1;
            bank=u_ground.u_buffer.line;
            for (i=0;i<3200;i=i+1) begin
                @(negedge clk); h=i/8; pxl_cen=(i%8)==0;
            end
            @(negedge clk); pxl_cen=0;
            if (overflow || u_ground.state != 0) $fatal(1,"invalidation line did not finish");
            hv=$signed(xvalue(54));
            b=gvalue((54<<7)|(hv>>2));
            pixel=(b>>((hv&3)*2))&3;
            stripe=((pvalue(54)+road_z)>>5)&3;
            want=512+(pixel<<2)+stripe;
            index=bank*512;
            if (u_ground.u_buffer.u_line.mem[index] !== want[10:0])
                $fatal(1,"cache invalidation got=%h expected=%h",u_ground.u_buffer.u_line.mem[index],want[10:0]);
        end
    end
    for (phase=0;phase<3;phase=phase+1) begin
        @(negedge clk); rst=1; pxl_cen=0; h=397; v=10;
        repeat (5) @(negedge clk);
        rst=0;
        force ram_ok=0;
        force ram_data=16'hffff;
        u_ground.state=4;
        u_ground.target_y=11;
        u_ground.x=319;
        u_ground.ram_cs=1;
        bank=u_ground.u_buffer.line;
        for (i=0;i<1024;i=i+1) u_ground.u_buffer.u_line.mem[i]=0;
        u_ground.u_buffer.u_line.mem[bank*512]=11'h135;
        repeat (3) @(negedge clk);
        h=398;
        repeat (2) @(negedge clk);
        if (phase==0) force ram_ok=1;
        repeat (6) @(negedge clk);
        h=399;
        if (phase==1) force ram_ok=1;
        repeat (8) @(negedge clk);
        if (pxl !== 11'h135) $fatal(1,"partial ground line lost at swap");
        h=0; v=11; pxl_cen=1;
        @(negedge clk); pxl_cen=0;
        if (phase==2) begin
            if (!overflow) $fatal(1,"late ground line did not flag overflow");
            force ram_ok=1;
        end
        repeat (3) @(negedge clk);
        if (u_ground.u_buffer.u_line.mem[bank*512+319] !== 0 ||
            u_ground.u_buffer.u_line.mem[(1-bank)*512+319] !== 0)
            $fatal(1,"late response crossed ground buffer boundary phase=%0d",phase);
        if (ram_cs) $fatal(1,"late ground response was not drained");
        release ram_ok;
        release ram_data;
    end
    $display("PASS ground wait=%0d, sky, mirrored ground, row clamp, rotation, cache invalidation and late line responses",WAIT);
    $finish;
end
initial begin
    #1000000;
    $fatal(1,"ground test timed out");
end
endmodule
