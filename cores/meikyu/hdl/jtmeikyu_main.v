/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 30-4-2022 */

module jtmeikyu_main(
    input              clk,
    input              rst,
    input              cpu_cen,

    // BUS sharing
    output      [17:0] main_addr,
    output             main_rnw,
    output             [7:0] cpu_dout,

    // Video configuration
    output  reg        flip,
    input              LVBL,
    input              dip_pause,
    // Sound
    output  reg        latch_wr,
    // scroll
    output  reg [ 8:0] scr1pos,
    // Object
    output  reg        scr_cs,
    output  reg        obj_cs,
    output  reg        pal_cs,
    input   [7:0]      pal_dout,
    input   [7:0]      scr_dout,
    input   [7:0]      obj_dout,
    // cabinet I/O
    input   [5:0]      joystick1,
    input   [5:0]      joystick2,
    input   [1:0]      cab_1p,
    input   [1:0]      coin,
    input              service,
    // DIP switches
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b,
    // ROM access
    output  reg        rom_cs,
    input       [ 7:0] rom_data,
    // input       [ 7:0] debug_bus,
    input              rom_ok
);
`ifndef NOMAIN

wire [15:0] A;
wire [ 7:0] ram_dout;
reg  [ 7:0] cpu_din;
reg  [ 2:0] bank;
reg         rst_n, ram_cs, dip1_cs, dip2_cs,
            in0_cs, in1_cs, in2_cs, objrd_cs,
            bank_cs, coin_cs;
reg         flipr;
wire        rd_n, wr_n, mreq_n, rfsh_n, iorq_n;
wire        int_n;

assign main_rnw = wr_n;
assign int_n    = LVBL | ~dip_pause;
assign main_addr = A[15] ? { 1'b0, bank, A[13:0] } + 18'h8000 : { 3'd0, A[14:0] };

always @(posedge clk) rst_n <= ~rst;

always @* begin
    // Memory mapped - shared
    rom_cs  = !mreq_n && rfsh_n && ( !A[15] || A[15:14]==2'b10 ); // 16kB Banks x 8 = 128
    scr_cs  = !mreq_n && rfsh_n && A[15:12]==4'hd;     // videoram D000-DFFF
    pal_cs  = !mreq_n && rfsh_n && A[15:11]==5'b11001; // palette   C800-CFFF
    ram_cs  = !mreq_n && rfsh_n && A[15:13]==3'b111;   // work RAM  E000-FFFF (8k)
    // write-only strobe: obj_cs drives the sprite-RAM BRAM write-enable, so it
    // must NOT assert on reads (a read would clobber the table with the bus).
    obj_cs  = !mreq_n && rfsh_n && !wr_n && A[15:8]==8'hc0;   // spriteram C000-C0FF
    // read side of the same region: the CPU does read-modify-write on the
    // sprite table, so it must read back real data (else RMW writes 0xFF back).
    objrd_cs= !mreq_n && rfsh_n && A[15:8]==8'hc0;

    // kikcubic_io_map (global_mask 0xff)
    dip1_cs  = !iorq_n && !rd_n && A[2:0]==0; // DSW1
    dip2_cs  = !iorq_n && !rd_n && A[2:0]==1; // DSW2
    in0_cs   = !iorq_n && !rd_n && A[2:0]==2; // IN0 (P1 joy+buttons)
    in1_cs   = !iorq_n && !rd_n && A[2:0]==3; // IN1 (start/coin)
    in2_cs   = !iorq_n && !rd_n && A[2:0]==4; // IN2 (P2 cocktail)
    coin_cs  = !iorq_n && !wr_n && A[2:0]==0; // coin counters + flip (bit0)
    bank_cs  = !iorq_n && !wr_n && A[2:0]==4; // PBANK
    latch_wr = !iorq_n && !wr_n && A[2:0]==6; // soundlatch
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank    <= 0;
        scr1pos <= 0;   // kikcubic does not scroll: stays at 0
        flip    <= 0;
    end else begin
        flip <= flipr ^ dipsw_b[0];
        if( bank_cs ) bank  <= cpu_dout[2:0];
        if( coin_cs ) flipr <= cpu_dout[0]; // coin_w bit0 = flip screen
    end
end

// always @(posedge clk) begin
always @* begin
    // kikcubic button bits are swapped vs vigilant (IN0 bit7=B1,bit5=B2; MAME)
    // IN1 carries start (cab_1p) + coins; service is a DSW2 bit, not a line.
    cpu_din =
        rom_cs  ? rom_data :
        ram_cs  ? ram_dout :
        pal_cs  ? pal_dout :
        objrd_cs? obj_dout :
        scr_cs  ? scr_dout : // I think the scroll cannot be read, but sch. are blurry
        in0_cs  ? { joystick1[4], 1'b1, joystick1[5], 1'b1, joystick1[3:0] } :
        in1_cs  ? { 2'b11, coin[1], coin[0], 2'b11, cab_1p[1], cab_1p[0] }    :
        in2_cs  ? { joystick2[4], 1'b1, joystick2[5], 1'b1, joystick2[3:0] }  :
        dip1_cs ? dipsw_a  :
        dip2_cs ? dipsw_b  : 8'hff;
end

jtframe_sysz80 #(
    .RAM_AW     ( 13        ), // kikcubic E000-FFFF = 8k;
    .CLR_INT    ( 1         )
    // .RECOVERY   ( 0         )
) u_cpu(
    .rst_n      ( rst_n     ),
    .clk        ( clk       ),
    .cen        ( cpu_cen   ),
    .cpu_cen    (           ),
    .int_n      ( int_n     ),
    .nmi_n      ( 1'b1      ),
    .busrq_n    ( 1'b1      ),
    .m1_n       (           ),
    .mreq_n     ( mreq_n    ),
    .iorq_n     ( iorq_n    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .rfsh_n     ( rfsh_n    ),
    .halt_n     (           ),
    .busak_n    (           ),
    .A          ( A         ),
    .cpu_din    ( cpu_din   ),
    .cpu_dout   ( cpu_dout  ),
    .ram_dout   ( ram_dout  ),
    // ROM access
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    )
);

`else
    integer f, fcnt;
    reg [7:0] dump[0:3];
    initial begin
        pal_cs    = 0;
        scr_cs    = 0;
        scr1pos   = 0;
        latch_wr  = 0;
        rom_cs    = 0;
        obj_cs    = 0;
        flip      = 1;
        // Scene read. rest.bin: byte0/byte2[0] = scr1pos, byte3[4] = flip
        f = $fopen("rest.bin","r");
        if( f!=0 ) begin
            fcnt = $fread(dump,f);
            $display("-%-12s (%4d bytes) %m","rest.bin",fcnt);
            scr1pos = { dump[2][0],dump[0] };
            flip    = dump[3][4];
            $fclose(f);
        end
    end
    assign  main_addr = 0;
    assign  main_rnw  = 1;
    assign  cpu_dout  = 0;
`endif

endmodule