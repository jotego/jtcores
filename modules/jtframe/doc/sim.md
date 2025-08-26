# Simulation Setup

JTFrame supports simulation of the target system top level. In the case of verilator sims, only the *jtgame* module is simulated.

The use of YAML files allows for sharing the core file list between different tools, so there is no need to elaborate a different list for simulators. Each JTFRAME target platform also has specific *sim.yaml* files that are taken into account only for simulators.

Some target platforms have a top-level test which can be used and that harness all signals and emulates the ROM transfer protocol. The MiST platform is the most commonly used for simulations and is kept alive. MiSTer is hard to keep working in simulations as many *sys* files developed by the MiSTer team do not work well in simulation and need to be edited. So the MiSTer setup will not normally work without extra effort.

The simulation script [jtsim](../bin/jtsim) supports several simulators and sets up everything. Installing simulators and running a first successful simulation is complicated and the JTFRAME team does not support users through this process. Yet, all the files needed are here, so with some studying anyone can set up a simulation.

# Core and JTFRAME Macros

All macros defined in the core's *cfg/macros.def* file are parsed by *jtsim* and accessible in simulation. The macros are also available to Verilator in the form of C++ macros.

# Cabinet Inputs During Simulation

You can use a hex file with inputs for simulation. Enable this with the macro
SIM_INPUTS. The file must be called sim_inputs.hex. Each line has a hexadecimal
number with inputs coded. Active high only:

bit  | meaning
-----|------------
0    | coin 1
1    | coin 2
2    | 1P start
3    | 2P start
4    | right   (may vary with each game)
5    | left    (may vary with each game)
6    | down    (may vary with each game)
7    | up      (may vary with each game)
8    | Button 1
9    | Button 2
10   | Test button

Each line will be applied on a new frame.

# Fast Load

## MiST
Starting from the Dec. 2020 firmware update, MiST can now delegate the ROM load to the FPGA. This makes the process 4x faster. This option is enabled by default. However, it can be a problem because the ROM transfer will be composed of full SD card sectors so there will be some garbage sent at the end of the ROM. If the core is not compatible with this and it relies on exact sizing of the ROM it needs to define the macro **JTFRAME_MIST_DIRECT** and set it to zero:

```
set_global_assignment -name VERILOG_MACRO "JTFRAME_MIST_DIRECT=0"
```

## MiSTer
In order to preserve the 8-bit ROM download interface with MiST, _jtframe_mister_ presents it too. However it can operate internally with 16-bit packets if the macro **JTFRAME_MR_FASTIO** is set to 1. This has only been tested with 96MHz clock. Indeed, if **JTFRAME_CLK96** is defined and **JTFRAME_MR_FASTIO** is not, then it will be defined to 1.

The measured speed for data transfers in MiSTer is about 1.2MHz (800ns) per request. If **JTFRAME_MR_FASTIO** is set, each request is 16-bit words, otherwise, 8 bits.

# SDRAM Simulation
A model for SDRAM mt48lc16m16a2 is included in JTFRAME. The model will load the contents of the file **sdram.hex** if available at the beginning of simulation.

The current contents of the SDRAM can be dumped at the beginning of each frame (falling edge of vertical blank) if **JTFRAME_SAVESDRAM** is defined. Because this is quite an overhead, it is possible to restrict it to dump only a certain **DUMP_START** frame count has been reached. All frames will be dumped after it. The macro **DUMP_START** is the same one used for setting the start of signal dump to the __VCD__ file.

To simulate the SDRAM load operation use **-load** on sim.sh. The normal download speed 1/270ns=3.7MHz. This is faster than the real systems but speeds up simulation. It is possible to slow it down by adding dead clock cycles to each transfer. The macro **JTFRAME_SIM_LOAD_EXTRA** can be defined with the required number of extra cycles.

## SDRAM Preparation

The core needs to have a SDRAM with the game ROM loaded into it. The most basic way is to have a file named **rom.bin** in the simulation folder. `jtsim -load` will download that file to the core and produce four files called **sdram_bank?.bin** with the SDRAM contents after the download is done.

