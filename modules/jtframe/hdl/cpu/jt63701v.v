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

// non-comprehensive implementation of a HD63701V compatible MCU
// The HD63701Y version, with an Y, has different port mappings
// and some ports are not controlled in the same way. That is not supported here

// Modes
// 6: multiplexed/partial decode

module jt63701v #(
    parameter ROMW = 12,  // valid values from 12~14 (2kB~16kB). Mapped at the end of memory
              MODE =  6,  // latched from port pints P2.2,1,0 at reset in the original
                          // only mode 6 is implemented so far
              SLOW_FRC=0  // operates the Free Running Counter at half the speed
)(
    input              rst,     // use it for standby too, RAM is always preserved
    input              clk,
    input              cen,     // clk must be at leat x4 cen (24MHz -> 6MHz maximum)

    // all inputs are active high
    input              irq,
    input              nmi, // edge triggered

    output     [15:0]  addr,
    input       [7:0]  xdin,
    output      [7:0]  dout,
    output             wr,
    output             x_cs,    // eXternal access
    // Ports
    // irq1 = P5-0, irq2 = P5-1
    input       [7:0]  p1_din,  p3_din,  p4_din,
    output      [7:0]  p1_dout, p3_dout, p4_dout,

    input       [4:0]  p2_din,
    output      [4:0]  p2_dout,

    output reg         irq_ack, // not a pin on the real one, but it is derived from the addr bus (i.e. pins) directly anyway
    // serial communication
    // it uses the same pins as R/W and AS, so it cannot be used when an
    // external is connected
    // output             sc2, sc1_out,
    // input              sc1_in,
    output             halted,

    // ROM, regardless of size is external
    // data assumed to be right from one cen to the next
    output [ROMW-1:0]  rom_addr,    // just addr, provided as a safeguard to check AW against upper hierarchy's signals
    input      [ 7:0]  rom_data,
    output reg         rom_cs
);

wire        vma, buf_we, irq1, irq2;
reg         buf_cs, port_cs, pre_clr;
wire [ 7:0] buf_dout;
wire [ 4:0] psel;
reg  [ 7:0] din, port_mux, fch, fcl;
integer     i;
reg         irq_ocf, irq_icf, irq_tof;
wire        intv_rd,    // interrupt vector is being read
            any_irq;
// MMR
reg  [ 7:6] ramc;
reg  [ 7:3] p3csr;
reg  [ 4:0] p2, p2ddr;
reg  [ 7:0] p1,p3,p4,
            p1ddr, p3ddr, p4ddr,
            tcsr, trcs, rmcr, td;
reg  [15:0] frc, ocr, icr;
// timers
wire [15:0] nx_frc;
reg         oc_en_aux;
wire        ocf, tin, nx_frc_ov, ic_edge, oc_en, frc_bsy;
reg         tin_l;
reg  [ 1:0] cen_frc;

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

assign buf_we = buf_cs & wr;
assign rom_addr = addr[0+:ROMW];

assign p1_dout = MODE==1 ? addr[7:0] : p1;
assign p2_dout = p2[4:0];   // Port 2 can be used by timers
assign p3_dout = (MODE<=2||MODE==6) ? dout : p3; // it should really toggle between dout and addr[7:0]
assign p4_dout = (MODE==0||MODE==2) ? addr[15:8] :
                  MODE!=6 ? p4 :
                (p4ddr & addr[15:8]) | (~p4ddr & p4);
