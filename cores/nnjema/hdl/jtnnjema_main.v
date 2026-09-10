/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 8-9-2026 */

module jtnnjema_main(
    input             rst,
    input             clk,
    input             cen6,

    input             m4_en,      // ninjemak/youma hardware
    input             LVBL,

    // cabinet
    input      [ 1:0] cab_1p,
    input      [ 1:0] coin,
    input      [ 6:0] joystick1,
    input      [ 6:0] joystick2,
    input             service,
    input             dip_test,
    input             dip_pause,
    input      [23:0] dipsw,

    // text RAM (write only from CPU)
    output            vram_we,
    output     [10:0] vram_addr,
    // sprite RAM (bram in mem.yaml)
    output     [ 8:0] ocpu_addr,
    output            ocpu_we,
    input      [ 7:0] ocpu_dout,
    output     [ 7:0] cpu_dout,

    // video control
    output reg        flip,
    output reg        dispen_n,   // gfxbank bit 4 (ninjemak)
    output     [ 2:0] layers,     // galivan scrollx[1] bits 7:5
    output     [12:0] scrx,
    output     [10:0] scry,

    // NB1414M4
    output reg        blit_stb,
    output reg        vb_ack,

    // sound
    output reg [ 7:0] snd_latch,
    input             latch_clr,

    // ROM
    output reg        rom_cs,
    output     [16:0] rom_addr,
    input      [ 7:0] rom_data,
    input             rom_ok
);

wire        mmr_cs;
wire [ 1:0] mmr_addr;
wire [10:0] gal_scrx;

