/* SPDX-License-Identifier: GPL-3.0-or-later */

// FPGA-native K056832 line renderer for the Moo Mesa 4bpp configuration.
// The register/VRAM owner is jtmoomsa_k056832; this block owns only raster,
// tile fetch and line-buffer state.  Its shared-ROM request remains asserted
// until rom_ok, matching the JTFRAME SDRAM contract.
module jtmoomsa_k056832_renderer(
    input             rst,
    input             clk,

    input             raster_lhbl,
    input             raster_lvbl,
    input             raster_hs,
    input             raster_vs,
    input      [8:0]  raster_hdump,
    input      [8:0]  raster_vdump,
    input      [8:0]  raster_vrender,
    input      [8:0]  raster_vrender1,
    input      [8:0]  raster_vmax,

    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,
    output     [8:0]  hdump,
    output     [8:0]  vdump,
    output     [8:0]  vrender,
    output     [8:0]  vrender1,

    output reg [16:0] render_vram_addr,
    input      [15:0] render_vram_dout,

    input      [3:0]  layer_mode,
    input      [3:0]  layer_page0,
    input      [3:0]  layer_page1,
    input      [3:0]  layer_page2,
    input      [3:0]  layer_page3,
    input      [1:0]  layer_flip0,
    input      [1:0]  layer_flip1,
    input      [1:0]  layer_flip2,
    input      [1:0]  layer_flip3,
    input      [1:0]  tile_fbits,
    input signed [15:0] layer_dx0,
    input signed [15:0] layer_dx1,
    input signed [15:0] layer_dx2,
    input signed [15:0] layer_dx3,
    input signed [15:0] layer_dy0,
    input signed [15:0] layer_dy1,
    input signed [15:0] layer_dy2,
    input signed [15:0] layer_dy3,
    input             flip_x,
    input             flip_y,

    output reg [18:0] rom_addr,
    output            rom_cs,
    input      [31:0] rom_data,
    input             rom_ok,

    output     [7:0]  lyrf_pxl,
    output     [7:0]  lyra_pxl,
    output     [7:0]  lyrb_pxl,
    input      [3:0]  gfx_en
);

// The fourth fetch/storage stream remains internal for owner cadence; direct
// K1 CI1 is VSS, so it has no live colour output at this boundary.

localparam signed [9:0] VX0 = 10'sd40;

function signed [9:0] layer_offs(input [1:0] l);
    begin
        case(l)
            2'd0: layer_offs = -10'sd1;
            2'd1: layer_offs =  10'sd3;
            2'd2: layer_offs =  10'sd5;
            default: layer_offs = 10'sd7;
        endcase
    end
endfunction

function [3:0] page_for(input [1:0] l);
    begin
        case(l)
            2'd0: page_for = layer_page0;
            2'd1: page_for = layer_page1;
            2'd2: page_for = layer_page2;
            default: page_for = layer_page3;
        endcase
    end
endfunction

function signed [15:0] dx_for(input [1:0] l);
    begin
        case(l)
            2'd0: dx_for = layer_dx0;
            2'd1: dx_for = layer_dx1;
            2'd2: dx_for = layer_dx2;
            default: dx_for = layer_dx3;
        endcase
    end
endfunction

function signed [15:0] dy_for(input [1:0] l);
    begin
        case(l)
            2'd0: dy_for = layer_dy0;
            2'd1: dy_for = layer_dy1;
            2'd2: dy_for = layer_dy2;
            default: dy_for = layer_dy3;
        endcase
    end
endfunction

function [1:0] flip_for(input [1:0] l);
    begin
        case(l)
            2'd0: flip_for = layer_flip0;
            2'd1: flip_for = layer_flip1;
            2'd2: flip_for = layer_flip2;
            default: flip_for = layer_flip3;
        endcase
    end
endfunction

