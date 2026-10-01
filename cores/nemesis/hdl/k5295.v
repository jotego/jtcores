/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

This core is available for hardware compatible with MiSTer.
Other FPGA systems may be supported by the time you read this.
This work is not mantained by the MiSTer project. Please contact the
core authors for issues and updates.

(c) LMN-san, OScherler, Raki 2020–2023.

Support the authors:

       Raki: https://www.patreon.com/ikamusume
    LMN-san: https://ko-fi.com/lmnsan
  OScherler: https://ko-fi.com/oscherler

The authors do not endorse or participate in illegal distribution
of copyrighted material. This work can be used with legally
obtained ROM dumps of games or with homebrew software for
the arcade platform.

This file license is GNU GPLv3.
You can read the whole license file at http://www.gnu.org/licenses/

*/

//================================================================================
//  K005295 SPRITE ENGINE
//  
//  December 03, 2021. Copyright © 2021-2022 Raki @ bubsys85.net
//================================================================================

/*
84e008d0 2021-12-03T08:25:45Z update K005295
d2a557d0 2021-12-04T14:38:04Z Update DRAM16k4 and K005295
ae54bc33 2021-12-05T05:42:40Z Add K005294
435a0a6a 2021-12-06T15:03:44Z Complete sprite engine
cd271ce6 2021-12-07T06:19:25Z Fix an ambiguous timing problem
8c0ccb38 2021-12-26T03:00:33Z fix K005295 bug
e8163537 2022-02-23T15:54:18Z K005295 bug fix
         2022-03-02           Update by zip file.
70f5c980 2022-03-17T10:00:47Z Fix K005295
ce8e0ecb 2022-03-18T02:27:55Z Fix K005295 bug
431c9d94 2022-03-21T01:40:22Z Update K005295
de2cbc58 2022-04-15T07:48:23Z fix comb effect
e7f2b11d 2022-04-24T15:10:00Z Add new_vblank_n test in ATTR_LATCHING_S1 state of K5295.
*/

/*
    GX400 SPRITES

    Konami GX400 hardware(developed in 1984, released in March 1985) is
    equipped with a nice sprite engine. This engine can draw 8 sizes of
    sprites:
        32*32, 16*32, 32*16, 64*64, 8*8, 16*8, 8*16, 16*16   
    by enabling double height mode(LATCH_A bit 1), it can draw some
    additional sizes:
        32*64, 16*64, 64*128, 8*32

    All sprite data is stored in CHARRAM. 4bpp, big endian. For example,
    think about 16*8 sprite. That can be expressed just like this:


        |----------- HLINE -----------|
        |---TILELINE---|---TILELINE---|
        O O O O o o o o A A A A a a a a ---
        O O O O o o o o A A A A a a a a  |
        O O O O o o o o A A A A a a a a  |
        O O O O o o o o A A A A a a a a VTILE
        O O O O o o o o A A A A a a a a  |
        O O O O o o o o A A A A a a a a  |
        O O O O o o o o A A A A a a a a  |
        O O O O o o o o A A A A a a a a ---

    Sprite engine can fetch 8 pixels of sprite data from CHARRAM at 
    a single time. 4bpp*8 = 32bits. I will call this "TILELINE."

    This sprite is 16*8, so there are two TILELINEs in one "HLINE"
    To draw ONE HLINE, TWO TILELINEs are needed to be fetched. 

    Again, eight HLINEs are needed to complete this 16*8 sprite.
    I will call this eight HLINEs, "VTILE". Width doesn't matter.

    Please remember these three terms, TILELINE, HLINE, VTILE. I
    use these terms in variable names.
*/

`default_nettype none

module K005295
#(parameter               __ENABLE_DOUBLE_HEIGHT_MODE = 1'b0)
(
    //emulator
    input   wire            i_EMU_MCLK,
    input   wire            i_EMU_CLK6MPCEN_n,

    //timings
    input   wire            i_DMA_n,
    input   wire            i_VBLANKH_n,
    input   wire            i_VBLANK_n,
    input   wire            i_HBLANK_n,
    input   wire            i_ABS_4H,
    input   wire            i_ABS_2H,
    input   wire            i_ABS_1H,
    input   wire            i_CHAMPX,
    input   wire            i_OBJWR,

    //flip
    input   wire            i_FLIP,

    //clocked shift
    input   wire    [7:0]   i_OBJDATA,
    output  wire    [2:0]   o_ORA,

    //framebuffer CAS
    output  wire            o_CAS,

    //framebuffer
`ifdef GX400_UNFOLD_DRAM_ADDR
    output  wire   [15:0]   o_FA, //ODD BUFFER
    output  wire   [15:0]   o_FB, //EVEN BUFFER
`else
    output  wire    [7:0]   o_FA, //ODD BUFFER
    output  wire    [7:0]   o_FB, //EVEN BUFFER
`endif

    output  reg             o_XA7,
    output  reg             o_XB7,

    //peripheral control signals
    input   wire            i_OBJHL,
    output  reg             o_CHAOV,
    output  wire            o_ORINC,

    //005294 control signals
    output  reg             o_WRTIME2,
    output  wire            o_COLORLATCH_n,
    output  wire            o_XPOS_D0,
    output  reg             o_PIXELLATCH_WAIT_n,
    output  wire            o_LATCH_A_D2,
    output  wire    [2:0]   o_PIXELSEL,

    //CHARRAM address
`ifdef GX400_UNFOLD_DRAM_ADDR
    output  wire   [13:0]   o_OCA
`else
    output  wire    [7:0]   o_OCA
`endif
);



///////////////////////////////////////////////////////////
//////  GLOBAL SIGNALS
////

reg             hsize_parity = 1'b0;
reg             pixellatch_wait_n;






///////////////////////////////////////////////////////////
//////  PIXEL3
////

/*
    pixel3_n is very important. The most of branches of FSM are occurs
    on Pixel 3.
*/

wire            pixel3_n = ~(i_ABS_1H & i_ABS_2H);






///////////////////////////////////////////////////////////
//////  4H clocked DMA_n
////

/*
    Sampling DMA_n at every rising edge of 4H allows FSM to know 
    the start of a new VBLANK. If the value of sampled DMA_n is 1
    and VBLANK or VBLANKH is 0, it is the beginning of a new VBLANK.
*/

reg             DMA_4H_CLKD_n = 1'b1;
wire            new_vblank_n = DMA_4H_CLKD_n | i_VBLANKH_n;
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if({i_ABS_4H, i_ABS_2H, i_ABS_1H} == 3'd3)
        begin
            DMA_4H_CLKD_n <= i_DMA_n;
        end
    end
end






///////////////////////////////////////////////////////////
//////  ORA/register enable generation
////

//latch enable signal
wire            LATCH_A_en_n; //OBJRAM BYTE 2: zoom MSBs[7:6], size[5:3], unknown size bits[2:1], hflip[0]
wire            LATCH_B_en_n; //OBJRAM BYTE 4: zoom LSBs[7:0]
wire            LATCH_C_en_n; //OBJRAM BYTE 6: sprite code LSBs[7:0]
wire            LATCH_D_en_n; //OBJRAM BYTE 8: sprite code MSBs[7:6], vflip[5], obj palette[4:1], xpos MSB[0]
wire            LATCH_E_en_n; //OBJRAM BYTE A: xpos LSBs[7:0]
wire            LATCH_F_en_n; //OBJRAM BYTE C: ypos[7:0]

assign  o_COLORLATCH_n = LATCH_D_en_n;

//if /A ORA = 2, if /B ORA = 3, ... ,if /F, ORA = 7
//MUDA MUDA MUDA MUDA MUDA MUDA
//ORA ORA ORA ORA ORA ORA ORA
assign  o_ORA[2] = ~&{                                LATCH_C_en_n,   LATCH_D_en_n,   LATCH_E_en_n,   LATCH_F_en_n};
assign  o_ORA[1] = ~&{LATCH_A_en_n,   LATCH_B_en_n,                                   LATCH_E_en_n,   LATCH_F_en_n};
assign  o_ORA[0] = ~&{                LATCH_B_en_n,                   LATCH_D_en_n,                   LATCH_F_en_n};

//latch enable shift register
reg             latching_start;
reg     [6:0]   attr_latch_en_sr;
assign  {LATCH_A_en_n, LATCH_B_en_n, LATCH_C_en_n,
         LATCH_D_en_n, LATCH_E_en_n, LATCH_F_en_n, o_ORINC} = attr_latch_en_sr;

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(i_ABS_1H == 1'b0)
        begin
            attr_latch_en_sr[6]   <= ~latching_start;
            attr_latch_en_sr[5:0] <= attr_latch_en_sr[6:1];
        end
    end
end






///////////////////////////////////////////////////////////
//////  SPRITE ATTRIBUTE LATCHES
////

//LATCH_F is not shown here since ypos data is directly loaded into ypos counter
reg     [7:0]   LATCH_A; //OBJRAM BYTE 2: zoom MSBs[7:6], size[5:3], unknown size bits[2:1], hflip[0]
reg     [7:0]   LATCH_B; //OBJRAM BYTE 4: zoom LSBs[7:0]
reg     [7:0]   LATCH_C; //OBJRAM BYTE 6: sprite code LSBs[7:0]
reg     [7:0]   LATCH_D; //OBJRAM BYTE 8: sprite code MSBs[7:6], vflip[5], obj palette[4:1], xpos MSB[0]
reg     [7:0]   LATCH_E; //OBJRAM BYTE A: xpos LSBs[7:0]
`ifdef SIMULATION
reg     [7:0]   LATCH_F; //OBJRAM BYTE C: ypos[7:0]
`endif

assign  o_XPOS_D0 = LATCH_E[0];
assign  o_LATCH_A_D2 = LATCH_A[2];

//LATCH_A
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(!LATCH_A_en_n)
        begin
            LATCH_A <= i_OBJDATA & {6'b1111_11, __ENABLE_DOUBLE_HEIGHT_MODE, 1'b1};
        end

        if(!LATCH_B_en_n)
        begin
            LATCH_B <= i_OBJDATA;
        end

        if(!LATCH_C_en_n)
        begin
            LATCH_C <= i_OBJDATA;
        end

        if(!LATCH_D_en_n)
        begin
            LATCH_D <= i_OBJDATA;
        end

        if(!LATCH_E_en_n)
        begin
            LATCH_E <= i_OBJDATA;
        end

    `ifdef SIMULATION
        if(!LATCH_F_en_n)
        begin
            LATCH_F <= i_OBJDATA;
        end
    `endif
    end
end

`ifdef SIMULATION
    wire [9:0] dbg_sprite_zoom    = { LATCH_A[7:6], LATCH_B };
    wire [2:0] dbg_sprite_size    = LATCH_A[5:3];
    wire       dbg_sprite_hflip   = LATCH_A[0];
    wire [9:0] dbg_sprite_code    = { LATCH_D[7:6], LATCH_C };
    wire       dbg_sprite_vflip   = LATCH_D[5];
    wire [3:0] dbg_sprite_palette = LATCH_D[4:1];
    wire [8:0] dbg_sprite_xpos    = { LATCH_D[0], LATCH_E };
    wire [7:0] dbg_sprite_ypos    = LATCH_F;
