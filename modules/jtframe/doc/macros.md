# System Name

Macro         |  Usage                  | Default Value
--------------|-------------------------|------------------
CORENAME      | Core name               | Core's folder name
GAMETOP       | Core's game module name | $CORENAME_game(_sdram)

# Macros for FPGA Synthesis

Macro                    | Target  |  Usage
-------------------------|---------|----------------------
JTFRAME_180SHIFT         | MiSTer  | Use DDIO cell instead of PLL to create the SDRAM phase shift
JTFRAME_ARX              | MiSTer  | Defines aspect ratio (default is 4)
JTFRAME_ARY              | MiSTer  | Defines aspect ratio (default is 3)
JTFRAME_AVATARS          |         | Enables avatars on credits screen
JTFRAME_BUTTONS          |         | Sets the number of action buttons used (2 by default)
JTFRAME_CART_OFFSET      |         | Value added to IOCTL address for the cartridge ROM (consoles)
JTFRAME_CHEAT            |         | Enables the [cheat engine](cheat.md)
JTFRAME_CHEAT_SCRAMBLE   |         | Enables cheat firmware encryption
JTFRAME_CLK24            |         | Adds an additional clock input
JTFRAME_CLK48            |         | Adds an additional clock input
JTFRAME_COLORW           |         | Sets the number of bits per color component (default=4)
JTFRAME_DEBUG_VPOS       |         | Row (from the bottom) at which debug information is shown (default=4)
JTFRAME_DIAL             |         | Adds dial_x and dial_y inputs to game module
JTFRAME_DIALEMU_LEFT     |         | Defaults to 5. Button to use to rotate left. That button+1  for right
JTFRAME_FLIP_RESET       |         | Varying the flip DIP setting causes a reset
JTFRAME_FORCED_DIPSW     | Pocket  | Forces a fixed value for the DIP switches
JTFRAME_FEEDTHRU         | MiST    | Bypasses video blending hardware. Saves some logic elements
JTFRAME_HEADER           |         | Set to the length of the ROM file header (derived from TOML)
JTFRAME_HEIGHT           |         | Sets the video height
JTFRAME_INPUT_RECORD     | MiST    | Input data is available as NVRAM. Do not define it in the command line, use macros.def. See [debug.md](debug.md)
JTFRAME_INTERLACED       |         | Support for interlaced games
JTFRAME_IOCTL_RD         |         | Enables saving to SD card via NVRAM interface. Set it to the number of bytes to save on MiST. Any value will work for MiSTer
JTFRAME_JOY_DURL         |         | Joystick lower 4 bits are:  down,  up,    right, left
JTFRAME_JOY_DULR         |         | Joystick lower 4 bits are:  down,  up,    left,  right
JTFRAME_JOY_LRUD         |         | Joystick lower 4 bits are:  left,  right, up,    down
JTFRAME_JOY_RLDU         |         | Joystick lower 4 bits are:  right, left,  down,  up
JTFRAME_JOY_UDLR         |         | Joystick lower 4 bits are:  up,    down,  left,  right (default)
JTFRAME_JOY_UDRL         |         | Joystick lower 4 bits are:  up,    down,  right, left
JTFRAME_JOY_B1B0         |         | Swaps the first two buttons
JTFRAME_LIGHTGUN         |         | Enables the crosshair overlay
JTFRAME_LIGHTGUN_ON      |         | Used with JTFRAME_LIGHTGUN, forces crosshair overlay onscreen
JTFRAME_LIGHTGUN_XOFFSET |         | Used with JTFRAME_LIGHTGUN, adds a 9 bit correction value to lightgun X coordinate sent to core
JTFRAME_LIGHTGUN_YOFFSET |         | Used with JTFRAME_LIGHTGUN, adds a 9 bit correction value to lightgun Y coordinate sent to core
JTFRAME_LF_BUFFER        |         | Enables the line-based frame buffer for objects
JTFRAME_LFBUF_CLR        |         | Sets the line clear value for the frame buffer. 0 by default.
JTFRAME_LF_SDRAM_BUFFER  | sidi128 | The line-based frame buffer (JTFRAME_LF_BUFFER) is implemented in the second SDRAM
JTFRAME_LITE_KEYBOARD    |         | Disables automatic MAME keys mapping
JTFRAME_LOGO_NOHEX       | Pocket  | Do not display the chip ID on the logo screen
JTFRAME_DIPBASE          | MiST    | Starting base in status word for MiST dip switches. Do not set in [mist] section of macros.def or the MRA will not be correct
JTFRAME_MIST_DIRECT      | MiST    | On by default. Define as 0 to disable. Fast ROM load
JTFRAME_MIST_DSP_BLOCKS  | MiST    | Use regular logic to implement DSP blocks if needed
JTFRAME_MOUSE            |         | Enables mouse input. See [inputs.md](inputs.md)
JTFRAME_MOUSE_EMUSENS    |         | Positive 9-bit value for the emulated mouse sensitivity. Default value is 9'h10. MSB should be zero
JTFRAME_MOUSE_NO2COMPL   |         | Mouse input is provided as sign+magnitude instead of default 2's complement
JTFRAME_MOUSE_NOEMU      |         | Disables mouse emulation via joystick
JTFRAME_MR_DDR           | MiSTer  | Defined internally. Do not define manually.
JTFRAME_MR_DDRLOAD       | MiSTer  | ROM download process uses the DDR as proxy
JTFRAME_MR_FASTIO        | MiSTer  | 16-bit ROM load in MiSTer. Set by default if CLK96 is set
JTFRAME_NO_DB15          | MiSTer  | Disables DB15 controller modules
JTFRAME_NOSTA            |         | jtcore will not check STA and will produce a PASS regardless of it
JTFRAME_NOHOLDBUS        |         | Reduces bus noise (non-interleaved SDRAM controller)
JTFRAME_NOHQ2X           | MiSTer  | Disables HQ2X filter in MiSTer
JTFRAME_OSD_FLIP         |         | flip option on OSD
JTFRAME_OSD_LOAD         | MiST(er)| load option shown on OSD (off by default on MiSTer)
JTFRAME_OSD_NOCREDITS    |         | No credits option on OSD
JTFRAME_OSD_NOLOGO       |         | Disables the JT logo as OSD background
JTFRAME_OSD_TEST         |         | Test option on OSD
JTFRAME_OSD_VOL          |         | Show FX volume control on OSD
JTFRAME_OSDCOLOR         |         | Sets the OSD colour. Use 0x30 for red.
JTFRAME_PADDLE           |         | Enables paddle inputs to the game module
JTFRAME_PADDLE_MAX       |         | Maximum paddle value used by jtframe_paddle (mouse-to-paddle emulation)
JTFRAME_PLL              |         | PLL module name to be used. PLL names must end in the pixel clock frequency in kHz
JTFRAME_PXLCLK           |         | 6 or 8. Defines de pixel clock. See [clocks](clocks.md)
JTFRAME_RELEASE          |         | Disables debug control via keyboard
JTFRAME_ROTATE           |         | Enables more rotate options in the OSD
JTFRAME_SCAN2X_NOBLEND   | MiST    | Disables pixel blending
JTFRAME_SDRAM96          |         | SDRAM is clocked at 96MHz and the clk input of game is 96MHz
JTFRAME_SHADOW           | MiSTer  | Start address for SDRAM shadowing and dump as NVRAM
JTFRAME_SHADOW_LEN       | MiSTer  | Length in bits of the shadowing. See [sdram.md](sdram.md)
JTFRAME_SHIFT            |         | Set to 1 if the SDRAM clock phase has a large positive shift
JTFRAME_SIGNED_SND       |         | Set to 0 if the game only uses unsigned sound sources
JTFRAME_SKIP             |         | If defined, jtcore will not compile the core and just return a PASS
JTFRAME_SND48K           |         | Enables a stereo 20kHz filter, 2kHz pass-band. Core's sample signal must be 48kHz and clk_sys=48MHz!
JTFRAME_STATUS           |         | Game module will receive an 8-bit address and can output 8-bit data in response
JTFRAME_STEREO           |         | Enables stereo sound (snd_left/right outputs from game module instead of single snd)
JTFRAME_UART             |         | Connects the UART pins to the game module (see [inputs.md](inputs.md))
JTFRAME_VERTICAL         |         | Enables support for vertical games
JTFRAME_WIDTH            |         | Sets the video width

