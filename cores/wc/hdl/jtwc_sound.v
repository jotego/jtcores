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
    input            rst_n,
    input            clk,
    input            cen_psg,
    input            cen_psg2,
    input            cen_pcm,
    input            vbl,
    input            m2s_set,
    input      [7:0] m2s,
    output reg [7:0] s2m,
    // ROM access
    output reg       rom_cs,
    output    [13:0] rom_addr,
    input     [ 7:0] rom_data,
    input            rom_ok,
    // PCM ROM
    output           pcm_cs,
    output reg[14:0] pcm_addr,
    input     [ 7:0] pcm_data,
    input            pcm_ok,
    // Sound output
    output    [ 9:0] psg0, psg1,
    output    [11:0] pcm,
    input     [ 7:0] debug_bus,
    output    [ 7:0] st_dout
);
`ifndef NOMAIN // do not use NOSOUND here
wire [15:0] A, smp;
wire [ 7:0] ay0_dout, ay1_dout, ram_dout, cpu_dout;
reg  [ 7:0] din;
reg  [ 3:0] pcm_din, gain;
reg         ay0_cs, ay1_cs, ram_cs, pcm_set, pcm_ctl, gain_cs, nmi_clr,
            latch_cs, pcm_en, nbl;
wire        iorq_n, rfsh_n, mreq_n, nmi_n, vclk,
            wr_n, rd_n, bdir0, bdir1, bc10, bc11;
wire signed [11:0] pcm_raw;

assign rom_addr = A[13:0];
assign pcm_cs   = 1;
assign rfsh_n   = 0;
assign st_dout  = { pcm_en, 3'd0, gain };

// AY0
function [1:0] cpu2ay(input cs);
begin
    cpu2ay = !cs   ? 2'b00 :
             !wr_n ? (A[0] ? 2'b11 : 2'b10) : // A[0] low = data / high = address
                     2'b01; // read
end
endfunction

assign {bdir0,bc10} = cpu2ay(ay0_cs);
assign {bdir1,bc11} = cpu2ay(ay1_cs);

always @* begin
    rom_cs   = 0;
    ram_cs   = 0;
    pcm_set  = 0;
    pcm_ctl  = 0;
    gain_cs  = 0;
    nmi_clr  = 0;
    latch_cs = 0;
    ay0_cs   = 0;
    ay1_cs   = 0;
    if( !mreq_n && !rfsh_n ) casez(A[15:14])
        0: rom_cs   = 1;
        1: ram_cs   = 1;
        2: if(!wr_n) case(A[1:0])
            0: pcm_set = 1;
            1: pcm_ctl = 1;
            2: gain_cs = 1;
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
    if( pcm_ok ) pcm_din <= nbl ? pcm_data[3:0] : pcm_data[7:4];
    if( gain_cs) gain    <= cpu_dout[3:0];
    if( debug_bus[7] ) gain <= debug_bus[3:0];
end

always @(posedge clk) begin
    if(!rst_n) begin
        s2m      <= 0;
        pcm_addr <= 0;
        pcm_en   <= 0;
        nbl      <= 0;
    end else begin
        if( latch_cs && !wr_n ) s2m      <= cpu_dout;
        if( pcm_set  && !wr_n ) pcm_addr <= smp[14:0];
        if( pcm_ctl  && !wr_n ) pcm_en   <= cpu_dout[0];
        if( pcm_en   &&  vclk ) {pcm_addr,nbl} <= {pcm_addr,nbl}+16'd1;
        if( !pcm_en ) nbl <= 0;
    end
end

jtframe_edge #(.QSET(0)) u_int(
    .rst    ( !rst_n    ),
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
    .int_n      ( vbl         ), // int clear logic is internal
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

jt49_bus u_ay0(
    .rst_n  ( rst_n     ),
    .clk    ( clk       ),
    .clk_en ( cen_psg2  ),
    .bdir   ( bdir0     ),
    .bc1    ( bc10      ),
    .din    ( cpu_dout  ),
    .sel    ( 1'b1      ),
    .dout   ( ay0_dout  ),
    .sound  ( psg0      ),
    .sample (           ),
    // unuseday1_cs
    .IOA_in ( 8'h0      ),
    .IOA_out( smp[7:0]  ),
    .IOA_oe (           ),
    .IOB_in ( 8'h0      ),
    .IOB_out( smp[15:8] ),
    .IOB_oe (           ),
    .A(), .B(), .C() // unused outputs
);

jt49_bus u_ay1(
    .rst_n  ( rst_n     ),
    .clk    ( clk       ),
    .clk_en ( cen_psg2  ),
    .bdir   ( bdir1     ),
    .bc1    ( bc11      ),
    .din    ( cpu_dout  ),
    .sel    ( 1'b1      ),
    .dout   ( ay1_dout  ),
    .sound  ( psg1      ),
    .IOA_in ({pcm_addr[7:1],1'b1}),
    .IOB_in ({1'b1,pcm_addr[14:8]}), // bit 14 has a pullup in all sets but teeoff
    // unused
    .sample (           ),
    .IOA_out(           ),
    .IOA_oe (           ),
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
    .sound  ( pcm_raw   ),
    .vclk_o ( vclk      ),
    // unused
    .irq    (           ),
    .sample (           )
);

jtwc_gain u_gain(
    .clk    ( clk       ),
    .ctl    ( gain      ),
    .raw    ( pcm_raw   ),
    .amp    ( pcm       )
);

`else
initial begin
    s2m      = 0;
    rom_cs   = 0;
    pcm_addr = 0;
end
assign {rom_addr, pcm_cs, psg0, psg1, pcm} = 0;
`endif
endmodule