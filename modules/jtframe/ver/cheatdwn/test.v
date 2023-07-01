`timescale 1ns/1ps

module test;

reg clk=0;

reg prog_en=0, prog_wr=0, prog_done=0, verify_done=0;
integer prog_addr=0;
reg [7:0] memin[0:2303];
wire [7:0] prog_data = memin[prog_addr];
wire [17:0] idata;

integer st=0;

initial begin
    $readmemh( "testin.hex", memin );
    forever #5 clk = ~clk;
end

always @(posedge clk) begin
    st <= st+1;
end

always @(posedge clk) begin
    if( !prog_done ) begin
        prog_en <= 1;
        prog_wr <= st[2:0]==4;
        if( st[2:0]==7 ) begin
            prog_addr <= prog_addr+1;
            if( prog_addr==2303 ) begin
                prog_en <= 0;
                prog_done <= 1;
                prog_addr <= 0;
                $display("Programming done\n");
            end
        end
    end else if( !verify_done ) begin
        if( st[2:0]==3 ) begin
            $display("%05X", idata );
        end
        if( st[2:0]==7 ) begin
            prog_addr <= prog_addr+1;
            if( prog_addr==1023 ) begin
                verify_done <= 1;
                $finish;
            end
        end
    end
end

jtframe_cheat_rom uut(
    .clk        ( clk       ),
    .iaddr      ( prog_addr[9:0] ),
    .idata      ( idata     ),
    // PBlaze Program
    .prog_en    ( prog_en   ),
    .prog_wr    ( prog_wr   ),
    .prog_addr  ( prog_addr[7:0] ),
    .prog_data  ( prog_data )
);

initial begin
`ifndef IVERILOG
    $shm_open("test.shm");
    $shm_probe(test,"AS");
`else
    $dumpfile("test.lxt");
    $dumpvars;
`endif
end

endmodule