library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

package HUC6280_PKG is  

	type MicroInst_r is record
		STATE_CTRL    	: std_logic_vector(1 downto 0);
		ADDR_BUS      	: std_logic_vector(2 downto 0);
		LOAD_SDLH      : std_logic_vector(1 downto 0);
		LOAD_P			: std_logic_vector(2 downto 0); 
		LOAD_T			: std_logic_vector(2 downto 0); 
		ADDR_CTRL     	: std_logic_vector(5 downto 0);
		LOAD_PC       	: std_logic_vector(2 downto 0);
		LOAD_SP       	: std_logic_vector(2 downto 0);
		AXY_CTRL      	: std_logic_vector(2 downto 0); 
		ALUBUS_CTRL		: std_logic_vector(3 downto 0); 
		ALUCtrl      	: std_logic_vector(4 downto 0); 
		OUT_BUS       	: std_logic_vector(3 downto 0);
		MEM_CYCLE      : std_logic;
	end record;

	type ALUCtrl_r is record
		fstOp        : std_logic_vector(2 downto 0);
		secOp        : std_logic_vector(2 downto 0);
		fc           : std_logic;
	end record;
	
	type MCode_r is record
		STATE_CTRL    	: std_logic_vector(1 downto 0);
		ADDR_BUS      	: std_logic_vector(2 downto 0);
		LOAD_SDLH      : std_logic_vector(1 downto 0);
		LOAD_P			: std_logic_vector(2 downto 0); 
		LOAD_T			: std_logic_vector(2 downto 0); 
		ADDR_CTRL     	: std_logic_vector(5 downto 0);
		LOAD_PC       	: std_logic_vector(2 downto 0);
		LOAD_SP       	: std_logic_vector(2 downto 0);
		AXY_CTRL      	: std_logic_vector(2 downto 0); 
		ALUBUS_CTRL		: std_logic_vector(3 downto 0); 
		OUT_BUS       	: std_logic_vector(3 downto 0);
		MEM_CYCLE      : std_logic;
		ALU_CTRL 		: ALUCtrl_r;
	end record;

	constant FLAG_C : integer := 0;
	constant FLAG_Z : integer := 1;
	constant FLAG_I : integer := 2;
	constant FLAG_D : integer := 3;
	constant FLAG_B : integer := 4;
	constant FLAG_T : integer := 5;
	constant FLAG_V : integer := 6;
	constant FLAG_N : integer := 7;

	type MPR_t is array(0 to 7) of std_logic_vector(7 downto 0);

end HUC6280_PKG;

package body HUC6280_PKG is

	
end package body HUC6280_PKG;
