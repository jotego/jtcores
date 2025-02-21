module k007785	(
				input clr_n,
				input clk2,
				input p1h,
				input p256vd,
				input fbref,
				input dinit,	
				input sclr_n,
				input [15:0] od,
				output [3:0] c,
				output [3:0] cx,
				output [1:0] hpoj,
				output [8:2] hpd,
				output [8:0] vpd,
				output [19:0] oca,
				output oscen,
				output ochf,
				output fb1_n,
				output fb2_n
				);

reg [15:0] wd3;// wd2[15] = sprten.
reg [10:0] countreg;
wire [10:0] count;
wire [6:0] hcount; 
wire [15:0] wd3lt,test,test2;

assign clr = ~clr_n;

assign wd3lt = {16{w3en}} & od | {16{~w3en}} & wd3;
assign test = {16{w3en}} & od;
assign test2 = {16{~w3en}} & wd3;

DFR_d_ff	a47	(
				.clk(clk2),
				.rst(~clr_n),
				.d(cnten_n),// cnten_n
				.q(),
				.q_bar(q_bar_a47)
				);

assign sprten = wd3[15];
assign o_l30 = sprten | q_bar_a47;

always @(posedge clk2 or clr_n)
begin
	if(~clr_n)
	begin
		wd3 <= 15'b0;
	end
	else
	begin
		wd3 <= wd3lt;
	end
end

DF_d_ff	o59	(
			.clk(clk2),
			.rst(1'b0),
			.set(clr),
			.d(q_bar_a47 | ~wd3[15]),
			.q(q_o59),
			.q_bar()
			);

DF_d_ff	r61	(
			.clk(clk2),
			.rst(1'b0),
			.set(clr),
			.d(q_o59),
			.q(q_r61),
			.q_bar()
			);

DF_d_ff	n60	(
			.clk(clk2),
			.rst(1'b0),
			.set(clr),
			.d(q_r61),
			.q(q_n60),
			.q_bar()
			);


always @(posedge clk2 or clr)
begin
	if(clr)
	begin
		countreg[10:0] <= 10'hfff;
	end
	else
	begin
		countreg[0] <= sclr_n & q_n60;//L60
		countreg[1] <= countreg[0];//K71
		countreg[2] <= countreg[1];//L72
		countreg[3] <= countreg[2];//N78
		countreg[4] <= countreg[3];//Q68
		countreg[5] <= countreg[4];//J68
		countreg[6] <= countreg[5];//H66
		countreg[7] <= countreg[6];//G69
		countreg[8] <= countreg[7];//M69
		countreg[9] <= countreg[8];//P72
		countreg[10] <= countreg[9];//S71
		//countreg[11] <= ~countreg[10];//T64
		//countreg[12] = ~countreg[11];//T13
	end
end

DFR_d_ff	t64	(
				.clk(clk2),
				.rst(~sclr_n),
				.d(~countreg[10]),
				.q(cnten_n),
				.q_bar(cnten)
				);

assign count[10:0] = countreg[10:0];

assign w0en = ~count[2]; // X pos
assign w1en = ~count[3]; // Code
assign w2en = ~count[10]; // Y pos
assign w3en = ~cnten; // Spriten and parameters.

assign oscen = ~w0en & ~w1en & ~w3en & ~w2en;

DFR_d_ff	q24	(
				.clk(clk2),
				.rst(~clr_n),
				.d(cnten & (hcount[1] ^ hcount[0])),
				.q(hcount[1]),
				.q_bar()
				); 

DFR_d_ff	l34	(
				.clk(clk2),
				.rst(~clr_n),
				.d(~(~(hcount[1] & hcount[0]) ^ hcount[2]) & cnten),
				.q(hcount[2]),
				.q_bar()
				);

DFR_d_ff	p39	(
				.clk(clk2),
				.rst(~clr_n),
				.d(~(~(hcount[1] & hcount[2] & hcount[0]) ^ hcount[3]) & cnten),
				.q(hcount[3]),
				.q_bar()
				);

DFR_d_ff	w47	(
				.clk(clk2),
				.rst(~clr_n),
				.d(~(~(hcount[1] & hcount[2] & hcount[3] & hcount[0]) ^ hcount[4]) & cnten),
				.q(hcount[4]),
				.q_bar()
				);

assign h16 = &hcount[4:1] & hcount[0];

DFR_d_ff	g35	(
				.clk(clk2),
				.rst(~clr_n),
				.d((h16 ^ hcount[5]) & cnten),
				.q(hcount[5]),
				.q_bar()
				);

DFR_d_ff	f34	(
				.clk(clk2),
				.rst(~clr_n),
				.d(~(~(hcount[5] & h16) ^ hcount[6]) & cnten),
				.q(hcount[6]),
				.q_bar()
				);

JKFR_jk_ff	m40	(
				.j(cnten_n),
				.k(1'b0),// Needs to be updated later..
				.ck(clk2),
				.rst(~clr_n),
				.q(),
				.q_bar(q_bar_m40)
				);

assign hcount[0] =  ~(q_bar_m40 | (fbref | dinit));

endmodule