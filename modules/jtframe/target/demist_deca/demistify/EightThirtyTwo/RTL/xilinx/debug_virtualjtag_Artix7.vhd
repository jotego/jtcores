
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Library UNISIM;
use UNISIM.vcomponents.all;

entity debug_virtualjtag_xilinx is
generic (
	irsize : integer := 2;
	drsize : integer := 32
);
port(
	ir_out : out std_logic_vector(irsize-1 downto 0);
	tdo : in std_logic;
	tck : out std_logic;
	tdi : out std_logic;
	virtual_state_cdr : out std_logic;
	virtual_state_sdr : out std_logic;
	virtual_state_udr : out std_logic;
	virtual_state_uir : out std_logic
);
end entity;

architecture rtl of debug_virtualjtag_xilinx is

signal ir_cap : std_logic;
signal ir_sel : std_logic;
signal ir_shift : std_logic;
signal ir_update : std_logic;
signal ir_tck : std_logic;
signal ir_tdi : std_logic;
signal ir_tdo : std_logic;
signal ir_sreg : std_logic_vector(1 downto 0);

signal dr_cap : std_logic;
signal dr_sel : std_logic;
signal dr_shift : std_logic;
signal dr_update : std_logic;

begin

-- Use chain 3 for virtual IR
irscan : BSCANE2
generic map
(
	JTAG_CHAIN => 3
)
port map (
	CAPTURE => ir_cap,   -- 1-bit output: CAPTURE output from TAP controller.
	DRCK => open,        -- 1-bit output: Gated TCK output. When SEL is asserted, DRCK toggles when CAPTURE or
                         -- SHIFT are asserted.
	RESET=> open,        -- 1-bit output: Reset output for TAP controller.
	RUNTEST => open,     -- 1-bit output: Output asserted when TAP controller is in Run Test/Idle state.
	SEL => ir_sel,       -- 1-bit output: USER instruction active output.
	SHIFT => ir_shift,   -- 1-bit output: SHIFT output from TAP controller.
	TCK => ir_tck,       -- 1-bit output: Test Clock output. Fabric connection to TAP Clock pin.
	TDI => ir_tdi,       -- 1-bit output: Test Data Input (TDI) output from TAP controller.
	TMS => open,         -- 1-bit output: Test Mode Select output. Fabric connection to TAP.
	UPDATE => ir_update, -- 1-bit output: UPDATE output from TAP controller
	TDO => ir_tdo        -- 1-bit input: Test Data Output (TDO) input for USER function.
);

ir_tdo <= ir_sreg(0);
ir_out <= ir_sreg;

process(ir_tck)
begin
	if rising_edge(ir_tck) then
		if ir_sel='1' and ir_shift='1' then
			ir_sreg <= ir_tdi & ir_sreg(irsize-1 downto 1);
		end if;
	end if;
end process;

virtual_state_uir <= ir_sel and ir_update;


-- Use chain 3 for virtual IR
drscan : BSCANE2
generic map
(
	JTAG_CHAIN => 4
)
port map (
	CAPTURE => dr_cap,   -- 1-bit output: CAPTURE output from TAP controller.
	DRCK => open,        -- 1-bit output: Gated TCK output. When SEL is asserted, DRCK toggles when CAPTURE or
                         -- SHIFT are asserted.
	RESET=> open,        -- 1-bit output: Reset output for TAP controller.
	RUNTEST => open,     -- 1-bit output: Output asserted when TAP controller is in Run Test/Idle state.
	SEL => dr_sel,       -- 1-bit output: USER instruction active output.
	SHIFT => dr_shift,   -- 1-bit output: SHIFT output from TAP controller.
	TCK => tck,          -- 1-bit output: Test Clock output. Fabric connection to TAP Clock pin.
	TDI => tdi,          -- 1-bit output: Test Data Input (TDI) output from TAP controller.
	TMS => open,         -- 1-bit output: Test Mode Select output. Fabric connection to TAP.
	UPDATE => dr_update, -- 1-bit output: UPDATE output from TAP controller
	TDO => tdo           -- 1-bit input: Test Data Output (TDO) input for USER function.
);

virtual_state_cdr <= dr_sel and dr_cap;
virtual_state_sdr <= dr_sel and dr_shift;
virtual_state_udr <= dr_sel and dr_update;

end architecture;

