module header_tb;
reg clk=0, rst=1, header=0, prog_we=0;
reg [21:0] prog_addr=0;
reg [7:0] prog_data=0;
always #5 clk=~clk;

jtseicro_game dut(
    .rst       ( rst       ),
    .clk       ( clk       ),
    .dip_flip  ( 1'b1      ),
    .prog_addr ( prog_addr ),
    .prog_data ( prog_data ),
    .prog_we   ( prog_we   ),
    .header    ( header    )
);

initial begin
    @(negedge clk); header=1; prog_we=1; prog_data=1;
    @(negedge clk); prog_we=0;
    if(dut.nsc8105!==1) $fatal(1,"NSC header not loaded");
    repeat(5) @(negedge clk);
    rst=0;
    @(negedge clk); prog_we=1; prog_addr=1; prog_data=0;
    @(negedge clk); header=0; prog_addr=0;
    @(negedge clk); prog_we=0;
    if(dut.nsc8105!==1) $fatal(1,"CPU mode changed outside selector byte");
    @(negedge clk); header=1; prog_we=1;
    @(negedge clk); prog_we=0; rst=1;
    repeat(5) @(negedge clk);
    if(dut.nsc8105!==0) $fatal(1,"M6802 header not retained across reset");
    $display("PASS header: per-set CPU selection and reset retention");
    $finish;
end
endmodule
