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
    Date: 3-4-2022 */

module jtrastan_snd(
    input                rst,
    input                clk,  // 24 MHz
    input                cen4, // generated in mem.yaml
    input                cen2,
    input                pcm_cen,
    input                opwolf,

    // From main CPU
    input                rst48,
    input                clk48,
    input                main_addr,
    input         [ 3:0] main_dout,
    output        [ 3:0] main_din,
    input                main_rnw,
    input                sn_rd,
    input                sn_we,

    output        [15:0] rom_addr,
    output reg           rom_cs,
    input                rom_ok,
    input         [ 7:0] rom_data,

    output reg    [18:0] pcm0_addr,
    output reg           pcm0_cs,
    input                pcm0_ok,
    input         [ 7:0] pcm0_data,
    output reg    [18:0] pcm1_addr,
    output reg           pcm1_cs,
    input                pcm1_ok,
    input         [ 7:0] pcm1_data,

    output signed [15:0] fm_l, fm_r,
    output signed [11:0] pcm0, pcm1
);
`ifndef NOSOUND
wire               int_n;
wire        [15:0] A;
wire        [ 7:0] dout, opm_dout, ram_dout;
wire        [ 3:0] pc6_dout;
reg                opm_cs, ram_cs, pc6_cs;
reg                pcm0_rst, pcm1_rst, pcm_stop, pcm_start, pcm_addr_cs;
reg                pcm0_reg_cs, pcm1_reg_cs;
wire               m1_n, iorq_n, rd_n, wr_n, mreq_n, rfsh_n, nmi_n;
wire               ct1, ct2, vclk0, vclk1, pc6_rst;
reg                nibble0, nibble1, vclk0_l, vclk1_l, snd_rstn;
wire        [ 3:0] pcm0_nibble, pcm1_nibble;
wire signed [11:0] pcm0_raw, pcm1_raw;
wire signed [20:0] pcm0_scaled, pcm1_scaled;
wire signed [11:0] pcm0_atten, pcm1_atten;
reg  signed [11:0] pcm0_q,     pcm1_q;
reg         [15:0] pcm0_start, pcm0_end, pcm1_start, pcm1_end;
reg         [ 7:0] pcm0_vol, pcm1_vol;
reg         [ 7:0] din;
wire               main_cs;
assign main_cs    = sn_rd | sn_we;
assign rom_addr   = A[14] ? { ct2, ct1, A[13:0]  } : A;
assign pcm0_nibble = !nibble0 ? pcm0_data[7:4] : pcm0_data[3:0];
assign pcm1_nibble = !nibble1 ? pcm1_data[7:4] : pcm1_data[3:0];
assign pcm0_scaled = pcm0_raw * $signed({1'b0,pcm0_vol});
assign pcm1_scaled = pcm1_raw * $signed({1'b0,pcm1_vol});
assign pcm0_atten = pcm0_scaled[19:8];
assign pcm1_atten = pcm1_scaled[19:8];
assign pcm0 = pcm0_q;
assign pcm1 = pcm1_q;

// Register the volume-scaled PCM before the RC mixer to break a long combiational path
// that miss the timings on pocket at 53Mhz
always @(posedge clk) begin
    pcm0_q   <= opwolf ? pcm0_atten : pcm0_raw;
    pcm1_q   <= pcm1_atten;
    snd_rstn <= ~(rst | pc6_rst);
end

// Rastan has one simple ADPCM address latch. Operation Wolf has two
// independent start/end controllers with 16-byte address granularity.
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pcm0_addr  <= 0;
        pcm1_addr  <= 0;
        pcm0_start <= 0;
        pcm0_end   <= 0;
        pcm1_start <= 0;
        pcm1_end   <= 0;
        pcm0_vol   <= 0;
        pcm1_vol   <= 0;
        pcm0_cs    <= 0;
        pcm1_cs    <= 0;
        nibble0    <= 0;
        nibble1    <= 0;
        pcm0_rst   <= 1;
        pcm1_rst   <= 1;
    end else begin
        vclk0_l <= vclk0;
        vclk1_l <= vclk1;
        if( pcm_addr_cs ) pcm0_addr[15:8] <= dout;
        if( pcm_start ) begin
            pcm0_cs         <= 1;
            pcm0_rst        <= 0;
            pcm0_addr[ 7:0] <= 0;
            nibble0         <= 0;
        end
        if( pcm_stop ) begin
            pcm0_cs  <= 0;
            pcm0_rst <= 1;
        end
        if( pcm0_reg_cs && !wr_n ) begin
            case( A[2:0] )
                0: pcm0_start[ 7:0] <= dout;
                1: pcm0_start[15:8] <= dout;
                2: pcm0_end[ 7:0]   <= dout;
                3: pcm0_end[15:8]   <= dout;
                4: begin
                    pcm0_addr <= {pcm0_start[14:0],4'd0};
                    pcm0_cs   <= 1;
                    pcm0_rst  <= 0;
                    nibble0   <= 0;
                end
                5: pcm0_vol <= dout;
                default:;
            endcase
        end
        if( pcm1_reg_cs && !wr_n ) begin
            case( A[2:0] )
                0: pcm1_start[ 7:0] <= dout;
                1: pcm1_start[15:8] <= dout;
                2: pcm1_end[ 7:0]   <= dout;
                3: pcm1_end[15:8]   <= dout;
                4: begin
                    pcm1_addr <= {pcm1_start[14:0],4'd0};
                    pcm1_cs   <= 1;
                    pcm1_rst  <= 0;
                    nibble1   <= 0;
                end
                5: pcm1_vol <= dout;
                default:;
            endcase
        end
        if( vclk0 && !vclk0_l && !pcm0_rst && pcm0_ok ) begin
            if( opwolf && nibble0 && pcm0_addr + 1'd1 == {pcm0_end[14:0],4'd0} ) begin
                pcm0_cs  <= 0;
                pcm0_rst <= 1;
            end else begin
                {pcm0_addr,nibble0} <= {pcm0_addr,nibble0} + 1'd1;
            end
        end
        if( vclk1 && !vclk1_l && !pcm1_rst && pcm1_ok ) begin
            if( nibble1 && pcm1_addr + 1'd1 == {pcm1_end[14:0],4'd0} ) begin
                pcm1_cs  <= 0;
                pcm1_rst <= 1;
            end else begin
                {pcm1_addr,nibble1} <= {pcm1_addr,nibble1} + 1'd1;
            end
        end
    end
end

always @* begin
    rom_cs      = !A[15] && !rd_n;
    ram_cs      = 0;
    opm_cs      = 0;
    pc6_cs      = 0;
    pcm_addr_cs = 0;
    pcm_start   = 0;
    pcm_stop    = 0;
    pcm0_reg_cs = 0;
    pcm1_reg_cs = 0;
    if( !mreq_n && rfsh_n && A[15]) begin
        case( A[14:12] )
            0: ram_cs = 1;
            1: opm_cs = 1;
            2: pc6_cs = 1;
            3: if( opwolf ) pcm0_reg_cs = A[11:3]==0;
               else         pcm_addr_cs = 1;
            4: if( opwolf ) pcm1_reg_cs = A[11:3]==0;
               else         pcm_start   = 1;
            5: if( !opwolf ) pcm_stop = 1;
            default:;
        endcase
    end
end

always @(posedge clk) begin
    din <=  rom_cs ? rom_data :
            ram_cs ? ram_dout :
            opm_cs ? opm_dout :
            pc6_cs ? { 4'hf, pc6_dout } :
            8'hff;
end

jtrastan_pc060 u_pc060(
    .rst48      ( rst48     ),
    .clk48      ( clk48     ),
    .main_dout  ( main_dout ),
    .main_din   ( main_din  ),
    .main_addr  ( main_addr ),
    .main_rnw   ( main_rnw  ),
    .main_cs    ( main_cs   ),

    .rst24      ( rst       ),
    .clk24      ( clk       ),
    .snd_dout   ( dout[3:0] ),
    .snd_din    ( pc6_dout  ),
    .snd_addr   ( A[0]      ),
    .snd_rnw    ( wr_n      ),
    .snd_cs     ( pc6_cs    ),
    .snd_nmin   ( nmi_n     ),
    .snd_rst    ( pc6_rst   )
);

jtframe_sysz80 #(.RECOVERY(0)) u_cpu(
    .rst_n      ( snd_rstn  ),
    .clk        ( clk       ),
    .cen        ( cen4      ),
    .cpu_cen    (           ),
    .int_n      ( int_n     ),
    .nmi_n      ( nmi_n     ),
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
    .cpu_din    ( din       ),
    .cpu_dout   ( dout      ),
    .ram_dout   ( ram_dout  ),
    // ROM access
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    )
);
/*
jtopl u_opl(
    .rst    ( rst       ),        // rst should be at least 6 clk&cen cycles long
    .clk    ( clk       ),        // CPU clock
    .cen    ( cen       ),        // optional clock enable, it not needed leave as 1'b1
    .din    ( din       ),
    .addr   ( A[0]      ),
    .cs_n   ( cs_n      ),
    .wr_n   ( wr_n      ),
    .dout   ( opl_dout  ),
    .irq_n  ( irqn_opl  ),
    // combined output
    .snd    ( snd_opl   ),
    .sample ( spl_opl   )
);
*/
jt51 u_jt51(
    .rst    ( ~snd_rstn ),
    .clk    ( clk       ),
    .cen    ( cen4      ),
    .cen_p1 ( cen2      ),
    .cs_n   ( ~opm_cs   ),
    .wr_n   ( wr_n      ),
    .a0     ( A[0]       ),
    .din    ( dout      ),
    .dout   ( opm_dout  ),
    // peripheral control
    .ct1    ( ct1       ),
    .ct2    ( ct2       ),
    .irq_n  ( int_n     ),
    // Low resolution output (same as real chip)
    .sample (           ),
    .left   (           ),
    .right  (           ),
    // Full resolution output
    .xleft  ( fm_l      ),
    .xright ( fm_r      )
);

jt5205 u_pcm0( // 8kHz, 4 bits/sample
    .rst    ( pcm0_rst   ),
    .clk    ( clk       ),
    .cen    ( pcm_cen   ),
    .sel    ( 2'b10     ),
    .din    ( pcm0_nibble),
    .sound  ( pcm0_raw  ),
    .sample (           ),
    .irq    (           ),
    .vclk_o ( vclk0     )
);

jt5205 u_pcm1( // 8kHz, 4 bits/sample
    .rst    ( pcm1_rst   ),
    .clk    ( clk        ),
    .cen    ( pcm_cen    ),
    .sel    ( 2'b10      ),
    .din    ( pcm1_nibble),
    .sound  ( pcm1_raw   ),
    .sample (            ),
    .irq    (            ),
    .vclk_o ( vclk1      )
);
`else
assign main_din=0, rom_addr=0, fm_l=0, fm_r=0, pcm0=0, pcm1=0;
initial begin
    rom_cs=0;
    pcm0_addr=0;
    pcm1_addr=0;
    pcm0_cs=0;
    pcm1_cs=0;
end
`endif
endmodule
