/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 3-10-2026 */

module jt88game_main(
    input             rst, clk, cen24,
    output            cpu_cen,
    output     [15:0] cpu_addr,
    output     [ 7:0] cpu_dout,
    output            cpu_we,

    output     [16:0] rom_addr,
    output reg        rom_cs,
    input      [ 7:0] rom_data,
    input             rom_ok,
    output            ram_we,
    input      [ 7:0] ram_dout,
    output            nvram_we,
    input      [ 7:0] nvram_dout,

    input      [ 3:0] cab_1p,
    input      [ 3:0] coin,
    input      [ 6:0] joystick1, joystick2, joystick3, joystick4,
    input             service,
    input      [23:0] dipsw,
    input             dip_pause,

    input             rst8, irq_n,
    input      [ 7:0] tilesys_dout, objsys_dout, pal_dout,
    input      [ 7:0] psac_dout, psac_rom_data,
    input             tilesys_rom_dtack, psac_ok,
    output reg        tilesys_cs, objsys_cs,
    output            pal_we,
    output reg        psac_vr_cs, psac_io_cs,
    output reg        rmrd, prio, rot_readroms,
    output reg        snd_irq,
    output reg [ 7:0] snd_latch,
    output     [ 7:0] st_dout
);
`ifndef NOMAIN

wire [ 7:0] aupper;
wire [15:0] pcbad;
wire        buserror;
reg         banked_cs, fixed_cs, pal_cs, work_cs, nvram_cs, second_cs;
reg         io_cs, rotreg_cs;
wire        dtack;
reg  [ 7:0] cpu_din, cab_dout;
reg         rst_cmb, buserror_l;

// U61 (052606) fuse equations, with the schematic pin assignments. NAS is
// asserted during a Konami CPU bus cycle. U61 pin 11 only qualifies palette
// and zoom selects; neither window overlaps another selected device here.
// U63 (052607): 4000-7fff tile RAM and a small set of subordinate windows.
// The object select is clocked by U92 on the PCB. It is kept combinational
// here, as in the existing 051960 core interface, until the timing is checked
// against a running scene.
always @* begin
    fixed_cs   = cpu_addr[15];                     // ROM1CS, U61 pin 12
    banked_cs  = cpu_addr[15:12]==4'h0 ||
                 cpu_addr[15:12]==4'h1 && !aupper[3]; // ROM2CS, pin 13
    pal_cs     = cpu_addr[15:12]==4'h1 && aupper[3]; // COLORCS, pin 14
    work_cs    = cpu_addr[15:12]==4'h2 ||
                 cpu_addr[15:11]==5'b00110 ||
                 cpu_addr[15:11]==5'b00111 && aupper[4]; // WORKCS, pin 15
    nvram_cs   = cpu_addr[15:11]==5'b00110;
    psac_vr_cs = cpu_addr[15:11]==5'b00111 && !aupper[4];
    second_cs  = cpu_addr[15:14]==2'b01;          // U61 pin 18 to U63 pin 1

    io_cs      = second_cs && cpu_addr[13:6]==8'h7e; // 5f80-5fbf
    rotreg_cs  = second_cs && cpu_addr[13:6]==8'h7f; // 5fc0-5fff
    objsys_cs  = second_cs && (cpu_we || !rmrd) &&
                 (cpu_addr[13:10]==4'hf || cpu_addr[13:3]==11'h700);
    tilesys_cs = second_cs && !io_cs && !rotreg_cs && !objsys_cs;
    psac_io_cs = rotreg_cs && cpu_addr[5:4]==2'b00;
    rom_cs     = !cpu_we && !rst_cmb && (fixed_cs || banked_cs);
end

assign ram_we      = work_cs && !nvram_cs && cpu_we;
assign nvram_we    = nvram_cs && cpu_we;
assign pal_we      = pal_cs && cpu_we;
assign rom_addr    = fixed_cs ? {1'b0,cpu_addr} :
                     {1'b1,aupper[2:0],cpu_addr[12:0]};
assign dtack       = (!rom_cs || rom_ok) &&
                     (!tilesys_cs || tilesys_rom_dtack) &&
                     (!psac_vr_cs || psac_ok);
assign st_dout     = {prio,rmrd,aupper[4:3],buserror_l,
                      cpu_addr[15:13]};

always @(posedge clk) begin
    case (cpu_addr[5:0])
        6'h14: cab_dout <= {dipsw[23:20],1'b1,service,coin[1:0]};
        6'h15: cab_dout <= {cab_1p[1],joystick2[6:4],
                            cab_1p[0],joystick1[6:4]};
        6'h16: cab_dout <= {cab_1p[3],joystick4[6:4],
                            cab_1p[2],joystick3[6:4]};
        6'h17: cab_dout <= dipsw[7:0];
        6'h1b: cab_dout <= dipsw[15:8];
        default: cab_dout <= 8'hff;
    endcase
end

always @* begin
    cpu_din = rom_cs      ? rom_data       :
              pal_cs      ? pal_dout       :
              nvram_cs    ? nvram_dout     :
              work_cs     ? ram_dout       :
              io_cs       ? cab_dout       :
              psac_vr_cs  ? (rot_readroms ? psac_rom_data : psac_dout) :
              tilesys_cs  ? tilesys_dout  :
              objsys_cs   ? objsys_dout   : 8'hff;
end

always @(posedge clk) begin
    rst_cmb <= rst | rst8;
    if (rst) begin
        snd_latch   <= 0;
        snd_irq     <= 0;
        rot_readroms<= 0;
        buserror_l  <= 0;
    end else begin
        if (cpu_cen) snd_irq <= 0;
        if (buserror) buserror_l <= 1;
        if (io_cs && cpu_we) case (cpu_addr[5:0])
            6'h04: rot_readroms <= cpu_dout[2];
            6'h0c: snd_latch <= cpu_dout;
            6'h10: snd_irq <= 1;
            default:;
        endcase
    end
end

always @(posedge clk) begin
    if (rst) begin
        prio <= 0;
        rmrd <= 0;
    end else begin
        prio <= aupper[7];
        rmrd <= aupper[5];
    end
end

jtkcpu u_cpu(
    .rst      ( rst_cmb            ),
    .clk      ( clk                ),
    .cen2     ( cen24              ),
    .cen_out  ( cpu_cen            ),
    .halt     ( buserror_l         ),
    .dtack    ( dtack              ),
    .nmi_n    ( 1'b1               ),
    .irq_n    ( irq_n | ~dip_pause ),
    .firq_n   ( 1'b1               ),
    .pcbad    ( pcbad              ),
    .buserror ( buserror           ),
    .din      ( cpu_din            ),
    .dout     ( cpu_dout           ),
    .addr     ( {aupper,cpu_addr}  ),
    .we       ( cpu_we             )
);
`else
assign {cpu_cen,cpu_addr,cpu_dout,cpu_we,rom_addr,rom_cs,ram_we,nvram_we,
        tilesys_cs,objsys_cs,pal_we,psac_vr_cs,psac_io_cs,st_dout}=0;
`ifdef SIMSCENE
reg [7:0] scene_prio[0:0];
integer scene_fd, scene_count;
`endif
initial begin
    rmrd=0; prio=0; rot_readroms=0; snd_irq=0; snd_latch=0;
`ifdef SIMSCENE
    scene_fd=$fopen("prio.bin","rb");
    if (scene_fd!=0) begin
        scene_count=$fread(scene_prio,scene_fd);
        $fclose(scene_fd);
        if (scene_count==1) prio=scene_prio[0][0];
    end
`endif
end
`endif
endmodule
