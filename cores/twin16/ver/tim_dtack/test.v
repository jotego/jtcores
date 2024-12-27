module test;

reg rst, clk;
wire tim1, tim2, cen_1m5;

wire [15:0] m_dout, s_dout, v_din, ma_dout, mb_dout, mo_dout;
wire [13:1] m_addr, s_addr, osha_addr;
wire [12:1] vram_addr;
wire [ 1:0] va_we, vb_we, vam_we, vas_we, vbm_we, vbs_we, osha_we, om_we, os_we;
wire        fail;

assign fail = m_fail | s_fail;

initial begin
    clk=0;
    forever #10.172 clk=~clk;
end

integer loops=0;
localparam MAXLOOPS=20;

initial begin
    rst=0;
    #5 rst=1;
    #200 rst=0;
    for(loops=1;loops<=MAXLOOPS;loops=loops+1) begin
        #100_000_000;
        $display("%d/%d",loops,MAXLOOPS);
        // if(loops==7)  $dumpon;
    end
    $display("PASS");
    $finish;
end

initial begin
    //$dumpfile("test.lxt");
    //$dumpvars;
    // $dumpon;
end

always @(posedge fail) begin
    $display("FAIL");
    #1000
    $finish;
end

jtframe_gated_cen #(.W(1),.NUM(835),.DEN(26721),.MFREQ(49153)) u_cen2_clk(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .busy   ( 1'b0      ),
    .cen    ( cen_1m5   ),
    .fave   (           ),
    .fworst (           )
);

jtframe_gated_cen #(.W(1),.NUM(3),.DEN(16),.MFREQ(49153)) u_cpu_cen(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .busy   ( 1'b0      ),
    .cen    ( cpu_cen   ),
    .fave   (           ),
    .fworst (           )
);

jtframe_ram16 #(.AW(13-1)) u_bram_scra(
    .clk    ( clk       ),
    .data   ( v_din     ),
    .addr   ( vram_addr ),
    .we     ( va_we     ),
    .q      ( ma_dout   )
);

jtframe_ram16 #(.AW(13-1)) u_bram_scrb(
    .clk    ( clk       ),
    .data   ( v_din     ),
    .addr   ( vram_addr ),
    .we     ( vb_we     ),
    .q      ( mb_dout   )
);

jtframe_ram16 #(.AW(14-1)) u_oram(
    .clk    ( clk       ),
    .data   ( v_din     ),
    .addr   ( osha_addr ),
    .we     ( osha_we   ),
    .q      ( mo_dout   )
);

memcheck #(0) u_mcheck(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cpu_cen( cpu_cen   ),
    .tim    ( tim1      ),
    .addr   ( m_addr    ),
    .va_we  ( vam_we    ),
    .vb_we  ( vbm_we    ),
    .osha_we( om_we     ),
    .ma_dout( ma_dout   ),
    .mb_dout( mb_dout   ),
    .mo_dout( mo_dout   ),
    .dout   ( m_dout    ),
    .fail   ( m_fail    )
);

memcheck #(1) u_scheck(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cpu_cen( cpu_cen   ),
    .tim    ( tim2      ),
    .addr   ( s_addr    ),
    .va_we  ( vas_we    ),
    .vb_we  ( vbs_we    ),
    .osha_we( os_we     ),
    .ma_dout( ma_dout   ),
    .mb_dout( mb_dout   ),
    .mo_dout( mo_dout   ),
    .dout   ( s_dout    ),
    .fail   ( s_fail    )
);

