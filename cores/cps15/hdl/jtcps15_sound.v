/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
(*keep*)     but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 19-9-2020 */

module jtcps15_sound(
    input             rst,
    input             clk96,
    input             clk48,
    input             cen8,
    input             vol_up,
    input             vol_down,
    output reg [12:0] volume, // volume moves in 2dB steps
    // Decode keys
    input             kabuki_we,
    input             kabuki_en,

    // Interface with main CPU
    input      [23:1] main_addr,
    input      [ 7:0] main_dout,
    output reg [ 7:0] main_din,
    input             main_ldswn,
    input             main_buse_n,
    output            main_busakn,
    output            main_waitn,

    // ROM
    output reg [18:0] rom_addr, // 512 kByte
    output reg        rom_cs,
    input      [ 7:0] rom_data,
    input             rom_ok,

    // QSound sample ROM
    output reg [22:0] qsnd_addr, // max 8 MB.
    output            qsnd_cs,
    input      [ 7:0] qsnd_data,
    input             qsnd_ok,

    // ROM programming interface
    input      [12:0] prog_addr,
    input      [ 7:0] prog_data,
    input             prog_we,

    // Sound output
    output signed [15:0] left,
    output signed [15:0] right,
    output               sample
);

wire        cpu_cen, cen_extra;
wire [ 7:0] dec_dout, ram_dout, cpu_dout, bus_din;
wire [15:0] A, bus_A;
reg  [ 3:0] bank;
reg  [ 7:0] cpu_din;
reg         rstn;
reg         ram_cs, bank_cs, qsnd_wr, qsnd_rd;
wire        ram_we, int_n, mreq_n, wr_n, rd_n, m1_n, iorq_n;
wire        busrq_n, busak_n, halt_n, z80_buswn;
wire        bus_wrn, bus_mreqn, main_busn;
reg         main_busn_dly;

// QSound registers
reg         [23:0] cpu2dsp;
reg                dsp_irq; // UR6B in schematics
reg         [ 1:0] dsp_datasel;
reg  signed [15:0] reg_left, reg_right, pre_l, pre_r;
wire signed [15:0] fxd_l, fxd_r;
wire               resample48;

// DSP16 wires
wire [15:0] dsp_ab, dsp_pbus_out;
reg  [15:0] dsp_pbus_in;
wire        dsp_pods_n, dsp_pids_n;
wire        dsp_do, dsp_ock, dsp_doen;
wire        dsp_iack, dsp_ext_rq;
reg         dsp_rst;
wire        dsp_psel, dsp_sadd, dsp_rdy_n;
wire        dsp_cen_cko;
wire        cen_dsp;
reg         base_sample;

reg         last_pids_n;
reg         rom_okl, last_romcs;

`ifndef NOSOUND
assign      dsp_rdy_n = ~(dsp_irq | dsp_iack);
assign      dsp_doen  = 1; // ignored by dsp16

jtcps15_qsnd_cen u_dspcen(
    .clk96       ( clk96       ),
    .clk48       ( clk48       ),
    .rst         ( rst         ),
    .base_sample ( base_sample ),
    .qsnd_ok     ( qsnd_ok     ),
    .ext_rq      ( dsp_ext_rq  ),
    .qsnd_cen    ( cen_dsp     ),
    // sound resample
    .l_in        ( pre_l       ),
    .r_in        ( pre_r       ),
    .l_out       ( fxd_l       ),
    .r_out       ( fxd_r       ),
    .resample48  ( resample48  )
);

`else
reg rdy_reads, last_rd;
assign      dsp_rdy_n = rdy_reads;

always @(posedge clk48, posedge rst) begin
    if( rst ) begin
        rdy_reads <= 0;
        last_rd   <= 0;
    end else begin
        last_rd <= qsnd_rd;
        if( !qsnd_rd && last_rd ) rdy_reads <= ~rdy_reads;
    end
