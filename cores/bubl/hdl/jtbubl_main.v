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
    Date: 1-06-2020 */

module jtbubl_main(
    input               rst,
    input               clk,
    input               cen6,
    input               cen3,
    input               cen4,

    // game selection
    input               tokio, bootleg,
    // Cabinet inputs
    input      [ 1:0]   cab_1p,
    input      [ 1:0]   coin,
    input      [ 5:0]   joystick1,
    input      [ 5:0]   joystick2,

    // Video interface
    output reg          vram_cs,
    output reg          pal_cs,
    output reg          black_n,
    output reg          flip,
    output     [12:0]   cpu_addr,
    output     [ 7:0]   cpu_dout,
    output              cpu_rnw,
    input      [ 7:0]   vram_dout,
    input      [ 7:0]   pal_dout,
    input               LVBL,

    // Sound interface
    input      [ 7:0]   main_latch,
    output reg [ 7:0]   snd_latch,
    output reg          snd_stb,
    input               snd_flag,
    input               main_stb,
    output              main_flag,
    output reg          snd_rst,

    // Main CPU ROM interface
    output     [17:0]   main_rom_addr,
    output reg          main_rom_cs,
    input               main_rom_ok,
    input      [ 7:0]   main_rom_data,

    // Sub CPU ROM interface
    output     [14:0]   sub_rom_addr,
    output reg          sub_rom_cs,
    input               sub_rom_ok,
    input      [ 7:0]   sub_rom_data,

    // MCU ROM interface
    output     [11:0]   mcu_rom_addr,
    output              mcu_rom_cs,
    input               mcu_rom_ok,
    input      [ 7:0]   mcu_rom_data,

    // DIP switches
    input               dip_pause,
    input               service,
    input               tilt,
    input      [ 7:0]   dipsw_a,
    input      [ 7:0]   dipsw_b,
    input      [ 7:0]   debug_bus
);

wire        cen_main, cen_sub;
reg  [ 7:0] main_din, sub_din;
wire [ 7:0] ram2sub, main_dout, sub_dout, comm2main, comm2mcu, mcu_dout,
            p1_in,
            p1_out, p3_out, p4_out;
wire [ 4:0] p2_out;
reg  [ 7:0] p3_in, rammcu_din;
reg  [ 7:0] cab_dout;
reg         h1;
wire [11:0] mcu_bus;
wire [15:0] main_addr, sub_addr;
wire        main_mreq_n, main_iorq_n, main_rdn, main_wrn, main_rfsh_n;
wire        sub_mreq_n,  sub_iorq_n,  sub_rd_n,  sub_wrn, sub_halt_n;
wire        mcu_stn, mcu_irqn;
reg         rammcu_we, rammcu_cs;
reg         main_work_cs, mcram_cs, // shared memories
            tres_cs,  // watchdog reset
            main2sub_nmi, mcu_cs,
            misc_cs, sound_cs,
            cabinet_cs, flip_cs;
reg         sub_work_cs;
wire        mcram_we, sub_int_n, main_int_n;
reg  [ 2:0] bank;
reg         main_rst_n, sub_rst_n, mcu_rst;
reg  [ 7:0] wdog_cnt, int_vector;
reg         last_VBL;

wire [ 7:0] work2main_dout, work2sub_dout;
wire        sub_m1_n, main_m1_n;
wire        cen_mcu = tokio ? cen3 : cen4;

wire        main_halt_n;
reg         lde, sde; // original signal names: lde = main drives, sde = sub drives
wire        VBL_gated;
wire        sub_int_ack, main_int_ack;

assign      sub_int_ack = ~sub_iorq_n & ~sub_m1_n;
assign      main_int_ack = ~main_iorq_n & ~main_m1_n;


