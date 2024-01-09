`timescale 1ns / 1ps
`default_nettype none

`define DEBUG_DISPLAYPORT_AUX_CHANNEL

//    This file is part of the ZXUNO Spectrum core. 
//    Creation date is 21:14:58 2023-05-01 by Miguel Angel Rodriguez Jodar
//    (c)2014-2020 ZXUNO association.
//    ZXUNO official repository: http://svn.zxuno.com/svn/zxuno
//    Username: guest   Password: zxuno
//    Github repository for this core: https://github.com/mcleod-ideafix/zxuno_spectrum_core
//
//    ZXUNO Spectrum core is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    ZXUNO Spectrum core is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with the ZXUNO Spectrum core.  If not, see <https://www.gnu.org/licenses/>.
//
//    Any distributed copy of this file must keep this notice intact.
//

`ifdef ZX3A35
`include "zxtres_wrapper_a35t.v"
`elsif ZX3A100
`include "zxtres_wrapper_a100t.v"
`else
`include "zxtres_wrapper_a200t.v"
`endif