end
`endif

`ifdef SIMULATION
wire bank_access = rom_cs & A[15];
`endif

reg [1:0] ram_ok;
reg  main_busnl;
wire bus_equ;

assign bus_equ     = main_busn == main_busnl;
assign ram_we      = ram_cs && !bus_wrn;
assign bus_A       = main_busn ?        A : main_addr[16:1];
assign bus_wrn     = main_busn ?     wr_n : main_ldswn;
assign bus_din     = main_busn ? cpu_dout : main_dout;
assign bus_mreqn   = main_busn ?   mreq_n : main_buse_n;
assign main_busakn = main_busn_dly | main_busn | busrq_n |
    //(rom_cs & ~(rom_ok & rom_okl)) |
    (rom_cs & ~last_romcs);
assign main_waitn  = rom_cs ? rom_ok & rom_okl : bus_equ & ram_ok[0];

always @(posedge clk48) begin
    main_busnl <= main_busn;
    ram_ok <= { ram_ok[0] & bus_equ, bus_equ };
    if(!main_busn) main_din <= cpu_din; // bus output
    main_busn_dly <= main_busn;
    rom_okl    <= rom_ok;
    last_romcs <= rom_cs;
end

always @(negedge clk48) begin
    rstn <= ~rst;
end

//always @(posedge clk48, posedge rst) begin
always @(*) begin
    //if ( rst ) begin
    //    rom_cs    <= 0;
    //    rom_addr  <= 16'd0;
    //    ram_cs    <= 0;
    //    bank_cs   <= 0;
    //    qsnd_wr   <= 0;
    //    qsnd_rd   <= 0;
    //end else begin
        rom_cs  = !bus_mreqn && (!bus_A[15] || bus_A[15:14]==2'b10);
        //if(!bus_mreqn) begin
        rom_addr = (bus_A[15] ? ({ 1'b0, bank, bus_A[13:0] } + 19'h8000) : { 4'b0, bus_A[14:0] });
//            rom_addr = (~mreq_n & main_busakn) ?
//                // Z80
//                (bus_A[15] ? ({ 1'b0, bank, bus_A[13:0] } + 19'h8000) : { 4'b0, bus_A[14:0] }) :
//                // M68000
//                main_addr[19:1];
        //end
        ram_cs   = !bus_mreqn && (bus_A[15:12] == 4'hc || bus_A[15:12]==4'hf);
        qsnd_wr  = !bus_mreqn && !bus_wrn && (bus_A[15:12] == 4'hd && bus_A[2:0]<=3'd2);
        bank_cs  = !bus_mreqn && !bus_wrn && (bus_A[15:12] == 4'hd && bus_A[2:0]==3'd3);
        qsnd_rd  = !bus_mreqn && !rd_n && (bus_A[15:12] == 4'hd && bus_A[2:0]==3'd7);
   // end
end

// wire qs0l_w = qsnd_wr && A[2:0]==2'd0;
// wire qs0h_w = qsnd_wr && A[2:0]==2'd1;
wire qs1l_w = qsnd_wr && A[2:0]==2;
reg [23:0] cpu2dsp_s;

always @(posedge clk48, posedge rst) begin
    if ( rst ) begin
        bank    <= 4'd0;
        cpu2dsp <= 24'd0;
        dsp_rst <= 1;
    end else begin
        if( bank_cs ) begin
            bank    <= bus_din[3:0];
            dsp_rst <= ~bus_din[7];
        end
        if( qsnd_wr ) begin
            case( A[2:0] )
                0: cpu2dsp[15: 8] <= bus_din; // data word MSB
                1: cpu2dsp[ 7: 0] <= bus_din; // data word LSB
                2: cpu2dsp[23:16] <= bus_din; // address
                default:;
            endcase // A[2:0]
        end
    end
end

always @(*) begin
    cpu_din =  rom_cs ? ( A[15] ? rom_data : dec_dout ) : (
               ram_cs ? ram_dout : (
              qsnd_rd ? { dsp_rdy_n, 3'b111, bank } : 8'hff
              ));
end

assign busrq_n = main_buse_n;
assign main_busn = busak_n;

jtcps15_z80int u_z80int(
    .clk    ( clk48     ),
    .rst    ( rst       ),
    .cen8   ( cen8      ),
    .m1_n   ( m1_n      ),
    .iorq_n ( iorq_n    ),
    .int_n  ( int_n     )
);

jtcps15_z80wait u_extrawait(
    .clk    ( clk48     ),
    .rst    ( rst       ),
    .cen8   ( cen8      ),
    .m1_n   ( m1_n      ),
    .addr   ( A[15:12]  ),
    .cen_cpu( cen_extra )
);

jtframe_ram #(.AW(13)) u_z80ram( // 8 kB!
    .clk    ( clk48         ),
    .cen    ( 1'b1          ),
    .data   ( bus_din       ),
    .addr   ( bus_A[12:0]   ),
    .we     ( ram_we        ),
    .q      ( ram_dout      )
);

jtframe_kabuki u_kabuki(
    .clk        ( clk48       ),    // Uses same clock as u_prom_we
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .rd_n       ( rd_n        ),
    .addr       ( A           ),
    .din        ( rom_data    ),
    .en         ( kabuki_en   ),
    // Decode keys
    .prog_data  ( prog_data   ),
    .prog_we    ( kabuki_we   ),
    .dout       ( dec_dout    )
);

jtframe_z80_romwait u_cpu(
    .rst_n      ( rstn        ),
    .clk        ( clk48       ),
    .cen        ( cen_extra   ),
    .cpu_cen    ( cpu_cen     ),
    .int_n      ( int_n       ),
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( busrq_n     ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     (             ),
    .halt_n     ( halt_n      ),
    .busak_n    ( busak_n     ),
    .A          ( A           ),
    .din        ( cpu_din     ),
    .dout       ( cpu_dout    ),
    // manage access to ROM data from SDRAM
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);

reg last_vol_up, last_vol_down;
reg last_sadd, last_pods_n;
reg audio_ws;
reg dsp_dsel96;

// DSP16 glue logic
always @(posedge clk48, posedge rst) begin
    if ( rst ) begin
        dsp_irq    <= 0;
        dsp_datasel<= 2'd0;
    end else begin
        last_pids_n <= dsp_pids_n;
        if( qs1l_w ) begin
            dsp_irq <= 1; // read MSB
            dsp_datasel <= 2'b11;
        end else begin
            if( dsp_pids_n && !last_pids_n ) begin
                dsp_irq <= 0; // read LSB
                dsp_datasel <= dsp_datasel>>1;
            end
        end
    end
end

// The uprate filter runs at 48MHz to ease synthesis
`ifndef NOFIR
jtframe_uprate2_fir uprate(
    .rst     ( dsp_rst       ),
    .clk     ( clk48         ),
    .sample  ( resample48    ),
    .upsample( sample        ),
    .l_in    ( fxd_l         ),
    .r_in    ( fxd_r         ),
    .l_out   ( left          ),
    .r_out   ( right         )
);
`else
assign sample = resample48;
assign left   = fxd_l;
assign right  = fxd_r;
`endif

