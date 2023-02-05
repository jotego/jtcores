/*  This file is part of JTDD.
    JTDD program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTDD program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTDD.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 30-7-2022 */

module jtkunio_main(
    input              clk,        // 24 MHz
    input              rst,
    input              cen_3,
    input              cen_1p5,
    input              LVBL,
    input              v8,

    input       [ 1:0] start,
    input       [ 1:0] coin,
    input       [ 6:0] joystick1,
    input       [ 6:0] joystick2,
    input       [ 7:0] dipsw_a,
    input       [ 7:0] dipsw_b,
    input              dip_pause,
    input              service,

    output      [ 7:0] cpu_dout,
    output             cpu_rnw,
    // graphics
    output reg  [ 9:0] scrpos,
    output reg         flip,
    output reg         ram_cs,
    output reg         scrram_cs,
    output reg         objram_cs,
    output reg         pal_cs,
    input       [ 7:0] ram_dout,
    input       [ 7:0] scr_dout,
    input       [ 7:0] obj_dout,
    input       [ 7:0] pal_dout,
    output      [12:0] bus_addr,
    // communication with sound CPU
    output reg         snd_irq,
    output reg  [ 7:0] snd_latch,
    // ROM
    input              rom_ok,
    output reg         rom_cs,
    output      [15:0] rom_addr,
    input       [ 7:0] rom_data,
    // MCU ROM
    input       [10:0] prog_addr,
    input       [ 7:0] prog_data,
    input              prog_we
);

wire [15:0] cpu_addr;
reg  [ 7:0] cpu_din, cab_dout, mcu_dout, mcu_din;
reg         bank, bank_cs, io_cs, flip_cs,
            scrpos0_cs, scrpos1_cs,
            mcu_irq, mcu_stn,
            irq_clr, nmi_clr, mcu_clr, main2mcu_cs, mcu2main_cs;
wire        rdy, irqn, nmi_n;
wire [ 7:0] p1_out, p2_out; // for the MCU - not implemented yet

assign rom_addr = { cpu_addr[15], cpu_addr[15] ? cpu_addr[14] : bank, cpu_addr[13:0] };
assign rdy      = ~rom_cs | rom_ok;
assign bus_addr = cpu_addr[12:0];
assign nmi_n    = LVBL & dip_pause;

always @* begin
    rom_cs      = 0;
    ram_cs      = 0;
    objram_cs   = 0;
    scrram_cs   = 0;
    pal_cs      = 0;
    flip_cs     = 0;
    io_cs       = 0;
    irq_clr     = 0;
    nmi_clr     = 0;
    bank_cs     = 0;
    snd_irq     = 0;
    scrpos0_cs  = 0;
    scrpos1_cs  = 0;
    main2mcu_cs = 0;
    mcu2main_cs = 0;
    mcu_clr     = 0;
    if( cpu_addr[15:14]>= 1 ) begin
        rom_cs = 1;
    end else begin
        case( cpu_addr[13:11] )
            0,1,2,3: ram_cs = 1; // 8kB in total, the character VRAM is the upper 2kB. Merged in the same chips.
            4: objram_cs = 1;
            5: scrram_cs = 1; // 2kB
            6: pal_cs = 1;
            7: begin
                io_cs = 1;
                case( cpu_addr[2:0] )
                    0: scrpos0_cs = !cpu_rnw;
                    1: scrpos1_cs = !cpu_rnw;
                    2: snd_irq = !cpu_rnw;
                    3: flip_cs = !cpu_rnw;
                    4: begin
                        main2mcu_cs = !cpu_rnw;
                        mcu2main_cs =  cpu_rnw;
                    end
                    5: begin
                        bank_cs = !cpu_rnw;
                        mcu_clr =  cpu_rnw;
                    end
                    6: nmi_clr = 1;
                    7: irq_clr = 1;
                endcase
            end
        endcase
    end
end

always @(posedge clk) begin
    case( cpu_addr[1:0] )
        0: cab_dout <= { start, joystick1[5:4], joystick1[2], joystick1[3], joystick1[1:0] };
        1: cab_dout <= { coin,  joystick2[5:4], joystick2[2], joystick2[3], joystick2[1:0] };
        2: cab_dout <= { service, ~LVBL, mcu_stn, ~mcu_irq,
                        joystick2[6], joystick1[6], dipsw_b[1:0] };
        3: cab_dout <=  dipsw_a;
    endcase
end

