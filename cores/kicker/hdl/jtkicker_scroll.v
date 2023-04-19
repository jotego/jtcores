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
    Date: 14-11-2021 */

module jtkicker_scroll(
    input               rst,
    input               clk,        // 48 MHz
    input               clk24,      // 24 MHz

    input               pxl_cen,

    // CPU interface
    input        [10:0] cpu_addr,
    input         [7:0] cpu_dout,
    input               cpu_rnw,
    input               vram_cs,
    input               vscr_cs,
    output        [7:0] vram_dout,
    output        [7:0] vscr_dout,

    // video inputs
    input               LHBL,
    input               LVBL,
    input         [7:0] vdump,
    input         [8:0] hdump,
    input               flip,

    // PROMs
    input         [3:0] prog_data,
    input         [7:0] prog_addr,
    input               prog_en,

    // SDRAM
    output reg   [12:0] rom_addr,
    input        [31:0] rom_data,
    input               rom_ok,

    output        [3:0] pxl,
    output reg          prio,
    input         [7:0] debug_bus
);

// Layout
// 0  Kicker
// 1  Yie Ar Kungfu
// 2  Super Basketball
// 3  Mikie
// 4  Road Fighter

parameter BYPASS_PROM=0, NOSCROLL=0;
parameter LAYOUT = !NOSCROLL ? 0 : 1;
parameter BSEL =
    LAYOUT==2 || LAYOUT==3 || LAYOUT==5 ? 10 :
    NOSCROLL ? 0 : 10;
parameter PACKED = LAYOUT==2 || LAYOUT==3;
// Column at which the score table ends. This is set by fixed logic
// in all games inspected so far. Thus, I encode it as a parameter
parameter [8:0] SCRCOL = LAYOUT==2 ? 9'o60 : // Super Basketball
                         LAYOUT==3 ? 9'o00 : // Mikie - doesn't use this feature
                         LAYOUT==5 ? 9'o00 : // Roc   - doesn't use this feature
                         9'o40;

wire [ 7:0] code, attr, vram_high, vram_low, pal_addr;
reg  [ 3:0] pal_msb;
reg  [ 3:0] cur_pal;
reg  [ 1:0] code_msb;
reg  [31:0] pxl_data;
wire [ 9:0] rd_addr;
reg  [ 7:0] hdf, vpos, vscr;
reg         cur_hf;
wire        vram_we_low, vram_we_high;
reg         vflip, hflip;
wire        vram_we;
reg  [ 9:0] eff_addr;
reg         scr_prio;
reg         cur_prio;

assign vram_we      = vram_cs & ~cpu_rnw;
assign vram_we_low  = vram_we & ~cpu_addr[BSEL];
assign vram_we_high = vram_we &  cpu_addr[BSEL];
assign vram_dout    = cpu_addr[BSEL] ? vram_high : vram_low;

