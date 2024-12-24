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
    Date: 2-4-2022 */

// This module implements the pc080sn logic
// The original clock was 26.686MHz/2 = 13.343MHz
// Using 48MHz as basis, the ratio is 1073/3860

module jtrastan_tilemap #( parameter
    RAM_MSB  = 0
)(
    input           rst,
    input           clk,

    input           flip,
    input    [ 8:0] hdump,
    input    [ 8:0] vdump,

    input    [ 8:0] hpos,
    input    [ 8:0] vpos,

    // VRAM is stored in the SDRAM
    output   [15:2] ram_addr,
    input    [31:0] ram_data,
    input           ram_ok,
    output reg      ram_cs,

    output reg [19:2] rom_addr,
    input      [31:0] rom_data,
    input             rom_ok,
    output reg        rom_cs,
    input      [ 7:0] debug_bus,

    output  [10:0]  pxl
);

wire        hinit, dr_start;
wire [15:0] code, attr;
reg  [ 8:0] hcnt, vscan, vf, buf_addr, hrdout;
reg  [ 8:3] hscan;
reg  [ 6:0] cur_pal;
reg         scan_st, scan_wait, dr_busy, buf_we, hflip;
reg  [31:0] pxl_data;
wire [ 3:0] cur_pxl;
reg  [ 2:0] buf_cnt;

assign hinit    = hdump==(9'd320+9'd60);
assign ram_addr = { RAM_MSB[0], 1'b0, vscan[8:3], hscan }; // 14 bits
assign dr_start = ram_ok && !dr_busy && !scan_wait;
assign { code, attr } = ram_data;
assign cur_pxl  = hflip ? pxl_data[31:28] : pxl_data[3:0];

always @* begin
    hscan = hcnt[8:3] + ~hpos[8:3] + 6'd2;
    hrdout = hdump -9'd5;
    vf    = flip ? vdump-9'd240 : vdump+9'd8;
    vscan = vf  + ~vpos;
end

always @(posedge clk, posedge rst) begin
    if(rst) begin
        scan_st   <= 0;
        ram_cs    <= 0;
        scan_wait <= 0;
    end else begin
        scan_wait <= 0;
        case( scan_st )
            0: begin
                hcnt <= 0;
                if ( hinit ) begin
                    scan_st <= 1;
                    ram_cs  <= 1;
                    scan_wait <= 1;
                end
            end
            1: if( dr_start ) begin
                scan_wait <= 1;
                hcnt[8:3] <= hcnt[8:3] + 6'd1;
                if( hcnt >= 9'h158 ) begin
                    scan_st <= 0;
                    ram_cs  <= 0;
                end
            end
        endcase
    end
end

always @(posedge clk, posedge rst) begin
    if(rst) begin
        dr_busy <= 0;
        cur_pal <= 0;
        buf_we  <= 0;
        rom_cs  <= 0;
    end else begin
        if( scan_st==0 && !dr_busy ) buf_addr <= { 6'd0, hpos[2:0] };
        if( dr_start ) begin
            hflip    <= attr[14];
            cur_pal  <= attr[6:0];
            rom_addr <= { code[14:0], vscan[2:0]^{3{attr[15]}} }; // 15+3+1=19
            rom_cs   <= 1;
            dr_busy  <= 1;
            buf_cnt  <= 3'd7;
        end
        if( dr_busy ) begin
            if( rom_ok && !buf_we ) begin
                pxl_data <= {
                    rom_data[27:24], rom_data[31:28],
                    rom_data[19:16], rom_data[23:20],
                    rom_data[11: 8], rom_data[15:12],
                    rom_data[ 3: 0], rom_data[ 7: 4] };
                buf_we   <= 1;
                rom_cs   <= 0;
            end
            if( buf_we ) begin
                buf_addr <= buf_addr + 1'd1;
                buf_cnt <= buf_cnt - 3'd1;
                pxl_data <= hflip ? pxl_data<<4 : pxl_data>>4;
                if( buf_cnt==0 ) begin
                    buf_we <= 0;
                    dr_busy <= 0;
                end
            end
        end
    end
end
/*
`ifdef SIMULATION
reg check=0;
always @(posedge clk) begin
    if(hinit) check<=1;
    if ( hdump<320 && hdump > hcnt && check && hcnt!=0) begin
        $display("Horizontal buffer overrun %m");
        //$finish;
    end
end
`endif
*/
// Not a double line buffer
jtframe_dual_ram #(
    .DW (4+7    ),
    .AW ( 9     )  // 320 points
) u_buffer(
    // Port 0
    .clk0   ( clk       ),
    .data0  ( {cur_pal, cur_pxl } ),
    .addr0  ( buf_addr  ),
    .we0    ( buf_we    ),
    .q0     (           ),
    // Port 1: readout
    .clk1   ( clk       ),
    .data1  (           ),
    .addr1  ( hrdout    ),
    .we1    ( 1'd0      ),
    .q1     ( pxl       )
);


endmodule