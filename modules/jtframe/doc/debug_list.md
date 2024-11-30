# Debug Check List

If a core synthesizes correctly but shows odd behaviour, these are some of the items that may have gone wrong

## Total Failure
- Is the CPU memory size correct? The game may boot with a smaller RAM but fail later on
- Are the clock enable signals applied to the right clock domain? Check the CPU clk/clk_en pair
- Is the port direction correct in all modules? Quartus will fail to drive signals that are defined in all modules as inputs
- Are level interrupts held long enough?
- Strobe signals from one clock domain to another, or one cen-domain to another must use jtframe strobe synchronizers
- Is the frame interrupt getting to the CPU?
- Try disabling cycle recovery in the CPUs

## Video Artefacts
- The shifted screen counter should keep the right sequence around LVBL/LHBL transitions
- Flipped counters are discontinuous around blanking edges

## Wrong Colours
- Is JTFRAME_COLORW correct?
- Is the bit plane order correct?
- If a color PROM is used, the bit plane order must be set right at the input
- Is the right part of the palette selected?

## Sound Problems
- Are interrupts coming correctly to the CPU?
- If unsigned and signed output modules are used for sound, the unsigned ones must be converted to signed using *jtframe_dcrm*

# CPU Debugging

The `jtutil vcd` utility can compare MAME trace files with simulation VCDs. But step comparison with MAME is hard because of interrupts happening at different times and the number of stack pointer transitions during in and out of the interrupt service. Workarounds:

1. Disable interrupts. If the CPU error may still arise if CPUs are disabled.
2. Locate the interrupt wait loop. Replace the last branch instruction for a halt/sync (wait for interrupt) and then a branch. This may still not work if the program does not get to the wait loop in busy frames. It will still be useful in situations where the CPU makes a count down for an interrupt, like the ADC interrupt in NeoGeo Pocket.
3. Create a new CPU instruction both on MAME and FPGA that does a BRANCH and a software interrupt. This will replace the original branch. Disable external interrupts. Now the software will self-interrupt ones all the between-frame calculations are completed. This should perfectly match the emulated and simulated CPUs.

# New Core Check List

This text can be used in GitHub to generate a check list to use during code development

## Beta core development

**Ground Work**
- [ ] Schematics
- [ ] Hardware dependencies
- [ ] SDRAM mapping (mame2mra.toml and mem.yaml)
- [ ] Audio information in mem.yaml
**RTL**
- [ ] Logic connected
- [ ] Tilemap logic
- [ ] Sprite logic
- [ ] Color mixer
- [ ] Graphics are correct
- [ ] Top level simulation hooked up correctly
- [ ] Simulation starts up correctly
- [ ] Music sounds
- [ ] No sound clipping
- [ ] Synthesis ok
- [ ] DIP switches work
- [ ] Playable
**Final Verification**
- [ ] Button names in mame2mra.toml
- [ ] Add Patreon message
- [ ] Update README file
- [ ] Check MiSTer
- [ ] Check Pocket
- [ ] Write Patreon entry

## Beta core publishing

**JTBIN checks**
- [ ] No files for non-beta RBF in JTBIN
- [ ] JTBIN has been comitted and pushed
- [ ] Run update_all and check the files
- [ ] Files in Patreon
**After publishing**
- [ ] Tweet about the beta

## Public release

- [ ] Remove jtbeta.zip from MRAs
- [ ] Recompile MiSTer without beta
- [ ] Recompile Sockit without beta
- [ ] Copy minor platforms to JTBIN
- [ ] Copy Pocket files to JTBIN
- [ ] Push branch to GitHub, if a local remote was used
- [ ] Make source code repository public, if it was private
**Unsupported games**
- [ ] mame2mra.toml discards unsupported games
- [ ] No MRA/JSON files for unsupported games in any repository
- [ ] issue in main repository listing unsupported games as possible _new cores_
