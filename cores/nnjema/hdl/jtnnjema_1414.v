/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 8-9-2026 */

// NB1414M4 text blitter. Command at videoram[0:1], params up to [0x11]
// Follows MAME nb1414m4.cpp. Scroll is latched on every command
module jtnnjema_1414(
    input             rst,
    input             clk,

    input             blit_stb,
    input             vb_ack,

    // text RAM. addr[10] selects the attribute plane. Reads: code plane only
    output reg [10:0] vram_addr,
    input      [ 7:0] vram_dout,
    output reg [ 7:0] vram_din,
    output reg        vram_we,

    // data ROM
    output reg [13:0] rom_addr,
    input      [ 7:0] rom_data,

    output reg [12:0] scrx,
    output reg [10:0] scry,
    output reg        busy
);

localparam [5:0] IDLE  = 0,
                 W8    = 1,
                 PRM0  = 2,  PRM1  = 3,
                 A13a  = 4,  A13b  = 5,
                 DISP  = 6,
                 STEP  = 7,
                 PTR0  = 8,  PTR1  = 9,  PTR2  = 10,
                 RD0   = 11, RD1   = 12,
                 DMA0  = 13, DMA1  = 14, DMA2  = 15, DMA3 = 16, DMA4 = 17,
                 FILL0 = 18, FILL1 = 19,
                 SCO0  = 20, SCO1  = 21, SCO2  = 22, SCO3 = 23,
                 SCO4  = 24, SCO5  = 25,
                 DONE  = 26;
// command pages
localparam [2:0] PG_TOP00 = 0, PG_INSERT = 1, PG_CREDIT = 2,
                 PG_0200  = 3, PG_0600   = 4, PG_0E00   = 5;

reg  [ 5:0] st, ret, w8_ret;
reg  [ 2:0] page, page_ret;
reg  [ 4:0] step, step_ret;
reg         subret;
reg  [ 7:0] params[0:17];
reg  [15:0] cmd;
reg  [ 7:0] attr13, tmp, tmp2, frcnt, prev02, prev02_fr;
reg         in_game, fl_cond;
reg  [ 4:0] prm_i;
reg  [13:0] ptr_a, dstp, dma_src, dma_dst;
reg  [10:0] dma_i, dma_size;
reg         dma_cond;
reg  [ 7:0] code_byte;
reg  [ 3:0] loop_i;
reg  [ 7:0] sco_code;
reg         sco_base, sco_first;
reg  [ 2:0] sco_i;

