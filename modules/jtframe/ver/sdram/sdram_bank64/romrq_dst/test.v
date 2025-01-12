`timescale 1ns/1ps

module test;

parameter HF=1, SHIFTED=1,PERIOD=20, SIMLEN=1;

reg         rst, clk, clk_sdram;
wire [15:0] data_read;

wire [11:0] slot0_addr, slot1_addr, slot2_addr;
wire        slot0_cs, slot1_cs, slot2_cs;
wire        slot0_ok, slot1_ok, slot2_ok;
wire [ 7:0] slot0_dout;
wire [15:0] slot1_dout;
wire [31:0] slot2_dout;

// bank signals
wire [21:0] ba0_addr, ba1_addr, ba2_addr, ba3_addr;
wire [ 1:0] ba0_din_m;

wire [ 3:0] ba_rd, ba_wr, ba_rdy, ba_dst, ba_ack, ba_dok;
wire        hblank;
wire [15:0] ba0_din;
wire        all_ack;

// sdram pins
wire [15:0] sdram_dq;
wire [12:0] sdram_a;
wire [ 1:0] sdram_dqm;
wire [ 1:0] sdram_ba;
wire        sdram_nwe;
wire        sdram_ncas;
wire        sdram_nras;
wire        sdram_ncs;
wire        sdram_cke;

assign ba3_addr = 0;
assign ba_rd[3] = 0;
assign ba_wr    = 0;

initial begin
    clk=0;
    forever begin
        #(PERIOD/2) clk=~clk;
        #(`SDRAM_SHIFT) clk_sdram = clk;
    end
end

initial begin
    rst=1;
    #100 rst=0;
    #(SIMLEN*1_000_000) begin
        $display("PASS");
        $finish;
    end
end

// horizontal line counter
localparam HMAX=64_000/PERIOD;
integer    hcnt;
assign hblank = hcnt==0;

initial $display("HMAX=%d",HMAX);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hcnt <= 0;
    end else begin
        hcnt <= hcnt == HMAX-1 ? 0 : (hcnt+1);
    end
end

wire init;
wire rst_romrq = rst | init;

reader #(.ROM("sdram_bank0.bin"),.DW(8)) u_read0(
    .rst        ( rst_romrq  ),
    .clk        ( clk        ),
    .cs         ( slot0_cs   ),
    .addr       ( slot0_addr ),
    .ok         ( slot0_ok   ),
    .data       ( slot0_dout )
);

reader #(.ROM("sdram_bank1.bin"),.DW(16)) u_read1(
    .rst        ( rst_romrq  ),
    .clk        ( clk        ),
    .cs         ( slot1_cs   ),
    .addr       ( slot1_addr ),
    .ok         ( slot1_ok   ),
    .data       ( slot1_dout )
);

reader #(.ROM("sdram_bank2.bin"),.DW(32)) u_read2(
    .rst        ( rst_romrq  ),
    .clk        ( clk        ),
    .cs         ( slot2_cs   ),
    .addr       ( slot2_addr ),
    .ok         ( slot2_ok   ),
    .data       ( slot2_dout )
);

localparam BA0_LEN=32,BA1_LEN=32,BA2_LEN=32,BA3_LEN=32;

jtframe_rom_1slot #(.SLOT0_DW( 8),.SLOT0_AW(12)) u_bank0(
    .rst        ( rst_romrq  ),
    .clk        ( clk        ),
    .slot0_addr ( slot0_addr ),
    .slot0_dout ( slot0_dout ),

    .slot0_cs   ( slot0_cs   ),
    .slot0_ok   ( slot0_ok   ),
    // SDRAM controller interface
    .sdram_ack  ( ba_ack[0]  ),
    .sdram_rd   ( ba_rd[0]   ),
    .sdram_addr ( ba0_addr   ),
    .data_rdy   ( ba_rdy[0]  ),
    .data_dst   ( ba_dst[0]  ),
    .data_read  ( data_read  )
);

jtframe_rom_1slot #(.SLOT0_DW(16),.SLOT0_AW(12)) u_bank1(
    .rst        ( rst_romrq  ),
    .clk        ( clk        ),
    .slot0_addr ( slot1_addr ),
    .slot0_dout ( slot1_dout ),

    .slot0_cs   ( slot1_cs   ),
    .slot0_ok   ( slot1_ok   ),
    // SDRAM controller interface
    .sdram_ack  ( ba_ack[1]  ),
    .sdram_rd   ( ba_rd[1]   ),
    .sdram_addr ( ba1_addr   ),
    .data_rdy   ( ba_rdy[1]  ),
    .data_dst   ( ba_dst[1]  ),
    .data_read  ( data_read  )
);

