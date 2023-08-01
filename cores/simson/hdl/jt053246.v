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
    Date: 30-7-2023 */

// Based on 051960 (previous generation of sprite hardware)
// and MAME documentation

// 256 sprites, 8x 16-bit data per sprite
// Sprite table = 256*8*2=4096 = (0x1000)
// DMA transfer takes 297.5us, and occurs 1 line after VS finishes
// The PCB may detect end of the DMA transfer and set
// an interrupt on it
// DMA duration may depend on the number of elements to transfer
// If all table entries were copied, it would take:
// 256 x 8 = 2048 -> 642 @ 3MHz, 341us @ 6MHz or 170.6us @ 12MHz

module jt053246(    // sprite logic
    input             rst,
    input             clk,
    input             pxl2_cen,
    input             pxl_cen,

    // CPU interface
    input             cs,
    input             cpu_we,
    input      [ 2:1] cpu_addr,
    input      [15:0] cpu_dout,
    input      [ 1:0] cpu_dsn,

    // ROM check by CPU
    output reg [21:1] rmrd_addr,

    // External RAM
    output reg [13:1] dma_addr, // up to 16 kB
    input      [15:0] dma_data,
    output reg        dma_bsy,

    // ROM addressing 22 bits in total
    output reg [15:0] code,
    // There are 22 bits communicating both chips on the PCB
    output reg [ 7:0] attr,     // OC pins
    output            hflip,
    output            vflip,
    output reg [ 8:0] hpos,
    output     [ 3:0] ysub,
    output reg [ 9:0] hzoom,
    output reg        hz_keep,

    // base video
    input      [ 8:0] hdump,    // Not inputs in the original, but
    input      [ 8:0] vdump,    // generated internally.
                                // Hdump goes from 20 to 19F, 384 pixels
                                // Vdump goes from F8 to 1FF, 264 lines
    input             vs,
    input             lvbl,
    input             hs,

    // shadow
    input      [ 8:0] pxl,
    output reg [ 1:0] shd,

    // draw module / 051937
    output reg        dr_start,
    input             dr_busy,

    // Debug
    input      [ 7:0] debug_bus,
    input      [ 7:0] st_addr,
    output reg [ 7:0] st_dout
);

localparam [2:0] REG_XOFF  = 0, // X offset
                 REG_YOFF  = 1, // Y offset
                 REG_CFG   = 2; // interrupt control, ROM read

wire        vb_rd, dma_we;
reg  [ 9:0] xoffset, yoffset;
reg  [ 7:0] cfg;
reg  [ 1:0] reserved, effect;

reg  [ 9:0] vzoom;
reg  [ 2:0] scan_sub, hstep, hcode;
reg  [ 8:0] ydiff, ydiff_b, vlatch;
reg  [ 9:0] y, x;
reg  [ 7:0] dma_prio, scan_obj; // max 256 objects
reg         dma_clr, dma_done, inzone, hs_l, done, hdone, busy_l;
wire [15:0] scan_dout;
reg  [ 3:0] size;
wire [15:0] dma_din;
wire [11:1] scan_addr, dma_wr_addr;
reg  [17:0] yz_add;
reg         dma_ok, vmir, hmir, sq, pre_vf, pre_hf;
wire        busy_g, cpu_bsy;
wire        ghf, gvf, dma_en;

assign ghf     = cfg[0]; // global flip
assign gvf     = cfg[1];
assign cpu_bsy = cfg[3];
assign dma_en  = cfg[4];
assign vflip   = pre_vf & ~vmir;
assign hflip   = pre_hf & ~hmir;

assign dma_din     = dma_clr ? 16'hffff : dma_data;
assign dma_we      = dma_bsy & (dma_clr | dma_ok);
assign dma_wr_addr = dma_clr ? dma_addr[11:1] : { dma_prio, dma_addr[3:1] };

assign scan_addr   = { scan_obj, scan_sub };
assign ysub        = ydiff[3:0];
assign busy_g      = busy_l | dr_busy;

