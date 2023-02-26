/*  This file is part of JTDD.
    JTDD program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTDD program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTDD.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 2-12-2019 */

// Schematics 3-7/10 OBJ
// Object layer
// Max 32 sprites per line


module jtdd_obj(
    input              clk,
    input              rst,
    (*direct_enable*)  input pxl_cen,
    input              cen_Q,
    input      [ 8:0]  cpu_AB,
    input              obj_cs,
    input              cpu_wrn,
    input      [ 7:0]  cpu_dout,
    output     [ 7:0]  obj_dout,
    // screen
    input      [ 7:0]  HPOS,
    input      [ 7:0]  VPOS,
    input              flip,
    input              HBL,
    // ROM access
    output reg [18:0]  rom_addr,
    input      [15:0]  rom_data,
    input              rom_ok,
    output reg [ 7:0]  obj_pxl
);

// RAM area shared with CPU
reg  [ 8:0] ram_addr, scan;
reg  [ 2:0] offset;
reg  [ 4:0] maxline;
wire [ 8:0] next_scan = scan + 9'd5;
wire        scan_done = next_scan == 9'd510;

reg  last_HBL, wait_mem;
wire negedge_HBL = !HBL && last_HBL;

reg  [ 7:0] scan_y, scan_attr, scan_attr2, scan_id, scan_x;
wire [ 8:0] sumy = {1'b0, VPOS } + { 1'b0, scan_y };
wire inzone = &{ sumy[7:5], ~(obj_dout[0]^sumy[8]), sumy[4]|obj_dout[4] };

reg  copy_done;
reg  line, copy;
reg  ram_we;

