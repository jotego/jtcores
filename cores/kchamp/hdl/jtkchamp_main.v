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
    Date: 2-9-2022 */

module jtkchamp_main(
    input              rst,
    input              clk,
    input              cen_3,
    input              LVBL,

    input       [ 7:0] joystick1,
    input       [ 7:0] joystick2,
    input       [ 1:0] game_start,
    input       [ 1:0] coin,
    input              dip_pause,
    output reg         flip,
    input       [ 7:0] dipsw,
    input              enc,
    input              link_joys,

    output      [ 7:0] cpu_dout,
    output             cpu_rnw,

    output reg         vram_cs,
    output reg         oram_cs,
    input       [ 7:0] vram_dout,
    input       [ 7:0] oram_dout,
    input              vram_bsy,

    output reg  [ 7:0] snd_latch,
    output reg         snd_req,
    output reg         snd_rstn,
    // ROM access
    output reg         rom_cs,
    output      [15:0] bus_addr,
    input       [ 7:0] rom_data,
    input              rom_ok
);

wire        m1_n, mreq_n, iorq_n, rd_n, wr_n,
            bus_cen, nmi_n;
reg         nmi_on, bus_bsyn, iord_cs, iowr_cs;
reg  [ 7:0] cpu_din, cab_dout, dec, ctrl_1p, ctrl_2p;
wire [15:0] A;
wire [ 7:0] ram_dout;
reg         ram_cs, snd_rst_rq;

assign bus_addr = A;
assign bus_cen  = bus_bsyn & cen_3;
assign cpu_rnw  = wr_n;

// The address decoder is a bit different for
// the encrypted version
always @* begin
    iord_cs = !iorq_n && !rd_n;
    iowr_cs = !iorq_n && !wr_n;
    if(enc) begin // kchampvs
        rom_cs  = !mreq_n && A[15:13]!=6;
        ram_cs  = !mreq_n && A[15:12]==4'hc;
        vram_cs = !mreq_n && A[15:11]==5'b1101_0; // c0
        oram_cs = !mreq_n && A[15:11]==5'b1101_1; // c8
        snd_req = iowr_cs && A[7:6]==1;
        snd_rst_rq = 0;
    end else begin // kchamp
        rom_cs  = !mreq_n && A[15:13]<6;
        ram_cs  = !mreq_n && A[15:12]==4'hc;
        vram_cs = !mreq_n && A[15:11]==5'b1110_0; // e0
        oram_cs = !mreq_n && A[15:11]==5'b1110_1; // e8, should it be ea?
        snd_req = iowr_cs && A[7:3]==5'b1010_1; // a8
        snd_rst_rq = iord_cs && A[7:3]==5'b1010_1; // a8
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        snd_rstn  <= 0;
        flip      <= 0;
        nmi_on    <= 1;
        snd_latch <= 0;
    end else begin
        if( !enc ) snd_rstn <= ~snd_rst_rq;
        if( iowr_cs ) begin
            if( snd_req  ) snd_latch <= cpu_dout;
            if( enc ? A[7:6]==0 : A[7:4]==8) begin
                case( A[2:0] )
                    0: flip     <= cpu_dout[0];
                    1: nmi_on   <= cpu_dout[0];
                    2: if( enc) snd_rstn <= cpu_dout[0];
                    default:;
                endcase
            end
        end
    end
end

always @(posedge clk) begin
    if( cen_3 ) bus_bsyn <= ~(vram_bsy & vram_cs);
end

always @* begin
    ctrl_1p = { joystick1[7:4], joystick1[2], joystick1[3], joystick1[1:0] };
    if( link_joys ) ctrl_1p[7:4] = { joystick2[2], joystick2[3], joystick2[1:0] };
    ctrl_2p = { joystick2[7:4], joystick2[2], joystick2[3], joystick2[1:0] };
end

always @(posedge clk) begin
    if( enc )
        case( A[7:6] )
            0: cab_dout <= ctrl_1p;
            1: cab_dout <= ctrl_2p;
            2: cab_dout <= { 4'hf, game_start, coin };
            3: cab_dout <= dipsw;
        endcase
    else
        case( A[5:3] )
            0: cab_dout <= dipsw;
            2: cab_dout <= ctrl_1p;
            3: cab_dout <= ctrl_2p;
            4: cab_dout <= { 4'hf, game_start, coin };
            default: cab_dout <= 8'hff;
        endcase
end

always @* begin
    dec = { rom_data[5], rom_data[6], rom_data[7], rom_data[4],
            rom_data[1], rom_data[2], rom_data[3], rom_data[0] };
end

always @* begin
    cpu_din = rom_cs  ? ((m1_n | ~enc)? rom_data : dec) :
              ram_cs  ? ram_dout  :
              vram_cs ? vram_dout :
              oram_cs ? oram_dout :
              iord_cs ? cab_dout  : 8'hff;
end

jtframe_ff u_nmi(
    .clk    ( clk       ),
    .rst    ( rst       ),
    .cen    ( 1'b1      ),
    .din    ( 1'b1      ),
    .q      (           ),
    .qn     ( nmi_n     ),
    .set    (           ),
    .clr    ( ~nmi_on   ),
    .sigedge( ~(LVBL & dip_pause) )
);

jtframe_sysz80 #(.RAM_AW(12)) u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( bus_cen   ),
    .cpu_cen    (           ),
    .int_n      ( 1'b1      ), // see CLR_INT parameter below
    .nmi_n      ( nmi_n     ),  // v blank
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

endmodule