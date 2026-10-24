/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-10-2026 */

module test;
reg frisky, radial, service, dip_test;
reg [1:0] cab_1p, coin;
reg [5:0] joystick1, joystick2;
reg [7:0] test_dip;
wire [7:0] in0, in1, test_in;
reg [7:0] want0, want1, want_test;
integer mode, keys, pattern, bitno;

jtseicro_cab dut(.*);

initial begin
    for(mode=0;mode<3;mode=mode+1) begin
        frisky=mode==1;
        radial=mode==2;
        for(keys=0;keys<4;keys=keys+1) begin
            service=keys[0];
            dip_test=keys[1];
            for(pattern=0;pattern<65536;pattern=pattern+1) begin
                {cab_1p,coin,joystick1,joystick2}=pattern[15:0];
                test_dip=pattern[7:0];
                want0=0;
                want1=0;
                want_test=0;
                for(bitno=0;bitno<4;bitno=bitno+1) begin
                    want0[bitno]=!joystick1[3-bitno];
                    want1[bitno]=!joystick2[3-bitno];
                end
                want0[4]=!coin[0];
                want0[5]=!coin[1];
                want0[6]=!cab_1p[0];
                want0[7]=!cab_1p[1];
                want1[4]=!service;
                case(mode)
                    0: begin
                        want1[6]=!joystick1[4];
                        want1[7]=!joystick2[4];
                        want_test[0]=test_dip[0] || !dip_test;
                        want_test[1]=test_dip[1];
                    end
                    1: begin
                        want1[5]=test_dip[5];
                        want1[7]=test_dip[7];
                        want_test[0]=test_dip[0] || !dip_test;
                        want_test[1]=test_dip[1];
                    end
                    2: begin
                        want1[5]=!joystick1[4];
                        want1[6]=!joystick1[5];
                        want_test[0]=!joystick2[4];
                        want_test[1]=!joystick2[5];
                    end
                endcase
                #1;
                if(in0!==want0 || in1!==want1 || test_in!==want_test)
                    $fatal(1,"Cabinet mode=%0d inputs=%h got=%h/%h/%h want=%h/%h/%h",
                        mode,pattern,in0,in1,test_in,want0,want1,want_test);
            end
        end
    end
    $display("PASS cabinet: 786432 input patterns across Seicross, Frisky Tom and Radical Radial");
    $finish;
end
endmodule
