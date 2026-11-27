/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-10-2026 */

module jtseicro_cab(
    input            frisky, radial,
    input      [1:0] cab_1p, coin,
    input      [5:0] joystick1, joystick2,
    input            service, dip_test,
    input      [7:0] test_dip,
    output     [7:0] in0, in1, test_in
);

wire [3:0] p2=~{joystick2[0],joystick2[1],joystick2[2],joystick2[3]};

assign in0=~{cab_1p,coin,joystick1[0],joystick1[1],joystick1[2],joystick1[3]};
assign in1=frisky ? {test_dip[7],1'b0,test_dip[5],~service,p2} :
           radial ? {1'b0,~joystick1[5],~joystick1[4],~service,p2} :
                    {~joystick2[4],~joystick1[4],1'b0,~service,p2};
assign test_in=radial ? {6'd0,~joystick2[5],~joystick2[4]} :
                       {6'd0,test_dip[1],test_dip[0] | ~dip_test};

endmodule
