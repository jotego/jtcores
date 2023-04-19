/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-1-2020 */
    

// DMA copying OBJ table data from video RAM to internal RAM
// Copying stops if 8'hFF is detected in the attributes word
// Because attributes are checked first, data is read in 3,2,1,0 order
// instead of the natural 0,1,2,3 order. Counters do count in the natural
// sequence but the lower 2 bits of the address registers are inverted
// the inversion applies both to the VRAM address and to the internal
// buffer address
// The rest of the table is filled with zeros, which seems the safest value

module jtcps1_obj_table(
    input              rst,
    input              clk,
    input              pxl_cen,

    input              obj_dma_ok,
    // BUS sharing
    output reg         busreq,
    input              busack,

    // control registers
    input      [15:0]  vram_base,
    output     [17:1]  vram_addr,
    input      [15:0]  vram_data,
    input              vram_ok,

    // interface with renderer
    input      [ 9:0]  table_addr,
    output reg [15:0]  table_data
);

reg frame, frame_n;
reg [ 1:0] st;
reg [ 9:0] wr_addr;
reg [15:0] wr_data;
reg        wr_en;
reg        wait_cycle;

// buffer (dual port RAM)
reg [15:0] table_buffer[0:(2**11)-1];

always @(posedge clk) begin
    if( wr_en ) table_buffer[ {frame_n, wr_addr[9:2], ~wr_addr[1:0]} ] <= wr_data;
end

always @(posedge clk, posedge rst) begin
    if( rst )
        table_data <= 16'd0;
    else
        table_data <= table_buffer[ {frame, table_addr} ];
end

`ifdef SIMULATION
// avoid X's
integer cnt, f;
initial begin
    //$display("OBJ table initialization OK");
    f=$fopen("obj.bin","rb");
    if( f==0 ) begin
        $display("WARNING: cannot open obj.bin");
    end else begin
        cnt=$fread(table_buffer,f);
        cnt=$fseek(f,0,0); // rewind
        cnt=$fread(table_buffer,f,1024 );
        $display("INFO: read %d bytes from obj.bin", cnt);
        $fclose(f);
    end
    //for(cnt=0;cnt<2**11;cnt=cnt+1) table_buffer[cnt]=16'd0;
    // $readmemh("vram_obj16.hex",table_buffer,0,1023);
    // $readmemh("vram_obj16.hex",table_buffer,1024,2047);
end
`endif

reg        restart;
reg [17:1] vram_cnt;
assign vram_addr = { vram_cnt[17:3], ~vram_cnt[2:1] };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        frame       <= 1'b0;
        frame_n     <= 1'b1;
        vram_cnt    <= 17'd0;
        // start by clearing the memory. Not very useful as it only clears one half of it, though.
        st          <= 2'd2;
        wr_addr     <= ~10'd0;
        wait_cycle  <= 1'b1; // this signals st'2 not to finish when wr_addr==~10'd0
        busreq      <= 1'b0;
        restart     <= 1'b0;
    end else begin
        if( obj_dma_ok && st!=2'd0 ) begin
            restart <= 1'b1;
            st      <= 2'd0;
        end else
        case( st )
            2'd0: begin
                wr_addr    <= 10'h3ff;
                wr_en      <= 1'b0;
                wait_cycle <= 1'b1;
                busreq     <= 1'b0;
                if( obj_dma_ok || restart ) begin // start of new frame, after blanking
                    vram_cnt  <= {vram_base[9:1], 8'd0};
                    // VRAM cache needs be cleared because otherwise if a sprite buffer end
                    // value was cached in the previous frame, this will be read and no
                    // objects will be displayed. The circuit would become locked in this state
                    // as the cache contents would stay fixed
                    busreq    <= 1'b1;
                    frame     <= ~frame;
                    frame_n   <=  frame;
                    st        <= 2'd3;      // one clock cycle to let cache clear propagate
                    restart   <= 1'b0;
                end
            end
            2'd1: if(pxl_cen) begin
                wait_cycle <= 1'b0;
                if(vram_ok && !wait_cycle && busack ) begin
                    if( vram_data[15:8]==8'hff && vram_cnt[2:1]==2'b00 ) begin
                        st     <= 2'd2; // fill
                        busreq <= 0;
                    end else begin                   
                        vram_cnt  <= vram_cnt + 17'd1;
                        wr_addr    <= wr_addr + 10'd1;
                        wr_data    <= vram_data;
                        wr_en      <= 1'b1;
                        wait_cycle <= 1'b1;
                        if( vram_cnt[10:1]== 10'h3ff ) st<=2'd0;
                    end
                end
            end
            2'd2: begin
                wait_cycle <= 1'b0;
                wr_addr    <= wr_addr + 10'd1;
                wr_data    <= 16'h0000;
                wr_en      <= 1'b1;
                vram_cnt  <= vram_cnt + 17'd1;
                if( vram_cnt[10:1]== 10'h3ff && !wait_cycle) st<=2'd0;
            end
            2'd3: begin
                if(busack) st <= 2'd1;
            end
        endcase
    end
end

endmodule