always @* begin
    hdf = flip ? (~hdump[7:0]-8'd3) : hdump[7:0];
    eff_addr =  LAYOUT==5 ? cpu_addr[9:0] :
                (NOSCROLL && LAYOUT!=3) ? cpu_addr[10:1] :
                cpu_addr[9:0];
    case( LAYOUT )
        0: begin // Kicker
            vflip    = attr[5];
            hflip    = attr[4];
            code_msb = attr[7:6];
            pal_msb  = attr[3:0];
            scr_prio = 0;
        end
        1: begin // Yie Ar Kungfu
            hflip    = attr[7];
            vflip    = attr[6];
            code_msb = {1'b0,attr[4]};
            pal_msb  = 0;
            scr_prio = 0;
        end
        2,3: begin // Super Basketball & Mikie
            code_msb = {1'b0,attr[5]};
            vflip    = attr[7];
            hflip    = ~attr[6];
            pal_msb  = attr[3:0];
            scr_prio = attr[4];
        end
        4: begin // Road Fighter
            code_msb = {1'b0,attr[5]};
            vflip    = 0;
            hflip    = attr[4];
            pal_msb  = attr[3:0];
            scr_prio = attr[4];
        end
        5: begin // Roc'n Rope
            code_msb = {1'b0,attr[7]};
            vflip    = attr[5];
            hflip    = attr[6];
            scr_prio = attr[4];
            pal_msb  = attr[3:0];
        end
    endcase
end

assign rd_addr  = { vscr[7:3], hdf[7:3] }; // 5+5 = 10
assign vscr_dout= NOSCROLL ? 8'd0 : vscr; // this could be vdump instead of vscr, it's hard to
                        // measure it in a test program because vscr=vdump
                        // for the first rows, which is when the NMI occurs
assign pal_addr =
    //flip && hdump<9'o20 ? 8'd0 :   // removes the first columns in flip mode
    { cur_pal, cur_hf ? pxl_data[3:0] : pxl_data[31:28] };

// scroll register in custom chip 085
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        vpos <= 0;
        vscr <= 0;
    end else begin
        if( vscr_cs  ) vpos <= cpu_dout;
        if( NOSCROLL || (flip ? hdf< SCRCOL[7:0] : hdump<SCRCOL) ) begin
            vscr <= {8{flip}} ^ vdump;
        end else begin
            // +1 needed to have a straight grid during boot up
            vscr <= ({8{flip}} ^ vdump) + vpos + 8'd1;
        end
    end
end

always @(posedge clk) if(pxl_cen) begin
    if( hdump[2:0]==0 ) begin
        rom_addr <= { code_msb, code, vscr[2:0]^{3{vflip}} }; // 2+8+3=13 bits
    end
    if( hdump[2:0]==4 ) begin // 2 pixel delay to grab data
        pxl_data <= PACKED ? rom_data
        : {
            rom_data[27], rom_data[31], rom_data[19], rom_data[23],
            rom_data[26], rom_data[30], rom_data[18], rom_data[22],
            rom_data[25], rom_data[29], rom_data[17], rom_data[21],
            rom_data[24], rom_data[28], rom_data[16], rom_data[20],
            rom_data[11], rom_data[15], rom_data[ 3], rom_data[ 7],
            rom_data[10], rom_data[14], rom_data[ 2], rom_data[ 6],
            rom_data[ 9], rom_data[13], rom_data[ 1], rom_data[ 5],
            rom_data[ 8], rom_data[12], rom_data[ 0], rom_data[ 4]
        };
        cur_hf   <= hflip^flip;
        cur_pal  <= pal_msb;
        cur_prio <= scr_prio;
    end else begin
        pxl_data <= cur_hf ? pxl_data>>4 : pxl_data<<4;
    end
end

jtframe_dual_ram #(.SIMFILE("vram_lo.bin")) u_low(
    // Port 0, CPU
    .clk0   ( clk24         ),
    .data0  ( cpu_dout      ),
    .addr0  ( eff_addr      ),
    .we0    ( vram_we_low   ),
    .q0     ( vram_low      ),
    // Port 1
    .clk1   ( clk           ),
    .data1  (               ),
    .addr1  ( rd_addr       ),
    .we1    ( 1'b0          ),
    .q1     ( attr          )
);

jtframe_dual_ram #(.SIMFILE("vram_hi.bin")) u_high(
    // Port 0, CPU
    .clk0   ( clk24         ),
    .data0  ( cpu_dout      ),
    .addr0  ( eff_addr      ),
    .we0    ( vram_we_high  ),
    .q0     ( vram_high     ),
    // Port 1
    .clk1   ( clk           ),
    .data1  (               ),
    .addr1  ( rd_addr       ),
    .we1    ( 1'b0          ),
    .q1     ( code          )
);

generate
    if( BYPASS_PROM ) begin
        assign pxl = pal_addr[3:0];
        initial prio=0; // unused
    end else begin
        jtframe_prom #(
            .DW ( 4     ),
            .AW ( 8     )
        //    SIMFILE = "477j09.b8",
        ) u_palette(
            .clk    ( clk       ),
            .cen    ( pxl_cen   ),
            .data   ( prog_data ),
            .wr_addr( prog_addr ),
            .we     ( prog_en   ),

            .rd_addr( pal_addr  ),
            .q      ( pxl       )
        );
        always @(posedge clk) if(pxl_cen) prio <= cur_prio;
    end
endgenerate

endmodule