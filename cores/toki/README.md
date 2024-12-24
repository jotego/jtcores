# Toki / JuJu Densetsu for Mister FPGA :

This is a port of [JuJu Densetsu](http://adb.arcadeitalia.net/dettaglio_mame.php?game_name=juju&lang=en) alias Toki, in verilog for [MiSTer FPGA](https://github.com/MiSTer-devel/Main_MiSTer/wiki).

A plateformer arcade game made by [TAD Corporation](https://en.wikipedia.org/wiki/Toki_(video_game)) in 1989 on [Seibu](https://en.wikipedia.org/wiki/Seibu_Kaihatsu) designed hardware.

This core is based mainly on [MAME sources](https://github.com/mamedev/mame), some PCB measurements and ROM reverse-engineering. 


## ROM Files Instructions

ROMs are not included! In order to use this arcade core, you will need to provide the correct ROM file yourself.

To simplify the process .mra files are provided in the releases folder, that specify the required ROMs with their checksums. The ROMs .zip filename refers to the corresponding file from the MAME project.

Please refer to [https://github.com/MiSTer-devel/Main_MiSTer/wiki/Arcade-Roms-and-MRA-files](https://github.com/MiSTer-devel/Main_MiSTer/wiki/Arcade-Roms-and-MRA-files) for information on how to setup and use the environment.

Quick reference for folders and file placement:

```
/_Arcade/<game name>.mra  
/_Arcade/cores/<game rbf>.rbf  
/_Arcade/mame/<mame rom>.zip  
/_Arcade/hbmame/<hbmame rom>.zip  
```


## How to compile :

- This core use [jtrame](https://github.com/jotego/jtcores/) follow jtcores/jtframe installation instruction
- Install Quartus 17.0
- clone this repository inside the jtcores/core directory
- clone [fx68k](https://github.com/JTFPGA/fx68k.git), [jt6295](https://github.com/jotego/jt6295.git) and [jtopl](https://github.com/jotego/jtopl.git) into the jtcores/modules directory
- run :
```
    source setprj
    jtframe cfgstr toki
    jtframe mem toki
    jtframe msg toki
    jtcore -mister toki
``` 

# Author : 

Solal Jacob