always @* begin
    cpu_din = rom_cs      ? rom_data :
              ram_cs      ? ram_dout :
              objram_cs   ? obj_dout :
              scrram_cs   ? scr_dout :
              pal_cs      ? pal_dout :
              mcu2main_cs ? mcu_dout :
              io_cs       ? cab_dout : 8'hff;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank      <= 0;
        snd_latch <= 0;
        scrpos    <= 0;
        flip      <= 0;
    end else begin
        if( bank_cs ) bank <= cpu_dout[0];
        if( snd_irq ) snd_latch <= cpu_dout;
        if( scrpos0_cs ) scrpos[7:0] <= cpu_dout;
        if( scrpos1_cs ) scrpos[9:8] <= cpu_dout[1:0];
        if( flip_cs ) flip <= ~cpu_dout[0];
    end
end

jtframe_ff u_ff (
    .clk    ( clk       ),
    .rst    ( rst       ),
    .cen    ( cen_1p5   ),
    .din    ( 1'b1      ),
    .q      (           ),
    .qn     ( irqn      ),
    .set    ( 1'b0      ),
    .clr    ( irq_clr   ),
    .sigedge( v8        )
);

jtframe_mos6502 u_cpu(
    .rst    ( rst       ),
    .clk    ( clk       ),    // FPGA clock
    .cen    ( cen_3     ),    // 2x 6502 clock

    .so     ( 1'b1      ),
    .rdy    ( rdy       ),
    .nmi    ( nmi_n     ),
    .irq    ( irqn      ),
    .dbi    ( cpu_din   ),
    .dbo    ( cpu_dout  ),
    .rw     ( cpu_rnw   ),
    .sync   (           ),
    .ab     ( cpu_addr  )
);
/*
T65 u_cpu(
    .Mode   ( 2'd0      ),  // 6502 mode
    .Res_n  ( ~rst      ),
    .Enable ( cen_1p5   ),
    .Clk    ( clk       ),
    .Rdy    ( rdy       ),
    .Abort_n( 1'b1      ),
    .IRQ_n  ( irqn      ),
    .NMI_n  ( nmi_n     ),
    .SO_n   ( 1'b1      ),
    .R_W_n  ( cpu_rnw   ),
    .Sync   (           ),
    .EF     (           ),
    .MF     (           ),
    .XF     (           ),
    .ML_n   (           ),
    .VP_n   (           ),
    .VDA    (           ),
    .VPA    (           ),
    .A      ( cpu_addr  ),
    .DI     ( cpu_din   ),
    .DO     ( cpu_dout  )
);*/

wire [10:0] mcu_addr;
wire [ 7:0] mcu_data;
wire        mcu_wrn = p2_out[2];
wire        mcu_rdn = p2_out[1];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mcu_dout <= 0;
        mcu_din  <= 0;
        mcu_stn  <= 1;
        mcu_irq  <= 0;
    end else begin
        if( !mcu_wrn ) begin
            mcu_dout <= p1_out;
            mcu_stn  <= 0;
        end
        if( main2mcu_cs ) begin
            mcu_irq <= 1;
            mcu_din <= cpu_dout;
        end
        if( !mcu_rdn || mcu_clr ) begin
            mcu_irq <= 0;
        end
        if( mcu_clr ) mcu_stn <= 1;
    end
end
/*
jtframe_prom #(.aw(11)) u_mcu_prom (
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( prog_data ),
    .rd_addr( mcu_addr  ),
    .wr_addr( prog_addr ),
    .we     ( prog_we   ),
    .q      ( mcu_data  )
);

jtframe_6801mcu #(.MAXPORT(7),.ROMW(11)) u_mcu (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen_3         ),
    .wait_cen   (               ),
    .wrn        (               ),
    .vma        ( mcu_vma       ),
    .addr       (               ),
    .dout       (               ),
    .halt       ( 1'b0          ),
    .halted     (               ),
    .irq        ( mcu_irq       ), // active high
    .nmi        ( 1'b0          ),
    // Ports
    .p1_in      ( mcu_din       ),
    .p1_out     ( p1_out        ),
    .p2_in      ( 8'hff         ), // feed back p2_out for sims
    .p2_out     ( p2_out        ),
    .p3_in      ( {4'd0, 2'b11, mcu_stn, ~mcu_irq } ),
    .p3_out     (               ),
    .p4_in      ( 8'hff         ), // feed back p4_out for sims
    .p4_out     (               ),
    // external RAM
    .ext_cs     ( 1'b0          ),
    .ext_dout   (               ),
    // ROM interface
    .rom_addr   ( mcu_addr      ),
    .rom_data   ( mcu_data      ),
    .rom_cs     (               ),
    .rom_ok     ( 1'b1          )
);
*/
endmodule
