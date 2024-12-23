/*  This file is part of JT_FRAME.
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
    Date: 1-6-2021 */

module jtframe_cheat #(parameter AW=22)(
    input           rst,
    input           clk_rom,
    input           clk_pico, // always 48 MHz

    input           LVBL,
    input  [31:0]   status,

    // From/to game
    input  [AW-1:0] game_addr,
    input           game_rd,
    input           game_wr,
    input  [ 15:0]  game_din,
    input  [  1:0]  game_din_m,
    output reg      game_ack,
    output reg      game_dst,
    output reg      game_rdy,

    // From/to SDRAM bank 0
    output reg [AW-1:0] ba0_addr,
    output reg          ba0_rd,
    output reg          ba0_wr,
    input               ba0_ack,
    input               ba0_dst,
    input               ba0_rdy,
    output reg [ 15:0]  ba0_din,
    output reg [  1:0]  ba0_din_m,
    input      [ 15:0]  data_read,

    // control
    input    [31:0] flags,
    input    [ 7:0] joy1,
    input    [15:0] joyana_l1,
    input    [15:0] joyana_r1,

    input    [ 7:0] joy2,
    input    [15:0] joyana_l2,
    input    [15:0] joyana_r2,

    output reg      led,
    input    [31:0] timestamp,
    input           pause_in,
    output          pause_out,
    input           locked,

    // Communication with game module
    output reg [7:0] st_addr,
    input      [7:0] st_dout,
    input      [7:0] debug_bus,

    // Video RAM
    output reg [9:0] vram_addr,
    output reg [7:0] vram_dout,
    input      [7:0] vram_din,
    output reg       vram_we,
    output reg [2:0] vram_ctrl,

    // UART
    input            uart_rx,     // Define JTFRAME_UART for OSD options to show
    output           uart_tx,

    // PBlaze Program
    input           prog_en,      // resets the address counter
    input           prog_wr,      // strobe for new data
    input  [7:0]    prog_addr,    // only 8 bits are needed regardless of actual length
    input  [7:0]    prog_data
);

localparam CHEATW=10;  // 12=>9kB (8 BRAM)
                       // 10=>2.25kB (2 BRAM), 9=>1.12kB (1 BRAM)

localparam [31:0] BUILDTIME = `JTFRAME_TIMESTAMP; // Build time

// UART works at 57.6 kbps for 48MHz, 115.2 for 96MHz
localparam [4:0] UART_DIV=29;

wire clk = clk_pico;

// Instruction ROM
wire [11:0] iaddr;
wire [17:0] idata;

// Ports
wire [ 7:0] pout, paddr;
reg  [ 7:0] pin=0;
wire        pwr, kwr, prd;

// interrupts
reg         irq=0, LVBL_last;
wire        iack;

// uptime
reg  [ 5:0] frame_cnt=0;
reg  [23:0] sec_cnt=0;   // count up to 194 days
wire [31:0] cur_time = timestamp + {8'd0, sec_cnt};

// UART
wire [ 7:0] uart_dout;
reg         uart_clr;
wire        uart_wr, uart_busy, uart_rdy, uart_error;

reg  [ 3:0] watchdog;
reg         prst=0;

assign pause_out = pause_in;
// UART
assign uart_wr = pwr && paddr==8'h34;

always @(posedge clk) begin
    prst <= watchdog[3] | rst;
end

`ifdef JTFRAME_EXPIRATION
    localparam [31:0] EXPIRATION = `JTFRAME_EXPIRATION;
    reg expired;

    always @(posedge clk) expired = cur_time > EXPIRATION;
`else
    wire expired=0;
