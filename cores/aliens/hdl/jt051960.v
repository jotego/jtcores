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

// 1 kB external RAM holding 128 sprites, 8 bytes each
// the RAM is copied in during the first 8 lines of VBLANK
// the process is only done if the sprite logic is enabled
// and it gets halted while the CPU tries to write to the memory
// only active sprites (bit 7 of byte 0 set) are copied

// horizontal and vertical down scaling


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

    // ROM addressing
    output     [17:0] rom_addr, // CA pins, actual rom addr pins may not connect directly
                                // 13 = code + 4 v + 1 h = 18
    output reg [ 7:0] attr,     // OC pins
    output reg        hflip, vflip,
    output reg [ 8:0] hpos,

    // control
    input      [ 8:0] hdump,    // Not inputs in the original, but
    input      [ 8:0] vdump,    // generated internally.
                                // Hdump goes from 20 to 19F, 384 pixels
                                // Vdump goes from F8 to 1FF, 264 lines
    input             vs,
    input             lvbl,

    // draw module / 051937
    output reg        dr_start,
    input             dr_busy,

    output            irq_n,
    output            firq_n,
    output            nmi_n,

    // Debug
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

localparam [ 2:0] REG_INT   = 0, // interrupt control, ROM read
                  REG_ROM_L = 2, // ROM address during ROM read
                  REG_ROM_H = 3,
                  REG_ROM_VH= 4;

wire        lut_we, reg_we, reg_rd, vb_rd, romrd, dma_we;
reg  [ 7:0] mmr[0:4];
reg  [ 5:0] hzoom, vzoom;
reg  [12:0] code;
reg  [ 9:0] dma_addr;
reg  [ 2:0] scan_sub;
reg  [ 8:0] ydiff;
reg  [ 6:0] dma_prio, scan_obj;
reg         dma_clr, dma_done, inzone;
wire [ 7:0] ram_dout, scan_data;
wire [ 2:0] int_en, size;
wire [ 7:0] romrd_bank, dma_din;
wire [ 9:0] romrd_msb, scan_addr;
reg         vb_start_n; // low for the first six lines of VBLANK

assign lut_we  = cs & cpu_we & cpu_addr[10];
assign reg_we  = &{ cpu_we,cpu_addr[10:3]==0,cs};
assign reg_rd  = &{~cpu_we,cpu_addr[10:0]==0,cs};
assign cpu_din = { ram_dout[7:1], reg_rd ? vb_start_n : ram_dout[0] };
assign int_en  = mmr[REG_INT][2:0];
assign romrd   = mmr[REG_INT][4];
assign { romrd_bank, romrd_msb } = // the bank part is outputted through OC pins
    { mmr[REG_ROM_VH][1:0], mmr[REG_ROM_H], mmr[REG_ROM_L] };
assign dma_din = dma_clr ? 8'd0 : dma_data;
assign dma_we  = ~vb_start_n & (dma_clr | ~dma_done);
assign scan_addr = { scan_obj, scan_sub };
assign rom_addr  = { code, 1'b0, ydiff[3:0] };

always @* begin
    ydiff  = y - (vdump+1'd1); // to do: add 1, flip...
    inzone = ydiff[8:4]==0;
end

// DMA logic
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        vb_start_n <= 0;
        dma_clr    <= 0;
        dma_done   <= 0;
        dma_addr   <= 0;
    end else if( pxl_cen) begin
        vb_start_n <= !(vdump>=9'h1f1 && vdump<9'h1f7); // 8 lines
        if( vb_start_n ) begin
            dma_done <= 0;
            dma_clr  <= 1;
            dma_addr <= 0;
        end else begin
            if( dma_clr) begin // clear the full buffer first
                { dma_clr, dma_addr } <= { 1'b1, dma_addr } + 1'd1;
            end else if( !dma_done && !lut_we && !romrd ) begin // copy by priority order
                { dma_done, dma_addr } <= { 1'b0, dma_addr } + 1'd1;
                if( dma_addr[2:0]==0 ) begin
                    dma_prio <= dma_data[6:0];
                    if( !dma_data[7] )
                        { dma_done, dma_addr } <= { 1'b0, dma_addr[9:3], 3'd0 } + 4'd8;
                end
            end
        end
    end
end


(* direct_enable *) reg cen2=0;
always @(negedge clk) cen2 <= ~cen2;

// Table scan
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        lhbl_l   <= 0;
        scan_obj <= 0;
        scan_sub <= 0;
    end else if( cen2 ) begin
        lhbl_l <= lhbl;
        if( !lhbl && lhbl_l ) begin
            done     <= 0;
            scan_obj <= 0;
            scan_sub <= 1;
        end
        if( !done ) begin
            scan_sub <= scan_sub + 1'd1;
            case( scan_sub )
                1: { size, code[12:8] } <= scan_dout;
                2: code[7:0] <= scan_dout;
                3: attr <= scan_dout;
                4: { vzoom, vflip, y[8] } <= scan_dout;
                5: y[7:0] <= scan_dout;
                6: begin
                    { hzoom, hflip, hpos[8] } <= scan_dout;
                end
                7: begin
                    hpos[7:0] <= scan_dout;
                    if( !dr_busy || !inzone ) begin
                        dr_start <= inzone;
                        scan_sub <= 1;
                        scan_obj <= scan_obj + 1'd1;
                        if( &scan_obj ) done <= 1;
                    end else begin
                        scan_sub <= 7;
                    end
                end
            endcase
        end
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
            // $display("OBJ mmr[%d] <= %02X (cpu_addr=%hpos)", cpu_addr[2:0], cpu_dout, cpu_addr);
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
    .addr1  ( dma_addr       ),
    .we1    ( 1'b0           ),
    .q1     ( dma_data       )
);

jtframe_dual_ram #(.SIMFILE("obj.bin")) u_lut(
    // Port 0: DMA
    .clk0   ( clk            ),
    .data0  ( dma_din        ),
    .addr0  ( { dma_prio, dma_addr[2:0] } ),
    .we0    ( dma_we         ),
    .q0     (                ),
    // Port 1: scan
    .clk1   ( clk            ),
    .data1  ( 8'd0           ),
    .addr1  ( scan_addr      ),
    .we1    ( 1'b0           ),
    .q1     ( scan_dout      )
);

endmodule
