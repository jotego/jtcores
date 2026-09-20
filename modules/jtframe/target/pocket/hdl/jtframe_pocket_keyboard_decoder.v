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

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 29-01-2025 */

// Analogue doc. https://www.analogue.co/developer/docs/bus-communication#pad

module jtframe_pocket_keyboard_decoder#(parameter
    KEYS=6,
	SKEYS=8,
    KW  =8
)(
    input            rst,
    input            clk,
    input         	 key_en,

    // pressed keys
    input   [KW-1:0] press0,press1,press2,
                     press3,press4,press5,
                     spress,

    // interface to PS2 transmitter
    output reg       released,
	output reg [7:0] key,
    input            tx_ready,
    output reg       tx_send
);

reg  [     3:0] cnt;

reg  [6*KW-1:0] scans_l;
reg  [  KW-1:0] scan0, scan1, scan2, scan3, scan4, scan5,
				shact, shact_l; // shift + alt + ctrl
wire [  KW-1:0] scan_nx;
wire	        busy, sbusy;


assign busy    = cnt < KEYS[3:0];
assign sbusy   = cnt < KEYS[3:0] + SKEYS[3:0];
assign scan_nx = scans_l[0+:KW];

function rel( input x );
	rel = scan_nx==scan0 || scan_nx==scan1 || scan_nx==scan2 ||
		  scan_nx==scan3 || scan_nx==scan4 || scan_nx==scan5;
	rel = ~rel;
endfunction

always @(posedge clk) begin
    if(rst) begin
        scan0    <= 0;  scan1   <= 0;  scan2   <= 0;
        scan3    <= 0;  scan4   <= 0;  scan5   <= 0;
        shact    <= 0;  shact_l <= 0;
        tx_send  <= 0;
        key      <= 0;
        released <= 0;
        scans_l  <= 0;
        cnt      <= 4'hf;
    end else begin
    	tx_send  <= 0;
    	if(tx_ready && !tx_send) begin
			cnt  <= cnt + 1'b1;
    		if(busy) begin
	    		if( scan_nx!=0 ) begin
		        	tx_send  <= 1;
		        	key      <= scan_nx;
		        	released <= rel(0);
	    		end
		        scans_l <= scans_l >> KW;
	    	end else if( sbusy ) begin
	    		shact   <= {shact[0],shact[KW-1:1]};
	    		shact_l <=  shact_l >> 1;
	    		if(shact_l[0]) begin
		        	tx_send  <= 1;
	    			released <= shact_l[0] & ~shact[0];
	    			key      <= {4'he, cnt-KEYS[3:0]};
	    		end
	    	end else begin
				cnt     <= 0;
    			shact_l <= shact;
    			scans_l <= {scan5, scan4, scan3, scan2, scan1, scan0};
				if(key_en) begin
	        		scan0 <= press0;
					scan1 <= press1;
					scan2 <= press2;
					scan3 <= press3;
					scan4 <= press4;
					scan5 <= press5;
					shact <= spress;
				end else
	    			{scan5, scan4, scan3, scan2, scan1, scan0, shact} <= 0;
    		end
    	end
    end
end

endmodule