`endif

always @(posedge clk) begin
    LVBL_last <= LVBL;
    if( !LVBL && LVBL_last ) begin
        if( frame_cnt==59 ) begin
            frame_cnt <= 0;
            sec_cnt   <= sec_cnt + 1'd1;
        end else begin
            frame_cnt <= frame_cnt+1;
        end
    end
end

always @(posedge clk) begin
    if( prst ) begin
        irq       <= 0;
    end else begin
        if( !LVBL && LVBL_last )
            irq <= 1;
        else if( iack ) irq <= 0;
    end
end

// Ports
reg  [ 7:0] ports[0:5];
reg  [ 7:0] sdram_lsb, sdram_msb;
wire [23:0] blaze_sdram_addr;
wire [15:0] blaze_sdram_din;
wire [ 1:0] blaze_sdram_din_m;

// SDRAM
reg  sdram_busy=0, pico_busy=0, owner=0, sdram_req=0, sdram_req_wr=0;

assign blaze_sdram_addr  = { ports[2], ports[1], ports[0] };
assign blaze_sdram_din   = { ports[4], ports[3] };
assign blaze_sdram_din_m = ports[5][1:0];

// VRAM
always @(posedge clk) begin
    if( prst ) begin
        vram_we    <= 0;
        vram_ctrl  <= 0;
    end else begin
        vram_we <= 0;
        if( (pwr|kwr) && paddr[7:3]==5'b0000_1 ) begin
            case( paddr[2:0] )
                0: vram_addr[4:0] <= pout[4:0];
                1: vram_addr[9:5] <= pout[4:0];
                2: { vram_we, vram_dout } <= { 1'b1, 1'b1, pout[6:0] };
                3: vram_ctrl <= pout[2:0];
            endcase
        end
    end
end

always @(posedge clk) begin
    if( (pwr|kwr) && paddr<=5 ) begin
        ports[ paddr[2:0] ] <= pout;
    end
    // Game status
    if( (pwr|kwr) && paddr==8'hc ) begin
        st_addr <= pout;
    end
    // watchdog
    if( !LVBL && LVBL_last ) begin
        watchdog <= watchdog+1'd1;
    end
    if( (pwr && paddr[7:6]==2'b01) || prst )
        watchdog <= 0;
    // led
    if( prst )
        led <= 0;
    else if( (pwr|kwr) && paddr==6 )
        led <= pout[0];
end

reg [7:0] timemux;

always @(*) begin
    case( paddr[7:0] )
        8'h20: timemux = timestamp[ 7: 0];
        8'h21: timemux = timestamp[15: 8];
        8'h22: timemux = timestamp[23:16];
        8'h23: timemux = timestamp[31:24];
        8'h24: timemux = BUILDTIME[ 7: 0];
        8'h25: timemux = BUILDTIME[15: 8];
        8'h26: timemux = BUILDTIME[23:16];
        8'h27: timemux = BUILDTIME[31:24];
        8'h28: timemux = cur_time[ 7: 0];
        8'h29: timemux = cur_time[15: 8];
        8'h2a: timemux = cur_time[23:16];
        8'h2b: timemux = cur_time[31:24];
        8'h2c: timemux = {2'd0, frame_cnt };
        default: timemux = 0;
    endcase
end

always @(posedge clk) begin
    if(prst) begin
        pin <= 0;
        uart_clr <= 0;
    end else begin
        uart_clr <= 0;
        if(prd) begin
            casez( paddr[7:0] )
                0,1,2,3,4,5:
                       pin <= ports[ paddr[2:0] ];
                6: pin <= sdram_lsb;
                7: pin <= sdram_msb;
                // VRAM or status
                8'h0a: pin <= vram_din;
                8'h0d: pin <= st_dout;
                8'h0f: pin <= debug_bus;

                // Flags
                8'h10: pin <= flags[ 7: 0];
                8'h11: pin <= flags[15: 8];
                8'h12: pin <= flags[23:16];
                8'h13: pin <= flags[31:24];

                // Board status
                8'h14: pin <= status[ 7: 0];
                8'h15: pin <= status[15: 8];
                8'h16: pin <= status[23:16];
                8'h17: pin <= status[31:24];

                // Joystick
                8'h18: pin <= joy1;
                8'h1a: pin <= joyana_l1[ 7:0];
                8'h1b: pin <= joyana_l1[15:8];
                8'h1c: pin <= joyana_r1[ 7:0];
                8'h1d: pin <= joyana_r1[15:8];
                8'h48: pin <= joy2;
                8'h4a: pin <= joyana_l2[ 7:0];
                8'h4b: pin <= joyana_l2[15:8];
                8'h4c: pin <= joyana_r2[ 7:0];
                8'h4d: pin <= joyana_r2[15:8];


                8'h2?: pin <= timemux; // Time
                // UART
                8'h34: begin
                    pin <= uart_dout;
                    uart_clr <= 1;
                end
                8'h35: pin <= { 3'b0, uart_error, 2'b0, uart_busy, uart_rdy };
                8'h80: pin <= { owner, pico_busy, LVBL, 3'b0, expired, locked }; // 8'hc0 means that the SDRAM data is ready
                default: pin <= 0;
            endcase
        end
    end
end


// SDRAM signals must use clk_rom
always @(posedge clk_rom) begin
    if( ba0_dst && owner ) begin
        {sdram_msb, sdram_lsb} <= data_read;
    end
    if( pwr && paddr[7] && !locked ) begin
        sdram_req <= 1;
        sdram_req_wr <= paddr[6];
    end
    if( ba0_ack && owner ) begin
        sdram_req <= 0;
    end
end

// SDRAM arbitrer
always @(posedge clk_rom) begin
    if( ba0_rdy ) begin
        sdram_busy <= 0;
        if( owner ) pico_busy <= 0;
    end
    if( !sdram_busy  ) begin
        if( game_rd || game_wr ) begin
            sdram_busy <= 1;
            owner <= 0;
        end else if( sdram_req ) begin
            sdram_busy <= 1;
            owner <= 1;
            pico_busy <= 1;
        end
    end
end

always @(*) begin
    ba0_addr  = owner ? blaze_sdram_addr  : game_addr;
    ba0_rd    = owner ? (sdram_req & ~sdram_req_wr) : game_rd;
    ba0_wr    = owner ? (sdram_req &  sdram_req_wr) : game_wr;
    ba0_din   = owner ? blaze_sdram_din   : game_din;
    ba0_din_m = owner ? blaze_sdram_din_m : game_din_m;
    game_dst  = ~owner & ba0_dst;
    game_rdy  = ~owner & ba0_rdy;
    game_ack  = ~owner & ba0_ack;
end

// PicoBlaze compatible module

pauloBlaze u_blaze(
    .clk            ( clk       ),
    .reset          ( prst      ),
    .sleep          ( 1'b0      ),

    .address        ( iaddr     ),
    .instruction    ( idata     ),
    .bram_enable    (           ),

    .in_port        ( pin       ),
    .out_port       ( pout      ),
    .port_id        ( paddr     ),
    .write_strobe   ( pwr       ),
    .k_write_strobe ( kwr       ),
    .read_strobe    ( prd       ),

    //.interrupt      ( irq       ),
    .interrupt      ( 1'b0      ), // The interrupt in pauloBlaze is buggy
    .interrupt_ack  ( iack      )
);

jtframe_uart #(
    .CLK_DIVIDER( UART_DIV  )
) u_uart(
    .rst        ( rst       ),
    .clk        ( clk       ),
    // serial wires
    .uart_rx    ( uart_rx   ),
    .uart_tx    ( uart_tx   ), // serial signal to transmit. High when idle
    // Rx interface
    .rx_data    ( uart_dout ),
    .rx_error   ( uart_error),
    .rx_rdy     ( uart_rdy  ),
    .rx_clr     ( uart_clr  ),    // clear the rx_rdy flag
    // Tx interface
    .tx_busy    ( uart_busy ),
    .tx_data    ( pout      ),
    .tx_wr      ( uart_wr   )      // write strobe
);

jtframe_cheat_rom #(.AW(CHEATW)) u_rom(
    .rst        ( rst       ),
    .clk_rom    ( clk_rom   ),
    .clk_pico   ( clk_pico  ),
    .iaddr      ( iaddr[CHEATW-1:0] ),
    .idata      ( idata     ),
    // PBlaze Program
    .prog_addr  ( prog_addr ),
    .prog_en    ( prog_en   ),      // resets the address counter
    .prog_wr    ( prog_wr   ),      // strobe for new data
    .prog_data  ( prog_data )
);

endmodule
