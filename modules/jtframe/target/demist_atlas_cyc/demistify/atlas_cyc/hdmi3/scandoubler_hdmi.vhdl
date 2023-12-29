---------------------------------------------------------------------------
-- (c) 2013 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;

ENTITY scandoubler_hdmi IS
GENERIC
(
	video_bits : integer := 4
);
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;
	
	colour_enable : in std_logic;
	doubled_enable : in std_logic;

	scanlines_on : in std_logic := '0';
	
	-- GTIA interface
	pal : in std_logic;
	colour_in : in std_logic_vector(7 downto 0);
	vsync_in : in std_logic;
	hsync_in : in std_logic;
	blank_in : in std_logic;
	
	-- TO TV...
	R : OUT STD_LOGIC_vector(video_bits-1 downto 0);
	G : OUT STD_LOGIC_vector(video_bits-1 downto 0);
	B : OUT STD_LOGIC_vector(video_bits-1 downto 0);
	
	VSYNC : out std_logic;
	HSYNC : out std_logic;
	BLANK : out std_logic
);
END scandoubler_hdmi;

ARCHITECTURE vhdl OF scandoubler_hdmi IS

   component scandouble_ram_infer_9 IS
   PORT
   (
      clock: IN   std_logic;
      data:  IN   std_logic_vector (8 DOWNTO 0);
      address:  IN   integer RANGE 0 to 1824;
      we:    IN   std_logic;
      q:     OUT  std_logic_vector (8 DOWNTO 0)
   );
	END component;

	
	component delay_line IS
	generic(COUNT : natural := 1);
	PORT 
	( 
		CLK : IN STD_LOGIC;
		SYNC_RESET : IN STD_LOGIC;
		DATA_IN : IN STD_LOGIC;
		ENABLE : IN STD_LOGIC; -- i.e. shift on this clock
		RESET_N : IN STD_LOGIC;
		
		DATA_OUT : OUT STD_LOGIC
	);
	END component;	
	
	signal colour_next : std_logic_vector(7 downto 0);
	signal colour_reg : std_logic_vector(7 downto 0);
	
	signal vsync_next : std_logic;
	signal vsync_reg : std_logic;
	
	signal hsync_next : std_logic;
	signal hsync_reg : std_logic;

	signal blank_next : std_logic;
	signal blank_reg : std_logic;

	signal r_next : std_logic_vector(7 downto 0);
	signal g_next : std_logic_vector(7 downto 0);
	signal b_next : std_logic_vector(7 downto 0);	
	signal r_reg : std_logic_vector(7 downto 0);
	signal g_reg : std_logic_vector(7 downto 0);
	signal b_reg : std_logic_vector(7 downto 0);
	
	signal linea_address : std_logic_vector(10 downto 0);
	signal linea_address_integer : integer;
	signal linea_write_enable : std_logic;
	signal linea_out : std_logic_vector(8 downto 0);

	signal lineb_address : std_logic_vector(10 downto 0);
	signal lineb_address_integer : integer;
	signal lineb_write_enable : std_logic;
	signal lineb_out : std_logic_vector(8 downto 0);
	
	signal input_address_next : std_logic_vector(10 downto 0);
	signal input_address_reg : std_logic_vector(10 downto 0);

	signal output_address_next : std_logic_vector(10 downto 0);
	signal output_address_reg : std_logic_vector(10 downto 0);
	
	signal buffer_select_next : std_logic;
	signal buffer_select_reg : std_logic;
	
	signal hsync_in_reg : std_logic;
	
	signal vga_hsync_next : std_logic;
	signal vga_hsync_reg : std_logic;
	signal vga_hsync_start : std_logic;
	signal vga_hsync_end : std_logic;

	signal vga_odd_reg : std_logic;
	signal vga_odd_next : std_logic;

	signal reset_output_address : std_logic;
	