jtframe_rom_1slot #(.SLOT0_DW(32),.SLOT0_AW(12)) u_bank2(
    .rst        ( rst_romrq  ),
    .clk        ( clk        ),
    .slot0_addr ( slot2_addr ),
    .slot0_dout ( slot2_dout ),

    .slot0_cs   ( slot2_cs   ),
    .slot0_ok   ( slot2_ok   ),
    // SDRAM controller interface
    .sdram_ack  ( ba_ack[2]  ),
    .sdram_rd   ( ba_rd[2]   ),
    .sdram_addr ( ba2_addr   ),
    .data_rdy   ( ba_rdy[2]  ),
    .data_dst   ( ba_dst[2]  ),
    .data_read  ( data_read  )
);

mt48lc16m16a2 sdram(
    .Clk        ( clk_sdram ),
    .Cke        ( sdram_cke ),
    .Dq         ( sdram_dq  ),
    .Addr       ( sdram_a   ),
    .Ba         ( sdram_ba  ),
    .Cs_n       ( sdram_ncs ),
    .Ras_n      ( sdram_nras),
    .Cas_n      ( sdram_ncas),
    .We_n       ( sdram_nwe ),
    .Dqm        ( sdram_dqm ),
    .downloading( 1'b0      ),
    .VS         ( 1'b0      ),
    .frame_cnt  ( 0         )
);

jtframe_sdram64 #(
    .AW     ( 22      ),
    .HF     ( HF      ),
    .SHIFTED( SHIFTED ),
    .BA0_LEN( BA0_LEN ),
    .BA1_LEN( BA1_LEN ),
    .BA2_LEN( BA2_LEN ),
    .BA3_LEN( BA3_LEN )
) uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .rfsh       ( hblank        ),
    .init       ( init          ),
    // Bank 0: allows R/W
    .ba0_addr   ( ba0_addr      ),
    .ba1_addr   ( ba1_addr      ),
    .ba2_addr   ( ba2_addr      ),
    .ba3_addr   ( ba3_addr      ),
    .rd         ( ba_rd         ),
    .wr         ( ba_wr         ),
    .ba0_din    ( ba0_din       ),
    .ba0_dsn    ( ba0_din_m     ),  // write mask
    .ba1_din    (               ),
    .ba1_dsn    (               ),  // write mask
    .ba2_din    (               ),
    .ba2_dsn    (               ),  // write mask
    .ba3_din    (               ),
    .ba3_dsn    (               ),  // write mask
    .rdy        ( ba_rdy        ),
    .dok        ( ba_dok        ),
    .dst        ( ba_dst        ),
    .ack        ( ba_ack        ),

    .prog_en    ( 1'd0          ),

    // SDRAM pins
    .sdram_dq   ( sdram_dq      ),
    .sdram_a    ( sdram_a       ),
    .sdram_dqml ( sdram_dqm[0]  ),
    .sdram_dqmh ( sdram_dqm[1]  ),
    .sdram_ba   ( sdram_ba      ),
    .sdram_nwe  ( sdram_nwe     ),
    .sdram_ncas ( sdram_ncas    ),
    .sdram_nras ( sdram_nras    ),
    .sdram_ncs  ( sdram_ncs     ),
    .sdram_cke  ( sdram_cke     ),
    // Common signals
    .dout       ( data_read     )
);

`ifdef DUMP
initial begin
    $dumpfile("test.lxt");
    $dumpvars;
end
`endif

endmodule

module reader #(parameter ROM="sdram_bank0.bin",DW=8)(
    input             rst,
    input             clk,
    output reg        cs,
    output reg [11:0] addr,
    input             ok,
    input    [DW-1:0] data
);

reg [15:0] ref_buf[0:1<<12];
reg [11:0] pre_addr;
reg   waiting;
reg   error;
reg [DW-1:0] exp;
wire [DW-1:0] ref_addr=ref_buf[addr];

integer file,rcnt;

initial begin
    file=$fopen(ROM,"rb");
    if(file==0) begin $display("Cannot open %s\nFAIL",ROM); $finish; end
    rcnt = $fread(ref_buf,file);
    $fclose(file);
end

always @(*) begin
    addr = pre_addr;
    if( DW==32 ) addr[0]=0;
    case(DW)
        8:  case(addr[0])
                0: exp = ref_buf[addr>>1];
                1: exp = ref_buf[addr>>1]>>8;
            endcase
        16: exp=ref_buf[addr];
        32: exp={ ref_buf[addr+1'd1], ref_buf[addr] };
    endcase
    case( DW )
        default: error=1;
        8:  error = data!==exp;
        16: error = data!==exp;
        32: error = data!==exp;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        addr <= 0;
        cs   <= 0;
        waiting <= 0;
    end else begin
        if( !cs ) begin
            pre_addr <= $random;
            waiting <= 1;
            cs      <= 1;
        end
        if( cs && ok ) begin
            if( error ) begin
                $display("ERROR: expecting %X, got %X (%m)",exp, data);
                #40 $finish;
            end
            cs <= 0;
        end
    end
end

endmodule
