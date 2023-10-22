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
    Date: 30-10-2021 */

module jts16b_cabinet(
    input             rst,
    input             clk,
    input             LHBL,
    input      [ 7:0] game_id,

    // CPU
    input      [23:1] A,
    input      [15:0] cpu_dout,
    input             LDSWn,
    input             UDSWn,
    input             LDSn,
    input             UDSn,
    input             io_cs,

    // DIP switches
    input             dip_test,
    input      [ 7:0] dipsw_a,
    input      [ 7:0] dipsw_b,

    // cabinet I/O
    input      [ 7:0] joystick1,
    input      [ 7:0] joystick2,
    input      [ 7:0] joystick3,
    input      [ 7:0] joystick4,
    input      [15:0] joyana1,
    input      [15:0] joyana1b, // used by Heavy Champ
    input      [15:0] joyana2,
    input      [15:0] joyana2b, // used by SDI
    input      [15:0] joyana3,
    input      [15:0] joyana4,
    input      [ 3:0] cab_1p,
    input      [ 3:0] coin,
    input             service,

    output     [ 7:0] sys_inputs,
    output reg [ 7:0] cab_dout,
    output reg        flip,
    output reg        video_en,

    input      [ 7:0] debug_bus
);

localparam [7:0] GAME_HWCHAMP =`GAME_HWCHAMP ,
                 GAME_PASSSHT =`GAME_PASSSHT ,
                 GAME_SDIBL   =`GAME_SDIBL   ,
                 GAME_PASSSHT2=`GAME_PASSSHT2,
                 GAME_DUNKSHOT=`GAME_DUNKSHOT,
                 GAME_EXCTLEAG=`GAME_EXCTLEAG,
                 GAME_BULLET  =`GAME_BULLET  ,
                 GAME_PASSSHT3=`GAME_PASSSHT3,
                 GAME_AFIGHTAN=`GAME_AFIGHTAN,  // Action Fighter, analogue controls
                 GAME_SDI     =`GAME_SDI     ;

reg  game_passsht, game_dunkshot, game_bullet,
     game_exctleag, game_sdi, game_afightan;

// Game ID registers
always @(posedge clk) begin
    game_passsht  <= game_id==GAME_PASSSHT2 || game_id==GAME_PASSSHT3 || game_id==GAME_PASSSHT;
    game_dunkshot <= game_id==GAME_DUNKSHOT;
    game_bullet   <= game_id==GAME_BULLET;
    game_exctleag <= game_id==GAME_EXCTLEAG;
    game_afightan <= game_id==GAME_AFIGHTAN;
    game_sdi      <= game_id==GAME_SDI || game_id==GAME_SDIBL;
end

reg [ 7:0] sort1, sort2, sort3;
reg        last_iocs;

wire [7:0] sort1_bullet, sort2_bullet, sort3_bullet,
           sort_dunkshot;

assign sort1_bullet = { sort1[3:0], sort1[7:4] };
assign sort2_bullet = { sort2[3:0], sort2[7:4] };
assign sort3_bullet = { sort3[3:0], sort3[7:4] };
assign sort_dunkshot= { joystick4[5:4], joystick3[5:4], joystick2[5:4], joystick1[5:4] };

function [7:0] sort_joy( input [7:0] joy_in );
    sort_joy = { joy_in[1:0], joy_in[3:2], joy_in[7], joy_in[5:4], joy_in[6] };
endfunction

always @(*) begin
    sort1 = sort_joy( joystick1 );
    sort2 = sort_joy( joystick2 );
    sort3 = sort_joy( joystick3 );
end

