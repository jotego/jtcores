// SPDX-License-Identifier: GPL-3.0-or-later
// Development view of the sheet G player-car outputs. The colours are FALSE
// colours: the sheet C video mixer that gives the outputs their real colour and
// priority is not traced yet. Captions are development aids, not game artwork.
module jtmonacogp_pview(
    input      [8:0] x, y,
    input            active,
    input            loaded, load_error,
    input      [1:0] state,
    input      [3:0] prom_en,
    input            vs4, vs8, vs16, vs32,
    input            strobe_n,
    input            slide_n,       // test stimulus, shown as a patch
    input            player_body_n, tire_n, player_bl_n,
    output reg [3:0] red, green, blue
);
    localparam [319:0] L0  = "SHEET G PLAYER CAR PATH, TEST POSITION  ";
    localparam [319:0] L2  = "ENABLED: PR127 PR128 PR129 PR130        ";
    localparam [319:0] L4  = "FALSE COLOURS: SHEET C IS NOT TRACED    ";
    localparam [319:0] L5  = "CODES: 1 BODY  2 TIRE  3 BL             ";
    localparam [319:0] LNL = "PROMS NOT LOADED                        ";
    localparam [319:0] LER = "PROM LOAD ERROR                         ";
    localparam [319:0] LEX = "EXPLO.ST HIGH DISABLES THE CAR PATH     ";
    localparam [191:0] L1T = "  B1 NEXT  B2 PREVIOUS  ";
    localparam [ 87:0] L3T = "           ";

    reg  [71:0] name;
    always @* begin
        case (state)
            2'd0: name = "NORMAL   ";
            2'd1: name = "SLIDE    ";
            2'd2: name = "ACCIDENT ";
            default: name = "EXPLOSION";
        endcase
    end
    wire [319:0] L1 = {"STATE: ", name, L1T};
    wire [319:0] L3 = {"VS/4=", 7'h18, vs4, " VS/8=", 7'h18, vs8,
                       " VS/16=", 7'h18, vs16, " VS/32=", 7'h18, vs32, L3T};

    // Text: 40 cells of 8x8 pixels from x=20; 5x7 ink per cell.
    wire [8:0] tx = x - 9'd20;
    wire [5:0] tcell = tx[8:3];
    reg  [2:0] tline;    // 0 = none
    reg  [8:0] ty;
    reg [319:0] text;
    always @* begin
        tline = 0; ty = 0; text = 0;
        if (x >= 20 && x < 340) begin
            if      (y >=   8 && y <  16) begin tline = 1; ty = y - 9'd8;   text = L0; end
            else if (y >=  24 && y <  32) begin tline = 2; ty = y - 9'd24;  text = L1; end
            else if (y >=  40 && y <  48) begin tline = 3; ty = y - 9'd40;  text = L2; end
            else if (y >=  56 && y <  64) begin tline = 4; ty = y - 9'd56;  text = L3; end
            else if (y >= 168 && y < 176 && (!loaded || load_error || state == 2'd3)) begin
                tline = 5; ty = y - 9'd168;
                text = load_error ? LER : !loaded ? LNL : LEX;
            end
            else if (y >= 200 && y < 208) begin tline = 6; ty = y - 9'd200; text = L4; end
            else if (y >= 216 && y < 224) begin tline = 7; ty = y - 9'd216; text = L5; end
        end
    end
    wire [5:0] cidx = tcell < 6'd40 ? 6'd39 - tcell : 6'd0;
    wire [7:0] ch = text[cidx*8 +: 8];
    wire ink;
    jtmonacogp_font u_font(.ch(ch), .row(ty[2:0]), .col(tx[2:0]), .pix(ink));

    // Line 3: one word per PROM, "PR127" starting at cell 9, six cells apart.
    wire [5:0] word_cell = tcell - 6'd9;
    wire [5:0] word = word_cell / 6'd6;      // 0..3 inside the four words
    wire in_word = tcell >= 9 && tcell < 32 && word_cell % 6'd6 < 6'd5;
    // Line 7: the code legends at cells 7-12, 15-20 and 23-26.
    wire [1:0] legend = tcell >= 7  && tcell < 13 ? 2'd1 :
                        tcell >= 15 && tcell < 21 ? 2'd2 :
                        tcell >= 23 && tcell < 27 ? 2'd3 : 2'd0;

    localparam [11:0] BACKGROUND = 12'h112, WINDOW = 12'h445,
                      BODY = 12'hfa0, TIRE = 12'h0bf, BL = 12'hf0b, SLICK = 12'h141,
                      TEXT = 12'hcdf, DIM = 12'h446, LIT = 12'hff4;
    always @* begin
        {red, green, blue} = 0;
        if (active) begin
            {red, green, blue} = BACKGROUND;
            if (loaded && !load_error) begin
                if (!strobe_n)      {red, green, blue} = WINDOW;
                if (!slide_n)       {red, green, blue} = SLICK;
                if (!player_body_n) {red, green, blue} = BODY;
                if (!tire_n)        {red, green, blue} = TIRE;
                if (!player_bl_n)   {red, green, blue} = BL;
            end
            if (tline != 0 && ink) begin
                {red, green, blue} = TEXT;
                if (tline == 3 && in_word)
                    {red, green, blue} = prom_en[word[1:0]] ? LIT : DIM;
                if (tline == 7)
                    case (legend)
                        2'd1: {red, green, blue} = BODY;
                        2'd2: {red, green, blue} = TIRE;
                        2'd3: {red, green, blue} = BL;
                        default: ;
                    endcase
            end
        end
    end
endmodule
