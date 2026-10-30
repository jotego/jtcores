/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 9-10-2025 */

module jtriders_tmnt2_zoom(
    input        clk,

    input        xylock,
    input signed[15:0] offset,
    input       [15:0] zoom,

    // LUTs
    output reg [ 9:0] mant, log,
    input      [ 8:0] frac,
    input      [14:0] lin,

    output reg [15:0] adj,
    output reg [ 1:0] ztype
);

reg signed [15:0] i, imul;
reg  [15:0] abs;
reg  [ 9:0] exp;
reg  signed [31:0] xmul32;
reg  signed [63:0] xmul64;

// Enlarge: a big sprite's pieces are spaced by the 053245 magnification,
// 64/(64-n). The game writes zoom register 0x40-n for zoom 0x4F00+n*0x100.
// recip = 2^16*64/(64-n)
reg  [ 5:0] n;
reg  [22:0] recip;
reg  signed [38:0] emul;
wire signed [38:0] emul_t = emul[38] ? emul + 39'sd65535 : emul; // truncate toward zero

always @(*) begin    
    abs   = offset[15] ? -offset : offset;
    if(abs[15]) abs=16'h7fff;
    mant = abs[14] ? abs[14-:10]:
           abs[13] ? abs[13-:10]:
           abs[12] ? abs[12-:10]:
           abs[11] ? abs[11-:10]:
           abs[10] ? abs[10-:10]:
                    abs[ 9-:10];
    exp  = abs[14] ? 10'd256 :
           abs[13] ? 10'd204 :
           abs[12] ? 10'd153 :
           abs[11] ? 10'd102 :
           abs[10] ? 10'd051 : 10'd0;
    i    = zoom - 16'h4f00;
    imul = $signed(zoom) + (i>>>3) + (i>>>4) + (i>>>5) + (i>>>6);
    n    = i[15:14]!=0 || i[13:8]==6'h3f ? 6'h3f : i[13:8];
    case( n )
        6'd0 : recip = 23'd65536;
        6'd1 : recip = 23'd66576;
        6'd2 : recip = 23'd67650;
        6'd3 : recip = 23'd68759;
        6'd4 : recip = 23'd69905;
        6'd5 : recip = 23'd71090;
        6'd6 : recip = 23'd72316;
        6'd7 : recip = 23'd73584;
        6'd8 : recip = 23'd74898;
        6'd9 : recip = 23'd76260;
        6'd10: recip = 23'd77672;
        6'd11: recip = 23'd79138;
        6'd12: recip = 23'd80660;
        6'd13: recip = 23'd82241;
        6'd14: recip = 23'd83886;
        6'd15: recip = 23'd85598;
        6'd16: recip = 23'd87381;
        6'd17: recip = 23'd89241;
        6'd18: recip = 23'd91181;
        6'd19: recip = 23'd93207;
        6'd20: recip = 23'd95325;
        6'd21: recip = 23'd97542;
        6'd22: recip = 23'd99864;
        6'd23: recip = 23'd102300;
        6'd24: recip = 23'd104858;
        6'd25: recip = 23'd107546;
        6'd26: recip = 23'd110376;
        6'd27: recip = 23'd113360;
        6'd28: recip = 23'd116508;
        6'd29: recip = 23'd119837;
        6'd30: recip = 23'd123362;
        6'd31: recip = 23'd127100;
        6'd32: recip = 23'd131072;
        6'd33: recip = 23'd135300;
        6'd34: recip = 23'd139810;
        6'd35: recip = 23'd144631;
        6'd36: recip = 23'd149797;
        6'd37: recip = 23'd155345;
        6'd38: recip = 23'd161319;
        6'd39: recip = 23'd167772;
        6'd40: recip = 23'd174763;
        6'd41: recip = 23'd182361;
        6'd42: recip = 23'd190650;
        6'd43: recip = 23'd199729;
        6'd44: recip = 23'd209715;
        6'd45: recip = 23'd220753;
        6'd46: recip = 23'd233017;
        6'd47: recip = 23'd246724;
        6'd48: recip = 23'd262144;
        6'd49: recip = 23'd279620;
        6'd50: recip = 23'd299593;
        6'd51: recip = 23'd322639;
        6'd52: recip = 23'd349525;
        6'd53: recip = 23'd381300;
        6'd54: recip = 23'd419430;
        6'd55: recip = 23'd466034;
        6'd56: recip = 23'd524288;
        6'd57: recip = 23'd599186;
        6'd58: recip = 23'd699051;
        6'd59: recip = 23'd838861;
        6'd60: recip = 23'd1048576;
        6'd61: recip = 23'd1398101;
        6'd62: recip = 23'd2097152;
        6'd63: recip = 23'd4194304;
    endcase
end

always @(posedge clk) begin
    log    <= {1'b0,frac} + exp + {1'b0,i[15:8]};
    xmul32 <= offset * imul;
    xmul64 <= (xmul32 * 64'sd6637) + (xmul32[31] ? 64'sd134217727 : 64'sd0);
    emul   <= offset * $signed({1'b0,recip});
end

always @* begin
    ztype = 0;
    adj   = offset;
    if(!xylock) begin
        if(zoom > 16'h4f00) begin
            adj   = emul_t[31:16];
            ztype = 1;
        end else if(i[15]) begin
            if(imul[15]) begin
                adj   = 0;
                ztype = 2;
            end else begin
                adj   = xmul64[27+:16];
                ztype = 3;
            end
        end
    end
end                    

endmodule