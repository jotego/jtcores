// Author: Andrea Bogazzi
`timescale 1ns/1ps
module reset_tb;
reg clk=0, rst=1, pause_n=1, lvbl=1, service=0;
reg bdir=0, bc1=0, header_we=0;
reg guard_mcu_reset=0;
reg [7:0] data=0;
reg [2:0] mode=0;
reg [8:0] last_h;
integer game_mode, frame;

always #5 clk=~clk;

always @(posedge clk) begin
    if(guard_mcu_reset && dut.u_mcu.core_rst)
        $fatal(1,"MCU reset pulsed while the release latch was set");
end

jtseicro_game dut(
    .rst                ( rst          ),
    .clk                ( clk          ),
    .cpu_cen            ( 1'b0         ),
    .audio_cen          ( 1'b1         ),
    .pxl_cen            ( 1'b1         ),
    .dip_pause          ( pause_n      ),
    .dip_flip           ( 1'b1         ),
    .dipsw              ( 32'hffffffff ),
    .gfx_en             ( 4'hf         ),
    .header             ( 1'b1         ),
    .prog_we            ( header_we    ),
    .prog_addr          ( 22'd0        ),
    .prog_data          ( {5'd0,mode}  ),
    .maincpu_ok         ( 1'b1         ),
    .maincpu_data       ( 8'd0         ),
    .mcu_ok             ( 1'b1         ),
    .mcu_data           ( 8'h01        ),
    .scr_ok             ( 1'b1         ),
    .scr_data           ( 16'd0        ),
    .obj_ok             ( 1'b1         ),
    .obj_data           ( 16'd0        ),
    .tile_vram_data     ( 8'd0         ),
    .tile_color_data    ( 8'd0         ),
    .scroll_video_data  ( 8'd0         ),
    .obj_ram0_data      ( 8'd0         ),
    .obj_ram1_data      ( 8'd0         ),
    .proms_data         ( 8'd0         ),
    .mcu_sharedram_dout ( 8'd0         ),
    .nvram_dout         ( 8'd0         )
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

task next_frame;
    begin
        lvbl=1;
        repeat(4) @(negedge clk);
        lvbl=0;
        repeat(4) @(negedge clk);
    end
endtask

task check_reset;
    input expected;
    begin
        if(dut.watchdog_rst!==expected || dut.board_rst!==(rst | expected))
            $fatal(1,"Watchdog reset state mode=%0d frame=%0d",mode,frame);
    end
endtask

initial begin
    force dut.cpu_dout=data;
    force dut.ay_bdir=bdir;
    force dut.ay_bc1=bc1;
    force dut.cpu_lvbl=lvbl;
    force dut.watchdog_clr=service;
    for(game_mode=0;game_mode<5;game_mode=game_mode+1) begin
        rst=1; service=0; pause_n=1; lvbl=1;
        mode=game_mode==4 ? 3'd5 : game_mode;
        header_we=1;
        repeat(5) @(negedge clk);
        header_we=0; rst=0;
        repeat(4) @(negedge clk);
        if(dut.mcu_run!==0) $fatal(1,"MCU released without a clock edge");
        ay_write(15,8'h04);
        if(!dut.irq_en) $fatal(1,"AY B0 preload drove ACK in input mode");
        ay_write(7,8'h80);
        if(dut.mcu_run!==0) $fatal(1,"High-to-high GPIO direction change released MCU");
        ay_write(15,8'h00);
        ay_write(15,8'h04);
        if(dut.mcu_run!==1 || dut.u_mcu.core_rst!==0)
            $fatal(1,"First B2 rising edge did not release MCU");
        guard_mcu_reset=1;
        ay_write(15,8'h00);
        if(dut.mcu_run!==1 || dut.u_mcu.core_rst!==0)
            $fatal(1,"B2 falling edge reset MCU");
        ay_write(15,8'h04);
        if(dut.mcu_run!==1 || dut.u_mcu.core_rst!==0)
            $fatal(1,"Repeated B2 rising edge reset MCU");
        guard_mcu_reset=0;
        next_frame;
        if(dut.u_main.irq_pending) $fatal(1,"ACK low did not suppress frame IRQ");
        ay_write(15,8'h05);
        if(dut.u_main.irq_pending) $fatal(1,"ACK rising edge triggered IRQ");
        pause_n=0;
        next_frame;
        if(dut.u_main.irq_pending) $fatal(1,"Pause did not suppress frame IRQ");
        pause_n=1;
        repeat(4) @(negedge clk);
        if(dut.u_main.irq_pending) $fatal(1,"Unpause triggered IRQ without a frame edge");
        next_frame;
        if(dut.u_main.irq_pending!==1) $fatal(1,"Frame edge did not latch IRQ");
        pause_n=0;
        ay_write(15,8'h04);
        if(dut.u_main.irq_pending) $fatal(1,"Paused CPU prevented software ACK");
        pause_n=1;
        rst=1;
        repeat(5) @(negedge clk); rst=0;
        repeat(4) @(negedge clk);
        ay_write(15,8'h00);
        ay_write(7,8'h80);
        if(dut.mcu_run!==0) $fatal(1,"Falling B2 released MCU");
        ay_write(7,8'h00);
        if(dut.mcu_run!==1) $fatal(1,"Input pull-up rising edge did not release MCU");
        if(!dut.irq_en) $fatal(1,"AY B0 input pull-up did not release ACK");
        for(frame=1;frame<=14;frame=frame+1) begin
            next_frame;
            check_reset(0);
        end
        next_frame;
        check_reset(1);
        if(dut.u_main.cpu_rst!==1 || dut.u_main.rst!==0 ||
           dut.u_main.irq_pending!==1 || dut.u_snd.rst!==1 || dut.u_mcu.core_rst!==1 ||
           dut.mcu_run!==0 || dut.u_video.rst!==0 ||
           {dut.radial,dut.frisky,dut.nsc8105}!==mode)
            $fatal(1,"Watchdog reset domain or game header changed");
        last_h=dut.u_video.hdump;
        repeat(20) @(negedge clk);
        check_reset(1);
        if(dut.u_video.hdump===last_h) $fatal(1,"Video timing stopped during watchdog reset");
        next_frame;
        check_reset(0);
        if(dut.mcu_run!==0) $fatal(1,"MCU restarted without B2 after watchdog reset");
        if(dut.u_main.irq_pending!==1) $fatal(1,"Watchdog cleared the IRQ latch");
        ay_write(15,8'h00);
        ay_write(7,8'h80);
        if(dut.irq_en || dut.u_main.irq_pending) $fatal(1,"AY B0 did not acknowledge IRQ after watchdog reset");
        ay_write(15,8'h04);
        if(dut.mcu_run!==1) $fatal(1,"MCU failed to restart after watchdog reset");
        for(frame=1;frame<=15;frame=frame+1) next_frame;
        check_reset(1);
        service=1;
        repeat(2) @(negedge clk);
        check_reset(0);
        for(frame=0;frame<32;frame=frame+1) begin
            next_frame;
            check_reset(0);
        end
        service=0; pause_n=0;
        for(frame=0;frame<32;frame=frame+1) begin
            next_frame;
            check_reset(0);
        end
        pause_n=1;
        repeat(20) @(negedge clk);
        check_reset(0);
        for(frame=1;frame<=14;frame=frame+1) begin
            next_frame;
            check_reset(0);
        end
        next_frame;
        check_reset(1);
        service=1;
        repeat(2) @(negedge clk); service=0;
        repeat(20) @(negedge clk);
        check_reset(0);
    end
    $display("PASS reset: five game modes, watchdog service/pause/wrap, reset domains and MCU GPIO latch");
    $finish;
end

initial begin
    #1000000;
    $fatal(1,"Reset test timeout");
end

endmodule
