/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0, spi_clk=0, rst=1, start=0, sample=0, finish=0, bank=0, abort_all=0;
reg [11:0] pixel=0;
reg [9:0] spi_pixel_addr=0;
wire [15:0] spi_pixel_data;
wire busy,committed,committed_bank;
wire [7:0] prefix;
reg [11:0] pixels[0:511];
reg [7:0] bytes[0:767];
integer i,n,total,waited;

always #5 clk=~clk;
always #7 spi_clk=~spi_clk;

jtframe_capture_line #(
    .WIDTH ( 512 )
) uut(
    .rst            ( rst            ),
    .clk            ( clk            ),
    .spi_clk        ( spi_clk        ),
    .start          ( start          ),
    .sample         ( sample         ),
    .finish         ( finish         ),
    .abort_all      ( abort_all      ),
    .pixel          ( pixel          ),
    .bank           ( bank           ),
    .spi_pixel_addr ( spi_pixel_addr ),
    .spi_pixel_data ( spi_pixel_data ),
    .busy           ( busy           ),
    .committed      ( committed      ),
    .committed_bank ( committed_bank ),
    .prefix         ( prefix         )
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

task read_bytes;
    integer k;
    begin
        for(k=0;k<total;k=k+1) begin
            spi_pixel_addr={bank,k[9:1]};
            @(posedge spi_clk); #1;
            bytes[k]=k[0] ? spi_pixel_data[15:8] : spi_pixel_data[7:0];
        end
        for(k=0;k<total;k=k+1)
            check((^bytes[k]) !== 1'bx,"encoded byte is known");
    end
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
        total=prefix==8'hff ? (n*3+1)/2 : prefix*2;
        check(prefix!==8'h00,"nonempty line has a nonzero prefix");
        check(total<=(n*3+1)/2,"encoder chose payload no larger than raw");
        read_bytes();
        tick();
    end
endtask

integer at,p;
reg [15:0] wordval;
reg [11:0] decoded;
integer runs;
initial begin
    for(i=0;i<512;i=i+1) pixels[i]=12'habc;
    repeat(4) tick(); rst=0; tick();
    n=17; bank=0; capture_line();
    check(prefix==2,"constant 17 pixel line uses run plus extension words");
    check(bytes[0]==8'hbc && bytes[1]==8'hfa && bytes[2]==1 && bytes[3]==0,
          "RLE payload format");

    for(i=0;i<17;i=i+1) pixels[i]=12'h123+i;
    n=17; bank=1; capture_line();
    check(prefix==8'hff,"noncompressible odd line uses raw prefix");
    check(total==26,"odd 17 pixel raw length");
    at=0;
    for(i=0;i<17;i=i+1) begin
        if(i[0]) decoded={bytes[at][3:0],bytes[at+1]};
        else decoded={bytes[at],bytes[at+1][7:4]};
        check(decoded==pixels[i],"raw RGB444 pixel roundtrip");
        at=at+(i[0] ? 2 : 1);
    end
    check(bytes[25][3:0]==0,"odd-width low padding nibble is zero");

    for(i=0;i<512;i=i+1) pixels[i]=i[11:0];
    n=512; bank=0; capture_line();
    check(prefix==8'hff && total==768,"maximum 512-pixel line uses 768 raw bytes");
    at=0;
    for(i=0;i<512;i=i+1) begin
        decoded=i[0] ? {bytes[at][3:0],bytes[at+1]} : {bytes[at],bytes[at+1][7:4]};
        check(decoded==pixels[i],"maximum-width raw RGB444 roundtrip");
        at=at+(i[0] ? 2 : 1);
    end

    n=257; bank=1; capture_line();
    check(prefix==8'hff && total==386,"odd 257-pixel line length");
    check(bytes[385][3:0]==0,"257-pixel final padding nibble is zero");
    at=0;
    for(i=0;i<257;i=i+1) begin
        decoded=i[0] ? {bytes[at][3:0],bytes[at+1]} : {bytes[at],bytes[at+1][7:4]};
        check(decoded==pixels[i],"257-pixel raw RGB444 roundtrip on second BRAM bank");
        at=at+(i[0] ? 2 : 1);
    end
    $display("PASS"); $finish;
end
initial begin #2000000; $display("FAIL timeout"); $finish; end
endmodule
