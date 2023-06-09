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
    output reg [12:0] code,
    output reg [ 7:0] attr,     // OC pins
    output reg        hflip, vflip,
    output reg [ 8:0] hpos,
    output     [ 3:0] ysub,
    output reg [ 5:0] hzoom,
    output reg        hz_keep,

    // control
    input      [ 8:0] hdump,    // Not inputs in the original, but
    input      [ 8:0] vdump,    // generated internally.
                                // Hdump goes from 20 to 19F, 384 pixels
                                // Vdump goes from F8 to 1FF, 264 lines
    input             vs,
    input             lvbl,
    input             lhbl,

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

localparam [ 2:0] REG_CFG   = 0, // interrupt control, ROM read
                  REG_ROM_L = 2, // ROM address during ROM read
                  REG_ROM_H = 3,
                  REG_ROM_VH= 4;

wire        lut_we, reg_we, reg_rd, vb_rd, romrd, dma_we,
            flip;
reg  [ 7:0] mmr[0:4];
reg  [ 5:0] vzoom;
reg  [ 9:0] dma_addr;
reg  [ 2:0] scan_sub, hstep, hcode;
reg  [ 8:0] ydiff, ydiff_b, y, vlatch, hadd;
reg  [ 6:0] dma_prio, scan_obj;
reg         dma_clr, dma_done, dma_cen, inzone, lhbl_l, done, hdone, busy_l;
wire [ 7:0] ram_dout, scan_dout, dma_data;
wire [ 2:0] int_en;
reg  [ 2:0] size;
wire [ 7:0] romrd_bank, dma_din;
wire [ 9:0] romrd_msb, scan_addr, dma_wr_addr;
reg  [17:0] yz_add;
reg         vb_start_n, // low for the first six lines of VBLANK
            dma_ok, obj_enb, lvbl_l;
wire        busy_g;

