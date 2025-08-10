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
    Date: 5-7-2025 */

// sel[1:0]      clk divider
//   00          /4
//   01          /2
//   10          /1
// the clock divider is not implemented. Apply the expected pxl_cen directly
module jtk053252(
    input             rst,
    input             clk,
    input             pxl_cen,
    input       [2:0] sel,          // sel pins, normally 0 (unused)
    input             vldi, hldi,   // external load pins, normally 1 (unused)

    input             cs,
    input       [3:0] addr,
    input             rnw,
    input       [7:0] din,
    output reg  [7:0] dout,

    output            lhbl, lvbl, hs, vs,
                      int1, int2,
    output reg        hld,  vld,
                      lhbs, // variable delay
    // IOCTL dump
    input      [3:0] ioctl_addr,
    output     [7:0] ioctl_din
);

parameter [127:0] INIT=128'h00_00_00_54_0E_0C_07_01_00_01_37_00_21_00_FF_01;

wire [9:0] hcnt0, hcnt;
wire [8:0] hbstart, hb2cnt0,  vcnt0, vcnt;
wire [7:0] vbstart, int2cnt0, vbcnt0;
reg  [8:0] hbcnt;
reg  [7:0] vbcnt, int2cnt;
reg  [6:0] lhbl_sh;
reg  [3:0] vscnt;
reg        hb2en, hldi_l, vldi_l, hbk0, hb_en, vb_en;
wire [3:0] hswidth, vswidth;
wire [2:0] nhbs_dly;
wire [1:0] fcnt_out;
wire       hcnt_dis, int1ack, int2ack, set_int2en, i2tc, hb, int2en,
           vtc, htc, vsn, hsn, hstc, vstc, hbtc, vb, vbtc;
wire       ld_sel = sel[2];
// wire clk_sel = sel[1:0]; // clock mux, unused
wire       hld_mx = ld_sel ? ~hldi_l : &{htc,~hcnt_dis};
wire       vld_mx = ld_sel ? ~vldi_l : &{vtc,~hcnt_dis};
wire hbk0_eff = hcnt_dis | hbk0; // j31
wire vsov     = vs & vstc;
wire vbk0     = vcnt=={1'b1,~vbstart} & hbk0_eff;
wire i2cnt_en = hbk0_eff & int2en;
wire hsov     = hs & hstc;

always @(posedge clk) if(pxl_cen) begin
    dout   <= {vcnt[7:1],addr[0] ? vcnt[0] : vcnt[8]};
    hld    <= hld_mx;
    vld    <= vld_mx;
    hldi_l <= hldi;
    vldi_l <= vldi;

    hbk0   <= hcnt=={1'b1,~hbstart};

    lhbl_sh <= {lhbl_sh[5:0],lhbl};
    lhbs    <= lhbl_sh[nhbs_dly];
end

jtframe_edge u_int2en(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( set_int2en),
    .clr    ( 1'b0      ),
    .q      ( int2en    )
);

jtframe_edge u_int1(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( vb        ),
    .clr    ( int1ack   ),
    .q      ( int1      )
);

jtframe_edge u_int2(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( i2tc      ),
    .clr    ( int2ack   ),
    .q      ( int2      )
);

wire hbk_cen = pxl_cen & hbk0_eff;

jtframe_count_ld #(9) u_vcnt(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( hbk_cen   ),
    .en         ( 1'b1      ),
    .ld         ( vld_mx    ),
    .cnt0       (~vcnt0     ),
    .cnt        ( vcnt      ),
    .tc         ( vtc       )
);

jtframe_count_ld #(10) u_hcnt(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( pxl_cen   ),
    .en         (~hcnt_dis  ),
    .ld         ( hld_mx    ),
    .cnt0       (~hcnt0     ),
    .cnt        ( hcnt      ),
    .tc         ( htc       )
);

jtframe_count_ld #(7) u_hscnt(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( pxl_cen   ),
    .en         ( ~hcnt_dis ),
    .ld         ( hld_mx    ),
    .cnt0       ( {~hswidth,3'd0} ),
    .cnt        (           ),
    .tc         ( hstc      )   // hstc = m11
);

// CNTA - VB
jtframe_count_ld #(.W(8),.ONE_SHOT(1)) u_vbcnt(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( pxl_cen   ),
    .en         ( hbk0_eff  ), // L38B
    .ld         ( vsov      ), // G51
    .cnt0       (~vbcnt0    ),
    .cnt        (           ),
    .tc         ( vbtc      )
);

// CNTB - HB
jtframe_count_ld #(.W(9),.ONE_SHOT(1)) u_hbcnt(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( pxl_cen   ),
    .en         ( 1'b1      ),
    .ld         ( hsov      ),  // hsov = l37
    .cnt0       (~hb2cnt0   ),
    .cnt        (           ),
    .tc         ( hbtc      )
);

// CNTC - VS
jtframe_count_ld #(4) u_vscnt(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( pxl_cen   ),
    .en         ( hbk0_eff  ),
    .ld         ( vld_mx    ), // d35
    .cnt0       ( vswidth   ),
    .cnt        (           ),
    .tc         ( vstc      )
);

// CNTD - interrupt 2
jtframe_count_ld #(8) u_i2cnt(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( pxl_cen   ),
    .en         ( i2cnt_en  ),
    .ld         ( i2tc      ),
    .cnt0       ( int2cnt0  ),
    .cnt        (           ),
    .tc         ( i2tc      )
);

//                                    J       K    Q   ~Q
jtframe_ff_jk u_hs(rst,clk,pxl_cen, hld_mx, hstc,  hs, hsn );
jtframe_ff_jk u_vs(rst,clk,pxl_cen, vld_mx, vstc,  vs, vsn );
jtframe_ff_jk u_hb(rst,clk,pxl_cen, hbk0,   hbtc,  hb, lhbl);
jtframe_ff_jk u_vb(rst,clk,pxl_cen, vbk0,   vbtc,  vb, lvbl);

jtk053252_mmr #(.SIMFILE("ccu.bin")) u_mmr(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .cs         ( cs        ),
    .addr       ( addr      ),
    .rnw        ( rnw       ),
    .din        ( din       ),
    .dout       (           ),

    .hcnt0      ( hcnt0     ),
    .hbstart    ( hbstart   ),
    .hb2cnt0    ( hb2cnt0   ),
    .nhbs_dly   ( nhbs_dly  ),
    .fcnt_out   ( fcnt_out  ),
    .hcnt_dis   ( hcnt_dis  ),
    .vcnt0      ( vcnt0     ),
    .vbcnt0     ( vbcnt0    ),
    .vbstart    ( vbstart   ),
    .vswidth    ( vswidth   ),
    .hswidth    ( hswidth   ),
    .int2cnt0   ( int2cnt0  ),
    .int1ack    ( int1ack   ),
    .int2ack    ( int2ack   ),
    .set_int2en ( set_int2en),

    // IOCTL dump
    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din ),
    // Debug
    .debug_bus  ( 8'd0      ),
    .st_dout    (           )
);

endmodule
