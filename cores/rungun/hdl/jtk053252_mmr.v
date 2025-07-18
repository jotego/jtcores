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
    
    output    [9:0] htotal,
    output    [8:0] hfporch,
    output    [8:0] hbporch,
    output    [7:0] int1en,
    output    [7:0] int2en,
    output    [8:0] vtotal,
    output    [7:0] vfporch,
    output    [7:0] vbporch,
    output    [3:0] vswidth,
    output    [3:0] hswidth,
    output    [7:0] inttime,
    output    [7:0] int1ack,
    output    [7:0] int2ack,

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

assign htotal = { 
    mmr[0][1:0],
    mmr[1][7:0], {0{1'b0}}  // finish off without a comma
    };

assign hfporch = { 
    mmr[2][0],
    mmr[3][7:0], {0{1'b0}}  // finish off without a comma
    };

assign hbporch = { 
    mmr[4][0],
    mmr[5][7:0], {0{1'b0}}  // finish off without a comma
    };

assign int1en = { 
    mmr[6][7:0], {0{1'b0}}  // finish off without a comma
    };

assign int2en = { 
    mmr[7][7:0], {0{1'b0}}  // finish off without a comma
    };

assign vtotal = { 
    mmr[8][0],
    mmr[9][7:0], {0{1'b0}}  // finish off without a comma
    };

assign vfporch = { 
    mmr[10][7:0], {0{1'b0}}  // finish off without a comma
    };

assign vbporch = { 
    mmr[11][7:0], {0{1'b0}}  // finish off without a comma
    };

assign vswidth = { 
    mmr[12][7:4], {0{1'b0}}  // finish off without a comma
    };

assign hswidth = { 
    mmr[12][3:0], {0{1'b0}}  // finish off without a comma
    };

assign inttime = { 
    mmr[13][7:0], {0{1'b0}}  // finish off without a comma
    };

assign int1ack = { 
    mmr[14][7:0], {0{1'b0}}  // finish off without a comma
    };

assign int2ack = { 
    mmr[15][7:0], {0{1'b0}}  // finish off without a comma
    };


always @(posedge clk, posedge rst) begin
    if( rst ) begin
    `ifndef SIMULATION
        for(i=0;i<SIZE;i=i+1) mmr[i] <= INIT[i*8+:8];
    `else
        for(i=0;i<SIZE;i=i+1) mmr[i] <= mmr_init[i];
    `endif 
    dout <= 0;
    end else begin
        dout      <= mmr[addr];
        st_dout   <= mmr[debug_bus[3:0]];
        ioctl_din <= mmr[ioctl_addr];
        if( cs & ~rnw ) begin
            mmr[addr]<=din;
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
            $display("\thtotal = %X",{  mmr_init[0][1:0], mmr_init[1][7:0],{0{1'b0}}});
            $display("\thfporch = %X",{  mmr_init[2][0], mmr_init[3][7:0],{0{1'b0}}});
            $display("\thbporch = %X",{  mmr_init[4][0], mmr_init[5][7:0],{0{1'b0}}});
            $display("\tint1en = %X",{  mmr_init[6][7:0],{0{1'b0}}});
            $display("\tint2en = %X",{  mmr_init[7][7:0],{0{1'b0}}});
            $display("\tvtotal = %X",{  mmr_init[8][0], mmr_init[9][7:0],{0{1'b0}}});
            $display("\tvfporch = %X",{  mmr_init[10][7:0],{0{1'b0}}});
            $display("\tvbporch = %X",{  mmr_init[11][7:0],{0{1'b0}}});
            $display("\tvswidth = %X",{  mmr_init[12][7:4],{0{1'b0}}});
            $display("\thswidth = %X",{  mmr_init[12][3:0],{0{1'b0}}});
            $display("\tinttime = %X",{  mmr_init[13][7:0],{0{1'b0}}});
            $display("\tint1ack = %X",{  mmr_init[14][7:0],{0{1'b0}}});
            $display("\tint2ack = %X",{  mmr_init[15][7:0],{0{1'b0}}});
        end
    end else begin
        for(i=0;i<SIZE;i++) mmr_init[i] = 0;
    end
    $fclose(f);
end
`endif

endmodule
