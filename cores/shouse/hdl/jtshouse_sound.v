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
    Date: 21-9-2023 */
/* verilator tracing_off */
module jtshouse_sound(
    input               srst_n,
    input               clk,
    input               cen_E,
    input               cen_Q,
    input               prc_snd,
    input               cen_fm,
    input               cen_fm2,
    input               lvbl,

    // main/sub bus
    input               bc30_cs,
    input               brnw,
    input        [ 9:0] baddr,
    input        [ 7:0] bdout,
    output       [ 7:0] c30_dout,

    output reg          tri_cs,
    input        [ 7:0] tri_dout,

    output              rnw,
    output              ram_we,
    input        [ 7:0] ram_dout,
    output       [ 7:0] cpu_dout,

    output reg          rom_cs,
    output       [16:0] rom_addr,
    input        [ 7:0] rom_data,
    input               rom_ok,
    output              bus_busy,

    input  signed[10:0] pcm_snd,
    output signed[15:0] left, right,
    output              sample,
    output              peak
);
`ifndef NOSOUND
localparam [7:0] FMGAIN =8'h10,
                 PCMGAIN=8'h10;

wire [15:0] A;
wire [ 7:0] fm_dout;
reg  [ 7:0] cpu_din;
reg  [ 2:0] bank;
reg         irq_n, lvbl_l, VMA, rst;
wire        bsel;
wire        AVMA, firq_n, peak_l, peak_r;
reg         ram_cs, fm_cs, cus30_cs, reg_cs;
wire signed [15:0] fm_l, fm_r;

assign rom_addr = { &A[15:14] ? 3'b0 : bank, A[13:0] };
assign bus_busy = rom_cs & ~rom_ok;
assign peak     = peak_r | peak_l;
assign ram_we   = ram_cs & ~rnw;
assign bsel     = ~prc_snd;

always @* begin
    rom_cs   = 0;
    fm_cs    = 0;
    cus30_cs = 0;
    tri_cs   = 0;
    ram_cs   = 0;
    reg_cs   = 0;
    if( VMA ) casez(A[15:12])
        4'b00??: rom_cs   = 1;
        4'b0100: fm_cs    = 1;
        4'b0101: cus30_cs = 1;
        4'b0111: tri_cs   = 1;
        4'b100?: ram_cs   = 1;
        4'b11??: begin
            if( !rnw ) reg_cs = 1;
            if(  rnw ) rom_cs = 1;
        end
        default:;
    endcase
end

always @(posedge clk) begin
    rst  <= ~srst_n;

    cpu_din <= rom_cs   ? rom_data :
               ram_cs   ? ram_dout :
               fm_cs    ? fm_dout  :
               tri_cs   ? tri_dout :
               cus30_cs ? c30_dout :
               8'd0;
end

always @(posedge clk, negedge srst_n) begin
    if( !srst_n ) begin
        bank  <= 0;
        irq_n <= 1;
        lvbl_l <= 0;
        VMA   <= 0;
    end else begin
        if( cen_E ) VMA <= AVMA;
        lvbl_l <= lvbl;
        if( !lvbl && lvbl_l ) irq_n <= 0;
        if( reg_cs ) begin
            if( A[13:12]==0 ) bank <=cpu_dout[6:4];
            // if( A[13:12]==1 ) WATCHDOG?
            if( A[13:12]==2 ) irq_n <= 1;
        end
    end
end

jtcus30 u_wav(
    .rst    ( rst       ),  // original does not have a reset pin
    .clk    ( clk       ),
    .bsel   ( bsel      ),

    .xdin   ( c30_dout  ),
    // main/sub bus
    .bcs    ( bc30_cs   ),
    .brnw   ( brnw      ),
    .baddr  ( baddr     ),
    .bdout  ( bdout     ),

    // sound CPU
    .scs    ( cus30_cs  ),
    .srnw   ( rnw       ),
    .saddr  ( A         ),
    .sdout  ( cpu_dout  )
);
/* verilator tracing_off */
jt51 u_jt51(
    .rst        ( ~srst_n   ), // reset
    .clk        ( clk       ), // main clock
    .cen        ( cen_fm    ),
    .cen_p1     ( cen_fm2   ),
    .cs_n       ( ~fm_cs    ), // chip select
    .wr_n       ( rnw       ), // write
    .a0         ( A[0]      ),
    .din        ( cpu_dout  ), // data in
    .dout       ( fm_dout   ), // data out
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      ( firq_n    ),
    // Low resolution output (same as real chip)
    .sample     ( sample    ), // marks new output sample
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);

jtframe_mixer #(.W1(11)) u_right(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    // input signals
    .ch0    ( fm_r      ),
    .ch1    ( pcm_snd   ),
    .ch2    ( 16'd0     ),
    .ch3    ( 16'd0     ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( FMGAIN    ),
    .gain1  ( PCMGAIN   ),
    .gain2  ( 8'h00     ),
    .gain3  ( 8'h00     ),
    .mixed  ( right     ),
    .peak   ( peak_r    )
);

jtframe_mixer #(.W1(11)) u_left(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    // input signals
    .ch0    ( fm_l      ),
    .ch1    ( pcm_snd   ),
    .ch2    ( 16'd0     ),
    .ch3    ( 16'd0     ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( FMGAIN    ),
    .gain1  ( PCMGAIN   ),
    .gain2  ( 8'h00     ),
    .gain3  ( 8'h00     ),
    .mixed  ( left      ),
    .peak   ( peak_l    )
);
/* verilator tracing_on */
mc6809i u_cpu(
    .nRESET     ( srst_n    ),
    .clk        ( clk       ),
    .cen_E      ( cen_E     ),
    .cen_Q      ( cen_Q     ),
    .D          ( cpu_din   ),
    .DOut       ( cpu_dout  ),
    .ADDR       ( A         ),
    .RnW        ( rnw       ),
    .AVMA       ( AVMA      ),
    // Interrupts
    .nIRQ       ( irq_n     ),
    .nFIRQ      ( firq_n    ),
    .nNMI       ( 1'b1      ),
    .nHALT      ( 1'b1      ),
    // unused
    .BS         (           ),
    .BA         (           ),
    .BUSY       (           ),
    .LIC        (           ),
    .nDMABREQ   ( 1'b1      ),
    .OP         (           ),
    .RegData    (           )
);
`else
initial tri_cs=0;
initial rom_cs=0;
assign c30_dout = 0;
assign rnw = 0;
assign ram_we = 0;
assign cpu_dout = 0;
assign rom_addr = 0;
assign bus_busy = 0;
assign left = 0, right=0;
assign sample = 0;
assign peak = 0;
`endif
endmodule