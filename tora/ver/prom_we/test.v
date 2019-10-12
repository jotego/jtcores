`timescale 1ns/1ps

module test;

reg         clk, downloading=1'b1;
reg  [21:0] ioctl_addr=22'd0;
reg  [ 7:0] ioctl_data= 8'd0;
reg         ioctl_wr;

wire [21:0] prog_addr;
wire [ 7:0] prog_data;
wire [ 1:0] prog_mask;
wire        prog_we;
wire [`PROM_W-1:0] prom_we;

jttora_prom_we
    u_uut(
    .clk         (  clk          ),
    .downloading (  downloading  ),
    .ioctl_addr  (  ioctl_addr   ),
    .ioctl_data  (  ioctl_data   ),
    .ioctl_wr    (  ioctl_wr     ),
    .prog_addr   (  prog_addr    ),
    .prog_data   (  prog_data    ),
    .prog_mask   (  prog_mask    ),
    .prog_we     (  prog_we      ),
    .prom_we     (  prom_we      )
);

initial begin
    clk = 1'b0;    
    forever #10 clk = ~clk;
end

reg [1:0] cnt=2'b0;
reg [7:0] romfile[0:`ROM_LEN-1];
integer f;

initial begin    
    f=$fopen(`ROM_PATH,"rb");
    if( f==0 ) begin
        $display("ERROR: cannot open file %s",`ROM_PATH);
        $finish;
    end
    cnt=$fread(romfile,f);
    $display("INFO: %s ROM lentgh 0x%h",`ROM_PATH,cnt);
    $fclose(f);
end

reg [15:0] sdram[0:2**22-1];
integer cnt2;

always @(posedge clk) begin
    cnt      <= cnt+2'd1;
    ioctl_wr <= 1'b0;
    if( ioctl_addr < `ROM_LEN && cnt==2'b10 ) begin
        ioctl_data <= romfile[ioctl_addr];
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
        $finish;
    end
end


always @(negedge prog_we) begin
    if(!prog_mask[1]) sdram[ prog_addr ][15:8] <= prog_data;
    if(!prog_mask[0]) sdram[ prog_addr ][ 7:0] <= prog_data;
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
    $dumpon;    
end

endmodule