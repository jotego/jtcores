/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0, spi_clk=0, rst=1, start=0, sample=0, finish=0, bank=0, abort_all=0;
reg [14:0] pixel=0;
reg [9:0] spi_pixel_addr=0;
wire [15:0] spi_pixel_data;
wire busy, committed, committed_bank;
wire [7:0] prefix;
reg [14:0] pixels[0:511];
reg [7:0] bytes[0:1023];
integer i, n, total, waited, inpos, outpos, run_length;
reg [15:0] token, count_word;

always #5 clk=~clk;
always #7 spi_clk=~spi_clk;

jtframe_capture_line #(
    .WIDTH  ( 512 ),
    .COLORW ( 5   )
) uut(
    .rst             ( rst             ),
    .clk             ( clk             ),
    .spi_clk         ( spi_clk         ),
    .start           ( start           ),
    .sample          ( sample          ),
    .finish          ( finish          ),
    .abort_all       ( abort_all       ),
    .pixel           ( pixel           ),
    .bank            ( bank            ),
    .spi_pixel_addr  ( spi_pixel_addr  ),
    .spi_pixel_data  ( spi_pixel_data  ),
    .busy            ( busy            ),
    .committed       ( committed       ),
    .committed_bank  ( committed_bank  ),
    .prefix          ( prefix          )
);

task check;
    input ok;
    input [255:0] msg;
    begin
        if(ok !== 1'b1) begin
            $display("FAIL %0s",msg);
            $finish;
        end
    end
endtask

task tick;
    begin @(posedge clk); #1; end
endtask

task capture_line;
    integer k;
    begin
        start=1; sample=1; pixel=pixels[0]; tick(); start=0;
        for(k=1;k<n;k=k+1) begin pixel=pixels[k]; tick(); end
        sample=0; finish=1; tick(); finish=0;
        waited=0;
        while(!committed && waited<10000) begin tick(); waited=waited+1; end
        check(committed,"line committed");
        check(committed_bank===bank,"published bank is known and correct");
        total=prefix==8'hff ? 2*n : prefix*2;
        check(prefix!==8'h00,"nonempty line has a nonzero prefix");
        check(total<=2*n,"encoder chose payload no larger than raw");
        for(k=0;k<total;k=k+1) begin
            spi_pixel_addr={bank,k[9:1]};
            @(posedge spi_clk); #1;
            bytes[k]=k[0] ? spi_pixel_data[15:8] : spi_pixel_data[7:0];
            check((^bytes[k])!==1'bx,"encoded byte is known");
        end
        tick();
    end
endtask

task check_payload;
    integer k;
    begin
        if(prefix==8'hff) begin
            check(total==2*n,"raw RGB555 has two bytes per pixel");
            for(k=0;k<n;k=k+1)
                check({bytes[2*k+1][7],bytes[2*k+1][6:0],bytes[2*k]}=={1'b0,pixels[k]},
                      "raw RGB555 pixel round trip");
        end else begin
            inpos=0; outpos=0;
            while(inpos<total) begin
                token={bytes[inpos+1],bytes[inpos]};
                inpos=inpos+2;
                check(token[15]===1'b0 || token[15]===1'b1,"known RGB555 token tag");
                if(token[15]) begin
                    check(inpos+1<total,"repeat token has a count word");
                    count_word={bytes[inpos+1],bytes[inpos]};
                    inpos=inpos+2;
                    run_length=count_word+2;
                    check(run_length<=n-outpos,"repeat fits remaining row");
                    for(k=0;k<run_length;k=k+1) begin
                        check(token[14:0]===pixels[outpos],"RGB555 repeat pixel");
                        outpos=outpos+1;
                    end
                end else begin
                    check(outpos<n,"literal fits remaining row");
                    check(token[14:0]===pixels[outpos],"RGB555 literal pixel");
                    outpos=outpos+1;
                end
            end
            check(outpos==n,"RLE decodes exact RGB555 pixel count");
        end
    end
endtask

initial begin
    repeat(4) tick(); rst=0; tick();

    // Opposite channel LSBs must remain distinct and therefore cannot merge.
    for(i=0;i<512;i=i+1) pixels[i]=(i[0] ? 15'h0001 : 15'h0000);
    n=17; bank=0; capture_line();
    check(prefix==8'hff,"length-two RGB555 repeats tie raw and use raw");
    check_payload();

    // A long run followed by one low-bit-distinct literal exercises token order.
    for(i=0;i<512;i=i+1) pixels[i]=(i<511 ? 15'h1234 : 15'h1235);
    n=512; bank=1; capture_line();
    check(prefix==3,"511-repeat plus literal is six-byte RLE");
    check_payload();

    // A raw maximum row spans all 512 words, including bytes 1023 and 1024.
    for(i=0;i<512;i=i+1) pixels[i]=(i*37+13)&15'h7fff;
    n=512; bank=0; capture_line();
    check(prefix==8'hff && total==1024,"maximum RGB555 raw row is 1024 bytes");
    check_payload();
    check((^bytes[1022])!==1'bx && (^bytes[1023])!==1'bx,
          "final raw words are known");

    for(i=0;i<512;i=i+1) pixels[i]=(i*53+7)&15'h7fff;
    n=511; bank=1; capture_line();
    check(prefix==8'hff && total==1022,"odd 511-pixel RGB555 raw row length");
    check_payload();

    // The 508-byte ceiling is inclusive, but selection remains strictly smaller.
    for(i=0;i<512;i=i+1) pixels[i]=i<252 ? (i/2)+1 : 15'h4321;
    n=255; bank=1; capture_line();
    check(prefix==254,"508-byte RLE boundary is accepted");
    check_payload();

    for(i=0;i<512;i=i+1) pixels[i]=((i/2)*19+1)&15'h7fff;
    n=256; bank=0; capture_line();
    check(prefix==8'hff,"RLE over 508 bytes falls back to raw");
    check_payload();

    $display("PASS"); $finish;
end
initial begin #5000000; $display("FAIL timeout"); $finish; end
endmodule
