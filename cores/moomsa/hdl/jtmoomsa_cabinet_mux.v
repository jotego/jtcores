/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_cabinet_mux(
    input      [7:0] p1, p2, p3, p4,
    input      [3:0] coin, dip,
    input            eeprom_do,
    input            eeprom_rdy,
    input            service,
    input            dip_test,
    input            psaca1,
    input            iocs, iocsb,
    output reg [15:0] data
);

always @* begin
    data = 16'hffff;
    if (iocs) begin
        data[0]  = psaca1 ? p2[2] : p1[2];
        data[1]  = psaca1 ? p2[3] : p1[3];
        data[2]  = psaca1 ? p2[1] : p1[1];
        data[3]  = psaca1 ? p2[0] : p1[0];
        data[4]  = psaca1 ? p2[4] : p1[4];
        data[5]  = psaca1 ? p2[5] : p1[5];
        data[6]  = psaca1 ? p2[6] : p1[6];
        data[7]  = psaca1 ? p2[7] : p1[7];
        data[8]  = psaca1 ? p4[2] : p3[2];
        data[9]  = psaca1 ? p4[3] : p3[3];
        data[10] = psaca1 ? p4[1] : p3[1];
        data[11] = psaca1 ? p4[0] : p3[0];
        data[12] = psaca1 ? p4[4] : p3[4];
        data[13] = psaca1 ? p4[5] : p3[5];
        data[14] = psaca1 ? p4[7] : p3[7];
        data[15] = psaca1 ? p4[6] : p3[6];
    end
    if (iocsb) begin
        if (psaca1) begin
            data[0] = eeprom_do;
            data[1] = eeprom_rdy;
            data[2] = 1'b0;
            data[3] = service & dip_test;
            data[4] = dip[0];
            data[5] = dip[1];
            data[6] = dip[3];
            data[7] = dip[2];
        end else begin
            data[0] = coin[0];
            data[1] = coin[1];
            data[2] = coin[2];
            data[3] = coin[3];
        end
    end
end

endmodule
