/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 28-4-2024 */

// Model of SEGA's 315-5242 DAC
// based on RE work in
// https://github.com/furrtek/SiliconRE
// DAC values derived from electrical network analysis

module jtshanon_coldac(
    input            clk,
    input            pxl_cen,
    input      [4:0] rin, gin, bin,
    input            en,
    input            gray_n,
    input            sh,
    input            hilo,
    output reg [5:0] rout, gout, bout
);

wire [4:0] gray;
wire [5:0] lvl_r, lvl_g, lvl_b;

jtshanon_coldac_lvldec dec_r(gray_n ? rin : gray, sh, hilo, lvl_r);
jtshanon_coldac_lvldec dec_g(gray_n ? gin : gray, sh, hilo, lvl_g);
jtshanon_coldac_lvldec dec_b(gray_n ? bin : gray, sh, hilo, lvl_b);

always @(posedge clk) begin
    {rout, gout, bout} <= {lvl_r, lvl_g, lvl_b};
    if( !en ) {rout,gout,bout} <= 0;
end

// gray out logic comes directly from Furrtek's model
wire JETA_A, GYPU,  HORA,  BULU,  CAGA, HUTO, GYVE, DUDO, CUFO,
      FYXA,  JUSO,  GETY,  AGYD,  ARAX, ENAS, COXA, HATE, HUWU,
      G0ADJ, G1ADJ, G2ADJ, G3ADJ, G4ADJ;

assign gray[0] = ^{~FYXA, ~&{~GETY, JUSO}}; // HYJA, FENY
assign gray[1] = ^{~&{~&{~FYXA, JUSO}, ~GETY}, ~&{~ARAX, AGYD}};    // CUNY, BUHE, BYVO
assign gray[2] = ^{~&{~ARAX, ~&{AGYD, GETY}, ~&{~FYXA, JUSO, AGYD}}, ~&{~COXA, ENAS}};  // BEPE, ACOB, COHU, DODO
assign gray[3] = ^{~&{~COXA, ~&{ENAS, ARAX}, ~&{AGYD, ENAS, GETY}, ~&{~FYXA, JUSO, AGYD, ENAS}}, ~&{HUWU, HATE}};   // EHON, BOGO, HORO, AMYG, CAJO, DAPA
assign gray[4] = &{HUWU, ~&{HATE, COXA}, ~&{ENAS, HATE, ARAX}, ~&{AGYD, JUSO, ~FYXA, HATE, ENAS}, ~&{AGYD, ENAS, HATE, GETY}};  // GOXY, FUBY, ATYH, FAVO, GEHA

assign JETA_A = ~&{rin[0], bin[0]};
assign GYPU   = ~&{rin[1], bin[1]};
assign HORA   = ~|{rin[1], bin[1]};
assign BULU   = ~&{rin[2], bin[2]};
assign CAGA   = ~|{rin[2], bin[2]};
assign HUTO   = ~&{rin[3], bin[3]};
assign GYVE   = ~|{rin[3], bin[3]};
assign DUDO   = ~&{rin[4], bin[4]};
assign CUFO   =    rin[4] |bin[4];

assign FYXA   =    gin[0] &G0ADJ;
assign JUSO   = ~&{gin[1], G1ADJ};
assign GETY   = ~|{gin[1], G1ADJ};
assign AGYD   = ~&{gin[2], G2ADJ};
assign ARAX   = ~|{gin[2], G2ADJ};
assign ENAS   = ~&{gin[3], G3ADJ};
assign COXA   = ~|{gin[3], G3ADJ};
assign HATE   = ~&{gin[4], G4ADJ};
assign HUWU   =    gin[4] |G4ADJ;

assign G0ADJ = ^{JETA_A, ~&{~HORA, GYPU}};  // GUTO, EROP
assign G1ADJ = ^{~&{~&{JETA_A, GYPU}, ~HORA}, ~&{~CAGA, BULU}}; // DOCY, COPU, DUFY
assign G2ADJ = ^{~&{~CAGA, ~&{BULU, HORA}, ~&{JETA_A, GYPU, BULU}}, ~&{~GYVE, HUTO}};   // ATOK, ETYB, BYXO, HAXO, HUNA
assign G3ADJ = ^{~&{~GYVE, ~&{HUTO, CAGA}, ~&{BULU, HUTO, HORA}, ~&{JETA_A, GYPU, BULU, HUTO}}, ~&{CUFO, DUDO}};    // BEWA, DAMY, BOCA, DYJU, ETEC, GYLO
assign G4ADJ = &{CUFO, ~&{DUDO, GYVE}, ~&{HUTO, DUDO, CAGA}, ~&{BULU, GYPU, JETA_A, DUDO, HUTO}, ~&{BULU, HUTO, DUDO, HORA}};   // FERO, JYSA, CUGO, FUGU, JANO

endmodule

module jtshanon_coldac_lvldec(
    input      [4:0] act,
    input            sh,
    input            hilo,
    output reg [5:0] lvl
);