assign      VBL_gated    = ~LVBL & dip_pause;
assign      main_rom_addr = main_addr[15] ?
                        { { {1'b0, bank}+4'b10} , main_addr[13:0] } : // banked
                        { 3'd0, main_addr[14:0] }; // not banked
assign      sub_rom_addr = sub_addr[14:0];
assign      mcram_we     = mcram_cs && !main_wrn;
assign      cpu_addr     = main_addr[12:0];
assign      cpu_dout     = main_dout;
assign      cpu_rnw      = main_wrn;
assign      p1_in[7:4]   = 4'hf;
assign      p1_in[3:2]   = ~coin;
assign      p1_in[1:0]   = { service, tilt };
assign      mcu_bus      = { p2_out[3:0], p4_out };

// Watchdog and main CPU reset
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        main_rst_n <= 0;
        wdog_cnt   <= 8'd0;
    end else begin
        last_VBL  <= VBL_gated;
        if( tres_cs )
            wdog_cnt <= 8'd0;
        else if( !VBL_gated && last_VBL ) wdog_cnt <= wdog_cnt + 8'd1;
        main_rst_n <= ~wdog_cnt[7];
    end
end

// Main CPU address decoder
always @(*) begin
    main_rom_cs    = !main_mreq_n && (!main_addr[15] || main_addr[15:14]==2'b10); // 0000-7FFF and 8000-BFFF
    vram_cs        = !main_mreq_n && main_addr[15:13]==3'b110; // C000-DCFF
    main_work_cs   = !main_mreq_n && main_addr[15:13]==3'b111 && main_addr[12:11]!=2'b11; //E000-F7FF
    pal_cs         = !main_mreq_n && main_addr[15: 9]==7'b1111_100; // F800-F9FF
    if( tokio ) begin
        sound_cs    = !main_mreq_n && main_addr[15: 8]==8'hFC && !main_addr[7];
        misc_cs     = !main_mreq_n && main_addr[15: 8]==8'hFA &&  main_addr[7] && !main_wrn;
        flip_cs     = !main_mreq_n && main_addr[15: 8]==8'hFB && !main_addr[7] && !main_wrn;
        main2sub_nmi= !main_mreq_n && main_addr[15: 8]==8'hFB &&  main_addr[7] && !main_wrn;
        tres_cs     = !main_mreq_n && main_addr[15: 8]==8'hFA && !main_addr[7]; // watchdog
        mcu_cs      = !main_mreq_n && main_addr[15: 9]==7'b1111_111; // FE
        mcram_cs    = 0;
        cabinet_cs  = !main_mreq_n && main_addr[15: 7]==9'b1111_1010_0 && main_wrn;
    end else begin // Bubble Bobble
        sound_cs    = !main_mreq_n && main_addr[15: 8]==8'hFA && !main_addr[7];
        misc_cs     = !main_mreq_n && main_addr[15: 8]==8'hFB && main_addr[7:6]==2'b01 && !main_wrn;
        flip_cs     = 0; // misc_cs used instead
        main2sub_nmi= !main_mreq_n && main_addr[15: 8]==8'hFB && main_addr[7:6]==2'b00 && !main_wrn;
        tres_cs     = !main_mreq_n && main_addr[15: 8]==8'hFA && main_addr[7];
        mcram_cs    = !main_mreq_n && main_addr[15:10]==6'b1111_11; // FC
        mcu_cs      = 0;
        cabinet_cs  = 0;
    end
end

// Main CPU input mux
always @(posedge clk) begin
    main_din <=
        main_rom_cs ? main_rom_data :
        vram_cs     ? vram_dout     :
        pal_cs      ? pal_dout      :
        main_work_cs? work2main_dout:
        mcram_cs    ? comm2main     :
        !main_iorq_n? int_vector    :
        sound_cs    ? (main_addr[0] ? { 6'h3f, main_flag, snd_flag } : main_latch) :
        cabinet_cs  ? cab_dout :
        mcu_cs      ? (bootleg ? 8'hbf : mcu_dout) :
        8'hff;
end

// Main CPU miscellaneous control bits
always @(posedge clk ) begin
    if( !main_rst_n ) begin
        bank      <= 3'd0;
        sub_rst_n <= 0;
        mcu_rst   <= 1;
        black_n   <= 0;
        flip      <= 0;
    end else begin
        if(misc_cs) begin
            bank      <= tokio ? cpu_dout[2:0] : (cpu_dout[2:0]^3'b100);
            black_n   <= cpu_dout[6];
            if(!tokio) begin
                sub_rst_n <= cpu_dout[4];
                mcu_rst   <= ~cpu_dout[5];
                if( cpu_dout[5]  &&  mcu_rst ) $display("MCU reset over");
                if( ~cpu_dout[5] && ~mcu_rst ) $display("MCU reset");
            end else begin
                sub_rst_n <= 1;
                mcu_rst   <= 1;
            end
        end
        if( tokio ? flip_cs : misc_cs )
            flip <= cpu_dout[7];
    end
end

// Communication with sound CPU
always @(posedge clk ) begin
    if( !main_rst_n ) begin
        snd_latch <= 8'd0;
        snd_rst   <= 0;
        snd_stb   <= 0;
    end else if(sound_cs) begin
        snd_stb <= !main_wrn && cpu_addr[1:0]==2'b00;
        if( !main_wrn )
            case( cpu_addr[1:0] )
                2'b00: snd_latch <= main_dout;
                2'b11: snd_rst   <= main_dout[0];
                default:;
            endcase
    end else snd_stb <= 0;
end

jtframe_ff u_flag(
    .clk    ( clk                    ),
    .rst    ( main_rst_n             ),
    .cen    ( 1'b1                   ),
    .din    ( 1'b0                   ),
    .q      (                        ),
    .qn     ( main_flag              ),
    .set    ( sound_cs && !main_rdn  ),
    .clr    ( 1'b0                   ),
    .sigedge( main_stb               )
);

// Sub CPU address decoder
always @(*) begin
    sub_rom_cs     = !sub_mreq_n && !sub_addr[15];
    if(tokio)
        sub_work_cs    = !sub_mreq_n &&  sub_addr[15:13]==3'b100;
    else // Bubble Bobble
        sub_work_cs    = !sub_mreq_n &&  sub_addr[15:13]==3'b111;
end

// Sub CPU input mux
always @(posedge clk) begin
    sub_din <= sub_rom_cs  ? sub_rom_data : (
               sub_work_cs ? work2sub_dout : 8'hff );
end
/*
always @(*) begin
    work_din = lde ? main_dout : sub_dout;
    work_we  = lde ? ~main_wrn : ~sub_wrn;
    work_addr= lde ? main_addr[12:0] : sub_addr[12:0];
end
*/
// Time shared
jtframe_dual_ram #(.AW(13)) u_work(
    .clk0   ( clk             ),
    .data0  ( main_dout       ),
    .addr0  ( main_addr[12:0] ),
    .we0    ( ~main_wrn & lde ),
    .q0     ( work2main_dout  ),
    // Sub CPU
    .clk1   ( clk             ),
    .data1  ( sub_dout        ),
    .addr1  ( sub_addr[12:0]  ),
    .we1    ( ~sub_wrn & sub_work_cs       ),
    .q1     ( work2sub_dout   )
);

/////////////////////////////////////////
// Main CPU

// H1 is used on the original PCB to divide access to the
// video memory
// When H1 is high, the main CPU is forced to wait before
// accessing the VRAM

always @(posedge clk, posedge rst) begin
    if( rst )
        h1 <= 0;
    else if(cen6) h1<=~h1;
end

always @(posedge clk, negedge main_rst_n) begin
    if( !main_rst_n )
        lde <= 0;
    else begin
        lde <= main_work_cs;
    end
end

always @(posedge clk, negedge sub_rst_n) begin
    if( !sub_rst_n )
        sde <= 0;
    else begin
        if( !sub_work_cs )
            sde <= 0;
        else if( !main_work_cs ) sde <= 1;
    end
end

jtframe_z80 u_maincpu(
    .rst_n    ( main_rst_n     ),
    .clk      ( clk            ),
    .cen      ( cen_main       ),
    .wait_n   ( 1'b1           ),
    .int_n    ( main_int_n     ),
    .nmi_n    ( 1'b1           ),
    .busrq_n  ( 1'b1           ),
    .m1_n     ( main_m1_n      ),
    .mreq_n   ( main_mreq_n    ),
    .iorq_n   ( main_iorq_n    ),
    .rd_n     ( main_rdn       ),
    .wr_n     ( main_wrn       ),
    .rfsh_n   ( main_rfsh_n    ),
    .halt_n   ( main_halt_n    ),
    .busak_n  (                ),
    .A        ( main_addr      ),
    .din      ( main_din       ),
    .dout     ( main_dout      )
);

jtframe_z80wait #(.DEVCNT(2),.RECOVERY(0)) u_mainwait(
    .rst_n    ( main_rst_n      ),
    .clk      ( clk             ),
    .cen_in   ( cen6            ),
    .cen_out  ( cen_main        ),
    .gate     (                 ),
    // cycle recovery
    .mreq_n   ( main_mreq_n     ),
    .iorq_n   ( main_iorq_n     ),
    .busak_n  ( 1'b1            ),
    .dev_busy ( { vram_cs & h1, sde & main_work_cs }    ),
    // SDRAM gating managed in mem.yaml
    .rom_cs   ( 1'b0            ),
    .rom_ok   ( 1'b1            )
);

/////////////////////////////////////////
// Sub CPU

jtframe_z80 u_subcpu(
    .rst_n    ( sub_rst_n      ),
    .clk      ( clk            ),
    .cen      ( cen_sub        ),
    .wait_n   ( 1'b1           ),
    .int_n    ( sub_int_n      ),
    .nmi_n    ( ~main2sub_nmi  ),
    .busrq_n  ( 1'b1           ),
    .m1_n     ( sub_m1_n       ),
    .mreq_n   ( sub_mreq_n     ),
    .iorq_n   ( sub_iorq_n     ),
    .rd_n     ( sub_rd_n       ),
    .wr_n     ( sub_wrn        ),
    .rfsh_n   (                ),
    .halt_n   ( sub_halt_n     ),
    .busak_n  (                ),
    .A        ( sub_addr       ),
    .din      ( sub_din        ),
    .dout     ( sub_dout       )
);

jtframe_z80wait #(.DEVCNT(1),.RECOVERY(0)) u_subwait(
    .rst_n    ( sub_rst_n       ),
    .clk      ( clk             ),
    .cen_in   ( cen6            ),
    .cen_out  ( cen_sub         ),
    .gate     (                 ),
    // cycle recovery
    .mreq_n   ( sub_mreq_n      ),
    .iorq_n   ( sub_iorq_n      ),
    .busak_n  ( 1'b1            ),
    .dev_busy ( (main_work_cs & ~sde) & sub_work_cs ),
    // SDRAM gating managed in mem.yaml
    .rom_cs   ( 1'b0            ),
    .rom_ok   ( 1'b1            )
);

jtframe_ff u_subint(
    .rst    ( ~sub_rst_n    ),
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .din    ( 1'b1          ),
    .q      (               ),
    .qn     ( sub_int_n     ),
    .set    ( 1'b0          ),
    .clr    ( sub_int_ack   ),
    .sigedge( VBL_gated     )
);

/////////////////////////////////////////
// MCU

jtframe_ff u_mcu2main (
    .clk    ( clk          ),
    .rst    ( tokio ? ~main_rst_n : mcu_rst ),
    .cen    ( 1'b1           ),
    .din    ( 1'b1           ),
    .q      (                ),
    .qn     ( main_int_n     ),
    .set    ( 1'b0           ),
    .clr    ( main_int_ack   ),
    // This is a jumper on the schematics
    // it can come from P1[6] or from VBL
    .sigedge( tokio ? VBL_gated : p1_out[6] )
);

// Time shared
jtframe_dual_ram #(.AW(10)) u_comm(
    .clk0   ( clk              ),
    .clk1   ( clk              ),
    // Main CPU
    .addr0  ( main_addr[9:0]     ),
    .data0  ( main_dout          ),
    .we0    ( mcram_we           ),
    .q0     ( comm2main          ),
    // MCU
    .addr1  ( mcu_bus[9:0]       ),
    .data1  ( rammcu_din         ),
    .we1    ( rammcu_we          ),
    .q1     ( comm2mcu           )
);

// Bubble Bobble handles the input ports via the MCU
always @(posedge clk) begin
    if( rammcu_cs )
        p3_in <= comm2mcu;
    else begin
        case( mcu_bus[1:0] )
            2'd0: p3_in <= dipsw_a;
            2'd1: p3_in <= dipsw_b;
            2'd2: p3_in <= {1'b1, cab_1p[0], joystick1[5:0] };
            2'd3: p3_in <= {1'b1, cab_1p[1], joystick2[5:0] };
        endcase // mcu_bus[1:0]
    end
end

// This is used for Tokio
always @(posedge clk) begin
    case( main_addr[2:0] )
        3'd3: cab_dout <= dipsw_a;
        3'd4: cab_dout <= dipsw_b;
        3'd5: cab_dout <= {2'b11,
            mcu_stn, mcu_irqn,
            coin, service, tilt };
        3'd6: cab_dout <= {1'b1, cab_1p[0], joystick1[5:0] };
        3'd7: cab_dout <= {1'b1, cab_1p[1], joystick2[5:0] };
        default: cab_dout <= 8'hff;
    endcase
end

reg [5:0] clrcnt;
reg       last_sub_int_n;
reg       mcuirq;

always @(posedge clk) begin
    if( mcu_rst ) begin
        clrcnt <= 0;
        last_sub_int_n <= 1;
        mcuirq <= 0;
    end else if(cen_mcu) begin
        last_sub_int_n <= sub_int_n;
        if( last_sub_int_n && !sub_int_n ) begin
            clrcnt <= 0;
            mcuirq <= 1;
        end else if(mcuirq) begin
            clrcnt<=clrcnt+1'd1;
            if(&clrcnt) mcuirq<=0;
        end
    end
end

wire rammcu_clk = p2_out[4];
reg  last_rammcu_clk;
wire mcu_posedge = !last_rammcu_clk && rammcu_clk;

always @(posedge clk) begin
    if( mcu_rst ) begin
        rammcu_cs       <= 0;
        rammcu_we       <= 0;
        last_rammcu_clk <= 1;
        rammcu_din      <= 8'd0;
        int_vector      <= 8'h2e;
    end else if(cen_mcu) begin
        last_rammcu_clk <= rammcu_clk;
        if( mcu_posedge ) begin
            if( mcu_bus[11:10]==2'b11 ) begin
                rammcu_cs  <= 1;
                rammcu_we  <= !p1_out[7];
                rammcu_din <= p3_out;
                if( mcu_bus[9:0]==10'd0 ) int_vector <= p3_out;
            end else begin
                rammcu_cs <= 0;
                rammcu_we <= 0;
            end
        end else begin
            //rammcu_cs <= 0;
            rammcu_we <= 0;
        end
    end
end

reg         rst01, rst05;
wire        rom01_cs, rom05_cs;
wire [11:0] rom01_a;
wire [10:0] rom05_a;

assign mcu_rom_cs  = tokio ? 1'b1           : rom01_cs;
assign mcu_rom_addr= tokio ? {1'b0,rom05_a} : rom01_a;
always @(posedge clk) { rst01, rst05 } <= { tokio, ~tokio } | {mcu_rst,rst};

jtframe_6801mcu #(.MODE(7)) u_mcu01 ( // MC6801U4
    .rst        ( rst01         ),
    // .rst( rst ), // for quick sims
    .clk        ( clk           ),
    .cen        ( cen_mcu       ),
    .wr         (               ),
    .addr       (               ),
    .dout       (               ),
    .irq        ( mcuirq        ), // relies on sub CPU to clear it
    .nmi        ( 1'b0          ),
    .xdin       ( 8'd0          ),
    .x_cs       (               ),
    .ba         (               ),
    // Ports
    .p1_din     ( p1_in         ),
    .p1_dout    ( p1_out        ),
    .p2_din     ( 5'h1f         ), // feed back p2_out for sims
    .p2_dout    ( p2_out        ),
    .p3_din     ( p3_in         ),
    .p3_dout    ( p3_out        ),
    .p4_din     ( 8'hff         ), // feed back p4_out for sims
    .p4_dout    ( p4_out        ),
    // ROM interface
    .rom_addr   ( rom01_a       ),
    .rom_data   ( mcu_rom_data  ),
    .rom_cs     ( rom01_cs      )
);

jtkunio_mcu u_mcu05(
    .rst        ( rst05         ),
    .clk        ( clk           ),
    .cen        ( cen_mcu       ),
    .rd         ( mcu_cs & ~main_rdn ),
    .wr         ( mcu_cs & ~main_wrn ),
    .clr        ( 1'b0          ),
    .cpu_dout   ( main_dout     ),
    .dout       ( mcu_dout      ),
    .stn        ( mcu_stn       ),
    .irqn       ( mcu_irqn      ),
    // ROM
    .rom_addr   ( rom05_a       ),
    .rom_data   ( mcu_rom_data  )
);

endmodule