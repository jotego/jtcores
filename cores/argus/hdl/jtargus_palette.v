module jtargus_palette(
    input             rst,
    input             clk,

    input      [11:0] addr,
    input      [ 7:0] din,
    input             we,
    input             grey_en,

    input      [ 9:0] pxl,
    input      [ 9:0] blend_bg_pxl,
    input      [ 9:0] blend_obj_pxl,
    output reg [11:0] rgb,
    output reg [11:0] blend_bg_rgb,
    output reg [11:0] blend_obj_rgb,
    output reg [ 3:0] blend_alpha
);

reg [ 7:0] palram[0:12'hbff];
reg [11:0] base[0:10'h37f];
reg [ 3:0] spr_blend[0:7'h7f];
reg [15:0] intensity;

integer i;

function [7:0] rd;
    input [11:0] a;
begin
    rd = (we && addr==a) ? din : palram[a];
end
endfunction

function [3:0] rd_lo;
    input [11:0] a;
    reg   [ 7:0] data;
begin
    data  = rd(a);
    rd_lo = data[3:0];
end
endfunction

function [11:0] raw_rgb;
    input [ 7:0] lo;
    input [ 7:0] hi;
begin
    raw_rgb = { lo[7:4], lo[3:0], hi[7:4] };
end
endfunction

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
    input [3:0] rgb;
    input [3:0] delta;
    input       subtract;
begin
    blend4 = subtract ? sub4(rgb,delta) : add4(rgb,delta);
end
endfunction

function [3:0] avg3;
    input [3:0] r;
    input [3:0] g;
    input [3:0] b;
    reg   [5:0] sum;
    reg   [5:0] avg;
begin
    sum  = {2'b0,r} + {2'b0,g} + {2'b0,b};
    avg  = sum / 6'd3;
    avg3 = avg[3:0];
end
endfunction

function [11:0] bg_effect;
    input [11:0] src;
    reg   [11:0] tmp;
    reg   [ 3:0] grey;
begin
    tmp = src;
    if( grey_en ) begin
        grey = avg3(tmp[11:8], tmp[7:4], tmp[3:0]);
        tmp  = { grey, grey, grey };
    end
    tmp[11:8] = blend4(tmp[11:8], intensity[15:12], intensity[2]);
    tmp[ 7:4] = blend4(tmp[ 7:4], intensity[11: 8], intensity[1]);
    tmp[ 3:0] = blend4(tmp[ 3:0], intensity[ 7: 4], intensity[0]);
    bg_effect = tmp;
end
endfunction

function [11:0] lookup_rgb;
    input [9:0] addr;
    reg [11:0] raw;
begin
    raw = addr<=10'h37f ? base[addr] : 12'd0;
    lookup_rgb = (addr>=10'h080 && addr<10'h180) ? bg_effect(raw) : raw;
end
endfunction

always @(posedge clk) begin
    if( rst ) begin
        intensity <= 16'd0;
        for(i=0;i<12'hc00;i=i+1) palram[i] <= 8'd0;
        for(i=0;i<10'h380;i=i+1) base[i] <= 12'd0;
        for(i=0;i<128;i=i+1) spr_blend[i] <= 4'd0;
    end else if( we ) begin
        palram[addr] <= din;
        if( addr<=12'h0ff ) begin
            base[{3'd0,addr[6:0]}] <= raw_rgb(rd({5'd0,addr[6:0]}), rd({5'd0,addr[6:0]}+12'h080));
            spr_blend[addr[6:0]] <= rd_lo({5'd0,addr[6:0]}+12'h080);
            if( addr==12'h07f || addr==12'h0ff )
                intensity <= {rd(12'h07f),rd(12'h0ff)};
        end

        if( (addr>=12'h400 && addr<=12'h4ff) || (addr>=12'h800 && addr<=12'h8ff) ) begin
            base[10'h080+{2'd0,addr[7:0]}] <= raw_rgb(rd(12'h400+{4'd0,addr[7:0]}), rd(12'h800+{4'd0,addr[7:0]}));
        end

        if( (addr>=12'h500 && addr<=12'h5ff) || (addr>=12'h900 && addr<=12'h9ff) ) begin
            base[10'h180+{2'd0,addr[7:0]}] <= raw_rgb(rd(12'h500+{4'd0,addr[7:0]}), rd(12'h900+{4'd0,addr[7:0]}));
        end

        if( (addr>=12'h700 && addr<=12'h7ff) || (addr>=12'hb00 && addr<=12'hbff) ) begin
            base[10'h280+{2'd0,addr[7:0]}] <= raw_rgb(rd(12'h700+{4'd0,addr[7:0]}), rd(12'hb00+{4'd0,addr[7:0]}));
        end
    end
end

always @* begin
    rgb           = lookup_rgb(pxl);
    blend_bg_rgb  = lookup_rgb(blend_bg_pxl);
    blend_obj_rgb = lookup_rgb(blend_obj_pxl);
    blend_alpha   = blend_obj_pxl<10'h080 ? spr_blend[blend_obj_pxl[6:0]] : 4'd0;
end

endmodule
