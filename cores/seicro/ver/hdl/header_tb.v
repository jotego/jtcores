// Author: Andrea Bogazzi
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

integer mode;
initial begin
    for(mode=0;mode<8;mode=mode+1) begin
        @(negedge clk); header=1; prog_we=1; prog_addr=0; prog_data=8'ha0+mode;
        @(negedge clk); prog_we=0; rst=1;
        repeat(5) @(negedge clk);
        rst=0;
        if({dut.radial,dut.frisky,dut.nsc8105}!==mode[2:0])
            $fatal(1,"Game mode not loaded/retained: %0d",mode);
        if(dut.psg_snd_rcen!==!(mode[1]|mode[2]) ||
           dut.dac_snd_rcen!==!(mode[1]|mode[2]))
            $fatal(1,"Schematic filters enabled for an unverified board: %0d",mode);
        if(dut.psg_snd!==0 || dut.dac_snd!==0) $fatal(1,"NOSOUND raw activity");
        @(negedge clk); prog_we=1; prog_addr=1; prog_data=8'hff;
        @(negedge clk); header=0; prog_addr=0;
        @(negedge clk); prog_we=0;
        if({dut.radial,dut.frisky,dut.nsc8105}!==mode[2:0])
            $fatal(1,"Game mode changed outside selector byte: %0d",mode);
    end
    $display("PASS header: CPU/game selectors, byte isolation and reset retention");
    $finish;
end
endmodule
