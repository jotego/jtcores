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
    Date: 18-12-2021 */

module jtyiear_main(
    input               rst,
    input               clk,        // 24 MHz
    input               cpu4_cen,   // 6 MHz
    output              cpu_cen,    // Q clock
    input               ti1_cen,
    input               ti2_cen,
    // ROM
    output      [15:0]  rom_addr,
    output reg          rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,
    // cabinet I/O
    input       [ 1:0]  cab_1p,
    input       [ 1:0]  coin,
    input       [ 5:0]  joystick1,
    input       [ 5:0]  joystick2,
    input               service,

    // GFX
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,
    output reg          vscr_cs,
    output reg          vram_cs,
    output reg          obj1_cs,
    output reg          obj2_cs,

    // configuration
    output reg  [ 2:0]  pal_sel,
    output reg          flip,

    // interrupt triggers
    input               LVBL,
    input               V16,

    input      [7:0]    vram_dout,
    input      [7:0]    vscr_dout,  // unused, left here for easier integration
    input      [7:0]    obj_dout,
    // DIP switches
    input               dip_pause,
    input      [7:0]    dipsw_a,
    input      [7:0]    dipsw_b,
    input      [3:0]    dipsw_c,

    // Sound
    output     [15:0]   pcm_addr,
    input      [ 7:0]   pcm_data,
    input               pcm_ok,

    output signed [ 9:0] vlm,
    output signed [10:0] ti1
);

reg  [ 7:0] cabinet, cpu_din;
wire [15:0] A;
wire        RnW, irq_n, nmi_n;
wire        irq_trigger, nmi_trigger;
reg         nmi_clrn, irq_clrn;
reg         ior_cs, dip2_cs, dip3_cs,
            ti1_cs,
            color_cs, tidata1_cs, iow_cs;
// reg         afe_cs; // watchdog
wire        VMA;

// VLM5030 sound
reg         vlm_bsy_cs;
wire        vlm_bsy, vlm_cen;
reg         vlm_data_cs, vlm_cont,
            vlm_st, vlm_rst, vlm_sel;
reg   [7:0] vlm_data;
wire  [7:0] vlm_mux;

assign irq_trigger = ~LVBL & dip_pause;
assign nmi_trigger =  V16;
assign cpu_rnw     = RnW;
assign rom_addr    = A;

always @(*) begin
    rom_cs     = 0;
    iow_cs     = 0;
    // afe_cs  = 0;
    ti1_cs     = 0;
    dip2_cs    = 0;
    dip3_cs    = 0;
    ior_cs     = 0;
    tidata1_cs = 0;
    color_cs   = 0;
    vscr_cs    = 0;
    obj1_cs    = 0;
    obj2_cs    = 0;
    vram_cs    = 0;
    vlm_bsy_cs = 0;
    vlm_data_cs = 0;
    vlm_cont   = 0;
    case( A[15:14] )
        0: vlm_bsy_cs = 1;
        1: case( A[13:11] )
                0: iow_cs = 1;
                1:
                    case(A[10:8])
                        // 7: afe_cs = 1;
                        6: ior_cs  = 1;
                        5: dip3_cs = 1;
                        4: dip2_cs = 1;
                        3: vlm_data_cs = 1;
                        2: vlm_cont = 1;
                        1: ti1_cs = 1;
                        0: tidata1_cs = 1;
                        default:;
                    endcase
                2: { obj2_cs, obj1_cs } = { ~A[10], A[10] };
                3: vram_cs = 1;
                default:;
            endcase
        2,3: rom_cs = VMA && RnW;
        default:;
    endcase
end

