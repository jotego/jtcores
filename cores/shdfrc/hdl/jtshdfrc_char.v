/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-11-2026 */

module jtshdfrc_char(
    input                rst,
    input                clk,
    input                line_start,
    input         [ 8:0] rline,
    input         [ 9:0] lb_ra,

    output reg    [12:1] fg_rd_addr,
    input         [15:0] fg_rd_data,

    output        [16:0] fgrom_addr,
    output reg           fgrom_cs,
    input                fgrom_ok,
    input         [ 7:0] fgrom_data,

    output        [ 7:0] lfg,
    output               busy
);

wire        rbank = rline[0];
reg  [ 9:0] fg_wa;
reg  [ 7:0] fg_wd;
reg         fg_we;

jtframe_rpwp_ram #(
    .DW ( 8  ),
    .AW ( 10 )
) u_lbfg(
    .clk     ( clk   ),
    .rd_addr ( lb_ra ),
    .dout    ( lfg   ),
    .wr_addr ( fg_wa ),
    .din     ( fg_wd ),
    .we      ( fg_we )
);

localparam F_IDLE=0, F_W0=1, F_W1=2, F_R0=3, F_REQ=4, F_D=5, F_D2=6;
reg  [2:0]  fst;
reg  [5:0]  fc;
reg  [15:0] fw0;
reg  [11:0] fcode;
reg  [3:0]  fcol;
reg  [1:0]  fk;
reg  [7:0]  fbyte;
reg  [2:0]  rom_row;
wire [4:0]  frow = rline[7:3];
wire [2:0]  fr   = rline[2:0];

assign fgrom_addr = { fcode, fk, rom_row };

always @* begin
    fg_rd_addr = { frow, fc, fst==F_W1 };
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        fst <= F_IDLE; fg_we <= 0; fgrom_cs <= 0;
    end else begin
        fg_we <= 0;
        case( fst )
            F_IDLE: if( line_start ) begin fc <= 0; fst <= F_W0; end
            F_W0: fst <= F_W1;
            F_W1: begin fw0 <= fg_rd_data; fst <= F_R0; end
            F_R0: begin
                fcode <= { fg_rd_data[3:0], fw0[7:0] };
                fcol  <= fg_rd_data[7:4];
                fk    <= 0;
                fst   <= F_REQ;
            end
            F_REQ: begin
                rom_row    <= fr;
                fgrom_cs   <= 1;
                fst        <= F_D;
            end
            F_D: if( fgrom_ok ) begin
                fgrom_cs <= 0;
                fbyte    <= fgrom_data;
                fg_wa    <= { rbank, fc, fk, 1'b0 };
                fg_wd    <= { fcol, fgrom_data[6], fgrom_data[4], fgrom_data[2], fgrom_data[0] };
                fg_we    <= 1;
                fst      <= F_D2;
            end
            F_D2: begin
                fg_wa <= { rbank, fc, fk, 1'b1 };
                fg_wd <= { fcol, fbyte[7], fbyte[5], fbyte[3], fbyte[1] };
                fg_we <= 1;
                if( fk==2'd3 ) begin
                    if( fc==6'd39 ) fst <= F_IDLE;
                    else begin fc <= fc + 6'd1; fst <= F_W0; end
                end else begin
                    fk  <= fk + 2'd1;
                    fst <= F_REQ;
                end
            end
            default: fst <= F_IDLE;
        endcase
    end
end

assign busy = fst!=F_IDLE;

endmodule