reg [2:0] state;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        last_HBL <= 1'b0;
        scan     <= 9'd0;
        offset   <= 3'd0;
        line     <= 1'b1;
        state    <= 3'd0;
        maxline  <= 5'd0;
    end else begin
        last_HBL <= HBL;
        case( state )
            3'd0: if(negedge_HBL) begin // wait for non blanking
                state    <= state+3'd1;
                line     <= ~line;
                scan     <= 9'd0;
                offset   <= 3'd0;
                wait_mem <= 1'b1;
                maxline  <= 5'd0;
            end
            3'd1: begin // get object's y
                wait_mem <= 1'b0;
                if( !wait_mem ) begin
                    scan_y    <= obj_dout; // +0
                    offset   <= 3'd1;
                    wait_mem <= 1'b1;
                    state    <= state+3'd1;
                end
            end
            3'd2: begin // advance until a visible object is found
                wait_mem  <= 1'b0;
                if( !wait_mem ) begin
                    scan_attr <= obj_dout; // +1
                    if( !inzone || !obj_dout[7] /*enable bit*/ ) begin
                        if( !scan_done ) begin
                            state    <= 3'd1;
                            offset   <= 3'd0; // try next object
                            scan     <= next_scan;
                            wait_mem <= 1'b1;
                        end else begin
                            state    <= 3'd0; // wait for next line
                        end
                    end
                    else begin
                        scan_y <= sumy[7:0]; // update the value
                        offset <= 3'd3;
                        state  <= 3'd3;
                    end
                end else begin
                    offset <= 3'd2;
                end
            end
            3'd3: begin
                offset     <= 3'd4;
                scan_attr2 <= obj_dout; // +2
                state      <= 3'd4;
            end
            3'd4: begin
                scan_id <= obj_dout; // +3
                state   <= 3'd5;
            end
            3'd5: begin
                scan_x  <= obj_dout; // +4
                `ifdef DD2
                if( scan_attr[5:4]!=2'b00 )
                    scan_id[1:0] <= scan_id[1:0] + {1'b0, scan_y[4] };
                `else
                if( scan_attr[4])
                    scan_id[0] <= scan_id[0]^scan_y[4];
                `endif
                state   <= 3'd6;
                copy    <= 1'b1;
            end
            3'd6: begin
                copy <= 1'b0;
                if( copy_done ) begin
                    if( !scan_done & ~&maxline ) begin
                        state    <= 3'd1;
                        offset   <= 3'd0; // try next object
                        scan     <= next_scan;
                        wait_mem <= 1'b1;
                        maxline  <= maxline + 5'd1;
                    end else begin
                        state    <= 3'd0; // wait for next line
                    end                
                end
            end
            default: state <= 3'd0;
        endcase
    end
end

always @(*) begin
    ram_we    = obj_cs && !cpu_wrn;
    ram_addr  = obj_cs ? cpu_AB : ( scan + {5'd0,offset} );
end

jtframe_ram #(.AW(9),.SIMFILE("obj.bin")) u_ram(
    .clk    ( clk         ),
    .cen    ( cen_Q       ),
    .data   ( cpu_dout    ),
    .addr   ( ram_addr    ),
    .we     ( ram_we      ),
    .q      ( obj_dout    )
);

// pixel drawing
reg  [ 3:0] pxl_cnt=0;
wire [ 1:0] cnt_msb_next = pxl_cnt[3:2] + 2'd1;
reg  [ 8:0] posx;
reg  [15:0] shift;
reg         copying;
wire        hflip = ~scan_attr[3];
wire        vflip = scan_attr[2];
`ifdef DD2
wire [ 4:0] id_top= scan_attr2[4:0];
wire [ 3:0] pal   = {1'b0, scan_attr2[7:5]};
`else
wire [ 4:0] id_top= {1'b0, scan_attr2[3:0]};
wire [ 3:0] pal   = scan_attr2[7:4];
`endif
wire [ 3:0] col   = hflip ? shift[15:12] : shift[3:0];
reg         ok_dly;
reg  [ 3:0] wait_buf;

always @(posedge clk) begin
    wait_buf[0]   <= pxl_cen;
    wait_buf[3:1] <= wait_buf[2:0];
end


always @(posedge clk, posedge rst) begin
    if( rst ) begin
        copy_done <= 1'b0;
        copying   <= 1'b0;
        ok_dly    <= 1'b0;
        posx      <= 9'd0;
        shift     <= 0;
    end else begin
        ok_dly <= rom_ok;
        copy_done <= 1'b0;
        if( copy && !copying) begin
            copying <= 1'b1;
            pxl_cnt <= 4'd0;
            posx    <= { scan_attr[1], scan_x };
            ok_dly  <= 1'b0;
            rom_addr  <= { id_top, scan_id, scan_y[3:0]^{4{vflip}}, 
                2'b00^{2{hflip}} };
        end
        if( copying ) begin
            if(ok_dly && rom_ok && !wait_buf[0] ) begin
                pxl_cnt <= pxl_cnt+4'd1;
                if( pxl_cnt!=4'd0 ) posx <= posx + 9'd1;
                if(pxl_cnt==4'hf) begin
                    copy_done<=1'b1;
                    copying  <=1'b0;
                end
                shift <= hflip ? (shift<<4) : (shift>>4);
            end
            case( pxl_cnt[1:0] ) 
                2'b0: begin
                    shift     <= { 
                        rom_data[15], rom_data[11], rom_data[7], rom_data[3],
                        rom_data[14], rom_data[10], rom_data[6], rom_data[2],
                        rom_data[13], rom_data[ 9], rom_data[5], rom_data[1],
                        rom_data[12], rom_data[ 8], rom_data[4], rom_data[0] };
                end
                2'b1: begin
                    rom_addr  <= { id_top, scan_id, scan_y[3:0], 
                        cnt_msb_next^{2{hflip}} };
                end
                default:;
            endcase            
        end
    end
end

// Line buffers
reg  [7:0] rd_addr, ln_data;
reg  [9:0] ln_addr;
wire [7:0] ln_dout;
reg        ln_we;
reg        copying_dly;

localparam [7:0] obj_dly = 8'd6;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ln_we        <= 1'b0;
        ln_addr      <= 10'd0;
        rd_addr      <= 8'd0;
        ln_data      <= 8'd0;
        copying_dly  <= 1'b0;
    end
    else begin
        copying_dly <= copying & ok_dly & rom_ok;
        if( HBL ) begin // clear memory during the blank
            rd_addr <= 8'd0-obj_dly;
            ln_data <= 8'h0;
            ln_addr[8:0] <= ln_addr[8:0] + 9'd1;
            ln_we   <= 1'b1;
            obj_pxl <= 8'd0;
        end else begin
            ln_we        <= 1'b0;

            if( wait_buf[3] ) obj_pxl <= ln_dout;
            if( wait_buf[1] ) begin
                ln_addr <= { line, 1'b0, ~rd_addr };
                rd_addr <= rd_addr + 8'd1;
                ln_we   <= 1'b0;
            end
            else if( copying_dly && col!=4'd0 ) begin
                ln_addr <= { ~line, posx };
                ln_data <= { pal, col };
                ln_we   <= 1'b1;
            end
        end
    end
end

jtframe_ram #(.AW(10)) u_line(
    .clk    ( clk         ),
    .cen    ( 1'b1        ),
    .data   ( ln_data     ),
    .addr   ( ln_addr     ),
    .we     ( ln_we       ),
    .q      ( ln_dout     )
);

endmodule