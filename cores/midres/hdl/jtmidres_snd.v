/*  This file is part of JTCOP.
    JTCOP program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCOP program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCOP.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 14-2-2021 */

/* verilator tracing_on */
module jtcop_snd(
    input                rst,
    input                clk,   // use 24 MHz
    input                cen_opn,
    input                cen_opl,

    input                enable_psg,
    input                enable_fm,
    input         [ 1:0] fxlevel,

    // From main CPU
    input                snreq,  // sound interrupt from main CPU
    input         [ 7:0] latch,

    // ROM
    output        [15:0] rom_addr,
    output    reg        rom_cs,
    input         [ 7:0] rom_data,
    input                rom_ok,
    output               snd_bank,

    // ADPCM ROM
    output        [17:0] adpcm_addr,
    output               adpcm_cs,
    input         [ 7:0] adpcm_data,
    input                adpcm_ok,

    output signed [15:0] snd,
    output               sample,
    output               peak,
    output        [ 7:0] status
);

wire [20:0] A;
wire [ 7:0] dout, opn_dout, opl_dout, oki_dout;
reg  [ 7:0] din;
wire        wrn, rdn, SX, oki_wrn;

wire        ce, cek_n, ce7_n, cer_n;
wire        main_we;

wire        irqn;
reg         ram_cs, opl_cs, opn_cs, oki_cs, latch_cs;
wire [ 7:0] ram_dout;
wire        ram_we;
reg         rom_good;
wire        opn_irqn, opl_irqn;

assign irqn     = opn_irqn & opl_irqn;
assign snd_bank = 0;
assign oki_wrn  = ~(oki_cs & ~wrn);
assign rom_addr = A[15:0];
assign ram_we   = ram_cs & ~wrn;
assign status   = { 1'b0, opn_irqn, opl_irqn, opn_dout[7], oki_dout[3:0]};

// Unless SX is used, you can create a SDRAM
// request before knowing whether it is a read or write
// rdn and wrn are asserted with SX
// the address changes with CE
// One approach is to latch CS signals with SX
// and clear them with CE
// Another approach is a combinational assign including
// rdn and wrn to validate the _cs signals
// There are three clock cycles between SX and CE
always @(posedge clk, posedge rst) begin
    if (rst) begin
        rom_cs   <= 0;
        opl_cs   <= 0;
        opn_cs   <= 0;
        oki_cs   <= 0;
        latch_cs <= 0;
        ram_cs   <= 0;
    end else begin
        latch_cs <= A[20] && A[19:16]==3 &&  A[15];
        if(SX) begin
            rom_cs   <= A[20:16]==0;
            opl_cs   <= A[20] && A[19:16]==0 &&  A[15];
            opn_cs   <= A[20] && A[19:16]==1 &&  A[15];
            oki_cs   <= A[20] && A[19:16]==3 && !A[15];
            ram_cs   <=&A[20:16]; // 1f0000-1f1fff
        end else if(ce) begin // CE will not happen is waitn is asserted
            rom_cs   <= 0;
            opl_cs   <= 0;
            opn_cs   <= 0;
            oki_cs   <= 0;
            ram_cs   <= 0;
        end
    end
end

always @(posedge clk) begin
    rom_good <= !rom_cs || rom_ok;
    din <=
        ram_cs ? ram_dout :
        opn_cs ? opn_dout :
        opl_cs ? opl_dout :
        oki_cs ? oki_dout :
        latch_cs ? latch  :
        rom_cs ? rom_data : 8'hff;
end

/* verilator tracing_off */
jtframe_ram #(.AW(13)) u_ram(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( dout      ),
    .addr   ( A[12:0]   ),
    .we     ( ram_we    ),
    .q      ( ram_dout  )
);

HUC6280 u_huc(
    .CLK        ( clk       ),
    .RST_N      ( ~rst      ),
    .WAIT_N     ( rom_good  ),
    .SX         ( SX        ),

    .A          ( A         ),
    .DI         ( din       ),
    .DO         ( dout      ),
    .WR_N       ( wrn       ),
    .RD_N       ( rdn       ),

    .RDY        ( 1'b1      ),
    .NMI_N      ( ~snreq    ),
    .IRQ1_N     ( 1'b1      ),
    .IRQ2_N     ( irqn      ),

    .CE         ( ce        ),
    .CEK_N      ( cek_n     ),
    .CE7_N      ( ce7_n     ),
    .CER_N      ( cer_n     ),
    // Unused
    .PRE_RD     (           ),
    .PRE_WR     (           ),
    .HSM        (           ),
    .O          (           ),
    .K          ( 8'd0      ),
    .VDCNUM     ( 1'b0      ),
    .AUD_LDATA  (           ),
    .AUD_RDATA  (           )
);
/* verilator tracing_on */
jtcop_ongen #(.PCM_GAIN(8'h30)) u_ongen(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen_opn    ( cen_opn       ),
    .cen_opl    ( cen_opl       ),

    .cpu_a0     ( A[0]          ),
    .cpu_rnw    ( wrn           ),
    .cpu_dout   ( dout          ),

    .opl_cs     ( opl_cs        ),
    .opl_irqn   ( opl_irqn      ),
    .opl_dout   ( opl_dout      ),

    .opn_cs     ( opn_cs        ),
    .opn_irqn   ( opn_irqn      ),
    .opn_dout   ( opn_dout      ),

    .oki_wrn    ( oki_wrn       ),
    .oki_dout   ( oki_dout      ),

    .enable_psg ( enable_psg    ),
    .enable_fm  ( enable_fm     ),
    .fxlevel    ( fxlevel       ),
    // ADPCM ROM
    .adpcm_addr ( adpcm_addr    ),
    .adpcm_cs   ( adpcm_cs      ),
    .adpcm_data ( adpcm_data    ),
    .adpcm_ok   ( adpcm_ok      ),

    .snd        ( snd           ),
    .sample     ( sample        ),
    .peak       ( peak          )
);

endmodule