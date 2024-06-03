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
    Date: 24-9-2023 */

// Port 4 configured as output --> use as address bus
// Port 6 configured as output

module jtshouse_mcu(
    input              clk,
    input              game_rst,
    input              rstn,
    input              cen,
    input              lvbl,

    input       [8:0]  hdump,

    output      [7:0]  mcu_dout,
    output             rnw,
    output reg         ram_cs,      // Tri port RAM
    input       [7:0]  ram_dout,
    output             halted,      // signals an decoding error too
    // Ports
    // cabinet I/O
    input       [1:0]  io_mode,
    input       [1:0]  cab_1p,
    input       [3:0]  coin,
    input       [9:0]  joystick1,
    input       [9:0]  joystick2,
    input       [9:0]  joystick3,
    input       [9:0]  joystick4,
    input       [1:0]  dial1,
    input       [1:0]  dial2,
    input       [7:0]  dipsw,
    input              service,
    input              dip_test,

    // PROM programming
    input      [11:0]  prog_addr,
    input      [ 7:0]  prog_data,
    input              prog_we,

    // EEROM
    output     [10:0]  mcu_addr,
    input      [ 7:0]  eerom_dout,
    output             eerom_we,

    // "Voice" ROM
    output     [19:0]  pcm_addr,
    input      [ 7:0]  pcm_data,
    output reg         pcm_cs,
    input              pcm_ok,
    output             bus_busy,

    output reg  [10:0] snd,
    input       [ 7:0] debug_bus
);
`ifndef NOMAIN
wire        vma;
reg         dip_cs, epr_cs, cab_cs, swio_cs, reg_cs,
            irq, lvbl_l;

wire [15:0] A;
wire [11:0] rom_addr;
reg  [11:0] mix;
wire [ 7:0] p1_din, rom_data;
wire [ 4:0] p2_dout;
wire [ 1:0] gain1,  gain0;
reg  [ 7:0] mcu_din, cab_dout, dac1, dac0;
reg  [ 2:0] bank;
reg  [ 3:0] dipmx;
reg  [ 1:0] pcm_msb;
reg  [10:0] amp1, amp0;
reg         init_done;
wire        wr;
reg         cab_csl;
reg  [ 5:0] strb_count;
reg  [ 2:0] berabohm_btn;
reg  [ 7:0] berabohm_force;
reg  [ 7:0] dial1_out;
reg  [ 7:0] dial2_out;
reg  [ 1:0] dial_strb;
reg  [ 1:0] dial1_l, dial2_l;
reg         a0_l;
reg  [ 5:0] inp_latch1, inp_latch2;

function [2:0] gain( input [1:0] g);
    case( g )
        0: gain = 1;
        1: gain = 2;
        2: gain = 3;
        3: gain = 4;
    endcase
endfunction

assign rnw         = ~wr;
assign bus_busy    = pcm_cs & ~pcm_ok;
assign eerom_we    = epr_cs & wr;
assign pcm_addr    = {bank, pcm_msb, A[15],A[13:0]};
assign mcu_addr    = A[10:0]; // used to access both Tri RAM and EEROM
assign p1_din      = { 1'b1, service, dip_test, coin[0], coin[1], 3'd0 };
assign gain1       = p2_dout[4:3];
assign gain0       = {p2_dout[2], p2_dout[0]};

`ifdef SIMULATION
wire bad_cs  = vma &&  A==16'hc000;
`endif
// Address decoder
always @(*) begin
    pcm_cs  = vma && ^A[15:14];                    // 4000~bfff
    swio_cs = vma &&  A[15:12]==4'h1;
    // the init_done mechanism mimics MAME's hack to prevent a lock up during the boot sequence
    // see https://github.com/jotego/jtcores/issues/410
    ram_cs  = vma &&  A[15:12]==4'hc && !A[11] /*&& (A[10:0]!=0 || rnw || !init_done)*/;    // c000~c7ff
    epr_cs  = vma &&  A[15:12]==4'hc &&  A[11];    // c800~cfff
    reg_cs  = vma &&  A[15:12]==4'hd && wr;
    dip_cs  = vma && swio_cs && A[11:10]==0;
    cab_cs  = vma && swio_cs && A[11:10]==1;
end

always @* begin
    mcu_din =   pcm_cs  ? pcm_data   :
                ram_cs  ? ram_dout   :
                epr_cs  ? eerom_dout :
                cab_cs  ? cab_dout   :
                dip_cs  ? { 4'hf, dipmx[0], dipmx[1], dipmx[2], dipmx[3] } :
                8'd0;
end

reg [7:0] sample_cnt;
wire sample = sample_cnt==0 && cen;

always @(posedge clk) begin
    if( cen ) sample_cnt <= sample_cnt+1'd1;
end

always @(*) begin
    case (strb_count[4:3])
        0: berabohm_btn = ~joystick1[6:4];
        1: berabohm_btn = ~joystick1[9:7];
        2: berabohm_btn = ~joystick2[6:4];
        3: berabohm_btn = ~joystick2[9:7];
        default: ;
    endcase
    berabohm_force = berabohm_btn[0] ? 8'h7f : berabohm_btn[1] ? 8'h48 : berabohm_btn[2] ? 8'h40 : 8'h00;
end

always @(posedge clk) begin
    if (!rstn) begin
        dial1_out <= 8'h00;
        dial2_out <= 8'h00;
    end else begin
        dial1_l <= dial1;
        case ({dial1_l, dial1})
            4'b0001 : dial1_out <= dial1_out - 1'd1;
            4'b0010 : dial1_out <= dial1_out + 1'd1;
            4'b0100 : dial1_out <= dial1_out + 1'd1;
            4'b0111 : dial1_out <= dial1_out - 1'd1;
            4'b1000 : dial1_out <= dial1_out - 1'd1;
            4'b1011 : dial1_out <= dial1_out + 1'd1;
            4'b1101 : dial1_out <= dial1_out + 1'd1;
            4'b1110 : dial1_out <= dial1_out - 1'd1;
            default: ;
        endcase
        dial2_l <= dial2;
        case ({dial2_l, dial2})
            4'b0001 : dial2_out <= dial2_out - 1'd1;
            4'b0010 : dial2_out <= dial2_out + 1'd1;
            4'b0100 : dial2_out <= dial2_out + 1'd1;
            4'b0111 : dial2_out <= dial2_out - 1'd1;
            4'b1000 : dial2_out <= dial2_out - 1'd1;
            4'b1011 : dial2_out <= dial2_out + 1'd1;
            4'b1101 : dial2_out <= dial2_out + 1'd1;
            4'b1110 : dial2_out <= dial2_out - 1'd1;
            default: ;
        endcase
    end
end

always @(posedge clk, negedge rstn ) begin
    if( !rstn ) begin
        bank     <= 0;
        dac1     <= 8'h80;
        dac0     <= 8'h80;
        snd      <= 0;
        cab_dout <= 0;
        irq      <= 0;
        lvbl_l   <= 0;
        mix      <= 0;
        init_done<= 0;
        strb_count<=0;
        dial_strb<= 0;
        inp_latch1<=6'h1f;
        inp_latch2<=6'h1f;
    end else begin
        lvbl_l <= lvbl;
        // The IRQ is held until VB ends or the CPU acknowledges it with a write at Fxxx
        if( !lvbl && lvbl_l         ) irq <= 1;
        if(  lvbl || &{A[15:12],wr} ) irq <= 0; // typ 31.2us width measure on the PCB
        // dac0, dac1 pre-amplification by the first opamp connected to the
        // resistor is done in mem.yaml
        // Stage      | Vpp
        // DAC output | 4    (it might be a bit over 4V)
        // Preamp     | 6    (assuming 1.5 gain, supply is 6V)
        // Amp        | 6    (must be clamped)
        amp1 <= dac1 * gain(gain1); // assuming no clamping
        amp0 <= dac0 * gain(gain0);
        mix  <= {1'b0, amp1}+{1'b0, amp0};
        if( sample ) snd <= mix[11] != 0 ? 11'h7ff : mix[10:0];
        dipmx<= A[1] ? dipsw[7:4] : dipsw[3:0];
        cab_csl <= cab_cs;
        a0_l <= A[0];
        if (cab_csl & !cab_cs) begin
            if (a0_l) strb_count <= strb_count + 1'd1;
            if (!a0_l) dial_strb[1] <= ~dial_strb[1]; else if (!dial_strb[1]) dial_strb[0] <= ~dial_strb[0];
        end
        case (io_mode)
            1: begin
                // 4p
                if (strb_count[2:0] == 3'b111) begin
                    cab_dout <= A[0] ? { coin[3], 4'h0, strb_count[5:3] } :
                                       { coin[2], 1'b0, inp_latch1 };
                    if(A[0]) case (strb_count[5:3])
                        0: begin
                            inp_latch1 <= {1'b0, joystick1[4:0]};
                            inp_latch2 <= {joystick4[2:0], 3'd0};
                        end
                        3:begin
                            inp_latch1 <= {1'b0, joystick2[4:0]};
                        end
                        4:begin
                            inp_latch1 <= {1'b0, joystick3[4:0]};
                            inp_latch2 <= {1'b0, joystick4[4:3], 3'd0};
                        end
                        default: begin
                            inp_latch1 <= 6'h1f;
                            inp_latch2 <= 6'h1f;
                        end
                    endcase
                end else begin
                    cab_dout <= A[0] ? { coin[3], 1'b1, inp_latch2 } :
                                       { coin[2], 1'b0, inp_latch1 };
                end
            end
            2: begin
                // berabohm
                cab_dout <= A[0] ? { cab_1p[1], strb_count[2], 1'b0, &strb_count[4:3], joystick2[3:0] }:
                                   strb_count[5] ? { cab_1p[0], 3'd0, joystick1[3:0] } : berabohm_force;
                if (strb_count == 40) strb_count <= 0;
            end
            3: begin
                //quester
                cab_dout <= A[0] ? ({cab_1p[1], 1'b0, dial_strb[0], joystick2[4], dial_strb[0] ? dial2_out[7:4] : dial1_out[7:4]}) :
                                   ({cab_1p[0], dial_strb[1], 1'b0, joystick1[4], dial_strb[0] ? dial2_out[3:0] : dial1_out[3:0]});
            end
            default: cab_dout <= A[0] ? { cab_1p[1], joystick2[6:0] }:
                                        { cab_1p[0], joystick1[6:0] };
        endcase
        if( ram_cs && A[10:0]==0 && wr && cen ) init_done <= mcu_dout=='ha6;
        if( reg_cs ) case(A[11:10])
            0: dac0 <= mcu_dout;
            1: dac1 <= mcu_dout;
            2: begin
                pcm_msb <= { (~mcu_dout[2])^mcu_dout[1], mcu_dout[0] };
                case( mcu_dout[7:2] )
                    ~(6'd1<<0): bank <= 0;
                    ~(6'd1<<1): bank <= 1;
                    ~(6'd1<<2): bank <= 2;
                    ~(6'd1<<3): bank <= 3;
                    ~(6'd1<<4): bank <= 4;
                    ~(6'd1<<5): bank <= 5;
                    default: bank <= 0;
                endcase
            end
        endcase
    end
end
/* verilator tracing_on */
jtframe_6801mcu #(.ROMW(12),.SLOW_FRC(2),.MODEL("HD63701V")) u_63701(
    .rst        ( ~rstn         ),
    .clk        ( clk           ),
    .cen        ( cen           ),

    // Bus
    .wr         ( wr            ),
    .x_cs       ( vma           ),
    .addr       ( A             ),
    .xdin       ( mcu_din       ),
    .dout       ( mcu_dout      ),
    .ba         ( halted        ),

    // interrupts
    .irq        ( irq           ),
    .nmi        ( 1'b0          ),
    // ports
    .p1_din     ( p1_din        ),
    .p2_din     ( 5'd0          ),
    .p3_din     ( 8'd0          ),
    .p4_din     ( 8'd0          ),

    .p1_dout    (               ),  // coin lock & counters
    .p2_dout    ( p2_dout       ),
    .p3_dout    (               ),
    .p4_dout    (               ),
    // ROM
    .rom_cs     (               ),
    .rom_addr   ( rom_addr      ),
    .rom_data   ( rom_data      )
);

jtframe_prom #(.AW(12),.SIMFILE("../../firmware/triram-mcu.bin")) u_prom(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( prog_data ),
    .we     ( prog_we   ),
    .wr_addr( prog_addr ),
    .rd_addr( rom_addr  ),
    .q      ( rom_data  )
);
`else
assign mcu_dout = 0;
assign rnw      = 1;
assign halted   = 0;
assign mcu_addr = 0;
assign eerom_we = 0;
assign pcm_addr = 0;
assign bus_busy = 0;
initial ram_cs  = 0;
initial pcm_cs  = 0;
initial snd     = 0;
`endif
endmodule
