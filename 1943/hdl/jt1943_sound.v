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
    Date: 19-2-2019 */

// 1943 Sound
// Schematics page 3/9

`timescale 1ns/1ps

module jt1943_sound(
    input           rst,
    input           clk,    // 24   MHz
    input           cen3   /* synthesis direct_enable = 1 */,   //  3   MHz
    input           cen1p5, //  1.5 MHz
    input           main_cen, // clock enable of main CPU
    // Interface with main CPU
    input           sres_b,
    input   [ 7:0]  main_dout,
    input           main_latch_cs,
    input           snd_int,
    // Sound control
    input           enable_psg,
    input           enable_fm,
    // PROM 4K
    input   [14:0]  prog_addr,
    input           prom_4k_we,
    input   [7:0]   prom_din,
    // Sound output
    output  [15:0]  snd
);

wire [14:0] rom_addr;
reg         rom_cs;
wire        mreq_n;
wire [7:0]  rom_data;

// posedge of snd_int
reg snd_int_last;
wire snd_int_edge = !snd_int_last && snd_int;
always @(posedge clk) if(cen3) begin
    snd_int_last <= snd_int;
end

reg reset_n=1'b0;

// interrupt latch
reg int_n;
wire iorq_n;
always @(posedge clk or negedge reset_n)
    if( !reset_n ) int_n <= 1'b1;
    else if(cen3) begin
        if(!iorq_n) int_n <= 1'b1;
        else if( snd_int_edge ) int_n <= 1'b0;
    end

// local reset
reg [3:0] rst_cnt;

always @(negedge clk)
    if( rst | ~sres_b ) begin
        rst_cnt <= 'd0;
        reset_n <= 1'b0;
    end else begin
        if( rst_cnt != ~4'b0 ) begin
            reset_n <= 1'b0;
            rst_cnt <= rst_cnt + 4'd1;
        end else reset_n <= 1'b1;
    end

reg fm1_cs, fm0_cs, latch_cs, ram_cs, SECWR_cs;

reg [7:0] latch;
wire [15:0] A;
assign rom_addr = A[14:0];

always @(*) begin
    rom_cs   = 1'b0;
    ram_cs   = 1'b0;
    latch_cs = 1'b0;
    fm0_cs   = 1'b0;
    fm1_cs   = 1'b0;
    SECWR_cs = 1'b0;
    if(!mreq_n) casez(A[15:13])
        3'b0??: rom_cs   = 1'b1;
        3'b110:
            case( A[12:11] )
                2'd0: ram_cs   = 1'b1;
                2'd1: latch_cs = 1'b1;
                2'd3: SECWR_cs = 1'b1;
                default:;
            endcase
        3'b111: begin
            fm0_cs = ~A[1];
            fm1_cs =  A[1];
        end
        default:;
    endcase
end


reg [1:0] fm_wait;
reg wait_n;
wire fmx_cs = fm0_cs|fm1_cs;
reg last_fmx_cs;
wire fmx_cs_posedge = !last_fmx_cs && fmx_cs;
wire fm_lock = |fm_wait;

always @(posedge clk or negedge reset_n)
    if( !reset_n ) begin
        fm_wait  <= 2'b11;
    end else if(cen3) begin
        fm_wait  <= {  fm_wait[0], fmx_cs_posedge };
    end // else if(cen3)


always @(posedge clk or negedge reset_n)
    if( !reset_n )
        wait_n <= 1'b1;
    else begin
        last_fmx_cs <= fmx_cs;
        wait_n <= !fm_lock;
    end

always @(posedge clk or negedge reset_n)
if( !reset_n ) begin
    latch <= 8'd0;
end else if(main_cen) begin
    if( main_latch_cs ) latch <= main_dout;
end

wire rd_n;
wire wr_n;

wire RAM_we = ram_cs && !wr_n;
wire [7:0] ram_dout, dout, rom_data0, rom_data1;

jtgng_ram #(.aw(11)) u_ram(
    .clk    ( clk      ),
    .cen    ( cen3     ),
    .data   ( dout     ),
    .addr   ( A[10:0]  ),
    .we     ( RAM_we   ),
    .q      ( ram_dout )
);

// full 32kB ROM is inside the FPGA to alleviate SDRAM bandwidth
// latch program signals
reg [14:0]  prog_latch_addr;
reg [7:0]   prog_latch_din;
reg         prog_latch_we;

always @(posedge clk) begin
    prog_latch_addr <= prog_addr; 
    prog_latch_din  <= prom_din;
    prog_latch_we   <= prom_4k_we;
end


jtgng_prom #(.aw(14),.dw(8),.simfile("../../../rom/1943/bm05.4k.lsb")) u_prom0(
    .clk    ( clk               ),
    .cen    ( cen3              ),
    .data   ( prog_latch_din          ),
    .rd_addr( A[13:0]           ),
    .wr_addr( prog_latch_addr[13:0]   ),
    .we     ( prog_latch_we & !prog_latch_addr[14] ),
    .q      ( rom_data0   )
);

jtgng_prom #(.aw(14),.dw(8),.simfile("../../../rom/1943/bm05.4k.msb")) u_prom1(
    .clk    ( clk               ),
    .cen    ( cen3              ),
    .data   ( prog_latch_din          ),
    .rd_addr( A[13:0]           ),
    .wr_addr( prog_latch_addr[13:0]   ),
    .we     ( prog_latch_we & prog_latch_addr[14]  ),
    .q      ( rom_data1   )
);

assign rom_data = A[14] ? rom_data1 : rom_data0;

reg [7:0] din;
wire [7:0] fm1_dout, fm0_dout, security;

always @(*)
    case( 1'b1 )
        fm1_cs:   din = fm1_dout;
        fm0_cs:   din = fm0_dout;
        latch_cs: din = latch;
        ram_cs:   din = ram_dout;
        default:  din = rom_data;
    endcase // {latch_cs,rom_cs,ram_cs}

jt1943_security u_security(
    .clk    ( clk      ),
    .cen    ( cen3     ),
    .wr_n   ( wr_n     ),
    .cs     ( SECWR_cs ),
    .din    ( dout     ),
    .dout   ( security )
);

// Select the Z80 core to use
`ifdef SIMULATION
`define Z80_ALT_CPU
`endif

