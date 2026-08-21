/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 3-4-2022 */

module jtrastan_snd(
    input                rst,
    input                clk,
    input                fm_cen,
    input                pcm_cen,
    input                fir_cen,
    input                opwolf, rbisland,

    // From main CPU
    input                main_cen,
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

    output reg signed [15:0] left, right,
    output reg           peak,
    input         [ 7:0] debug_bus
);
reg  snd_cen_tog;
wire snd_cen = main_cen & snd_cen_tog;
always @(posedge clk, posedge rst) begin
    if( rst )
        snd_cen_tog <= 0;
    else if( main_cen )
        snd_cen_tog <= ~snd_cen_tog;
end
`ifndef NOSOUND
wire               int_n;
wire        [15:0] A;
wire        [ 7:0] dout, fm_dout, ram_dout;
wire        [ 3:0] pc6_dout;
reg                opm_cs, ram_cs, pc6_cs;
reg                pcm0_rst, pcm1_rst, pcm_stop, pcm_start, pcm_addr_cs;
reg                pcm0_reg_cs, pcm1_reg_cs, total_vol1_cs, total_vol2_cs;
wire               m1_n, iorq_n, rd_n, wr_n, mreq_n, rfsh_n, nmi_n;
wire               ct1, ct2, vclk0, vclk1, pc6_rst;
wire               va_vol_we, vb_vol_we;
reg                nibble0, nibble1, vclk0_l, vclk1_l, snd_rstn;
wire        [ 3:0] pcm0_nibble, pcm1_nibble;
wire signed [15:0] fm_l, fm_r;
wire signed [15:0] rastan_snd, opwolf_l, opwolf_r;
wire signed [11:0] pcm0, pcm1;
reg         [15:0] pcm0_start, pcm0_end, pcm1_start, pcm1_end;
reg         [ 7:0] din;
wire               main_cs, rastan_peak, opwolf_peak;
assign main_cs     = sn_rd | sn_we;
assign rom_addr    = A[14] ? { ct2, ct1, A[13:0]  } : A;
assign pcm0_nibble = !nibble0 ? pcm0_data[7:4] : pcm0_data[3:0];
assign pcm1_nibble = !nibble1 ? pcm1_data[7:4] : pcm1_data[3:0];
assign va_vol_we    = pcm0_reg_cs && !wr_n && A[2:0]==5;
assign vb_vol_we    = pcm1_reg_cs && !wr_n && A[2:0]==5;

always @(posedge clk) begin
    snd_rstn <= ~(rst | pc6_rst);
    peak <= rastan_peak | opwolf_peak;
end

always @(posedge clk) begin
    left  <= rbisland ? fm_l : opwolf ? opwolf_l : rastan_snd;
    right <= rbisland ? fm_r : opwolf ? opwolf_r : rastan_snd;
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
    rom_cs      = !A[15] && !rd_n && !mreq_n && rfsh_n ;
    ram_cs      = 0;
    opm_cs      = 0;
    pc6_cs      = 0;
    pcm_addr_cs = 0;
    pcm_start   = 0;
    pcm_stop    = 0;
    pcm0_reg_cs = 0;
    pcm1_reg_cs = 0;
    total_vol1_cs  = 0;
    total_vol2_cs  = 0;
    if( !mreq_n && rfsh_n && A[15]) begin
        case( A[14:12] )
            0: ram_cs = 1;
            1: opm_cs = 1;
            2: pc6_cs = 1;
            3: if( opwolf ) pcm0_reg_cs   = 1;
               else         pcm_addr_cs   = 1;
            4: if( opwolf ) pcm1_reg_cs   = 1;
               else         pcm_start     = 1;
            5: if( opwolf ) total_vol1_cs = 1;
               else         pcm_stop      = 1;
            6: if( opwolf ) total_vol2_cs = 1;
            default:;
        endcase
    end
end

always @(posedge clk) begin
    din <=  rom_cs ? rom_data :
            ram_cs ? ram_dout :
            opm_cs ? fm_dout  :
            pc6_cs ? { 4'hf, pc6_dout } :
            8'hff;
end

jtrastan_pc060 u_pc060(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .main_cen   ( main_cen  ),
    .snd_cen    ( snd_cen   ),
    .main_dout  ( main_dout ),
    .main_din   ( main_din  ),
    .main_addr  ( main_addr ),
    .main_rnw   ( main_rnw  ),
    .main_cs    ( main_cs   ),

    .snd_dout   ( dout[3:0] ),
    .snd_din    ( pc6_dout  ),
    .snd_addr   ( A[0]      ),
    .snd_rnw    ( wr_n      ),
    .snd_cs     ( pc6_cs    ),
    .snd_nmin   ( nmi_n     ),
    .snd_rst    ( pc6_rst   )
);

// RECOVERY cannot be set because snd_cen comes from fx68k and it
// may not have enough idle clock cycles for RECOVERY to work.
// See https://github.com/jotego/jtcores/issues/1502
jtframe_sysz80 #(.RECOVERY(0)) u_cpu(
    .rst_n      ( snd_rstn  ),
    .clk        ( clk       ),
    .cen        ( snd_cen   ),
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
/* verilator tracing_off */
jtikaopm u_opm( // IKAOPM version used for sword sound
    .rst    ( ~snd_rstn ),
    .clk    ( clk       ),
    .cen    ( fm_cen    ),
    .cs_n   ( ~opm_cs   ),
    .rd_n   ( rd_n      ),
    .wr_n   ( wr_n      ),
    .a0     ( A[0]      ),
    .din    ( dout      ),
    .dout   ( fm_dout   ),
    .ct1    ( ct1       ),
    .ct2    ( ct2       ),
    .irq_n  ( int_n     ),
    .left   ( fm_l      ),
    .right  ( fm_r      )
);

jt5205 u_pcm0( // 8kHz, 4 bits/sample
    .rst    ( pcm0_rst    ),
    .clk    ( clk         ),
    .cen    ( pcm_cen     ),
    .sel    ( 2'b10       ),
    .din    ( pcm0_nibble ),
    .sound  ( pcm0        ),
    .sample (             ),
    .irq    (             ),
    .vclk_o ( vclk0       )
);

jt5205 u_pcm1( // 8kHz, 4 bits/sample
    .rst    ( pcm1_rst    ),
    .clk    ( clk         ),
    .cen    ( pcm_cen     ),
    .sel    ( 2'b10       ),
    .din    ( pcm1_nibble ),
    .sound  ( pcm1        ),
    .sample (             ),
    .irq    (             ),
    .vclk_o ( vclk1       )
);

jtrastan_mix u_rastan_mix(
    .rst    ( rst         ),
    .clk    ( clk         ),
    .sample ( fir_cen     ),
    .fm_l   ( fm_l        ),
    .fm_r   ( fm_r        ),
    .pcm    ( pcm0        ),
    .snd    ( rastan_snd  ),
    .peak   ( rastan_peak )
);

jtopwolf_mix u_opwolf_mix(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .sample      ( fir_cen       ),
    .va_vol_we   ( va_vol_we     ),
    .vb_vol_we   ( vb_vol_we     ),
    .spk1_vol_we ( total_vol1_cs ),
    .spk2_vol_we ( total_vol2_cs ),
    .din         ( dout          ),
    .fm_l        ( debug_bus[0] ? 16'd0 : fm_l          ),
    .fm_r        ( debug_bus[0] ? 16'd0 : fm_r          ),
    // .fm_l        ( 16'd0         ),
    // .fm_r        ( 16'd0         ),
    .va          ( pcm0          ),
    .vb          ( pcm1          ),
    .snd_l       ( opwolf_l      ),
    .snd_r       ( opwolf_r      ),
    .peak        ( opwolf_peak   )
);
`else
assign main_din=0, rom_addr=0;
initial begin
    rom_cs=0;
    pcm0_addr=0;
    pcm1_addr=0;
    pcm0_cs=0;
    pcm1_cs=0;
    peak=0;
    left=0; right=0;
end
`endif
endmodule
