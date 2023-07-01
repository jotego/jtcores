// Copyright (c) 2014 Takashi Toyoshima <toyoshim@gmail.com>.
// All rights reserved.  Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

localparam MODE_INDEXED_INDIRECT    = 3'b000;
localparam MODE_ZERO_PAGE           = 3'b001;
localparam MODE_IMMEDIATE           = 3'b010;
localparam MODE_ABSOLUTE            = 3'b011;
localparam MODE_INDIRECT_INDEX      = 3'b100;
localparam MODE_ZERO_PAGE_INDEX_X   = 3'b101;
localparam MODE_ABSOLUTE_INDEXED_Y  = 3'b110;
localparam MODE_ABSOLUTE_INDEXED_X  = 3'b111;

localparam MODEX_IMMEDIATE          = 3'b000;
localparam MODEX_ZERO_PAGE          = 3'b001;
localparam MODEX_REGISTER           = 3'b010;
localparam MODEX_ABSOLUTE           = 3'b011;
localparam MODEX_ABSOLUTE_PC        = 3'b011;
localparam MODEX_INDIRECT_PC        = 3'b100;
localparam MODEX_ZERO_PAGE_INDEX_Y  = 3'b101;
localparam MODEX_ABSOLUTE_INDEXED_Y = 3'b111;

localparam REG_A                    = 2'b00;
localparam REG_X                    = 2'b01;
localparam REG_Y                    = 2'b10;
localparam REG_S                    = 2'b11;

localparam P_REG_A                  = 1'b0;
localparam P_REG_PSR                = 1'b1;

// xxx1_0000
localparam OP_BPL                   = 3'b000;
localparam OP_BMI                   = 3'b001;
localparam OP_BVC                   = 3'b010;
localparam OP_BVS                   = 3'b011;
localparam OP_BCC                   = 3'b100;
localparam OP_BCS                   = 3'b101;
localparam OP_BNE                   = 3'b110;
localparam OP_BEQ                   = 3'b111;

// xxx0_0000
localparam OP_BRK                   = 3'b000;
localparam OP_JSR                   = 3'b001;
localparam OP_RTI                   = 3'b010;
localparam OP_RTS                   = 3'b011;

// xxx0_1000 [11]
localparam OP_PHP                   = 3'b000;
localparam OP_PLP                   = 3'b001;
localparam OP_PHA                   = 3'b010;
localparam OP_PLA                   = 3'b011;
localparam OP_DEY                   = 3'b100;
localparam OP_TAY                   = 3'b101;
localparam OP_INY                   = 3'b110;
localparam OP_INX                   = 3'b111;

// xxxy_yy01 [01]
localparam OP_ORA                   = 3'b000;
localparam OP_AND                   = 3'b001;
localparam OP_EOR                   = 3'b010;
localparam OP_ADC                   = 3'b011;
localparam OP_STA                   = 3'b100;
localparam OP_LDA                   = 3'b101;
localparam OP_CMP                   = 3'b110;
localparam OP_SBC                   = 3'b111;

// xxxy_yy10 [10]
localparam OP_ASL                   = 3'b000;
localparam OP_ROL                   = 3'b001;
localparam OP_LSR                   = 3'b010;
localparam OP_ROR                   = 3'b011;
localparam OP_STX                   = 3'b100;
localparam OP_LDX                   = 3'b101;
localparam OP_DEC                   = 3'b110;
localparam OP_INC                   = 3'b111;

// xxxy_yy00 [00]
localparam OP_BIT                   = 3'b001;
localparam OP_JMP_ABS               = 3'b010;
localparam OP_JMP_IND               = 3'b011;
localparam OP_STY                   = 3'b100;
localparam OP_LDY                   = 3'b101;
localparam OP_CPY                   = 3'b110;
localparam OP_CPX                   = 3'b111;
