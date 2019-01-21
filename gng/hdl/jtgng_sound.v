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

module jtgng_sound(
    input   clk,    // 24   MHz
    input   cen3,   //  3   MHz
    input   cen1p5, //  1.5 MHz
    input   rst,
    input   soft_rst,
    // Interface with main CPU
    input           sres_b, // Z80 reset
    input   [7:0]   snd_latch,
    input           V32,    
    // ROM access
    output  [14:0]  rom_addr,
    output          rom_cs,
    input   [ 7:0]  rom_dout,
    // Sound output
    input   enable_psg,
    input   enable_fm,
    output  signed [15:0] ym_snd,
    output  sample
);

wire [15:0] A;
assign rom_addr = A[14:0];

reg reset_n=1'b0;

always @(posedge clk) if(cen3)
    reset_n <= ~( rst | soft_rst | ~sres_b );

wire fm1_cs,fm0_cs, latch_cs, ram_cs;
reg [4:0] map_cs;

assign { rom_cs, fm1_cs, fm0_cs, latch_cs, ram_cs } = map_cs;

reg [7:0] AH;

always @(*)
    casez(A[15:11])
        5'b0???_?: map_cs = 5'h10; // 0000-7FFF, ROM
        5'b1100_0: map_cs = 5'h1;  // C000-C7FF, RAM
        5'b1100_1: map_cs = 5'h2;  // C800-C8FF, Sound latch
        5'b1110_0: map_cs = A[1] ? 5'h8 : 5'h4; // E000-E0FF, Yamaha
        default: map_cs = 5'h0;
    endcase


wire rd_n;
wire wr_n;

wire RAM_we = ram_cs && !wr_n;
wire [7:0] ram_dout, dout;

jtgng_ram #(.aw(11),.simfile("snd_ram.hex")) u_ram(
    .clk    ( clk      ),
    .cen    ( 1'b1     ),
    .data   ( dout     ),
    .addr   ( A[10:0]  ),
    .we     ( RAM_we   ),
    .q      ( ram_dout )
);

reg [7:0] din;

always @(*)
    case( {latch_cs, rom_cs,ram_cs } )
        3'b1_00:  din = snd_latch;
        3'b0_10:  din = rom_dout;
        3'b0_01:  din = ram_dout;
        default:  din = 8'd0;
    endcase // {latch_cs,rom_cs,ram_cs}

    reg int_n;

reg lastV32;
reg [4:0] int_n2;

always @(posedge clk) if(cen3) begin
    lastV32 <= V32;
    if ( !V32 && lastV32 ) begin
        { int_n, int_n2 } <= 6'b0;
    end
    else begin
        if( ~&int_n2 ) 
            int_n2 <= int_n2+5'd1;
        else
            int_n <= 1'b1;
    end
end

`ifdef SIMULATION
tv80s #(.Mode(0)) u_cpu (
    .reset_n(reset_n ),
    .clk    (clk     ), // 3 MHz, clock gated
    .cen    (cen3    ),
    .wait_n (1'b1    ),
    .int_n  (int_n   ),
    .nmi_n  (1'b1    ),
    .busrq_n(1'b1    ),
    .rd_n   (rd_n    ),
    .wr_n   (wr_n    ),
    .A      (A       ),
    .di     (din     ),
    .dout   (dout    ),
    // unused
    .iorq_n (),
    .mreq_n (),
    .m1_n   (),
    .busak_n(),
    .halt_n (),
    .rfsh_n ()
);
`else
T80pa u_cpu(
    .RESET_n    ( reset_n ),
    .CLK        ( clk     ),
    .CEN_p      ( cen3    ),
    .CEN_n      ( 1'b1    ),
    .WAIT_n     ( 1'b1    ),
    .INT_n      ( int_n   ),
    .NMI_n      ( 1'b1    ),
    .BUSRQ_n    ( 1'b1    ),
    .RD_n       ( rd_n    ),
    .WR_n       ( wr_n    ),
    .A          ( A       ),
    .DI         ( din     ),
    .DO         ( dout    ),
    // unused
    .REG        (),
    .RFSH_n     (),
    .IORQ       (),
    .M1_n       (),
    .BUSAK_n    (),
    .HALT_n     (),
    .MREQ_n     (),
    .MC         (),
    .TS         (),
    .IntCycle_n (),
    .IntE       (),
    .Stop       (),
    .REG        ()
);
`endif


wire signed [15:0] fm0_snd,  fm1_snd;
wire        [ 9:0] psg0_snd, psg1_snd;
wire        [10:0] psg01 = psg0_snd + psg1_snd;
// wire signed [15:0] 
//     psg0_signed = {1'b0, psg0_snd, 4'b0 },
//     psg1_signed = {1'b0, psg1_snd, 4'b0 };

wire signed [10:0] psg2x; // DC-removed version of psg01

jt49_dcrm2 #(.sw(11)) u_dcrm (
    .clk    (  clk    ),
    .cen    (  cen1p5 ),
    .rst    (  rst    ),
    .din    (  psg01  ),
    .dout   (  psg2x  )
);

wire signed [7:0] psg_gain = enable_psg ? 8'hd0 : 8'h0;
wire signed [7:0]  fm_gain = enable_fm  ? 8'h06 : 8'h0;

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
    .mixed  ( ym_snd       )
);

jt03 u_fm0(
    .rst    ( ~reset_n  ),
    // CPU interface
    .clk    ( clk        ),
    .cen    ( cen1p5     ),
    .din    ( dout       ),
    .addr   ( A[0]       ),
    .cs_n   ( ~fm0_cs    ),
    .wr_n   ( wr_n       ),
    .psg_snd( psg0_snd   ),
    .fm_snd ( fm0_snd    ),
    .snd_sample ( sample ),
    // unused outputs
    .dout   (),
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
    .addr   ( A[0]      ),
    .cs_n   ( ~fm1_cs   ),
    .wr_n   ( wr_n      ),
    .psg_snd( psg1_snd  ),
    .fm_snd ( fm1_snd   ),
    // unused outputs
    .dout   (),
    .irq_n  (),
    .psg_A  (),
    .psg_B  (),
    .psg_C  (),
    .snd    (),
    .snd_sample()
);

endmodule // jtgng_sound