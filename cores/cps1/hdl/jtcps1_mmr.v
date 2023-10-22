/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-1-2020 */


// This module represents the register logic of both CPS-A and CPS-B chips

module jtcps1_mmr(
    input              rst,
    input              clk,
    input              pxl_cen,

    input              frame_start,
    input              line_inc,
    output             raster,

    input              ppu_rstn,
    input              ppu1_cs,
    input              ppu2_cs,

    input   [ 5:1]     addr,
    input   [ 1:0]     dsn,      // data select, active low
    input   [15:0]     cpu_dout,
    output  reg [15:0] mmr_dout,
    //input   [ 7:0]     debug_bus,

    // registers
    output reg [15:0]  ppu_ctrl,
    output reg         obj_dma_ok,
    output             cpu_speed, // 0 for 10MHz, 1 for 12MHz
    output             charger,   // 0 arcade game, 1 charger game
    output             kabuki_en, // 0 for no kabuki, 1 for kabuki encryption
    output reg         star_bank,

    // Extra inputs read through the C-Board
    input      [ 3:0]  cab_1p,
    input      [ 3:0]  coin,
    input      [ 9:0]  joystick1,
    input      [ 9:0]  joystick2,
    input      [ 9:0]  joystick3,
    input      [ 9:0]  joystick4,

    // Scroll
    output reg [15:0]  hpos1,
    output reg [15:0]  hpos2,
    output reg [15:0]  hpos3,
    output reg [15:0]  vpos1,
    output reg [15:0]  vpos2,
    output reg [15:0]  vpos3,

    output reg [15:0]  hstar1,
    output reg [15:0]  hstar2,

    output reg [15:0]  vstar1,
    output reg [15:0]  vstar2,

    // ROM banks
    output     [ 5:0]  game,
    output     [15:0]  bank_offset,
    output     [15:0]  bank_mask,

    // VRAM position
    output reg [15:0]  vram1_base,
    output reg [15:0]  vram2_base,
    output reg [15:0]  vram3_base,
    output reg [15:0]  vram_obj_base,
    output reg [15:0]  vram_row_base,
    output reg [15:0]  row_offset,
    output reg [15:0]  pal_base,
    output reg         pal_copy,

    // CPS-B Registers configuration
    input              cfg_we,
    input      [ 7:0]  cfg_data,

    output reg [15:0]  layer_ctrl,
    output reg [15:0]  prio0,
    output reg [15:0]  prio1,
    output reg [15:0]  prio2,
    output reg [15:0]  prio3,
    output reg [ 5:0]  pal_page_en, // which palette pages to copy
    output     [ 7:0]  layer_mask0,
    output     [ 7:0]  layer_mask1,
    output     [ 7:0]  layer_mask2,
    output     [ 7:0]  layer_mask3,
    output     [ 7:0]  layer_mask4

    `ifdef CPS1
    // EEPROM
    ,output reg        sclk,
    output  reg        sdi,
    output  reg        scs,
    input              sdo
    `endif
);

// Shift register configuration
parameter REGSIZE=24; // This is defined at _game level
reg [8*REGSIZE-1:0] regs;

wire [5:1] addr_id,
           addr_mult1,
           addr_mult2,
           addr_rslt0,
           addr_rslt1,
           addr_layer,
           addr_prio0,
           addr_prio1,
           addr_prio2,
           addr_prio3,
           addr_pal_page,
           addr_in2,
           addr_in3;

wire [12:0] addrb = {
           addr == addr_in3 && addr_in3!=5'h0,     // 12
           addr == addr_in2 && addr_in2!=5'h0,     // 11
           addr == addr_pal_page,// 10
           // priority masks cannot be modified if the address is all '1
           addr == addr_prio3 && addr_prio3!=5'h1f,   // 9
           addr == addr_prio2 && addr_prio2!=5'h1f,   // 8
           addr == addr_prio1 && addr_prio1!=5'h1f,   // 7
           addr == addr_prio0 && addr_prio0!=5'h1f,   // 6
           addr == addr_layer,   // 5
           // multiply registers only valid if different from '1
           addr == addr_rslt1 && addr_rslt1!=5'h1f,   // 4
           addr == addr_rslt0 && addr_rslt0!=5'h1f,   // 3
           addr == addr_mult2 && addr_mult2!=5'h1f,   // 2
           addr == addr_mult1 && addr_mult1!=5'h1f,   // 1
           addr == addr_id       // 0
        };

wire [7:0]  cpsb_id;
reg  [15:0]  mult1, mult2;
reg  [15:0]  rslt1, rslt0;
reg  [ 7:0]  in2, in3;
reg          last_cfg_we;
wire [ 2:0]  cpsb_inputs;

`ifdef CPS2
wire [ 8:0]  raster_dout;
reg  [ 2:0]  cnt_sel;
`endif

