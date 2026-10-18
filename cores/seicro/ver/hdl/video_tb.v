/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-10-2026 */

module video_tb;
parameter WITH_SPRITES=0;
reg clk=0, rst=1, flip=0;
reg [2:0] count=0;
wire pxl_cen=count==0;
wire HS,VS,LHBL,LVBL,cpu_lvbl;
wire [9:0] tile_vram_addr;
wire [8:0] tile_color_addr;
wire [4:0] scroll_video_addr, obj_ram1_addr;
wire [6:0] obj_ram0_addr;
reg [7:0] tile_vram_data,tile_color_data,scroll_video_data;
wire [13:1] scr_addr,obj_addr;
wire scr_cs,obj_cs;
reg [15:0] scr_data,obj_data;
reg [13:1] obj_addr_l;
reg obj_cs_l;
wire obj_ok=obj_cs && obj_cs_l && obj_addr==obj_addr_l && count[1:0]==0;
wire [5:0] proms_addr;
wire [3:0] red,green,blue;
reg [7:0] proms_data, obj_ram0_data, obj_ram1_data;
integer bank,slot,ax,ay,fx,fy,oc,op,osx,osy,ox,oy,obj_checks=0, rgb=0, rr=0,gg=0,bb=0;
reg [5:0] obj_expected;
integer h,v,x,y,sy,idx,attr,code,rx,ry,byteaddr,pixel,checked=0,errors=0,frames=0;
reg [7:0] packed_byte;
reg [7:0] expected;
reg vs_l;

function [7:0] chr;
    input integer addr;
    chr=(addr*73)^(addr>>3)^(addr>>7)^8'hc9;
