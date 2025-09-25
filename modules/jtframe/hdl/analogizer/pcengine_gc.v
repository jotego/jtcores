//pcengine_gamecontroller.v
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
//         ___                     ___                        
// CLR    |   |___________________|   |___________________
//         ___________             ___________    
// SEL    /           \___________/           \___________
//             _________ _________     _________ _________
// DATA   ____/ LDRU    X  RS21   \___/   0     X 6543  
//        ^       ^       ^       ^       ^       ^       
// SAMPLE         |       |               |       |
//                1       2               3       4

module pcengine_game_controller #(parameter MASTER_CLK_FREQ=50_000_000, parameter PULSE_CLR_LINE=1'b0)
(
    input wire i_clk,
	input wire i_rst,
    input wire [3:0] game_controller_type, //0X4 2btn,0X5 6btn
	input wire i_stb,
    output reg [15:0] player_btn_state,
    output reg busy,

    //SNAC Game controller interface
    output wire o_clr,
    output wire o_sel,
    input wire [3:0] i_dat //data from controller
);


    //FSM states
    localparam [2:0] IDLE  = 3'b001;
    localparam [2:0] CLR   = 3'b010;
    localparam [2:0] DATA  = 3'b100;

    //store module settings
    reg [3:0] game_controller_type_r;

    wire pulse_clr = PULSE_CLR_LINE;

    reg [2:0] state /* synthesis preserve */;

    reg [3:0] counter;
    reg [3:0] scan_number;
    reg [3:0] counter_top_value;
    reg clr_internal;
    reg sel_internal;
    reg [11:0] pb_r;


    wire latch_level,disable_clock_on_latch;
    wire sample_data;

    reg btn6;

    //always sample data at falling edge of o_clk starting and second clock pulse in latch phase.
    assign sample_data = ~counter[0] && i_stb && (counter > 0) && (counter <= counter_top_value);

    always @(posedge i_clk) begin
        game_controller_type_r <= game_controller_type;

        //detect any change on gamepad configuration and restart FSM at IDLE state.
        if(i_rst || (game_controller_type != game_controller_type_r)) begin
            state <= IDLE;
            pb_r <= 12'hfff;
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

                        
                        if(game_controller_type_r == 4'h5) begin
                            //6btn mapping
                            //                    START    SELECT   R3 L3 R2 L2 R1        L1        Y        X        B        A        RIGH     LEFT     DOWN     UP 
                            player_btn_state <= ~{pb_r[7], pb_r[6], 4'b1111,    pb_r[11], pb_r[10], pb_r[9], pb_r[8], pb_r[5], pb_r[4], pb_r[1], pb_r[3], pb_r[2], pb_r[0]};
                        end
                        else if (game_controller_type_r == 4'h4) begin
                            //2btn mapping RUN+A = X, RUN+B = Y not implemented
                            //                    START    SELECT   R3 L3 R2 L2 R1 L1 Y     X     B        A        RIGH     LEFT     DOWN     UP 
                            player_btn_state <= ~{pb_r[7], pb_r[6], 6'b111111,        1'b1, 1'b1, pb_r[5], pb_r[4], pb_r[1], pb_r[3], pb_r[2], pb_r[0]};
                        end
                        else begin
                            player_btn_state <= 16'h0;
                        end
                        counter <= 0;
                        scan_number <= 0;
                        
                        // if     (game_controller_type_r == 5'd4) counter_top_value <= 4'd4;
                        // else if(game_controller_type_r == 5'd5) counter_top_value <= 4'd8;
                        counter_top_value <= 4'd4;
                        sel_internal <= 1'b1;
                        clr_internal <= pulse_clr;
                        busy <= 1'b1;
                        //if (~btn6) pb_r <= 12'hfff;
                        state <= CLR;
                    end
                CLR:
                    begin
                        counter <= counter + 4'b1;
                        if (counter == 1) begin
                            state <= DATA;
                            sel_internal <= 1'b1;
                            clr_internal <= 1'b0;
                        end
                    end
                DATA:
                    begin
                        counter <= counter + 4'b1; //should be start clocking at 3
                        //following data samples are get in DATA phase.
                        if(counter[0]) begin
                            sel_internal <= ~sel_internal;
                            scan_number <= scan_number + 4'b1;
                        end

                        if(sample_data) begin//read button state
                            case(scan_number)
                                0:  begin 
                                        if(i_dat == 4'b0000) begin
                                            btn6 <= 1'b1; 
                                            //pb_r[3:0]  <= pb_r[3:0]; 
                                        end 
                                        else begin 
                                            btn6 <= 1'b0; 
                                            pb_r[3:0]  <= i_dat; 
                                        end
                                    end
                                1:  begin
                                        if(btn6) begin
                                            pb_r[11:8] <= i_dat;
                                        end
                                        else begin
                                            pb_r[7:4]  <= i_dat;
                                        end
                                        //btn6 <= 1'b0; 
                                    end
                                // 3:       pb_r[11:8] <= i_dat;
                                default: pb_r       <= pb_r;
                            endcase
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
    end

    assign o_clr = (game_controller_type_r == 4'd0) ? 1'b0 : clr_internal;
    assign o_sel = (game_controller_type_r == 4'd0) ? 1'b0 : sel_internal;
endmodule