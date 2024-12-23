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

    input              irq, nmi, // active high
    input              halt,
    output             halted,

    output     [15:0]  A,
    input       [7:0]  xdin,
    output      [7:0]  dout,
    output             rnw,
    output             x_cs,    // eXternal access
    // Ports
    input       [7:0]  p1_din, p2_din, p3_din, p4_din, p5_din, p6_din,
    output      [7:0]  p1_dout, p2_dout, p3_dout, p4_dout, p5_dout, p6_dout,

    // ROM, regardless of size is external
    // data assumed to be right from one cen to the next
    output [ROMW-1:0]  rom_addr,    // just A, provided as a safeguard to check AW against upper hierarchy's signals
    input      [ 7:0]  rom_data,
    output reg         rom_cs
);

wire        vma, ram_we;
reg         ram_cs, port_cs;
wire [ 7:0] ram_dout;
wire [ 5:0] psel;
reg  [ 7:0] din, port_mux;
reg  [ 7:0] ports[0:'h27];
integer     i;

localparam  P1DDR = 'h0,
            P2DDR = 'h1,
            P1    = 'h2,
            P2    = 'h3,
            P3DDR = 'h4,
            P4DDR = 'h5,
            P3    = 'h6,
            P4    = 'h7,
            P5    = 'h15,
            P6DDR = 'h16,
            P6    = 'h17,
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

// Address decoder
always @(posedge clk) begin
    port_cs <= vma &&  A < 16'h28;
    ram_cs  <= vma &&  A >=16'h40 && A < 16'h140;
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
        ports[P1DDR] = 0;
        ports[P2DDR] = 0;
        ports[P3DDR] = 0;
        ports[P4DDR] = 0;
        ports[P5DDR] = 0;
        ports[P6DDR] = 0;
        ports[P6CSR] = 7;
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
                default: ports[psel] <= dout;
            endcase
        end
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

m6801 u_6801(
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
    // not implemented
    .irq_icf    ( 1'b0      ),
    .irq_ocf    ( 1'b0      ),
    .irq_tof    ( 1'b0      ),
    .irq_sci    ( 1'b0      )
);

endmodule