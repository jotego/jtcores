////////// seibu sound system  /////////////////////////////
//
// seibu sound system is composed of :
// - Z80 @3.579545 MHz
// - YM3812 OPL2 @3.579545 MHz
// - MSM6295 @1Mhz 
// - YM3931 (not implemented)
//
// z80 communicate with the main 68k cpu :
//   - recv  command for the MSM6295
//   - recv  data for the YM3812
//   - send  ack of cmd/data
//
// /-----------\         /-------\
// | z80  rom  |         |68k    |
// | encrypted |         |       |      
// | 8.m3 8192 |         |       |
// |           |         \-------/
// |           |             |
// \-----------/        /---------\     /--------\
//      |               |  latch  |     |ROM 9.m1|
//      |               |         |     |131072  |
//      |               \---------/     \--------/
//      |                    |              |
// /---------\           /------\        /-------\ 
// |         |           |      |------- |MSM6295|--->/-------\
// | sei80bu | z80 rom   | z80  |        \-------/    | sound |
// |         |---------->|      |        /------\     | mixer |--> sound out
// |         |           |      |--------|YM3812|---->|       |
// |         |           \------/        \------/     \-------/
// \---------/               |
//                           |
//                    /----------------\
//                    | 7.m7 65536     |
//                    | z80 bank       |
//                    | encrypted      |
//                    \----------------/
//
module toki_sound(
  input             rst,
  input             clk,
  input             clk48,

  input             oki_cen,

  input       [1:0] coin_input,

  output     [15:0] snd,
  input       [1:0] fxlevel,
  input             enable_fm,
  input             enable_psg,

  input       [7:0] z80_rom_data,
  input             z80_rom_ok, 
  output reg [12:0] z80_rom_addr,
  output            z80_rom_cs,

  input       [7:0] bank_rom_data,
  input             bank_rom_ok, 
  output reg [15:0] bank_rom_addr,
  output            bank_rom_cs,

  // OKI 6295 ADPCM 
  input       [7:0] pcm_rom_data,
  input             pcm_rom_ok, 
  output     [16:0] pcm_rom_addr,
  output            pcm_rom_cs,

  input             m68k_sound_cs_2,
  input             m68k_sound_cs_4,
  input             m68k_sound_cs_6,

  //SEIBU SOUND DEVICE MAIN READ
  input      [15:0] m68k_sound_latch_0,
  input      [15:0] m68k_sound_latch_1,

  //SEIBU SOUND DEVICE MAIN WRITE
  output reg   [15:0] z80_sound_latch_0,
  output reg   [15:0] z80_sound_latch_1,
  output reg   [15:0] z80_sound_latch_2
);

/////// Z80 address bus ///////////////////////////////////
//
wire z80_ram_cs, ym_cs_0, ym_cs_1, 
     m68k_latch0_cs, m68k_latch1_cs, main_data_pending_cs, 
     read_coin_cs, ym_wr, z80_wr_n, 
     oki_wr, oki_rd;

wire [7:0]  ym3812_dout;
wire [15:0] z80_addr;
wire [7:0]  z80_dout;
wire        z80_rd_n;

z80_cs u_z80cs(
  .z80_addr(z80_addr),
  .z80_wr_n(z80_wr_n),
  .z80_rd_n(z80_rd_n),
  .z80_rom_cs(z80_rom_cs),
  .bank_rom_cs(bank_rom_cs),
  .z80_ram_cs(z80_ram_cs),

  .ym_cs_0(ym_cs_0),
  .ym_cs_1(ym_cs_1),

  .m68k_latch0_cs(m68k_latch0_cs),
  .m68k_latch1_cs(m68k_latch1_cs),

  .main_data_pending_cs(main_data_pending_cs),
  .read_coin_cs(read_coin_cs),

  .ym_wr(ym_wr),
  .oki_wr(oki_wr),
  .oki_rd(oki_rd)
);

///////// SEIBU80 //////////
//
// Decypher z80 ROM 8.m3
//
wire [7:0] decrypt_rom_data;
wire       decrypt_rom_ok;
reg        decrypt_rom_cs_seibu;

wire       z80_m1_n;   //m1 low => opcode
wire       z80_mreq_n;
wire       z80_wait_n;

