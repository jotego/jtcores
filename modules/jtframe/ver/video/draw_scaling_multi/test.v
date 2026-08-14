`timescale 1ns / 1ps

module test;

localparam AW    = 10;
localparam CW    = 16;
localparam PW    =  4;
localparam ZW    = 12;
localparam ZI    =  6;
localparam HZONE = 1 << ZI;

reg             rst = 1'b1;
reg             clk = 1'b0;
reg             draw = 1'b0;
reg  [CW-1:0]   code = 0;
reg  [AW-1:0]   xpos = 0;
reg  [ 3:0]     ysub = 0;
reg  [ 1:0]     trunc = 0;
reg  [ZW-1:0]   hzoom = 0;
reg             hz_keep = 1'b0;
reg             hflip = 1'b0;
reg             vflip = 1'b0;
reg  [PW-5:0]   pal = 0;
reg  [31:0]     rom_data;

wire            busy, rom_cs, buf_we;
wire [CW+6:2]   rom_addr;
wire [AW-1:0]   buf_addr;
wire [PW-1:0]   buf_din;
wire            rom_ok = 1'b1;

reg  [ 3:0]     wr_pxl [0:1023];
reg  [AW-1:0]   wr_addr[0:1023];
integer         wr_count;
integer         errors;
integer         i, plane, pen, base;
string          msg;

`include "test_tasks.vh"

always #5 clk = ~clk;

always @* begin
    rom_data = 0;
    base = rom_addr[6] ? 8 : 0;
    for( i=0; i<8; i=i+1 ) begin
        pen = base+i;
        for( plane=0; plane<4; plane=plane+1 ) begin
            rom_data[plane*8+i] = pen[plane];
        end
    end
end

always @(posedge clk) if( !rst && buf_we ) begin
    wr_pxl [wr_count] <= buf_din;
    wr_addr[wr_count] <= buf_addr;
    wr_count <= wr_count+1;
end

task reset_uut;
begin
    @(negedge clk);
    rst = 1'b1;
    draw = 1'b0;
    repeat(4) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;
    repeat(2) @(posedge clk);
end
endtask

task draw_object;
    input [ZW-1:0] zoom;
    integer tile;
begin
    for( tile=0; tile<4; tile=tile+1 ) begin
        @(negedge clk);
        hzoom   = zoom;
        xpos    = tile*16;
        hz_keep = tile != 0;
        draw    = 1'b1;
        @(negedge clk);
        draw = 1'b0;
        wait( busy );
        wait( !busy );
    end
    @(negedge clk);
end
endtask

task check;
    input condition;
    input string text;
begin
    if( !condition ) begin
        $display("FAIL: %s", text);
        errors = errors+1;
    end
end
endtask

task check_integer;
    input integer scale;
    input [ZW-1:0] zoom;
    integer expected;
begin
    reset_uut();
    wr_count = 0;
    draw_object(zoom);
    expected = (64*HZONE+zoom-1)/zoom;
    msg = $sformatf("%0dx four-tile object has %0d writes, expected %0d", scale,
        wr_count, expected);
    check(wr_count == expected, msg);
    for( i=0; i<expected && i<wr_count; i=i+1 ) begin
        msg = $sformatf("%0dx four-tile object write %0d has address %0d, expected %0d",
            scale, i, wr_addr[i], i);
        check(wr_addr[i] == i, msg);
        msg = $sformatf("%0dx four-tile object write %0d has pen %0d, expected %0d",
            scale, i, wr_pxl[i], (i*zoom/HZONE)&4'hf);
        check(wr_pxl[i] == ((i*zoom/HZONE)&4'hf), msg);
    end
end
endtask

task check_fractional;
    input integer numerator;
    input integer denominator;
    input integer expected;
    input [ZW-1:0] zoom;
    integer quantized;
begin
    reset_uut();
    wr_count = 0;
    draw_object(zoom);
    quantized = (64*HZONE+zoom-1)/zoom;
    msg = $sformatf("%0d/%0dx four-tile object has %0d writes, expected %0d",
        numerator, denominator, wr_count, quantized);
    check(wr_count == quantized, msg);
    for( i=0; i<quantized && i<wr_count; i=i+1 ) begin
        msg = $sformatf("%0d/%0dx four-tile object write %0d has address %0d, expected %0d",
            numerator, denominator, i, wr_addr[i], i);
        check(wr_addr[i] == i, msg);
        msg = $sformatf("%0d/%0dx four-tile object write %0d has pen %0d, expected %0d",
            numerator, denominator, i, wr_pxl[i], (i*zoom/HZONE)&4'hf);
        check(wr_pxl[i] == ((i*zoom/HZONE)&4'hf), msg);
    end
end
endtask

initial begin
    errors = 0;
    check_integer( 2, HZONE/ 2);
    check_integer( 3, HZONE/ 3);
    check_integer( 4, HZONE/ 4);
    check_integer( 5, HZONE/ 5);
    check_integer( 6, HZONE/ 6);
    check_integer( 7, HZONE/ 7);
    check_integer( 8, HZONE/ 8);
    check_integer( 9, HZONE/ 9);
    check_integer(10, HZONE/10);

    check_fractional(5, 4,  80, HZONE*4/5);
    check_fractional(3, 2,  96, HZONE*2/3);
    check_fractional(5, 2, 160, HZONE*2/5);
    if( errors == 0 ) pass();
    else fail();
end

jtframe_draw #(
    .AW       ( AW       ),
    .CW       ( CW       ),
    .PW       ( PW       ),
    .ZW       ( ZW       ),
    .ZI       ( ZI       ),
    .ZENLARGE( 1        )
) uut (
    .rst      ( rst      ),
    .clk      ( clk      ),
    .draw     ( draw     ),
    .busy     ( busy     ),
    .code     ( code     ),
    .xpos     ( xpos     ),
    .ysub     ( ysub     ),
    .trunc    ( trunc    ),
    .hzoom    ( hzoom    ),
    .hz_keep  ( hz_keep  ),
    .hflip    ( hflip    ),
    .vflip    ( vflip    ),
    .pal      ( pal      ),
    .rom_addr ( rom_addr ),
    .rom_cs   ( rom_cs   ),
    .rom_ok   ( rom_ok   ),
    .rom_data ( rom_data ),
    .buf_addr ( buf_addr ),
    .buf_we   ( buf_we   ),
    .buf_din  ( buf_din  )
);

endmodule
