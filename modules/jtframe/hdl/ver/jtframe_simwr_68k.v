/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-2-2022 */

// Writes a series of values to the CPU bus
// as a simplified M68K. The values come from
// a text file (CSV) with the following format
// Address,data,~mask
// the mask is active low

module jtframe_simwr_68k(
    input              rst,
    input              clk,
    input              DTACKn,
    output reg  [23:1] A,
    output reg  [15:0] dout,
    output reg  [ 1:0] dsn,
    output reg         wrn,
    output reg         ASn
);

parameter SIMFILE="simwr.csv";

integer file,rdcnt;

reg [1:0] st;

initial begin
    file=$fopen(SIMFILE,"r");
end

always @(posedge clk) begin
    if( rst ) begin
        A    <= 0;
        dout <= 0;
        dsn  <= 3;
        wrn  <= 1;
        ASn  <= 1;
        st   <= 0;
    end else begin
        st <= st+1;
        case( st )
            0: begin
                rdcnt <= $fscanf(file,"%X,%X,%X",A,dout,dsn);
            end
            1: begin
                if( rdcnt <= 0 ) begin
                    st <= st; // Stall here
                end else begin
                    ASn <= 0;
                    wrn <= 0;
                end
            end
            2: begin
                if( !DTACKn )
                    wrn <= 1;
                else
                    st <= st;
            end
            3: begin
                ASn <= 1;
            end
        endcase
    end
end

endmodule