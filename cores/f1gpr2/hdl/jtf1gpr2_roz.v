/*  SPDX-FileCopyrightText: © 2026 Andrea Bogazzi
    SPDX-License-Identifier: GPL-3.0-or-later
    Date: 25-10-2026 */

module jtf1gpr2_roz #(parameter CODEW=11, XOFFSET=27, YOFFSET=4, ROM_BYTES=4194304, PIPELINED=0)(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             hs, vs,
    input      [ 8:0] hdump, vdump,
    input             flip,

    input             cs,
    input      [ 4:1] addr,
    input      [15:0] din,
    input      [ 1:0] dsn,

    input      [ 7:0] roz_bank,

    output reg [12:1] rozv_addr,
    input      [15:0] rozv_dout,

    output reg [21:1] rom_addr,
    output reg        rom_cs,
    input      [15:0] rom_data,
    input             rom_ok,

    output     [ 7:0] pxl,
    output            on
);

wire [12:0] x, y;
reg  vs_dly, hs_l;
wire vs_eff = flip ? vs : vs_dly;

always @(posedge clk) begin
    hs_l <= hs;
    if( hs & ~hs_l ) vs_dly <= vs;
end

jt053936 #(
    .XOFFSET    ( XOFFSET   ),
    .YOFFSET    ( YOFFSET   )
) u_xy(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( pxl_cen   ),

    .din        ( din       ),
    .addr       ( addr      ),

    .hs         ( hs        ),
    .vs         ( vs_eff    ),
    .cs         ( cs        ),
    .dtackn     ( 1'b0      ),
    .dsn        ( dsn       ),
    .dma_n      (           ),

    .ldout      ( 16'd0     ),
    .lh         (           ),
    .la         (           ),

    .x          ( x         ),
    .xh         (           ),
    .y          ( y         ),
    .yh         (           ),
    .nx         (           ),
    .ny         (           ),
    .ob         (           ),

    .ioctl_addr ( 5'd0      ),
    .ioctl_din  (           )
);

localparam [2:0] S_IDLE=0, S_MAP_WAIT=1, S_MAP=2, S_WAIT=3, S_ROM=4, S_WRITE=5;
reg  [ 2:0] st;
reg  [ 3:0] col, col_req;
reg  [ 3:0] xl, yl, xl2;
reg  [15:0] gfx_word;
reg  [ 3:0] req_bank;
reg  [ 8:0] req_line, req_h;

(* ramstyle = "MLAB, no_rw_check" *) reg [41:0] requests[0:63];
reg  [ 5:0] rd_ptr, wr_ptr;
reg  [ 6:0] queued;
wire [41:0] head = requests[rd_ptr];
wire [ 8:0] next_line = vdump==9'd261 ? 9'd0 : vdump+9'd1;
wire        line_start = pxl_cen && hdump==0;
wire        capture = pxl_cen && hdump<9'd320 && next_line<9'd224;
wire        pop = queued!=0 && (PIPELINED!=0 ? (st==S_IDLE || st==S_WRITE) && map_age[1] : st==S_IDLE);
reg  [ 1:0] map_age;
wire        push = capture && (queued!=7'd64 || pop);
wire        overflow = capture && !push;

reg  [ 1:0] ready, failed;
reg  [ 8:0] tags[0:1];
reg  [ 8:0] written[0:1];
reg [319:0] populated[0:1];
reg         pixel_ready, valid;
reg  [ 7:0] display_pixel;
wire        write_bank = req_line[0];
wire        read_bank = vdump[0];
wire        write_current = tags[write_bank]==req_line &&
                            !(line_start && write_bank!=read_bank);
wire        line_we = st==S_WRITE && write_current;
wire        display_ready = ready[read_bank] && tags[read_bank]==vdump;
wire [ 7:0] line_data;
reg  [ 3:0] pix;

always @* begin
    case( xl2[1:0] )
        2'd0: pix = gfx_word[15:12];
        2'd1: pix = gfx_word[11: 8];
        2'd2: pix = gfx_word[ 7: 4];
        2'd3: pix = gfx_word[ 3: 0];
    endcase
end

jtframe_dual_ram #(
    .DW         ( 8                         ),
    .AW         ( 10                        )
) u_lines(
    .clk0       ( clk                       ),
    .data0      ( { col, pix }              ),
    .addr0      ( { write_bank, req_h }      ),
    .we0        ( line_we                   ),
    .q0         (                           ),
    .clk1       ( clk                       ),
    .data1      ( 8'd0                      ),
    .addr1      ( { read_bank, hdump }       ),
    .we1        ( 1'b0                      ),
    .q1         ( line_data                 )
);

always @(posedge clk) begin
    if( rst ) begin
        rd_ptr <= 0;
        wr_ptr <= 0;
        queued <= 0;
    end else begin
        if( push ) begin
            requests[wr_ptr] <= { roz_bank[3:0], next_line, hdump, y[9:0], x[9:0] };
            wr_ptr <= wr_ptr+6'd1;
        end
        if( pop ) rd_ptr <= rd_ptr+6'd1;
        case( { push, pop } )
            2'b10: queued <= queued+7'd1;
            2'b01: queued <= queued-7'd1;
            default:;
        endcase
    end
end

always @(posedge clk) begin
    if( rst ) begin
        ready         <= 0;
        failed        <= 0;
        tags[0]       <= 9'h1ff;
        tags[1]       <= 9'h1ff;
        written[0]    <= 0;
        written[1]    <= 0;
        populated[0]  <= 0;
        populated[1]  <= 0;
        pixel_ready   <= 0;
        valid         <= 0;
        display_pixel <= 8'hff;
    end else begin
        if( line_start ) begin
            ready[~read_bank]   <= 0;
            failed[~read_bank]  <= 0;
            tags[~read_bank]    <= next_line;
            written[~read_bank] <= 0;
            populated[~read_bank] <= 0;
        end
        if( overflow ) failed[~read_bank] <= 1;
        if( line_we ) begin
            written[write_bank] <= written[write_bank]+9'd1;
            populated[write_bank][req_h] <= 1'b1;
            if( req_h==9'd319 )
                ready[write_bank] <= written[write_bank]==9'd319 && !failed[write_bank];
        end
        pixel_ready   <= hdump<9'd320 && vdump<9'd224 &&
                         tags[read_bank]==vdump && populated[read_bank][hdump];
        valid         <= pixel_ready;
        display_pixel <= line_data;
    end
end

generate if( PIPELINED==0 ) begin : g_serial
    always @* map_age = 0;
always @(posedge clk) begin
    if( rst ) begin
        st         <= S_IDLE;
        rozv_addr  <= 0;
        col        <= 0;
        col_req    <= 0;
        xl         <= 0;
        yl         <= 0;
        xl2        <= 0;
        req_bank   <= 0;
        req_line   <= 0;
        req_h      <= 0;
        rom_cs     <= 0;
        rom_addr   <= 0;
        gfx_word   <= 0;
    end else case( st )
        S_IDLE: if( pop ) begin
            rozv_addr <= { head[19:14], head[9:4] };
            xl        <= head[3:0];
            yl        <= head[13:10];
            req_h     <= head[28:20];
            req_line  <= head[37:29];
            req_bank  <= head[41:38];
            st        <= S_MAP_WAIT;
        end
        S_MAP_WAIT: st <= S_MAP;
        S_MAP: begin
            rom_addr <= { req_bank[14-CODEW:0], rozv_dout[CODEW-1:0], yl, xl[3:2] };
            col_req  <= rozv_dout[15:12];
            rom_cs   <= 1;
            st       <= S_WAIT;
        end
        S_WAIT: st <= S_ROM;
        S_ROM: if( rom_ok ) begin
            gfx_word <= {rom_addr,1'b0}>=ROM_BYTES ? 16'd0 : rom_data;
            col      <= col_req;
            xl2      <= xl;
            rom_cs   <= 0;
            st       <= S_WRITE;
        end
        S_WRITE: st <= S_IDLE;
        default: st <= S_IDLE;
    endcase
end
end else begin : g_pipeline
    always @* rozv_addr = { head[19:14], head[9:4] };

    always @(posedge clk) begin
        if( rst || queued==0 || pop ) map_age <= 0;
        else if( !(&map_age) ) map_age <= map_age+2'd1;
    end

    always @(posedge clk) begin
        if( rst ) begin
            st         <= S_IDLE;
            col        <= 0;
            col_req    <= 0;
            xl         <= 0;
            yl         <= 0;
            xl2        <= 0;
            req_bank   <= 0;
            req_line   <= 0;
            req_h      <= 0;
            rom_cs     <= 0;
            rom_addr   <= 0;
            gfx_word   <= 0;
        end else case( st )
            S_IDLE, S_WRITE: begin
                if( pop ) begin
                    rom_addr <= { head[52-CODEW:38], rozv_dout[CODEW-1:0], head[13:10], head[3:2] };
                    col_req  <= rozv_dout[15:12];
                    xl2      <= head[3:0];
                    req_h    <= head[28:20];
                    req_line <= head[37:29];
                    rom_cs   <= 1;
                    st       <= S_WAIT;
                end else begin
                    rom_cs <= 0;
                    st <= S_IDLE;
                end
            end
            S_WAIT: st <= S_ROM;
            S_ROM: if( rom_ok ) begin
                gfx_word <= {rom_addr,1'b0}>=ROM_BYTES ? 16'd0 : rom_data;
                col      <= col_req;
                rom_cs   <= 0;
                st       <= S_WRITE;
            end
            default: st <= S_IDLE;
        endcase
    end
end endgenerate

assign on  = valid;
assign pxl = valid ? display_pixel : 8'hff;

`ifdef SIMULATION
integer sim_frame, sim_lines, sim_incomplete, sim_overflow, sim_late, sim_peak;
reg sim_vs;
always @(posedge clk) begin
    if( rst ) begin
        sim_frame      <= 0;
        sim_lines      <= 0;
        sim_incomplete <= 0;
        sim_overflow   <= 0;
        sim_late       <= 0;
        sim_peak       <= 0;
        sim_vs         <= 0;
    end else begin
        sim_vs <= vs;
        if( line_start && vdump<9'd224 ) begin
            sim_lines <= sim_lines+1;
            if( !display_ready ) sim_incomplete <= sim_incomplete+1;
        end
        if( overflow ) sim_overflow <= sim_overflow+1;
        if( st==S_WRITE && !write_current ) sim_late <= sim_late+1;
        if( {25'd0,queued}>sim_peak ) sim_peak <= {25'd0,queued};
        if( vs && !sim_vs ) begin
            $display("ROZ_PREFETCH frame=%0d lines=%0d incomplete=%0d overflow=%0d late=%0d peak_queue=%0d",sim_frame,sim_lines,sim_incomplete,sim_overflow,sim_late,sim_peak);
            sim_frame      <= sim_frame+1;
            sim_lines      <= 0;
            sim_incomplete <= 0;
            sim_overflow   <= 0;
            sim_late       <= 0;
            sim_peak       <= 0;
        end
    end
end
`endif

endmodule