# Core-specific OSD Items

Macro                    | Target  |  Usage
-------------------------|---------|----------------------
CORE_OSD                 |         | Adds an option to the OSD

Example from the JTCPS core:

`CORE_OSD=O5,Turbo,Off,On;`

Follow the character coding documented in [osd.md](osd.md)


# Device Selection

The wrappers jtframe_m68k and jtframe_z80 offer an uniform interface for
different underlying modules.

Macro                    | Target  |  Usage
-------------------------|---------|----------------------
JTFRAME_J68              |         | Selects J68_CPU as M68000 module (default fx68k)

# SDRAM Banks

Macro                    | Target  |  Usage
-------------------------|---------|----------------------
JTFRAME_BA1_START        |         | Start of bank 1
JTFRAME_BA2_START        |         | Start of bank 2
JTFRAME_BA3_START        |         | Start of bank 3
JTFRAME_BA1_WEN          |         | Enables writting on bank 1
JTFRAME_BA2_WEN          |         | Enables writting on bank 2
JTFRAME_BA3_WEN          |         | Enables writting on bank 3
JTFRAME_PROM_START       |         | PROM signals starts here
JTFRAME_SDRAM_ADQM       | MiSTer  | A12 and A11 are equal to DQMH/L
JTFRAME_SDRAM_BWAIT      |         | Adds a wait cycle in the SDRAM
JTFRAME_SDRAM_CHECK      |         | Double check SDRAM data through modules (slow)
JTFRAME_SDRAM_DEBUG      |         | Outputs debug messages for SDRAM during simulation
JTFRAME_SDRAM_LARGE      | MiSTer  | Enables 64MB access to SDRAM modules
JTFRAME_SDRAM_MUXLATCH   |         | Extra latch for SDRAM mux for <64MHz operation
JTFRAME_SDRAM_NO_DWNRFSH |         | No refresh during download (non-interleaved SDRAM controller)
JTFRAME_SDRAM_REPACK     |         | Extra latch stage at SDRAM mux output