jttwin16_share u_share(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_1m5   ),
    .tim1       ( tim1      ),
    .tim2       ( tim2      ),

    .m_dout     ( m_dout    ),
    .s_dout     ( s_dout    ),
    .v_din      ( v_din     ),
    .m_addr     ( m_addr    ),
    .s_addr     ( s_addr    ),
    // shared RAM
    .shm_we     ( 2'd0      ),
    .shs_we     ( 2'd0      ),
    .shm_dout   (           ),
    .shs_dout   (           ),
    // video RAM multiplexers
    .vram_addr  ( vram_addr ),
    .osha_addr  ( osha_addr ),

    .om_we      ( om_we     ),
    .os_we      ( os_we     ),
    .oram_we    ( osha_we   ),

    .vam_we     ( vam_we    ),
    .vas_we     ( vas_we    ),
    .va_we      ( va_we     ),

    .vbm_we     ( vbm_we    ),
    .vbs_we     ( vbs_we    ),
    .vb_we      ( vb_we     )
);

endmodule

module memcheck(
    input         rst, clk, cpu_cen, tim,
    output [ 1:0] va_we, vb_we, osha_we,
    input  [15:0] ma_dout, mb_dout, mo_dout,
    output reg [15:0] dout=0,
    output [13:1] addr,
    output        fail
);


parameter [0:0] ID=0;
localparam IDLE=0, WRITE=1, DELAY_DSN=2, WAIT_DTACK=3, DELAY_RD=4, CHECK=5;
localparam MSB=5, TIMEOUT=4;
localparam [1:0] VA=0,VB=1,OBJ=2;

wire [ 15:0] dmux;
reg  [MSB:0] idle='h3f;
reg  [ 13:1] test_addr=0;
wire         dtack_n, oram_cs, vram_cs;
reg          ASn=1, RnW=1, DSn=1, ASnl=1, bad_check=0, tim_l;
reg  [  1:0] dsel=0;
wire [  1:0] we;
integer      rnd, timeout=0, st=0;

assign addr    = dsel!=OBJ ? {1'b0,ID[0],test_addr[11:1]} : {ID[0],test_addr[12:1]};
assign fail    = (ASnl && !dtack_n) || bad_check || timeout==TIMEOUT;
assign we      = {2{!ASn && !RnW && !DSn}};
assign va_we   = dsel==VA  ? we : 2'b0;
assign vb_we   = dsel==VB  ? we : 2'b0;
assign osha_we = dsel==OBJ ? we : 2'b0;
assign oram_cs = dsel==OBJ && !ASn;
assign vram_cs = dsel!=OBJ && !ASn;

always @(posedge clk) begin
    ASnl  <= ASn;
    tim_l <= tim;
    rnd  <= $random;
    if( !ASn && tim && !tim_l ) begin
        timeout <= timeout+1;
        if(timeout==(TIMEOUT-1)) $display("Timeout (%d)",ID);
    end
    if( !ASn && ASnl ) timeout <= 0;
end

always @(posedge clk) if(cpu_cen) begin
    idle <= idle-6'd1;
    case(st)
        IDLE: begin
            ASn  <= 1;
            RnW  <= 1;
            DSn  <= 1;
            dsel <= rnd[1:0]%3;
            if(idle==0) st <= WRITE;
        end
        WRITE: begin
            ASn  <= 1'b0;
            RnW  <= 1'b0;
            test_addr <= rnd[15-:11];
            dout <= rnd[31:16];
            idle <= {4'd0,rnd[1:0]};
            st   <= DELAY_DSN;
        end
        DELAY_DSN: if(idle[MSB]) begin
            DSn <= 0;
            st  <= WAIT_DTACK;
        end
        WAIT_DTACK: if(!dtack_n) begin
            ASn  <= 1;
            RnW  <= 1;
            DSn  <= 1;
            idle <= {1'b1,rnd[MSB-1:0]};
            st   <= DELAY_RD;
        end
        DELAY_RD: if(idle==0) begin
            ASn <= 0;
            DSn <= 0;
            st  <= CHECK;
        end
        CHECK: if(!dtack_n) begin
            ASn  <= 1;
            DSn  <= 1;
            if(dmux!==dout) begin
                $display("%X!==%X (%d)",dmux,dout,ID);
                bad_check <= 1;
            end
            idle <= {1'b1, rnd[MSB-1:0]};
            st   <= IDLE;
        end
    endcase
end

jttwin16_dtack u_dtack(
    .clk        ( clk       ),
    .oram_cs    ( oram_cs   ),
    .vram_cs    ( vram_cs   ),
    .oeff_cs    (           ),
    .dma_bsy    ( 1'b0      ),
    .ASn        ( ASn       ),
    .RnW        ( RnW       ),
    .UDSn       ( DSn       ),
    .LDSn       ( DSn       ),
    .tim        ( tim       ),
    .ab_sel     ( dsel==VA  ),
    .pre_dtackn ( 1'b1      ),
    .ma_dout    ( ma_dout   ),
    .mb_dout    ( mb_dout   ),
    .mo_dout    ( mo_dout   ),
    .vdout      ( dmux      ),
    .DTACKn     ( dtack_n   )
);

endmodule
