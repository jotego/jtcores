/*  This file is part of JTBUBL.
    JTBUBL program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTBUBL program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTBUBL.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 29-05-2020 */

module jtbubl_gfx(
    input               rst,
    input               clk,
    input               clk_cpu,
    input               pxl2_cen,
    input               pxl_cen,
    // PROMs
    input      [ 7:0]   prog_addr,
    input      [ 3:0]   prog_data,
    input               prom_we,
    // Screen
    input               flip,
    input               LHBL,
    input               LVBL,
    input      [8:0]    hdump,
    input      [7:0]    vdump,
    // CPU interface
    input               vram_cs,
    output reg [ 7:0]   vram_dout,
    input               cpu_rnw,
    input      [12:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    // SDRAM interface
    output     [17:0]   rom_addr,
    input      [31:0]   rom_data,
    input               rom_ok,
    output reg          rom_cs,
    // Color address to palette
    output     [ 7:0]   col_addr
);

wire [ 7:0] scan0_data, scan1_data, scan2_data, scan3_data;
wire [ 7:0] vram0_dout, vram1_dout, vram2_dout, vram3_dout;
wire [10:0] vram_addr = cpu_addr[11:1];
reg  [ 3:0] vram_we, cpu_cc;
reg  [ 7:0] line_din;
reg  [ 8:0] line_addr;
reg         line_we;
wire [ 3:0] dec_dout;
wire [ 7:0] dec_addr;
reg  [ 4:0] vn;

always @(*) begin
    cpu_cc = 4'd0;
    cpu_cc[{cpu_addr[12],cpu_addr[0]}] = 1;
    vram_we = cpu_cc & {4{~cpu_rnw & vram_cs}};
end


always @(*) begin
    case( cpu_cc )
        4'b0001: vram_dout = vram0_dout;
        4'b0010: vram_dout = vram1_dout;
        4'b0100: vram_dout = vram2_dout;
        4'b1000: vram_dout = vram3_dout;
        default: vram_dout = 8'hff;
    endcase
end

localparam [10:0] OBJ_START = 11'h140;

reg  [ 9:0] code0, code1, code_mux;
// Let's follow the original signal names but in lower case
reg  [ 8:0] oa;   // VRAM address for first read (object)
reg         oatop;
wire [11:0] sa;   // VRAM address for second read (char)
reg  [ 7:0] vsub, sa_base, hotpxl;
reg  [31:0] pxl_data;
reg  [ 8:0] hpos;
reg  [ 3:0] bank, pal0, pal1, pal_mux;
wire [10:0] cbus; // address to read VRAM
reg         ch;
reg  [ 1:0] hflip, vflip;
reg         hf_mux, vf_mux;
reg  [ 1:0] waitok;
//reg         last_LHBL;
reg         busy, idle; // extra cycle to wait for memories
wire [15:0] vrmux;
wire        lden_b, next;
reg         half, newdata;

assign cbus      = ch ? { sa[10:6],oa[0],sa[4:0] } : {1'b1, oatop, oa };
assign rom_addr  = { bank, code_mux, vsub[2:0]^{3{vf_mux}}, 1'b0 }; // 18 bits
assign sa        = { sa_base[7]&sa_base[5], sa_base[4:0], 1'b1 /*unused bit*/, 
                     dec_dout[1:0], vsub[5:3] };
assign dec_addr  = { LVBL, sa_base[7:5], vsub[7:4] };
assign vrmux     = sa[11] ? {scan3_data, scan2_data} : {scan1_data, scan0_data};
assign lden_b    = dec_dout[2];
assign next      = dec_dout[3];

//always @(posedge clk) last_LHBL <= LHBL;

`ifdef SIMULATION
wire [1:0] phase = { ch, oa[0] };
`endif

// Collection of tile information
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        oa      <= 9'd0;
        ch      <= 0;
        idle    <= 0;
        code0   <= 10'd0;
        code1   <= 10'd0;
        bank    <= 4'd0;
        vsub    <= 8'd0;
        hflip   <= 2'b0;
        vflip   <= 2'b0;
        sa_base <= 8'd0;
        newdata <= 0;
    end else begin
        if( hdump[8] && hdump<9'h12B ) begin // note that tile drawing is disabled if LHBL is low
            oa      <= 9'h80;
            ch      <= 0;
            idle    <= 0;
            oatop   <= 1;
            newdata <= 0;
        end else begin
            if( !busy && oa[8:1]!=8'hE0 ) begin // the oa limit was not in the original
                { oa[8:1], ch, oa[0], idle } <= { oa[8:1], ch, oa[0], idle } + 10'd1;
            end
            if(idle) begin
                case( {ch, oa[0]} )
                    2'd0: begin
                        vsub    <= scan2_data+(vdump^{8{flip}});
                        sa_base <= scan3_data;
                    end
                    2'd1: begin
                        oatop   <= ~scan3_data[7];
                        hpos    <= {scan3_data[6], scan2_data };
                        bank    <= scan3_data[3:0]; // there was a provision to use bit 4
                                   // too on the board via a jumper but was never used
                    end
                    2'd2: begin
                        code0   <= vrmux[9:0];
                        pal0    <= vrmux[13:10];
                        hflip[0]<= vrmux[14];
                        vflip[0]<= vrmux[15];                    
                    end
                    2'd3: begin
                        code1   <= vrmux[9:0];
                        pal1    <= vrmux[13:10];
                        hflip[1]<= vrmux[14];
                        vflip[1]<= vrmux[15];
                    end
                endcase
            end
            newdata <= {ch, oa[0],idle}==3'b110;
        end
    end
end

// Tile drawing
function [3:0] get_pxl;
    input [31:0] pxl_data;
    input        hflip;

    get_pxl = hflip ?
        { pxl_data[7], pxl_data[15], pxl_data[23], pxl_data[31] } :
        { pxl_data[0], pxl_data[ 8], pxl_data[16], pxl_data[24] };
endfunction

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        busy    <= 0;
        rom_cs  <= 0;
        line_we <= 0;
        waitok  <= 2'b11;
    end else begin
        /*if( !LHBL ) begin
            busy    <= 0;
            line_we <= 0;
            rom_cs  <= 0;            
        end else*/
        if( newdata & ~next) begin
            busy        <= 1;
            rom_cs      <= 1;
            waitok      <= 2'b11;
            if(!lden_b) line_addr <= hpos;
            line_we     <= 0;
            code_mux    <= code0;
            hf_mux      <= hflip[0];
            vf_mux      <= vflip[0];
            pal_mux     <= pal0;
            half        <= 0;
        end else if(busy) begin
            waitok[0] <= 0;
            if( waitok[1] && rom_ok ) begin
                pxl_data <= { 
                    rom_data[19:16], rom_data[ 3: 0], // plane 0
                    rom_data[23:20], rom_data[ 7: 4], // plane 1
                    rom_data[27:24], rom_data[11: 8], // plane 2
                    rom_data[31:28], rom_data[15:12]  // plane 3
                 };
                hotpxl    <= 8'h0;
                waitok[1] <= 0;
                rom_cs    <= 0;
            end else if(!waitok[1]) begin
                if( hotpxl[0])
                    line_addr <= line_addr + 9'd1;
                line_din  <= {pal_mux, ~get_pxl(pxl_data, hf_mux) };
                line_we   <= 1;
                pxl_data  <= hf_mux ? pxl_data<<1 : pxl_data>>1;
                hotpxl    <= { hotpxl[6:0], 1'b1 };
                if( hotpxl[7] ) begin
                    line_we <= 0;
                    if( half ) begin
                        busy    <= 0; // done
                    end else begin
                        waitok <= 2'b11;
                        code_mux <= code1;
                        hf_mux   <= hflip[1];
                        vf_mux   <= vflip[1];
                        pal_mux  <= pal1;
                        half     <= 1;
                        rom_cs   <= 1;
                    end
                end
            end
        end
    end
end

jtframe_dual_ram #(.aw(11),.simhexfile("vram0.hex")) u_ram0(
    .clk0   ( clk_cpu   ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( vram_addr ),
    .we0    ( vram_we[0]),
    .q0     ( vram0_dout),
    // Port 1
    .data1  (           ),
    .addr1  ( cbus      ),
    .we1    ( 1'b0      ),
    .q1     ( scan0_data)
);

jtframe_dual_ram #(.aw(11),.simhexfile("vram1.hex")) u_ram1(
    .clk0   ( clk_cpu   ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( vram_addr ),
    .we0    ( vram_we[1]),
    .q0     ( vram1_dout),
    // Port 1
    .data1  (           ),
    .addr1  ( cbus      ),
    .we1    ( 1'b0      ),
    .q1     ( scan1_data)
);

jtframe_dual_ram #(.aw(11),.simhexfile("vram2.hex")) u_ram2(
    .clk0   ( clk_cpu     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( vram_addr ),
    .we0    ( vram_we[2]),
    .q0     ( vram2_dout),
    // Port 1
    .data1  (           ),
    .addr1  ( cbus      ),
    .we1    ( 1'b0      ),
    .q1     ( scan2_data)
);

jtframe_dual_ram #(.aw(11),.simhexfile("vram3.hex")) u_ram3(
    .clk0   ( clk_cpu     ),
    .clk1   ( clk       ),
    // Port 0
    .data0  ( cpu_dout  ),
    .addr0  ( vram_addr ),
    .we0    ( vram_we[3]),
    .q0     ( vram3_dout),
    // Port 1
    .data1  (           ),
    .addr1  ( cbus      ),
    .we1    ( 1'b0      ),
    .q1     ( scan3_data)
);

jtframe_prom #(.dw(4),.aw(8), .simfile("a71-25.41")) u_prom(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( prog_data ),
    .rd_addr( dec_addr  ),
    .wr_addr( prog_addr ),
    .we     ( prom_we   ),
    .q      ( dec_dout  )
);

jtframe_obj_buffer #(.FLIP_OFFSET(9'h100)) u_line(
    .clk    ( clk           ),
    .LHBL   ( LHBL          ),
    .flip   ( flip          ),
    // New data writes
    .wr_data( line_din      ),
    .wr_addr( line_addr     ),
    .we     ( line_we       ),
    // Old data reads (and erases)
    .rd_addr( hdump         ),
    .rd     ( pxl_cen       ),  // data will be erased after the rd event
    .rd_data( col_addr      )
);

endmodule