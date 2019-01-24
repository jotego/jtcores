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
    input              cen6    /* synthesis direct_enable = 1 */,   // 6MHz
    input              cen3    /* synthesis direct_enable = 1 */,   // 3MHz
    input              cen1p5  /* synthesis direct_enable = 1 */,   // 1.5MHz
    input              rst,
    input              soft_rst,
    input              [7:0] char_dout,
    output             [7:0] cpu_dout,
    output  reg        char_cs,
    input              char_wait_n,
    input              scr_wait_n,
    output  reg        flip,
    input   [7:0]      V,
    input              LHBL,
    // Sound
    output  reg        sres_b, // sound reset
    output  reg        snd_int,
    output  reg        snd_latch0_cs,
    output  reg        snd_latch1_cs,
    // scroll
    input   [7:0]      scr_dout,
    output  reg        scr_cs,
    output  reg        scrpos_cs,
    // Object
    output  reg        obj_cs,
    // cabinet I/O
    input   [7:0]      joystick1,
    input   [7:0]      joystick2,
    // BUS sharing
    output  [12:0]     cpu_AB,
    output             rd_n,
    // ROM access
    output  reg [16:0] rom_addr,
    input       [ 7:0] rom_data,
    // DIP switches
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b,
    // PROM F1
    input    [7:0]     prog_addr,
    input              prom_k6_we,
    input    [3:0]     prog_din
);

wire [15:0] A;
wire [ 7:0] ram_dout;
reg t80_rst_n;
reg main_cs, in_cs, ram_cs, bank_cs, flip_cs, 
    joy1_cs, joy2_cs, dipsw1_cs, dipsw2_cs;

wire mreq_n;

always @(A,rd_n) begin
    main_cs       = 1'b0;
    ram_cs        = 1'b0;
    snd_latch0_cs = 1'b0;
    snd_latch1_cs = 1'b0;
    scrpos_cs     = 1'b0;
    flip_cs       = 1'b0;
    bank_cs       = 1'b0;
    in_cs         = 1'b0;
    joy1_cs       = 1'b0;
    joy2_cs       = 1'b0;
    dipsw1_cs     = 1'b0;
    dipsw2_cs     = 1'b0;
    char_cs       = 1'b0;
    scr_cs        = 1'b0;
    obj_cs        = 1'b0;
    casez(A[15:13])
        3'b0??: main_cs = 1'b1;
        3'b10?: main_cs = 1'b1; // bank
        3'b110: // cscd
            case(A[12:11])
                2'b00: // COCS
                    if( !rd_n )
                        case(A[2:0])
                            3'b000: in_cs     = 1'b1; // coin, 1p/2p start...
                            3'b001: joy1_cs   = 1'b1;
                            3'b010: joy2_cs   = 1'b1;
                            3'b011: dipsw1_cs = 1'b1;
                            3'b100: dipsw2_cs = 1'b1;
                            default:;
                        endcase
                2'b01:
                    if( A[10]==1'b1 )
                        obj_cs = 1'b1;
                    else
                        casez(A[2:0])
                            3'b000: snd_latch0_cs = 1'b1;
                            3'b001: snd_latch1_cs = 1'b1;
                            3'b01?: scrpos_cs     = 1'b1;
                            3'b100: flip_cs       = 1'b1;
                            3'b110: bank_cs       = 1'b1;
                            default:;
                        endcase
                2'b10: char_cs = 1'b1; // DOCS
                2'b11: scr_cs  = 1'b1; // SCRCE
            endcase
        3'b111: ram_cs = A[12]==1'b0; // csef
    endcase
end

// special registers
reg [1:0] bank;
always @(posedge clk)
    if( rst ) begin
        t80_rst_n <= 1'b0;
        bank      <= 2'd0;
    end
    else if(cen3) begin
        if( bank_cs && rd_n ) begin
            bank <= cpu_dout[1:0];
        end
        else t80_rst_n <= ~(rst | soft_rst);
    end

localparam coinw = 4;
reg [coinw-1:0] coin_cnt1, coin_cnt2;

always @(posedge clk)
    if( rst ) begin
        coin_cnt1 <= {coinw{1'b0}};
        coin_cnt2 <= {coinw{1'b0}};
        flip <= 1'b0;
        sres_b <= 1'b1;
        end
    else if(cen3) begin
        if( flip_cs ) 
            case(A[2:0])
                3'd0: flip <= cpu_dout[0];
                3'd1: sres_b <= cpu_dout[0];
                3'd2: coin_cnt1 <= coin_cnt1+{ {(coinw-1){1'b0}}, cpu_dout[0] };
                3'd3: coin_cnt2 <= coin_cnt2+{ {(coinw-1){1'b0}}, cpu_dout[0] };
                default:;
            endcase
    end

reg [7:0] cabinet_input;

