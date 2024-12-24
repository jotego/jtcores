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
    Date: 11-11-2021 */

module jtsbaskt_main(
    input               rst,
    input               clk,        // 24 MHz
    input               cpu_cen,    // 1.53 MHz
    input               decode,
    // ROM
    output      [15:0]  rom_addr,
    output reg          rom_cs,
    input       [ 7:0]  rom_data,

    input       [ 7:0]  ram_dout,
    output              ram_we,

    // cabinet I/O
    input       [ 1:0]  cab_1p,
    input       [ 1:0]  coin,
    input       [ 6:0]  joystick1,
    input       [ 6:0]  joystick2,
    input               service,

    // GFX
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,
    output reg          vscr_cs,
    output reg          vram_cs,
    output reg          objram_cs,
    output reg          obj_frame,

    // Sound
    output reg          snd_data_cs,
    output reg          snd_on_cs,

    // configuration
    output reg  [ 3:0]  pal_sel,
    output reg          flip,

    // interrupt triggers
    input               LVBL,
    input               V16,

    input      [7:0]    vram_dout,
    input      [7:0]    vscr_dout,  // output from Konami 085 custom chip
    input      [7:0]    obj_dout,
    // DIP switches
    input               dip_pause,
    input      [7:0]    dipsw_a,
    input      [7:0]    dipsw_b
);

reg  [ 7:0] cabinet, cpu_din;
wire [ 7:0] din_dec;
wire [15:0] A;
wire        RnW, irq_n, nmi_n;
wire        irq_trigger;
reg         irq_clrn, ram_cs, vgap_cs;
reg         ior_cs, in5_cs, in6_cs, int_cs,
            color_cs, iow_cs, intshow_cs;
// reg         afe_cs; // watchdog
wire        avma, op;
reg         VMA, cen_Q;

assign irq_trigger = ~LVBL & dip_pause;
assign cpu_rnw     = RnW;
assign rom_addr    = A;
assign ram_we      = ram_cs & ~RnW;

always @(*) begin
    rom_cs  = VMA && A[15:13]>2 && RnW && VMA; // ROM = 4000 - FFFF
    iow_cs     = 0;
    int_cs     = 0;
    in5_cs     = 0;
    in6_cs     = 0;
    ior_cs     = 0;
    color_cs   = 0;
    vscr_cs    = 0;
    intshow_cs = 0;
    objram_cs  = 0;
    ram_cs     = 0;
    vram_cs    = 0;
    snd_data_cs= 0;
    snd_on_cs  = 0;
    if( VMA && A[15:13]==1 ) begin // 2???
        case( A[12:11] )
            0,1: ram_cs = 1;    // 2000-2FFF
            2: vram_cs  = 1;    // 3000-37FF
            3: if( A[10] ) begin
                case( A[9:7] )  // 3C??
                    0: case(A[6:4])
                        // 0: watchdog    // 3c00
                        1: int_cs   = 1;  // 3c10
                        2: color_cs = 1;  // 3c20
                        3: intshow_cs = 1;  // 3c30
                        default:;
                    endcase
                    1: iow_cs      = 1; // 3c80
                    2: snd_data_cs = 1; // 3d00
                    3: snd_on_cs   = 1; // 3d80
                    4: ior_cs      = 1; // 3e00
                    5: in5_cs      = 1; // 3e80
                    6: in6_cs      = 1; // 3f00
                    7: vscr_cs     = 1; // 3f80
                endcase
            end else begin  // 38??
                objram_cs = 1;
            end
        endcase
    end
end

always @(posedge clk) begin
    case( A[1:0] )
        0: cabinet <= { ~3'd0, cab_1p, service, coin };
        1: cabinet <= { 1'b1, joystick1[6:0] };
        2: cabinet <= { 1'b1, joystick2[6:0] };
        3: cabinet <= 8'hff;
    endcase
    cpu_din <= rom_cs  ? rom_data  :
               ram_cs  ? ram_dout  :
               vram_cs ? vram_dout :
               intshow_cs ? vscr_dout :
               objram_cs  ? obj_dout :
               ior_cs  ? cabinet  :
               in6_cs  ? dipsw_a  :
               in5_cs  ? dipsw_b  : 8'hff;
end

always @(posedge clk) begin
    if( rst ) begin
        obj_frame   <= 0;
        irq_clrn <= 0;
        flip     <= 0;
        pal_sel  <= 0;
    end else if(cpu_cen) begin
        if( iow_cs && !RnW ) begin
            case(A[2:0]) // 74LS259
                5: obj_frame <= cpu_dout[0];
                1: irq_clrn  <= cpu_dout[0];
                0: flip      <= cpu_dout[0];
                default:;
            endcase
        end
        if( color_cs ) pal_sel <= cpu_dout[3:0];
    end
end

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

always @(posedge clk) begin
    cen_Q <= cpu_cen;
    if( cpu_cen ) VMA <= avma;
end

assign din_dec = !(decode && op) ? cpu_din :
    cpu_din ^ {A[1], 1'b0, ~A[1], 1'b0, A[3], 1'b0, ~A[3], 1'b0};

mc6809i u_cpu(
    .nRESET     ( ~rst      ),
    .clk        ( clk       ),
    .cen_E      ( cpu_cen   ),
    .cen_Q      ( cen_Q     ),

    // Interrupts
    .nIRQ       ( irq_n     ),
    .nFIRQ      ( 1'b1      ),
    .nNMI       ( 1'b1      ),
    // Bus sharing
    .BUSY       (           ),
    .LIC        (           ),
    .BS         (           ),
    .BA         (           ),
    .nDMABREQ   ( 1'b1      ),
    .nHALT      ( 1'b1      ),
    .OP         ( op        ),
    // memory interface
    .ADDR       ( A         ),
    .RnW        ( RnW       ),
    .AVMA       ( avma      ),
    // Bus multiplexer is external
    .D          ( din_dec   ),
    .DOut       ( cpu_dout  ),
    .RegData    (           )
);

endmodule
