--------------------------------------------------------------------------------
-- AVALON SCALER
--------------------------------------------------------------------------------
-- TEMLIB 2018 - 2020
--------------------------------------------------------------------------------
-- This code can be freely distributed and used for any purpose, but, if you
-- find any bug, or want to suggest an enhancement, you ought to send a mail
-- to info@temlib.org.
--------------------------------------------------------------------------------

-- Features
--  - Arbitrary output video format
--  - Autodetect input image size or fixed window
--  - Progressive and interlaced input
--  - Interpolation
--    Upscaling   : Nearest, Bilinear, Sharp Bilinear, Bicubic, Polyphase
--    Downscaling : Nearest, Bilinear
--  - Avalon bus interface with 128 or 64 bits DATA
--  - Optional triple buffering
--  - Support for external low lag syntonization

--------------------------------------------
-- Downscaling
-- - Horizontal and vertical up-/down-scaling are independant.
-- - Downscaling, H and/or V, supports only nearest-neighbour and bilinear
--   filtering.
-- - For interlaced video, when the vertical size is lower than a deinterlaced
--   frame size (2x half-frame), the scaler processes only half-frames
--   and upscales (when the output size is between 1x an 2x) or downscales (size
--   below 1x) them.

--------------------------------------------
-- 5 clock domains
--  i_xxx    : Input video
--  o_xxx    : Output video
--  avl_xxx  : Avalon memory bus
--  poly_xxx : Polyphase filters memory
--  pal_xxx  : Framebuffer mode 8bpp palette.