always @(*) begin
    casez( {act,sh,hilo})
        // normal tones
        {5'd00, 2'b0?}: lvl = 0;
        {5'd01, 2'b0?}: lvl = 2;
        {5'd02, 2'b0?}: lvl = 4;
        {5'd03, 2'b0?}: lvl = 5;
        {5'd04, 2'b0?}: lvl = 7;
        {5'd05, 2'b0?}: lvl = 9;
        {5'd06, 2'b0?}: lvl = 10;
        {5'd07, 2'b0?}: lvl = 12;
        {5'd08, 2'b0?}: lvl = 15;
        {5'd09, 2'b0?}: lvl = 16;
        {5'd10, 2'b0?}: lvl = 18;
        {5'd11, 2'b0?}: lvl = 20;
        {5'd12, 2'b0?}: lvl = 22;
        {5'd13, 2'b0?}: lvl = 24;
        {5'd14, 2'b0?}: lvl = 25;
        {5'd15, 2'b0?}: lvl = 27;
        {5'd16, 2'b0?}: lvl = 31;
        {5'd17, 2'b0?}: lvl = 33;
        {5'd18, 2'b0?}: lvl = 35;
        {5'd19, 2'b0?}: lvl = 36;
        {5'd20, 2'b0?}: lvl = 38;
        {5'd21, 2'b0?}: lvl = 40;
        {5'd22, 2'b0?}: lvl = 42;
        {5'd23, 2'b0?}: lvl = 43;
        {5'd24, 2'b0?}: lvl = 46;
        {5'd25, 2'b0?}: lvl = 47;
        {5'd26, 2'b0?}: lvl = 49;
        {5'd27, 2'b0?}: lvl = 51;
        {5'd28, 2'b0?}: lvl = 53;
        {5'd29, 2'b0?}: lvl = 55;
        {5'd30, 2'b0?}: lvl = 56;
        {5'd31, 2'b0?}: lvl = 58;
        // dimmed
        {5'd00, 2'b10}: lvl = 0;
        {5'd01, 2'b10}: lvl = 0;
        {5'd02, 2'b10}: lvl = 1;
        {5'd03, 2'b10}: lvl = 1;
        {5'd04, 2'b10}: lvl = 1;
        {5'd05, 2'b10}: lvl = 2; // values above this point were rounded up
        {5'd06, 2'b10}: lvl = 2; // to avoid too many zero entries
        {5'd07, 2'b10}: lvl = 3;
        {5'd08, 2'b10}: lvl = 4;
        {5'd09, 2'b10}: lvl = 5;
        {5'd10, 2'b10}: lvl = 7;
        {5'd11, 2'b10}: lvl = 8;
        {5'd12, 2'b10}: lvl = 9;
        {5'd13, 2'b10}: lvl = 11;
        {5'd14, 2'b10}: lvl = 12;
        {5'd15, 2'b10}: lvl = 14;
        {5'd16, 2'b10}: lvl = 17;
        {5'd17, 2'b10}: lvl = 18;
        {5'd18, 2'b10}: lvl = 20;
        {5'd19, 2'b10}: lvl = 21;
        {5'd20, 2'b10}: lvl = 23;
        {5'd21, 2'b10}: lvl = 24;
        {5'd22, 2'b10}: lvl = 25;
        {5'd23, 2'b10}: lvl = 27;
        {5'd24, 2'b10}: lvl = 29;
        {5'd25, 2'b10}: lvl = 30;
        {5'd26, 2'b10}: lvl = 32;
        {5'd27, 2'b10}: lvl = 33;
        {5'd28, 2'b10}: lvl = 34;
        {5'd29, 2'b10}: lvl = 36;
        {5'd30, 2'b10}: lvl = 37;
        {5'd31, 2'b10}: lvl = 38;
        // bright
        {5'd00, 2'b11}: lvl = 17;
        {5'd01, 2'b11}: lvl = 18;
        {5'd02, 2'b11}: lvl = 20;
        {5'd03, 2'b11}: lvl = 21;
        {5'd04, 2'b11}: lvl = 23;
        {5'd05, 2'b11}: lvl = 24;
        {5'd06, 2'b11}: lvl = 25;
        {5'd07, 2'b11}: lvl = 27;
        {5'd08, 2'b11}: lvl = 29;
        {5'd09, 2'b11}: lvl = 30;
        {5'd10, 2'b11}: lvl = 32;
        {5'd11, 2'b11}: lvl = 33;
        {5'd12, 2'b11}: lvl = 34;
        {5'd13, 2'b11}: lvl = 36;
        {5'd14, 2'b11}: lvl = 37;
        {5'd15, 2'b11}: lvl = 38;
        {5'd16, 2'b11}: lvl = 42;
        {5'd17, 2'b11}: lvl = 43;
        {5'd18, 2'b11}: lvl = 45;
        {5'd19, 2'b11}: lvl = 46;
        {5'd20, 2'b11}: lvl = 47;
        {5'd21, 2'b11}: lvl = 49;
        {5'd22, 2'b11}: lvl = 50;
        {5'd23, 2'b11}: lvl = 51;
        {5'd24, 2'b11}: lvl = 54;
        {5'd25, 2'b11}: lvl = 55;
        {5'd26, 2'b11}: lvl = 56;
        {5'd27, 2'b11}: lvl = 58;
        {5'd28, 2'b11}: lvl = 59;
        {5'd29, 2'b11}: lvl = 60;
        {5'd30, 2'b11}: lvl = 62;
        {5'd31, 2'b11}: lvl = 63;
    endcase
end

endmodule
