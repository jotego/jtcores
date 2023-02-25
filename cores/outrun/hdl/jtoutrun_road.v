/*  This file is part of JTS16.
    JTS16 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTS16 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTS16.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 9-7-2022 */

module jtoutrun_road(
    input              rst,
    input              clk,
    input              pxl_cen,
    input        [8:0] v,
    input              vint,
    input              hs,

    // CPU interface
    input       [11:1] cpu_addr,
    input       [15:0] cpu_dout,
    output      [15:0] cpu_din,
    input       [ 1:0] cpu_dsn,
    input              cpu_rnw,
    input              road_cs,
    input              io_cs,

    // ROM access
    output      [13:0] rom0_addr,
    input       [15:0] rom0_data,
    output             rom0_cs,
    input              rom0_ok,

    output      [13:0] rom1_addr,
    input       [15:0] rom1_data,
    output             rom1_cs,
    input              rom1_ok,
    // Pixel output
    input       [ 7:0] debug_bus,
    output reg  [ 7:0] pxl,
    output reg  [ 4:3] rc,

    input       [ 7:0] st_addr,
    output reg  [ 7:0] st_dout,
    // SD card dumps
    input      [21:0]  ioctl_addr,
    input              ioctl_ram,
    output     [ 7:0]  ioctl_din
);

    reg  [10:0] rd_addr;
    wire [15:0] rd_gfx;
    wire [ 1:0] rd_we;
    reg         ram_half, toggle;
    reg         viq;
    reg  [ 1:0] ctrl;
    reg  [ 2:0] st;
    wire [ 1:0] rd_a, rd_b;
    wire        cent_a, cent_b;
/* verilator lint_off UNOPTFLAT */
    reg  [ 4:0] rrc;
