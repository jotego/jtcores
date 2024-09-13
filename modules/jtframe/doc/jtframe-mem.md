# Parses the core's YAML file to generate RTL files.

The YAML file name must be mem.yaml and be stored in cores/corename/cfg
The output files are stored in cores/corename/target where target is
one of the names in the $JTFRAME/target folder (mist, mister, etc.).

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
      outputs:
        - cen24
        - cen12
    - freq: 3579545
      outputs:
        - cen_fm
        - cen_fm2

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
        - name: another bus...
    - buses: # same for bank 1
        - name: another bus...
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
```