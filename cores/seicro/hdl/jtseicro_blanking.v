module jtseicro_blanking(
    input            rst, clk,
    input            vblk, v0,
    input      [8:0] h,
    output reg       palette_clr_n, color_clr_n,
    output           data_blank,
    output reg       bank_blank, bank_sel
);

wire palette_clk = v0 & h[4];
wire eft3_n = !(h[0] & h[1] & h[2] & !h[3]);
reg palette_clk_l, eft3_l, h2_l, h3_l;
reg hblank_latched, vblk_latched;

assign data_blank = hblank_latched | vblk_latched;

always @(posedge clk) begin
    palette_clk_l <= palette_clk;
    eft3_l <= eft3_n;
    h2_l <= h[2];
    h3_l <= h[3];
    if(rst) begin
        palette_clr_n <= 0;
        color_clr_n <= 0;
        hblank_latched <= 1;
        vblk_latched <= 1;
        bank_blank <= 1;
        bank_sel <= 0;
    end else begin
        if(palette_clk && !palette_clk_l) palette_clr_n <= !vblk;
        if(eft3_n && !eft3_l) color_clr_n <= !vblk;
        if(h[2] && !h2_l) begin
            hblank_latched <= !h[8];
            vblk_latched <= vblk;
        end
        if(h[3] && !h3_l) begin
            bank_blank <= hblank_latched;
            if(hblank_latched && !bank_blank) bank_sel <= ~bank_sel;
        end
    end
end

endmodule
