/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 10-7-2022 */

module jtttnose_controls(
    input      [ 2:0] ctrl_type,
    input      [ 1:0] directions,
    input      [ 1:0] buttons,
    input      [15:0] joyana_l,
    input      [15:0] joyana_r,
    output reg [ 7:0] steering,
    output reg [ 7:0] accelerator,
    output reg [ 7:0] brake
);

always @* begin
    steering = joyana_l[7:0] ^ 8'h80;
    if( !directions[0] ) steering = 8'he0;
    if( !directions[1] ) steering = 8'h20;

    accelerator = 0;
    brake = 0;
    case( ctrl_type )
        0: begin
            accelerator = joyana_r[15] ? ~{joyana_r[14:8], joyana_r[14]} : 8'd0;
            brake       = joyana_r[15] ? 8'd0 : {joyana_r[14:8], joyana_r[14]};
        end
        1: begin
            accelerator = joyana_r[7] ? 8'd0 : {joyana_r[6:0], joyana_r[6]};
            brake       = joyana_l[15] ? 8'd0 : {joyana_l[14:8], joyana_l[14]};
        end
        2: begin
            accelerator = joyana_l[15] ? ~{joyana_l[14:8], joyana_l[14]} : 8'd0;
            brake       = joyana_r[15] ? ~{joyana_r[14:8], joyana_r[14]} : 8'd0;
        end
        default:;
    endcase
    if( !buttons[0] ) accelerator = 8'hff;
    if( !buttons[1] ) brake = 8'hff;
end

endmodule
