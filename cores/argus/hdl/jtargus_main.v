module jtargus_main(
    input             rst,
    input             clk,
    input             cen5,
    input             irq8,
    input             irq10,

    output     [ 7:0] cpu_dout,

    output reg [ 7:0] snd_latch,
    output reg        flip,
    output            bg1_en,
    output            grey_en,
    output     [ 9:0] bg0_scrx,
    output     [ 8:0] bg0_scry,
    output     [ 7:0] bg0_vrom,
    output     [ 8:0] bg1_scrx,
    output     [ 8:0] bg1_scry,

    output     [12:0] ram_addr,
    input      [ 7:0] ram_dout,
    output            ram_we,

    output     [10:1] tx_addr,
    input      [15:0] tx_dout,
    output     [ 1:0] tx_we,

    output     [10:1] bg1_addr,
    input      [15:0] bg1_dout,
    output     [ 1:0] bg1_we,

    output     [11:0] pal_addr,
    output     [ 7:0] pal_din,
    output            pal_we,

    output reg [17:0] main_addr,
    input      [ 7:0] main_data,
    output reg        main_cs,
    input             main_ok,

    input      [ 1:0] cab_1p,
    input      [ 1:0] coin,
    input      [ 5:0] joystick1,
    input      [ 5:0] joystick2,
    input      [ 7:0] dipsw_a,
    input      [ 7:0] dipsw_b,
    input             dip_pause
);

reg  [ 7:0] cpu_din, cpu_mux, int_vector, bg_status,
            sys_din, p1_din, p2_din;
reg  [ 2:0] bank;
reg  [ 7:0] bg0_x[0:1];
reg  [ 7:0] bg0_y[0:1];
reg  [ 7:0] bg1_x[0:1];
reg  [ 7:0] bg1_y[0:1];
reg rst_n, irq_pending, irq8_l, irq10_l;
reg sys_cs,  p1_cs,   p2_cs,   dswa_cs, dswb_cs, snd_cs,
    flip_cs, bank_cs, scx0_cs, scy0_cs, scx1_cs, scy1_cs,
    bgst_cs, pal_cs,  tx_cs,   bg1_cs,  ram_cs;

wire [15:0] A;
wire mreq_n, iorq_n, rd_n, wr_n, rfsh_n, m1_n, int_n;
wire macc, wr, rd, irq_ack;

assign macc   = !mreq_n && rfsh_n;
assign wr     = macc && !wr_n;
assign rd     = macc && !rd_n;
assign irq_ack = !m1_n && !iorq_n;


