module k007784	(
				input clk2,
				input clr_n,
				input dma,
				input obfi,
				inout [15:0] od,	
				output bflg
				);

wire [3:0] hcount;
wire [15:0] odw,w0out,w1out,w2out,w3out,test3;
wire [7:0] w0outhi,w0outlo,w1outhi,w1outlo,w2outhi,w2outlo,w3outhi,w3outlo,test;
wire w0lt;
reg [15:0] w0,w1,w2;
reg [14:0] w3;
reg [8:0] x,y;
reg sprten;

assign # 1 clk2_n = ~clk2;
assign # 33 hdout_n = ~(q_q43 & hcount[3] & dma);
assign ldout_n = ~(q_q60 & hcount[3] & dma);

//assign odh = ~hdout_n ? odhw : 8'hz;
//assign odl = ~ldout_n ? odlw : 8'hz;
assign od = {~hdout_n ? odw[15:8] : 8'hz,~ldout_n ? odw[7:0] : 8'hz};
assign din = ~(~dma | hcount[3] | clk2);

// Words in latched

assign  w0lt = ~(din & ~hcount[0] & ~hcount[1] & ~hcount[2]);
assign  w2lt = ~(din & ~hcount[0] & hcount[1] & ~hcount[2]);
assign  w3lt = ~(din & hcount[0] & hcount[1] & ~hcount[2]);
assign  w4lt = ~(din & ~hcount[0] & ~hcount[1] & hcount[2]);
assign  w5lt = ~(din & hcount[0] & ~hcount[1] & hcount[2]);
assign  w6lt = ~(din & ~hcount[0] & hcount[1] & hcount[2]);
assign  w7lt = ~(din & hcount[0] & hcount[1] & hcount[2]);

C42_4bit_cnt	r25	(
					.ck(clk2),
					.cl_n(clr_n),
					.q(hcount)
					);

FDO_d_ff 		q69	(
			   		.d(~hcount[1]),
			   		.clk(clk2_n),
			   		.reset_n(clr_n),
			   		.q(q_69),
			   		.q_bar()
					);

assign h2dd = ~q_69;
assign h2dd_n = ~h2dd;

FDO_d_ff 		r71	(
			   		.d(hcount[2]),
			   		.clk(clk2_n),
			   		.reset_n(clr_n),
			   		.q(q_r71),
			   		.q_bar()
					);

assign h4dd_n = ~q_r71;
assign h4dd = ~h4dd_n;

FDO_d_ff 		q43	(
			   		.d(hcount[3]),
			   		.clk(clk2_n),
			   		.reset_n(clr_n),
			   		.q(q_q43),
			   		.q_bar()
					);

FDO_d_ff 		q60	(
			   		.d(hcount[3]),
			   		.clk(clk2_n),
			   		.reset_n(clr_n),
			   		.q(q_q60),
			   		.q_bar()
					);


FDO_d_ff 		d78	(
			   		.d(od[15]),
			   		.clk(w0lt),
			   		.reset_n(clr_n),
			   		.q(bflg),
			   		.q_bar()
					);



/*
always @(posedge w2lt or posedge w3lt or posedge w7lt or negedge clr_n) begin
	if(!clr_n)
		begin
			w1 <= 16'h0;	
			w2 <= 16'h0;	
			w3 <= 16'h0;	
			w4 <= 16'h0;
			sprten <= 1'b0;	
		end	
	else if (w2lt)
		begin
			w2 <= {sprten,od[14:0]};
		end
	else if (w3lt)
		begin 
			w1 <= od; 
		end	
	else if (w7lt) 
		begin 
			sprten <= 1'b1; 
		end	
	
end
*/
always @(posedge w2lt or negedge clr_n) begin
	if(!clr_n)
		begin
//			w2 <= 16'h0;	
			w3 <= 16'h0;	
		end	
	else if (w2lt)
		begin
//			w2 <= {1'bz,od[14:0]};
			w3 <= {1'bz,od[14:0]};

		end
end

always @(posedge w3lt or negedge clr_n) begin
	if(!clr_n)
		begin
//			w1 <= 16'h0;
			w0 <= 16'h0;	
		end	
	else if (w3lt)
		begin
//			w1 <= od;
			w0 <= od;
		end
end

always @(posedge w4lt or negedge clr_n) begin
	if(!clr_n)
		begin
			x[15:8] <= 8'b0;	
		end	
	else if (w6lt)
		begin
			x[15:8] <= od[7:0];
		end
end

always @(posedge w5lt or negedge clr_n) begin
	if(!clr_n)
		begin
			x[7:0] <= 8'b0;	
		end	
	else if (w6lt)
		begin
			x[7:0] <= od[15:8];
		end
end

always @(posedge w6lt or negedge clr_n) begin
	if(!clr_n)
		begin
			sprten <= 1'b0;	
		end	
	else if (w6lt)
		begin
			y[15:8] <= od[7:0];
		end
end

always @(posedge w7lt or negedge clr_n) begin
	if(!clr_n)
		begin
			sprten <= 1'b0;	
		end	
	else if (w7lt)
		begin
			sprten <= 1'b1;
			//w4 <= 16'hffff;
			y[7:0] <= od[15:8];
		end
end

assign w0out = w0[15:0];
assign w0outhi = w0[15:8];
assign w0outlo = w0[7:0];

assign w1out = {{6{1'b0}},x[8:0]};
assign w1outhi = {{6{1'b0}},x[8:7]};
assign w1outlo = x[6:0];

assign w2out = {{7{1'b0}},y[8:0]};
assign w2outhi = {{7{1'b0}},y[8]};
assign w2outlo = y[7:0];

assign w3out = {sprten,w3};
assign w3outhi = {sprten,w3[14:8]};
assign w3outlo = w3[7:0];


//assign test3 = {8{h2dd_n & h4dd_n},8{1'b0}};

assign odw[15:8] = hdout_n ? 8'hz : obfi ? 8'h0 : {8{h2dd_n & h4dd_n}} & w0outhi
| {8{h2dd & h4dd_n}} & w1outhi | {8{h2dd_n & h4dd}} & w2outhi | {8{h2dd & h4dd}} & w3outhi;

assign odw[7:0] = hdout_n ? 8'hz : obfi ? 8'h0 : {8{h2dd_n & h4dd_n}} & w0outlo
| {{8{1'b0}},{8{h2dd & h4dd_n}}} & w1outlo | {{8{1'b0}},{8{h2dd_n & h4dd}}} & w2outlo | {{8{1'b0}},{8{h2dd & h4dd}}} & w3outlo;

//assign odw[7:0] = ldout_n ? 8'hz : obfi ? 8'h0 : {{8{1'b0},8{h2dd_n & h4dd_n}}} & w1[7:0]
//| {8{1'b0},8{h2dd & h4dd_n}} & w2[7:0] | {8{1'b0},8{h2dd_n & h4dd}} & w3[7:0] | {8{1'b0},8{h2dd & h4dd}} & y[7:0];

// ~obfi ? 8'h0 : 8{~hcount[1] & ~hcount[2]} & w1[15:8]
//  + 8{hcount[1] & ~hcount[2]} & w2[15:8] + 8{~hcount[1] & hcount[2]} & w3[15:8] + 8{hcount[1] & hcount[2]} & w4[15:8]
endmodule
