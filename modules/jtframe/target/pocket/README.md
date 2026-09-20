# Pocket Target for JTFRAME

- Supporter: [Jose Tejada](https://github.com/jotego)
- Funded by [Patreon](https://patreon.com/jotego)

## Memories

- 2 x pseudo SRAM chips, 8 Mbyte each, 16-bit access, 1.8V [datasheet](https://www.alliancememory.com/wp-content/uploads/pdf/psram/AllianceMemory_128M_LP-PSRAM-CellularRAM_x2stack_AS1C8M16PL-70BIN_August2018-v1.0.pdf)
- 1 x SRAM chip, 256 kByte, 16-bit access, 3.3V [datasheet](https://www.alliancememory.com/wp-content/uploads/pdf/lp_sram/AllianceMemory_2M_LPSRAM_AS6C2016%20May%202021_v1.1_May2021.pdf)
- 1 x SDRAM chip, 64 Mbyte, 16-bit access, 1.8V [datasheet](https://www.alliancememory.com/wp-content/uploads/pdf/mobile_sdram/20180115_AllianceMemory_512M_LPSDRAM_AS4C32M16MSA-6BIN(TR)_rev1.0_Dec2017.pdf)

## NVRAM Support

NVRAM will be automatically handled when **JTFRAME_IOCTL_RD** is declared with the size in bytes of the file. The core will receive **ioctl_ram** high and should drive **ioctl_din**. From the core point of view, nothing changes with respect to MiST(er) targets.

Note that the size of the NVRAM slot is fixed at compile time.

# Dedicated Clock Outputs

Neither the SDRAM or the PSRAM chip clocks are connected to dedicated clock pins in the FPGA. The rest of the Pocket system clocks are not connected to FPGA clock pins either.

# PLL Frequencies

Obtaining the direct PLL frequencies needed by cores from 74.25MHz requires these factors:

| pll  | x8    | num   | den   |
|:-----|:------|:------|:------|
| 6000 | 48000 | 24000 | 37125 |
| 6144 | 49152 | 24576 | 37125 |
| 6293 | 50344 | 25172 | 37125 |
| 6671 | 53368 | 26684 | 37125 |

But Cyclone PLLs can only do factors from 1-512, so the factors above would need to be broken in two stages. That is not possible because 6671 is a prime number and it is too large to be done on a single stage. The other three could be done and then accept some error in the final one.

The current solution just reuses the MiST PLL factors after converting the 74.25MHz input clock to 27MHz.

# Using Analogizer with JT cores

[Analogizer](https://github.com/RndMnkIII/Analogizer) is an Analogue Pocket compatible device used to generate different types of Analog Video output, and/or to make possible the use of SNAC controllers. As JT cores are compatible with the use of Analogizer, in order to set your preferred configuration you will need to:

1. Get the [configuration tool](https://github.com/jotego/jtcores/blob/master/modules/jtframe/bin/jt-crtcfg.py).
2. Run in the terminal using `python3 jt-crtcfg.py`
3. A set of video options will appear. Type the letter of your preferred option an press Intro:
![image](https://github.com/user-attachments/assets/8e52301e-2635-4f95-ba61-a23004687219)
4. Options for SNAC controllers will appear. Select your preferred option and press Intro:

     ![image](https://github.com/user-attachments/assets/4b4d5e41-2b3c-4e39-a5ed-cf293abc4efa)    
5. Copy the generated .bin file to the folder `Assets/jtpatreon/common` in your SD card.

Now you should be ready to use Pocket Analogizer!

# Automatic Controller Assignment

As expected, using Analogue Pocket with JT Cores defaults Pocket controllers to player 1. However, if you wanted to add more external controllers (USB/SNAC) it might be confusing to check which controllers is assigned to which player. To solve this, **automatic controller assignment** has been added.

How does it work?

When you start running a game using a JT Core and you connect several controllers to your Pocket, the first one to press the action buttons will be assigned as Player 1, the next one will be Player 2, and so on until Player 4 is selected. Therefore, you won't have to worry about where you connect your controllers!