assign bg1_en   = bg_status[0];
assign grey_en  = bg_status[1];
assign bg0_scrx = {2'd0, bg0_x[0]};
assign bg0_scry = {bg0_y[1][0] ^ flip, bg0_y[0]};
assign bg0_vrom = bg0_x[1] + {7'd0, flip};
assign bg1_scrx = {bg1_x[1][0] ^ flip, bg1_x[0]};
assign bg1_scry = {bg1_y[1][0] ^ flip, bg1_y[0]};

assign ram_addr = A[12:0];
assign ram_we   = ram_cs && !wr_n;

assign tx_addr  = A[10:1];
assign tx_we    = {2{tx_cs && !wr_n}} & { A[0], ~A[0] };

assign bg1_addr = A[10:1];
assign bg1_we   = {2{bg1_cs && !wr_n}} & { A[0], ~A[0] };

assign pal_addr = A[11:0] - 12'h400;
assign pal_din  = cpu_dout;
assign pal_we   = pal_cs && !wr_n;
assign int_n    = ~(irq_pending&dip_pause);

always @* begin
    sys_cs    = 1'b0;
    p1_cs     = 1'b0;
    p2_cs     = 1'b0;
    dswa_cs   = 1'b0;
    dswb_cs   = 1'b0;
    snd_cs    = 1'b0;
    flip_cs   = 1'b0;
    bank_cs   = 1'b0;
    scx0_cs   = 1'b0;
    scy0_cs   = 1'b0;
    scx1_cs   = 1'b0;
    scy1_cs   = 1'b0;
    bgst_cs   = 1'b0;
    pal_cs    = 1'b0;
    tx_cs     = 1'b0;
    bg1_cs    = 1'b0;
    ram_cs    = 1'b0;
    main_cs   = 1'b0;
    main_addr = {2'b0,A};
    if( !rst && macc && A<16'hc000 ) begin
        main_cs = 1'b1;
        if( A[15] )
            main_addr = 18'h1_0000 + {1'b0, bank, A[13:0]};
    end
    if (&A[15:14]) begin
        if(rd) begin
            case(A[2:0])
                0: sys_cs = 1;
                1: p1_cs  = 1;
                2: p2_cs  = 1;
                3: dswa_cs= 1;
                4: dswb_cs= 1;
                default:
            endcase
        end
        if(wr && A[9])begin
            case(A[11:8])
                2:  case(A[7:0])
                        8'h00: snd_cs  = 1;
                        8'h01: flip_cs = 1;
                        8'h02: bank_cs = 1;
                        default:;
                    endcase
                3:  case(A[7:1])
                        7'h00: scx0_cs = 1;
                        7'h01: scy0_cs = 1;
                        7'h04: scx1_cs = 1;
                        7'h05: scy1_cs = 1;
                        7'h18: bgst_cs = 1;
                        default:;
                    endcase
                default:;
            endcase
        end
        if(macc) begin
            pal_cs = A[13:12]==0 && A[11:10]!=0;
            tx_cs  = A[13:11]==3'b10;
            bg1_cs = A[13:11]==3'b11;
            ram_cs = A[13];
        end
    end
end

always @* begin
    sys_din = { coin[0], coin[1], 4'hf, cab_1p };
    p1_din  = { 2'b11, joystick1 };
    p2_din  = { 2'b11, joystick2 };

    cpu_mux =
        !iorq_n ? int_vector :
        main_cs ? main_data  :
        ram_cs  ? ram_dout   :
        tx_cs   ? (A[0] ? tx_dout[ 15:8] : tx_dout[ 7:0]) :
        bg1_cs  ? (A[0] ? bg1_dout[15:8] : bg1_dout[7:0]) :
        sys_cs  ? sys_din    :
        p1_cs   ? p1_din     :
        p2_cs   ? p2_din     :
        dswa_cs ? dipsw_a    :
        dswb_cs ? dipsw_b    :
        8'hff;
end

always @(posedge clk) begin
    cpu_din <= cpu_mux;
    rst_n   <= ~rst;
    irq8_l  <= irq8;
    irq10_l <= irq10;
end

always @(posedge clk) begin
    if( rst ) begin
        bank        <= 3'd0;
        snd_latch   <= 8'd0;
        flip        <= 1'b0;
        bg_status   <= 8'h01;
        bg0_x[0]    <= 8'd0;
        bg0_x[1]    <= 8'd0;
        bg0_y[0]    <= 8'd0;
        bg0_y[1]    <= 8'd0;
        bg1_x[0]    <= 8'd0;
        bg1_x[1]    <= 8'd0;
        bg1_y[0]    <= 8'd0;
        bg1_y[1]    <= 8'd0;
        irq_pending <= 1'b0;
        int_vector  <= 8'hcf;
        cpu_din     <= 8'hff;
    end else begin
        if( irq_ack ) begin
            irq_pending <= 1'b0;
        end else if( irq8 && !irq8_l ) begin
            irq_pending <= 1'b1;
            int_vector  <= 8'hcf;
        end else if( irq10 && !irq10_l ) begin
            irq_pending <= 1'b1;
            int_vector  <= 8'hd7;
        end

        if( snd_cs  ) snd_latch <= cpu_dout;
        if( flip_cs ) flip      <= cpu_dout[7];
        if( bank_cs ) bank      <= cpu_dout[2:0];
        if( bgst_cs ) bg_status <= cpu_dout;
        if( scx0_cs ) bg0_x[A[0]] <= cpu_dout;
        if( scy0_cs ) bg0_y[A[0]] <= cpu_dout;
        if( scx1_cs ) bg1_x[A[0]] <= cpu_dout;
        if( scy1_cs ) bg1_y[A[0]] <= cpu_dout;
    end
end

jtframe_z80_romwait #(.CLR_INT(0),.RECOVERY(1)) u_cpu(
    .rst_n   ( rst_n    ),
    .clk     ( clk      ),
    .cen     ( cen5     ),
    .cpu_cen (          ),
    .int_n   ( int_n    ),
    .nmi_n   ( 1'b1     ),
    .busrq_n ( 1'b1     ),
    .m1_n    ( m1_n     ),
    .mreq_n  ( mreq_n   ),
    .iorq_n  ( iorq_n   ),
    .rd_n    ( rd_n     ),
    .wr_n    ( wr_n     ),
    .rfsh_n  ( rfsh_n   ),
    .halt_n  (          ),
    .busak_n (          ),
    .A       ( A        ),
    .din     ( cpu_din  ),
    .dout    ( cpu_dout ),
    .rom_cs  ( main_cs  ),
    .rom_ok  ( main_ok  )
);

endmodule