begin
	-- register
	process(clk,reset_n)
	begin
		if (reset_n = '0') then
			r_reg <= (others=>'0');
			g_reg <= (others=>'0');
			b_reg <= (others=>'0');			
			colour_reg <= (others=>'0');
			hsync_reg <= '0';
			vsync_reg <= '0';
			blank_reg <= '0';
			
			input_address_reg <= (others=>'0');
			output_address_reg <= (others=>'0');
			
			buffer_select_reg <= '0';
			
			vga_hsync_reg <= '0';

			vga_odd_reg <= '0';
		elsif (clk'event and clk='1') then										
			r_reg <= r_next;
			g_reg <= g_next;
			b_reg <= b_next;
			colour_reg <= colour_next;
			hsync_reg <= hsync_next;
			vsync_reg <= vsync_next;
			blank_reg <= blank_next;
		
			input_address_reg <= input_address_next;
			output_address_reg <= output_address_next;
			
			buffer_select_reg <= buffer_select_next;
			
			hsync_in_reg <= hsync_in;
			
			vga_hsync_reg <= vga_hsync_next;

			vga_odd_reg <= vga_odd_next;
		end if;
	end process;
	
	-- TODO - these should use FPGA RAM - at present about 50% of FPGA is taken by these!!!
	--	linea : reg_file
		--generic map (BYTES=>456,WIDTH=>9)
		--port map (clk=>clk,addr=>linea_address,wr_en=>linea_write_enable,data_in=>colour_in,data_out=>linea_out);

	--lineb : reg_file
	--	generic map (BYTES=>456,WIDTH=>9)
	--	port map (clk=>clk,addr=>lineb_address,wr_en=>lineb_write_enable,data_in=>colour_in,data_out=>lineb_out);	

	linea_address_integer <= to_integer(unsigned(linea_address));
	linea : scandouble_ram_infer_9
	port map (clock=>clk,address=>linea_address_integer,we=>linea_write_enable,data=>blank_in&colour_in,q=>linea_out);

	lineb_address_integer <= to_integer(unsigned(lineb_address));
	lineb : scandouble_ram_infer_9
	port map (clock=>clk,address=>lineb_address_integer,we=>lineb_write_enable,data=>blank_in&colour_in,q=>lineb_out);	
	
	-- capture
	process(input_address_reg,colour_enable,hsync_in,hsync_in_reg,buffer_select_reg)
	begin
		input_address_next <= input_address_reg;
		buffer_select_next <= buffer_select_reg;
		
		linea_write_enable <= '0';
		lineb_write_enable <= '0';
		reset_output_address <= '0';
		
		if (colour_enable = '1') then
			input_address_next <= std_logic_vector(unsigned(input_address_reg)+1);
			linea_write_enable <= buffer_select_reg;
			lineb_write_enable <= not(buffer_select_reg);
		end if;		
		
		if (hsync_in = '1' and hsync_in_reg = '0') then
			input_address_next <= (others=>'0');
			buffer_select_next <= not(buffer_select_reg);
			reset_output_address <= '1';
		end if;		
	end process;
	
	-- output
	process(vga_hsync_reg,vga_hsync_end,output_address_reg,doubled_enable,vga_odd_reg,reset_output_address)
	begin
		output_address_next <= output_address_reg;
		vga_hsync_start<='0';
		vga_hsync_next <= vga_hsync_reg;
		vga_odd_next <= vga_odd_reg;
		
		if (doubled_enable = '1') then
			output_address_next <= std_logic_vector(unsigned(output_address_reg)+1);
			
			if (output_address_reg = "111"&X"1F") then
				output_address_next <= (others=>'0');
				vga_hsync_start <= '1';
				vga_hsync_next <= '1';
			end if;
		end if;
		
		if (vga_hsync_end = '1') then
			vga_hsync_next <= '0';
			vga_odd_next <= not(vga_odd_reg);
		end if;

		if (reset_output_address = '1') then
			output_address_next <= (others=>'0');
			vga_odd_next <= '1';
		end if;
	end process;
	
	linea_address <= input_address_reg when buffer_select_reg='1' else output_address_reg;
	lineb_address <= input_address_reg when buffer_select_reg='0' else output_address_reg;
	
	hsync_delay : delay_line
		generic map (COUNT=>128)
		port map(clk=>clk,sync_reset=>'0',data_in=>vga_hsync_start,enable=>doubled_enable,reset_n=>reset_n,data_out=>vga_hsync_end);			
	
	-- display
	process(colour_reg,vsync_reg,vga_hsync_reg,hsync_reg,blank_reg,colour_in,vsync_in,hsync_in,colour_enable,doubled_enable,buffer_select_reg,linea_out,lineb_out, scanlines_on, vga_odd_reg)
	begin	
		colour_next <= colour_reg;
		
		-- vga mode, store all inputs - then play back!			
		if (buffer_select_reg = '0') then
			if (scanlines_on ='1' and vga_odd_reg='1') then
				colour_next(7 downto 4) <= linea_out(7 downto 4);
				colour_next(3) <= '0';
				colour_next(2 downto 0) <= linea_out(3 downto 1);
			else
				colour_next <= linea_out(7 downto 0);
			end if;
			blank_next <= linea_out(8) or vsync_in or vga_hsync_reg;
		else
			if (scanlines_on ='1' and vga_odd_reg='1') then
				colour_next(7 downto 4) <= lineb_out(7 downto 4);
				colour_next(3) <= '0';
				colour_next(2 downto 0) <= lineb_out(3 downto 1);
			else
				colour_next <= lineb_out(7 downto 0);
			end if;
			blank_next <= lineb_out(8) or vsync_in or vga_hsync_reg;
		end if;
		
		hsync_next <= vga_hsync_reg;			
		vsync_next <= vsync_in;				
		
	end process;

	-- colour palette
	palette4 : entity work.gtia_palette
		port map (PAL=>pal,ATARI_COLOUR=>colour_reg, R_next=>R_next, G_next=>G_next, B_next=>B_next);		
	
	-- output	
		-- TODO - for DE2, output full 8 bits
	R <= R_reg(7 downto 8-video_bits);
	G <= G_reg(7 downto 8-video_bits);
	B <= B_reg(7 downto 8-video_bits);
	
	vsync<=vsync_reg;
	hsync<=hsync_reg;
	blank<=blank_reg;

end vhdl;


