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
    Date: 12-3-2022 */

module jtroadf_main(
    input               rst,
    input               clk,        // 24 MHz
    input               clk48,      // 24 MHz
    input               cpu4_cen,   // 6 MHz
    output              cpu_cen,    // Q clock

    // ROM
    output      [15:0]  rom_addr,
    output reg          rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,

    // cabinet I/O
    input       [ 3:0]  cab_1p,
    input       [ 3:0]  coin,
    input       [ 6:0]  joystick1,
    input       [ 6:0]  joystick2,
    input       [ 6:0]  joystick3,
    input       [ 6:0]  joystick4,
    input               service,
    input               is_hyper,

    // GFX
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,
    output reg          vram_cs,
    output reg          objram_cs,
    output reg          obj_frame,

    // Sound
    output reg          snd_data_cs,
    output reg          snd_irq,

    // configuration
    output reg          flip,

    // interrupt triggers
    input               LVBL,

    input      [7:0]    vram_dout,
    input      [7:0]    obj_dout,
    // DIP switches
    input               dip_pause,
    input      [7:0]    dipsw_a,
    input      [7:0]    dipsw_b,
    input      [2:0]    dipsw_c, // three jumpers at the board

    // NVRAM
    input      [15:0]   ioctl_addr,
    input               ioctl_ram,
    input               ioctl_wr,
    input      [ 7:0]   ioctl_dout,
    output     [ 7:0]   ioctl_din
);

reg  [ 7:0] cabinet, cpu_din;
wire [ 7:0] ram_dout;
wire [15:0] A;
wire        RnW, irq_n, nmi_n;
wire        irq_trigger;
reg         irq_clrn, ram_cs;
reg         ior_cs, in5_cs, intst_cs, intst_l,
            iow_cs;
wire        VMA, nvram_we;

assign irq_trigger = ~LVBL & dip_pause;
assign cpu_rnw     = RnW;
assign rom_addr    = A;
assign nvram_we    = ioctl_ram && ioctl_wr && ioctl_addr[15:11]==0;

always @(*) begin
    // the ROM logic has some optional jumpers and the PCB we got
    // had G13 missing, apparently it was never there
    rom_cs  = VMA && RnW && A[15:13]>=2; // ROM = 4000 - FFFF
    iow_cs     = 0;
    in5_cs     = 0;
    intst_cs   = 0;
    ior_cs     = 0;
    objram_cs  = 0;
    vram_cs    = 0;
    ram_cs     = 0;
    snd_data_cs     = 0;

    if( VMA ) begin
        if( A[15:13]==1 ) // chip H16
            case( A[12:11] ) // chip H13
                0,1: vram_cs = 1; // Divided down in two signals originally: V1_cs and V2_cs
                2,3: ram_cs = 1; // 3 is the NVRAM (2kB)
            endcase
        if( A[15:13]==0 )
            case( A[12:10] ) // chip H14
                4: objram_cs = 1;
                5: case( A[9:7]) // chip H8
                    0: intst_cs    = 1; // intst / afe, two signals on board B, the same signal on board A
                    1: iow_cs      = 1;
                    2: snd_data_cs = 1;
                    4: in5_cs      = 1;
                    5: ior_cs      = 1;
                    default:;
                endcase
                default:;
            endcase
    end
end

function [2:0] rev3( input [6:0] x );
    rev3 = {x[4]&x[0], x[5]&x[2], x[6]&x[1]}; // merge buttons and directions
endfunction

always @(posedge clk) begin
    // Shockingly, if bit 6 for cabinet inputs 1/2 is high, the game won't boot,
    // however these are regular button inputs in the schematics with pullup resistors
    case( A[1:0] )
        0: cabinet <= { dipsw_c, cab_1p[1:0], service, coin[1:0] };
        1: cabinet <=
            is_hyper ? {1'b1, rev3(joystick2), cab_1p[2], rev3(joystick1) } :
            { 2'b10, joystick1[5:0]};
        2: cabinet <=
            is_hyper ? {1'b1, rev3(joystick4), cab_1p[3], rev3(joystick3) } :
            { 2'b10, joystick2[5:0]};
        3: cabinet <= dipsw_a;
    endcase
    cpu_din <= rom_cs  ? rom_data  :
               vram_cs ? vram_dout :
               ram_cs  ? ram_dout  :
               objram_cs  ? obj_dout :
               ior_cs  ? cabinet  :
               in5_cs  ? dipsw_b  : 8'hff;
end

always @(posedge clk) begin
    if( rst ) begin
        irq_clrn <= 0;
        flip     <= 0;
        snd_irq  <= 0;
        obj_frame<= 0;
        intst_l  <= 0;
    end else if(cpu_cen) begin
        intst_l <= intst_cs;
        if( intst_cs && !intst_l ) obj_frame <= ~obj_frame;
        if( iow_cs && !RnW ) begin
            case(A[2:0]) // 74LS259 @ F2
                0: flip      <= cpu_dout[0];
                1: snd_irq   <= cpu_dout[0];
                // 2: END - this must be some test output
                // 3: coin 1 counter
                // 4: coin 2 counter
                // 5: SA ?
                // 6: unconnected
                7: irq_clrn  <= cpu_dout[0];
                default:;
            endcase
        end
    end
end

// `ifdef SIMULATION
// reg clrnl;
// always @(posedge clk) begin
//     clrnl <= irq_clrn;
//     if( !irq_clrn && clrnl && !irq_n ) $display("IRQ cleared");
// end
// `endif

jtframe_ff u_irq(
    .rst      ( rst         ),
    .clk      ( clk         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( irq_n       ),
    .set      (             ),    // active high
    .clr      ( ~irq_clrn   ),    // active high
    .sigedge  ( irq_trigger )     // signal whose edge will trigger the FF
);

jtframe_sys6809_dma #(.RAM_AW(12),.KONAMI(1)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cpu4_cen  ),   // This is normally the input clock to the CPU
    .cpu_cen    ( cpu_cen   ),   // 1/4th of cen -> 3MHz

    // Interrupts
    .nIRQ       ( irq_n     ),
    .nFIRQ      ( 1'b1      ),
    .nNMI       ( 1'b1      ),
    .irq_ack    (           ),
    // Bus sharing
    .bus_busy   ( 1'b0      ),
    .breq_n     ( 1'b1      ),  // ioctl access does not halt the CPU
    .bg         (           ),
    // memory interface
    .A          ( A         ),
    .RnW        ( RnW       ),
    .VMA        ( VMA       ),
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    // Bus multiplexer is external
    .ram_dout   ( ram_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    ( cpu_din   ),
    // NVRAM
    .dma_clk    ( clk48         ),
    .dma_addr   ( {1'b1, ioctl_addr[10:0]} ),
    .dma_din    ( ioctl_dout    ),
    .dma_dout   ( ioctl_din     ),
    .dma_we     ( nvram_we      )
);

endmodule
