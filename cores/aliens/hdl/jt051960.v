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
    Date: 15-4-2023 */

// Based on Furrtek's RE work on die shots
// and MAME documentation


module jt051960(    // sprite logic
    input             rst,
    input             clk,
    input             pxl_cen,

    // CPU interface
    input             cs,
    input             cpu_we,
    input      [ 7:0] cpu_dout,
    input      [10:0] cpu_addr,
    output     [ 7:0] cpu_din,

    // control
    input      [ 8:0] hdump,    // Not inputs in the original, but
    input      [ 8:0] vdump,    // generated internally.
                                // Hdump goes from 20 to 19F, 384 pixels
                                // Vdump goes from F8 to 1FF, 264 lines
    input             vs,
    input             lvbl,

    output            irq_n,
    output            firq_n,
    output            nmi_n,

    // Debug
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

localparam [ 2:0] REG_INT   = 0; // interrupt control, ROM read

wire        lut_we, reg_we, reg_rd, vb_rd;
reg  [ 7:0] mmr[0:4];
wire [ 7:0] ram_dout;
wire [ 2:0] int_en;
reg         vb_start_n; // low for the first six lines of VBLANK

assign lut_we  = cs & cpu_we & cpu_addr[10];
assign reg_we  = &{ cpu_we,cpu_addr[10:3]==0,cs};
assign reg_rd  = &{~cpu_we,cpu_addr[10:0]==0,cs};
assign cpu_din = { ram_dout[7:1], reg_rd ? vb_start_n : ram_dout[0] };
assign int_en  = mmr[REG_INT][2:0];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        vb_start_n <= 0;
    end else begin
        vb_start_n <= !(vdump>=9'h1f1 && vdump<9'h1f7);
    end
end

// Register map
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mmr[0]  <= 0; mmr[2] <= 0; mmr[3] <= 0; mmr[4]  <= 0;
        st_dout <= 0;
    end else begin
        if( reg_we ) begin
            mmr[cpu_addr[2:0]] <= cpu_dout;
`ifdef SIMULATION
            // $display("OBJ mmr[%d] <= %02X (cpu_addr=%x)", cpu_addr[2:0], cpu_dout, cpu_addr);
`endif
        end
        case( debug_bus[2:0] )
            0,2,3,4: st_dout <= mmr[debug_bus[2:0]];
            default: st_dout <= 0; // keep it to 0 so we can merge it with the output from 051937
        endcase
    end
end

// Interrupt handling
jtframe_edge #(.QSET(0)) u_irq(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( ~lvbl     ),
    .clr    (~int_en[0] ),
    .q      ( irq_n     )
);

jtframe_edge #(.QSET(0)) u_firq(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( vdump[0]  ),
    .clr    (~int_en[1] ),
    .q      ( firq_n    )
);

jtframe_edge #(.QSET(0)) u_nmi(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( vdump[4:0]==4 ), // every 32 lines
    .clr    (~int_en[2] ),
    .q      ( nmi_n     )
);

jtframe_dual_ram #(.SIMFILE("obj.bin")) u_lut(
    // Port 0: CPU
    .clk0   ( clk            ),
    .data0  ( cpu_dout       ),
    .addr0  ( cpu_addr[9:0]  ),
    .we0    ( lut_we         ),
    .q0     ( ram_dout       ),
    // Port 1
    .clk1   ( clk            ),
    .data1  ( 8'd0           ),
    .addr1  ( 10'd0          ),
    .we1    ( 1'b0           ),
    .q1     (                )
);

endmodule
