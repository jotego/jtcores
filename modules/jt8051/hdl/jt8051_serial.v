/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

// 8051 serial port.  The port is deliberately separate from jt8051_periph so
// the SFR/timer/interrupt mux remains small and opcode agnostic.  Modes 1--3
// use the normal 16x serial clock; mode 0 is the fixed-rate 8-bit shifter.
module jt8051_serial(
    input             rst,
    input             clk,
    input             cen,
    input             tick12,
    input             t1_ovf,
    input      [ 7:0] pcon,
    input      [ 7:0] scon,
    input             sbuf_we,
    input      [ 7:0] sbuf_din,
    input             rxd,
    output reg        rxd_o,
    output reg        txd,
    output reg        ti_set,
    output reg        rx_valid,
    output reg        ri_set,
    output reg [ 7:0] rx_data,
    output reg        rx_rb8
);

reg        smod_div;
reg [ 1:0] mode2_div;
reg [ 3:0] tx_sub, tx_bit, rx_sub, rx_bit;
reg [ 7:0] tx_data, rx_shift;
reg        tx_busy, rx_busy, rx8;
wire [1:0] mode = scon[7:6];
// Mode 2 has a fixed fosc/64 baud rate (fosc/32 with SMOD).  Its 16x
// sampling clock is consequently fosc/4 (or fosc/2), independent of timers.
wire       mode2_tick = mode==2 && mode2_div==(pcon[7] ? 2'd1 : 2'd3);
// Timer-1 overflow is a 2x baud source with SMOD clear and a 1x source
// with SMOD set.  Each accepted event is one sixteenth of a serial bit.
wire       mode13_tick = (mode==1 || mode==3) && t1_ovf && (pcon[7] || !smod_div);
wire       baud16_tick = mode2_tick || mode13_tick;
wire       mode0_clock = tx_busy || rx_busy || (scon[4] && !scon[0]);

always @(posedge clk) begin
    if (rst) begin
        smod_div<=0; mode2_div<=0; tx_sub<=0; tx_bit<=0; rx_sub<=0; rx_bit<=0;
        tx_data<=0; rx_shift<=0; tx_busy<=0; rx_busy<=0; rx8<=0; rxd_o<=1; txd<=1;
        ti_set<=0; rx_valid<=0; ri_set<=0; rx_data<=0; rx_rb8<=0;
    end else if (cen) begin
        ti_set   <= 0;
        rx_valid <= 0;
        ri_set   <= 0;
        if (mode==2) mode2_div <= mode2_tick ? 0 : mode2_div+1'd1;
        if ((mode==1 || mode==3) && t1_ovf)
            smod_div <= pcon[7] ? 1'b0 : !smod_div;

        // A SBUF write starts/restarts only the transmitter.  The CPU reads
        // the independent receive SBUF held in jt8051_periph.
        if (sbuf_we) begin
            tx_data <= sbuf_din;
            tx_busy <= 1;
            tx_bit  <= 0;
            tx_sub  <= 0;
            if (mode==0) rxd_o <= sbuf_din[0];
        end

        if (mode==0) begin
            // Mode 0 is the 8051 synchronous shift-register mode: P3.0
            // (RxD) carries data in both directions and P3.1 (TxD) emits
            // one shift-clock pulse per machine cycle.  There are no UART
            // start or stop bits in this mode.
            txd <= 1;
            if (tick12 && mode0_clock) txd <= 0;
            if (tick12 && tx_busy) begin
                if (tx_bit==7) begin
                    tx_busy <= 0;
                    rxd_o   <= 1;
                    ti_set  <= 1;
                end else begin
                    tx_bit <= tx_bit+1'd1;
                    rxd_o  <= tx_data[tx_bit[2:0]+3'd1];
                end
            end
            if (!tx_busy && !sbuf_we) rxd_o <= 1;
            // Mode 0 receives one bit per synchronous shift-clock pulse.
            if (tick12 && !rx_busy && scon[4] && !scon[0]) begin
                rx_busy <= 1;
                rx_bit  <= 0;
            end
            if (tick12 && rx_busy) begin
                rx_shift <= {rxd,rx_shift[7:1]};
                if (rx_bit==7) begin
                    rx_busy <= 0;
                    rx_bit <= 0;
                    if (!scon[0]) begin
                        rx_data  <= {rxd,rx_shift[7:1]};
                        rx_valid <= 1;
                        ri_set   <= 1;
                        rx_rb8   <= 0;
                    end
                end else rx_bit <= rx_bit+1'd1;
            end
        end else begin
            rxd_o <= 1;
            // Detect a start edge continuously, then sample the centre of
            // every frame bit with the generated 16x clock.
            if (!rx_busy && scon[4] && !rxd) begin
                rx_busy <= 1;
                rx_bit  <= 0;
                rx_sub  <= 4'd7;
            end
            if (baud16_tick) begin
                if (tx_busy) begin
                    if (tx_sub==4'd15) begin
                        tx_sub <= 0;
                        case (tx_bit)
                            0: begin txd<=0; tx_bit<=1; end
                            1,2,3,4,5,6,7,8: begin
                                txd <= tx_data[tx_bit[2:0]-3'd1];
                                tx_bit <= tx_bit+1'd1;
                            end
                            9: if (mode==1) begin txd<=1; tx_busy<=0; ti_set<=1; end
                               else begin txd<=scon[3]; tx_bit<=10; end
                            default: begin txd<=1; tx_busy<=0; ti_set<=1; end
                        endcase
                    end else tx_sub <= tx_sub+1'd1;
                end else txd <= 1;

                if (rx_busy) begin
                    if (rx_sub!=0) rx_sub <= rx_sub-1'd1;
                    else begin
                        rx_sub <= 4'd15;
                        case (rx_bit)
                            0: if (!rxd) rx_bit<=1; else rx_busy<=0;
                            1,2,3,4,5,6,7,8: begin
                                rx_shift[rx_bit[2:0]-3'd1] <= rxd;
                                rx_bit <= rx_bit+1'd1;
                            end
                            9: if (mode==1) begin
                                if (!scon[0] && (!scon[5] || rxd)) begin
                                    rx_data  <= rx_shift;
                                    rx_rb8   <= rxd;
                                    rx_valid <= 1;
                                    ri_set   <= 1;
                                end
                                rx_busy <= 0;
                            end else begin rx8<=rxd; rx_bit<=10; end
                            default: begin
                                if (!scon[0] && (!scon[5] || rx8)) begin
                                    rx_data  <= rx_shift;
                                    rx_rb8   <= rx8;
                                    rx_valid <= 1;
                                    ri_set   <= 1;
                                end
                                rx_busy <= 0;
                            end
                        endcase
                    end
                end
            end
        end
    end
end

endmodule
