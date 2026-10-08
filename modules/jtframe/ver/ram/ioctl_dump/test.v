`timescale 1ns/1ps

module test;

wire clk, rst;
wire [ 7:0] din0_mx, din3_mx, din4_mx, din5_mx;
wire [15:0] din1_mx;
wire [31:0] din2_mx;
wire        we0, we3, we4, we5;
wire [ 1:0] we1;
wire [ 3:0] we2;
wire        we0_mx, we3_mx, we4_mx, we5_mx;
wire [ 1:0] we1_mx;
wire [ 3:0] we2_mx;
reg        ioctl_ram, ioctl_wr;
reg  [7:0] ioctl_dout,


           dout0, dout3, dout4, dout5,
           din0, din3, din4, din5;
reg  [15:0] dout1, din1;
reg  [31:0] dout2, din2;
wire [7:0] ioctl_aux;
wire [7:0] ioctl_din;

reg  [ 9:0] addr0;
wire [ 9:0] addr0_mx;
reg  [11:1] addr1;
wire [11:1] addr1_mx;
reg  [12:2] addr2;
wire [12:2] addr2_mx;
reg  [23:0] ioctl_addr;

assign we0 = 1'b0;
assign we1 = 2'd0;
assign we2 = 4'd0;
assign we3 = 1'b0;
assign we4 = 1'b0;
assign we5 = 1'b0;
assign ioctl_aux = 8'h5a;

`include "test_tasks.vh"
function check_sel(input [23:0]a0,a1, input sel); begin
    reg inrange;
    inrange = ioctl_addr>=a0 && ioctl_addr<a1;
    check_sel = inrange ? sel : ~sel;
end endfunction

// function check_ofs(input [23:0]io,start,a); begin
//     reg [23:0] adj;
//     adj       = io-start;
//     check_ofs = adj!=a;
// end endfunction

reg [13:0] last_addr;

always @(posedge clk) begin
    last_addr <= ioctl_addr[13:0];
end

