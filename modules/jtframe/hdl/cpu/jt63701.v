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
    Date: 24-9-2023 */

// non-comprehensive implementation of a HD63701 compatible MCU

module jt63701#(
    parameter ROMW = 12 // valid values from 12~14 (2kB~16kB). Mapped at the end of memory
)(
    input              rst,
    input              clk,
    input              cen,     // clk must be at leat x4 cen (24MHz -> 6MHz maximum)

    // all inputs are active high
    input              irq,     // not a pin on HD63701Y, but needed by shouse (?)
    input              nmi,
    input              halt,
    output             halted,

    output     [15:0]  A,
    input       [7:0]  xdin,
    output      [7:0]  dout,
    output             rnw,
    output             x_cs,    // eXternal access
    // Ports
    // irq1 = P5-0, irq2 = P5-1
    input       [7:0]  p1_din, p2_din, p3_din, p4_din, p5_din, p6_din,
    output      [7:0]  p1_dout, p2_dout, p3_dout, p4_dout, p5_dout, p6_dout,

    // ROM, regardless of size is external
    // data assumed to be right from one cen to the next
    output [ROMW-1:0]  rom_addr,    // just A, provided as a safeguard to check AW against upper hierarchy's signals
    input      [ 7:0]  rom_data,
    output reg         rom_cs
);

