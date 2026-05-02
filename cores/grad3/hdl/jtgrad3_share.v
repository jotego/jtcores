/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jtgrad3_share(
    input             clk,
    input      [15:0] m_dout,
    input      [15:0] s_dout,
    input      [13:1] m_addr,
    input      [13:1] s_addr,
    input      [ 1:0] m_we,
    input      [ 1:0] s_we,
    output     [15:0] m_din,
    output     [15:0] s_din
);

jtframe_dual_ram16 #(.AW(13)) u_shram(
    .clk0   ( clk    ),
    .data0  ( m_dout ),
    .addr0  ( m_addr ),
    .we0    ( m_we   ),
    .q0     ( m_din  ),

    .clk1   ( clk    ),
    .data1  ( s_dout ),
    .addr1  ( s_addr ),
    .we1    ( s_we   ),
    .q1     ( s_din  )
);

endmodule
