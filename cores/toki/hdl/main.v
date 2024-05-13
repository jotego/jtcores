////////// main module  //////////////////////
//
//  - Motorola 68k main cpu @10mhz 
//  - cpu address bus 
//  - cpu 2*32kx8 ram
//  - palette / video / bg1 / bg2 / sprite ram
//  - scrolling & sound latch
// 
module toki_main(
  input             rst,

  // Clock
  input             clk,
  input             clk48,
  input             pxl_cen,
  input             pxl2_cen,

  // Video
  input             hsync, 
  input             vsync,
  input             vblank,
  input       [8:0] hpos,
  input       [8:0] vpos,

  // Input
  input      [1:0]  start_button,
  input      [5:0]  joystick1,
  input      [5:0]  joystick2,

  input      [31:0] dipsw,
  input             dip_pause,     
  input             service,

  input      [15:0] cpu_rom_data,
  input             cpu_rom_ok,
  output reg [18:1] cpu_rom_addr,
  output reg        cpu_rom_cs,

  //Shared video RAM 
  input      [10:1] palette_addr,
  output     [15:0] palette_out,

  input      [10:1] vram_addr,
  output     [15:0] vram_out,


  input      [10:1] bg1_addr,
  output     [15:0] bg1_out,

  input      [10:1] bg2_addr,
  output     [15:0] bg2_out,

  input      [10:1] sprite_addr,
  output     [15:0] sprite_out,

  output  reg [8:0] bg1_scroll_x,
  output  reg [8:0] bg1_scroll_y,
  output  reg [8:0] bg2_scroll_x,
  output  reg [8:0] bg2_scroll_y,

  output  reg       bg_order,

  output reg        sound_cs_2, 
  output reg        sound_cs_4,
  output reg        sound_cs_6,

  output reg [15:0] m68k_sound_latch_0,
  output reg [15:0] m68k_sound_latch_1,

  input      [15:0] z80_sound_latch_0,
  input      [15:0] z80_sound_latch_1,
  input      [15:0] z80_sound_latch_2
);

wire p1_right    = joystick1[0];
wire p1_left     = joystick1[1];
wire p1_down     = joystick1[2];
wire p1_up       = joystick1[3];
wire p1_button1  = joystick1[4];
wire p1_button2  = joystick1[5];
wire p1_start    = start_button[0];

wire p2_right    = joystick2[0];
wire p2_left     = joystick2[1];
wire p2_down     = joystick2[2];
wire p2_up       = joystick2[3];
wire p2_button1  = joystick2[4];
wire p2_button2  = joystick2[5];
wire p2_start    = start_button[1];

///////// Motorola 68K CPU ///////////////////////////
//
// 
//
wire cpu_wr;                // Read = 1, Write = 0
wire cpu_as_n;              // Address strobe
wire cpu_lds_n;             // Lower byte strobe
wire cpu_uds_n;             // Upper byte strobe
(*keep*) wire [2:0]cpu_fc;  // Processor state

// CPU buses
reg  [15:0] cpu_din;
wire [15:0] cpu_dout;

wire [23:0] cpu_a;    
assign cpu_a[0] = 0;   // odd memory address should cause cpu exception

wire bg_n;             // Bus grant
wire br_n;
wire bgack_n;
wire cen10;
wire cen10b;
wire dtack_n;
wire int1;