--------------------------------------------
-- O_FB_FORMAT : Framebuffer format
--  [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
--  [3]   : 0=16bits 565 1=16bits 1555
--  [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
--  [5]   : TBD

--------------------------------------------
-- Image header. When HEADER = TRUE
-- Header Address = RAMBASE
-- Image Address  = RAMBASE + HEADER_SIZE

-- Header (Bytes. Big Endian.)
--  0    : Type = 1
--  1    : Pixel format
--         0 : 16 bits/pixel, RGB : RRRRRGGGGGGBBBBB
--         1 : 24 bits/pixel, RGB
--         2 : 32 bits/pixel, RGB0

--  3:2  : Header size : Offset to start of picture (= N_BURST). 12 bits
--  5:4  : Attributes
--         b0 ; Interlaced
--         b1 : Field number
--         b2 : Horizontal downscaled
--         b3 : Vertical downscaled
--         b4 : Triple buffered
--       b7-5 : Frame counter
--  7:6  : Image width. Pixels. 12 bits
--  9:8  : Image height. Pixels. 12 bits
-- 11:10 : Line length. Bytes.
-- 13:12 : Output width. Pixels. 12 bits
-- 15:14 : Output height. Pixels. 12 bits
--------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

-- MODE[2:0]
-- 000 : Nearest
-- 001 : Bilinear
-- 010 : Sharp Bilinear
-- 011 : Bicubic
-- 100 : Polyphase
-- 101 : TBD
-- 110 : TBD
-- 111 : TBD

-- MODE[3]
-- 0 : Direct. Single framebuffer.
-- 1 : Triple buffering

-- MODE[4] : TBD

-- MASK      : Enable / Disable selected interpoler
--             0:Nearest 1:Bilinear 2:SharpBilinear 3:Bicubic 4:Polyphase
-- RAMBASE   : RAM base address for framebuffer
-- RAMSIZE   : RAM allocated for one framebuffer (needs x3 if triple-buffering)
--             Must be a power of two
-- INTER     : True=Autodetect interlaced video False=Force progressive scan
-- HEADER    : True=Add image properties header
-- PALETTE   : Enable palette for framebuffer 8bpp mode
-- PALETTE2  : Enable palette for framebuffer 8bpp mode supplied by core
-- DOWNSCALE : True=Support downscaling False=Downscaling disabled
-- BYTESWAP  : Little/Big endian byte swap
-- FRAC      : Fractional bits, subpixel resolution
-- OHRES     : Max. output horizontal resolution. 1024, 2048, 2304, 2560, 4096
--             (Used for sizing line buffers)
-- IHRES     : Max. input horizontal resolution. Must be a power of two.
--             (Used for sizing line buffers)
-- N_DW      : Avalon data bus width. 64 or 128 bits
-- N_AW      : Avalon address bus width
-- N_BURST   : Burst size in bytes. Power of two.

ENTITY ascal IS
	GENERIC (
		MASK         : unsigned(7 DOWNTO 0) :=x"FF";
		RAMBASE      : unsigned(31 DOWNTO 0);
		RAMSIZE      : unsigned(31 DOWNTO 0) := x"0080_0000"; -- =8MB
		INTER        : boolean := true;
		HEADER       : boolean := true;
		DOWNSCALE    : boolean := true;
		BYTESWAP     : boolean := true;
		PALETTE      : boolean := true;
		PALETTE2     : boolean := true;
		ADAPTIVE     : boolean := true;
		DOWNSCALE_NN : boolean := false;
		FRAC         : natural RANGE 4 TO 8 :=4;
		OHRES        : natural RANGE 1 TO 4096 :=2304;
		IHRES        : natural RANGE 1 TO 2048 :=2048;
		N_DW         : natural RANGE 64 TO 128 := 128;
		N_AW         : natural RANGE 8 TO 32 := 32;
		CAPTURE      : boolean := false;
		-- Deterministic starting identity for capture verification. Production
		-- instances retain zero; writer tokens are locally modulo-256.
		CAPTURE_WRITE_ID_SEED : unsigned(31 DOWNTO 0) := (OTHERS=>'0');

		-- Sinden Lightgun support border
		BORDER_H     : natural := 20;
		BORDER_V     : natural := 20;
		BORDER_H2    : natural := 28;
		BORDER_V2    : natural := 28;

		N_BURST      : natural := 256; -- 256 bytes per burst
		CAPTURE_CYCLES_PER_MS : natural := 100000
		);
	PORT (
		------------------------------------
		-- Input video
		i_r   : IN  unsigned(7 DOWNTO 0);
		i_g   : IN  unsigned(7 DOWNTO 0);
		i_b   : IN  unsigned(7 DOWNTO 0);
		i_hs  : IN  std_logic; -- H sync
		i_vs  : IN  std_logic; -- V sync
		i_fl  : IN  std_logic; -- Interlaced field
		i_de  : IN  std_logic; -- Display Enable
		i_ce  : IN  std_logic; -- Clock Enable
		i_clk : IN  std_logic; -- Input clock

		------------------------------------
		-- Output video
		o_r   : OUT unsigned(7 DOWNTO 0);
		o_g   : OUT unsigned(7 DOWNTO 0);
		o_b   : OUT unsigned(7 DOWNTO 0);
		o_hs  : OUT std_logic; -- H sync
		o_vs  : OUT std_logic; -- V sync
		o_de  : OUT std_logic; -- Display Enable
		o_vbl : OUT std_logic; -- V blank
		o_brd : OUT std_logic; -- border enable
		o_ce  : IN  std_logic; -- Clock Enable
		o_clk : IN  std_logic; -- Output clock

		-- Border colour R G B
		o_border   : IN unsigned(23 DOWNTO 0) := x"000000";

		-- Enable white borders for SINDEN LIGHTGUN
		gun_border_en : IN std_logic;
		------------------------------------
		-- Framebuffer mode
		o_fb_ena    : IN std_logic :='0'; -- Enable Framebuffer Mode
		o_fb_hsize  : IN natural RANGE 0 TO 4095 :=0;
		o_fb_vsize  : IN natural RANGE 0 TO 4095 :=0;
		o_fb_format : IN unsigned(5 DOWNTO 0) :="000100";
		o_fb_base   : IN unsigned(31 DOWNTO 0) :=x"0000_0000";
		o_fb_stride : IN unsigned(13 DOWNTO 0) :=(OTHERS =>'0');

		-- Framebuffer palette in 8bpp mode
		pal1_clk : IN std_logic :='0';
		pal1_dw  : IN unsigned(47 DOWNTO 0) :=x"000000000000"; -- R1 G1 B1 R0 G0 B0
		pal1_dr  : OUT unsigned(47 DOWNTO 0) :=x"000000000000";
		pal1_a   : IN unsigned(6 DOWNTO 0)  :="0000000"; -- Colour index/2
		pal1_wr  : IN std_logic :='0';

		pal_n    : IN std_logic :='0';

		pal2_clk : IN std_logic :='0';
		pal2_dw  : IN unsigned(23 DOWNTO 0) :=x"000000"; -- R G B
		pal2_dr  : OUT unsigned(23 DOWNTO 0) :=x"000000";
		pal2_a   : IN unsigned(7 DOWNTO 0)  :="00000000"; -- Colour index
		pal2_wr  : IN std_logic :='0';

		------------------------------------
		-- Low lag PLL tuning
		o_lltune : OUT unsigned(15 DOWNTO 0);

		------------------------------------
		-- Input video parameters
		iauto : IN std_logic :='1'; -- 1=Autodetect image size 0=Choose window
		himin : IN natural RANGE 0 TO 4095 :=0; -- MIN < MAX, MIN >=0, MAX < DISP
		himax : IN natural RANGE 0 TO 4095 :=0;
		vimin : IN natural RANGE 0 TO 4095 :=0;
		vimax : IN natural RANGE 0 TO 4095 :=0;

		-- Detected input image size
		i_hdmax : OUT natural RANGE 0 TO 4095;
		i_vdmax : OUT natural RANGE 0 TO 4095;

		-- Output video parameters
		run       : IN std_logic :='1'; -- 1=Enable output image. 0=No image
		freeze    : IN std_logic :='0'; -- 1=Disable framebuffer writes
		mode      : IN unsigned(4 DOWNTO 0);
 		bob_deint : IN std_logic := '0';
		-- SYNC  |_________________________/"""""""""\_______|
		-- DE    |""""""""""""""""""\________________________|
		-- RGB   |    <#IMAGE#>      ^HDISP                  |
		--            ^HMIN   ^HMAX        ^HSSTART  ^HSEND  ^HTOTAL
		htotal  : IN natural RANGE 0 TO 4095;
		hsstart : IN natural RANGE 0 TO 4095;
		hsend   : IN natural RANGE 0 TO 4095;
		hdisp   : IN natural RANGE 0 TO 4095;
		hmin    : IN natural RANGE 0 TO 4095;
		hmax    : IN natural RANGE 0 TO 4095; -- 0 <= hmin < hmax < hdisp
		vtotal  : IN natural RANGE 0 TO 4095;
		vsstart : IN natural RANGE 0 TO 4095;
		vsend   : IN natural RANGE 0 TO 4095;
		vdisp   : IN natural RANGE 0 TO 4095;
		vmin    : IN natural RANGE 0 TO 4095;
		vmax    : IN natural RANGE 0 TO 4095; -- 0 <= vmin < vmax < vdisp
		vrr     : IN std_logic := '0';
		vrrmax  : IN natural RANGE 0 TO 4095 := 0;
		swblack : IN std_logic := '0';        -- will output 3 black frame on every resolution switch

		-- Scaler format. 00=16bpp 565, 01=24bpp 10=32bpp
		format  : IN unsigned(1 DOWNTO 0) :="01";

		------------------------------------
		-- Polyphase filter coefficients
		-- Order :
		--   [Horizontal] [Vertical] [Horizontal2] [Vertical2]
		--   [0]...[2**FRAC-1]
		--   [-1][0][1][2]
		poly_clk : IN std_logic;
		poly_dw  : IN unsigned(9 DOWNTO 0);
		poly_a   : IN unsigned(FRAC+3 DOWNTO 0);
		poly_wr  : IN std_logic;

		------------------------------------
		-- Avalon
		avl_clk            : IN    std_logic; -- Avalon clock
		avl_waitrequest    : IN    std_logic;
		avl_readdata       : IN    std_logic_vector(N_DW-1 DOWNTO 0);
		avl_readdatavalid  : IN    std_logic;
		avl_burstcount     : OUT   std_logic_vector(7 DOWNTO 0);
		avl_writedata      : OUT   std_logic_vector(N_DW-1 DOWNTO 0);
		avl_address        : OUT   std_logic_vector(N_AW-1 DOWNTO 0);
		avl_write          : OUT   std_logic;
		avl_read           : OUT   std_logic;
		avl_byteenable     : OUT   std_logic_vector(N_DW/8-1 DOWNTO 0);

		------------------------------------
		reset_na           : IN    std_logic;

		-- Optional exact-frame capture interface. The shared CAB/frame helper
		-- owns the native-clock tag source; ascal owns its async FIFO and the
		-- capture/write/readback state machine.
		cap_io_clk               : IN  std_logic := '0';
		cap_io_rst               : IN  std_logic := '1';
		cap_req_toggle           : IN  std_logic := '0';
		cap_req                  : IN  std_logic_vector(31 DOWNTO 0) := (OTHERS=>'0');
		cap_req_ack_toggle       : OUT std_logic;
		cap_release_toggle       : IN  std_logic := '0';
		cap_release              : IN  std_logic_vector(15 DOWNTO 0) := (OTHERS=>'0');
		cap_release_ack_toggle   : OUT std_logic;
		cap_abort_toggle         : IN  std_logic := '0';
		cap_abort                : IN  std_logic_vector(15 DOWNTO 0) := (OTHERS=>'0');
		cap_abort_ack_toggle     : OUT std_logic;
		cap_life_toggle          : IN  std_logic := '0';
		cap_life                 : IN  std_logic_vector(31 DOWNTO 0) := (OTHERS=>'0');
		cap_life_ack_toggle      : OUT std_logic;
		cap_tag_clk              : IN  std_logic := '0';
		cap_tag_rst              : IN  std_logic := '1';
		cap_tag_valid            : IN  std_logic := '0';
		cap_tag                  : IN  std_logic_vector(14 DOWNTO 0) := (OTHERS=>'0');
		cap_tag_error            : IN  std_logic := '0';
		cap_mode_supported       : IN  std_logic := '1';
		cap_tag_ready            : OUT std_logic;
		cap_result_toggle        : OUT std_logic;
		cap_result               : OUT std_logic_vector(511 DOWNTO 0);
		cap_result_ack_toggle    : IN  std_logic := '0';
		cap_state                : OUT std_logic_vector(7 DOWNTO 0);
		cap_fault                : OUT std_logic_vector(7 DOWNTO 0)
		);

BEGIN
	ASSERT N_DW=64 OR N_DW=128 REPORT "DW" SEVERITY failure;
	ASSERT CAPTURE_CYCLES_PER_MS>0 REPORT "CAPTURE_CYCLES_PER_MS" SEVERITY failure;

	ASSERT OHRES = 1024 OR OHRES = 2048 OR OHRES = 2304 OR
	       OHRES = 2560 OR OHRES = 4096 REPORT "OHRES" SEVERITY failure;

END ENTITY ascal;

--##############################################################################

ARCHITECTURE rtl OF ascal IS

	CONSTANT MASK_NEAREST        : natural :=0;
	CONSTANT MASK_BILINEAR       : natural :=1;
	CONSTANT MASK_SHARP_BILINEAR : natural :=2;
	CONSTANT MASK_BICUBIC        : natural :=3;
	CONSTANT MASK_POLY           : natural :=4;

	----------------------------------------------------------
	FUNCTION ilog2 (CONSTANT v : natural) RETURN natural IS
		VARIABLE r : natural := 1;
		VARIABLE n : natural := 0;
	BEGIN
		WHILE v>r LOOP
			n:=n+1;
			r:=r*2;
		END LOOP;
		RETURN n;
	END FUNCTION ilog2;
	FUNCTION to_std_logic (a : boolean) RETURN std_logic IS
	BEGIN
		IF a THEN RETURN '1';
		ELSE RETURN '0';
		END IF;
	END FUNCTION to_std_logic;

	----------------------------------------------------------
	FUNCTION ohres_h(CONSTANT r : natural) RETURN natural IS
	BEGIN
		CASE r IS
			WHEN 1024   => RETURN 1024;
			WHEN 2048   => RETURN 2048;
			WHEN OTHERS => RETURN 4096;
		END CASE;
	END FUNCTION;
	FUNCTION ohres_l(CONSTANT r : natural) RETURN natural IS
	BEGIN
		CASE r IS
			WHEN 1024               => RETURN 1024;
			WHEN 2048 | 2304 | 2560 => RETURN 2048;
			WHEN OTHERS             => RETURN 4096;
		END CASE;
	END FUNCTION;
	FUNCTION ohres_m(CONSTANT r : natural) RETURN natural IS
	BEGIN
		CASE r IS
			WHEN 1024 | 2048 | 2304 => RETURN 256;
			WHEN OTHERS             => RETURN 512;
		END CASE;
	END FUNCTION;

	FUNCTION cap_gray(v : unsigned) RETURN unsigned IS
	BEGIN
		RETURN v XOR ('0' & v(v'left DOWNTO 1));
	END FUNCTION;

	CONSTANT OHRESH : natural := ohres_h(OHRES);
	CONSTANT OHRESL : natural := ohres_l(OHRES);
	CONSTANT OHRESM : natural := ohres_m(OHRES);

	----------------------------------------------------------
	CONSTANT NB_BURST : natural :=ilog2(N_BURST);
	CONSTANT NB_LA    : natural :=ilog2(N_DW/8); -- Low address bits
	CONSTANT BLEN     : natural :=N_BURST / N_DW * 8; -- Burst length

	----------------------------------------------------------
	TYPE arr_dw IS  ARRAY (natural RANGE <>) OF unsigned(N_DW-1 DOWNTO 0);

	CONSTANT CAP_TAG_AW : natural := 2;
	TYPE cap_tag_mem_t IS ARRAY (0 TO 2**CAP_TAG_AW-1) OF std_logic_vector(14 DOWNTO 0);
	SIGNAL cap_tag_mem : cap_tag_mem_t;
	SIGNAL cap_tag_wr_bin,cap_tag_wr_gray,cap_tag_rd_bin,cap_tag_rd_gray : unsigned(CAP_TAG_AW DOWNTO 0);
	SIGNAL cap_tag_rd_gray_sync1,cap_tag_rd_gray_sync2 : unsigned(CAP_TAG_AW DOWNTO 0);
	SIGNAL cap_tag_wr_gray_sync1,cap_tag_wr_gray_sync2 : unsigned(CAP_TAG_AW DOWNTO 0);
	SIGNAL cap_tag_full,cap_tag_empty : std_logic;
	SIGNAL cap_tag_error_sync1_i,cap_tag_error_sync2_i : std_logic := '0';
	SIGNAL cap_tag_valid_sync1_i,cap_tag_valid_sync2_i : std_logic := '0';
	SIGNAL cap_tag_pop : std_logic := '0';
	SIGNAL cap_tag_head : std_logic_vector(14 DOWNTO 0);
	SIGNAL cap_req_ack_i,cap_release_ack_i,cap_abort_ack_i,cap_life_ack_i : std_logic := '0';
	SIGNAL cap_result_toggle_i : std_logic := '0';
	SIGNAL cap_result_published_io : std_logic := '0';
	SIGNAL cap_result_toggle_sync1_io,cap_result_toggle_sync2_io,cap_result_toggle_seen_io,
	       cap_result_toggle_io,cap_result_ack_sync1_i,
	       cap_result_ack_sync2_i : std_logic := '0';
	SIGNAL cap_mode_sync1_i,cap_mode_sync2_i : std_logic := '1';
	SIGNAL cap_req_ack_pending_i,cap_req_ack_pending_toggle_i : std_logic := '0';
	SIGNAL cap_fault_mailbox_avl : std_logic_vector(7 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_fault_mailbox_pending_code_avl : std_logic_vector(7 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_fault_mailbox_toggle_avl,cap_fault_mailbox_pending_avl : std_logic := '0';
	SIGNAL cap_fault_mailbox_ack_i_sync1_avl,cap_fault_mailbox_ack_i_sync2_avl,
	       cap_fault_mailbox_ack_io_sync1_avl,cap_fault_mailbox_ack_io_sync2_avl : std_logic := '0';
	SIGNAL cap_fault_mailbox_toggle_sync1_i,cap_fault_mailbox_toggle_sync2_i,
	       cap_fault_mailbox_seen_i,cap_fault_mailbox_ack_toggle_i,
	       cap_fault_mailbox_ack_sync1_i,cap_fault_mailbox_ack_sync2_i : std_logic := '0';
	SIGNAL cap_fault_mailbox_code_i : std_logic_vector(7 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_fault_mailbox_toggle_sync1_io,cap_fault_mailbox_toggle_sync2_io,
	       cap_fault_mailbox_seen_io,cap_fault_mailbox_ack_toggle_io,
	       cap_fault_override_io : std_logic := '0';
	SIGNAL cap_fault_mailbox_code_io : std_logic_vector(7 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_state_i,cap_fault_i : std_logic_vector(7 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_status_bundle_i,cap_status_bundle_io : std_logic_vector(19 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_status_toggle_i,cap_status_ack_toggle_io : std_logic := '0';
	SIGNAL cap_status_ack_sync1_i,cap_status_ack_sync2_i : std_logic := '0';
	SIGNAL cap_status_toggle_sync1_io,cap_status_toggle_sync2_io,cap_status_seen_io : std_logic := '0';
	SIGNAL cap_req_sync1,cap_req_sync2,cap_req_seen : std_logic := '0';
	SIGNAL cap_release_sync1,cap_release_sync2,cap_release_seen : std_logic := '0';
	SIGNAL cap_abort_sync1,cap_abort_sync2,cap_abort_seen : std_logic := '0';
	SIGNAL cap_life_sync1,cap_life_sync2,cap_life_seen : std_logic := '0';
	SIGNAL cap_req_checkpoint,cap_last_checkpoint_i : unsigned(14 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_req_hold_ms : unsigned(10 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_life_completed_i : unsigned(14 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_life_state_i,cap_life_error_i : std_logic_vector(7 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_life_running,cap_life_done_i,cap_life_valid_i : std_logic := '0';
	SIGNAL cap_session_ready_i,cap_drain_ready_i : std_logic := '0';
	SIGNAL cap_status_state_i : std_logic_vector(7 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_lifecycle_cancel_i : std_logic := '0';
	SIGNAL cap_watchdog_active_i,cap_watchdog_toggle_i : std_logic := '0';
	SIGNAL cap_watchdog_sync1_avl,cap_watchdog_sync2_avl,cap_watchdog_seen_avl,
	       cap_watchdog_active_avl : std_logic := '0';
	SIGNAL cap_watchdog_cycle_avl : natural RANGE 0 TO CAPTURE_CYCLES_PER_MS-1 := 0;
	SIGNAL cap_watchdog_ms_avl : natural RANGE 0 TO 2000 := 0;
	SIGNAL cap_hold_pending,cap_hold_active,cap_release_pending,cap_abort_pending : std_logic := '0';
	SIGNAL cap_owner_i : std_logic := '0';
	SIGNAL cap_producer_seen_i : std_logic := '0';
	-- Slot reply follows the input EOF request through the output buffer-update
	-- pipeline. The stable generation+slot bundle describes the NEXT image.
	SIGNAL cap_slot_req_toggle_i,cap_slot_reply_ack_i : std_logic := '0';
	SIGNAL cap_slot_req_sync1_o,cap_slot_req_sync2_o,cap_slot_req_seen_o : std_logic := '0';
	SIGNAL cap_slot_pending_o : std_logic := '0';
	SIGNAL cap_slot_reply_toggle_o,cap_slot_reply_ack_sync1_o,cap_slot_reply_ack_sync2_o : std_logic := '0';
	SIGNAL cap_slot_reply_slot_o : natural RANGE 0 TO 2 := 0;
	SIGNAL cap_slot_reply_sync1_i,cap_slot_reply_sync2_i,cap_slot_reply_seen_i : std_logic := '0';
	SIGNAL cap_slot_reply_slot_i : natural RANGE 0 TO 2 := 0;
	SIGNAL cap_image_slot_i : natural RANGE 0 TO 2 := 0;
	SIGNAL cap_image_base_i : unsigned(31 DOWNTO 0) := (OTHERS=>'0');
	TYPE cap_unsigned32_pair_t IS ARRAY (0 TO 1) OF unsigned(31 DOWNTO 0);
	-- Two leased halves bound the outstanding queue to two entries. Consecutive
	-- issues therefore have opposite order bits even across a frame boundary.
	SUBTYPE cap_write_id_t IS unsigned(0 DOWNTO 0);
	TYPE cap_write_id_pair_t IS ARRAY (0 TO 1) OF cap_write_id_t;
	TYPE cap_natural_pair_t IS ARRAY (0 TO 1) OF natural RANGE 0 TO 2;
	SIGNAL cap_half_lease_i,cap_half_req_toggle_i,cap_half_ack_sync1_i,
	       cap_half_ack_sync2_i,cap_half_ack_seen_i : std_logic_vector(1 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_half_req_toggle_o,cap_half_req_sync1_o,cap_half_req_sync2_o,
	       cap_half_req_seen_o,cap_half_ack_toggle_o : std_logic_vector(1 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL i_wreq_header,cap_write_stage_header_i : std_logic := '0';
	SIGNAL cap_half_header_i : std_logic_vector(1 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_half_base_i,cap_half_offset_i : cap_unsigned32_pair_t := (OTHERS=>(OTHERS=>'0'));
	SIGNAL cap_half_id_i : cap_write_id_pair_t := (OTHERS=>(OTHERS=>'0'));
	SIGNAL cap_write_stage_valid_i,cap_write_stage_half_i : std_logic := '0';
	SIGNAL cap_write_stage_delay_i : natural RANGE 0 TO 1 := 0;
	SIGNAL cap_write_stage_base_i,cap_write_stage_offset_i : unsigned(31 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_write_stage_id_i,cap_write_next_id_i : cap_write_id_t := (OTHERS=>'0');
	SIGNAL cap_half_pending_avl : std_logic_vector(1 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_half_pending_toggle_avl,cap_half_active_toggle_avl : std_logic_vector(1 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_write_active_avl,cap_write_active_half_avl : std_logic := '0';
	SIGNAL cap_write_expected_id_avl,cap_write_completed_id_i : cap_write_id_t := (OTHERS=>'0');
	-- Exact image tuple saved with the header which was actually admitted. The
	-- descriptor fields and final CRC remain immutable through cleanup and
	-- result publication; a fresh admitted ARM
	-- is the only reuse point after the existing drain/ACK barriers.
	SIGNAL cap_image_header_i,cap_target_header_i : unsigned(127 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_crc_active_i : std_logic := '0';
	SIGNAL cap_crc_byte_i : natural RANGE 0 TO 55 := 0;
	SIGNAL cap_crc_state_i : unsigned(31 DOWNTO 0) := (OTHERS=>'1');
	SIGNAL cap_image_slot_i_saved,cap_target_slot_i : natural RANGE 0 TO 2 := 0;
	SIGNAL cap_image_base_i_saved,cap_target_base_i : unsigned(31 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_image_width_i,cap_image_height_i,cap_target_width_i,cap_target_height_i : natural RANGE 0 TO 4095 := 0;
	SIGNAL cap_image_pitch_i,cap_target_pitch_i : natural RANGE 0 TO 65535 := 0;
	SIGNAL cap_target_final_id_i : cap_write_id_t := (OTHERS=>'0');
	SIGNAL cap_error_watchdog_started_i : std_logic := '0';
	CONSTANT CAPTURE_REQUEST_COUNT_W : natural := 17;
	CONSTANT CAPTURE_MAX_PIXEL_BURSTS : natural := 4095*31;
	SIGNAL cap_image_request_count_i,cap_target_request_count_i,cap_target_expected_count_i : unsigned(CAPTURE_REQUEST_COUNT_W-1 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_target_pixel_bursts_i : unsigned(CAPTURE_REQUEST_COUNT_W-1 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_target_payload_bytes_i : unsigned(31 DOWNTO 0) := (OTHERS=>'0');
	-- Avalon accumulates every accepted pixel word, including row padding.
	-- The value is stable before the drain acknowledgement crosses to i_clk.
	SIGNAL cap_pixel_hash_avl,cap_target_pixel_hash_i : unsigned(31 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_target_checkpoint_i : unsigned(14 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_target_valid_i,cap_target_active_i,cap_drain_sent_i : std_logic := '0';
	SIGNAL cap_cleanup_pending_i,cap_cleanup_drained_i,cap_drain_cleanup_i : std_logic := '0';
	SIGNAL cap_cleanup_diag_i : std_logic := '0';
	SIGNAL cap_cleanup_done_toggle_avl,cap_cleanup_done_sync1_i,cap_cleanup_done_sync2_i,
	       cap_cleanup_done_seen_i : std_logic := '0';
	SIGNAL cap_drain_toggle_i,cap_drain_ack_sync1_i,cap_drain_ack_sync2_i : std_logic := '0';
	SIGNAL cap_drain_req_sync1_avl,cap_drain_req_sync2_avl,cap_drain_req_seen_avl : std_logic := '0';
	SIGNAL cap_drain_cleanup_sync1_avl,cap_drain_cleanup_sync2_avl,cap_drain_cleanup_avl : std_logic := '0';
	SIGNAL cap_cleanup_sync1_avl,cap_cleanup_sync2_avl,cap_cleanup_seen_avl : std_logic := '0';
	SIGNAL cap_drain_sent_sync1_avl,cap_drain_sent_sync2_avl : std_logic := '0';
	SIGNAL cap_drain_pending_avl,cap_drain_ack_avl : std_logic := '0';
	SIGNAL cap_drain_final_id_avl : cap_write_id_t := (OTHERS=>'0');
	SIGNAL cap_avl_fault_avl : std_logic_vector(7 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL cap_avl_fault_clear_toggle_i,cap_avl_fault_clear_sync1_avl,
	       cap_avl_fault_clear_sync2_avl,cap_avl_fault_clear_seen_avl,
	       cap_avl_fault_clear_ack_avl,cap_avl_fault_clear_ack_sync1_i,
	       cap_avl_fault_clear_ack_sync2_i,cap_avl_fault_clear_pending_i : std_logic := '0';

	TYPE type_pix IS RECORD
		r,g,b : unsigned(7 DOWNTO 0); -- 0.8
	END RECORD;
	TYPE arr_pix IS ARRAY (natural RANGE <>) OF type_pix;
	TYPE arr_pixq IS ARRAY(natural RANGE <>) OF arr_pix(0 TO 3);
	ATTRIBUTE ramstyle : string;

	SUBTYPE uint12 IS natural RANGE 0 TO 4095;
	SUBTYPE uint13 IS natural RANGE 0 TO 8191;

	TYPE arr_uv48 IS ARRAY (natural RANGE <>) OF unsigned(47 DOWNTO 0);
	TYPE arr_uv24 IS ARRAY (natural RANGE <>) OF unsigned(23 DOWNTO 0);
	TYPE arr_uv40 IS ARRAY (natural RANGE <>) OF unsigned(39 DOWNTO 0);
	TYPE arr_int9 IS ARRAY (natural RANGE <>) OF integer RANGE -256 TO 255;
	TYPE arr_uint12 IS ARRAY (natural RANGE <>) OF uint12;
	TYPE arr_frac IS ARRAY (natural RANGE <>) OF unsigned(11 DOWNTO 0);
	TYPE arr_div IS ARRAY (natural RANGE <>) OF unsigned(20 DOWNTO 0);

	----------------------------------------------------------
	-- Input image
	SIGNAL i_pvs,i_pde,i_pce : std_logic;
	-- A deterministic progressive field history avoids a false interlace
	-- detection on the first pixel-enable after reset when i_fl is held low.
	SIGNAL i_pfl : std_logic := '0';
	SIGNAL i_ppix : type_pix;
	SIGNAL i_freeze : std_logic;
	SIGNAL i_bob_deint : std_logic;
	-- Power-up value keeps the legacy header's modulo-8 frame hint defined.
	-- Exact capture identity is the bounded native checkpoint alone.
	SIGNAL i_count : unsigned(2 DOWNTO 0) := (OTHERS=>'0');
	SIGNAL i_hsize,i_hmin,i_hmax,i_hcpt : uint12;
	SIGNAL i_hrsize,i_vrsize : uint12;
	SIGNAL i_himax,i_vimax : uint12;
	SIGNAL i_vsize,i_vmaxmin,i_vmin,i_vmax,i_vcpt : uint12;
	SIGNAL i_iauto : std_logic;
	SIGNAL i_mode : unsigned(4 DOWNTO 0);
	SIGNAL i_format : unsigned(1 DOWNTO 0);
	SIGNAL i_ven,i_sof : std_logic;
	SIGNAL i_wr : std_logic;
	SIGNAL i_divstart,i_divrun : std_logic;
	SIGNAL i_de_pre,i_vs_pre : std_logic;
	SIGNAL i_fl_pre : std_logic := '0';
	SIGNAL i_de_delay : natural RANGE 0 TO 31;
	SIGNAL i_intercnt : natural RANGE 0 TO 3;
	SIGNAL i_inter,i_half,i_flm : std_logic;
	SIGNAL i_wfl : std_logic_vector(2 DOWNTO 0);
	SIGNAL i_write,i_wreq,i_alt,i_line,i_wline,i_wline_mem : std_logic;
	SIGNAL i_walt,i_walt_mem,i_wreq_mem : std_logic;
	SIGNAL i_wdelay : natural RANGE 0 TO 7;
	SIGNAL i_push,i_pushend,i_pushend2 : std_logic;
	SIGNAL i_eol : std_logic;
	SIGNAL i_pushhead,i_pushhead2,i_pushhead3 : std_logic;
	SIGNAL i_hburst,i_hbcpt : natural RANGE 0 TO 31;
	SIGNAL i_shift : unsigned(0 TO 119) := (OTHERS =>'0');
	SIGNAL i_head : unsigned(127 DOWNTO 0);
	SIGNAL i_acpt : natural RANGE 0 TO 15;
	-- A partially filled last burst retains prior bytes in its padding. Give
	-- its first use a defined power-up value as well as later frame reuse.
	SIGNAL i_dpram : arr_dw(0 TO BLEN*2-1) := (OTHERS=>(OTHERS=>'0'));
	ATTRIBUTE ramstyle OF i_dpram : SIGNAL IS "no_rw_check";
	SIGNAL i_endframe0,i_endframe1,i_vss : std_logic;
	SIGNAL i_wad : natural RANGE  0 TO BLEN*2-1;
	SIGNAL i_dw : unsigned(N_DW-1 DOWNTO 0);
	SIGNAL i_adrs,i_adrsi,i_wadrs,i_wadrs_mem : unsigned(31 DOWNTO 0);
	SIGNAL i_reset_na : std_logic;
	SIGNAL i_hnp,i_vnp : std_logic;
	SIGNAL i_mem : arr_pix(0 TO IHRES-1); -- Downscale line buffer
	ATTRIBUTE ramstyle OF i_mem : SIGNAL IS "no_rw_check";
	SIGNAL i_ohsize,i_ovsize : uint12;
	SIGNAL i_vdivi   : unsigned(12 DOWNTO 0);
	SIGNAL i_vdivr   : unsigned(24 DOWNTO 0);
	SIGNAL i_div     : unsigned(16 DOWNTO 0);
	SIGNAL i_dir     : unsigned(11 DOWNTO 0);
	SIGNAL i_h_frac,i_v_frac : unsigned(11 DOWNTO 0);
	SIGNAL i_hacc,i_vacc     : uint13;
	SIGNAL i_hdown,i_vdown   : std_logic;
	SIGNAL i_divcpt : natural RANGE 0 TO 36;
	SIGNAL i_lwad,i_lrad : natural RANGE 0 TO OHRESH-1;
	SIGNAL i_lwr,i_bil : std_logic;
	SIGNAL i_ldw,i_ldrm : type_pix;
	SIGNAL i_hpixp,i_hpix0,i_hpix1,i_hpix2,i_hpix3,i_hpix4 : type_pix;
	SIGNAL i_hpix,i_pix : type_pix;
	SIGNAL i_hnp1,i_hnp2,i_hnp3,i_hnp4 : std_logic;
	SIGNAL i_ven1,i_ven2,i_ven3,i_ven4,i_ven5,i_ven6 : std_logic;

	----------------------------------------------------------
	-- Avalon
	TYPE type_avl_state IS (sIDLE,sWRITE,sREAD);
	SIGNAL avl_state : type_avl_state;
	SIGNAL avl_write_i,avl_write_sync,avl_write_sync2 : std_logic;
	SIGNAL avl_read_i,avl_read_sync,avl_read_sync2 : std_logic;
	SIGNAL avl_read_pulse,avl_write_pulse : std_logic;
	SIGNAL avl_read_sr,avl_write_sr,avl_read_clr,avl_write_clr : std_logic;
	SIGNAL avl_rad,avl_rad_c,avl_wad : natural RANGE 0 TO 2*BLEN-1;
	SIGNAL avl_walt,avl_wline,avl_rline : std_logic;
	SIGNAL avl_dw,avl_dr : unsigned(N_DW-1 DOWNTO 0);
	SIGNAL avl_wr : std_logic;
	SIGNAL avl_readdataack,avl_readack : std_logic;
	SIGNAL avl_radrs,avl_wadrs : unsigned(31 DOWNTO 0);
	SIGNAL avl_i_offset0,avl_o_offset0 : unsigned(31 DOWNTO 0);
	SIGNAL avl_i_offset1,avl_o_offset1 : unsigned(31 DOWNTO 0);
	SIGNAL avl_reset_na : std_logic;
	SIGNAL avl_o_vs_sync,avl_o_vs : std_logic;
	SIGNAL avl_fb_ena : std_logic;

	FUNCTION buf_next(a,b : natural RANGE 0 TO 2; freeze : std_logic := '0') RETURN natural IS
	BEGIN
		IF (freeze='1') THEN RETURN a; END IF;
		IF (a=0 AND b=1) OR (a=1 AND b=0) THEN RETURN 2; END IF;
		IF (a=1 AND b=2) OR (a=2 AND b=1) THEN RETURN 0; END IF;
		RETURN 1;
	END FUNCTION;
	FUNCTION buf_offset(b : natural RANGE 0 TO 2;
								base : unsigned(31 DOWNTO 0);
								size : unsigned(31 DOWNTO 0)) RETURN unsigned IS
	BEGIN
		IF b=1 THEN RETURN base+size; END IF;
		IF b=2 THEN RETURN base+(size(30 DOWNTO 0) & '0'); END IF;
		RETURN base;
	END FUNCTION;
	FUNCTION crc32_ieee_byte(crc_in : unsigned(31 DOWNTO 0);
	                         data : std_logic_vector(7 DOWNTO 0)) RETURN unsigned IS
		VARIABLE crc_v : unsigned(31 DOWNTO 0);
	BEGIN
		crc_v:=crc_in XOR resize(unsigned(data),32);
		FOR bit_idx IN 0 TO 7 LOOP
			IF crc_v(0)='1' THEN crc_v:=shift_right(crc_v,1) XOR x"EDB88320";
			ELSE crc_v:=shift_right(crc_v,1);
			END IF;
		END LOOP;
		RETURN crc_v;
	END FUNCTION;
	SUBTYPE capture_byte_t IS std_logic_vector(7 DOWNTO 0);
	FUNCTION capture_u32_byte(value : unsigned(31 DOWNTO 0); byte_lane : natural)
		RETURN capture_byte_t IS
	BEGIN
		CASE byte_lane IS
			WHEN 0 => RETURN std_logic_vector(value(7 DOWNTO 0));
			WHEN 1 => RETURN std_logic_vector(value(15 DOWNTO 8));
			WHEN 2 => RETURN std_logic_vector(value(23 DOWNTO 16));
			WHEN 3 => RETURN std_logic_vector(value(31 DOWNTO 24));
			WHEN OTHERS => RETURN x"00";
		END CASE;
	END FUNCTION;
	FUNCTION capture_gfw1_step(hash_value,word_value : unsigned(31 DOWNTO 0)) RETURN unsigned IS
		VARIABLE shifted : unsigned(31 DOWNTO 0);
	BEGIN
		shifted:=shift_left(hash_value,1);
		IF hash_value(31)='1' THEN shifted:=shifted XOR x"00400007"; END IF;
		RETURN shifted XOR word_value;
	END FUNCTION;
	FUNCTION capture_metadata_byte(
		header : unsigned(127 DOWNTO 0);
		checkpoint : unsigned(14 DOWNTO 0);
		base,stride,payload,burst_count,pixel_hash : unsigned(31 DOWNTO 0);
		slot : natural RANGE 0 TO 2;
		fb_enabled : std_logic;
		crc : unsigned(31 DOWNTO 0);
		byte_index : natural
	) RETURN capture_byte_t IS
		VARIABLE descriptor_index,byte_lane : natural RANGE 0 TO 63;
		VARIABLE width_v,height_v,pitch_v,mode_v,value_v : unsigned(31 DOWNTO 0);
		VARIABLE previous_checkpoint_v : unsigned(14 DOWNTO 0);
	BEGIN
		descriptor_index:=byte_index-192;
		width_v:=resize(header(79 DOWNTO 64),32);
		height_v:=resize(header(63 DOWNTO 48),32);
		pitch_v:=resize(header(47 DOWNTO 32),32);
		mode_v:=to_unsigned(1+slot*256+1024+2048,32);
		IF fb_enabled='1' THEN mode_v:=mode_v+4096; END IF;
		previous_checkpoint_v:=checkpoint-1;
		CASE descriptor_index IS
			WHEN 0  => RETURN x"4A"; -- JTC2, byte0 in bits7:0
			WHEN 1  => RETURN x"54";
			WHEN 2  => RETURN x"43";
			WHEN 3  => RETURN x"32";
			WHEN 4  => RETURN x"02";
			WHEN 5  => RETURN x"00";
			WHEN 6  => RETURN x"40";
			WHEN 7  => RETURN x"00";
			WHEN 8  => RETURN std_logic_vector(checkpoint(7 DOWNTO 0));
			WHEN 9  => RETURN '0' & std_logic_vector(checkpoint(14 DOWNTO 8));
			WHEN 10 => RETURN std_logic_vector(previous_checkpoint_v(7 DOWNTO 0));
			WHEN 11 => RETURN '0' & std_logic_vector(previous_checkpoint_v(14 DOWNTO 8));
			WHEN 12 TO 15 => value_v:=base; byte_lane:=descriptor_index-12;
			WHEN 16 TO 19 => value_v:=stride; byte_lane:=descriptor_index-16;
			WHEN 20 => RETURN std_logic_vector(width_v(7 DOWNTO 0));
			WHEN 21 => RETURN std_logic_vector(width_v(15 DOWNTO 8));
			WHEN 22 => RETURN std_logic_vector(height_v(7 DOWNTO 0));
			WHEN 23 => RETURN std_logic_vector(height_v(15 DOWNTO 8));
			WHEN 24 TO 27 => value_v:=pitch_v; byte_lane:=descriptor_index-24;
			WHEN 28 TO 31 => value_v:=payload; byte_lane:=descriptor_index-28;
			WHEN 32 TO 35 => value_v:=mode_v; byte_lane:=descriptor_index-32;
			WHEN 36 TO 39 => value_v:=burst_count; byte_lane:=descriptor_index-36;
			WHEN 40 TO 43 => value_v:=x"31574647"; byte_lane:=descriptor_index-40;
			WHEN 44 TO 47 => value_v:=pixel_hash; byte_lane:=descriptor_index-44;
			WHEN 56 TO 59 => value_v:=crc; byte_lane:=descriptor_index-56;
			WHEN 60 => RETURN x"52"; -- RDY2, byte0 in bits7:0
			WHEN 61 => RETURN x"44";
			WHEN 62 => RETURN x"59";
			WHEN 63 => RETURN x"32";
			WHEN OTHERS => RETURN x"00";
		END CASE;
		RETURN capture_u32_byte(value_v,byte_lane);
	END FUNCTION;
	FUNCTION capture_descriptor_result(
		header : unsigned(127 DOWNTO 0);
		checkpoint : unsigned(14 DOWNTO 0);
		base,stride,payload,burst_count,pixel_hash : unsigned(31 DOWNTO 0);
		slot : natural RANGE 0 TO 2;
		fb_enabled : std_logic;
		crc : unsigned(31 DOWNTO 0)
	) RETURN std_logic_vector IS
		VARIABLE result_v : std_logic_vector(511 DOWNTO 0);
	BEGIN
		FOR byte_index IN 0 TO 63 LOOP
			result_v(byte_index*8+7 DOWNTO byte_index*8):=capture_metadata_byte(
				header,checkpoint,base,stride,payload,burst_count,pixel_hash,slot,fb_enabled,crc,192+byte_index);
		END LOOP;
		RETURN result_v;
	END FUNCTION;

	----------------------------------------------------------
	-- Output
	SIGNAL o_run : std_logic;
	SIGNAL o_freeze : std_logic;
	SIGNAL o_bob_deint : std_logic;
	SIGNAL o_iwfl : std_logic_vector(2 DOWNTO 0);
	SIGNAL o_mode,o_hmode,o_vmode : unsigned(4 DOWNTO 0);
	SIGNAL o_format : unsigned(5 DOWNTO 0);
	SIGNAL o_fb_pal_dr : unsigned(23 DOWNTO 0);
	SIGNAL o_fb_pal_dr2 : unsigned(23 DOWNTO 0);
	SIGNAL o_fb_pal_dr_x2 : unsigned(47 DOWNTO 0);
	SIGNAL pal_idx: unsigned(7 DOWNTO 0);
	SIGNAL pal_idx_lsb: std_logic;
	SIGNAL pal1_mem : arr_uv48(0 TO 127);
	SIGNAL pal2_mem : arr_uv24(0 TO 255);
	ATTRIBUTE ramstyle of pal1_mem : signal is "no_rw_check";
	ATTRIBUTE ramstyle of pal2_mem : signal is "no_rw_check";
	SIGNAL o_htotal,o_hsstart,o_hsend : uint12;
	SIGNAL o_hmin,o_hmax,o_hdisp,o_v_hmin_adj : uint12;
	SIGNAL o_hsize,o_vsize : uint12;
	SIGNAL o_vtotal,o_vsstart,o_vsend : uint12;
	SIGNAL o_vrr,o_isync,o_isync2 : std_logic;
	SIGNAL o_vrr_sync,o_vrr_sync2 : boolean;
	SIGNAL o_vrr_min,o_vrr_min2 : boolean;
	SIGNAL o_vrr_max,o_vrr_max2 : boolean;
	SIGNAL o_vcpt_sync,o_vcpt_sync2, o_vrrmax : uint12;
	SIGNAL o_sync, o_sync_max : boolean;
	SIGNAL o_vmin,o_vmax,o_vdisp : uint12;
	SIGNAL o_divcpt : natural RANGE 0 TO 36;
	SIGNAL o_iendframe0,o_iendframe02,o_iendframe1,o_iendframe12 : std_logic;
	SIGNAL o_bufup0,o_bufup1,o_inter : std_logic;
	SIGNAL o_ibuf0,o_ibuf1,o_obuf0,o_obuf1 : natural RANGE 0 TO 2;
	TYPE enum_o_state IS (sDISP,sHSYNC,sREAD,sWAITREAD);
	SIGNAL o_state : enum_o_state;
	TYPE enum_o_copy IS (sWAIT,sSHIFT,sCOPY);
	SIGNAL o_copy : enum_o_copy;
	SIGNAL o_pshift : natural RANGE 0 TO 15;
	SIGNAL o_readack,o_readack_sync,o_readack_sync2 : std_logic;
	SIGNAL o_readdataack,o_readdataack_sync,o_readdataack_sync2 : std_logic;
	SIGNAL o_copyv : unsigned(0 TO 14);
	SIGNAL o_adrs : unsigned(31 DOWNTO 0); -- Avalon address
	SIGNAL o_adrs_pre : natural RANGE 0 TO 2**24-1;
	SIGNAL o_stride : unsigned(13 DOWNTO 0);
	SIGNAL o_adrsa,o_adrsb,o_rline : std_logic;
	SIGNAL o_ad,o_ad1,o_ad2,o_ad3 : natural RANGE 0 TO 2*BLEN-1;
	SIGNAL o_adturn : std_logic;
	SIGNAL o_dr : unsigned(N_DW-1 DOWNTO 0);
	SIGNAL o_shift : unsigned(0 TO N_DW+15);
	SIGNAL o_sh,o_sh1,o_sh2,o_sh3,o_sh4 : std_logic;
	SIGNAL o_reset_na : std_logic;
	SIGNAL o_dpram : arr_dw(0 TO BLEN*2-1);
	ATTRIBUTE ramstyle OF o_dpram : SIGNAL IS "no_rw_check";
	SIGNAL o_line0,o_line1,o_line2,o_line3 : arr_pix(0 TO OHRESL-1);
	SIGNAL o_linf0,o_linf1,o_linf2,o_linf3 : arr_pix(0 TO OHRESM-1);

	ATTRIBUTE ramstyle OF o_line0 : SIGNAL IS "no_rw_check";
	ATTRIBUTE ramstyle OF o_line1 : SIGNAL IS "no_rw_check";
	ATTRIBUTE ramstyle OF o_line2 : SIGNAL IS "no_rw_check";
	ATTRIBUTE ramstyle OF o_line3 : SIGNAL IS "no_rw_check";
	ATTRIBUTE ramstyle OF o_linf0 : SIGNAL IS "no_rw_check";
	ATTRIBUTE ramstyle OF o_linf1 : SIGNAL IS "no_rw_check";
	ATTRIBUTE ramstyle OF o_linf2 : SIGNAL IS "no_rw_check";
	ATTRIBUTE ramstyle OF o_linf3 : SIGNAL IS "no_rw_check";
	SIGNAL o_wadl,o_radl0,o_radl1,o_radl2,o_radl3 : natural RANGE 0 TO OHRESH-1;
	SIGNAL o_ldr0,o_ldr1,o_ldr2,o_ldr3,o_ldw : type_pix;
	SIGNAL o_ler0,o_ler1,o_ler2,o_ler3       : type_pix;
	SIGNAL o_lex0,o_lex1,o_lex2,o_lex3       : std_logic;
	SIGNAL o_wr : unsigned(3 DOWNTO 0);
	SIGNAL o_hcpt,o_vcpt,o_vcpt_pre,o_vcpt_pre2,o_vcpt_pre3,o_vcpt2 : uint12;
	SIGNAL o_ihsize,o_ihsizem,o_ivsize : uint12;
	SIGNAL o_ihsize_temp, o_ihsize_temp2 : natural RANGE 0 TO 32767;

	SIGNAL o_vfrac : unsigned(11 DOWNTO 0);
	SIGNAL o_hfrac : arr_frac(0 TO 9);
	ATTRIBUTE ramstyle OF o_hfrac : SIGNAL IS "logic"; -- avoid blockram shift register

	SIGNAL o_hacc,o_hacc_ini,o_hacc_next,o_vacc,o_vacc_next,o_vacc_ini : natural RANGE 0 TO 4*OHRESH-1;
	SIGNAL o_hsv,o_vsv,o_dev,o_pev,o_bzl,o_end : unsigned(0 TO 11);
	SIGNAL o_hsp,o_vss : std_logic;
	SIGNAL o_vcarrym,o_prim : boolean;
	SIGNAL o_read,o_read_pre : std_logic;
	SIGNAL o_readlev,o_copylev : natural RANGE 0 TO 2;
	SIGNAL o_hburst,o_hbcpt : natural RANGE 0 TO 31;
	SIGNAL o_fload : natural RANGE 0 TO 3;
	SIGNAL o_acpt,o_acpt1,o_acpt2,o_acpt3,o_acpt4 : natural RANGE 0 TO 15; -- Alternance pixels FIFO
	SIGNAL o_dshi : natural RANGE 0 TO 3;
	SIGNAL o_first,o_last,o_last1,o_last2 : std_logic;
	SIGNAL o_lastt1,o_lastt2,o_lastt3,o_lastt4 : std_logic;
	SIGNAL o_alt,o_altx : unsigned(3 DOWNTO 0);
	SIGNAL o_hdown,o_vdown : std_logic;
	SIGNAL o_primv,o_lastv,o_bibv : unsigned(0 TO 2);
	TYPE arr_uint4 IS ARRAY (natural RANGE <>) OF natural RANGE 0 TO 15;
	SIGNAL o_off : arr_uint4(0 TO 2);
	SIGNAL o_bibu : std_logic :='0';
	SIGNAL o_dcptv : arr_uint12(13 TO 14);
	SIGNAL o_dcpt_clr, o_dcpt_inc : std_logic;
	SIGNAL o_dcptv_clr, o_dcptv_inc : std_logic_vector(1 TO 12);
	SIGNAL o_hpixs,o_hpix0,o_hpix1,o_hpix2,o_hpix3 : type_pix;
	SIGNAL o_hpixq : arr_pixq(2 TO 8);
	ATTRIBUTE ramstyle OF o_hpixq : SIGNAL IS "logic"; -- avoid blockram shift register
	SIGNAL o_vpixq, o_vpixq_pre : arr_pix(0 TO 3);
	SIGNAL o_vpix_outer : arr_pix(0 TO 2);
	SIGNAL o_vpix_inner : arr_pix(0 TO 6);

	SIGNAL o_vpe : std_logic;
	SIGNAL o_div : arr_div(0 TO 2); --uint12;
	SIGNAL o_dir : arr_frac(0 TO 2);
	ATTRIBUTE ramstyle OF o_div, o_dir : SIGNAL IS "logic"; -- avoid blockram shift register
	SIGNAL o_vdivi : unsigned(12 DOWNTO 0);
	SIGNAL o_vdivr : unsigned(24 DOWNTO 0);
	SIGNAL o_divstart : std_logic;
	SIGNAL o_divrun : std_logic;
	SIGNAL o_hacpt,o_vacpt : unsigned(11 DOWNTO 0);
	SIGNAL o_vacptl : unsigned(1 DOWNTO 0);
	signal o_newres : integer range 0 to 3;

	-----------------------------------------------------------------------------
	FUNCTION shift_ishift(shift : unsigned(0 TO 119);
												pix   : type_pix;
												format : unsigned(1 DOWNTO 0)) RETURN unsigned IS
	BEGIN
		CASE format IS
			WHEN "01" => -- 24bpp
				RETURN shift(24 TO 119) & pix.r & pix.g & pix.b;
			WHEN "10" => -- 32bpp
				RETURN shift(32 TO 119) & pix.r & pix.g & pix.b & x"00";
			WHEN OTHERS => -- 16bpp 565
				RETURN shift(16 TO 119) &
					pix.g(4 DOWNTO 2) & pix.r(7 DOWNTO 3) &
					pix.b(7 DOWNTO 3) & pix.g(7 DOWNTO 5);
		END CASE;
	END FUNCTION;

	FUNCTION shift_ipack(i_dw   : unsigned(N_DW-1 DOWNTO 0);
	                     acpt   : natural RANGE 0 TO 15;
	                     shift  : unsigned(0 TO 119);
	                     pix    : type_pix;
	                     format : unsigned(1 DOWNTO 0)) RETURN unsigned IS
		VARIABLE dw : unsigned(N_DW-1 DOWNTO 0);
	BEGIN
		dw:=i_dw;
		CASE format IS
			WHEN "01" => -- 24bpp
				IF N_DW=128 THEN
					IF    acpt=5 THEN  dw:=shift(0 TO 119) & pix.r;
					ELSIF acpt=10 THEN dw:=shift(8 TO 119) & pix.r & pix.g;
					ELSIF acpt=15 THEN dw:=shift(16 TO 119) & pix.r & pix.g & pix.b;
					END IF;
				ELSE -- N_DW=64
					IF    (acpt MOD 8)=2 THEN dw:=shift(72 TO 119) & pix.r & pix.g;
					ELSIF (acpt MOD 8)=5 THEN dw:=shift(64 TO 119) & pix.r;
					ELSIF (acpt MOD 8)=7 THEN dw:=shift(80 TO 119) & pix.r & pix.g & pix.b;
					END IF;
				END IF;
			WHEN "10" => -- 32bpp
				IF (N_DW=128 AND (acpt MOD 4)=3) OR (N_DW=64 AND (acpt MOD 8)=7) THEN
					dw:=shift(128-N_DW+24 TO 119) & pix.r & pix.g & pix.b & x"00";
				END IF;
			WHEN OTHERS => -- 16bpp 565
				IF (N_DW=128 AND (acpt MOD 8)=7) OR (N_DW=64 AND (acpt MOD 4)=3) THEN
					dw:=shift(128-N_DW+8 TO 119) & pix.g(4 DOWNTO 2) & pix.r(7 DOWNTO 3) &
							 pix.b(7 DOWNTO 3) & pix.g(7 DOWNTO 5);
				END IF;
		END CASE;
		RETURN dw;
	END FUNCTION;

	FUNCTION shift_inext (acpt   : natural RANGE 0 TO 15;
								 format : unsigned(1 DOWNTO 0)) RETURN boolean IS
	BEGIN
		CASE format IS
			WHEN "01" => -- 24bpp
				RETURN (N_DW=128 AND (acpt=5 OR acpt=10 OR acpt=15)) OR
						 (N_DW=64  AND ((acpt MOD 8)=2 OR (acpt MOD 8)=5 OR (acpt MOD 8)=7));
			WHEN "10" => -- 32bpp
				RETURN (N_DW=128 AND ((acpt MOD 4)=3)) OR
						 (N_DW=64  AND ((acpt MOD 2)=1));
			WHEN OTHERS => -- 16bpp
				RETURN (N_DW=128 AND ((acpt MOD 8)=7)) OR
						 (N_DW=64  AND ((acpt MOD 4)=3));
		END CASE;
	END FUNCTION;

	FUNCTION shift_opack(acpt   : natural RANGE 0 TO 15;
								shift  : unsigned(0 TO N_DW+15);
								dr     : unsigned(N_DW-1 DOWNTO 0);
								format : unsigned(5 DOWNTO 0)) RETURN unsigned IS
		VARIABLE shift_v : unsigned(0 TO N_DW+15);
	BEGIN
		CASE format(2 DOWNTO 0) IS
			WHEN "011" => -- 8bpp
				IF (N_DW=128 AND acpt=0) OR (N_DW=64 AND (acpt MOD 8)=0) THEN
					shift_v:=dr & dr(15 DOWNTO 0);
				ELSE
					shift_v:=shift(8 TO N_DW+15) & dr(7 DOWNTO 0);
				END IF;

			WHEN "100" => -- 16bpp
				IF (N_DW=128 AND (acpt MOD 8)=0) OR (N_DW=64 AND (acpt MOD 4)=0) THEN
					shift_v:=dr & dr(15 DOWNTO 0);
				ELSE
					shift_v:=shift(16 TO N_DW+15) & dr(15 DOWNTO 0);
				END IF;

			WHEN "101" => -- 24bpp
				IF N_DW=128 THEN
					IF acpt=0 THEN
						shift_v:=dr & dr(15 DOWNTO 0);
					ELSIF acpt=5 THEN
						shift_v:=shift(24 TO 31) & dr & dr(7 DOWNTO 0);
					ELSIF acpt=10 THEN
						shift_v:=shift(24 TO 39) & dr;
					ELSE
						shift_v:=shift(24 TO N_DW+15) & dr(23 DOWNTO 0);
					END IF;
				ELSE -- N_DW=64
					IF (acpt MOD 8)=0 THEN
						shift_v:=dr & dr(15 DOWNTO 0);
					ELSIF (acpt MOD 8)=2 THEN
						shift_v:=shift(24 TO 39) & dr;
					ELSIF (acpt MOD 8)=5 THEN
						shift_v:=shift(24 TO 31) & dr & dr(7 DOWNTO 0);
					ELSE
						shift_v:=shift(24 TO N_DW+15) & dr(23 DOWNTO 0);
					END IF;
				END IF;
			WHEN OTHERS => -- 32bpp
				IF (N_DW=128 AND (acpt MOD 4)=0) OR (N_DW=64 AND (acpt MOD 2)=0) THEN
					shift_v:=dr & dr(15 DOWNTO 0);
				ELSE
					shift_v:=shift(32 TO N_DW+15) & dr(31 DOWNTO 0);
				END IF;
		END CASE;
		RETURN shift_v;
	END FUNCTION;

	FUNCTION shift_onext (acpt   : natural RANGE 0 TO 15;
								 format : unsigned(5 DOWNTO 0)) RETURN boolean IS
	BEGIN
		CASE format(2 DOWNTO 0) IS
			WHEN "011" => -- 8bpp
				RETURN (N_DW=128 AND acpt=0) OR
						 (N_DW=64  AND ((acpt MOD 8)=0));
			WHEN "100" => -- 16bpp
				RETURN (N_DW=128 AND ((acpt MOD 8)=0)) OR
						 (N_DW=64  AND ((acpt MOD 4)=0));
			WHEN "101" => -- 24bpp
				RETURN (N_DW=128 AND (acpt=0 OR acpt=5 OR acpt=10)) OR
						 (N_DW=64  AND ((acpt MOD 8)=0 OR (acpt MOD 8)=2 OR (acpt MOD 8)=5));
			WHEN OTHERS => -- 32bpp
				RETURN (N_DW=128 AND ((acpt MOD 4)=0)) OR
						 (N_DW=64  AND ((acpt MOD 2)=0));
		END CASE;
	END FUNCTION;

	FUNCTION shift_opix (shift  : unsigned(0 TO N_DW+15);
											 format : unsigned(5 DOWNTO 0)) RETURN type_pix IS
	BEGIN
		CASE format(3 DOWNTO 0) IS
			WHEN "0100" => -- 16bpp 565
				RETURN (b=>shift(8 TO 12) & shift(8 TO 10),
						  g=>shift(13 TO 15) & shift(0 TO 2) & shift(13 TO 14),
						  r=>shift(3 TO 7) & shift(3 TO 5));
			WHEN "1100" => -- 16bpp 1555
				RETURN (b=>shift(9 TO 13) & shift(9 TO 11),
						  g=>shift(14 TO 15) & shift(0 TO 2) & shift(14 TO 15) & shift(0),
						  r=>shift(3 TO 7) & shift(3 TO 5));
			WHEN "0101" | "0110" =>  -- 24bpp / 32bpp
				RETURN (r=>shift(0 TO 7),g=>shift(8 TO 15),b=>shift(16 TO 23));

			WHEN OTHERS =>
				RETURN (r=>shift(0 TO 7),g=>shift(8 TO 15),b=>shift(16 TO 23));

		END CASE;
	END FUNCTION;

	FUNCTION pixoffset(adrs   : unsigned(31 DOWNTO 0);
										 format : unsigned (5 DOWNTO 0)) RETURN natural IS
	BEGIN
		CASE format(2 DOWNTO 0) IS
			WHEN "011" => -- 8bbp
				RETURN to_integer(adrs(NB_LA-1 DOWNTO 0));
			WHEN "100" => -- 16bpp 565
				RETURN to_integer(adrs(NB_LA-1 DOWNTO 1));
			WHEN OTHERS => -- 32bpp
				RETURN to_integer(adrs(NB_LA-1 DOWNTO 2));
		END CASE;
	END FUNCTION;

	FUNCTION swap(d : unsigned(N_DW-1 DOWNTO 0)) RETURN unsigned IS
		VARIABLE e : unsigned(N_DW-1 DOWNTO 0);
	BEGIN
		IF BYTESWAP THEN
			FOR i IN 0 TO N_DW/8-1 LOOP
				e(i*8+7 DOWNTO i*8):=d(N_DW-i*8-1 DOWNTO N_DW-i*8-8);
			END LOOP;
			RETURN e;
		ELSE
			RETURN d;
		END IF;
	END FUNCTION swap;

	-----------------------------------------------------------------------------
	FUNCTION altx (a : unsigned(1 DOWNTO 0)) RETURN unsigned IS
	BEGIN
		CASE a IS
			WHEN "00"   => RETURN "0001";
			WHEN "01"   => RETURN "0010";
			WHEN "10"   => RETURN "0100";
			WHEN OTHERS => RETURN "1000";
		END CASE;
	END FUNCTION;

	-----------------------------------------------------------------------------
	FUNCTION bound(a : unsigned;
								 s : natural) RETURN unsigned IS
	BEGIN
		IF a(a'left)='1' THEN
			RETURN x"00";
		ELSIF a(a'left DOWNTO s)/=0 THEN
			RETURN x"FF";
		ELSE
			RETURN a(s-1 DOWNTO s-8);
		END IF;
	END FUNCTION bound;

	-----------------------------------------------------------------------------
	-- Nearest
	FUNCTION near_frac(f : unsigned) RETURN unsigned IS
		VARIABLE x : unsigned(FRAC-1 DOWNTO 0);
	BEGIN
		x:=(OTHERS =>f(f'left));
		RETURN x;
	END FUNCTION;

	SIGNAL o_h_near_frac,o_v_near_frac : unsigned(FRAC-1 DOWNTO 0);
	SIGNAL o_h_bil_frac,o_v_bil_frac : unsigned(FRAC-1 DOWNTO 0);
	SIGNAL o_h_bil_pix,o_v_bil_pix : type_pix;

	-----------------------------------------------------------------------------
	-- Nearest + Bilinear + Sharp Bilinear
	FUNCTION bil_frac(f : unsigned) RETURN unsigned IS
	BEGIN
		RETURN f(f'left DOWNTO f'left+1-FRAC);
	END FUNCTION;

	TYPE type_bil_t IS RECORD
		r,g,b : unsigned(8+FRAC DOWNTO 0);
	END RECORD;

	FUNCTION bil_calc(f : unsigned(FRAC-1 DOWNTO 0);
							p : arr_pix(0 TO 3)) RETURN type_bil_t IS
		VARIABLE fp,fn : unsigned(FRAC DOWNTO 0);
		VARIABLE u : unsigned(8+FRAC DOWNTO 0);
		VARIABLE x : type_bil_t;
		CONSTANT Z : unsigned(FRAC-1 DOWNTO 0):=(OTHERS =>'0');
	BEGIN
		fp:=('0' & f) + (Z & f(FRAC-1));
		fn:=('1' & Z) - fp;
		u:=p(2).r * fp + p(1).r * fn;
		x.r:=u;
		u:=p(2).g * fp + p(1).g * fn;
		x.g:=u;
		u:=p(2).b * fp + p(1).b * fn;
		x.b:=u;
		RETURN x;
	END FUNCTION;

	FUNCTION near_calc(f : unsigned(FRAC-1 DOWNTO 0);
							 p : arr_pix(0 TO 3)) RETURN type_bil_t IS
		VARIABLE fp,fn : unsigned(FRAC DOWNTO 0);
		VARIABLE u : unsigned(8+FRAC DOWNTO 0);
		VARIABLE x : type_bil_t;
		CONSTANT Z : unsigned(FRAC-1 DOWNTO 0):=(OTHERS =>'0');
	BEGIN
		IF f(FRAC-1)='0' THEN
			x.r := '0' & p(1).r & Z;
			x.g := '0' & p(1).g & Z;
			x.b := '0' & p(1).b & Z;
		ELSE
			x.r := '0' & p(2).r & Z;
			x.g := '0' & p(2).g & Z;
			x.b := '0' & p(2).b & Z;
		END IF;
		RETURN x;
	END FUNCTION;

	SIGNAL o_h_bil_t,o_v_bil_t : type_bil_t;
	SIGNAL o_h_near_t,o_v_near_t : type_bil_t;
	SIGNAL i_h_bil_t : type_bil_t;

	-----------------------------------------------------------------------------
	-- Sharp Bilinear
	--  <0.5 : x*x*x*4
	--  >0.5 : 1 - (1-x)*(1-x)*(1-x)*4

	TYPE type_sbil_tt IS RECORD
		f : unsigned(FRAC-1 DOWNTO 0);
		s : unsigned(FRAC-1 DOWNTO 0);
	END RECORD;

	SIGNAL o_h_sbil_t,o_v_sbil_t : type_sbil_tt;

	FUNCTION sbil_frac1(f : unsigned(11 DOWNTO 0)) RETURN type_sbil_tt IS
		VARIABLE u : unsigned(FRAC-1 DOWNTO 0);
		VARIABLE v : unsigned(2*FRAC-1 DOWNTO 0);
		VARIABLE x : type_sbil_tt;
	BEGIN
		IF f(11)='0' THEN
			u:=f(11 DOWNTO 12-FRAC);
		ELSE
			u:=NOT f(11 DOWNTO 12-FRAC);
		END IF;
		v:=u*u;
		x.f:=u;
		x.s:=v(2*FRAC-2 DOWNTO FRAC-1);
		RETURN x;
	END FUNCTION;

	FUNCTION sbil_frac2(f : unsigned(11 DOWNTO 0);
							  t : type_sbil_tt) RETURN unsigned IS
		VARIABLE v : unsigned(2*FRAC-1 DOWNTO 0);
	BEGIN
		v:=t.f*t.s;
		IF f(11)='0' THEN
			RETURN v(2*FRAC-2 DOWNTO FRAC-1);
		ELSE
			RETURN NOT v(2*FRAC-2 DOWNTO FRAC-1);
		END IF;
	END FUNCTION;

	-----------------------------------------------------------------------------
	-- Bicubic
	TYPE type_bic_abcd IS RECORD
		a  : unsigned(7 DOWNTO 0);  --  0.8
		b  : signed(8 DOWNTO 0);  --  0.9
		c  : signed(11 DOWNTO 0); -- 3.9
		d  : signed(10 DOWNTO 0); -- 2.9
		xx : signed(8 DOWNTO 0); -- X.X 1.8
	END RECORD;
	TYPE type_bic_pix_abcd IS RECORD
		r,g,b : type_bic_abcd;
	END RECORD;
	TYPE type_bic_tt1 IS RECORD -- Intermediate result
		r_bx,g_bx,b_bx    : signed(8 DOWNTO 0);  -- B.X 1.8
		r_cxx,g_cxx,b_cxx : signed(11 DOWNTO 0); -- C.XX 3.9
		r_dxx,g_dxx,b_dxx : signed(10 DOWNTO 0); -- D.XX 2.9
	END RECORD;
	TYPE type_bic_tt2 IS RECORD -- Intermediate result
		r_abxcxx,g_abxcxx,b_abxcxx : signed(9 DOWNTO 0); --  A + B.X + C.XX 2.8
		r_dxxx,g_dxxx,b_dxxx : signed(9 DOWNTO 0); -- D.X.X.X 2.8
	END RECORD;

	----------------------------------------------------------
	-- Y = A + B.X + C.X.X + D.X.X.X = A + X.(B + X.(C + X.D))
	-- A = Y(0)                                       0 .. 1    unsigned
	-- B = Y(1)/2 - Y(-1)/2                        -1/2 .. +1/2 signed
	-- C = Y(-1) - 5*Y(0)/2 + 2*Y(1) - Y(2)/2        -3 .. +3   signed
	-- D = -Y(-1)/2 + 3*Y(0)/2 - 3*Y(1)/2 + Y(2)/2   -2 .. +2   signed

	FUNCTION bic_calc0(f : unsigned(11 DOWNTO 0);
							 pm,p0,p1,p2 : unsigned(7 DOWNTO 0)) RETURN type_bic_abcd IS
		VARIABLE xx : signed(2*FRAC+1 DOWNTO 0); -- 2.(2*FRAC)
	BEGIN
		xx := signed('0' & f(11 DOWNTO 12-FRAC)) *
				signed('0' & f(11 DOWNTO 12-FRAC)); -- 2.(2*FRAC)
		RETURN type_bic_abcd'(
			a=>p0,-- 0.8
			b=>signed(('0' & p1) - ('0' & pm)), -- 0.9
			c=>signed(("000" & pm & '0') - ("00" & p0 & "00") - ("0000" & p0) +
						 ("00" & p1 & "00") - ("0000" & p2)), -- 3.9
			d=>signed(("00" & p0 & '0') - ("00" & p1 & '0') - ("000" & p1) +
						 ("000" & p0) + ("000" & p2) - ("000" & pm)), -- 2.9
			xx=>xx(2*FRAC DOWNTO 2*FRAC-8)); -- 1.8
	END FUNCTION;
	FUNCTION bic_calc0(f : unsigned(11 DOWNTO 0);
							 p : arr_pix(0 TO 3)) RETURN type_bic_pix_abcd IS
	BEGIN
		RETURN type_bic_pix_abcd'( r=>bic_calc0(f,p(0).r,p(1).r,p(2).r,p(3).r),
											g=>bic_calc0(f,p(0).g,p(1).g,p(2).g,p(3).g),
											b=>bic_calc0(f,p(0).b,p(1).b,p(2).b,p(3).b));
	END FUNCTION;

	----------------------------------------------------------
	-- Calc : B.X, C.XX, D.XX
	FUNCTION bic_calc1(f    : unsigned(11 DOWNTO 0);
							 abcd : type_bic_pix_abcd) RETURN type_bic_tt1 IS
		VARIABLE t : type_bic_tt1;
		VARIABLE bx : signed(9+FRAC DOWNTO 0); -- 1.(FRAC+9)
		VARIABLE cxx : signed(20 DOWNTO 0); -- 4.17
		VARIABLE dxx : signed(19 DOWNTO 0); -- 3.17
	BEGIN
		bx := abcd.r.b * signed('0' & f(11 DOWNTO 12-FRAC)); -- 1.(FRAC+9)
		t.r_bx:=bx(9+FRAC DOWNTO 9+FRAC-8); -- 1.8
		cxx:= abcd.r.c * abcd.r.xx; -- 3.9 * 1.8 = 4.17
		t.r_cxx:=cxx(19 DOWNTO 8); -- 3.9
		dxx:= abcd.r.d * abcd.r.xx; -- 2.9 * 1.8 = 3.17
		t.r_dxx:=dxx(18 DOWNTO 8); -- 2.9
		bx := abcd.g.b * signed('0' & f(11 DOWNTO 12-FRAC)); -- 1.(FRAC+9)
		t.g_bx:=bx(9+FRAC DOWNTO 9+FRAC-8); -- 1.8
		cxx:= abcd.g.c * abcd.g.xx; -- 3.9 * 1.8 = 4.17
		t.g_cxx:=cxx(19 DOWNTO 8); -- 3.9
		dxx:= abcd.g.d * abcd.g.xx; -- 2.9 * 1.8 = 3.17
		t.g_dxx:=dxx(18 DOWNTO 8); -- 2.9
		bx := abcd.b.b * signed('0' & f(11 DOWNTO 12-FRAC)); -- 1.(FRAC+9)
		t.b_bx:=bx(9+FRAC DOWNTO 9+FRAC-8); -- 1.8
		cxx:= abcd.b.c * abcd.b.xx; -- 3.9 * 1.8 = 4.17
		t.b_cxx:=cxx(19 DOWNTO 8); -- 3.9
		dxx:= abcd.b.d * abcd.b.xx; -- 2.9 * 1.8 = 3.17
		t.b_dxx:=dxx(18 DOWNTO 8); -- 2.9
		RETURN t;
	END FUNCTION;

	----------------------------------------------------------
	-- Calc A + BX + CXX , X.DXX
	FUNCTION bic_calc2(f    : unsigned(11 DOWNTO 0);
							 t    : type_bic_tt1;
							 abcd : type_bic_pix_abcd) RETURN type_bic_tt2 IS
		VARIABLE u : type_bic_tt2;
		VARIABLE x : signed(11+FRAC DOWNTO 0); -- 3.(9+FRAC)
	BEGIN
		u.r_abxcxx:=(t.r_bx(8) & t.r_bx) + ("00" & signed(abcd.r.a)) + t.r_cxx(10 DOWNTO 1); -- 2.8
		u.g_abxcxx:=(t.g_bx(8) & t.g_bx) + ("00" & signed(abcd.g.a)) + t.g_cxx(10 DOWNTO 1); -- 2.8
		u.b_abxcxx:=(t.b_bx(8) & t.b_bx) + ("00" & signed(abcd.b.a)) + t.b_cxx(10 DOWNTO 1); -- 2.8

		x:=t.r_dxx *  signed('0' & f(11 DOWNTO 12-FRAC)); --2.9 * 1.FRAC =3.(9+FRAC)
		u.r_dxxx:=x(10+FRAC DOWNTO 9+FRAC-8); -- 2.8
		x:=t.g_dxx *  signed('0' & f(11 DOWNTO 12-FRAC)); --2.9 * 1.FRAC =3.(9+FRAC)
		u.g_dxxx:=x(10+FRAC DOWNTO 9+FRAC-8); -- 2.8
		x:=t.b_dxx *  signed('0' & f(11 DOWNTO 12-FRAC)); --2.9 * 1.FRAC =3.(9+FRAC)
		u.b_dxxx:=x(10+FRAC DOWNTO 9+FRAC-8); -- 2.8
		RETURN u;
	END FUNCTION;

	----------------------------------------------------------
	-- Calc  (A + BX + CXX) + (DXXX)
	FUNCTION bic_calc3(f    : unsigned(11 DOWNTO 0);
							 t    : type_bic_tt2;
							 abcd : type_bic_pix_abcd) RETURN type_pix IS
		VARIABLE x : type_pix;
		VARIABLE v : signed(9 DOWNTO 0); -- 2.8
	BEGIN
		v:=t.r_abxcxx + t.r_dxxx;
		x.r:=bound(unsigned(v),8);
		v:=t.g_abxcxx + t.g_dxxx;
		x.g:=bound(unsigned(v),8);
		v:=t.b_abxcxx + t.b_dxxx;
		x.b:=bound(unsigned(v),8);
		RETURN x;
	END FUNCTION;

	-----------------------------------------------------------------------------
	SIGNAL o_h_bic_pix,o_v_bic_pix : type_pix;
	SIGNAL o_h_bic_abcd1,o_h_bic_abcd2 : type_bic_pix_abcd;
	SIGNAL o_v_bic_abcd1,o_v_bic_abcd2 : type_bic_pix_abcd;
	SIGNAL o_h_bic_tt1,o_v_bic_tt1 : type_bic_tt1;
	SIGNAL o_h_bic_tt2,o_v_bic_tt2 : type_bic_tt2;

	-----------------------------------------------------------------------------
	-- Polyphase
	-- 2.7
	TYPE poly_phase_t IS RECORD
		t0, t1, t2, t3  : signed(9 DOWNTO 0);
	END RECORD;

	-- 4.14
	TYPE poly_phase_interp_t IS RECORD
		t0, t1, t2, t3  : signed(17 DOWNTO 0);
	END RECORD;

	-- 5.22
	TYPE type_poly_t IS RECORD
		r0,r1,b0,b1,g0,g1 : signed(26 DOWNTO 0);
	END RECORD;

	SIGNAL o_h_poly_mem : arr_uv40(0 TO 2**FRAC-1);
	SIGNAL o_v_poly_mem : arr_uv40(0 TO 2**FRAC-1);
	SIGNAL o_a_poly_mem : arr_uv40(0 TO 2**FRAC-1);
	ATTRIBUTE ramstyle OF o_h_poly_mem : SIGNAL IS "no_rw_check";
	ATTRIBUTE ramstyle OF o_v_poly_mem : SIGNAL IS "no_rw_check";
	ATTRIBUTE ramstyle OF o_a_poly_mem : SIGNAL IS "no_rw_check";
	SIGNAL o_a_poly_addr, o_v_poly_addr : integer RANGE 0 TO 2**FRAC-1;
	SIGNAL o_h_poly_phase_a,o_h_poly_phase_a2,o_h_poly_phase_a3, o_h_poly_phase_a4, o_h_poly_phase_a5 : poly_phase_t;
	SIGNAL o_v_poly_phase_a,o_v_poly_phase_a2,o_v_poly_phase_a3, o_v_poly_phase_a4, o_v_poly_phase_a5 : poly_phase_t;
	SIGNAL o_poly_phase_a, o_poly_phase_a2, o_poly_phase_a3 : poly_phase_t;
	SIGNAL o_poly_phase_b,o_poly_phase_b2,o_poly_phase_b3 : poly_phase_t;
	SIGNAL o_v_poly_phase, o_v_poly_phase2, o_h_poly_phase, o_poly_phase, o_poly_phase1 : poly_phase_interp_t;
	SIGNAL o_v_poly_pix, o_h_poly_pix, o_h_lum_pix, o_v_lum_pix : type_pix;
	SIGNAL o_poly_lum, o_poly_lum1 : unsigned(7 DOWNTO 0);
	SIGNAL o_poly_lerp_ta, o_poly_lerp_tb : signed(9 DOWNTO 0);
	SIGNAL o_h_poly_t,o_h_poly_t2,o_v_poly_t   : type_poly_t;

	SIGNAL o_v_poly_adaptive, o_h_poly_adaptive, o_v_poly_use_adaptive, o_h_poly_use_adaptive : std_logic;
	SIGNAL poly_wr_mode : std_logic_vector(2 DOWNTO 0);
	SIGNAL poly_tdw : unsigned(39 DOWNTO 0);
	SIGNAL poly_a2 : unsigned(FRAC-1 DOWNTO 0);

	FUNCTION poly_unpack(a : unsigned(39 DOWNTO 0)) RETURN poly_phase_t IS
		VARIABLE v : poly_phase_t;
	BEGIN
		 v.t0 := signed(a(39 DOWNTO 30));
		 v.t1 := signed(a(29 DOWNTO 20));
		 v.t2 := signed(a(19 DOWNTO 10));
		 v.t3 := signed(a( 9 DOWNTO  0));
		RETURN v;
	END FUNCTION;

	-- 6 DSP 18*18 + 18*18
	FUNCTION poly_calc(fi : poly_phase_interp_t;
							 p  : arr_pix(0 TO 3)) RETURN type_poly_t IS
		VARIABLE t : type_poly_t;
	BEGIN
		-- 3.15 * 1.8 = 4.23
		t.r0:=(fi.t0 * signed('0' & p(0).r) +
					 fi.t1 * signed('0' & p(1).r));
		t.r1:=(fi.t2 * signed('0' & p(2).r) +
					 fi.t3 * signed('0' & p(3).r));
		t.g0:=(fi.t0 * signed('0' & p(0).g) +
					 fi.t1 * signed('0' & p(1).g));
		t.g1:=(fi.t2 * signed('0' & p(2).g) +
					 fi.t3 * signed('0' & p(3).g));
		t.b0:=(fi.t0 * signed('0' & p(0).b) +
					 fi.t1 * signed('0' & p(1).b));
		t.b1:=(fi.t2 * signed('0' & p(2).b) +
					 fi.t3 * signed('0' & p(3).b));
		RETURN t;
	END FUNCTION;

	FUNCTION poly_final(t : type_poly_t) RETURN type_pix IS
		VARIABLE p : type_pix;
	BEGIN
		p.r:=bound(unsigned(t.r0(26 DOWNTO 8)+t.r1(26 DOWNTO 8)),15);
		p.g:=bound(unsigned(t.g0(26 DOWNTO 8)+t.g1(26 DOWNTO 8)),15);
		p.b:=bound(unsigned(t.b0(26 DOWNTO 8)+t.b1(26 DOWNTO 8)),15);
		RETURN p;
	END FUNCTION;

	-- 4 DSP 18*18 + 18*18
	FUNCTION poly_lerp(a  : poly_phase_t;
							 b  : poly_phase_t;
							 ta : SIGNED(9 DOWNTO 0);
							 tb : SIGNED(9 DOWNTO 0)) RETURN poly_phase_interp_t IS
		VARIABLE v : poly_phase_interp_t;
		VARIABLE t0,t1,t2,t3 : signed(19 DOWNTO 0);
	BEGIN
		-- 2.8 * 2.8 = 4.16
		t0 := (a.t0 * ta) + (b.t0 * tb);
		t1 := (a.t1 * ta) + (b.t1 * tb);
		t2 := (a.t2 * ta) + (b.t2 * tb);
		t3 := (a.t3 * ta) + (b.t3 * tb);

		-- 4.16 -> 3.15
		v.t0 := t0(18 DOWNTO 1);
		v.t1 := t1(18 DOWNTO 1);
		v.t2 := t2(18 DOWNTO 1);
		v.t3 := t3(18 DOWNTO 1);

		RETURN v;
	END FUNCTION;

	FUNCTION poly_cvt(a : poly_phase_t) RETURN poly_phase_interp_t IS
		VARIABLE v : poly_phase_interp_t;
	BEGIN
		v.t0 := resize(signed( a.t0 & "0000000" ), v.t0'length);
		v.t1 := resize(signed( a.t1 & "0000000" ), v.t1'length);
		v.t2 := resize(signed( a.t2 & "0000000" ), v.t2'length);
		v.t3 := resize(signed( a.t3 & "0000000" ), v.t3'length);
		RETURN v;
	END FUNCTION;

	-- Nearest neighbor polyphase ceoffs
	FUNCTION poly_nn(frac : unsigned(FRAC-1 DOWNTO 0)) RETURN poly_phase_t IS
		VARIABLE v : poly_phase_t;
	BEGIN
		IF frac(frac'left)='0' THEN
			v := (t1=>to_signed(256, 10), OTHERS=>to_signed(0, 10));
		ELSE
			v := (t2=>to_signed(256, 10), OTHERS=>to_signed(0, 10));
		END IF;
		RETURN v;
	END FUNCTION;


	FUNCTION poly_lum(p : type_pix) RETURN unsigned IS
		VARIABLE v : UNSIGNED(7 DOWNTO 0);
	BEGIN
		-- 0.375 R + 0.5 G + 0.125 B
		--v := ("00" & p.r(7 DOWNTO 2)) + ("000" & p.r(7 DOWNTO 3)) + ("0" & p.g(7 DOWNTO 1)) + ("000" & p.b(7 DOWNTO 3));

		-- 0.25 R + 0.5 G + 0.25 B
		-- v := ( ("00" & p.r(7 DOWNTO 2)) + ("0" & p.g(7 DOWNTO 1)) + ("00" & p.b(7 DOWNTO 2)) );

		-- Just OR them all together
		--v := (p.r OR p.g OR p.b);

		-- Maximum
		IF p.r > p.g THEN
			v := p.r;
		ELSE
			v := p.g;
		END IF;

		IF p.b > v THEN
			v := p.b;
		END IF;

		-- 100%
		-- v := "1111111";

		RETURN v;
	END FUNCTION;

	-- Keep the byte-address shift at the Avalon address width. Shifting the
	-- bounded burst index before resize silently discarded high address bits.
	FUNCTION capture_byte_offset(index_i : unsigned) RETURN unsigned IS
		VARIABLE wide_v : unsigned(31 DOWNTO 0);
	BEGIN
		wide_v := resize(index_i, wide_v'length);
		RETURN shift_left(wide_v, NB_BURST);
	END FUNCTION;
	FUNCTION capture_expected_pixels(expected_count_i : unsigned) RETURN unsigned IS
	BEGIN
		-- Zero denotes an uninitialized/invalid target; avoid subtract underflow.
		IF expected_count_i=0 THEN RETURN to_unsigned(0,expected_count_i'length); END IF;
		RETURN expected_count_i-1;
	END FUNCTION;
BEGIN
	cap_target_pixel_bursts_i<=capture_expected_pixels(cap_target_expected_count_i);
	cap_target_payload_bytes_i<=capture_byte_offset(cap_target_pixel_bursts_i);
	-- synthesis translate_off
	CaptureTwoLeasesObserved: PROCESS(i_clk) IS
		VARIABLE reported : boolean := false;
	BEGIN
		IF rising_edge(i_clk) THEN
			IF i_reset_na='0' THEN reported:=false;
			ELSIF CAPTURE AND cap_state_i=x"02" AND cap_half_lease_i="11" AND NOT reported THEN
				REPORT "capture target held with both halves leased" SEVERITY note;
				reported:=true;
			END IF;
		END IF;
	END PROCESS;
	-- synthesis translate_on
	ASSERT 1+CAPTURE_MAX_PIXEL_BURSTS < 2**CAPTURE_REQUEST_COUNT_W
		REPORT "capture request counter width does not cover the bounded source geometry"
		SEVERITY failure;
	-- synthesis translate_off
	ASSERT capture_byte_offset(to_unsigned(511,CAPTURE_REQUEST_COUNT_W)) =
		to_unsigned(511*N_BURST,32) REPORT "capture byte offset 511 wrapped" SEVERITY failure;
	ASSERT capture_byte_offset(to_unsigned(512,CAPTURE_REQUEST_COUNT_W)) =
		to_unsigned(512*N_BURST,32) REPORT "capture byte offset 512 wrapped" SEVERITY failure;
	ASSERT capture_byte_offset(to_unsigned(CAPTURE_MAX_PIXEL_BURSTS,CAPTURE_REQUEST_COUNT_W)) =
		to_unsigned(CAPTURE_MAX_PIXEL_BURSTS*N_BURST,32)
		REPORT "maximum capture byte offset wrapped" SEVERITY failure;
	-- synthesis translate_on
	cap_req_ack_toggle<=cap_status_bundle_io(0);
	cap_release_ack_toggle<=cap_status_bundle_io(1);
	cap_abort_ack_toggle<=cap_status_bundle_io(2);
	cap_life_ack_toggle<=cap_status_bundle_io(3);
	cap_result_toggle<=cap_result_toggle_io;
	-- The descriptor record is held from publication until the next ARM.
	-- The UIO side invalidates its result before issuing that ARM.
	cap_result<=capture_descriptor_result(cap_target_header_i,
		cap_target_checkpoint_i,cap_target_base_i,RAMSIZE,cap_target_payload_bytes_i,
		resize(cap_target_request_count_i,32),cap_target_pixel_hash_i,
		cap_target_slot_i,'0',NOT cap_crc_state_i) WHEN cap_result_published_io='1'
		ELSE (OTHERS=>'0');
	cap_drain_ready_i<='1' WHEN CAPTURE AND
		(cap_session_ready_i='1' OR
		 (cap_life_valid_i='1' AND cap_life_state_i=x"00" AND cap_life_error_i=x"00")) AND
		cap_state_i=x"00" AND cap_owner_i='0' AND cap_cleanup_pending_i='0' AND
		cap_lifecycle_cancel_i='0' AND cap_life_sync2=cap_life_seen AND
		cap_tag_empty='1' AND cap_tag_valid_sync2_i='0' AND
		cap_result_ack_sync2_i=cap_result_toggle_i AND
		cap_fault_mailbox_ack_sync2_i=cap_fault_mailbox_toggle_sync2_i AND
		cap_fault_mailbox_ack_toggle_i=cap_fault_mailbox_toggle_sync2_i AND
		cap_avl_fault_clear_pending_i='0'
		ELSE '0';
	cap_status_state_i<=x"05" WHEN CAPTURE AND cap_state_i=x"00" AND cap_drain_ready_i='0'
		ELSE cap_state_i;
	cap_state<=x"04" WHEN cap_fault_override_io='1' AND cap_status_bundle_io(19 DOWNTO 12)/=x"00"
		ELSE cap_status_bundle_io(19 DOWNTO 12);
	-- The Avalon override can invalidate stale READY while i_clk is stopped,
	-- but must not replace an earlier first-fault already published by the
	-- controller. A later coherent controller status can still publish that
	-- original code after the independent override arrives.
	cap_fault<=cap_status_bundle_io(11 DOWNTO 4)
		WHEN cap_fault_override_io='1' AND cap_status_bundle_io(11 DOWNTO 4)/=x"00"
		ELSE cap_fault_mailbox_code_io WHEN cap_fault_override_io='1'
		ELSE cap_status_bundle_io(11 DOWNTO 4);
	-- Coherent capture status mailbox from the controller clock to CAP_IO_CLK.
	-- State, fault and controller acknowledgements move as one stable20-bit
	-- bundle so a completion cannot outrun the matching coherent status.
	CaptureStatusIo: PROCESS(cap_io_clk,cap_io_rst) IS
	BEGIN
		IF cap_io_rst='1' THEN
			cap_status_toggle_sync1_io<='0'; cap_status_toggle_sync2_io<='0'; cap_status_seen_io<='0';
			cap_status_ack_toggle_io<='0'; cap_status_bundle_io<=(OTHERS=>'0');
		ELSIF rising_edge(cap_io_clk) THEN
			cap_status_toggle_sync1_io<=cap_status_toggle_i;
			cap_status_toggle_sync2_io<=cap_status_toggle_sync1_io;
			IF cap_status_toggle_sync2_io/=cap_status_seen_io THEN
				cap_status_seen_io<=cap_status_toggle_sync2_io;
				cap_status_bundle_io<=cap_status_bundle_i;
				cap_status_ack_toggle_io<=cap_status_toggle_sync2_io;
			END IF;
		END IF;
	END PROCESS;

	-- An Avalon-clock watchdog can expire while i_clk is stopped. Publish its
	-- sticky fault independently so CAP_IO_CLK immediately invalidates stale
	-- READY; state remains ERROR until the controller later confirms cleanup.
	CaptureFaultIo: PROCESS(cap_io_clk,cap_io_rst) IS
	BEGIN
		IF cap_io_rst='1' THEN
			cap_fault_mailbox_toggle_sync1_io<='0'; cap_fault_mailbox_toggle_sync2_io<='0';
			cap_fault_mailbox_seen_io<='0'; cap_fault_mailbox_ack_toggle_io<='0';
			cap_fault_override_io<='0'; cap_fault_mailbox_code_io<=(OTHERS=>'0');
		ELSIF rising_edge(cap_io_clk) THEN
			cap_fault_mailbox_toggle_sync1_io<=cap_fault_mailbox_toggle_avl;
			cap_fault_mailbox_toggle_sync2_io<=cap_fault_mailbox_toggle_sync1_io;
			IF cap_fault_mailbox_toggle_sync2_io/=cap_fault_mailbox_seen_io THEN
				cap_fault_mailbox_seen_io<=cap_fault_mailbox_toggle_sync2_io;
				cap_fault_mailbox_code_io<=cap_fault_mailbox_avl;
				IF cap_fault_mailbox_avl/=x"00" THEN
					cap_fault_override_io<='1';
				ELSE
					cap_fault_override_io<='0';
				END IF;
				cap_fault_mailbox_ack_toggle_io<=cap_fault_mailbox_toggle_sync2_io;
			END IF;
		END IF;
	END PROCESS;

	-- The immutable descriptor crosses with its synchronized publication toggle.
	CaptureResultIo: PROCESS(cap_io_clk,cap_io_rst) IS
	BEGIN
		IF cap_io_rst='1' THEN
			cap_result_toggle_sync1_io<='0'; cap_result_toggle_sync2_io<='0';
			cap_result_toggle_seen_io<='0'; cap_result_toggle_io<='0';
			cap_result_published_io<='0';
		ELSIF rising_edge(cap_io_clk) THEN
			cap_result_toggle_sync1_io<=cap_result_toggle_i;
			cap_result_toggle_sync2_io<=cap_result_toggle_sync1_io;
			IF cap_result_toggle_sync2_io/=cap_result_toggle_seen_io THEN
				cap_result_toggle_seen_io<=cap_result_toggle_sync2_io;
				cap_result_published_io<='1';
				cap_result_toggle_io<=cap_result_toggle_sync2_io;
			END IF;
		END IF;
	END PROCESS;

	-- Native CAB image tags cross into the input-video clock through a single
	-- four-entry Gray-pointer FIFO. A full FIFO is an explicit capture fault;
	-- it never stalls the game or native CAB clock.
	cap_tag_fifo_enabled: IF CAPTURE GENERATE
		SIGNAL cap_tag_wr_bin_next : unsigned(CAP_TAG_AW DOWNTO 0);
		SIGNAL cap_tag_wr_gray_next : unsigned(CAP_TAG_AW DOWNTO 0);
	BEGIN
		cap_tag_wr_bin_next  <= cap_tag_wr_bin + 1;
		cap_tag_wr_gray_next <= cap_gray(cap_tag_wr_bin_next);
		-- Full describes whether the current write pointer names a full FIFO.
		-- Comparing wr_next would reject the fourth entry at depth four.
		cap_tag_full <= '1' WHEN cap_tag_wr_gray =
			(NOT cap_tag_rd_gray_sync2(CAP_TAG_AW DOWNTO CAP_TAG_AW-1)) &
			 cap_tag_rd_gray_sync2(CAP_TAG_AW-2 DOWNTO 0) ELSE '0';
		cap_tag_empty <= '1' WHEN cap_tag_rd_gray = cap_tag_wr_gray_sync2 ELSE '0';
		cap_tag_head <= cap_tag_mem(to_integer(cap_tag_rd_bin(CAP_TAG_AW-1 DOWNTO 0)));
		cap_tag_ready <= NOT cap_tag_full;

		TagWrite: PROCESS(cap_tag_clk,cap_tag_rst) IS
		BEGIN
			IF cap_tag_rst='1' THEN
				cap_tag_wr_bin<=(OTHERS=>'0');
				cap_tag_wr_gray<=(OTHERS=>'0');
				cap_tag_rd_gray_sync1<=(OTHERS=>'0');
				cap_tag_rd_gray_sync2<=(OTHERS=>'0');
			ELSIF rising_edge(cap_tag_clk) THEN
				cap_tag_rd_gray_sync1<=cap_tag_rd_gray;
				cap_tag_rd_gray_sync2<=cap_tag_rd_gray_sync1;
				IF cap_tag_valid='1' THEN
					IF cap_tag_full='0' THEN
						cap_tag_mem(to_integer(cap_tag_wr_bin(CAP_TAG_AW-1 DOWNTO 0)))<=cap_tag;
						cap_tag_wr_bin<=cap_tag_wr_bin_next;
						cap_tag_wr_gray<=cap_tag_wr_gray_next;
					END IF;
				END IF;
			END IF;
		END PROCESS;

		TagRead: PROCESS(i_clk,i_reset_na) IS
		BEGIN
			IF i_reset_na='0' THEN
				cap_tag_rd_bin<=(OTHERS=>'0');
				cap_tag_rd_gray<=(OTHERS=>'0');
				cap_tag_wr_gray_sync1<=(OTHERS=>'0');
				cap_tag_wr_gray_sync2<=(OTHERS=>'0');
			ELSIF rising_edge(i_clk) THEN
				cap_tag_wr_gray_sync1<=cap_tag_wr_gray;
				cap_tag_wr_gray_sync2<=cap_tag_wr_gray_sync1;
				IF cap_tag_pop='1' AND cap_tag_empty='0' THEN
					cap_tag_rd_bin<=cap_tag_rd_bin+1;
					cap_tag_rd_gray<=cap_gray(cap_tag_rd_bin+1);
				END IF;
			END IF;
		END PROCESS;
	END GENERATE;

	cap_tag_fifo_disabled: IF NOT CAPTURE GENERATE
	BEGIN
		cap_tag_full<='0';
		cap_tag_empty<='1';
		cap_tag_head<=(OTHERS=>'0');
		cap_tag_ready<='0';
	END GENERATE;

	-- Request/reply slot ownership by native input EOF generation. The output
	-- pointer is sampled only after its registered o_isync update has occurred;
	-- the response remains stable until the input clock acknowledges it.
	CaptureSlotReply: PROCESS(o_clk,o_reset_na) IS
	BEGIN
		IF o_reset_na='0' THEN
			cap_slot_req_sync1_o<='0'; cap_slot_req_sync2_o<='0'; cap_slot_req_seen_o<='0';
			cap_slot_pending_o<='0';
			cap_slot_reply_toggle_o<='0';
			cap_slot_reply_slot_o<=0;
			cap_slot_reply_ack_sync1_o<='0'; cap_slot_reply_ack_sync2_o<='0';
		ELSIF rising_edge(o_clk) THEN
			cap_slot_req_sync1_o<=cap_slot_req_toggle_i;
			cap_slot_req_sync2_o<=cap_slot_req_sync1_o;
			cap_slot_reply_ack_sync1_o<=cap_slot_reply_ack_i;
			cap_slot_reply_ack_sync2_o<=cap_slot_reply_ack_sync1_o;
			IF CAPTURE AND cap_slot_req_sync2_o/=cap_slot_req_seen_o AND cap_slot_pending_o='0' THEN
				cap_slot_req_seen_o<=cap_slot_req_sync2_o;
				cap_slot_pending_o<='1';
			END IF;
			IF CAPTURE AND cap_slot_pending_o='1' AND
			   cap_slot_reply_toggle_o=cap_slot_reply_ack_sync2_o AND
			   o_iendframe02='1' THEN
				cap_slot_reply_slot_o<=o_ibuf0;
				cap_slot_reply_toggle_o<=NOT cap_slot_reply_toggle_o;
				cap_slot_pending_o<='0';
			END IF;
		END IF;
	END PROCESS;

	CaptureSlotRead: PROCESS(i_clk,i_reset_na) IS
	BEGIN
		IF i_reset_na='0' THEN
			cap_slot_reply_sync1_i<='0'; cap_slot_reply_sync2_i<='0'; cap_slot_reply_seen_i<='0';
			cap_slot_reply_ack_i<='0';
			cap_slot_reply_slot_i<=0;
		ELSIF rising_edge(i_clk) THEN
			cap_slot_reply_sync1_i<=cap_slot_reply_toggle_o;
			cap_slot_reply_sync2_i<=cap_slot_reply_sync1_i;
			IF CAPTURE AND cap_slot_reply_sync2_i/=cap_slot_reply_seen_i THEN
				cap_slot_reply_seen_i<=cap_slot_reply_sync2_i;
				cap_slot_reply_ack_i<=cap_slot_reply_sync2_i;
				cap_slot_reply_slot_i<=cap_slot_reply_slot_o;
			END IF;
		END IF;
	END PROCESS;

	-- Capture request/control bundles use a stable-data toggle mailbox. The
	-- native token is paired at the input EOF; only the following clean header
	-- boundary closes admission, allowing the matched image's pipeline to drain.
	CaptureControl: PROCESS(i_clk,i_reset_na) IS
		VARIABLE eof_v : boolean;
		VARIABLE half_v : natural RANGE 0 TO 1;
		VARIABLE completed_id_v : cap_write_id_t;
		VARIABLE completion_update_v : boolean;
		VARIABLE ack_pending_v : std_logic_vector(1 DOWNTO 0);
		VARIABLE ack_found_v : boolean;
		VARIABLE tag_checkpoint_v : unsigned(14 DOWNTO 0);
		VARIABLE crc_v : unsigned(31 DOWNTO 0);
		VARIABLE width_v,height_v,pitch_v : natural;
		VARIABLE producer_quiet_v : boolean;
		VARIABLE life_cancel_v : boolean;
		VARIABLE life_event_v : boolean;
		VARIABLE life_armed_v : boolean;
		VARIABLE life_armed_from_idle_v : boolean;
		VARIABLE life_invalid_state_v : boolean;
		VARIABLE life_arm_block_v : boolean;
		VARIABLE life_progress_v : boolean;
	BEGIN
		IF i_reset_na='0' THEN
			cap_req_sync1<='0'; cap_req_sync2<='0'; cap_req_seen<='0';
			cap_release_sync1<='0'; cap_release_sync2<='0'; cap_release_seen<='0';
			cap_abort_sync1<='0'; cap_abort_sync2<='0'; cap_abort_seen<='0';
			cap_life_sync1<='0'; cap_life_sync2<='0'; cap_life_seen<='0';
			cap_tag_error_sync1_i<='0'; cap_tag_error_sync2_i<='0';
			cap_tag_valid_sync1_i<='0'; cap_tag_valid_sync2_i<='0';
			cap_mode_sync1_i<='1'; cap_mode_sync2_i<='1';
			cap_fault_mailbox_toggle_sync1_i<='0'; cap_fault_mailbox_toggle_sync2_i<='0';
			cap_fault_mailbox_seen_i<='0'; cap_fault_mailbox_ack_toggle_i<='0';
			cap_fault_mailbox_code_i<=(OTHERS=>'0');
			cap_fault_mailbox_ack_sync1_i<='0'; cap_fault_mailbox_ack_sync2_i<='0';
			cap_req_ack_pending_i<='0'; cap_req_ack_pending_toggle_i<='0';
			cap_status_bundle_i<=(OTHERS=>'0'); cap_status_toggle_i<='0';
			cap_status_ack_sync1_i<='0'; cap_status_ack_sync2_i<='0';
			cap_req_ack_i<='0'; cap_release_ack_i<='0'; cap_abort_ack_i<='0'; cap_life_ack_i<='0';
			cap_result_toggle_i<='0';
			cap_result_ack_sync1_i<='0'; cap_result_ack_sync2_i<='0';

			cap_crc_active_i<='0';
			cap_crc_byte_i<=0; cap_crc_state_i<=(OTHERS=>'1');
			cap_cleanup_done_sync1_i<='0'; cap_cleanup_done_sync2_i<='0'; cap_cleanup_done_seen_i<='0';
			cap_req_checkpoint<=(OTHERS=>'0'); cap_req_hold_ms<=(OTHERS=>'0');
			cap_life_state_i<=(OTHERS=>'0'); cap_life_error_i<=(OTHERS=>'0');
			cap_life_completed_i<=(OTHERS=>'0'); cap_last_checkpoint_i<=(OTHERS=>'0');
			cap_life_running<='0'; cap_life_done_i<='0'; cap_life_valid_i<='0';
			cap_session_ready_i<='0';
			cap_lifecycle_cancel_i<='0';
			cap_watchdog_active_i<='0'; cap_watchdog_toggle_i<='0';
			cap_slot_req_toggle_i<='0';
			cap_image_slot_i<=0; cap_image_base_i<=(OTHERS=>'0');
			cap_half_lease_i<=(OTHERS=>'0'); cap_half_req_toggle_i<=(OTHERS=>'0');
			cap_half_ack_sync1_i<=(OTHERS=>'0'); cap_half_ack_sync2_i<=(OTHERS=>'0');
			cap_half_ack_seen_i<=(OTHERS=>'0'); cap_write_stage_valid_i<='0';
			cap_write_stage_half_i<='0'; cap_write_stage_delay_i<=0;
			cap_write_stage_header_i<='0'; cap_half_header_i<=(OTHERS=>'0');
			cap_write_stage_base_i<=(OTHERS=>'0'); cap_write_stage_offset_i<=(OTHERS=>'0');
			cap_write_stage_id_i<=(OTHERS=>'0'); cap_write_next_id_i<=resize(CAPTURE_WRITE_ID_SEED,1);
			cap_half_base_i<=(OTHERS=>(OTHERS=>'0')); cap_half_offset_i<=(OTHERS=>(OTHERS=>'0'));
			cap_half_id_i<=(OTHERS=>(OTHERS=>'0'));
			cap_write_completed_id_i<=resize(CAPTURE_WRITE_ID_SEED,1);
			cap_image_header_i<=(OTHERS=>'0'); cap_target_header_i<=(OTHERS=>'0');
			cap_image_slot_i_saved<=0; cap_target_slot_i<=0;
			cap_image_base_i_saved<=(OTHERS=>'0'); cap_target_base_i<=(OTHERS=>'0');
			cap_image_width_i<=0; cap_image_height_i<=0; cap_target_width_i<=0; cap_target_height_i<=0;
			cap_image_pitch_i<=0; cap_target_pitch_i<=0;
			cap_target_final_id_i<=(OTHERS=>'0');
			cap_target_pixel_hash_i<=(OTHERS=>'0');
			cap_error_watchdog_started_i<='0';
			cap_image_request_count_i<=(OTHERS=>'0'); cap_target_request_count_i<=(OTHERS=>'0');
			cap_target_expected_count_i<=(OTHERS=>'0');
			cap_target_checkpoint_i<=(OTHERS=>'0');
			cap_target_valid_i<='0'; cap_target_active_i<='0'; cap_drain_sent_i<='0'; cap_drain_toggle_i<='0';
			cap_cleanup_pending_i<='0'; cap_cleanup_drained_i<='0'; cap_drain_cleanup_i<='0';
			cap_cleanup_diag_i<='0';
			cap_drain_ack_sync1_i<='0'; cap_drain_ack_sync2_i<='0';
			cap_avl_fault_clear_toggle_i<='0'; cap_avl_fault_clear_ack_sync1_i<='0';
			cap_avl_fault_clear_ack_sync2_i<='0'; cap_avl_fault_clear_pending_i<='0';
			cap_state_i<=(OTHERS=>'0'); cap_fault_i<=(OTHERS=>'0');
			cap_hold_pending<='0'; cap_hold_active<='0';
			cap_release_pending<='0'; cap_abort_pending<='0'; cap_tag_pop<='0';
			cap_owner_i<='0';
			cap_producer_seen_i<='0';
		ELSIF rising_edge(i_clk) THEN
			IF CAPTURE AND cap_crc_active_i='1' THEN
				crc_v:=crc32_ieee_byte(cap_crc_state_i,
					capture_metadata_byte(cap_target_header_i,cap_target_checkpoint_i,
						cap_target_base_i,RAMSIZE,cap_target_payload_bytes_i,
						resize(cap_target_request_count_i,32),cap_target_pixel_hash_i,
						cap_target_slot_i,'0',
						(OTHERS=>'0'),192+cap_crc_byte_i));
				IF cap_crc_byte_i=55 THEN
					IF cap_state_i=x"02" AND cap_fault_i=x"00" AND
					   cap_abort_sync2=cap_abort_seen AND cap_release_sync2=cap_release_seen AND
					   cap_life_sync2=cap_life_seen AND cap_cleanup_pending_i='0' AND
					   cap_lifecycle_cancel_i='0' THEN
						cap_crc_state_i<=crc_v;
						cap_crc_active_i<='0';
						cap_result_toggle_i<=NOT cap_result_toggle_i;
						cap_state_i<=x"03";
						cap_watchdog_active_i<='1'; cap_watchdog_toggle_i<=NOT cap_watchdog_toggle_i;
					END IF;
				ELSE
					cap_crc_byte_i<=cap_crc_byte_i+1;
					cap_crc_state_i<=crc_v;
				END IF;
			END IF;
			cap_status_ack_sync1_i<=cap_status_ack_toggle_io;
			cap_status_ack_sync2_i<=cap_status_ack_sync1_i;
			cap_result_ack_sync1_i<=cap_result_ack_toggle;
			cap_result_ack_sync2_i<=cap_result_ack_sync1_i;
			cap_cleanup_done_sync1_i<=cap_cleanup_done_toggle_avl;
			cap_cleanup_done_sync2_i<=cap_cleanup_done_sync1_i;
			IF cap_cleanup_done_sync2_i/=cap_cleanup_done_seen_i THEN
				cap_cleanup_done_seen_i<=cap_cleanup_done_sync2_i;
				cap_cleanup_drained_i<='1';
			END IF;
			cap_drain_ack_sync1_i<=cap_drain_ack_avl;
			cap_drain_ack_sync2_i<=cap_drain_ack_sync1_i;
			cap_avl_fault_clear_ack_sync1_i<=cap_avl_fault_clear_ack_avl;
			cap_avl_fault_clear_ack_sync2_i<=cap_avl_fault_clear_ack_sync1_i;
			IF cap_avl_fault_clear_ack_sync2_i=cap_avl_fault_clear_toggle_i THEN
				cap_avl_fault_clear_pending_i<='0';
			END IF;
			cap_req_sync1<=cap_req_toggle; cap_req_sync2<=cap_req_sync1;
			cap_release_sync1<=cap_release_toggle; cap_release_sync2<=cap_release_sync1;
			cap_abort_sync1<=cap_abort_toggle; cap_abort_sync2<=cap_abort_sync1;
			cap_life_sync1<=cap_life_toggle; cap_life_sync2<=cap_life_sync1;
			cap_tag_error_sync1_i<=cap_tag_error; cap_tag_error_sync2_i<=cap_tag_error_sync1_i;
			cap_tag_valid_sync1_i<=cap_tag_valid; cap_tag_valid_sync2_i<=cap_tag_valid_sync1_i;
			cap_mode_sync1_i<=cap_mode_supported; cap_mode_sync2_i<=cap_mode_sync1_i;
			cap_fault_mailbox_toggle_sync1_i<=cap_fault_mailbox_toggle_avl;
			cap_fault_mailbox_toggle_sync2_i<=cap_fault_mailbox_toggle_sync1_i;
			cap_fault_mailbox_ack_sync1_i<=cap_fault_mailbox_ack_toggle_io;
			cap_fault_mailbox_ack_sync2_i<=cap_fault_mailbox_ack_sync1_i;
			IF cap_fault_mailbox_toggle_sync2_i/=cap_fault_mailbox_seen_i THEN
				cap_fault_mailbox_seen_i<=cap_fault_mailbox_toggle_sync2_i;
				cap_fault_mailbox_code_i<=cap_fault_mailbox_avl;
				cap_fault_mailbox_ack_toggle_i<=cap_fault_mailbox_toggle_sync2_i;
			END IF;
			IF cap_req_ack_pending_i='1' AND
			   cap_avl_fault_clear_ack_sync2_i=cap_avl_fault_clear_toggle_i AND
			   cap_fault_mailbox_ack_sync2_i=cap_fault_mailbox_toggle_sync2_i AND
			   cap_fault_mailbox_ack_toggle_i=cap_fault_mailbox_toggle_sync2_i THEN
				cap_req_ack_i<=cap_req_ack_pending_toggle_i;
				cap_req_ack_pending_i<='0';
			END IF;
			cap_half_ack_sync1_i<=cap_half_ack_toggle_o;
			cap_half_ack_sync2_i<=cap_half_ack_sync1_i;
			cap_tag_pop<='0';
			eof_v := i_pce='1' AND i_pvs='1' AND i_vs_pre='0';
			-- A STOP/error already present at the lifecycle mailbox has
			-- priority over an empty-tag EOF on this same i_clk edge. Otherwise an
			-- EOF underflow could overwrite the lifecycle first fault.
			life_event_v := CAPTURE AND cap_life_sync2/=cap_life_seen;
			life_armed_v := life_event_v AND cap_life(17 DOWNTO 15)="001";
			life_armed_from_idle_v := life_armed_v AND cap_life_valid_i='1' AND
				cap_life_state_i=x"00" AND cap_life_error_i=x"00" AND
				cap_life(25 DOWNTO 18)=x"00";
			life_invalid_state_v := life_event_v AND
				((cap_life(17 DOWNTO 15)/="000" AND cap_life(17 DOWNTO 15)/="001" AND
				  cap_life(17 DOWNTO 15)/="010" AND cap_life(17 DOWNTO 15)/="011" AND
				  cap_life(17 DOWNTO 15)/="100") OR cap_life(25 DOWNTO 18)/=x"00");
			life_arm_block_v := life_event_v AND
				(cap_life(17 DOWNTO 15)="000" OR cap_life(17 DOWNTO 15)="001" OR
				 cap_life(17 DOWNTO 15)="100" OR life_invalid_state_v);
			life_cancel_v := CAPTURE AND cap_state_i/=x"00" AND life_arm_block_v;
			life_progress_v := life_event_v AND cap_life_valid_i='1' AND
				cap_session_ready_i='1' AND cap_life_error_i=x"00" AND
				cap_life(25 DOWNTO 18)=x"00" AND
				unsigned(cap_life(14 DOWNTO 0))>=cap_life_completed_i AND
				((cap_life_state_i=x"01" AND
				  (cap_life(17 DOWNTO 15)="010" OR cap_life(17 DOWNTO 15)="011")) OR
				 (cap_life_state_i=x"02" AND
				  (cap_life(17 DOWNTO 15)="010" OR cap_life(17 DOWNTO 15)="011")) OR
				 (cap_life_state_i=x"03" AND cap_life(17 DOWNTO 15)="011"));
			IF life_cancel_v AND eof_v THEN
				REPORT "capture lifecycle cancellation coincident with native EOF" SEVERITY note;
			END IF;
			producer_quiet_v := (cap_producer_seen_i='0' AND i_ven/='1' AND i_wr/='1' AND i_wreq/='1') OR
				(i_ven='0' AND i_ven1='0' AND i_ven2='0' AND
				i_ven3='0' AND i_ven4='0' AND i_ven5='0' AND i_ven6='0' AND
				i_push='0' AND i_pushend='0' AND i_pushend2='0' AND i_eol='0' AND i_wr='0' AND
				i_pushhead='0' AND i_pushhead2='0' AND i_pushhead3='0' AND
				i_wreq='0' AND cap_write_stage_valid_i='0' AND i_acpt=0);
			IF CAPTURE AND (i_pushhead='1' OR i_ven='1' OR i_wr='1' OR i_wreq='1') THEN
				cap_producer_seen_i<='1';
			END IF;
			IF CAPTURE AND cap_state_i=x"04" AND cap_fault_i/=x"00" AND
			   (cap_fault_i/=x"0C" OR cap_fault_mailbox_code_i=x"0B") THEN
				cap_cleanup_pending_i<='1';
				cap_hold_pending<='0'; cap_hold_active<='1';
			END IF;
			-- ARMED faults can happen before the normal target watchdog starts.
			-- Give each owned failed session one bounded cleanup window, without
			-- restarting a watchdog already running or one which has expired.
			IF CAPTURE AND cap_state_i=x"04" AND cap_fault_i/=x"00" AND
			   cap_owner_i='1' AND cap_error_watchdog_started_i='0' THEN
				cap_error_watchdog_started_i<='1';
				IF cap_watchdog_active_i='0' THEN
					cap_watchdog_active_i<='1';
					cap_watchdog_toggle_i<=NOT cap_watchdog_toggle_i;
				END IF;
			END IF;
			IF CAPTURE AND cap_cleanup_pending_i='1' AND cap_drain_sent_i='0' AND
			   NOT producer_quiet_v AND cap_cleanup_diag_i='0' THEN
				cap_cleanup_diag_i<='1';
				-- synthesis translate_off
				REPORT "capture cleanup waiting producer: acpt=" & integer'image(i_acpt) &
					" ven=" & std_logic'image(i_ven) & std_logic'image(i_ven1) &
					std_logic'image(i_ven2) & std_logic'image(i_ven3) & std_logic'image(i_ven4) &
					std_logic'image(i_ven5) & std_logic'image(i_ven6) &
					" push=" & std_logic'image(i_push) & std_logic'image(i_pushend) &
					std_logic'image(i_pushend2) & " eol=" & std_logic'image(i_eol) &
					" wr=" & std_logic'image(i_wr) & " head=" & std_logic'image(i_pushhead) &
					std_logic'image(i_pushhead2) & std_logic'image(i_pushhead3) &
					" wreq=" & std_logic'image(i_wreq) & " stage=" &
					std_logic'image(cap_write_stage_valid_i) SEVERITY note;
				-- synthesis translate_on
			END IF;
			IF CAPTURE AND cap_avl_fault_clear_pending_i='0' AND
			   cap_fault_mailbox_code_i/=x"00" AND cap_fault_i=x"00" THEN
				cap_fault_i<=cap_fault_mailbox_code_i;
				cap_state_i<=x"04";
				cap_hold_pending<='0'; cap_hold_active<='1';
			END IF;
			IF CAPTURE AND i_pushhead='1' AND i_freeze='0' AND
			   cap_hold_pending='0' AND cap_hold_active='0' THEN
				-- Snapshot the exact old header and slot on the edge which InAT
				-- writes that same i_head value as the legacy image header.
				cap_image_header_i<=i_head;
				cap_image_slot_i_saved<=cap_image_slot_i;
				cap_image_base_i_saved<=cap_image_base_i;
				cap_image_width_i<=i_hrsize; cap_image_height_i<=i_vrsize;
				cap_image_pitch_i<=N_BURST*i_hburst;
				cap_image_request_count_i<=(OTHERS=>'0');
			END IF;
			completed_id_v:=cap_write_completed_id_i;
			completion_update_v:=false;
			FOR h IN 0 TO 1 LOOP
				ack_pending_v(h):='0';
				IF CAPTURE AND cap_half_ack_sync2_i(h)/=cap_half_ack_seen_i(h) THEN
					ack_pending_v(h):='1';
				END IF;
			END LOOP;
			-- synthesis translate_off
			IF ack_pending_v="11" THEN
				REPORT "capture observed both half ACKs together; next ID=" &
					to_hstring(completed_id_v+1) SEVERITY note;
			END IF;
			-- synthesis translate_on
			-- ACK IDs wrap at the bounded local token width. Select the exact expected-next ID
			-- each pass rather than sorting IDs numerically (0 follows FFFFFFFF).
			FOR n IN 0 TO 1 LOOP
				ack_found_v:=false;
				FOR h IN 0 TO 1 LOOP
					IF ack_pending_v(h)='1' AND
					   cap_half_id_i(h)=completed_id_v+1 AND NOT ack_found_v THEN
						half_v:=h;
						ack_found_v:=true;
					END IF;
				END LOOP;
				IF ack_found_v THEN
					cap_half_ack_seen_i(half_v)<=cap_half_ack_sync2_i(half_v);
					cap_half_lease_i(half_v)<='0';
					ack_pending_v(half_v):='0';
					completed_id_v:=cap_half_id_i(half_v);
					completion_update_v:=true;
				END IF;
			END LOOP;
			FOR h IN 0 TO 1 LOOP
				IF ack_pending_v(h)='1' THEN
					cap_half_ack_seen_i(h)<=cap_half_ack_sync2_i(h);
					cap_half_lease_i(h)<='0';
					IF cap_fault_i=x"00" THEN cap_fault_i<=x"08"; END IF; -- WRITE_OVERRUN
					cap_state_i<=x"04";
					cap_hold_pending<='0'; cap_hold_active<='1';
				END IF;
			END LOOP;
			IF completion_update_v THEN cap_write_completed_id_i<=completed_id_v; END IF;

			-- A request is recognized after i_wr has presented its final half
			-- word. Lease acquisition on this edge therefore permits that final
			-- fill, then prevents any later write until the Avalon last-beat ACK.
			-- A failed session drops new descriptors, but normal hold still drains
			-- already-admitted EOL/packing tail requests before the explicit drain
			-- predicate is satisfied.
			IF CAPTURE AND i_wreq='1' AND cap_state_i/=x"04" THEN
				IF cap_image_request_count_i=(cap_image_request_count_i'RANGE=>'1') OR
				   (cap_target_active_i='1' AND
				    cap_target_request_count_i=(cap_target_request_count_i'RANGE=>'1')) THEN
					IF cap_fault_i=x"00" THEN cap_fault_i<=x"0D"; END IF; -- NATIVE_PROGRESS / count overflow
					cap_state_i<=x"04";
					cap_hold_pending<='0'; cap_hold_active<='1';
				ELSE
					cap_image_request_count_i<=cap_image_request_count_i+1;
					IF cap_target_active_i='1' THEN
						cap_target_request_count_i<=cap_target_request_count_i+1;
					END IF;
					IF i_alt='0' THEN half_v:=0; ELSE half_v:=1; END IF;
					IF cap_write_stage_valid_i='1' OR
					   (cap_half_lease_i(half_v)='1' AND
					    cap_half_ack_sync2_i(half_v)=cap_half_ack_seen_i(half_v)) OR
					   ((i_wad>=BLEN) /= (i_alt='1')) THEN
						IF cap_fault_i=x"00" THEN cap_fault_i<=x"08"; END IF; -- WRITE_OVERRUN
						cap_state_i<=x"04";
						cap_hold_pending<='0'; cap_hold_active<='1';
					ELSE
						cap_half_lease_i(half_v)<='1';
						cap_write_stage_valid_i<='1';
						cap_write_stage_delay_i<=0;
						cap_write_stage_half_i<=i_alt;
						cap_write_stage_header_i<=i_wreq_header;
						cap_write_stage_base_i<=cap_image_base_i;
						cap_write_stage_offset_i<=i_adrs;
						cap_write_stage_id_i<=cap_write_next_id_i+1;
						-- synthesis translate_off
						IF CAPTURE_WRITE_ID_SEED/=0 THEN
							REPORT "capture issued write ID " & to_hstring(cap_write_next_id_i+1) &
								" half=" & std_logic'image(i_alt) &
								" base=" & to_hstring(cap_image_base_i) &
								" offset=" & to_hstring(i_adrs)
							SEVERITY note;
						END IF;
						-- synthesis translate_on
						cap_write_next_id_i<=cap_write_next_id_i+1;
					END IF;
				END IF;
			END IF;
			IF CAPTURE AND cap_write_stage_valid_i='1' THEN
				-- The final half-buffer write commits on the request edge. Hold
				-- its descriptor for two i_clk edges before the Avalon toggle;
				-- the two-stage receiver then precedes any half-buffer read.
				IF cap_write_stage_delay_i=1 THEN
					half_v:=0;
					IF cap_write_stage_half_i='1' THEN half_v:=1; END IF;
					cap_half_base_i(half_v)<=cap_write_stage_base_i;
					cap_half_offset_i(half_v)<=cap_write_stage_offset_i;
					cap_half_header_i(half_v)<=cap_write_stage_header_i;
					cap_half_id_i(half_v)<=cap_write_stage_id_i;
					cap_half_req_toggle_i(half_v)<=NOT cap_half_req_toggle_i(half_v);
					cap_write_stage_valid_i<='0';
					cap_write_stage_delay_i<=0;
				ELSE
					cap_write_stage_delay_i<=cap_write_stage_delay_i+1;
				END IF;
			END IF;
			IF CAPTURE AND i_wr='1' THEN
				half_v:=0;
				IF i_wad>=BLEN THEN half_v:=1; END IF;
				IF cap_half_lease_i(half_v)='1' AND
				   cap_half_ack_sync2_i(half_v)=cap_half_ack_seen_i(half_v) THEN
										-- synthesis translate_off
										IF CAPTURE_WRITE_ID_SEED/=0 THEN
										REPORT "capture WRITE_OVERRUN half=" & integer'image(half_v) &
											" wad=" & integer'image(i_wad) &
											" stage_id=" & to_hstring(cap_write_stage_id_i) &
											" completed_id=" & to_hstring(cap_write_completed_id_i)
											SEVERITY note;
									END IF;
										-- synthesis translate_on
					IF cap_fault_i=x"00" THEN cap_fault_i<=x"08"; END IF; -- WRITE_OVERRUN
					cap_state_i<=x"04";
					cap_hold_pending<='0'; cap_hold_active<='1';
				END IF;
			END IF;

			IF life_event_v THEN
				cap_life_seen<=cap_life_sync2;
				cap_life_ack_i<=cap_life_sync2;
				cap_life_completed_i<=unsigned(cap_life(14 DOWNTO 0));
				cap_life_state_i<="00000" & cap_life(17 DOWNTO 15);
				cap_life_error_i<=cap_life(25 DOWNTO 18);
				cap_life_valid_i<='1';
				IF cap_life(17 DOWNTO 15)="000" THEN
					cap_session_ready_i<='0';
				ELSIF cap_life(17 DOWNTO 15)="001" THEN
					-- ARMED is eligible only when a valid, acknowledged IDLE
					-- mailbox value immediately preceded it. Invalid/repeated ARMED
					-- always drops admission, including after reset or a live owner.
					IF life_armed_from_idle_v THEN
						cap_session_ready_i<='1';
					ELSE
						cap_session_ready_i<='0';
					END IF;
				ELSIF life_invalid_state_v OR cap_life(17 DOWNTO 15)="100" THEN
					cap_session_ready_i<='0';
				END IF;
				IF cap_state_i/=x"00" AND life_arm_block_v THEN
					cap_life_running<='0'; cap_life_done_i<='0';
					IF cap_fault_i=x"00" THEN cap_fault_i<=x"05"; END IF; -- LIFECYCLE_CHANGED
					cap_state_i<=x"04"; cap_hold_pending<='0'; cap_hold_active<='1';
					cap_lifecycle_cancel_i<='1';
					cap_watchdog_active_i<='1'; cap_watchdog_toggle_i<=NOT cap_watchdog_toggle_i;
				ELSIF cap_life(17 DOWNTO 15)="010" AND cap_life(25 DOWNTO 18)=x"00" THEN
					cap_life_running<='1'; cap_life_done_i<='0';
				ELSIF cap_life(17 DOWNTO 15)="011" AND cap_life(25 DOWNTO 18)=x"00" THEN
					-- Normal DONE preserves a matched final checkpoint and READY ownership.
					cap_life_running<='1'; cap_life_done_i<='1';
				ELSIF cap_life(17 DOWNTO 15)="000" OR cap_life(17 DOWNTO 15)="100" OR
				      life_invalid_state_v THEN
					cap_life_running<='0';
				END IF;
			END IF;
			IF CAPTURE AND cap_tag_error_sync2_i='1' AND cap_state_i/=x"00" AND cap_fault_i=x"00" THEN
				cap_fault_i<=x"07"; -- TAG_SEQUENCE / helper detected lost token
				cap_state_i<=x"04";
				cap_hold_pending<='0'; cap_hold_active<='1';
			END IF;
			IF CAPTURE AND cap_mode_sync2_i='0' AND cap_state_i/=x"00" AND cap_fault_i=x"00" THEN
				cap_fault_i<=x"06"; -- UNSUPPORTED_MODE
				cap_state_i<=x"04";
				cap_hold_pending<='0'; cap_hold_active<='1';
			END IF;

			IF CAPTURE AND cap_req_sync2/=cap_req_seen AND NOT
			   (cap_state_i=x"00" AND cap_owner_i='0' AND cap_cleanup_pending_i='0' AND
			    cap_lifecycle_cancel_i='0' AND life_progress_v) THEN
				cap_req_seen<=cap_req_sync2;
				-- A completed CAB IDLE->ARMED barrier plus drained transport, tag,
				-- result mailboxes replaces an epoch identity.
				IF cap_state_i=x"00" AND NOT life_arm_block_v AND cap_drain_ready_i='1' AND
				   cap_life_valid_i='1' AND cap_session_ready_i='1' AND
				   (cap_life_state_i=x"01" OR cap_life_state_i=x"02" OR
				    (cap_life_state_i=x"03" AND cap_life_completed_i>=unsigned(cap_req(14 DOWNTO 0)))) AND
				   cap_life_error_i=x"00" AND cap_req(15)='0' AND
				   cap_req(31 DOWNTO 27)="00000" AND
				   cap_result_ack_sync2_i=cap_result_toggle_i AND
				   cap_fault_mailbox_ack_sync2_i=cap_fault_mailbox_toggle_sync2_i AND
				   cap_fault_mailbox_ack_toggle_i=cap_fault_mailbox_toggle_sync2_i AND
				   cap_tag_error_sync2_i='0' AND cap_mode_sync2_i='1' AND
				   unsigned(cap_req(14 DOWNTO 0))/=0 AND
				   unsigned(cap_req(26 DOWNTO 16))>=100 AND
				   unsigned(cap_req(26 DOWNTO 16))<=2000 THEN
					cap_req_checkpoint<=unsigned(cap_req(14 DOWNTO 0));
					cap_req_hold_ms<=unsigned(cap_req(26 DOWNTO 16));
					cap_state_i<=x"01"; -- ARMED
					cap_req_ack_pending_i<='1';
					cap_req_ack_pending_toggle_i<=cap_req_sync2;
					cap_owner_i<='1';
					cap_error_watchdog_started_i<='0';
					cap_avl_fault_clear_toggle_i<=NOT cap_avl_fault_clear_toggle_i;
					cap_avl_fault_clear_pending_i<='1';
					cap_fault_i<=(OTHERS=>'0');

					cap_crc_active_i<='0';

					IF cap_life_state_i=x"02" THEN
						cap_life_running<='1'; cap_life_done_i<='0';
					ELSIF cap_life_state_i=x"03" THEN
						cap_life_running<='1'; cap_life_done_i<='1';
					ELSE
						cap_life_running<='0'; cap_life_done_i<='0';
					END IF;
					cap_last_checkpoint_i<=(OTHERS=>'0');
					cap_lifecycle_cancel_i<='0';
					cap_hold_pending<='0'; cap_hold_active<='0';
					cap_target_valid_i<='0'; cap_target_active_i<='0'; cap_drain_sent_i<='0';
					cap_cleanup_pending_i<='0'; cap_cleanup_drained_i<='0'; cap_drain_cleanup_i<='0';
					cap_image_request_count_i<=(OTHERS=>'0'); cap_target_request_count_i<=(OTHERS=>'0');
				ELSE
					cap_req_ack_i<=cap_req_sync2;
					-- synthesis translate_off
					REPORT "capture ARM rejected state=" & to_hstring(cap_state_i) &
						" drain_ready=" & std_logic'image(cap_drain_ready_i) &
						" fault=" & to_hstring(cap_fault_i) & " tag_error=" &
						std_logic'image(cap_tag_error_sync2_i) & " request=" & to_hstring(cap_req)
						SEVERITY note;
					-- synthesis translate_on
					IF cap_fault_i=x"00" AND NOT life_cancel_v THEN
						IF cap_mode_sync2_i='0' THEN cap_fault_i<=x"06";
						ELSIF cap_tag_error_sync2_i='1' THEN cap_fault_i<=x"07";
						ELSIF life_arm_block_v THEN cap_fault_i<=x"03"; -- same-edge session boundary/invalid lifecycle
						ELSIF cap_life_valid_i='0' OR cap_session_ready_i='0' OR
						      (cap_life_state_i/=x"01" AND cap_life_state_i/=x"02" AND
						       cap_life_state_i/=x"03") OR cap_life_error_i/=x"00" THEN
							cap_fault_i<=x"03"; -- BAD_STATE / missing lifecycle barrier
						ELSIF cap_life_state_i=x"03" AND
						      cap_life_completed_i<unsigned(cap_req(14 DOWNTO 0)) THEN
							cap_fault_i<=x"04"; -- LATE_TARGET
						ELSE cap_fault_i<=x"03"; -- BAD_STATE / undrained mailbox
						END IF;
					END IF;
					IF cap_state_i=x"00" THEN
						cap_state_i<=x"00";
					ELSE
						cap_state_i<=x"04";
						cap_hold_pending<='0'; cap_hold_active<='1';
					END IF;
				END IF;
			END IF;

			IF CAPTURE AND cap_state_i=x"00" AND eof_v AND cap_tag_empty='0' THEN
				cap_tag_pop<='1'; -- Drain unrelated scaler frames before capture ARM.
			END IF;
			IF CAPTURE AND cap_state_i=x"04" AND eof_v AND cap_tag_empty='0' THEN
				cap_tag_pop<='1'; -- Failed sessions keep consuming native tags while ownership drains.
			END IF;
			IF CAPTURE AND cap_state_i=x"01" AND cap_life_running='1' AND eof_v AND NOT life_cancel_v THEN
				IF cap_tag_empty='1' THEN
					IF cap_life_done_i='1' AND cap_last_checkpoint_i>=cap_life_completed_i THEN
						IF cap_fault_i=x"00" THEN cap_fault_i<=x"04"; END IF; -- LATE_TARGET
					ELSE
						IF cap_fault_i=x"00" THEN cap_fault_i<=x"07"; END IF; -- TAG_SEQUENCE
					END IF;
					cap_state_i<=x"04";
				ELSE
					cap_tag_pop<='1';
					tag_checkpoint_v:=unsigned(cap_tag_head);
					cap_last_checkpoint_i<=tag_checkpoint_v;
					IF tag_checkpoint_v<cap_req_checkpoint THEN
						IF cap_life_done_i='1' AND tag_checkpoint_v>=cap_life_completed_i THEN
							IF cap_fault_i=x"00" THEN cap_fault_i<=x"04"; END IF; -- LATE_TARGET
							cap_state_i<=x"04";
						ELSE
							NULL; -- Discard preceding native intervals while staying armed.
						END IF;
					ELSIF tag_checkpoint_v=cap_req_checkpoint THEN
						cap_state_i<=x"02"; -- RUNNING / matched target
						cap_watchdog_active_i<='1'; cap_watchdog_toggle_i<=NOT cap_watchdog_toggle_i;
						cap_hold_pending<='1';
						cap_target_valid_i<='1'; cap_target_active_i<='1';
						cap_target_checkpoint_i<=tag_checkpoint_v;
						cap_target_header_i<=cap_image_header_i;
						cap_target_slot_i<=cap_image_slot_i_saved; cap_target_base_i<=cap_image_base_i_saved;
						cap_target_width_i<=cap_image_width_i; cap_target_height_i<=cap_image_height_i;
						cap_target_pitch_i<=cap_image_pitch_i;
						cap_target_expected_count_i<=to_unsigned(1+cap_image_height_i*(cap_image_pitch_i/N_BURST),CAPTURE_REQUEST_COUNT_W);
						cap_target_request_count_i<=cap_image_request_count_i;
						IF i_wreq='1' THEN cap_target_request_count_i<=cap_image_request_count_i+1; END IF;
					ELSE
						IF cap_fault_i=x"00" THEN cap_fault_i<=x"04"; END IF; -- LATE_TARGET
						cap_state_i<=x"04";
					END IF;
				END IF;
			END IF;
			IF CAPTURE AND (cap_state_i=x"02" OR cap_state_i=x"03") AND eof_v AND cap_tag_empty='0' THEN
				-- Native playback is never backpressured; discard subsequent image
				-- tags while the selected slot remains owned.
				cap_tag_pop<='1';
			END IF;

			-- Close admission only after the matched image's last EOF/EOL work,
			-- at the next vertical-blank boundary before its next header/pixels.
			IF CAPTURE AND cap_state_i=x"02" AND cap_hold_pending='1' AND
			   i_pvs='0' AND i_vs_pre='1' THEN
				cap_hold_pending<='0';
				cap_hold_active<='1';
			END IF;

			-- The output pointer update follows this EOF across its own clock
			-- domain. Request one stable slot reply for every forwarded interval;
			-- held/discarded source intervals do not advance the request generation.
			IF CAPTURE AND eof_v AND cap_hold_active='0' THEN
				IF cap_slot_reply_ack_i=cap_slot_req_toggle_i THEN
					cap_slot_req_toggle_i<=NOT cap_slot_req_toggle_i;
				ELSE
					IF cap_fault_i=x"00" THEN cap_fault_i<=x"0D"; END IF; -- NATIVE_PROGRESS
					cap_state_i<=x"04";
					cap_hold_pending<='0'; cap_hold_active<='1';
				END IF;
			END IF;

			-- At the next header boundary the reply describes this image, not
			-- the one that just completed. Never guess a stale/live slot value.
			IF CAPTURE AND i_pce='1' AND i_pvs='0' AND i_vs_pre='1' AND
			   cap_hold_pending='0' AND cap_hold_active='0' THEN
				IF cap_slot_reply_ack_i=cap_slot_req_toggle_i THEN
					cap_image_slot_i<=cap_slot_reply_slot_i;
					cap_image_base_i<=buf_offset(cap_slot_reply_slot_i,RAMBASE,RAMSIZE);
				ELSE
					IF cap_fault_i=x"00" THEN cap_fault_i<=x"0D"; END IF; -- NATIVE_PROGRESS
					cap_state_i<=x"04";
					cap_hold_active<='1';
				END IF;
			END IF;

			-- The target image is not drainable until every admitted scaler
			-- validity, pack, EOL, DPRAM and descriptor stage is empty. Keep this
			-- separate from the admission hold so already-launched tail requests
			-- continue through the writer.
			IF CAPTURE AND cap_state_i=x"02" AND cap_fault_i=x"00" AND
			   cap_target_valid_i='1' AND cap_hold_active='1' AND
			   cap_drain_sent_i='0' AND i_ven='0' AND i_ven1='0' AND i_ven2='0' AND
			   i_ven3='0' AND i_ven4='0' AND i_ven5='0' AND i_ven6='0' AND
			   i_push='0' AND i_pushend='0' AND i_pushend2='0' AND i_eol='0' AND i_wr='0' AND
			   i_pushhead='0' AND i_pushhead2='0' AND i_pushhead3='0' AND
			   i_wreq='0' AND cap_write_stage_valid_i='0' AND
			   cap_half_lease_i="00" AND i_acpt=0 THEN
				IF cap_target_request_count_i=cap_target_expected_count_i AND
				   cap_image_request_count_i=cap_target_expected_count_i THEN
					cap_target_final_id_i<=cap_write_next_id_i;
					cap_drain_sent_i<='1';
					cap_drain_cleanup_i<='0';
					cap_drain_toggle_i<=NOT cap_drain_toggle_i;
					-- synthesis translate_off
					REPORT "capture producer quiet; target requests=" &
						to_hstring(cap_target_request_count_i) & " expected=" &
						to_hstring(cap_target_expected_count_i) & " final ID=" &
						to_hstring(cap_write_next_id_i) & " slot=" &
						integer'image(cap_target_slot_i) & " pitch=" &
						integer'image(cap_target_pitch_i)
						SEVERITY note;
					-- synthesis translate_on
				ELSE
					IF cap_fault_i=x"00" THEN cap_fault_i<=x"0E"; END IF; -- GEOMETRY_CHANGED
					cap_state_i<=x"04";
					-- synthesis translate_off
					REPORT "capture image request count mismatch: got=" &
						to_hstring(cap_target_request_count_i) & " expected=" &
						to_hstring(cap_target_expected_count_i) & " total=" &
						to_hstring(cap_image_request_count_i)
						SEVERITY note;
					-- synthesis translate_on
				END IF;
			END IF;
			IF CAPTURE AND cap_state_i=x"04" AND cap_cleanup_pending_i='1' AND
			   cap_cleanup_drained_i='0' AND cap_drain_sent_i='0' AND producer_quiet_v AND
			   cap_write_stage_valid_i='0' AND cap_half_lease_i="00" THEN
				cap_target_final_id_i<=cap_write_next_id_i;
				cap_drain_cleanup_i<='1'; cap_drain_sent_i<='1';
				cap_drain_toggle_i<=NOT cap_drain_toggle_i;
				-- synthesis translate_off
				REPORT "capture cleanup issued local drain ID=" & to_hstring(cap_write_next_id_i)
					SEVERITY note;
				-- synthesis translate_on
			END IF;

			-- The drain acknowledgement covers the final accepted image burst.
			-- Verify the saved geometry and latch its stable Avalon checksum.
			IF CAPTURE AND cap_drain_sent_i='1' AND
				   cap_drain_ack_sync2_i=cap_drain_toggle_i AND
				   cap_crc_active_i='0' AND
			   cap_state_i=x"02" AND cap_fault_i=x"00" THEN
				IF cap_write_completed_id_i/=cap_target_final_id_i THEN
					-- Wait for both ordered half acknowledgements to cross back.
					NULL;
				ELSE
				width_v:=to_integer(cap_target_header_i(79 DOWNTO 64));
				height_v:=to_integer(cap_target_header_i(63 DOWNTO 48));
				pitch_v:=to_integer(cap_target_header_i(47 DOWNTO 32));
				IF cap_target_checkpoint_i=0 OR cap_target_header_i(127 DOWNTO 120)/=x"01" OR
				   cap_target_header_i(119 DOWNTO 112)/=x"01" OR
				   width_v/=cap_target_width_i OR height_v/=cap_target_height_i OR
				   pitch_v/=cap_target_pitch_i OR width_v=0 OR height_v=0 OR
				   pitch_v/=((width_v*3+N_BURST-1)/N_BURST)*N_BURST OR
				   to_integer(RAMSIZE)<N_BURST OR
				   to_integer(cap_target_payload_bytes_i)>to_integer(RAMSIZE)-N_BURST OR
				   o_fb_ena/='0' THEN
					IF cap_fault_i=x"00" THEN cap_fault_i<=x"0E"; END IF; -- GEOMETRY_CHANGED
					cap_state_i<=x"04";
					cap_hold_active<='1';
				ELSE
					cap_target_pixel_hash_i<=cap_pixel_hash_avl;

					cap_crc_byte_i<=0; cap_crc_state_i<=(OTHERS=>'1');
					cap_crc_active_i<='1';
				END IF;
				END IF;
			END IF;

			IF CAPTURE AND cap_release_sync2/=cap_release_seen THEN
				cap_release_seen<=cap_release_sync2;
				IF cap_state_i=x"03" AND cap_release(15)='0' AND
				   unsigned(cap_release(14 DOWNTO 0))=cap_req_checkpoint THEN
					cap_release_pending<='1';
				ELSE
					IF cap_fault_i=x"00" THEN cap_fault_i<=x"0C"; END IF; -- BAD_RELEASE
					cap_release_ack_i<=cap_release_sync2;
					IF cap_state_i/=x"00" THEN
						cap_state_i<=x"04"; cap_hold_pending<='0'; cap_hold_active<='1';

						cap_crc_active_i<='0';
					END IF;
				END IF;
			END IF;
			IF CAPTURE AND cap_abort_sync2/=cap_abort_seen THEN
				cap_abort_seen<=cap_abort_sync2;
				IF cap_state_i/=x"00" AND cap_abort(15)='0' AND
				   unsigned(cap_abort(14 DOWNTO 0))=cap_req_checkpoint THEN
					cap_abort_pending<='1';
					cap_cleanup_pending_i<='1';
					cap_hold_pending<='0'; cap_hold_active<='1';
					cap_state_i<=x"04";

					cap_crc_active_i<='0';
					IF cap_state_i=x"03" THEN cap_cleanup_drained_i<='1'; END IF;
				ELSE
					IF cap_fault_i=x"00" THEN cap_fault_i<=x"0C"; END IF; -- BAD_RELEASE
					cap_abort_ack_i<=cap_abort_sync2;
					IF cap_state_i/=x"00" THEN
						cap_state_i<=x"04"; cap_hold_pending<='0'; cap_hold_active<='1';
					END IF;
				END IF;
			END IF;
			IF CAPTURE AND cap_release_pending='1' AND cap_state_i=x"03" AND cap_fault_i=x"00" AND
			   i_pce='1' AND i_pvs='0' AND i_vs_pre='1' THEN
				cap_hold_pending<='0'; cap_hold_active<='0'; cap_state_i<=x"00";
				cap_watchdog_active_i<='0'; cap_watchdog_toggle_i<=NOT cap_watchdog_toggle_i;
				cap_target_valid_i<='0'; cap_target_active_i<='0'; cap_drain_sent_i<='0';
				cap_crc_active_i<='0';
				cap_release_pending<='0'; cap_abort_pending<='0';
				cap_cleanup_pending_i<='0'; cap_cleanup_drained_i<='0'; cap_drain_cleanup_i<='0';
				cap_lifecycle_cancel_i<='0';
				cap_owner_i<='0';
				cap_release_ack_i<=cap_release_sync2;
			END IF;
			IF CAPTURE AND cap_cleanup_pending_i='1' AND cap_cleanup_drained_i='1' AND
			   (cap_abort_pending='1' OR cap_lifecycle_cancel_i='1' OR
			    cap_fault_mailbox_code_i=x"0B" OR cap_owner_i='0') AND
			   i_pce='1' AND i_pvs='0' AND i_vs_pre='1' THEN
				cap_hold_pending<='0'; cap_hold_active<='0';
				cap_state_i<=x"00";
				cap_watchdog_active_i<='0'; cap_watchdog_toggle_i<=NOT cap_watchdog_toggle_i;
				cap_target_valid_i<='0'; cap_target_active_i<='0'; cap_drain_sent_i<='0';
				cap_crc_active_i<='0';
				cap_release_pending<='0'; cap_abort_pending<='0';
				cap_cleanup_pending_i<='0'; cap_cleanup_drained_i<='0'; cap_drain_cleanup_i<='0';
				cap_lifecycle_cancel_i<='0';
				cap_owner_i<='0';
				IF cap_abort_pending='1' THEN cap_abort_ack_i<=cap_abort_sync2; END IF;
			END IF;
			IF CAPTURE AND cap_status_ack_sync2_i=cap_status_toggle_i AND
			   cap_status_bundle_i/=(cap_status_state_i & cap_fault_i & cap_life_ack_i &
				cap_abort_ack_i & cap_release_ack_i & cap_req_ack_i) THEN
				cap_status_bundle_i<=cap_status_state_i & cap_fault_i & cap_life_ack_i &
					cap_abort_ack_i & cap_release_ack_i & cap_req_ack_i;
				cap_status_toggle_i<=NOT cap_status_toggle_i;
			END IF;
		END IF;
	END PROCESS;

	-----------------------------------------------------------------------------
	i_reset_na<='0'   WHEN reset_na='0' ELSE '1' WHEN rising_edge(i_clk);
	o_reset_na<='0'   WHEN reset_na='0' ELSE '1' WHEN rising_edge(o_clk);
	avl_reset_na<='0' WHEN reset_na='0' ELSE '1' WHEN rising_edge(avl_clk);

	-----------------------------------------------------------------------------
	-- Input pixels FIFO and shreg
	InAT:PROCESS(i_clk,i_reset_na) IS
		CONSTANT Z : unsigned(FRAC-1 DOWNTO 0):=(OTHERS =>'0');
		VARIABLE frac_v : unsigned(FRAC-1 DOWNTO 0);
		VARIABLE div_v : unsigned(16 DOWNTO 0);
		VARIABLE dir_v : unsigned(11 DOWNTO 0);
		VARIABLE bil_t_v : type_bil_t;
	BEGIN
		IF i_reset_na='0' THEN
			i_write<='0'; i_wreq_header<='0';
			IF CAPTURE THEN i_wreq<='0'; END IF;

		ELSIF rising_edge(i_clk) THEN
			i_push<='0';
			i_pushhead<='0';
			i_eol<='0'; -- End Of Line
			i_freeze <=freeze; -- <ASYNC>
			i_bob_deint <= bob_deint;
			i_iauto<=iauto; -- <ASYNC>
			i_wreq<='0';
			i_wreq_header<='0';
			i_wr<='0';

			------------------------------------------------------
			i_head(127 DOWNTO 120)<=x"01"; -- Header type
			i_head(119 DOWNTO 112)<="000000" & i_format; -- Header format
			i_head(111 DOWNTO 96)<="0000" & to_unsigned(N_BURST,12); -- Header size
			i_head(95 DOWNTO 80)<=x"0000"; -- Attributes. TBD
			i_head(80)<=i_inter;
			i_head(81)<=i_flm;
			i_head(82)<=i_hdown;
			i_head(83)<=i_vdown;
			i_head(84)<=i_mode(3);
			i_head(87 DOWNTO 85)<=i_count;
			i_head(79 DOWNTO 64)<="0000" & to_unsigned(i_hrsize,12); -- Image width
			i_head(63 DOWNTO 48)<="0000" & to_unsigned(i_vrsize,12); -- Image height
			i_head(47 DOWNTO 32)<= to_unsigned(N_BURST * i_hburst,16); -- Line Length. Bytes
			i_head(31 DOWNTO 16)<="0000" & to_unsigned(i_ohsize,12);
			i_head(15 DOWNTO 0) <="0000" & to_unsigned(i_ovsize,12);

			------------------------------------------------------
			i_ppix<=(i_r,i_g,i_b);
			i_pvs<=i_vs;
			i_pfl<=i_fl;
			i_pde<=i_de;
			i_pce<=i_ce;

			------------------------------------------------------
			IF i_pce='1' THEN
				----------------------------------------------------
				i_vs_pre<=i_pvs;
				i_de_pre<=i_pde;
				i_fl_pre<=i_pfl;

				----------------------------------------------------
				-- Detect interlaced video
				IF NOT INTER THEN
					i_intercnt<=0;
				ELSIF i_pfl/=i_fl_pre THEN
					i_intercnt<=3;
				ELSIF i_pvs='1' AND i_vs_pre='0' AND i_intercnt>0 THEN
					i_intercnt<=i_intercnt-1;
				END IF;
				i_inter<=to_std_logic(i_intercnt>0);

				----------------------------------------------------
				IF i_pvs='1' AND i_vs_pre='0' THEN
					i_sof<='1';
				END IF;

				IF i_pde='1' AND i_de_pre='0' THEN
					i_flm<=i_pfl;
				END IF;

				IF i_pde='1' AND i_sof='1' THEN
					i_sof<='0';
					i_vcpt<=0;
					IF i_inter='1' AND i_flm='0' AND i_half='0' AND INTER THEN
						i_line<='1';
						i_wfl(o_ibuf1) <= '0';
						i_adrsi<=to_unsigned(N_BURST * i_hburst,32) +
									to_unsigned(N_BURST * to_integer(
									unsigned'("00") & to_std_logic(HEADER)),32);
					ELSE
						i_line<='0';
						i_wfl(o_ibuf0) <= '1';
						i_adrsi<=to_unsigned(N_BURST * to_integer(
									 unsigned'("00") & to_std_logic(HEADER)),32);
					END IF;
				END IF;

				i_ven<=to_std_logic(i_hcpt>=i_hmin AND i_hcpt<=i_hmax AND
													 i_vcpt>=i_vmin AND i_vcpt<=i_vmax) AND
													 NOT cap_hold_pending AND NOT cap_hold_active;

				-- Detects end of frame for triple buffering.
				i_endframe0<=i_vs AND (NOT i_inter OR i_flm OR i_bob_deint) AND NOT cap_hold_active;
				i_endframe1<=i_vs AND (NOT i_inter OR NOT i_flm OR i_bob_deint) AND NOT cap_hold_active;

				i_vss<=to_std_logic(i_vcpt>=i_vmin AND i_vcpt<=i_vmax);

				----------------------------------------------------
				IF i_pde='1' AND i_de_pre='0' THEN
					i_vimax<=i_vcpt;
					i_hcpt<=0;
				ELSE
					i_hcpt<=(i_hcpt+1) MOD 4096;
				END IF;

				IF i_pde='0' AND i_de_pre='1' THEN
					i_himax<=i_hcpt;
				END IF;

				IF i_iauto='1' THEN
					-- Auto-size
					i_hmin<=0;
					i_hmax<=i_himax;
					i_vmin<=0;
					IF i_pvs='1' AND i_vs_pre='0' AND (i_inter='0' OR i_pfl='0') THEN
						i_vmax<=i_vimax;
					END IF;
				ELSE
					-- Forced image
					i_hmin<=himin; -- <ASYNC>
					i_hmax<=himax; -- <ASYNC>
					i_vmin<=vimin; -- <ASYNC>
					IF i_pvs='1' AND i_vs_pre='0' AND (i_inter='0' OR i_pfl='0') THEN
						i_vmax<=vimax; -- <ASYNC>
					END IF;
				END IF;

				IF i_pvs='1' AND i_vs_pre='0' AND (i_inter='0' OR i_pfl='0') THEN
					i_vdmax<=i_vimax;
				END IF;
				i_hdmax<=i_himax;

				IF i_format="00" OR i_format="11" THEN -- 16bpp
					i_hburst<=(i_hrsize*2 + N_BURST - 1) / N_BURST;
				ELSIF i_format="01" THEN -- 24bpp
					i_hburst<=(i_hrsize*3 + N_BURST - 1) / N_BURST;
				ELSE -- 32bpp
					i_hburst<=(i_hrsize*4 + N_BURST - 1) / N_BURST;
				END IF;
				----------------------------------------------------
				i_mode<=mode; -- <ASYNC>
				i_format<=format; -- <ASYNC>

				-- Downscaling : Nearest or bilinear
				i_bil<=to_std_logic(i_mode(2 DOWNTO 0)/="000" AND NOT DOWNSCALE_NN);

				i_hdown<=to_std_logic(i_hsize>i_ohsize AND DOWNSCALE); --H downscale
				i_vdown<=to_std_logic(i_vsize>i_ovsize AND DOWNSCALE); --V downscale

				----------------------------------------------------
				i_hsize  <=(4096+i_hmax-i_hmin+1) MOD 4096;
				i_vmaxmin<=(4096+i_vmax-i_vmin+1) MOD 4096;

				IF i_inter='0' THEN
					-- Non interlaced
					i_vsize<=i_vmaxmin;
					i_half <='0';
				ELSIF i_ovsize<2*i_vmaxmin THEN
					-- Interlaced, but downscaling, use only half frames
					i_vsize<=i_vmaxmin;
					i_half <='1';
				ELSE
					-- Interlaced : Double image height
					i_vsize<=2*i_vmaxmin;
					i_half <='0';
				END IF;

				i_ohsize<=o_hsize; -- <ASYNC>
				i_ovsize<=o_vsize; -- <ASYNC>

				----------------------------------------------------
				-- Downscaling vertical
				i_divstart<='0';
				IF i_de_delay=16 THEN
					IF (i_vacc + 2*i_ovsize) < 2*i_vsize THEN
						i_vacc<=(i_vacc + 2*i_ovsize) MOD 8192;
						i_vnp<='0';
					ELSE
						i_vacc<=(i_vacc + 2*i_ovsize - 2*i_vsize + 8192) MOD 8192;
						i_vnp<='1';
					END IF;
					i_divstart<='1';

					IF i_vcpt=i_vmin THEN
					 i_vacc<=(i_vsize - i_ovsize + 8192) MOD 8192;
					 i_vnp<='1'; -- <AVOIR>
					END IF;
				END IF;

				IF i_vdown='0' THEN
					i_vnp<='1';
				END IF;

				-- Downscaling horizontal
				IF i_ven='1' THEN
					IF i_hacc + 2*i_ohsize < 2*i_hsize THEN
						i_hacc<=(i_hacc + 2*i_ohsize) MOD 8192;
						i_hnp<='0'; -- Skip. pix.
					ELSE
						i_hacc<=(i_hacc + 2*i_ohsize - 2*i_hsize + 8192) MOD 8192;
						i_hnp<='1';
					END IF;
				END IF;
				IF i_hdown='0' THEN
					i_hnp<='1';
				END IF;

				----------------------------------------------------
				-- Downscaling interpolation
				i_hpixp<=i_ppix;
				i_hpix0<=i_hpixp;
				i_hpix1<=i_hpix0;
				i_hpix2<=i_hpix1;
				i_hpix3<=i_hpix2;
				i_hpix4<=i_hpix3;

				i_hnp1<=i_hnp;  i_hnp2<=i_hnp1; i_hnp3<=i_hnp2; i_hnp4<=i_hnp3;
				i_ven1<=i_ven;  i_ven2<=i_ven1; i_ven3<=i_ven2; i_ven4<=i_ven3;
				i_ven5<=i_ven4; i_ven6<=i_ven5;

				-- C1 : DIV 1. Pipelined 4 bits non-restoring divider
				dir_v:=x"000";
				div_v:=to_unsigned(i_hacc * 16,17);

				div_v:=div_v-to_unsigned(i_hsize*16,17);
				dir_v(11):=NOT div_v(16);
				IF div_v(16)='0' THEN
					div_v:=div_v-to_unsigned(i_hsize*8,17);
				ELSE
					div_v:=div_v+to_unsigned(i_hsize*8,17);
				END IF;
				dir_v(10):=NOT div_v(16);
				i_div<=div_v;
				i_dir<=dir_v;

				-- C2 : DIV 2.
				div_v:=i_div;
				dir_v:=i_dir;
				IF div_v(16)='0' THEN
					div_v:=div_v-to_unsigned(i_hsize*4,17);
				ELSE
					div_v:=div_v+to_unsigned(i_hsize*4,17);
				END IF;
				dir_v(9):=NOT div_v(16);

				IF div_v(16)='0' THEN
					div_v:=div_v-to_unsigned(i_hsize*2,17);
				ELSE
					div_v:=div_v+to_unsigned(i_hsize*2,17);
				END IF;
				dir_v(8):=NOT div_v(16);
				i_h_frac<=dir_v;

				-- C4 : Horizontal Bilinear
				IF i_bil='0' THEN
					frac_v:=near_frac(i_h_frac);
					i_h_bil_t<=near_calc(frac_v,(i_hpix2,i_hpix2,i_hpix3,i_hpix3));
				ELSE
					frac_v:=bil_frac(i_h_frac);
					i_h_bil_t<=bil_calc(frac_v,(i_hpix2,i_hpix2,i_hpix3,i_hpix3));
				END IF;

				i_hpix.r<=bound(i_h_bil_t.r,8+FRAC);
				i_hpix.g<=bound(i_h_bil_t.g,8+FRAC);
				i_hpix.b<=bound(i_h_bil_t.b,8+FRAC);

				IF i_hdown='0' THEN
					i_hpix<=i_hpix4;
				END IF;

				-- C5 : Vertical Bilinear
				IF i_bil='0' THEN
					frac_v:=near_frac(i_v_frac(11 DOWNTO 0));
					bil_t_v:=near_calc(frac_v,(i_hpix,i_hpix,i_ldrm,i_ldrm));
				ELSE
					frac_v:=bil_frac(i_v_frac(11 DOWNTO 0));
					bil_t_v:=bil_calc(frac_v,(i_hpix,i_hpix,i_ldrm,i_ldrm));
				END IF;

				i_pix.r<=bound(bil_t_v.r,8+FRAC);
				i_pix.g<=bound(bil_t_v.g,8+FRAC);
				i_pix.b<=bound(bil_t_v.b,8+FRAC);

				IF i_vdown='0' THEN
					i_pix<=i_hpix;
				END IF;

				----------------------------------------------------
				-- VNP : Vert. downscaling line enable
				-- HNP : Horiz. downscaling pix. enable
				-- VEN : Enable pixel within displayed window

				IF (i_hnp4='1' AND i_ven6='1') OR i_pushend='1' THEN
					i_shift<=shift_ishift(i_shift,i_pix,i_format);
					i_dw<=shift_ipack(i_dw,i_acpt,i_shift,i_pix,i_format);

					IF shift_inext(i_acpt,i_format) AND i_vnp='1' THEN
						i_push<='1';
						i_pushend<='0';
					END IF;
					i_acpt<=(i_acpt+1) MOD 16;
				END IF;

				IF i_ven6='1' AND i_ven5='0' AND i_vnp='1' THEN
					i_pushend<='1';
				END IF;
				i_pushend2<=i_pushend;

				IF i_pushend2='1' AND i_pushend='0' THEN
					i_eol<='1';
				END IF;

				IF i_pde='0' AND i_de_pre='1' THEN
					i_de_delay<=0;
				ELSIF i_de_delay<18 THEN
					i_de_delay<=i_de_delay+1;
				END IF;

				IF i_de_delay=16 THEN
					i_lwad<=0;
					i_lrad<=0;
					i_vcpt<=i_vcpt+1;
					i_hacc<=(i_hsize - i_ohsize + 8192) MOD 8192;
					i_hbcpt<=0;
				END IF;
				IF i_de_delay=17 THEN
					i_acpt<=0;
					i_wad<=2*BLEN-1;
				END IF;

				IF i_pvs='0' AND i_vs_pre='1' AND
				   cap_hold_pending='0' AND cap_hold_active='0' THEN
					-- Push header
					i_pushhead<=to_std_logic(HEADER);
				END IF;

			END IF; -- IF i_pce='1'

			------------------------------------------------------
			-- Push pixels to downscaling line buffer
			i_lwr<=i_hnp4 AND i_ven5 AND i_pce;
			IF i_lwr='1' THEN
				i_lwad<=(i_lwad+1) MOD OHRESH;
			END IF;
			i_ldw<=i_hpix;

			IF i_hnp3='1' AND i_ven4='1' AND i_pce='1' THEN
				i_lrad<=(i_lrad+1) MOD OHRESH;
			END IF;

			------------------------------------------------------
			-- Write image properties header
			i_pushhead2<=i_pushhead AND NOT cap_hold_pending AND NOT cap_hold_active;
			i_pushhead3<=i_pushhead2 AND NOT cap_hold_pending AND NOT cap_hold_active;

			IF i_pushhead='1' AND i_freeze='0' AND cap_hold_pending='0' AND cap_hold_active='0' THEN
				i_dw<=i_head(127 DOWNTO 128-N_DW);
				i_count<=i_count+1;
				i_wr<='1';
				i_wad<=0;
				IF N_DW=128 THEN
					i_alt<='0';
					i_wreq<=NOT i_freeze;
					i_wreq_header<='1';
					i_adrs<=(OTHERS =>'0');
				END IF;
			END IF;

			IF i_pushhead2='1' AND i_freeze='0' AND cap_hold_pending='0' AND cap_hold_active='0' AND N_DW=64 THEN
				i_dw<=i_head(N_DW-1 DOWNTO 0);
				i_wr<='1';
				i_wad<=1;
				i_wreq<=NOT i_freeze;
				i_wreq_header<='1';
				i_alt<='0';
				i_adrs<=(OTHERS =>'0');
			END IF;
			IF i_pushhead3='1' AND cap_hold_pending='0' AND cap_hold_active='0' THEN
				i_wad<=BLEN-1;
			END IF;

			------------------------------------------------------
			-- Push pixels to DPRAM
			IF i_push='1' AND i_freeze='0' THEN
				i_wr<='1';
				i_wad<=(i_wad+1) MOD (BLEN*2);
				IF (i_wad+1) MOD BLEN=BLEN-1 AND i_hbcpt<i_hburst THEN
					i_hbcpt<=(i_hbcpt+1) MOD 32;
					i_wreq<=NOT i_freeze;
					i_wreq_header<='0';
					i_alt<=to_std_logic((i_wad+1)/BLEN /= 0);
					i_adrs<=i_adrsi;
					i_adrsi<=i_adrsi+N_BURST;
				END IF;
			END IF;

			-- End of line
			IF i_eol='1' AND i_freeze='0' THEN
				IF (i_wad MOD BLEN)/=BLEN-1 AND i_hbcpt<i_hburst THEN
					-- Some pixels are in the partially filled buffer
					i_hbcpt<=(i_hbcpt+1) MOD 32;
					i_wreq<=NOT i_freeze;
					i_wreq_header<='0';
					i_alt <=to_std_logic(i_wad/BLEN /= 0);
					i_adrs <=i_adrsi;
					IF i_inter='1' AND i_half='0' THEN
						-- Skip every other line for interlaced video
						i_adrsi<=i_adrsi + N_BURST * (i_hburst + 1);
					ELSE
						i_adrsi<=i_adrsi + N_BURST;
					END IF;
				ELSE
					IF i_inter='1' AND i_half='0' THEN
						-- Skip every other line for interlaced video
						i_adrsi<=i_adrsi + N_BURST * i_hburst;
					END IF;
				END IF;
			END IF;

			-- Push write accesses. Ensure a delay between consecutive writes
			IF i_wreq='1' AND NOT CAPTURE THEN
				i_wadrs_mem<=i_adrs; -- Address
				i_walt_mem <=i_alt;  -- Double buffer select
				i_wline_mem<=i_line; -- Line, for interleaved video
				i_wreq_mem<='1';
			END IF;
			IF i_wreq_mem='1' AND i_wdelay=5 AND NOT CAPTURE THEN
				i_write<=NOT i_write;
				i_wadrs<=i_wadrs_mem;
				i_walt <=i_walt_mem;
				i_wline<=i_wline_mem;
				i_wdelay<=0;
				i_wreq_mem<='0';
			ELSIF i_wdelay<5 THEN
				i_wdelay<=i_wdelay+1;
			END IF;
			-- Capture uses the leased-half handshake instead of this toggle.
			IF CAPTURE THEN i_write<='0'; END IF;

		END IF;
	END PROCESS;

	-- If downscaling, export to the output part the downscaled size
	i_hrsize<=i_hsize WHEN i_hdown='0' ELSE i_ohsize;
	i_vrsize<=i_vsize WHEN i_vdown='0' ELSE i_ovsize;

	-----------------------------------------------------------------------------
	-- Input Divider. For downscaling.
	-- Vfrac = IVacc / IVsize 12 / 12 --> 12
	IDividers:PROCESS (i_clk,i_reset_na) IS
	BEGIN
		IF i_reset_na='0' THEN
--pragma synthesis_off
			i_v_frac<=x"000";
--pragma synthesis_on
			NULL;
		ELSIF rising_edge(i_clk) THEN
			i_vdivi<=to_unsigned(2*i_vsize,13);
			i_vdivr<=to_unsigned(i_vacc*4096,25);

			------------------------------------------------------
			IF i_divstart='1' THEN
				i_divcpt<=0;
				i_divrun<='1';

			ELSIF i_divrun='1' THEN
				----------------------------------------------------
				IF i_divcpt=6 THEN
					i_divrun<='0';
					i_v_frac<=i_vdivr(4 DOWNTO 0) & NOT i_vdivr(24) & "000000";
				ELSE
					i_divcpt<=i_divcpt+1;
				END IF;

				IF i_vdivr(24)='0' THEN
					i_vdivr(24 DOWNTO 12)<=i_vdivr(23 DOWNTO 11) - i_vdivi;
				ELSE
					i_vdivr(24 DOWNTO 12)<=i_vdivr(23 DOWNTO 11) + i_vdivi;
				END IF;
				i_vdivr(11 DOWNTO 0)<=i_vdivr(10 DOWNTO 0) & NOT i_vdivr(24);

				----------------------------------------------------
			END IF;
		END IF;
	END PROCESS IDividers;

	-----------------------------------------------------------------------------
	-- DPRAM Input. Double buffer for RAM bursts.
	PROCESS (i_clk) IS
	BEGIN
		IF rising_edge(i_clk) THEN
			IF i_wr='1' THEN
				IF NOT CAPTURE THEN
					i_dpram(i_wad)<=i_dw;
				ELSIF i_wad<BLEN THEN
					IF cap_half_lease_i(0)='0' OR
					   cap_half_ack_sync2_i(0)/=cap_half_ack_seen_i(0) THEN
						i_dpram(i_wad)<=i_dw;
					END IF;
				ELSE
					IF cap_half_lease_i(1)='0' OR
					   cap_half_ack_sync2_i(1)/=cap_half_ack_seen_i(1) THEN
						i_dpram(i_wad)<=i_dw;
					END IF;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	avl_dr<=i_dpram(avl_rad_c) WHEN rising_edge(avl_clk);

	-- Line buffer for downscaling with interpolation
	DownLine:IF DOWNSCALE GENERATE
		ILBUF:PROCESS(i_clk) IS
		BEGIN
			IF rising_edge(i_clk) THEN
				IF i_lwr='1' THEN
					i_mem(i_lwad MOD IHRES)<=i_ldw;
				END IF;
				IF i_pce='1' THEN
					i_ldrm<=i_mem(i_lrad MOD IHRES);
				END IF;
			END IF;
		END PROCESS ILBUF;
	END GENERATE DownLine;

	-----------------------------------------------------------------------------
	-- AVALON interface
	Avaloir:PROCESS(avl_clk,avl_reset_na) IS
		VARIABLE adr_v : unsigned(31 DOWNTO 0);
		VARIABLE sum_v : unsigned(31 DOWNTO 0);
		VARIABLE write_data_v : unsigned(N_DW-1 DOWNTO 0);
		VARIABLE cap_half_v : natural RANGE 0 TO 1;
	BEGIN
		IF avl_reset_na='0' THEN
			avl_state<=sIDLE;
			avl_write_sr<='0';
			avl_read_sr<='0';
			avl_readdataack<='0';
			avl_readack<='0';
			cap_half_req_sync1_o<=(OTHERS=>'0'); cap_half_req_sync2_o<=(OTHERS=>'0');
			cap_half_req_seen_o<=(OTHERS=>'0'); cap_half_pending_avl<=(OTHERS=>'0');
			cap_half_pending_toggle_avl<=(OTHERS=>'0'); cap_half_ack_toggle_o<=(OTHERS=>'0');
			cap_write_active_avl<='0'; cap_write_active_half_avl<='0';
			cap_half_active_toggle_avl<=(OTHERS=>'0');
			cap_write_expected_id_avl<=resize(CAPTURE_WRITE_ID_SEED,1)+1;
			cap_pixel_hash_avl<=(OTHERS=>'0');
			cap_drain_req_sync1_avl<='0'; cap_drain_req_sync2_avl<='0'; cap_drain_req_seen_avl<='0';
			cap_drain_cleanup_sync1_avl<='0'; cap_drain_cleanup_sync2_avl<='0'; cap_drain_cleanup_avl<='0';
			cap_cleanup_sync1_avl<='0'; cap_cleanup_sync2_avl<='0'; cap_cleanup_seen_avl<='0';
			cap_drain_sent_sync1_avl<='0'; cap_drain_sent_sync2_avl<='0';
			cap_cleanup_done_toggle_avl<='0';
			cap_drain_pending_avl<='0'; cap_drain_ack_avl<='0'; cap_drain_final_id_avl<=(OTHERS=>'0');

			cap_avl_fault_avl<=(OTHERS=>'0');
			cap_avl_fault_clear_sync1_avl<='0'; cap_avl_fault_clear_sync2_avl<='0';
			cap_avl_fault_clear_seen_avl<='0'; cap_avl_fault_clear_ack_avl<='0';
			cap_fault_mailbox_avl<=(OTHERS=>'0'); cap_fault_mailbox_pending_code_avl<=(OTHERS=>'0');
			cap_fault_mailbox_toggle_avl<='0'; cap_fault_mailbox_pending_avl<='0';
			cap_fault_mailbox_ack_i_sync1_avl<='0'; cap_fault_mailbox_ack_i_sync2_avl<='0';
			cap_fault_mailbox_ack_io_sync1_avl<='0'; cap_fault_mailbox_ack_io_sync2_avl<='0';
			cap_watchdog_sync1_avl<='0'; cap_watchdog_sync2_avl<='0'; cap_watchdog_seen_avl<='0';
			cap_watchdog_active_avl<='0'; cap_watchdog_cycle_avl<=0; cap_watchdog_ms_avl<=0;

		ELSIF rising_edge(avl_clk) THEN
			cap_drain_req_sync1_avl<=cap_drain_toggle_i;
			cap_drain_req_sync2_avl<=cap_drain_req_sync1_avl;
			cap_drain_cleanup_sync1_avl<=cap_drain_cleanup_i;
			cap_drain_cleanup_sync2_avl<=cap_drain_cleanup_sync1_avl;
			cap_cleanup_sync1_avl<=cap_cleanup_pending_i;
			cap_cleanup_sync2_avl<=cap_cleanup_sync1_avl;
			cap_drain_sent_sync1_avl<=cap_drain_sent_i;
			cap_drain_sent_sync2_avl<=cap_drain_sent_sync1_avl;
			IF cap_cleanup_sync2_avl='0' THEN
				cap_cleanup_seen_avl<='0';
			ELSIF cap_cleanup_sync2_avl='1' AND cap_drain_sent_sync2_avl='1' AND
			      cap_cleanup_seen_avl='0' AND
			      avl_state=sIDLE AND
			      cap_drain_pending_avl='0' AND cap_half_pending_avl="00" AND
			      cap_write_active_avl='0' AND
			      cap_write_expected_id_avl=cap_drain_final_id_avl+1 AND
			      cap_drain_req_seen_avl=cap_drain_req_sync2_avl THEN
				cap_cleanup_seen_avl<='1';
				cap_cleanup_done_toggle_avl<=NOT cap_cleanup_done_toggle_avl;
			END IF;
			cap_watchdog_sync1_avl<=cap_watchdog_toggle_i;
			cap_watchdog_sync2_avl<=cap_watchdog_sync1_avl;
			cap_avl_fault_clear_sync1_avl<=cap_avl_fault_clear_toggle_i;
			cap_avl_fault_clear_sync2_avl<=cap_avl_fault_clear_sync1_avl;
			cap_fault_mailbox_ack_io_sync1_avl<=cap_fault_mailbox_ack_toggle_io;
			cap_fault_mailbox_ack_io_sync2_avl<=cap_fault_mailbox_ack_io_sync1_avl;
			cap_fault_mailbox_ack_i_sync1_avl<=cap_fault_mailbox_ack_toggle_i;
			cap_fault_mailbox_ack_i_sync2_avl<=cap_fault_mailbox_ack_i_sync1_avl;
			IF cap_avl_fault_clear_sync2_avl/=cap_avl_fault_clear_seen_avl THEN
				cap_avl_fault_clear_seen_avl<=cap_avl_fault_clear_sync2_avl;
				cap_avl_fault_clear_ack_avl<=cap_avl_fault_clear_sync2_avl;
				cap_avl_fault_avl<=(OTHERS=>'0');
				cap_fault_mailbox_pending_code_avl<=(OTHERS=>'0');
				cap_fault_mailbox_pending_avl<='1';
			ELSIF cap_avl_fault_avl/=x"00" AND
			      cap_avl_fault_avl/=cap_fault_mailbox_avl AND
			      cap_avl_fault_avl/=cap_fault_mailbox_pending_code_avl THEN
				cap_fault_mailbox_pending_code_avl<=cap_avl_fault_avl;
				cap_fault_mailbox_pending_avl<='1';
			END IF;
			IF cap_fault_mailbox_pending_avl='1' AND
			   cap_avl_fault_clear_sync2_avl=cap_avl_fault_clear_seen_avl AND
			   NOT (cap_avl_fault_avl/=x"00" AND cap_avl_fault_avl/=cap_fault_mailbox_avl AND
			        cap_avl_fault_avl/=cap_fault_mailbox_pending_code_avl) AND
			   cap_fault_mailbox_ack_io_sync2_avl=cap_fault_mailbox_toggle_avl AND
			   cap_fault_mailbox_ack_i_sync2_avl=cap_fault_mailbox_toggle_avl THEN
				cap_fault_mailbox_avl<=cap_fault_mailbox_pending_code_avl;
				cap_fault_mailbox_toggle_avl<=NOT cap_fault_mailbox_toggle_avl;
				cap_fault_mailbox_pending_avl<='0';
			END IF;
			IF cap_watchdog_sync2_avl/=cap_watchdog_seen_avl THEN
				cap_watchdog_seen_avl<=cap_watchdog_sync2_avl;
				cap_watchdog_active_avl<=cap_watchdog_active_i;
				cap_watchdog_cycle_avl<=0; cap_watchdog_ms_avl<=0;
			ELSIF cap_watchdog_active_avl='1' THEN
				IF cap_watchdog_cycle_avl=CAPTURE_CYCLES_PER_MS-1 THEN
					cap_watchdog_cycle_avl<=0;
					IF cap_watchdog_ms_avl+1>=to_integer(cap_req_hold_ms) THEN
						cap_watchdog_active_avl<='0';
						IF cap_avl_fault_avl=x"00" THEN cap_avl_fault_avl<=x"0B"; END IF; -- HOLD_TIMEOUT
					ELSE
						cap_watchdog_ms_avl<=cap_watchdog_ms_avl+1;
					END IF;
				ELSE
					cap_watchdog_cycle_avl<=cap_watchdog_cycle_avl+1;
				END IF;
			END IF;
			IF CAPTURE AND cap_drain_req_sync2_avl/=cap_drain_req_seen_avl THEN
				cap_drain_req_seen_avl<=cap_drain_req_sync2_avl;
				cap_drain_final_id_avl<=cap_target_final_id_i;
				cap_drain_cleanup_avl<=cap_drain_cleanup_sync2_avl;
				cap_drain_pending_avl<='1';
			END IF;
			cap_half_req_sync1_o<=cap_half_req_toggle_i;
			cap_half_req_sync2_o<=cap_half_req_sync1_o;
			FOR h IN 0 TO 1 LOOP
				IF CAPTURE AND cap_half_req_sync2_o(h)/=cap_half_req_seen_o(h) THEN
					cap_half_req_seen_o(h)<=cap_half_req_sync2_o(h);
					cap_half_pending_toggle_avl(h)<=cap_half_req_sync2_o(h);
					cap_half_pending_avl(h)<='1';
				END IF;
			END LOOP;
			----------------------------------
			avl_write_sync<=i_write; -- <ASYNC>
			avl_write_sync2<=avl_write_sync;
			avl_write_pulse<=avl_write_sync XOR avl_write_sync2;
			IF avl_write_pulse='1' THEN
				avl_wadrs <=i_wadrs AND (RAMSIZE - 1); -- <ASYNC>
				avl_wline <=i_wline; -- <ASYNC>
				avl_walt  <=i_walt; -- <ASYNC>
			END IF;

			----------------------------------
			avl_read_sync<=o_read; -- <ASYNC>
			avl_read_sync2<=avl_read_sync;
			avl_read_pulse<=avl_read_sync XOR avl_read_sync2;
			avl_radrs <=o_adrs; -- <ASYNC>
			avl_rline <=o_rline; -- <ASYNC>

			--------------------------------------------
			avl_o_vs_sync<=o_vsv(0); -- <ASYNC>
			avl_o_vs<=avl_o_vs_sync;

			avl_fb_ena<=o_fb_ena; -- <ASYNC>
			IF avl_fb_ena='0' THEN
				IF HEADER THEN
					avl_o_offset0<=buf_offset(o_obuf0,RAMBASE,RAMSIZE) + N_BURST;  -- <ASYNC>
					avl_o_offset1<=buf_offset(o_obuf1,RAMBASE,RAMSIZE) + N_BURST;  -- <ASYNC>
				ELSE
					avl_o_offset0<=buf_offset(o_obuf0,RAMBASE,RAMSIZE);  -- <ASYNC>
					avl_o_offset1<=buf_offset(o_obuf1,RAMBASE,RAMSIZE);  -- <ASYNC>
				END IF;
			ELSIF avl_o_vs_sync='0' AND avl_o_vs='1' THEN
				-- Copy framebuffer base address at VS falling edge
				avl_o_offset0<=o_fb_base; -- <ASYNC>
				avl_o_offset1<=o_fb_base; -- <ASYNC>
			END IF;

			avl_i_offset0<=buf_offset(o_ibuf0,RAMBASE,RAMSIZE);  -- <ASYNC>
			avl_i_offset1<=buf_offset(o_ibuf1,RAMBASE,RAMSIZE);  -- <ASYNC>

			--------------------------------------------
			avl_dw<=swap(unsigned(avl_readdata));
			avl_read_i<='0';
			avl_write_i<='0';

			avl_write_sr<=(avl_write_sr OR avl_write_pulse) AND NOT avl_write_clr;
			avl_read_sr <=(avl_read_sr  OR avl_read_pulse)  AND NOT avl_read_clr;
			avl_write_clr<='0';
			avl_read_clr <='0';

			avl_rad<=avl_rad_c;

			--------------------------------------------
			CASE avl_state IS
				WHEN sIDLE =>
					IF CAPTURE AND
					   ((cap_half_pending_avl(0)='1' AND cap_half_id_i(0)=cap_write_expected_id_avl) OR
					    (cap_half_pending_avl(1)='1' AND cap_half_id_i(1)=cap_write_expected_id_avl)) THEN
						IF cap_half_pending_avl(0)='1' AND cap_half_id_i(0)=cap_write_expected_id_avl THEN
							cap_half_v:=0;
						ELSE
							cap_half_v:=1;
						END IF;
						cap_half_pending_avl(cap_half_v)<='0';
						cap_write_active_avl<='1';
						cap_write_active_half_avl<=to_std_logic(cap_half_v=1);
						cap_half_active_toggle_avl(cap_half_v)<=cap_half_pending_toggle_avl(cap_half_v);
						-- synthesis translate_off
						IF CAPTURE_WRITE_ID_SEED/=0 THEN
							REPORT "capture Avalon start ID " & to_hstring(cap_half_id_i(cap_half_v)) &
								" half=" & integer'image(cap_half_v) &
								" base=" & to_hstring(cap_half_base_i(cap_half_v)) &
								" offset=" & to_hstring(cap_half_offset_i(cap_half_v))
								SEVERITY note;
						END IF;
						-- synthesis translate_on
						avl_state<=sWRITE;
						avl_rad<=cap_half_v*BLEN;
						avl_walt<=to_std_logic(cap_half_v=1);
						-- A half's descriptor is immutable until its last-beat ACK.
						adr_v:=cap_half_base_i(cap_half_v)+cap_half_offset_i(cap_half_v);
						avl_address<=std_logic_vector(adr_v(N_AW+NB_LA-1 DOWNTO NB_LA));
					ELSIF avl_write_sr='1' THEN
						avl_state<=sWRITE;
						avl_write_clr<='1';
						IF avl_walt='0' THEN
							avl_rad<=0;
						ELSE
							avl_rad<=BLEN;
						END IF;
						IF avl_wline='0' THEN
							avl_address<=std_logic_vector(
								avl_wadrs(N_AW+NB_LA-1 DOWNTO NB_LA) +
								avl_i_offset0(N_AW+NB_LA-1 DOWNTO NB_LA));
						ELSE
							avl_address<=std_logic_vector(
								avl_wadrs(N_AW+NB_LA-1 DOWNTO NB_LA) +
								avl_i_offset1(N_AW+NB_LA-1 DOWNTO NB_LA));
						END IF;
					ELSIF avl_read_sr='1' THEN
						avl_state<=sREAD;
						avl_read_clr<='1';
					END IF;

				WHEN sWRITE =>
					avl_write_i<='1';
					IF avl_write_i='1' AND avl_waitrequest='0' THEN
						IF CAPTURE AND cap_write_active_avl='1' THEN
							cap_half_v:=0;
							IF cap_write_active_half_avl='1' THEN cap_half_v:=1; END IF;
							IF cap_half_header_i(cap_half_v)='1' THEN
								-- The native header starts each image, before its pixels.
								cap_pixel_hash_avl<=(OTHERS=>'0');
							ELSE
								write_data_v:=swap(avl_dr);
								sum_v:=cap_pixel_hash_avl;
								FOR word_index IN 0 TO N_DW/32-1 LOOP
									sum_v:=capture_gfw1_step(sum_v,write_data_v(word_index*32+31 DOWNTO word_index*32));
								END LOOP;
								cap_pixel_hash_avl<=sum_v;
							END IF;
						END IF;
						IF (avl_rad MOD BLEN)=BLEN-1 THEN
							avl_write_i<='0';
							avl_state<=sIDLE;
							IF CAPTURE AND cap_write_active_avl='1' THEN
								cap_half_v:=0;
								IF cap_write_active_half_avl='1' THEN cap_half_v:=1; END IF;
								ASSERT cap_half_id_i(cap_half_v)=cap_write_expected_id_avl
									REPORT "capture Avalon write completion identity out of order" SEVERITY failure;
								-- synthesis translate_off
								IF CAPTURE_WRITE_ID_SEED/=0 THEN
									REPORT "capture accepted write ID " & to_hstring(cap_half_id_i(cap_half_v))
										SEVERITY note;
								END IF;
								-- synthesis translate_on
								IF cap_write_active_half_avl='0' THEN
									cap_half_ack_toggle_o(0)<=cap_half_active_toggle_avl(0);
								ELSE
									cap_half_ack_toggle_o(1)<=cap_half_active_toggle_avl(1);
								END IF;
								cap_write_expected_id_avl<=cap_write_expected_id_avl+1;
								cap_write_active_avl<='0';
							END IF;
						END IF;
					END IF;

				WHEN sREAD =>
					IF avl_rline='0' THEN
						adr_v:=avl_radrs + avl_o_offset0;
					ELSE
						adr_v:=avl_radrs + avl_o_offset1;
					END IF;
					avl_address<=std_logic_vector(adr_v(N_AW+NB_LA-1 DOWNTO NB_LA));

					avl_read_i<='1';
					IF avl_read_i='1' AND avl_waitrequest='0' THEN
						avl_state<=sIDLE;
						avl_read_i<='0';
						avl_readack<=NOT avl_readack;
					END IF;
			END CASE;

			-- Local Avalon drain means the exact final image identity has been
			-- accepted and no captured half or active image burst remains. This
			-- publishes a checksum; the host verifies DDR after copying.
			IF CAPTURE AND cap_drain_pending_avl='1' AND avl_state=sIDLE AND
			   cap_half_pending_avl="00" AND cap_write_active_avl='0' AND
			   cap_write_expected_id_avl=cap_drain_final_id_avl+1 THEN
				cap_drain_pending_avl<='0';
				cap_drain_ack_avl<=cap_drain_req_sync2_avl;

				-- synthesis translate_off
				REPORT "capture Avalon drain complete; final ID=" &
					to_hstring(cap_drain_final_id_avl) SEVERITY note;
				-- synthesis translate_on
			END IF;

			--------------------------------------------
			-- Pipelined data read
			avl_wr<='0';
			IF avl_readdatavalid='1' THEN
				avl_wr<='1';
				avl_wad<=(avl_wad+1) MOD (2*BLEN);
				IF (avl_wad MOD BLEN)=BLEN-2 THEN
					avl_readdataack<=NOT avl_readdataack;
				END IF;
			END IF;

			IF avl_o_vs_sync='0' AND avl_o_vs='1' THEN
				avl_wad<=2*BLEN-1;
			END IF;


			--------------------------------------------
		END IF;
	END PROCESS Avaloir;

	avl_read<=avl_read_i;
	avl_write<=avl_write_i;
	avl_writedata<=std_logic_vector(swap(avl_dr));
	avl_burstcount<=std_logic_vector(to_unsigned(BLEN,8));
	avl_byteenable<=(OTHERS =>'1');

	avl_rad_c<=(avl_rad+1) MOD (2*BLEN)
					WHEN avl_write_i='1' AND avl_waitrequest='0' ELSE avl_rad;

	-----------------------------------------------------------------------------
	-- DPRAM Output. Double buffer for RAM bursts.
	PROCESS (avl_clk) IS
	BEGIN
		IF rising_edge(avl_clk) THEN
			IF avl_wr='1' THEN
				o_dpram(avl_wad)<=avl_dw;
			END IF;
		END IF;
	END PROCESS;

	o_dr<=o_dpram(o_ad3) WHEN rising_edge(o_clk);

	-----------------------------------------------------------------------------
	-- Output Vertical Divider
	-- Vfrac = Vacc / Vsize
	ODivider:PROCESS (o_clk,o_reset_na) IS
	BEGIN
		IF o_reset_na='0' THEN
--pragma synthesis_off
			o_vfrac<=x"000";
--pragma synthesis_on
		ELSIF rising_edge(o_clk) THEN
			o_vdivi<=to_unsigned(2*o_vsize,13);
			o_vdivr<=to_unsigned(o_vacc*4096,25);
			------------------------------------------------------
			IF o_divstart='1' THEN
				o_divcpt<=0;
				o_divrun<='1';

			ELSIF o_divrun='1' THEN
				----------------------------------------------------
				IF o_divcpt=12 THEN
					o_divrun<='0';
					o_vfrac<=o_vdivr(10 DOWNTO 0) & NOT o_vdivr(24);
				ELSE
					o_divcpt<=o_divcpt+1;
				END IF;

				IF o_vdivr(24)='0' THEN
					o_vdivr(24 DOWNTO 12)<=o_vdivr(23 DOWNTO 11) - o_vdivi;
				ELSE
					o_vdivr(24 DOWNTO 12)<=o_vdivr(23 DOWNTO 11) + o_vdivi;
				END IF;
				o_vdivr(11 DOWNTO 0)<=o_vdivr(10 DOWNTO 0) & NOT o_vdivr(24);
				----------------------------------------------------
			END IF;
		END IF;
	END PROCESS ODivider;

	-----------------------------------------------------------------------------
	Scalaire:PROCESS (o_clk,o_reset_na) IS
		VARIABLE lev_inc_v,lev_dec_v : std_logic;
		VARIABLE prim_v,last_v,bib_v : std_logic;
		VARIABLE shift_v : unsigned(0 TO N_DW+15);
		VARIABLE hpix_v : type_pix;
		VARIABLE hcarry_v,vcarry_v : boolean;
		VARIABLE dif_v : natural RANGE 0 TO 8*OHRESH-1;
		VARIABLE off_v : natural RANGE 0 TO 15;
	BEGIN
		IF o_reset_na='0' THEN
			o_copy<=sWAIT;
			o_state<=sDISP;
			o_read_pre<='0';
			o_readlev<=0;
			o_copylev<=0;
			o_hsp<='0';
			o_readack_sync<='0';
			o_readack_sync2<='0';
			o_readack<='0';
			o_readdataack_sync<='0';
			o_readdataack_sync2<='0';
			o_readdataack<='0';

		ELSIF rising_edge(o_clk) THEN
			------------------------------------------------------
			o_mode   <=mode; -- <ASYNC> ?
			o_format <="0001" & format; -- <ASYNC> ?

			o_run    <=run; -- <ASYNC> ?

			o_htotal <=htotal; -- <ASYNC> ?
			o_hsstart<=hsstart; -- <ASYNC> ?
			o_hsend  <=hsend; -- <ASYNC> ?
			o_hdisp  <=hdisp; -- <ASYNC> ?

			o_vtotal <=vtotal; -- <ASYNC> ?
			o_vsstart<=vsstart; -- <ASYNC> ?
			o_vsend  <=vsend; -- <ASYNC> ?
			o_vdisp  <=vdisp; -- <ASYNC> ?

			IF gun_border_en='1' THEN
				o_hmin <= hmin + BORDER_H2;
				o_hmax <= hmax - BORDER_H2;
				o_vmin <= vmin + BORDER_V2;
				o_vmax <= vmax - BORDER_V2;
			ELSE
				o_hmin <= hmin;
				o_hmax <= hmax;
				o_vmin <= vmin;
				o_vmax <= vmax;
			END IF;

			o_hsize  <=o_hmax - o_hmin + 1;
			o_vsize  <=o_vmax - o_vmin + 1;

			o_vrr    <=vrr;
			o_vrrmax <= vrrmax;

			--------------------------------------------
			-- Triple buffering.
			-- For intelaced video, half frames are updated independently
			-- Input : Toggle buffer at end of input frame
			o_isync <= '0';
			o_isync2 <= o_isync;
			o_freeze <= freeze;
			o_bob_deint <= bob_deint;
			o_iwfl <= i_wfl;
			o_inter  <=i_inter; -- <ASYNC>
			o_iendframe0<=i_endframe0; -- <ASYNC>
			o_iendframe02<=o_iendframe0;
			IF o_iendframe0='1' AND o_iendframe02='0' THEN
				o_ibuf0<=buf_next(o_ibuf0,o_obuf0,o_freeze);
				o_bufup0<='1';
				o_isync <= '1';
			END IF;
			o_iendframe1<=i_endframe1; -- <ASYNC>
			o_iendframe12<=o_iendframe1;
			IF o_iendframe1='1' AND o_iendframe12='0' THEN
				o_ibuf1<=buf_next(o_ibuf1,o_obuf1,o_freeze);
				o_bufup1<='1';
				o_isync <= '1';
			END IF;

			-- Output : Change framebuffer, and image properties, at VS falling edge
			IF o_vsv(1)='1' AND o_vsv(0)='0' AND o_bufup0='1' THEN
				o_obuf0<=buf_next(o_obuf0,o_ibuf0,o_freeze);
				o_bufup0<='0';
			END IF;
			IF o_vsv(1)='1' AND o_vsv(0)='0' AND o_bufup1='1' THEN
				o_obuf1<=buf_next(o_obuf1,o_ibuf1,o_freeze);
				o_bufup1<='0';
				o_ihsize<=i_hrsize; -- <ASYNC>
				o_ivsize<=i_vrsize; -- <ASYNC>
				o_hdown<=i_hdown; -- <ASYNC>
				o_vdown<=i_vdown; -- <ASYNC>

				IF (o_newres > 0) then
					o_newres <= o_newres- 1;
				END IF;
			END IF;

			IF (swblack = '1' and o_fb_ena = '0' and (o_ihsize /= i_hrsize or o_ivsize /= i_vrsize)) then
				o_newres <= 3;
			END IF;

			-- Simultaneous change of input and output framebuffers
			IF o_vsv(1)='1' AND o_vsv(0)='0' AND
				o_iendframe0='1' AND o_iendframe02='0' THEN
				o_bufup0<='0';
				o_obuf0<=o_ibuf0;
			END IF;
			IF o_vsv(1)='1' AND o_vsv(0)='0' AND
				o_iendframe1='1' AND o_iendframe12='0' THEN
				o_bufup1<='0';
				o_obuf1<=o_ibuf1;
			END IF;

			-- Non-interlaced, use same buffer for even and odd lines
			IF o_inter='0' THEN
				o_ibuf1<=o_ibuf0;
				o_obuf1<=o_obuf0;
			END IF;

			-- Triple buffer disabled
			IF o_mode(3)='0' THEN
				o_obuf0<=0;
				o_obuf1<=0;
				o_ibuf0<=0;
				o_ibuf1<=0;
			END IF;

			-- Framebuffer mode.
			IF o_fb_ena='1' THEN
				o_ihsize<=o_fb_hsize;
				o_ivsize<=o_fb_vsize;
				o_format<=o_fb_format;
				o_hdown<='0';
				o_vdown<='0';
			END IF;

			-- 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
			CASE o_format(2 DOWNTO 0) IS
				WHEN "011" => o_ihsize_temp <= o_ihsize;
				WHEN "100" => o_ihsize_temp <= o_ihsize * 2;
				WHEN "110" => o_ihsize_temp <= o_ihsize * 4;
				WHEN OTHERS => o_ihsize_temp <= o_ihsize * 3;
			END CASE;

			o_ihsize_temp2 <= (o_ihsize_temp + N_BURST - 1);
			o_hburst <= o_ihsize_temp2 / N_BURST;

			IF o_fb_ena='1' AND o_fb_stride /= 0 THEN
				o_stride<=o_fb_stride;
			ELSE
				o_stride<=to_unsigned(o_ihsize_temp2,14);
				o_stride(NB_BURST-1 DOWNTO 0)<=(OTHERS =>'0');
			END IF;
			------------------------------------------------------
			o_hmode<=o_mode;
			IF o_hdown='1' AND DOWNSCALE THEN
				-- Force nearest if downscaling : Downscaled framebuffer
				o_hmode(2 DOWNTO 0)<="000";
			END IF;

			o_vmode<=o_mode;
			IF o_vdown='1' AND DOWNSCALE THEN
				-- Force nearest if downscaling : Downscaled framebuffer
				o_vmode(2 DOWNTO 0)<="000";
			END IF;

			------------------------------------------------------
			-- End DRAM READ
			o_readack_sync<=avl_readack; -- <ASYNC>
			o_readack_sync2<=o_readack_sync;
			o_readack<=o_readack_sync XOR o_readack_sync2;

			o_readdataack_sync<=avl_readdataack; -- <ASYNC>
			o_readdataack_sync2<=o_readdataack_sync;
			o_readdataack<=o_readdataack_sync XOR o_readdataack_sync2;

			------------------------------------------------------
			lev_inc_v:='0';
			lev_dec_v:='0';

			-- acpt : Pixel position within current data word
			-- dcpt : Destination image position

			-- Force preload 2 lines at top of screen
			IF o_hsv(0)='1' AND o_hsv(1)='0' THEN
				IF o_vcpt_pre3=o_vmin THEN
					o_fload<=2;
					o_bibu<='0';
				END IF;
				o_hsp<='1';
			END IF;

			o_vpe<=to_std_logic(o_vcpt_pre<o_vmax AND o_vcpt_pre>=o_vmin);
			o_divstart<='0';
			o_adrsa<='0';
			o_adrsb<=o_adrsa;

			o_vacc_ini<=(o_vsize - o_ivsize + 8192) MOD 8192;
			o_hacc_ini<=(o_hsize + o_ihsize + 8192) MOD 8192;

			--Alternate phase
			--o_vacc_ini<=o_ivsize;
			--o_hacc_ini<=(2*o_hsize - o_ihsize + 8192) MOD 8192;

			CASE o_state IS
					--------------------------------------------------
				WHEN sDISP =>
					IF o_hsp='1' THEN
						o_state<=sHSYNC;
						o_hsp<='0';
					END IF;
					o_prim<=true;
					o_vcarrym<=false;

					--------------------------------------------------
				WHEN sHSYNC =>
					dif_v :=(o_vacc_next - 2*o_vsize + 16384) MOD 16384;
					IF o_prim THEN
						IF dif_v>=8192 THEN
							o_vacc     <=o_vacc_next;
						ELSE
							o_vacc     <=dif_v;
						END IF;
					END IF;
					IF dif_v>=8192 THEN
						o_vacc_next<=(o_vacc_next + 2*o_ivsize) MOD 8192;
						vcarry_v:=false;
					ELSE
						o_vacc_next<=dif_v;
						vcarry_v:=true;
					END IF;

					IF o_vcpt_pre2=o_vmin THEN
						o_vacc     <=o_vacc_ini;
						o_vacc_next<=o_vacc_ini + 2*o_ivsize;
						o_vacpt <=x"001";
						o_vacptl<="01";
						vcarry_v:=false;
					END IF;

					IF vcarry_v THEN
						o_vacpt<=o_vacpt+1;
					END IF;
					IF vcarry_v AND o_prim THEN
						o_vacptl<=o_vacptl+1;
					END IF;
					o_vcarrym <= o_vcarrym OR vcarry_v;
					o_prim <= false;
					o_hbcpt<=0; -- Clear burst counter on line
					o_divstart<=to_std_logic(NOT vcarry_v);
					IF NOT vcarry_v  OR o_fload>0 THEN
						IF (o_vpe='1' AND o_vcarrym) OR o_fload>0 THEN
							o_state<=sREAD;
						ELSE
							o_state<=sDISP;
						END IF;
					END IF;

				WHEN sREAD =>
					-- Read a block
					IF o_readlev<2 AND o_adrsb='1' THEN
						lev_inc_v:='1';
						o_read_pre<=NOT o_read_pre;
						o_state <=sWAITREAD;
						o_bibu<=NOT o_bibu;
					END IF;
					prim_v:=to_std_logic(o_hbcpt=0);
					last_v:=to_std_logic(o_hbcpt=o_hburst-1);
					bib_v :=o_bibu;
					off_v :=pixoffset(o_adrs + o_fb_base(NB_LA-1 DOWNTO 0),o_fb_format);
					IF o_fb_ena='0' THEN
						off_v:=0;
					END IF;
					o_adrsa<='1';

				WHEN sWAITREAD =>
					IF o_readack='1' THEN
						o_hbcpt<=o_hbcpt+1;
						IF o_hbcpt<o_hburst-1 THEN
							-- If not finshed line, read more
							o_state<=sREAD;
						ELSE
							o_state<=sDISP;
							IF o_fload>=1 THEN
								o_fload<=o_fload-1;
							END IF;
						END IF;
					END IF;

					--------------------------------------------------
			END CASE;

			o_read<=o_read_pre AND o_run;
			o_rline<=o_vacpt(0); -- Even/Odd line for interlaced video

			----
			-- When bob deinterlacing we read lines from one buffer (the most current) but we read them twice
			-- (in contrast to weave deinterlacing where we read each 480p line from alternating buffers)
			-- To counteract the severe vibrating/motion with bob deinterlacing, we need to offset one field
			-- by a half-line. This is done by only reading the first line of the 'even' frame once

			IF o_inter='1' AND o_bob_deint='1' THEN
				IF o_iwfl(o_obuf0)='0' THEN
					IF o_vacpt=0 OR o_rline='1' THEN
						o_adrs_pre <= to_integer(o_vacpt) * to_integer(o_stride);
					ELSE
						o_adrs_pre <= (to_integer(o_vacpt)-1) * to_integer(o_stride);
					END IF;
				ELSE
					o_adrs_pre <= to_integer(o_vacpt(11 DOWNTO 1) & "0") * to_integer(o_stride);
				END IF;
			ELSE
				o_adrs_pre<=to_integer(o_vacpt) * to_integer(o_stride);
			END IF;

			IF o_adrsa='1' THEN
				IF o_fload=2 THEN
					o_adrs<=to_unsigned(o_hbcpt * N_BURST,32);
					o_alt<="1111";
				ELSIF o_fload=1 THEN
					o_adrs<=to_unsigned(o_hbcpt * N_BURST,32) + o_stride;
					o_alt<="0100";
				ELSE
					o_adrs<=to_unsigned(o_adrs_pre + (o_hbcpt * N_BURST),32);
					o_alt<=altx(o_vacptl + 1);
				END IF;
			END IF;

			------------------------------------------------------
			-- Copy from buffered memory to pixel lines
			o_sh<='0';
			o_dcpt_clr <= '0';
			o_dcpt_inc <= '0';

			CASE o_copy IS
				WHEN sWAIT =>
					o_copyv(0)<='0';
					IF o_copylev>0 AND o_copyv(0)='0' THEN
						o_copy<=sCOPY;
						IF o_off(0)>0 AND o_primv(0)='1' THEN
							o_copy<=sSHIFT;
						END IF;
						o_altx<=o_alt;
					END IF;
					o_adturn<='0';
					-- This is a four-bit hardware counter. Spell out wraparound so
					-- simulators with strict natural range checks see the same
					-- modulo-16 behavior as the synthesized counter.
					o_pshift<=(o_off(0)+15) MOD 16;
					IF o_primv(0)='1' THEN
						-- First memcopy of a horizontal line, carriage return !
						-- o_ihsize/o_ihsizem are 12-bit hardware counters. Preserve
						-- their wraparound on startup when the first image is absent.
						o_ihsizem<=(o_ihsize + o_off(0) + 4094) MOD 4096;
						o_hacc     <=o_hacc_ini;
						o_hacc_next<=o_hacc_ini + 2*o_ihsize;
						o_hacpt    <=x"000";
						o_dcpt_clr <= '1';
						o_dshi<=2;
						o_acpt<=0;
						o_first<='1';
						o_last<='0';
					END IF;

					IF o_bibv(0)='0' THEN
						o_ad<=0;
					ELSE
						o_ad<=BLEN;
					END IF;

				WHEN sSHIFT =>
					o_hacpt<=o_hacpt+1;
					o_sh<='1';
					o_acpt<=(o_acpt+1) MOD 16;
					IF shift_onext(o_acpt,o_format) THEN
						o_ad<=(o_ad+1) MOD (2*BLEN);
					END IF;
					o_pshift<=(o_pshift+15) MOD 16;
					IF o_pshift=0 THEN
						o_copy<=sCOPY;
					END IF;

				WHEN sCOPY =>
					-- dshi : Force shift first two or three pixels of each line
					IF o_dshi=0 THEN
						dif_v:=(o_hacc_next - 2*o_hsize + (8*OHRESH)) MOD (8*OHRESH);
						IF dif_v>=4*OHRESH THEN
							o_hacc<=o_hacc_next;
							o_hacc_next<=o_hacc_next + 2*o_ihsize;
							hcarry_v:=false;
						ELSE
							o_hacc<=dif_v;
							o_hacc_next<=(dif_v + 2*o_ihsize + (4*OHRESH)) MOD (4*OHRESH);
							hcarry_v:=true;
						END IF;
						o_dcpt_inc <= '1';
					ELSE
						o_dshi<=o_dshi-1;
						hcarry_v:=false;
					END IF;
					IF o_dshi<=1 THEN
						o_copyv(0)<='1';
					END IF;
					IF hcarry_v THEN
						o_hacpt<=o_hacpt+1;
						o_last <=to_std_logic(o_hacpt>=o_ihsizem);
					END IF;

					IF hcarry_v OR o_dshi>0 THEN
						o_sh<='1';
						o_acpt<=(o_acpt+1) MOD 16;

						-- Shift two more pixels to the right before ending line.
						o_last1<=o_last;
						o_last2<=o_last1;

						IF shift_onext(o_acpt,o_format) THEN
							o_ad<=(o_ad+1) MOD (2*BLEN);
						END IF;

						IF o_adturn='1' AND (shift_onext((o_acpt+1) MOD 16,o_format)) AND
							(((o_ad MOD BLEN=0) AND o_lastv(0)='0') OR o_last2='1')  THEN
							o_copy<=sWAIT;
							lev_dec_v:='1';
						END IF;

						IF o_ad MOD BLEN=4 THEN
							o_adturn<='1';
						END IF;
					END IF;
			END CASE;

			o_acpt1<=o_acpt; o_acpt2<=o_acpt1; o_acpt3<=o_acpt2; o_acpt4<=o_acpt3;
			o_ad1<=o_ad; o_ad2<=o_ad1; o_ad3<=o_ad2;
			o_sh1<=o_sh; o_sh2<=o_sh1; o_sh3<=o_sh2; o_sh4<=o_sh3;
			o_lastt1<=o_last;   o_lastt2<=o_lastt1;
			o_lastt3<=o_lastt2; o_lastt4<=o_lastt3;

			------------------------------------------------------
			IF o_sh3='1' THEN
				shift_v:=shift_opack(o_acpt4,o_shift,o_dr,o_format);
				o_shift<=shift_v;
				o_hpixs<=shift_opix(shift_v,o_format);
			END IF;

			IF o_sh4='1' THEN
				hpix_v:=o_hpixs;
				IF o_format(4)='1' THEN -- Swap B <-> R
					hpix_v:=(r=>o_hpixs.b,g=>o_hpixs.g,b=>o_hpixs.r);
				END IF;
				IF o_format(2 DOWNTO 0)="011" THEN
					-- 8bpp indexed colour mode
					hpix_v:=(r=>o_fb_pal_dr(23 DOWNTO 16),g=>o_fb_pal_dr(15 DOWNTO 8),
									 b=>o_fb_pal_dr(7 DOWNTO 0));
				END IF;
				IF (o_newres > 0) then
					hpix_v := (others => (others => '0'));
				END IF;
				o_hpix0<=hpix_v;
				o_hpix1<=o_hpix0;
				o_hpix2<=o_hpix1;
				o_hpix3<=o_hpix2;

				IF o_first='1' THEN
					-- Left edge. Duplicate first pixel
					o_hpix1<=hpix_v;
					o_hpix2<=hpix_v;
					o_first<='0';
				END IF;
				IF o_lastt4='1' THEN
					-- Right edge. Keep last pixel.
					o_hpix0<=o_hpix0;
				END IF;
			END IF;

			------------------------------------------------------
			-- lev_inc : read start
			-- lev_dec : end of copy
			-- READLEV : Number of ongoing Avalon Reads
			IF lev_dec_v='0' AND lev_inc_v='1' THEN
				o_readlev<=o_readlev+1;
			ELSIF lev_dec_v='1' AND lev_inc_v='0' THEN
				o_readlev<=o_readlev-1;
			END IF;

			-- COPYLEV : Number of ongoing copies to line buffers
			IF lev_dec_v='1' AND o_readdataack='0' THEN
				o_copylev<=o_copylev-1;
			ELSIF lev_dec_v='0' AND o_readdataack='1' THEN
				o_copylev<=o_copylev+1;
			END IF;

			-- FIFOs
			IF lev_dec_v='1' THEN
				o_primv(0 TO 1)<=o_primv(1 TO 2); -- First buffer of line
				o_lastv(0 TO 1)<=o_lastv(1 TO 2); -- Last buffer of line
				o_bibv (0 TO 1)<=o_bibv (1 TO 2); -- Double buffer select
				o_off  (0 TO 1)<=o_off  (1 TO 2); -- Start offset
			END IF;

			IF lev_inc_v='1' THEN
				IF o_readlev=0 OR (o_readlev=1 AND lev_dec_v='1') THEN
					o_primv(0)<=prim_v;
					o_lastv(0)<=last_v;
					o_bibv (0)<=bib_v;
					o_off  (0)<=off_v;
				ELSIF (o_readlev=1 AND lev_dec_v='0') OR
							(o_readlev=2 AND lev_dec_v='1') THEN
					o_primv(1)<=prim_v;
					o_lastv(1)<=last_v;
					o_bibv (1)<=bib_v;
					o_off  (1)<=off_v;
				END IF;
				o_primv(2)<=prim_v;
				o_lastv(2)<=last_v;
				o_bibv (2)<=bib_v;
				o_off  (2)<=off_v;
			END IF;

			-- Sometimes o_clk is paused during PLL reconfig and causes o_state to get stuck in sREAD state.
			-- Reset state at VSync.
			IF o_vsv(1)='1' AND o_vsv(0)='0' THEN
				o_copy<=sWAIT;
				o_state<=sDISP;
				o_readlev<=0;
				o_copylev<=0;
				o_hsp<='0';
			END IF;

			------------------------------------------------------
		END IF;
	END PROCESS Scalaire;

	-- Fetch polyphase coefficients
	PolyFetch:PROCESS (o_clk) IS
		VARIABLE hfrac3_v, vfrac_v : unsigned(FRAC-1 DOWNTO 0);
	BEGIN
		IF rising_edge(o_clk) THEN
			hfrac3_v:=o_hfrac(3)(11 DOWNTO 12-FRAC);
			vfrac_v:=o_vfrac(11 DOWNTO 12-FRAC);

			o_v_poly_use_adaptive <= to_std_logic((o_vmode(2 DOWNTO 0)/="000") AND (o_v_poly_adaptive = '1'));
			o_h_poly_use_adaptive <= to_std_logic((o_hmode(2 DOWNTO 0)/="000") AND (o_h_poly_adaptive = '1'));
			o_v_poly_addr<=to_integer(o_vfrac(11 DOWNTO 12-FRAC));

			-- C3 / HC3 / VC4
			IF o_vmode(2 DOWNTO 0)/="000" THEN
				o_v_poly_phase_a<=poly_unpack(o_v_poly_mem(o_v_poly_addr));
			ELSE
				o_v_poly_phase_a<=poly_nn(vfrac_v);
			END IF;

			IF o_hmode(2 DOWNTO 0)/="000" THEN
				o_h_poly_phase_a<=poly_unpack(o_h_poly_mem(to_integer(hfrac3_v)));
			ELSE
				o_h_poly_phase_a<=poly_nn(hfrac3_v);
			END IF;

			IF o_v_poly_use_adaptive='1' THEN
				o_poly_lum<=poly_lum(o_v_lum_pix);
				o_a_poly_addr<=o_v_poly_addr;
			ELSIF o_h_poly_use_adaptive='1' THEN
				o_poly_lum<=poly_lum(o_h_lum_pix);
				o_a_poly_addr<=to_integer(hfrac3_v);
			END IF;

			-- C4 / HC4 / VC5
			o_poly_phase_b<=poly_unpack(o_a_poly_mem(o_a_poly_addr));

			IF o_v_poly_use_adaptive='1' THEN
				o_poly_phase_a<=o_v_poly_phase_a;
			ELSIF o_h_poly_use_adaptive = '1' THEN
				o_poly_phase_a<=o_h_poly_phase_a;
			END IF;

			o_h_poly_phase_a2<=o_h_poly_phase_a;
			o_v_poly_phase_a2<=o_v_poly_phase_a;
			o_poly_lum1<=o_poly_lum;

			-- C5 / HC5 / VC6
			o_poly_lerp_ta<=signed(to_unsigned(256,10) - resize(o_poly_lum1,10));
			o_poly_lerp_tb<=signed(resize(o_poly_lum1,10));

			o_poly_phase_b2<=o_poly_phase_b;
			o_poly_phase_a2<=o_poly_phase_a;

			o_h_poly_phase_a3<=o_h_poly_phase_a2;
			o_v_poly_phase_a3<=o_v_poly_phase_a2;

			-- C6 / HC6 / VC7
			o_poly_phase<=poly_lerp(o_poly_phase_a2, o_poly_phase_b2, o_poly_lerp_ta, o_poly_lerp_tb);
			o_h_poly_phase_a4<=o_h_poly_phase_a3;
			o_v_poly_phase_a4<=o_v_poly_phase_a3;

			-- C7 / HC7 / VC8
			o_h_poly_phase_a5<=o_h_poly_phase_a4;
			o_v_poly_phase_a5<=o_v_poly_phase_a4;
			o_poly_phase1<=o_poly_phase;

			-- C8 / HC8 / VC9
			o_v_poly_phase<=poly_cvt(o_v_poly_phase_a5);
			o_h_poly_phase<=poly_cvt(o_h_poly_phase_a5);

			IF o_v_poly_use_adaptive = '1' THEN
				o_v_poly_phase<=o_poly_phase1;
			ELSIF o_h_poly_use_adaptive = '1' THEN
				o_h_poly_phase<=o_poly_phase1;
			END IF;

		END IF;
	END PROCESS PolyFetch;


	-- Framebuffer palette
	GenPal1:IF PALETTE GENERATE
		Tempera1:PROCESS(pal1_clk) IS
		BEGIN
			IF rising_edge(pal1_clk) THEN
				IF pal1_wr='1' THEN
					pal1_mem(to_integer(pal1_a))<=pal1_dw;
				END IF;
				pal1_dr<=pal1_mem(to_integer(pal1_a));
			END IF;
		END PROCESS;

		pal_idx <= shift_opack(o_acpt4,o_shift,o_dr,o_format)(0 TO 7);
		pal_idx_lsb <= pal_idx(0) WHEN rising_edge(o_clk);
		o_fb_pal_dr_x2 <= pal1_mem(to_integer(pal_idx(7 DOWNTO 1))) WHEN rising_edge(o_clk);
	END GENERATE GenPal1;

	GenPal2:IF PALETTE and PALETTE2 GENERATE
		Tempera2:PROCESS(pal2_clk) IS
		BEGIN
			IF rising_edge(pal2_clk) THEN
				IF pal2_wr='1' THEN
					pal2_mem(to_integer(pal2_a))<=pal2_dw;
				END IF;
				pal2_dr<=pal2_mem(to_integer(pal2_a));
			END IF;
		END PROCESS;

		o_fb_pal_dr2 <= pal2_mem(to_integer(pal_idx(7 DOWNTO 0))) WHEN rising_edge(o_clk);
		o_fb_pal_dr <= o_fb_pal_dr2 when pal_n = '1' else o_fb_pal_dr_x2(47 DOWNTO 24) WHEN pal_idx_lsb = '1' ELSE o_fb_pal_dr_x2(23 DOWNTO 0);
	END GENERATE GenPal2;

	GenPal1not2:IF PALETTE and not PALETTE2 GENERATE
		o_fb_pal_dr <= o_fb_pal_dr_x2(47 DOWNTO 24) WHEN pal_idx_lsb = '1' ELSE o_fb_pal_dr_x2(23 DOWNTO 0);
	END GENERATE GenPal1not2;

	GenNoPal:IF NOT PALETTE GENERATE
		o_fb_pal_dr<=x"000000";
	END GENERATE GenNoPal;

	-----------------------------------------------------------------------------
	-- Polyphase ROMs
	Polikarpov:PROCESS(poly_clk) IS
	BEGIN
		IF rising_edge(poly_clk) THEN
			IF poly_wr='1' THEN
				poly_tdw(9+10*(3-to_integer(poly_a(1 DOWNTO 0))) DOWNTO
									 10*(3-to_integer(poly_a(1 DOWNTO 0))))<=poly_dw;
			END IF;

			poly_wr_mode(0)<=poly_wr AND NOT poly_a(FRAC+2);
			poly_wr_mode(1)<=poly_wr AND poly_a(FRAC+2);
			poly_wr_mode(2)<=poly_wr AND poly_a(FRAC+3) AND to_std_logic(ADAPTIVE);
			poly_a2<=poly_a(FRAC+1 DOWNTO 2);

			CASE poly_wr_mode IS
				WHEN "001" => -- horiz
					o_h_poly_mem(to_integer(poly_a2))<=poly_tdw;
					o_h_poly_adaptive<='0';
				WHEN "010" => -- vert
					o_v_poly_mem(to_integer(poly_a2))<=poly_tdw;
					o_v_poly_adaptive<='0';
				WHEN "101" => -- horiz adaptive
					o_a_poly_mem(to_integer(poly_a2))<=poly_tdw;
					o_h_poly_adaptive<='1';
				WHEN "110" => -- vert adaptive
					o_a_poly_mem(to_integer(poly_a2))<=poly_tdw;
					o_v_poly_adaptive<='1';
				WHEN OTHERS => NULL;
			END CASE;
		END IF;
	END PROCESS Polikarpov;

	-----------------------------------------------------------------------------
	-- Horizontal Scaler
	HSCAL:PROCESS(o_clk) IS
		VARIABLE div_v : unsigned(20 DOWNTO 0);
		VARIABLE dir_v : unsigned(11 DOWNTO 0);
	BEGIN
		IF rising_edge(o_clk) THEN
			-- Pipeline signals
			-----------------------------------
			-- Pipelined 8 bits non-restoring divider. Cycle 1
			dir_v:=x"000";
			div_v:=to_unsigned(o_hacc * 256,21);

			div_v:=div_v-to_unsigned(o_hsize*256,21);
			dir_v(11):=NOT div_v(20);
			IF div_v(20)='0' THEN
				div_v:=div_v-to_unsigned(o_hsize*128,21);
			ELSE
				div_v:=div_v+to_unsigned(o_hsize*128,21);
			END IF;
			dir_v(10):=NOT div_v(20);

			o_div(0)<=div_v;
			o_dir(0)<=dir_v;

			-- Cycle 2
			div_v:=o_div(0);
			dir_v:=o_dir(0);
			IF div_v(20)='0' THEN
				div_v:=div_v-to_unsigned(o_hsize*64,21);
			ELSE
				div_v:=div_v+to_unsigned(o_hsize*64,21);
			END IF;
			dir_v( 9):=NOT div_v(20);

			IF div_v(20)='0' THEN
				div_v:=div_v-to_unsigned(o_hsize*32,21);
			ELSE
				div_v:=div_v+to_unsigned(o_hsize*32,21);
			END IF;
			dir_v( 8):=NOT div_v(20);

			o_div(1)<=div_v;
			o_dir(1)<=dir_v;

			-- Cycle 3
			div_v:=o_div(1);
			dir_v:=o_dir(1);
			IF FRAC>4 THEN
				IF div_v(20)='0' THEN
					div_v:=div_v-to_unsigned(o_hsize*16,21);
				ELSE
					div_v:=div_v+to_unsigned(o_hsize*16,21);
				END IF;
				dir_v(7):=NOT div_v(20);

				IF div_v(20)='0' THEN
					div_v:=div_v-to_unsigned(o_hsize*8,21);
				ELSE
					div_v:=div_v+to_unsigned(o_hsize*8,21);
				END IF;
				dir_v(6):=NOT div_v(20);
			END IF;
			o_div(2)<=div_v;
			o_dir(2)<=dir_v;

			div_v:=o_div(2);
			dir_v:=o_dir(2);
			IF FRAC>6 THEN
				IF div_v(20)='0' THEN
					div_v:=div_v-to_unsigned(o_hsize*4,21);
				ELSE
					div_v:=div_v+to_unsigned(o_hsize*4,21);
				END IF;
				dir_v(5):=NOT div_v(20);

				IF div_v(20)='0' THEN
					div_v:=div_v-to_unsigned(o_hsize*2,21);
				ELSE
					div_v:=div_v+to_unsigned(o_hsize*2,21);
				END IF;
				dir_v(4):=NOT div_v(20);
			END IF;

			-----------------------------------
			o_hfrac(1)<=dir_v;
			o_hfrac(2 TO 9) <= o_hfrac(1 TO 8);

			o_copyv(1 TO 14)<=o_copyv(0 TO 13);
			o_dcptv_clr(1 TO 12)<=o_dcpt_clr & o_dcptv_clr(1 TO 11);
			o_dcptv_inc(1 TO 12)<=o_dcpt_inc & o_dcptv_inc(1 TO 11);

			IF o_dcptv_clr(12)='1' THEN
				o_dcptv(13) <= 0;
			ELSIF o_dcptv_inc(12)='1' THEN
				o_dcptv(13) <= (o_dcptv(13) + 1) MOD OHRESH;
			END IF;
			o_dcptv(14)<=o_dcptv(13);

			IF o_dcptv(13)>=o_hsize THEN
				o_copyv(14)<='0';
			END IF;

			-- C2
			o_hpixq(2)<=(o_hpix3,o_hpix2,o_hpix1,o_hpix0);
			o_hpixq(3 TO 8)<=o_hpixq(2 TO 7);

			-- BILINEAR / SHARP BILINEAR ---------------
			-- C7 : Pre-calc Sharp Bilinear
			o_h_sbil_t<=sbil_frac1(o_hfrac(6));

			-- C8 : Select
			o_h_bil_frac<=(OTHERS =>'0');
			IF o_hmode(0)='1' THEN -- Bilinear
				IF MASK(MASK_BILINEAR)='1' THEN
					o_h_bil_frac<=bil_frac(o_hfrac(7));
				END IF;
			ELSE -- Sharp Bilinear
				IF MASK(MASK_SHARP_BILINEAR)='1' THEN
					o_h_bil_frac<=sbil_frac2(o_hfrac(7),o_h_sbil_t);
				END IF;
			END IF;

			-- C9 : Opposite frac
			o_h_bil_t<=bil_calc(o_h_bil_frac,o_hpixq(8));

			-- C10 : Bilinear / Sharp Bilinear
			o_h_bil_pix.r<=bound(o_h_bil_t.r,8+FRAC);
			o_h_bil_pix.g<=bound(o_h_bil_t.g,8+FRAC);
			o_h_bil_pix.b<=bound(o_h_bil_t.b,8+FRAC);

			-- BICUBIC -------------------------------------------
			-- C8 : Bicubic coefficients A,B,C,D
			-- C8 : Bicubic calc T1 = X.D + C
			o_h_bic_abcd1<=bic_calc0(o_hfrac(7),o_hpixq(6));
			o_h_bic_tt1<=bic_calc1(o_hfrac(7),
										 bic_calc0(o_hfrac(7),o_hpixq(6)));

			-- C9 : Bicubic calc T2 = X.T1 + B
			o_h_bic_abcd2<=o_h_bic_abcd1;
			o_h_bic_tt2<=bic_calc2(o_hfrac(8),o_h_bic_tt1,o_h_bic_abcd1);

			-- C10 : Bicubic final Y = X.T2 + A
			o_h_bic_pix<=bic_calc3(o_hfrac(9),o_h_bic_tt2,o_h_bic_abcd2);

			-- POLYPHASE -----------------------------------------
			-- C2
			IF o_hfrac(2)(o_hfrac(2)'left)='0' THEN
				o_h_lum_pix<=o_hpix2;
			ELSE
				o_h_lum_pix<=o_hpix1;
			END IF;

			-- C3-C8 in PolyFetch

			-- C9 : Apply Polyphase
			o_h_poly_t<=poly_calc(o_h_poly_phase,o_hpixq(8));

			-- C10 : Sum and bound
			o_h_poly_pix<=poly_final(o_h_poly_t);

			-- C11 : Select interpoler ----------------------------
			o_wadl<=o_dcptv(14);
			o_wr<=o_altx AND (o_copyv(14) & o_copyv(14) & o_copyv(14) & o_copyv(14));
			o_ldw<=(x"00",x"00",x"00");

			CASE o_hmode(2 DOWNTO 0) IS
				WHEN "000"  => -- Nearest
					IF MASK(MASK_NEAREST)='1' THEN
						o_ldw<=o_h_poly_pix;
				 END IF;
				WHEN "001" | "010" => -- Bilinear | Sharp Bilinear
					IF MASK(MASK_BILINEAR)='1' OR
						 MASK(MASK_SHARP_BILINEAR)='1' THEN
						o_ldw<=o_h_bil_pix;
				 END IF;
				WHEN "011" => -- BiCubic
					IF MASK(MASK_BICUBIC)='1' THEN
						o_ldw<=o_h_bic_pix;
					END IF;
				WHEN OTHERS => -- PolyPhase
					IF MASK(MASK_POLY)='1' THEN
						o_ldw<=o_h_poly_pix;
					END IF;
			END CASE;
			------------------------------------------------------
		END IF;
	END PROCESS HSCAL;

	-----------------------------------------------------------------------------
	-- Line buffers 4 x OHRES x (R+G+B)
	OLBUF:PROCESS(o_clk) IS
	BEGIN
		IF rising_edge(o_clk) THEN
			-----------------------------------------------
			-- WRITES
			IF o_wr(0)='1' AND o_wadl < OHRESL  THEN o_line0(o_wadl MOD OHRESL)<=o_ldw; END IF;
			IF o_wr(1)='1' AND o_wadl < OHRESL  THEN o_line1(o_wadl MOD OHRESL)<=o_ldw; END IF;
			IF o_wr(2)='1' AND o_wadl < OHRESL  THEN o_line2(o_wadl MOD OHRESL)<=o_ldw; END IF;
			IF o_wr(3)='1' AND o_wadl < OHRESL  THEN o_line3(o_wadl MOD OHRESL)<=o_ldw; END IF;
			IF OHRES = 2304 OR OHRES = 2560 THEN
				IF o_wr(0)='1' AND o_wadl >= OHRESL THEN o_linf0(o_wadl MOD OHRESM)<=o_ldw; END IF;
				IF o_wr(1)='1' AND o_wadl >= OHRESL THEN o_linf1(o_wadl MOD OHRESM)<=o_ldw; END IF;
				IF o_wr(2)='1' AND o_wadl >= OHRESL THEN o_linf2(o_wadl MOD OHRESM)<=o_ldw; END IF;
				IF o_wr(3)='1' AND o_wadl >= OHRESL THEN o_linf3(o_wadl MOD OHRESM)<=o_ldw; END IF;
			END IF;

			-----------------------------------------------
			-- READS
			o_ldr0<=o_line0(o_radl0 MOD OHRESL);
			o_ldr1<=o_line1(o_radl1 MOD OHRESL);
			o_ldr2<=o_line2(o_radl2 MOD OHRESL);
			o_ldr3<=o_line3(o_radl3 MOD OHRESL);

			IF OHRES = 2304 OR OHRES = 2560 THEN
				o_ler0<=o_linf0(o_radl0 MOD OHRESM);
				o_ler1<=o_linf1(o_radl1 MOD OHRESM);
				o_ler2<=o_linf2(o_radl2 MOD OHRESM);
				o_ler3<=o_linf3(o_radl3 MOD OHRESM);
			END IF;

			o_lex0 <= to_std_logic(o_radl0 >= OHRESL);
			o_lex1 <= to_std_logic(o_radl1 >= OHRESL);
			o_lex2 <= to_std_logic(o_radl2 >= OHRESL);
			o_lex3 <= to_std_logic(o_radl3 >= OHRESL);
			-----------------------------------------------

		END IF;
	END PROCESS OLBUF;

	-----------------------------------------------------------------------------
	-- Output video sweep
	OSWEEP:PROCESS(o_clk) IS
	BEGIN
		IF rising_edge(o_clk) THEN

			IF o_ce='1' THEN
				-- Output pixels count
				IF o_hcpt+1<o_htotal THEN
					o_hcpt<=(o_hcpt+1) MOD 4096;
				ELSE
					o_hcpt<=0;

					IF o_vcpt_sync /= 4095 THEN
						o_vcpt_sync <= o_vcpt_sync+1;
					END IF;

					IF o_vcpt_pre3+1>=o_vtotal THEN
						o_vcpt_pre3<=0;
					ELSIF o_vrr_sync2 THEN
						o_vcpt_pre3<=o_vsstart;
						o_sync<=false;
					ELSE
						o_vcpt_pre3<=(o_vcpt_pre3+1) MOD 4096;
					END IF;

					o_vcpt_pre2<=o_vcpt_pre3;
					o_vcpt_pre<=o_vcpt_pre2;
					o_vcpt<=o_vcpt_pre;
				END IF;

				o_end(0)<=to_std_logic(o_vcpt>=o_vdisp);
				o_dev(0)<=to_std_logic(o_hcpt<o_hdisp AND o_vcpt<o_vdisp);
				o_pev(0)<=to_std_logic(o_hcpt>=o_hmin AND o_hcpt<=o_hmax AND
											  o_vcpt>=o_vmin AND o_vcpt<=o_vmax);
				o_hsv(0)<=to_std_logic(o_hcpt>=o_hsstart AND o_hcpt<o_hsend);
				o_vsv(0)<=to_std_logic((o_vcpt=o_vsstart AND o_hcpt>=o_hsstart) OR
											  (o_vcpt>o_vsstart AND o_vcpt<o_vsend) OR
											  (o_vcpt=o_vsend   AND o_hcpt<o_hsstart));

				o_bzl(0)<=to_std_logic(o_hcpt>=o_hmin-BORDER_H AND o_hcpt<=o_hmax+BORDER_H AND
									   o_vcpt>=o_vmin-BORDER_V AND o_vcpt<=o_vmax+BORDER_V);

				o_vss<=to_std_logic(o_vcpt_pre2>=o_vmin AND o_vcpt_pre2<=o_vmax);
				o_hsv(1 TO 11)<=o_hsv(0 TO 10);
				o_vsv(1 TO 11)<=o_vsv(0 TO 10);
				o_dev(1 TO 11)<=o_dev(0 TO 10);
				o_pev(1 TO 11)<=o_pev(0 TO 10);
				o_bzl(1 TO 11)<=o_bzl(0 TO 10);
				o_end(1 TO 11)<=o_end(0 TO 10);

				IF o_run='0' THEN
					o_hsv(2)<='0';
					o_vsv(2)<='0';
					o_dev(2)<='0';
					o_pev(2)<='0';
					o_bzl(2)<='0';
					o_end(2)<='0';
				END IF;
			END IF;

			o_vcpt_sync2<=o_vcpt_sync;
			o_vrr_min<=(o_vcpt_sync2<o_vtotal);
			o_vrr_min2<=o_vrr_min;
			o_vrr_max<=(o_vcpt_sync2<o_vrrmax);
			o_vrr_max2<=o_vrr_max;

			IF o_isync2='1' THEN
				o_vcpt_sync<=0;
				o_sync_max<=o_vrr_max2;
				IF o_vrr_min2 THEN
					o_sync<=true;
				END iF;
			END IF;

			o_vcpt2<=o_vcpt_pre3;
			o_vrr_sync<=(o_vrr='1' AND (o_sync OR o_sync_max) AND o_vcpt2>=o_vdisp AND o_vcpt2<o_vsstart);
			o_vrr_sync2<=o_vrr_sync;

	 END IF;
	END PROCESS OSWEEP;

	-----------------------------------------------------------------------------
	-- Vertical Scaler
	VSCAL:PROCESS(o_clk) IS
		VARIABLE pixq_v : arr_pix(0 TO 3);
		VARIABLE vlumpix_v : type_pix;
		VARIABLE r1_v, r2_v : natural RANGE 0 TO OHRESH-1;
		VARIABLE fracnn_v : std_logic;
		VARIABLE o_l0_v, o_l1_v, o_l2_v, o_l3_v : type_pix;
	BEGIN
		IF rising_edge(o_clk) THEN
			IF o_ce='1' THEN
				o_v_hmin_adj<=o_hmin + 5;

				fracnn_v := o_vfrac(o_vfrac'left);
				r1_v := (o_hcpt - o_v_hmin_adj + OHRESH) MOD OHRESH;
				r2_v := (o_hcpt - o_hmin       + OHRESH) MOD OHRESH;

				-- CYCLE 1 -----------------------------------------
				-- Read mem
				o_radl0<=r1_v;
				o_radl1<=r1_v;
				o_radl2<=r1_v;
				o_radl3<=r1_v;

				IF fracnn_v = '0' THEN
					CASE o_vacptl IS
						WHEN "10"   => o_radl1<=r2_v;
						WHEN "11"   => o_radl2<=r2_v;
						WHEN "00"   => o_radl3<=r2_v;
						WHEN OTHERS => o_radl0<=r2_v;
					END CASE;
				ELSE
					CASE o_vacptl IS
						WHEN "10"   => o_radl2<=r2_v;
						WHEN "11"   => o_radl3<=r2_v;
						WHEN "00"   => o_radl0<=r2_v;
						WHEN OTHERS => o_radl1<=r2_v;
					END CASE;
				END IF;

				-- CYCLE 2 -----------------------------------------
				-- Lines reordering
				IF o_lex0='0' THEN o_l0_v := o_ldr0; ELSE o_l0_v := o_ler0; END IF;
				IF o_lex1='0' THEN o_l1_v := o_ldr1; ELSE o_l1_v := o_ler1; END IF;
				IF o_lex2='0' THEN o_l2_v := o_ldr2; ELSE o_l2_v := o_ler2; END IF;
				IF o_lex3='0' THEN o_l3_v := o_ldr3; ELSE o_l3_v := o_ler3; END IF;

				CASE o_vacptl IS
					WHEN "10"   => pixq_v:=(o_l0_v,o_l1_v,o_l2_v,o_l3_v);
					WHEN "11"   => pixq_v:=(o_l1_v,o_l2_v,o_l3_v,o_l0_v);
					WHEN "00"   => pixq_v:=(o_l2_v,o_l3_v,o_l0_v,o_l1_v);
					WHEN OTHERS => pixq_v:=(o_l3_v,o_l0_v,o_l1_v,o_l2_v);
				END CASE;

				IF fracnn_v = '0' THEN
					o_vpix_outer<=(pixq_v(0), pixq_v(2), pixq_v(3));
					o_vpix_inner(0)<=pixq_v(1);
				ELSE
					o_vpix_outer<=(pixq_v(0), pixq_v(1), pixq_v(3));
					o_vpix_inner(0)<=pixq_v(2);
				END IF;

				-- CYCLE 3-7
				o_vpix_inner(1 TO 5)<=o_vpix_inner(0 TO 4);

				-- CYCLE 8
				IF to_integer(o_vacpt)>o_ivsize THEN
					IF fracnn_v = '0' THEN
						o_vpixq_pre<=(o_vpix_outer(0), o_vpix_inner(5), o_vpix_inner(5), o_vpix_inner(5));
					ELSE
						o_vpixq_pre<=(o_vpix_outer(0), o_vpix_outer(1), o_vpix_outer(1), o_vpix_outer(1));
					END IF;
				ELSIF to_integer(o_vacpt)=o_ivsize THEN
					IF fracnn_v = '0' THEN
						o_vpixq_pre<=(o_vpix_outer(0), o_vpix_inner(5), o_vpix_outer(1), o_vpix_outer(1));
					ELSE
						o_vpixq_pre<=(o_vpix_outer(0), o_vpix_outer(1), o_vpix_inner(5), o_vpix_inner(5));
					END IF;
				ELSE
					IF fracnn_v = '0' THEN
						o_vpixq_pre<=(o_vpix_outer(0), o_vpix_inner(5), o_vpix_outer(1), o_vpix_outer(2));
					ELSE
						o_vpixq_pre<=(o_vpix_outer(0), o_vpix_outer(1), o_vpix_inner(5), o_vpix_outer(2));
					END IF;
				END IF;

				-- CYCLE 9
				o_vpixq<=o_vpixq_pre;

				-- BILINEAR / SHARP BILINEAR -----------------------
				-- C8 : Pre-calc Sharp Bilinear
				o_v_sbil_t<=sbil_frac1(o_vfrac);

				-- C9 : Select
				o_v_bil_frac<=(OTHERS =>'0');
				IF o_vmode(0)='1' THEN -- Bilinear
					IF MASK(MASK_BILINEAR)='1' THEN
						o_v_bil_frac<=bil_frac(o_vfrac);
					END IF;
				ELSE  -- Sharp Bilinear
					IF MASK(MASK_SHARP_BILINEAR)='1' THEN
						o_v_bil_frac<=sbil_frac2(o_vfrac,o_v_sbil_t);
					END IF;
				END IF;

				-- C10 :
				o_v_bil_t<=bil_calc(o_v_bil_frac,o_vpixq);

				-- C11 : Nearest / Bilinear / Sharp Bilinear
				o_v_bil_pix.r<=bound(o_v_bil_t.r,8+FRAC);
				o_v_bil_pix.g<=bound(o_v_bil_t.g,8+FRAC);
				o_v_bil_pix.b<=bound(o_v_bil_t.b,8+FRAC);

				-- BICUBIC -----------------------------------------
				-- C9 : Bicubic coefficients A,B,C,D
				-- C9 : Bicubic calc T1 = X.D + C
				o_v_bic_abcd1<=bic_calc0(o_vfrac,o_vpixq);
				o_v_bic_tt1<=bic_calc1(o_vfrac,bic_calc0(o_vfrac,o_vpixq));

				-- C10 : Bicubic calc T2 = X.T1 + B
				o_v_bic_abcd2<=o_v_bic_abcd1;
				o_v_bic_tt2<=bic_calc2(o_vfrac,o_v_bic_tt1,o_v_bic_abcd1);

				-- C11 : Bicubic final Y = X.T2 + A
				o_v_bic_pix<=bic_calc3(o_vfrac,o_v_bic_tt2,o_v_bic_abcd2);

				-- POLYPHASE ---------------------------------------
				-- C3 : Setup luminance
				o_v_lum_pix<=o_vpix_inner(0);

				-- C4-C9 in PolyFetch

				-- C10 : Apply polyphase
				o_v_poly_t<=poly_calc(o_v_poly_phase,o_vpixq);

				-- C11 : Bound
				o_v_poly_pix<=poly_final(o_v_poly_t);

				-- CYCLE 12 -----------------------------------------
				o_hs<=o_hsv(11);
				o_vs<=o_vsv(11);
				o_de<=o_dev(11);
				o_vbl<=o_end(11);
				o_r<=x"00";
				o_g<=x"00";
				o_b<=x"00";
				o_brd<= not o_pev(11);

				CASE o_vmode(2 DOWNTO 0) IS
					WHEN "000" => -- Nearest
						IF MASK(MASK_NEAREST)='1' THEN
							o_r<=o_v_poly_pix.r;
							o_g<=o_v_poly_pix.g;
							o_b<=o_v_poly_pix.b;
						END IF;
					WHEN "001" | "010" => -- Bilinear | Sharp Bilinear
						IF MASK(MASK_BILINEAR)='1' OR
							 MASK(MASK_SHARP_BILINEAR)='1' THEN
							o_r<=o_v_bil_pix.r;
							o_g<=o_v_bil_pix.g;
							o_b<=o_v_bil_pix.b;
						END IF;
					WHEN "011" => -- BiCubic
						IF MASK(MASK_BICUBIC)='1' THEN
							o_r<=o_v_bic_pix.r;
							o_g<=o_v_bic_pix.g;
							o_b<=o_v_bic_pix.b;
						END IF;

					WHEN OTHERS => -- Polyphase
						IF MASK(MASK_POLY)='1' THEN
							o_r<=o_v_poly_pix.r;
							o_g<=o_v_poly_pix.g;
							o_b<=o_v_poly_pix.b;
						END IF;
				END CASE;

				IF o_pev(11)='0' THEN
					IF o_bzl(11)='1' AND gun_border_en='1' THEN
						o_r<=x"FF";
						o_g<=x"FF";
						o_b<=x"FF";
					ELSE
						o_r<=o_border(23 DOWNTO 16); -- Copy border colour
						o_g<=o_border(15 DOWNTO 8);
						o_b<=o_border(7  DOWNTO 0);
					END IF;
				END IF;

				----------------------------------------------------
			END IF;
		END IF;
	END PROCESS VSCAL;

	-----------------------------------------------------------------------------
	-- Low Lag syntoniser interface
	o_lltune<=(0 => i_vss,
						 1 => i_pde,
						 2 => i_inter,
						 3 => i_flm,
						 4 => o_vss,
						 5 => i_pce,
						 6 => i_clk,
						 7 => o_clk,
						 OTHERS =>'0');

	----------------------------------------------------------------------------
END ARCHITECTURE rtl;