assign scrx = {2'd0, gal_scrx};

`ifndef NOMAIN
wire [15:0] A;
wire [ 7:0] cpu_din;
reg  [ 7:0] cab_dout, gfxbank;
wire        mreq_n, iorq_n, rd_n, wr_n, m1_n, rfsh_n;
wire        cen_eff;
reg         int_n;
reg         ram_cs, oram_cs, io_rd, io_wr;
reg  [ 1:0] bank;
wire [ 7:0] ram_dout;
reg         LVBLl;

wire iorq  = !iorq_n && m1_n;
wire iowr  = iorq && !wr_n;
wire iord  = iorq && !rd_n;
wire memrd = !mreq_n && rfsh_n && !rd_n;
wire memwr = !mreq_n && rfsh_n && !wr_n;

assign vram_we   = memwr && A[15:11]==5'b11011;    // D800-DFFF
assign vram_addr = A[10:0];
assign rom_addr  = A[15:13]==3'b110 ? {2'b10,bank,A[12:0]} : {1'b0,A};
assign ocpu_addr = A[8:0];
assign ocpu_we   = oram_cs && memwr;

always @* begin
    rom_cs  = memrd && A<16'he000;
    oram_cs = !mreq_n && rfsh_n && A[15:9]==7'b1110_000;  // E000-E1FF
    ram_cs  = !mreq_n && rfsh_n && A[15:13]==3'b111 && !oram_cs;
end

// gfxbank: 0-1 coin counters, 2 flip, 4 display disable (m4), bank bits
always @(posedge clk) begin
    if( rst ) begin
        gfxbank  <= 0;
        flip     <= 0;
        dispen_n <= 0;
        bank     <= 0;
    end else if( iowr && (m4_en ? A[7:0]==8'h80 : A[7:0]==8'h40) ) begin
        gfxbank  <= cpu_dout;
        flip     <= cpu_dout[2];
        dispen_n <= m4_en & cpu_dout[4];
        bank     <= m4_en ? cpu_dout[7:6] : {1'b0,cpu_dout[7]};
    end
end

// galivan scroll registers in the video MMR, ports 0x41-0x44
assign mmr_cs   = iowr && !m4_en && A[7:0]>=8'h41 && A[7:0]<=8'h44;
assign mmr_addr = A[1:0]-2'd1;

// sound latch, cleared by the sound CPU
always @(posedge clk) begin
    if( rst )
        snd_latch <= 0;
    else begin
        if( iowr && (m4_en ? A[7:0]==8'h85 : A[7:0]==8'h45) )
            snd_latch <= {cpu_dout[6:0],1'b1};
        else if( latch_clr )
            snd_latch <= 0;
    end
end

// NB1414M4 strobes
always @(posedge clk) begin
    blit_stb <= m4_en && iowr && A[7:0]==8'h86;
    vb_ack   <= m4_en && iowr && A[7:0]==8'h87;
end

// vblank interrupt, cleared by IO write (47/87)
always @(posedge clk) begin
    if( rst ) begin
        int_n <= 1;
        LVBLl <= 0;
    end else begin
        LVBLl <= LVBL;
        if( LVBLl && !LVBL && dip_pause ) int_n <= 0;
        if( iowr && A[7:0]==(m4_en ? 8'h87 : 8'h47) ) int_n <= 1;
    end
end

// cabinet inputs, active low
always @(posedge clk) begin
    case( {m4_en, A[2:0]} )
        {1'b0,3'd0}, {1'b1,3'd0}:
            cab_dout <= ~{1'b0,joystick1[6:4],joystick1[0],joystick1[1],joystick1[2],joystick1[3]};
        {1'b0,3'd1}, {1'b1,3'd1}:
            cab_dout <= ~{1'b0,joystick2[6:4],joystick2[0],joystick2[1],joystick2[2],joystick2[3]};
        {1'b0,3'd2}, {1'b1,3'd2}:
            cab_dout <= ~{2'd0,m4_en?1'b0:~dip_test,service,coin,cab_1p};
        {1'b1,3'd3}: cab_dout <= {6'h3f,dipsw[17],1'b1};   // SERVICE port
        {1'b0,3'd3}, {1'b1,3'd4}: cab_dout <= dipsw[ 7:0]; // DSW1
        {1'b0,3'd4}, {1'b1,3'd5}: cab_dout <= dipsw[15:8]; // DSW2
        default: cab_dout <= 8'hff;
    endcase
end

wire cab_cs = iord && (m4_en ? A[7:4]==4'h8 && A[3:0]<6
                             : A[7:4]==4'h0 && A[3:0]<5);
wire c0_cs  = iord && !m4_en && A[7:0]==8'hc0; // dangar watchdog check

assign cpu_din = rom_cs  ? rom_data  :
                 oram_cs ? ocpu_dout :
                 ram_cs  ? ram_dout  :
                 cab_cs  ? cab_dout  :
                 c0_cs   ? 8'h58     : 8'hff;

jtframe_z80 u_cpu(
    .rst_n   ( ~rst      ),
    .clk     ( clk       ),
    .cen     ( cen_eff   ),
    .wait_n  ( 1'b1      ),
    .int_n   ( int_n     ),
    .nmi_n   ( 1'b1      ),
    .busrq_n ( 1'b1      ),
    .m1_n    ( m1_n      ),
    .mreq_n  ( mreq_n    ),
    .iorq_n  ( iorq_n    ),
    .rd_n    ( rd_n      ),
    .wr_n    ( wr_n      ),
    .rfsh_n  ( rfsh_n    ),
    .halt_n  (           ),
    .busak_n (           ),
    .A       ( A         ),
    .din     ( cpu_din   ),
    .dout    ( cpu_dout  )
);

jtframe_z80wait #(.DEVCNT(1),.RECOVERY(0)) u_wait(
    .rst_n   ( ~rst      ),
    .clk     ( clk       ),
    .cen_in  ( cen6      ),
    .cen_out ( cen_eff   ),
    .gate    (           ),
    .mreq_n  ( mreq_n    ),
    .iorq_n  ( iorq_n    ),
    .busak_n ( 1'b1      ),
    .dev_busy( 1'b0      ),
    .rom_cs  ( rom_cs    ),
    .rom_ok  ( rom_ok    )
);

jtframe_ram #(.AW(13)) u_wram(
    .clk  ( clk       ),
    .cen  ( 1'b1      ),
    .addr ( A[12:0]   ),
    .data ( cpu_dout  ),
    .we   ( ram_cs & memwr ),
    .q    ( ram_dout  )
);

`else
initial begin
    flip=0; dispen_n=0;
    blit_stb=0; vb_ack=0; snd_latch=0; rom_cs=0;
end
assign vram_we   = 0;
assign vram_addr = 0;
assign ocpu_addr = 0;
assign ocpu_we   = 0;
assign cpu_dout  = 0;
assign rom_addr  = 0;
assign mmr_cs    = 0;
assign mmr_addr  = 0;
`endif

jtnnjema_video_mmr u_video_mmr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cs         ( mmr_cs    ),
    .addr       ( mmr_addr  ),
    .rnw        ( 1'b0      ),
    .din        ( cpu_dout  ),
    .scrx       ( gal_scrx  ),
    .scry       ( scry      ),
    .layers     ( layers    ),
    .ioctl_addr ( 2'd0      ),
    .ioctl_din  (           ),
    .debug_bus  ( 8'd0      ),
    .st_dout    (           )
);
endmodule
