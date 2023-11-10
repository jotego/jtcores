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
    Date: 27-10-2017 */

// 1942: Main CPU


module jt1942_main(
    input              rst,
    input              clk,
    input              cen6,   // 6MHz
    input              cen3    /* synthesis direct_enable = 1 */,   // 3MHz
    output             cpu_cen,

    input        [1:0] game_id,
    output       [7:0] cpu_dout,
    output  reg        flip,
    input   [7:0]      V,
    input              LHBL,
    input              dip_pause,
    // Sound
    output  reg        sres_b, // sound reset
    output  reg        snd_int,
    output  reg        snd_latch0_cs,
    output  reg        snd_latch1_cs,
    // Higemaru
    output  reg        ay0_cs, ay1_cs,
    // Char
    output  reg        char_cs,
    input              char_busy,
    input              [7:0] char_dout,
    // scroll
    input   [7:0]      scr_dout,
    output  reg        scr_cs,
    input              scr_busy,
    output  reg [2:0]  scr_br,
    output  reg [8:0]  scr_hpos,
    output  reg [8:0]  scr_vpos,
    // cheat!
    input              cheat_invincible,
    // Object
    output  reg        obj_cs,
    // cabinet I/O
    input   [5:0]      joystick1,
    input   [5:0]      joystick2,
    input   [1:0]      cab_1p,
    input   [1:0]      coin,
    input              service,
    // BUS sharing
    output  [12:0]     cpu_AB,
    output             rd_n,
    output             wr_n,
    // ROM access
    output  reg        rom_cs,
    output  reg [16:0] rom_addr,
    input       [ 7:0] rom_data,
    input              rom_ok,
    // DIP switches
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b,
    output reg         coin_cnt,
    // PROM F1
    input    [7:0]     prog_addr,
    input              prom_irq_we,
    input    [3:0]     prog_din
);

`ifndef NOMAIN
`include "1942.vh"
wire [15:0] A;
wire [ 7:0] ram_dout, irq_vector;
reg         t80_rst_n, in_cs, ram_cs,
            bank_cs, flip_cs, brt_cs, scrpos_cs;

wire        iorq_n, m1_n, busak_n, mreq_n, rfsh_n;
reg [ 7:0] cab_dout;
// Data bus input
reg  [ 7:0] cpu_din;
wire [ 3:0] int_ctrl;
wire        irq_ack = !iorq_n && !m1_n;
// RAM, 8kB
wire        cpu_ram_we = ram_cs && !wr_n;

reg         hige=0;
reg   [1:0] bank;

assign irq_vector = {3'b110, int_ctrl[1:0], 3'b111 }; // Schematic K10
assign cpu_AB     = A[12:0];

assign cpu_cen = cen3;

always @(posedge clk) hige <= game_id==HIGEMARU;

always @(*) begin
    rom_cs        = 1'b0;
    ram_cs        = 1'b0;
    ay0_cs        = 1'b0;
    ay1_cs        = 1'b0;
    snd_latch0_cs = 1'b0;
    snd_latch1_cs = 1'b0;
    scrpos_cs     = 1'b0;
    bank_cs       = 1'b0;
    in_cs         = 1'b0;
    char_cs       = 1'b0;
    scr_cs        = 1'b0;
    brt_cs        = 1'b0;
    obj_cs        = 1'b0;
    rom_cs        = 1'b0;
    flip_cs       = 1'b0;
    if( rfsh_n && !mreq_n ) begin
        if( hige ) casez(A[15:13]) // Higemaru
            3'b0??: rom_cs  = 1'b1;
            3'b110: // cscd
                case(A[12:11])
                    2'b00: // C0CS
                        in_cs = 1'b1;
                    2'b01: // C8
                        casez(A[2:0])
                            3'b000: flip_cs  = 1;
                            3'b001, 3'b010: ay0_cs = 1;
                            3'b011, 3'b100: ay1_cs = 1;
                            default:;
                        endcase
                    2'b10: char_cs = 1'b1; // D0CS
                    2'b11: obj_cs  = A[8:7]>=2'b01; // D880 - D9FF
                endcase
            3'b111: ram_cs = A[12]==1'b0; // csef
            default:;
        endcase else casez(A[15:13]) // 1942 / Vulgus
            3'b0??: rom_cs  = 1'b1;
            3'b10?: rom_cs  = 1'b1; // bank
            3'b110: // cscd
                case(A[12:11])
                    2'b00: // C0CS
                        in_cs = 1'b1;
                    2'b01: // C8
                        if( A[10]==1'b1 ) // CC
                            obj_cs = 1'b1;
                        else if(!wr_n)
                            casez(A[2:0])
                                3'b000: snd_latch0_cs = 1'b1;
                                3'b001: snd_latch1_cs = 1'b1;
                                3'b01?: scrpos_cs     = 1'b1;
                                3'b100: flip_cs       = 1'b1;
                                3'b101: brt_cs        = 1'b1;
                                3'b110: bank_cs       = 1'b1;
                                default:;
                            endcase
                    2'b10: char_cs = 1'b1; // D0CS
                    2'b11: scr_cs  = 1'b1; // D8CS SCRCE
                endcase
            3'b111: ram_cs = A[12]==1'b0; // csef
        endcase
    end
end

// SCROLL H/V POSITION
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scr_vpos <= 0;
        scr_hpos <= 0;
    end else if(cpu_cen && scrpos_cs) begin
        if( game_id==VULGUS ) begin
            case( {A[8], A[0]} )
                2'b00: scr_vpos[7:0] <= cpu_dout;
                2'b01: scr_hpos[7:0] <= cpu_dout;
                2'b10: scr_vpos[  8] <= cpu_dout[0];
                2'b11: scr_hpos[  8] <= cpu_dout[0];
            endcase
        end else begin // 1942
            scr_vpos <= 0;
            if( A[0] )
                scr_hpos[8]   <= cpu_dout[0];
            else
                scr_hpos[7:0] <= cpu_dout;
        end
    end
end

// special registers
always @(posedge clk) begin
    if( rst ) begin
        bank     <= 0;
        scr_br   <= 0;
        flip     <= 0;
        sres_b   <= 1'b1;
        coin_cnt <= 0;
    end
    else if(cen3) begin
        if( bank_cs  ) begin
            bank   <= game_id==VULGUS ? 2'd0 : cpu_dout[1:0];
        end
        if (brt_cs ) scr_br <= cpu_dout[2:0];
        if( flip_cs ) begin
            flip     <= ~cpu_dout[7]^hige;
            sres_b   <= ~cpu_dout[4];   // only Vulgus/1942
            coin_cnt <= ~cpu_dout[0];
        end
        if( hige ) begin
            sres_b <= 0; // keep the Vulgus sound CPU off for Higemaru
            bank   <= 0;
        end
    end
end

always @(posedge clk) begin
    t80_rst_n <= ~rst;
end

always @(*) begin
    if(hige) case( A[2:0] )
        3'd0: cab_dout = { 4'hf, joystick1[3:0] };
        3'd1: cab_dout = { 4'hf, joystick2[3:0] & joystick1[3:0] };
        3'd2: cab_dout = { coin[0], coin[1], // COINS
                    cab_1p[0], cab_1p[1],
                    joystick1[4], dip_pause,
                    joystick2[4], 1'b1 }; // START
        3'd3: cab_dout = dipsw_a;
        3'd4: cab_dout = dipsw_b;
        default: cab_dout = 8'hff;
    endcase else case( A[2:0] )
        3'd0: cab_dout = { coin[0], coin[1], // COINS
                     1'd1, // Tilt ?
                     service,
                     2'b11, // undocumented. The game start screen has background when set to 0!
                     cab_1p }; // START
        3'd1: cab_dout = { 2'b11, joystick1 };
        3'd2: cab_dout = { 2'b11, joystick2 };
        3'd3: cab_dout = dipsw_a;
        3'd4: cab_dout = dipsw_b;
        default: cab_dout = 8'hff;
    endcase
