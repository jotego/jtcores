/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-10-2026 */

module jt6802_decode #(parameter FC_COMPAT=0)(
    input            nsc8105,
    input      [7:0] raw,
    output     [7:0] opcode,
    output reg       legal
);

wire [7:0] mapped = nsc8105 ? {raw[6],raw[7],raw[5:2],raw[0],raw[1]} : raw;
// FC compatibility only; absent from MC6802 manual, real-chip behavior/timing unknown.
assign opcode = FC_COMPAT && !nsc8105 && raw==8'hfc ? 8'h03 : mapped;

always @* begin
    legal=0;
    if(mapped[7]) begin
        case(mapped[3:0])
            0,1,2,4,5,6,8,9,10,11,14: legal=1;
            12: legal=!mapped[6];
            7,15: legal=mapped[5:4]!=0;
            13: legal=!mapped[6];
            default:;
        endcase
    end else if(mapped[7:4]>=4) begin
        case(mapped[3:0])
            0,3,4,6,7,8,9,10,12,13,15: legal=1;
            14: legal=mapped[7:4]>=6;
            default:;
        endcase
    end else if(mapped[7:4]==2) legal=1;
    else case(mapped)
        8'h01,8'h06,8'h07,8'h08,8'h09,8'h0a,8'h0b,8'h0c,8'h0d,8'h0e,8'h0f,
        8'h10,8'h11,8'h16,8'h17,8'h19,8'h1b,
        8'h30,8'h31,8'h32,8'h33,8'h34,8'h35,8'h36,8'h37,
        8'h39,8'h3b,8'h3e,8'h3f: legal=1;
        default:;
    endcase
    if(nsc8105 && (mapped==8'h71 || mapped==8'h7b || mapped==8'hec || mapped==8'hfc)) legal=1;
    if(FC_COMPAT && !nsc8105 && raw==8'hfc) legal=1;
end
endmodule
