/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 1-1-2025 */

module jtgaiden_mcu_emu(
    input                rst,
    input                clk,
    input                we,
    input                mcutype,
    input          [7:0] din,
    output reg     [7:0] dout
);

localparam [3:0] INIT=0, 
                 CODEMSB=1,
                 CODELSB=2,
                 SELNIB3=3, // nibble selection
                 SELNIB2=4,
                 SELNIB1=5,
                 SELNIB0=6;

localparam [ 0:0] WILDFANG=0, RAIGA=1;
localparam [15:0] SWITCH_TO_GAMEPLAY=-16'd2;

reg  [ 7:0] addr;
reg  [ 1:0] lsb_up;
reg         gameplay_sel;
reg  [15:0] jump;
wire [15:0] wildfang, bootup, gameplay;

always @(posedge clk) begin
    jump <= mcutype == WILDFANG     ? wildfang :
                       gameplay_sel ? gameplay : bootup;
end

jtgaiden_wildfang_lut u_lut(
    .clk      ( clk       ),
    .addr     ( addr[4:0] ),
    .jump     ( wildfang  )
);

jtgaiden_raiga_luts u_raiga(
    .clk      ( clk       ),
    .addr     ( addr      ),
    .bootup   ( bootup    ),
    .gameplay ( gameplay  )
);

always @(posedge clk) begin
    if(rst) begin
        gameplay_sel <= 0;
    end else begin
        if(!gameplay_sel && bootup==SWITCH_TO_GAMEPLAY && lsb_up[0]) gameplay_sel <= 1;
    end
end

always @(posedge clk) begin
    if(rst) begin
        dout         <= 0;
        addr         <= 0;
    end else begin
        lsb_up <= lsb_up >> 1;
        if(we) case(din[7:4])
            INIT:    dout <= 0;
            CODEMSB: begin addr[7:4] <= din[3:0]; dout<=8'h10; end
            CODELSB: begin addr[3:0] <= din[3:0]; dout<=8'h20; lsb_up[1]<=1; end
            SELNIB3: dout <= {4'h4,jump[12+:4]};
            SELNIB2: dout <= {4'h5,jump[ 8+:4]};
            SELNIB1: dout <= {4'h6,jump[ 4+:4]};
            SELNIB0: dout <= {4'h7,jump[ 0+:4]};
            default:;
        endcase
    end
end

endmodule    