/* verilator lint_on  UNOPTFLAT */

    reg  [11:0] rd0_idx, rd1_idx,
                rd0_scr, rd1_scr, rds_col,
                rd0_col, rd1_col;
    reg  [ 6:0] solid;

    localparam [1:0] ONLY_ROAD0=0, ROAD0_PRIO=1,
                     ROAD1_PRIO=2, ONLY_ROAD1=3;

    assign rd_we   = {2{road_cs & ~cpu_rnw}} & ~cpu_dsn;

    always @(posedge clk) begin
        case( st_addr[2:0] )
            0: st_dout <= {  3'd0, ram_half, 2'd0, ctrl };
            1: st_dout <= rd0_scr[11:4];
            2: st_dout <= rd0_idx[11:4];
            3: st_dout <= rd1_scr[11:4];
            4: st_dout <= rd1_idx[11:4];
        endcase
    end

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            ram_half  <= 0;
            toggle <= 0;
            ctrl   <= 0;
        end else begin
            if( io_cs & ~cpu_dsn[0] & ~cpu_rnw )  ctrl <= cpu_dout[1:0];
            if( !io_cs ) begin
                toggle <= 0;
            end else if( io_cs && cpu_rnw ) begin
                if(!toggle) ram_half  <= ~ram_half;
                toggle <= 1;
            end
        end
    end

    jtframe_dual_nvram16 #(.AW(12),.SIMFILE_LO("roadram_lo.bin"),.SIMFILE_HI("roadram_hi.bin"))
    u_vram0(
        // CPU
        .clk0   ( clk       ),
        .data0  ( cpu_dout  ),
        .addr0  ( {~ram_half, cpu_addr } ),
        .we0    ( rd_we     ),
        .q0     ( cpu_din   ),
        // Road engine
        .clk1   ( clk       ),
        .addr1a ( { ram_half, rd_addr } ),
        .q1a    ( rd_gfx    ),
        // SD card dumps
        .we1b   ( 1'b0      ),
        .data1  (           ),
        .addr1b ( ioctl_addr[12:0]),
        .sel_b  ( ioctl_ram ),
        .q1b    ( ioctl_din )
    );

    always @* begin
        case( st )
            0:  rd_addr = { 3'd0, v[7:0] };
            1:  rd_addr = { 3'd1, v[7:0] };
            2:  rd_addr = { 2'd1, rd0_idx[8:0] };
            3:  rd_addr = { 2'd3, rd0_idx[8:0] };
            4:  rd_addr = { 2'd2, rd1_idx[8:0] };
            default:
                rd_addr = { 2'd3, rd1_idx[8:0] };
        endcase
    end

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            st      <= 0;
            rd0_idx <= 0;
            rd1_idx <= 0;
            rd0_scr <= 0;
            rd1_scr <= 0;
            rd0_col <= 0;
            rd1_col <= 0;
        end else if(pxl_cen) begin
            if( hs ) begin
                if(st<6) st <= st + 3'd1;
                case( st )
                    0: rd0_idx <= rd_gfx[11:0];
                    1: rd1_idx <= rd_gfx[11:0];
                    2: rd0_scr <= rd_gfx[11:0];
                    3: rd0_col <= rd_gfx[11:0];
                    4: rd1_scr <= rd_gfx[11:0];
                    5: rd1_col <= rd_gfx[11:0];
                    default:;
                endcase
            end else begin
                st <= 0;
            end
        end
    end

    wire only_road0 = ctrl==ONLY_ROAD0,// || debug_bus[0],
         only_road1 = ctrl==ONLY_ROAD1,// && !debug_bus[0],
         road0_prio = ctrl==ROAD0_PRIO,// && !debug_bus[0],
         road1_prio = ctrl==ROAD1_PRIO;// && !debug_bus[0];

    always @* begin
        viq = ~hs | (hs & ( ~rrc[3] | ~rrc[4] ));

        rrc = 0;
        // active road: high for rd_b, low for rd_a
        rrc[2] = (hs && viq) ||
                 only_road1 ||
                 ( !cent_a && rd_a==3 && !cent_b && rd_b==3 && road1_prio ) ||
                 ( !cent_a && rd_a==3 &&  cent_b && rd_b==3 && road0_prio ) ||
                 ( !cent_a && rd_a==3 &&            rd_b==1 && road0_prio ) ||
                 ( !cent_a && rd_a==3 &&            rd_b==2 && road0_prio ) ||
                 ( !cent_a && rd_a==3 &&           !rd_b[0] && road1_prio ) ||
                 ( !cent_a && rd_a==3 &&           !rd_b[1] && road1_prio ) ||

                 ( !cent_a && rd_a[0] &&            rd_b==0 && road0_prio ) ||
                 ( !cent_a && rd_a[1] &&            rd_b==0 && road0_prio ) ||
                 (  cent_b && rd_b==3             && road1_prio ) ||
                 (  cent_b && rd_b==3 && !rd_a[0] && road0_prio ) ||
                 (  cent_b && rd_b==3 && !rd_a[1] && road0_prio ) ||
                 ( !rd_a[0] && rd_b==0 && road1_prio ) ||
                 ( !rd_a[1] && rd_b==0 && road1_prio );
        // road bit 0 set
        // cent here does not affect whether the line in the road center
        rrc[0] = rrc[2] ? ( rd_b==1 || (cent_b && rd_b==3) ) :
                          ( rd_a==1 || (cent_a && rd_a==3) );
        // road bit 1 set
        rrc[1] = rrc[2] ? ( rd_b==2 || (cent_b && rd_b==3) ) :
                          ( rd_a==2 || (cent_a && rd_a==3) );
        // road not from ROM -sky solid color-
        rrc[3] = (rd0_idx[11] && rd1_idx[11]) ||
                 (rd0_idx[11] && only_road0 ) ||
                 (rd1_idx[11] && only_road1 );
        // road not from ROM or blank pixel. cent here does not
        // affect whether the line in the road center
        rrc[4] = rrc[3] ||
                ( !cent_a && rd_a==3 && !cent_b && rd_b==3 ) ||
                ( !cent_b && rd_b==3 && only_road1 ) ||
                ( !cent_a && rd_a==3 && only_road0 );
        rds_col = rrc[2] ? rd1_col : rd0_col;           // stripes in the road
        solid   = rrc[2] ? rd1_idx[6:0] : rd0_idx[6:0]; // stripes in the sky
    end

    always @(posedge clk) if(pxl_cen) begin
        pxl <= !rrc[4] ? {4'd0, rrc[2:0], rds_col[{1'b0, rrc[2:0]} /* road stripes */ ] } :
                rrc[3] ? { 1'b1, solid } :          // sky stripes
                { 3'b001, rrc[2], rds_col[11:8] };  // road stripes
        rc[4:3] <= rrc[4:3];
    end

    jtoutrun_rdrom u_rom0(
        .rst        ( rst       ),
        .clk        ( clk       ),
        .pxl_cen    ( pxl_cen   ),

        .hs         ( hs        ),
        .cfg        ( rd0_idx   ),
        .hscr       ( rd0_scr   ),

        .rom_addr   ( rom0_addr ),
        .rom_data   ( rom0_data ),
        .rom_cs     ( rom0_cs   ),
        .rom_ok     ( rom0_ok   ),
        .cent       ( cent_a    ),
        .pxl        ( rd_a      )
    );

    jtoutrun_rdrom u_rom1(
        .rst        ( rst       ),
        .clk        ( clk       ),
        .pxl_cen    ( pxl_cen   ),

        .hs         ( hs        ),
        .cfg        ( rd1_idx   ),
        .hscr       ( rd1_scr   ),

        .rom_addr   ( rom1_addr ),
        .rom_data   ( rom1_data ),
        .rom_cs     ( rom1_cs   ),
        .rom_ok     ( rom1_ok   ),
        .cent       ( cent_b    ),
        .pxl        ( rd_b      )
    );

endmodule

module jtoutrun_rdrom(
    input              rst,
    input              clk,
    input              pxl_cen,
    input              hs,

    input       [11:0] cfg,
    input       [11:0] hscr,

    output      [13:0] rom_addr,
    input       [15:0] rom_data, // 2 bpp data, 8 pixels in 16 bits
    output reg         rom_cs,
    input              rom_ok,
    output reg         cent, // this seems to mean the road central 8 pixels
    output      [ 1:0] pxl
);
    parameter HOFF = 12'h18;

    reg  [11:0] hpos;
    reg  [15:0] pxl_data;
    wire        en;
    wire        j, k;

    assign pxl  = { pxl_data[15], pxl_data[7] };
    assign rom_addr = { cfg[8:1], hpos[8:3] };
    assign en   = !cfg[11] && hpos[11:9]==3'b011;
    assign j    = &hpos[2:0];
    assign k    = hpos[11:9]==3'b011 && hpos[8:0] == 9'hff;

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            rom_cs   <= 0;
            pxl_data <= 0;
            hpos     <= 0;
            cent     <= 0;
        end else begin
            if( hs ) begin
                rom_cs   <= 0;
                hpos     <= hscr - HOFF;
                pxl_data <= 16'hffff;
                cent     <= 0;
            end else if( pxl_cen ) begin
                rom_cs <= en;
                hpos   <= hpos + 11'd1;
                case( {j,k} )
                    1:  cent <= 1;
                    2:  cent <= 0;
                    3:  cent <= ~cent;
                endcase
                if( hpos[2:0]==3 ) begin // 3 pixel delay, to give time to the SDRAM
                    pxl_data <= !en ? 16'hffff : rom_data;
                end else begin
                    pxl_data <= pxl_data << 1;
                end
            end
        end
    end

endmodule