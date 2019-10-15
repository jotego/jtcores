/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-2-2019 */

`timescale 1ns/1ps

module jtgng_rom #(parameter
    main_dw  = 8,
    char_aw  = 14,
    main_aw  = 18,
     snd_aw  = 15,
     obj_aw  = 17,
    scr1_aw  = 17,
    scr2_aw  = 15,
     obj_dw  = 16,
  snd_offset = 22'h14_000, // bm05.4k,  32kB
 char_offset = 22'h18_000, // bm04.5h,  32kB
 map1_offset = 22'h1C_000, // bm14.5f,  32kB
 map2_offset = 22'h20_000, // bmm23.8k, 32kB
 scr1_offset = 22'h24_000, // 10f/j, 11f/j, 12f/j, 14f/j 256kB
 scr2_offset = 22'h44_000, // 14k/l 64kB
  obj_offset = 22'h4C_000, // 10a/c, 11a/c, 12a/c, 14a/c 256kB
/// Selects whether ROM goes into SDRAM or BRAM
   BRAM_MAIN =0,
   BRAM_SOUND=0
)(
    input               rst,
    input               clk,
    input               LHBL,
    input               LVBL,

    input               pause,
    input               main_cs,
    input               snd_cs,

    input       [char_aw-1:0]  char_addr, //  32 kB
    input       [main_aw-1:0]  main_addr, // 160 kB, addressed as 8-bit words
    input       [ snd_aw-1:0]   snd_addr, //  32 kB
    input       [ obj_aw-1:0]   obj_addr,  // 256 kB
    input       [scr1_aw-1:0]  scr1_addr, // 256 kB (16-bit words)
    input       [scr2_aw-1:0]  scr2_addr, //  64 kB
    input       [13:0]  map1_addr, //  32 kB
    input       [13:0]  map2_addr, //  32 kB

    // ROM download, only important if any of the BRAM parameters are set to 1
    input       [ 7:0]  prog_data,
    input       [ 1:0]  prog_mask,
    input       [21:0]  prog_addr,
    input               prog_we,  

    //  output data
    output reg       [15:0] char_dout,
    output    [main_dw-1:0] main_dout,
    output           [ 7:0] snd_dout,
    output reg [obj_dw-1:0] obj_dout,
    output           [15:0] map1_dout,
    output           [15:0] map2_dout,
    output           [15:0] scr1_dout,
    output           [15:0] scr2_dout,
    output  reg             ready,

    output              main_ok,
    output              snd_ok,
    output              scr1_ok,
    output              scr2_ok,
    output              char_ok,
    output              obj_ok,
    // SDRAM controller interface
    input               data_rdy,
    input               sdram_ack,
    input               downloading,
    input               loop_rst,
    output  reg         sdram_req,
    output  reg         refresh_en,
    output  reg [21:0]  sdram_addr,
    input       [31:0]  data_read
);

wire prog_main = prog_we && (prog_mask!=2'b11) && prog_addr < snd_offset;
wire  prog_snd = prog_we && (prog_mask!=2'b11) && prog_addr < char_offset && prog_addr>=snd_offset;

// Main code
// bme01.12d -> 32kB
// bme02.13d, bme03.14d, -> 128kB, 8 banks of 16kB each
// 6C_000 = ROM LEN

reg [3:0] ready_cnt;
reg [3:0] rd_state_last;
wire main_req, char_req, map1_req, map2_req, scr1_req, scr2_req, obj_req, snd_req;

reg [7:0] data_sel;
wire [main_aw-1:0] main_addr_req;
wire [ snd_aw-1:0]  snd_addr_req;
wire [char_aw-1:0] char_addr_req;
wire [ obj_aw-1:0]  obj_addr_req;
wire [scr1_aw-1:0] scr1_addr_req;
wire [scr2_aw-1:0] scr2_addr_req;
wire [13:0] map1_addr_req;
wire [13:0] map2_addr_req;

wire map1_ok, map2_ok;
//wire newref = 
//    &{ main_ok&main_cs, char_ok, scr1_ok, scr2_ok, map1_ok, map2_ok, obj_ok };

// wire blank_b = LVBL && LHBL;

always @(posedge clk)
    // refresh_en <= !LVBL;
    refresh_en <= &{ main_ok&main_cs, char_ok, scr1_ok, scr2_ok, map1_ok, map2_ok, obj_ok };

reg download_ok = 1'b0; // signals that the download process is completed

always @(posedge clk) begin : download_watch
    reg last_downloading;
    last_downloading <= downloading;
    if( !downloading && last_downloading )
        download_ok <= 1'b1;
end

wire [22:0] prog_addr2 = { prog_addr[21:0], prog_mask[0] };

jtgng_romflex #(
    .AW(main_aw),
    .DW(main_dw),
    .INVERT_A0(1),
    .USE_BRAM(BRAM_MAIN)) 
u_main(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .cen       ( 1'b1                   ),
    .addr      ( main_addr              ),
    .addr_ok   ( main_cs                ),
    .addr_req  ( main_addr_req          ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dout      ( main_dout              ),
    .req       ( main_req               ),
    .data_ok   ( main_ok                ),
    .we        ( data_sel[0]            ),
    .prog_we   ( prog_main              ),
    // 16-bit operation from BRAM has not been
    // verified yet
    .prog_data ( {(main_dw==8?1:2){prog_data}} ),
    .prog_addr ( prog_addr2[main_aw-1:0])
);


jtgng_romflex #(.AW(snd_aw),.INVERT_A0(1), .USE_BRAM(BRAM_SOUND)) u_snd(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .cen       ( 1'b1                   ),
    .addr      ( snd_addr               ),
    .addr_ok   ( snd_cs                 ),
    .addr_req  ( snd_addr_req           ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dout      ( snd_dout               ),
    .req       ( snd_req                ),
    .data_ok   ( snd_ok                 ),
    .we        ( data_sel[7]            ),
    .prog_we   ( prog_snd               ),
    .prog_data ( prog_data              ),
    .prog_addr ( prog_addr2[snd_aw-1:0] )
);

wire [15:0] char_preout;

jtgng_romrq #(.AW(char_aw),.DW(16)) u_char(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( 1'b1            ),
    .addr     ( char_addr       ),
    .addr_ok  ( LVBL            ),
    .addr_req ( char_addr_req   ),
    .din      ( data_read       ),
    .din_ok   ( data_rdy        ),
    .dout     ( char_preout     ),
    .req      ( char_req        ),
    .data_ok  ( char_ok         ),
    .we       ( data_sel[1]     )
);

// Provides a non-zero output for characters before SDRAM has valid data
// This can be used to display a rudimentary message on screen
// and prompt the user to load the ROM
// assign char_dout = download_ok ? char_preout : 16'hAAAA;
// This behaviour is disabled during simulation
`ifndef SIMULATION
always @(posedge clk) char_dout <= download_ok ? char_preout : 16'hAAAA;
`else
always @(posedge clk) char_dout <= char_preout;
`endif

