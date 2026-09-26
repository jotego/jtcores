// Draws two sprite scenes through jtwardnr_obj and compares every visible
// pixel with a reference drawn the way MAME does: screen x = (x>>7)-32,
// screen y = (y>>7)-16, entry 0 on top. The scenes cover
//  - 62 overlapping sprites on the same lines, in both x directions
//  - sprites cut by each edge of the screen
//  - a sprite with priority 0 and one with y = 0x100, which are not drawn
//  - object RAM rewritten during the frame, which must wait for the next
//    vertical blank
// The graphics ROM answers ROM_LAT clocks after the address changes. With 62
// sprites on a line the test passes up to ROM_LAT=12 and fails from 13.
`ifndef ROM_LAT
`define ROM_LAT 2
`endif

module test;

reg         clk = 0, rst = 1, pxl_cen = 0;
reg  [ 2:0] cdiv = 0;
reg  [15:0] objram[0:2047], objbuf[0:2047];
reg  [15:0] ram_dout, scan_dout;
reg  [15:0] e_code[0:511], e_attr[0:511], e_x[0:511], e_y[0:511];
reg  [11:0] cap[0:262143], exp[0:76799];
reg  [15:0] rom_al;
reg  [31:0] rom_data;
reg  [ 7:0] rom_cnt;
reg         rom_rdy = 0, LVBL_l, swapped = 0;
wire [ 8:0] hdump, vdump, vrender, vrender1;
wire [11:1] ram_addr, cpy_addr, scan_addr;
wire [ 1:0] cpy_we;
wire [15:0] rom_addr;
wire [11:0] pxl;
wire        rom_cs, rom_ok, LHBL, LVBL, HS, VS, Hinit, Vinit;
integer     k, copies = 0;

function [3:0] pen(input [10:0] code, input [3:0] r, input [3:0] c);
    pen = c*3 + r*5 + code;
endfunction

// {code, row, half}: plane 0 in the top byte, leftmost pixel in each MSB
function [31:0] rom_word(input [15:0] a);
    integer i, k;
    reg [3:0] c, p;
    begin
        rom_word = 0;
        for( i=0; i<8; i=i+1 ) begin
            c = a[0] ? 4'd8 + i[3:0] : i[3:0];
            p = pen(a[15:5], a[4:1], c);
            for( k=0; k<4; k=k+1 ) rom_word[31-8*k-i] = p[k];
        end
    end
endfunction

task set_entry(input integer e, input integer code, input integer colour,
               input integer prio, input integer sx, input integer sy);
    begin
        e_code[e] = code;
        e_attr[e] = { 4'd0, prio[1:0], 4'd0, colour[5:0] };
        e_x[e]    = { sx[8:0], 7'd0 };
        e_y[e]    = { sy[8:0], 7'd0 };
    end
endtask

// scene 1 moves everything by (7,3) and changes the colours
task scene(input integer s);
    integer e, dx, dy, cx;
    begin
        dx = s ? 7 : 0;
        dy = s ? 3 : 0;
        cx = s ? 'h15 : 0;
        for( e=0; e<512; e=e+1 ) set_entry(e, 0, 0, 0, 0, 'h100);
        for( e=0; e<64; e=e+1 )
            set_entry(e, 100+e, e^cx, 1+e%3, 24+5*e+dx, 56+dy);
        set_entry(2, 102, 2^cx, 0, 34+dx, 56+dy);
        set_entry(3, 103, 3^cx, 3, 39+dx, 'h100);
        for( e=100; e<164; e=e+1 )
            set_entry(e, e, (e-100)^cx, 3, 339-5*(e-100)+dx, 136+dy);
        set_entry(300,   7,  9^cx, 2,  32+dx, 216+dy);
        set_entry(301,   8, 10^cx, 2, 344+dx, 216+dy);
        set_entry(400,   9, 11^cx, 1, 132+dx,   8+dy);
        set_entry(401,  10, 12^cx, 1, 232+dx, 248+dy);
        set_entry(511, 511, 13^cx, 3, 182+dx, 166+dy);
    end
endtask

task write_ram;
    integer e;
    for( e=0; e<512; e=e+1 ) begin
        objram[e*4]   = e_code[e];
        objram[e*4+1] = e_attr[e];
        objram[e*4+2] = e_x[e];
        objram[e*4+3] = e_y[e];
    end
endtask

task render;
    integer e, r, c, row, col;
    reg [3:0] p;
    begin
        for( r=0; r<76800; r=r+1 ) exp[r] = 0;
        for( e=511; e>=0; e=e-1 ) begin
            if( e_attr[e][11:10] != 0 && e_y[e][15:7] != 'h100 ) begin
                for( r=0; r<16; r=r+1 ) for( c=0; c<16; c=c+1 ) begin
                    row = (e_y[e][15:7] + 512 - 16 + r) % 512;
                    col = (e_x[e][15:7] + 512 - 32 + c) % 512;
                    p   = pen(e_code[e][10:0], r[3:0], c[3:0]);
                    if( row < 240 && col < 320 && p != 0 )
                        exp[row*320+col] = { e_attr[e][11:10], e_attr[e][5:0], p };
                end
            end
        end
    end
endtask

// the pixel for screen (col,row) comes out while hdump=col and vdump=row
function integer mismatches(input integer show);
    integer r, c, shown;
    reg [11:0] got;
    begin
        mismatches = 0;
        shown      = 0;
        for( r=0; r<240; r=r+1 ) for( c=0; c<320; c=c+1 ) begin
            got = cap[r*512+c];
            if( got !== exp[r*320+c] ) begin
                mismatches = mismatches + 1;
                if( shown < show ) begin
                    $display("row %0d col %0d: got %03x, want %03x", r, c, got, exp[r*320+c]);
                    shown = shown + 1;
                end
            end
        end
    end
endfunction

initial begin
    scene(0);
    write_ram;
    for( k=0; k<2048; k=k+1 ) objbuf[k] = 0;
    repeat(100) @(posedge clk);
    rst = 0;
end

always #10 clk = ~clk;

always @(posedge clk) begin
    cdiv    <= cdiv == 3'd6 ? 3'd0 : cdiv + 3'd1;
    pxl_cen <= cdiv == 3'd6;
end

// object RAM, the copy made during blanking, and the graphics ROM
assign rom_ok = rom_cs && rom_rdy && rom_addr === rom_al;

always @(posedge clk) begin
    ram_dout  <= objram[ram_addr];
    scan_dout <= objbuf[scan_addr];
    if( cpy_we[0] ) objbuf[cpy_addr] <= ram_dout;
    if( !rom_cs || rom_addr !== rom_al ) begin
        rom_al  <= rom_addr;
        rom_cnt <= `ROM_LAT;
        rom_rdy <= 0;
    end else if( rom_cnt != 0 ) begin
        rom_cnt <= rom_cnt - 8'd1;
    end else begin
        rom_rdy  <= 1;
        rom_data <= rom_word(rom_al);
    end