The ROM download process is slow but normally you only need to run it once to produce the sdram files. After that, calling `jtsim` will load those files directly to the SDRAM simulation model.

`jtsim -setname game` will create the .rom file for the given name in the **$JTROOT/rom** folder and make a symbolic link to it called **rom.bin** in the simulation folder. It will then proceed to load the rom.

As the .rom download can sometimes be very slow and it does not require any core CPU, you can often use `jtsim -load -d NOMAIN -q` in order to simulate without the main and sound CPUs. Somecores will also take `-d NOMCU` to skip the MCU simulation. After creating the sdram files, a regular simulation with CPUs can be executed.

The fastest method to produce the sdram files is to run `jtutil sdram` from the simulation folder. This will work for cores that do not execute data transformations during downloading. It will simply skip the header and use the bank start definitions in **macros.def** to split the .rom file into four sdram files.

## Simulator Speed

Comparison run on [Roc'n Rope](https://github.com/jotego/jtkicker) core for ten frames plus ROM loading.

simulator | vcd/no video | no vcd/video | no vcd/no video
----------|--------------|--------------|-----------------
modelsim  |  17'         |   16'        | 16'
iverilog  |              |              | 15'50"
verilator |  0'30"       |  0'12"       |

Versions used:
* The ModelSim - INTEL FPGA STARTER EDITION vsim 2020.1
* Icarus Verilog 12.0
* Verilator 4.224

The advantage of ModelSim over the other two is mixed VHDL/Verilog simulations.

Verilator simulations do not simulate the *target* but only the game top. SDRAM access is particularly faster in Verilator. Verilator does not simulate 4-state signals either.

## Audio output

By default, all audio output gets dumped to test.wav. If the **Audio** section of the **mem.yaml** file is used, then per-channel audio files can be generated too. In order to enable per-channel files, either request jtsim to dump waveforms `jtsim -w` or use the macro **JTFRAME_SIM_CH_RAW** so produce wave files without dumping logic waveforms.

# Regression

You can execute a regression for each game, using the command `run_regression.sh`. This command will execute a simulation using `jtsim` in a way you define in a configuration file inside `<core>/cfg`, called `reg.yaml`. Here, you can set the same options you can set when using `jtsim`. The syntaxis for that file is as follows:
```yaml
<setname_1>:
    video: number
    inputs: file
    dipsw: binary_number
    d: MACRO
    ...
...
<setname_n>:
    ...
```

Also, there is another `reg.yaml` file on `$JTFRAME/bin`, where you can set default options. The syntaxis is the same as above, but you don't have to specify any setname:
```yaml
video: number
inputs: file
dipsw: binary_number
d: MACRO
...
```

Also this command is ready for check if the simulation performed is valid against another one. To do so, you can use `--check` or `--local-check <folder>` flags, that allows you to compare against a remote folder in a SFTP server, or a local folder within your machine. If you decide to use a SFTP server, you must use `--port <port>`, `--host <host>` and `--user <user>` flags to set the way it has to connect to that server. Also, the server has to be already defined on known_hosts.
If you use a local folder, the frames have to be on a folder called *frames*, and the audio has to be called *audio.wav*. Also, if you don't want to download ROMs from the SFTP server, you have to set `--local-rom` flag, and it will search for ROMs on `~/.mame/roms`.
If you use a remote SFTP server, it expects two folders, called *regression* and *mame*. You have to select the root folder on your server using `--path`. On *mame* it is expected all zips containing ROMs. On *regression*, it is expected the following structure: `regression/<core>/<setname>/VALID,NOT_CHECKED,FAIL/frames.zip,audio.zip`
It will use that files to download and compress/uncompress the needed info for simulating and checking.
Also you can use `--push` flag to upload the simulation results. Depending on the validation result, it will be upload on `fail` or `not_checked` folder. You will always have to manually upload the reference frames/audio to the VALID folder.

This is the script used for automatic regressions triggered by GitHub Actions. It will execute a regression for all setnames that are set on `<core>/reg.yaml` files, using flags `--check` and `--push`. In case there were any problems when executing the regression (simulation failed, unable to get audio/frames, audio/frames validation failed...) An issue will be created on GitHub specifying why the regression failed.