jtgng_romrq #(.AW(14),.DW(16)) u_map1(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( 1'b1            ),
    .addr     ( map1_addr       ),
    .addr_ok  ( LVBL            ),
    .addr_req ( map1_addr_req   ),
    .din      ( data_read       ),
    .din_ok   ( data_rdy        ),
    .dout     ( map1_dout       ),
    .req      ( map1_req        ),
    .data_ok  ( map1_ok         ),
    .we       ( data_sel[2]     )
);

jtgng_romrq #(.AW(14),.DW(16)) u_map2(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( 1'b1            ),
    .addr     ( map2_addr       ),
    .addr_ok  ( LVBL            ),
    .addr_req ( map2_addr_req   ),
    .din      ( data_read       ),
    .din_ok   ( data_rdy        ),
    .dout     ( map2_dout       ),
    .req      ( map2_req        ),
    .data_ok  ( map2_ok         ),
    .we       ( data_sel[3]     )
);

jtgng_romrq #(.AW(scr1_aw),.DW(16)) u_scr1(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( 1'b1            ),
    .addr     ( scr1_addr       ),
    .addr_ok  ( LVBL            ),
    .addr_req ( scr1_addr_req   ),
    .din      ( data_read       ),
    .din_ok   ( data_rdy        ),
    .dout     ( scr1_dout       ),
    .req      ( scr1_req        ),
    .data_ok  ( scr1_ok         ),
    .we       ( data_sel[4]     )
);

jtgng_romrq #(.AW(scr2_aw),.DW(16)) u_scr2(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( 1'b1            ),
    .addr     ( scr2_addr       ),
    .addr_ok  ( LVBL            ),
    .addr_req ( scr2_addr_req   ),
    .din      ( data_read       ),
    .din_ok   ( data_rdy        ),
    .dout     ( scr2_dout       ),
    .req      ( scr2_req        ),
    .data_ok  ( scr2_ok         ),
    .we       ( data_sel[5]     )
);

