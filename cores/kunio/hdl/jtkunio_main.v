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
    Date: 30-7-2022 */

module jtkunio_main(
    input              clk,        // 24 MHz
    input              rst,
    input              cen3,
    input              cen1p5,
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
    output      [10:0] mcu_addr,
    input       [ 7:0] mcu_data
);
`ifndef NOMAIN
wire [15:0] cpu_addr;
reg  [ 7:0] cpu_din, cab_dout;
wire [ 7:0] mcu_dout;
reg         bank, bank_cs, io_cs, flip_cs,
            scrpos0_cs, scrpos1_cs,
            irq_clr, nmi_clr, mcu_clr, main2mcu_cs, mcu2main_cs;
wire        rdy, irqn, nmi_n,
            mcu_stn, mcu_irqn;

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
                        // if( !mcu_stn ) $display("Rd %X from MCU",mcu_dout);
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
        2: cab_dout <= { service, ~LVBL, mcu_stn, mcu_irqn,
                        joystick2[6], joystick1[6], dipsw_b[1:0] };
        3: cab_dout <=  dipsw_a;
    endcase
end

always @(posedge clk) begin
    cpu_din <=rom_cs      ? rom_data :
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
    .cen    ( cen1p5    ),
    .din    ( 1'b1      ),
    .q      (           ),
    .qn     ( irqn      ),
    .set    ( 1'b0      ),
    .clr    ( irq_clr   ),
    .sigedge( v8        )
);

wire [7:0] nc;
/* verilator tracing_off */
T65 u_cpu(
    .Mode   ( 2'd0      ),  // 6502 mode
    .Res_n  ( ~rst      ),
    .Enable ( cen1p5    ),
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
    .A      ({nc,cpu_addr}),
    .DI     ( cpu_din   ),
    .DO     ( cpu_dout  )
);

jtkunio_mcu u_mcu(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen3          ),
    .rd         ( mcu2main_cs   ),
    .wr         ( main2mcu_cs   ),
    .clr        ( mcu_clr       ),
    .cpu_dout   ( cpu_dout      ),
    .dout       ( mcu_dout      ),
    .stn        ( mcu_stn       ),
    .irqn       ( mcu_irqn      ),
    // ROM
    .rom_addr   ( mcu_addr      ),
    .rom_data   ( mcu_data      )
);

`else
    initial rom_cs   = 0;
    assign  pal_cs   = 0;
    assign  ram_cs   = 0;
    assign  objram_cs= 0;
    assign  scrram_cs= 0;
    assign  snd_irq  = 0;
    assign  snd_latch= 0;
    assign  rom_addr = 0;
    assign  mcu_addr = 0;
    assign  cpu_addr = 0;
    assign  cpu_rnw  = 1;
    assign  cpu_dout = 0;
    assign  scrpos   = 10'h180;
    assign  flip     = 0;
`endif
endmodule