# Clock Frequency Macros

These macros are generated automatically by jtframe.

Macro                    |  Usage
-------------------------|----------------------
JTFRAME_MCLK             | Automatic macro holding the master clock frequency in Hz
JTFRAME_NTSC             | 40-bit phase increment for [MikeS11's YC module](https://github.com/MikeS11/MiSTerFPGA_YC_Encoder?tab=readme-ov-file)
JTFRAME_PAL              | 40-bit phase increment for YC module
JTFRAME_PAL_LEN          | Use as COLORBURST_RANGE for YC module on PAL mode
JTFRAME_NTSC_LEN         | Use as COLORBURST_RANGE for YC module on NTSC mode

# SDRAM64

Macro                    | Target  |  Usage
-------------------------|---------|----------------------
JTFRAME_BA0_AUTOPRECH    |         | Enables auto precharge on bank 0
JTFRAME_BA0_LEN          |         | Sets length of bank 0, valid values 16, 32 or 64
JTFRAME_BA1_AUTOPRECH    |         | Enables auto precharge on bank 1
JTFRAME_BA2_LEN          |         | Sets length of bank 1, valid values 16, 32 or 64
JTFRAME_BA2_AUTOPRECH    |         | Enables auto precharge on bank 2
JTFRAME_BA2_LEN          |         | Sets length of bank 2, valid values 16, 32 or 64
JTFRAME_BA3_AUTOPRECH    |         | Enables auto precharge on bank 3
JTFRAME_BA3_LEN          |         | Sets length of bank 3, valid values 16, 32 or 64

# SDRAM ROM/RAM Modules

Macro                    | Target  |  Usage
-------------------------|---------|----------------------
JTFRAME_SDRAM_TOGGLE     |         | Consider a CS toggle automatically after SDRAM is ready (experimental)

# Simulation-only Macros

The following macros only have an effect if SIMULATION is defined.

Macro                    | Target  |  Usage
-------------------------|---------|---------------------------------------------
DUMP_6809                |         | Generates a m6809.log during simulation with register dumps
DUMP_VIDEO               |         | Enables video dump to a file
DUMP_VIDEO_FNAME         |         | Internal. Do not assign.
JTFRAME_DUAL_RAM_DUMP    |         | Enables dumping of RAM contents in simulation
JTFRAME_SAVESDRAM        |         | Saves SDRAM contents at the end of each frame (slow)
JTFRAME_SDRAM_STATS      |         | Produce SDRAM usage data during simulation
JTFRAME_SIM96            |verilator| Produces the clk96 clock input to the game module when JTFRAME_SDRAM96 is not set
JTFRAME_SIM_CH_RAW       |         | Creates binary files with raw audio data for each channel. Automatically enabled when logic waveforms are dumped.
JTFRAME_SIM_DEBUG        |verilator| Assign to debug_bus and then increase each frame. See [debug.md](debug.md)
JTFRAME_SIM_DIPS         |         | DIP switch values for simulation. Use 0x... for verilator sims
JTFRAME_SIM_GFXEN        |         | Sets the gfx_en value (4 bits). See [debug.md](debug.md)
JTFRAME_SIM_IODUMP       |verilator| Frame at which an ioctl_ram read is run. Outputs to dump.bin (JTFRAME_IOCTL_RD needed)
JTFRAME_SIM_LOAD_EXTRA   |         | Extra wait time when transferring ROM in simulation
JTFRAME_SIM_ROMRQ_NOCHECK|         | Disable protocol checking of romrq
JTFRAME_SIM_RTC          |         | RTC value at reset, three-byte value: hours-minutes-seconds
JTFRAME_SIM_SDRAM_NONSTOP|modelsim | SDRAM model will not stop the simulation for timing violations
JTFRAME_SIM_SLOWLOAD     |verilator| slows down the ROM load in case the core needs extra time
JTFRAME_SIM_SNDEN        |verilator| Enable sound channels (bits active high) following the order in mem.yaml
JTFRAME_SIM_VIDEO        |verilator| Create PNG files for all frames. Good for creation of video files.
LOADROM                  |         | Sends ROM data via serial interface. Set by `jtsim -load`
SIM_LOAD_PROM            |         | Manually enable it to force PROM load on offset-header cores (like JTS18)
SIMSCENE                 |         | Set when jtsim is called with -scene
SIMULATION               |         | Enables simulation features
VERILATOR_KEEP_AUDIO     |verilator| Keeps all the audio mixing generated by mem.yaml
VERILATOR_KEEP_CEN       |verilator| Keeps all the cen signals generated by mem.yaml
VERILATOR_KEEP_CPU       |verilator| Keeps CPU signals (Z80/M6809/M68000) during simulation
VERILATOR_KEEP_SDRAM     |verilator| Keeps SDRAM signals in the game_sdram.v module (mem.yaml)
VERILATOR_KEEP_VTIMER    |verilator| Keeps jtframe_vtimer signals
VIDEO_START              |         | First frame for which video output is provided use it to prevent a split first frame

# Credits

JTFRAME_CREDITS is always enabled if JTFRAME_CHEAT is defined

Macro                    | Target  |  Usage
-------------------------|---------|---------------------------------------------
JTFRAME_CREDITS          |         | Adds credits screen. Automatic for releases if cfg/msg exists
JTFRAME_CREDITS_AON      |         | credits screen is always on
JTFRAME_CREDITS_HIDEVERT |         | Hide the credits when the core plays a vertical game
JTFRAME_CREDITS_HSTART   |         | Horizontal offset for the 256-pxl wide credits
JTFRAME_CREDITS_NOROTATE |         | Always display the credits horizontally
JTFRAME_CREDITS_PAGES    |         | number of pages of credits text (default 3)
