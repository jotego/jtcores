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
    Date: 26-10-2024 */

module jtwc_sound(
    input            rst,
    input            clk,
    input            cen_psg,
    input            cen_psg2,
    input            cen_pcm,
    input            m2s_set,
    input      [7:0] m2s,
    output reg [7:0] s2m,
    // ROM access
    output reg       rom_cs,
    output    [13:0] rom_addr,
    input     [ 7:0] rom_data,
    input            rom_ok,
    // PCM ROM
    output reg       pcm_cs,
    output    [14:0] pcm_addr,
    input     [ 7:0] pcm_data,
    input            pcm_ok,
    // Sound output
    output    [ 9:0] psg0, psg1,
    output signed [11:0] pcm
);

wire [15:0] A, smp;
wire [11:0] snd;
wire [ 7:0] ay0_dout, ay1_dout, ram_dout, cpu_dout;
reg  [ 7:0] din;
reg  [ 3:0] pcm_din;
wire [ 3:0] addr0, addr1;
reg         ay0_cs, ay1_cs, ram_cs, pcm_set, pcm_ctl, filter, nmi_clr,
            latch_cs, rst_n, pcm_en, nbl;
wire        iorq_n, rfsh_n, mreq_n, nmi_n, int_n, vclk,
            wr_n, rd_n;

assign rom_addr = A[13:0];
assign {addr0, addr1} = 0; // Assign correctly
assign pcm_cs         = 0;
assign pcm            = 12'b0;
assign rfsh_n = 0;

always @* begin
    rom_cs   = 0;
    ram_cs   = 0;
    pcm_set  = 0;
    pcm_ctl  = 0;
    filter   = 0;
    nmi_clr  = 0;
    latch_cs = 0;
    ay0_cs   = 0;
    ay1_cs   = 0;
    if( !mreq_n && !rfsh_n ) casez(A[15:14])
        0: rom_cs   = 1;
        1: ram_cs   = 1;
        2: case(A[1:0])
            0: pcm_set = 1;
            1: pcm_ctl = 1;
            2: filter  = 1;
            3: nmi_clr = 1;
        endcase
        3: latch_cs = 1;
        default:;
    endcase
    if( ~iorq_n ) begin
        ay0_cs = ~A[1];
        ay1_cs =  A[1];
    end
end

always @* begin
    din = rom_cs   ? rom_data :
          ram_cs   ? ram_dout :
          ay0_cs   ? ay0_dout :
          ay1_cs   ? ay1_dout :
          latch_cs ? m2s      : 8'd0;
end

always @(posedge clk) begin
    rst_n <= ~rst;
    if( pcm_ok ) pcm_din <= nbl ? pcm_data[7:4] : pcm_data[3:0];
end

always @(posedge clk) begin
    if(rst) begin
        s2m      <= 0;
        pcm_addr <= 0;
        pcm_en   <= 0;
        nbl      <= 0;
    end else begin
        if( latch_cs && !wr_n ) s2m      <= cpu_dout;
        if( pcm_set  && !wr_n ) pcm_addr <= smp[14:0];
        if( pcm_ctl  && !wr_n ) {pcm_en,nbl}   <= {2{cpu_dout[0]}};
        if( pcm_en   &&  vclk ) {pcm_addr,nbl} <= {pcm_addr,nbl}+16'd1;
    end
end

jtframe_edge #(.QSET(0)) u_int(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( m2s_set   ), // should it be ~v8?
    .clr    ( nmi_clr   ),
    .q      ( nmi_n     )
);

jtframe_sysz80 #(.RAM_AW(11),.CLR_INT(1)) u_cpu(
    .rst_n      ( rst_n       ),
    .clk        ( clk         ),
    .cen        ( cen_psg     ),
    .cpu_cen    (             ),
    .int_n      ( ~m2s_set    ), // int clear logic is internal
    .nmi_n      ( nmi_n       ),
    .busrq_n    ( 1'b1        ),
    .m1_n       (             ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     (             ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .cpu_din    ( din         ),
    .cpu_dout   ( cpu_dout    ),
    .ram_dout   ( ram_dout    ),
    // ROM access
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);

jt49 u_ay0(
    .rst_n  ( rst_n     ),
    .clk    ( clk       ),
    .clk_en ( cen_psg2  ),
    .addr   ( addr0     ),
    .cs_n   ( ~ay0_cs   ),
    .wr_n   ( wr_n      ),
    .din    ( cpu_dout  ),
    .sel    ( 1'b1      ),
    .dout   ( ay0_dout  ),
    .sound  ( psg0      ),
    .sample (           ),
    // unused
    .IOA_in ( 8'h0      ),
    .IOA_out( smp[7:0]  ),
    .IOA_oe (           ),
    .IOB_in ( 8'h0      ),
    .IOB_out( smp[15:8] ),
    .IOB_oe (           ),
    .A(), .B(), .C() // unused outputs
);

jt49 u_ay1(
    .rst_n  ( rst_n     ),
    .clk    ( clk       ),
    .clk_en ( cen_psg2  ),
    .addr   ( addr1     ),
    .cs_n   ( ~ay1_cs   ),
    .wr_n   ( wr_n      ),
    .din    ( cpu_dout  ),
    .sel    ( 1'b1      ),
    .dout   ( ay1_dout  ),
    .sound  ( psg1      ),
    .sample (           ),
    // unused
    .IOA_in ( 8'h0      ),
    .IOA_out(           ),
    .IOA_oe (           ),
    .IOB_in ( 8'h0      ),
    .IOB_out(           ),
    .IOB_oe (           ),
    .A(), .B(), .C() // unused outputs
);

jt5205 #(.INTERPOL(0)) u_pcm(
    .rst    ( ~pcm_en   ),
    .clk    ( clk       ),
    .cen    ( cen_pcm   ),
    .sel    ( 2'b00     ),
    .din    ( pcm_din   ),
    .sound  ( snd       ),
    .vclk_o ( vclk      ),
    // unused
    .irq    (           ),
    .sample (           )
);

endmodule
