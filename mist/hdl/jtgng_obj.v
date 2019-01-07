/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */
    
`timescale 1ns/1ps

module jtgng_obj(
    input              rst,
    input              clk,     // 24 MHz
    input              cen6,    //  6 MHz
    // screen
    input              HINIT,
    input              LHBL,
    input              LVBL,
    input   [ 7:0]     V,
    input   [ 8:0]     H,
    input              flip,
    // shared bus
    output  reg [ 8:0] AB,
    input       [ 7:0] DB,
    input              OKOUT,
    output  reg        bus_req,        // Request bus
    input              bus_ack,    // bus acknowledge
    output  reg        blen,   // bus line counter enable
    // SDRAM interface
    output  reg [14:0] obj_addr,
    input       [15:0] objrom_data,
    // pixel output
    output  reg [ 5:0] obj_pxl
);

reg [1:0] bus_state;
reg over96;

localparam ST_IDLE=2'd0, ST_WAIT=2'd1,ST_BUSY=2'd2;
localparam MEM_PREBUF=1'd0,MEM_BUF=1'd1;

always @(posedge clk) 
    if( rst ) begin
        blen      <= 1'b0;
        bus_state <= ST_IDLE;
    end else if(cen6) begin
        case( bus_state )
            ST_IDLE: if( OKOUT ) begin
                    bus_req   <= 1'b1;
                    bus_state <= ST_WAIT;
                end
                else begin
                    bus_req <= 1'b0;
                    blen    <= 1'b0;
                end
            ST_WAIT: if( bus_ack && mem_sel == MEM_PREBUF && !LVBL ) begin
                blen      <= 1'b1;
                bus_state <= ST_BUSY;
            end
            ST_BUSY: if( AB==9'h180 ) begin
                bus_req <= 1'b0;
                blen    <= 1'b0;
                bus_state <= ST_IDLE;
            end
            default: bus_state <= ST_IDLE;
        endcase
    end

reg ABslow;
always @(posedge clk) if(cen6) begin
    if( !blen )
        {AB, ABslow} <= 10'd0;
    else begin
        {AB, ABslow} <= {AB, ABslow} + 1'b1;
    end
end

reg mem_sel;
always @(posedge clk)
    if(rst)
        mem_sel <= MEM_PREBUF;
    else if(cen6) begin
        mem_sel <= ~mem_sel;
    end


wire [9:0]  wr_addr = mem_sel==MEM_PREBUF ? {1'b0, AB } : 10'd0; 
reg  [8:0]  pre_scan;
wire [7:0]  ram_din = mem_sel==MEM_PREBUF ? DB : 8'd0;
wire [7:0]  ram_dout;
wire        ram_we  = mem_sel==MEM_PREBUF ? blen : 1'b0;

jtgng_dual_ram #(.aw(10)) objram (
    .clk        ( clk               ),
    .clk_en     ( cen6              ),
    .data       ( ram_din           ),
    .rd_addr    ( {1'b0, pre_scan } ),
    .wr_addr    ( wr_addr           ),
    .we         ( ram_we            ),
    .q          ( ram_dout          )
);

reg line;
localparam lineA=1'b0, lineB=1'b1;
reg [4:0] post_scan;
reg fill;
reg line_obj_we;
reg [1:0] trf_state, trf_next;

reg [7:0] VF;
always @(posedge clk) if(cen6) begin
    if( HINIT ) VF <= {8{flip}} ^ V;
end
//wire [7:0] VFx = (~(VF+8'd4))+8'd1;

localparam SEARCH=2'd1, WAIT=2'd2, TRANSFER=2'd3, FILL=2'd0;

always @(posedge clk) 
    if( rst )
        line <= lineA;
    else if(cen6) begin
        if( HINIT ) line <= ~line;
    end


always @(posedge clk) 
    if( rst ) begin
        trf_state <= SEARCH;
        line_obj_we <= 1'b0;
    end
    else if(cen6) begin
        case( trf_state )
            SEARCH: begin
                if( !LVBL ) begin
                    pre_scan <= 9'd2;
                    post_scan<= 5'd31; // store obj data in reverse order
                    // so we can print them in straight order while taking
                    // advantage of horizontal blanking to avoid graphich clash
                    fill <= 1'd0;
                end
                else begin
                    line_obj_we <= 1'b0;
                    //if( ram_dout[7:5] == VFx[7:5] ) begin
                    if( (ram_dout-8'd4)<VF && (ram_dout+8'd16)>VF  ) begin
                        pre_scan[1:0] <= 2'd0;
                        trf_next  <= TRANSFER;
                        trf_state <= WAIT;
                    end
                    else begin
                        if( pre_scan>=9'h17E ) begin
                            trf_next  <= FILL;
                            trf_state <= WAIT;
                            pre_scan <= 9'h180;
                            fill <= 1'b1;
                        end else begin
                            pre_scan <= pre_scan + 9'd4;
                            trf_state <= WAIT;
                            trf_next  <= SEARCH;
                        end
                    end
                end
            end
            WAIT: begin
                trf_state <= trf_next;
                if( trf_next==TRANSFER || trf_next==FILL ) line_obj_we <= 1'b1;
            end
            TRANSFER: begin
                line_obj_we <= 1'b0;
                if( post_scan == 5'h07 ) begin // Transfer done before the end of the line
                    if( HINIT ) begin
                        trf_state <= SEARCH;
                        pre_scan <= 9'd2;
                        post_scan <= 5'd31;
                        fill <= 1'd0;
                    end
                end
                else
                if( pre_scan[1:0]==2'b11 ) begin
                    post_scan <= post_scan-1'b1;
                    pre_scan <= pre_scan + 9'd3;
                    trf_state <= WAIT;
                    trf_next  <= SEARCH;
                end
                else begin
                    pre_scan[1:0] <= pre_scan[1:0]+1'b1;
                    trf_state <= WAIT;
                end
            end
            FILL: begin
                pre_scan <= pre_scan + 1'b1;
                if( pre_scan[1:0]==2'b11 ) post_scan <= post_scan - 1'b1;
                trf_next <= FILL;
                if( &pre_scan[1:0] && post_scan==5'd8 ) begin
                    pre_scan <= 9'd2;
                    post_scan<= 5'd31;
                    fill <= 1'd0;
                    trf_state <= WAIT;
                    trf_next <= SEARCH;
                    line_obj_we <= 1'b0;
                end
                else begin
                    line_obj_we <= 1'b0;
                    trf_state <= WAIT;
                end
            end
        endcase
    end


wire [7:0] q_a, q_b;
wire [7:0] objbuf_data = line==lineA ? q_b : q_a;

reg [7:0] ADlow;
reg [1:0] objpal;
reg [1:0] ADhigh;
reg [7:0] objy, objx;
reg [7:0] VB;
wire [7:0] posy;
wire [8:0] objx2;
reg obj_vflip, obj_hflip, hover;
wire posvflip, poshflip;
wire [1:0] pospal;
reg vinzone;
wire vinzone2;

jtgng_sh #(.width(8), .stages(3)) sh_objy (.clk(clk), .clk_en(cen6), .din(objy), .drop(posy));
jtgng_sh #(.width(9), .stages(3)) sh_objx (.clk(clk), .clk_en(cen6), .din({hover,objx}), .drop(objx2));
//jtgng_sh #(.width(1), .stages(4)) sh_objv (.clk(clk), .clk_en(cen6), .din(obj_vflip), .drop(posvflip));
jtgng_sh #(.width(1), .stages(5)) sh_objh (.clk(clk), .clk_en(cen6), .din(obj_hflip), .drop(poshflip));

reg poshflip2;
always @(posedge clk) if(cen6) begin
    poshflip2 <= poshflip;
end

jtgng_sh #(.width(2), .stages(7)) sh_objp (.clk(clk), .clk_en(cen6), .din(objpal), .drop(pospal));
jtgng_sh #(.width(1), .stages(4)) sh_objz (.clk(clk), .clk_en(cen6), .din(vinzone), .drop(vinzone2));

always @(*) begin
    //VB = posy + ( ~VF + {{7{~flip}},1'b1});
    // vinzone = &VB[7:4];
    VB = VF-objy;
    vinzone = (VF>=objy) && (VF<(objy+8'd16));
end

reg [4:0] objcnt;
reg [3:0] pxlcnt;
//wire [6:0] hscan = { H[8:4], H[1:0] };
wire [6:0] hscan = { objcnt, pxlcnt[1:0] };

always @(posedge clk) if(cen6) begin
    if( HINIT ) 
        { objcnt, pxlcnt } <= {5'd8,4'd0};
    else 
        if( objcnt != 5'd0 )  { objcnt, pxlcnt } <=  { objcnt, pxlcnt } + 1'd1;
end

always @(posedge clk) if(cen6) begin
    case( pxlcnt[3:0] )
        4'd0: ADlow   <= objbuf_data;
        4'd1: begin
            ADhigh    <= objbuf_data[7:6];
            objpal    <= objbuf_data[5:4];
            obj_vflip <= objbuf_data[3];
            obj_hflip <= objbuf_data[2];
            hover     <= objbuf_data[0];
        end
        4'd2: begin
            objy <= (objbuf_data-8'd2);
        end
        4'd3: begin
            objx <= objbuf_data;
        end
        default:;
    endcase
    if( pxlcnt[2:0]==3'd3 ) begin   
        obj_addr <= (!vinzone || objcnt==5'd0) ? 15'd0 : { ADhigh, ADlow, pxlcnt[3]^obj_hflip, VB[3:0]^{4{obj_vflip}} };
    end
end

reg [6:0] address_a, address_b;
reg we_a, we_b;
reg [7:0] data_a, data_b;

always @(*) begin
    data_a = fill ? 8'hf8 : ram_dout;
    data_b = fill ? 8'hf8 : ram_dout;
    if( line == lineA ) begin
        address_a = { post_scan, pre_scan[1:0] };
        address_b = hscan;
        we_a = line_obj_we;
        we_b = 1'b0;
    end
    else begin
        address_a = hscan;
        address_b = { post_scan, pre_scan[1:0] };
        we_a = 1'b0;
        we_b = line_obj_we;
    end
end

jtgng_ram #(.aw(7),.simfile("obj_buf.hex")) objbuf_a(
    .clk   ( clk       ),
    .cen   ( cen6      ),
    .addr  ( address_a ),
    .data  ( data_a    ),
    .we    ( we_a      ),
    .q     ( q_a       )
);

jtgng_ram #(.aw(7),.simfile("obj_buf.hex")) objbuf_b(
    .clk   ( clk       ),
    .cen   ( cen6      ),    
    .addr  ( address_b ),
    .data  ( data_b    ),
    .we    ( we_b      ),
    .q     ( q_b       )
);

// ROM data depacking

reg [3:0] z,y,x,w;
reg [3:0] new_pxl;
reg [8:0] posx;

reg [15:0] other_half;


always @(posedge clk) if(cen6) begin
    new_pxl <= poshflip2 ? {w[0],x[0],y[0],z[0]} : {w[3],x[3],y[3],z[3]};   
    posx    <= pxlcnt[3:0]==4'h8 ? objx2 : posx + 1'b1;
    case( pxlcnt[3:0] )
        4'd7,4'd15: if( poshflip )  begin // new data
            //{z,y,x,w} <= vinzone2 ? objrom_data[31:16] : 16'hffff;
				{z,y,x,w} <= vinzone2 ? objrom_data[15:0] : 16'hffff;
                other_half <= objrom_data[15:0];
            end
            else begin
                {z,y,x,w} <= vinzone2 ? objrom_data[15:0] : 16'hffff;
                //other_half <= objrom_data[31:16];
    				other_half <= objrom_data[15:0];
            end
        4'd11,4'd3: if( poshflip )  // get the second half
            {z,y,x,w} <= vinzone2 ? other_half : 16'hffff;
        else
            {z,y,x,w} <= vinzone2 ? other_half : 16'hffff;
        default: 
            if( poshflip ) begin
                z <= z >> 1;
                y <= y >> 1;
                x <= x >> 1;
                w <= w >> 1;
            end else begin
                z <= z << 1;
                y <= y << 1;
                x <= x << 1;
                w <= w << 1;
            end
    endcase
end

// Line colour buffer

reg [7:0] lineA_address_a, lineA_address_b;
reg [7:0] lineB_address_a, lineB_address_b;
reg [7:0] Hcnt;

wire [7:0] lineA_q_a, lineA_q_b;
wire [7:0] lineB_q_a, lineB_q_b;
wire [7:0] lineX_data = { 2'b11, pospal, new_pxl };

reg lineA_we_a, lineB_we_a, lineA_we_b, lineB_we_b;

reg pxlbuf_line;

always @(posedge clk)
    if( rst )
        pxlbuf_line <= lineA;
    else if(cen6) begin
        if( pxlcnt== 4'hf ) pxlbuf_line<=line; // to account for latency drawing the object
    end

always @(posedge clk) if(cen6) begin
    if( !LHBL ) Hcnt <= 8'd0;
    else Hcnt <= Hcnt+1'd1;
end

always @(*)
    if( pxlbuf_line == lineA ) begin 
        // lineA readout
        lineA_address_a = Hcnt;
        lineA_we_a = 1'b0;
        obj_pxl = lineA_q_a[5:0];
        // lineB writein
        lineB_address_a = {8{flip}} ^ posx[7:0];
        lineB_we_a = !posx[8] && (lineX_data[3:0]!=4'hf);
    end else begin
        // lineA writein
        lineA_address_a = {8{flip}} ^ posx[7:0];
        lineA_we_a = !posx[8] && (lineX_data[3:0]!=4'hf);
        // lineB readout
        lineB_address_a = Hcnt;
        lineB_we_a = 1'b0;
        obj_pxl = lineB_q_a[5:0];
    end

always @(posedge clk) if(cen6) begin
    if( pxlbuf_line == lineA ) begin
        // lineA clear after each pixel is readout
        lineA_address_b <= lineA_address_a;
        lineA_we_b <= 1'b1;
        // lineB port B unused
        lineB_we_b <= 1'b0;
    end
    else begin
        // lineA port A unused
        lineA_we_b <= 1'b0;
        // lineB clear after each pixel is readout
        lineB_address_b <= lineB_address_a;
        lineB_we_b <= 1'b1;
    end
end

jtgng_true_dual_ram #(.aw(8)) lineA_buf(
    .clk     ( clk             ),
    .clk_en  ( cen6            ),
    .addr_a  ( lineA_address_a ),
    .addr_b  ( lineA_address_b ),
    .data_a  ( lineX_data      ),
    .data_b  ( 8'hFF           ), // delete only
    .we_a    ( lineA_we_a      ),
    .we_b    ( lineA_we_b      ),
    .q_a     ( lineA_q_a       ),
    .q_b     (                 )
);

jtgng_true_dual_ram #(.aw(8)) lineB_buf(
    .clk     ( clk             ),
    .clk_en  ( cen6            ),
    .addr_a  ( lineB_address_a ),
    .addr_b  ( lineB_address_b ),
    .data_a  ( lineX_data      ),
    .data_b  ( 8'hFF           ), // delete only
    .we_a    ( lineB_we_a      ),
    .we_b    ( lineB_we_b      ),
    .q_a     ( lineB_q_a       ),
    .q_b     (                 )
);

endmodule // jtgng_char