always @(*)
    case( cpu_AB[3:0])
        4'd0: cabinet_input = { joystick2[7],joystick1[7], // COINS
                     4'hf, // undocumented. The game start screen has background when set to 0!
                     joystick2[6], joystick1[6] }; // START
        4'd1: cabinet_input = { 2'b11, joystick1[5:0] };
        4'd2: cabinet_input = { 2'b11, joystick2[5:0] };
        4'd3: cabinet_input = dipsw_a;
        4'd4: cabinet_input = dipsw_b;
        default: cabinet_input = 8'hff;
    endcase


// RAM, 8kB
wire wr_n;
wire cpu_ram_we = ram_cs && !wr_n;
assign cpu_AB = A[12:0];

jtgng_ram #(.aw(12)) RAM(
    .clk        ( clk       ),
    .cen        ( cen3      ),
    .addr       ( A[11:0]   ),
    .data       ( cpu_dout  ),
    .we         ( cpu_ram_we),
    .q          ( ram_dout  )
);

// Data bus input
reg [7:0] cpu_din;
wire [3:0] int_ctrl;
wire iorq_n, m1_n;

always @(*)
    if( !iorq_n && !m1_n ) // Interrupt address
        cpu_din = {3'b110, int_ctrl[1:0], 3'b000 };
    else
    case( {ram_cs, char_cs, scr_cs, main_cs, in_cs} )
        5'b10_000: cpu_din =  ram_dout;
        5'b01_000: cpu_din = char_dout;
        5'b00_100: cpu_din =  scr_dout;
        5'b00_010: cpu_din =  rom_data;
        5'b00_001: cpu_din =  cabinet_input;
        default:   cpu_din =  rom_data;
    endcase

// ROM ADDRESS
always @(A,bank) begin
    rom_addr[13:0] = A[13:0];
    rom_addr[16:14] = { 1'b0, A[15:14] } + (!A[15] ? 3'd0 : {1'b0, bank});
end


wire [7:0] prom_k6_addr  = prom_k6_we  ? prog_addr[7:0] : V[7:0];

jtgng_ram #(.aw(8),.dw(4),.simfile("../../../rom/1942/sb-1.k6")) u_vprom(
    .clk    ( clk          ),
    .cen    ( cen6         ),
    .data   ( prog_din     ),
    .addr   ( prom_k6_addr ),
    .we     ( prom_k6_we   ),
    .q      ( int_ctrl     )
);

// interrupt generation
reg [7:0] vstatus;
reg int_n, LHBL_old;

always @(posedge clk) if(cen3) begin // H1 == cen3
    // Schematic K10
    vstatus <= { 2'b11, 1'b0, int_ctrl[1:0], 3'b111 };
    // Schematic L5 - sound interrupter
    snd_int <= int_ctrl[2];
    // Schematic L6, L5 - main CPU interrupter
    LHBL_old<=LHBL;
    if( !(iorq_n || m1_n) )
        int_n <= 1'b1;
    else if(LHBL && !LHBL_old && int_ctrl[3]) int_n <= 1'b0;
end

wire wait_n = scr_wait_n & char_wait_n;

`define Z80_ALT_CPU
`ifndef SIMULATION
`ifndef VERILATOR_LINT 
`undef Z80_ALT_CPU
T80pa u_cpu(
    .RESET_n    ( t80_rst_n   ),
    .CLK        ( clk         ),
    .CEN_p      ( cen3        ),
    .CEN_n      ( 1'b1        ),
    .WAIT_n     ( wait_n      ),
    .INT_n      ( int_n       ),
    .NMI_n      ( 1'b1        ),
    .BUSRQ_n    ( 1'b1        ),
    .RD_n       ( rd_n        ),
    .WR_n       ( wr_n        ),
    .A          ( A           ),
    .DI         ( cpu_din     ),
    .DO         ( cpu_dout    ),
    .IORQ_n     ( iorq_n      ),
    .M1_n       ( m1_n        ),
    .MREQ_n     ( mreq_n      ),
    // unused
    .REG        (),
    .RFSH_n     (),
    .BUSAK_n    (),
    .HALT_n     (),
    .MC         (),
    .TS         (),
    .IntCycle_n (),
    .IntE       (),
    .Stop       (),
    .REG        ()
);
`endif
`endif

`ifdef Z80_ALT_CPU
tv80s #(.Mode(0)) u_cpu (
    .reset_n( t80_rst_n  ),
    .clk    ( clk        ), // 3 MHz, clock gated
    .cen    ( cen3       ),
    .wait_n ( wait_n     ),
    .int_n  ( int_n      ),
    .nmi_n  ( 1'b1       ),
    .busrq_n( 1'b1       ),
    .rd_n   ( rd_n       ),
    .wr_n   ( wr_n       ),
    .A      ( A          ),
    .di     ( cpu_din    ),
    .dout   ( cpu_dout   ),
    .iorq_n ( iorq_n     ),
    .m1_n   ( m1_n       ),
    .mreq_n ( mreq_n     ),
    // unused
    .busak_n(),
    .halt_n (),
    .rfsh_n ()
);
`endif
endmodule // jtgng_main