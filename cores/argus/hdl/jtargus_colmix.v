module jtargus_colmix(
    input             clk,
    input             pxl_cen,
    input             blankn,
    input             bg1_en,
    input      [ 7:0] bg0_pxl,
    input      [ 7:0] bg1_pxl,
    input      [ 7:0] tx_pxl,
    input      [ 8:0] obj_pxl,
    output reg [ 9:0] pal_pxl,
    output reg [ 9:0] blend_bg_pxl,
    output reg [ 9:0] blend_obj_pxl,
    input      [11:0] pal_rgb,
    input      [11:0] blend_bg_rgb,
    input      [11:0] blend_obj_rgb,
    input      [ 3:0] blend_alpha,
    output reg [ 3:0] red,
    output reg [ 3:0] green,
    output reg [ 3:0] blue,
    input      [ 3:0] gfx_en
);

wire bg0_opaque = bg0_pxl[3:0] != 4'hf;
wire bg1_opaque = bg1_en && bg1_pxl[3:0] != 4'hf;
wire tx_opaque  = tx_pxl [3:0] != 4'hf;
wire obj_opaque = obj_pxl[3:0] != 4'hf;
wire obj_pri    = obj_pxl[7];
wire obj_mask   = obj_pxl[8];
wire obj_draw   = obj_opaque && !(obj_mask && !bg1_opaque);
wire [9:0] bg0_pal = 10'h080 + {2'd0,bg0_pxl};
wire [9:0] bg1_pal = 10'h180 + {2'd0,bg1_pxl};
wire [9:0] tx_pal  = 10'h280 + {2'd0,tx_pxl};
wire [9:0] obj_pal = {3'd0,obj_pxl[6:0]};

reg        blend_sel;
reg        blend_sel_l, blankn_l;
reg [11:0] rgb_mux;

initial begin
    blend_sel_l = 1'b0;
    blankn_l    = 1'b0;
end

function [3:0] sub4;
    input [3:0] a;
    input [3:0] b;
begin
    sub4 = a>b ? a-b : 4'd0;
end
endfunction

function [3:0] add4;
    input [3:0] a;
    input [3:0] b;
    reg   [4:0] sum;
begin
    sum  = {1'b0,a} + {1'b0,b};
    add4 = sum[4] ? 4'hf : sum[3:0];
end
endfunction

function [3:0] blend4;
    input [3:0] bg;
    input [3:0] obj;
    input       subtract;
begin
    blend4 = subtract ? sub4(bg,obj) : add4(bg,obj);
end
endfunction

function [11:0] blend_rgb;
    input [11:0] bg;
    input [11:0] obj;
    input [ 3:0] alpha;
begin
    blend_rgb[11:8] = blend4(bg[11:8], obj[11:8], alpha[2]);
    blend_rgb[ 7:4] = blend4(bg[ 7:4], obj[ 7:4], alpha[1]);
    blend_rgb[ 3:0] = blend4(bg[ 3:0], obj[ 3:0], alpha[0]);
end
endfunction

always @* begin
    pal_pxl       = bg0_pal;
    blend_bg_pxl  = bg0_pal;
    blend_obj_pxl = obj_pal;
    blend_sel     = 1'b0;

    if( gfx_en[0] && obj_draw && obj_pri ) begin
        pal_pxl      = obj_pal;
        blend_bg_pxl = bg0_pal;
        blend_sel    = blend_alpha != 4'd0;
    end
    if( gfx_en[2] && bg1_opaque ) begin
        pal_pxl   = bg1_pal;
        blend_sel = 1'b0;
    end
    if( gfx_en[0] && obj_draw && !obj_pri ) begin
        pal_pxl      = obj_pal;
        blend_bg_pxl = (gfx_en[2] && bg1_opaque) ? bg1_pal : bg0_pal;
        blend_sel    = blend_alpha != 4'd0;
    end
    if( gfx_en[3] && tx_opaque ) begin
        pal_pxl   = tx_pal;
        blend_sel = 1'b0;
    end
    if( !blankn ) begin
        pal_pxl   = 10'd0;
        blend_sel = 1'b0;
    end

    rgb_mux = blend_sel_l ? blend_rgb(blend_bg_rgb, blend_obj_rgb, blend_alpha) : pal_rgb;
end

always @(posedge clk) if( pxl_cen ) begin
    blend_sel_l      <= blend_sel;
    blankn_l         <= blankn;
    {red,green,blue} <= blankn_l ? rgb_mux : 12'd0;
end

endmodule
