/* verilator lint_off WIDTHEXPAND */
//primitive : SR latch
module primitive_srlatch (
    input   wire            i_S,
    input   wire            i_R,
    output  reg             o_Q
);

always @(*) begin
    case({i_S, i_R})
        2'b00: o_Q = o_Q;
        2'b01: o_Q = 1'b0;
        2'b10: o_Q = 1'b1;
        2'b11: o_Q = 1'b0; //invalid
    endcase
end

endmodule

//primitive : D latch
module primitive_dlatch #(parameter WIDTH = 8 ) (
    input   wire                    i_EN,
    input   wire    [WIDTH-1:0]     i_D,
    output  reg     [WIDTH-1:0]     o_Q
);

always @(*) begin
    if(i_EN) o_Q = i_D;
    else o_Q = o_Q;
end

endmodule

//primitive : synchronous SR latch
module primitive_syncsrlatch (
    input   wire            i_EMUCLK,
    input   wire            i_RST_n,

    input   wire            i_S,
    input   wire            i_R,
    output  reg             o_Q
);

always @(posedge i_EMUCLK) begin
    if(!i_RST_n) o_Q <= 1'b0;
    else begin
        case({i_S, i_R})
            2'b00: o_Q <= o_Q;
            2'b01: o_Q <= 1'b0;
            2'b10: o_Q <= 1'b1;
            2'b11: o_Q <= 1'b0; //invalid
        endcase
    end
end

endmodule

//primitive : synchronous D latch
module primitive_syncdlatch #(parameter WIDTH = 8 ) (
    input   wire                    i_EMUCLK,
    input   wire                    i_RST_n,

    input   wire                    i_EN,
    input   wire    [WIDTH-1:0]     i_D,
    output  reg     [WIDTH-1:0]     o_Q
);

