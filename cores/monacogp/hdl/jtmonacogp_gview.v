// SPDX-License-Identifier: GPL-3.0-or-later
// Development view of the connected sheets A, B, D, F, G, H and M. With
// real_colour the picture is sheet C's (jtmonacogp_colour.v); otherwise the
// colours and their order are FALSE, except sheet B's two texts (as seen on
// the real game). Captions are
// development aids, not game artwork. Every picture input is for the
// previous pixel (sheets D and H register theirs so, and the game module
// delays sheets B and G by one pixel to match), so the picture sits one
// pixel to the right of the raster position.
module jtmonacogp_gview(
    input      [8:0] x, y,
    input            active,
    input            loaded, load_error,
    // Status
    input      [3:0] t_tens, t_units,   // sheet A timer (display, sheet J)
    input            game, coin_in, extend, credit_lamp,
    input      [3:0] acce,              // sheet F
    input            high_gear,
    input      [3:0] s100,
    // Sheet B
    input            ex_gameover_n, coin_start_n,
    // Sheet D
    input            road, green_belt_n, grass_area_n, grass_w_n,
    input            tree_grass_bl_n, tree_grass_g_n, gravel_n, pool_n, wall_n,
    input      [3:0] house_n,
    input            slip_n, y_line_n, side_line_n,
    // Sheet H
    input            other_car_n, other_body_n, other_tiar_n,
    // Sheet M
    input            rescue_bl_n, rescue_r_n, rescue_w_n, rescue_y_n,
    input            sig_y_n, sig_bl_n, dummy_w_n, dummy_r_n, dummy_bl_n,
    input            bridge_w_n, bridge_dbu_n, bridge_y_n, bridge_r_n, bridge_bu_n,
    // Sheet G
    input            player_body_n, tire_n, player_bl_n,
    // Sheet C's colour, shown instead of the false colours when real_colour
    input            real_colour,
    input      [3:0] c_red, c_green, c_blue,
    input            dev_text,          // the two caption lines (development only)
    output reg [3:0] red, green, blue
);
    localparam [319:0] LH  = "COIN B1 PEDAL  B2 UP DOWN GEAR  ST2 S100";
    localparam [319:0] LNL = "PROMS NOT LOADED                        ";
    localparam [319:0] LER = "PROM LOAD ERROR                         ";

    function [7:0] digit(input [3:0] d);
        digit = d > 4'd9 ? "?" : "0" + {4'd0, d};
    endfunction
    wire [7:0]  code_ch = s100 == 4'hf ? "-" : digit(s100);
    wire [15:0] acce_ch = {acce >= 4'd10 ? "1" : "0", digit(acce >= 4'd10 ? acce - 4'd10 : acce)};
    wire [31:0] game_w  = game ? "GAME" : coin_in ? "COIN" : "    ";
    wire [15:0] gear_w  = high_gear ? "HI" : "LO";
    // 40 characters: "TIME 90 GAME ACCE 07 HI S100 - EXT CR   "
    wire [319:0] LS = {"TIME ", digit(t_tens), digit(t_units), " ", game_w, " ACCE ", acce_ch,
                       " ", gear_w, " S100 ", code_ch, extend ? " EXT" : "    ",
                       credit_lamp ? " CR" : "   ", "   "};

    // Text: 40 cells of 8x8 pixels from x=20; 5x7 ink per cell.
    wire [8:0] tx = x - 9'd20;
    wire [5:0] tcell = tx[8:3];
    reg        tline;
    reg  [8:0] ty;
    reg [319:0] text;
    always @* begin
        tline = 0; ty = 0; text = 0;
        if (x >= 20 && x < 340) begin
            if      (y >=   0 && y <   8 && dev_text) begin tline = 1; ty = y; text = LS; end
            else if (y >= 120 && y < 128 && (!loaded || load_error)) begin
                tline = 1; ty = y - 9'd120; text = load_error ? LER : LNL;
            end
            else if (y >= 232 && y < 240 && dev_text) begin tline = 1; ty = y - 9'd232; text = LH; end
        end
    end
    wire [5:0] cidx = tcell < 6'd40 ? 6'd39 - tcell : 6'd0;
    wire [7:0] ch = text[cidx*8 +: 8];
    wire ink;
    jtmonacogp_font u_font(.ch(ch), .row(ty[2:0]), .col(tx[2:0]), .pix(ink));

    // Scenery as in jtmonacogp_sview; sheet M's bridge, signs, spare cars and
    // rescue car, each in the colour of its label; other cars; the player car
    // as in jtmonacogp_pview.
    localparam [11:0] ROAD = 12'h333, GREEN_BELT = 12'h570, GRASS_AREA = 12'h141,
                      GRASS_W = 12'h8f8, TG_BL = 12'h066, TG_G = 12'h0c0, GRAVEL = 12'hca6,
                      POOL = 12'h24f, WALL = 12'hf80, HOUSE_R = 12'hf00, HOUSE_MU = 12'hf0f,
                      HOUSE_ST = 12'h840, HOUSE_W = 12'hfff, SLIP = 12'h0ff, Y_LINE = 12'hff0,
                      SIDE_LINE = 12'heee, MSG_TOP = 12'hf22, MSG_BOTTOM = 12'h44f, TEXT = 12'hcdf, TEXT_BG = 12'h000,
                      BR_W = 12'hddd, BR_DBU = 12'h00a, BR_Y = 12'hcc0, BR_R = 12'hc00, BR_BU = 12'h46f,
                      SG_Y = 12'hfd0, SG_BL = 12'h06f, DM_W = 12'hfff, DM_R = 12'hf44, DM_BL = 12'h44f,
                      RS_BL = 12'h22f, RS_R = 12'hf22, RS_W = 12'hfff, RS_Y = 12'hff0,
                      O_CAR = 12'hc00, O_BODY = 12'hf66, O_TIAR = 12'hfff,
                      P_BODY = 12'hfa0, P_TIRE = 12'h0bf, P_BL = 12'hf0b;
    always @* begin
        {red, green, blue} = 0;
        if (active) begin
            if (loaded && !load_error) begin
                // A later line covers an earlier one.
                if (road)             {red, green, blue} = ROAD;
                if (!green_belt_n)    {red, green, blue} = GREEN_BELT;
                if (!grass_area_n)    {red, green, blue} = GRASS_AREA;
                if (!grass_w_n)       {red, green, blue} = GRASS_W;
                if (!tree_grass_bl_n) {red, green, blue} = TG_BL;
                if (!tree_grass_g_n)  {red, green, blue} = TG_G;
                if (!gravel_n)        {red, green, blue} = GRAVEL;
                if (!pool_n)          {red, green, blue} = POOL;
                if (!wall_n)          {red, green, blue} = WALL;
                if (!house_n[0])      {red, green, blue} = HOUSE_R;
                if (!house_n[1])      {red, green, blue} = HOUSE_MU;
                if (!house_n[2])      {red, green, blue} = HOUSE_ST;
                if (!house_n[3])      {red, green, blue} = HOUSE_W;
                if (!slip_n)          {red, green, blue} = SLIP;
                if (!y_line_n)        {red, green, blue} = Y_LINE;
                if (!side_line_n)     {red, green, blue} = SIDE_LINE;
                if (!bridge_bu_n)     {red, green, blue} = BR_BU;
                if (!bridge_r_n)      {red, green, blue} = BR_R;
                if (!bridge_y_n)      {red, green, blue} = BR_Y;
                if (!bridge_dbu_n)    {red, green, blue} = BR_DBU;
                if (!bridge_w_n)      {red, green, blue} = BR_W;
                if (!sig_bl_n)        {red, green, blue} = SG_BL;
                if (!sig_y_n)         {red, green, blue} = SG_Y;
                if (!dummy_bl_n)      {red, green, blue} = DM_BL;
                if (!dummy_r_n)       {red, green, blue} = DM_R;
                if (!dummy_w_n)       {red, green, blue} = DM_W;
                if (!rescue_bl_n)     {red, green, blue} = RS_BL;
                if (!rescue_r_n)      {red, green, blue} = RS_R;
                if (!rescue_w_n)      {red, green, blue} = RS_W;
                if (!rescue_y_n)      {red, green, blue} = RS_Y;
                if (!other_car_n)     {red, green, blue} = O_CAR;
                if (!other_body_n)    {red, green, blue} = O_BODY;
                if (!other_tiar_n)    {red, green, blue} = O_TIAR;
                if (!player_body_n)   {red, green, blue} = P_BODY;
                if (!tire_n)          {red, green, blue} = P_TIRE;
                if (!player_bl_n)     {red, green, blue} = P_BL;
                // Sheet B's text: red GAME OVER / EXTENDED PLAY and blue
                // DEPOSIT COIN / START, the colours of the real game (Aldo)
                if (!ex_gameover_n)   {red, green, blue} = MSG_TOP;
                if (!coin_start_n)    {red, green, blue} = MSG_BOTTOM;
                if (real_colour)      {red, green, blue} = {c_red, c_green, c_blue};
            end
            if (tline) {red, green, blue} = ink ? TEXT : TEXT_BG;
        end
    end
endmodule
