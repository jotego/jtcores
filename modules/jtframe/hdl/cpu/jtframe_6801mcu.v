/*  This file is part of JTFRAME.
      JTFRAME program is free software: you can redistribute it and/or modify
      it under the terms of the GNU General Public License as published by
      the Free Software Foundation, either version 3 of the License, or
      (at your option) any later version.

      JTFRAME program is distributed in the hope that it will be useful,
      but WITHOUT ANY WARRANTY; without even the implied warranty of
      MERCHANTABILITY or FITNESS FOR addr PARTICULAR PURPOSE.  See the
      GNU General Public License for more details.

      You should have received a copy of the GNU General Public License
      along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

      Author: Jose Tejada Gomez. Twitter: @topapate
      Version: 1.0
      Date: 7-12-2023

*/

// SCI functionality is not implemented

module jtframe_6801mcu #(
    parameter ROMW = 12,  // valid values from 12~14 (2kB~16kB). Mapped at the end of memory
              MODE =  6,  // latched from port pints P2.2,1,0 at reset in the original
                          // only mode 6 is implemented so far
              SLOW_FRC=0, // operates the Free Running Counter at half the speed
              MODEL="MC6801" // see valid values below
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
    output             ba,      // not a real output, used for debugging
    // Ports
    // irq1 = P5-0, irq2 = P5-1
    input       [7:0]  p1_din,  p3_din,  p4_din,
    output      [7:0]  p1_dout, p3_dout, p4_dout,

    input       [4:0]  p2_din,
    output      [4:0]  p2_dout,

    // serial communication
    // it uses the same pins as R/W and AS, so it cannot be used when an
    // external is connected
    // output             sc2, sc1_out,
    // input              sc1_in,

    // ROM, regardless of size is external
    // data assumed to be right from one cen to the next
    output [ROMW-1:0]  rom_addr,    // just addr, provided as a safeguard to check AW against upper hierarchy's signals
    input      [ 7:0]  rom_data,
    output reg         rom_cs
);

localparam M6801=0, M6801U4=1, H6301=2;
/* verilator lint_off WIDTHEXPAND */
localparam M = MODEL=="MC6801"   ? M6801   :
               MODEL=="MC6801U4" ? M6801U4 : // more timers
               MODEL=="HD63701V" ? H6301   : -1;
/* verilator lint_on WIDTHEXPAND */

initial if( M<0 ) begin $display("Invalid value for MODEL in %m"); $stop; end


wire        buf_we, irq1, irq2;
reg         buf_cs, port_cs, pre_clr;
wire [ 7:0] buf_dout;
wire [ 4:0] psel;
reg  [ 7:0] din, port_mux, frbuf;
// MMR
reg  [ 7:6] ramc;
reg  [ 7:3] p3csr;
reg  [ 4:0] p2, p2ddr;
reg  [ 7:2] tcr2, tsr;
reg  [ 7:0] p1,p3,p4,
            p1ddr, p3ddr, p4ddr,
            tcr1, trcs, rmcr, td;
reg  [15:0] frc, ocr1, ocr2, ocr3, icr1, icr2;
integer     i;
reg         irq_ocf, irq_icf, irq_tof;
// timers
wire [15:0] nx_frc;
reg  [ 2:0] oc_en_aux;
wire [ 2:0] oc_en, ocf;
wire [ 1:0] tin, ic_edge;
reg  [ 1:0] tin_l;
wire        nx_frc_ov;
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
            OCR1H = 'hB,    // Output Compare Register (MSB)
            OCR1L = 'hC,    // Output Compare Register (LSB)
            ICR1H = 'hD,    // input capture register (MSB)
            ICR1L = 'hE,    // input capture register (LSB)
            P3CSR = 'hF,    // port 3 control and status register
            RMCR  = 'h10,   // rate and mode control register
            TRCS  = 'h11,   // transmit/receive control and status
            RD    = 'h12,   // receive data
            TD    = 'h13,   // transmit data
            RAMC  = 'h14,   // RAM control
            CAAH  = 'h15,   // Counter Alternate Address (MSB) - this is a mirror of FRC, with the difference that it does not clear the TOF
            CAAL  = 'h16,   // Counter Alternate Address (LSB)
            TCR1  = 'h17,   // Timer control register 1
            TCR2  = 'h18,   // Timer control register 2
            TSR   = 'h19,   // Timer status register - mirrores some of the bits in TCSR
            OCR2H = 'h1A,    // Output Compare Register 2 (MSB)
            OCR2L = 'h1B,    // Output Compare Register 2 (LSB)
            OCR3H = 'h1C,    // Output Compare Register 3 (MSB)
            OCR3L = 'h1D,    // Output Compare Register 3 (LSB)
            ICR2H = 'h1E,    // input capture register 2 (MSB)
            ICR2L = 'h1F;    // input capture register 2 (LSB)


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
assign ocf[0]  = ocr1==nx_frc && oc_en[0];
assign ocf[1]  = ocr2==nx_frc && oc_en[1];
assign ocf[2]  = ocr3==nx_frc && oc_en[2];
assign tin[0]  = p2_din[0];
assign tin[1]  = p1_din[0];
assign ic_edge[0] = tcr1[3] ? (tin[0]&~tin_l[0]) : (~tin[0]&tin_l[0]);
assign ic_edge[1] = tcr1[4] ? (tin[1]&~tin_l[1]) : (~tin[1]&tin_l[1]);
assign oc_en[0]= oc_en_aux[0] && !(wr && port_cs && (psel==OCR1H || psel==FRCH));
assign oc_en[1]= oc_en_aux[1] && !(wr && port_cs && (psel==OCR2H || psel==FRCH));
assign oc_en[2]= oc_en_aux[2] && !(wr && port_cs && (psel==OCR3H || psel==FRCH));

