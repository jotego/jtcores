/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1, pxl_cen=0;
always #5 clk=~clk;
reg [8:0] h=0, v=32;
wire [12:1] map_addr;
reg [15:0] map_data=0;
wire [16:2] gfx_addr;
wire gfx_cs;
wire [31:0] gfx_data;
wire gfx_ok;
wire [21:0] sdram_addr;
wire sdram_rd;
reg sdram_ack=0, sdram_dst=0, sdram_rdy=0;
reg [15:0] sdram_data=0;
reg selected=0, second=0;
wire [6:0] pxl;
reg pending=0;
reg [14:0] pending_addr;
integer delay_count=0;
integer cycle, line, x, delta, dx, addr, tile, pal, p, plane, bits, diffs, best, best_delta, scenario, current_y;
reg [6:0] observed[0:319];
`ifdef WAIT40
localparam WAIT=40;
`elsif WAIT20
localparam WAIT=20;
`elsif WAIT12
localparam WAIT=12;
`elsif WAIT4
localparam WAIT=4;
`else
localparam WAIT=0;
`endif

jtapach3_text u_text (
    .rst      ( rst       ),
    .clk      ( clk       ),
    .pxl_cen  ( pxl_cen   ),
    .h        ( h         ),
    .v        ( v         ),
    .map_addr ( map_addr  ),
    .map_data ( map_data  ),
    .gfx_addr ( gfx_addr  ),
    .gfx_data ( gfx_data  ),
    .gfx_cs   ( gfx_cs    ),
    .gfx_ok   ( gfx_ok    ),
    .pxl      ( pxl       )
);

function [15:0] mapword;
    input [11:0] address;
    begin mapword = {address[3:0]^address[7:4],address}; end
endfunction
function [7:0] rombyte;
    input [16:0] address;
    begin rombyte = (address*37) ^ (address>>5) ^ (address>>13) ^ 8'ha5; end
endfunction
jtframe_romrq #(
    .SDRAMW ( 22 ),
    .AW     ( 16 ),
    .DW     ( 32 ),
    .DOUBLE (  0 )
) u_cache (
    .rst        ( rst             ),
    .clk        ( clk             ),
    .clr        ( 1'b0            ),
    .offset     ( 22'd0           ),
    .din        ( sdram_data      ),
    .din_ok     ( sdram_rdy       ),
    .dst        ( sdram_dst       ),
    .we         ( selected        ),
    .req        ( sdram_rd        ),
    .sdram_addr ( sdram_addr      ),
    .xaddr      (                 ),
    .xaddr_in   ( 22'd0           ),
    .addr       ( {gfx_addr,1'b0} ),
    .addr_ok    ( gfx_cs          ),
    .data_ok    ( gfx_ok          ),
    .dout       ( gfx_data        )
);

always @(posedge clk) begin
    map_data <= mapword(map_addr);
    sdram_ack <= 0;
    sdram_dst <= 0;
    sdram_rdy <= 0;
    if (rst) begin
        pending <= 0;
        selected <= 0;
        second <= 0;
    end else begin
        if (!pending && !selected && sdram_rd) begin
            if (sdram_addr[0]) $fatal(1,"unaligned text burst");
            pending <= 1;
            selected <= 1;
            sdram_ack <= 1;
            pending_addr <= sdram_addr[15:1];
            delay_count <= WAIT;
            second <= 0;
        end else if (pending) begin
            if (delay_count != 0) delay_count <= delay_count-1;
            else if (!second) begin
                sdram_data <= {rombyte({2'b01,pending_addr}),rombyte({2'b00,pending_addr})};
                sdram_dst <= 1;
                second <= 1;
            end else begin
                sdram_data <= {rombyte({2'b00,pending_addr}),rombyte({2'b10,pending_addr})};
                sdram_rdy <= 1;
                pending <= 0;
            end
        end
        if (sdram_rdy) selected <= 0;
    end
end

initial begin
    repeat (6) @(negedge clk);
    rst=0;
    for (scenario=0;scenario<3;scenario=scenario+1) begin
        for (line=0;line<4;line=line+1) begin
            v=scenario==0 ? 32+line : scenario==1 ? (278+line)%280 : (277+line)%280;
            for (cycle=0;cycle<3200;cycle=cycle+1) begin
                @(negedge clk);
                h=cycle/8; pxl_cen=(cycle%8)==0;
                if (line==3 && cycle%8==2 && h<320) observed[h]=pxl;
            end
        end
        current_y=scenario==0 ? 35 : scenario==1 ? 1 : 0;
        best=321; best_delta=999;
        for (delta=-32;delta<=32;delta=delta+1) begin
            diffs=0;
            for (x=0;x<320;x=x+1) begin
                dx=(x+18+delta)&511;
                addr=((current_y>>3)<<6)|(dx>>3);
                tile=addr; pal=(addr&15)^((addr>>4)&15); p=0;
                for (plane=0;plane<3;plane=plane+1) begin
                    bits=rombyte((plane<<15)|(tile<<3)|(current_y&7));
                    p=p|(((bits>>(7-(dx&7)))&1)<<plane);
                end
                if (observed[x] !== ((pal<<3)|p)) diffs=diffs+1;
            end
            if (diffs<best) begin best=diffs; best_delta=delta; end
        end
        if (best!=0 || best_delta!=0) $fatal(1,"text mismatch y=%0d best_delta=%0d errors=%0d wait=%0d",current_y,best_delta,best,WAIT);
    end
    $display("PASS text pixels and horizontal alignment with ROM wait %0d",WAIT);
    $finish;
end
initial begin
    #1000000;
    $fatal(1,"text test timed out");
end
endmodule