sei80bu u_sei80bu(
  .clk(clk48),
  .z80_rom_addr({3'd0, z80_rom_addr}),
  .z80_rom_data(z80_rom_data),
  .z80_rom_ok(z80_rom_ok), 
  .z80_rom_cs(z80_rom_cs),
  .z80_m1(~z80_m1_n),
  .decrypt_rom_data(decrypt_rom_data),
  .decrypt_rom_ok(decrypt_rom_ok)
);

///////// Z80 CLOCK /////////////////////////////
//
// Generate 3.579545 MHz clock
//
wire cen_fm, cen_fm2;

jtframe_cen3p57 u_fmcen(
    .clk(clk48),      // 48 MHz
    .cen_3p57(cen_fm),
    .cen_1p78(cen_fm2)
);

///////// Z80 WAIT ///////////////////////
// 
// make z80 bus wait if rom or banked rom
// is selected and not available  
// 
reg  wait_n;

always @(posedge clk, posedge rst) begin
  if (rst)
    wait_n <= 1'b1;
  else begin
    if (z80_rom_cs & ~z80_rom_ok)
      wait_n <= 1'b0;
    else if (bank_rom_cs & ~bank_rom_ok)
      wait_n <= 1'b0;
    else 
      wait_n <= 1'b1;
  end 
end

////// Z80 ROM & bank switch /////////////////////
//
//
reg bank_selected = 1'b0; // switch to data bank

always @(posedge clk) begin
    // ROM & bank handling
    if (z80_addr[15:0] < 16'h2000)
      z80_rom_addr[12:0] <= z80_addr[12:0];
    // bank size is 0x10000 
    // z80 address from 0x8000  to 0x10000 is read directly from the rom 
    // z80 address from 0x10000 to 0x18000 is read after switching bank
    if (z80_addr[15:0] == 16'h4007) // switch bank usage 
      bank_selected <= z80_dout[0];
    if (z80_addr[15:0] >= 16'h8000 && bank_selected == 1'b0)
      bank_rom_addr[15:0] <= (z80_addr[15:0] - 16'h8000); //0x2000 first bytes
    else if (z80_addr[15:0] >= 16'h8000 && bank_selected == 1'b1)
      bank_rom_addr[15:0] <= z80_addr[15:0];
end

///////// Z80 CPU  /////////////////////// 
// 
//
//
reg  [7:0] z80_din;
wire z80_iorq_n;
wire z80_cen;
wire z80_busak_n;
wire ym3812_irq_n; 

jtframe_z80 u_z80(
    .rst_n(~rst),
    .clk(clk48),
    .cen(cen_fm),

    .wait_n(wait_n),
    .int_n(~(irq_rst10|irq_rst18)), // sound interrupt
    .nmi_n(1'b1),
    .busrq_n(1'b1),

    .m1_n(z80_m1_n),
    .mreq_n(z80_mreq_n),
    .iorq_n(z80_iorq_n),
    .rd_n(z80_rd_n), 
    .wr_n(z80_wr_n),
    .rfsh_n(),
    .halt_n(), 
    .busak_n(),

    .A(z80_addr[15:0]),

    .din(z80_din),
    .dout(z80_dout) 
);

////// SOUND ////////////////////
//
// sound latch
//
reg oki6295_irq_n;
reg sub2main_pending;

always @(posedge clk, posedge rst) begin //XXX speed must be same than 68k din ?
  if (rst) begin
    z80_sound_latch_0 <= 16'b0;
    z80_sound_latch_1 <= 16'b0;
    sub2main_pending  <= 1'b0;
    oki6295_irq_n     <= 1'b1;
    end
  else begin
    // send z80 data to 68k cpu
    if (z80_addr[15:0] == 16'h4018) 
      z80_sound_latch_0 <= {8'b0, z80_dout[7:0]};
    if (z80_addr[15:0] == 16'h4019)
      z80_sound_latch_1 <= {8'b0, z80_dout[7:0]};

    // data from z80 is pending read from 68k
    if (z80_addr[15:0] == 16'h4000) begin
      z80_sound_latch_2 <= 16'b0;
      sub2main_pending <= 1'b1;
      end
    else if (m68k_sound_cs_6 == 1'b1 || m68k_sound_cs_2 == 1'b1) begin
      z80_sound_latch_2 <= 16'b1;
      sub2main_pending <= 1'b0;
      end

    // main cpu assert irq for oki6295
    if (m68k_sound_cs_4 == 1'b1) 
      oki6295_irq_n <= 1'b0; 
    else
      oki6295_irq_n <= 1'b1;
    end
end

////// Z80 databus input   /////////////////////// 
//
//  IRQ use z80 interrupt mode 0 :
//  After interrupt is asserted, the cpu signal it's 
//  ready by putting iorq and m1 high 
//  it then read on the databus 
//  this data is directly executed by the cpu as an opcode 
//
//  - ym3821 assert irq and put 0xd7 (rst10) on the bus 
//  - 68k main cpu assert irq and put 0xdf (rst18) on the bus 
// 
//  both interrupt are needed to handle sound and coin input
//
reg irq_rst10;
reg irq_rst18;
reg stop_irq_10; 
reg stop_irq_18; 
wire irq_ack;
assign irq_ack = ~z80_iorq_n & ~z80_m1_n;

always @(posedge clk, posedge rst) begin
  if (rst) begin
    z80_din     <= 8'hff;
    irq_rst10 <= 1'b0;
    irq_rst18 <= 1'b0;
    stop_irq_10 <= 1'b0;
    stop_irq_18 <= 1'b0;
    end
  else begin
    if (clk) begin
      if (~irq_ack & stop_irq_10) begin
        irq_rst10 <= 1'b0;
        stop_irq_10 <= 1'b0;
        end
      else if (~irq_ack & stop_irq_18) begin
        stop_irq_18 <= 1'b0;
        irq_rst18 <= 1'b0;
        end
      else if (ym3812_irq_n == 1'b0)
        irq_rst10 <= 1'b1;
      else if (oki6295_irq_n == 1'b0) //~m68k_sound_cs_4
        irq_rst18 <= 1'b1;
          
      if (irq_ack & irq_rst10)
        stop_irq_10 <= 1'b1;
      else if (irq_ack & irq_rst18)
        stop_irq_18 <= 1'b1;

      z80_din <= irq_ack & irq_rst10                      ? 8'hd7 : 
                 irq_ack & irq_rst18                      ? 8'hdf :
                 main_data_pending_cs &  sub2main_pending ? 8'b1  :
                 main_data_pending_cs & ~sub2main_pending ? 8'b0 :
                 ym_cs_0 & ~z80_rd_n                      ? ym3812_dout :
                 oki_rd                                   ? oki_dout :
                 bank_rom_cs                              ? bank_rom_data :
                 m68k_latch0_cs                           ? m68k_sound_latch_0[7:0] :
                 m68k_latch1_cs                           ? m68k_sound_latch_1[7:0] :
                 read_coin_cs                             ? {6'b0, ~coin_input[1], ~coin_input[0]} :
                 z80_ram_cs                               ? z80_ram_dout :
                 z80_rom_cs                               ? decrypt_rom_data :
                                                            8'hff;
    end 
  end
end

////// Z80 RAM  ///////////////////////
//
//  8bits ram  (2048)
//
wire [7:0] z80_ram_dout;

jtframe_ram #(.AW(11)) u_z80_cpu_ram(
    .clk(clk),
    .cen(1'b1),
    .data(z80_dout[7:0]),
    .addr(z80_addr[10:0]), 
    .we(z80_ram_cs & ~z80_wr_n), //& ~z80_mreq_n ?
    .q(z80_ram_dout[7:0])
);

///////// OKIM6295   /////////////////////// 
//
// ADPCM sound effects 
//
wire [7:0] oki_dout;
wire       oki_sample;
wire signed [13:0] oki_snd;
wire [17:0] adpcm_rom_addr;

assign pcm_rom_cs = 1'b1;

// pcm rom byte 13 and 15 are swapped, that could be a simple encryption 
assign pcm_rom_addr = { adpcm_rom_addr[16], adpcm_rom_addr[13], adpcm_rom_addr[14] ,adpcm_rom_addr[15] , adpcm_rom_addr[12:0]}; 

jt6295 #(.INTERPOL(1))  u_adpcm(
    .rst(rst),
    .clk(clk48),
    .cen(oki_cen),
    .ss(1'b1), // pin7 high, select low sample rate
     //CPU interface
    .wrn(~oki_wr),   // wr selected
    .din(z80_dout),  // input data from z80 
    .dout(oki_dout), // output data to z80
     //ROM interface
    .rom_addr(adpcm_rom_addr), // output 18 memory address to read
    .rom_data(pcm_rom_data),   // input  data read
    .rom_ok(pcm_rom_ok),       // high when rom_data is valid and matches rom_addr
     //Sound output
    .sound(oki_snd[13:0]), // sound output 
    .sample(oki_sample)    // sample rate  
);

////////// YM3812 /////////////////////////////////// 
//
// MUSIC
//
reg ym3812_addr;
wire signed [15:0] opl_snd;
wire opl_sample;

jtopl2   u_YM3812(
    .rst(rst),
    .clk(clk48),
    .cen(cen_fm),
    .din(z80_dout),
    .addr(ym_cs_1), // cmd addr 
    .cs_n(~(ym_cs_0 | ym_cs_1)),
    .wr_n(~ym_wr), 
    .dout(ym3812_dout),
    .irq_n(ym3812_irq_n),
    .snd(opl_snd[15:0]),
    .sample(opl_sample)
);

///////// MIXING /////////////////
//
// MIX YM3812 & OKI6295 
//
//
//1: pcmgain <= 8'h20 ;   // 200%
//0: pcmgain <= 8'h10 ;   // 100%
//2: pcmgain <= 8'h0c ;   // 75%
//3: pcmgain <= 8'h08 ;   // 50%
//
reg [7:0] fx_volume;
reg [7:0] fm_volume;

always @(posedge clk48)  begin //posedge clk ?
  if (clk48) begin
   fm_volume <=  ~enable_fm ? 8'h00 : 8'h10; 
   fx_volume <=  ~enable_psg ? 8'h00 : 
                        (fxlevel == 2'h0) ? 8'h08 : 
                        (fxlevel == 2'h1) ? 8'h0c : 
                        (fxlevel == 2'h2) ? 8'h10 : 
                                            8'h20; 
   end
end

jtframe_mixer #(.W1(14)) u_mixer(
    .rst(rst),
    .clk(clk48),
    .cen(1'b1),
    // input signals
    .ch0(opl_snd[15:0]), // fm 
    .ch1(oki_snd[13:0]), // fx
    .ch2(16'd0),
    .ch3(16'd0),
    //
    .gain0(fm_volume),
    .gain1(fx_volume),
    .gain2(8'd0),
    .gain3(8'd0),
    .mixed(snd),
    .peak()
);

endmodule
