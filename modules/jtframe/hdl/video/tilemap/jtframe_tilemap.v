/*  This file is part of JTFRAME.
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
    Date: 15-12-2022 */


// Generic tile map generator with no scroll
// The ROM address must be in this format: {code, H parts, V part}
// pixel data has arbitrary bpp but it must arrive in groups of 8 pixels
// Each byte is for a plane

module jtframe_tilemap #( parameter
    SIZE         =  8,    // 8x8, 16x16 or 32x32
    VA           = 10,    // VRAM bit width
    CW           = 12,
    PW           =  8,    // pixel width
    BPP          =  4,    // bits per pixel. Palette width = PW-BPP
    VR           = SIZE==8 ? CW+3 : SIZE==16 ? CW+5 : CW+7,
    MAP_HW       = 8,    // 2^MAP_HW = size of the map in pixels
    MAP_VW       = 8,
    FLIP_MSB     = 1, // set to 0 for scroll tile maps
    FLIP_HDUMP   = 1,
    FLIP_VDUMP   = 1,
    XOR_HFLIP    = 0,  // set to 1 so hflip gets ^ with flip
    XOR_VFLIP    = 0,  // set to 1 so vflip gets ^ with flip
    HDUMP_OFFSET = 0,  // adds an offset to hdump
    HJUMP        = 1,  // see jtframe_scroll
    // hdump/vdump dimensions can be larger than the screen for the scroll use case
    // but the MSBs will be fixed
    HDUMPW       = 9,
    VDUMPW       = 9,
    // override VH and HW only for non rectangular tiles
    VW           = SIZE==8 ? 3 : SIZE==16 ? 4:5,
    HW           = VW,
    // localparam, do not modify
    PALW         = PW-BPP,
    DW           = 8*BPP
)(
    input              rst,
    input              clk,
    input              pxl_cen,

    input [VDUMPW-1:0] vdump,
    input [HDUMPW-1:0] hdump,
    input              blankn,  // if !blankn there are no ROM requests
    input              flip,    // Screen flip

    output    [VA-1:0] vram_addr,

    input     [CW-1:0] code,
    input   [PALW-1:0] pal,
    input              hflip,
    input              vflip,

    output reg [VR-1:0]rom_addr,
    input      [DW-1:0]rom_data,    // expects data packed as plane3,plane2,plane1,plane0, each of 8 bits
    output reg         rom_cs,
    input              rom_ok, // zeros used if rom_ok is not high in time

    output reg [PW-1:0]pxl
);

reg   [DW-1:0]    pxl_data;
reg [PALW-1:0]    cur_pal, nx_pal;
wire              vflip_g, xhflip;
reg               hflip_g, nx_hf;
reg  [HDUMPW-1:0] heff, hoff;
wire [VDUMPW-1:0] veff;

// not flipping the MSB is usually needed in scroll layers
assign veff = FLIP_VDUMP ? vdump ^ { FLIP_MSB[0]&flip, {VDUMPW-1{flip}}} : vdump;

always @* begin
    hoff = hdump - HDUMP_OFFSET[HDUMPW-1:0];
    heff = FLIP_HDUMP ? hoff ^ {HDUMPW{flip}} : hoff;
end

initial begin
    if( SIZE==32 ) begin
        $display("WARNING %m: SIZE=32 has not been tested");
    end
end

`ifdef SIMULATION
wire vram_len, vram_big;
assign vram_len = VA == (MAP_VW-VW + MAP_HW-HW);
assign vram_big = VA >  (MAP_VW-VW + MAP_HW-HW);
initial begin
    if( !vram_len ) begin
        if( vram_big ) $display("WARNING %m: vram_addr has unassigned bits. Adjust parameters to avoid this");
        else           $display("WARNING %m: vram_addr has bits assigned by two different sources. Adjust parameters to avoid this");
        $finish;
    end
end
`endif

assign xhflip  = (flip & XOR_HFLIP[0])^hflip;
assign vflip_g = (flip & XOR_VFLIP[0])^vflip;

// VRAM address width of H and V portions
localparam AHW=MAP_HW-HW,
           AVW=MAP_VW-VW;

assign vram_addr={ veff[MAP_VW-1:VW], heff[MAP_HW-1:HW] };

initial begin
    if( AHW+AVW > VA ) begin
        $display("vram address width is too narrow.");
        $display("It should be at least %d",AHW+AVW);
        $finish;
    end
end

integer i;
always @* begin
    pxl[PW-1-:PALW] = cur_pal;
    for(i=0;i<BPP;i=i+1) begin
        if( hflip_g )
            pxl[i] = pxl_data[i<<3];
        else
            pxl[i] = pxl_data[((i+1)<<3)-1];
    end
end

reg heff_l, hmsb_l;
wire zero = heff[3] != heff_l // read the ROM every 8 pixels
         || (hmsb_l!=hdump[HDUMPW-1] && HJUMP==0); // identify a typical blanking end case

always @(posedge clk) begin
    if( rst ) begin
        rom_cs   <= 0;
        rom_addr <= 0;
        pxl_data <= 0;
        cur_pal  <= 0;
        hflip_g  <= 0;
    end else if(pxl_cen) begin
        heff_l <= heff[3];
        hmsb_l <= hdump[HDUMPW-1];
        if( zero ) begin
            rom_cs <= ~rst & blankn;
            rom_addr[0+:VW] <= veff[0+:VW]^{VW{vflip_g}};
            rom_addr[VR-1-:CW] <= code;
            if( SIZE==16 ) rom_addr[VW]      <= heff[3]^xhflip;
            if( SIZE==32 ) rom_addr[VW+1-:2] <= heff[4:3]^{2{xhflip}};
            pxl_data <= rom_ok ? rom_data : {DW{1'b0}};
            // draw information is eight pixels behind
            nx_pal   <= pal;
            cur_pal  <= nx_pal;
            nx_hf    <= xhflip;
            hflip_g  <= nx_hf;
        end else begin
            pxl_data <= hflip_g ? (pxl_data>>1) : (pxl_data<<1);
        end
    end
end

endmodule