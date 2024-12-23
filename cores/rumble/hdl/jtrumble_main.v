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
    Date: 5-4-2021 */

module jtrumble_main(
    input              rst,
    input              clk,
    input              clk_obj,
    input              cen8,
    output             cpu_cen,
    input              LVBL,   // vertical blanking when 0
    input              vmid,
    // Screen
    output  reg        pal_cs,
    output  reg        flip,
    // Sound
    output             sres_b, // Z80 reset
    output  reg [7:0]  snd_latch,
    // Characters
    input       [7:0]  char_dout,
    output      [7:0]  cpu_dout,
    output  reg        char_cs,
    input              char_busy,
    // scroll
    input       [7:0]  scr_dout,
    output  reg        scr_cs,
    input              scr_busy,
    output  reg [9:0]  scr_hpos,
    output  reg [9:0]  scr_vpos,
    // cabinet I/O
    input       [1:0]  cab_1p,
    input       [1:0]  coin,
    input       [5:0]  joystick1,
    input       [5:0]  joystick2,
    // BUS sharing
    output             bus_ack,
    input              bus_req,
    input   [ 8:0]     obj_AB,
    output  [12:0]     cpu_AB,
    output             RnW,
    output  [7:0]      obj_din,
    // ROM access
    output             rom_cs,
    output  reg [17:0] rom_addr,
    input       [ 7:0] rom_data,
    input              rom_ok,
    // DIP switches
    input              service,
    input              dip_pause,
    input  [7:0]       dipsw_a,
    input  [7:0]       dipsw_b
);

wire [15:0] A;
wire        AVMA;
wire        nRESET;
wire        cen_E, cen_Q;
reg         io_cs, ram_cs;
reg  [ 7:0] bank;
wire [ 7:0] mem_map, bank_addr0, bank_addr1, cpu_din,
            ram_data;
wire        RAM_we;

assign RAM_we     = ram_cs && !RnW;
assign bank_addr1 = { bank[7:4], A[15:12] };
assign bank_addr0 = { bank[3:0], A[15:12] };

reg        VMA, pre_cs;
reg        last_cs;

assign rom_cs = last_cs && pre_cs;
assign sres_b = 1;
assign cpu_AB = A[12:0];

always @(posedge clk or negedge nRESET) begin
    if(!nRESET) begin
        VMA      <= 1;
        last_cs  <= 0;
        rom_addr <= 0;
    end else begin
        last_cs <= pre_cs;
        if( cen_E ) begin
            VMA <= AVMA;
        end
        if( pre_cs ) rom_addr <= { mem_map[5:0], A[11:0] };
    end
end

always @(*) begin
    ram_cs  = 0;
    scr_cs  = 0;
    io_cs   = 0;
    pre_cs  = 0;
    char_cs = 0;
    pal_cs  = 0;
    if( VMA && nRESET ) begin
        casez(A[15:12])
            4'b000?: ram_cs = 1;
            4'b001?: scr_cs = 1; // 2-3
            4'b0100: io_cs  = A[3]; // 4
            default: begin
                pre_cs =  RnW;
                char_cs= !RnW && A[15:12]==4'h5;
                pal_cs = !RnW && A[15:12]==4'h7;
            end
        endcase
    end
end

