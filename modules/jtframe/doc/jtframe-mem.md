# Parses the core's YAML file to generate RTL files.

The YAML file name must be mem.yaml and be stored in cores/corename/cfg
The output files are stored in cores/corename/target where target is
one of the names in the $JTFRAME/target folder (mist, mister, etc.).

## Audio Connections

- If both outputs of YM3012 are connected to the same summing net at an opamp input use the resistance value of one of the outputs as rsum.

Example with YM3012 having both channels connected to the summing net via:

- 1kOhm, 33pF parallel, 1kOhm, 4.7uF series, 1.2kOhm

The RC resistors is the parallel of 1k and 1+1.2

``` YAML
- {name: fm,  module: jt51, rsum:  3.2k,  rc: [{ r:  687, c: 33n  }, {r: 1rout, c: 2.2n }] }
```

- If only one output of YM3012 is connected to the summing net, set the pregain to 0.5

``` YAML
- {name: fm,  module: jt51, rsum:  3.2k,  rc: [{ r:  687, c: 33n  }, {r: 1rout, c: 2.2n }], pre: 0.5 }
```


- For K007232, the output of jt007232 can be taken as two separate channels or a mixed one. The mixed one does not attenuate each channel, so it can clip. On the board, each channel will have its own DAC

## mem.yaml Syntax
```
# Include other .yaml files
include:
    - game: cop
    - file: ../../cop/cfg/mem.yaml
# Parameters to be used in the sdram section
params: [ {name:vSCR_OFFSET, value: "32'h10000"}, ... ]
# Map SDRAM addresses during download by
# passing additional ports to the game module
download:
    pre_addr: false   # modify the address value going into the downloader
    post_addr: false  # modify the address value going into the SDRAM
    post_data: false  # modify the data byte going into the SDRAM
    noswab: false     # Reverse all bytes, avoid using it and modify the MRA instead
# Connect addtional output ports from the game module
ports:
    - { name: foo_data, msb: 15, lsb: 0, input:true }
    - { name: foo_cs }
# Instantiates a differente game module
game: othergame

# Generate clock-enable signals
clocks:
  clk48:
    - freq: 24000000
      gate: [main,snd] # stop the cen if main_cs&~main_ok or snd_cs&~snd_ok
      outputs:
        - cen24
        - cen12
    - freq: 3579545
      outputs:
        - cen_fm
        - cen_fm2

# Audio filters and accumulator
audio:
  rsum: 1k
  gain: 2.0   # global gain
  rsum_feedback_res: false # if false, rsum attenuates, if true, rsum gives gain
  mute: true  # add mute signal
  RC: { r: 1k, c: 1n } # global RC filter
  pcb:
    # must match PCB order in TOML file - not automated check yet
    - { rfb: 10k, rsums: [  7.1k, 12.25k ], pres: [ 1.0, 0.19 ] }
    - { rfb: 10k, rsums: [  3.2k, 13.25k ], pres: [ 1.0, 0.19 ] }
    - { rfb: 27k, rsums: [ 12.0k, 12.25k ], pres: [ 1.0, 0.16 ] }
    - { rfb: 27k, rsums: [  4.7k, 12.25k ], pres: [ 1.0, 0.16 ] }
  Channels:
    - Name: psg
      Rsum: 1k
      Rout: 100k
      Pre: 0.5    # pre-amplifier gain
      Vpp: 5      # peak-to-peak amplitude in Volts
      RC:
        - { r: 1k, c: 1n }  # up to two filters
        - ...
      # Fir: myfilter.csv   # use RC or FIR filter
      DCrm: true  # DC offset removal
      stereo: true
      unsigned: false
      data_width: 12
      rc_en: true # add a signal to control the RC filters

# Details about the SDRAM usage
sdram:
  banks:
    - buses: # connections to bank 0
        - name:
          addr_width:
          data_width: # 8, 16 or 32. It will affect the LSB start of addr_width
          cache_size: 4 # default 0, will use the regular jtframe_romrq_bcache
                        # change it to !=0 to use jtframe_romrq_dcache, that will cache
                        # the served data to the game, rather than all the data coming
                        # from SDRAM. This is good when data access is not sequential
          # Optional switches:
          rw: true # normally false
          cs: myown_cs # use a cs signal not based on the bus name
          addr: myown_addr # use a cs signal not based on the bus name
          gfx_sort: hhvvv/hhvvvv/hhvvvvx(x/xx) # moves h bits after v bits
          do_not_erase: true # for rw slots, do not clear upon reset
        - name: another bus...
          when: [ POCKET ]        # use when/unless to set conditions that enabled or disabled the buses
    - buses: # same for bank 1
        - name: another bus...
          unless: [ MISTER ]
    - buses: # same for bank 2
        - name: another bus...
    - buses: # same for bank 3
        - name: another bus...
# BRAM connections
bram:
    - name: vram
      addr_width: 12
      data_width: 8
      rw: true
      [cs:]
      [addr:]
      [din:]
      [sim_file:]
      ioctl:  # optionally dump to RAM file (mainly MiST/SiDi)
        save: true # a dump2bin.sh file will be generated in the sim folder
        restore: true # whether to load it upon core boot
        order: 0   # order in the file
        unless: [ JTFRAME_RELEASE ] # include only for debug builds
        when: [ SIDI ] # include only for sidi builds
      dual_port:
        name: main
        [din:]
        [dout:]
        rw: true
        [cs:]
    # BRAM used as ROM. Note that data gets downloaded
    # to both BRAM and SRAM, but only the BRAM will be read
    - name: mcu_rom
      addr_width: 12
      data_width: 8
      sim_file: required if load is skipped
      rom:
        offset: position in prog_addr*2, with the bank number taking bits 24:23
    # BRAM used as PROM. Data width must be 8 or less
    # Currently only support for a single BRAM PROM is implemented
    - name: mcu
      addr_width: 11
      data_width: 8
      prom: true
```