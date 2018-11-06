`timescale 1ns/1ps

module jtgng_sound(
    input   clk,    // 6   MHz
    input   rst,
    input   soft_rst,
    // Interface with main CPU
    input           sres_b, // Z80 reset
    input   [7:0]   snd_latch,
    input           V32,    
    // ROM access
    output  [14:0]  rom_addr,
    output          rom_cs,
    input   [ 7:0]  rom_dout,
    input           snd_wait,
    // Sound output
    output  signed [8:0] ym_mux_right,
    output  signed [8:0] ym_mux_left,
    output  signed [11:0] fm_right,
    output  signed [11:0] fm_left,
    output  ym_mux_sample
);

wire [15:0] A;
assign rom_addr = A[14:0];
wire ym_mux0_sample;
assign ym_mux_sample = ym_mux0_sample;

reg reset_n;

always @(negedge clk)
    reset_n <= ~( rst | soft_rst /*| ~sres_b*/ );

reg clk_en;

always @(negedge clk)
    if( rst ) 
        clk_en <= 1'b1;
    else
        clk_en <= ~clk_en;

wire ym1_cs,ym0_cs, latch_cs, ram_cs;
reg [4:0] map_cs;

assign { rom_cs, ym1_cs, ym0_cs, latch_cs, ram_cs } = map_cs;

reg [7:0] AH;

always @(*)
    casez(A[15:11])
        5'b0???_?: map_cs = 5'h10; // 0000-7FFF, ROM
        5'b1100_0: map_cs = 5'h1; // C000-C7FF, RAM
        5'b1100_1: map_cs = 5'h2; // C800-C8FF, Sound latch
        5'b1110_0: 
            if( !A[1] ) map_cs = 5'h4; // E000-E0FF, Yamaha
                else    map_cs = 5'h8;
        default: map_cs = 5'h0;
    endcase


// RAM, 8kB
wire rd_n;
wire wr_n;

wire RAM_we = ram_cs && !wr_n;
wire [7:0] ram_dout, dout;

jtgng_chram RAM(    // 2 kB, just like CHARs
    .address    ( A[10:0]   ),
    .clock      ( clk       ),  // 6 MHz
    .data       ( dout      ),
    .wren       ( RAM_we    ),
    .q          ( ram_dout  )
);

reg [7:0] din;

always @(*)
    din =  ({8{  ram_cs}} & ram_dout  ) | 
                ({8{  rom_cs}} & rom_dout  ) |
                ({8{latch_cs}} & snd_latch ) ;

    reg int_n;
    wire m1_n;
    wire mreq_n;
    wire iorq_n;
    wire rfsh_n;
    wire halt_n;
    wire busak_n;

    wire [1:0] busy_bus;
    wire busy = |busy_bus;
    // wire wait_n = !( busy || !snd_wait);
    wire wait_n = snd_wait;

reg lastV32;
reg [4:0] int_n2;

always @(posedge clk) begin
    lastV32 <= V32;
    if ( !V32 && lastV32 ) begin
        { int_n, int_n2 } <= 6'b0;
    end
    else begin
        if( ~&int_n2 ) 
            int_n2 <= int_n2+5'd1;
        else
            int_n <= 1'b1;
    end
end

tv80s Z80 (
    .reset_n(reset_n ),
    .clk    (clk     ), // 3 MHz, clock gated
    .cen    (clk_en  ),
    .wait_n (wait_n  ),
    .int_n  (int_n   ),
    .nmi_n  (1'b1    ),
    .busrq_n(1'b1    ),
    .m1_n   (m1_n    ),
    .mreq_n (mreq_n  ),
    .iorq_n (iorq_n  ),
    .rd_n   (rd_n    ),
    .wr_n   (wr_n    ),
    .rfsh_n (rfsh_n  ),
    .halt_n (halt_n  ),
    .busak_n(busak_n ),
    .A      (A       ),
    .di     (din     ),
    .dout   (dout    )
);

wire [6:0] nc0, nc1;
wire [8:0] ym_mux1_left, ym_mux0_left, ym_mux1_right, ym_mux0_right;

wire signed [11:0] fm0_snd_right,fm1_snd_right;
wire signed [11:0] fm0_snd_left,fm1_snd_left;


assign ym_mux_right = (ym_mux0_right+ym_mux1_right)>>>1;
assign ym_mux_left  = ( ym_mux0_left+ym_mux1_left )>>>1;
assign fm_right = fm0_snd_right+fm1_snd_right;
assign fm_left  = fm0_snd_left+fm1_snd_left;



jt12 fm0(
    .rst    ( ~reset_n  ),
    // CPU interface
    .clk    ( clk       ),
    .cen    ( clk_en    ),
    .din    ( dout      ),
    .addr   ( {1'b0,A[0]}   ),
    .cs_n   ( ~ym0_cs   ),
    .wr_n   ( wr_n      ),
    .limiter_en( 1'b1   ),

    .dout   ( { busy_bus[0], nc0 } ),
    //output            irq_n,
    // combined output
    .snd_right  ( fm0_snd_right ),
    .snd_left   ( fm0_snd_left  ),
    .snd_sample (),
    // multiplexed output
    .mux_right  ( ym_mux0_right ),  
    .mux_left   ( ym_mux0_left  ),
    .mux_sample ( ym_mux0_sample),
    .irq_n()
);

jt12 fm1(
    .rst    ( ~reset_n  ),
    // CPU interface
    .clk    ( clk       ),
    .cen    ( clk_en    ),
    .din    ( dout  )   ,
    .addr   ( {1'b0,A[0]}   ),
    .cs_n   ( ~ym1_cs   ),
    .wr_n   ( wr_n      ),
    .limiter_en( 1'b1   ),

    .dout   ( { busy_bus[1], nc1 } ),
    //output            irq_n,
    // combined output
    .snd_right  ( fm1_snd_right ),
    .snd_left   ( fm1_snd_left  ),
    .snd_sample (),
    // multiplexed output
    .mux_right  ( ym_mux1_right ),  
    .mux_left   ( ym_mux1_left  ),
    .mux_sample (),
    .irq_n()    
);


endmodule // jtgng_sound