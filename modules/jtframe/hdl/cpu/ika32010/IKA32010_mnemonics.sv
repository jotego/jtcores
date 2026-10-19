//Program counter control
localparam  PC_HOLD             = 3'd0;
localparam  PC_INCREASE         = 3'd1;
localparam  PC_LOAD_IMMEDIATE   = 3'd2;
localparam  PC_LOAD_INTERRUPT   = 3'd3;
localparam  PC_LOAD_WRBUS       = 3'd4;
localparam  PC_RESET            = 3'd5;
localparam  DO_RESET            = 1'b0;
localparam  DO_INCREASE         = 1'b1;

//Write bus sources
localparam  WRBUS_SOURCE_SHB     = 3'd0;
localparam  WRBUS_SOURCE_RAM     = 3'd1;
localparam  WRBUS_SOURCE_AR      = 3'd2;
localparam  WRBUS_SOURCE_STACK   = 3'd3;
localparam  WRBUS_SOURCE_IMM     = 3'd4;
localparam  WRBUS_SOURCE_FLAG    = 3'd5;
localparam  WRBUS_SOURCE_INLATCH = 3'd6;

//address output
localparam  BUSCTRL_ADDR_PC         = 1'd0;
localparam  BUSCTRL_ADDR_PERIPHERAL = 1'd1;

//bus access types
localparam  BUSCTRL_STOP        = 3'd0;
localparam  OPCODE_READ         = 3'd1;
localparam  DATA_READ           = 3'd2;
localparam  DATA_WRITE          = 3'd3;
localparam  COMMAND_IN          = 3'd4;
localparam  COMMAND_OUT         = 3'd5;

//multiplier input
parameter   MUL_OP1_SOURCE_IMM = 1'b0;
parameter   MUL_OP1_SOURCE_RAM = 1'b1;

//stack data
localparam  STACK_DATA_ACC  = 1'b0;
localparam  STACK_DATA_PC   = 1'b1;

//ALU mode
localparam  ALU_AND             = 3'd0;
localparam  ALU_OR              = 3'd1;
localparam  ALU_XOR             = 3'd2;
localparam  ALU_ABS             = 3'd3;
localparam  ALU_ADD             = 3'd4;
localparam  ALU_SUB             = 3'd5;
localparam  ALU_SUBC            = 3'd6;

//ALU port B data part select
localparam  ALU_PBDATA_LONGWORD = 2'd0;
localparam  ALU_PBDATA_HIGHWORD = 2'd1;
localparam  ALU_PBDATA_LOWWORD  = 2'd2;
localparam  ALU_PBDATA_BYTE     = 2'd3;  

//ALU port B source select
localparam  ALU_SOURCE_SHFT     = 1'b0;
localparam  ALU_SOURCE_MUL      = 1'b1;

//Microcode
localparam  YES = 1'b1;
localparam  NO  = 1'b0;
localparam  HIGH = 1'b1;
localparam  LOW = 1'b0;