wire [ 7:0] credits = params[15];
wire [ 3:0] sco_res = sco_i[0] ? params[{2'd0,sco_i[2:1]}+5+(sco_base?3:0)][3:0]
                               : params[{2'd0,sco_i[2:1]}+5+(sco_base?3:0)][7:4];
wire [13:0] sco_atr = 14'h10f+(sco_base?14'h1c:14'd0);

`define CALLPTR(a,nx) begin ptr_a<=(a); st<=PTR0; ret<=STEP; step<=(nx); end
`define CALLDMA(s,d,n,c,nx) begin dma_src<=(s); dma_dst<=(d); dma_size<=(n); dma_cond<=(c); dma_i<=0; st<=DMA0; ret<=STEP; step<=(nx); end
`define CALLRD(a,nx) begin ptr_a<=(a); st<=RD0; ret<=STEP; step<=(nx); end
`define ROMRD(a,nx) begin rom_addr<=(a); w8_ret<=(nx); st<=W8; end
`define PAGERET begin if(subret) begin page<=page_ret; step<=step_ret; end else st<=DONE; subret<=0; end

always @(posedge clk) begin
    if( rst ) begin
        st      <= IDLE;
        busy    <= 0;
        vram_we <= 0;
        scrx    <= 0;
        scry    <= 0;
        in_game <= 0;
        frcnt   <= 0;
        prev02  <= 8'hff;
        prev02_fr <= 0;
    end else begin
        vram_we <= 0;
        if( vb_ack ) frcnt <= frcnt+8'd1;
        case( st )
            IDLE: if( blit_stb ) begin
                busy    <= 1;
                prm_i   <= 0;
                fl_cond <= frcnt[4];
                st      <= PRM0;
            end
            W8: st <= w8_ret;

            // read params 0x00-0x11 from the code plane
            PRM0: begin
                vram_addr <= {6'd0,prm_i};
                w8_ret    <= PRM1;
                st        <= W8;
            end
            PRM1: begin
                params[prm_i] <= vram_dout;
                prm_i <= prm_i+5'd1;
                st    <= prm_i==17 ? A13a : PRM0;
            end
            A13a: `ROMRD(14'h13,A13b)
            A13b: begin
                attr13 <= rom_data;
                cmd    <= {params[0],params[1]};
                scrx   <= {params[14][4:0],params[13]};
                scry   <= {params[12][2:0],params[11]};
                st     <= DISP;
            end
            DISP: begin
                step   <= 0;
                subret <= 0;
                st     <= STEP;
                case( cmd[15:8] )
                    8'h00: page <= PG_TOP00;
                    8'h02: page <= PG_0200;
                    8'h06: page <= PG_0600;
                    8'h0e: page <= PG_0E00;
                    default: st <= DONE; // 0x8000/0xff00 nops
                endcase
            end

            STEP: case( page )
                PG_TOP00: case( step )
                    0: begin page<=PG_INSERT; step<=0; subret<=1; page_ret<=PG_TOP00; step_ret<=1; end
                    1: begin page<=PG_CREDIT; step<=0; subret<=1; page_ret<=PG_TOP00; step_ret<=2; end
                    default: st <= DONE;
                endcase

                PG_INSERT: case( step )
                    0: begin
                        if( in_game ) step <= 5;
                        else if( credits==0 ) `CALLPTR(14'h1,5'd1)
                        else `CALLPTR(14'h49,5'd3)
                    end
                    1: `CALLDMA(14'h3,dstp,11'h10,fl_cond,5'd5)
                    3: `CALLDMA(14'h4b,dstp,11'h18,1'b1,5'd5)
                    default: `PAGERET
                endcase

                PG_CREDIT: case( step )
                    0: `CALLPTR(14'h23,5'd1)
                    1: `CALLDMA(14'h25,dstp,11'h10,1'b1,5'd2)
                    2: `CALLPTR(14'h45,5'd3)
                    3: `CALLRD(14'h47,5'd4)
                    4: begin // credit tens
                        vram_addr <= {1'b0,dstp[9:0]};
                        vram_din  <= credits[7:4]!=0 ? {4'h3,credits[7:4]} : 8'h20;
                        vram_we   <= 1;
                        step <= 5;
                    end
                    5: begin
                        vram_addr <= {1'b1,dstp[9:0]};
                        vram_din  <= tmp;
                        vram_we   <= 1;
                        step <= 6;
                    end
                    6: `CALLRD(14'h48,5'd7)
                    7: begin // credit units
                        vram_addr <= {1'b0,dstp[9:0]+10'd1};
                        vram_din  <= {4'h3,credits[3:0]};
                        vram_we   <= 1;
                        step <= 8;
                    end
                    8: begin
                        vram_addr <= {1'b1,dstp[9:0]+10'd1};
                        vram_din  <= tmp;
                        vram_we   <= 1;
                        step <= 9;
                    end
                    9: begin
                        if( in_game ) step <= 13;
                        else if( credits==1 ) `CALLPTR(14'h7b,5'd10)
                        else if( credits>1 ) `CALLPTR(14'had,5'd11)
                        else step <= 13;
                    end
                    10: `CALLDMA(14'h7d,dstp,11'h18,fl_cond,5'd13)
                    11: `CALLDMA(14'haf,dstp,11'h18,fl_cond,5'd13)
                    default: `PAGERET
                endcase

                PG_0200: case( step )
                    0: begin
                        in_game <= cmd[7];
                        // repeated command within a frame is dropped
                        if( prev02==(cmd[7:0]&8'h87) && (frcnt-prev02_fr)<=8'd1 )
                            st <= DONE;
                        else begin
                            prev02    <= cmd[7:0]&8'h87;
                            prev02_fr <= frcnt;
                            `CALLPTR(14'h330+{9'd0,cmd[3:0],1'b0},5'd1)
                        end
                    end
                    1: begin
                        if( dstp[10:0]!=0 ) `CALLRD(dstp,5'd2)      // fill
                        else `CALLDMA(dstp,14'd0,11'h400,1'b1,5'd4) // full page copy
                    end
                    2: begin tmp2 <= tmp; `CALLRD(dstp+14'd1,5'd3) end
                    3: begin
                        code_byte <= tmp2;  // tile, pal stays in tmp
                        dma_i     <= 0;
                        st        <= FILL0;
                        ret       <= STEP;
                        step      <= 4;
                    end
                    default: st <= DONE;
                endcase

                PG_0600: case( step )
                    0: `CALLPTR(14'h1f5,5'd1)
                    1: begin // lives
                        vram_addr <= {1'b0,dstp[9:0]};
                        vram_din  <= {4'h3,1'b0,params[7][2:0]};
                        vram_we   <= 1;
                        step <= 2;
                    end
                    2: `CALLPTR(14'h1f8,5'd3)
                    3: `CALLDMA(14'h1fa+{8'd0,params[7][5:4],4'd0}+{9'd0,params[7][5:4],3'd0},dstp,11'd12,1'b1,5'd4)
                    4: `CALLPTR(14'h262,5'd5)
                    5: `CALLDMA(params[7][7]?14'h27c:14'h264,dstp,11'd12,1'b1,5'd6)
                    6: `CALLPTR(14'h294,5'd7)
                    7: `CALLDMA(params[7][6]?14'h2ae:14'h296,dstp,11'd12,1'b1,5'd8)
                    8: `CALLPTR(14'h2c6,5'd9)
                    9: begin
                        vram_addr <= {1'b0,dstp[9:0]}; vram_din <= {4'h3,params[15][7:4]}; vram_we <= 1;
                        step <= 10;
                    end
                    10: `CALLPTR(14'h2c9,5'd11)
                    11: begin
                        vram_addr <= {1'b0,dstp[9:0]}; vram_din <= {4'h3,params[15][3:0]}; vram_we <= 1;
                        step <= 12;
                    end
                    12: `CALLPTR(14'h2cc,5'd13)
                    13: begin
                        vram_addr <= {1'b0,dstp[9:0]}; vram_din <= {4'h3,params[16][7:4]}; vram_we <= 1;
                        step <= 14;
                    end
                    14: `CALLPTR(14'h2cf,5'd15)
                    15: begin
                        vram_addr <= {1'b0,dstp[9:0]}; vram_din <= {4'h3,params[16][3:0]}; vram_we <= 1;
                        step <= 16;
                    end
                    16: `CALLPTR(14'h2d2,5'd17)
                    17: begin // sound test number
                        vram_addr <= {1'b0,dstp[9:0]}; vram_din <= {4'h3,params[17][7:4]}; vram_we <= 1;
                        step <= 18;
                    end
                    18: begin
                        vram_addr <= {1'b0,dstp[9:0]+10'd1}; vram_din <= {4'h3,params[17][3:0]}; vram_we <= 1;
                        step <= 19;
                    end
                    19: `CALLPTR(14'h2d6,5'd20)
                    20: `CALLDMA(cmd[0]?14'h2f0:14'h2d8,dstp,11'd12,1'b1,5'd21)
                    21: begin loop_i<=0; `CALLPTR(14'h308,5'd22) end
                    22: begin // system inputs, 5 lines
                        `CALLDMA(params[4][4-loop_i]?14'h316:14'h310,dstp+{5'd0,loop_i,5'd0},11'd3,1'b1,5'd22)
                        loop_i <= loop_i+4'd1;
                        if( loop_i==4 ) begin loop_i<=0; step<=23; end
                    end
                    23: `CALLPTR(14'h30a,5'd24)
                    24: begin // 1p/2p inputs, 7 lines
                        `CALLDMA(params[cmd[0]?3:2][6-loop_i]?14'h316:14'h310,dstp+{5'd0,loop_i,5'd0},11'd3,1'b1,5'd24)
                        loop_i <= loop_i+4'd1;
                        if( loop_i==6 ) begin loop_i<=0; step<=25; end
                    end
                    25: `CALLPTR(14'h30c,5'd26)
                    26: begin // dsw1, 8 lines
                        `CALLDMA(params[5][7-loop_i]?14'h316:14'h310,dstp+{5'd0,loop_i,5'd0},11'd3,1'b1,5'd26)
                        loop_i <= loop_i+4'd1;
                        if( loop_i==7 ) begin loop_i<=0; step<=27; end
                    end
                    27: `CALLPTR(14'h30e,5'd28)
                    28: begin // dsw2, 8 lines
                        `CALLDMA(params[6][7-loop_i]?14'h316:14'h310,dstp+{5'd0,loop_i,5'd0},11'd3,1'b1,5'd28)
                        loop_i <= loop_i+4'd1;
                        if( loop_i==7 ) begin loop_i<=0; step<=29; end
                    end
                    default: st <= DONE;
                endcase

                PG_0E00: case( step )
                    0: `CALLPTR(14'hdf,5'd1)
                    1: `CALLDMA(14'he1,dstp,11'd8,1'b1,5'd2)
                    2: `CALLPTR(14'hfb,5'd3)
                    3: `CALLDMA(14'hfd,dstp,11'd8,~cmd[0],5'd4)
                    4: `CALLPTR(14'h10d,5'd5)
                    5: begin sco_base<=0; sco_i<=0; sco_first<=0; st<=SCO0; ret<=STEP; step<=6; end
                    6: begin
                        if( cmd[7] ) `CALLPTR(14'h117,5'd7)
                        else step <= 10;
                    end
                    7: `CALLDMA(14'h119,dstp,11'd8,~cmd[1],5'd8)
                    8: `CALLPTR(14'h129,5'd9)
                    9: begin sco_base<=1; sco_i<=0; sco_first<=0; st<=SCO0; ret<=STEP; step<=10; end
                    10: begin
                        if( !cmd[2] ) `CALLPTR(14'h133,5'd11)
                        else st <= DONE;
                    end
                    11: `CALLDMA(14'h135,dstp,11'h10,1'b1,5'd12)
                    12: begin page<=PG_INSERT; step<=0; subret<=1; page_ret<=PG_0E00; step_ret<=13; end
                    13: begin
                        if( cmd[4:3]==0 ) begin
                            page<=PG_CREDIT; step<=0; subret<=1; page_ret<=PG_0E00; step_ret<=14;
                        end else st <= DONE;
                    end
                    default: st <= DONE;
                endcase
                default: st <= DONE;
            endcase

            // read a 14-bit pointer from the data ROM into dstp
            PTR0: `ROMRD(ptr_a,PTR1)
            PTR1: begin
                dstp[13:8] <= rom_data[5:0];
                `ROMRD(ptr_a+14'd1,PTR2)
            end
            PTR2: begin
                dstp[7:0] <= rom_data;
                st <= ret;
            end

            // read one ROM byte into tmp
            RD0: `ROMRD(ptr_a,RD1)
            RD1: begin tmp <= rom_data; st <= ret; end

            // dma(src,dst,size,cond)
            DMA0: begin
                if( dma_i==dma_size ) st <= ret;
                else if( dma_cond ) `ROMRD(dma_src+{3'd0,dma_i},DMA1)
                else begin
                    code_byte <= 8'h20;
                    st <= DMA2;
                end
            end
            DMA1: begin code_byte <= rom_data; st <= DMA2; end
            DMA2: begin // code plane write
                if( dma_dst+{3'd0,dma_i} >= 18 ) begin
                    vram_addr <= {1'b0,dma_dst[9:0]+dma_i[9:0]};
                    vram_din  <= code_byte;
                    vram_we   <= 1;
                end
                if( dma_cond ) `ROMRD(dma_src+{3'd0,dma_size}+{3'd0,dma_i},DMA3)
                else begin
                    code_byte <= attr13;
                    st <= DMA4;
                end
            end
            DMA3: begin code_byte <= rom_data; st <= DMA4; end
            DMA4: begin // attr plane write
                if( dma_dst+{3'd0,dma_i} >= 18 ) begin
                    vram_addr <= {1'b1,dma_dst[9:0]+dma_i[9:0]};
                    vram_din  <= code_byte;
                    vram_we   <= 1;
                end
                dma_i <= dma_i+11'd1;
                st <= DMA0;
            end

            // fill whole page, tile in code_byte, pal in tmp
            FILL0: begin
                if( dma_i==11'h400 ) st <= ret;
                else begin
                    if( dma_i >= 18 ) begin
                        vram_addr <= {1'b0,dma_i[9:0]};
                        vram_din  <= code_byte;
                        vram_we   <= 1;
                    end
                    st <= FILL1;
                end
            end
            FILL1: begin
                if( dma_i >= 18 ) begin
                    vram_addr <= {1'b1,dma_i[9:0]};
                    vram_din  <= tmp;
                    vram_we   <= 1;
                end
                dma_i <= dma_i+11'd1;
                st <= FILL0;
            end

            // score digits (kozure_score_msg): 6 BCD digits + "0" + fixed 0x30
            SCO0: begin
                sco_code <= (sco_first || sco_res!=0) ? {4'h3,sco_res} : 8'h20;
                if( sco_res!=0 ) sco_first <= 1;
                vram_addr <= {1'b0,dstp[9:0]+{7'd0,sco_i}};
                vram_din  <= (sco_first || sco_res!=0) ? {4'h3,sco_res} : 8'h20;
                vram_we   <= 1;
                `ROMRD(sco_atr+{11'd0,sco_i},SCO1)
            end
            SCO1: begin
                vram_addr <= {1'b1,dstp[9:0]+{7'd0,sco_i}};
                vram_din  <= rom_data;
                vram_we   <= 1;
                sco_i <= sco_i+3'd1;
                st <= sco_i==5 ? SCO2 : SCO0;
            end
            SCO2: begin // char 6: 0x30 unless score was all blank
                vram_addr <= {1'b0,dstp[9:0]+10'd6};
                vram_din  <= sco_code==8'h20 ? 8'h20 : 8'h30;
                vram_we   <= 1;
                `ROMRD(sco_atr+14'd6,SCO3)
            end
            SCO3: begin
                vram_addr <= {1'b1,dstp[9:0]+10'd6};
                vram_din  <= rom_data;
                vram_we   <= 1;
                st <= SCO4;
            end
            SCO4: begin // char 7: fixed 0x30
                vram_addr <= {1'b0,dstp[9:0]+10'd7};
                vram_din  <= 8'h30;
                vram_we   <= 1;
                `ROMRD(sco_atr+14'd7,SCO5)
            end
            SCO5: begin
                vram_addr <= {1'b1,dstp[9:0]+10'd7};
                vram_din  <= rom_data;
                vram_we   <= 1;
                st <= ret;
            end

            DONE: begin
                busy <= 0;
                st   <= IDLE;
            end
            default: st <= IDLE;
        endcase
    end
end

endmodule
