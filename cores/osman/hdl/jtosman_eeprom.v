/* This file is part of JTCORES. GPLv3. See jtosman_game.v header.
   Author: Andrea Bogazzi.

   93C46, 64 x 16 bits. MAME ROM defaults and MiSTer .nvm saves use big-endian
   byte pairs, except Magical Drop's ROM_LOAD16_WORD_SWAP defaults. Commit only
   after both bytes arrive, and latch the word address for consecutive transfers.
   Soft reset clears the serial protocol, never the EEPROM contents.
*/
module jtosman_eeprom(
    input         rst, clk,
    input         swap_bytes, // Magical Drop / Plus: MAME ROM_LOAD16_WORD_SWAP
    input         sclk, sdi, scs,
    output        sdo,
    input  [25:0] ioctl_addr,
    input  [ 7:0] ioctl_dout,
    input         ioctl_wr, ioctl_ram,
    output [ 7:0] ioctl_din,
    output        busy
);

wire rx = ioctl_ram & ioctl_wr & (ioctl_addr < 26'd128);
reg [ 7:0] high_byte;
reg [ 5:0] high_addr;
reg        have_high = 0;
reg [15:0] write_data;
reg [ 5:0] write_addr;
reg        write_pending = 0, restoring = 0;
reg        read_low;
wire [15:0] dump_q;

always @(posedge clk) begin
    read_low <= ioctl_addr[0];
    write_pending <= 0;
    if( !ioctl_ram ) have_high <= 0;
    if( !ioctl_ram && !write_pending ) restoring <= 0;
    if( rx ) begin
        restoring <= 1;
        if( !ioctl_addr[0] ) begin
            high_byte <= ioctl_dout;
            high_addr <= ioctl_addr[6:1];
            have_high <= 1;
        end else if( have_high && high_addr==ioctl_addr[6:1] ) begin
            write_data <= swap_bytes ? {ioctl_dout, high_byte} : {high_byte, ioctl_dout};
            write_addr <= high_addr;
            write_pending <= 1;
            have_high <= 0;
        end
    end
end

wire [5:0] dump_addr = write_pending ? write_addr : ioctl_addr[6:1];

// Keep the ARM and serial interface in reset throughout a restore, including
// the final delayed word write. Uploads stall the ARM in jtosman_main instead.
assign busy = rx | restoring | write_pending;
assign ioctl_din = (read_low ^ swap_bytes) ? dump_q[7:0] : dump_q[15:8];

jt9346 #(.AW(6),.DW(16)) u_chip(
    .rst(rst | busy), .clk(clk),
    .sclk(sclk), .sdi(sdi), .sdo(sdo), .scs(scs),
    .dump_clk(clk), .dump_addr(dump_addr),
    .dump_we(write_pending), .dump_din(write_data), .dump_dout(dump_q),
    .dump_clr(ioctl_ram), .dump_flag()
);
endmodule