fx68k fx68k (
    .clk(clk48),    // Input clock
    .enPhi1(cen10), // cpu clock 
    .enPhi2(cen10b), 

    .extReset(rst),
    .pwrUp(rst),
    .HALTn(dip_pause),

    //SYSTEM CONTROL 
    .BERRn(1'b1),
    .oRESETn(), 
    .oHALTEDn(), 

    //ADDRESS BUS 
    .eab(cpu_a[23:1]), //output A23-A0 : 24bits address bus

    //DATA BUS (originally one INOUT bus) 
    .iEdb(cpu_din),    // input D15-D0 : 16 bits cpu bus data in
    .oEdb(cpu_dout),   // input D15-D0 : 16 bits cpu bus data out 
    
    //ASYNCHRONOUS BUS CONTROL 
    .ASn(cpu_as_n),    // output : address strobe, tell the memory device that the address inputs are valid. Upon receiving this signal the selected memory device starts the memory access (read/write) indicated by its other inputs.
    .eRWn(cpu_wr),     // ouput  : write=0, read =1 
    .UDSn(cpu_uds_n),  // ouput  : upper byte strobe
    .LDSn(cpu_lds_n),  // output : lower byte strobe
    .DTACKn(dtack_n),  // input  : data transfer ack

    //BUS ARBITRATION CONTROL 
    .BRn(1'b1),        // input  : bus request
    .BGn(bg_n),        // output : bus grant 
    .BGACKn(1'b1),     // input  : Bus grant ack 

    // PERIPHERAL CONTROL 
    .E(),              // output : cpu enable 
    .VMAn(),           // output : valid pheripheral memory address
    .VPAn(inta_n),     // output :valid peripheral address detected  

    /// PROCESSOR STATUS 
    .FC0(cpu_fc[0]),   // output 
    .FC1(cpu_fc[1]),   // output 
    .FC2(cpu_fc[2]),   // output 

    //INTERUPT CONTROL 
    .IPL0n(int1),      //int @vblank
    .IPL1n(1'b1),
    .IPL2n(1'b1)  
);

///////// 68K interrupt ///////////////////////////
//
// interrupt at each vblank 
// 59.61hz,59.60hz verified on board
// interrupt routine fill char, bg1, bg1, palette ram
// during dip-switch char ram is zero filled @vblank
// ram drawing and filling is longer than vblank period 
//
wire inta_n;
assign inta_n = ~&{cpu_fc[2], cpu_fc[1], cpu_fc[0], ~cpu_as_n};

jtframe_virq u_virq(
    .rst        (rst),
    .clk        (clk48),
    .LVBL       (vblank),
    .dip_pause  (dip_pause), //handle cpu pause
    .skip_en    (),
    .skip_but   (),
    .clr        (~inta_n),
    .custom_in  (),
    .blin_n     (),
    .blout_n    (int1),
    .custom_n   ()
);


///////// 68K dtack //////////////////////////////
//
// handle 68k clock and data trasnfer acknowledge
// bus is busy if cpu rom is not available 
//

// cpu clock 48*5/24 => 10mhz 
localparam [3:0] cen_num =  4'd5;
localparam [4:0] cen_den = 5'd24;

wire bus_cs   = |{cpu_rom_cs};
wire bus_busy = |{cpu_rom_cs & ~cpu_rom_ok}; 

jtframe_68kdtack_cen  u_dtack(
    .rst        (rst),
    .clk        (clk48),
    .cpu_cen    (cen10),
    .cpu_cenb   (cen10b),
    .bus_cs     (bus_cs),
    .bus_busy   (bus_busy),
    .bus_legit  (1'b0),
    .ASn        (cpu_as_n),
    .DSn        ({cpu_uds_n, cpu_lds_n}), 
    .num        (cen_num),
    .den        (cen_den),
    .DTACKn     (dtack_n),
    .wait2      (1'b0),
    .wait3      (1'b0),
    // unused
    .fave       (),
    .fworst     ()
);

jtframe_68kdma #(.BW(1)) u_arbitration(
    .clk        (clk48),
    .cen        (cen10b),
    .rst        (rst),
    .cpu_BRn    (br_n),
    .cpu_BGACKn (bgack_n),
    .cpu_BGn    (bg_n),
    .cpu_ASn    (cpu_as_n),
    .cpu_DTACKn (dtack_n),
    .dev_br     (1'b1)
);

///////// 68k bus mapping  ////////////////////
//
// 0x000000, 0x05ffff : rom        (393216)(ro)
// 0x060000, 0x06d7ff : cpu ram     (55296)(rw)
// 0x06d800, 0x06dfff : spriteram    (2048)(rw) 
// 0x06e000, 0x06e7ff : palette      (2048)(rw)
// 0x06e800, 0x06efff : bg1 vram     (2048)(wo) 
// 0x06f000, 0x06f7ff : bg2 vram     (2048)(wo)
// 0x06f800, 0x06ffff : videoram     (2048)(wo)
// gap 
// 0x080000, 0x08000d : sound latch        (rw) 
// gap  
// 0x0a0000, 0x0a005f : scroll latch       (wo)
// gap 
// 0x0c0000, 0x0c0001 : dip-switch port    (ro) 
// 0x0c0002, 0x0c0003 : input port         (ro)
// 0x0c0004, 0x0c0005 : system port        (ro) 
//
reg ram_cs, sprite_cs, palette_cs, bg1_cs, bg2_cs, vram_cs,  
    scroll_cs, dsw_cs, inputs_cs, system_cs;
reg sound_cs_3, sound_cs_5;

always @(posedge clk or posedge rst) begin
  if (rst) begin
    ram_cs <= 1'd0;
    sprite_cs <= 1'd0;
    palette_cs <= 1'd0;
    bg1_cs <= 1'd0;
    bg2_cs <= 1'd0;
    vram_cs <= 1'd0;
    scroll_cs <= 1'd0;
    dsw_cs <= 1'd0;
    inputs_cs <= 1'd0;
    system_cs <= 1'd0;
    cpu_rom_addr <= 18'd0;
  end else begin
     if(!cpu_as_n) begin
      if (cpu_a[23:0] < 24'h60000)
        cpu_rom_addr[18:1] <= cpu_a[18:1];

      cpu_rom_cs <= (                        cpu_a[23:0] < 24'h60000);
      ram_cs <= (cpu_a[23:0] >= 24'h60000 && cpu_a[23:0] < 24'h6d800);
      //video 
      sprite_cs  <= (cpu_a[23:0] >= 24'h6d800 && cpu_a[23:0] < 24'h6e000); //2048
      palette_cs <= (cpu_a[23:0] >= 24'h6e000 && cpu_a[23:0] < 24'h6e800); //2048
      bg1_cs     <= (cpu_a[23:0] >= 24'h6e800 && cpu_a[23:0] < 24'h6f000); //2048
      bg2_cs     <= (cpu_a[23:0] >= 24'h6f000 && cpu_a[23:0] < 24'h6f800); //2048
      vram_cs    <= (cpu_a[23:0] >= 24'h6f800 && cpu_a[23:0] < 24'h70000); //2048
      //sound latch
      sound_cs_2 <= (cpu_a[23:0] == 24'h80004);
      sound_cs_3 <= (cpu_a[23:0] == 24'h80006);
      sound_cs_4 <= (cpu_a[23:0] == 24'h80008);
      sound_cs_5 <= (cpu_a[23:0] == 24'h8000a);
      sound_cs_6 <= (cpu_a[23:0] == 24'h8000c);
      //scroll 
      scroll_cs  <= (cpu_a[23:0] >= 24'ha0000 && cpu_a[23:0] < 24'ha005f); //96 
      //IO
      dsw_cs     <= (cpu_a[23:0] >= 24'hc0000 && cpu_a[23:0] < 24'hc0001); //2 
      inputs_cs  <= (cpu_a[23:0] >= 24'hc0002 && cpu_a[23:0] < 24'hc0003); //2 
      system_cs  <= (cpu_a[23:0] >= 24'hc0004 && cpu_a[23:0] < 24'hc0005); //2 
    end else begin
      ram_cs <= 1'd0;
      sprite_cs <= 1'd0;
      palette_cs <= 1'd0;
      bg1_cs <= 1'd0;
      bg2_cs <= 1'd0;
      vram_cs <= 1'd0;
      scroll_cs <= 1'd0;
      dsw_cs <= 1'd0;
      inputs_cs <= 1'd0;
      system_cs <= 1'd0;
      cpu_rom_addr <= 18'd0;
    end
  end
end


////// 68K databus input   /////////////////////// 
//
always @(posedge clk, posedge rst) begin
  if(rst) begin 
    cpu_din <= 16'h0000;
    end
  else begin
    if (clk) begin
      cpu_din <= cpu_rom_cs ? cpu_rom_data[15:0] :  
                 ram_cs     ? ram_do[15:0] :
                 palette_cs ? palette_do[15:0] :
                 sprite_cs  ? sprite_do[15:0] : 
                 vram_cs    ? vram_do[15:0] : 
                 dsw_cs     ? dipsw[15:0] : 
                 inputs_cs  ? {1'b1,1'b1,p2_button2,p2_button1,p2_right,p2_left,p2_down,p2_up,
                               1'b1,1'b1,p1_button2,p1_button1,p1_right,p1_left,p1_down,p1_up} :
                 system_cs  ? {1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,
                               1'b1,1'b1,1'b1,p2_start,p1_start,1'b1,1'b1,1'b1} : 
                 sound_cs_2 ? z80_sound_latch_0 : 
                 sound_cs_3 ? z80_sound_latch_1 :
                 sound_cs_5 ? z80_sound_latch_2 :
                 16'd0;
      end
    end
end


//////// Scroll /////////////////////////
//
// Scrolling register latch
//
reg [15:0] bg1_scroll_x_lo = 0;
reg [15:0] bg2_scroll_x_lo = 0;
reg [15:0] bg1_scroll_y_lo = 0;
reg [15:0] bg2_scroll_y_lo = 0;

always @(posedge clk, posedge rst) begin
  if (rst) begin
      bg_order <= 1'b0;
      bg1_scroll_x <= 9'b0;
      bg1_scroll_y <= 9'b0;
      bg2_scroll_x <= 9'b0;
      bg2_scroll_y <= 9'b0;
      end
  else if (clk) begin
    if (scroll_cs == 'b1) begin
      if (cpu_a[6:1] == 'h6)
        bg1_scroll_x_lo[15:0] <= cpu_dout[15:0];
      else if (cpu_a[6:1] == 'h5)
        bg1_scroll_x[8:0] <= { cpu_dout[4], bg1_scroll_x_lo[6:0], bg1_scroll_x_lo[7] };
      else if (cpu_a[6:1] == 'he)
        bg1_scroll_y_lo[15:0] <= cpu_dout[15:0];
      else if (cpu_a[6:1] == 'hd) 
        bg1_scroll_y[8:0] <= { cpu_dout[4], bg1_scroll_y_lo[6:0], bg1_scroll_y_lo[7] };
      else if (cpu_a[6:1] == 'h16) 
        bg2_scroll_x_lo[15:0] <= cpu_dout[15:0];
      else if (cpu_a[6:1] == 'h15) 
        bg2_scroll_x[8:0] <= { cpu_dout[4], bg2_scroll_x_lo[6:0], bg2_scroll_x_lo[7] };
      else if (cpu_a[6:1] == 'h1e)
        bg2_scroll_y_lo[15:0] <= cpu_dout[15:0];
      else if (cpu_a[6:1] == 'h1d)
         bg2_scroll_y[8:0] <= { cpu_dout[4], bg2_scroll_y_lo[6:0], bg2_scroll_y_lo[7] };
      else if (cpu_a[6:1] == 'h28) begin
        if ((cpu_dout[15:0] & 16'h100) == 16'h0)
          bg_order <= 1'b0;
        else
          bg_order <= 1'b1;
        end
    end
  end
end

///////// Sound ///////////////
//
// Sound register latch
//
always @(posedge clk, posedge rst) begin
  if (rst) begin
    m68k_sound_latch_0 <= 16'b0;
    m68k_sound_latch_1 <= 16'b0;
    end
  else begin
    if (cpu_a[23:0] == 24'h80000)
      m68k_sound_latch_0[15:0] <= cpu_dout[15:0];
    if (cpu_a[23:0] == 24'h80002)
      m68k_sound_latch_1[15:0] <= cpu_dout[15:0];
  end
end

//////// RAM //////////////////////////
//
// 68k cpu ram (64k)
// 2x Sony58257 - 32kx8 SRAM on PCB
//
wire [15:0] ram_do;

jtframe_ram16 #(.AW(15)) u_cpu_ram(
    .clk(clk),
    .data(cpu_dout[15:0]), 
    .addr(cpu_a[15:1]), 
    .we({ram_cs && !cpu_wr && !cpu_uds_n, ram_cs && !cpu_wr && !cpu_lds_n}),
    .q(ram_do[15:0])
);

///////// PALETTE RAM //////////
//
// palette ram (2048)
// palette is read and checked by main cpu 
//
wire [15:0]  palette_do;

dual_ram_buffer16 #(.W(10)) u_palette_ram(
  .clk(clk),
  .trigger(vblank),
  .we({palette_cs && !cpu_wr && !cpu_uds_n, palette_cs && !cpu_wr && !cpu_lds_n}),
  .addr_in(cpu_a[10:1]), 
  .data(cpu_dout[15:0]),
  .q_in(palette_do),

  .addr_out(palette_addr[10:1]),
  .q(palette_out)
); 

///////// VIDEO RAM //////////
//
// video ram (2048)
// we use special ram that copy content @vblank
// because during dipswitch (only) vram is reset at each frame
// that make cpu write to vram longer than a vblank period
//
wire [15:0] vram_do;

dual_ram_buffer16 #(.W(10)) u_vram_ram(
  .clk(clk),
  .trigger(vblank),
  .we({vram_cs && !cpu_wr && !cpu_uds_n , vram_cs && !cpu_wr && !cpu_lds_n }),
  .addr_in(cpu_a[10:1]), 
  .data(cpu_dout[15:0]),
  .q_in(vram_do),

  .addr_out(vram_addr[10:1]),
  .q(vram_out[15:0])
); 

///////// BG1 RAM //////////
//
// background 1 (2048)
//
dual_ram_buffer16 #(.W(10)) u_bg1_ram(
  .clk(clk),
  .trigger(vblank),
  .we({bg1_cs && !cpu_wr && !cpu_uds_n, bg1_cs && !cpu_wr && !cpu_lds_n}),
  .addr_in(cpu_a[10:1]), 
  .data(cpu_dout[15:0]),
  .q_in(),

  .addr_out(bg1_addr[10:1]),
  .q(bg1_out)
); 

///////// BG2 RAM //////////
//
// background 2 (2048)
//
dual_ram_buffer16 #(.W(10)) u_bg2_ram(
  .clk(clk),
  .trigger(vblank),
  .we({bg2_cs && !cpu_wr && !cpu_uds_n, bg2_cs && !cpu_wr && !cpu_lds_n}),
  .addr_in(cpu_a[10:1]), 
  .data(cpu_dout[15:0]),
  .q_in(),

  .addr_out(bg2_addr[10:1]),
  .q(bg2_out)
); 

///////// SPRITE RAM //////////
//
// sprite ram (2048)
// sprite ram is read by the cpu 
// if cpu can't read sprite ram content 
// there will be no scrolling during the 'cave screen'
//
wire [15:0] sprite_do;

dual_ram_buffer16 #(.W(10)) u_sprite_ram(
  .clk(clk),
  .trigger(vblank),
  .we({sprite_cs && !cpu_wr && !cpu_uds_n, sprite_cs && !cpu_wr && !cpu_lds_n}),
  .addr_in(cpu_a[10:1]), 
  .data(cpu_dout[15:0]),
  .q_in(sprite_do),

  .addr_out(sprite_addr[10:1]),
  .q(sprite_out)
);

endmodule
