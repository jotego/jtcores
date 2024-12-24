/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR addr PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 24-9-2023 */

// non-comprehensive implementation of a HD63701Y compatible MCU
// the external bus pins are mixed with the port pins as the original
// refer to port assignments or comments to know the bus addressing bits
// trap interrupt - not implemented
module jt63701y #(
    parameter ROMW = 12,    // valid values from 12~14 (2kB~16kB). Mapped at the end of memory
              MODE = 2'd2   // expanded mode (internal ROM valid). Valid values: 1,2,3
)(
    input              rst,
    input              clk,
    input              cen,     // clk must be at leat x4 cen (24MHz -> 6MHz maximum)

    // all inputs are active high
    input              nmi,
    // input           stby,    // active high - standby function not implemented
    // Ports
    // irq1 = P5-0, irq2 = P5-1, halt = P5-3
    input       [7:0]  p1_din, p2_din,
                       p3_din,  // used as data input
                       p4_din, p5_din, p6_din,
    output      [7:0]  p1_dout, // address low
                       p2_dout,
                       p3_dout, // use as dout on MODE 2
                       p4_dout, // address high
                       p5_dout,
                       p6_dout,
    output      [4:0]  p7_dout, // use as rnw, ba (see assignment below)

    // ROM, regardless of size is external
    // data assumed to be right from one cen to the next
    output [ROMW-1:0]  rom_addr,    // just addr, provided as a safeguard to check AW against upper hierarchy's signals
    input      [ 7:0]  rom_data,
    output reg         rom_cs
);

`ifdef SIMULATION
initial begin
    if( MODE<1 || MODE>3 ) begin
        $display("%m: MODE must be 1,2 or 3");
        $stop;
    end
end
`endif

wire [15:0] addr;
wire        ram_we, irq1, irq2, wr, ba,
            halt_en, halt_g,
            x_cs;    // eXternal access
reg         ram_cs, port_cs, fcup;
wire [ 7:0] ram_dout, nx_t2, dout;
wire [ 5:0] psel;
reg  [ 7:0] din, fch, fcl, pmux;
integer     i;
reg         irq_ocf, irq_icf, irq_tof, irq_cmf;
// timers
wire [15:0] nx_frc;
wire        ocf1, ocf2, ocf3, tin, nx_frc_ov, ic_edge;
reg         t2, t2l, tin_l;

reg  [15:0] frc, ocr1, ocr2, icr;
reg  [ 7:0] p2ddr, p1, p2, p4ddr, p3, p4, tcsr1, trcsr1, p5, p6ddr, p6,
            tcsr3, tconr, t2cnt, trcsr2, p5ddr;
reg  [ 7:3] p6csr;
reg  [ 6:0] rp5cr;
reg  [ 5:0] rmcr, tcsr2;
reg  [ 4:0] p7;
reg         p1ddr, p3ddr;

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
            RMCR  = 'h10,   // Rate/Mode control register
            TRCSR1= 'h11,   // Tx/Rx Control Status Register 1
            RDR   = 'h12,   // Receive data
            TDR   = 'h13,   // Transmit data
            RP5CR = 'h14,   // RAM/port 5 control register
            P5    = 'h15,
            P6DDR = 'h16,
            P6    = 'h17,
            P7    = 'h18,
            OCR2H = 'h19,    // Output Compare Register 2 (MSB)
            OCR2L = 'h1A,    // Output Compare Register 2 (LSB)
            TCSR3 = 'h1B,    // Timer Control/Status Register 3
            TCONR = 'h1C,    // Timer Constand Register
            T2CNT = 'h1D,    // Timer 2 Up Counter
            TRCSR2= 'h1E,    // Tx/Rx Control/Status Register
            P5DDR = 'h20,
            P6CSR = 'h21; // P6 Control/Status - Not implemented

assign ram_we = ram_cs & wr;
assign rom_addr = addr[0+:ROMW];

