/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 02-06-2020 */

module jtbubl_sound(
    input             rst,    // System reset
    input             rstn,   // from Main
    input             clk,
    input             cen3,   //  3   MHz

    input             tokio,
    // Interface with main CPU
    input      [ 7:0] snd_latch,
    input             snd_stb,
    output reg [ 7:0] main_latch,
    output reg        main_stb,
    output            snd_flag,
    input             main_flag,
    // ROM
    output     [14:0] rom_addr,
    output reg        rom_cs,
    input      [ 7:0] rom_data,
    input             rom_ok,

    // Sound output
    output signed [15:0] fm03, fm26,
    output reg    [ 9:0] psg,
    input         [ 7:0] debug_bus
);

`ifndef NOSOUND

wire        [15:0] A;
wire               iorq_n, m1_n, wr_n, rd_n;
wire        [ 7:0] ram_dout, dout, fm0_dout, fm1_dout;
reg                ram_cs, fm1_cs, fm0_cs, io_cs, nmi_en, macc_n;
wire               mreq_n, rfsh_n, nmi_n;
reg         [ 7:0] din;
wire        [ 9:0] pre_psg;
wire               intn_fm0, intn_fm1;
wire               int_n;
wire               flag_clr;
wire               snd_rstn = ~rst & rstn;

assign int_n      = intn_fm0 & intn_fm1;
assign rom_addr   = A[14:0];
assign nmi_n      = snd_flag | ~nmi_en;
assign flag_clr   = (io_cs && !rd_n && A[1:0]==2'b0) || ~snd_rstn;

always @(posedge clk) psg <= tokio ? pre_psg>>2 : pre_psg;


always @(*) begin
    macc_n =  mreq_n | ~rfsh_n;
    rom_cs = !macc_n && !A[15];
    ram_cs = !macc_n &&  A[15] && A[14:12]==3'b00;
    if( tokio ) begin
        fm0_cs = !macc_n && A[15:12]==4'b1011; // YM2203
        fm1_cs = 0;
        io_cs  = !macc_n && (A[15:12]==4'b1001 || A[15:12]==4'b1010);
    end else begin
        fm0_cs = !macc_n && A[15] && A[14:12]==3'b01; // YM2203
        fm1_cs = !macc_n && A[15] && A[14:12]==3'b10; // OPL
        io_cs  = !macc_n && A[15] && A[14:12]==3'b11;
    end
end

always @(posedge clk) begin
    case( 1'b1 )
        rom_cs:   din <= rom_data;
        fm0_cs:   din <= fm0_dout;
        fm1_cs:   din <= fm1_dout;
        io_cs:    din <= tokio ? (
                         !A[12] ? 8'hff :
                         ( A[11] ? {6'h3f, main_stb, snd_flag} : snd_latch )
                         ) : ( // Bubble Bobble:
                         A[1] ? 8'hff : (
                         A[0] ? {6'h3f, main_stb, snd_flag} : snd_latch));
        ram_cs:   din <= ram_dout;
        default:  din <= 8'hff;
    endcase
end

always @(posedge clk, negedge snd_rstn) begin
    if( !snd_rstn ) begin
        main_latch <= 8'h00;
        main_stb   <= 0;
        nmi_en     <= 0;
    end else begin
        if( io_cs && !wr_n ) begin
            if( tokio ) begin
                if( !A[12] ) begin // NMI control
                    if(!A[11]) nmi_en <= 0;
                    if( A[11]) nmi_en <= 1;
                end else begin
                    if(!A[11]) main_latch <= dout;
                    if( A[11]) main_stb   <= 1;
                end
            end else begin
                case( A[1:0] )
                    2'd0: begin
                        main_latch <= dout;
                        main_stb   <= 1;
                    end
                    2'd1: nmi_en     <= 1; // enables NMI
                    2'd2: nmi_en     <= 0;
                    default:;
                endcase
            end
        end else begin
            main_stb <= 0;
        end
    end
end

jtframe_ff u_flag(
    .clk    ( clk      ),
    .rst    ( rst      ),
    .cen    ( 1'b1     ),
    .din    ( 1'b1     ),
    .q      (          ),
    .qn     ( snd_flag ),
    .set    ( 1'b0     ),
    .clr    ( flag_clr ),
    .sigedge( snd_stb  )
);

jtframe_sysz80 #(.RAM_AW(13),.RECOVERY(0)) u_cpu(
    .rst_n      ( snd_rstn    ),
    .clk        ( clk         ),
    .cen        ( cen3        ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ),
    .nmi_n      ( nmi_n       ),
    .busrq_n    ( 1'b1        ),
    .m1_n       (             ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     (             ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .cpu_din    ( din         ),
    .cpu_dout   ( dout        ),
    .ram_dout   ( ram_dout    ),
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( 1'b1        )   // SDRAM gating managed in mem.yaml
);

jt03 #(.YM2203_LUMPED(1)) u_2203(
    .rst        ( ~snd_rstn  ),
    .clk        ( clk        ),
    .cen        ( cen3       ),
    .din        ( dout       ),
    .dout       ( fm0_dout   ),
    .addr       ( A[0]       ),
    .cs_n       ( ~fm0_cs    ),
    .wr_n       ( wr_n       ),
    .psg_snd    ( pre_psg    ),
    .fm_snd     ( fm03       ),
    .snd_sample (            ),
    .irq_n      ( intn_fm0   ),
    // unused outputs
    .IOA_oe     (            ),
    .IOB_oe     (            ),
    .IOA_in     ( 8'd0       ),
    .IOB_in     ( 8'd0       ),
    .IOA_out    (            ),
    .IOB_out    (            ),
    .psg_A      (            ),
    .psg_B      (            ),
    .psg_C      (            ),
    .snd        (            ),
    .debug_view (            )
);

jtopl u_opl(
    .rst        ( ~snd_rstn  ),
    .clk        ( clk        ),
    .cen        ( cen3       ),
    .din        ( dout       ),
    .dout       ( fm1_dout   ),
    .addr       ( A[0]       ),
    .cs_n       ( ~fm1_cs    ),
    .wr_n       ( wr_n       ),
    .irq_n      ( intn_fm1   ),
    .snd        ( fm26       ),
    .sample     (            )
);

`else
assign snd_flag = 1'b0;
assign rom_addr = 15'd0;
assign fm03     = 16'sd0;
assign fm26     = 16'sd0;

initial begin
    main_latch = 8'd0;
    main_stb   = 1'b0;
    rom_cs     = 1'b0;
    psg        = 10'd0;
end
`endif

endmodule