always @* begin
    ydiff_b= y[8:0] + vlatch;
    ydiff  = ydiff_b+yz_add[17-:9];
    case( size[3:2] )
        0: inzone = ydiff_b[8:4]==0 && ydiff[8:4]==0; // 16
        1: inzone = ydiff_b[8:5]==0 && ydiff[8:5]==0; // 32
        2: inzone = ydiff_b[8:6]==0 && ydiff[8:6]==0; // 64
        3: inzone = ydiff_b[8:7]==0 && ydiff[8:7]==0; // 128
    endcase
    case( size[1:0] )
        0: hdone = 1;
        1: hdone = hstep==1;
        2: hdone = hstep==3;
        3: hdone = hstep==7;
    endcase
end

// DMA logic
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dma_bsy  <= 0;
        dma_clr  <= 0;
        dma_done <= 0;
        dma_addr <= 0;
    end else if( pxl2_cen ) begin
        if( dma_done && !dma_clr ) dma_bsy <= 0;
        if( vdump==9'h101 ) begin
            dma_done <= ~dma_en;
            dma_addr <= 0;
            dma_clr  <= 0;
            dma_ok   <= 0;
            dma_bsy  <= 0;
            dma_prio <= 0;
        end else if( !dma_done ) begin // copy by priority order
            dma_bsy  <= 1;
            { dma_done, dma_addr } <= { 1'b0, dma_addr } + 1'd1;
            if( dma_addr[3:1]==0 ) begin
                dma_prio <= dma_data[7:0];
                if( dma_data==0 ) begin
                    dma_done <= 1;
                    dma_clr  <= 1; // clear the rest of the list
                    dma_addr[11:1] <= { dma_prio, 3'd0 };
                    dma_ok   <= 0;
                end else if( !dma_data[15] ) begin // skip this one
                    { dma_done, dma_addr[11:1] } <= { 1'b0, dma_addr[11:4], 3'd0 } + 12'd8;
                    dma_ok  <= 0;
                end else begin
                    dma_ok <= 1;
                end
            end
            if( dma_addr[3:1]==7 ) dma_ok <= 0;
        end else if( dma_clr ) begin
            { dma_clr, dma_addr[11:1] } <= { 1'b1, dma_addr[11:1] } + 1'd1;
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
        hs_l     <= 0;
        scan_obj <= 0;
        scan_sub <= 0;
        hstep    <= 0;
        code     <= 0;
        attr     <= 0;
        pre_vf   <= 0;
        pre_hf   <= 0;
        vzoom    <= 0;
        hzoom    <= 0;
        hz_keep  <= 0;
        busy_l   <= 0;
    end else if( cen2 ) begin
        hs_l <= hs;
        busy_l <= dr_busy;
        dr_start <= 0;
        if( hs && !hs_l && vdump>9'h10D && vdump<9'h1f1) begin
            done     <= 0;
            scan_obj <= 0;
            scan_sub <= 0;
            vlatch   <= vdump;
        end else if( !done ) begin
            scan_sub <= scan_sub + 1'd1;
            case( scan_sub )
                0: { sq, pre_vf, pre_hf, size } <= scan_dout[14:8];
                1: begin
                    code    <= scan_dout;
                    hstep   <= 0;
                    hz_keep <= 0;
                end
                2: y <= scan_dout[9:0]^{10{gvf}};
                3: x <= scan_dout[9:0]^{10{ghf}};
                4: begin
                    x <= x + {9'd0,ghf};
                    y <= x + {9'd0,gvf};
                    vzoom <= scan_dout[9:0];
                    hzoom <= scan_dout[9:0];
                end
                5: begin
                    if(!sq) hzoom <= scan_dout[9:0];
                    x <=  x - xoffset;
                    y <= -y - yoffset;
                end
                6: begin
                    { vmir, hmir, reserved, shd, effect, attr } <= scan_dout;
                    hstep <= 0;
                    // Add the vertical offset to the code
                    case( size ) // could be + or |
                        1: {code[5],code[3],code[1]} <= { code[5], code[3], ydiff[4]^vflip   };
                        2: {code[5],code[3],code[1]} <= { code[5], ydiff[5:4]^{2{vflip}} };
                        3: {code[5],code[3],code[1]} <= ( ydiff[6:4]^{3{vflip}});
                    endcase
                    hcode <= {code[4],code[2],code[0]};
                    if( !inzone ) begin
                        scan_sub <= 1;
                        scan_obj <= scan_obj + 1'd1;
                        if( &scan_obj ) done <= 1;
                    end
                end
                7: begin
                    scan_sub <= 7;
                    if( (!dr_start && !busy_g) || !inzone ) begin
                        case( size )
                            0: {code[4],code[2],code[0]} <= hcode;
                            1: {code[4],code[2],code[0]} <= {hcode[2],hcode[1],hstep[0]^hflip};
                            2: {code[4],code[2],code[0]} <= {hcode[2],hstep[1:0]^{2{hflip}}};
                            3: {code[4],code[2],code[0]} <= hstep[2:0]^{3{hflip}};
                        endcase
                        if( hstep==0 )
                            hpos <= x[8:0]; //{debug_bus[7], debug_bus };
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

`ifdef SIMULATION
reg [7:0] mmr_init[0:7];
integer f,fcnt=0;

initial begin
    f=$fopen("obj_mmr.bin","rb");
    if( f!=0 ) begin
        fcnt=$fread(mmr_init,f);
        $fclose(f);
    end
end
`endif

// Register map
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        xoffset <= 0; yoffset <= 0; cfg <= 0;
`ifdef SIMULATION
        if( fcnt!=0 ) begin
            xoffset <= { mmr_init[1][1:0], mmr_init[0] };
            yoffset <= { mmr_init[3][1:0], mmr_init[2] };
            cfg     <= mmr_init[5];
        end
`endif
        st_dout <= 0;
    end else begin
        if( cs ) begin // note that the write signal is not checked
            case( cpu_addr )
                0: begin
                    if( !cpu_dsn[0] ) xoffset[ 7:0] <= cpu_dout[7:0];
                    if( !cpu_dsn[1] ) xoffset[ 9:8] <= cpu_dout[9:8];
                end
                1: begin
                    if( !cpu_dsn[0] ) yoffset[7:0] <= cpu_dout[7:0];
                    if( !cpu_dsn[1] ) yoffset[9:8] <= cpu_dout[9:8];
                end
                2: begin
                    if( !cpu_dsn[0] ) rmrd_addr[8:1] <= cpu_dout[7:0];
                    if( !cpu_dsn[1] ) cfg <= cpu_dout[15:8];
                end
                3: begin
                    if( !cpu_dsn[0] ) rmrd_addr[16: 9] <= cpu_dout[ 7:0];
                    if( !cpu_dsn[1] ) rmrd_addr[21:17] <= cpu_dout[12:8];
                end
            endcase
        end
        case( st_addr[2:0])
            0: st_dout <= xoffset[7:0];
            1: st_dout <= {6'd0,xoffset[9:8]};
            2: st_dout <= yoffset[7:0];
            3: st_dout <= {6'd0,yoffset[9:8]};
            5: st_dout <= cfg;
            default: st_dout <= 0;
        endcase
    end
end

jtframe_dual_ram16 #(.AW(11)) u_copy( // 11:0 -> 4kB
    // Port 0: DMA
    .clk0   ( clk            ),
    .data0  ( dma_din        ),
    .addr0  ( dma_wr_addr    ),
    .we0    ( {2{dma_we}}    ),
    .q0     (                ),
    // Port 1: scan
    .clk1   ( clk            ),
    .data1  ( 16'd0          ),
    .addr1  ( scan_addr      ),
    .we1    ( 2'b0           ),
    .q1     ( scan_dout      )
);

endmodule
