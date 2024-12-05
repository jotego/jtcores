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
    Date: 22-11-2024 */

// 0x100 RAM
// 00~0x7F -> 32 objects, 4 bytes per object
// 80~9F   -> 4:0 drawing order
//            7   priority bit

module jtflstory_obj(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             lhbl,
    input             lvbl,
    input             hs,
    input             gvflip,
    input             ghflip,

    input       [8:0] vrender,
    input       [8:0] hdump,
    // RAM shared with CPU
    output     [ 7:0] ram_addr,
    input      [ 7:0] ram_dout,
    output     [ 7:0] ram_din,
    output reg        ram_we,
    // ROM
    output     [16:2] rom_addr,
    input      [31:0] rom_data,
    output            rom_cs,
    input             rom_ok,
    output     [ 2:0] prio,
    output     [ 7:0] pxl
);

wire [31:0] sorted;
wire [16:2] raw_addr;
wire [10:0] pxl_raw;
wire [ 7:0] ydiff;
reg  [ 9:0] code;
reg  [ 7:0] vlatch, xpos, chk; // object to check
reg  [ 6:0] pal;               // priority at top 3 bits
reg  [ 4:0] scan;
reg  [ 3:0] ysub, cnt;
reg  [ 1:0] obj_sub;
reg  [ 2:0] st;
reg         lhbl_l, lvbl_l, cen, draw, scan_done, hflip, vflip,
            order, blink=0, blank, info, vsbl, inzone_l;
wire        inzone, dr_busy;

// same RAM usage as the original
assign ram_addr = vsbl  ? {4'b1101,cnt[2:0],cnt[3]&blink}: // visible indexes   D0~D7, blinking D8~DF
                  info  ? {1'b0,   chk[4:0],  obj_sub   }: // object data       00~7F
                  order ? {3'b100, scan                 }: // object draw order 80~9F
                          {3'b101, hdump[7:3]           }; // column scroll     A0~BF
assign ydiff    = vlatch+ram_dout;
assign inzone   = ydiff[7:4]==0;
assign ram_din  = chk;
assign rom_addr = { raw_addr[16:7], raw_addr[5], raw_addr[6], raw_addr[4:2] };

assign sorted = ~{
    rom_data[12],rom_data[13],rom_data[14],rom_data[15],rom_data[28],rom_data[29],rom_data[30],rom_data[31],
    rom_data[ 8],rom_data[ 9],rom_data[10],rom_data[11],rom_data[24],rom_data[25],rom_data[26],rom_data[27],
    rom_data[ 4],rom_data[ 5],rom_data[ 6],rom_data[ 7],rom_data[20],rom_data[21],rom_data[22],rom_data[23],
    rom_data[ 0],rom_data[ 1],rom_data[ 2],rom_data[ 3],rom_data[16],rom_data[17],rom_data[18],rom_data[19]
};

always @(posedge clk) begin
    lvbl_l <= lvbl;
    if( lvbl && !lvbl_l ) blink <= ~blink;
end

always @(posedge clk) begin
    lhbl_l   <= lhbl;
    draw     <= 0;
    blank    <= vrender >= 9'h1f2 || vrender <= 9'h10e || !vrender[8];
    cen      <= ~cen;
    if(!scan_done && cen) begin
        if( order ) begin
            st <= {st[1:0],st[2]};
            case(st)
                1: begin
                    chk  <= ram_dout;
                    info <= 1;
                end
                2: if(inzone) begin
                    ram_we <= 1;
                    vsbl   <= 1;
                end
                4: begin
                    scan   <= scan+5'd1;
                    ram_we <= 0;
                    vsbl   <= 0;
                    info   <= 0;
                    if(ram_we) cnt <= cnt - 4'd1;
                    if(&scan) begin
                        order <= 0;
                        cnt   <= 0;
                        vsbl  <= 1;
                    end
                end
            endcase
        end else begin
            if( !info  ) begin
                chk      <= ram_dout;
                pal[6:4] <= ram_dout[7:5]; // priority bits
                info     <= 1;
                vsbl     <= 0;
            end else begin
                if(!dr_busy) obj_sub <= obj_sub+2'd1;
                case(obj_sub)
                    0: begin
                        ysub <= ydiff[3:0];
                        inzone_l <= inzone;
                    end
                    1: {vflip,hflip,code[9:8],pal[3:0]} <= ram_dout;
                    2: code[7:0] <= ram_dout;
                    3: begin
                        draw <= inzone_l;
                        info <= 0;
                        vsbl <= 1;
                        xpos <= ram_dout;
                        {scan_done, cnt[2:0]} <= {1'b0,cnt[2:0]}+4'd1;
                    end
                endcase
            end
        end
    end
    if(scan_done) {info,vsbl,order}<=0;
    if( (!lhbl && lhbl_l) || blank ) begin
        vlatch    <= (vrender[7:0]-8'h10)^{8{gvflip}};
        cnt       <= 7;
        obj_sub   <= 0;
        scan_done <= 0;
        cen       <= 0;
        {info,vsbl,order} <= 3'b001;
        st        <= 1;
        scan      <= 0;
    end
end

// original does not use a double line buffer. It buffers the data during
// HB instead. I'm using a double-line buffer to ease the implementation
jtframe_objdraw #(
    .CW(10),
    .PW(11),
    .SWAPH(1),
    .HJUMP(0),
    .ALPHA(15),
    .LATCH(1)
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
    .xpos       ({1'b0,xpos}),
    .ysub       ( ysub      ),
    // optional zoom, keep at zero for no zoom
    .hzoom      ( 6'd0      ),
    .hz_keep    ( 1'b0      ), // set at 1 for the first tile

    .hflip      ( ~hflip    ),
    .vflip      ( vflip     ),
    .pal        ( pal       ),

    .rom_addr   ( raw_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( sorted    ),

    .pxl        ( pxl_raw   )
);

jtframe_sh #(.W(11),.L(8)) u_sh(
    .clk    ( clk       ),
    .clk_en ( pxl_cen   ),
    .din    ( pxl_raw   ),
    .drop   ({prio,pxl} )
);

endmodule