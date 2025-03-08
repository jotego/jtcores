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
    Date: 1-1-2025 */

module jtgaiden_main(
    input                rst,
    input                clk,
    input                LVBL,
    input                mcutype,

    output        [17:1] main_addr,
    output        [15:0] main_dout,
    output reg           rom_cs,
    output reg           ram_cs,
    output               ram_we,
    output        [ 1:0] dsn,

    output reg           nmi_set,
    output        [ 7:0] snd_cmd,
    // video memories
    output        [ 1:0] txt_we,
    output        [ 1:0] scra_we,
    output        [ 1:0] scrb_we,
    output        [ 1:0] obj_we,
    output        [ 1:0] pal_we,

    input         [15:0] mt_dout,
    input         [15:0] mo_dout,
    input         [15:0] mp_dout,
    input         [15:0] ma_dout,
    input         [15:0] mb_dout,

    // video registers
    output               flip,
    output        [15:0] txt_x, txt_y, scra_x, scra_y, scrb_x, scrb_y,
    output        [ 7:0] obj_y,

    input         [15:0] ram_dout,
    input         [15:0] rom_data,
    input                ram_ok,
    input                rom_ok,

    input         [ 6:0] joystick1,
    input         [ 6:0] joystick2,
    input         [ 1:0] cab_1p,
    input         [ 1:0] coin,
    input                dip_pause,
    input         [15:0] dipsw,

    // IOCTL dump
    input         [ 3:0] ioctl_addr,
    output reg    [ 7:0] ioctl_din
);
`ifndef NOMAIN
wire [23:1] A;
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, RnW, ASn, VPAn, DTACKn, BUSn;
wire [ 2:0] FC, IPLn;
reg         io_cs, txt_cs, scra_cs, scrb_cs, obj_cs, pal_cs, regs_cs, cab_cs,
            txty_cs, scray_cs, scrby_cs,
            txtx_cs, scrax_cs, scrbx_cs, objy_cs, flip_cs, clr_int,
            mcu_rd,  mcu_wr;
reg  [15:0] cpu_din, cab_dout;
wire [15:0] cpu_dout, wf_lut;
wire        bus_cs, bus_busy, intn, short_en, long_en;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign main_addr= A[17:1];
assign dsn      = {UDSn, LDSn};
assign main_dout= cpu_dout;
assign IPLn     = { intn, 1'b1, intn };
assign VPAn     = !(!ASn && FC==7 && RnW);
assign ram_we   = ram_cs & ~RnW;
assign bus_cs   = rom_cs | ram_cs;
assign bus_busy = (rom_cs & ~rom_ok) | (ram_cs & ~ram_ok);
assign BUSn     = ASn | (LDSn & UDSn);
assign txt_we   = {2{txt_cs &~RnW}} & ~{UDSn,LDSn};
assign scra_we  = {2{scra_cs&~RnW}} & ~{UDSn,LDSn};
assign scrb_we  = {2{scrb_cs&~RnW}} & ~{UDSn,LDSn};
assign obj_we   = {2{obj_cs &~RnW}} & ~{UDSn,LDSn};
assign pal_we   = {2{pal_cs &~RnW}} & ~{UDSn,LDSn};
assign short_en = A[3];
assign long_en  = A[2];
assign wf_lut[15:8] = 0;

always @* begin
    rom_cs  = !ASn  && A[19:16]<=   3;
    ram_cs  = !BUSn && A[19:16]==4'h6;
    txt_cs = !BUSn && A[19:12]==8'h70;
    scra_cs = !BUSn &&(A[19:12]==8'h72 || A[19:12]==8'h73);
    scrb_cs = !BUSn &&(A[19:12]==8'h74 || A[19:12]==8'h75);
    obj_cs  = !BUSn &&(A[19:12]==8'h76 || A[19:12]==8'h77);
    pal_cs  = !BUSn &&(A[19:12]==8'h78 || A[19:12]==8'h79);
    cab_cs  = !ASn  && A[19:12]==8'h7a;
    regs_cs = cab_cs && !RnW && !A[11];

    objy_cs  = regs_cs && A[9:8]==0 &&  A[3:2]==0 && A[1];
    txty_cs  = regs_cs && A[9:8]==1 && ^A[3:2];
    txtx_cs  = regs_cs && A[9:8]==1 && &A[3:2];
    scray_cs = regs_cs && A[9:8]==2 && ^A[3:2];
    scrax_cs = regs_cs && A[9:8]==2 && &A[3:2];
    scrby_cs = regs_cs && A[9:8]==3 && ^A[3:2];
    scrbx_cs = regs_cs && A[9:8]==3 && &A[3:2];

    mcu_rd   = cab_cs  &&  RnW && A[11:8]==0 && A[3:2]==1 && A[1];
    nmi_set  = cab_cs  && !RnW && A[11] && A[3:1]==1;
    mcu_wr   = cab_cs  && !RnW && A[11] && A[3:1]==2;
    clr_int  = cab_cs  && !RnW && A[11] && A[3:1]==3;
    flip_cs  = cab_cs  && !RnW && A[11] && A[3:1]==4;
end

always @(posedge clk) begin
    case(A[2:1])
        0: cab_dout <= {8'd0,coin,4'd0,cab_1p};
        1: cab_dout <= {1'b1,joystick2,1'b1,joystick1};
        2: cab_dout <= dipsw;
        default: cab_dout <= 0;
    endcase
end

always @(posedge clk) begin
    cpu_din <= rom_cs  ? rom_data :
               ram_cs  ? ram_dout :
               txt_cs  ? mt_dout  :
               scra_cs ? ma_dout  :
               scrb_cs ? mb_dout  :
               obj_cs  ? mo_dout  :
               pal_cs  ? mp_dout  :
               mcu_rd  ? wf_lut   :
               cab_cs  ? cab_dout : 16'h0;
end

always @(posedge clk) begin
    case(ioctl_addr)
        0: ioctl_din = txt_x[ 7:0];
        1: ioctl_din = txt_x[15:8];
        2: ioctl_din = txt_y[ 7:0];
        3: ioctl_din = txt_y[15:8];
        4: ioctl_din = scra_x[ 7:0];
        5: ioctl_din = scra_x[15:8];
        6: ioctl_din = scra_y[ 7:0];
        7: ioctl_din = scra_y[15:8];
        8: ioctl_din = scrb_x[ 7:0];
        9: ioctl_din = scrb_x[15:8];
       10: ioctl_din = scrb_y[ 7:0];
       11: ioctl_din = scrb_y[15:8];
       12: ioctl_din = obj_y;
       13: ioctl_din = {7'd0,flip};
       default: ioctl_din = 0;
    endcase
end

jtframe_16bit_reg   u_txtx (rst,clk,RnW, dsn, cpu_dout, txtx_cs,  txt_x  );
jtframe_16bit_reg   u_scrax(rst,clk,RnW, dsn, cpu_dout, scrax_cs, scra_x );
jtframe_16bit_reg   u_scrab(rst,clk,RnW, dsn, cpu_dout, scrbx_cs, scrb_x );
jtframe_mmr_reg     u_objy (rst,clk,RnW, cpu_dout[7:0], objy_cs , obj_y  );
jtframe_mmr_reg     u_snd  (rst,clk,1'b0,cpu_dout[7:0], nmi_set , snd_cmd);
jtframe_mmr_reg#(1) u_flip (rst,clk,RnW, cpu_dout[0],   flip_cs , flip   );

jtgaiden_scroll_adder u_txt_y(
    .clk        ( clk           ),
    .din        ( cpu_dout      ),
    .dsn        ( dsn           ),
    .wr_n       ( RnW           ),
    .cs         ( txty_cs       ),
    .short_en   ( short_en      ),
    .long_en    ( long_en       ),
    .scroll     ( txt_y         )
);

jtgaiden_scroll_adder u_scra_y(
    .clk        ( clk           ),
    .din        ( cpu_dout      ),
    .dsn        ( dsn           ),
    .wr_n       ( RnW           ),
    .cs         ( scray_cs      ),
    .short_en   ( short_en      ),
    .long_en    ( long_en       ),
    .scroll     ( scra_y        )
);

jtgaiden_scroll_adder u_scrb_y(
    .clk        ( clk           ),
    .din        ( cpu_dout      ),
    .dsn        ( dsn           ),
    .wr_n       ( RnW           ),
    .cs         ( scrby_cs      ),
    .short_en   ( short_en      ),
    .long_en    ( long_en       ),
    .scroll     ( scrb_y        )
);

jtgaiden_mcu_emu u_mcu_emu(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .we         ( mcu_wr        ),
    .mcutype    ( mcutype       ),
    .din        ( cpu_dout[15:8]),
    .dout       ( wf_lut[7:0]   )
);

jtframe_edge #(.QSET(0))u_vbl(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .edgeof     ( ~LVBL     ),
    .clr        ( clr_int   ),
    .q          ( intn      )
);

jtframe_68kdtack_cen #(.W(8)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'd0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 7'd24     ),  // 9.216 MHz
    .den        ( 8'd125    ),
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    // Frequency report
    .fave       (           ),
    .fworst     (           )
);

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .RESETn     (             ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),

    // Buses
    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),


    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( VPAn        ),
    .FC         ( FC          ),

    .BERRn      ( 1'b1        ),
    // Bus arbitrion
    .HALTn      ( dip_pause   ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        ) // VBLANK
);
`else
    integer fin, fcnt;
    reg [7:0] mmr[0:13];

    initial begin
        for( fcnt=0; fcnt<11; fcnt=fcnt+1 ) mmr[fcnt]=0;
        fin=$fopen("rest.bin","rb");
        fcnt = $fread(mmr,fin);
        $display("Read %d bytes from rest.bin",fcnt);
        $fclose(fin);
    end
    assign txt_x  = {mmr[1],mmr[0]};
    assign txt_y  = {mmr[3],mmr[2]};
    assign scra_x = {mmr[5],mmr[4]};
    assign scra_y = {mmr[7],mmr[6]};
    assign scrb_x = {mmr[9],mmr[8]};
    assign scrb_y = {mmr[11],mmr[10]};
    assign obj_y  =  mmr[12];
    assign flip   =  mmr[13][0];

    initial begin
        rom_cs = 0;
        ram_cs = 0;
        nmi_set = 0;
    end
    assign
    main_addr = 0, main_dout = 0, ram_we = 0, dsn = 0, snd_cmd = 0, txt_we = 0,
    scra_we = 0, scrb_we = 0, obj_we = 0, pal_we = 0, ioctl_din = 0;
`endif
endmodule
