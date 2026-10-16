module flip_tb;
reg clk=0, rst=1;
reg [63:0] status=0;
reg bdir=0, bc1=0;
reg [7:0] data=0;
wire dip_flip;
wire [1:0] rotate;
integer hardware_flip, osd_flip;
reg expected;
always #5 clk=~clk;

jtframe_dip u_dip(
    .clk         ( clk      ),
    .status      ( status   ),
    .game_pause  ( 1'b0     ),
    .vertical    ( 1'b1     ),
    .dipflip_xor ( 1'b0     ),
    .osd_shown   ( 1'b0     ),
    .game_test   ( 1'b1     ),
    .dip_flip    ( dip_flip ),
    .rotate      ( rotate   )
);

jtseicro_game dut(
    .rst       ( rst             ),
    .clk       ( clk             ),
    .audio_cen ( 1'b1            ),
    .cpu_cen   ( 1'b0            ),
    .pxl_cen   ( 1'b0            ),
    .dip_pause ( 1'b1            ),
    .dip_flip  ( dip_flip        ),
    .status    ( status[31:0]    ),
    .dipsw     ( 32'hffffffff    ),
    .header    ( 1'b0            ),
    .prog_we   ( 1'b0            ),
    .prog_addr ( 22'd0           ),
    .prog_data ( 8'd0            )
);

task ay_write;
    input [7:0] address, value;
    begin
        @(negedge clk); data=address; bdir=1; bc1=1;
        repeat(4) @(negedge clk); bdir=0; bc1=0;
        repeat(4) @(negedge clk); data=value; bdir=1;
        repeat(4) @(negedge clk); bdir=0;
        repeat(8) @(negedge clk);
    end
endtask

initial begin
    force dut.cpu_dout=data;
    force dut.ay_bdir=bdir;
    force dut.ay_bc1=bc1;
    repeat(5) @(negedge clk); rst=0;
    ay_write(7,8'h80);
    for(hardware_flip=0;hardware_flip<2;hardware_flip=hardware_flip+1) begin
        ay_write(15,{6'd0,hardware_flip[0],1'b1});
        for(osd_flip=0;osd_flip<2;osd_flip=osd_flip+1) begin
            status[1]=osd_flip[0];
            repeat(4) @(negedge clk);
            case({hardware_flip[0],osd_flip[0]})
                2'b00,2'b11: expected=1;
                default: expected=0;
            endcase
            if(dip_flip!==!osd_flip[0] || dut.flip!==hardware_flip[0] ||
               dut.u_video.flip!==expected || dut.u_video.u_scroll.flip!==expected ||
               dut.u_video.u_obj.flip!==expected)
                $fatal(1,"OSD/cocktail flip wiring raw=%0d osd=%0d",hardware_flip,osd_flip);
            if((dut.u_video.flip ^ rotate[1])!==hardware_flip[0])
                $fatal(1,"HDMI rotation changed the software flip");
            if(!dut.irq_en || dut.mcu_run) $fatal(1,"OSD flip changed AY control state");
        end
    end
    $display("PASS flip: four OSD/cocktail combinations through AY, scroll, sprites and HDMI rotation");
    $finish;
end
endmodule
