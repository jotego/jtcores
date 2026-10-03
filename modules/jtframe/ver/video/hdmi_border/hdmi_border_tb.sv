`timescale 1ns/1ps
// Focused, unrotated scan2x + SiDi128 HDMI OSD diagnostic.
// Synthetic 384x264 raster, 288x224 active. No game CPU/audio instantiated.
module hdmi_border_tb;
reg clk=0;
always #5 clk=~clk;
reg [2:0] div=0;
always @(posedge clk) div<=div+1'b1;
integer pephase=7;
wire pe=div==pephase, pe2=div[1:0]==3;
integer h=0,v=0,frames=0,vphase=319;
reg rst=1;
reg vb=1;
wire hb=h>=288;
wire hs=h>=320 && h<352;
wire vs=v>=256;
wire [23:0] pattern=(!hb && !vb) ? {7'd0,(h<256 ? 1'b0:1'b1),h[7:0],v[7:0]}+24'h010001 : 24'd0;
wire [23:0] rgb,hdmi;
reg [23:0] pd[0:8];
reg [8:0] hbd=9'h1ff,vbd=9'h1ff;
integer k;
always @(posedge clk) if(pe) begin
    pd[0]<=pattern;
    for(k=1;k<9;k=k+1) pd[k]<=pd[k-1];
    hbd<={hbd[7:0],hb};vbd<={vbd[7:0],vb};
end
wire de,ohs,ovs,hde,hhs,hvs;
initial begin
    if($value$plusargs("vphase=%d",vphase)) begin end
    if($value$plusargs("pephase=%d",pephase)) begin end
    $dumpfile("hdmi_border.vcd");
    $dumpvars(0,hdmi_border_tb);
    $dumpoff;
    #100 rst=0;
end
always @(posedge clk) if(pe) begin
    h<=h==383 ? 0:h+1;
    if(h==319) begin
        v<=v==263 ? 0:v+1;
        if(v==263) frames<=frames+1;
    end
    if(h==vphase) begin
        if(v==15) vb<=0;
        if(v==239) vb<=1;
    end
    if(frames==2 && v==16 && h==0) $dumpon;
    if(frames==2 && v==18 && h==0) $dumpoff;
    if(frames==4) $finish;
end
jtframe_scan2x #(.COLORW(8),.HLEN(384)) scan(
    .clk(clk),.rst(rst),.pxl_cen(pe),.pxl2_cen(pe2),
    .enb(1'b0),.sl_mode(2'd0),.blend_en(1'b0),.rotation(2'd0),
    .hfilter(1'b0),.vfilter(1'b0),.init(1'b0),
    .x1_pxl(pd[8]),.x1_hs(hs),.x1_vs(vs),.x1_hb(hbd[8]),.x1_vb(vbd[8]),
    .x2_pxl(rgb),.x2_de(de),.x2_hs(ohs),.x2_vs(ovs));
osd #(.OSD_DW(8)) hdmi_osd(
    .clk_sys(clk),.SPI_DI(1'b0),.SPI_SCK(1'b0),.SPI_SS3(1'b1),.rotate(2'd0),
    .R_in(rgb[23:16]),.G_in(rgb[15:8]),.B_in(rgb[7:0]),
    .DE(de),.HSync(ohs),.VSync(ovs),
    .R_out(hdmi[23:16]),.G_out(hdmi[15:8]),.B_out(hdmi[7:0]),
    .DE_out(hde),.HSync_out(hhs),.VSync_out(hvs));
integer n=0,black=0,lines=0,firstx=-1,lastx=-1,firstrow=-1,lastrow=-1;
reg prevde=0,prevvs=0;
// One sample per doubled pixel, after scan2x and OSD registers settle.
always @(posedge clk) if(pe2) begin
    #11;
    if(hde) begin
        n=n+1;
        if(hdmi==0) black=black+1;
        else begin
            if(firstx<0) begin firstx=hdmi[23:8]-256; firstrow=hdmi[7:0]-1; end
            lastx=hdmi[23:8]-256; lastrow=hdmi[7:0]-1;
        end
    end
    if(prevde && !hde) begin
        if(frames>=2) $display("LINE phase=%0d line=%0d width=%0d black=%0d x=%0d..%0d row=%0d..%0d",vphase,lines,n,black,firstx,lastx,firstrow,lastrow);
        if(frames>=2 && (n!=288 || black!=0 || firstx!=0 || lastx!=287 || firstrow!=lastrow))
            $fatal(1,"Incomplete or misaligned active line");
        if(frames>=2 && firstrow != (vphase>319 ? 15:16)+lines/2)
            $fatal(1,"Missing, reordered or incorrectly repeated source row");
        lines=lines+1; n=0;black=0;firstx=-1;lastx=-1;firstrow=-1;lastrow=-1;
    end
    if(hvs && !prevvs) begin
        if(frames>=2) $display("FRAME phase=%0d active_lines=%0d",vphase,lines);
        if(frames>=2 && lines!=448) $fatal(1,"Expected 448 active lines");
        lines=0;
    end
    prevde=hde;prevvs=hvs;
end
integer samples=0,zeros=0,first_samples=0,last_samples=0;
reg lastde=0;
always @(posedge clk) begin
    #1;
    if(hde) begin
        samples=samples+1;
        if(frames>=2 && hdmi[23:8]-256 != (samples-1)/4)
            $fatal(1,"Missing, reordered or incorrectly repeated source column");
        if(hdmi==0) zeros=zeros+1;
        if(hdmi[23:8]==256) first_samples=first_samples+1;
        if(hdmi[23:8]==543) last_samples=last_samples+1;
    end
    if(lastde && !hde) begin
        if(frames==2 && v==100) $display("HDMI phase=%0d samples=%0d black=%0d first_pixel_samples=%0d last_pixel_samples=%0d",vphase,samples,zeros,first_samples,last_samples);
        if(frames>=2 && (samples!=1152 || zeros!=0 || first_samples!=4 || last_samples!=4))
            $fatal(1,"Missing pixels at HDMI sample rate");
        samples=0;zeros=0;first_samples=0;last_samples=0;
    end
    lastde=hde;
end
endmodule
