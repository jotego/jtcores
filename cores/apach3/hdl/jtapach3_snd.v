/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */

module jtapach3_snd(
    input             rst,
    input             clk,
    input             cen,
    input             ym_cen,
    input             oki_cen,
    input      [15:0] control,
    input      [ 7:0] in0,
    input      [ 7:0] stick_x,
    input      [ 7:0] stick_y,
    input      [ 7:0] throttle,
    input      [14:0] host_addr,
    input             host_sel,
    input             host_rd,
    input             host_wr,
    input      [ 7:0] host_din,
    output reg [ 7:0] host_dout,
    output            host_ok,
    output signed [15:0] fm_l,
    output signed [15:0] fm_r,
    output signed [13:0] pcm,
    output     [15:0] sound_rom_addr,
    output            sound_rom_cs,
    input      [ 7:0] sound_rom_data,
    input             sound_rom_ok,
    output     [15:0] v30_sound_rom_addr,
    output            v30_sound_rom_cs,
    input      [ 7:0] v30_sound_rom_data,
    input             v30_sound_rom_ok,
    output reg [17:0] oki_addr,
    output reg        oki_cs,
    input      [ 7:0] oki_data,
    input             oki_ok,
    output     [12:0] soundram_addr,
    output     [ 7:0] soundram_din,
    input      [ 7:0] soundram_dout,
    output            soundram_we,
    output     [12:0] v30_soundram_addr,
    output     [ 7:0] v30_soundram_din,
    input      [ 7:0] v30_soundram_dout,
    output            v30_soundram_we
);

