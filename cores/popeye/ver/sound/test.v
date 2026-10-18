`timescale 1ns/1ps

module test;

reg        rst, reset_n, clk, psg_cen, bdir, bc1;
reg  [7:0] din;
reg  [3:0] sw1;
reg  [7:0] sw2;
reg  [1:0] cpyr;
wire [7:0] dout;
wire [9:0] psga, psgb, psgc;
wire       rv;
integer    errors=0, checks=0, cencnt=0, i, n, f, k;
reg  [7:0] rd, wv, exp_rd;
reg  [7:0] shadow[0:15];

initial begin
    clk = 0;
    forever #10.417 clk = ~clk;
end

always @(posedge clk) begin
    cencnt  <= cencnt==23 ? 0 : cencnt+1;
    psg_cen <= cencnt==0;
end

task check(input [7:0] got, input [7:0] want, input [255:0] what);
begin
    checks = checks+1;
    if( got !== want ) begin
        errors = errors+1;
        $display("ERROR %0s: got %02X expected %02X", what, got, want);
    end
end
endtask

task idle(input integer cycles);
    repeat(cycles) @(posedge clk);
endtask

task ay_addr(input [3:0] a);
begin
    @(posedge clk); {bdir,bc1} <= 2'b11; din <= {4'd0,a};
    idle(12);
    {bdir,bc1} <= 2'b00; din <= 8'hzz;
    idle(12);
end
endtask

task ay_data(input [7:0] d);
begin
    @(posedge clk); {bdir,bc1} <= 2'b10; din <= d;
    idle(12);
    {bdir,bc1} <= 2'b00; din <= 8'hzz;
    idle(12);
end
endtask

task ay_write(input [3:0] a, input [7:0] d);
begin
    ay_addr(a);
    ay_data(d);
    shadow[a] = d;
end
endtask

task ay_read(input [3:0] a, output [7:0] d);
begin
    ay_addr(a);
    @(posedge clk); {bdir,bc1} <= 2'b01;
    idle(12);
    d = dout;
    {bdir,bc1} <= 2'b00;
    idle(12);
end
endtask

function [7:0] mask(input [3:0] a);
    case(a)
        1,3,5,13: mask = 8'h0f;
        6,8,9,10: mask = 8'h1f;
        default:  mask = 8'hff;
    endcase
endfunction

function [7:0] mame_dsw0(input [3:0] s1, input [7:0] s2, input [7:0] portb, input [7:0] copyright);
    integer dswbit;
begin
    dswbit    = (portb & 8'h0e) >> 1;
    mame_dsw0 = {s2[dswbit], 7'd0} | copyright | 8'h10 | {4'd0, s1};
end
endfunction

function board_y(input [7:0] s2, input [7:0] iob_pins);
    reg pin12, pin11, pin10, ls_a, ls_b, ls_c;
    reg sw_i, sw_j, sw_k, sw_l, sw_m, sw_n, sw_o, sw_p;
begin
    pin12 = iob_pins[1];
    pin11 = iob_pins[2];
    pin10 = iob_pins[3];
    ls_a  = pin12;
    ls_b  = pin11;
    ls_c  = pin10;
    {sw_p, sw_o, sw_n, sw_m, sw_l, sw_k, sw_j, sw_i} = s2;
    case( {ls_c, ls_b, ls_a} )
        3'b000: board_y = sw_i;
        3'b001: board_y = sw_j;
        3'b010: board_y = sw_k;
        3'b011: board_y = sw_l;
        3'b100: board_y = sw_m;
        3'b101: board_y = sw_n;
        3'b110: board_y = sw_o;
        3'b111: board_y = sw_p;
    endcase
end
endfunction

function [7:0] board_ioa(input [3:0] s1, input [7:0] s2, input [7:0] iob_pins, input r84_link, input r85_link);
    reg pin14, pin15, pin16, pin17, pin18, pin19, pin20, pin21;
begin
    pin21 = s1[0];
    pin20 = s1[1];
    pin19 = s1[2];
    pin18 = s1[3];
    pin17 = 1'b1;
    pin16 = r84_link;
    pin15 = r85_link;
    pin14 = board_y(s2, iob_pins);
    board_ioa = {pin14, pin15, pin16, pin17, pin18, pin19, pin20, pin21};
end
endfunction

task measure_half(input integer ch, output integer len);
    integer t0;
    reg [7:0] v0;
begin
    v0 = ch==0 ? psga : ch==1 ? psgb : psgc;
    while( (ch==0 ? psga : ch==1 ? psgb : psgc) == v0 ) @(posedge clk);
    v0 = ch==0 ? psga : ch==1 ? psgb : psgc;
    t0 = $time;
    while( (ch==0 ? psga : ch==1 ? psgb : psgc) == v0 ) @(posedge clk);
    len = ($time-t0)/20.834;
end
endtask

integer hl, pk, other;

jtpopeye_sound u_dut(
    .rst    ( rst   ),
    .reset_n( reset_n ),
    .clk    ( clk   ),
    .psg_cen( psg_cen ),
    .bdir   ( bdir  ),
    .bc1    ( bc1   ),
    .din    ( din   ),
    .dout   ( dout  ),
    .sw1    ( sw1   ),
    .sw2    ( sw2   ),
    .cpyr   ( cpyr  ),
    .rv     ( rv    ),
    .psga   ( psga  ),
    .psgb   ( psgb  ),
    .psgc   ( psgc  )
);

initial begin
    rst = 1; reset_n = 1; cpyr = 2'b00; bdir = 0; bc1 = 0; din = 0; sw1 = 4'ha; sw2 = 8'h5c; psg_cen = 0;
    idle(5);
    check({7'd0,rv}, 8'd1, "rv during reset");
    idle(50);
    rst = 0;
    idle(5);
    check({7'd0,rv}, 8'd1, "rv after reset, IOB input mode pulled up");

    for( i=0; i<16; i=i+1 ) shadow[i] = 0;
    for( i=0; i<14; i=i+1 ) begin
        ay_read(i[3:0], rd);
        check(rd, 8'd0, "register after reset");
    end

    ay_read(4'he, rd);
    check(rd, board_ioa(sw1, sw2, 8'hff, cpyr[0], cpyr[1]), "IOA after reset, IOB pulled up");

    for( k=0; k<3; k=k+1 ) begin
        for( i=0; i<14; i=i+1 ) begin
            wv = $random;
            if( i==7 ) wv = 8'h3f;
            ay_write(i[3:0], wv);
        end
        for( i=0; i<14; i=i+1 ) begin
            ay_read(i[3:0], rd);
            check(rd, shadow[i] & mask(i[3:0]), "register read back");
        end
    end

    ay_addr(4'h3);
    @(posedge clk); {bdir,bc1} <= 2'b11; din <= 8'h12;
    idle(12); {bdir,bc1} <= 2'b00; idle(12);
    ay_data(8'h99);
    ay_read(4'h3, rd);
    check(rd, shadow[3] & 8'h0f, "address with upper nibble set is ignored");

    ay_write(7, 8'hbf);
    for( n=0; n<8; n=n+1 ) for( f=0; f<2; f=f+1 ) for( k=0; k<256; k=k+1 ) begin
        sw2 = k[7:0];
        sw1 = $random;
        cpyr = k[1:0]^n[1:0];
        ay_write(15, {4'hf^k[3:0],n[2:0],f[0]});
        idle(2);
        check({7'd0,rv}, {7'd0,f[0]}, "rv follows IOB0");
        ay_read(14, rd);
        check(rd, board_ioa(sw1, sw2, {4'hf^k[3:0],n[2:0],f[0]}, cpyr[0], cpyr[1]), "IOA against the P35 pin table");
        check(rd, mame_dsw0(sw1, sw2, {4'hf^k[3:0],n[2:0],f[0]}, {1'b0,cpyr,5'd0}), "IOA against MAME dswbit cross-check");
        ay_read(15, rd);
        check(rd, {4'hf^k[3:0],n[2:0],f[0]}, "IOB read back");
    end

    ay_write(15, 8'h01);
    @(posedge clk); {bdir,bc1} <= 2'b11; din <= 8'h0f;
    idle(12); {bdir,bc1} <= 2'b00; idle(1);
    @(posedge clk); {bdir,bc1} <= 2'b10; din <= 8'h00;
    idle(1);
    k = 0;
    while( rv !== 1'b0 ) begin @(posedge clk); k = k+1; end
    {bdir,bc1} <= 2'b00;
    if( k>3 ) begin errors=errors+1; $display("ERROR flip latency %0d clk", k); end
    $display("rv latency after the write strobe: %0d clk (independent of psg_cen)", k);

    sw1 = 4'h5; sw2 = 8'hff; cpyr = 2'b00;
    ay_write(7, 8'hff);
    ay_write(14, 8'h3c);
    ay_read(14, rd);
    check(rd, 8'h3c & board_ioa(sw1, sw2, 8'h00, cpyr[0], cpyr[1]), "IOA output mode reads pins (latch AND inputs)");

    ay_write(15, 8'h0e);
    ay_write(7, 8'h3f);
    idle(3);
    check({7'd0,rv}, 8'd1, "IOB back to input: pulled up, rv=1");
    ay_read(14, rd);
    check(rd, board_ioa(sw1, sw2, 8'hff, cpyr[0], cpyr[1]), "IOA input mode again");
    for( k=0; k<4; k=k+1 ) begin
        cpyr = k[1:0];
        ay_read(14, rd);
        case( k )
            0: check(rd & 8'h60, 8'h00, "copyright 00 = board links R84/R85 fitted");
            1: check(rd & 8'h60, 8'h20, "copyright 01 = MAME 0x20");
            2: check(rd & 8'h60, 8'h40, "copyright 10 = MAME 0x40");
            3: check(rd & 8'h60, 8'h60, "copyright 11 = MAME 0x60");
        endcase
    end
    cpyr = 2'b00;

    ay_write(7, 8'hbf);
    ay_write(15, 8'h0a);
    ay_write(8, 8'h0c);
    idle(3);
    check({7'd0,rv}, 8'd0, "rv=0 before the board reset");
    @(posedge clk) reset_n <= 0;
    idle(3);
    check({7'd0,rv}, 8'd1, "rv=1 while /RESET is low");
    idle(40);
    @(posedge clk) reset_n <= 1;
    idle(3);
    check({7'd0,rv}, 8'd1, "rv=1 after /RESET, IOB back to input");
    ay_read(7, rd);
    check(rd, 8'd0, "/RESET clears the mixer register");
    ay_read(8, rd);
    check(rd, 8'd0, "/RESET clears the volume register");
    ay_read(14, rd);
    check(rd, board_ioa(sw1, sw2, 8'hff, cpyr[0], cpyr[1]), "IOA after /RESET");

    ay_write(0, 8'd100);
    ay_write(1, 8'd0);
    ay_write(2, 8'd50);
    ay_write(3, 8'd0);
    ay_write(4, 8'd25);
    ay_write(5, 8'd0);
    ay_write(8, 8'h0f);
    ay_write(9, 8'h00);
    ay_write(10,8'h00);
    ay_write(7, 8'h3e);
`ifndef NOSOUND
    measure_half(0, hl);
    measure_half(0, hl);
    $display("channel A half period %0d clk (expected %0d)", hl, 8*100*24);
    if( hl < 8*100*24-30 || hl > 8*100*24+30 ) begin errors=errors+1; $display("ERROR channel A period"); end
    pk = 0; other = 0;
    repeat(40000) begin
        @(posedge clk);
        if( psga > pk ) pk = psga;
        if( psgb != 0 || psgc != 0 ) other = 1;
    end
    $display("channel A peak %0d, B/C silent=%0d", pk, !other);
    if( pk==0 || other ) begin errors=errors+1; $display("ERROR channel A level/isolation"); end

    ay_write(8, 8'h00);
    ay_write(9, 8'h0f);
    ay_write(7, 8'h3d);
    measure_half(1, hl);
    measure_half(1, hl);
    $display("channel B half period %0d clk (expected %0d)", hl, 8*50*24);
    if( hl < 8*50*24-30 || hl > 8*50*24+30 ) begin errors=errors+1; $display("ERROR channel B period"); end

    ay_write(9, 8'h00);
    ay_write(10,8'h0f);
    ay_write(7, 8'h3b);
    measure_half(2, hl);
    measure_half(2, hl);
    $display("channel C half period %0d clk (expected %0d)", hl, 8*25*24);
    if( hl < 8*25*24-30 || hl > 8*25*24+30 ) begin errors=errors+1; $display("ERROR channel C period"); end
`else
    ay_write(9, 8'h0f);
    ay_write(10,8'h0f);
    ay_write(7, 8'h38);
    other = 0;
    repeat(100000) begin
        @(posedge clk);
        if( psga != 0 || psgb != 0 || psgc != 0 ) other = 1;
    end
    $display("NOSOUND: channels silent=%0d with three tones playing", !other);
    if( other ) begin errors=errors+1; $display("ERROR NOSOUND channels not zero"); end
`endif

    rst = 1;
    idle(30);
    check({7'd0,rv}, 8'd1, "rv in second reset");
    check(psga|psgb|psgc, 8'd0, "channels cleared by reset");
    rst = 0;

    $display("%0d checks, %0d errors", checks, errors);
    if( errors==0 ) $display("PASS"); else $display("FAIL");
    $finish;
end

endmodule
