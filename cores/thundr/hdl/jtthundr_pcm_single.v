/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-3-2025 */

module jtthundr_pcm_single(
    input               rst,
                        clk, cen,
    input               addr,
    input        [ 7:0] din,
    input               wr,

    output       [18:0] rom_addr,
    input        [ 7:0] rom_data,
    output reg          rom_cs,
    input               rom_ok,

    output signed [11:0] snd
);

localparam [2:0] IDLE=0, OS0=1, OS1=2, OS2=3,PLAY=4,LOOP0=5,LOOP1=6, START=7;
localparam [7:0] END=8'hff,SILENT=8'h0, MUTE=8'h0, OS=8'h80;

reg [15:0] rda=0;
reg [ 7:0] loop=0,page=0;
reg  signed [7:0] pcm;
wire signed [7:0] osdata;
reg [ 4:0] sample=0;
reg [12:0] extrabit;
reg signed [4:0] gain;
reg [ 2:0] bank=0, st=0;
reg [ 1:0] vol=0;
reg        start=0, start_l=0, cen_ok=0;
wire       rom_good, valid;
wire [7:0] att;

assign rom_good = ~rom_cs | rom_ok;
assign rom_addr = { bank, rda }; // 3+16=19
assign valid    = sample!=0;
assign osdata   = rom_data - OS;
assign snd      = extrabit[11:0];
assign att      = pcm==-1 ? MUTE : {pcm[7],pcm[7:1]};

always @(posedge clk) begin
    if(rst) begin
        start   <= 0;
    end else begin
        start <= 0;
        if(wr &&  addr) {bank,sample} <= din;
        if(wr && !addr) begin
            start <= 1;
            vol <= din[7:6];
        end
    end
end

always @(posedge clk) begin
    cen_ok <= ~cen_ok;
    case(vol)
        0: gain <= 5'd01;
        1: gain <= 5'd03;
        2: gain <= 5'd08;
        3: gain <= 5'd10;
    endcase
    extrabit <= pcm*gain;
end

always @(posedge clk) begin
    if(rst) begin
        st      <= IDLE;
        start_l <= 0;
        rom_cs  <= 0;
        pcm     <= MUTE;
    end else begin
        if(rom_good) case(st)
            OS0: if(cen_ok) begin
                rda <= {10'd0,sample-5'd1,1'b0}; // 10+5+1=16
                rom_cs <= 1;
                st  <= OS1;
            end
            OS1: if(cen_ok) begin
                page   <= rom_data;
                rda[0] <= 1;
                st     <= OS2;
            end
            OS2: if(cen_ok) begin
                rda[15:0] <= {page,rom_data};
                st <= PLAY;
            end
            PLAY: if(cen) begin
                rda[15:0] <= rda[15:0] + 16'd1;
                case(rom_data)
                    END:     st  <= IDLE;
                    SILENT:  st  <= LOOP0;
                    default: pcm <= osdata;
                endcase
            end
            LOOP0: if(cen) begin
                loop <= rom_data;
                rda[15:0] <= rda[15:0] + 16'd1;
                st <= LOOP1;
            end
            LOOP1: if(cen) begin
                pcm <= att;
                if(loop<=1) begin
                    st  <= PLAY;
                end
                loop <= loop-8'd1;
            end
            START: begin
                rom_cs <= 0;
                st     <= OS0;
            end
            default: begin
                rom_cs <= 0;
                if(cen) pcm <= att;
            end
        endcase
        start_l <= start;
        if(start && !start_l && valid) begin
            rom_cs <= 0;
            st     <= START;
        end
    end
end

endmodule