wire [8:0] joyana_sum = {joyana1[15], joyana1[15:8]} + {joyana2[15], joyana2[15:8]};
reg  [7:0] ana_in;
assign sys_inputs = { 2'b11, cab_1p[1:0], service, dip_test, coin[1:0] };

function [7:0] pass_joy( input [7:0] joy_in );
    pass_joy = { joy_in[7:4], joy_in[1:0], joy_in[3:2] };
endfunction

function [7:0] dunkshot_joy( input [11:0] tb );
    dunkshot_joy = !A[1] ? tb[7:0] : {4'd0,tb[11:8]};
endfunction

wire [11:0] trackball[0:7];
reg         shift_en;

jts16_trackball u_trackball(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .LHBL       ( LHBL          ),

    .right_en   ( game_sdi      ),

    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .joystick3  ( joystick3     ),
    .joystick4  ( joystick4     ),
    .joyana1    ( joyana1       ),
    .joyana1b   ( joyana1b      ), // used by Heavy Champ
    .joyana2    ( joyana2       ),
    .joyana2b   ( joyana2b      ), // used by SDI
    .joyana3    ( joyana3       ),
    .joyana4    ( joyana4       ),

    .trackball0 ( trackball[0]  ),
    .trackball1 ( trackball[1]  ),
    .trackball2 ( trackball[2]  ),
    .trackball3 ( trackball[3]  ),
    .trackball4 ( trackball[4]  ),
    .trackball5 ( trackball[5]  ),
    .trackball6 ( trackball[6]  ),
    .trackball7 ( trackball[7]  )
);

// Heavy Champ
// The handle is centred at 20h, pulling it can take it to 0
// pushing it takes it to FFh. This means that the two regions
// are not mapped with the same sensitivity to the analogue stick
reg  [7:0] hwchamp_left, hwchamp_right, hwchamp_monitor;

function [7:0] hwchamp_handle( input [7:0] anain );
    hwchamp_handle = !anain[7] ? 8'h20-{ 3'd0, anain[6:2]} :
        ~({1'b0, anain[6:0]} + {2'b0,anain[6:1]} + {3'b0,anain[6:2]});
endfunction

always @(*) begin
    hwchamp_left  = hwchamp_handle( joyana1b[15:8] );
    hwchamp_right = hwchamp_handle( joyana1[15:8] );
    hwchamp_monitor = {joyana1[7],joyana1[7:1]}+{joyana1b[7],joyana1b[7:1]};
    hwchamp_monitor[7] = ~hwchamp_monitor[7];
end

`ifdef SIMULATION
`ifdef DISPLAY_IO
reg displayed=0, displ_wr=0, io_csl;
always @(posedge clk) begin
    io_csl <= io_cs;
    if( (io_csl && !io_cs && !displayed)
        || (io_cs && (!LDSWn || !UDSWn) )
    ) begin
        $display("io access: %6X, A[13:12]=%X, A[2:1]=%X - %s - %d%d%d",
            A, A[13:12],A[2:1], (!LDSWn||!UDSWn) ? "wr" : "rd",
            game_bullet, game_dunkshot, game_exctleag );
        displayed <= 1;
    end
    if(!io_csl) begin
        displayed<=0;
    end
end
`endif
`endif

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cab_dout <= 8'hff;
        flip     <= 0;
        video_en <= 1;
        shift_en <= 0;
    end else begin
        cab_dout  <= 8'hff;
        if(!io_cs && shift_en) begin
            ana_in   <= ana_in << 1;
            shift_en <= 0;
        end
        if(io_cs) case( A[13:12] )
            0: if( !LDSWn ) begin // $000x
                flip     <= cpu_dout[6];
                video_en <= cpu_dout[5];
            end
            1: // $100x
                case( A[2:1] )
                    0: begin  // Service
                        cab_dout <= sys_inputs;
                        if( game_bullet ) begin
                            cab_dout[7] <= coin[2];
                            cab_dout[6] <= cab_1p[2];
                        end
                        if( game_passsht | game_dunkshot )  begin
                            cab_dout[7:6] <= cab_1p[3:2];
                        end
                        if( game_sdi ) begin
                            cab_dout[7:6] <= { joystick2[4], joystick1[4] };
                        end
                    end
                    1: begin  // P1
                        cab_dout <= game_bullet ? sort1_bullet :
                            game_dunkshot ? sort_dunkshot :
                            game_exctleag ? { trackball[1][11:9], trackball[1][11:10], trackball[1][11:9] } :
                            game_afightan ? { joystick1[7:4], 1'b1,
                                // The accelerator is hot-one encoded in 3 bits
                                joyana1[15:14]==2'b10 ? ~3'b100 :
                                joyana1[15:14]==2'b11 ? ~3'b010 :
                                joyana1[15:14]==2'b00 ? ~3'b001 : ~3'b0
                                } : // accelerator
                            sort1;
                    end
                    2: begin
                        if( game_bullet ) cab_dout <= sort3_bullet;
                        if( game_sdi    ) cab_dout <= { sort2[7:4], sort1[7:4] };
                        if( game_afightan )
                            cab_dout <=  // right side of driving wheel (hot one)
                              ~(joyana1[7] ? 8'h00 :
                                joyana1[6] ? 8'h80 :
                                joyana1[5] ? 8'h40 :
                                joyana1[4] ? 8'h20 :
                                joyana1[3] ? 8'h10 :
                                joyana1[2] ? 8'h08 :
                                joyana1[1] ? 8'h04 :
                                joyana1[0] ? 8'h02 : 8'h01);
                    end
                    3: begin  // P2
                        cab_dout <= game_bullet ? sort2_bullet :
                            game_exctleag ? { trackball[3][11:9], trackball[3][11:10], trackball[3][11:9] } :
                            game_afightan ? ~(   // left side of driving wheel (hot one)
                                !joyana1[7] ? 8'h00 :
                                !joyana1[6] ? 8'h80 :
                                !joyana1[5] ? 8'h40 :
                                !joyana1[4] ? 8'h20 :
                                !joyana1[3] ? 8'h10 :
                                !joyana1[2] ? 8'h08 :
                                !joyana1[1] ? 8'h04 :
                                !joyana1[0] ? 8'h02 : 8'h01
                            ):
                            sort2;
                    end
                endcase
            2: cab_dout <= { A[1] ? dipsw_a : dipsw_b }; // $200x
            3: begin // $300x - custom inputs
                case( game_id )
                    GAME_HWCHAMP: begin // Heavy Champion
                        if( A[5:4]==2 && (!LDSn || !UDSn)) begin
                            if (!LDSWn || !UDSWn) begin // load value in shift reg
                                case( A[2:1])
                                    0: ana_in <= hwchamp_monitor;
                                    1: ana_in <= hwchamp_left;
                                    2: ana_in <= hwchamp_right;
                                    3: ana_in <= 8'hff;
                                endcase
                            end else begin
                                cab_dout <= { 7'd0, ana_in[7] };
                                shift_en <= 1;
                            end
                        end else cab_dout <= 8'hff;
                        // A[9:8]==3, bits 7:5 control the lamps, bit 4 is the bell
                    end
                    GAME_PASSSHT2: begin // Passing Shot (J)
                        //if( A[9:8]== 2'b10 ) begin
                            case( A[2:1] )
                                0: cab_dout <= pass_joy( joystick1 );
                                1: cab_dout <= pass_joy( joystick2 );
                                2: cab_dout <= pass_joy( joystick3 );
                                3: cab_dout <= pass_joy( joystick4 );
                            endcase
                        //end
                    end
                    GAME_DUNKSHOT: begin
                        cab_dout <= dunkshot_joy( trackball[A[4:2]]^{12{A[3]}} );
                    end
                    GAME_EXCTLEAG,GAME_SDI,GAME_SDIBL: begin // SDI / Defense
                        case( A[3:2] )
                            // 1P
                            0: cab_dout <= trackball[0][10:3];
                            1: cab_dout <= trackball[1][10:3];
                            // 2P
                            2: cab_dout <= trackball[2][10:3];
                            3: cab_dout <= trackball[3][10:3];
                        endcase
                    end
                    default:;
                endcase
            end
        endcase
    end
end

endmodule