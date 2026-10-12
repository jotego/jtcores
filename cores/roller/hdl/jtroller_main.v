/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

module jtroller_main(
    input             rst, clk, cen24,
    output     [15:0] cpu_addr,
    output     [ 7:0] cpu_dout,
    output            cpu_we,

    output     [16:0] main_addr,
    output reg        main_cs,
    input      [ 7:0] main_data,
    input             main_ok,
    output reg        ram_we,
    input      [ 7:0] ram_dout,

    input      [ 1:0] cab_1p, coin,
    input      [ 5:0] joystick1, joystick2,
    input             service,
    input      [23:0] dipsw,
    input             dip_pause,

    input             ccu_int1,
    input      [ 7:0] ccu_dout, psac_dout, psac_rom_data,
                      obj_dout, pal_dout, snd_dout,
    input             psac_ok, obj_ok,
    output reg        ccu_cs, psac_reg_cs, psac_vr_cs,
                      obj_reg_cs, obj_ram_cs, pal_cs, snd_cs,
    output            snd_irq, psac_readroms, psac_wrap,
    output     [ 7:0] st_dout
);
wire [ 7:0] ext;
wire        bank_rom, wrap, ext_cs, ext_wr_n;

assign bank_rom      = ext[2];
assign wrap          = ext[5];
assign ext_wr_n      = ~cpu_we;
assign psac_readroms = bank_rom;
assign psac_wrap     = wrap;

`ifndef NOMAIN

wire [23:0] addr;
wire [15:0] pcbad;
wire [ 3:0] rom_ab;
wire        cs1_n, rom_oe_n, data_oe_n;
wire        pal12_n, ccu_n, pal14_n, objset_n;
wire        objoe_n, pal17_n, obj_cs_n, objse_n;
wire        buserror;
wire        cpu_cen, dtack;
wire        irq_n;
reg  [ 7:0] cpu_din, cab_dout;
reg         io_cs, sndirq_cs, cab_cs, dip_cs;
reg         buserror_l;
reg         snd_irq_l;

assign cpu_addr      = addr[15:0];
assign main_addr     = {rom_ab,addr[12:0]};
assign snd_irq       = snd_irq_l;
assign ext_cs        = io_cs && addr[6:4]==3'd1;
assign dtack         = (!main_cs || main_ok) &&
                       (!psac_vr_cs || psac_ok) && obj_ok;
assign irq_n         = ~ccu_int1 | ~dip_pause;
assign st_dout       = {5'd0,bank_rom,wrap,buserror_l};

// F13 74LS138 is enabled by F12 pin 12 and decodes A6:A4.
always @* begin
    main_cs    = !rom_oe_n && !cpu_we;
    ram_we     = !cs1_n && cpu_we;
    ccu_cs     = !ccu_n;
    psac_reg_cs= !pal14_n;
    psac_vr_cs = !objoe_n || !pal17_n;
    obj_reg_cs = !objset_n;
    obj_ram_cs = !obj_cs_n;
    pal_cs     = !objse_n;
    io_cs      = !pal12_n;
    snd_cs     = io_cs && addr[6:4]==3'd3;
    sndirq_cs  = io_cs && addr[6:4]==3'd4;
    cab_cs     = io_cs && addr[6:4]==3'd5;
    dip_cs     = io_cs && addr[6:4]==3'd6;
end

always @(posedge clk) begin
    case (addr[7:0])
        8'h50: cab_dout <= {cab_1p[0],joystick1[3:0],joystick1[4],joystick1[5],1'b1};
        8'h51: cab_dout <= {cab_1p[1],joystick2[3:0],joystick2[4],joystick2[5],1'b1};
        8'h52: cab_dout <= {service,1'b1,coin[0],coin[1],1'b1,dipsw[18],1'b1,dipsw[16]};
        8'h53: cab_dout <= dipsw[7:0];
        8'h60: cab_dout <= dipsw[15:8];
        8'h61: cab_dout <= 8'h7f;
        default: cab_dout <= 8'hff;
    endcase
end

always @* begin
    cpu_din = main_cs     ? main_data :
              !cs1_n      ? ram_dout  :
              ccu_cs      ? ccu_dout  :
              psac_vr_cs  ? (bank_rom ? psac_rom_data : psac_dout) :
              obj_reg_cs  ? obj_dout  :
              obj_ram_cs  ? obj_dout  :
              pal_cs      ? pal_dout  :
              snd_cs      ? snd_dout  :
              cab_cs      ? cab_dout  :
              dip_cs      ? cab_dout  : 8'hff;
end

always @(posedge clk) begin
    snd_irq_l <= cpu_we && sndirq_cs;
    if (rst) begin
        buserror_l <= 0;
    end else begin
        if (buserror) buserror_l <= 1;
    end
end

jtroller_decode u_decode(
    .as_n      ( 1'b0      ),
    .addr      ( addr[19:0]),
    .g18p7     ( bank_rom  ),
    .cs1_n     ( cs1_n     ),
    .rom_ab    ( rom_ab    ),
    .rom_oe_n  ( rom_oe_n  ),
    .data_oe_n ( data_oe_n ),
    .pal12_n   ( pal12_n   ),
    .ccu_n     ( ccu_n     ),
    .pal14_n   ( pal14_n   ),
    .objset_n  ( objset_n  ),
    .objoe_n   ( objoe_n   ),
    .pal17_n   ( pal17_n   ),
    .obj_cs_n  ( obj_cs_n  ),
    .objse_n   ( objse_n   )
);

jtkcpu u_cpu(
    .rst      ( rst                  ),
    .clk      ( clk                  ),
    .cen2     ( cen24                ),
    .cen_out  ( cpu_cen              ),
    .halt     ( buserror_l           ),
    .dtack    ( dtack                ),
    .nmi_n    ( 1'b1                 ),
    .irq_n    ( irq_n                ),
    .firq_n   ( 1'b1                 ),
    .pcbad    ( pcbad                ),
    .buserror ( buserror             ),
    .din      ( cpu_din              ),
    .dout     ( cpu_dout             ),
    .addr     ( addr                 ),
    .we       ( cpu_we               )
);
`else
assign {cpu_addr,cpu_dout,cpu_we,main_addr,snd_irq,
        st_dout}=0;
assign ext_cs = 1'b0;
initial {main_cs,ram_we,ccu_cs,psac_reg_cs,psac_vr_cs,
         obj_reg_cs,obj_ram_cs,pal_cs,snd_cs}=0;
`endif

// G18 Q2 selects the PSAC ROM and G18 Q5 drives PSAC OBLK.
jtframe_8bit_reg #(.SIMFILE("ext.bin")) u_ext(
    .rst    ( rst      ),
    .clk    ( clk      ),
    .wr_n   ( ext_wr_n ),
    .din    ( cpu_dout ),
    .cs     ( ext_cs   ),
    .dout   ( ext      )
);
endmodule
