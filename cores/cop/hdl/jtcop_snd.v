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
    Date: 26-9-2021 */

module jtcop_snd(
    input                rst,
    input                clk,
    input                cen_opn,
    input                cen_opl,

    // From main CPU
    input                snreq,  // sound interrupt from main CPU
    input         [ 7:0] latch,

    // ROM
    output        [15:0] rom_addr,
    output    reg        rom_cs,
    input         [ 7:0] rom_data,
    input                rom_ok,
    output    reg        snd_bank,

    // ADPCM ROM
    output        [17:0] adpcm_addr,
    output               adpcm_cs,
    input         [ 7:0] adpcm_data,
    input                adpcm_ok,

    output signed [15:0] opn, opl,
    output signed [13:0] pcm,
    output        [ 9:0] psg,

    output        [ 7:0] status
);
parameter BANKS=0, KARNOV=0;

`ifndef NOSOUND

wire [15:0] cpu_addr;
wire [ 7:0] cpu_dout, opl_dout, opn_dout, ram_dout, oki_dout;
reg  [ 7:0] cpu_din, dev_mux;
reg         nmin, opl_cs, opn_cs, ram_cs, bank_cs,
            nmi_clr, oki_cs, dev_cs;
wire        irqn, ram_we, cpu_rnw, oki_wrn, rdy;
wire        opn_irqn, opl_irqn;


assign irqn     = KARNOV ? opl_irqn : opn_irqn & opl_irqn;
assign ram_we   = ram_cs & ~cpu_rnw;
assign oki_wrn  = ~(oki_cs & ~cpu_rnw);
assign rom_addr = cpu_addr;
assign rdy      = ~rom_cs | rom_ok;
assign status   = { 1'b0, opn_irqn, opl_irqn, opn_dout[7], oki_dout[3:0]};

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ram_cs  <= 0;
        opn_cs  <= 0;
        opl_cs  <= 0;
        nmi_clr <= 0;
        oki_cs  <= 0;
    end else begin
        ram_cs  <= 0;
        opn_cs  <= 0;
        opl_cs  <= 0;
        nmi_clr <= 0;
        oki_cs  <= 0;
        if( KARNOV ) begin
            bank_cs <= 0;
            rom_cs  <= cpu_addr[15];
            if( !cpu_addr[15] ) begin
                case(cpu_addr[12:11])
                    0: ram_cs  <= 1;
                    1: nmi_clr <= cpu_rnw;
                    2: opn_cs  <= 1;
                    3: opl_cs  <= 1;
                endcase
            end
        end else begin
            bank_cs <= BANKS && cpu_addr[15] && !cpu_rnw;
            rom_cs  <= |cpu_addr[15:14]; // some games only use bit 15
            if(cpu_addr[15:14]==0) begin
                case( cpu_addr[13:11] )
                    0: ram_cs  <= 1;
                    1: opn_cs  <= 1;
                    2: opl_cs  <= 1;
                    6: nmi_clr <= cpu_rnw;
                    7: oki_cs  <= 1;
                    default:;
                endcase
            end
        end
    end
end

always @(posedge clk) begin
    dev_cs  <= opn_cs | opl_cs | oki_cs;
    dev_mux <= opn_cs  ? opn_dout :
               opl_cs  ? opl_dout : oki_dout;
end

always @* begin
    cpu_din = rom_cs  ? rom_data :
               ram_cs  ? ram_dout :
               nmi_clr ? latch    :
               dev_cs  ? dev_mux :
               8'hff;
end

reg snreq_l;

always @(posedge clk) begin
    if( rst ) begin
        nmin    <= 1;
        snreq_l <= 0;
    end else begin
        snreq_l <= snreq;
        if( nmi_clr ) nmin <= 1;
        else if( snreq & ~snreq_l ) nmin <= 0;
    end
end

// system registers
always @(posedge clk) begin
    if( rst ) begin
        snd_bank <= 0;
    end else begin
        if( bank_cs ) snd_bank <= cpu_dout[0];
    end
end

// As the sound tempo comes from interruptions,
// cycle recovery isn't probably needed
wire [7:0] nc;
T65 u_cpu(
    .Mode   ( 2'd0      ),  // 6502 mode
    .Res_n  ( ~rst      ),
    .Enable ( cen_opn   ),
    .Clk    ( clk       ),
    .Rdy    ( rdy       ),
    .Abort_n( 1'b1      ),
    .IRQ_n  ( irqn      ),
    .NMI_n  ( nmin      ),
    .SO_n   ( 1'b1      ),
    .R_W_n  ( cpu_rnw   ),
    .Sync   (           ),
    .EF     (           ),
    .MF     (           ),
    .XF     (           ),
    .ML_n   (           ),
    .VP_n   (           ),
    .VDA    (           ),
    .VPA    (           ),
    .A      ({nc,cpu_addr}),
    .DI     ( cpu_din   ),
    .DO     ( cpu_dout  )
);

jtframe_ram #(.AW(11)) u_ram(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( cpu_dout      ),
    .addr   ( cpu_addr[10:0]),
    .we     ( ram_we        ),
    .q      ( ram_dout      )
);

jtcop_ongen u_ongen(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen_opn    ( cen_opn       ),
    .cen_opl    ( cen_opl       ),

    .cpu_a0     ( cpu_addr[0]   ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_dout   ( cpu_dout      ),

    .opl_cs     ( opl_cs        ),
    .opl_irqn   ( opl_irqn      ),
    .opl_dout   ( opl_dout      ),

    .opn_cs     ( opn_cs        ),
    .opn_irqn   ( opn_irqn      ),
    .opn_dout   ( opn_dout      ),

    .oki_wrn    ( oki_wrn       ),
    .oki_dout   ( oki_dout      ),

    // ADPCM ROM
    .adpcm_addr ( adpcm_addr    ),
    .adpcm_cs   ( adpcm_cs      ),
    .adpcm_data ( adpcm_data    ),
    .adpcm_ok   ( adpcm_ok      ),

    .opn        ( opn           ),
    .opl        ( opl           ),
    .pcm        ( pcm           ),
    .psg        ( psg           )
);

`else
    initial rom_cs     = 0;
    assign  rom_addr   = 0;
    assign  adpcm_addr = 0;
    assign  adpcm_cs   = 0;
    assign  opn        = 0;
    assign  opl        = 0;
    assign  pcm        = 0;
    assign  psg        = 0;
    assign  status     = 0;
    initial snd_bank   = 0;
`endif

endmodule