always @(posedge clk) {rslt1,rslt0} <= mult1*mult2;

`define MMR(a) regs[8*(a+1)-1:8*a]
`define MMR2(a) regs[8*a+1 +: 5]
`define MMR3(a,b) regs[8*a +: b]

/*verilator lint_off width*/
assign addr_id       = `MMR2(0);
assign cpsb_id       = `MMR(1); // 16-bit value compressed in 8 bits
assign addr_mult1    = `MMR2(2);
assign addr_mult2    = `MMR2(3);
assign addr_rslt0    = `MMR2(4);
assign addr_rslt1    = `MMR2(5);
assign addr_layer    = `MMR2(6);
assign addr_prio0    = `MMR2(7);
assign addr_prio1    = `MMR2(8);
assign addr_prio2    = `MMR2(9);
assign addr_prio3    = `MMR2(10);
`ifdef CPS15
assign addr_in2      = 5'd0; // no inputs on CPS-B chip for CPS1.5 games
assign addr_in3      = 5'd0;
`else
assign addr_in2      = `MMR2(11);
assign addr_in3      = `MMR2(12);
`endif
assign addr_pal_page = `MMR2(13);
assign layer_mask0   = `MMR(14);
assign layer_mask1   = `MMR(15);
assign layer_mask2   = `MMR(16);
assign layer_mask3   = `MMR(17);
assign layer_mask4   = layer_mask3; // it is not well know what the
// mask bits are for layer 4. MAME uses the same values for layers 3 and 4
// so I just skip layer 4 from the configuration. This saves one MMR register
// which is what I need to make the MMR length 16 bytes. The length must be
// a multiple of 2 in order to work with the ROM downloading

// Mapper, last 5 bytes
assign game         = `MMR3(18,6);
assign bank_offset  = { `MMR(20), `MMR(19) };
assign bank_mask    = { `MMR(22), `MMR(21) };
assign { kabuki_en /* bit 5*/, charger /* bit 4*/, cpsb_inputs, cpu_speed }  = `MMR3(23,6);
/*verilator lint_on width*/

reg [15:0] pre_mux0, pre_mux1;
reg [ 1:0] sel;

always @(posedge clk) begin
    star_bank <= game==6'd14 || game==6'd15; // Use ROM bank 1 for Forgotten Worlds
end

// extra inputs
always @(posedge clk) begin
    in3 = { cab_1p[3], coin[3], joystick4[5:0] }; // four players
    if( cpsb_inputs[2] )
        begin // 6 buttons
            in2 = { 1'b1, joystick2[9:7], 1'b1, joystick1[9:7] };
        end
        else begin // 3'b001 or other: three players
            in2 = { cab_1p[2], coin[2], joystick3[5:0] };
        end
end

always @(*) begin
    pre_mux0 = 16'hffff;
    pre_mux1 = 16'hffff;
    if( &addr ) sel=2'b00;
    else begin
        sel = { |addrb[12:6], |addrb[5:0] };
        case( addrb[5:0] )
            6'b000_001: pre_mux0 = {4'd0, cpsb_id[7:4], 4'd0, cpsb_id[3:0]};
            6'b000_010: pre_mux0 = mult1;
            6'b000_100: pre_mux0 = mult2;
            6'b001_000: pre_mux0 = rslt0;
            6'b010_000: pre_mux0 = rslt1;
            6'b100_000: pre_mux0 = layer_ctrl;
            default:;
        endcase
        case( addrb[12:6] )
            7'b0_000_001: pre_mux1 = prio0;
            7'b0_000_010: pre_mux1 = prio1;
            7'b0_000_100: pre_mux1 = prio2;
            7'b0_001_000: pre_mux1 = prio3;
            7'b0_010_000: pre_mux1 = { 10'd0, pal_page_en };
            // extra inputs
            7'b0_100_000: pre_mux1 = { in2, in2 };
            7'b1_000_000: pre_mux1 = { in3, in3 };
            default:;
        endcase
    end
end

always@(posedge clk) begin
    last_cfg_we <= cfg_we;
    if( cfg_we && !last_cfg_we ) begin // catching the edge for mixed 48/96MHz operation
        regs <= { cfg_data, regs[8*REGSIZE-1:8] };
    end
end

wire reg_rst;
reg  pre_copy, pre_dma_ok;


// For quick simulation of the video alone
// it is possible to load the regs from a file
// defined by the macro MMR_FILE

