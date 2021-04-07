/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 5-4-2021 */

module jtrumble_main(
    input              rst,
    input              clk,
    input              cen8,
    output             cpu_cen,
    input              LVBL,   // vertical blanking when 0
    // Screen
    output  reg        pal_cs,
    output  reg        flip,
    // Sound
    output  reg        sres_b, // Z80 reset
    output  reg [7:0]  snd_latch,
    // Characters
    input       [7:0]  char_dout,
    output      [7:0]  cpu_dout,
    output  reg        char_cs,
    input              char_busy,
    // scroll
    input       [7:0]  scr_dout,
    output  reg        scr_cs,
    input              scr_busy,
    output  reg [8:0]  scr_hpos,
    output  reg [8:0]  scr_vpos,
    // cabinet I/O
    input       [1:0]  start_button,
    input       [1:0]  coin_input,
    input       [5:0]  joystick1,
    input       [5:0]  joystick2,
    // BUS sharing
    output             bus_ack,
    input              bus_req,
    output  [12:0]     cpu_AB,
    output             RnW,
    output reg         OKOUT,
    // ROM access
    output  reg        rom_cs,
    output      [17:0] rom_addr,
    input       [ 7:0] rom_data,
    input              rom_ok,
    // RAM access
    output  reg        ram_cs,
    output      [12:0] ram_addr,
    input       [ 7:0] ram_data,
    input              ram_ok,
    // Memory map PROM
    input       [ 7:0] prog_addr,
    input       [ 1:0] prom_bank,
    input       [ 3:0] prom_din,
    // DIP switches
    input              service,
    input              dip_pause,
    input  [7:0]       dipsw_a,
    input  [7:0]       dipsw_b
);

wire [15:0] A;
wire        waitn;
wire        nRESET;
wire        cen_E, cen_Q;
reg         io_cs, ram_cs;
reg  [ 7:0] bank;
wire [ 7:0] mem_map, bank_addr0, bank_addr1, cpu_din;

assign bank_addr0 = { bank[7:4], A[15:12] };
assign bank_addr1 = { bank[3:0], A[15:12] };
assign rom_addr   = { mem_map[5:0], A[11:0] };
assign ram_addr   = A[12:0];

always @(*) begin
    ram_cs      = 0;
    scr_cs      = 0;
    io_cs       = 0;
    rom_cs      = 0;
    char_cs     = 0;
    pal_cs      = 0;
    if( /* (E || Q || !waitn) && */ nRESET ) begin
        casez(A[15:12])
            4'b000?: ram_cs = 1; // 0
            4'b001?: scr_cs = 1; // 2-3
            4'b0100: io_cs  = A[3]; // 4
            default: begin
                rom_cs =  RnW;
                char_cs= !RnW && A[15:12]==4'h5;
                pal_cs = !RnW && A[15:12]==4'h7;
            end
        endcase
    end
end

always @(posedge clk or negedge nRESET) begin
    if( !nRESET ) begin
        scr_hpos  <= 0;
        scr_vpos  <= 0;
        snd_latch <= 0;
        flip      <= 0;
        sres_b    <= 1;
        bank      <= 0;
    end else if(cen_Q && io_cs && !RnW ) begin
        case(A[2:0])
            3'd0: bank <= cpu_dout;
            3'd1: begin
                flip   <= cpu_dout[7]; // coin counters go here too
                sres_b <= cpu_dout[4]; // it could be bit 5, not sure, they are toggled together
            end
            3'd2: scr_hpos[7:0] <= cpu_dout;
            3'd3: scr_hpos[8]   <= cpu_dout[0];
            3'd4: scr_vpos[7:0] <= cpu_dout;
            3'd5: scr_vpos[8]   <= cpu_dout[0];
            3'd6: snd_latch     <= cpu_dout;
        endcase
    end
end

// CPU reset
jt12_rst u_rst(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .rst_n  ( nRESET    )
);

reg [7:0] cabinet;

always @(*) begin
    case( cpu_AB[2:0])
        3'd0: cabinet = { coin_input, // COINS
                     service,
                     1'b1, // tilt?
                     2'h3, // undocumented
                     start_button }; // START
        3'd1: cabinet = { 2'b11, joystick1 };
        3'd2: cabinet = { 2'b11, joystick2 };
        3'd3: cabinet = dipsw_a;
        3'd4: cabinet = dipsw_b;
        default: cabinet = 8'hff;
    endcase
end

assign cpu_din = rom_cs  ? rom_data : (
                 ram_cs  ? ram_data : (
                 scr_cs  ? scr_dout : (
                 char_cs ? char_dout: (
                 io_cs   ? cabinet  : 8'hff ))));

// Bus access
reg nIRQ, last_LVBL;
wire BS,BA;

assign bus_ack = BA && BS;

always @(posedge clk) if(cen_Q) begin
    last_LVBL <= LVBL;
    if( {BS,BA}==2'b10 )
        nIRQ <= 1'b1;
    else
        if(last_LVBL && !LVBL ) nIRQ<=1'b0 | ~dip_pause; // when LVBL goes low
end

wire bus_busy = scr_busy | char_busy;

jtframe_6809wait u_wait(
    .rstn       ( nRESET    ),
    .clk        ( clk       ),
    .cen        ( cen8      ),
    .cpu_cen    ( cpu_cen   ),
    .dev_busy   ( bus_busy  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .cen_E      ( cen_E     ),
    .cen_Q      ( cen_Q     )
);

mc6809i u_cpu (
    .clk     ( clk     ),
    .cen_E   ( cen_E   ),
    .cen_Q   ( cen_Q   ),
    .D       ( cpu_din ),
    .DOut    ( cpu_dout),
    .ADDR    ( A       ),
    .RnW     ( RnW     ),
    .BS      ( BS      ),
    .BA      ( BA      ),
    .nIRQ    ( nIRQ    ),
    .nFIRQ   ( 1'b1    ),
    .nNMI    ( 1'b1    ),
    .nHALT   ( ~bus_req),
    .nRESET  ( nRESET  ),
    .nDMABREQ( 1'b1    ),
    // unused:
    .RegData (         )
    //.AVMA()
);

jtframe_prom #(.dw(4),.aw(8),.simfile("63s141.12a")) u_bank0(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( prom_din[3:0] ),
    .rd_addr( bank_addr0    ),
    .wr_addr( prog_addr     ),
    .we     ( prom_bank[0]  ),
    .q      ( mem_map[3:0]  )
);

jtframe_prom #(.dw(4),.aw(8),.simfile("63s141.13a")) u_bank1(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( prom_din[3:0] ),
    .rd_addr( bank_addr1    ),
    .wr_addr( prog_addr     ),
    .we     ( prom_bank[1]  ),
    .q      ( mem_map[7:4]  )
);

endmodule