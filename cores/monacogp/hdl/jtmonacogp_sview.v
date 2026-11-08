// SPDX-License-Identifier: GPL-3.0-or-later
// Development view of the sheet B text and sheet D scenery outputs. The
// colours are FALSE colours, the same as in tests/tb_scenery.v: the sheet C
// video mixer that gives the outputs their real colour and priority is not
// traced yet. Captions are development aids, not game artwork.
// Sheet D's outputs are registered for the previous pixel, so its picture
// sits one pixel to the right of the raster position; sheet B's text does not.
module jtmonacogp_sview(
    input      [8:0] x, y,
    input            active,
    input            loaded, load_error,
    input      [3:0] s100, sp,
    input            in_reset_n,
    // Sheet B
    input            ex_gameover_n, coin_start_n,
    // Sheet D
    input            road, green_belt_n, grass_area_n, grass_w_n,
    input            tree_grass_bl_n, tree_grass_g_n, gravel_n, pool_n, wall_n,
    input      [3:0] house_n,
    input            slip_n, y_line_n, side_line_n,
    output reg [3:0] red, green, blue
);
    localparam [319:0] L0  = "SHEETS B AND D, ROAD AND SCENERY        ";
    localparam [319:0] L2  = "B1 B2 S-100  UP DOWN SP  RIGHT LEFT ROAD";
    localparam [319:0] L3  = "FALSE COLOURS: SHEET C IS NOT TRACED    ";
    localparam [319:0] LNL = "PROMS NOT LOADED                        ";
    localparam [319:0] LER = "PROM LOAD ERROR                         ";
    localparam [95:0]  L1T = "            ";

    wire [7:0] code_ch = s100 == 4'hf ? "-" : "0" + {4'd0, s100};
    wire [15:0] sp_ch = {sp >= 4'd10 ? "1" : "0", "0" + {4'd0, sp >= 4'd10 ? sp - 4'd10 : sp}};
    wire [55:0] road_w = in_reset_n ? "NORMAL " : "MOVING ";
    wire [319:0] L1 = {"S-100=", code_ch, "  SP=", sp_ch, "  ROAD ", road_w, L1T};

    // Text: 40 cells of 8x8 pixels from x=20; 5x7 ink per cell.
    wire [8:0] tx = x - 9'd20;
    wire [5:0] tcell = tx[8:3];
    reg        tline;
    reg  [8:0] ty;
    reg [319:0] text;
    always @* begin
        tline = 0; ty = 0; text = 0;
        if (x >= 20 && x < 340) begin
            if      (y >=   8 && y <  16) begin tline = 1; ty = y - 9'd8;   text = L0; end
            else if (y >=  24 && y <  32) begin tline = 1; ty = y - 9'd24;  text = L1; end
            else if (y >=  40 && y <  48) begin tline = 1; ty = y - 9'd40;  text = L2; end
            else if (y >= 120 && y < 128 && (!loaded || load_error)) begin
                tline = 1; ty = y - 9'd120; text = load_error ? LER : LNL;
            end
            else if (y >= 216 && y < 224) begin tline = 1; ty = y - 9'd216; text = L3; end
        end
    end
    wire [5:0] cidx = tcell < 6'd40 ? 6'd39 - tcell : 6'd0;
    wire [7:0] ch = text[cidx*8 +: 8];
    wire ink;
    jtmonacogp_font u_font(.ch(ch), .row(ty[2:0]), .col(tx[2:0]), .pix(ink));

    localparam [11:0] ROAD = 12'h333, GREEN_BELT = 12'h570, GRASS_AREA = 12'h141,
                      GRASS_W = 12'h8f8, TG_BL = 12'h066, TG_G = 12'h0c0, GRAVEL = 12'hca6,
                      POOL = 12'h24f, WALL = 12'hf80, HOUSE_R = 12'hf00, HOUSE_MU = 12'hf0f,
                      HOUSE_ST = 12'h840, HOUSE_W = 12'hfff, SLIP = 12'h0ff, Y_LINE = 12'hff0,
                      SIDE_LINE = 12'heee, MESSAGE = 12'hf8c, TEXT = 12'hcdf;
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
                if (!ex_gameover_n || !coin_start_n) {red, green, blue} = MESSAGE;
            end
            if (tline && ink) {red, green, blue} = TEXT;
        end
    end
endmodule
