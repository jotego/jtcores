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

module jtwc_main(
    input            rst,
    input            clk,
    input            cen,
    input            ws,
    input            LVBL,       // video interrupt
    // shared memory
    output reg       mmx_c8,
    output reg       mmx_d0,
    output reg       mmx_d8,
    output reg       mmx_e0,
    output reg       mmx_e8,
    output    [ 7:0] cpu_dout,
    output           wr_n,
    input     [ 7:0] sh_dout,
    // control
    output reg       hflip,
    output reg       vflip,
    output reg       mute_n,
    output reg       srst_n,
    // sound
    output reg       m2s_set,
    output reg [7:0] m2s,
    input      [7:0] s2m,
    // ROM access
    output reg       rom_cs,
    output    [15:0] rom_addr,
    input     [ 7:0] rom_data,
    input            rom_ok,
    //
    input     [19:0] dipsw
);

wire [15:0] A;
wire [ 7:0] ram_dout, din;
reg  [ 7:0] dip_mux;
reg         ram_cs, dip_cs, dip1_cs, dip2_cs, dip3_cs, latch_cs,
            sh_cs, s2m_cs, rst_n, mmx_f8;
wire        rd_n, iorq_n, rfsh_n, mreq_n, cen_eff;

assign rom_addr = A;
assign cen_eff  = ~ws & cen;

always @(posedge clk) begin
    rst_n <= ~rst;
end

always @(posedge clk) begin
    dip_mux = dip1_cs ? {4'hf,dipsw[3:0]} :
              dip2_cs ? dipsw[ 4+:8]      :
              dip3_cs ? dipsw[12+:8]      : 8'hff;
end

always @(posedge clk) begin
    if( rst ) begin
        srst_n  <= 0;
        mute_n  <= 0;
        hflip   <= 0;
        vflip   <= 0;
        m2s_set <= 0;
    end else begin
        m2s_set <= 0;
        if( mmx_f8 && !wr_n ) case(A[6:4])
            2: begin
                m2s_set <= 1;
                m2s   <= cpu_dout;
            end
            4: srst_n <= cpu_dout[0];
            5: mute_n <= cpu_dout[0];
            6: hflip  <= cpu_dout[0];
            7: vflip  <= cpu_dout[0];
        endcase
    end
end

always @* begin
    rom_cs  = 0;
    ram_cs  = 0;
    mmx_c8  = 0;
    mmx_d0  = 0;
    mmx_d8  = 0;
    mmx_e0  = 0;
    mmx_e8  = 0;
    mmx_f8  = 0;
    dip3_cs = 0;
    dip2_cs = 0;
    dip1_cs = 0;
    dip_cs  = 0;
    sh_cs   = 0;
    s2m_cs  = 0;
    if( !mreq_n && !rfsh_n ) casez(A[15:14])
        0,1,2: rom_cs   = 1;
        3: case(A[13:11])
            0: ram_cs = 1;
            1: {sh_cs,mmx_c8} = 2'b11;
            2: {sh_cs,mmx_d0} = 2'b11;
            3: {sh_cs,mmx_d8} = 2'b11;
            4: {sh_cs,mmx_e0} = 2'b11;
            5: {sh_cs,mmx_e8} = 2'b11;
            6: begin
                mmx_f8 = 1;
                if( !rd_n ) case(A[6:4])
                    2: s2m_cs  = 1;
                    4: {dip_cs,dip3_cs} = 2'b11;
                    5: {dip_cs,dip2_cs} = 2'b11;
                    // 6: wdog = 1;
                    7: {dip_cs,dip1_cs} = 2'b11;
                    default:;
                endcase
            end
        endcase
    endcase
end

assign din = rom_cs ? rom_data :
             ram_cs ? ram_dout :
             sh_cs  ? sh_dout  :
             dip_cs ? dip_mux  :
             s2m_cs ? s2m      : 8'hff;

jtframe_sysz80 #(.RAM_AW(11),.CLR_INT(1)) u_cpu(
    .rst_n      ( rst_n       ),
    .clk        ( clk         ),
    .cen        ( cen_eff     ),
    .cpu_cen    (             ),
    .int_n      ( LVBL        ), // int clear logic is internal
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( 1'b1        ),
    .m1_n       (             ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
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

endmodule