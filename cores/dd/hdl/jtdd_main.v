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
    Date: 2-12-2019 */

// Clocks are derived from H counter on the original PCB
// Yet, that doesn't seem to be important and it only
// matters the frequency of the signals:
// E,Q: 3 MHz
// Q is 1/4th of wave advanced

module jtdd_main(
    input              clk,
    input              rst,
    input              cpu_cen,
    input              VBL,
    input              IMS, // =VPOS[3]
    // MCU
    input       [7:0]  mcu_ram,
    input              mcu_irqmain,
    input              mcu_ban,
    output             mcu_nmi_set,
    output  reg        mcu_haltn,
    output  reg        com_cs,
    // Palette
    output  reg        pal_cs,
    output             flip,
    input       [7:0]  pal_dout,
    // Sound
    output  reg        mcu_rstb,
    output  reg        snd_irq,
    output  reg [7:0]  snd_latch,
    // Characters
    input       [7:0]  char_dout,
    output      [7:0]  cpu_dout,
    output  reg        cram_cs,
    // Object
    input       [7:0]  obj_dout,
    output  reg        oram_cs,
    // scroll
    input       [7:0]  scr_dout,
    output  reg        vram_cs,
    output  reg [8:0]  scrhpos,
    output  reg [8:0]  scrvpos,
    // cabinet I/O
    input       [1:0]  cab_1p,
    input       [1:0]  coin,
    input       [6:0]  joystick1,
    input       [6:0]  joystick2,
    // BUS sharing
    output  [12:0]     cpu_AB,
    output             RnW,
    // ROM access
    output  reg        rom_cs,
    output  reg [17:0] rom_addr,
    input       [ 7:0] rom_data,
    // DIP switches
    input              service,
    input              dip_pause,
    input  [7:0]       dipsw_a,
    input  [7:0]       dipsw_b
);

wire [15:0] A;
wire [ 7:0] ram_dout;
reg io_cs, ram_cs, misc_cs, banked_cs;

// These refer to memory locations to which a write operation
// has some hardware effect. In reality A[3] must be high too
// so the labels are incorrect. But I keep the ones used in the
// schematics
(*keep*) reg w3801, w3802, w3803, w3804, w3805, w3806, w3807;
wire scrhpos_cs  = w3801; // sch. sheet 8/10
wire scrvpos_cs  = w3802;
`ifdef SIMULATION
wire nmi_clr     = w3803;
wire firq_clr    = w3804;
wire irq_clr     = w3805;
`endif
wire sndlatch_cs = w3806;
wire irq_ack;
reg  rst_vb;

assign mcu_nmi_set = w3807;
assign flip = 0; // not implemented

// Do not release the reset while in blanking or it will trigger
// a potentially catastrophic NMI
always @(posedge clk) begin
    if( rst )
        rst_vb <= 1;
    else if( !VBL )
        rst_vb <= 0;
end

