`timescale 1ns/1ps

module test;

reg clk, pxl_cen;
reg [4:0] clip;
reg [0:0] v_en=0,h_en=0, wd=0,fin=0;

wire LHBL, LVBL, lhbs, lvbs, HS;

initial begin
    clk = 0;
    pxl_cen = 0;
    forever #(83.333/2) clk = ~clk;
end

//initial #(16600*1000*4) $finish;

reg [4:0] left=0, right=0, down=0, up=0;

always @(posedge clk) pxl_cen <= ~pxl_cen;

integer hcnt=0, vcnt=0, framecnt=0, change=0;

always @(*) begin
    clip = !v_en&&!h_en? 0 : wd? 16 : 8;
end

always @(posedge clk) if(pxl_cen) begin
    hcnt <= hcnt==383 ? 0 : hcnt + 1;
    if( hcnt == 256+32 )  begin
        vcnt <= vcnt+1;
        if( vcnt == 224 ) begin
            framecnt <= framecnt + 1;
            change <= change+1;
        end
        if( vcnt == 256 ) vcnt <= 0;
    end
    if( change == 3 ) begin
        change <= 0;
        //en_wd <= en_wd+1;
        {fin,wd,v_en,h_en} <= {fin,wd,v_en,h_en}+3'd1;
        //$display("Change \nFrame=%d  en=%b  wide=%b  Clip=%d",
            //framecnt, en_wd[1], en_wd[0], clip);
        //$display("Horizontal count = %d",pxl_cnt);
    end;
    if (fin) $finish;
end

reg [4:0] hs_cnt;

always @(posedge HS) begin
    if (!lvbs && LVBL) hs_cnt<=hs_cnt+1;
    if (lvbs==LVBL) begin
        if (hs_cnt != 0) begin       
            if (lvbs)    up <= hs_cnt;
            if (!lvbs) down <= hs_cnt;
        end
        hs_cnt <=0;
    end
end

reg [4:0] pxl_cnt;

always @(posedge clk) if (pxl_cen) begin
    if (!lhbs && LHBL) pxl_cnt<=pxl_cnt+1;
    if (lhbs==LHBL) begin
        pxl_cnt <=0;
        if (pxl_cnt != 0) begin
            if (lhbs)  right <= pxl_cnt;
            if (!lhbs) left  <= pxl_cnt;
        end
    end
end


initial begin
    #10 $display("-----------------------------------------------------------------------------------------\n",
        "|\tH_Enable\tV_Enable\tWide\tLeft\tRight\tDown\tUp\tExpected|");
    $monitor("|\t%b\t\t%b\t\t%b\t%d\t%d\t%d\t%d\t%d\t|", 
        h_en,v_en, wd, left, right,down,up,clip);
end

//always @(lhbs == LHBL) if (pxl_cnt!= 0) $display("Horizontal count = %d",pxl_cnt);

jtframe_vtimer #(
    .HCNT_START ( 9'h020    ),
    .HCNT_END   ( 9'h19F    ),
    .HB_START   ( 9'h19F    ),
    .HB_END     ( 9'h05F    ),  // 10.6 us
    .HS_START   ( 9'h039    ),
    .HS_END     ( 9'h059    ),  //  5.33 us

    .V_START    ( 9'h0F8    ),
    .VB_START   ( 9'h1F0    ),
    .VB_END     ( 9'h110    ),  //  2.56 ms
    .VS_START   ( 9'h1FF    ),
    .VS_END     ( 9'h0FF    ),
    .VCNT_END   ( 9'h1FF    )   // 16.896 ms (59.18Hz)
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      (           ),
    .vrender    (           ),
    .vrender1   (           ),
    .H          (           ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       (  LHBL     ),
    .LVBL       (  LVBL     ),
    .HS         (  HS       ),
    .VS         (           )
);

jtframe_short_blank #(
    .WIDTH (384),
    .HEIGHT (264)
) u_short_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .h_en       ( h_en[0]   ),
    .v_en       ( v_en[0]   ),
    .wide       ( wd[0]     ),
    .HS         ( HS        ),
    .hb_out     (   lhbs    ),
    .vb_out     (   lvbs    )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
end

endmodule