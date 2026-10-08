/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-6-2021 */

module jts16_fd1094_ctrl(
    input             rst,
    input             clk,

    // Operation
    input             inta_n,      // interrupt acknowledgement
    input             op_n,

    input      [23:1] addr,
    input      [15:0] dec,    
    input      [ 7:0] gkey0,

    input             sup_prog,
    input             dtackn,
    output     [ 7:0] st
);

reg [ 7:0] state;
reg        irqmode;
reg [ 1:0] stchange;
reg [15:0] stcode;
reg        dtacknl;
wire       stadv;

assign st    = irqmode ? gkey0 : state;
assign stadv = !op_n && dtacknl && !dtackn && sup_prog && stchange!=0;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        state     <= 0;
        stchange  <= 0;
        irqmode   <= 0;
        dtacknl   <= 0;
    end else begin
        dtacknl <= dtackn;
        if( !inta_n ) irqmode <= 1;
        if( stadv ) begin
            stchange <= stchange << 1;
            if( stchange[0] ) begin
                stcode <= dec;
                if( dec[15:10]!=0 ) stchange <= 0; // not a cmpi.l #$00/01/02/03
            end
            if( stchange[1] && dec==16'hffff ) begin
                case( stcode[9:8])
                    0: state <= stcode[7:0];
                    1: begin
                        state   <= 0; // reset
                        irqmode <= 0;
                    end
                    2: irqmode <= 1; // enter interruption
                    3: irqmode <= 0; // leave interruption
                endcase
            end
        end
        if( !op_n && !dtackn && sup_prog /*&& stchange==0*/ ) begin
            // cmpi.l #data, Dx
            if( dec[15:8]==8'h0c && dec[7:6]==2'b10 && dec[5:3] == 0 ) begin
                stchange <= 2'b01;
            end
            // rte
            if( dec == 16'h4e73 ) irqmode <= 0;
        end
    end
end

endmodule