reg [12:0] vol_lut[0:39];
reg [ 5:0] vol_st;

initial begin
    vol_lut[ 0]=13'h1010; vol_lut[ 1]=13'h1008; vol_lut[ 2]=13'h1004; vol_lut[ 3]=13'h1002;
    vol_lut[ 4]=13'h1001; vol_lut[ 5]=13'h0810; vol_lut[ 6]=13'h0808; vol_lut[ 7]=13'h0804;
    vol_lut[ 8]=13'h0802; vol_lut[ 9]=13'h0801; vol_lut[10]=13'h0410; vol_lut[11]=13'h0408;
    vol_lut[12]=13'h0404; vol_lut[13]=13'h0402; vol_lut[14]=13'h0401; vol_lut[15]=13'h0210;
    vol_lut[16]=13'h0208; vol_lut[17]=13'h0204; vol_lut[18]=13'h0202; vol_lut[19]=13'h0201;
    vol_lut[20]=13'h0110; vol_lut[21]=13'h0108; vol_lut[22]=13'h0104; vol_lut[23]=13'h0102;
    vol_lut[24]=13'h0101; vol_lut[25]=13'h0090; vol_lut[26]=13'h0088; vol_lut[27]=13'h0084;
    vol_lut[28]=13'h0082; vol_lut[29]=13'h0081; vol_lut[30]=13'h0050; vol_lut[31]=13'h0048;
    vol_lut[32]=13'h0044; vol_lut[33]=13'h0042; vol_lut[34]=13'h0041; vol_lut[35]=13'h0030;
    vol_lut[36]=13'h0028; vol_lut[37]=13'h0024; vol_lut[38]=13'h0022; vol_lut[39]=13'h0021;
end

