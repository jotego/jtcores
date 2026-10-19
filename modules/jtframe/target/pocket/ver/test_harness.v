/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 6-9-2021 */

/////////////////////////////////////////////
//  This module includes the SDRAM model
//  when used to simulate the core at the game level (instead of MiST(er) level)
//  this module also adds the SDRAM controller
//
//

`timescale 1ns/1ps

module test_harness(
    output  reg  clk_74a,
    output  reg  clk_74b,

    input        vblank,
    // video output to the scaler
    input [11:0] scal_vid,
    input        scal_clk,
    input        scal_de,
    input        scal_skip,
    input        scal_vs,
    input        scal_hs,

    output       scal_audadc,
    input        scal_audmclk,
    input        scal_auddac,
    input        scal_audlrck,

    inout  [1:0] spi_dio,
    inout        spi_clk,
    output reg   spi_ss=0,
    inout        brg_1wire,
    // SDRAM
    inout [15:0] sdram_dq,
    input [12:0] sdram_a,
    input [ 1:0] sdram_dqm,
    input        sdram_nwe,
    input        sdram_ncas,
    input        sdram_nras,
    input        sdram_ncs,
    input [1:0]  sdram_ba,
    input        sdram_clk,
    input        sdram_cke
);

reg [31:0] frame_cnt=0;
integer fincnt;

assign scal_audadc = 0;
assign bridge_spiss = 0;

initial begin
    clk_74a = 0;
    forever #6.734 clk_74a = ~clk_74a;
end

initial begin
    clk_74b = 0;
    #1.734
    forever #6.734 clk_74b = ~clk_74b;
end

always @(posedge scal_vs) begin
    frame_cnt <= frame_cnt+1;
end

pocket_dump u_dump(
    .scal_vs    ( scal_vs   ),
    .frame_cnt  ( frame_cnt )
);

mt48lc16m16a2 u_sdram (
    .Dq         ( sdram_dq      ),
    .Addr       ( sdram_a       ),
    .Ba         ( sdram_ba      ),
    .Clk        ( sdram_clk     ),
    .Cke        ( sdram_cke     ),
    .Cs_n       ( 1'd0          ),
    .Ras_n      ( sdram_nras    ),
    .Cas_n      ( sdram_ncas    ),
    .We_n       ( sdram_nwe     ),
    .Dqm        ( sdram_dqm     ),
    .downloading( dwnld_busy    ),
    .VS         ( vblank        ),
    .frame_cnt  ( frame_cnt     )
);

initial begin
    fincnt=0;
    $display("Simulate for %0d us",`SIM_MS*100);
    forever begin
        #(100*1000); // 0.1ms
        fincnt = fincnt+1;
        $display("%d ms",fincnt);
        //if( fincnt>=`SIM_MS ) $finish;
    end
end

// Send SPI commands
reg [ 63:0] cmd[0:127];
reg         spi_idlel, spi_wr;
reg         wait_startup, spi_cen=0;
integer     spi_cnt=0, st=0;
reg         repeat_rd=0;
wire [63:0] spi_din;
wire [ 1:0] spi_data;
reg  [ 6:0] spi_wait; // no less than 1.18 us between transactions
wire        spi_idle, rding, tx_clk;

assign spi_din  = cmd[spi_cnt];
assign spi_clk  = rding ? 1'bz : tx_clk;
assign spi_dio  = (!spi_ss && !rding) ? spi_data[1:0] :  2'bzz;

pullup( spi_clk    );
pullup( spi_dio[0] );
pullup( spi_dio[1] );

initial begin
    wait_startup = 1;
    #150_000 wait_startup = 0;
end

localparam CMDCNT=38; // set to max index used

initial begin // last address bit sets write (1) or read (0)
    // Reads must be sent twice
    // Request status command
    cmd[ 0] = { 32'hf800_0004, 32'h0  }; // desired host parameter pointer
    cmd[ 1] = { 32'hf800_0008, 32'h0  }; // desired host response pointer
    cmd[ 2] = { 32'hf800_0021, 32'h00 }; // blank parameter
    cmd[ 3] = { 32'hf800_0025, 32'h00 }; // blank parameter
    cmd[ 4] = { 32'hf800_0029, 32'h00 }; // blank parameter
    cmd[ 5] = { 32'hf800_002D, 32'h00 }; // blank parameter
    cmd[ 6] = { 32'hf800_0001, 32'h434d_0000 }; // request status
    cmd[ 7] = { 32'hf800_0000, 32'h0 }; // read the response, expects 4f4b'0003
    cmd[ 8] = { 32'hf800_0040, 32'h0 }; // read response parameters
    cmd[ 9] = { 32'hf800_0044, 32'h0 }; // read response parameters
    cmd[10] = { 32'hf800_0048, 32'h0 }; // read response parameters
    cmd[11] = { 32'hf800_004c, 32'h0 }; // read response parameters
    // "Slot all complete" command
    cmd[12] = { 32'hf800_0004, 32'h0  }; // desired host parameter pointer
    cmd[13] = { 32'hf800_0008, 32'h0  }; // desired host response pointer
    cmd[14] = { 32'hf800_0021, 32'h00 }; // blank parameter
    cmd[15] = { 32'hf800_0025, 32'h00 }; // blank parameter
    cmd[16] = { 32'hf800_0029, 32'h00 }; // blank parameter
    cmd[17] = { 32'hf800_002D, 32'h00 }; // blank parameter
    cmd[18] = { 32'hf800_0001, 32'h434d_008f }; // slot all complete
    cmd[19] = { 32'hf800_0000, 32'h0 }; // read the response, expects 4f4b'0003/0?
    cmd[20] = { 32'hf800_0040, 32'h0 }; // read response parameters
    cmd[21] = { 32'hf800_0044, 32'h0 }; // read response parameters
    cmd[22] = { 32'hf800_0048, 32'h0 }; // read response parameters
    cmd[23] = { 32'hf800_004c, 32'h0 }; // read response parameters
    // "Ready to run" target command
    cmd[24] = { 32'hf800_1004, 32'h0  }; // desired host parameter pointer
    cmd[25] = { 32'hf800_1008, 32'h0  }; // desired host response pointer
    cmd[26] = { 32'hf800_1000, 32'h0  }; // command status, expects 636d'0140
    cmd[27] = { 32'hf800_1020, 32'h0 };  // response parameters - 636d'0140
    cmd[28] = { 32'hf800_1024, 32'h0 };  // response parameters - 636d'0140
    cmd[29] = { 32'hf800_1028, 32'h0 };  // response parameters - 636d'0140
    cmd[30] = { 32'hf800_102c, 32'h0 };  // response parameters - 636d'0140
    // "Set done flag" target command
    cmd[31] = { 32'hf800_1004, 32'h0 }; // desired host parameter pointer
    cmd[32] = { 32'hf800_1008, 32'h0 }; // desired host response pointer
    cmd[33] = { 32'hf800_1000, 32'h0 }; // command status, expects 636d'0140
    cmd[34] = { 32'hf800_1041, 32'h0 };  // host parameters - 0
    cmd[35] = { 32'hf800_1045, 32'h0 };  // host parameters - 0
    cmd[36] = { 32'hf800_1049, 32'h0 };  // host parameters - 0
    cmd[37] = { 32'hf800_104d, 32'h0 };  // host parameters - 0
    cmd[38] = { 32'hf800_1001, 32'h6f6b_0000 };  // writes done
