/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */

// 1942: Main CPU


module jt1942_main(
    input              clk,
    input              cen6,   // 6MHz
    input              cen3    /* synthesis direct_enable = 1 */,   // 3MHz
    output             cpu_cen,
    input              rst,
    output             [7:0] cpu_dout,
    output  reg        flip,
    input   [7:0]      V,
    input              LHBL,
    input              dip_pause,
    // Sound
    output  reg        sres_b, // sound reset
    output  reg        snd_int,
    output  reg        snd_latch0_cs,
    output  reg        snd_latch1_cs,
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
    input   [1:0]      start_button,
    input   [1:0]      coin_input,
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
    input              dip_flip,    // Not a DIP in the original board ;-)
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b,
    output reg         coin_cnt,
    // PROM F1
    input    [7:0]     prog_addr,
    input              prom_irq_we,
    input    [3:0]     prog_din
);

parameter VULGUS=1'b0;
`ifndef NOMAIN
wire [15:0] A;
wire [ 7:0] ram_dout, irq_vector;
reg         t80_rst_n, in_cs, ram_cs,
            bank_cs, flip_cs, brt_cs, scrpos_cs;

wire        iorq_n, m1_n, busak_n, mreq_n, rfsh_n;
reg [ 7:0] cabinet_input;
// Data bus input
reg  [ 7:0] cpu_din;
wire [ 3:0] int_ctrl;
wire        irq_ack = !iorq_n && !m1_n;
// RAM, 8kB
wire        cpu_ram_we = ram_cs && !wr_n;

assign irq_vector = {3'b110, int_ctrl[1:0], 3'b111 }; // Schematic K10
assign cpu_AB     = A[12:0];

assign cpu_cen = cen3;

always @(*) begin
    rom_cs        = 1'b0;
    ram_cs        = 1'b0;
    snd_latch0_cs = 1'b0;
    snd_latch1_cs = 1'b0;
    scrpos_cs     = 1'b0;
    flip_cs       = 1'b0;
    bank_cs       = 1'b0;
    in_cs         = 1'b0;
    char_cs       = 1'b0;
    scr_cs        = 1'b0;
    brt_cs        = 1'b0;
    obj_cs        = 1'b0;
    rom_cs        = 1'b0;
    if( rfsh_n && !mreq_n ) casez(A[15:13])
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

// SCROLL H/V POSITION
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scr_vpos <= 0;
        scr_hpos <= 0;
    end else if(cpu_cen && scrpos_cs) begin
        if( VULGUS ) begin
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
reg [1:0] bank;
always @(posedge clk)
    if( rst ) begin
        bank     <= 0;
        scr_br   <= 0;
        flip     <= 0;
        sres_b   <= 1'b1;
        coin_cnt <= 0;
    end
    else if(cen3) begin
        if( bank_cs  ) begin
            bank   <= VULGUS ? 2'd0 : cpu_dout[1:0];
        end
        if (brt_cs ) scr_br <= cpu_dout[2:0];
        if( flip_cs ) begin
            `ifdef VULGUS
            flip     <=  cpu_dout[7] ^ ~dip_flip; // Vulgus doesn't have a real dip_flip
            `else
            flip     <=  cpu_dout[7];
            `endif
            sres_b   <= ~cpu_dout[4];
            coin_cnt <= ~cpu_dout[0];
        end
    end

always @(posedge clk) begin
    t80_rst_n <= ~rst;
end

always @(*) begin
    case( A[2:0] )
        3'd0: cabinet_input = { coin_input[0], coin_input[1], // COINS
                     1'd1, // Tilt ?
                     service,
                     2'b11, // undocumented. The game start screen has background when set to 0!
                     start_button }; // START
        3'd1: cabinet_input = { 2'b11, joystick1 };
        3'd2: cabinet_input = { 2'b11, joystick2 };
        3'd3: cabinet_input = dipsw_a;
        3'd4: cabinet_input = dipsw_b;

        // `ifdef FIRMWARE_SIM
        // 3'd5: cabinet_input = random;
        // 3'd6: if(in_cs) begin
        //         $display("INFO: Simulation finished as per firmware request. (%m)");
        //         #100 $finish;
        //     end
        // `endif
        default: cabinet_input = 8'hff;
    endcase
end

jtframe_ram #(.aw(12)) RAM(
    .clk        ( clk       ),
    .cen        ( cen3      ),
    .addr       ( A[11:0]   ),
    .data       ( cpu_dout  ),
    .we         ( cpu_ram_we),
    .q          ( ram_dout  )
);

always @(*)
    if( irq_ack ) // Interrupt address
        cpu_din = irq_vector;
    else
    case( {ram_cs, char_cs, scr_cs, rom_cs , in_cs} )
        5'b10_000: cpu_din =  (cheat_invincible && A==16'he0a5) ? 8'h2 : ram_dout;
        5'b01_000: cpu_din = char_dout;
        5'b00_100: cpu_din =  scr_dout;
        5'b00_010: cpu_din =  rom_data;
        5'b00_001: cpu_din =  cabinet_input;
        default:   cpu_din =  rom_data;
    endcase

// ROM ADDRESS
always @(*) begin
    rom_addr[13:0] = A[13:0];
    //rom_addr[16:14] = { 1'b0, A[15:14] } + (!A[15] ? 3'd0 : {1'b0, bank});
    rom_addr[16:14] = !A[15] ? { 2'b0, A[14] } : ( 3'b010 + {1'b0, bank});
end

jtframe_prom #(.aw(8),.dw(4),.simfile("../../../rom/1942/sb-1.k6")) u_vprom(
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

always @(posedge clk)
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