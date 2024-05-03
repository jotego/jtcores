// OKI M71064
// Copyright (C) 2020 Sean 'furrtek' Gonsalves
// This was only tested in simulation

module M71064(
	input CLK,
	input nBLANK,
	input nGREY,
	input nSHADE, HI_LO,

	input [4:0] R,
	input [4:0] G,
	input [4:0] B,
	
	output reg [4:0] ROUT,
	inout ROUT_SH,
	output reg [4:0] GOUT,
	inout GOUT_SH,
	output reg [4:0] BOUT,
	inout BOUT_SH
);

wire ETAC, JUBE, CUSA, GOFU, HAZE, BUBU, BEXU, JARY, JOGO, DUVO, HOKU, GUVA, ALYF, CONE, AVUR;
wire JOSU, DEGE, COCU, EPOP, ABAR, ATUB, GUVO, BYWE, FYXA, GETY, JUSO, ARAX, HOKA, COGA, FEVY;
wire AGYD, HORA, COXA, ENAS, HUWU, HATE, GYVE, G2ADJ, G3ADJ, G0ADJ, G1ADJ, G4ADJ;

reg ROUT_SH_D, GOUT_SH_D, BOUT_SH_D;
reg nROUT_SH_EN, nGOUT_SH_EN, nBOUT_SH_EN;
wire [4:0] GREY;

assign ROUT_SH = nROUT_SH_EN ? 1'bz : ROUT_SH_D;
assign GOUT_SH = nGOUT_SH_EN ? 1'bz : GOUT_SH_D;
assign BOUT_SH = nBOUT_SH_EN ? 1'bz : BOUT_SH_D;

always @(posedge CLK) begin
	{ROUT, ROUT_SH_D, nROUT_SH_EN} <= {ETAC, JUBE, CUSA, GOFU, HAZE, BUBU, BEXU};
	{GOUT, GOUT_SH_D, nGOUT_SH_EN} <= {JARY, JOGO, DUVO, HOKU, GUVA, ALYF, CONE};
	{BOUT, BOUT_SH_D, nBOUT_SH_EN} <= {AVUR, HOKA, COGA, FEVY, JOSU, DEGE, COCU};
end

assign BUBU = ~&{HI_LO, nBLANK, EPOP};
assign BEXU = ~&{~nSHADE, nBLANK, EPOP};
assign EPOP = |{HAZE, GOFU, CUSA, ETAC, JUBE};
assign HAZE = (GREY[0] & ABAR) | (ATUB & R[0]);
assign GOFU = (GREY[1] & ABAR) | (ATUB & R[1]);
assign CUSA = (GREY[2] & ABAR) | (ATUB & R[2]);
assign JUBE = (GREY[3] & ABAR) | (ATUB & R[3]);
assign ETAC = (GREY[4] & ABAR) | (ATUB & R[4]);

assign ALYF = ~&{HI_LO, nBLANK, GUVO};
assign CONE = ~&{~nSHADE, nBLANK, GUVO};
assign GUVO = |{GUVA, HOKU, DUVO, JARY, JOGO};
assign GUVA = (GREY[0] & ABAR) | (ATUB & G[0]);
assign HOKU = (GREY[1] & ABAR) | (ATUB & G[1]);
assign DUVO = (GREY[2] & ABAR) | (ATUB & G[2]);
assign JOGO = (GREY[3] & ABAR) | (ATUB & G[3]);
assign JARY = (GREY[4] & ABAR) | (ATUB & G[4]);

assign DEGE = ~&{HI_LO, nBLANK, BYWE};
assign COCU = ~&{~nSHADE, nBLANK, BYWE};
assign BYWE = |{JOSU, FEVY, COGA, AVUR, HOKA};
assign JOSU = (GREY[0] & ABAR) | (ATUB & B[0]);
assign FEVY = (GREY[1] & ABAR) | (ATUB & B[1]);
assign COGA = (GREY[2] & ABAR) | (ATUB & B[2]);
assign HOKA = (GREY[3] & ABAR) | (ATUB & B[3]);
assign AVUR = (GREY[4] & ABAR) | (ATUB & B[4]);

