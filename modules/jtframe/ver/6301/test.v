module test;

reg         rst, clk;
wire        rnw, vma, rom_cs, ram_cs;
reg  [ 7:0] ram[0:255];
reg  [ 7:0] rom[0:4095];
wire [15:0] addr;
wire [ 7:0] dout, din;

integer f, fcnt;

initial begin
   for( f=0; f<256; f=f+1 ) ram[f]=0;
   f=$fopen("test.bin","rb");
   fcnt=$fread(rom,f);
   $display("Read %d bytes",fcnt);
   $fclose(f);
   rom['hffe]=8'hf0;
   rom['hfff]=8'h00;
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

initial begin
    rst=0;
    #200
    rst=1;
    #200
    rst=0;
end

initial begin
    clk=0;
    forever #5 clk=~clk;
end

assign rom_cs = vma &&  addr[15];
assign ram_cs = vma && !addr[15];
assign din = ram_cs ? ram[addr[7:0]] :
             rom_cs ? rom[addr[11:0]]: 8'd0;

always @(posedge clk) begin
    if( ram_cs & ~rnw ) begin
        ram[addr[7:0]] = dout;
        if( addr=='h4001 ) $finish;
    end
end

m6801 uut(
        .rst        ( rst       ),
        .clk        ( clk       ),
        .cen        ( 1'b1      ),
        .rw         ( rnw       ),
        .vma        ( vma       ),
        .address    ( addr      ),
        .data_in    ( din       ),
        .data_out   ( dout      ),
        .halt       (           ),
        .halted     (           ),
        .irq        ( 1'b0      ),
        .nmi        ( 1'b0      ),
        .irq_icf    ( 1'b0      ),
        .irq_ocf    ( 1'b0      ),
        .irq_tof    ( 1'b0      ),
        .irq_sci    ( 1'b0      )
);

endmodule