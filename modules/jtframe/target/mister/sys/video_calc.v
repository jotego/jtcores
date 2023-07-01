///////////////////////////////////////////////////////////////////////
// Copyright (c) 2017-2020 Alexey Melnikov
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
///////////////////////////////////////////////////////////////////////

///////////////// calc video parameters //////////////////
module video_calc
(
    input clk_100,
    input clk_vid,
    input clk_sys,

    input ce_pix,
    input de,
    input hs,
    input vs,
    input vs_hdmi,
    input f1,
    input new_vmode,
    input video_rotated,

    input       [3:0] par_num,
    output reg [15:0] dout
);

always @(posedge clk_sys) begin
    case(par_num)
        1: dout <= {video_rotated, |vid_int, vid_nres};
        2: dout <= vid_hcnt[15:0];
        3: dout <= vid_hcnt[31:16];
        4: dout <= vid_vcnt[15:0];
        5: dout <= vid_vcnt[31:16];
        6: dout <= vid_htime[15:0];
        7: dout <= vid_htime[31:16];
        8: dout <= vid_vtime[15:0];
        9: dout <= vid_vtime[31:16];
      10: dout <= vid_pix[15:0];
      11: dout <= vid_pix[31:16];
      12: dout <= vid_vtime_hdmi[15:0];
      13: dout <= vid_vtime_hdmi[31:16];
      14: dout <= vid_ccnt[15:0];
      15: dout <= vid_ccnt[31:16];
      default dout <= 0;
    endcase
end

reg [31:0] vid_hcnt = 0;
reg [31:0] vid_vcnt = 0;
reg [31:0] vid_ccnt = 0;
reg  [7:0] vid_nres = 0;
reg  [1:0] vid_int  = 0;

always @(posedge clk_vid) begin
    integer hcnt;
    integer vcnt;
    integer ccnt;
    reg old_vs= 0, old_de = 0, old_vmode = 0;
    reg [3:0] resto = 0;
    reg calch = 0;

    if(calch & de) ccnt <= ccnt + 1;

    if(ce_pix) begin
        old_vs <= vs;
        old_de <= de;

        if(~vs & ~old_de & de) vcnt <= vcnt + 1;
        if(calch & de) hcnt <= hcnt + 1;
        if(old_de & ~de) calch <= 0;

        if(old_vs & ~vs) begin
            vid_int <= {vid_int[0],f1};
            if(~f1) begin
                if(hcnt && vcnt) begin
                    old_vmode <= new_vmode;

                    //report new resolution after timeout
                    if(resto) resto <= resto + 1'd1;
                    if(vid_hcnt != hcnt || vid_vcnt != vcnt || old_vmode != new_vmode) resto <= 1;
                    if(&resto) vid_nres <= vid_nres + 1'd1;
                    vid_hcnt <= hcnt;
                    vid_vcnt <= vcnt;
                    vid_ccnt <= ccnt;
                end
                vcnt <= 0;
                hcnt <= 0;
                ccnt <= 0;
                calch <= 1;
            end
        end
    end
end

reg [31:0] vid_htime = 0;
reg [31:0] vid_vtime = 0;
reg [31:0] vid_pix = 0;

// 2-FF synchronizers
reg [ 1:0] de_100, vs_100, hs_100;
// reg        vid_htime_lsb, vid_vtime_lsb;

always @(posedge clk_100) begin
    de_100 <= { de_100[0], de };
    vs_100 <= { vs_100[0], vs };
    hs_100 <= { hs_100[0], hs };
end

always @(posedge clk_100) begin
    integer vtime, htime, hcnt;
    reg old_vs, old_hs, old_vs2, old_hs2, old_de, old_de2;
    reg calch = 0;

    old_vs <= vs_100[1];
    old_hs <= hs_100[1];

    old_vs2 <= old_vs;
    old_hs2 <= old_hs;

    vtime <= vtime + 1'd1;
    htime <= htime + 1'd1;

    if(~old_vs2 & old_vs) begin
        vid_pix <= hcnt;
        vid_vtime <= vtime;
        vtime <= 0;
        hcnt <= 0;
    end

    if(old_vs2 & ~old_vs) calch <= 1;

    if(~old_hs2 & old_hs) begin
        vid_htime <= htime;
        htime <= 0;
    end

    old_de   <= de_100[1];
    old_de2  <= old_de;

    if(calch & old_de) hcnt <= hcnt + 1;
    if(old_de2 & ~old_de) calch <= 0;
end

reg [31:0] vid_vtime_hdmi;
always @(posedge clk_100) begin
    integer vtime;
    reg old_vs, old_vs2;

    old_vs <= vs_hdmi;
    old_vs2 <= old_vs;

    vtime <= vtime + 1'd1;

    if(~old_vs2 & old_vs) begin
        vid_vtime_hdmi <= vtime;
        vtime <= 0;
    end
end

endmodule