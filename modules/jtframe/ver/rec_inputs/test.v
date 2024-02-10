module test;

reg rst=0, clk=0,vs=0;
integer cnt=0;
reg start=1, coin=1;
reg [5:0] joystick=6'h3f;
wire [15:0] frame_cnt = cnt[6+:16]-16'd64; // 64 => allow time for memory clear

initial begin
	forever #5 clk=~clk;
end

always @(posedge clk) begin
	cnt <= cnt+1;
	vs  <= &cnt[5:0];
	case( frame_cnt )
		5: coin <= 0;
		6: coin <= 1;
		10: start <= 0;
		12: start <= 1;
		26: joystick[0] <= 0;
		36: joystick[0] <= 1;
		300: joystick[1] <= 0;
		400: joystick[1] <= 1;
		700: joystick[2] <= 0;
		701: joystick[2] <= 1;
	   1000: $finish;
	endcase
end

initial begin
	$dumpfile("test.lxt");
	$dumpvars;
	rst = 0;
	#50 rst = 1;
	#50 rst = 0;
end

jtframe_rec_inputs #(12) uut(
    .rst            ( rst           ),
    .clk            ( clk           ),

    .vs             ( vs            ),
    .dip_pause      ( 1'b1          ),

    .game_start     ( { 3'd0,start }),
    .game_coin      ( { 3'd0,coin  }),
    .joystick       ( ~joystick     ),
    
    .ioctl_addr     ( 13'd0         ),
    .ioctl_merged   (               )
);

endmodule