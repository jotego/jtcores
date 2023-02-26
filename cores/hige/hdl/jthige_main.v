/*  This file is part of JTGNG.
    JTGNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTGNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTGNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-9-2020 */

module jthige_main(
    input              clk,
    input              cen6,
    input              cen3,
    input              cen1p5,
    output             cpu_cen,
    input              rst,
    output             [7:0] cpu_dout,
    output  reg        flip,
    input   [7:0]      V,
    input              LHBL,
    input              dip_pause,
    // Sound
    output             sample,
    output signed [15:0] snd, // sound reset
    // Char
    output  reg        char_cs,
    input              char_busy,
    input              [7:0] char_dout,
    // Object
    output  reg        obj_cs,
    // cabinet I/O
    input   [4:0]      joystick1,
    input   [4:0]      joystick2,
    input   [1:0]      start_button,
    input   [1:0]      coin_input,
    // BUS sharing
    output  [12:0]     cpu_AB,
    output             rd_n,
    output             wr_n,
    // RAM
    output             ram_we,
    input       [ 7:0] ram_dout,
    // ROM access
    output  reg        rom_cs,
    output      [14:0] rom_addr,
    input       [ 7:0] rom_data,
    input              rom_ok,
    // DIP switches
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b,
    // PROM F1
    input    [7:0]     prog_addr,
    input              prom_irq_we,
    input    [3:0]     prog_din
);

wire [15:0] A;
wire [ 7:0] ay0_dout, ay1_dout, irq_vector;
reg  [ 7:0] cabinet_input, cpu_din;
wire [3:0] int_ctrl;
reg         t80_rst_n, in_cs, ram_cs, misc_cs, ay0_cs, ay1_cs;
wire        mreq_n, rfsh_n, iorq_n, m1_n, busak_n, irq_ack;

assign irq_ack    = !iorq_n && !m1_n;
assign cpu_AB     = A[12:0];
assign ram_we     = ram_cs && !wr_n;
assign irq_vector = {3'b110, int_ctrl[1:0], 3'b111 }; // Same as 1942 (Schematic K10)

assign cpu_cen  = cen3;
assign rom_addr = A[14:0];

always @(*) begin
    rom_cs  = 0;
    ram_cs  = 0;
    ay0_cs  = 0;
    ay1_cs  = 0;
    misc_cs = 0;
    in_cs   = 0;
    char_cs = 0;
    obj_cs  = 0;
    rom_cs  = 0;
    if( rfsh_n && !mreq_n ) casez(A[15:13])
        3'b0??: rom_cs  = 1'b1;
        3'b110: // cscd
            case(A[12:11])
                2'b00: // C0CS
                    in_cs = 1'b1;
                2'b01: // C8
                    casez(A[2:0])
                        3'b000: misc_cs  = 1;
                        3'b001, 3'b010: ay0_cs = 1;
                        3'b011, 3'b100: ay1_cs = 1;
                        default:;
                    endcase
                2'b10: char_cs = 1'b1; // D0CS
                2'b11: obj_cs  = A[8:7]>=2'b01; // D880 - D9FF
            endcase
        3'b111: ram_cs = A[12]==1'b0; // csef
        default:;
    endcase
end

// special registers
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        flip     <= 0;
    end else if(cen3) begin
        if( misc_cs  ) begin
            // cpu_dout[1:0] are coin counters
            flip <= cpu_dout[7];
        end
    end
end

always @(posedge clk) begin
    t80_rst_n <= ~rst;
end

always @(*) begin
    case( A[2:0] )
        3'd0: cabinet_input = { 4'hf, joystick1[3:0] };
        3'd1: cabinet_input = { 4'hf, joystick2[3:0] & joystick1[3:0] };
        3'd2: cabinet_input = { coin_input[0], coin_input[1], // COINS
                    start_button[0], start_button[1],
                    joystick1[4], dip_pause,
                    joystick2[4], 1'b1 }; // START
        3'd3: cabinet_input = dipsw_a;
        3'd4: cabinet_input = dipsw_b;
        default: cabinet_input = 8'hff;
    endcase
end

always @(*)
    if( irq_ack ) // Interrupt address
        cpu_din = irq_vector;
    else
    case( {ram_cs, char_cs, rom_cs , in_cs} )
        4'b10_00: cpu_din = ram_dout;
        4'b01_00: cpu_din = char_dout;
        4'b00_10: cpu_din = rom_data;
        4'b00_01: cpu_din = cabinet_input;
        default:   cpu_din = 8'hff;
    endcase


jtframe_prom #(.AW(8),.DW(4),.SIMFILE("../../../rom/hige/hgb4.l9")) u_vprom(
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
        int_n   <= 1'b1;
    end else if(cen3) begin // H1 == cen3
        // Schematic L6, L5 - main CPU interrupter
        LHBL_old<=LHBL;
        if( irq_ack )
            int_n <= 1;
        else if(LHBL && !LHBL_old && int_ctrl[3])
            int_n <= 0;
    end

wire cpu_cenw;

jtframe_z80wait #(1) u_wait(
    .rst_n      ( t80_rst_n ),
    .clk        ( clk       ),
    .cen_in     ( cpu_cen   ),
    .cen_out    ( cpu_cenw  ),
    .gate       (           ),
    .iorq_n     ( iorq_n    ),
    .mreq_n     ( mreq_n    ),
    .busak_n    ( busak_n   ),
    // manage access to shared memory
    .dev_busy   ( char_busy ),
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

////////// Sound

wire [9:0] sound0, sound1;

wire bdir0 = ay0_cs & ~wr_n;
wire bc0   = ay0_cs & ~wr_n & A[0];
wire bdir1 = ay1_cs & ~wr_n;
wire bc1   = ay1_cs & ~wr_n & A[0];

jt49_bus #(.COMP(2'b10)) u_ay0( // note that input ports are not multiplexed
    .rst_n  ( t80_rst_n ),
    .clk    ( clk       ),
    .clk_en ( cen1p5    ),
    .bdir   ( bdir0     ),
    .bc1    ( bc0       ),
    .din    ( cpu_dout  ),
    .sel    ( 1'b1      ),
    .dout   ( ay0_dout  ),
    .sound  ( sound0    ),
    .sample ( sample    ),
    // unused
    .IOA_in ( 8'h0      ),
    .IOA_out(           ),
    .IOB_in ( 8'h0      ),
    .IOB_out(           ),
    .A(), .B(), .C() // unused outputs
);

jt49_bus #(.COMP(2'b10)) u_ay1( // note that input ports are not multiplexed
    .rst_n  ( t80_rst_n ),
    .clk    ( clk       ),
    .clk_en ( cen1p5    ),
    .bdir   ( bdir1     ),
    .bc1    ( bc1       ),
    .din    ( cpu_dout  ),
    .sel    ( 1'b1      ),
    .dout   ( ay1_dout  ),
    .sound  ( sound1    ),
    .sample (           ),
    // unused
    .IOA_in ( 8'h0      ),
    .IOA_out(           ),
    .IOB_in ( 8'h0      ),
    .IOB_out(           ),
    .A(), .B(), .C() // unused outputs
);

jtframe_jt49_filters u_filters(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .din0   ( sound0    ),
    .din1   ( sound1    ),
    .sample ( sample    ),
    .dout   ( snd       )
);

endmodule