`endif

///////////////////////////////////////////////////////////
//////  HZOOM FEEDBACK ACCUMULATOR
////

/*
                        FEEDBACK LOOP[9:0]
                    ┌────────────────────────┐
                    │                        │
                    │   ┌─────┐     ┌─────┐  │
                    │   │  A  │CLK─►│  D  │  │
                    └─► │  D  │RST─►│  F  │  │
                        │  D  │     │  F  │  │
                        │  E  ├(+)─►│     ├──┴──► FEEDBACK_LOOP[9:7] = PIXELSEL[2:0]
    ZOOM FACTOR ──────► │  R  │     │     │
                        │     │     │     │
                        └──┬──┘     └─────┘
                           │ CARRY
                           │        ┌─────┐
                           │   CLK─►│ LS  │
                           |   RST─►│ 163 ├─────► TILELINE_ADDR[2:0]
                           └───────►│     │
                            ENP/ENT └─────┘
*/

reg             hzoom_cnt_n;
reg             hzoom_rst_n;
reg     [9:0]   hzoom_acc = 10'd0;
wire    [10:0]  hzoom_nextval = hzoom_acc + {LATCH_A[7:6], LATCH_B};
reg     [2:0]   hzoom_tileline_cntr;

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(!hzoom_rst_n)
        begin
            hzoom_acc <= 10'd0;
            hzoom_tileline_cntr <= 3'd0;
        end
        else
        begin
            if(!hzoom_cnt_n)
            begin
                hzoom_acc <= hzoom_nextval[9:0];
                if(hzoom_nextval[10] == 1'b1)
                begin
                    hzoom_tileline_cntr <= hzoom_tileline_cntr + 3'd1;
                end
            end
        end
    end
end



///////////////////////////////////////////////////////////
//////  TILELINE/HLINE COMPLETE FLAG
////

/*
    "tileline complete" flag is the carry output of hzoom feedback
    accumulator. It notifies the end of the current tileline(8 pixels)

    "hline complete" flag notifies the end of current hline. The multiplexer
    selects proper complete flag according to the width of the current
    sprite.
*/

reg             hline_complete;
wire            tileline0_complete = hzoom_nextval[10];
wire            tileline1_complete = &{hzoom_nextval[10], hzoom_tileline_cntr[0]};
wire            tileline3_complete = &{hzoom_nextval[10], hzoom_tileline_cntr[0], hzoom_tileline_cntr[1]};
wire            tileline7_complete = &{hzoom_nextval[10], hzoom_tileline_cntr[0], hzoom_tileline_cntr[1], hzoom_tileline_cntr[2]};

always @(*)
begin
    case({LATCH_A[5:3]})
        4'h0: hline_complete <= tileline3_complete; //32*32     4 horizontal tileline
        4'h1: hline_complete <= tileline1_complete; //16*32     2 horizontal tileline
        4'h2: hline_complete <= tileline3_complete; //32*16     4 horizontal tileline
        4'h3: hline_complete <= tileline7_complete; //64*64     8 horizontal tileline
        4'h4: hline_complete <= tileline0_complete; //8*8       1 horizontal tileline
        4'h5: hline_complete <= tileline1_complete; //16*8      2 horizontal tileline
        4'h6: hline_complete <= tileline0_complete; //8*16      1 horizontal tileline
        4'h7: hline_complete <= tileline1_complete; //16*16     2 horizontal tileline
    endcase
end





///////////////////////////////////////////////////////////
//////  VZOOM FEEDBACK ACCUMULATOR
////

/*
                        FEEDBACK LOOP[9:0]
                    ┌────────────────────────┐
                    │                        │
                    │   ┌─────┐     ┌─────┐  │
                    │   │  A  │CLK─►│  D  │  │
                    └─► │  D  │RST─►│  F  │  │
                        │  D  │     │  F  │  │
                        │  E  ├(+)─►│     ├──┴──► FEEDBACK_LOOP[9:7] = HLINE_ADDR[2:0]
    ZOOM FACTOR ──────► │  R  │     │     │
                        │     │     │     │
                        └──┬──┘     └─────┘
                           │ CARRY
                           │        ┌─────┐
                           │   CLK─►│ LS  │
                           |   RST─►│ 163 ├─────► VTILE_ADDR[3:0]
                           └───────►│     │
                            ENP/ENT └─────┘
*/

reg             vzoom_cnt_n;
reg             vzoom_rst_n;
reg     [9:0]   vzoom_acc = 10'd0;
wire    [10:0]  vzoom_nextval = vzoom_acc + {LATCH_A[7:6], LATCH_B};
reg     [3:0]   vzoom_vtile_cntr;

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(!vzoom_rst_n)
        begin
            vzoom_acc <= 10'd0;
            vzoom_vtile_cntr <= 4'd0;
        end
        else
        begin
            if(!vzoom_cnt_n)
            begin
                vzoom_acc <= vzoom_nextval[9:0];
                if(vzoom_nextval[10] == 1'b1)
                begin
                    vzoom_vtile_cntr <= vzoom_vtile_cntr + 4'd1;
                end
            end
        end
    end
end





///////////////////////////////////////////////////////////
//////  DRAWING COMPLETE FLAG
////

/*
    "vtile_complete" notifies the last hline of the sprite. It is ANDed with 
    the carry output of the vzoom feedback accumulator, so the flag only 
    appears on the drawing cycle of the last hline. Stops sprite drawing 
    after vtile_complete + hline_complete were asserted.
*/

reg             vtile_complete_n;
wire            vtile0_complete_n  = ~vzoom_nextval[10];
wire            vtile1_complete_n  = ~&{vzoom_nextval[10], vzoom_vtile_cntr[0]};
wire            vtile3_complete_n  = ~&{vzoom_nextval[10], vzoom_vtile_cntr[0], vzoom_vtile_cntr[1]};
wire            vtile7_complete_n  = ~&{vzoom_nextval[10], vzoom_vtile_cntr[0], vzoom_vtile_cntr[1], vzoom_vtile_cntr[2]};
wire            vtile15_complete_n = ~&{vzoom_nextval[10], vzoom_vtile_cntr[0], vzoom_vtile_cntr[1], vzoom_vtile_cntr[2], vzoom_vtile_cntr[3]};

always @(*)
begin
    case({LATCH_A[1], LATCH_A[5:3]})
        4'h0: vtile_complete_n <= vtile3_complete_n; //32*32    4 vetrical tiles
        4'h1: vtile_complete_n <= vtile3_complete_n; //16*32    4 vetrical tiles
        4'h2: vtile_complete_n <= vtile1_complete_n; //32*16    2 vetrical tiles
        4'h3: vtile_complete_n <= vtile7_complete_n; //64*64    8 vetrical tiles
        4'h4: vtile_complete_n <= vtile0_complete_n; //8*8      1 vetrical tiles
        4'h5: vtile_complete_n <= vtile0_complete_n; //16*8     1 vetrical tiles
        4'h6: vtile_complete_n <= vtile1_complete_n; //8*16     2 vetrical tiles
        4'h7: vtile_complete_n <= vtile1_complete_n; //16*16    2 vetrical tiles
        4'h8: vtile_complete_n <= vtile7_complete_n; //32*64    8 vetrical tiles
        4'h9: vtile_complete_n <= vtile7_complete_n; //16*64    8 vetrical tiles
        4'hA: vtile_complete_n <= vtile3_complete_n; //32*32    4 vetrical tiles
        4'hB: vtile_complete_n <= vtile15_complete_n; //64*128  16 vetrical tiles
        4'hC: vtile_complete_n <= vtile1_complete_n; //8*16     2 vetrical tiles
        4'hD: vtile_complete_n <= vtile1_complete_n; //16*16    2 vetrical tiles
        4'hE: vtile_complete_n <= vtile3_complete_n; //8*32     4 vetrical tiles
        4'hF: vtile_complete_n <= vtile3_complete_n; //16*32    4 vetrical tiles
    endcase
end






///////////////////////////////////////////////////////////
//////  FRAMEBUFFER XYPOS COUNTER
////

//countup signal delay registers
reg             xpos_cnt_dly_n;
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        xpos_cnt_dly_n <= ~o_WRTIME2;
    end
end

reg             ypos_cnt_n;
reg     [3:0]   ypos_cnt_dly_n;
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        ypos_cnt_dly_n[0] <= ypos_cnt_n;
        ypos_cnt_dly_n[3:1] <= ypos_cnt_dly_n[2:0];
    end
end


//xpos counter
reg     [7:0]   evenbuffer_xpos_counter;
reg     [7:0]   oddbuffer_xpos_counter;
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(LATCH_F_en_n == 1'b0) //2clk delay AND LATCH_F_en_n -> preload data before sprite drawing
        begin
            evenbuffer_xpos_counter <= {LATCH_D[0], LATCH_E[7:1]} + LATCH_E[0];
            oddbuffer_xpos_counter <= {LATCH_D[0], LATCH_E[7:1]};
        end
        else if(ypos_cnt_dly_n[2] == 1'b0)
        begin
            evenbuffer_xpos_counter <= {LATCH_D[0], LATCH_E[7:1]} + LATCH_E[0];
            oddbuffer_xpos_counter <= {LATCH_D[0], LATCH_E[7:1]};
        end
        else
        begin
            if(xpos_cnt_dly_n == 1'b0) //Bootleggers were right. Do not delay 2 clks
                                       //The xpos counter increases immediately after the DRAM latches the row address.
                                       //This is not aesthetically pleasing, but there is no problem at all. 
                                       //Only 1 clock delay allows logic to know the offscreen flag in advance
                                       //and switch the state appropriately.
            begin
                evenbuffer_xpos_counter <= evenbuffer_xpos_counter + 8'd1;
                oddbuffer_xpos_counter <= oddbuffer_xpos_counter + 8'd1;
            end
        end
    end
end


//ypos counter
reg     [7:0]   buffer_ypos_counter;
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(LATCH_F_en_n == 1'b0)
        begin
            buffer_ypos_counter <= i_OBJDATA;
        end
        else
        begin
            if(ypos_cnt_dly_n[3] == 1'b0)
            begin
                buffer_ypos_counter <= buffer_ypos_counter + 8'd1;
            end
        end
    end
end






///////////////////////////////////////////////////////////
//////  DRAWING STATUS FLAGS
////

wire            evenbuffer_xpos_d7 = evenbuffer_xpos_counter[7]; //not oddbuffer, TODO: check the bootleg PCB again

wire            x_offscreen = ~(~oddbuffer_xpos_counter[7] | oddbuffer_xpos_counter[6]); //0-255 or 384-511
wire            y_offscreen = (buffer_ypos_counter == 8'd255) ? 1'b1 : 1'b0;

wire            end_of_tileline = tileline0_complete | x_offscreen;
wire            end_of_hline = hline_complete | x_offscreen;
//wire            end_of_last_hline_n = ~(~(vtile_complete_n | vzoom_cnt_n) | y_offscreen);
wire            end_of_last_hline_n = ~(~(vtile_complete_n) | y_offscreen);







///////////////////////////////////////////////////////////
//////  SPRITE ENGINE MegaPAL
////

// DIRECT REPLACEMENT OF MegaPAL IMPLEMENTATION

/*
    [Comb] STATUS FLAGS
*/

wire    [2:0]   drawing_status = {end_of_last_hline_n, end_of_hline, end_of_tileline};

localparam KEEP_DRAWING     = 3'b100;
localparam END_OF_TILELINE  = 2'b01; //3'bX01 will not work
localparam END_OF_HLINE     = 3'b111;
localparam END_OF_SPRITE    = 3'b011;



/*
    [4H CLK] FSM SUSPEND AND RESUME
*/

reg     [1:0]   FSM_SUSPEND_DLY;
wire            FSM_SUSPEND = ((i_HBLANK_n & i_VBLANKH_n) | FSM_SUSPEND_DLY[1]) | ~DMA_4H_CLKD_n;

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if({i_ABS_4H, i_ABS_2H, i_ABS_1H} == 3'd3)
        begin
            FSM_SUSPEND_DLY[0] <= (i_HBLANK_n & i_VBLANKH_n);
            FSM_SUSPEND_DLY[1] <= FSM_SUSPEND_DLY[0];
        end
    end
end



/*
    [6M CLK] CHA O/V
*/

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(pixel3_n == 1'b0)
        begin
            o_CHAOV <= FSM_SUSPEND;
        end
    end
end



/*
    [4H CLK] FOR ATTRIBUTE FETCHING END DETECTION
*/

reg             LATCH_F_2H_NCLKD_en_n = 1'b1;
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(pixel3_n == 1'b0)
        begin
            LATCH_F_2H_NCLKD_en_n <= LATCH_F_en_n;
        end
    end
end



/*
    [6M CLK] HSIZE PARITY
*/

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(hzoom_rst_n == 1'b0) //preload, new hline
        begin
            hsize_parity <= 1'b1;
        end
        else
        begin
            if(hzoom_cnt_n == 1'b0)
            begin
                hsize_parity <= ~hsize_parity;
            end
        end
    end
end



/*
    [6M CLK] FINITE STATE MACHINE
*/

/*
    ATTR_LATCHING_S0:
        Put 1 in latching_start for 1 pixel. After that, sprite attributes are latched
        sequentially while 1H clocked shift register shifting 0(inverted input) 

    ATTR_LATCHING_S1:
        FSM does nothing while 1H clocked sr working for 14 pixels. FSM jumps to
        HCOUNT_S0 if ORed signal of LATCH_F_2H_NCLKD_en_n(sampled at a rising edge of 
        4H) and pixel3_n is 0. Reset HV accumulator at this time.

    HCOUNT_S0:
        hcounter_en_n becomes 0 during HCOUNT_S0. If H accumulator's carry is enabled,
        FSM controls hcounter_en_n according to the hsize_parity(this is important)
        if hsize at the point is odd(=1), put 0 in pixellatch_wait_n(stop K005294 to
        latch a pixel). In contrast, if hsize at the point is even(=0), put 1 in
        pixellatch_wait_n

    HWAIT_S0:
        Current tileline data is always latched at a rising edge (pixel3_n = 0) of 
        the 2H, so if the tileline drawing is finished before that, insert HWAIT_S0
        cycle to wait for the next data. At a rising edge of 2H, the FSM can branch to:
            HCOUNT_S0(hline not completed)
            ODDSIZE_S0(current hline is ended with an =odd numbered size 7, 9, 11...)
            SUSPEND_S0(active video period)

    ODDSIZE_S0:
        If the previous state was HCOUNT_S0 or HWAIT_S0, and if it satisfies the 
        condition that hsize is odd, FSM goes ODDSIZE_S0 to end current hline drawing
        cycle. The reason why this state exists is as follows:
        1. The engine draws sprite two pixels(EVEN+ODD) per one buffer access cycle.
           It latches the first pixel from pixel selctor, switches selector to pick
           the next pixel. Writes these two pixels to the frame buffer.
        2. If the current tileline's size is an odd number, and should be terminate the
           cycle, it can't be done. Because the first pixel is still on the pixel
           selector's output without being latched. And, WRTIME has not been asserted.
           It(the first pixel) can't be written on the buffer.
        3. This cycle maintained for four pixels(next pixel3_n = next rising edge of 2H)
           During this cycle, the first pixel is latched and WRTIME is asserted in 
           pixel3_n of ODDSIZE_S0.

    SUSPEND_S0:
        Branches to this state unconditionally when FSM_SUSPEND is 1. When the FSM is in
        ATTR_LATCHING_S1, it moves to this state after attrubute latching. The FSM checks
        FSM_SUSPEND at every rising edge of 2H. 
        Note that WRTIME2 and o_PIXELLATCH_WAIT_n will still be on the lines after a
        suspension, since they are just delayed signals from the shift registers.

    XOFF_S0:
        A true delay to handle sprite clipping.
*/

/*
    일단 스프라이트 속성부터 래치시킴 S0을 1픽셀동안 유지시키면 SR이 1H클럭에 맞춰 쭉
    시프팅, 그동안 S1을 유지하는데 이때는 아무일도 안 함. S1이 끝나면 그리기를 시작하는데,
    만약 서스펜드 플래그가 올라가있으면 대기상태로 들어감. 

    쭉 그리는데, 확대/축소된 스프라이트의 경우 h어큐뮬레이터의 캐리가 픽셀 3에서 정확히 안
    올라갈 때가 있음. 이럴 경우 캐리가 올라간 엣지의 다음 엣지에서 HWAIT상태로 들어감.
    여기서 중요한 건 HCOUNT에서 캐리가 올라갔을 때(end_of_tileline) K5294쪽 MUX빠져나온 후
    래치를 잠깐 정지시키는 latch_wait신호가 hsize_parity에 따라 다르다는 것임. 사라만다 
    캡쳐에 이 경우가 없어서 3시간을 날렸다는 걸 잊지 말기

    HWAIT때는 그냥 latch_wait으로 래칭을 정지. end_of_hline일때 가로사이즈가 홀수라면 먼저
    들어온 픽셀이 아직 래치되지 않고 기다리는 중이므로 ODDSIZE를 4클럭동안 삽입. 이때 먼저
    들어온 픽셀이 래치되고 기록됨.

    XOFF_S0은 스프라이트가 잘릴 때 스프라이트 카운터는 3클럭 후에 리셋되는데 FSM이
    여전히 딜레이된 오프스크린 신호를 잡아들어서 발생한 문제. 순수 딜레이.
*/

//Declare states
localparam ATTR_LATCHING_S0 = 3'd1;
localparam ATTR_LATCHING_S1 = 3'd2;
localparam HCOUNT_S0 = 3'd3;
localparam HWAIT_S0 = 3'd4;
localparam ODDSIZE_S0 = 3'd5;
localparam XOFF_S0 = 3'd6;
localparam SUSPEND_S0 = 3'd0;

//Declare state register
reg     [2:0]   sprite_engine_state = SUSPEND_S0; //3'd0 = reset state, Quartus always reset FSM as 0

//Determine the next state synchronously, based on the current state and the input
always @ (posedge i_EMU_MCLK) 
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        case(sprite_engine_state)
            // ATTRIBUTE LATCHING START
            ATTR_LATCHING_S0:
                sprite_engine_state <= ATTR_LATCHING_S1;
            
            // WAIT FOR LATCHING COMPLETION
            ATTR_LATCHING_S1:
                if(pixel3_n == 1'b0) //exit condition: 1 pixel just after end of ORINC(negative logic)
                begin
                    if(new_vblank_n == 1'b0)
                    begin
                        sprite_engine_state <= ATTR_LATCHING_S0; //new vblank
                    end
                    else
                    begin
                        if(LATCH_F_2H_NCLKD_en_n == 1'b0)
                        begin
                            if(FSM_SUSPEND == 1'b0) //keep going
                            begin
                                sprite_engine_state <= HCOUNT_S0;
                            end
                            else //if not, go suspend_s0
                            begin
                                sprite_engine_state <= SUSPEND_S0;
                            end
                        end
                        else
                        begin
                            sprite_engine_state <= ATTR_LATCHING_S1;
                        end
                    end
                end
                else
                begin
                    sprite_engine_state <= ATTR_LATCHING_S1;
                end

            // DRAWING
            // IMPORTANCE LEVEL:  END_OF_SPRITE > END_OF_HLINE > END_OF_TILELINE > KEEP_DRAWING
            HCOUNT_S0:
                if(drawing_status == END_OF_SPRITE)
                begin
                    if(pixel3_n == 1'b0) //at pixel 3
                    begin
                        if(new_vblank_n == 1'b0)
                        begin
                            sprite_engine_state <= ATTR_LATCHING_S0; //new vblank
                        end
                        else
                        begin
                            if(FSM_SUSPEND == 1'b0) //keep going
                            begin
                                if(hsize_parity == 1'b0) //zoomed horizontal size is even
                                begin
                                    sprite_engine_state <= ATTR_LATCHING_S0;
                                end
                                else
                                begin
                                    sprite_engine_state <= ODDSIZE_S0;
                                end
                            end
                            else //if not, go suspend_s0
                            begin
                                sprite_engine_state <= SUSPEND_S0;
                            end
                        end
                    end
                    else //at pixel 0, 1, 2
                    begin
                        sprite_engine_state <= HWAIT_S0;
                    end
                end
                else if(drawing_status == END_OF_HLINE)
                begin
                    if(pixel3_n == 1'b0) //at pixel 3
                    begin
                        if(new_vblank_n == 1'b0)
                        begin
                            sprite_engine_state <= ATTR_LATCHING_S0; //new vblank
                        end
                        else
                        begin
                            if(FSM_SUSPEND == 1'b0) //keep going
                            begin
                                if(hsize_parity == 1'b0) //zoomed horizontal size is even
                                begin
                                    if(evenbuffer_xpos_d7 == 1'b1) //if END_OF_HLINE flag is triggered by the offscreen flag
                                    begin
                                        sprite_engine_state <= XOFF_S0;
                                    end
                                    else
                                    begin
                                        sprite_engine_state <= HCOUNT_S0;
                                    end
                                end
                                else //zoomed horizontal size is odd
                                begin
                                    sprite_engine_state <= ODDSIZE_S0;
                                end
                            end
                            else //if not, go SUSPEND_S0
                            begin
                                sprite_engine_state <= SUSPEND_S0;
                            end
                        end
                    end
                    else //at pixel 0, 1, 2
                    begin
                        sprite_engine_state <= HWAIT_S0;
                    end
                end
                else if(drawing_status[1:0] == END_OF_TILELINE)
                begin
                    if(pixel3_n == 1'b0) //at pixel 3
                    begin
                        if(new_vblank_n == 1'b0)
                        begin
                            sprite_engine_state <= ATTR_LATCHING_S0; //new vblank
                        end
                        else
                        begin
                            if(FSM_SUSPEND == 1'b0) //keep going
                            begin
                                sprite_engine_state <= HCOUNT_S0;
                            end
                            else //if not, go suspend_s0
                            begin
                                sprite_engine_state <= SUSPEND_S0;
                            end
                        end
                    end
                    else //at pixel 0, 1, 2
                    begin
                        sprite_engine_state <= HWAIT_S0;
                    end
                end
                else // `KEEP_DRAWING
                begin
                    if(pixel3_n == 1'b0) //at pixel 3
                    begin
                        if(new_vblank_n == 1'b0)
                        begin
                            sprite_engine_state <= ATTR_LATCHING_S0; //new vblank
                        end
                        else
                        begin
                            if(FSM_SUSPEND == 1'b0) //keep going
                            begin
                                sprite_engine_state <= HCOUNT_S0;
                            end
                            else //if not, go SUSPEND_S0
                            begin
                                sprite_engine_state <= SUSPEND_S0;
                            end
                        end
                    end
                    else //at pixel 0, 1, 2
                    begin
                        sprite_engine_state <= HCOUNT_S0;
                    end
                end



            // WAIT STATE: WAITING FOR /PX3
            HWAIT_S0:
                if(pixel3_n == 1'b0) //exit condition: encounter px3
                begin
                    if(new_vblank_n == 1'b0)
                    begin
                        sprite_engine_state <= ATTR_LATCHING_S0; //new vblank
                    end
                    else
                    begin
                        if(FSM_SUSPEND == 1'b0) //keep going, return to HCOUNT_S0 or fetch new attributes
                        begin
                            if(drawing_status == END_OF_SPRITE)
                            begin
                                if(hsize_parity == 1'b0) //zoomed horizontal size is even
                                begin
                                    sprite_engine_state <= ATTR_LATCHING_S0;
                                end
                                else //zoomed horizontal size is odd
                                begin
                                    sprite_engine_state <= ODDSIZE_S0;
                                end
                            end
                            else if(drawing_status == END_OF_HLINE)
                            begin
                                if(hsize_parity == 1'b0) //zoomed horizontal size is even
                                begin
                                    if(evenbuffer_xpos_d7 == 1'b1) //if END_OF_HLINE flag is triggered by the offscreen flag
                                    begin
                                        sprite_engine_state <= XOFF_S0;
                                    end
                                    else
                                    begin
                                        sprite_engine_state <= HCOUNT_S0;
                                    end
                                end
                                else //zoomed horizontal size is odd
                                begin
                                    sprite_engine_state <= ODDSIZE_S0;
                                end
                            end
                            else
                            begin
                                sprite_engine_state <= HCOUNT_S0;
                            end
                        end
                        else //if not, go suspend_s0
                        begin
                            sprite_engine_state <= SUSPEND_S0;
                        end
                    end
                end
                else
                begin
                    sprite_engine_state <= HWAIT_S0;
                end
            
            
            // WAIT FOR WRITE ONLY A SINGLE PIXEL
            ODDSIZE_S0:
                if(pixel3_n == 1'b0) //exit condition: encounter px3
                begin
                    if(new_vblank_n == 1'b0)
                    begin
                        sprite_engine_state <= ATTR_LATCHING_S0; //new vblank
                    end
                    else
                    begin
                        if(FSM_SUSPEND == 1'b0) //keep going, return to HCOUNT_S0 or fetch new attributes
                        begin
                            if(drawing_status == END_OF_SPRITE)
                            begin
                                sprite_engine_state <= ATTR_LATCHING_S0;
                            end
                            else if(drawing_status == END_OF_HLINE)
                            begin
                                if(evenbuffer_xpos_d7 == 1'b1) //if END_OF_HLINE flag is triggered by the offscreen flag
                                begin
                                    sprite_engine_state <= XOFF_S0;
                                end
                                else
                                begin
                                    sprite_engine_state <= HCOUNT_S0;
                                end
                            end
                            else
                            begin
                                sprite_engine_state <= HCOUNT_S0;
                            end
                        end
                        else //if not, go suspend_s0. *But get new properties first*
                        begin
                            if(drawing_status == END_OF_SPRITE)
                            begin
                                sprite_engine_state <= ATTR_LATCHING_S0;
                            end
                            else
                            begin
                                sprite_engine_state <= SUSPEND_S0;
                            end
                        end
                    end
                end
                else
                begin
                    sprite_engine_state <= ODDSIZE_S0;
                end

            // TRUE DELAY FOR H CLIPPING
            XOFF_S0:
                if(pixel3_n == 1'b0) //exit condition: encounter px3
                begin
                    if(new_vblank_n == 1'b0)
                    begin
                        sprite_engine_state <= ATTR_LATCHING_S0; //new vblank
                    end
                    else
                    begin
                        if(FSM_SUSPEND == 1'b0)
                        begin
                            if(drawing_status == END_OF_SPRITE)
                            begin
                                sprite_engine_state <= ATTR_LATCHING_S0;
                            end
                            else
                            begin
                                sprite_engine_state <= HCOUNT_S0;
                            end
                        end
                        else
                        begin
                            sprite_engine_state <= XOFF_S0;
                        end
                    end
                end


            // SUSPEND STATE: WAITING FOR /PX3
            SUSPEND_S0:
                if(pixel3_n == 1'b0) //exit condition: encounter px3
                begin
                    if(new_vblank_n == 1'b0)
                    begin
                        sprite_engine_state <= ATTR_LATCHING_S0; //new vblank
                    end
                    else
                    begin
                        if(FSM_SUSPEND == 1'b0) //return to HCOUNT_S0  or fetch new attributes
                        begin
                            if(drawing_status == END_OF_SPRITE)
                            begin
                                sprite_engine_state <= HCOUNT_S0;
                            end
                            else if(drawing_status == END_OF_HLINE)
                            begin
                                if(hsize_parity == 1'b0) //zoomed horizontal size is even
                                begin
                                    if(evenbuffer_xpos_d7 == 1'b1) //if END_OF_HLINE flag is triggered by the offscreen flag
                                    begin
                                        sprite_engine_state <= XOFF_S0;
                                    end
                                    else
                                    begin
                                        sprite_engine_state <= HCOUNT_S0;
                                    end
                                end
                                else //zoomed horizontal size is odd
                                begin
                                    sprite_engine_state <= ODDSIZE_S0;
                                end
                            end
                            else
                            begin
                                sprite_engine_state <= HCOUNT_S0;
                            end
                        end
                        else
                        begin
                            sprite_engine_state <= SUSPEND_S0;
                        end
                    end
                end

            default:
                sprite_engine_state <= SUSPEND_S0;
            
        endcase
    end
end

//Determine the output based only on the current state and the input (do not wait for a clock edge)
//signal list:
//  latching_start
//  hzoom_cnt_n
//  hzoom_rst_n
//  vzoom_cnt_n
//  vzoom_rst_n
//  ypos_cnt_n
//  pixellatch_wait_n
always @(*) //Quartus
begin
    case(sprite_engine_state)
        ATTR_LATCHING_S0: begin
            latching_start <= 1'b1;

            hzoom_cnt_n <= 1'b1;
            hzoom_rst_n <= 1'b1;

            vzoom_cnt_n <= 1'b1;
            vzoom_rst_n <= 1'b1;

            ypos_cnt_n <= 1'b1;

            pixellatch_wait_n <= 1'b0;
        end
        ATTR_LATCHING_S1: begin
            if(LATCH_F_2H_NCLKD_en_n == 1'b0 && pixel3_n == 1'b0)
            begin
                latching_start <= 1'b0;

                hzoom_cnt_n <= 1'b1;
                hzoom_rst_n <= 1'b0;

                vzoom_cnt_n <= 1'b1;
                vzoom_rst_n <= 1'b0;

                ypos_cnt_n <= 1'b1;

                pixellatch_wait_n <= 1'b0;
            end
            else
            begin
                latching_start <= 1'b0;

                hzoom_cnt_n <= 1'b1;
                hzoom_rst_n <= 1'b1;

                vzoom_cnt_n <= 1'b1;
                vzoom_rst_n <= 1'b1;

                ypos_cnt_n <= 1'b1;

                pixellatch_wait_n <= 1'b0;
            end    
        end

        HCOUNT_S0: begin
        /*
            HCOUNT_S0
            대기 상태: 다음 PIXEL3_n까지 기다립니다.

            1. END_OF_SPRITE가 PIXEL3_n전에 감지되었을 경우 pixellatch_wait_n
            은 0이 되고, hv피드백 카운터를 정지해야 합니다. HWAIT_S0에서 hv피드백
            카운터를 조작하기 때문입니다. PIXEL3_n에 감지되었을 경우는 
            pixellatch_wait_n가 1이고, hv피드백 카운터를 조작해야 합니다.
            2. END_OF_SPRITE가 PIXEL3_n전에 감지되었을 경우 pixellatch_wait_n
            은 0이 되고, hv피드백 카운터를 정지해야 합니다. HWAIT_S0에서 hv피드백
            카운터를 조작하기 때문입니다. PIXEL3_n에 감지되었을 경우는 
            pixellatch_wait_n가 1이고, hv피드백 카운터를 조작해야 합니다.
            3. END_OF_SPRITE가 PIXEL3_n전에 감지되었을 경우 pixellatch_wait_n
            은 0이 되고, hv피드백 카운터를 정지해야 합니다. HWAIT_S0에서 hv피드백
            카운터를 조작하기 때문입니다. PIXEL3_n에 감지되었을 경우는 
            pixellatch_wait_n가 1이고, hv피드백 카운터를 조작해야 합니다.
            4. KEEP_DRAWING에는 pixellatch_wait_n은 1이 되고, hv피드백 카운터를
            계속 증가시켜야 합니다.
        */

            latching_start <= 1'b0;

            if(drawing_status == END_OF_SPRITE)
            begin
                if(pixel3_n == 1'b0) //pixel 3
                begin
                    hzoom_cnt_n <= 1'b1;
                    hzoom_rst_n <= 1'b1;

                    vzoom_cnt_n <= 1'b1;
                    vzoom_rst_n <= 1'b1;

                    ypos_cnt_n <= 1'b1;

                    pixellatch_wait_n <= 1'b1;
                end
                else
                begin //before pixel 3
                    hzoom_cnt_n <= 1'b1;
                    hzoom_rst_n <= 1'b1;

                    vzoom_cnt_n <= 1'b1;
                    vzoom_rst_n <= 1'b1;

                    ypos_cnt_n <= 1'b1;

                    pixellatch_wait_n <= ~hsize_parity;
                end
            end
            else if(drawing_status == END_OF_HLINE)
            begin
                if(hsize_parity == 1'b0) //after drawing even pixels
                begin
                    if(pixel3_n == 1'b0) //pixel 3
                    begin
                        hzoom_cnt_n <= 1'b1;
                        hzoom_rst_n <= 1'b0;

                        vzoom_cnt_n <= 1'b0;
                        vzoom_rst_n <= 1'b1;

                        ypos_cnt_n <= 1'b0;

                        pixellatch_wait_n <= 1'b1;
                    end
                    else
                    begin //before pixel 3
                        hzoom_cnt_n <= 1'b1;
                        hzoom_rst_n <= 1'b1;

                        vzoom_cnt_n <= 1'b1;
                        vzoom_rst_n <= 1'b1;

                        ypos_cnt_n <= 1'b1;

                        pixellatch_wait_n <= ~hsize_parity;
                    end 
                end
                else 
                begin
                    if(pixel3_n == 1'b0) //pixel 3, after drawing odd pixles: will go to ODDSIZE_S0
                    begin
                        hzoom_cnt_n <= 1'b1;
                        hzoom_rst_n <= 1'b1;

                        vzoom_cnt_n <= 1'b1;
                        vzoom_rst_n <= 1'b1;

                        ypos_cnt_n <= 1'b1;

                        pixellatch_wait_n <= 1'b1; //latch immediately
                    end
                    else
                    begin //before pixel 3, will go to HWAIT_S0
                        hzoom_cnt_n <= 1'b1;
                        hzoom_rst_n <= 1'b1;

                        vzoom_cnt_n <= 1'b1;
                        vzoom_rst_n <= 1'b1;

                        ypos_cnt_n <= 1'b1;

                        pixellatch_wait_n <= 1'b0; //will be latched on pixel3 of HWAIT_S0
                    end 
                end
                   
            end
            else if(drawing_status[1:0] == END_OF_TILELINE)
            begin
                if(pixel3_n == 1'b0) //pixel 3
                begin
                    hzoom_cnt_n <= 1'b0;
                    hzoom_rst_n <= 1'b1;

                    vzoom_cnt_n <= 1'b1;
                    vzoom_rst_n <= 1'b1;

                    ypos_cnt_n <= 1'b1;

                    pixellatch_wait_n <= 1'b1; //latch anyway
                end
                else
                begin //before pixel 3
                    hzoom_cnt_n <= 1'b1;
                    hzoom_rst_n <= 1'b1;

                    vzoom_cnt_n <= 1'b1;
                    vzoom_rst_n <= 1'b1;

                    ypos_cnt_n <= 1'b1;

                    pixellatch_wait_n <= ~hsize_parity; //odd size = wait for the even pixel, 
                                                        //even size = latch(=do not need to be latched, will be drawn immediately)
                end
            end
            else //`KEEP_DRAWING
            begin
                if(pixel3_n == 1'b0) //pixel 3
                begin
                    hzoom_cnt_n <= 1'b0;
                    hzoom_rst_n <= 1'b1;

                    vzoom_cnt_n <= 1'b1;
                    vzoom_rst_n <= 1'b1;

                    ypos_cnt_n <= 1'b1;

                    pixellatch_wait_n <= 1'b1;
                end
                else
                begin //before pixel 3
                    hzoom_cnt_n <= 1'b0;
                    hzoom_rst_n <= 1'b1;

                    vzoom_cnt_n <= 1'b1;
                    vzoom_rst_n <= 1'b1;

                    ypos_cnt_n <= 1'b1;

                    pixellatch_wait_n <= 1'b1;
                end
            end
        end

    
        HWAIT_S0: begin
        /*
            HWAIT_S0
            대기 상태: 다음 PIXEL3_n까지 기다립니다.

            1. END_OF_SPRITE인 경우 hsize_parity에 따라 출력이 달라집니다. 
            짝수개를 그린 후라면 스프라이트를 그만 그려도 되지만, 홀수개를
            그린 후라면 ODDSIZE_S0을 삽입해야 하기 때문에 hv피드백 카운터를 
            조작해서는 안 됩니다.
            2. END_OF_HLINE인 경우 hsize_parity에 따라 출력이 달라집니다. 
            짝수개를 그린 후라면 바로 다음 tileline을 그려야 하지만, 홀수개를
            그린 후라면 ODDSIZE_S0을 삽입해야 하기 때문에 hv피드백 카운터를 
            조작해서는 안 됩니다.
            3. END_OF_TILELINE인 경우 PIXEL3_n이 오면 카운터를 증가시킵니다
            4. KEEP_DRAWING은 발생할 수 없지만 모든 경우를 기술해야 하므로
            작성합니다.
        */

            latching_start <= 1'b0;

            if(drawing_status == END_OF_SPRITE)
            begin
                if(hsize_parity == 1'b0) //after drawing even pixels
                begin
                    if(pixel3_n == 1'b0) //pixel 3
                    begin
                        hzoom_cnt_n <= 1'b1;
                        hzoom_rst_n <= 1'b1;

                        vzoom_cnt_n <= 1'b1;
                        vzoom_rst_n <= 1'b1;

                        ypos_cnt_n <= 1'b1;

                        pixellatch_wait_n <= 1'b1;
                    end
                    else
                    begin //before pixel 3
                        hzoom_cnt_n <= 1'b1;
                        hzoom_rst_n <= 1'b1;

                        vzoom_cnt_n <= 1'b1;
                        vzoom_rst_n <= 1'b1;

                        ypos_cnt_n <= 1'b1;

                        pixellatch_wait_n <= 1'b0;
                    end
                end
                else //after drawing odd pixels: everything will be changed in ODDSIZE_S0
                begin
                    if(pixel3_n == 1'b0) //pixel 3
                    begin
                        hzoom_cnt_n <= 1'b1;
                        hzoom_rst_n <= 1'b1;

                        vzoom_cnt_n <= 1'b1;
                        vzoom_rst_n <= 1'b1;

                        ypos_cnt_n <= 1'b1;

                        pixellatch_wait_n <= 1'b1;
                    end
                    else
                    begin //before pixel 3
                        hzoom_cnt_n <= 1'b1;
                        hzoom_rst_n <= 1'b1;

                        vzoom_cnt_n <= 1'b1;
                        vzoom_rst_n <= 1'b1;

                        ypos_cnt_n <= 1'b1;

                        pixellatch_wait_n <= 1'b0;
                    end
                end
            end
            else if(drawing_status == END_OF_HLINE)
            begin
                if(hsize_parity == 1'b0) //after drawing even pixels
                begin
                    if(pixel3_n == 1'b0) //pixel 3
                    begin
                        hzoom_cnt_n <= 1'b1;
                        hzoom_rst_n <= 1'b0;

                        vzoom_cnt_n <= 1'b0;
                        vzoom_rst_n <= 1'b1;

                        ypos_cnt_n <= 1'b0;

                        pixellatch_wait_n <= 1'b1;
                    end
                    else
                    begin //before pixel 3
                        hzoom_cnt_n <= 1'b1;
                        hzoom_rst_n <= 1'b1;

                        vzoom_cnt_n <= 1'b1;
                        vzoom_rst_n <= 1'b1;

                        ypos_cnt_n <= 1'b1;

                        pixellatch_wait_n <= 1'b0;
                    end
                end
                else //after drawing odd pixels: everything will be changed in ODDSIZE_S0
                begin
                    if(pixel3_n == 1'b0) //pixel 3
                    begin
                        hzoom_cnt_n <= 1'b1;
                        hzoom_rst_n <= 1'b1;

                        vzoom_cnt_n <= 1'b1;
                        vzoom_rst_n <= 1'b1;

                        ypos_cnt_n <= 1'b1;

                        pixellatch_wait_n <= 1'b1;
                    end
                    else
                    begin //before pixel 3
                        hzoom_cnt_n <= 1'b1;
                        hzoom_rst_n <= 1'b1;

                        vzoom_cnt_n <= 1'b1;
                        vzoom_rst_n <= 1'b1;

                        ypos_cnt_n <= 1'b1;

                        pixellatch_wait_n <= 1'b0;
                    end
                end 
            end
            else if(drawing_status[1:0] == END_OF_TILELINE)
            begin
                if(pixel3_n == 1'b0) //pixel 3
                begin
                    hzoom_cnt_n <= 1'b0;
                    hzoom_rst_n <= 1'b1;

                    vzoom_cnt_n <= 1'b1;
                    vzoom_rst_n <= 1'b1;

                    ypos_cnt_n <= 1'b1;

                    pixellatch_wait_n <= 1'b1;
                end
                else
                begin //before pixel 3
                    hzoom_cnt_n <= 1'b1;
                    hzoom_rst_n <= 1'b1;

                    vzoom_cnt_n <= 1'b1;
                    vzoom_rst_n <= 1'b1;

                    ypos_cnt_n <= 1'b1;

                    pixellatch_wait_n <= 1'b0;
                end
            end
            else //`KEEP_DRAWING: WILL NOT HAPPEN
            begin
                if(pixel3_n == 1'b0) //pixel 3
                begin
                    hzoom_cnt_n <= 1'b0;
                    hzoom_rst_n <= 1'b1;

                    vzoom_cnt_n <= 1'b1;
                    vzoom_rst_n <= 1'b1;

                    ypos_cnt_n <= 1'b1;

                    pixellatch_wait_n <= 1'b1;
                end
                else
                begin //before pixel 3
                    hzoom_cnt_n <= 1'b0;
                    hzoom_rst_n <= 1'b1;

                    vzoom_cnt_n <= 1'b1;
                    vzoom_rst_n <= 1'b1;

                    ypos_cnt_n <= 1'b1;

                    pixellatch_wait_n <= 1'b1;
                end
            end
        end

        ODDSIZE_S0: begin
        /*
            ODDSIZE_S0
            지금까지 그린 픽셀 갯수가 홀수인 상황에서 짝수 버퍼에 0을 쓰고 한
            라인 그리기를 마쳐야 하는 경우입니다. 이 상태로 넘어온 경우 hsize_
            parity가 홀수인 것은 확정된 상황입니다.

            1. END_OF_SPRITE인 경우 스프라이트 그리기를 마쳐야 합니다.
            2. END_OF_HLINE인 경우 ypos와 vzoom을 증가시켜야 합니다.
            3. END_OF_TILELINE은 발생할 수 없지만 모든 경우를 기술해야 하므로
            작성합니다.
            4. KEEP_DRAWING은 발생할 수 없지만 모든 경우를 기술해야 하므로
            작성합니다.
        */

            latching_start <= 1'b0;
            
            if(drawing_status == END_OF_SPRITE)
            begin
                if(pixel3_n == 1'b0) //pixel 3
                begin
                    hzoom_cnt_n <= 1'b1;
                    hzoom_rst_n <= 1'b0;

                    vzoom_cnt_n <= 1'b1;
                    vzoom_rst_n <= 1'b0;

                    ypos_cnt_n <= 1'b1;

                    pixellatch_wait_n <= 1'b0;
                end
                else
                begin //before pixel 3
                    hzoom_cnt_n <= 1'b1;
                    hzoom_rst_n <= 1'b1;

                    vzoom_cnt_n <= 1'b1;
                    vzoom_rst_n <= 1'b1;

                    ypos_cnt_n <= 1'b1;

                    pixellatch_wait_n <= 1'b0;
                end
            end
            else if(drawing_status == END_OF_HLINE)
            begin
                if(pixel3_n == 1'b0) //pixel 3
                begin
                    hzoom_cnt_n <= 1'b1;
                    hzoom_rst_n <= 1'b0;

                    vzoom_cnt_n <= 1'b0;
                    vzoom_rst_n <= 1'b1;

                    ypos_cnt_n <= 1'b0;

                    pixellatch_wait_n <= 1'b0;
                end
                else
                begin //before pixel 3
                    hzoom_cnt_n <= 1'b1;
                    hzoom_rst_n <= 1'b1;

                    vzoom_cnt_n <= 1'b1;
                    vzoom_rst_n <= 1'b1;

                    ypos_cnt_n <= 1'b1;

                    pixellatch_wait_n <= 1'b0;
                end     
            end
            else if(drawing_status[1:0] == END_OF_TILELINE) //WILL NOT HAPPEN
            begin
                if(pixel3_n == 1'b0) //pixel 3
                begin
                    hzoom_cnt_n <= 1'b0;
                    hzoom_rst_n <= 1'b1;

                    vzoom_cnt_n <= 1'b1;
                    vzoom_rst_n <= 1'b1;

                    ypos_cnt_n <= 1'b1;

                    pixellatch_wait_n <= 1'b1;
                end
                else
                begin //before pixel 3
                    hzoom_cnt_n <= 1'b1;
                    hzoom_rst_n <= 1'b1;

                    vzoom_cnt_n <= 1'b1;
                    vzoom_rst_n <= 1'b1;

                    ypos_cnt_n <= 1'b1;

                    pixellatch_wait_n <= 1'b0;
                end
            end
            else //`KEEP_DRAWING
            begin
                if(pixel3_n == 1'b0) //pixel 3
                begin
                    hzoom_cnt_n <= 1'b1;
                    hzoom_rst_n <= 1'b1;

                    vzoom_cnt_n <= 1'b1;
                    vzoom_rst_n <= 1'b1;

                    ypos_cnt_n <= 1'b1;

                    pixellatch_wait_n <= 1'b1;
                end
                else
                begin //before pixel 3
                    hzoom_cnt_n <= 1'b1;
                    hzoom_rst_n <= 1'b1;

                    vzoom_cnt_n <= 1'b1;
                    vzoom_rst_n <= 1'b1;

                    ypos_cnt_n <= 1'b1;

                    pixellatch_wait_n <= 1'b0;
                end
            end
        end

        SUSPEND_S0: begin
        /*
            SUSPEND_S0
            작업이 재개될 때 까지 기다립니다.
        */
            latching_start <= 1'b0;

            hzoom_cnt_n <= 1'b1;
            hzoom_rst_n <= 1'b1;

            vzoom_cnt_n <= 1'b1;
            vzoom_rst_n <= 1'b1;

            ypos_cnt_n <= 1'b1;

            pixellatch_wait_n <= 1'b0;
        end

        XOFF_S0: begin
            latching_start <= 1'b0;

            hzoom_cnt_n <= 1'b1;
            hzoom_rst_n <= 1'b1;

            vzoom_cnt_n <= 1'b1;
            vzoom_rst_n <= 1'b1;

            ypos_cnt_n <= 1'b1;

            pixellatch_wait_n <= 1'b0;
        end

        default: begin
            latching_start <= 1'b0;

            hzoom_cnt_n <= 1'b1;
            hzoom_rst_n <= 1'b1;

            vzoom_cnt_n <= 1'b1;
            vzoom_rst_n <= 1'b1;

            ypos_cnt_n <= 1'b1;

            pixellatch_wait_n <= 1'b0;
        end
    endcase
end



/*
    [6M CLK] WRTIME DELAY
*/

reg             wrtime1;
wire            oddsize_wrtime0 = (sprite_engine_state == ODDSIZE_S0 && pixel3_n == 1'b0) ? 1'b1 : 1'b0;
wire            evensize_wrtime0 = (sprite_engine_state == HCOUNT_S0) ? ~hsize_parity : 1'b0;
always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        //feed hsize_parity normally, but it should be 1 when PIXEL3 at ODDSIZE_S0
        wrtime1 <= evensize_wrtime0 | oddsize_wrtime0;
        o_WRTIME2 <= wrtime1;
    end
end



/*
    [6M CLK] o_PIXELLATCH_WAIT_n DELAY
*/

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        o_PIXELLATCH_WAIT_n <= pixellatch_wait_n;
    end
end






///////////////////////////////////////////////////////////
//////  PIXEL SELECT(005294), LINE SELECT, TILE SELECT
////

//005294 PIXEL SELECT
assign  o_PIXELSEL = hzoom_acc[9:7] ^ {3{LATCH_A[0]}}; //OBJ_HFLIP

//CHARRAM ADDRESS
wire    [2:0]   TILELINE_ADDR = hzoom_tileline_cntr ^ {3{LATCH_A[0]}};
wire    [2:0]   HLINE_ADDR = vzoom_acc[9:7] ^ {3{LATCH_D[5]}};
wire    [3:0]   VTILE_ADDR = vzoom_vtile_cntr ^ {4{LATCH_D[5]}};
reg     [13:0]  CHARRAM_ADDR; //unmultiplexed

`ifdef GX400_UNFOLD_DRAM_ADDR
    assign  o_OCA = CHARRAM_ADDR;
`else
    assign  o_OCA = (i_CHAMPX == 1'b0) ? CHARRAM_ADDR[7:0] : {1'b1, CHARRAM_ADDR[13:8], 1'b1}; //RAS : CAS
`endif

always @(*)
begin
    case({LATCH_A[1], LATCH_A[5:3]})
        //                     |-------(OBJ CODE)-------| 
        4'h0: CHARRAM_ADDR <= {LATCH_D[7:6], LATCH_C[7:3], VTILE_ADDR[1:0], HLINE_ADDR[2:0], TILELINE_ADDR[1:0]}; //32*32    4 vetrical tiles
        4'h1: CHARRAM_ADDR <= {LATCH_D[7:6], LATCH_C[7:2], VTILE_ADDR[1:0], HLINE_ADDR[2:0], TILELINE_ADDR[0:0]}; //16*32    4 vetrical tiles
        4'h2: CHARRAM_ADDR <= {LATCH_D[7:6], LATCH_C[7:2], VTILE_ADDR[0:0], HLINE_ADDR[2:0], TILELINE_ADDR[1:0]}; //32*16    2 vetrical tiles
        4'h3: CHARRAM_ADDR <= {LATCH_D[7:6], LATCH_C[7:5], VTILE_ADDR[2:0], HLINE_ADDR[2:0], TILELINE_ADDR[2:0]}; //64*64    8 vetrical tiles
        4'h4: CHARRAM_ADDR <= {LATCH_D[7:6], LATCH_C[7:0],            1'b0, HLINE_ADDR[2:0]                    }; //8*8      1 vetrical tiles
        4'h5: CHARRAM_ADDR <= {LATCH_D[7:6], LATCH_C[7:0],                  HLINE_ADDR[2:0], TILELINE_ADDR[0:0]}; //16*8     1 vetrical tiles
        4'h6: CHARRAM_ADDR <= {LATCH_D[7:6], LATCH_C[7:0], VTILE_ADDR[0:0], HLINE_ADDR[2:0]                    }; //8*16     2 vetrical tiles
        4'h7: CHARRAM_ADDR <= {LATCH_D[7:6], LATCH_C[7:1], VTILE_ADDR[0:0], HLINE_ADDR[2:0], TILELINE_ADDR[0:0]}; //16*16    2 vetrical tiles

        4'h8: CHARRAM_ADDR <= {LATCH_D[7:6], LATCH_C[7:4], VTILE_ADDR[2:0], HLINE_ADDR[2:0], TILELINE_ADDR[1:0]}; //32*64    8 vetrical tiles
        4'h9: CHARRAM_ADDR <= {LATCH_D[7:6], LATCH_C[7:3], VTILE_ADDR[2:0], HLINE_ADDR[2:0], TILELINE_ADDR[0:0]}; //16*64    8 vetrical tiles
        4'hA: CHARRAM_ADDR <= {LATCH_D[7:6], LATCH_C[7:4], VTILE_ADDR[1:0], HLINE_ADDR[2:0], TILELINE_ADDR[1:0]}; //32*32    4 vetrical tiles
        4'hB: CHARRAM_ADDR <= {LATCH_D[7:6], LATCH_C[7:6], VTILE_ADDR[3:0], HLINE_ADDR[2:0], TILELINE_ADDR[2:0]}; //64*128   16 vetrical tiles
        4'hC: CHARRAM_ADDR <= {LATCH_D[7:6], LATCH_C[7:0], VTILE_ADDR[0:0], HLINE_ADDR[2:0]                    }; //8*16     2 vetrical tiles
        4'hD: CHARRAM_ADDR <= {LATCH_D[7:6], LATCH_C[7:1], VTILE_ADDR[0:0], HLINE_ADDR[2:0], TILELINE_ADDR[0:0]}; //16*16    2 vetrical tiles
        4'hE: CHARRAM_ADDR <= {LATCH_D[7:6], LATCH_C[7:1], VTILE_ADDR[1:0], HLINE_ADDR[2:0]                    }; //8*32     4 vetrical tiles
        4'hF: CHARRAM_ADDR <= {LATCH_D[7:6], LATCH_C[7:2], VTILE_ADDR[1:0], HLINE_ADDR[2:0], TILELINE_ADDR[0:0]}; //16*32    4 vetrical tiles
    endcase
end








///////////////////////////////////////////////////////////
//////  SCREEN COUNTER
////

//X Screen Counter
reg     [6:0]   buffer_x_screencounter = 7'd0;

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        if(i_ABS_1H == 1'b1) //negedge of 1H
        begin
            if(i_OBJWR == 1'b1)
            begin
                buffer_x_screencounter <= 7'd0;
            end
            else
            begin
                if(buffer_x_screencounter == 7'd127)
                begin
                    buffer_x_screencounter <= 7'd0;
                end 
                else
                begin
                    buffer_x_screencounter <= buffer_x_screencounter + 7'd1;
                end
            end
        end
    end
end

/*
    Y Screen Counter

    This Y Screen Counter increases at a rising edge of i_HBLANK_n,
    asynchronously. But we need to synchronize all flip-flops to 
    the master clock, so there was no choice but to install an edge 
    detector, and counting was delayed by one clock. However, a rising 
    edge of HBLANK increases the Y Counter before OBJ WR switches MUX 
    and the timing is not stern, so this delay is invisible from the 
    outside and does not affect the behavior.
*/

reg             prev_hblank;
reg     [7:0]   buffer_y_screencounter = 8'd15;

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        prev_hblank <= i_HBLANK_n;

        if(i_VBLANK_n == 1'b0) //async reset by VBLANK
        begin
            buffer_y_screencounter <= 8'd15;
            
        end
        else
        begin
            if(i_HBLANK_n == 1'b1 && prev_hblank == 1'b0) //1 clk after the positive edge of vblank
            begin
                if(buffer_y_screencounter == 8'd255)
                begin
                    buffer_y_screencounter <= 8'd0;
                end 
                else
                begin
                    buffer_y_screencounter <= buffer_y_screencounter + 8'd1;
                end
            end
        end
    end
end






///////////////////////////////////////////////////////////
//////  BUFFER MUX
////

/*
    GX400 uses 1Mb of frame buffer, but 256*256 size sprite field consumes
    only 512kb. I think Konami engineers designed the hardware that can
    support interlaced mode that was never been used.
*/

reg             buffer_frame_parity = 1'b0;
reg             prev_vblank;

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        prev_vblank <= i_VBLANK_n;

        if(i_VBLANK_n == 1'b0 && prev_vblank == 1'b1) //async reset by VBLANK
        begin
            buffer_frame_parity <= ~buffer_frame_parity;
        end
    end
end


reg     [15:0]  EVENBUFFER_ADDR; //unmultiplexed, buffer A on the Nemesis schematics
reg     [15:0]  ODDBUFFER_ADDR; //unmultiplexed, buffer B on the Nemesis schematics

`ifdef GX400_UNFOLD_DRAM_ADDR
    assign  o_FA = EVENBUFFER_ADDR;
    assign  o_FB = ODDBUFFER_ADDR;
`else
    assign  o_FA = (o_CAS == 1'b0) ? EVENBUFFER_ADDR[7:0] : EVENBUFFER_ADDR[15:8]; //RAS : CAS
    assign  o_FB = (o_CAS == 1'b0) ?  ODDBUFFER_ADDR[7:0] :  ODDBUFFER_ADDR[15:8]; //RAS : CAS
`endif

/*
    SPRITE DOUBLE BUFFERING(VERIFIED)

    GX400 GFX board uses sprite double buffering. This means the sprites
    currently drawn in this VBLANK will not be displayed in the upcoming
    active video period, but will be shown on a screen on the next frame.
*/

always @(*)
begin
    case(i_OBJWR)
        1'b1: begin //sprite drawing period
            EVENBUFFER_ADDR <= {~buffer_frame_parity, buffer_ypos_counter, evenbuffer_xpos_counter[6:0]}; //sprite double buffering
            ODDBUFFER_ADDR  <= {~buffer_frame_parity, buffer_ypos_counter, oddbuffer_xpos_counter[6:0]}; //sprite double buffering
        end
        1'b0: begin //active video period
            EVENBUFFER_ADDR <= {buffer_frame_parity, buffer_y_screencounter ^ {8{i_FLIP}}, buffer_x_screencounter ^ {7{i_FLIP}}};
            ODDBUFFER_ADDR  <= {buffer_frame_parity, buffer_y_screencounter ^ {8{i_FLIP}}, buffer_x_screencounter ^ {7{i_FLIP}}};
        end
    endcase
end







///////////////////////////////////////////////////////////
//////  XA7 XB7
////

/*
    When the X coordinate goes out of the screen (xpos>255), the xpos counter
    value wraps around, which can damage the sprite drawn before, so make XA/XB
    as 1 and overwrite it with the existing data without updating the value.

    Need to delay 1 clk.

    Note that Konami swapped the name of two signals on the Nemesis schematics.
    XA is on the ODD(B) buffer, and vice versa. 
*/

always @(posedge i_EMU_MCLK)
begin
    if(!i_EMU_CLK6MPCEN_n)
    begin
        o_XA7 <= evenbuffer_xpos_counter[7];
        o_XB7 <= oddbuffer_xpos_counter[7];
    end
end






///////////////////////////////////////////////////////////
//////  CAS
////

assign  o_CAS = i_OBJHL;


reg debug;
always @(*)
begin
    if(oddbuffer_xpos_counter == 8'd124 && buffer_ypos_counter == 8'd218)
    begin
        debug <= 1'b1;
    end
    else
    begin
        debug <= 1'b0;
    end
end


endmodule