end

always @(posedge clk_74a ) begin
    if( !wait_startup && st!=8 ) st <= st + 1'd1;
    spi_wr <= 0;
    case( st )
        0: begin
            if( !spi_idle || spi_cnt > CMDCNT )
                st <= st;
            else
                spi_ss <= 1;
            if( spi_cnt > CMDCNT ) begin
                $display("Pocket commands completed");
                #1000 $finish;
            end
        end
        2: begin
            if( !cmd[spi_cnt][32] ) repeat_rd <= ~repeat_rd;
            $display("Sending %X - %X",cmd[spi_cnt][63:32],cmd[spi_cnt][31:0]);
            spi_wr <= 1;
            spi_ss  <= 0;
        end
        // 3: begin
        // end
        5:  if( !spi_idle ) begin
            st <= st;
        end
        7: begin
            spi_ss <= 1;
            if( spi_cnt <= CMDCNT ) begin
                if( !repeat_rd ) spi_cnt <= spi_cnt+1;
                st <= 8;
                spi_wait <= 0;
            end else begin
                st <= 7;
            end
        end
        8: begin
            spi_wait <= spi_wait+1;
            if( &spi_wait ) st <= 0;
        end
    endcase
end

pocket_spi u_spi(
    .spi_clk( spi_clk   ),
    .spi_ss ( spi_ss    ),
    .clk    ( clk_74a   ),
    .tx_clk ( tx_clk    ),
    .wr     ( spi_wr    ),
    .din    ( spi_din   ),
    .dout   ( spi_data  ),
    .rding  ( rding     ),
    .idle   ( spi_idle  )
);

pocket_rx_spi u_rx(
    .spi_ss ( spi_ss    ),
    .spi_clk( spi_clk   ),
    .spi_dio( spi_dio   )
);

endmodule

/////////////////////////////////////////////////////////

module pocket_rx_spi(
    input         spi_clk,
    input         spi_ss,
    input [1:0]   spi_dio
);

    reg [63:0] bufin;
    reg [31:0] addr,data;

    always @* begin
        if( spi_ss ) { addr, data } = bufin;
    end

    always @(posedge spi_clk ) begin
        if( !spi_ss ) bufin <= { bufin[61:0], spi_dio };
    end

    integer spi_pulses;

    always @(posedge spi_ss) begin
        if( spi_pulses!=0 && spi_pulses!=16 && spi_pulses!= 32 ) begin
            $display("%m incomplete SPI transaction");
            #300 $finish;
        end
    end

    always @(posedge spi_clk, posedge spi_ss ) begin
        if( spi_ss ) begin
            spi_pulses <= 0;
        end else begin
            spi_pulses <= spi_pulses + 1;
        end
    end
endmodule



module pocket_spi(
    input         spi_clk,
    input         spi_ss,
    input         clk,
    output reg    tx_clk,
    input  [63:0] din,
    input         wr,
    inout   [1:0] dout,
    output reg    rding,
    output reg    idle=1
);

    reg        wrl=0;
    reg [65:0] data;
    reg [ 5:0] cnt=0;
    reg        is_rd=0;

    assign dout = rding ? 2'bzz : data[65:64];

    always @(posedge spi_clk, spi_ss) begin
        if( spi_ss )
            cnt <= 0;
        else if( spi_clk )
            cnt <= cnt+1'd1;
    end

    always @(posedge clk) begin
        wrl <= wr;
        tx_clk <= (idle || rding) ? 1'b1 : ~tx_clk;
        if( idle ) begin
            data  <= 0;
            rding <= 0;
        end
        if( wr && !wrl ) begin
            idle  <= 0;
            data  <= {2'b11,din};
            is_rd <= ~din[32];
        end else begin
            if( tx_clk ) begin
                if( rding ? cnt<6'h21 : !cnt[5]  ) begin
                    data <= data<<2;
                end else begin
                    idle <= 1;
                    rding <= 0;
                end
            end else begin
                if( cnt==16 && is_rd ) rding <= 1;
            end
        end
    end

endmodule