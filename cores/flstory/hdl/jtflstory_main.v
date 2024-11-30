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
    Date: 17-11-2024 */

module jtflstory_main(
    input            rst,
    input            clk,
    input            cen,
    input            lvbl,       // video interrupt

    output    [ 7:0] cpu_dout,
    output    [15:0] bus_addr,
    output    [ 7:0] bus_dout,
    output    [ 7:0] bus_din,


    // sound
    input     [ 7:0] s2m_data,
    output reg       m2s_wr,
    output reg       s2m_rd,

    // video memories
    output    [ 1:0] pal16_we,
    output    [ 1:0] vram_we,
    output           oram_we,
    input     [15:0] pal16_dout,
    input     [15:0] vram16_dout,
    input     [ 7:0] oram8_dout,
    output reg[ 1:0] pal_bank,
    output reg[ 1:0] scr_bank,
    output reg       scr_flen,
    output reg       gvflip,
    output reg       ghflip,

    // shared memory with MCU
    input            busrq_n,
    output           busak_n,
    // MCU as master
    input     [15:0] c2b_addr,
    input     [ 7:0] c2b_dout,
    input            c2b_we,
    // communication with MCU
    output           b2c_wr,
    output           b2c_rd,
    input     [ 7:0] mcu2bus,
    // shared memory (although no sub CPU in the core)
    output           sha_we,
    input     [ 7:0] sha_dout,
    // Cabinet inputs
    input     [ 1:0] cab_1p,
    input     [ 1:0] coin,
    input     [ 5:0] joystick1,
    input     [ 5:0] joystick2,
    input     [23:0] dipsw,
    input            service,
    input            tilt,
    // ROM access
    output reg       rom_cs,
    output    [15:0] rom_addr,
    input     [ 7:0] rom_data,
    input            rom_ok,

    input     [ 7:0] debug_bus
);
`ifndef NOMAIN

wire [15:0] A, cpu_addr;
reg  [ 7:0] cab, din, ram_dout;
wire        mreq_n, rfsh_n, rd_n, wr_n, bus_we;
reg         ram_cs, vram_cs,sha_cs, vcfg_cs, oram_cs,
            cab_cs, pal_hi, pal_lo, rst_n;

assign A        = bus_addr;
assign rom_addr = bus_addr;
assign bus_addr = busak_n ? cpu_addr : c2b_addr;
assign bus_dout = busak_n ? cpu_dout : c2b_dout;
assign bus_din  = din;
assign bus_we   = busak_n ? ~wr_n    : c2b_we;
assign pal16_we = {2{bus_we}} & {pal_hi,pal_lo};
assign sha_we   = sha_cs & bus_we;
assign vram_we  = {2{vram_cs&bus_we}} & { A[0], ~A[0] };
assign oram_we  = oram_cs & bus_we;

always @* begin
    rom_cs  = 0;
    ram_cs  = 0;
    vram_cs = 0;
    sha_cs  = 0;
    cab_cs  = 0;
    oram_cs = 0;
    pal_lo  = 0;
    pal_hi  = 0;
    vcfg_cs = 0;
    m2s_wr  = 0;
    s2m_rd  = 0;
    b2c_wr  = 0;
    b2c_rd  = 0;
    if( !mreq_n && rfsh_n ) case(A[15:14])
        0,1,2: rom_cs = 1;
        3: case(A[13:12])
            0: vram_cs = 1;
            1: begin
                case(A[11:10]) // D000
                    0: if(bus_we) case(A[1:0])
                        0: b2c_wr = 1; // CPU writes to MCU latch
                        // 1: watchdog
                        // 2: sub CPU reset and coin lock
                        // 3: sub CPU NMI
                        default:;
                    endcase else case(A[1:0])
                        0: b2c_rd = 1; // CPU reads from MCU latch
                        default:;
                    endcase
                    1: if(bus_we) m2s_wr = 1; else s2m_rd = 1;
                    2: cab_cs  = 1; // D80?
                    3: case(A[9:8]) // DC?? ~ DF??
                        0: oram_cs = 1;
                        1: pal_lo  = 1;
                        2: pal_hi  = 1; // includes priority bits
                        3: case(A[1:0])
                            // 0, 1, 2: related to gun games?
                            3: vcfg_cs = 1;
                        endcase
                    endcase

                endcase
            end
            2,3: sha_cs = 1; // E000~FFFF
            default:;
        endcase
    endcase
end

always @(posedge clk) begin
    rst_n <= ~rst;
    if( vcfg_cs ) begin
        // hvlatch <= bus_dout[7]
        pal_bank <= bus_dout[6:5];
        scr_bank <= bus_dout[4:3];
        scr_flen <= bus_dout[2];
        { gvflip, ghflip } <= bus_dout[1:0];
    end
    case(A[2:0])
        0: cab <= dipsw[ 7: 0];
        1: cab <= dipsw[15: 8];
        2: cab <= dipsw[23:16];
        3: cab <= {2'b11,coin,tilt,service,cab_1p};
        4: cab <= {2'b11,joystick1[3:0],joystick1[5:4]};
        6: cab <= {2'b11,joystick2[3:0],joystick2[5:4]};
        default:;
    endcase
end

always @* begin
    din = rom_cs ? rom_data   :
          ram_cs ? ram_dout   :
          cab_cs ? cab        :
          b2c_rd ? mcu2bus    :
          s2m_rd ? s2m_data   :
          oram_cs? oram8_dout :
          pal_hi ? pal16_dout[15:8] :
          pal_lo ? pal16_dout[ 7:0] :
          vram_cs? (A[0] ? vram16_dout[15:8] : vram16_dout[7:0]) :
          8'd0;
end

jtframe_sysz80 #(.RAM_AW(11),.CLR_INT(1),.RECOVERY(1)) u_cpu(
    .rst_n      ( rst_n       ),
    .clk        ( clk         ),
    .cen        ( cen         ),
    .cpu_cen    (             ),
    .int_n      ( lvbl        ), // int clear logic is internal
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( busrq_n     ),
    .busak_n    ( busak_n     ),
    .m1_n       (             ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     (             ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .A          ( cpu_addr    ),
    .cpu_din    ( din         ),
    .cpu_dout   ( cpu_dout    ),
    .ram_dout   ( ram_dout    ),
    // ROM access
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);
`else
initial begin
end
`endif
endmodule