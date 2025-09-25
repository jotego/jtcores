//**************************************************************
//* Analogizer SNAC openFPGA interface for the Analogue Pocket *
//**************************************************************
// By @RndMnkIII. 
// Date: 01/2024 
// Release: 1.0

// Aquí he documentado el funcionamiento de los diferentes mandos de juegos a los que he ido dando soporte, basado en las capturas de datos
// realizadas con analizador lógico + generador de patrones:
//
// ********
// * DB15 * Tested up 1MHz
// ********
//         
// STB    | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |10 |11 |12 |13 |14 |15 |16 |17 |18 |19 |20 |21 |22 |23 |24 |25 |26 |27 |28 |29 |30 |31 |32 |33 |34 |35 |36 |37 |38 |39 |40 |41 |42 |43 |44 |45 |46 |47 |48 |49 |   
//        ____         ___________________________________________________________________________________________________________________________________________________________________________________________
// LATCH      \_______/   
//         ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     
// CLK    /   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___
//         ___ ___________ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ 
// DATA   /   \   P1 D    X P1 C  X P1 B  X P1 A  X P1 RG X P1 LF X P1 DW X P1 UP X P2 RG X P2 LF X P2 DW X P2 UP X P1 F  X P1 E  X P1 SELX P1 ST X  P2 F X P2 E  X P2 SELX P2 ST X P2 D  X P2 C  X P2B   X P2 A  
//                    ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^
// SAMPLE             |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |
//                    1       2       3       4       5       6       7       8       9       10      11      12      13      14      15      16      17      18      19      20      21      22      23      24   
// TEST DATA 1        1       0       1       0       1       0       1       0       1       0       1       0       1       0       1       0       1       0       1       0       1       0       1       0
// TEST DATA 2        0       1       0       1       0       1       0       1       0       1       0       1       0       1       0       1       0       1       0       1       0       1       0       1
// POCKET INPUTS                                                                                                                                                                                                  
// 1  P1 up                                                                   X
// 0  P1 down                                                         X
// 1  P1 left                                                 X
// 0  P1 right                                        X 
// 0  P1 y            X
// 1  P1 x                    X  
// 0  P1 b                            X
// 1  P1 a                                    X
// 1  P1 l1                                                                                                                   X
// 0  P1 r1                                                                                                            X
// 0  P1 l2           -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// 0  P1 r2           -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// 0  P1 l3           -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// 0  P1 r3           -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// 0  P1 select                                                                                                                       X
// 1  P1 start                                                                                                                                X
// 1  P2 up                                                                                                   X       
// 0  P2 down                                                                                         X   
// 1  P2 left                                                                                 X  
// 0  P2 right                                                                        X
// 0  P2 y                                                                                                                                                                           X
// 1  P2 x                                                                                                                                                                                   X
// 0  P2 b                                                                                                                                                                                           X  
// 1  P2 a                                                                                                                                                                                                  X 
// 1  P2 l1                                                                                                                                                    X    
// 0  P2 r1                                                                                                                                             X
// 0  P2 l2            -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// 0  P2 r2            -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// 0  P2 l3            -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// 0  P2 r3            -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// 0  P2 select                                                                                                                                                      X 
// 1  P2 start                                                                                                                                                              X
//P1 1010 0101 1000 0001
//      A    5    8    1 
//P2 1010 0101 1000 0001
//      A    5    8    1 
//gtkwave
//p1 1010 0101 1000 0001
//    A581
//p2 1010 0101 1000 0001
//    A581
//          x
//   1111111
//   6543210987654321 
// ********
// * NES *  Tested up 1MHz
// ********
// STB    | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |10 |11 |12 |13 |14 |15 |16 |17 |18 |19 |20 |21 |22 |23 |24 |25 |26 |27 |28 |29 |30 |31 |32 |33 |34 |35 |
//             _______
// LATCH  ____/       \___________________________________________________________________________________________________________________________________
//                .....    ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___      
// CLK    ________.___.___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___
//        ____ ___________ _______ _______ _______ _______ _______ _______ _______ _______________________________________________________________________
// DATA       \  BTN A    X BTN B X SELECTX START X  UP   X DOWN  X LEFT  X RIGHT / 
//                    ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^    
// SAMPLE             |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |     
//                    0       1       2       3       4       5       6       7       8       9       10      11      12      13      14      15      16     
// POCKET INPUTS                                                                                                                                                                                                  
// P1 P2
//  0  1 P1 up                                        X
//  1  0 P1 down                                              X
//  0  1 P1 left                                                      X
//  1  0 P1 right                                                             X
//  0  0 P1 y         ------------------------------------------------------------------------------------------------------------------------------------
//  0  0 P1 x         ------------------------------------------------------------------------------------------------------------------------------------  
//  1  0 P1 b                 X
//  0  1 P1 a         X
//  0  0 P1 l1        ------------------------------------------------------------------------------------------------------------------------------------
//  0  0 P1 r1        ------------------------------------------------------------------------------------------------------------------------------------
//  0  0 P1 l2        ------------------------------------------------------------------------------------------------------------------------------------
//  0  0 P1 r2        ------------------------------------------------------------------------------------------------------------------------------------
//  0  0 P1 l3        ----------------------------------------------------------------------------------------------------------------------------------
//  0  0 P1 r3        ------------------------------------------------------------------------------------------------------------------------------------
//  0  1 P1 select                    X
//  1  0 P1 start                             X
// P1 0101 0010 0000 0001         <-  0101_0101 B START DOWN RIGHT
//       5    2    0    1
// P2 1010 0001 0000 0010         <-  1010_1010 A SELECT UP LEFT
//       A    1    0    2
//    1111111
//    6543210987654321 
//gtkwave
// P1 5201
// P2 A102
//
// ********
// * SNES * Tested up 200KHz
// ********
// STB    | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |10 |11 |12 |13 |14 |15 |16 |17 |18 |19 |20 |21 |22 |23 |24 |25 |26 |27 |28 |29 |30 |31 |32 |33 |34 |35 |
//             _______
// LATCH  ____/       \___________________________________________________________________________________________________________________________________ 
//                .....    ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     ___      
// CLK    ________.___.___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___  
//             __ _________ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______ _______  
// DATA   ___ /  \ BTN_B   X BTN_Y X SEL   X START X  UP   X DOWN  X LEFT  X RIGHT X BTN_A X BTN_X X TG_L  X TG_R  X   H   X   H   X   H   X   H   \______ 
//                    ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^       ^      
// SAMPLE             |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |     
//                    0       1       2       3       4       5       6       7       8       9       10      11      12      13      14      15      16    
// POCKET INPUTS                                                                                                                                                                                                   
// 0 P1 up                                            X                                                                                                   
// 1 P1 down                                                  X                                                                                            
// 2 P1 left                                                          X                                                                                       
// 3 P1 right                                                                 X                                                                                
// 4 P1 y                     X                                                                                                                                 
// 5 P1 x                                                                                     X                                                               
// 6 P1 b             X                                                                                                                                       
// 7 P1 a                                                                             X                                                                     
// 8 P1 l1                                                                                            X                                                        
// 9 P1 r1                                                                                                    X                                                  
//10 P1 l2            ------------------------------------------------------------------------------------------------------------------------------------
//11 P1 r2            ------------------------------------------------------------------------------------------------------------------------------------
//12 P1 l3            ------------------------------------------------------------------------------------------------------------------------------------
//13 P1 r3            ------------------------------------------------------------------------------------------------------------------------------------
//14 P1 select                        X
//15 P1 start                                 X
module serlatch_game_controller #(parameter MASTER_CLK_FREQ=53_600_000)
(
    input wire i_clk,
	input wire i_rst,
    input wire [3:0] game_controller_type, //0x0 DISABLED, 0x1 DB15, 0x2 NES, 0x3 SNES, 0x9 DB15 Fast, 0xB SNES SWAP A,B<->X,Y
    input wire i_stb,
    output reg [15:0] p1_btn_state,
    output reg [15:0] p2_btn_state,
    output reg busy,

    //SNAC Game controller interface
    output wire o_clk, //for  controller 1
    output wire o_clk2, //for  controller 2
    output wire o_lat, //shared for 2 controllers
    input wire i_dat1, //data from controller 1
    input wire i_dat2 //data from controller 2
);
    //FSM states
    localparam [2:0] IDLE  = 3'b001;
    localparam [2:0] LATCH = 3'b010;
    localparam [2:0] DATA  = 3'b100;

    //store module settings
    reg [3:0] game_controller_type_r;
    reg [2:0] state = IDLE;

    reg [5:0] counter;
    //reg [4:0] btn_cnt;
    reg [5:0] counter_top_value;
    reg latch_internal;
    reg clk_internal;
    reg [23:0] bstat_r;
    reg [15:0] p1b_r;
    reg [15:0] p2b_r;

    wire latch_level /* synthesis keep */;
    wire disable_clock_on_latch /* synthesis keep */;
    wire sample_data /* synthesis keep */;

    //always sample data at falling edge of o_clk starting and second clock pulse in latch phase.
    assign sample_data = ~counter[0] && i_stb && (counter > 1) && (counter <= counter_top_value);


    always @(posedge i_clk) begin
        //detect reset or any change on gamepad configuration and restart FSM at IDLE state.
        if(i_rst || (game_controller_type != game_controller_type_r)) begin
            state <= IDLE;
            //clear internal register button state
            p1b_r <= 16'hffff;
            p2b_r <= 16'hffff;
            bstat_r <= 24'hffffff;
        end

        game_controller_type_r <= game_controller_type;
        
        if(i_stb) begin
            case(state)
            IDLE:
                begin
                    //fetch data from last read
                    //set button status output
                        case(game_controller_type_r)
							4'h0: begin //DISABLED
                                p1_btn_state <= 16'd0;
                                p2_btn_state <= 16'd0;
							end
                            4'h1,4'h9: begin //DB15, DB15 FAST
                                // Pocket logic button order:
                                // [0]     dpad_up
                                // [1]     dpad_down
                                // [2]     dpad_left
                                // [3]     dpad_right
                                // [4]     face_a
                                // [5]     face_b
                                // [6]     face_x
                                // [7]     face_y
                                // [8]     trig_l1
                                // [9]     trig_r1
                                // [10]    trig_l2
                                // [11]    trig_r2
                                // [12]    trig_l3
                                // [13]    trig_r3
                                // [14]    face_select
                                // [15]    face_start      

                                //SNAC DB15 adapter button order from first to last
                                //  0   1   2   3   4   5   6   7   8   9  10  11  12  13    14   15  16  17    18   19  20  21  22  23 
                                //P1D,P1C,P1B,P1A,P1R,P1L,P1D,P1U,P2R,P2L,P2D,P2U,P1F,P1E,P1SEL,P1ST,P2F,P2E,P2SEL,P2ST,P2D,P2C,P2B,P2A
                                //follow Pocket game controls order:
                                //PLAYER1         START        SELECT       R3 L3 R2 L2     R1           L1           Y           X           B           A           RIGH        LEFT        DOWN        UP 
                                p1_btn_state <= ~{bstat_r[15], bstat_r[14], 4'b1111,        bstat_r[12], bstat_r[13], bstat_r[0], bstat_r[1], bstat_r[2], bstat_r[3], bstat_r[4], bstat_r[5], bstat_r[6], bstat_r[7]};

                                //PLAYER2         START        SELECT       R3 L3 R2 L2     R1           L1           Y            X            B            A            RIGH        LEFT        DOWN         UP
                                p2_btn_state <= ~{bstat_r[19], bstat_r[18], 4'b1111,        bstat_r[16], bstat_r[17], bstat_r[20], bstat_r[21], bstat_r[22], bstat_r[23], bstat_r[8], bstat_r[9], bstat_r[10], bstat_r[11]};
                            end
                            4'h2: begin //NES
                                //SNAC NES adapter button order from first to last
                                //  0   1   2   3   4   5   6   7   8   9  10  11  12 13 14 15
                                //  A   B SEL  ST  UP  DW  LF  RG   H   H   H   H   H  H  H  H

                                //follow Pocket game controls order:
                                //                START    SELECT        R3        L3     R2     L2     R1     L1    Y         X         B         A        RIGHT    LEFT     DOWN     UP
                                p1_btn_state <= ~{p1b_r[3],p1b_r[2],     1'b1,     1'b1,  1'b1,  1'b1,  1'b1,  1'b1, 1'b1,     1'b1,     p1b_r[1], p1b_r[0],p1b_r[7],p1b_r[6],p1b_r[5],p1b_r[4]};
                                p2_btn_state <= ~{p2b_r[3],p2b_r[2],     1'b1,     1'b1,  1'b1,  1'b1,  1'b1,  1'b1, 1'b1,     1'b1,     p2b_r[1], p2b_r[0],p2b_r[7],p2b_r[6],p2b_r[5],p2b_r[4]};
                            end
                            4'h3: begin //SNES
                                //SNAC SNES adapter button order from first to last
                                //  0   1   2   3   4   5   6   7   8   9  10  11  12 13 14 15
                                //  B   Y SEL  ST  UP  DW  LF  RG   A   X  LT  LR   H  H  H  H

                                //follow Pocket game controls order:
                                //                START    SELECT   R3     L3     R2     L2    R1         L1         Y         X         B         A        RIGHT    LEFT     DOWN      UP
                                p1_btn_state <= ~{p1b_r[3],p1b_r[2],1'b1,  1'b1,  1'b1,  1'b1, p1b_r[11], p1b_r[10], p1b_r[1], p1b_r[9], p1b_r[0], p1b_r[8],p1b_r[7],p1b_r[6], p1b_r[5],p1b_r[4]};
                                p2_btn_state <= ~{p2b_r[3],p2b_r[2],1'b1,  1'b1,  1'b1,  1'b1, p2b_r[11], p2b_r[10], p2b_r[1], p2b_r[9], p2b_r[0], p2b_r[8],p2b_r[7],p2b_r[6], p2b_r[5],p2b_r[4]};

                            end
                            4'hB: begin //SNES SWAP A,B <-> X,Y
                                //SNAC SNES adapter button order from first to last
                                //  0   1   2   3   4   5   6   7   8   9  10  11  12 13 14 15
                                //  B   Y SEL  ST  UP  DW  LF  RG   A   X  LT  LR   H  H  H  H

                                //follow Pocket game controls order:
                                //                START    SELECT   R3     L3     R2     L2    R1         L1         Y         X         B         A        RIGHT    LEFT     DOWN      UP
                                p1_btn_state <= ~{p1b_r[3],p1b_r[2],1'b1,  1'b1,  1'b1,  1'b1, p1b_r[11], p1b_r[10], p1b_r[0], p1b_r[8], p1b_r[1], p1b_r[9],p1b_r[7],p1b_r[6], p1b_r[5],p1b_r[4]};
                                p2_btn_state <= ~{p2b_r[3],p2b_r[2],1'b1,  1'b1,  1'b1,  1'b1, p2b_r[11], p2b_r[10], p2b_r[0], p2b_r[8], p2b_r[1], p2b_r[9],p2b_r[7],p2b_r[6], p2b_r[5],p2b_r[4]};

                            end
                            default:
                            begin //disabled
                            	p1_btn_state <= 16'd0;
								p2_btn_state <= 16'd0;                          
							end
                        endcase

                    //init counter and set initial LAT,CLK values on IDLE state
                    counter <= 6'd0;

					counter_top_value <= 6'd0;
					if     ((game_controller_type_r == 4'h1) || (game_controller_type_r == 4'h9))                                     counter_top_value <= 6'd48;
					else if((game_controller_type_r == 4'h2) || (game_controller_type_r == 4'h3) || (game_controller_type_r == 4'hB)) counter_top_value <= 6'd34;

                    latch_internal <= latch_level;
                    clk_internal <= disable_clock_on_latch ? 1'b0 : 1'b1; 
                    state <= LATCH;
                    busy <= 1'b1;
                    p1b_r <= 16'hffff;
                    p2b_r <= 16'hffff;
                    bstat_r <= 24'hffffff;
                end
            LATCH:
                begin
                    counter <= counter + 6'd1;
                    latch_internal <= ~latch_level;
                    clk_internal <= disable_clock_on_latch ? 1'b0 : ~clk_internal; 
                    
                    //first sample of data is available in LATCH phase.
                    if(sample_data) begin//read button state
                        if((game_controller_type_r == 4'h1) || (game_controller_type_r == 4'h9))  begin //if is selected DB15,DB15 FAST all button state is store in one 24bit register
                            bstat_r[0] <= i_dat1; //3->0, 5->1, 7->2, 9->3, ...
                            // $display("DB15 [LATCH] BTN_CNT:%d  i_dat1:%d", btn_cnt, i_dat1);
                        end
                        else begin
                            p1b_r[0] <= i_dat1;
                            p2b_r[0] <= i_dat2;
                        end
                    end

                    if(counter == 6'd2) begin 
                        state <= DATA; 
                        latch_internal <= latch_level;
                    end
                end
            DATA:
                begin
                    counter <= counter + 6'd1; //should be start clocking at 3
                    clk_internal <= ~clk_internal; 
                    //following data samples are get in DATA phase.
                    if(sample_data) begin//read button state
                        if((game_controller_type_r == 4'h1) || (game_controller_type_r == 4'h9) ) begin //if is selected DB15,DB15 FAST all button state is store in one 24bit register
                            bstat_r[((counter>>1)-1)] <= i_dat1; //3->0, 5->1, 7->2, 9->3, ...
                            //$display("DB15 [DATA] BTN_CNT:%d  i_dat1:%d r_dat[%d]:%d", btn_cnt, i_dat1, btn_cnt,bstat_r[btn_cnt]);
                        end
                        else if((game_controller_type_r == 4'h2) || (game_controller_type_r == 4'h3)  || (game_controller_type_r == 4'hB)) begin
                            p1b_r[((counter>>1)-1)] <= i_dat1;
                            p2b_r[((counter>>1)-1)] <= i_dat2;
                        end
                    end

                    //the gamepads buton state are fetched at the end of DATA phase
                    if(counter == counter_top_value) begin
                        state <= IDLE;
                        busy <= 1'b0;
                    end  
                end
            default: state <= IDLE;
            endcase       
        end    
    end

    //the DB15 SNAC interface uses active LOW latch signal, NES,SNES use active HIGH latch:
    //                -----   ------  ...
    //DB15 LATCH          |___|          
    //
    //                     ___  
    //NES,SNES LATCH _____|   |_____  ...

    assign latch_level = ((game_controller_type_r == 4'h1) || (game_controller_type_r == 4'h9))  ? 1'b1 : 1'b0; //DB15, DB15 FAST

    //the NES,SNES SNAC interfaces disable clock signal while are in LATCH phase
    //but internally the falling edge CLK is used for sample the button state
    //             ___  
    //LATCH ______|   |_________ ... 
    //       _           _   _ 
    //o_clk | |_________| |_| |_ ...
    //       _   _   _   _   _ 
    //CLK   | |_|X|_|X|_| |_| |_ ...
    //       ... 1 2 3 4 5 6 7 8 ...
    assign disable_clock_on_latch = ((game_controller_type_r != 4'h1) && (game_controller_type_r != 4'h9)) ? 1'b1 : 1'b0; //en caso de que sea controlador NES,SNES

    //counter values: 36 for NES,SNES, 50 for DB15
    assign o_clk  = (game_controller_type_r == 4'h0) ? 1'b0 : clk_internal;
    assign o_clk2 = (game_controller_type_r == 4'h0) ? 1'b0 : clk_internal;
    assign o_lat  = (game_controller_type_r == 4'h0) ? 1'b0 : latch_internal;
endmodule