end

always @(posedge clk) begin
    LVBL_l <= LVBL;
    if( pxl_cen ) cap[{vdump, hdump}] <= pxl;
    if( !rst && LVBL_l && !LVBL ) copies = copies + 1;
    // copy 0 holds nothing, copy 1 scene 0, copy 2 scene 1. Scene 1 is
    // written while scene 0 is on screen.
    if( pxl_cen && copies == 1 && vdump == 9'd100 && !swapped ) begin
        scene(1);
        write_ram;
        swapped = 1;
    end
    if( pxl_cen && vdump == 9'd260 && hdump == 9'd0 && copies >= 2 ) begin
        scene(copies - 2);
        render;
        if( mismatches(8) != 0 ) begin
            $display("FAIL: scene %0d, %0d pixels differ", copies - 2, mismatches(0));
            $finish;
        end
        if( copies == 3 ) begin
            $display("PASS");
            $finish;
        end
    end
end

jtframe_vtimer #(
    .HB_START   ( 9'd319            ),
    .HB_END     ( 9'd445            ),
    .HCNT_END   ( 9'd445            ),
    .HS_START   ( 9'd352            ),
    .HS_END     ( 9'd382            ),
    .VB_START   ( 9'd239            ),
    .VB_END     ( 9'd285            ),
    .VCNT_END   ( 9'd285            ),
    .VS_START   ( 9'd248            ),
    .VS_END     ( 9'd256            )
) u_vtimer(
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),
    .vdump      ( vdump             ),
    .vrender    ( vrender           ),
    .vrender1   ( vrender1          ),
    .H          ( hdump             ),
    .Hinit      ( Hinit             ),
    .Vinit      ( Vinit             ),
    .LHBL       ( LHBL              ),
    .LVBL       ( LVBL              ),
    .HS         ( HS                ),
    .VS         ( VS                )
);

jtwardnr_obj uut(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),
    .hs         ( HS                ),
    .LVBL       ( LVBL              ),
    .hdump      ( hdump             ),
    .vrender    ( vrender           ),
    .ram_addr   ( ram_addr          ),
    .ram_dout   ( ram_dout          ),
    .cpy_addr   ( cpy_addr          ),
    .cpy_we     ( cpy_we            ),
    .scan_addr  ( scan_addr         ),
    .scan_dout  ( scan_dout         ),
    .rom_addr   ( rom_addr          ),
    .rom_data   ( rom_data          ),
    .rom_cs     ( rom_cs            ),
    .rom_ok     ( rom_ok            ),
    .pxl        ( pxl               )
);

endmodule
