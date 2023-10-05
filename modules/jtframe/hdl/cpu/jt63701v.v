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

// non-comprehensive implementation of a HD63701V compatible MCU
// The HD63701Y version, with an Y, has different port mappings
// and some ports are not controlled in the same way. That is not supported here

module jt63701v #(
    parameter ROMW = 12, // valid values from 12~14 (2kB~16kB). Mapped at the end of memory
              MODE   = 6  // latched from port pints P2.2,1,0 at reset in the original
                          // only mode 6 is implemented so far
)(
    input              rst,
    input              clk,
    input              cen,     // clk must be at leat x4 cen (24MHz -> 6MHz maximum)

    // all inputs are active high
    input              irq,
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
    input       [7:0]  p1_din, p2_din, p3_din, p4_din,
    output      [7:0]  p1_dout, p2_dout, p3_dout, p4_dout,

    // ROM, regardless of size is external
    // data assumed to be right from one cen to the next
    output [ROMW-1:0]  rom_addr,    // just A, provided as a safeguard to check AW against upper hierarchy's signals
    input      [ 7:0]  rom_data,
    output reg         rom_cs
);

wire        vma, buf_we, irq1, irq2;
reg         buf_cs, port_cs, fcup;
wire [ 7:0] buf_dout;
wire [ 4:0] psel;
reg  [ 7:0] din, port_mux, fch, fcl;
reg  [ 7:0] ports[0:'h1f];
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
            P2    = 'h3,    // Used as mode register too
            P3DDR = 'h4,
            P4DDR = 'h5,
            P3    = 'h6,
            P4    = 'h7,
            TCSR  = 'h8,    // Timer Control/Status Register 1
            FRCH  = 'h9,    // Free Running Counter High
            FRCL  = 'hA,    // Free Running Counter Low
            OCRH  = 'hB,    // Output Compare Register (MSB)
            OCRL  = 'hC,    // Output Compare Register (LSB)
            ICRH  = 'hD,    // input capture register (MSB)
            ICRL  = 'hE,    // input capture register (LSB)
            P3CSR = 'hF,    // port 3 control and status register
            RMCR  = 'h10,   // rate and mode control register
            TRCS  = 'h11,   // transmit/receive control and status
            RD    = 'h12,   // receive data
            TD    = 'h13,   // transmit data
            RAMC  = 'h14;   // RAM control

assign buf_we = buf_cs & ~rnw;
assign rom_addr = A[0+:ROMW];

assign p1_dout = ports[P1];
assign p2_dout = ports[P2];   // Port 2 can be used by timers 1,2 too
assign p3_dout = ports[P3];
assign p4_dout = ports[P4];
assign psel    = A[4:0];
assign x_cs    = vma && {port_cs,buf_cs,rom_cs}==0; // the MODE should limit this
assign intv_rd = &A[15:5];
// Timers
assign { nx_frc_ov, nx_frc } = { 1'd0, ports[FRCH],ports[FRCL] }+17'd1;
assign ocf1    = {ports[OCRH],ports[OCRL]}==nx_frc;
assign tin     = p2_din[0];
assign ic_edge = ports[TCSR][1] ? (tin&~tin_l) : (~tin&tin_l);

`ifdef SIMULATION
wire p1ddr = ports[P1DDR][0];
`endif

// Address decoder
always @(posedge clk) begin
    port_cs <= vma &&  A < 16'h20;
    buf_cs  <= vma &&  A >=16'h40 && A < 16'h100;
    rom_cs  <= vma && &A[15:ROMW] && rnw;
end

always @(*) begin
    din = rom_cs  ? rom_data :
          buf_cs  ? buf_dout :
          port_cs ? port_mux : xdin;
end

// ports
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ports[P1DDR] <='hfe;
        ports[P2DDR] <= 0;
        ports[P3DDR] <='hfe;
        ports[P4DDR] <= 0;
        ports[FRCH]  <= 0;
        ports[FRCL]  <= 0;
        ports[OCRH] <='hff;
        ports[OCRL] <='hff;
        ports[ICRH]  <= 0;
        ports[ICRL]  <= 0;
        tin_l <= 0;
        fcup  <= 0;
        fch   <= 0;
        fcl   <= 0;
    end else begin
        port_mux <= ports[psel];
        // The FRCL register is read through a latch, to guarantee accuracy
        if( psel == FRCH && rnw ) fcl <= ports[FRCL];
        if( psel == FRCL && rnw ) port_mux <= fcl;
        for( i=0; i<8; i=i+1) begin
            if( !ports[P1DDR][i] ) ports[P1][i] <= p1_din[i];
            if( !ports[P3DDR][i] ) ports[P3][i] <= p3_din[i];
            if( !ports[P2DDR][i] ) ports[P2][i] <= p2_din[i];
            if( !ports[P4DDR][i] ) ports[P4][i] <= p4_din[i];
        end

        if( port_cs & ~rnw ) begin
            case(psel)
                P1: if( ports[P1DDR][0] ) ports[P1] <= dout;
                P3: if( ports[P3DDR][0] ) ports[P3] <= dout;
                P2, P4:
                    for( i=0; i<8; i=i+1 ) begin
                        if( psel==P1 && ports[P1DDR][i] ) ports[P1][i] <= dout[i];
                        if( psel==P2 && ports[P2DDR][i] ) ports[P2][i] <= dout[i];
                        if( psel==P3 && ports[P3DDR][i] ) ports[P3][i] <= dout[i];
                        if( psel==P4 && ports[P4DDR][i] ) ports[P4][i] <= dout[i];
                    end
                TCSR: ports[psel][4:0] <= dout[4:0];
                FRCH: begin
                    { ports[FRCH], ports[FRCL] } <= 16'hfff8;
                    fch <= dout;
                    fcup <= 1;
                end
                FRCL: fcl <= dout;
                // any other port is directly written through
                default: begin
                    ports[psel] <= dout;
                    if( psel>='h1b && psel<'h1f ) $display("Unsupported port write: %X <- %X", psel, dout);
                    if( psel>='h10 && psel<'h14 ) $display("Unsupported port write: %X <- %X", psel, dout);
                end
            endcase
        end
        ports[P2][7:5] <= MODE[2:0];
        if( cen ) begin
            if( psel==ICRH ) begin // the manual sets one more condition for this bit clearance, though
                ports[TCSR][7] <= 0;   // ICF (input capture flag)
                ports[TCSR][5] <= 0;   // TOF (timer overflow flag)
            end
            // Free running counter
            { ports[FRCH],ports[FRCL] } <= nx_frc;
            ports[TCSR][6] <= ocf1;
            ports[TCSR][5] <= nx_frc_ov;
            if( fcup ) begin
                { ports[FRCH], ports[FRCL] } <= { fch, fcl };
                fcup <= 0;
            end
            // input capture register
            tin_l <= tin;
            if( ic_edge ) begin
                { ports[ICRH], ports[ICRL] } <= { ports[FRCH],ports[FRCL] };
                ports[TCSR][7] <= 1;
            end
            // free counter matches fed to output ports:
            if( ports[P2DDR][1] ) ports[P2][1] <= ~ports[TCSR][0]^ports[TCSR][6];
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
        if( ports[TCSR][6]&ports[TCSR][3] ) irq_ocf <= 1; // Counter compare register 1
        if( ports[TCSR][4]&ports[TCSR][7] ) irq_icf <= 1; // input capture flag
        if( ports[TCSR][2]&ports[TCSR][5] ) irq_tof <= 1; // timer overflow flag
        if( intv_rd ) case(A[4:1])
            4'o13: irq_icf <= 0;  // FFF6-FFF7
            4'o12: irq_ocf <= 0;  // FFF4-FFF5
            4'o11: irq_tof <= 0;  // FFF2-FFF3
            default:;
        endcase
    end
end

jtframe_ram #(.AW(8)) u_buffer( // internal RAM
    .clk    ( clk       ),
    .cen    ( cen       ),
    .data   ( dout      ),
    .addr   ( A[7:0]    ),
    .we     ( buf_we    ),
    .q      ( buf_dout  )
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
    .irq        ( irq       ),
    .nmi        ( nmi       ),
    .irq_tof    ( irq_tof   ),  // interrupt vector at FFF2
    .irq_ocf    ( irq_ocf   ),  // interrupt vector at FFF4
    .irq_icf    ( irq_icf   ),  // interrupt vector at FFF6
    // not implemented
    .irq_sci    ( 1'b0      )
);

endmodule