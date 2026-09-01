/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_cabinet(
    input      [7:0] p1, p2, p3, p4,
    input      [3:0] coin,
    input      [3:0] dip,
    input            eeprom_do,
    input            eeprom_rdy,
    input            service,
    input            dip_test,
    input            psaca1,
    input            iocs,
    input            iocsb,
    output     [15:0] data
);

jtmoomsa_cabinet_mux u_mux(
    .p1(p1), .p2(p2), .p3(p3), .p4(p4), .coin(coin), .dip(dip),
    .eeprom_do(eeprom_do), .eeprom_rdy(eeprom_rdy),
    .service(service), .dip_test(dip_test), .psaca1(psaca1),
    .iocs(iocs), .iocsb(iocsb),
    .data(data)
);

endmodule
