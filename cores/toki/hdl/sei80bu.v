////////// sei80bu  ///////////////////////////////
//
// sei80bu decrypt the z80 encrypted rom
// address is used as key to decrypt for rom data
// decrypt rom opcode if m1 high or data if m1 low
//
module sei80bu(
    input             clk,
    input      [15:0] rom_addr,
    input       [7:0] rom_data,
    input             rom_ok,
    input             rom_cs,

    input             z80_m1,

    output reg  [7:0] dec_data,
    output reg        dec_ok
);

always @(posedge clk) begin
    if (rom_cs == 1'b1 && rom_ok == 1'b1) begin
        dec_data[(z80_m1 &&(rom_addr[11] & ~rom_addr[6])) ? 6 : 7]
                                            <= (rom_addr[9] & rom_addr[8])
                                                    ? rom_data[7] ^ 1'b1
                                                    : rom_data[7];

        dec_data[(z80_m1 &&(rom_addr[11] & ~rom_addr[6])) ? 7 : 6]
                                            <=(rom_addr[11] & rom_addr[4] & rom_addr[1])
                                                ? rom_data[6] ^ 1'b1
                                                : rom_data[6];

        dec_data[(z80_m1 &&(rom_addr[12] & rom_addr[9])) ? 4 : 5]
                                            <= (z80_m1 && (~rom_addr[13] & rom_addr[12]))
                                                        ? rom_data[5] ^ 1'b1
                                                        : rom_data[5];

        dec_data[(z80_m1 &&(rom_addr[12] & rom_addr[9])) ? 5 : 4]
                                            <= (z80_m1 && (~rom_addr[6] & rom_addr[1]))
                                                        ? rom_data[4] ^ 1'b1
                                                        : rom_data[4];


        dec_data[rom_addr[8] & rom_addr[4] ? 2 : 3]
                                        <= (z80_m1 &&(~rom_addr[12] & rom_addr[2]))
                                                        ? rom_data[3] ^ 1'b1
                                                        : rom_data[3];

        dec_data[rom_addr[8] & rom_addr[4] ? 3 : 2]
                                            <= (rom_addr[11] & ~rom_addr[8] & rom_addr[1])
                                                        ? rom_data[2] ^ 1'b1
                                                        : rom_data[2];


        dec_data[(rom_addr[13] & rom_addr[4]) ? 0  : 1]
                                            <= (rom_addr[13] & ~rom_addr[6] & rom_addr[4])
                                                        ? rom_data[1] ^ 1'b1
                                                        : rom_data[1];

        dec_data[(rom_addr[13] & rom_addr[4]) ? 1 : 0]
                                        <= (~rom_addr[11] & rom_addr[9] & rom_addr[2])
                                                        ? rom_data[0] ^ 1'b1
                                                        : rom_data[0];
        dec_ok <= 1;
        end
        else if (rom_cs == 1'b0)
            dec_ok <= 1'b0;
        else if (rom_ok == 1'b0)
            dec_ok <= 1'b0;
end

endmodule