always @(posedge i_EMUCLK) begin
    if(!i_RST_n) o_Q <= {WIDTH{1'b0}};
    else begin
        if(i_EN) o_Q <= i_D;
        else o_Q <= o_Q;
    end
end

endmodule

//primitive : YM2151 counter
module primitive_counter #(parameter WIDTH = 4 ) (
    input   wire                    i_EMUCLK,
    input   wire                    i_PCEN_n,
    input   wire                    i_NCEN_n,

    input   wire                    i_CNT,
    input   wire                    i_LD,
    input   wire                    i_RST,

    input   wire    [WIDTH-1:0]     i_D,
    output  wire    [WIDTH-1:0]     o_Q,
    output  wire                    o_CO
);

/*

                ext DFF    <-four counter cells->
    comb logic     +-------+------+------+------+-------> COUT
                   |       |      |      |      |
    carry DFF    [CIN]    [0]    [1]    [2]    [3]   (negedge of phi1)
            
    counter DFF  [DIN] -> [0]    [1]    [2]    [3]   (posedge of phi1)
                           |      |      |      |                        
                           V      V      V      V
                                    QOUT

    All YM2151 counter works really weird.

    1. Count up
    First, on this falling edge, the external DFF stores the CNT signal.
    Since this is before the "next" rising edge, the counter value is not
    incremented when the CNT signal is entered. This unaltered counter value
    is also "copied" to the carry DFFs on this edge. The copied counter value
    and the CNT input are passed through combinational logic to generate
    the carry.

    On the next rising edge, the counter DFFs incremented based on the value
    of carry DFFs. However, the carry DFFs do not latch this new changed 
    counter value. Therefore, even though the counter value changes, the carry
    output is maintained until the next falling edge.

    2. Reset and Preload
    The reset and preload signals are externally triggered on the falling edge.
    Counter DFFs fetche or reset its value on the next rising edge. The carry
    changes on the next falling edge.
*/

localparam COUNTER_MAX = (2**WIDTH) - 1;
reg     [WIDTH-1:0]     counter;
reg                     counter_full;

always @(posedge i_EMUCLK) begin
    if(!i_PCEN_n) begin
        if(i_RST) counter <= {WIDTH{1'b0}};
        else begin
            if(i_LD) counter <= i_D;
            else begin
                if(i_CNT) begin
                    counter <= (counter == COUNTER_MAX) ? {WIDTH{1'b0}} : counter + {{(WIDTH - 1){1'b0}}, 1'b1};
                end
            end
        end
    end

    if(!i_NCEN_n) begin
        counter_full <= counter == COUNTER_MAX;
    end
end

assign  o_CO = counter_full & i_CNT;
assign  o_Q = counter;

endmodule


module primitive_sr #(parameter WIDTH = 1, parameter LENGTH = 32, parameter TAP = 32 ) (
    input   wire                    i_EMUCLK,
    input   wire                    i_CEN_n, 

    input   wire    [WIDTH-1:0]     i_D,
    output  wire    [WIDTH-1:0]     o_Q_TAP,
    output  wire    [WIDTH-1:0]     o_Q_LAST
);

reg     [WIDTH-1:0]     sr[0:LENGTH-1];

//first stage
always @(posedge i_EMUCLK) begin
    if(!i_CEN_n) begin
        sr[0] <= i_D;
    end
end

//the other stages
genvar stage;
generate
for(stage = 0; stage < LENGTH-1; stage = stage + 1) begin : primitive_sr
    always @(posedge i_EMUCLK) if(!i_CEN_n) begin
        sr[stage + 1] <= sr[stage];
    end
end
endgenerate

assign  o_Q_LAST = sr[LENGTH-1];
assign  o_Q_TAP = (TAP == 0) ? i_D : sr[TAP-1];

endmodule


module primitive_sr_bram #(parameter WIDTH = 1, parameter LENGTH = 32, parameter TAP = 32 ) (
    input   wire                    i_EMUCLK,
    input   wire                    i_CEN_n,

    input   wire                    i_CNTRRST,
    input   wire                    i_WR,

    input   wire    [WIDTH-1:0]     i_D,
    output  reg     [WIDTH-1:0]     o_Q_TAP
);

//calculate counter bits
function integer length_bin (input integer length); 
    integer iter;
begin
    iter = 0;
    while(2**iter < length) begin
        iter = iter + 1;
    end
    length_bin = iter;
end
endfunction

//define wr/rd counter reset value
localparam  LENGTH_BIN = length_bin(LENGTH);
localparam  WRCNTR_INIT = 0;
localparam  RDCNTR_INIT = {LENGTH - (TAP - 1)};

//write and read counter
reg     [LENGTH_BIN-1:0]    wrcntr;
reg     [LENGTH_BIN-1:0]    rdcntr;
always @(posedge i_EMUCLK) if(!i_CEN_n) begin
    if(i_CNTRRST) begin
        wrcntr <= WRCNTR_INIT[LENGTH_BIN-1:0];
        rdcntr <= RDCNTR_INIT[LENGTH_BIN-1:0];
    end
    else begin
        wrcntr <= (wrcntr < LENGTH - 1) ? wrcntr + {{(LENGTH_BIN - 1){1'b0}}, 1'b1} : {LENGTH_BIN{1'b0}}; // +1 or reset
        rdcntr <= (rdcntr < LENGTH - 1) ? rdcntr + {{(LENGTH_BIN - 1){1'b0}}, 1'b1} : {LENGTH_BIN{1'b0}};
    end
end

//declare inferred bram
reg     [WIDTH-1:0]     sr_bram[0:LENGTH-1];

integer i;
initial begin
    for(i=0; i<LENGTH; i=i+1) sr_bram[i] = {WIDTH{1'b0}};
end

//BRAM write
always @(posedge i_EMUCLK) if(!i_CEN_n) begin
    if(i_WR) sr_bram[wrcntr] <= i_D;
end

//BRAM read
always @(posedge i_EMUCLK) if(!i_CEN_n) begin
    o_Q_TAP <= sr_bram[rdcntr];
end


endmodule
