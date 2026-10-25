/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-10-2026 */

module jtpopeye_main(
    input             rst,
    input             clk,
    input             cpu_cen,
    input             psg_cen,

    input             vb,
    input             initeo,
    input             tpp1rom,
    input             boot,
    input             tpp1ram,
    input             tnx1,
    output reg        reset_n,

    input      [ 1:0] cab_1p,
    input             coin,
    input             service,
    input             dip_pause,
    input      [ 5:0] joystick1,
    input      [ 5:0] joystick2,

    input             busrq_n,
    output            busak_n,
    input             dma_cs,
    input      [10:0] dma_addr,

    output     [12:0] ad,
    output     [ 7:0] dd,
    output     [ 7:0] cpu_dout,
    output            csv,
    output            csbw_n,
    output            dwrbk_n,
    output            memwr0,

    output            bdir,
    output            bc1,
    input      [ 7:0] ay_dout,

    output            prot_cs,
    output            prot_we,
    output            prot_addr,
    input      [ 7:0] prot_dout,

    output reg [ 7:0] blprot_addr,
    input      [ 7:0] blprot_data,

    output     [11:0] work_addr,
    output            work_we,
    input      [ 7:0] work_dout,

    output            main_cs,
    output     [14:0] main_addr,
    input      [ 7:0] main_data,
    input             main_ok
);
`ifndef NOMAIN
wire [15:0] A;
wire [15:13] ad_hi;
wire [ 7:0] rom_dd, rom_sw, bl_dd, bl_xor;
wire [14:0] tnx_addr;
wire        m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n,
            memrq, iorq, wrh, rdh, rfsh, iowr, iord, memwr, memrd,
            csb, ram_cs, busak,
            ad11, ram_sel, rfst, pe_n, phi_cen, dma_rd, bl_cs;
wire [ 7:0] cab;
reg         sel8, sela, selc, sele;
reg  [ 7:0] din;
reg  [ 3:0] cnt2l;
reg         nmi_n, q3kl, q3kr, vb_l, rfst_l, csb_d, wr_d, phi_l;

assign ad       = { A[12:10], A[8], A[7], A[6], A[3], ~A[9], ~A[5], ~A[4], ~A[2:0] };
assign ad_hi    = A[15:13];
assign rom_sw   = { main_data[3], main_data[4], main_data[2], main_data[5],
                    main_data[1], main_data[6], main_data[0], main_data[7] };
assign rom_dd   = boot ? main_data : rom_sw;
assign tnx_addr = { A[14:10], A[8], A[7], ~A[0], ~A[1], ~A[2], ~A[4], ~A[5], ~A[9], A[3], A[6] };
assign memrq    = ~mreq_n;
assign iorq     = ~iorq_n;
assign wrh      = ~wr_n;
assign rdh      = ~rd_n;
assign rfsh     = ~rfsh_n;
assign busak    = ~busak_n;
assign iowr     = wrh & iorq;
assign iord     = rdh & iorq;
assign memwr    = memrq & wrh;
assign memrd    = memrq & rdh;
assign memwr0   = memwr;
assign rfst     = rfsh & memrq;

assign csv      = memrq & sela;
assign csb      = memrq & selc;
assign csbw_n   = ~(csb | csb_d);
assign dwrbk_n  = ~(csb & wr_d & wrh);

assign ram_sel  = tnx1    ? (~ad[11] | ad[10]) :
                  tpp1ram ? (ad[11] == ad[10]) : ad[11];
assign ad11     = busak | ram_sel;
assign dma_rd   = dma_cs & busak;
assign ram_cs   = ad11 & (dma_rd | (memrq & sel8));
assign work_we  = ram_cs & memwr;
assign work_addr= busak ? { 1'b1, dma_addr } : ad[11:0];
assign dd       = busak ? work_dout : cpu_dout;

assign main_cs  = memrq & rfsh_n & ~ad_hi[15];
assign main_addr= boot ? A[14:0] : tpp1rom ? tnx_addr : { ad_hi[14:13], ad };

assign bdir     = iowr;
assign bc1      = (iowr & ad[0]) | (iord & (ad[1:0]==2'd0));

assign prot_cs  = sele & (memwr | memrd) & ~boot;
assign prot_we  = memwr;
assign prot_addr= ad[0];

assign bl_cs    = boot & sele & memrd & (A[12:5]==8'd0);
assign bl_xor   = blprot_addr[7] ? 8'h03 : 8'h0f;
assign bl_dd    = blprot_data ^ bl_xor;

assign pe_n     = ~(q3kr | q3kl);

always @* begin
    sel8 = ad_hi==3'b100;
    sela = ad_hi==3'b101;
    selc = ad_hi==3'b110;
    sele = ad_hi==3'b111;
end

always @* begin
    din = memrd ? (!ad_hi[15] ? rom_dd :
                    ram_cs   ? work_dout :
                    prot_cs  ? prot_dout :
                    bl_cs    ? bl_dd : 8'hff) :
          iord  ? (ad[1:0]==2'd0 ? ay_dout : cab) : 8'hff;
end

always @(posedge clk) begin
    if( rst ) begin
        blprot_addr <= 0;
    end else begin
        blprot_addr <= { m1_n, 2'b00, A[4:0] };
    end
end

always @(posedge clk) begin
    if( rst ) begin
        phi_l <= 0;
        csb_d <= 0;
        wr_d  <= 0;
    end else begin
        phi_l <= phi_cen;
        if( phi_l ) begin
            csb_d <= csb;
            wr_d  <= wrh;
        end
    end
end

always @(posedge clk) begin
    if( rst ) begin
        vb_l    <= 0;
        rfst_l  <= 0;
        q3kl    <= 1;
        q3kr    <= 0;
        nmi_n   <= 1;
        cnt2l   <= 0;
        reset_n <= 0;
    end else begin
        vb_l    <= vb;
        rfst_l  <= rfst;
        reset_n <= ~cnt2l[2];
        if( rfst && !rfst_l ) begin
            q3kl <= ad[5];
            q3kr <= ad[9];
        end
        if( !reset_n ) q3kr <= 0;
        if( !q3kr )
            nmi_n <= 1;
        else if( vb && !vb_l && dip_pause )
            nmi_n <= 0;
        if( vb && !vb_l ) cnt2l <= pe_n ? cnt2l + 4'd1 : 4'd0;
    end
end

jtpopeye_cab u_cab(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .psg_cen    ( psg_cen   ),
    .addr       ( ad[1:0]   ),
    .initeo     ( initeo    ),
    .tnx1       ( tnx1      ),
    .cab_1p     ( cab_1p    ),
    .coin       ( coin      ),
    .service    ( service   ),
    .joystick1  ( joystick1 ),
    .joystick2  ( joystick2 ),
    .cab        ( cab       )
);

jtframe_z80_romwait #(.RECOVERY(0)) u_cpu(
    .rst_n      ( reset_n   ),
    .clk        ( clk       ),
    .cen        ( cpu_cen   ),
    .cpu_cen    ( phi_cen   ),
    .int_n      ( 1'b1      ),
    .nmi_n      ( nmi_n     ),
    .busrq_n    ( busrq_n   ),
    .m1_n       ( m1_n      ),
    .mreq_n     ( mreq_n    ),
    .iorq_n     ( iorq_n    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .rfsh_n     ( rfsh_n    ),
    .halt_n     (           ),
    .busak_n    ( busak_n   ),
    .A          ( A         ),
    .din        ( din       ),
    .dout       ( cpu_dout  ),
    .rom_cs     ( main_cs   ),
    .rom_ok     ( main_ok   )
);
`else
wire _unused = &{1'b0, cpu_cen, psg_cen, vb, initeo, tpp1rom, boot, tpp1ram, tnx1,
                  cab_1p, coin, service, dip_pause, joystick1, joystick2, dma_cs,
                  ay_dout, prot_dout, blprot_data,
                  main_data, main_ok};
always @(posedge clk) reset_n <= ~rst;
always @(posedge clk) blprot_addr <= 0;
// Scene mode leaves the CPU bus available to the ordinary video DMA.
assign busak_n   = busrq_n;
assign work_addr = {1'b1,dma_addr};
assign work_we   = 0;
assign ad        = 0;
assign dd        = work_dout;
assign cpu_dout  = 0;
assign csv       = 0;
assign csbw_n    = 1;
assign dwrbk_n   = 1;
assign memwr0    = 0;
assign bdir      = 0;
assign bc1       = 0;
assign prot_cs   = 0;
assign prot_we   = 0;
assign prot_addr = 0;
assign main_cs   = 0;
assign main_addr = 0;
`endif
endmodule
