# JTFRAME target for ATLAS base board with CYC1000 FGPA 

target by @somhi

### This is an experimental target. Most cores do not work. SDRAM64 controller needs to be modified in order to work.

## Target information

This target is based on [DeMiSTify](https://github.com/robinsonb5/DeMiSTify) firmware by Alastair M. Robinson. DeMiSTify is code to support porting MiST cores to other boards. 

Deca target consists of a Trenz electronic CYC1000 board (Cyclone 10CL025, 8 MB sdram) plus an Atlas base board for retro connectivity

**Base board options**

Edit jtframe_atlas_cyc_top.vhd to select base board options (keyboard, video output).

## Changes needed in jtframe_sdram64_bank.v

**Because of the very low resources of this target (8 MB SDRAM) only a handful of cores are working on it. The cores reported to be working by 06/2023 were:  bubl, dd, dd2, exed, gunsmk, kchamp, kicker, sectnz, trojan, yiear.**  

You need to manually modify the file modules/jtframe/hdl/sdram/jtframe_sdram64_bank.v according to these changes:

```diff
@@ -127 +127
-       addr_row = AW==22 ? addr[AW-1:AW-ROW] : addr[AW-2:AW-1-ROW],
+       addr_row = addr[20:8],
 
@@ -217 +217
-    sdram_a[12:11] =  addr_row[12:11];
-    sdram_a[10:0] = do_act ? addr_row[10:0] :
-            { do_read ? AUTOPRECH[0] : PRECHARGE_ALL[0], addr[AW-1], addr[8:0]};
+    sdram_a[12:0] = do_act ? addr_row :
+            { 2'b00, do_read ? AUTOPRECH[0] : PRECHARGE_ALL[0], 2'b00, addr[7:0]};  
```



## Atlas base board information

* https://github.com/ATLASfpga
* https://github.com/theexperimentgroup/Atlas-FPGA



## CYC1000 board information

Website CYC1000: https://shop.trenz-electronic.de/de/TEI0003-02-CYC1000-mit-Cyclone-10-FPGA-8-MByte-SDRAM

Family: Cyclone 10 LP

Device: 10CL025YU256C8G

Total login elements (LEs): 24624

Total memory (BRAM):  76 kB  (608256 bits) [66 M9k]

Embedded Multiplier 9-bit elements: 132

Total PLLs: 4

UFM blocks: 0

ADC block: 0

| CYC1000 features:                                            |
| ------------------------------------------------------------ |
| HDMI video output                                            |
| 8MB SDRAM                                                    |
| 2MB Flash memory                                             |
| Micro SD card                                                |
| Audio out (jack 3.5)                                         |
| Audio in (jack 3.5)                                          |
| temperature sensor                                           |
| 3-axis accelerometer                                         |
| 1 user button                                                |
| Eight blue user LEDs                                         |
| MKR form factor & PMOD connector                             |
| Arrow USB programmer2 on-board (FT2232H)                     |
| 12 MHz clock & footprint for additional clock                |
|                                                              |
| **ATLAS features:**                                          |
| HDMI (TDMS)                                                  |
| DB9 joystick                                                 |
| PS/2 keyboard & mouse                                        |
| Audio sigma-delta                                            |
| Ear (some atlas versions)                                    |
| uSD / SD card                                                |
| MKR form factor connector (cyc1000, max1000, RPi pico Pi with adaptor, ...) |
| Raspberry Pi 40 pin connector (for multicore)                |