always @(*) begin
    vram_cs      = 1'b0;
    io_cs       = 1'b0;
    pal_cs      = 1'b0;
    ram_cs      = 1'b0;
    cram_cs     = 1'b0;
    rom_cs      = 1'b0;
    oram_cs      = 1'b0;
    misc_cs     = 1'b0;
    com_cs      = 1'b0;
    banked_cs   = 1'b0;
    w3801       = 1'b0;
    w3802       = 1'b0;
    w3806       = 1'b0;
    if( A[15:14]==2'b00 ) begin
        case(A[13:11])
            3'd0, 3'd1: ram_cs = 1'b1;
            `ifndef DD2
            3'd2: pal_cs  = 1'b1;
            `else
            3'd2: ram_cs = 1'b1; // more available RAM in DD2
            `endif
            3'd3: cram_cs = 1'b1;
            3'd4: com_cs  = 1'b1;
            3'd5: oram_cs  = 1'b1;
            3'd6: vram_cs  = 1'b1;
            3'd7: begin
                `ifdef DD2
                if(A[10]) pal_cs = 1'b1;
                else
                `endif
                begin
                    io_cs  = RnW;
                    if(A[3] && !RnW) begin
                        case( A[2:0] )
                            3'd0: misc_cs = 1'b1;
                            3'd1: w3801   = 1'b1; // H scroll
                            3'd2: w3802   = 1'b1; // V scroll
                            3'd6: w3806   = 1'b1; // sound latch CS
									 default:;
                        endcase
                    end
                end
            end
        endcase
    end else begin
        rom_cs    =  A[15] | A[14];
        banked_cs = ~A[15] & A[14];
    end
end

always @(posedge clk) begin
    w3803 <= A[15:10] == 6'b0011_10 && A[2:0]==3'd3; // NMI clear
    w3804 <= A[15:10] == 6'b0011_10 && A[2:0]==3'd4; // FIRQ ack
    w3805 <= A[15:10] == 6'b0011_10 && A[2:0]==3'd5; // IRQ ack (from MCU)
    w3807 <= A[15:10] == 6'b0011_10 && A[2:0]==3'd7; // MCU NMI set
end

// special registers. Schematic sheet 3/9
reg [2:0] bank;
always @(posedge clk or posedge rst) begin
    if( rst ) begin
        bank        <= 3'd0;
        //flip        <= 1'b0;
        mcu_haltn   <= 1'b0;
        scrhpos     <= 9'b0;
        scrvpos     <= 9'b0;
        mcu_rstb    <= 1'b0;
    end else if(cpu_cen) begin
        snd_irq <= 1'b0;
        if( sndlatch_cs ) begin
            snd_latch <= cpu_dout;
            snd_irq   <= 1'b1;
        end
        if( scrvpos_cs ) scrvpos[7:0] <= cpu_dout;
        if( scrhpos_cs ) scrhpos[7:0] <= cpu_dout;
        if( misc_cs ) begin
            scrhpos[8] <= cpu_dout[0];
            scrvpos[8] <= cpu_dout[1];
            //flip       <=~cpu_dout[2];
            mcu_rstb   <= cpu_dout[3];
            mcu_haltn  <= ~cpu_dout[4];
            bank       <= cpu_dout[7:5];
            // `ifdef SIMULATION
            //     if(  cpu_dout[4] &&  mcu_haltn ) $display("MCU halted");
            //     if( !cpu_dout[4] && !mcu_haltn ) $display("MCU released");
            // `endif
        end
    end
end

reg [7:0] cabinet_input;

function [5:0] fix_joy;
    input [5:0] joy;
    fix_joy = { joy[5:4],joy[2],joy[3],joy[1:0]};
endfunction

always @(posedge clk) begin
    case( A[3:0])
        4'd0:    cabinet_input <= { cab_1p, fix_joy(joystick1[5:0]) };
        4'd1:    cabinet_input <= { coin,   fix_joy(joystick2[5:0]) };
        4'd2:    cabinet_input <= { 3'b111, mcu_ban, ~VBL, // Using ~VBL instead of VBL increases the game speed
            // as observed by comparing the frame count at which the demo starts:
            // 10 frames earlier in dd (~VBL faster than VBL)
            //  8 frames earlier in dd2
            joystick2[6], joystick1[6], service };
        4'd3:    cabinet_input <= dipsw_a;
        4'd4:    cabinet_input <= dipsw_b;
        default: cabinet_input <= 8'hff;
    endcase
end

assign cpu_AB = A[12:0];

reg [7:0] cpu_din;

always @* begin // do not register
    case( 1'b1 )
        ram_cs    : cpu_din = ram_dout;
        cram_cs   : cpu_din = char_dout;
        vram_cs   : cpu_din = scr_dout;
        rom_cs    : cpu_din = rom_data;
        banked_cs : cpu_din = rom_data;
        io_cs     : cpu_din = cabinet_input;
        pal_cs    : cpu_din = pal_dout;
        oram_cs   : cpu_din = obj_dout;
        com_cs    : cpu_din = mcu_ram;
        default   : cpu_din = 8'hff;
    endcase
end

// In the original PCB, the CPU RAM is shared with the
// character generator. Time multiplexing avoids the two to clash
// There is 1/4 of that memory unaccessible by the CPU
// I have broken up the memory in order to avoid that waste
// and ease design compilation.
// RAM which is not shared by the characters

// banked ROM address
always @(*) begin
    rom_addr[13:0] =  A[13:0];
    rom_addr[17:14]= banked_cs ? {1'b0,bank} : {3'b100, A[14]};
end

// Interrupts
wire nIRQ, nFIRQ, nNMI, VBL_pause;

assign VBL_pause = VBL & dip_pause;

jtframe_ff #(.W(3)) u_irq(
    .clk     (   clk                            ),
    .rst     (   rst_vb                         ),
    .cen     (   1'b1                           ),
    .sigedge ( {VBL_pause, IMS, mcu_irqmain   } ),
    .din     ( ~3'd0                            ),
    .clr     ( { w3803, w3804, w3805 }          ),
    .set     ( 3'b0                             ),
    .q       (                                  ),
    .qn      ( { nNMI, nFIRQ, nIRQ }            )
);

// RECOVERY does not seem to have an effect on DD2 hanging up
jtframe_sys6809 #(.RAM_AW(13),.CENDIV(0),.RECOVERY(0)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cpu_cen   ),   // This is normally the input clock to the CPU
    .cpu_cen    (           ),
    .VMA        (           ),
    // Interrupts
    .nIRQ       ( nIRQ      ),
    .nFIRQ      ( nFIRQ     ),
    .nNMI       ( nNMI      ),
    .irq_ack    ( irq_ack   ),
    // Bus sharing
    .bus_busy   ( 1'b0      ),
    // memory interface
    .A          ( A         ),
    .RnW        ( RnW       ),
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( 1'b1      ),
    // Bus multiplexer is external
    .ram_dout   ( ram_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    ( cpu_din   )
);

endmodule // jtdd_main