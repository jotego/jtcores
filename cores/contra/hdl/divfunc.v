/////////////////////////////////////////////////////////////////////////////////////
//
//Copyright 2019  Li Xinbing
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//Unless required by applicable law or agreed to in writing, software
//distributed under the License is distributed on an "AS IS" BASIS,
//WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//See the License for the specific language governing permissions and
//limitations under the License.
//
/////////////////////////////////////////////////////////////////////////////////////

`define N(n)                       [(n)-1:0]
`define FFx(signal,bits)           always @ ( posedge clk or posedge  rst ) if (   rst   )  signal <= bits;  else

/* verilator lint_off WIDTH */
/* verilator lint_off UNOPTFLAT */

module divfunc
#(
    parameter                      XLEN          = 32,
    parameter `N(XLEN)             STAGE_LIST    = 0
)
(

    input              clk,
    input              rst,

    input  `N(XLEN)    a,
    input  `N(XLEN)    b,
    input              vld,


    output `N(XLEN)    quo,
    output `N(XLEN)    rem,
    output             ack

);

    reg               ready    `N(XLEN+1);
    reg `N(XLEN)      dividend `N(XLEN+1);
    reg `N(XLEN)      divisor  `N(XLEN+1);
    reg `N(XLEN)      quotient `N(XLEN+1);

    always@* begin
        ready[0]    = vld;
        dividend[0] = a;
        divisor[0]  = b;
        quotient[0] = 0;
    end

    generate
    	genvar i;
    	for (i=0;i<XLEN;i=i+1) begin:gen_div

            wire [i:0]      m = dividend[i]>>(XLEN-i-1);
            wire [i:0]      n = divisor[i][i:0];
    	    wire            q = (|(divisor[i]>>(i+1))) ? 1'b0 : ( m>=n );
    	    wire [i:0]      t = q ? (m - n) : m;
			wire [XLEN-1:0] u = dividend[i]<<(i+1);
    	    wire [XLEN+i:0] d = {t,u}>>(i+1);

            if (STAGE_LIST[XLEN-i-1]) begin:gen_ff
                `FFx(ready[i+1],0)
                ready[i+1] <= ready[i];

                `FFx(dividend[i+1],0)
                dividend[i+1] <= d;

                `FFx(divisor[i+1],0)
                divisor[i+1] <= divisor[i];

                `FFx(quotient[i+1],0)
                quotient[i+1] <= quotient[i]|(q<<(XLEN-i-1));

            end else begin:gen_comb
                always @* begin
                	ready[i+1]    = ready[i];
                	dividend[i+1] = d[0+:XLEN];
                    divisor[i+1]  = divisor[i];
                	quotient[i+1] = quotient[i]|(q<<(XLEN-i-1));
                end
            end
        end
    endgenerate

    assign quo = quotient[XLEN];

    assign rem = dividend[XLEN];

    assign ack = ready[XLEN];

endmodule

/* verilator lint_on WIDTH */
/* verilator lint_on UNOPTFLAT */
