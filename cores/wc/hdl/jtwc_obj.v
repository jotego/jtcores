/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 5-11-2024 */

module jtwc_obj(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             hs,

    input             ghflip,
    input             gvflip,

    input       [8:0] vrender,
    input       [8:0] hdump,
    // RAM shared with CPU
    output     [ 9:0] vram_addr,
    input      [ 7:0] vram_data,
    // Frame buffer
    output     [10:2] fb_addr,
    output reg [31:0] fb_din,
    input      [31:0] fb_dout,
    output reg        fb_we,
    // ROM
    output     [15:2] rom_addr,
    input      [31:0] rom_data,
    output            rom_cs,
    input             rom_ok,
    output     [ 6:0] pxl
);

localparam [8:0] HOFFSET=9;

wire [15:2] raw_addr;
wire [ 6:0] pre_pxl;
// DMA
reg [ 9:0] dma_a;
reg [ 9:2] scan_a, dma_wa;
reg        frame=0, dma_done, dma_cen=0, fb_sel=0;
// scan
reg [ 7:0] ysub;
reg        hs_l, scan_done, inzone;
reg [ 1:0] st;
// drawing
reg  [ 8:0] xpos,code, xraw;
reg  [ 2:0] pal;
reg  [ 7:0] ypos;
// wire [31:0] sorted;
reg         hflip, vflip, draw, blank;
wire        dr_busy;

assign rom_addr  = {raw_addr[15:7],raw_addr[5],raw_addr[6],raw_addr[4:2]};
assign vram_addr = dma_a;
assign fb_addr   = fb_sel ? {~frame,dma_wa} : {frame,scan_a};

// assign sorted = {
//     rom_data[31],rom_data[27],rom_data[23],rom_data[19],rom_data[15],rom_data[11],rom_data[7],rom_data[3],
//     rom_data[30],rom_data[26],rom_data[22],rom_data[18],rom_data[14],rom_data[10],rom_data[6],rom_data[2],
//     rom_data[29],rom_data[25],rom_data[21],rom_data[17],rom_data[13],rom_data[ 9],rom_data[5],rom_data[1],
//     rom_data[28],rom_data[24],rom_data[20],rom_data[16],rom_data[12],rom_data[ 8],rom_data[4],rom_data[0]
// };

always @(posedge clk) begin
    if(rst) begin
        fb_we    <= 0;
        fb_din   <= 0;
        dma_done <= 0;
        dma_wa   <= 0;
    end else begin
        dma_cen <= ~dma_cen;
        fb_we   <= 0;
        fb_sel  <= !dma_done || fb_we;
        if( hs && !hs_l && vrender==9'h10e ) begin
            dma_a    <= 0;
            dma_wa   <= 0;
            dma_done <= 0;
            dma_cen  <= 0;
            frame    <= ~frame;
        end
        if( !dma_done && dma_cen ) begin
            {dma_done, dma_a} <= {1'b0,dma_a}+1'd1;
            fb_din <= {vram_data,fb_din[31:8]};
            fb_we  <= dma_a[1:0]==3;
            dma_wa <= dma_a[9:2];
        end
    end
end

always @* begin
    ysub = ~(vrender[7:0]^{8{gvflip}})+ypos;
    inzone = &ysub[7:4];
end

always @(posedge clk) begin
    hs_l     <= hs;
    draw     <= 0;
    blank    <= vrender >= 9'h1f2 || vrender <= 9'h10e || !vrender[8];
    if( !scan_done ) begin
        st <= st==2'd2 ? 2'd0 : st+2'd1;
        case( st )
            1: begin
                ypos <= fb_dout[31-:8];
                xraw <= {fb_dout[13],fb_dout[23-:8]};
                {vflip,hflip} <= fb_dout[15:14];
                {code[8],pal,code[7:0]} <= fb_dout[11:0];
            end
            2: begin
                if( inzone ) begin
                    if( dr_busy )
                        st <= 2;
                    else begin
                        xpos  <= xraw+9'h80;
                        vflip <= ~vflip ^ gvflip;
                        draw  <= 1;
                    end
                end
                if( !inzone || !dr_busy ) {scan_done,scan_a} <= {1'b0,scan_a} + 1'd1;
            end
        endcase
    end
    if( (hs && !hs_l) || fb_sel || blank ) begin
        scan_a    <= 0;
        scan_done <= 0;
        st        <= 0;
    end
end

jtframe_objdraw #(
    .CW(9),
    .PW(7),
    //SWAPH =  0,
    .HJUMP(0),
    .LATCH(1),
    .PACKED(1)
) u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .flip       ( ghflip    ),
    .hdump      ( hdump     ),

    .draw       ( draw      ),
    .busy       ( dr_busy   ),
    .code       ( code      ),
    .xpos       ( xpos      ),
    .ysub       ( ysub[3:0] ),
    // optional zoom, keep at zero for no zoom
    .hzoom      ( 6'd0      ),
    .hz_keep    ( 1'b0      ), // set at 1 for the first tile

    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .pal        ( pal       ),

    .rom_addr   ( raw_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( rom_data  ),

    .pxl        ( pre_pxl   )
);

jtframe_sh #(.W(7),.L(HOFFSET)) u_sh(
    .clk    ( clk       ),
    .clk_en ( pxl_cen   ),
    .din    ( pre_pxl   ),
    .drop   ( pxl       )
);

endmodule