// `ifdef NCVERILOG
// `undef Z80_ALT_CPU
// `endif

`ifdef VERILATOR_LINT
`define Z80_ALT_CPU
`endif

`ifndef Z80_ALT_CPU
// This CPU is used for synthesis
T80s u_cpu(
    .RESET_n    ( reset_n     ),
    .CLK        ( clk         ),
    .CEN        ( cen3        ),
    .WAIT_n     ( wait_n      ),
    .INT_n      ( int_n       ),
    .RD_n       ( rd_n        ),
    .WR_n       ( wr_n        ),
    .A          ( A           ),
    .DI         ( din         ),
    .DO         ( dout        ),
    .IORQ_n     ( iorq_n      ),
    .MREQ_n     ( mreq_n      ),
    .NMI_n      ( 1'b1        ),
    .BUSRQ_n    ( 1'b1        ),
    .out0       ( 1'b0        )
);
`else
tv80s #(.Mode(0)) u_cpu (
    .reset_n(reset_n ),
    .clk    (clk     ), // 3 MHz, clock gated
    .cen    (cen3    ),
    .wait_n (wait_n  ),
    .int_n  (int_n   ),
    .nmi_n  (1'b1    ),
    .busrq_n(1'b1    ),
    .rd_n   (rd_n    ),
    .wr_n   (wr_n    ),
    .A      (A       ),
    .di     (din     ),
    .dout   (dout    ),
    .iorq_n ( iorq_n ),
    .mreq_n ( mreq_n ),
    // unused
    .m1_n   (),
    .busak_n(),
    .halt_n (),
    .rfsh_n ()
);
`endif

`ifndef SIMULATION
wire signed [15:0] fm0_snd,  fm1_snd;
wire        [ 9:0] psg0_snd, psg1_snd;
wire        [10:0] psg01 = psg0_snd + psg1_snd;
// wire signed [15:0]
//     psg0_signed = {1'b0, psg0_snd, 4'b0 },
//     psg1_signed = {1'b0, psg1_snd, 4'b0 };

wire signed [10:0] psg2x; // DC-removed version of psg01

jt49_dcrm2 #(.sw(11)) u_dcrm (
    .clk    ( clk      ),
    .cen    ( cen1p5   ),
    .rst    ( !reset_n ),
    .din    ( psg01    ),
    .dout   ( psg2x    )
);

wire signed [7:0] psg_gain = enable_psg ? 8'h80 : 8'h0;
wire signed [7:0]  fm_gain = enable_fm  ? 8'h10 : 8'h0;

jt12_mixer #(.w0(16),.w1(16),.w2(13),.w3(8),.wout(16)) u_mixer(
    .clk    ( clk          ),
    .cen    ( cen1p5       ),
    .ch0    ( fm0_snd      ),
    .ch1    ( fm1_snd      ),
    .ch2    ( {psg2x, 2'b0}),
    .ch3    ( 8'd0         ),
    .gain0  ( fm_gain      ), // unity gain for FM
    .gain1  ( fm_gain      ),
    .gain2  ( psg_gain     ), // larger gain for PSG
    .gain3  ( 8'd0         ),
    .mixed  ( snd          )
);

jt03 u_fm0(
    .rst    ( ~reset_n   ),
    // CPU interface
    .clk    ( clk        ),
    .cen    ( cen1p5     ),
    .din    ( dout       ),
    .dout   ( fm0_dout   ),
    .addr   ( A[0]       ),
    .cs_n   ( ~fm0_cs    ),
    .wr_n   ( wr_n       ),
    .psg_snd( psg0_snd   ),
    .fm_snd ( fm0_snd    ),
    // unused outputs
    .snd_sample (),
    .irq_n  (),
    .psg_A  (),
    .psg_B  (),
    .psg_C  (),
    .snd    ()
);

jt03 u_fm1(
    .rst    ( ~reset_n  ),
    // CPU interface
    .clk    ( clk       ),
    .cen    ( cen1p5    ),
    .din    ( dout      ),
    .dout   ( fm1_dout  ),
    .addr   ( A[0]      ),
    .cs_n   ( ~fm1_cs   ),
    .wr_n   ( wr_n      ),
    .psg_snd( psg1_snd  ),
    .fm_snd ( fm1_snd   ),
    // unused outputs
    .irq_n  (),
    .psg_A  (),
    .psg_B  (),
    .psg_C  (),
    .snd    (),
    .snd_sample()
);
`else
assign fm0_dout = 'd0;
assign fm1_dout = 'd0;
assign snd      = 'd0;
`endif
endmodule // jtgng_sound