assign p1_dout = MODE!=2'd3 ? addr[7:0] : p1;
assign p3_dout = MODE!=2'd3 ? dout : p3;
assign p4_dout = MODE!=2'd3 ? addr[15:8] : p4; // MODE 2 may use some pins as inputs too
assign p7_dout = MODE!=2'd3 ? {ba, 1'b0 /*LIR*/, ~wr |~x_cs, ~wr|~x_cs, wr|~x_cs} : p7;
assign p2_dout = p2;   // Port 2 can be used by timers 1,2 too
assign p5_dout = p5;
assign p6_dout = p6;   // Port 6 supports handshaking -not implemented-
assign halt_en = rp5cr[3];
assign halt_g  = halt_en && (MODE!=3 && !p5_din[3]);
// assign mr   = MODE!=3 && p5_din[2] && rp5cr[4]; // Memory Ready input, adds wait cycles for the bus
// rp5cr[AMRE=4] set -> makes E clock stay high one cycle longer when accessing external addresses -> should implement this one! it's the behavior at reset!
// rp5ce[ MRE=2] set -> MR high keeps E high
assign psel    = addr[5:0];
assign x_cs    = !ba && {port_cs,ram_cs,rom_cs}==0 && MODE!=2'd3;
// IRQ enables
assign irq1    = rp5cr[0] & p5[0];
assign irq2    = rp5cr[1] & p5[1];
// Timers
assign { nx_frc_ov, nx_frc } = { 1'd0, frc }+17'd1;
assign nx_t2   = t2cnt+8'd1;
assign ocf1    = ocr1==nx_frc;
assign ocf2    = ocr2==nx_frc;
assign ocf3    = tconr==nx_t2;
assign tin     = p2_din[0];
assign ic_edge = tcsr1[1] ? (tin&~tin_l) : (~tin&tin_l);

// Address decoder
always @(posedge clk) begin
    port_cs <= addr < 16'h28;
    ram_cs  <= addr >=16'h40 && addr < 16'h140 && rp5cr[6];
    case( MODE[1:0] )
        1: case( addr[4:0 ])
            'h0, 'h2, 'h4, 'h5, 'h6, 'h7, 'h18: port_cs <= 0;
            default:;
        endcase
        2: case( addr[4:0 ])
            'h0, 'h2, 'h4, 'h6, 'h18: port_cs <= 0;
            default:;
        endcase
    endcase
    rom_cs  <= &addr[15:ROMW] && ~wr && MODE!=2'd0;
    if( ba ) begin
        port_cs <= 0;
        ram_cs  <= 0;
        rom_cs  <= 0;
    end
end

always @* begin
    din = rom_cs  ? rom_data :
          ram_cs  ? ram_dout :
          port_cs ? pmux     : p3_din;
end

always @* begin // Timer 2 input
    case( tcsr3[1:0] )
        0: t2 = 1;
        1: t2 = frc[2];
        2: t2 = frc[6];
        3: t2 = p2_din[7];
    endcase
end

always @(posedge clk) begin
    pmux<=8'hff;
    case( psel )
        P1:     pmux <= p1ddr ? p1 : p1_din;
        P2:     pmux <= (p2ddr&p2)|(~p2ddr&p2_din);
        P3:     pmux <= p3ddr ? p3 : p3_din;
        P4:     pmux <= (p4ddr&p4_dout)|(~p4ddr&p4_din);
        TCSR1:  pmux <= tcsr1;
        FRCH:   pmux <= frc [15:8];
        FRCL:   pmux <= fcl;
        OCR1H:  pmux <= ocr1[15:8];
        OCR1L:  pmux <= ocr1[ 7:0];
        ICRH:   pmux <= icr [15:8];
        ICRL:   pmux <= icr [ 7:0];
        TCSR2:  pmux <= { tcsr1[7:6], tcsr2[5],1'b1,tcsr2[3:0]};
        RMCR:   pmux <= {2'b11,rmcr};
        TRCSR1: pmux <= trcsr1;
        RDR:    pmux <= 0; // rdr;
        RP5CR:  pmux <= {1'b1,rp5cr};
        P5:     pmux <= (p5ddr&p5)|(~p5ddr&p5_din);
        P6:     pmux <= (p6ddr&p6)|(~p6ddr&p6_din);
        P7:     pmux <= {3'b111,p7};
        OCR2H:  pmux <= ocr2[15:8];
        OCR2L:  pmux <= ocr2[ 7:0];
        TCSR3:  pmux <= tcsr3;
        T2CNT:  pmux <= t2cnt;
        TRCSR2: pmux <= trcsr2;
        P6CSR:  pmux <= {p6csr,3'b111};
    endcase
end

// ports
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        p1ddr <= 0;
        p2ddr <= 0;
        p3ddr <= 0;
        p4ddr <= 0;
        p5ddr <= 0;
        p6ddr <= 0;
        rp5cr <='h78; // MSB should be high if we come from a sleep without losing power
        p6csr <= 0;
        frc   <= 0;
        tcsr2 <= 0;
        ocr1  <='hffff;
        ocr2  <='hffff;
        icr   <= 0;
        tin_l <= 0;
        fcup  <= 0;
        fch   <= 0;
        fcl   <= 0;
        t2l   <= 0;
        {p1,p2,p3,p4,p5,p6,p7}<=53'd0;
    end else begin
        // The FRCL register is read through a latch, to guarantee accuracy
        if( psel == FRCH && ~wr ) fcl <= frc[7:0];

        if( port_cs & wr ) begin
            case(psel)
                P1: p1 <= dout;
                P2: p2 <= dout;
                P3: p3 <= dout;
                P4: p4 <= dout;
                P5: p5 <= dout;
                P6: p6 <= dout;
                P7: p7 <= dout[4:0];
                P1DDR: p1ddr <= dout[0];
                P2DDR: p2ddr <= dout;
                P3DDR: p3ddr <= dout[0];
                P4DDR: p4ddr <= dout;
                P5DDR: p5ddr <= dout;
                P6DDR: p6ddr <= dout;
                TCSR1: tcsr1[4:0] <= dout[4:0];
                TCSR2: tcsr2[4:0] <= dout[4:0];
                TCSR3: begin
                    if( !dout[7] ) tcsr3[7] <= 0;
                    tcsr3[6:0] <= dout[6:0];
                end
                TCONR: tconr <= dout;
                FRCH: begin
                    frc <= 16'hfff8;
                    fch  <= dout;
                end
                FRCL: begin
                    fcl <= dout;
                    fcup <= 1;
                end
                OCR1H: ocr1[15:8] <= dout;
                OCR1L: ocr1[ 7:0] <= dout;
                OCR2H: ocr2[15:8] <= dout;
                OCR2L: ocr2[ 7:0] <= dout;
                ICRH:  icr [15:8] <= dout;
                ICRL:  icr [ 7:0] <= dout;
                RMCR:  rmcr <= dout[5:0];
                // TDR:   td   <= dout;
                RP5CR: rp5cr <= dout[6:0];
                TRCSR1:trcsr1<= dout;
                TRCSR2:trcsr2<= dout;
                P6CSR: p6csr <= dout[7:3]; // interrupt on p6csr[7] not implemented
            endcase
        end
        if( cen ) begin
            if( psel==ICRH ) begin // the manual sets one more condition for this bit clearance, though
                tcsr1[7] <= 0;   // ICF  (input capture flag)
                tcsr1[6] <= 0;   // OCF1 (output compare flag - 1)
                tcsr2[5] <= 0;   // OCF2 (output compare flag - 2)
            end
            // Free running counter
            frc <= nx_frc;
            if( ocf1      ) tcsr1[6] <= 1;
            if( ocf2      ) tcsr2[5] <= 1;
            if( ocf3      ) tcsr3[7] <= 1;
            if( nx_frc_ov ) tcsr1[5] <= 1;
            if( fcup ) begin
                frc <= { fch, fcl };
                fcup <= 0;
            end
            // input capture register
            tin_l <= tin;
            if( ic_edge ) begin
                icr <= frc;
                tcsr1[7] <= 1;
            end
            // free counter matches fed to output ports:
            if( tcsr2[0] ) p2[1] <= ~tcsr1[0]^tcsr1[6];
            if( tcsr2[1] ) p2[5] <= ~tcsr2[2]^tcsr2[5];
            if( ocf3 ) case( tcsr3[3:2] )
                0:;
                1: p2[6] <= ~p2[6];
                2: p2[6] <= 0;
                3: p2[6] <= 1;
            endcase
            // Timer 2
            t2l <= t2;
            if( tcsr3[4] && t2 && !t2l ) t2cnt <= nx_t2;
            if( ocf3 ) t2cnt <= 0;
        end
    end
end

// interrupts
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        irq_ocf <= 0;
        irq_icf <= 0;
        irq_tof <= 0;
        irq_cmf <= 0;
    end else begin
        irq_ocf <=(tcsr1[6]&tcsr1[3]|  // Counter compare register 1
                   tcsr2[5]&tcsr2[3]); // Counter compare register 2
        irq_icf <= tcsr1[4]&tcsr1[7];  // input capture flag
        irq_tof <= tcsr1[2]&tcsr1[5];  // timer overflow flag
        irq_cmf <= tcsr3[7]&tcsr3[6];  // timer 2 counter match
    end
end

jtframe_ram #(.AW(8)) u_intram(
    .clk    ( clk       ),
    .cen    ( cen       ),
    .data   ( dout      ),
    .addr   ( addr[7:0] ),
    .we     ( ram_we    ),
    .q      ( ram_dout  )
);

jt680x u_mcu( // use 6301.yaml
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen           ),
    .wr         ( wr            ),
    .addr       ( addr          ),
    .din        ( din           ),
    .dout       ( dout          ),
    .irq        ( irq1          ),
    .nmi        ( nmi           ),
    // Bus sharing
    .ba         ( ba            ),
    .ext_halt   ( halt_g        ),
    // Other interrupts
    .irq_icf    ( irq_icf       ),
    .irq_ocf    ( irq_ocf       ),
    .irq_tof    ( irq_tof       ),
    .irq_sci    ( 1'b0          ),  // not implemented
    // 6301 only
    .irq_cmf    ( irq_cmf       ),
    .irq2       ( irq2          )
);

endmodule