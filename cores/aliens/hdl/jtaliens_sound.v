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
    Date: 6-5-2023 */

module jtaliens_sound(
    input           rst,
    input           clk,
    input           cen_fm,
    input           cen_fm2,
    input   [ 1:0]  fxlevel,
    input   [ 1:0]  cfg,        // board configuration
    // communication with main CPU
    input           snd_irq,
    input   [ 7:0]  snd_latch,
    // ROM
    output  [14:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,
    // ADPCM ROM
    output   [18:0] pcma_addr,
    input    [ 7:0] pcma_dout,
    output          pcma_cs,
    input           pcma_ok,

    output   [18:0] pcmb_addr,
    input    [ 7:0] pcmb_dout,
    output          pcmb_cs,
    input           pcmb_ok,

    // Sound output
    output signed [15:0] fm_l, fm_r,
    output signed [11:0] pcm,
    // Debug
    input    [ 7:0] debug_bus,
    output   [ 7:0] st_dout
);
`ifndef NOSOUND

`include "jtaliens.inc"

wire        [ 7:0]  cpu_dout, ram_dout, fm_dout, st_pcm;
wire        [15:0]  A;
reg         [ 7:0]  cpu_din;
wire                m1_n, mreq_n, rd_n, wr_n, iorq_n, rfsh_n;
reg                 ram_cs, latch_cs, fm_cs, dac_cs, bank_cs, iock;
wire                cpu_cen;
reg                 mem_acc, mem_upper, pcm_swap;
reg         [ 3:0]  pcm_bank;
wire        [ 1:0]  ct;
reg         [ 3:0]  pcm_msb;

assign rom_addr = A[14:0];
assign st_dout  = debug_bus[4] ? st_pcm : { pcmb_cs, pcma_cs, ct, pcm_msb };

// This connection is done through the NE output
// of the 007232 on the board by using a latch
// I can simplify it here:
assign pcma_addr[18:17] = pcm_msb[1:0];
assign pcmb_addr[18:17] = pcm_msb[3:2];

always @(posedge clk) begin
    case( cfg )
        ALIENS,CRIMFGHT: begin
            pcm_msb[1:0] <= {1'b0,ct[1]};
            pcm_msb[3:2] <= {1'b0,ct[0]};
            pcm_swap     <= 0;
        end
        default: begin
            pcm_msb <= pcm_bank;
            pcm_swap     <= 1;
        end
    endcase
end

always @(*) begin
    mem_acc  = !mreq_n && rfsh_n;
    rom_cs   = mem_acc && !A[15] && !rd_n;
    // Devices
    mem_upper = mem_acc && A[15];
    // the schematics show an IOCK output which
    // isn't connected on the real PCB
    // fm_gain = 8'h18;
    case( cfg )
        ALIENS,CRIMFGHT: begin // aliens
            ram_cs    = mem_upper && A[14:13]==0; // 8/9xxx
            fm_cs     = mem_upper && A[14:13]==1; // A/Bxxx
            latch_cs  = mem_upper && A[14:13]==2; // C/Dxxx
            dac_cs    = mem_upper && A[14:13]==3; // E/Fxxx
            bank_cs   = 0;
        end
        default: begin // super contra, thunder cross
            ram_cs    = mem_upper && A[14:12]==0; // 8/9xxx
            latch_cs  = mem_upper && A[14:12]==2; // Axxx
            dac_cs    = mem_upper && A[14:12]==3; // Bxxx
            fm_cs     = mem_upper && A[14:12]==4; // Cxxx
            bank_cs   = mem_upper && A[14:12]==7; // Fxxx
        end
    endcase
    // if( cfg==SCONTRA  ) fm_gain = 8'h20;
    // if( cfg==THUNDERX ) fm_gain = 8'h10;
end

always @(*) begin
    case(1'b1)
        rom_cs:      cpu_din = rom_data;
        ram_cs:      cpu_din = ram_dout;
        latch_cs:    cpu_din = snd_latch;
        fm_cs:       cpu_din = fm_dout;
        default:     cpu_din = 8'hff;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pcm_bank <= 0;
    end else begin
        if( bank_cs ) pcm_bank <= cpu_dout[3:0];
    end
end

jtframe_sysz80 #(.RAM_AW(11),.CLR_INT(1)) u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .cpu_cen    ( cpu_cen   ),
    .int_n      ( ~snd_irq  ),
    .nmi_n      ( 1'b1      ),
    .busrq_n    ( 1'b1      ),
    .m1_n       ( m1_n      ),
    .mreq_n     ( mreq_n    ),
    .iorq_n     ( iorq_n    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .rfsh_n     ( rfsh_n    ),
    .halt_n     (           ),
    .busak_n    (           ),
    .A          ( A         ),
    .cpu_din    ( cpu_din   ),
    .cpu_dout   ( cpu_dout  ),
    .ram_dout   ( ram_dout  ),
    // ROM access
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    )
);
/* verilator tracing_off */
jt51 u_jt51(
    .rst        ( rst       ), // reset
    .clk        ( clk       ), // main clock
    .cen        ( cen_fm    ),
    .cen_p1     ( cen_fm2   ),
    .cs_n       ( !fm_cs    ), // chip select
    .wr_n       ( wr_n      ), // write
    .a0         ( A[0]      ),
    .din        ( cpu_dout  ), // data in
    .dout       ( fm_dout   ), // data out
    .ct1        ( ct[0]     ),
    .ct2        ( ct[1]     ),
    .irq_n      (           ),
    // Low resolution output (same as real chip)
    .sample     (           ),
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);
/* verilator tracing_on */

jt007232 #(.REG12A(0)) u_pcm(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .addr       ( A[3:0]    ),
    .dacs       ( dac_cs    ), // active high
    .cen_q      (           ),
    .cen_e      (           ),
    .wr_n       ( wr_n      ),
    .din        ( cpu_dout  ),
    .swap_gains ( pcm_swap  ),

    // External memory - the original chip
    // only had one bus
    .roma_addr  ( pcma_addr[16:0] ),
    .roma_dout  ( pcma_dout ),
    .roma_cs    ( pcma_cs   ),
    .roma_ok    ( pcma_ok   ),

    .romb_addr  ( pcmb_addr[16:0] ),
    .romb_dout  ( pcmb_dout ),
    .romb_cs    ( pcmb_cs   ),
    .romb_ok    ( pcmb_ok   ),
    // sound output - raw
    .snda       (           ),
    .sndb       (           ),
    .snd        ( pcm       ),
    // debug
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_pcm    )
);
`else
initial rom_cs   = 0;
assign  pcma_cs  = 0;
assign  pcmb_cs  = 0;
assign  pcma_addr= 0;
assign  pcmb_addr= 0;
assign  rom_addr = 0;
assign  snd      = 0;
assign  sample   = 0;
assign  st_dout  = 0;
`endif
endmodule
