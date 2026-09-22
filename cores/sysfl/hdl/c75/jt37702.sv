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

    Author: Andrea Bogazzi. email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 19-9-2026
*/

// Mitsubishi M37702 MCU (Namco C75). CPU core + on-chip peripherals +
// 512B internal RAM. The 16kB mask ROM (c75.bin) comes in through rom_*
// so the game top can source it from the SDRAM/BRAM slots in mem.yaml
//
// internal map (bank 0): 00-7F peripheral registers, 80-27F RAM,
// C000-FFFF internal ROM. Everything else goes to the external bus
//
// external bus, jtframe DTACK style: bus_cs asserts the request and the
// transaction completes on cen & bus_ok. dsn active-low byte lanes

module jt37702(
    input             rst,
    input             clk,
    input             cen,      // instruction rate, can run above XIN
    input             tcen,     // XIN = 16.128 MHz on System FL, subset of cen
    // external bus
    output     [23:0] addr,
    output reg        bus_cs,
    output            rnw,
    output     [15:0] dout,
    input      [15:0] din,
    output reg [ 1:0] dsn,
    input             bus_ok,
    // internal ROM, 16kB
    output reg        rom_cs,
    output     [13:1] rom_addr,
    input      [15:0] rom_data,
    input             rom_ok,
    // I/O ports 4-8
    input      [ 7:0] p4_din, p5_din, p6_din, p7_din, p8_din,
    output     [ 7:0] p4_dout, p5_dout, p6_dout, p7_dout, p8_dout,
    output     [ 7:0] p4_diro, p5_diro, p6_diro, p7_diro, p8_diro,
    // ADC channels an0-an7, 8 bits each, an0 = an[7:0]
    input      [63:0] an,
    // external interrupts, rising edge sensitive
    input             irq0, irq1, irq2,
    // timer A external event inputs
    input      [ 4:0] tain,
    output            stp
);

// CPU <-> bus unit
wire        breq, bw16, bwr;
wire [23:0] baddr;
wire [15:0] bdout;
reg  [15:0] bdin;
reg         back;
// interrupts
wire        irq_rq, irq_ack;
wire [ 2:0] irq_lvl;
wire [ 4:0] irq_ix, irq_ackix;
// peripheral register bus
reg         psel;
wire        pwr;
wire [ 7:0] pdout;
// internal RAM, 512B
reg  [15:0] ram[0:255];
reg  [23:0] a1;         // current sub-access address
reg  [ 7:0] lob;        // low byte of a split access
reg         h1, two, wlat;
reg  [15:0] dlat;
reg  [ 1:0] bst;

localparam [1:0] BIDLE=0, BRUN=1;

// sub-access target decode
wire sel_reg = a1[23:7]==0;
wire sel_ram = a1[23:10]==0 && a1[9:7]!=0 && a1[9:0]<10'h280;
wire sel_rom = a1[23:16]==0 && a1[15:14]==2'b11;
wire sel_ext = !sel_reg && !sel_ram && !sel_rom;
// same decode on the raw request, for the single-cycle internal fast path
wire breg    = baddr[23:7]==0;
wire bram    = baddr[23:10]==0 && baddr[9:7]!=0 && baddr[9:0]<10'h280;
wire brom    = baddr[23:16]==0 && baddr[15:14]==2'b11;
wire bsplit  = bw16 && (baddr[0] || breg); // registers are byte wide
wire bfast   = !bsplit && bram;            // completes in one cen

// RAM covers 080-27F: word index minus 0x40 fits in 8 bits
wire [ 7:0] rix    = a1[8:1]    - 8'h40;
wire [ 7:0] rix0   = baddr[8:1] - 8'h40;
wire [15:0] ram_q  = ram[rix];
wire [15:0] ram_q0 = ram[rix0];
wire [ 7:0] cur_b;
// internal ROM is self-timed: the BRAM output is valid one cen after a1
// settles, so a1-addressed data can be consumed on the second BRUN cycle
reg         romrdy;
wire        sub_ok = sel_ext ? bus_ok : sel_rom ? (romrdy && rom_ok) : 1'b1;

