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
    Date: 20-1-2019 */

// 1942 Sound
// Schematics page 3/8


module jt1942_sound(
    input           clk,    // 24   MHz
    input           cen3   /* synthesis direct_enable = 1 */,   //  3   MHz
    input           cen1p5, //  1.5 MHz
    input           rst,
    // Interface with main CPU
    input           sres_b,
    input   [ 7:0]  main_dout,
    input   [ 7:0]  snd_latch,
    input           main_latch0_cs,
    input           main_latch1_cs, // Vulgus PCB also has two latches. MAME ignores one of them.
    input           snd_int,
    // ROM access
    (*keep*)output  reg     rom_cs,
    output  [14:0]  rom_addr,
    input   [ 7:0]  rom_data,
    (*keep*)input           rom_ok,
    // Sound output
    output signed [15:0] snd,
    output           sample,
    output           peak
);

parameter EXEDEXES=0;

wire mreq_n;
wire rd_n;
wire wr_n;

reg ay1_cs, ay0_cs, latch_cs, ram_cs;
reg psg2_wrn, psg1_wrn;

reg [7:0] AH;

wire [7:0] ram_dout, cpu_dout;

// posedge of snd_int
reg snd_int_last;
wire snd_int_edge = !snd_int_last && snd_int;
always @(posedge clk) if(cen3) begin
    snd_int_last <= snd_int;
end

// interrupt latch
reg int_n;
wire iorq_n;
always @(posedge clk)
    if( rst ) int_n <= 1'b1;
    else if(cen3) begin
        if(!iorq_n) int_n <= 1'b1;
        else if( snd_int_edge ) int_n <= 1'b0;
    end

wire [15:0] A;
assign rom_addr = A[14:0];

reg reset_n=1'b0;

always @(posedge clk) if(cen3)
    reset_n <= ~( rst | ~sres_b );

always @(*) begin
    rom_cs   = 1'b0;
    ram_cs   = 1'b0;
    latch_cs = 1'b0;
    ay0_cs   = 1'b0;
    ay1_cs   = 1'b0;
    if( !mreq_n ) casez(A[15:13])
        3'b00?: rom_cs   = 1'b1;
        3'b010: ram_cs   = 1'b1;
        3'b011: latch_cs = 1'b1;
        3'b100: begin
            ay0_cs   = EXEDEXES==0 || A[2:0]<2;
            psg1_wrn = A[2:0] == 2 && !wr_n;
            psg2_wrn = A[2:0] == 3 && !wr_n;
        end
        3'b110: if( EXEDEXES==0 ) ay1_cs = 1'b1;
        default:;
    endcase
end

reg [7:0] latch0, latch1;

always @(posedge clk)
if( rst ) begin
    latch1 <= 8'd0;
    latch0 <= 8'd0;
end else if(cen3) begin
    if( main_latch1_cs ) latch1 <= main_dout;
    if( main_latch0_cs ) latch0 <= main_dout;
    `ifdef SIMULATION
        if( main_latch1_cs )
            $display("(%X) SND LATCH 1 = $%X", $time/1000, main_dout );
        if( main_latch0_cs )
            $display("(%X) SND LATCH 0 = $%X", $time/1000, main_dout );
    `endif
end

reg [7:0] din;
wire [7:0] ay1_dout, ay0_dout;

always @(*) begin
    case( 1'b1 )
        ay1_cs:   din = ay1_dout;
        ay0_cs:   din = ay0_dout;
        latch_cs: din = EXEDEXES ? snd_latch : (A[0] ? latch1 : latch0);
        rom_cs:   din = rom_data;
        ram_cs:   din = ram_dout;
        default:  din = 8'hff;
    endcase // {latch_cs,rom_cs,ram_cs}
end

jtframe_sysz80 #(.RAM_AW(11)) u_cpu(
    .rst_n      ( reset_n     ),
    .clk        ( clk         ),
    .cen        ( cen3        ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ),
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( 1'b1        ),
    .m1_n       (             ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     (             ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .cpu_din    ( din         ),
    .cpu_dout   ( cpu_dout    ),
    .ram_dout   ( ram_dout    ),
    // ROM access
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);

wire        [ 9:0] sound0, sound1;

wire bdir0 = ay0_cs & ~wr_n;
wire bc0   = ay0_cs & ~wr_n & ~A[0];
wire bdir1 = ay1_cs & ~wr_n;
wire bc1   = ay1_cs & ~wr_n & ~A[0];

jt49_bus #(.COMP(2'b10)) u_ay0( // note that input ports are not multiplexed
    .rst_n  ( reset_n   ),
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

generate
    if( EXEDEXES==1 ) begin
        wire signed [10:0] psg1, psg2;
        jt89 u_psg1(
            .rst    ( rst       ),
            .clk    ( clk       ),
            .clk_en ( cen3      ),
            .wr_n   ( psg1_wrn  ),
            .din    ( cpu_dout  ),
            .sound  ( psg1      ),
            .ready  (           )
        );

        jt89 u_psg2(
            .rst    ( rst       ),
            .clk    ( clk       ),
            .clk_en ( cen3      ),
            .wr_n   ( psg2_wrn  ),
            .din    ( cpu_dout  ),
            .sound  ( psg2      ),
            .ready  (           )
        );

        wire [9:0] dcrm_snd;

        jtframe_dcrm #(.SW(10)) u_dcrm(
            .rst    ( rst       ),
            .clk    ( clk       ),
            .sample ( sample    ),
            .din    ( sound0    ),
            .dout   ( dcrm_snd  )
        );

        jtframe_mixer #(.W0(10),.W1(11),.W2(11)) u_mixer(
            .rst    ( rst       ),
            .clk    ( clk       ),
            .cen    ( cen3      ),
            // input signals
            .ch0    ( dcrm_snd  ),
            .ch1    ( psg1      ),
            .ch2    ( psg2      ),
            .ch3    (           ),
            // gain for each channel in 4.4 fixed point format
            .gain0  ( 8'h08     ),
            .gain1  ( 8'h04     ),
            .gain2  ( 8'h04     ),
            .gain3  ( 8'h10     ),
            .mixed  ( snd       ),
            .peak   ( peak      )   // overflow signal (time enlarged)
        );
    end else begin
        jt49_bus #(.COMP(2'b10)) u_ay1( // note that input ports are not multiplexed
            .rst_n  ( reset_n   ),
            .clk    ( clk       ),
            .clk_en ( cen1p5    ),
            .bdir   ( bdir1     ),
            .bc1    ( bc1       ),
            .din    ( cpu_dout  ),
            .sel    ( 1'b1      ),
            .dout   ( ay1_dout  ),
            .sound  ( sound1    ),
            // unused
            .IOA_in ( 8'h0      ),
            .IOA_out(           ),
            .IOB_in ( 8'h0      ),
            .IOB_out(           ),
            .sample (           ),
            .A(), .B(), .C()
        );

        jtframe_jt49_filters u_filters(
            .rst    ( rst       ),
            .clk    ( clk       ),
            .din0   ( sound0    ),
            .din1   ( sound1    ),
            .sample ( sample    ),
            .dout   ( snd       )
        );

        assign peak = 0;
    end
endgenerate

endmodule