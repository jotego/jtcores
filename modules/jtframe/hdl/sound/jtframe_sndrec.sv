/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-6-2023 */

module jtframe_sndrec(
    input             rst,
    input             clk,
    input             v5, // 240 Hz
    input             we,
    input       [3:0] a,
    input       [7:0] din,

    output      [7:0] ioctl_din
);

localparam RECAW=13;

/* Encoding
    byte 0:
        00 -> EOF
        80 -> v5 pulse (once every 64 lines -rising edge of v5- )
        1x -> write to address a
    byte 1
        xx -> data written
*/

reg v5l, we_l, rec_we, do_data, rec_clrd, full;
reg [RECAW-1:0] reca;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        reca     <= 0;
        rec_clrd <= 0;
        recin    <= 0;
        rec_we   <= 0;
        do_data  <= 0;
        v5l      <= 0;
        we_l     <= 0;
        full     <= 0;
    end else begin
        if( !rec_clrd ) begin
            reca   <= reca+1'd1;
            recin  <= 0;
            rec_we <= 1;
            if( &reca ) begin
                rec_clrd <= 1;
                rec_we   <= 0;
            end
        end else if(!full) begin
            v5l  <= v5;
            we_l <= we;
            if( rec_we ) begin
                reca <= reca + 1'd1;
                rec_we <= 0;
            end
            if( v5 && !v5l ) do_v5 <= 1;
            if( we && !we_l ) begin
                recin   <= {4'd1,a};
                do_data <= 1;
                rec_we  <= 1;
            end else if( do_data ) begin
                recin   <= din;
                do_data <= 0;
                rec_we  <= 1;
            end else if( do_v5 ) begin
                rec_din <= 8'h80;
                rec_we  <= 1;
            end
            if( &reca ) full <= 1;
        end else begin // full
            rec_we <= 0;
        end
    end
end

jtframe_dual_ram #(.AW(RECAW) ) u_record( // 2kB, set in jtdef.go
    // Port 0: record
    .clk0   ( clk            ),
    .data0  ( recmux         ),
    .addr0  ( reca           ),
    .we0    ( rec_we         ),
    .q0     (                ),
    // Port 1: readout
    .clk1   ( clk            ),
    .data1  ( 8'd0           ),
    .addr1  (ioctl_addr[RECAW-1:0]),
    .we1    ( 1'b0           ),
    .q1     ( ioctl_din      )
);

endmodule