jtframe_dual_ram #(.AW(13)) u_ram(
    // CPU
    .clk0   ( clk       ),
    .data0  ( cpu_dout  ),
    .addr0  ( A[12:0]   ),
    .we0    ( RAM_we    ),
    .q0     ( ram_data  ),
    // Object controller
    .clk1   ( clk_obj   ),
    .data1  (           ),
    .addr1  ({4'hf,obj_AB}),
    .we1    ( 1'b0      ),
    .q1     ( obj_din   )
);

always @(posedge clk or negedge nRESET) begin
    if( !nRESET ) begin
        scr_hpos  <= 0;
        scr_vpos  <= 0;
        snd_latch <= 0;
        flip      <= 0;
        bank      <= 0;
    end else if(cen_Q && io_cs && !RnW ) begin
        case(A[2:0])
            3'd0: bank <= cpu_dout;
            3'd1: begin
                flip   <= cpu_dout[0];
                // coin counters go here too
                // sres_b <= cpu_dout[4]; // it could be bit 5, not sure, they are toggled together
            end
            3'd2: scr_hpos[7:0] <= cpu_dout;
            3'd3: scr_hpos[9:8] <= cpu_dout[1:0];
            3'd4: scr_vpos[7:0] <= cpu_dout;
            3'd5: scr_vpos[9:8] <= cpu_dout[1:0];
            3'd6: snd_latch     <= cpu_dout;
            default:;
        endcase
    end
end

// CPU reset
jt12_rst u_rst(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .rst_n  ( nRESET    )
);

reg [7:0] cabinet;

always @(*) begin
    case( A[2:0])
        3'd0: cabinet = { coin, // COINS
                     service,
                     1'b1, // tilt?
                     2'h3, // undocumented
                     cab_1p }; // START
        3'd1: cabinet = { 2'b11, joystick1 };
        3'd2: cabinet = { 2'b11, joystick2 };
        3'd3: cabinet = dipsw_a;
        3'd4: cabinet = dipsw_b;
        default: cabinet = 8'hff;
    endcase
end

assign cpu_din = pre_cs  ? rom_data : (
                 ram_cs  ? ram_data : (
                 scr_cs  ? scr_dout : (
                 char_cs ? char_dout: (
                 io_cs   ? cabinet  : 8'hff ))));

// Bus access
reg nIRQ, nFIRQ, last_LVBL, last_vmid;
wire BS,BA;

assign bus_ack = BA && BS;

always @(posedge clk) if(cen_Q) begin
    last_LVBL <= LVBL;
    last_vmid <= vmid;
    if( {BS,BA}==2'b10 || rst ) begin
        nIRQ  <= 1'b1;
        nFIRQ <= 1'b1;
    end else begin
        if( last_LVBL && !LVBL ) nIRQ<=1'b0  | ~dip_pause; // when LVBL goes low
        if(!last_vmid &&  vmid ) nFIRQ<=1'b0 | ~dip_pause; // mid screen
    end
end

wire bus_busy = scr_busy | char_busy;

jtframe_6809wait u_wait(
    .rstn       ( nRESET    ),
    .clk        ( clk       ),
    .cen        ( cen8      ),
    .cpu_cen    ( cpu_cen   ),
    .dev_busy   ( bus_busy  ),
    .rom_cs     ( pre_cs    ),
    .rom_ok     ( rom_ok    ),
    .cen_E      ( cen_E     ),
    .cen_Q      ( cen_Q     )
);

/* verilator tracing_off */
mc6809i u_cpu (
    .clk     ( clk     ),
    .cen_E   ( cen_E   ),
    .cen_Q   ( cen_Q   ),
    .D       ( cpu_din ),
    .DOut    ( cpu_dout),
    .ADDR    ( A       ),
    .RnW     ( RnW     ),
    .BS      ( BS      ),
    .BA      ( BA      ),
    .nIRQ    ( nIRQ    ),
    .nFIRQ   ( nFIRQ   ),
    .nNMI    ( 1'b1    ),
    .nHALT   ( ~bus_req),
    .nRESET  ( nRESET  ),
    .nDMABREQ( 1'b1    ),
    // unused:
    .RegData (         ),
    .AVMA    ( AVMA    ),
    .BUSY    (         ),
    .LIC     (         ),
    .OP      (         )
);
/* verilator tracing_on */

jtrumble_banks u_banks(
    .msb_addr   ( bank_addr1   ),
    .lsb_addr   ( bank_addr0   ),
    .msb        ( mem_map[7:4] ),
    .lsb        ( mem_map[3:0] )
);

endmodule