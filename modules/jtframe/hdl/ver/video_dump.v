/*  This file is part of JT_FRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 6-9-2021 */

////////////////////////////////////////////////////////////////////
// video output dump
// this is a binary bile with 32 bits per pixel. First 8 bits are the alpha, and set to 0xFF
// The rest are RGB in 8-bit format
// There is no dump while blanking. The inputs pxl_hb and pxl_vb are high during blanking
// The linux tool "convert" can process the raw stream and separate it into individual frames
// automatically

`timescale 1ns/1ps

module video_dump(
    input        pxl_clk,
    input        pxl_cen,
    input        pxl_hb,
    input        pxl_vb,
    input [ 3:0] red,
    input [ 3:0] green,
    input [ 3:0] blue,
    input [31:0] frame_cnt
    //input        downloading
);


`ifdef DUMP_VIDEO

`ifndef DUMP_VIDEO_FNAME
    `define DUMP_VIDEO_FNAME "video.raw"
    initial $display("WARNING: DUMP_VIDEO_FNAME undefined\n");
`else
    initial $display("INFO: dumping video to %s\n",`DUMP_VIDEO_FNAME);
`endif

integer vcnt=-1, hcnt=-1, hvinfo_done=-1, finfo;
integer fvideo;

reg last_vb, last_hb;

initial begin
    fvideo = $fopen(`DUMP_VIDEO_FNAME,"wb");
end

wire [31:0] video_dump = { 8'hff, {2{blue}}, {2{green}}, {2{red}} };

// Define VIDEO_START with the first frame number for which
// video will be dumped. If undefined, it will start from frame 0
`ifndef VIDEO_START
`define VIDEO_START 0
`endif

always @(posedge pxl_clk) if(pxl_cen && frame_cnt>=`VIDEO_START && hvinfo_done>=0 ) begin
    if( !pxl_hb && !pxl_vb ) $fwrite(fvideo,"%u", video_dump);
end

always @(posedge pxl_clk) if( pxl_cen && hvinfo_done<1 ) begin
    last_vb <= pxl_vb;
    last_hb <= pxl_hb;
    if( pxl_vb ) begin
        vcnt<=0;
        if( hvinfo_done==0 && vcnt>0 && hcnt>0 ) begin
            finfo  = $fopen("video.info","w");
            $fdisplay( finfo, "1%d\n%1d\n", hcnt, vcnt );
            $display( "Visible screen size: %1dx%1d\n", hcnt, vcnt );
            $fclose(finfo);
            hvinfo_done <= 1;
        end else if(hvinfo_done<0) begin
            hvinfo_done <= 0;
        end
    end else if( pxl_hb===1 && last_hb===0 )
        vcnt<=vcnt+1;

    if( pxl_hb )
        hcnt <= 0;
    else hcnt <= hcnt + 1;
end

`endif

endmodule