assign lut_we  = cs & cpu_we & cpu_addr[10];
assign reg_we  = &{ cpu_we,cpu_addr[10:3]==0,cs};
assign reg_rd  = &{~cpu_we,cpu_addr[10:0]==0,cs};
// original hardware outputs ram_dout[7:1],
// leaving 7'd0 for compatibility with MAME traces
// and it also simplifies logic
assign cpu_din = reg_rd ? { 7'd0, ~vb_start_n }  : ram_dout;
assign int_en  = mmr[REG_CFG][2:0];
assign flip    = mmr[REG_CFG][3];
assign romrd   = mmr[REG_CFG][5];
assign { romrd_bank, romrd_msb } = // the bank part is outputted through OC pins
    { mmr[REG_ROM_VH][1:0], mmr[REG_ROM_H], mmr[REG_ROM_L] };
assign dma_din = dma_clr ? 8'd0 : dma_data;
assign dma_we  = ~vb_start_n & (dma_clr | dma_ok);
assign dma_wr_addr = dma_clr ? dma_addr : { dma_prio, dma_addr[2:0] };
assign scan_addr = { scan_obj, scan_sub };
assign ysub = ydiff[3:0]^{4{vflip}};
assign busy_g = busy_l | dr_busy;

always @* begin
    ydiff_b= y + vlatch; // to do: add 1, flip...
    ydiff  = ydiff_b+yz_add[17-:9];
    case( size )
        0,1:   inzone = ydiff_b[8:4]==0 && ydiff[8:4]==0; // 16
        2,3,4: inzone = ydiff_b[8:5]==0 && ydiff[8:5]==0; // 32
        5,6:   inzone = ydiff_b[8:6]==0 && ydiff[8:6]==0; // 64
        7:     inzone = ydiff_b[8:7]==0 && ydiff[8:7]==0;   // 128
    endcase
    case( size )
        0,2:   hdone = 1;
        1,3,5: hdone = hstep==1;
        4,6:   hdone = hstep==3;
        7:     hdone = hstep==7;
    endcase
    case( size )
        0,2:   hadd = 0;
        1,3,5: hadd = 9'h10;
        4,6:   hadd = 9'h40;
        7:     hadd = 9'h80;
    endcase
end

// DMA logic
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        vb_start_n <= 0;
        dma_clr    <= 0;
        dma_done   <= 0;
        dma_addr   <= 0;
        dma_cen    <= 0; // 3 MHz
        obj_enb    <= 0;
        lvbl_l     <= 0;
    end else if( pxl_cen ) begin
        lvbl_l <= lvbl;
        if( !lvbl && lvbl_l ) obj_enb <= mmr[REG_CFG][4];
        dma_cen <= ~dma_cen; // not really a cen, must be combined with pxl_cen
        if( lvbl ) begin
            dma_done   <= 0;
            dma_clr    <= 1;
            dma_addr   <= 0;
            dma_ok     <= 0;
            vb_start_n <= 1;
        end else if(!obj_enb && dma_cen) begin
            vb_start_n <= !(dma_clr || !dma_done);
            if( dma_clr ) begin // clear the full buffer (341.3 us as original)
                { dma_clr, dma_addr } <= { 1'b1, dma_addr } + 1'd1;
                dma_ok <= 0;
            end else if( !dma_clr && !dma_done ) begin // copy by priority order
                { dma_done, dma_addr } <= { 1'b0, dma_addr } + 1'd1;
                if( dma_addr[2:0]==0 ) begin
                    dma_prio <= dma_data[6:0];
                    if( !dma_data[7] ) begin
                        { dma_done, dma_addr } <= { 1'b0, dma_addr[9:3], 3'd0 } + 11'd8;
                        dma_ok <= 0;
                    end else begin
                        dma_ok <= 1;
                    end
                end
                if( dma_addr[2:0]==7 ) dma_ok <= 0;
            end
        end
    end
end


(* direct_enable *) reg cen2=0;
always @(negedge clk) cen2 <= ~cen2;

always @(posedge clk) begin
    /* verilator lint_off WIDTH */
    yz_add <= {vzoom,3'b0}*ydiff_b;
    /* verilator lint_on WIDTH */
end

// Table scan
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        lhbl_l   <= 0;
        scan_obj <= 0;
        scan_sub <= 0;
        hstep    <= 0;
        code     <= 0;
        attr     <= 0;
        vflip    <= 0;
        hflip    <= 0;
        vzoom    <= 0;
        hzoom    <= 0;
        hz_keep  <= 0;
        busy_l   <= 0;
    end else if( cen2 ) begin
        lhbl_l <= lhbl;
        busy_l <= dr_busy;
        dr_start <= 0;
        if( !lhbl && lhbl_l && vdump>9'h10D && vdump<9'h1f1) begin
            done     <= 0;
            scan_obj <= 0;
            scan_sub <= 0;
            vlatch   <= vdump;
        end else if( !done ) begin
            scan_sub <= scan_sub + 1'd1;
            case( scan_sub )
                1: begin
                    { size, code[12:8] } <= scan_dout;
                    hstep   <= 0;
                    hz_keep <= 0;
                end
                2: code[7:0] <= scan_dout;
                3: attr <= scan_dout;
                4: { vzoom, vflip, y[8] } <= scan_dout;
                5: y[7:0] <= scan_dout;
                6: begin
                    { hzoom, hflip, hpos[8] } <= scan_dout;
                    hstep <= 0;
                    // Add the vertical offset to the code
                    case( size ) // could be + or |
                        2,3,4: {code[5],code[3],code[1]} <= { code[5], code[3], ydiff[4]^vflip   };
                        5,6  : {code[5],code[3],code[1]} <= { code[5], ydiff[5:4]^{2{vflip}} };
                        7    : {code[5],code[3],code[1]} <= ( ydiff[6:4]^{3{vflip}});
                    endcase
                    hcode <= {code[4],code[2],code[0]};
                    if( !inzone ) begin
                        scan_sub <= 1;
                        scan_obj <= scan_obj + 1'd1;
                        if( &scan_obj ) done <= 1;
                    end
                    // attr[6:0] <= attr[6:0]^{7{scan_dout[1]}}; // highlight hflipped sprite
                    // attr[2:0] <= size;
                end
                7: begin
                    scan_sub <= 7;
                    if( (!dr_start && !busy_g) || !inzone ) begin
                        case( size )
                            0,2:   {code[4],code[2],code[0]} <= hcode;
                            1,3,5: {code[4],code[2],code[0]} <= {hcode[2],hcode[1],hstep[0]^hflip};
                            4,6:   {code[4],code[2],code[0]} <= {hcode[2],hstep[1:0]^{2{hflip}}};
                            7:     {code[4],code[2],code[0]} <= hstep[2:0]^{3{hflip}};
                        endcase
                        if( hstep==0 )
                            hpos <= { hpos[8], scan_dout } + 9'd9; //{debug_bus[7], debug_bus };
                        else begin
                            hpos <= hpos + 9'h10;
                            hz_keep <= 1;
                        end
                        hstep <= hstep + 1'd1;
                        dr_start <= inzone;
                        if( hdone || !inzone ) begin
                            scan_sub <= 1;
                            scan_obj <= scan_obj + 1'd1;
                            if( &scan_obj ) done <= 1;
                        end
                    end
                end
            endcase
        end
    end
end

// Register map
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mmr[0]  <= 8'h10; mmr[2] <= 0; mmr[3] <= 0; mmr[4]  <= 0;
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

jtframe_dual_ram u_copy(
    // Port 0: DMA
    .clk0   ( clk            ),
    .data0  ( dma_din        ),
    .addr0  ( dma_wr_addr    ),
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
