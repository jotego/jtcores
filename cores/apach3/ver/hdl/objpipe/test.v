/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1, flush=0, start=0;
always #5 clk=~clk;
reg signed [59:0] source_x=0, source_y=0, step_x=0, step_y=0;
reg [8:0] scale=128;
reg [32:0] reciprocal=0;
reg fx=0, fy=0, repeat_rows=0;
reg desc_we=0;
reg [10:0] desc_addr=0;
reg [4:0] desc_page=0;
wire [31:0] x_min=(desc_page[0]*8*scale+127)/128;
wire [31:0] x_max=(64*scale+127)/128;
reg [11:0] desc_left=0;
reg [12:0] desc_right=0;
reg [17:0] desc_base=0;
wire busy, valid, ahead_valid;
wire [47:0] pixel;
wire [17:0] ahead_addr;
reg pop=0;
reg [319:0] occupied=0;
reg [47:0] expected [0:319];
integer scenario, i, n, received, cycles, px, py, col, line, row, left, right, base, tile, address;
reg signed [59:0] sx, sy;
reg [47:0] held;
reg stalled;

jtapach3_objpipe u_pipe (
    .rst         ( rst         ),
    .clk         ( clk         ),
    .flush       ( flush       ),
    .start       ( start       ),
    .occupied    ( occupied    ),
    .source_x    ( source_x    ),
    .source_y    ( source_y    ),
    .step_x      ( step_x      ),
    .step_y      ( step_y      ),
    .first_x     ( 9'd0        ),
    .last_x      ( 9'd319      ),
    .target_y    ( 9'd17       ),
    .palette     ( 8'ha7       ),
    .scale       ( scale       ),
    .reciprocal  ( reciprocal  ),
    .flip_x      ( fx          ),
    .flip_y      ( fy          ),
    .repeat_line ( repeat_rows ),
    .top_line    ( 9'd0        ),
    .bottom_line ( 10'd512     ),
    .x_min       ( x_min       ),
    .x_max       ( x_max       ),
    .y_min       ( 32'd0       ),
    .y_max       ( 32'd2044    ),
    .desc_we     ( desc_we     ),
    .desc_addr   ( desc_addr   ),
    .desc_page   ( desc_page   ),
    .desc_left   ( desc_left   ),
    .desc_right  ( desc_right  ),
    .desc_base   ( desc_base   ),
    .busy        ( busy        ),
    .valid       ( valid       ),
    .pop         ( pop         ),
    .pixel       ( pixel       ),
    .ahead_valid ( ahead_valid ),
    .ahead_addr  ( ahead_addr  )
);
initial begin
    repeat (4) @(negedge clk);
    rst=0;
    for (i=0;i<2048;i=i+1) begin
        desc_we=1; desc_addr=i; desc_left=((i%64)%3+(i/64)%2)*8; desc_right=((i%64)%3+(i/64)%2+(i%64)%5+1)*8; desc_base=(i%64)*173+300+(i/64)*31;
        @(negedge clk);
    end
    desc_we=0;
    for (scenario=0;scenario<64;scenario=scenario+1) begin
        case (scenario%4)
            0: scale=128;
            1: scale=37;
            2: scale=511;
            3: scale=7;
        endcase
        desc_page=scenario%32;
        reciprocal=(33'h100000000+scale-1)/scale;
        fx=scenario[2]; fy=scenario[3]; repeat_rows=scenario[4];
        source_x=fx ? -(60'sd120<<<40) : -(60'sd8<<<40);
        source_y=fy ? -(60'sd80<<<40) : (60'sd4<<<40);
        step_x=(scenario[1] ? 60'sd3 : 60'sd1)<<<39;
        step_y=(scenario[0] ? -60'sd1 : 60'sd1)<<<38;
        for (i=0;i<320;i=i+1) occupied[i]=scenario[5] && ((i>=64 && i<128) || i%7==3);
        n=0; sx=source_x; sy=source_y;
        for (i=0;i<320;i=i+1) begin
            px=sx>>>40; py=sy>>>40;
            if (fx) px=-px-1;
            if (fy) py=-py-1;
            if (!occupied[i] && px>=0 && py>=0 && py<2044) begin
                col=(px*128)/scale; line=(py*128)/scale; row=line/8;
                if (line<512) begin
                    left=(row%3+desc_page%2)*8; right=(row%3+desc_page%2+row%5+1)*8; base=row*173+300+desc_page*31;
                    if (col>=left && (repeat_rows || col<right)) begin
                        if (col>=right) col=left+(col-left)%(right-left);
                        tile=base+(col-left)/8;
                        address=((tile/2)%32768)*8+(line%8);
                        expected[n]={9'd17,8'ha7,i[8:0],address[17:0],tile[0],col[2:0]^3'd3};
                        n=n+1;
                    end
                end
            end
            sx=sx+step_x; sy=sy+step_y;
        end
        start=1; @(negedge clk); start=0;
        received=0; cycles=0; stalled=0;
        while (busy || valid) begin
            pop=(cycles%29)<11;
            if (stalled && pixel!==held) $fatal(1,"FIFO head changed while stalled");
            if (ahead_valid && (received+1>=n || ahead_addr!==expected[received+1][21:4])) $fatal(1,"transformed prefetch address mismatch");
            if (valid && pop) begin
                if (received>=n || pixel!==expected[received])
                    $fatal(1,"scenario=%0d pixel=%0d got=%h expected=%h",scenario,received,pixel,expected[received]);
                received=received+1;
            end
            stalled=valid && !pop; held=pixel;
            @(negedge clk); cycles=cycles+1;
            if (cycles>10000) $fatal(1,"timeout");
        end
        if (received!=n) $fatal(1,"lost pixels %0d/%0d",received,n);
    end
    start=1; @(negedge clk); start=0; pop=0;
    repeat (40) @(negedge clk);
    flush=1; @(negedge clk); flush=0;
    if (busy || valid) $fatal(1,"flush failed");
    $display("PASS transformed requests: signed coordinates, flips, scales, repeat, row changes, stalls, tags and flush");
    $finish;
end
endmodule
