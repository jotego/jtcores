/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1;
always #5 clk=~clk;
reg [23:1] address=0;
reg as_n=1, uds_n=1, lds_n=1, rw=1;
reg rom_ok=0, ground_ok=0;
wire rom_cs, ground_cs;
integer i, n, restore_file, restore_count;
reg [7:0] restore_expected [0:33];

jtapach3_sub u_sub (
    .rst               ( rst       ),
    .clk               ( clk       ),
    .halt              ( 1'b0      ),
    .vblank            ( 1'b0      ),
    .reset_n           (           ),
    .z80_halt          (           ),
    .rotate_data       (           ),
    .rotate_we         (           ),
    .road_z            (           ),
    .slave_rom_addr    (           ),
    .slave_rom_cs      ( rom_cs    ),
    .slave_rom_data    ( 16'h1234  ),
    .slave_rom_ok      ( rom_ok    ),
    .sharedram_addr    (           ),
    .sharedram_din     (           ),
    .sharedram_dout    ( 16'h5678  ),
    .sharedram_we      (           ),
    .spriteram_addr    (           ),
    .spriteram_din     (           ),
    .spriteram_dout    ( 16'h9abc  ),
    .spriteram_we      (           ),
    .obj_ctrl_ram_addr (           ),
    .obj_ctrl_ram_din  (           ),
    .obj_ctrl_ram_dout ( 16'hdef0  ),
    .obj_ctrl_ram_we   (           ),
    .ground_ram_addr   (           ),
    .ground_ram_cs     ( ground_cs ),
    .ground_ram_we     (           ),
    .ground_ram_din    (           ),
    .ground_ram_dsn    (           ),
    .ground_ram_data   ( 16'h1122  ),
    .ground_ram_ok     ( ground_ok ),
    .m68k_z80ram_addr  (           ),
    .m68k_z80ram_din   (           ),
    .m68k_z80ram_dout  ( 8'h33     ),
    .m68k_z80ram_we    (           )
);

task wait_for_hold;
    begin
        n=0;
        while (!u_sub.u_dtack.hold_cpu && n<200) begin @(negedge clk); n=n+1; end
        if (!u_sub.u_dtack.hold_cpu || !u_sub.dtack_n) $fatal(1,"68000 failed to hold for memory");
        repeat (40) begin
            @(negedge clk);
            if (u_sub.cpu_cen || u_sub.cpu_cenb || !u_sub.dtack_n) $fatal(1,"68000 moved during memory stall");
        end
    end
endtask

task finish_transfer;
    begin
        n=0;
        while (u_sub.dtack_n && n<200) begin @(negedge clk); n=n+1; end
        if (u_sub.dtack_n) $fatal(1,"68000 did not receive DTACK");
        repeat (4) @(negedge clk);
        as_n=1; uds_n=1; lds_n=1;
        repeat (30) @(negedge clk);
    end
endtask

initial begin
    restore_file=$fopen("rest.bin","rb");
    restore_count=0;
    if (restore_file) begin
        restore_count=$fread(restore_expected,restore_file);
        $fclose(restore_file);
    end
    force u_sub.addr=address;
    force u_sub.as_n=as_n;
    force u_sub.uds_n=uds_n;
    force u_sub.lds_n=lds_n;
    force u_sub.rw=rw;
    force u_sub.fc=3'b000;
    repeat (8) @(negedge clk);
    rst=0;
    if (restore_count>=33 && u_sub.road_z !== restore_expected[32]) $fatal(1,"road Z restore");
    repeat (8) @(negedge clk);
    address=0; as_n=0; uds_n=0; lds_n=0; rom_ok=0;
    wait_for_hold();
    if (!rom_cs || ground_cs) $fatal(1,"ROM request select");
    rom_ok=1;
    finish_transfer();
    address=24'h0d0000>>1; as_n=0; uds_n=0; lds_n=0; ground_ok=0;
    wait_for_hold();
    if (!ground_cs || rom_cs) $fatal(1,"ground request select");
    ground_ok=1;
    finish_transfer();
    address=24'h080000>>1; as_n=0; uds_n=0; lds_n=0;
    n=0;
    while (u_sub.dtack_n && n<100) begin @(negedge clk); n=n+1; end
    if (u_sub.dtack_n || u_sub.bus_busy) $fatal(1,"BRAM access did not acknowledge");
    $display("PASS 68000 DTACK stalls on ROM/ground and resumes on acknowledgement");
    $finish;
end
initial begin
    #100000;
    $fatal(1,"68000 wait test timed out");
end
endmodule
