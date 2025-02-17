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

module jtflstory_obj_scan(
    input             clk, 
                      lhbl, blink, dr_busy,
                      ghflip, gvflip,
                      layout,
    input       [8:0] hdump, vdump,
    // RAM shared with CPU
    output     [ 7:0] ram_addr,
    input      [ 7:0] ram_dout,
    output     [ 7:0] ram_din,
    output reg        ram_we,    
    // draw requests
    output reg        draw,
                      hflip, vflip,
    output reg [ 9:0] code,
    output reg [ 7:0] xpos,
    output reg [ 3:0] ysub,
    output reg [ 6:0] pal
);

wire [ 8:0] hf;
reg  [ 7:0] vlatch, chk; // object to check
reg  [ 4:0] scan;
reg  [ 3:0] cnt;
reg  [ 2:0] st;
reg  [ 1:0] obj_sub;
wire [ 7:0] ydiff;
reg         blank, cen, scan_done, order, info, vsbl, inzone_l, lhbl_l;
wire        inzone;

assign ram_din  = chk;
// same RAM usage as the original
assign ram_addr = vsbl  ? {4'b1101,cnt[2:0],cnt[3]&blink}: // visible indexes   D0~D7, blinking D8~DF
                  info  ? {1'b0,   chk[4:0],  obj_sub   }: // object data       00~7F
                  order ? {3'b100, scan                 }: // object draw order 80~9F
                          {3'b101, hf[7:3]              }; // column scroll     A0~BF
assign ydiff    = vlatch+ram_dout;
assign inzone   = ydiff[7:4] == 4'b1111;
assign hf       = ghflip ? -9'h8-hdump : hdump;

always @(posedge clk) begin
    lhbl_l   <= lhbl;
    draw     <= 0;
    blank    <= vdump >= 9'h1f2 || vdump <= 9'h10e || !vdump[8];
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
                    if(ram_we) cnt <= cnt + 4'd1;
                    if(&scan || cnt == 15) begin
                        order <= 0;
                        cnt   <= 7;
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
                if(!dr_busy) begin
                    obj_sub <= obj_sub+2'd1;
                    case(obj_sub)
                        0: begin
                            ysub <= ydiff[3:0];
                            inzone_l <= inzone;
                        end
                        1: begin
                            {vflip,hflip,code[9:8],pal[3:0]} <= ram_dout;
                            if(layout) code[9:8] <= {1'b0,ram_dout[5]};
                        end
                        2: code[7:0] <= ram_dout;
                        3: begin
                            draw <= inzone_l;
                            info <= 0;
                            vsbl <= 1;
                            xpos <= ram_dout;
                            {scan_done, cnt[2:0]} <= {1'b0,cnt[2:0]}-4'd1;
                        end
                    endcase
                end
            end
        end
    end
    if(scan_done) {info,vsbl,order}<=0;
    if( (!lhbl && lhbl_l) || blank ) begin
        vlatch    <= vdump[7:0]^{8{gvflip}};
        cnt       <= 0;
        obj_sub   <= 0;
        scan_done <= 0;
        cen       <= 0;
        {info,vsbl,order} <= 3'b001;
        st        <= 1;
        scan      <= 0;
    end
end

endmodule