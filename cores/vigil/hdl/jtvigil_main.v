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
    Date: 30-4-2022 */

module jtvigil_main(
    input              clk,
    input              rst,
    input              cpu_cen,

    // BUS sharing
    output      [17:0] main_addr,
    output             main_rnw,
    output             [7:0] cpu_dout,

    // Video configuration
    output  reg        flip,
    input              LVBL,
    input              dip_pause,
    // Sound
    output  reg        latch_wr,
    // scroll
    output  reg [ 8:0] scr1pos,
    output  reg [10:0] scr2pos,
    output  reg [ 2:0] scr2col,
    output  reg        scr2enb,
    // Object
    output  reg        scr_cs,
    output  reg        obj_cs,
    output  reg        pal_cs,
    input   [7:0]      pal_dout,
    input   [7:0]      scr_dout,
    // cabinet I/O
    input   [5:0]      joystick1,
    input   [5:0]      joystick2,
    input   [1:0]      cab_1p,
    input   [1:0]      coin,
    input              service,
    // DIP switches
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b,
    // ROM access
    output  reg        rom_cs,
    input       [ 7:0] rom_data,
    input              rom_ok
);
`ifndef NOMAIN

wire [15:0] A;
wire [ 7:0] ram_dout;
reg  [ 7:0] cpu_din;
reg  [ 2:0] bank;
reg         rst_n, ram_cs, dip1_cs, dip2_cs,
            in0_cs, in1_cs, in2_cs,
            out2_cs, bank_cs,
            scr1pos_cs, scr2pos_cs, scr2col_cs;
reg         flipr;
wire        rd_n, wr_n, mreq_n, iorq_n;
wire        int_n;

assign main_rnw = wr_n;
assign int_n    = LVBL | ~dip_pause;
assign main_addr = A[15] ? { 1'b0, bank, A[13:0] } + 18'h8000 : { 3'd0, A[14:0] };

always @(posedge clk) rst_n <= ~rst;

always @* begin
    // Memory mapped
    rom_cs  = !mreq_n && ( !A[15] || A[15:14]==2'b10 ); // 16kB Banks x 8 = 128
    ram_cs  = !mreq_n && A[15:12]==4'he;
    scr_cs  = !mreq_n && A[15:12]==4'hd;
    pal_cs  = !mreq_n && A[15:11]==5'b11001; // C8
    obj_cs  = !mreq_n && A[15:11]==5'b11000 && !wr_n; // C0
    // IO mapped
    in0_cs  = !iorq_n && !rd_n && A[2:0]==0;
    in1_cs  = !iorq_n && !rd_n && A[2:0]==1;
    in2_cs  = !iorq_n && !rd_n && A[2:0]==2;
    dip1_cs = !iorq_n && !rd_n && A[2:0]==3;
    dip2_cs = !iorq_n && !rd_n && A[2:0]==4;

    latch_wr   = !iorq_n && !wr_n && !A[7] && A[2:0]==0;
    out2_cs    = !iorq_n && !wr_n && !A[7] && A[2:0]==1;
    bank_cs    = !iorq_n && !wr_n && !A[7] && A[2:0]==4;
    scr1pos_cs = !iorq_n && !wr_n &&  A[7] && A[2:1]==0;
    scr2pos_cs = !iorq_n && !wr_n &&  A[7] && A[2:1]==1;
    scr2col_cs = !iorq_n && !wr_n &&  A[7] && A[2:0]==4;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank    <= 0;
        scr1pos <= 0;
        scr2pos <= 0;
        scr2col <= 0;
        flip    <= 0;
        scr2enb <= 0;
    end else begin
        flip <= flipr ^ dipsw_b[0];
        if( bank_cs    ) bank <= cpu_dout[2:0];
        if( out2_cs ) begin
            // COA1 COB1 ?
            flipr <= cpu_dout[0];
        end
        if( scr1pos_cs ) begin
            if( A[0] )
                scr1pos[8]    <= cpu_dout[0];
            else
                scr1pos[ 7:0] <= cpu_dout;
        end
        if( scr2pos_cs ) begin
            if( A[0] )
                scr2pos[10:8] <= cpu_dout[2:0];
            else
                scr2pos[ 7:0] <= cpu_dout;
        end
        if( scr2col_cs ) begin
            // bit 6 ROME ? ROMF ?
            scr2enb <= cpu_dout[6];
            scr2col <= {cpu_dout[3:2], cpu_dout[0]};
        end
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cpu_din <= 0;
    end else begin
        cpu_din <=
            rom_cs  ? rom_data :
            ram_cs  ? ram_dout :
            pal_cs  ? pal_dout :
            scr_cs  ? scr_dout : // I think the scroll cannot be read, but sch. are blurry
            in0_cs  ? { 4'hf, coin[0], service, cab_1p } :
            in1_cs  ? { joystick1[5], 1'b1, joystick1[4], 1'b1, joystick1[3:0] } :
            in2_cs  ? { joystick2[5], 1'b1, joystick2[4], 1'b1, joystick2[3:0] } :
            dip1_cs ? dipsw_a  :
            dip2_cs ? dipsw_b  : 8'hff;
    end
end

jtframe_sysz80 #(
    .RAM_AW     ( 12        ),
    .CLR_INT    ( 1         )
) u_cpu(
    .rst_n      ( rst_n     ),
    .clk        ( clk       ),
    .cen        ( cpu_cen   ),
    .cpu_cen    (           ),
    .int_n      ( int_n     ),
    .nmi_n      ( 1'b1      ),
    .busrq_n    ( 1'b1      ),
    .m1_n       (           ),
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

`else
    initial begin
        pal_cs    = 0;
        scr_cs    = 0;
        scr1pos   = 0;
        scr2pos   = { debug_bus, 3'd0 };
        scr2col   = 0;
        latch_wr  = 0;
        rom_cs    = 0;
        flip      = 1;
    end
    assign  main_addr = 0;
    assign  cpu_dout  = 0;
`endif

endmodule