assign rom_addr = bst==BIDLE ? baddr[13:1] : a1[13:1]; // early address for 2-cen fetch
assign addr     = {a1[23:1], bw16&&!two ? 1'b0 : a1[0]};
assign rnw      = !wlat;
// byte transfers replicate the byte on both lanes, dsn selects the target
assign dout     = two  ? {2{h1 ? dlat[15:8] : dlat[7:0]}} :
                  bw16 ? dlat : {2{dlat[7:0]}};
assign cur_b    = sel_reg ? pdout :
                  sel_ram ? (a1[0] ? ram_q[15:8]  : ram_q[7:0]) :
                  sel_rom ? (a1[0] ? rom_data[15:8]: rom_data[7:0]) :
                            (a1[0] ? din[15:8]    : din[7:0]);
assign pwr      = wlat;

wire [7:0] wr_b = h1 ? dlat[15:8] : dlat[7:0];

always @* begin
    bus_cs = 0;
    rom_cs = 0;
    psel   = 0;
    dsn    = 2'b11;
    if( bst==BRUN ) begin
        bus_cs = sel_ext;
        rom_cs = sel_rom;
        psel   = sel_reg && sub_ok;
        if( bw16 && !two ) dsn = 2'b00;
        else dsn = a1[0] ? 2'b01 : 2'b10;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        bst<=BIDLE; back<=0; bdin<=0; a1<=0; lob<=0; romrdy<=0;
        h1<=0; two<=0; wlat<=0; dlat<=0;
    end else if( cen ) begin
        back <= 0;
        romrdy <= (bst==BIDLE && breq && !back && brom && !bsplit) ||
                  (bst==BRUN  && sel_rom && !sub_ok);
        case( bst )
        BIDLE: if( breq && !back ) begin
            a1   <= baddr;
            h1   <= 0;
            two  <= bsplit;
            wlat <= bwr;
            dlat <= bdout;
            if( bfast ) begin // internal RAM completes in one cen
                if( bwr ) begin
                    if( bw16 ) ram[rix0] <= bdout;
                    else if( baddr[0] ) ram[rix0][15:8] <= bdout[7:0];
                    else                ram[rix0][ 7:0] <= bdout[7:0];
                end
                bdin <= bw16 ? ram_q0 :
                        baddr[0] ? {8'd0,ram_q0[15:8]} : {8'd0,ram_q0[7:0]};
                back <= 1;
            end else begin
                bst <= BRUN;
            end
        end
        BRUN: if( sub_ok ) begin
            // capture / commit the current sub-access
            if( wlat ) begin
                if( sel_ram ) begin
                    if( bw16 && !two ) ram[rix] <= dlat;
                    else if( a1[0] ) ram[rix][15:8] <= wr_b;
                    else             ram[rix][ 7:0] <= wr_b;
                end
                // sel_reg writes happen in jt37702_per via psel/pwr
                // sel_rom writes are ignored
            end
            if( two && !h1 ) begin
                lob <= cur_b;
                h1  <= 1;
                a1  <= a1 + 24'd1;
            end else begin
                bdin <= two ? {cur_b,lob} :
                        bw16 ? ( sel_ram ? ram_q :
                                 sel_rom ? rom_data :
                                 sel_ext ? din : {8'd0,pdout} )
                             : {8'd0,cur_b};
                back <= 1;
                bst  <= BIDLE;
            end
        end
        default: bst <= BIDLE;
        endcase
    end
end

jt37702_cpu u_cpu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .breq       ( breq      ),
    .baddr      ( baddr     ),
    .bw16       ( bw16      ),
    .bwr        ( bwr       ),
    .bdout      ( bdout     ),
    .bdin       ( bdin      ),
    .back       ( back      ),
    .irq_rq     ( irq_rq    ),
    .irq_lvl    ( irq_lvl   ),
    .irq_ix     ( irq_ix    ),
    .irq_ack    ( irq_ack   ),
    .irq_ackix  ( irq_ackix ),
    .stp        ( stp       )
);

jt37702_per u_per(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .tcen       ( tcen      ),
    .pa         ( a1[6:0]   ),
    .psel       ( psel      ),
    .pwr        ( pwr       ),
    .pdin       ( wr_b      ),
    .pdout      ( pdout     ),
    .p4_din     ( p4_din    ),
    .p5_din     ( p5_din    ),
    .p6_din     ( p6_din    ),
    .p7_din     ( p7_din    ),
    .p8_din     ( p8_din    ),
    .p4_dout    ( p4_dout   ),
    .p5_dout    ( p5_dout   ),
    .p6_dout    ( p6_dout   ),
    .p7_dout    ( p7_dout   ),
    .p8_dout    ( p8_dout   ),
    .p4_diro    ( p4_diro   ),
    .p5_diro    ( p5_diro   ),
    .p6_diro    ( p6_diro   ),
    .p7_diro    ( p7_diro   ),
    .p8_diro    ( p8_diro   ),
    .an         ( an        ),
    .irq0       ( irq0      ),
    .irq1       ( irq1      ),
    .irq2       ( irq2      ),
    .tain       ( tain      ),
    .irq_rq     ( irq_rq    ),
    .irq_lvl    ( irq_lvl   ),
    .irq_ix     ( irq_ix    ),
    .irq_ack    ( irq_ack   ),
    .irq_ackix  ( irq_ackix )
);

endmodule
