# JTFRAME target for DECA board + [Deca Retro Cape 2](https://github.com/somhi/DECA_retro_cape_2) 

target by @somhi

## Target information

This target is based on [DeMiSTify](https://github.com/robinsonb5/DeMiSTify) firmware by Alastair M. Robinson. DeMiSTify is code to support porting MiST cores to other boards. 

Deca target consists of a Terasic/Arrow DECA board plus a Deca Retro Cape 2 addon for VGA/PS2/DB9/User IO connectors. It also requires an external SDRAM module.

### DECA board information

Website: https://github.com/DECAfpga/DECA_board

Family: MAX 10

Device: 10M50DAF484C6GES

Total login elements (LEs): 49760

Total memory (BRAM): 209.6 kB  (1,677,312 bits)   [182 M9k]

Embedded Multiplier 9-bit elements: 288

Total PLLs: 4

UFM blocks: 1

ADC block: 2

| DECA features:                                    |
| ------------------------------------------------- |
| HDMI video output                                 |
| 512MB DDR3 SDRAM                                  |
| 64MB QSPI Flash                                   |
| USB for peripherals                               |
| 10/100 Mbps Ethernet PHY                          |
| micro SD card                                     |
| Audio out (jack 3.5)                              |
| Audio in (jack 3.5)                               |
| MIPI connector for camera                         |
| 2 ADC SMA inputs                                  |
| proximity/ambient light sensor                    |
| humidity and temperature sensor                   |
| temperature sensor                                |
| accelerometer                                     |
| 2 CapSense buttons                                |
| 2 push-buttons, 2 slide switches                  |
| Eight blue user LEDs                              |
| Beaglebone connectors (GPIO/Analog) (69/76 GPIOS) |
| Arrow USB programmer2 on-board                    |
| 50 MHz clock x 2 & 10 MHz clock                   |



### **Additional hardware required**

- [Deca Retro Cape 2](https://github.com/somhi/DECA_retro_cape_2) addon. Otherwise, see pinout below to connect everything through GPIOs.

- SDRAM module. 

  - Tested with a [dual memory module v1.3](https://github.com/DECAfpga/sdram_sram_v1.3_mister) with 3 extra pins

  * **In order to work with newer MiSTer sdram modules** (those without the DQM extra pins) you need to manually modify the file modules/jtframe/hdl/sdram/jtframe_sdram64,v according to these changes:


```diff
@@ -159,7 +159,7 @@ 
-assign {sdram_dqmh, sdram_dqml} = MISTER ? sdram_a[12:11] : dqm;
+assign {sdram_dqmh, sdram_dqml} = sdram_a[12:11];
@@ -227,15 +227,15 @@ 
-    if( MISTER ) begin
+//    if( MISTER ) begin
         if( next_cmd==CMD_ACTIVE )
             sdram_a[12:11] <= next_a[12:11];
         else
             sdram_a[12:11] <= wr_cycle ? mask_mux : 2'd0;
-    end else begin
-        sdram_a[12:11] <= next_a[12:11];
-        dqm <= wr_cycle ? mask_mux : 2'd0;
-    end
+//    end else begin
+//        sdram_a[12:11] <= next_a[12:11];
+//        dqm <= wr_cycle ? mask_mux : 2'd0;
+//    end
```




### Pinout connections

![pinout_deca](https://github.com/DECAfpga/DECA_board/raw/main/Deca_pinout/DECA-vector-Cores-v1.2/pinout_deca.png)



## Resources

* https://github.com/DECAfpga
* https://github.com/robinsonb5/DeMiSTify