// Duplication for large fan-out
/*assign ABAR = ~|{nGREY, ~nBLANK};
assign ATUB = ~|{~nGREY, ~nBLANK};
assign BABY = ~|{nGREY, ~nBLANK};
assign BAFU = ~|{~nGREY, ~nBLANK};
assign CANY = ~|{nGREY, ~nBLANK};
assign CUMU = ~|{~nGREY, ~nBLANK};
assign HENO = ~|{nGREY, ~nBLANK};
assign HOLU = ~|{~nGREY, ~nBLANK};*/
assign ABAR = ~|{nGREY, ~nBLANK};
assign ATUB = ~|{~nGREY, ~nBLANK};

assign GREY[0] = ^{~FYXA, ~&{~GETY, JUSO}};	// HYJA, FENY
assign GREY[1] = ^{~&{~&{~FYXA, JUSO}, ~GETY}, ~&{~ARAX, AGYD}};	// CUNY, BUHE, BYVO
assign GREY[2] = ^{~&{~ARAX, ~&{AGYD, GETY}, ~&{~FYXA, JUSO, AGYD}}, ~&{~COXA, ENAS}};	// BEPE, ACOB, COHU, DODO
assign GREY[3] = ^{~&{~COXA, ~&{ENAS, ARAX}, ~&{AGYD, ENAS, GETY}, ~&{~FYXA, JUSO, AGYD, ENAS}}, ~&{HUWU, HATE}};	// EHON, BOGO, HORO, AMYG, CAJO, DAPA
assign GREY[4] = &{HUWU, ~&{HATE, COXA}, ~&{ENAS, HATE, ARAX}, ~&{AGYD, JUSO, ~FYXA, HATE, ENAS}, ~&{AGYD, ENAS, HATE, GETY}};	// GOXY, FUBY, ATYH, FAVO, GEHA

assign JETA_A = ~&{R[0], B[0]};
assign GYPU = ~&{R[1], B[1]};
assign HORA = ~|{R[1], B[1]};
assign BULU = ~&{R[2], B[2]};
assign CAGA = ~|{R[2], B[2]};
assign HUTO = ~&{R[3], B[3]};
assign GYVE = ~|{R[3], B[3]};
assign DUDO = ~&{R[4], B[4]};
assign CUFO = R[4] | B[4];

assign FYXA = G[0] & G0ADJ;
assign JUSO = ~&{G[1], G1ADJ};
assign GETY = ~|{G[1], G1ADJ};
assign AGYD = ~&{G[2], G2ADJ};
assign ARAX = ~|{G[2], G2ADJ};
assign ENAS = ~&{G[3], G3ADJ};
assign COXA = ~|{G[3], G3ADJ};
assign HATE = ~&{G[4], G4ADJ};
assign HUWU = G[4] | G4ADJ;

assign G0ADJ = ^{JETA_A, ~&{~HORA, GYPU}};	// GUTO, EROP
assign G1ADJ = ^{~&{~&{JETA_A, GYPU}, ~HORA}, ~&{~CAGA, BULU}};	// DOCY, COPU, DUFY
assign G2ADJ = ^{~&{~CAGA, ~&{BULU, HORA}, ~&{JETA_A, GYPU, BULU}}, ~&{~GYVE, HUTO}};	// ATOK, ETYB, BYXO, HAXO, HUNA
assign G3ADJ = ^{~&{~GYVE, ~&{HUTO, CAGA}, ~&{BULU, HUTO, HORA}, ~&{JETA_A, GYPU, BULU, HUTO}}, ~&{CUFO, DUDO}};	// BEWA, DAMY, BOCA, DYJU, ETEC, GYLO
assign G4ADJ = &{CUFO, ~&{DUDO, GYVE}, ~&{HUTO, DUDO, CAGA}, ~&{BULU, GYPU, JETA_A, DUDO, HUTO}, ~&{BULU, HUTO, DUDO, HORA}};	// FERO, JYSA, CUGO, FUGU, JANO

endmodule