endfunction
function [7:0] attr_at;
    input integer addr;
    attr_at={addr[2],addr[1],1'b0,addr[4],addr[3:0]};
endfunction
function [7:0] code_at;
    input integer addr;
    code_at=addr[7:0]^(addr>>4);
endfunction
function [7:0] scroll_at;
    input integer col;
    scroll_at=col*13+7;
endfunction

function [7:0] object_at;
    input integer bank,addr;
    integer slot;
    begin
        slot=addr/4;
        case(addr%4)
            0: object_at=((slot*13)&63) | ((slot&3)<<6);
            1: object_at=(slot&15) | ((slot&1)<<4);
            2: object_at=200-(slot%8)*21;
            3: object_at=(slot%5)*52+246;
        endcase
    end
endfunction

always #5 clk=~clk;
always @(posedge clk) begin
    count<=count+3'd1;
    tile_vram_data<=code_at(tile_vram_addr);
    tile_color_data<=attr_at(tile_color_addr);
    scroll_video_data<=scroll_at(scroll_video_addr);
    scr_data<={chr(scr_addr*2+1),chr(scr_addr*2)};
    obj_data<={chr(obj_addr*2+1),chr(obj_addr*2)};
    obj_addr_l<=obj_addr;
    obj_cs_l<=obj_cs;
    obj_ram0_data<=WITH_SPRITES ? object_at(0,obj_ram0_addr) : 0;
    obj_ram1_data<=WITH_SPRITES ? object_at(1,obj_ram1_addr) : 0;
    proms_data<=proms_addr;
end

jtseicro_video dut(
    .rst               ( rst               ),
    .clk               ( clk               ),
    .pxl_cen           ( pxl_cen           ),
    .flip              ( flip              ),
    .HS                ( HS                ),
    .VS                ( VS                ),
    .LHBL              ( LHBL              ),
    .LVBL              ( LVBL              ),
    .cpu_lvbl          ( cpu_lvbl          ),
    .tile_vram_addr    ( tile_vram_addr    ),
    .tile_color_addr   ( tile_color_addr   ),
    .tile_vram_data    ( tile_vram_data    ),
    .tile_color_data   ( tile_color_data   ),
    .scroll_video_addr ( scroll_video_addr ),
    .scroll_video_data ( scroll_video_data ),
    .obj_ram0_addr     ( obj_ram0_addr     ),
    .obj_ram1_addr     ( obj_ram1_addr     ),
    .obj_ram0_data     ( obj_ram0_data     ),
    .obj_ram1_data     ( obj_ram1_data     ),
    .scr_addr          ( scr_addr          ),
    .obj_addr          ( obj_addr          ),
    .scr_cs            ( scr_cs            ),
    .obj_cs            ( obj_cs            ),
    .scr_data          ( scr_data          ),
    .obj_data          ( obj_data          ),
    .scr_ok            ( 1'b1              ),
    .obj_ok            ( obj_ok            ),
    .proms_addr        ( proms_addr        ),
    .proms_data        ( proms_data        ),
    .red               ( red               ),
    .green             ( green             ),
    .blue              ( blue              ),
    .gfx_en            ( 4'hf              )
);

always @(negedge clk) if(count==5 && !rst) begin
    vs_l=VS;
    h=dut.hdump; v=dut.vdump;
    if(h<256 && v>=16 && v<240 && frames>0) begin
        for(x=0;x<1;x=x+1) begin
            y=flip ? 255-v : v;
            sy=(y+scroll_at((flip ? 255-h : h)/8))%256;
            idx=(sy/8)*32+(flip ? 255-h : h)/8;
            attr=attr_at(((idx>>6)<<5)+(idx%32));
            code=code_at(idx)+((attr&16)<<4);
            rx=(flip ? 255-h : h)%8;
            ry=sy%8;
            if(attr&64) rx=7-rx;
            if(attr&128) ry=7-ry;
            byteaddr=code*16+ry*2+rx/4;
            packed_byte=chr(byteaddr);
            pixel=(((packed_byte>>(7-rx%4))&1)<<1) | ((packed_byte>>(3-rx%4))&1);
            expected={(attr[3:0]),2'b00,pixel[1:0]};
            if(dut.scr_pxl!==expected) begin
                if(errors<8) $display("tile h=%d v=%d flip=%d got=%h expected=%h map=%h scroll=%h",h,v,flip,dut.scr_pxl,expected,tile_vram_addr,scroll_video_data);
                if(errors<8) $display("rom=%h pxldata=%h heff=%h veff=%h hflip=%b curpal=%h",dut.tile_addr,dut.u_scroll.u_tilemap.pxl_data,dut.u_scroll.u_tilemap.heff,dut.u_scroll.u_tilemap.veff,dut.u_scroll.u_tilemap.hflip_g,dut.u_scroll.u_tilemap.cur_pal);
                errors=errors+1;
            end
            rgb=pixel!=0 ? ((attr&15)<<2) | pixel : 0;
            if(WITH_SPRITES) begin
                obj_expected=0;
                for(bank=0;bank<2;bank=bank+1) begin
                    for(slot=(bank==0 ? 23 : 7);slot>=0;slot=slot-1) begin
                        ax=object_at(bank,slot*4+3);
                        ay=240-object_at(bank,slot*4+2);
                        fx=(object_at(bank,slot*4)>>6)&1;
                        fy=(object_at(bank,slot*4)>>7)&1;
                        if(flip) begin ax=240-ax;ay=240-ay;fx=1-fx;fy=1-fy;end
                        ox=(h-ax+512)%256;
                        oy=v-ay;
                        if(ox<16 && oy>=0 && oy<16) begin
                            if(fx) ox=15-ox;
                            if(fy) oy=15-oy;
                            oc=(object_at(bank,slot*4)&63) | ((object_at(bank,slot*4+1)&16)<<2) | (bank==0 ? 128 : 0);
                            op=oc*64+(oy/8)*32+(ox/8)*16+(oy%8)*2+(ox%8)/4;
                            packed_byte=chr(op);
                            op=(((packed_byte>>(7-ox%4))&1)<<1) | ((packed_byte>>(3-ox%4))&1);
                            if(op!=0) obj_expected=((object_at(bank,slot*4+1)&15)<<2) | op;
                        end
                    end
                end
                if(obj_expected[1:0]!=0) begin
                    if(proms_addr!==obj_expected) begin
                        if(errors<8) $display("sprite h=%d v=%d f=%d got=%h want=%h",h,v,flip,proms_addr,obj_expected);
                        errors=errors+1;
                    end
                    rgb=obj_expected;
                    obj_checks=obj_checks+1;
                end else if(dut.obj_pxl[1:0]!==0) begin
                    if(errors<8) $display("unexpected sprite h=%d v=%d f=%d got=%h",h,v,flip,dut.obj_pxl);
                    errors=errors+1;
                end
            end
            rr=((rgb&1) ? 33 : 0)+((rgb&2) ? 71 : 0)+((rgb&4) ? 151 : 0);
            gg=((rgb&8) ? 33 : 0)+((rgb&16) ? 71 : 0)+((rgb&32) ? 151 : 0);
            if(red!==rr[7:4] || green!==gg[7:4] || blue!==0 || !LHBL || !LVBL) begin
                if(errors<8) $display("RGB h=%d v=%d got=%h%h%h want=%h%h0 blank=%b%b",h,v,red,green,blue,rr[7:4],gg[7:4],LHBL,LVBL);
                errors=errors+1;
            end
            checked=checked+1;
        end
    end
    if(h==383 && v==263) begin
        frames=frames+1;
        if(frames==2) flip=1;
        if(frames==3) begin
            if(errors) $fatal(1,"video mismatches=%d checks=%d",errors,checked);
            $display("PASS video: %d background pixels, %d sprite pixels, both flips",checked,obj_checks);
            $finish;
        end
    end
end
initial begin repeat(20) @(negedge clk); rst=0; end
initial begin #20000000; $fatal(1,"video timeout"); end
endmodule