// Address decoder
always @(posedge clk) begin
    port_cs <=  addr[11:0] < 12'h20 && (MODE==3?addr[15:12]==4'hd : addr[15:12]==0);
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
    case(psel)
        P1DDR:  port_mux = p1ddr;
        P2DDR:  port_mux = {3'b0,p2ddr};
        P1:     port_mux = (~p1ddr&p1_din | p1ddr&p1);
        P2:     port_mux = { MODE[2:0], (~p2ddr&p2_din | p2ddr&p2) };
        P3DDR:  port_mux = p3ddr;
        P4DDR:  port_mux = p4ddr;
        P3:     port_mux = (~p3ddr&p3_din | p3ddr&p3);
        P4:     port_mux = (~p4ddr&p4_din | p4ddr&p4);
        TCSR:   port_mux = {tsr[6], tsr[3], tsr[2], tcr2[6], tcr2[3:2], tcr1[3], tcr1[0]};
        FRCH:   port_mux = frc[15:8];
        FRCL:   port_mux = frc[ 7:0];
        OCR1H:  port_mux = ocr1[15:8];
        OCR1L:  port_mux = ocr1[ 7:0];
        ICR1H:  port_mux = icr1[15:8];
        ICR1L:  port_mux = icr1[ 7:0];
        // serial interface
        P3CSR:  port_mux = {p3csr[7:6],1'b1,p3csr[4:3],3'd7};
        RMCR:   port_mux = { rmcr[7],3'b111,rmcr[3:0]};
        TRCS:   port_mux = trcs;
        RD:     port_mux = 8'd0; // rd; - not implemented
        TD:     port_mux = td;
        RAMC:   port_mux = {ramc, 6'h3f};
        default:;
    endcase
    if(M==M6801U4) case(psel)
        CAAH:   port_mux = frc[15:8];
        CAAL:   port_mux = frc[ 7:0];
        TCR1:   port_mux = tcr1;
        TCR2:   port_mux = {tcr2,2'b11};
        TSR:    port_mux = {tsr,2'b11};
        OCR2H:  port_mux = ocr2[15:8];
        OCR2L:  port_mux = ocr2[ 7:0];
        OCR3H:  port_mux = ocr3[15:8];
        OCR3L:  port_mux = ocr3[ 7:0];
        ICR2H:  port_mux = icr2[15:8];
        ICR2L:  port_mux = icr2[ 7:0];
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
        ocr1  <='hffff;
        icr1  <= 0;
        rmcr  <='hf0;
        trcs  <= 0;
        tcr1  <= 0;
        tcr2  <= 0;
        tsr   <= 0;
        p1    <= 0;
        p2    <= 0;
        p3    <= 0;
        p4    <= 0;
        tin_l <= 0;
        frbuf <= 0;
        ramc  <= 1;
        if( M==M6801U4 ) begin
            icr2 <= 0;
            ocr2 <= 'hffff;
            ocr3 <= 'hffff;
        end
    end else begin
        if( cen ) begin
            oc_en_aux <= 3'b111;
            // Free running counter
            cen_frc <= cen_frc+1'd1;
            if( cen_frc==3 ) frc <= nx_frc;
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
                TCSR: begin
                    tcr1[0]  <= dout[0];
                    tcr1[3]  <= dout[1];
                    tcr2[3:2]<= dout[3:2]; // EOCI1 / ETOI
                    tcr2[6]  <= dout[4];   // EICI1
                end
                TRCS: trcs <= dout;
                FRCH: begin
                    frc <= 16'hfff8;
                    frbuf <= dout;
                end /* verilator lint_off WIDTHEXPAND */
                FRCL: if(MODEL=="HD63701V") begin /* verilator lint_on WIDTHEXPAND */
                    frc     <= { frbuf, dout };
                    cen_frc <= 1;
                end
                OCR1H: { ocr1[15:8], oc_en_aux[0] } <= { dout, 1'b0 };
                OCR1L: ocr1[7:0] <= dout;
                // serial interface
                P3CSR: p3csr <= dout[7:3]; // bit 5 unused
                RMCR: rmcr <= dout; // bits 6-4 unused
                TD:   td   <= dout;
                RAMC: ramc[7:6] <= dout[7:6];
                default:;
            endcase
            if(M==M6801U4) case(psel)
                TCR1: tcr1 <= dout;
                TCR2: tcr2 <= dout[7:2];
                OCR2H: { ocr2[15:8], oc_en_aux[1] } <= { dout, 1'b0 };
                OCR3H: { ocr3[15:8], oc_en_aux[2] } <= { dout, 1'b0 };
                OCR2L: ocr2[7:0] <= dout;
                OCR3L: ocr3[7:0] <= dout;
                CAAH,CAAL,ICR1H,ICR1L,ICR2H,ICR2L,RD,FRCL,TSR:; // read-only port
            endcase else begin // prevents a latch warning in Quartus. These bits are not read in not M6801U4 mode
                { tcr1[7:4], tcr1[2:1] } <= 0;
                { tcr2[7],   tcr2[5:4] } <= 0;
            end
        end
        if( cen ) begin
            if( port_cs && (psel==TCSR || psel==TSR) && !wr) pre_clr <= 1;
            if( port_cs && pre_clr ) begin // clear conditions
                if( psel==ICR1H && !wr ) tsr[6] <= 0; // ICF1 (input  capture flag 1)
                if( psel==ICR2H && !wr ) tsr[7] <= 0; // ICF2 (input  capture flag 2)
                if( (psel==OCR1H || psel==OCR1L) && wr ) tsr[3] <= 0; // OCF (output compare flag)
                if( (psel==OCR2H || psel==OCR2L) && wr ) tsr[4] <= 0;
                if( (psel==OCR3H || psel==OCR3L) && wr ) tsr[5] <= 0;
                if( psel==FRCH && !wr ) tsr[2] <= 0; // TOF (timer overflow flag)
            end
            // Timer flags
            if( nx_frc_ov ) begin tsr[2] <= 1; pre_clr <= 0; end
            tin_l <= tin;
            if( ic_edge[0] ) begin // input capture register 1
                icr1    <= frc;
                tsr[6]  <= 1;
                pre_clr <= 0;
            end
            if( M==M6801U4 ) begin
                if( ic_edge[1] ) begin // input capture register 2
                    icr2    <= frc;
                    tsr[7]  <= 1;
                    pre_clr <= 0;
                end
                if( ocf[0] ) begin tsr[3] <= 1; pre_clr <= 0; if(tcr1[5]) p2[1]<=tcr1[0]; end
                if( ocf[1] ) begin tsr[4] <= 1; pre_clr <= 0; if(tcr1[6]) p1[1]<=tcr1[1]; end
                if( ocf[2] ) begin tsr[5] <= 1; pre_clr <= 0; if(tcr1[7]) p1[2]<=tcr1[2]; end
            end else begin
                if( ocf[0] ) begin tsr[3] <= 1; pre_clr <= 0; if(p2ddr[1]) p2[1]<=tcr1[0]; end
            end
        end
    end
end

// interrupts
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        irq_ocf <= 0;
        irq_icf <= 0;
        irq_tof <= 0;
    end else begin
        irq_tof <=   tsr[ 2 ] & tcr2[ 2 ] ; // TOF
        irq_ocf <= |(tsr[5:3] & tcr2[5:3]); // OCF
        irq_icf <= |(tsr[7:6] & tcr2[7:6]); // ICF
    end
end

`ifdef SIMULATION
reg [7:0] ram[0:255];
reg [7:0] bdout_aux;
integer rk;

wire [7:0] ramAE=ram[8'hae];
wire [7:0] ram92=ram[8'h92];
assign buf_dout = bdout_aux;

always @(posedge clk,posedge rst) begin
    if( rst ) begin
        for(rk=0;rk<256;rk=rk+1) ram[rk]=0;
        bdout_aux <= 0;
    end else begin
        if(buf_we) ram[addr[7:0]] <= dout;
        bdout_aux <= ram[addr[7:0]];
    end
end
`else
jtframe_ram #(.AW(8)) u_buffer( // internal RAM
    .clk    ( clk       ),
    .cen    ( cen       ),
    .data   ( dout      ),
    .addr   ( addr[7:0] ),
    .we     ( buf_we    ),
    .q      ( buf_dout  )
);
`endif

// reg [7:0] tracka, trackd;

// always @(posedge clk, posedge rst) begin
//     if( rst ) begin
//         tracka <= 0;
//         trackd <= 0;
//     end else begin
//         if( buf_we && addr[7:0]<8'hf0 ) begin
//             tracka <= addr[7:0];
//             trackd <= dout;
//         end
//     end
// end

jt680x u_mcu(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen           ),
    .wr         ( wr            ),
    .addr       ( addr          ),
    .din        ( din           ),
    .dout       ( dout          ),
    .irq        ( irq           ),
    .nmi        ( nmi           ),
    // bus sharing - only used on 6301 mode
    .ext_halt   ( 1'b0          ),
    .ba         ( ba            ),
    // Timer interrupts
    .irq_icf    ( irq_icf       ),
    .irq_ocf    ( irq_ocf       ),
    .irq_tof    ( irq_tof       ),
    .irq_sci    ( 1'b0          ),  // not implemented
    // 6301 only
    .irq_cmf    ( 1'b0          ),
    .irq2       ( 1'b0          )
);

endmodule