initial begin
    ioctl_ram  = 0;
    ioctl_wr   = 0;
    ioctl_dout = 0;
    ioctl_addr = 0;
    dout0=0; dout1=0; dout2=0; dout3=0; dout4=0; dout5=0;
    din0=0; din1=0; din2=0; din3=0; din4=0; din5=0;
    @(negedge rst);
    repeat(4) @(posedge clk);
    // din muxes must follow din when ioctl_ram is low
    ioctl_ram  = 0;
    repeat(200) begin
        din0  = $random;
        din1  = $random;
        din2  = $random;
        din5  = $random;
        addr0 = $random;
        addr1 = $random;
        addr2 = $random;
        #10;
        assert_msg(din0_mx==din0,"signals to memories must ignore IOCTL when ioctl_ram is low");
        assert_msg(din1_mx==din1,"16-bit signals to memories must ignore IOCTL when ioctl_ram is low");
        assert_msg(din2_mx==din2,"32-bit signals to memories must ignore IOCTL when ioctl_ram is low");
        assert_msg(din5_mx==din5,"signals to memories must ignore IOCTL when ioctl_ram is low");
        assert_msg(addr0_mx==addr0,"signals to memories must ignore IOCTL when ioctl_ram is low");
        assert_msg(addr1_mx==addr1,"signals to memories must ignore IOCTL when ioctl_ram is low");
        assert_msg(addr2_mx==addr2,"signals to memories must ignore IOCTL when ioctl_ram is low");
    end
    // din muxes must follow ioctl_dout when ioctl_ram is high
    ioctl_ram  = 1;
    repeat(500) begin
        ioctl_dout = $random;
        ioctl_addr[14:0] = $random;
        @(posedge clk);
        @(posedge clk);
        assert_msg(din0_mx==ioctl_dout,"signals to memories must follow IOCTL when ioctl_ram is high");
        assert_msg(din1_mx=={2{ioctl_dout}},"16-bit signals to memories must follow IOCTL when ioctl_ram is high");
        assert_msg(din2_mx=={4{ioctl_dout}},"32-bit signals to memories must follow IOCTL when ioctl_ram is high");
        assert_msg(din5_mx==ioctl_dout,"signals to memories must follow IOCTL when ioctl_ram is high");
        assert_msg(addr0_mx==last_addr[9:0],"addr0_mx must track ioctl_addr");
        assert_msg(check_sel(0,1024,          uut.sel[0]), "block 0 must be selected" );
        assert_msg(check_sel(1024,  1024  +1024*4,uut.sel[1]), "block 1 must be selected" );
        assert_msg(check_sel(1024*5,1024*5+1024*8,uut.sel[2]), "block 2 must be selected" );
        assert_msg( last_addr[ 9:0]            ==addr0_mx || !uut.sel[0],"block 0 address is not shifted correctly");
        assert_msg((last_addr[12:1]-12'd512   )==addr1_mx || !uut.sel[1],"block 1 address is not shifted correctly");
        assert_msg((last_addr[13:2]-12'd1280  )==addr2_mx || !uut.sel[2],"block 2 address is not shifted correctly");
    end
    dout0 = 8'hc3;
    dout1 = 16'hb1a0;
    dout2 = 32'hd3c2b1a0;
    ioctl_wr = 0;
    ioctl_addr = 24'd0;
    @(posedge clk); #1 assert_msg(ioctl_din==8'hc3,"8-bit dump must read byte 0");
    ioctl_addr = 24'd1024;
    @(posedge clk); #1 assert_msg(ioctl_din==8'ha0,"16-bit dump must read byte 0");
    ioctl_addr = 24'd1025;
    @(posedge clk); #1 assert_msg(ioctl_din==8'hb1,"16-bit dump must read byte 1");
    ioctl_addr = 24'd1024*5;
    @(posedge clk); #1 assert_msg(ioctl_din==8'ha0,"32-bit dump must read byte 0");
    ioctl_addr = 24'd1024*5+1;
    @(posedge clk); #1 assert_msg(ioctl_din==8'hb1,"32-bit dump must read byte 1");
    ioctl_addr = 24'd1024*5+2;
    @(posedge clk); #1 assert_msg(ioctl_din==8'hc2,"32-bit dump must read byte 2");
    ioctl_addr = 24'd1024*5+3;
    @(posedge clk); #1 assert_msg(ioctl_din==8'hd3,"32-bit dump must read byte 3");

    ioctl_wr = 1;
    ioctl_addr = 24'd0;
    @(posedge clk); #1 assert_msg(we0_mx==1'b1,"8-bit restore must select byte 0");
    ioctl_addr = 24'd1024;
    @(posedge clk); #1 assert_msg(we1_mx==2'b01,"16-bit restore must select byte 0");
    ioctl_addr = 24'd1025;
    @(posedge clk); #1 assert_msg(we1_mx==2'b10,"16-bit restore must select byte 1");
    ioctl_addr = 24'd1024*5;
    @(posedge clk); #1 assert_msg(we2_mx==4'b0001,"32-bit restore must select byte 0");
    ioctl_addr = 24'd1024*5+1;
    @(posedge clk); #1 assert_msg(we2_mx==4'b0010,"32-bit restore must select byte 1");
    ioctl_addr = 24'd1024*5+2;
    @(posedge clk); #1 assert_msg(we2_mx==4'b0100,"32-bit restore must select byte 2");
    ioctl_addr = 24'd1024*5+3;
    @(posedge clk); #1 assert_msg(we2_mx==4'b1000,"32-bit restore must select byte 3");
    pass();
end

jtframe_ioctl_dump #(
    .AW0(10),
    .DW1(16),
    .AW1(12),
    .DW2(32),
    .AW2(13)
) uut (
    .clk       (clk       ),
    .dout0     (dout0     ),
    .dout1     (dout1     ),
    .dout2     (dout2     ),
    .dout3     (dout3     ),
    .dout4     (dout4     ),
    .dout5     (dout5     ),
    .din0      (din0      ),
    .din1      (din1      ),
    .din2      (din2      ),
    .din3      (din3      ),
    .din4      (din4      ),
    .din5      (din5      ),
    .din0_mx   (din0_mx   ),
    .din1_mx   (din1_mx   ),
    .din2_mx   (din2_mx   ),
    .din3_mx   (din3_mx   ),
    .din4_mx   (din4_mx   ),
    .din5_mx   (din5_mx   ),
    .we0       (we0       ),
    .we1       (we1       ),
    .we2       (we2       ),
    .we3       (we3       ),
    .we4       (we4       ),
    .we5       (we5       ),
    .we0_mx    (we0_mx    ),
    .we1_mx    (we1_mx    ),
    .we2_mx    (we2_mx    ),
    .we3_mx    (we3_mx    ),
    .we4_mx    (we4_mx    ),
    .we5_mx    (we5_mx    ),
    .addr0     (addr0     ),
    .addr1     (addr1     ),
    .addr2     (addr2     ),
    .addr0_mx  (addr0_mx  ),
    .addr1_mx  (addr1_mx  ),
    .addr2_mx  (addr2_mx  ),
    .ioctl_addr(ioctl_addr),
    .ioctl_ram (ioctl_ram ),
    .ioctl_wr  (ioctl_wr  ),
    .ioctl_aux (ioctl_aux ),
    .ioctl_dout(ioctl_dout),
    .ioctl_din (ioctl_din )
);

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           )
);

endmodule
