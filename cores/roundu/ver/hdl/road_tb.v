/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-10-2026 */

`timescale 1ns/1ps
module road_tb;
reg clk=0, rst=1;
reg [2:0] phase=0;
reg [8:0] h=0,v=0;
wire pxl_cen=phase==0;
wire [11:1] ctrl_addr,pixel_addr,color_addr;
reg [15:0] ctrl_data,pixel_data,color_data;
reg [15:0] controls [0:2047],pixels [0:2047],colors [0:2047];
reg [9:0] expected [0:76799];
wire [8:0] pxl;
wire solid;
integer bank=0,enabled=1,frames=0,x,y,checked=0,n;
reg [9:0] value;

jtroundu_road u_road (
    .rst        ( rst         ),
    .clk        ( clk         ),
    .pxl_cen    ( pxl_cen     ),
    .h          ( h           ),
    .v          ( v           ),
    .enable     ( enabled[0]  ),
    .top        ( 8'd200      ),
    .yclip      ( 16'd19      ),
    .bank       ( bank[0]     ),
    .ctrl_addr  ( ctrl_addr   ),
    .ctrl_data  ( ctrl_data   ),
    .pixel_addr ( pixel_addr  ),
    .pixel_data ( pixel_data  ),
    .color_addr ( color_addr  ),
    .color_data ( color_data  ),
    .pxl        ( pxl         ),
    .solid      ( solid       )
);

always #5 clk=~clk;
always @(posedge clk) begin
    ctrl_data <= controls[ctrl_addr];
    pixel_data <= pixels[pixel_addr];
    color_data <= colors[color_addr];
    if (!rst) begin
        phase <= phase+1'd1;
        if (pxl_cen) begin
            x=h;
            y=v;
            h<=h==399 ? 9'd0 : h+1'd1;
            if (h==399) begin
                v<=v==271 ? 9'd0 : v+1'd1;
                if (v==271) frames<=frames+1;
            end
        end
        if (phase==4 && frames==1 && x<320 && y<240) begin
            value=enabled ? expected[y*320+x] : 10'd0;
            if (solid !== value[9] || (solid && pxl !== value[8:0]))
                $fatal(1,"road x=%0d y=%0d actual=%h expected=%h",x,y,{solid,pxl},value);
            checked=checked+1;
            if (checked==76800) begin
                $display("PASS: 76800 road pixels, bank=%0d enable=%0d, signed shifts, wrapped sum, scales, zero step, edges, gap, palette and clipping",bank,enabled);
                $finish;
            end
        end
    end
end

initial begin
    n=$value$plusargs("BANK=%d",bank);
    n=$value$plusargs("ENABLE=%d",enabled);
    $readmemh("controls.hex",controls);
    $readmemh("pixels.hex",pixels);
    $readmemh("colors.hex",colors);
    if (bank==0) $readmemh("expected0.hex",expected);
    else $readmemh("expected1.hex",expected);
    repeat(8) @(negedge clk);
    rst=0;
end
endmodule
