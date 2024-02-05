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
    Date: 5-2-2024 */

module jt053246_mmr(
    input             rst,
    input             clk,

    input             k44_en,   // enable k053244/5 mode (default k053246/7)
    // CPU interface
    input             cs,
    input             cpu_we,
    input      [ 3:1] cpu_addr, // bit 3 only in k44 mode
    input      [15:0] cpu_dout,
    input      [ 1:0] cpu_dsn,

    output reg [ 7:0] cfg,
    output reg [ 9:0] xoffset,
    output reg [ 9:0] yoffset,
    output reg [21:1] rmrd_addr,

    input      [ 7:0] st_addr,
    output reg [ 7:0] st_dout
);

`ifdef SIMULATION
reg [7:0] mmr_init[0:7];
integer f,fcnt=0;

initial begin
    f=$fopen("obj_mmr.bin","rb");
    if( f!=0 ) begin
        fcnt=$fread(mmr_init,f);
        $fclose(f);
        $display("Read %1d bytes for 053246 MMR", fcnt);
        mmr_init[5][4] = 1; // enable DMA, which will be low if the game was paused for the dump
    end
end
`endif

// Register map
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        xoffset <= 0; yoffset <= 0; cfg <= 0;
`ifdef SIMULATION
        if( fcnt!=0 ) begin
            xoffset <= { mmr_init[1][1:0], mmr_init[0] };
            yoffset <= { mmr_init[3][1:0], mmr_init[2] };
            cfg     <= mmr_init[5];
        end
`endif
        st_dout <= 0;
    end else begin
        if( cs ) begin // note that the write signal is not checked
            case( {cpu_addr[3] & k44_en, cpu_addr[2:1]} )
                0: begin
                    if( !cpu_dsn[0] ) xoffset[ 7:0] <= cpu_dout[7:0];
                    if( !cpu_dsn[1] ) xoffset[ 9:8] <= cpu_dout[9:8];
                end
                1: begin
                    if( !cpu_dsn[0] ) yoffset[7:0] <= cpu_dout[7:0];
                    if( !cpu_dsn[1] ) yoffset[9:8] <= cpu_dout[9:8];
                end
                2: begin
                    if( !cpu_dsn[0] ) cfg <= cpu_dout[15:8];
                    if( !cpu_dsn[1] && !k44_en ) rmrd_addr[8:1] <= cpu_dout[7:0];
                end
                3: if( !k44_en ) begin // related to dma_en, see above
                    if( !cpu_dsn[0] ) rmrd_addr[16: 9] <= cpu_dout[ 7:0];
                    if( !cpu_dsn[1] ) rmrd_addr[21:17] <= cpu_dout[12:8];
                end
                // k44_en only
                4: begin
                    if( !cpu_dsn[0] ) rmrd_addr[ 8: 1] <= cpu_dout[ 7:0];
                    if( !cpu_dsn[1] ) rmrd_addr[16: 9] <= cpu_dout[15:8];
                end
                5: begin
                    if( !cpu_dsn[0] ) rmrd_addr[21:17] <= cpu_dout[ 4:0];
                end
            endcase
        end
        case( st_addr[2:0])
            0: st_dout <= xoffset[7:0];
            1: st_dout <= {6'd0,xoffset[9:8]};
            2: st_dout <= yoffset[7:0];
            3: st_dout <= {6'd0,yoffset[9:8]};
            5: st_dout <= cfg;
            default: st_dout <= 0;
        endcase
    end
end

endmodule