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
    input              rst,
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
    output  reg [1:0]  scrpos_cs,
    output  reg [2:0]  scr_br,
    // cheat!
    input              cheat_invincible,
    // Object
    output  reg        obj_cs,
    // cabinet I/O
    input   [5:0]      joystick1,
    input   [5:0]      joystick2,
    input   [1:0]      start_button,
    input   [1:0]      coin_input,
    // BUS sharing
    output  [12:0]     cpu_AB,
    output             rd_n,
    output             wr_n,
    // ROM access
    output  reg [16:0] rom_addr,
    input       [ 7:0] rom_data,
    // DIP switches
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b,
    output reg         coin_cnt,
    // PROM F1
    input    [7:0]     prog_addr,
    input              prom_k6_we,
    input    [3:0]     prog_din
);

wire [15:0] A;
wire [ 7:0] ram_dout;
reg t80_rst_n;
reg main_cs, in_cs, ram_cs, bank_cs, flip_cs, brt_cs;

wire mreq_n;

always @(*) begin
    main_cs       = 1'b0;
    ram_cs        = 1'b0;
    snd_latch0_cs = 1'b0;
    snd_latch1_cs = 1'b0;
    scrpos_cs     = 2'b0;
    flip_cs       = 1'b0;
    bank_cs       = 1'b0;
    in_cs         = 1'b0;
    char_cs       = 1'b0;
    scr_cs        = 1'b0;
    brt_cs        = 1'b0;
    obj_cs        = 1'b0;    
    casez(A[15:13])
        3'b0??: main_cs = 1'b1;
        3'b10?: main_cs = 1'b1; // bank
        3'b110: // cscd
            case(A[12:11])
                2'b00: // COCS
                    in_cs = 1'b1;
                2'b01:
                    if( A[10]==1'b1 )
                        obj_cs = 1'b1;
                    else if(!wr_n)
                        casez(A[2:0])
                            3'b000: snd_latch0_cs = 1'b1;
                            3'b001: snd_latch1_cs = 1'b1;
                            3'b010: scrpos_cs     = 2'b01;
                            3'b011: scrpos_cs     = 2'b10;
                            3'b100: flip_cs       = 1'b1;
                            3'b101: brt_cs        = 1'b1;
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
        bank      <= 2'd0;
        scr_br    <= 3'b0;
        flip     <= 1'b0;
        sres_b   <= 1'b1;
        coin_cnt <= 1'b0;
    end
    else if(cen3) begin
        if( bank_cs  ) begin
            bank   <= cpu_dout[1:0];
            `ifdef SIMULATION
            $display("Bank changed to %d", cpu_dout[1:0]);
            `endif
        end
        if (brt_cs ) scr_br <= cpu_dout[2:0];
        if( flip_cs ) begin
            flip     <=  cpu_dout[7];
            sres_b   <= ~cpu_dout[4];
            coin_cnt <= ~cpu_dout[0];
        end
    end

always @(negedge clk)
    t80_rst_n <= ~rst;

`ifdef SIMULATION
wire [7:0] random;

noise_gen u_noise(
    .rst    ( rst    ),
    .clk    ( clk    ),
    .cen    ( cen3   ),
    .noise  ( random )
);
`endif

reg [7:0] cabinet_input;

always @(*)
    case( A[2:0] )
        3'd0: cabinet_input = { coin_input, // COINS
                     4'hf, // undocumented. The game start screen has background when set to 0!
                     start_button }; // START
        3'd1: cabinet_input = { 2'b11, joystick1 };
        3'd2: cabinet_input = { 2'b11, joystick2 };
        3'd3: cabinet_input = dipsw_a;
        3'd4: cabinet_input = dipsw_b;

        `ifdef FIRMWARE_SIM
        3'd5: cabinet_input = random;
        3'd6: if(in_cs) begin
                $display("INFO: Simulation finished as per firmware request. (%m)");
                #100 $finish;
            end
        `endif
        default: cabinet_input = 8'hff;
    endcase


// RAM, 8kB
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
wire irq_ack = !iorq_n && !m1_n;
wire [7:0] irq_vector = {3'b110, int_ctrl[1:0], 3'b111 }; // Schematic K10

always @(*)
    if( irq_ack ) // Interrupt address
        cpu_din = irq_vector;
    else
    case( {ram_cs, char_cs, scr_cs, main_cs, in_cs} )
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

jtgng_prom #(.aw(8),.dw(4),.simfile("../../../rom/1942/sb-1.k6")) u_vprom(
    .clk    ( clk          ),
    .cen    ( cen6         ),
    .data   ( prog_din     ),
    .wr_addr( prog_addr    ),
    .rd_addr( V[7:0]       ),
    .we     ( prom_k6_we   ),
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
        else if(LHBL && !LHBL_old && int_ctrl[3]) int_n <= 1'b0;
    end

wire wait_n = scr_wait_n & char_wait_n;

`ifdef SIMULATION
`define Z80_ALT_CPU
`endif

//`ifdef NCVERILOG
//`undef Z80_ALT_CPU
//`endif

`ifdef VERILATOR_LINT 
`define Z80_ALT_CPU
`endif



`ifndef Z80_ALT_CPU
// This CPU is used for synthesis
wire [211:0] z80_regs;
`ifdef SIMULATION
wire reg_IFF2; 
wire reg_IFF1; 
wire [1:0]  reg_IM;    // 4
wire [15:0] reg_IY; 
wire [15:0] reg_HL_; 
wire [15:0] reg_DE_; 
wire [15:0] reg_BC_; 
wire [15:0] reg_IX; 
wire [15:0] reg_HL; 
wire [15:0] reg_DE; 
wire [15:0] reg_BC; 
wire [15:0] reg_PC; 
wire [15:0] reg_SP; // 164 
wire [7:0]  reg_R; 
wire [7:0]  reg_I; 
wire [7:0]  reg_F_; 
wire [7:0]  reg_A_; 
wire [7:0]  reg_F; 
wire [7:0]  reg_A;
assign { 
    reg_IFF2, reg_IFF1, reg_IM, reg_IY, reg_HL_, reg_DE_, reg_BC_, 
    reg_IX, reg_HL, reg_DE, reg_BC, reg_PC, reg_SP, reg_R, reg_I, 
    reg_F_, reg_A_, reg_F, reg_A } = z80_regs; 
`endif
T80s u_cpu(
    .RESET_n    ( t80_rst_n   ),
    .CLK        ( clk         ),
    .CEN        ( cen3        ),
    .WAIT_n     ( wait_n      ),
    .INT_n      ( int_n       ),
    .RD_n       ( rd_n        ),
    .WR_n       ( wr_n        ),
    .A          ( A           ),
    .DI         ( cpu_din     ),
    .DO         ( cpu_dout    ),
    .IORQ_n     ( iorq_n      ),
    .M1_n       ( m1_n        ),
    .MREQ_n     ( mreq_n      ),
    .NMI_n      ( 1'b1        ),
    .BUSRQ_n    ( 1'b1        ),
    .out0       ( 1'b0        )
);
`else
// This CPU is used for simulation
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