// K056832 register 3 selects which attribute bits carry tile flips and
// colour.  Moo uses the 4bpp device, but the format selector is still
// software-visible and must not be hard-wired to the power-on layout.
function [5:0] attr_color(input [1:0] f, input [15:0] attr);
    begin
        case(f)
            2'd0: attr_color = attr[5:0];
            2'd1: attr_color = {attr[7:6], attr[3:0]};
            2'd2: attr_color = {attr[7:4], attr[1:0]};
            default: attr_color = attr[7:2];
        endcase
    end
endfunction

function [1:0] attr_flip(input [1:0] f, input [15:0] attr);
    begin
        case(f)
            2'd0: attr_flip = attr[7:6];
            2'd1: attr_flip = attr[5:4];
            2'd2: attr_flip = attr[3:2];
            default: attr_flip = attr[1:0];
        endcase
    end
endfunction

// K053252 is the sole live raster owner. The game wrapper supplies
// active-relative H/V coordinates so the line producer does not duplicate
// the programmable timing device or the PCB's (40,16) screen offset.
assign lhbl = raster_lhbl;
assign lvbl = raster_lvbl;
assign hs = raster_hs;
assign vs = raster_vs;
assign hdump = raster_hdump;
assign vdump = raster_vdump;
assign vrender = raster_vrender;
assign vrender1 = raster_vrender1;

localparam P_IDLE = 4'd0, P_SETUP = 4'd1, P_ATTR = 4'd2,
           P_ATTR2 = 4'd3, P_CODE = 4'd4, P_CODE2 = 4'd5,
           P_ROM = 4'd6, P_WAIT = 4'd7, P_HANDOFF = 4'd8;
localparam C_IDLE = 1'b0, C_WRITE = 1'b1;

reg [3:0] pf_st;
reg       cs_st;
reg [1:0] flyr, wlyr;
reg [5:0] ftile, wtile;
reg [2:0] fpx;
reg [8:0] fline;
reg       fbank, dispbank;
reg       prev_lhbl;
reg       hs_valid;
reg [15:0] attr_p, attr_c, code_p;
reg [31:0] romdata_p, romdata_c;
reg [5:0]  h_tile;
reg [1:0]  h_lyr;
reg [2:0]  h_sub;
reg [2:0]  sub_c;
reg [15:0] h_attr;
reg [31:0] h_rom;
reg [8:0]  fill_cov0, fill_cov1, fill_cov2, fill_cov3;
reg [8:0]  disp_cov0, disp_cov1, disp_cov2, disp_cov3;