wire        vma, ram_we, irq1, irq2;
reg         ram_cs, port_cs;
wire [ 7:0] ram_dout;
wire [ 5:0] psel;
reg  [ 7:0] din, port_mux;
reg  [ 7:0] ports[0:'h27];
integer     i;
reg         irq_ocf, irq_icf, irq_tof;
wire        intv_rd,    // interrupt vector is being read
            any_irq;
// timers
wire [15:0] nx_frc;
wire        ocf1, ocf2, tin, nx_frc_ov, ic_edge;
reg         tin_l;

localparam  P1DDR = 'h0,
            P2DDR = 'h1,
            P1    = 'h2,
            P2    = 'h3,
            P3DDR = 'h4,
            P4DDR = 'h5,
            P3    = 'h6,
            P4    = 'h7,
            TCSR1 = 'h8,    // Timer Control/Status Register 1
            FRCH  = 'h9,    // Free Running Counter High
            FRCL  = 'hA,    // Free Running Counter Low
            OCR1H = 'hB,    // Output Compare Register 1 (MSB)
            OCR1L = 'hC,    // Output Compare Register 1 (LSB)
            ICRH  = 'hD,    // input capture register (MSB)
            ICRL  = 'hE,    // input capture register (LSB)
            TCSR2 = 'hF,
            RP5CR = 'h14,   // RAM/port 5 control register
            P5    = 'h15,
            P6DDR = 'h16,
            P6    = 'h17,
            OCR2H = 'h19,    // Output Compare Register 2 (MSB)
            OCR2L = 'h1A,    // Output Compare Register 2 (LSB)
            P5DDR = 'h20,
            P6CSR = 'h21; // P6 Control/Status - Not implemented

assign ram_we = ram_cs & ~rnw;
assign rom_addr = A[0+:ROMW];

assign p1_dout = ports[P1];
assign p2_dout = ports[P2];   // Port 2 can be used by timers 1,2 too
assign p3_dout = ports[P3];
assign p4_dout = ports[P4];
assign p5_dout = ports[P5];
assign p6_dout = ports[P6];   // Port 6 supports handshaking -not implemented-
// assign p7_dout = ports[P7];
assign psel    = A[5:0];
assign x_cs    = vma && {port_cs,ram_cs,rom_cs}==0;
// IRQ enables
assign irq1    = ports[RP5CR][0] & ports[P5][0];
assign irq2    = ports[RP5CR][1] & ports[P5][1];
assign any_irq = |{irq,irq1,irq2};
assign intv_rd = &A[15:5];
// Timers
assign { nx_frc_ov, nx_frc } = { 1'd0, ports[FRCH],ports[FRCL] }+17'd1;
assign ocf1    = {ports[OCR1H],ports[OCR1L]}==nx_frc;
assign ocf2    = {ports[OCR2H],ports[OCR2L]}==nx_frc;
assign tin     = p2_din[0];
assign ic_edge = ports[TCSR1][1] ? (tin&~tin_l) : (~tin&tin_l);

// Address decoder
always @(posedge clk) begin
    port_cs <= vma &&  A < 16'h28;
    ram_cs  <= vma &&  A >=16'h40 && A < 16'h140 && ports[RP5CR][6];
    rom_cs  <= vma && &A[15:ROMW] && rnw;
end

always @(*) begin
    din = rom_cs  ? rom_data :
          ram_cs  ? ram_dout :
          port_cs ? port_mux : xdin;
end

// ports
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ports[P1DDR] <='hf1;
        ports[P2DDR] <= 0;
        ports[P3DDR] <='hf3;
        ports[P4DDR] <= 0;
        ports[P5DDR] <= 0;
        ports[RP5CR] <='h78; // MSB should be high if we come from a sleep without losing power
        ports[P6DDR] <= 0;
        ports[P6CSR] <= 7;
        ports[FRCH]  <= 0;
        ports[FRCL]  <= 0;
        ports[TCSR2] <='h10;
        ports[OCR1H] <='hff;
        ports[OCR1L] <='hff;
        ports[OCR2H] <='hff;
        ports[OCR2L] <='hff;
        ports[ICRH]  <= 0;
        ports[ICRL]  <= 0;
        tin_l <= 0;
    end else begin
        port_mux <= ports[psel];
        // PORT 1
        if( !ports[P1DDR][0] ) ports[P1] <= p1_din;
        if( !ports[P3DDR][0] ) ports[P3] <= p3_din;
        for( i=0; i<8; i=i+1) begin
            if( !ports[P2DDR][i] ) ports[P2][i] <= p2_din[i];
            if( !ports[P4DDR][i] ) ports[P4][i] <= p4_din[i];
            if( !ports[P5DDR][i] ) ports[P5][i] <= p5_din[i];
            if( !ports[P6DDR][i] ) ports[P6][i] <= p6_din[i];
        end

        if( port_cs & ~rnw ) begin
            case(psel)
                P1: if( ports[P1DDR][0] ) ports[P1] <= dout;
                P3: if( ports[P3DDR][0] ) ports[P3] <= dout;
                P2, P4, P5, P6:
                    for( i=0; i<8; i=i+1 ) begin
                        if( psel==P2 && ports[P2DDR][i] ) ports[P2][i] <= dout[i];
                        if( psel==P4 && ports[P4DDR][i] ) ports[P4][i] <= dout[i];
                        if( psel==P5 && ports[P5DDR][i] ) ports[P5][i] <= dout[i];
                        if( psel==P6 && ports[P6DDR][i] ) ports[P6][i] <= dout[i];
                    end
                TCSR1, TCSR2: ports[psel][4:0] <= dout[4:0];
                // any other port is directly written through
                default: ports[psel] <= dout;
            endcase
        end
        if( cen ) begin
            if( psel==ICRH ) begin // the manual sets one more condition for this bit clearance, though
                ports[TCSR1][7] <= 0;   // ICF (input capture flag)
                ports[TCSR2][7] <= 0;
                ports[TCSR1][5] <= 0;   // TOF (timer overflow flag)
            end
            // Free running counter
            { ports[FRCH],ports[FRCL] } <= nx_frc;
            ports[TCSR1][6] <= ocf1;
            ports[TCSR2][6] <= ocf1; // repeated in both ports
            ports[TCSR2][5] <= ocf2;
            ports[TCSR1][5] <= nx_frc_ov;
            // input capture register
            tin_l <= tin;
            if( ic_edge ) begin
                { ports[ICRH], ports[ICRL] } <= { ports[FRCH],ports[FRCL] };
                ports[TCSR1][7] <= 1;
                ports[TCSR2][7] <= 1; // mirrored
            end
            // free counter matches fed to output ports:
            if( ports[TCSR2][0] ) ports[P2][1] <= ~ports[TCSR1][0]^ports[TCSR1][6];
            if( ports[TCSR2][1] ) ports[P2][5] <= ~ports[TCSR2][2]^ports[TCSR2][5];
        end
    end
end

// interrupts
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        irq_ocf <= 0;
        irq_icf  <= 0;
        irq_tof <= 0;
    end else begin
        if ( ports[TCSR1][6]&ports[TCSR1][3]| // Counter compare register 1
             ports[TCSR2][5]&ports[TCSR2][3]) // Counter compare register 2
            irq_ocf <= 1;
        if( ports[TCSR1][4]&ports[TCSR1][7] ) irq_icf <= 1; // input capture flag
        if( ports[TCSR1][2]&ports[TCSR1][5] ) irq_tof <= 1; // timer overflow flag
        if( intv_rd ) case(A[4:1])
            4'o13: irq_icf <= 0;  // FFF6-FFF7
            4'o12: irq_ocf <= 0;  // FFF4-FFF5
            4'o11: irq_tof <= 0;  // FFF2-FFF3
            default:;
        endcase
    end
end

jtframe_ram #(.AW(8)) u_intram(
    .clk    ( clk       ),
    .cen    ( cen       ),
    .data   ( dout      ),
    .addr   ( A[7:0]    ),
    .we     ( ram_we    ),
    .q      ( ram_dout  )
);

m6801 #(.NOSX_BITS(1)) u_6801(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .rw         ( rnw       ),
    .vma        ( vma       ),
    .address    ( A         ),
    .data_in    ( din       ),
    .data_out   ( dout      ),
    .halt       ( halt      ),
    .halted     ( halted    ),
    .irq        ( any_irq   ),
    .nmi        ( nmi       ),
    .irq_tof    ( irq_tof   ),  // interrupt vector at FFF2
    .irq_ocf    ( irq_ocf   ),  // interrupt vector at FFF4
    .irq_icf    ( irq_icf   ),  // interrupt vector at FFF6
    // not implemented
    .irq_sci    ( 1'b0      )
);

endmodule