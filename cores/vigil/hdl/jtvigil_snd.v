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
    Date: 1-5-2022 */

module jtvigil_snd(
    input                clk,
    input                rst,
    input                cpu_cen,
    input                fm_cen,
    input                v1,

    // From main
    input         [ 7:0] main_dout,
    input                latch_wr,

    // ROM access
    output    reg        rom_cs,
    output        [15:0] rom_addr,
    input         [ 7:0] rom_data,
    input                rom_ok,

    output               pcm_cs,
    output    reg [15:0] pcm_addr,
    input         [ 7:0] pcm_data,
    input                pcm_ok,

    input         [ 7:0] debug_bus,
    output signed [15:0] fm_l, fm_r,
    output signed [ 7:0] pcm
);

`ifndef NOSOUND

wire [15:0] A;
wire [ 7:0] ram_dout, fm_dout, cpu_dout, int_addr;
reg  [ 7:0] cpu_din, latch;
reg  [ 2:0] bank;
reg         rst_n, ram_cs,  cntcs_l,
            fm_cs, latch_cs, irq_clr,
            hi_cs, lo_cs, cnt_cs, pcm_rd;
wire        rd_n, wr_n, mreq_n, iorq_n;
reg         main_intn;
wire        fm_intn, int_cs, m1_n;

wire signed [15:0] left, right;

assign pcm_cs   = 1;
assign rom_addr = A;
assign int_cs   = ~m1_n & ~iorq_n;
assign int_addr = { 2'b11, main_intn, fm_intn, 4'hf };

always @(posedge clk) rst_n <= ~rst;

always @* begin
    // Memory mapped
    rom_cs  = !mreq_n && A[15:12]!=4'hf;
    ram_cs  = !mreq_n && A[15:12]==4'hf;
    // IO mapped R/W
    fm_cs   = !iorq_n && !A[7];
    // IO mapped reads
    latch_cs= !iorq_n && !rd_n &&  A[7] && !A[2];
    pcm_rd  = !iorq_n && !rd_n &&  A[7] &&  A[2]; // labeled ~SROMC
    // IO mapped writes
    lo_cs   = !iorq_n && !wr_n &&  A[7] && A[2:0]==0;
    hi_cs   = !iorq_n && !wr_n &&  A[7] && A[2:0]==1;
    cnt_cs  = !iorq_n && !wr_n &&  A[7] && A[2:0]==2;
    irq_clr = !iorq_n && !wr_n &&  A[7] && A[2:0]==3;
end

// latch from main CPU
wire int_n = main_intn & fm_intn;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        latch <= 0;
        main_intn <= 1;
    end else begin
        if( latch_wr ) begin
            latch     <= main_dout;
            main_intn <= 0;
        end
        if( irq_clr ) main_intn <= 1;
    end
end

// PCM controller

reg  [7:0] pcm_good;
reg  [1:0] pcm_rdy;
reg        pcm_sample;

assign pcm = 8'h80 - pcm_good;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pcm_addr   <= 16'd0;
        cntcs_l    <= 0;
        pcm_good   <= 0;
        pcm_sample <= 0;
    end else begin
        cntcs_l    <= cnt_cs;
        pcm_rdy    <= { pcm_rdy[0], pcm_ok };
        pcm_sample <= 0;
        if( pcm_rdy==2'b01 && pcm_ok ) begin
            pcm_good   <= pcm_data;
            pcm_sample <= 1;
        end
        if( hi_cs ) pcm_addr[15:8] <= cpu_dout;
        if( lo_cs ) pcm_addr[ 7:0] <= cpu_dout;
        if( cnt_cs && !cntcs_l ) begin
            pcm_addr <= pcm_addr + 16'd1;
            pcm_rdy  <= 0;
        end
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cpu_din <= 0;
    end else begin
        cpu_din <=
            rom_cs   ? rom_data :
            ram_cs   ? ram_dout :
            pcm_rd   ? pcm_data :
            latch_cs ? latch    :
            int_cs   ? int_addr :
            fm_cs    ? fm_dout  : 8'hff;
    end
end

jtframe_sysz80 #(
    .RAM_AW     ( 12        )
) u_cpu(
    .rst_n      ( rst_n     ),
    .clk        ( clk       ),
    .cen        ( cpu_cen   ),
    .cpu_cen    (           ),
    .int_n      ( int_n     ),
    .nmi_n      ( ~v1       ),
    //.nmi_n      ( 1'b1      ),
    .busrq_n    ( 1'b1      ),
    .m1_n       ( m1_n      ),
    .mreq_n     ( mreq_n    ),
    .iorq_n     ( iorq_n    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .rfsh_n     (           ),
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

jt51 u_jt51 (
    .rst     ( rst        ),
    .clk     ( clk        ),
    .cen     ( cpu_cen    ),
    .cen_p1  ( fm_cen     ),
    .cs_n    ( !fm_cs     ),
    .wr_n    ( wr_n       ),
    .a0      ( A[0]       ),
    .din     ( cpu_dout   ),
    .dout    ( fm_dout    ),
    .ct1     (            ),
    .ct2     (            ),
    .irq_n   ( fm_intn    ),
    .sample  (            ),
    .left    (            ),
    .right   (            ),
    .xleft   ( fm_l       ),
    .xright  ( fm_r       )
);
`else
    initial rom_cs   = 0;
    assign  pcm_cs   = 0;
    assign  fm_l     = 0;
    assign  fm_r     = 0;
    assign  pcm      = 0;
    initial pcm_addr = 0;
    assign  rom_addr = 0;
`endif
endmodule