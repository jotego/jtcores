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
    Date: 23-8-2024 */

module jtcircus_snd(
    input                rst,
    input                clk,
    input                psg1_cen,
    input                psg2_cen,
    // ROM
    output        [13:0] rom_addr,
    output reg           rom_cs,
    input         [ 7:0] rom_data,
    input                rom_ok,
    // From main CPU
    input         [ 7:0] main_latch,
    input                snd_on,

    output signed [10:0] psg1, psg2,
    output reg    [ 7:0] rdac,
    output        [ 1:0] psg1_rcen,
    output        [ 3:0] psg2_rcen,
    output               rdac_rcen,
    output reg    [ 7:0] st_dout
);
`ifndef NOSOUND
localparam CNTW=14;

reg  [ 7:0] psg_data, din;
wire [ 7:0] ram_dout, dout;
wire        irq_ack, int_n, rfsh_n, mreq_n, iorq_n, m1_n;
reg         ram_cs;
wire [15:0] A;
reg  [ 3:0] rc_en;
wire        rdy1, rdy2;
reg         latch_cs, cnt_cs, rdac_cs, rcen_cs,
            psgdata_cs, psg1_cs, psg2_cs;
reg  [CNTW-1:0] cnt;
wire [CNTW-1:0] cnt_sel;

assign irq_ack   = ~iorq_n & ~m1_n;
assign rom_addr  = A[13:0];
assign cnt_sel   = cnt>>9;
assign rdac_rcen = rc_en[3];
assign psg1_rcen = { rc_en[2], 1'b1 };
assign psg2_rcen = rc_en[1:0]==1 ? 4'b0010 :
                   rc_en[1:0]==2 ? 4'b0100 :
                   rc_en[1:0]==3 ? 4'b1000 : 4'b0001;

always @(posedge clk) begin
    if( rst ) begin
        psg_data <= 0;
        cnt      <= 0;
        rc_en    <= 0;
    end else begin
        if( psg2_cen   ) cnt      <= cnt+1'd1;
        if( psgdata_cs ) psg_data <= dout;
        if( rdac_cs    ) rdac     <= dout;
        if( rcen_cs    ) rc_en    <= A[6:3];
    end
end

always @* begin
    rom_cs     = 0;
    ram_cs     = 0;
    psgdata_cs = 0;
    psg1_cs    = 0;
    psg2_cs    = 0;
    rdac_cs    = 0;
    rcen_cs    = 0;
    cnt_cs     = 0;
    latch_cs   = 0;
    if( !mreq_n && rfsh_n ) begin
        case(A[15:13])
          0,1: rom_cs   = 1; // 0000-3FFF
            2: ram_cs   = 1; // 4000
            3: latch_cs = 1; // 6000
            4: cnt_cs   = 1; // 8000
            5: case(A[2:0])  // A000
                0: psgdata_cs = 1;
                1: psg1_cs    = 1;
                2: psg2_cs    = 1;
                3: rdac_cs    = 1;
                4: rcen_cs    = 1;
                default:;
            endcase
            default:;
        endcase
    end
end

always @(posedge clk) begin
    din  <= rom_cs   ? rom_data   :
            ram_cs   ? ram_dout   :
            cnt_cs   ? { 3'h0, cnt_sel[3:0], 1'b0 } :
            latch_cs ? main_latch :
            8'hff;
    st_dout <= {3'd0, rdac!=0, rc_en };
end

jt89 u_psg1(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .clk_en ( psg2_cen      ),
    .wr_n   ( rdy1          ),
    .cs_n   ( ~psg1_cs      ),
    .din    ( psg_data      ),
    .sound  ( psg1          ),
    .ready  ( rdy1          )
);

jt89 u_psg2(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .clk_en ( psg2_cen      ),
    .wr_n   ( rdy2          ),
    .cs_n   ( ~psg2_cs      ),
    .din    ( psg_data      ),
    .sound  ( psg2          ),
    .ready  ( rdy2          )
);

jtframe_ff u_irq(
    .rst      ( rst         ),
    .clk      ( clk         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( int_n       ),
    .set      (             ),
    .clr      ( irq_ack     ),
    .sigedge  ( snd_on      )
);

jtframe_sysz80 #(.RAM_AW(10)) u_cpu(
    .rst_n      ( ~rst        ),
    .clk        ( clk         ),
    .cen        ( psg1_cen    ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ),
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( 1'b1        ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       (             ),
    .wr_n       (             ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .cpu_din    ( din         ),
    .cpu_dout   ( dout        ),
    .ram_dout   ( ram_dout    ),
    // manage access to ROM data from SDRAM
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);
`else
    initial rom_cs    = 0;
    initial rdac      = 0;
    assign  rom_addr  = 0;
    assign  psg1      = 0;
    assign  psg2      = 0;
    assign  psg1_rcen = 0;
    assign  psg2_rcen = 0;
    assign  rdac_rcen = 0;
    initial st_dout   = 0;
`endif
endmodule