always @(posedge clk) begin
    case( A[1:0] )
        0: cabinet <= { ~3'd0, cab_1p, service, coin };
        1: cabinet <= { 2'b11, joystick1[5:0] };
        2: cabinet <= { 2'b11, joystick2[5:0] };
        3: cabinet <= dipsw_a;
    endcase
    cpu_din <= rom_cs  ? rom_data  :
               vram_cs ? vram_dout :
               (obj1_cs | obj2_cs) ? obj_dout  :
               ior_cs  ? cabinet   :
               dip2_cs ? dipsw_b   :
               dip3_cs ? { 4'hf, dipsw_c } :
               vlm_bsy_cs ? {7'h7f,vlm_bsy} : 8'hff;
end

always @(posedge clk) begin
    if( rst ) begin
        nmi_clrn <= 0;
        irq_clrn <= 0;
        flip     <= 0;
        pal_sel  <= 0;
        vlm_data <= 0;
        vlm_rst  <= 1;
        vlm_st   <= 0;
        vlm_sel  <= 0;
    end else if(cpu_cen) begin
        if( vlm_data_cs ) vlm_data <= cpu_dout;
        if( vlm_cont ) { vlm_rst, vlm_st, vlm_sel } <= cpu_dout[2:0];
        if( iow_cs && !RnW ) begin
            // bit 5 = SA ??
            irq_clrn <= cpu_dout[2];
            nmi_clrn <= cpu_dout[1];
            flip     <= cpu_dout[0];
        end
        if( color_cs ) pal_sel <= cpu_dout[2:0];
    end
end

jtframe_ff u_irq(
    .rst      ( rst         ),
    .clk      ( clk         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( irq_n       ),
    .set      (             ),    // active high
    .clr      ( ~irq_clrn   ),    // active high
    .sigedge  ( irq_trigger )     // signal whose edge will trigger the FF
);

jtframe_ff u_nmi(
    .rst      ( rst         ),
    .clk      ( clk         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( nmi_n       ),
    .set      (             ),    // active high
    .clr      ( ~nmi_clrn   ),    // active high
    .sigedge  (nmi_trigger  )     // signal whose edge will trigger the FF
);

reg  [ 7:0] ti1_data;
wire        rdy1;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ti1_data <= 0;
    end else begin
        if( tidata1_cs ) ti1_data <= cpu_dout;
    end
end

jt89 u_ti1(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .clk_en ( ti2_cen       ),  // yes, ti2_cen (half the speed of ti1_cen)
    .wr_n   ( rdy1          ),
    .cs_n   ( ~ti1_cs       ),
    .din    ( ti1_data      ),
    .sound  ( ti1           ),
    .ready  ( rdy1          )
);


jtframe_sys6809 #(.RAM_AW(0)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cpu4_cen  ),   // This is normally the input clock to the CPU
    .cpu_cen    ( cpu_cen   ),   // 1/4th of cen -> 3MHz

    // Interrupts
    .nIRQ       ( irq_n     ),
    .nFIRQ      ( 1'b1      ),
    .nNMI       ( nmi_n     ),
    .irq_ack    (           ),
    // Bus sharing
    .bus_busy   ( 1'b0      ),
    // memory interface
    .A          ( A         ),
    .RnW        ( RnW       ),
    .VMA        ( VMA       ),
    .ram_cs     ( 1'b0      ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    // Bus multiplexer is external
    .ram_dout   (           ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    ( cpu_din   )
);

jtframe_cen3p57 #(.CLK24(1)) u_vlmcen(
    .clk        ( clk       ),
    .cen_3p57   ( vlm_cen   ),
    .cen_1p78   (           )
);

wire [2:0] pcm_nc;
wire       vlm_ceng, vlm_me_b;

assign vlm_mux = vlm_sel ? vlm_data :
               ~vlm_me_b ? pcm_data : 8'hff;
assign pcm_addr[15:13]=0;
assign vlm_ceng = vlm_cen & ( vlm_me_b | pcm_ok );

vlm5030_gl u_vlm(
    .i_rst   ( vlm_rst      ),
    .i_clk   ( clk          ),
    .i_oscen ( vlm_ceng     ),
    .i_start ( vlm_st       ),
    .i_vcu   ( 1'b0         ),
    .i_d     ( vlm_mux      ),
    .o_a     ( { pcm_nc, pcm_addr[12:0] } ),
    .o_me_l  ( vlm_me_b     ),
    .o_mte   (              ),
    .o_bsy   ( vlm_bsy      ),

    .o_dao   (              ),
    .o_audio ( vlm          ),
    // Unused test pins
    .i_tst1  ( 1'b0         ),
    .o_tst2  (              ),
    .i_tst3  ( 1'b0         ),
    .o_tst4  (              ),
    .i_vref  ( 1'b0         )
);

endmodule
