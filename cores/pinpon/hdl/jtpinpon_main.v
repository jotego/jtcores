/*  This file is part of JTKICKER.
    JTKICKER program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTKICKER program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTKICKER.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 26-3-2022 */

module jtpinpon_main(
    input               rst,
    input               clk,        // 24 MHz
    input               ti1_cen,    // 3 MHz
    output              cpu_cen,    // 3 MHz
    // ROM
    output      [14:0]  rom_addr,
    output reg          rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,
    // cabinet I/O
    input       [ 1:0]  start_button,
    input       [ 1:0]  coin_input,
    input       [ 5:0]  joystick1,
    input       [ 5:0]  joystick2,
    input               service,

    // GFX
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,
    output reg          vram_cs,
    output reg          oram_cs,

    // configuration
    output              flip,

    // interrupt triggers
    input               LVBL,
    input               V16,

    input      [7:0]    vram_dout,
    input      [7:0]    obj_dout,
    // DIP switches
    input               dip_pause,
    input      [7:0]    dipsw_a,
    input      [7:0]    dipsw_b,
    input      [2:0]    dipsw_c,
    input               dip_test,

    // Sound
    output signed [10:0] snd,
    output               sample
);

reg  [ 7:0] cabinet, cpu_din;
wire [15:0] A;
wire        rd_n, wr_n, int_n, nmi_n, m1_n, iorq_n;
wire        irq_trigger, nmi_trigger;
reg         nmi_clrn, irq_clrn;
reg         ior_cs, ti1_cs, tidata1_cs, iow_cs;
wire        mreq_n, rfsh_n, gated_cen;
reg         gfx_sel;

assign irq_trigger = ~LVBL & dip_pause; // this should match line 224
assign nmi_trigger =  V16; // check in sch/PCB
assign cpu_rnw     = wr_n;
assign sample      = ti1_cen;
assign rom_addr    = A[14:0];
assign flip        = 0;
assign gated_cen   = gfx_sel & (oram_cs | vram_cs) ? 1'b0 : ti1_cen; // bus contention as the original board

always @(*) begin
    rom_cs     = 0;
    iow_cs     = 0;
    ti1_cs     = 0;
    ior_cs     = 0;
    tidata1_cs = 0;
    oram_cs    = 0;
    vram_cs    = 0;
    if( !mreq_n && rfsh_n ) begin
        if( !A[15] )
            rom_cs = 1;
        else begin
            if( !A[13] ) begin
                vram_cs = !A[12];
                oram_cs =  A[12];
            end else begin
                case(A[11:9])
                    0: iow_cs = 1;
                    1: tidata1_cs = 1;
                    2: ti1_cs = 1;
                    // 3: watchdog
                    4: ior_cs = 1;
                    default:;
                endcase
            end
        end
    end
end

always @(posedge clk) begin
    case( A[8:7] )
        0: cabinet <= { coin_input[0], coin_input[1], service,
            start_button[0], start_button[1], dipsw_c };
        1: cabinet <= { joystick1[4], joystick1[0], joystick1[1], joystick1[5],
                        joystick2[4], joystick2[0], joystick2[1], joystick2[5] };
        2: cabinet <= dipsw_a;
        3: cabinet <= { dipsw_b[0], dipsw_b[1], dipsw_b[2], dipsw_b[3],
                        dipsw_b[4], dipsw_b[5], dipsw_b[6], dipsw_b[7] };
    endcase
    cpu_din <= rom_cs  ? rom_data  :
               vram_cs ? vram_dout :
               oram_cs ? obj_dout  :
               ior_cs  ? cabinet   : 8'hff;
end

always @(posedge clk) begin
    if( rst ) begin
        gfx_sel  <= 0;
    end else if(ti1_cen) begin
        gfx_sel <= ~gfx_sel;
    end
end


always @(posedge clk) begin
    if( rst ) begin
        nmi_clrn <= 0;
        irq_clrn <= 0;
    end else if(cpu_cen) begin
        if( iow_cs && !wr_n ) begin
            nmi_clrn <= cpu_dout[3];
            irq_clrn <= cpu_dout[2];
        end
    end
end

jtframe_ff u_irq(
    .rst      ( rst         ),
    .clk      ( clk         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( int_n       ),
    .set      (             ),
    .clr      ( ~irq_clrn   ),
    .sigedge  ( irq_trigger )
);

jtframe_ff u_nmi(
    .rst      ( rst         ),
    .clk      ( clk         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( nmi_n       ),
    .set      (             ),
    .clr      ( ~nmi_clrn   ),
    .sigedge  (nmi_trigger  )
);

reg  [ 7:0] ti1_data;
wire [10:0] ti1_snd;
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
    .clk_en ( ti1_cen       ),
    .wr_n   ( rdy1          ),
    .cs_n   ( ~ti1_cs       ),
    .din    ( ti1_data      ),
    .sound  ( snd           ),
    .ready  ( rdy1          )
);

/* verilator tracing_off */

// TODO: check bus contention in the PCB
jtframe_z80_romwait  u_cpu(
    .rst_n      ( ~rst        ),
    .clk        ( clk         ),
    .cen        ( gated_cen   ),
    .cpu_cen    ( cpu_cen     ),
    .int_n      ( int_n       ),
    .nmi_n      ( nmi_n       ),
    .busrq_n    ( 1'b1        ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .din        ( cpu_din     ),
    .dout       ( cpu_dout    ),
    // manage access to ROM data from SDRAM
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);

endmodule
