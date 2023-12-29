library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- FIFO queue for debug channel.
-- Asynchronous, fall-through semantics.

ENTITY debug_fifo IS
	generic (
		width : integer := 32;
		depth : integer := 4
	);
	PORT (
		reset_n : in std_logic := '1';
		-- Read-side signals
		rd_clk : IN STD_LOGIC;
		rd_en : IN STD_LOGIC;
		dout : OUT STD_LOGIC_VECTOR(width-1 DOWNTO 0);
		empty : OUT STD_LOGIC;
		-- Write-side signals
		wr_clk : IN STD_LOGIC;
		wr_en : IN STD_LOGIC;
		din : IN STD_LOGIC_VECTOR(width-1 DOWNTO 0);
		full : OUT STD_LOGIC
	);
END entity;

architecture rtl of debug_fifo is

function togray(d : unsigned) return unsigned is begin
	return d xor ('0'&d(d'high downto 1));
end function;

subtype element_t is std_logic_vector(width-1 downto 0);
type storage_t is array ((2**depth)-1 downto 0) of element_t;
signal storage : storage_t;

signal inptr_gray : unsigned(depth-1 downto 0) := (others=>'0');
signal outptr_gray : unsigned(depth-1 downto 0) := (others => '0');
signal outptr_prev_gray : unsigned(depth-1 downto 0) := to_unsigned((2**(depth-1)),depth); -- Set MSB only

begin

-- Read side logic

readlogic : block is

signal inptr_gray_sync : unsigned(depth-1 downto 0);
signal inptr_gray_sync2 : unsigned(depth-1 downto 0);
signal outptr : unsigned(depth-1 downto 0) := (others=>'0');
signal outptr_prev : unsigned(depth-1 downto 0);
signal outptr_next : unsigned(depth-1 downto 0);
signal empty_c : std_logic;
signal rd_trigger : std_logic;
signal reset_rd : std_logic_vector(1 downto 0);
begin

	process(rd_clk) begin
		if rising_edge(rd_clk) then
			reset_rd <= reset_rd(0) & reset_n;
			inptr_gray_sync2<=inptr_gray;
			inptr_gray_sync<=inptr_gray_sync2;			
		end if;
	end process;

	rd_trigger <= '1' when rd_en='1' and empty_c='0' else '0';

	empty_c <= '1' when inptr_gray_sync = outptr_gray else'0';
	empty <= empty_c;	

	outptr_next<=outptr+1;
	outptr_prev<=outptr-1;

	process(rd_clk,reset_rd(1)) begin
		if reset_rd(1)='0' then
			outptr<=(others=>'0');
			outptr_gray<=(others=>'0');
			outptr_prev_gray<=to_unsigned((2**(depth-1)),depth); -- Set MSB only
		elsif rising_edge(rd_clk) then
			dout <= storage(to_integer(outptr_gray));
			if rd_trigger='1' then
				outptr<=outptr_next;
				outptr_gray <= togray(outptr_next);
				outptr_prev_gray<=togray(outptr_prev);
			end if;
		end if;
	end process;

end block;


-- Write side logic;

writelogic : block is

signal outptr_prev_gray_sync : unsigned(depth-1 downto 1);
signal outptr_prev_gray_sync2 : unsigned(depth-1 downto 1);
signal inptr : unsigned(depth-1 downto 0) := (others=>'0');
signal inptr_next : unsigned(depth-1 downto 0);
signal reset_wr : std_logic_vector(1 downto 0);
signal fullptr : unsigned(depth-1 downto 1);
begin

	fullptr <= outptr_prev_gray_sync;
	
	process(wr_clk) begin
		if rising_edge(wr_clk) then
			reset_wr <= reset_wr(0) & reset_n;
			outptr_prev_gray_sync2<=outptr_prev_gray(outptr_prev_gray'high downto 1); -- Ignore the lowest bit to provide some headroom.
			outptr_prev_gray_sync<=outptr_prev_gray_sync2;
		end if;
	end process;

	-- We consider the FIFO full when outptr_prev_gray == inptr_gray, so the write pointer is about to
	-- catch up with the read pointer (ignoring the LSB to give a little extra headroom, so the FIFO can accept one further
	-- entry in the cycle during which full goes high).
	full <= '1' when inptr_gray(inptr_gray'high downto 1) = fullptr else '0';

	inptr_next<=inptr+1;

	process(wr_clk,reset_wr(1)) begin
		if reset_wr(1)='0' then
			inptr<=(others=>'0');
			inptr_gray<=(others=>'0');
		elsif rising_edge(wr_clk) then
			if wr_en='1' then
				storage(to_integer(inptr_gray))<=din;
				inptr<=inptr_next;
				inptr_gray <= togray(inptr_next);
			end if;
		end if;
	end process;

end block;

end architecture;

