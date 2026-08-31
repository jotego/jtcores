/* SPDX-License-Identifier: GPL-3.0-or-later */

/* verilator lint_off UNUSEDSIGNAL */
module jtmoomsa_054156_ctrl(
    input             clk,
    input             rst,
    input      [13:1] ab,
    input      [15:0] db_in,
    input      [1:0]  dsn,
    input             cs,
    input             we,
    input             rd,
    output reg [15:0] db_out,
    output reg        db_valid,
    output     [10:0] scroll_y0, scroll_y1, scroll_y2, scroll_y3,
    output     [11:0] scroll_x0, scroll_x1, scroll_x2, scroll_x3,
    output     [5:0]  linescroll_bank,
    output     [5:0]  vram_bank,
    output     [15:0] rom_bank,
    output     [1:0]  rom_bank_hi,
    output     [15:0] tile_bank_lut,
    output     [10:0] x_flip_offset,
    output     [10:0] y_flip_offset,
    output     [7:0]  reg00, reg02, reg04, reg06, reg08, reg0a, reg0c,
    output     [2:0]  y_grid0, y_grid1, y_grid2, y_grid3,
    output     [2:0]  y_pages0, y_pages1, y_pages2, y_pages3,
    output     [2:0]  x_grid0, x_grid1, x_grid2, x_grid3,
    output     [2:0]  x_pages0, x_pages1, x_pages2, x_pages3,
    output            flip_x,
    output            flip_y
);

reg [7:0] r[0:255];
wire [7:0] addr = {ab[7:1],1'b0};
integer k;

// SCROLLY[10:8] latch from REG2xU (D8..D10) and SCROLLY[7:0] from REG2xL
// (decap sheets 054156_p2/p8).  The 68000 places the upper register byte at
// the even address, so the upper byte is r[even] and the lower byte r[even+1],
// matching the SCROLLX assembly below.
assign scroll_y0 = {r[8'h20][2:0],r[8'h21]};
assign scroll_y1 = {r[8'h22][2:0],r[8'h23]};
assign scroll_y2 = {r[8'h24][2:0],r[8'h25]};
assign scroll_y3 = {r[8'h26][2:0],r[8'h27]};
assign scroll_x0 = {r[8'h28][3:0],r[8'h29]};
assign scroll_x1 = {r[8'h2A][3:0],r[8'h2B]};
assign scroll_x2 = {r[8'h2C][3:0],r[8'h2D]};
assign scroll_x3 = {r[8'h2E][3:0],r[8'h2F]};
assign linescroll_bank = r[8'h31][5:0];
assign vram_bank       = r[8'h33][5:0];
assign rom_bank        = {r[8'h34],r[8'h35]};
assign rom_bank_hi     = r[8'h37][1:0];
assign tile_bank_lut   = {r[8'h38],r[8'h39]};
assign x_flip_offset   = {r[8'h3A][2:0],r[8'h3B]};
assign y_flip_offset   = {r[8'h3C][2:0],r[8'h3D]};
assign reg00           = r[8'h01];
assign reg02           = r[8'h03];
assign reg04           = r[8'h05];
assign reg06           = r[8'h07];
assign reg08           = r[8'h09];
assign reg0a           = r[8'h0B];
assign reg0c           = r[8'h0D];
assign y_grid0         = {1'b0,r[8'h11][4:3]};
assign y_grid1         = {1'b0,r[8'h13][4:3]};
assign y_grid2         = {1'b0,r[8'h15][4:3]};
assign y_grid3         = {1'b0,r[8'h17][4:3]};
assign y_pages0        = {1'b0,r[8'h11][1:0]};
assign y_pages1        = {1'b0,r[8'h13][1:0]};
assign y_pages2        = {1'b0,r[8'h15][1:0]};
assign y_pages3        = {1'b0,r[8'h17][1:0]};
assign x_grid0         = {1'b0,r[8'h19][4:3]};
assign x_grid1         = {1'b0,r[8'h1B][4:3]};
assign x_grid2         = {1'b0,r[8'h1D][4:3]};
assign x_grid3         = {1'b0,r[8'h1F][4:3]};
assign x_pages0        = {1'b0,r[8'h19][1:0]};
assign x_pages1        = {1'b0,r[8'h1B][1:0]};
assign x_pages2        = {1'b0,r[8'h1D][1:0]};
assign x_pages3        = {1'b0,r[8'h1F][1:0]};
assign flip_x          = r[8'h01][4];
assign flip_y          = r[8'h01][5];

always @(posedge clk) begin
    if (rst) begin
        db_out <= 16'h0;
        db_valid <= 1'b0;
        for (k = 0; k < 256; k = k + 1)
            r[k] <= 8'h00;
    end else begin
        db_valid <= cs && rd;
        if (cs && we) begin
            if (!dsn[1]) r[addr] <= db_in[15:8];
            if (!dsn[0]) r[addr + 8'd1] <= db_in[7:0];
        end
        if (cs && rd)
            db_out <= {r[addr],r[addr + 8'd1]};
    end
end

endmodule
/* verilator lint_on UNUSEDSIGNAL */