wire [obj_dw-1:0] obj_preout;

jtgng_romrq #(.AW(obj_aw),.DW(obj_dw)) u_obj(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( 1'b1            ),
    .addr     ( obj_addr        ),
    .addr_ok  ( 1'b1            ),
    .addr_req ( obj_addr_req    ),
    .din      ( data_read       ),
    .din_ok   ( data_rdy        ),
    .dout     ( obj_preout      ),
    .req      ( obj_req         ),
    .data_ok  ( obj_ok          ),
    .we       ( data_sel[6]     )
);

`ifdef AVATARS
`ifdef MISTER
`define AVATAR_ROM
`endif
`endif

`ifdef AVATAR_ROM
    // Alternative Objects during pause for MiSTer
    wire [15:0] avatar_data;
    jtgng_ram #(.dw(16), .aw(13), .synfile("avatar.hex"),.cen_rd(1)) u_avatars(
        .clk    ( clk            ),
        .cen    ( pause          ),  // tiny power saving when not in pause
        .data   ( 16'd0          ),
        .addr   ( obj_addr[12:0] ),
        .we     ( 1'b0           ),
        .q      ( avatar_data    )
    );
    always @(posedge clk) obj_dout <= pause ? avatar_data : obj_preout;
`else 

    `ifndef OBJROMTEST
        // Let the real data go through
        always @(*) obj_dout = obj_preout;
        initial begin
            $display("INFO: direct OBJ");
        end
    `else
        initial begin
            $display("INFO: Using OBJ address as data read from ROM");
        end
        // Use the address as the data, but only when obj_ok is valid
        always @(posedge clk) begin : objromtest
            reg last_ok;
            last_ok <= obj_ok;
            if( obj_ok && !last_ok ) 
                obj_dout = { {16-obj_aw{1'b0}}, obj_addr[obj_aw-1:0] };
        end
    `endif

`endif

`ifdef SIMULATION
real busy_cnt=0, total_cnt=0;
always @(posedge clk) begin
    total_cnt <= total_cnt + 1;
    if( |data_sel ) busy_cnt <= busy_cnt+1;
end
always @(posedge LVBL) begin
    $display("INFO: frame ROM stats: %.0f %%", 100.0*busy_cnt/total_cnt);
end
`endif

always @(posedge clk)
if( loop_rst || downloading ) begin
    sdram_addr <=  'd0;
    ready_cnt <=  4'd0;
    ready     <=  1'b0;
    sdram_req <=  1'b0;
    data_sel  <=  8'd0;
end else begin
    {ready, ready_cnt}  <= {ready_cnt, 1'b1};
    // if( data_rdy ) begin
    //     data_sel <= 8'd0;
    // end
    if( sdram_ack ) sdram_req <= 1'b0;
    // accept a new request
    if( data_sel==8'd0 || data_rdy ) begin
        sdram_req <= 
           |{main_req, map1_req, map2_req, scr1_req, scr2_req,
             char_req, obj_req,  snd_req };
        data_sel <= 8'd0;
        case( 1'b1 )
            snd_req: begin
                sdram_addr <= snd_offset + { {23-snd_aw{1'b0}}, snd_addr_req[snd_aw-1:1] };
                data_sel[7] <= 1'b1;
            end
            scr1_req: begin
                sdram_addr <= scr1_offset + { {22-scr1_aw{1'b0}}, scr1_addr_req };
                data_sel[4] <= 1'b1;
            end
            scr2_req: begin
                sdram_addr <= scr2_offset + { {22-scr2_aw{1'b0}}, scr2_addr_req };
                data_sel[5] <= 1'b1;
            end
            map1_req: begin
                sdram_addr <= map1_offset + { 8'b0, map1_addr_req };
                data_sel[2] <= 1'b1;
            end
            map2_req: begin
                sdram_addr <= map2_offset + { 8'b0, map2_addr_req };
                data_sel[3] <= 1'b1;
            end
            obj_req: begin
                sdram_addr <= obj_offset + { {22-obj_aw{1'b0}}, obj_addr_req };
                data_sel[6] <= 1'b1;
            end
            main_req: begin
                sdram_addr <= { {23-main_aw{1'b0}}, main_addr_req[main_aw-1:1] };
                data_sel[0] <= 1'b1;
            end
            char_req: begin
                sdram_addr <= char_offset + { {22-char_aw{1'b0}}, char_addr_req };
                data_sel[1] <= 1'b1;
            end
        endcase
    end
end

endmodule // jtgng_rom