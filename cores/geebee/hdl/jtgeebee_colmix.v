/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 06-11-2026 */

module jtgeebee_colmix(
    input                  char_pxl,
    input                  ball_pxl,
    input                  bgw,
    input                  lhbl,
    input                  lvbl,
    output [`JTFRAME_COLORW-1:0] red,
    output [`JTFRAME_COLORW-1:0] green,
    output [`JTFRAME_COLORW-1:0] blue
);

wire white = lhbl && lvbl && (bgw ^ (char_pxl | ball_pxl));

assign red   = {`JTFRAME_COLORW{white}};
assign green = {`JTFRAME_COLORW{white}};
assign blue  = {`JTFRAME_COLORW{white}};

endmodule
