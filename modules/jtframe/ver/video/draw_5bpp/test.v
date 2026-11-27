`timescale 1ns/1ps

module test;

reg clk = 0, rst = 1, draw = 0, hflip = 0, overlay = 0;
reg hs = 0, pxl_cen = 0;
reg [8:0] hdump = 0;
wire [1:0] busy;
wire [10:0] pxl[2];
reg line_blank = 1, buffer_we = 0, buffer_rd = 0;
reg [2:0] buffer_wr_addr = 0, buffer_rd_addr = 0;
reg [4:0] buffer_din = 0;
wire [4:0] buffer_dout[2];

`include "test_tasks.vh"

always #5 clk = ~clk;

function [4:0] pen_for(input [3:0] x, input layer);
    if (layer) pen_for = x==8 ? 5'd16 : 5'd0;
    else pen_for = x==0 ? 5'd16 : {1'b0,x}+5'd1;
endfunction

genvar mode, pixel, plane;
generate
    for (mode=0; mode<2; mode=mode+1) begin : gen_draw
        wire [18:2] rom_addr;
        wire [39:0] rom_data;
        for (pixel=0; pixel<8; pixel=pixel+1) begin : gen_pixel
            wire [4:0] pen = pen_for({rom_addr[6],pixel[2:0]}, rom_addr[7]);
            for (plane=0; plane<5; plane=plane+1) begin : gen_plane
                assign rom_data[mode ? 5*pixel+plane : 8*plane+pixel] = pen[plane];
            end
        end

        jtframe_objdraw #(
            .PW     ( 11   ),
            .BPP    ( 5    ),
            .HFIX   ( 0    ),
            .PACKED ( mode )
        ) uut(
            .rst      ( rst              ),
            .clk      ( clk              ),
            .pxl_cen  ( pxl_cen          ),
            .hs       ( hs               ),
            .flip     ( 1'b0             ),
            .hdump    ( hdump            ),
            .draw     ( draw             ),
            .busy     ( busy[mode]       ),
            .code     ( {11'd0,overlay}  ),
            .xpos     ( 9'd12            ),
            .ysub     ( 4'd3             ),
            .hzoom    ( 6'd0             ),
            .hz_keep  ( 1'b0             ),
            .hflip    ( hflip            ),
            .vflip    ( 1'b0             ),
            .pal      ( 6'h29            ),
            .rom_addr ( rom_addr         ),
            .rom_cs   (                  ),
            .rom_ok   ( 1'b1             ),
            .rom_data ( rom_data         ),
            .pxl      ( pxl[mode]        )
        );

        jtframe_obj_buffer #(
            .AW       ( 3    ),
            .DW       ( 5    ),
            .ALPHAW   ( 5    ),
            .ALPHA    ( 0    ),
            .LATCH_RD ( mode )
        ) u_buffer(
            .clk     ( clk             ),
            .LHBL    ( line_blank      ),
            .flip    ( 1'b0            ),
            .wr_data ( buffer_din      ),
            .wr_addr ( buffer_wr_addr  ),
            .we      ( buffer_we       ),
            .rd_addr ( buffer_rd_addr  ),
            .rd      ( buffer_rd       ),
            .rd_data ( buffer_dout[mode] )
        );
    end
endgenerate

task draw_tile(input layer, input reverse);
    @(negedge clk);
    overlay = layer;
    hflip = reverse;
    draw = 1;
    @(negedge clk);
    draw = 0;
    wait(busy==0);
    repeat(2) @(negedge clk);
endtask

task check_line(input reverse, input with_overlay);
    integer x;
    reg [4:0] expected;
    hs = 1;
    @(negedge clk);
    hs = 0;
    for (x=0; x<16; x=x+1) begin
        hdump = 9'd12 + x[8:0];
        pxl_cen = 1;
        @(negedge clk);
        pxl_cen = 0;
        repeat(3) @(negedge clk);
        expected = with_overlay && x==8 ? 5'd16 : pen_for(x[3:0] ^ {4{reverse}}, 1'b0);
        assert_msg(pxl[0] === {6'h29,expected}, $sformatf("Planar pixel %0d",x));
        assert_msg(pxl[1] === pxl[0], $sformatf("Packed pixel %0d",x));
    end
endtask

task check_buffer_read_modes;
    buffer_we = 1;
    buffer_wr_addr = 3'd3;
    buffer_din = 5'd16;
    @(negedge clk);
    buffer_wr_addr = 3'd4;
    buffer_din = 5'd17;
    @(negedge clk);
    buffer_we = 0;
    line_blank = 0;
    buffer_rd_addr = 3'd3;
    repeat(2) @(negedge clk);
    assert_msg(buffer_dout[0] === 5'd16, "Direct read before erase");

    buffer_rd = 1;
    @(negedge clk);
    buffer_rd = 0;
    repeat(3) @(negedge clk);
    assert_msg(buffer_dout[0] === 5'd0, "Direct read after erase");
    assert_msg(buffer_dout[1] === 5'd16, "Latched read holds the erased pixel");

    buffer_rd_addr = 3'd4;
    @(negedge clk);
    assert_msg(buffer_dout[0] === 5'd17, "Direct read follows the address");
    assert_msg(buffer_dout[1] === 5'd16, "Latched read holds until the next erase");
endtask

initial begin
    repeat(3) @(negedge clk);
    rst = 0;
    draw_tile(0,0);
    draw_tile(1,0);
    check_line(0,1);
    draw_tile(0,1);
    check_line(1,0);
    check_buffer_read_modes();
    pass();
end

initial begin
    #10000;
    fail();
end

endmodule
