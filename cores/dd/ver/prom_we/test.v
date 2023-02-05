`timescale 1ns/1ps

module test;

reg         rst;
reg         clk, downloading=1'b1;
reg  [21:0] ioctl_addr= 22'd0;
reg  [ 7:0] ioctl_dout= 8'd0;
reg         ioctl_wr;

wire [21:0] prog_addr;
wire [ 7:0] prog_data;
wire [ 1:0] prog_mask;
wire        prog_we;
wire [`PROM_W-1:0] prom_we;

`ifndef DD2
localparam BANK_ADDR   = 22'h00000;
localparam MAIN_ADDR   = 22'h20000;
localparam SND_ADDR    = 22'h28000;
localparam ADPCM_0     = 22'h30000;
localparam ADPCM_1     = 22'h40000;
localparam CHAR_ADDR   = 22'h50000;
// Scroll
localparam SCRZW_ADDR  = 22'h60000;
localparam SCRXY_ADDR  = 22'h80000;
// objects
localparam OBJWZ_ADDR  = 22'hA0000;
localparam OBJXY_ADDR  = 22'hE0000;
// FPGA BRAM:
localparam MCU_ADDR    = 22'h120000;
localparam PROM_ADDR   = 22'h124000;
// ROM length 124300
`else
//Double Dragon 2
localparam BANK_ADDR   = 22'h00000;
localparam MAIN_ADDR   = 22'h20000;
localparam SND_ADDR    = 22'h28000;
localparam SUB_ADDR    = 22'h30000;
localparam ADPCM_0     = 22'h40000;
localparam ADPCM_1     = 22'h60000;
localparam CHAR_ADDR   = 22'h80000;
// Scroll
localparam SCRZW_ADDR  = 22'h90000;
localparam SCRXY_ADDR  = 22'hB0000;
// objects
localparam OBJWZ_ADDR  = 22'hD0000;
localparam OBJXY_ADDR  = 22'h130000;
// FPGA BRAM:
localparam PROM_ADDR   = 22'h190000;
localparam MCU_ADDR    = 22'h190000; // same as PROM_ADDR for DD2
// ROM length 190200
`endif

jtdd_prom_we #(
    .BANK_ADDR  ( BANK_ADDR     ),
    .MAIN_ADDR  ( MAIN_ADDR     ),
    .SND_ADDR   ( SND_ADDR      ),
    .MCU_ADDR   ( MCU_ADDR      ),
    .ADPCM_0    ( ADPCM_0       ),
    .ADPCM_1    ( ADPCM_1       ),
    .CHAR_ADDR  ( CHAR_ADDR     ),
    .SCRZW_ADDR ( SCRZW_ADDR    ),
    .SCRXY_ADDR ( SCRXY_ADDR    ),
    .OBJWZ_ADDR ( OBJWZ_ADDR    ),
    .OBJXY_ADDR ( OBJXY_ADDR    ),
    .PROM_ADDR  ( PROM_ADDR     )
) u_uut(
    .clk         (  clk          ),
    .downloading (  downloading  ),
    .ioctl_addr  (  ioctl_addr   ),
    .ioctl_dout  (  ioctl_dout   ),
    .ioctl_wr    (  ioctl_wr     ),
    .prog_addr   (  prog_addr    ),
    .prog_data   (  prog_data    ),
    .prog_mask   (  prog_mask    ),
    .prog_we     (  prog_we      ),
    .prom_we     (  prom_we      ),
    .sdram_ack   (  1'b1         )
);

wire [15:0] sdram_dout = 16'habcd;

initial begin
    clk = 1'b0;    
    forever #10 clk = ~clk;
end

initial begin
    rst = 1'b0;
    #7 rst = 1'b1;
    #7 rst = 1'b0;
end

reg [1:0] cnt=2'b0;
reg [7:0] romfile[0:`ROM_LEN-1];
integer f, flen;

initial begin    
    f=$fopen(`ROM_PATH,"rb");
    if( f==0 ) begin
        $display("ERROR: cannot open file %s",`ROM_PATH);
        $finish;
    end
    flen=$fread(romfile,f);
    $display("INFO: %s ROM lentgh 0x%X",`ROM_PATH,flen);
    $fclose(f);
end

reg [15:0] sdram[0:2**22-1];
integer cnt2;

always @(posedge clk) begin
    cnt      <= cnt+2'd1;
    ioctl_wr <= 1'b0;
    if( ioctl_addr < `ROM_LEN && cnt==2'b10 ) begin
        ioctl_dout <= romfile[ioctl_addr];
        ioctl_wr   <= 1'b1;
    end else if(cnt==2'b11) begin
        ioctl_addr <= ioctl_addr + 22'd1;
    end else if( ioctl_addr >= `ROM_LEN ) begin
        downloading <= 1'b0;
        f=$fopen("sdram.hex");
        for( cnt2=0; cnt2<(2**22-1); cnt2=cnt2+1) begin
            $fdisplay(f,"%04X",sdram[cnt2]);
        end
        $fclose(f);
        $display("INFO: SDRAM download done");
        $finish;
    end
end

always @(negedge prog_we) begin
    if(!prog_mask[1]) sdram[ prog_addr ][15:8] <= prog_data;
    if(!prog_mask[0]) sdram[ prog_addr ][ 7:0] <= prog_data;
end

initial begin
`ifndef NCVERILOG
    $dumpfile("test.lxt");
    $dumpvars(0,test);
    $dumpon;    
`else 
    $shm_open("test.shm");
    $shm_probe(test,"AS");
`endif
end

endmodule