wire halt = control[7];
wire cpu_cen = cen && !halt;
reg [2:0] half_delay;
wire [19:0] cpu_addr;
wire [7:0] cpu_dout;
reg  [7:0] cpu_din;
wire [2:0] cpu_bs;
wire cpu_req, cpu_rd_n, cpu_wr_n;
wire mem_cycle = cpu_req && (cpu_bs == 3'd4 || cpu_bs == 3'd5 || cpu_bs == 3'd6);
wire host_rom = host_sel && control[7:6] == 2'b11;
wire host_mem = host_sel && (host_wr || !host_rom);
wire host_active = host_mem && (host_rd || host_wr);
wire [15:0] io_addr = host_mem ? {1'b0,host_addr} : cpu_addr[15:0];
wire [7:0] io_din = host_mem ? host_din : cpu_dout;
wire io_rd = host_mem ? host_rd : mem_cycle && !cpu_rd_n && !halt;
wire io_wr = host_mem ? host_wr : mem_cycle && !cpu_wr_n && !halt;
wire cpu_ram = mem_cycle && !halt && cpu_addr[19:13] == 0;
wire host_ram = host_mem && host_addr[14:13] == 0;
wire cpu_io = mem_cycle && !halt && cpu_addr[19:16] == 0 && cpu_addr[15:13] != 0;
wire io_access = host_mem ? host_active : cpu_io;
wire ppi_cs = io_access && io_addr[15:2] == 14'h1000;
wire in_cs  = io_access && io_addr[15:1] == 15'h3000;
wire fm_cs  = io_access && io_addr[15:1] == 15'h4000;
wire pcm_cs = io_access && io_addr == 16'ha000;
wire adc_cs = io_access && io_addr[15:3] == 13'h1c00;
wire [7:0] fm_dout, pcm_dout, ppi_dout;
wire [17:0] pcm_rom_addr;
reg [7:0] pcm_rom_data;
reg pcm_rom_valid;
wire pcm_rom_ok = pcm_rom_valid && oki_addr == pcm_rom_addr;
wire fm_irq_n;
reg fm_half;
reg [7:0] adc_data;
reg fm_seen;
reg adc_seen;
wire io_ready = !fm_cs || !io_wr || fm_seen;
wire cpu_ready = sound_rom_cs ? sound_rom_ok : io_ready;

assign sound_rom_addr     = cpu_addr[15:0];
assign sound_rom_cs       = mem_cycle && !halt && !cpu_rd_n && cpu_addr[19:16] == 4'hf;
assign v30_sound_rom_addr = {control[5],host_addr};
assign v30_sound_rom_cs   = host_rom && host_rd;
assign host_ok            = v30_sound_rom_cs ? v30_sound_rom_ok : host_mem ? io_ready : 1'b1;
assign soundram_addr      = cpu_addr[12:0];
assign soundram_din       = cpu_dout;
assign soundram_we        = !rst && cpu_ram && !cpu_wr_n && cpu_cen;
assign v30_soundram_addr  = host_addr[12:0];
assign v30_soundram_din   = host_din;
assign v30_soundram_we    = !rst && host_ram && host_wr && host_ok;

always @* begin
    cpu_din = 8'hff;
    if (sound_rom_cs) cpu_din = sound_rom_data;
    else if (cpu_ram) cpu_din = soundram_dout;
    else if (cpu_io) begin
        if (ppi_cs)      cpu_din = ppi_dout;
        else if (in_cs)  cpu_din = in0;
        else if (fm_cs)  cpu_din = fm_dout;
        else if (pcm_cs) cpu_din = pcm_dout;
        else if (adc_cs) cpu_din = adc_data;
    end
    host_dout = 8'hff;
    if (v30_sound_rom_cs) host_dout = v30_sound_rom_data;
    else if (host_ram)    host_dout = v30_soundram_dout;
    else if (host_mem) begin
        if (ppi_cs)      host_dout = ppi_dout;
        else if (in_cs)  host_dout = in0;
        else if (fm_cs)  host_dout = fm_dout;
        else if (pcm_cs) host_dout = pcm_dout;
        else if (adc_cs) host_dout = adc_data;
    end
end

always @(posedge clk) begin
    half_delay <= {half_delay[1:0],cpu_cen};
    if (rst) begin
        fm_half <= 0;
        fm_seen <= 0;
        oki_addr <= 0;
        oki_cs <= 0;
        pcm_rom_data <= 0;
        pcm_rom_valid <= 0;
        adc_data <= 8'hff;
        adc_seen <= 0;
    end else begin
        if (ym_cen) fm_half <= ~fm_half;
        if (oki_cs) begin
            if (oki_ok) begin
                pcm_rom_data <= oki_data;
                pcm_rom_valid <= 1;
                oki_cs <= 0;
            end
        end else if (!pcm_rom_ok) begin
            oki_addr <= pcm_rom_addr;
            oki_cs <= 1;
            pcm_rom_valid <= 0;
        end
        if (!fm_cs || !io_wr) fm_seen <= 0;
        else if (ym_cen && fm_half) fm_seen <= 1;
        if (!adc_cs || !io_wr) adc_seen <= 0;
        else if (!adc_seen) begin
            adc_seen <= 1;
            case (io_addr[2:0])
                0: adc_data <= stick_x;
                1: adc_data <= stick_y;
                2: adc_data <= 0;
                4: adc_data <= 0;
                5: adc_data <= throttle;
                6: adc_data <= 0;
                7: adc_data <= 0;
                default: adc_data <= 8'hff;
            endcase
        end
    end
end

jtframe_v20 u_cpu (
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .cen       ( cpu_cen                ),
    .cenb      ( half_delay[2]          ),
    .ready     ( cpu_ready              ),
    .int_n     ( fm_irq_n               ),
    .nmi_n     ( 1'b1                   ),
    .poll_n    ( 1'b1                   ),
    .A         ( cpu_addr               ),
    .din       ( cpu_din                ),
    .dout      ( cpu_dout               ),
    .bs        ( cpu_bs                 ),
    .qs        (                        ),
    .req       ( cpu_req                ),
    .rd_n      ( cpu_rd_n               ),
    .wr_n      ( cpu_wr_n               ),
    .buslock_n (                        )
);

jt8255 u_ppi (
    .rst        ( rst          ),
    .clk        ( clk          ),
    .addr       ( io_addr[1:0] ),
    .din        ( io_din       ),
    .dout       ( ppi_dout     ),
    .rdn        ( ~io_rd       ),
    .wrn        ( ~io_wr       ),
    .csn        ( ~ppi_cs      ),
    .porta_din  ( 8'hff        ),
    .portb_din  ( 8'hff        ),
    .portc_din  ( 8'hff        ),
    .porta_dout (              ),
    .portb_dout (              ),
    .portc_dout (              )
);

jt51 u_fm (
    .rst    ( rst               ),
    .clk    ( clk               ),
    .cen    ( ym_cen            ),
    .cen_p1 ( ym_cen && fm_half ),
    .cs_n   ( ~fm_cs            ),
    .wr_n   ( ~io_wr            ),
    .a0     ( io_addr[0]        ),
    .din    ( io_din            ),
    .dout   ( fm_dout           ),
    .ct1    (                   ),
    .ct2    (                   ),
    .irq_n  ( fm_irq_n          ),
    .sample (                   ),
    .left   (                   ),
    .right  (                   ),
    .xleft  ( fm_l              ),
    .xright ( fm_r              )
);

jt6295 u_pcm (
    .rst      ( rst                ),
    .clk      ( clk                ),
    .cen      ( oki_cen            ),
    .ss       ( 1'b1               ),
    .wrn      ( !(pcm_cs && io_wr) ),
    .din      ( io_din             ),
    .dout     ( pcm_dout           ),
    .rom_addr ( pcm_rom_addr       ),
    .rom_data ( pcm_rom_data       ),
    .rom_ok   ( pcm_rom_ok         ),
    .sound    ( pcm                ),
    .sample   (                    )
);

endmodule
