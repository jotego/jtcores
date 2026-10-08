/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-12-2022 */
    

// Generic color mixer based on PROMs

module jtframe_prom_colmix #( parameter
    PROM_AW  = 10,
    SIMFILE0 = "",
    SIMFILE1 = "",
    CODING   = "RGB",
    COLORW   = 4
)(
    input              rst,
    input              clk,
    input              pxl_cen,
    input              LHBL,
    input              LVBL,

    input [PROM_AW-1:0] lyr0_addr,
    input [PROM_AW-1:0] lyr1_addr,
    input [PROM_AW-1:0] lyr2_addr,
    input [PROM_AW-1:0] lyr3_addr,
    input [1:0]         lyr_sel,

    input [PROM_AW:0]  prog_addr,
    input [7:0]        prog_data,
    input              prom_we,

    output reg [COLORW-1:0] red,
    output reg [COLORW-1:0] green,
    output reg [COLORW-1:0] blue

);

wire [PROM_AW-1:0] rd_addr;
wire               prom_we0, prom_we1;
wire         [7:0] prom0_dout, prom1_dout;
reg  [PROM_AW-1:0] col_addr;
wire               blank;

assign prom_we0 = ~prog_addr[PROM_AW] & prom_we;
assign prom_we1 =  prog_addr[PROM_AW] & prom_we;
assign blank    = ~(LVBL&LHBL);

always @(posedge clk) if(pxl_cen) begin
    case( lyr_sel )
        0: col_addr <= lyr0_addr;
        1: col_addr <= lyr1_addr;
        2: col_addr <= lyr2_addr;
        3: col_addr <= lyr3_addr;
    endcase
end

always @* begin
    case( CODING )
        "RGB": {red,green,blue} = { prom1_dout[COLORW*3-9:0], prom0_dout };
        "BGR": {blue,green,red} = { prom1_dout[COLORW*3-9:0], prom0_dout };
        default: begin
            {red,green,blue} = { prom1_dout[COLORW*3-9:0], prom0_dout };
`ifdef SIMULATION
            $display("ERROR: %m unsupported CODING");
            $finish;
`endif
        end
    endcase
    if( blank ) {red,green,blue} = 0;
end

jtframe_prom #(.AW(PROM_AW),.SIMFILE(SIMFILE0)) u_prom0(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( prog_data     ),
    .rd_addr( col_addr      ),
    .wr_addr( prog_addr[PROM_AW-1:0] ),
    .we     ( prom_we0      ),
    .q      ( prom0_dout    )
);

jtframe_prom #(.AW(PROM_AW),.SIMFILE(SIMFILE1)) u_prom1(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( prog_data     ),
    .rd_addr( col_addr      ),
    .wr_addr( prog_addr[PROM_AW-1:0] ),
    .we     ( prom_we1      ),
    .q      ( prom1_dout    )
);



endmodule