assign psel    = addr[4:0];
assign x_cs    = MODE!=7 && {port_cs,buf_cs,rom_cs/*,~rame[6]*/}==0; // the MODE should limit this
// Timers
assign { nx_frc_ov, nx_frc } = { 1'd0, frc }+17'd1;
assign ocf     = ocr==nx_frc && oc_en;
assign tin[0]  = p2_din[0];
assign tin[1]  = p1_din[0];
assign ic_edge[0] = tcr1[3] ? (tin[0]&~tin_l[0]) : (~tin[0]&tin_l[0]);
assign ic_edge[1] = tcr1[4] ? (tin[1]&~tin_l[1]) : (~tin[1]&tin_l[1]);
assign oc_en      = oc_en_aux && !(wr && port_cs && (psel==OCRH || psel==FRCH));

// Address decoder
always @(posedge clk) begin
    port_cs <=  addr[11:0] < 12'h20;
    buf_cs  <=  addr >=16'h40 && addr < 16'h100;
    rom_cs  <= &addr[15:ROMW] && ~wr;
    // some port addresses are redirected to x_cs depending upon MODE
    case( MODE )
        0:   if((psel>=4 && psel<=7) || psel=='hf ) port_cs <= 0;
        1:   if( psel==0 || psel==2  ||(psel>=4 && psel<=7) || psel=='hf) port_cs <= 0;
        2:   if((psel>=4 && psel<=7) || psel=='hf ) port_cs <= 0;
        5,6: if((psel==4 || psel==6  || psel=='hf)) port_cs <= 0;
    endcase
end

always @(*) begin
    port_mux = 8'hff;
    case( psel )
        P1DDR:  port_mux = p1ddr;
        P2DDR:  port_mux = {3'b0,p2ddr};
        P1:     port_mux = (~p1ddr&p1_din | p1ddr&p1);
        P2:     port_mux = { MODE[2:0], (~p2ddr&p2_din | p2ddr&p2) };
        P3DDR:  port_mux = p3ddr;
        P4DDR:  port_mux = p4ddr;
        P3:     port_mux = (~p3ddr&p3_din | p3ddr&p3);
        P4:     port_mux = (~p4ddr&p4_din | p4ddr&p4);
        TCSR:   port_mux = tcsr;
        FRCH:   port_mux = frc[15:8];
        FRCL:   port_mux = frc[ 7:0];
        OCRH:   port_mux = ocr[15:8];
        OCRL:   port_mux = ocr[ 7:0];
        ICRH:   port_mux = icr[15:8];
        ICRL:   port_mux = icr[ 7:0];
        // serial interface
        P3CSR:  port_mux = {p3csr[7:6],1'b1,p3csr[4:3],3'd7};
        RMCR:   port_mux = { rmcr[7],3'b111,rmcr[3:0]};
        TRCS:   port_mux = trcs;
        RD:     port_mux = 8'd0; // rd; - not implemented
        TD:     port_mux = td;

        RAMC:   port_mux = {ramc, 6'h3f};
    endcase
end


always @(*) begin
    din = rom_cs  ? rom_data :
          buf_cs  ? buf_dout :
          port_cs ? port_mux :
          MODE!=7 ? xdin     : 8'd0;
end

// ports
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        p1ddr <= 0;
        p2ddr <= 0;
        p3ddr <= 0;
        p4ddr <= 0;
        frc   <= 0;
        ocr  <='hffff;
        icr  <= 0;
        rmcr  <='hf0;
        trcs  <= 0;
        tcr1  <= 0;
        p1    <= 0;
        p2    <= 0;
        p3    <= 0;
        p4    <= 0;
        tin_l <= 0;
        ramc  <= 1;
    end else begin
        // The FRCL register is read through a latch, to guarantee accuracy
        if( psel == FRCH && !wr ) fcl <= frc[7:0];
        if( psel == FRCL && !wr ) port_mux <= fcl;

        if( cen ) begin
            oc_en_aux <= 1;
        end
        if( port_cs & wr ) begin
            case(psel)
                P1: p1 <= dout;
                P2: p2 <= dout[4:0];
                P3: p3 <= dout;
                P4: p4 <= dout;
                P1DDR: p1ddr <= dout;
                P2DDR: p2ddr <= dout[4:0];
                P3DDR: p3ddr <= dout;
                P4DDR: p4ddr <= dout;
                // Timers
                TCSR: tcsr <= dout[4:0];
                TRCS: trcs <= dout;
                FRCH: if(MODE==0) frc <= 16'hfff8;
                OCRH: { ocr[15:8], oc_en_aux[0] } <= { dout, 1'b0 };
                OCRL: ocr[7:0] <= dout;
                // serial interface
                P3CSR: p3csr <= dout[7:3]; // bit 5 unused
                RMCR:  rmcr  <= dout; // bits 6-4 unused
                TD:    td    <= dout;
                RAMC:  ramc[7:6] <= dout[7:6];
                ICRH,ICRL,RD,FRCL:; // read-only port
                default: $display("%m: ignored write to port %X",psel);
            endcase
        end
        if( cen ) begin
            if( port_cs && psel==TCSR && !wr) pre_clr <= 1;
            if( port_cs && pre_clr ) begin // clear conditions
                if( psel==ICRH && !wr ) begin
                    tcsr[7] <= 0;   // ICF (input  capture flag)
                    pre_clr <= 0;
                end
                if( (psel==OCRH || psel==OCRL) && wr ) begin
                    tcsr[6] <= 0;   // OCF (output compare flag)
                    pre_clr <= 0;
                end
                if( psel==FRCH && !wr ) begin
                    tcsr[5] <= 0;   // TOF (timer overflow flag)
                    pre_clr <= 0;
                end
            end
            // Free running counter
            if( ocf       ) tcsr[6] <= 1;
            if( nx_frc_ov ) tcsr[5] <= 1;
            cen_frc <= cen_frc==SLOW_FRC[1:0] ? 2'd0 : cen_frc+1'd1;
            if( SLOW_FRC==0 || cen_frc==SLOW_FRC[1:0] ) { frch, frcl } <= nx_frc;
            // input capture register
            tin_l <= tin;
            if( ic_edge ) begin
                icr <= { frch, frcl };
                tcsr[7] <= 1;
            end
            // free counter matches fed to output ports:
            if( p2ddr[1] ) p2[1] <= ~tcsr[0]^tcsr[6];
        end
    end
end

// interrupts
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        irq_ocf <= 0;
        irq_icf <= 0;
        irq_tof <= 0;
        irq_ack <= 0;
    end else begin
        irq_ocf <= tcsr[6] & tcsr[3]; // Counter compare register 1 -- FFF4-FFF5
        irq_icf <= tcsr[7] & tcsr[4]; // input capture flag         -- FFF6-FFF7
        irq_tof <= tcsr[5] & tcsr[2]; // timer overflow flag        -- FFF2-FFF3
        irq_ack <= intv_rd && addr[4:1]=='hc;
    end
end

jtframe_ram #(.AW(8)) u_intram( // internal RAM
    .clk    ( clk       ),
    .cen    ( cen       ),
    .data   ( dout      ),
    .addr   ( addr[7:0] ),
    .we     ( buf_we    ),
    .q      ( buf_dout  )
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
    .ext_halt   ( 1'b0          ),
    .ba         ( halted        ),
    // Other interrupts
    .irq_icf    ( irq_icf       ),
    .irq_ocf    ( irq_ocf       ),
    .irq_tof    ( irq_tof       ),
    .irq_sci    ( 1'b0          ),  // not implemented
    // 6301 only
    .irq_cmf    ( irq_cmf       ),
    .irq2       ( 1'b0          )
);

endmodule