wire signed [15:0] dx_full = dx_for(flyr);
wire signed [15:0] dy_full = dy_for(flyr);
wire [1:0] flip_flyr = flip_for(flyr);
wire [1:0] flip_wlyr = flip_for(wlyr);
wire signed [9:0] dx_val = dx_full[9:0];
wire signed [9:0] dy_val = dy_full[9:0];
wire signed [9:0] offx_val = layer_offs(flyr);
wire signed [11:0] vx0_ext = {{2{VX0[9]}},VX0};
wire signed [11:0] dx_ext = {{2{dx_val[9]}},dx_val};
wire signed [11:0] offx_ext = {{2{offx_val[9]}},offx_val};
wire signed [11:0] xbase_s = vx0_ext + dx_ext - offx_ext;
wire [8:0] base_x = xbase_s[8:0];
wire [2:0] first_sub = base_x[2:0];
wire [5:0] first_col = base_x[8:3];
wire [5:0] cur_col = first_col + ftile;
wire signed [17:0] fline_ext = {9'd0,fline};
wire signed [17:0] dy_ext_wide = {{8{dy_val[9]}},dy_val};
wire signed [17:0] ycalc_s = fline_ext + dy_ext_wide;
wire [7:0] ytile = ycalc_s[7:0];
wire [4:0] tile_row = ytile[7:3];
wire [2:0] tile_y = ytile[2:0];
wire [11:0] tile_index = {tile_row,cur_col,1'b0};
wire [16:0] attr_addr = {1'b0,page_for(flyr),tile_index};
wire [16:0] code_addr = attr_addr + 17'd1;
wire [5:0] tile_color = attr_color(tile_fbits, attr_c);
wire [1:0] tile_attr_flip = attr_flip(tile_fbits, attr_c);
wire [1:0] tile_fetch_flip = attr_flip(tile_fbits, attr_p);
wire       flip_y_tile = flip_flyr[1] & tile_fetch_flip[1];
wire [2:0] tile_y_fetch = flip_y_tile ? ~tile_y : tile_y;

wire       flip_x_tile = flip_wlyr[0] & tile_attr_flip[0];
wire [2:0] px_fetch = flip_x_tile ? ~fpx : fpx;

wire [3:0] pen;
jtmoomsa_k056832_tile_decode u_tile_decode(
    .x   ( px_fetch   ),
    .raw ( romdata_c  ),
    .pen ( pen        )
);
wire [3:0] col_nib = tile_color[5:2];
wire signed [11:0] outpx_s = $signed({3'b0,wtile,3'b0}) -
                              $signed({9'b0,sub_c}) + $signed({9'b0,fpx});
wire [8:0] outpx = outpx_s[8:0];
wire outpx_ok = (outpx_s >= 0) && (outpx_s < 384);
wire [9:0] lb_wa = {fbank,outpx};
wire [9:0] lb_wd = {2'b0,col_nib,pen};
wire lb_we = (cs_st == C_WRITE) && outpx_ok;
wire [8:0] display_x = flip_x ? (9'h1ff - hdump) : hdump;
wire [9:0] lb_ra = {dispbank,display_x};
wire [9:0] lb0_q, lb1_q, lb2_q, lb3_q;

jtframe_rpwp_ram #(.DW(10),.AW(10)) u_lbuf0(
    .clk(clk), .rd_addr(lb_ra), .dout(lb0_q), .wr_addr(lb_wa), .din(lb_wd), .we(lb_we && wlyr==2'd0));
jtframe_rpwp_ram #(.DW(10),.AW(10)) u_lbuf1(
    .clk(clk), .rd_addr(lb_ra), .dout(lb1_q), .wr_addr(lb_wa), .din(lb_wd), .we(lb_we && wlyr==2'd1));
jtframe_rpwp_ram #(.DW(10),.AW(10)) u_lbuf2(
    .clk(clk), .rd_addr(lb_ra), .dout(lb2_q), .wr_addr(lb_wa), .din(lb_wd), .we(lb_we && wlyr==2'd2));
jtframe_rpwp_ram #(.DW(10),.AW(10)) u_lbuf3(
    .clk(clk), .rd_addr(lb_ra), .dout(lb3_q), .wr_addr(lb_wa), .din(lb_wd), .we(lb_we && wlyr==2'd3));

reg cov0, cov1, cov2, cov3;
always @(posedge clk) begin
    cov0 <= display_x < disp_cov0;
    cov1 <= display_x < disp_cov1;
    cov2 <= display_x < disp_cov2;
    cov3 <= display_x < disp_cov3;
end

assign lyrf_pxl = (gfx_en[0] && layer_mode[0] && cov0) ? lb0_q[7:0] : 8'd0;
assign lyra_pxl = (gfx_en[1] && layer_mode[1] && cov1) ? lb1_q[7:0] : 8'd0;
assign lyrb_pxl = (gfx_en[2] && layer_mode[2] && cov2) ? lb2_q[7:0] : 8'd0;
assign rom_cs = (pf_st == P_ROM) || (pf_st == P_WAIT);

always @(posedge clk or posedge rst) begin : k056_fetch
    if (rst) begin
        pf_st <= P_IDLE;
        cs_st <= C_IDLE;
        flyr <= 0;
        wlyr <= 0;
        ftile <= 0;
        wtile <= 0;
        fpx <= 0;
        fline <= 0;
        fbank <= 1'b1;
        dispbank <= 1'b0;
        prev_lhbl <= 1'b1;
        hs_valid <= 1'b0;
        attr_p <= 0;
        attr_c <= 0;
        code_p <= 0;
        romdata_p <= 0;
        romdata_c <= 0;
        h_tile <= 0;
        h_lyr <= 0;
        h_sub <= 0;
        sub_c <= 0;
        h_attr <= 0;
        h_rom <= 0;
        render_vram_addr <= 0;
        rom_addr <= 0;
        fill_cov0 <= 0;
        fill_cov1 <= 0;
        fill_cov2 <= 0;
        fill_cov3 <= 0;
        disp_cov0 <= 0;
        disp_cov1 <= 0;
        disp_cov2 <= 0;
        disp_cov3 <= 0;
    end else begin
        prev_lhbl <= lhbl;

        if (prev_lhbl && !lhbl) begin
            dispbank <= fbank;
            fbank <= ~fbank;
            flyr <= 0;
            ftile <= 0;
        fline <= flip_y ? (raster_vmax - vrender1) : vrender1;
            pf_st <= P_SETUP;
            cs_st <= C_IDLE;
            hs_valid <= 1'b0;
            disp_cov0 <= fill_cov0;
            disp_cov1 <= fill_cov1;
            disp_cov2 <= fill_cov2;
            disp_cov3 <= fill_cov3;
            fill_cov0 <= 0;
            fill_cov1 <= 0;
            fill_cov2 <= 0;
            fill_cov3 <= 0;
        end

        if (cs_st == C_WRITE && outpx_ok) begin
            case (wlyr)
                2'd0: if (outpx + 1'b1 > fill_cov0) fill_cov0 <= outpx + 1'b1;
                2'd1: if (outpx + 1'b1 > fill_cov1) fill_cov1 <= outpx + 1'b1;
                2'd2: if (outpx + 1'b1 > fill_cov2) fill_cov2 <= outpx + 1'b1;
                default: if (outpx + 1'b1 > fill_cov3) fill_cov3 <= outpx + 1'b1;
            endcase
        end

        case (pf_st)
            P_IDLE: begin end
            P_SETUP: begin
                render_vram_addr <= attr_addr;
                pf_st <= P_ATTR;
            end
            P_ATTR: begin
                pf_st <= P_ATTR2;
            end
            P_ATTR2: begin
                attr_p <= render_vram_dout;
                render_vram_addr <= code_addr;
                pf_st <= P_CODE;
            end
            P_CODE: begin
                pf_st <= P_CODE2;
            end
            P_CODE2: begin
                code_p <= render_vram_dout;
                pf_st <= P_ROM;
            end
            P_ROM: begin
                rom_addr <= {code_p,3'b000} + {16'd0,tile_y_fetch};
                pf_st <= P_WAIT;
            end
            P_WAIT: begin
                if (rom_ok) begin
                    romdata_p <= rom_data;
                    pf_st <= P_HANDOFF;
                end
            end
            P_HANDOFF: begin
                if (!hs_valid) begin
                    h_attr <= attr_p;
                    h_rom <= romdata_p;
                    h_tile <= ftile;
                    h_lyr <= flyr;
                    h_sub <= first_sub;
                    hs_valid <= 1'b1;
                    if (ftile == 6'd48) begin
                        ftile <= 0;
                        if (flyr == 2'd3)
                            pf_st <= P_IDLE;
                        else begin
                            flyr <= flyr + 1'b1;
                            pf_st <= P_SETUP;
                        end
                    end else begin
                        ftile <= ftile + 1'b1;
                        pf_st <= P_SETUP;
                    end
                end
            end
            default: pf_st <= P_IDLE;
        endcase

        case (cs_st)
            C_IDLE: begin
                if (hs_valid) begin
                    attr_c <= h_attr;
                    romdata_c <= h_rom;
                    wtile <= h_tile;
                    wlyr <= h_lyr;
                    sub_c <= h_sub;
                    fpx <= 0;
                    hs_valid <= 1'b0;
                    cs_st <= C_WRITE;
                end
            end
            C_WRITE: begin
                if (fpx == 3'd7)
                    cs_st <= C_IDLE;
                else
                    fpx <= fpx + 1'b1;
            end
            default: cs_st <= C_IDLE;
        endcase
    end
end

endmodule
