/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 23-7-2023 */

// Color mixer compatible with K053251
// See Furrtek's files for RE information

module jtcolmix_053251(
    input             rst,
    input             clk,
    input             pxl_cen,
    // CPU interface
    input             cs,
    input       [3:0] addr,
    input       [5:0] din,
    // explicit priorities
    input             sel,  // unused in The Simpsons, may need further testing
    input       [5:0] pri0, pri1, pri2,
    // color inputs
    input       [8:0] ci0, ci1, ci2,
    input       [7:0] ci3, ci4,
    // shadow
    input       [1:0] shd_in,
    output reg  [1:0] shd_out,
    // MMR dump
    input       [3:0] ioctl_addr,
    output      [7:0] ioctl_din,

    output reg [10:0] cout,
    output reg        brit,     // bright
    output reg        col_n
);

localparam EXTEN =12,
           FULL  =11,
           COLHI0= 9,
           COLHI3=10;

reg  [ 5:0] mmr[0:12];
reg  [ 5:0] pri0_mux, pri1_mux, pri2_mux, pri3_mux, pri4_mux,
            mix1p, mix2p, mix3p, mix4p;
reg  [10:0] mix1,mix2,mix3,mix4;
reg  [ 8:0] cl0, cl1, cl2;
reg  [ 7:0] cl3, cl4;
reg  [ 1:0] shd_l;
reg  [ 5:0] shd_p;
reg  [ 4:0] op, pre_n;
reg  [ 2:0] st;
reg         shd_sel, col1_n, col2_n, col3_n, col4_n;

reg  p1win, l1, l2, l3, l4;

assign ioctl_din = {2'd0, mmr[ioctl_addr]};

always @* begin
    op[0] = opaque(mmr[FULL][0],ci0[7:0]);
    op[1] = opaque(mmr[FULL][1],ci1[7:0]);
    op[2] = opaque(mmr[FULL][2],ci2[7:0]);
    op[3] = opaque(mmr[FULL][3],ci3[7:0]);
    op[4] = opaque(mmr[FULL][4],ci4[7:0]);

    p1win = pri1_mux < pri0_mux;
    l1    = ~(~sel & mmr[11][5]) & ~( ~p1win & ~mmr[11][5]);

    l2    = pri2_mux < mix1p;
    l3    = pri3_mux < mix2p;
    l4    = pri4_mux < mix3p;

    case( shd_l )
        0: shd_p = 6'h3f;
        1: shd_p = mmr[6];
        2: shd_p = mmr[7];
        3: shd_p = mmr[8];
    endcase
end

function opaque( input full, input [7:0] col );
    opaque = ~|col[3:0];
    if(full) opaque = opaque & ~|col[7:4];
endfunction

`ifdef SIMULATION
reg [5:0] mmr_init[0:12];
integer f,fcnt=0;

initial begin
    f=$fopen("pal_mmr.bin","rb");
    if( f!=0 ) begin
        fcnt=$fread(mmr_init,f);
        $fclose(f);
        $display("Read %1d bytes for 053251 MMR (priority color mixer)", fcnt);
    end
end
`endif

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pri0_mux<=0; pri1_mux<=0; pri2_mux<=0; pri3_mux<=0; pri4_mux<=0;
        cl0     <=0; cl1     <=0; cl2     <=0; cl3     <=0; cl4     <=0;
                     mix1    <=0; mix2    <=0; mix3    <=0; mix4    <=0;
                     mix1p   <=0; mix2p   <=0; mix3p   <=0; mix4p   <=0;
        pre_n   <= 0;
        col_n   <= 0;
        cout    <= 0;
        shd_out <= 0;
        brit    <= 0;
        st      <= 0;
    end else begin
        st <= st+3'd1;
        if( pxl_cen ) begin
            pri0_mux <= op[0] ? 6'h3f : (mmr[EXTEN][0] ? mmr[0] : pri0);
            pri1_mux <= op[1] ? 6'h3f : (mmr[EXTEN][1] ? mmr[1] : pri1);
            pri2_mux <= op[2] ? 6'h3f : (mmr[EXTEN][2] ? mmr[2] : pri2);
            pri3_mux <= op[3] ? 6'h3f :                  mmr[3]        ;
            pri4_mux <= op[4] ? 6'h3f :                  mmr[4]        ;
            pre_n <= op;
            cl0   <= ci0; cl1 <= ci1; cl2 <= ci2; cl3 <= ci3; cl4 <= ci4;
            shd_l <= shd_in;
            // assign module outputs
            col_n   <= col4_n;
            cout    <= mix4;
            shd_out <= shd_sel ? shd_l : 2'b0;
            brit    <= mix4p < ~mmr[5];
            // start pipeline
            st <= 0;
        end
        case( st )
            1: begin
                mix1  <= l1 ? {mmr[COLHI0][3:2],cl1} : {mmr[COLHI0][1:0],cl0};
                mix1p <= (l1 | mmr[11][5]) ? pri1_mux : pri0_mux;
                col1_n<= l1 ? pre_n[1] : pre_n[0];
            end
            2: begin
                mix2  <= l2 ? {mmr[COLHI0][5:4],cl2} : mix1;
                mix2p <= l2 ? pri2_mux : mix1p;
                col2_n<= l2 ? pre_n[2] : col1_n;
            end
            3: begin
                mix3  <= l3 ? {mmr[COLHI3][2:0],cl3} : mix2;
                mix3p <= l3 ? pri3_mux : mix2p;
                col3_n<= l3 ? pre_n[3] : col2_n;
            end
            4: begin
                mix4  <= l4 ? {mmr[COLHI3][5:3],cl4} : mix3;
                mix4p <= l4 ? pri4_mux : mix3p;
                col4_n<= l4 ? pre_n[4] : col3_n;
            end
            5: begin
                shd_sel <= shd_p < mix4p;
            end
            default:;
        endcase
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mmr[0] <= 0; mmr[1] <= 0; mmr[ 2] <= 0; mmr[ 3] <= 0;
        mmr[4] <= 0; mmr[5] <= 0; mmr[ 6] <= 0; mmr[ 7] <= 0;
        mmr[8] <= 0; mmr[9] <= 0; mmr[10] <= 0; mmr[11] <= 0; mmr[12] <= 0;
`ifdef SIMULATION
        if( fcnt!=0 ) begin
            mmr[0] <= mmr_init[0]; mmr[1] <= mmr_init[1]; mmr[2] <= mmr_init[2];
            mmr[3] <= mmr_init[3]; mmr[4] <= mmr_init[4]; mmr[5] <= mmr_init[5];
            mmr[6] <= mmr_init[6]; mmr[7] <= mmr_init[7]; mmr[8] <= mmr_init[8];
            mmr[9] <= mmr_init[9]; mmr[10] <= mmr_init[10];
            mmr[11] <= mmr_init[11]; mmr[12] <= mmr_init[12];
        end
`endif
    end else begin
        if( cs ) mmr[addr] <= din;
    end
end

endmodule