end

jtframe_ram #(.AW(12)) RAM(
    .clk        ( clk       ),
    .cen        ( cen3      ),
    .addr       ( A[11:0]   ),
    .data       ( cpu_dout  ),
    .we         ( cpu_ram_we),
    .q          ( ram_dout  )
);

always @(*) begin
    cpu_din =   irq_ack ? irq_vector :
                ram_cs  ? ram_dout   :
                char_cs ? char_dout  :
                scr_cs  ? scr_dout   :
                rom_cs  ? rom_data   :
                in_cs   ? cab_dout   : 8'h0;
end

// ROM ADDRESS
always @(*) begin
    rom_addr[14:0] = A[14:0];
    if( !hige )
        rom_addr[16:14] = !A[15] ? { 2'b0, A[14] } : ( 3'b010 + {1'b0, bank});
    else
        rom_addr[16:15] = 0;
end

jtframe_prom #(.AW(8),.DW(4),.SIMFILE("../../../rom/1942/sb-1.k6")) u_vprom(
    .clk    ( clk          ),
    .cen    ( cen6         ),
    .data   ( prog_din     ),
    .wr_addr( prog_addr    ),
    .rd_addr( V[7:0]       ),
    .we     ( prom_irq_we  ),
    .q      ( int_ctrl     )
);

// interrupt generation
reg int_n, LHBL_old;

always @(posedge clk) begin
    if (rst) begin
        snd_int <= 1'b1;
        int_n   <= 1'b1;
    end else if(cen3) begin // H1 == cen3
        // Schematic L5 - sound interrupter
        snd_int <= int_ctrl[2];
        // Schematic L6, L5 - main CPU interrupter
        LHBL_old<=LHBL;
        if( irq_ack )
            int_n <= 1'b1;
        else if(LHBL && !LHBL_old && int_ctrl[3])
            int_n <= ~dip_pause;
    end
end

wire cpu_cenw;

jtframe_z80wait #(2) u_wait(
    .rst_n      ( t80_rst_n ),
    .clk        ( clk       ),
    .cen_in     ( cpu_cen   ),
    .cen_out    ( cpu_cenw  ),
    .iorq_n     ( iorq_n    ),
    .mreq_n     ( mreq_n    ),
    .busak_n    ( busak_n   ),
    .gate       (           ),
    // manage access to shared memory
    .dev_busy   ( { scr_busy, char_busy } ),
    // manage access to ROM data from SDRAM
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    )
);

jtframe_z80 u_cpu(
    .rst_n      ( t80_rst_n   ),
    .clk        ( clk         ),
    .cen        ( cpu_cenw    ),
    .wait_n     ( 1'b1        ),
    .int_n      ( int_n       ),
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( 1'b1        ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .busak_n    ( busak_n     ),
    .A          ( A           ),
    .din        ( cpu_din     ),
    .dout       ( cpu_dout    )
);
`else
    assign cpu_AB = 0;
    assign rd_n = 1;
    assign wr_n = 1;
    assign cpu_cen = cen3;
    assign cpu_dout = 0;
    initial begin
        flip = 0;
        sres_b = 0;
        snd_int = 0;
        snd_latch0_cs = 0;
        snd_latch1_cs = 0;
        char_cs = 0;
        scr_cs = 0;
        scr_br = 0;
        scr_hpos = 0;
        scr_vpos = 0;
        obj_cs = 0;
        rom_cs = 0;
        rom_addr = 0;
        coin_cnt = 0;
    end
`endif
endmodule