// volume control
always @(posedge clk48, posedge rst) begin
    if ( rst ) begin
        volume     <= 13'b0;   // I think the volume is never actually read by the DSP
        vol_st     <= 6'd39;   // Max
    end else begin
        last_vol_up   <= vol_up;
        last_vol_down <= vol_down;
        if( vol_up && !last_vol_up ) begin
            if( vol_st < 6'd39 ) vol_st <= vol_st+6'd1;
        end else if( vol_down && !last_vol_down ) begin
            if( vol_st != 6'd0 ) vol_st <= vol_st-6'd1;
        end
        volume <= vol_lut[vol_st];
    end
end

reg [15:0] ser_cnt;
reg        dsp_ockl;
reg        left_done, right_done;

always @(posedge clk96, posedge rst) begin
    if ( rst ) begin
        audio_ws   <= 0;
        qsnd_addr  <= 23'd0;
        base_sample<= 0;
        dsp_dsel96 <= 0;
        pre_l      <= 16'd0;
        pre_r      <= 16'd0;
        cpu2dsp_s  <= 24'd0;
    end else begin
        last_pods_n <= dsp_pods_n;
        dsp_dsel96  <= dsp_datasel[1];
        dsp_ockl    <= dsp_ock;

        // latch sound data like the TDA1543 would
        last_sadd <= dsp_sadd;
        if( dsp_irq ) cpu2dsp_s <= cpu2dsp;
        if( !dsp_sadd && last_sadd ) begin
            audio_ws <= dsp_psel;
            ser_cnt  <= 16'hffff;
        end
        if( dsp_ockl & ~dsp_ock & ser_cnt[15] ) begin
            ser_cnt <= ser_cnt << 1;
            if( audio_ws ) begin
                reg_right <= { reg_right[14:0], dsp_do };
                if( !ser_cnt[14] ) right_done <= 1;
            end else begin
                reg_left <= { reg_left[14:0], dsp_do };
                if( !ser_cnt[14] ) left_done <= 1;
            end
        end
        if( left_done & right_done ) begin
            pre_l <= reg_left;
            pre_r <= reg_right;
            base_sample <= 1;
            left_done  <= 0;
            right_done <= 0;
        end else begin
            base_sample <= 0;
        end
        // latch QSound ROM address
        if( dsp_pods_n && !last_pods_n) begin
            qsnd_addr[15:0] <= dsp_pbus_out;
        end
        if( dsp_ab[15] && dsp_cen_cko ) begin
            qsnd_addr[22:16] <= dsp_ab[6:0];/*{ dsp_ab[2:0], dsp_ab[4], dsp_ab[5],
                dsp_ab[6], dsp_ab[7] };*/
        end
    end
end

always @(*) begin
    dsp_pbus_in = dsp_dsel96 ? {8'd0, cpu2dsp_s[23:16]} : cpu2dsp_s[15:0];
end

`ifndef NOSOUND
wire        dsp_fault;

assign qsnd_cs = 1;

jtdsp16 u_dsp16(
    .rst        ( dsp_rst       ),
    .clk        ( clk96         ),
    .clk_en     ( cen_dsp       ),

    .cen_cko    ( dsp_cen_cko   ),
    .ab         ( dsp_ab        ),  // address bus
    .rb_din     ( { qsnd_data, 8'h0 } ),  // ROM data bus
    .ext_rq     ( dsp_ext_rq    ),
    .ext_ok     ( qsnd_ok       ),
    // Parallel I/O
    .pbus_in    ( dsp_pbus_in   ),
    .pbus_out   ( dsp_pbus_out  ),
    .pods_n     ( dsp_pods_n    ),  // parallel output data strobe
    .pids_n     ( dsp_pids_n    ),  // parallel input  data strobe
    // Serial output
    .sdo        ( dsp_do        ),  // serial data output
    .ock        ( dsp_ock       ),  // output clock
    .doen       ( dsp_doen      ),  // data output enable
    .sadd       ( dsp_sadd      ),  // serial address
    .psel       ( dsp_psel      ),  // peripheral select
    .ser_out    (               ),  // debug output to bypass the serial register
        // Unused by QSound firmware:
    .ose        (               ),  // output shift register empty
    .old        (               ),  // output load
    .ibf        (               ),  // input buffer full
    .di         (               ),  // serial data input
    .ick        (               ),  // serial data input clock
    .ild        (               ),  // serial data input load
    // interrupts
    .irq        ( dsp_irq       ),  // interrupt
    .iack       ( dsp_iack      ),  // interrupt acknowledgement
    // ROM programming interface
    .prog_addr  ( prog_addr     ),
    .prog_data  ( prog_data     ),
    .prog_we    ( prog_we       ),
    // Debug
    .fault      ( dsp_fault     )
);
`else
assign dsp_pbus_out = 16'd0;
assign dsp_pods_n   = 1;
assign dsp_pids_n   = 1;
assign dsp_do       = 1;
assign dsp_ock      = 1;
assign dsp_doen     = 0;
assign dsp_sadd     = 0;
assign dsp_psel     = 0;
assign dsp_ab       = 16'd0;
assign qsnd_cs      = 0;
`endif

endmodule

//////////////////////////// Small modules only instantiated by jtcps15_sound

module jtcps15_z80int(
    input      clk,
    input      rst,
    input      cen8,
    input      m1_n,
    input      iorq_n,
    output reg int_n
);

reg  [14:0] cnt;
wire        cntover = cnt==15'd31999;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cnt   <= 15'd0;
        int_n <= 1;
    end else if(cen8) begin
        cnt <= cntover ? 15'd0 : (cnt+15'd1);
        if( !m1_n && !iorq_n )
            int_n <= 1;
        else
            if( cntover ) int_n <= 0;

    end
end

endmodule

// There is an extra cycle for
// -OP access above C000
// -All data access
// This could be to give extra time to Kabuki decode logic

module jtcps15_z80wait(
    input         clk,
    input         rst,
    input         cen8,
    input         m1_n,
    input [15:12] addr,
    output        cen_cpu
);

assign cen_cpu = cen8;

// It slows down music, I think this isn't correct
// I have to check the PAL output with Loic.
/*
reg idle;

assign cen_cpu = cen8 & ~idle;

always @(posedge clk, posedge rst) begin
    if( rst )
        idle <= 0;
    else if(cen8) begin
        if( (addr[15:14]==2'b11 || m1_n) && !idle )
            idle <= 1;
        else
            idle <= 0;
    end
end
*/
endmodule

// M68000 requests and gets the bus in a synchronous way

module jtcps15_z80buslock(
    input         clk,
    input         rst,
    input         cen8,
    output  reg   busrq_n,  // to Z80
    input         busak_n,  // from Z80
    // Signals from M68000
    input         buse_n,   // request from M68000
    input [23:12] m68_addr,
    input         m68_buswen,
    output        z80_buswn,
    output  reg   m68_busakn    // to M68
);

parameter CPS2=0;

wire shared_addr = CPS2 ? m68_addr[23:16]==8'h61 : (
                   (m68_addr[23:12]>=12'hf18 && m68_addr[23:12]<12'hf1a ) ||
                   (m68_addr[23:12]>=12'hf1e && m68_addr[23:12]<12'hf20 ) );

assign z80_buswn = m68_buswen | m68_busakn;

reg last_busen, last_busakn;
reg preqrqn;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        m68_busakn <= 1'b1;
        busrq_n    <= 1'b1;
        preqrqn    <= 1'b1;
    end else if(cen8) begin
        // to Z80
        last_busen <= buse_n;
        if( !buse_n && last_busen)
            preqrqn <= 1'b0;
        else if( buse_n ) begin
            preqrqn <= 1'b1;
            busrq_n <= 1;
        end
        if( !preqrqn && busak_n ) busrq_n <= 0;

        // to M68
        last_busakn <= busak_n;
        m68_busakn  <= busak_n | last_busakn | buse_n;
    end
end

endmodule

module jtcps15_qsnd_cen(
    input       clk96,
    input       clk48,
    input       rst,
    input       base_sample,
    input       qsnd_ok,
    input       ext_rq,
    // resample
    input signed [15:0] l_in,
    input signed [15:0] r_in,
    output reg signed [15:0] l_out,
    output reg signed [15:0] r_out,
    output reg  resample48,
    // clock enable
    output reg  qsnd_cen
);

wire [13:0] MAXCNT = 14'd3999;

reg [13:0] cnt;
reg        sleep;
reg [ 1:0] resample;

always @(posedge clk96, posedge rst) begin
    if( rst ) begin
        cnt      <= 14'd0;
        sleep    <= 0;
        qsnd_cen <= 1;
        resample <= 0;
        l_out    <= 16'd0;
        r_out    <= 16'd0;
    end else begin
        qsnd_cen <= ~sleep & qsnd_ok;
        if( cnt == MAXCNT ) begin
            sleep    <= 0;
            cnt      <= 14'd0;
            resample <= 2'b11;
            l_out    <= l_in;
            r_out    <= r_in;
        end else begin
            cnt      <= cnt + 14'd1;
            resample <= resample<<1;
            if( base_sample ) sleep <= 1;
        end
    end
end

always @(posedge clk48) begin
    resample48 <= resample[1];
end

endmodule