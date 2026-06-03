module jtargus_palette(
    input             rst,
    input             clk,

    input      [11:0] addr,
    input      [ 7:0] din,
    input             we,
    input             grey_en,

    // SDRAM
    output     [10:1] pxl_addr,
    output reg [15:0] pxl_din,
    output reg [ 1:0] pxl_dsn,
    output reg        pxl_cs,
    output reg        pxl_we,
    input             pxl_ok,


    input      [ 9:0] pxl,
    input      [ 9:0] blend_bg_pxl,
    input      [ 9:0] blend_obj_pxl,
    output reg [11:0] rgb,
    output reg [11:0] blend_bg_rgb,
    output reg [11:0] blend_obj_rgb,
    output reg [ 3:0] blend_alpha
);

reg  [15:0] raw_pal,  intensity;
reg  [11:0] pal0_addr, pal1_addr, pre0_addr, pre1_addr;
reg  [ 9:0] base_addr;
reg  [ 7:0] din_l;
reg  [ 3:0] sprb_din;
wire [ 7:0] pal0_dout, pal1_dout;
reg         pal0_we,   pal1_we, base_we,
            sprb_we,   int_we;

reg [11:0] base[0:10'h37f];
reg [ 3:0] spr_blend[0:7'h7f];
integer i;

assign pxl_addr = base_addr;

initial begin
    int_we    = 0;
    sprb_we   = 0;
    base_we   = 0;
    din_l     = 0;
    base_addr = 0;
    pal0_addr = 0;
    pal1_addr = 0;
    pal0_we   = 0;
    pal1_we   = 0;
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
    lookup_rgb = (addr>=10'h080 && addr<10'h180) ? bg_effect(raw) : raw; // only applies to bg0
end
endfunction

always @* begin
    pre0_addr = addr;
    pre1_addr = addr;

    if(addr[11:8]==0) begin
        pre0_addr[7] = 0;
        pre1_addr[7] = 1;
    end

    if(^addr[11:10]) begin
        pre0_addr[11:10] = 2'b01;
        pre1_addr[11:10] = 2'b10;
    end
    raw_pal = { pal0_dout, pal1_dout };
    if(pal0_we) raw_pal[15:8] = din_l;
    if(pal1_we) raw_pal[ 7:0] = din_l;
end

always @(posedge clk) begin
    int_we    <= 0;
    sprb_we   <= 0;
    base_we   <= 0;
    pal0_we   <= 0;
    pal1_we   <= 0;
    din_l     <= din;
    base_addr <= addr[9:0];

    if(we) begin
        pal0_addr <= pre0_addr;
        pal1_addr <= pre1_addr;
        pal0_we   <= addr[11:7]==pre0_addr[11:7];
        pal1_we   <= addr[11:7]==pre1_addr[11:7];
        // Sprites
        if( addr[11:8]==0 ) begin
            base_addr <= {3'd0,addr[6:0]};
            base_we   <= 1;
            sprb_we   <= 1;
            int_we    <= &addr[6:0];
        end
        // BG0
        if(addr[11:8]==4'h4 || addr[11:8]==4'h8) begin
            base_we <= 1;
            base_addr <= 10'h080+{2'd0,addr[7:0]};
        end
        // BG1
        if(addr[11:8]==4'h5 || addr[11:8]==4'h9) begin
            base_we <= 1;
            base_addr <= 10'h180+{2'd0,addr[7:0]};
        end
        // Txt
        if(addr[11:8]==4'h7 || addr[11:8]==4'hb) begin
            base_we <= 1;
            base_addr <= 10'h280+{2'd0,addr[7:0]};
        end
    end
end

always @* begin
    rgb           = lookup_rgb(pxl);
    blend_bg_rgb  = lookup_rgb(blend_bg_pxl);
    blend_obj_rgb = base[blend_obj_pxl]; // lookup_rgb(blend_obj_pxl);
    blend_alpha   = blend_obj_pxl<10'h080 ? spr_blend[blend_obj_pxl[6:0]] : 4'd0;
end

always @( posedge clk) begin
    if( rst ) begin
        intensity <= 16'd0;
        for(i=0;i<10'h380;i=i+1) base[i] <= 12'd0;
        for(i=0;i<128;    i=i+1) spr_blend[i] <= 4'd0;
        pxl_cs  <= 0;
        pxl_we  <= 0;
        pxl_dsn <= 2'b11;
        pxl_din <= 0;
    end else begin
        if(pxl_ok) begin
            pxl_cs  <= 0;
            pxl_we  <= 0;
            pxl_dsn <= 2'b11;
        end
        if(base_we) begin
            base[base_addr] <= raw_pal[15:4];
            pxl_din[15:4] <= raw_pal[15:4];
            pxl_din[ 3:0] <= sprb_we ? raw_pal[3:0] : 4'b0;
            pxl_we  <= 1;
            pxl_cs  <= 1;
            pxl_dsn <= 2'b00;
        end
        if(int_we ) intensity       <= raw_pal;
        if(sprb_we) spr_blend[base_addr[6:0]] <= raw_pal[3:0];
    end
end

jtframe_dual_ram #(
    .AW(12)
) u_palram(
    // Port 0 - pal lo
    .clk0   ( clk       ),
    .addr0  ( pal0_addr ),
    .data0  ( din_l     ),
    .we0    ( pal0_we   ),
    .q0     ( pal0_dout ),
    // Port 1 - pal hi
    .clk1   ( clk       ),
    .data1  ( din_l     ),
    .addr1  ( pal1_addr ),
    .we1    ( pal1_we   ),
    .q1     ( pal1_dout )
);

endmodule
