/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 24-11-2021

*/

module jtframe_uart(
    input            rst,
    input            clk,
    // serial wires
    input            uart_rx,
    output reg       uart_tx, // serial signal to transmit. High when idle
    // Rx interface
    output reg [7:0] rx_data,
    output reg       rx_error,
    output reg       rx_rdy,
    input            rx_clr,    // clear the rx_rdy flag
    // Tx interface
    output reg       tx_busy,
    input      [7:0] tx_data,
    input            tx_wr      // write strobe
);

/* Division of the system clock
        For a 50MHz system clock use:
            CLK_DIVIDER = 28, UART_DIVIDER = 30 ->  57kbps, 0.01% timing error
            CLK_DIVIDER = 14, UART_DIVIDER = 30 -> 115kbps, 0.01% timing error
            CLK_DIVIDER =  7, UART_DIVIDER = 30 -> 230kbps, 0.01% timing error
    */
parameter [4:0] CLK_DIVIDER  = 28,
                UART_DIVIDER = CLK_DIVIDER; // number of divisions of the UART bit period

//-----------------------------------------------------------------
// zero generator... this is actually a 32-module counter
//-----------------------------------------------------------------
reg  [4:0] clk_cnt;
reg zero;

always @(posedge clk or posedge rst) begin : clock_divider
    if(rst) begin
        clk_cnt <= CLK_DIVIDER - 5'b1;
        zero    <= 1'b0;
    end else begin
        clk_cnt <= clk_cnt - 5'd1;
        zero <= clk_cnt==5'd1;
        if(zero)
            clk_cnt <= CLK_DIVIDER - 5'b1;  // reload the divider value
    end
end

//-----------------------------------------------------------------
// Synchronize uart_rx
//-----------------------------------------------------------------
reg uart_rx1;
reg uart_rx2;

always @(posedge clk) begin : synchronizer
    uart_rx1 <= uart_rx;
    uart_rx2 <= uart_rx1;
end

// Reception
reg rx_busy;
reg [4:0] rx_divcnt;
reg [3:0] rx_bitcnt;
reg [7:0] rx_reg;

always @(posedge clk or posedge rst) begin : rx_logic
    if(rst) begin
        rx_rdy    <= 0;     // output data is valid
        rx_busy   <= 0;
        rx_divcnt <= 0;
        rx_bitcnt <= 0;
        rx_data   <= 0;
        rx_reg    <= 0;
        rx_error  <= 0;
    end else begin
        if( rx_clr ) begin
            rx_rdy   <= 0;
            rx_error <= 0;
        end

        if( zero ) begin
            if(!rx_busy && !uart_rx2) begin // look for start bit
                rx_busy    <= 1;
                rx_divcnt  <= UART_DIVIDER>>1; // wait middle period
                rx_bitcnt  <= 0;
                rx_reg     <= 0;
            end else if( rx_busy ) begin
                rx_divcnt <= rx_divcnt==0 ? UART_DIVIDER : rx_divcnt - 1'b1;
                if( rx_divcnt==0 ) begin // sample
                    rx_bitcnt  <= rx_bitcnt + 4'd1;
                    if( rx_bitcnt<9 ) begin // stop bit
                        rx_reg <= {uart_rx2, rx_reg[7:1]}; // shift data in
                    end else begin
                        rx_busy  <= 0;
                        rx_rdy   <= 1;
                        rx_data  <= rx_reg;
                        rx_error <= !uart_rx2; // check stop bit
                    end
                end
            end
        end
    end
end

// Transmission
reg [3:0] tx_bitcnt;
reg [4:0] tx_divcnt;
reg [7:0] tx_reg;

always @(posedge clk or posedge rst) begin :tx_logic
    if(rst) begin
        tx_busy   <= 0;
        uart_tx   <= 1;
        tx_divcnt <= 0;
        tx_reg    <= 0;
    end else begin
        if( tx_wr && !tx_busy ) begin
            tx_reg    <= tx_data;
            tx_bitcnt <= 0;
            tx_divcnt <= UART_DIVIDER;
            tx_busy   <= 1;
            uart_tx   <= 0; // start bit
        end else if(zero && tx_busy) begin
            tx_divcnt <= tx_divcnt==0 ? UART_DIVIDER : tx_divcnt-1'd1;
            if( tx_divcnt==0 ) begin
                tx_bitcnt <= tx_bitcnt + 4'd1;
                if( tx_bitcnt < 8 ) begin
                    uart_tx <= tx_reg[0];
                    tx_reg  <= tx_reg>>1;
                end else begin
                    uart_tx <= 1; // 8 bits sent, now 1 or more stop bits
                    if(tx_bitcnt==9) tx_busy <= 0;
                end
            end
        end
    end
end

endmodule
