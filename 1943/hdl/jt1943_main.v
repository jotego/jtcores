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
    Date: 18-2-2019 */

// 1943: Main CPU

`timescale 1ns/1ps

module jt1943_main(
    input              clk,
    input              cen6,   // 6MHz
    input              cen3    /* synthesis direct_enable = 1 */,   // 3MHz
    input              rst,
    // Timing
    output  reg        flip,
    input   [8:0]      V,
    input              LHBL,
    input              LVBL,
    // Sound
    output  reg        sres_b, // sound reset
    output  reg        snd_latch_cs,
    // Characters
    input              [7:0] char_dout,
    output             [7:0] cpu_dout,
    output  reg        char_cs,
    output  reg        CHON,    // 1 enables character output
    output             cpu_cen,
    input              char_wait,
    // scroll
    output  reg [7:0]  scrposv,
    output  reg [1:0]  scr1posh_cs,
    output  reg [1:0]  scr2posh_cs,
    output  reg        SC1ON,
    output  reg        SC2ON,
    // cheat!
    input              cheat_invincible,
    output  reg        OBJON,
    // cabinet I/O
    input   [6:0]      joystick1,
    input   [6:0]      joystick2,
    input   [1:0]      start_button,
    input   [1:0]      coin_input,
    // BUS sharing
    output  [12:0]     cpu_AB,
    output  [ 7:0]     ram_dout,
    input   [12:0]     obj_AB,
    output             rd_n,
    output             wr_n,
    output  reg        OKOUT,
    input              bus_req,  // Request bus
    output             bus_ack,  // bus acknowledge
    input              blcnten,  // bus line counter enable
    // ROM access
    output  reg        rom_cs,
    output  reg [17:0] rom_addr,
    input       [ 7:0] rom_data,
    input              rom_ok,
    // DIP switches
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b,
    output reg         coin_cnt
);

wire [15:0] A;
wire t80_rst_n;
reg in_cs, ram_cs, bank_cs, scrposv_cs, gfxen_cs;
reg SECWR_cs;

wire mreq_n, rfsh_n, busak_n;
assign cpu_cen = cen6;
assign bus_ack = ~busak_n;

always @(*) begin
    rom_cs       = 1'b0;
    ram_cs        = 1'b0;
    snd_latch_cs  = 1'b0;
    scrposv_cs    = 1'b0;
    bank_cs       = 1'b0;
    in_cs         = 1'b0;
    char_cs       = 1'b0;
    scr1posh_cs   = 2'b0;
    scr2posh_cs   = 2'b0;
    scrposv_cs    = 1'b0;
    gfxen_cs      = 1'b0;
    OKOUT         = 1'b0;
    SECWR_cs      = 1'b0;
    if( rfsh_n && !mreq_n ) casez(A[15:13])
        3'b0??: rom_cs = 1'b1;
        3'b10?: rom_cs = 1'b1; // bank
        3'b110: // cscd
            case(A[12:11])
                2'b00: // Part 11B
                    in_cs = 1'b1;
                2'b01:
                    casez(A[2:0])
                        3'b000: snd_latch_cs = 1'b1;
                        3'b100: bank_cs      = 1'b1;
                        3'b110: OKOUT        = 1'b1;
                        3'b111: SECWR_cs     = 1'b1;
                        default:;
                    endcase
                2'b10: // D0CS (D phi CS on schematics)
                    char_cs = 1'b1; // D0CS
                2'b11: // D8CS
                    if( !A[3] && !wr_n) case(A[2:0])
                        3'd0: scr1posh_cs = 2'b01; // LSB
                        3'd1: scr1posh_cs = 2'b10; // MSB
                        3'd2: scrposv_cs  = 1'b1;
                        3'd3: scr2posh_cs = 2'b01; // LSB
                        3'd4: scr2posh_cs = 2'b10; // MSB
                        3'd6: gfxen_cs    = 1'b1;
                        default:;
                    endcase
            endcase
        3'b111: ram_cs = 1'b1;
    endcase
end

// special registers
reg [2:0] bank;
always @(posedge clk)
    if( rst ) begin
        bank      <=  'd0;
        scrposv   <= 8'd0;
        CHON      <= 1'b0;
        flip      <= 1'b0;
        sres_b    <= 1'b1;
        coin_cnt  <= 1'b0;  // omitting inverter in M54532 for coin counter.
        {OBJON, SC2ON, SC1ON } <= 3'd0;
    end
    else if(cpu_cen) begin
        if( bank_cs  && !wr_n ) begin
            CHON     <= cpu_dout[7];
            flip     <= cpu_dout[6];
            sres_b   <= ~cpu_dout[5]; // inverted through M54532
            coin_cnt <= |cpu_dout[1:0];
            bank     <= cpu_dout[4:2];
            `ifdef SIMULATION
                if (!cpu_dout[5])
                    $display("INFO: Sound CPU reset");
                if(cpu_dout[4:2]!=bank)
                    $display("INFO: Bank changed to %d", cpu_dout[4:2]);
            `endif
        end
        if( scrposv_cs ) scrposv <= cpu_dout;
        if( gfxen_cs ) begin
            {OBJON, SC2ON, SC1ON } <= cpu_dout[6:4];
        end
    end

jt12_rst u_rst(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .rst_n  ( t80_rst_n )
);

reg [7:0] cabinet_input;
wire [7:0] security;

always @(*)
    case( A[2:0] )
        3'd0: cabinet_input = { coin_input, // COINS
                     ~2'h0, // undocumented. D5 & D4 what are those?
                     ~LVBL,
                     1'b1,
                     start_button }; // START
        3'd1: cabinet_input = { 1'b1, joystick1 };
        3'd2: cabinet_input = { 1'b1, joystick2 };
        3'd3: cabinet_input = dipsw_a;
        3'd4: cabinet_input = dipsw_b;
        3'd7: cabinet_input = security;
        default: cabinet_input = 8'hff;
    endcase


// RAM, 16kB
wire cpu_ram_we = ram_cs && !wr_n;
assign cpu_AB = A[12:0];

wire [12:0] RAM_addr = blcnten ? obj_AB : cpu_AB;
wire RAM_we   = blcnten ? 1'b0 : cpu_ram_we;

jtgng_ram #(.aw(13),.cen_rd(0)) RAM(
    .clk        ( clk       ),
    .cen        ( cpu_cen   ),
    .addr       ( RAM_addr  ),
    .data       ( cpu_dout  ),
    .we         ( RAM_we    ),
    .q          ( ram_dout  )
);

// Data bus input
reg [7:0] cpu_din;
wire iorq_n, m1_n;
wire irq_ack = !iorq_n && !m1_n;

always @(*)
    case( {ram_cs, char_cs, rom_cs, in_cs} )
        4'b10_00: cpu_din = // (cheat_invincible && (A==16'hf206 || A==16'hf286)) ? 8'h40 :
                            ram_dout;
        4'b01_00: cpu_din = char_dout;
        4'b00_10: cpu_din = rom_data;
        4'b00_01: cpu_din = cabinet_input;
        default:  cpu_din = rom_data;
    endcase

`ifdef SIMULATION
always @(negedge rd_n)
    if( in_cs && A[2:0]=='d7 ) $display("INFO: Security code read %m ");
`endif

// ROM ADDRESS: 32kB + 8 banks of 16kB
always @(*) begin
    rom_addr[13:0] = A[13:0];
    rom_addr[17:14] = !A[15] ? { 3'b0, A[14] } : ( 4'b0010 + { 1'b0, bank});
end

///////////////////////////////////////////////////////////////////
// interrupt generation. Schematics page 5/9, parts 12J and 14K
reg int_n, int_rqb, int_rqb_last;
wire int_middle = V[7:5]!=3'd3;
wire int_rqb_negedge = !int_rqb && int_rqb_last;

always @(posedge clk)
    if(rst) begin
        int_n <= 1'b1;
    end else if(cpu_cen) begin
        int_rqb_last <= int_rqb;
        int_rqb <= LVBL && int_middle;
        if( irq_ack )
            int_n <= 1'b1;
        else
            if ( int_rqb_negedge ) int_n <= 1'b0;
    end

reg [1:0] mem_wait_n;
//wire wait_n = char_wait_n & mem_wait_n[0];
reg wait_n;
reg last_rom_cs, last_chwait;
wire rom_cs_posedge = !last_rom_cs && rom_cs;
wire chwait_posedge = !last_chwait && char_wait;

reg char_free, rom_free, mem_free;

always @(posedge clk or negedge t80_rst_n)
    if( !t80_rst_n ) begin
        wait_n <= 1'b1;
        mem_wait_n[0] <= 1'b1;
        char_free <= 1'b0;
        rom_free  <= 1'b0;
        mem_free  <= 1'b0;
    end else begin
        last_rom_cs <= rom_cs;
        last_chwait <= char_wait;
        mem_wait_n[0] <= !mem_wait_n[1] ? 1'b1 : m1_n; // & mreq_n; // mreq_n
        if(cpu_cen) mem_wait_n[1] <= mem_wait_n[0];
        if( (char_wait&&char_cs) || rom_cs_posedge || !mem_wait_n[1]) begin
            // The PCB has a slow down mechanism for the main CPU
            // it loses one clock cycle at the beginning of every machine cycle
            if( char_wait&&char_cs ) char_free <= 1'b1;
            if( rom_cs_posedge ) rom_free  <= 1'b1;
            if( !mem_wait_n ) mem_free  <= 1'b1;
            wait_n <= 1'b0;
        end
        else begin
            if( rom_ok     && rom_free  ) begin
                wait_n <= 1'b1;
                rom_free <= 1'b0;
            end
            if( !char_wait && char_free ) begin
                wait_n <= 1'b1;
                char_free <= 1'b0;
            end
            if( mem_wait_n[1] && mem_free ) begin
                wait_n <= 1'b1;
                mem_free <= 1'b0;
            end
        end
    end

jt1943_security u_security(
    .clk    ( clk      ),
    .cen    ( cpu_cen  ),
    .wr_n   ( wr_n     ),
    .cs     ( SECWR_cs ),
    .din    ( cpu_dout ),
    .dout   ( security )
);

///////////////////////////////////////////////////////////////////


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
    .CEN        ( cpu_cen     ),
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
    .BUSRQ_n    ( ~bus_req    ),
    .BUSAK_n    ( busak_n     ),
    .RFSH_n     ( rfsh_n      ),
    .out0       ( 1'b0        )
);
`else
// This CPU is used for simulation
tv80s #(.Mode(0)) u_cpu (
    .reset_n( t80_rst_n  ),
    .clk    ( clk        ),
    .cen    ( cpu_cen    ),
    .wait_n ( wait_n     ),
    .int_n  ( int_n      ),
    .nmi_n  ( 1'b1       ),
    .busrq_n( ~bus_req   ),
    .rd_n   ( rd_n       ),
    .wr_n   ( wr_n       ),
    .A      ( A          ),
    .di     ( cpu_din    ),
    .dout   ( cpu_dout   ),
    .iorq_n ( iorq_n     ),
    .m1_n   ( m1_n       ),
    .mreq_n ( mreq_n     ),
    .rfsh_n ( rfsh_n     ),
    .busak_n( busak_n    ),
    // unused
    .halt_n ()
);
`endif
endmodule // jtgng_main