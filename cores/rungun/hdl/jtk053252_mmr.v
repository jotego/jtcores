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
    Date: 20-10-2023 */

module jtk053252_mmr(
    input             rst,
    input             clk,

    input             cs,
    input       [3:0] addr,
    input             rnw,
    input       [7:0] din, 
    output reg  [7:0] dout,
    
    output [9:0] hcnt0,
    output [8:0] hbstart,
    output [8:0] hb2cnt0,
    output [2:0] nhbs_dly,
    output [1:0] fcnt_out,
    output       hcnt_dis,
    output [8:0] vcnt0,
    output [7:0] vbstart,
    output [7:0] vbcnt0,
    output [3:0] vswidth,
    output [3:0] hswidth,
    output [7:0] int2cnt0,
    output reg   set_int2en,
    output reg   int1ack,
    output reg   int2ack,

    // IOCTL dump
    input      [3:0] ioctl_addr,
    output reg [7:0] ioctl_din,
    // Debug
    input      [7:0] debug_bus,
    output reg [7:0] st_dout
);

parameter SIMFILE="rest.bin",
          SEEK=0;
parameter [SIZE*8-1:0] INIT=0; // from high to low regs {mmr[3],mmr[2],mmr[1],mmr[0]}

localparam SIZE=16;

reg  [ 7:0] mmr[0:SIZE-1];
integer     i;

assign hcnt0 = { 
    mmr[0][1:0],
    mmr[1][7:0], {0{1'b0}}  // finish off without a comma
    };

assign hbstart = { 
    mmr[2][0],
    mmr[3][7:0], {0{1'b0}}  // finish off without a comma
    };

assign hb2cnt0 = { 
    mmr[4][0],
    mmr[5][7:0], {0{1'b0}}  // finish off without a comma
    };

assign nhbs_dly = { 
    mmr[6][2:0], {0{1'b0}}  // finish off without a comma
    };

assign fcnt_out = { 
    mmr[7][1:0], {0{1'b0}}  // finish off without a comma
    };

assign hcnt_dis = { 
    mmr[7][7], {0{1'b0}}  // finish off without a comma
    };

assign vcnt0 = { 
    mmr[8][0],
    mmr[9][7:0], {0{1'b0}}  // finish off without a comma
    };

assign vbstart = { 
    mmr[10][7:0], {0{1'b0}}  // finish off without a comma
    };

assign vbcnt0 = { 
    mmr[11][7:0], {0{1'b0}}  // finish off without a comma
    };

assign vswidth = { 
    mmr[12][7:4], {0{1'b0}}  // finish off without a comma
    };

assign hswidth = { 
    mmr[12][3:0], {0{1'b0}}  // finish off without a comma
    };

assign int2cnt0 = { 
    mmr[13][7:0], {0{1'b0}}  // finish off without a comma
    };


always @(posedge clk) begin
    if( rst ) begin
    `ifndef SIMULATION
        for(i=0;i<SIZE;i=i+1) mmr[i] <= INIT[i*8+:8];
    `else
        for(i=0;i<SIZE;i=i+1) mmr[i] <= mmr_init[i];
    `endif 
        set_int2en <= 0; 
        int1ack <= 0; 
        int2ack <= 0; 
    dout <= 0;
    end else begin
        set_int2en <= 0; 
        int1ack <= 0; 
        int2ack <= 0; 
        dout      <= mmr[addr];
        st_dout   <= mmr[debug_bus[3:0]];
        ioctl_din <= mmr[ioctl_addr];
        if( cs & ~rnw ) begin
            mmr[addr]<=din;
            if(addr=='d13) set_int2en <= 1; 
            if(addr=='d14) int1ack <= 1; 
            if(addr=='d15) int2ack <= 1; 
        end
        i = 0; // for Quartus linter
    end
end

`ifdef SIMULATION
/* verilator tracing_off */
integer f, fcnt, err;
reg [7:0] mmr_init[0:SIZE-1];
initial begin
    f=$fopen(SIMFILE,"rb");
    err=$fseek(f,SEEK,0);
    if( f!=0 && err!=0 ) begin
        $display("Cannot seek file rest.bin to offset 0x%0X (%0d)",SEEK,SEEK);
    end
    if( f!=0 ) begin
        fcnt=$fread(mmr_init,f);
        $display("MMR %m - read %0d bytes from offset %0d",fcnt,SEEK);
        if( fcnt!=SIZE ) begin
            $display("WARNING: Missing %d bytes for %m.mmr",SIZE-fcnt);
        end else begin
            $display("\thcnt0 = %X",{  mmr_init[0][1:0], mmr_init[1][7:0],{0{1'b0}}});
            $display("\thbstart = %X",{  mmr_init[2][0], mmr_init[3][7:0],{0{1'b0}}});
            $display("\thb2cnt0 = %X",{  mmr_init[4][0], mmr_init[5][7:0],{0{1'b0}}});
            $display("\tnhbs_dly = %X",{  mmr_init[6][2:0],{0{1'b0}}});
            $display("\tfcnt_out = %X",{  mmr_init[7][1:0],{0{1'b0}}});
            $display("\thcnt_dis = %X",{  mmr_init[7][7],{0{1'b0}}});
            $display("\tvcnt0 = %X",{  mmr_init[8][0], mmr_init[9][7:0],{0{1'b0}}});
            $display("\tvbstart = %X",{  mmr_init[10][7:0],{0{1'b0}}});
            $display("\tvbcnt0 = %X",{  mmr_init[11][7:0],{0{1'b0}}});
            $display("\tvswidth = %X",{  mmr_init[12][7:4],{0{1'b0}}});
            $display("\thswidth = %X",{  mmr_init[12][3:0],{0{1'b0}}});
            $display("\tint2cnt0 = %X",{  mmr_init[13][7:0],{0{1'b0}}});
        end
    end else begin
        for(i=0;i<SIZE;i++) mmr_init[i] = 0;
    end
    $fclose(f);
end
`endif

endmodule
