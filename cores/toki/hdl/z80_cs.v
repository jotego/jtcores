////////// Z80 CHIP SELECT /////////////////////////////////
//
//
module z80_cs 
(
    input [15:0]      z80_addr,
    input             z80_wr_n,
    input             z80_rd_n,

    output reg        z80_rom_cs,
    output reg        bank_rom_cs,
    output reg        z80_ram_cs,

    output reg        ym_cs_0,
    output reg        ym_cs_1,

    output reg        m68k_latch0_cs,
    output reg        m68k_latch1_cs,

    output reg        main_data_pending_cs,
    output reg        read_coin_cs,

    output reg        ym_wr,
    output reg        oki_wr,
    output reg        oki_rd
);

///////// z80 bus mapping  ////////////////////
//
// 0x0000, 0x1fff : rom (decrypted by sei80bu)
// 0x2000, 0x27ff : ram (2048) 8bits SRAM (rw)
// 0x4000, 0x4000 : pending data for 68k (w)
// 0x4001, 0x4001 : irq clear (wo) ?
// 0x4002, 0x4002 : rst10 ack (wo) ?
// 0x4003, 0x4003 : rst18 ack (wo) ?
// 0x4007, 0x4007 : switch bank (wo) 
// 0x4008, 0x4009 : ym3812 read / write  
// 0x4010, 0x4011 : 68k sound latch (ro) 
// 0x4012, 0x4012 : 68k data pending (ro) 
// 0x4013, 0x4013 : coin inserted (ro) 
// 0x4018, 0x4019 : z80 sound latch (wo)
// 0x401b, 0x401b : write coin inserted ? (wo) 
// 0x6000, 0x6000 : okim6295 (rw)
// 0x8000, 0xffff : bank rom data start (ro)
// if bank switch :
// 0x0000, 0x8000 : bank rom data (starting at 0x2000 from bank file) 
//

always @(*) begin
    // RAM & ROM
    z80_rom_cs = (z80_addr[15:0] < 16'h2000);
    z80_ram_cs = (z80_addr[15:0] >= 16'h2000 && z80_addr[15:0] < 16'h2800);
 
    // IO
    ym_cs_0 =  (z80_addr[15:0] == 16'h4008);
    ym_cs_1 =  (z80_addr[15:0] == 16'h4009);
    m68k_latch0_cs =  (z80_addr[15:0] == 16'h4010);
    m68k_latch1_cs =  (z80_addr[15:0] == 16'h4011);
    main_data_pending_cs =   (z80_addr[15:0] == 16'h4012);
    read_coin_cs =   (z80_addr[15:0] == 16'h4013);

    oki_rd = ((z80_addr[15:0] == 16'h6000) && (z80_rd_n == 1'b0));
    oki_wr = ((z80_addr[15:0] == 16'h6000) && (z80_wr_n == 1'b0));

    bank_rom_cs = (z80_addr[15:0] >= 16'h8000);
    ym_wr = ((z80_addr[15:0] == 16'h4008 || z80_addr[15:0] == 16'h4009)  && (z80_wr_n == 1'b0));
end 

endmodule


