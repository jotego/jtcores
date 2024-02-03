# Macro Definition

Macros are expected in the file *cores/corename/cfg/macros.def*. From there, other files can be included. The *macros.def* file accepts target-specific macros. Check for examples in JT cores, such as [kicker](https://github.com/jotego/jtkicker).

Macros can also be defined when invoking *jtcore* or *jtframe* command-line tools.

Macros in *macros.def* can have different values for a given target platform, using the following syntax:

```
# defines FOO as 4
FOO=4
[sidi]
# but in the sidi platform, it will become 6
FOO=6
[mist*]
# and in mist/mister platforms, it will be 7
FOO=7
```

The glob matching pattern (using * and ? as in the command line) is supported for target platform name comparisons.

# System Name

There are two macros that define the core name the FPGA will use when communicating with the rest of the target platform. This is the name that MiST(er) display in the side of the OSD menu under some circumstances. It is also the name used for compilation files and the RBF file name. If undefined, the core folder name will be used. CORENAME is a way of using a different name for the core folder and the core itself.

The core's game module that connects to the target top module is set by GAMETOP. If undefined, it will default to $CORENAME_game (or $CORENAME_game_sdram when cfg/mem.yaml exists). $CORENAME is used in lower case for the GAMETOP.

A macro for the core folder name in capitals is always defined and can be used in `ifdef` statements when a file is common to several cores.

Macro         |  Usage                  | Default Value
--------------|-------------------------|------------------
CORENAME      | Core name               | Core's folder name
GAMETOP       | Core's game module name | $CORENAME_game(_sdram)

# Macros for FPGA Synthesis

Macro                    | Target  |  Usage
-------------------------|---------|----------------------
JTFRAME_180SHIFT         | MiSTer  | Use DDIO cell instead of PLL to create the SDRAM phase shift
JTFRAME_4PLAYERS         |         | Extra inputs for 4 players
JTFRAME_ANALOG           |         | Enables analog sticks
JTFRAME_ANALOG_DUAL      |         | Enables second analog stick, requires JTFRAME_ANALOG too
JTFRAME_ARX              | MiSTer  | Defines aspect ratio
JTFRAME_ARY              | MiSTer  | Defines aspect ratio
JTFRAME_AUTOFIRE0        | MiSTer  | Button 0 will autofire when pressed ([OSD](osd.md) option)
JTFRAME_AVATARS          |         | Enables avatars on credits screen
JTFRAME_BUTTONS          |         | Sets the number of action buttons used (2 by default)
JTFRAME_CART_OFFSET      |         | Value added to IOCTL address for the cartridge ROM (consoles)
JTFRAME_CHEAT            |         | Enables the [cheat engine](cheat.md)
JTFRAME_CHEAT_SCRAMBLE   |         | Enables cheat firmware encryption
JTFRAME_CLK24            |         | Adds an additional clock input
JTFRAME_CLK48            |         | Adds an additional clock input
JTFRAME_CLK6             |         | Adds an additional clock input
JTFRAME_CLK96            |         | Adds an additional clock input
JTFRAME_COLORW           |         | Sets the number of bits per color component (default=4)
JTFRAME_DIAL             |         | Adds dial_x and dial_y inputs to game module
JTFRAME_DIALEMU_LEFT     |         | Defaults to 5. Button to use to rotate left. That button+1  for right
JTFRAME_DONTSIM_SCAN2X   |         | Internal. Do not define externally
JTFRAME_FLIP_RESET       |         | Varying the flip DIP setting causes a reset
JTFRAME_FORCED_DIPSW     | Pocket  | Forces a fixed value for the DIP switches
JTFRAME_HEADER           |         | Set to the length of the ROM file header
JTFRAME_HEIGHT           |         | Sets the video height
JTFRAME_INPUT_RECORD     | MiST    | Input data is available as NVRAM. See [debug.md](debug.md)
JTFRAME_INTERLACED       |         | Support for interlaced games
JTFRAME_INTERPOL2        |         | Enables a x2 FIR interpolation filter for audio. The game 'sample' output must be well defined
JTFRAME_IOCTL_RD         |         | Enables saving to SD card via NVRAM interface. Set it to the number of bytes to save on MiST. Any value will work for MiSTer
JTFRAME_JOY_DURL         |         | Joystick lower 4 bits are:  down,  up,    right, left
JTFRAME_JOY_LRUD         |         | Joystick lower 4 bits are:  left,  right, up,    down
JTFRAME_JOY_RLDU         |         | Joystick lower 4 bits are:  right, left,  down,  up
JTFRAME_JOY_UDLR         |         | Joystick lower 4 bits are:  up,    down,  left,  right (default)
JTFRAME_JOY_UDRL         |         | Joystick lower 4 bits are:  up,    down,  right, left
JTFRAME_JOY_B1B0         |         | Swaps the first two buttons
JTFRAME_LF_BUFFER        |         | Enables the line-based frame buffer for objects
JTFRAME_LFBUF_CLR        |         | Sets the line clear value for the frame buffer. 0 by default.
JTFRAME_LITE_KEYBOARD    |         | Disables automatic MAME keys mapping
JTFRAME_LOGO_NOHEX       | Pocket  | Do not display the chip ID on the logo screen
JTFRAME_MCLK             |         | Automatic macro holding the master clock frequency in kHz
JTFRAME_MFREQ            |         | Automatically set to the master clock in kHz. Depends on JTFRAME_PLL
JTFRAME_DIPBASE          | MiST    | Starting base in status word for MiST dip switches. Do not set in [mist] section of macros.def or the MRA will not be correct
JTFRAME_MIST_DIRECT      | MiST    | On by default. Define as 0 to disable. Fast ROM load
JTFRAME_MOUSE            |         | Enables mouse input. See [inputs.md](inputs.md)
JTFRAME_MOUSE_EMUSENS    |         | Positive 9-bit value for the emulated mouse sensitivity. Default value is 9'h10. MSB should be zero
JTFRAME_MOUSE_NO2COMPL   |         | Mouse input is provided as sign+magnitude instead of default 2's complement
JTFRAME_MOUSE_NOEMU      |         | Disables mouse emulation via joystick
JTFRAME_MR_DDR           | MiSTer  | Defined internally. Do not define manually.
JTFRAME_MR_DDRLOAD       | MiSTer  | ROM download process uses the DDR as proxy
JTFRAME_MR_FASTIO        | MiSTer  | 16-bit ROM load in MiSTer. Set by default if CLK96 is set
JTFRAME_NO_DB15          | MiSTer  | Disables DB15 controller modules
JTFRAME_NO_DB15_OSD      | MiSTer  | Disables OSD control via DB15 controller
JTFRAME_NO_MRA_DIP       |         | DIPs are not in an MRA file. Do not call it out from the config string.
JTFRAME_NOSTA            |         | jtcore will not check STA and will produce a PASS regardless of it
JTFRAME_NOHOLDBUS        |         | Reduces bus noise (non-interleaved SDRAM controller)
JTFRAME_NOHQ2X           | MiSTer  | Disables HQ2X filter in MiSTer
JTFRAME_OSD_FLIP         |         | flip option on OSD
JTFRAME_OSD_LOAD         | MiST(er)| load option shown on OSD (off by default on MiSTer)
JTFRAME_OSD_NOCREDITS    |         | No credits option on OSD
JTFRAME_OSD_NOLOGO       |         | Disables the JT logo as OSD background
JTFRAME_OSD_SND_EN       |         | OSD option to enable/disable FX and FM channels
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
JTFRAME_SDRAM_BANKS      |         | Game module ports will support interleaved bank access
JTFRAME_SHADOW           | MiSTer  | Start address for SDRAM shadowing and dump as NVRAM
JTFRAME_SHADOW_LEN       | MiSTer  | Length in bits of the shadowing. See [sdram.md](sdram.md)
JTFRAME_SIGNED_SND       |         | Set to 0 if the game only uses unsigned sound sources
JTFRAME_SKIP             |         | If defined, jtcore will not compile the core and just return a PASS
JTFRAME_STATUS           |         | Game module will receive an 8-bit address and can output 8-bit data in response
JTFRAME_STEREO           |         | Enables stereo sound (snd_left/right outputs from game module instead of single snd)
JTFRAME_SUPPORT_4WAY     |         | Enables support for 4-way joysticks if the MRA sets it
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

# SDRAM64

Macro                    | Target  |  Usage
-------------------------|---------|----------------------
JTFRAME_BAx_AUTOPRECH    |         | Enables auto precharge on bank X (0,1,2,3)
JTFRAME_BAx_LEN          |         | Sets length of bank x, valid values 16, 32 or 64

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
JTFRAME_SIM_DEBUG        |verilator| Assign to debug_bus and then increase each frame. See [debug.md](debug.md)
JTFRAME_SIM_DIPS         |         | DIP switch values for simulation. Use 0x... for verilator sims
JTFRAME_SIM_GFXEN        |         | Sets the gfx_en value (4 bits). See [debug.md](debug.md)
JTFRAME_SIM_LOAD_EXTRA   |         | Extra wait time when transferring ROM in simulation
JTFRAME_SIM_ROMRQ_NOCHECK|         | Disable protocol checking of romrq
JTFRAME_SIM_SCAN2X       |         | Enables scan doubler simulation
JTFRAME_SIM_SLOWLOAD     |verilator| slows down the ROM load in case the core needs extra time
JTFRAME_SIM_VIDEO        |verilator| Create PNG files for all frames. Good for creation of video files.
JTFRAME_SIM_RTC          |         | RTC value at reset, three-byte value: hours-minutes-seconds
JTFRAME_SIM_IODUMP       |verilator| Frame at which an ioctl_ram read is run. Outputs to dump.bin (JTFRAME_IOCTL_RD needed)
LOADROM                  |         | Sends ROM data via serial interface. Set by `jtsim -load`
SIMULATION               |         | Enables simulation features
SIMSCENE                 |         | Set when jtsim is called with -scene
VERILATOR_KEEP_CPU       |verilator| Keeps Z80 signals/M6809 regs during simulation
VERILATOR_KEEP_SDRAM     |verilator| Keeps SDRAM signals in the game_sdram.v module (mem.yaml)
VERILATOR_KEEP_68K       |verilator| Keeps M68000 signals during simulation
VERILATOR_KEEP_VTIMER    |verilator| Keeps jtframe_vtimer signals
VERILATOR_KEEP_SDRAM     |verilator| Keeps all SDRAM related signals
VERILATOR_KEEP_CEN       |verilator| Keeps all the cen signals generated by mem.yaml
VIDEO_START              |         | First frame for which video output is provided use it to prevent a split first frame

# Credits

JTFRAME_CREDITS is always enabled if JTFRAME_CHEAT is defined

Macro                    | Target  |  Usage
-------------------------|---------|---------------------------------------------
JTFRAME_CREDITS          |         | Adds credits screen
JTFRAME_CREDITS_AON      |         | credits screen is always on
JTFRAME_CREDITS_HSTART   |         | Horizontal offset for the 256-pxl wide credits
JTFRAME_CREDITS_PAGES    |         | number of pages of credits text
JTFRAME_CREDITS_NOROTATE |         | Always display the credits horizontally
JTFRAME_CREDITS_HIDEVERT |         | Hide the credits when the core plays a vertical game