// Load MMR configuration and contents directly for video-only simulations
`ifdef MMR_FILE
reg [15:0] mmr_regs[0:19];
integer aux;
initial begin
    // CPSB_CONFIG samples:
    //      `define CPSB_CONFIG {REGSIZE{8'b0}}
    //      `define CPSB_CONFIG 16'hfff7, 16'h4440, 8'h07, 8'hff,8'hf3,8'h44,8'h40,8'h0,8'h14,8'h20,8'h8,8'h2,8'h32,8'h0,8'h0,8'h30,8'h2e,8'h2c,8'h2a,8'h28,8'hff,8'hff,8'hff,8'hff,8'h5,8'h20
    `ifdef CPSB_CONFIG
        regs = { `CPSB_CONFIG };
    `endif
    $display("Layer control address: %X", `MMR(6) );
    $display("Palette page  address: %X", `MMR(11));
    $display("INFO: MMR initial values read from %s", `MMR_FILE );
    // clear the content in case the MMR file does not
    // contain values for all
    for( aux=0; aux<20; aux=aux+1 ) mmr_regs[aux]=16'd0;
    $readmemh(`MMR_FILE,mmr_regs);
    vram_obj_base  = mmr_regs[0];
    vram1_base     = mmr_regs[1];
    vram2_base     = mmr_regs[2];
    vram3_base     = mmr_regs[3];
    pal_base       = mmr_regs[4];
    hpos1          = mmr_regs[5];
    vpos1          = mmr_regs[6];
    hpos2          = mmr_regs[7];
    vpos2          = mmr_regs[8];
    hpos3          = mmr_regs[9];
    vpos3          = mmr_regs[10];
    layer_ctrl     = mmr_regs[11]; //16'h12ce; // default
    pal_page_en    = mmr_regs[12][5:0];
    vram_row_base  = mmr_regs[13];
    row_offset     = mmr_regs[14];
    ppu_ctrl       = mmr_regs[15];
    prio0          = mmr_regs[16];
    prio1          = mmr_regs[17];
    prio2          = mmr_regs[18];
    prio3          = mmr_regs[19];
    hstar1         = 16'd10;
    hstar2         = 16'd0;
    vstar1         = 16'd0;
    vstar2         = 16'd0;
    // Default layer order = 4B = 01 00 10 11
    // Strider layer order = 4E = 01 00 11 10
    //layer_ctrl     = 16'h138e; // strider
    //layer_ctrl     = {2'b0,2'b01,2'b11,2'b10,2'b00,6'd0}; // strider
    // Carrier Airwing scene 2
    // 06da = 00 /00 01 10 11 / 01 10 10
    // layer_ctrl     = {2'b0, 2'b0,2'd2,2'd1,2'd3,6'h1a}; // change layer order
    // layer_ctrl     = {2'b0, 2'd0,2'd3,2'd1,2'd2,6'h1f}; // no carrier
    //layer_ctrl     = {  8'b01_00_10_11 , 6'b011010 };
    //layer_ctrl     = {  8'b01_10_00_11 , 6'b011010 }; // works
    obj_dma_ok = 1'b1; // so data is copied at the beginning of sim.
end
assign reg_rst = 1'b0;  // reset is skipped for this type of simulation
`else
// Normal synthesis:
assign reg_rst = rst | ~ppu_rstn;
`endif

`ifdef SIMULATION
reg dump_aux=0;
`endif

always @(posedge clk, posedge reg_rst) begin
    if( reg_rst ) begin
        hpos1         <= 16'd0;
        hpos2         <= 16'd0;
        hpos3         <= 16'd0;
        vpos1         <= 16'd0;
        vpos2         <= 16'd0;
        vpos3         <= 16'd0;
        hstar1        <= 16'd0;
        hstar2        <= 16'd0;
        vstar1        <= 16'd0;
        vstar2        <= 16'd0;
        vram1_base    <= 16'd0;
        vram2_base    <= 16'd0;
        vram3_base    <= 16'd0;
        vram_obj_base <= 16'd0;
        pal_base      <= 16'd0;
        row_offset    <= 16'd0;

        prio0         <= 16'h0;
        prio1         <= 16'h0;
        prio2         <= 16'h0;
        prio3         <= 16'h0;
        pal_page_en   <= 6'h3f;
        layer_ctrl    <= {2'b0,2'b11,2'b10,2'b01,2'b00,6'd0};
        ppu_ctrl      <= 16'd0;

        pal_copy      <= 1'b0;
        pre_copy      <= 1'b0;
        mmr_dout      <= 16'hffff;
        `ifdef CPS1
        sclk          <= 1'b0;
        sdi           <= 1'b0;
        scs           <= 1'b0;
        `endif
        `ifdef CPS2
        cnt_sel       <= 3'd0;
        `endif

        obj_dma_ok    <= 1'b0;
    end else begin
        if( !ppu1_cs && pxl_cen ) begin
            // The palette copy signal is delayed until after ppu1_cs has gone down
            // otherwise it would get a wrong pal_base value as pal_base is written
            // to a bit after ppu1_cs has gone high
            pal_copy   <= pre_copy;
            pre_copy   <= 1'b0;
            // same for OBJ DMA
            obj_dma_ok <= pre_dma_ok;
            pre_dma_ok <= 1'b0;
        end
        if( ppu1_cs && dsn==2'b00 ) begin // only full 16-bit writes are allowed
            case( addr[5:1] )
                // CPS-A registers
                5'h00: begin
                    vram_obj_base <= cpu_dout;
                    pre_dma_ok   <= 1'b1;
                end
                5'h01: vram1_base    <= cpu_dout;
                5'h02: vram2_base    <= cpu_dout;
                5'h03: vram3_base    <= cpu_dout;
                5'h04: vram_row_base <= cpu_dout;
                5'h05: begin
                    pal_base      <= cpu_dout;
                    pre_copy      <= 1'b1;
                    //$display("PALETTE!");
                end
                5'h06: hpos1      <= cpu_dout;
                5'h07: vpos1      <= cpu_dout;
                5'h08: hpos2      <= cpu_dout;
                5'h09: vpos2      <= cpu_dout;
                5'h0a: hpos3      <= cpu_dout;
                5'h0b: vpos3      <= cpu_dout;
                5'h0c: hstar1     <= cpu_dout;
                5'h0d: vstar1     <= cpu_dout;
                5'h0e: hstar2     <= cpu_dout;
                5'h0f: vstar2     <= cpu_dout;
                5'h10: row_offset <= cpu_dout;
                5'h11: ppu_ctrl   <= cpu_dout;
                default:;
            endcase
        end
        if( ppu2_cs ) begin
            mmr_dout <= sel[0] ? pre_mux0 : (sel[1] ? pre_mux1 : 16'hffff);
            if( addrb[ 1] && dsn==0) mult1      <= cpu_dout;
            if( addrb[ 2] && dsn==0) mult2      <= cpu_dout;
            if( addrb[ 5] && dsn==0) layer_ctrl <= cpu_dout;
            if( addrb[ 6] && dsn==0) prio0      <= cpu_dout;
            if( addrb[ 7] && dsn==0) prio1      <= cpu_dout;
            if( addrb[ 8] && dsn==0) prio2      <= cpu_dout;
            if( addrb[ 9] && dsn==0) prio3      <= cpu_dout;
            if( addrb[10] && dsn==0) pal_page_en<= cpu_dout[5:0];
            `ifdef CPS1
            if( game == 6'h14 /*game_pang3*/ ) begin
                if( addr == 5'h1d && !dsn[0] ) { scs, sclk, sdi } <= { cpu_dout[7], cpu_dout[6], cpu_dout[0] };
                if( addr == 5'h1d ) mmr_dout <= { 15'd0, sdo };
            end
            `endif
            `ifdef CPS2
            // raster effects
            if( addr == (5'h0e>>1) || addr == (5'h10>>1) || addr == (5'h12>>1) ) begin
                mmr_dout <= { 7'd0, raster_dout };
                cnt_sel[0] <=  addr[4] && !addr[1]; // raster2 in schematics
                cnt_sel[1] <=  addr[4] &&  addr[1]; // raster3
                cnt_sel[2] <= !addr[4]; // raster3 (pixel count)
                /*
                `ifdef SIMULATION
                    if( 0 && ppu2_cs===1 && cpu_dout[8:0]!=0
                          && cpu_dout[8:0]!=9'h106
                          && !dump_aux) begin
                        dump_aux <= 1;
                        $shm_open("test.shm");
                        $shm_probe(UUT.u_game.u_main,"A");
                        $shm_probe(UUT.u_game.u_video,"A");
                        $shm_probe(UUT.u_game.u_video.u_mmr,"A");
                        $shm_probe(UUT.u_game.u_video.u_mmr.u_raster,"AS");
                        $display("Raster dump started");
                        #(16600000*50) $finish;
                    end
                `endif
                */
            end else cnt_sel <= 0;
            `endif
        end
        `ifdef CPS2
        else cnt_sel <= 0;
        `endif

    end
end

// Raster interrupts
`ifdef CPS2
jtcps2_raster u_raster(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .frame_start( frame_start   ),
    .line_inc   ( line_inc      ),

    // interface with CPU
    .cnt_sel    ( cnt_sel       ),
    .wrn        ( |dsn          ),
    //.cpu_dout   ( cpu_dout^16'h1ff    ),
    //.cpu_dout   ( cpu_dout-16'd20    ),
    //.cpu_dout   ( cpu_dout+16'h20    ), // The demo doesn't go into Cammyys
    .cpu_dout   ( cpu_dout      ),
    .cnt_dout   ( raster_dout   ),

    .raster     ( raster        )       // raster event
);
`else
assign raster = 0;
`endif

endmodule
