//pcengine_game_controller_multitap.v
//***********************************************************************
//* Analogizer PCEngine SNAC openFPGA interface for the Analogue Pocket *
//***********************************************************************
// By @RndMnkIII. 
// Date: 01/2024 
// Release: 1.0

// Aquí he documentado el funcionamiento de los diferentes mandos de juegos a los que he ido dando soporte, basado en las capturas de datos
// realizadas con analizador lógico + generador de patrones:
//
// ************
// * PCEngine * Tested up 100KHz clr to clr (500KHz step)
// ************
//        <--------- 2BTN -------->
//        <----------------- 6BTN ---------------->
// STB    | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
//        .........
// CLR    :       :_______________________________
//         _______________         _______    
// SEL    /               \_______/       \_______
//        ________ _______ _______ _______ _______
// DATA      1    \ LDRU  X  RS21 X   0   X 6543  
//                    ^       ^       ^       ^
// SAMPLE             |       |       |       |
//                    1       2       3       4

// NEED TO CHECK THIS -+
//                     |
//                     V
//
//        <--------- 2BTN ------->
//        <----------------- 6BTN ------------------------>
// STB    | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |10 |11 |
//        | SCAN1                 | SCAN2                 |
//        .....                   .....                        
// CLR    :   :___________________:   :___________________
//         ___________             ___________    
// SEL    /           \___________/           \___________
//             _________ _________     _________ _________
// DATA   ____/ LDRU    X  RS21   \___/   0     X 6543  
//        ^       ^       ^       ^       ^       ^       
// SAMPLE         |       |               |       |
//                1       2               3       4
// TEST DATA 1        
// TEST DATA 2        
// POCKET INPUTS                                                                                                                                                                                                  
// 1  P1 up          DO
// 0  P1 down        D2
// 1  P1 left        D3
// 0  P1 right       D1
// 0  P1 y                                    D1    
// 1  P1 x                                    D0
// 0  P1 b                    D1
// 1  P1 a                    D0
// 1  P1 l1                                   D2
// 0  P1 r1                                   D3
// 0  P1 l2           --------------------------
// 0  P1 r2           --------------------------
// 0  P1 l3           --------------------------
// 0  P1 r3           --------------------------
// 0  P1 select               D2                
// 1  P1 start                D3                
//                                                                                                                                                           X
//P1 1010 0101 1000 0001
//      A    5    8    1 
//gtkwave
//p1 1010 0101 1000 0001
//    A581
// MULTITAP (x5 Controllers):
//     CLR	SEL	Active Port	Port 1 CLR	Port 1 SEL	Port 2 CLR	Port 2 SEL	Port 3 CLR	Port 3 SEL	Port 4 CLR	Port 4 SEL	Port 5 CLR	Port 5 SEL
// 1    L	H	None        H	        H	        H	        H	        H	        H	        H	        H	        H	        H
// 2    H	H	None        H	        H	        H	        H	        H	        H	        H	        H	        H	        H
// 3    L	H	1	        L	        H	        H	        H	        H	        H	        H	        H	        H	        H
// 4    L	L	1	        L	        L	        H	        H	        H	        H	        H	        H	        H	        H
// 5    L	H	2	        H	        H	        L	        H	        H	        H	        H	        H	        H	        H
// 6    L	L	2	        H	        H	        L	        L	        H	        H	        H	        H	        H	        H
// 7    L	H	3	        H	        H	        H	        H	        L	        H	        H	        H	        H	        H
// 8    L	L	3	        H	        H	        H	        H	        L	        L	        H	        H	        H	        H
// 9    L	H	4	        H	        H	        H	        H	        H	        H	        L	        H	        H	        H
// 10   L	L	4	        H	        H	        H	        H	        H	        H	        L	        L	        H	        H
// 11   L	H	5	        H	        H	        H	        H	        H	        H	        H	        H	        L	        H
// 12   L	L	5	        H	        H	        H	        H	        H	        H	        H	        H	        L	        L
`default_nettype none

module pcengine_game_controller_multitap #(parameter MASTER_CLK_FREQ=50_000_000)
(
    input wire i_clk,
	input wire i_rst,
    input wire [3:0] game_controller_type, //0x4 2btn, 0x5 6btn, 0x6 multitap
	input wire i_stb,
    output reg [15:0] player1_btn_state,
    output reg [15:0] player2_btn_state,
    output reg [15:0] player3_btn_state,
    output reg [15:0] player4_btn_state,
    output reg [15:0] player5_btn_state,
    output reg busy,

    //SNAC Game controller interface
    output wire o_clr,
    output wire o_sel,
    input wire [3:0] i_dat //data from controller
);
    //FSM states
    localparam [2:0] IDLE    = 3'b001;
    localparam [2:0] CLR     = 3'b010;
    localparam [2:0] PRE_CLR = 3'b011;
    localparam [2:0] DATA    = 3'b100;

    //store module settings
    reg [3:0] game_controller_type_r;

    reg [2:0] state /* synthesis preserve */;

    reg [4:0] counter;
    reg [4:0] scan_number;
    reg [4:0] counter_top_value;
    reg clr_internal;
    reg sel_internal;
    reg [11:0] pb1_r, pb2_r, pb3_r, pb4_r, pb5_r;

    wire sample_data;

    //always sample data at falling edge of o_clk starting and second clock pulse in latch phase.
    assign sample_data = ~counter[0] && i_stb && (counter > 0) && (counter <= counter_top_value);

    always @(posedge i_clk) begin
        game_controller_type_r <= game_controller_type;

        //detect any change on gamepad configuration and restart FSM at IDLE state.
        if(i_rst || (game_controller_type != game_controller_type_r)) begin
            state <= IDLE;
            pb1_r <= 12'hfff;
            pb2_r <= 12'hfff;
            pb3_r <= 12'hfff;
            pb4_r <= 12'hfff;
            pb5_r <= 12'hfff;
        end
        else begin
            if(i_stb) begin
                case(state)
                IDLE:
                    begin
                        //fetch data from last read

                        //button order from first to last
                        //0   1     2    3    4   5   6      7   8   9  10  11 
                        //UP  RIGHT DOWN LEFT I   II  SELECT RUN III IV  V  VI
                        //follow Pocket game controls order:                                    D           C           B           A           E           F
                        //                        up        down       left      right       btn_y       btn_x       btn_b       btn_a      btn_l1      btn_r1 btn_l2 btn_r2 btn_l3 btn_r3  select   start
                        //player_btn_state <= ~{pb_r[0],   pb_r[2],   pb_r[3],   pb_r[1],    pb_r[9],    pb_r[8],    pb_r[5],    pb_r[4],   pb_r[10],   pb_r[11],  1'b1,  1'b1,  1'b1,  1'b1,pb_r[6],pb_r[7]};

                        //                     START     SELECT   R3 L3 R2 L2 R1 L1 Y X        B         A        RIGH      LEFT      DOWN      UP 
                        player1_btn_state <= ~{pb1_r[7], pb1_r[6], 8'b11111111,                pb1_r[5], pb1_r[4],pb1_r[1], pb1_r[3], pb1_r[2], pb1_r[0]};
                        player2_btn_state <= ~{pb2_r[7], pb2_r[6], 8'b11111111,                pb2_r[5], pb2_r[4],pb2_r[1], pb2_r[3], pb2_r[2], pb2_r[0]};
                        player3_btn_state <= ~{pb3_r[7], pb3_r[6], 8'b11111111,                pb3_r[5], pb3_r[4],pb3_r[1], pb3_r[3], pb3_r[2], pb3_r[0]};
                        player4_btn_state <= ~{pb4_r[7], pb4_r[6], 8'b11111111,                pb4_r[5], pb4_r[4],pb4_r[1], pb4_r[3], pb4_r[2], pb4_r[0]};
                        player5_btn_state <= ~{pb5_r[7], pb5_r[6], 8'b11111111,                pb5_r[5], pb5_r[4],pb5_r[1], pb5_r[3], pb5_r[2], pb5_r[0]};

                        counter <= 0;
                        scan_number <= 0;
                        counter_top_value <= 5'd19;

                        sel_internal <= 1'b1;
                        clr_internal <= 1'b0;
                        busy <= 1'b1;
                        pb1_r <= 12'hfff;
                        pb2_r <= 12'hfff;
                        pb3_r <= 12'hfff;
                        pb4_r <= 12'hfff;
                        pb5_r <= 12'hfff;
                        state <= PRE_CLR;
                    end
                PRE_CLR: begin
                        sel_internal <= 1'b1;
                        clr_internal <= 1'b1;
                        state <= CLR;
                end

                CLR:
                    begin
                        counter <= counter + 1'b1;
                        sel_internal <= 1'b1;
                        clr_internal <= 1'b0;
                        pb1_r[3:0]  <= i_dat;
                        state <= DATA;
                    end
                DATA:
                    begin
                        counter <= counter + 1'b1; //should be start clocking at 3
                        //following data samples are get in DATA phase.
                        if(counter[0]) begin
                            sel_internal <= ~sel_internal;
                            scan_number <= scan_number + 1'b1;
                        end

                        if(sample_data) begin//read button state
                            case(scan_number)
                                //0:       pb1_r[3:0]  <= i_dat;
                                1:       pb1_r[7:4]  <= i_dat;
                                2:       pb2_r[3:0]  <= i_dat;
                                3:       pb2_r[7:4]  <= i_dat;
                                4:       pb3_r[3:0]  <= i_dat;
                                5:       pb3_r[7:4]  <= i_dat;
                                6:       pb4_r[3:0]  <= i_dat;
                                7:       pb4_r[7:4]  <= i_dat;                                
                                8:       pb5_r[3:0]  <= i_dat;
                                9:       pb5_r[7:4]  <= i_dat;                                
                                default: 
                                begin
                                        pb1_r       <= pb1_r;
                                        pb2_r       <= pb2_r;
                                        pb3_r       <= pb3_r;
                                        pb4_r       <= pb4_r;
                                        pb5_r       <= pb5_r;
                                end
                            endcase
                        end

                        //the gamepads buton state are fetched at the end of DATA phase 1101 0101
                        if(scan_number == 9) begin
                            state <= IDLE;
                            busy <= 1'b0;
                        end  
                    end
                default: state <= IDLE;
                endcase       
            end    
        end
    end

    assign o_clr = (game_controller_type_r == 4'h6) ? clr_internal : 1'b0;
    assign o_sel = (game_controller_type_r == 4'h6) ? sel_internal : 1'b0;
endmodule