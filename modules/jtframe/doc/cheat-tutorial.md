# Cheat Development Tutorial

## Introduction

Arcade cheats are made manipulating either the game ROM or the CPU RAM. The
ROM can be modified statically, with `<patch>` in the MRA file. However, the
game RAM can only be modified when the game is actually running, so you need
a way to access it.

JTFRAME cheat engine provides a way of accessing all the SDRAM information
contained on bank 0. Bank 0 is used as the R/W bank for arcade games in JT
cores. Other SDRAM banks are used as read-only memory. Some JT arcade cores
take advantage of this feature to implement the game RAM and even VRAM directly
on the SDRAM. As of June 2021, these cores are:

* CPS series
* Street Fighter 1
* System 16
* The Speed Rumbler

Older cores may be updated to move the RAM to the SDRAM. Even if the SDRAM
only contains the ROM, the cheat engine can still be used. It just cannot
modify RAM contents.

The cheat engine is built around a small processor called the PicoBlaze. You
will need to write a small piece of code that modifies the game data as needed.

There is plenty of information about cheat code on the internet, including a
wonderful tutorial on how to develop cheat codes [here](http://cheat.retrogames.com/download/holycheat!.zip).

The cheat information is added to the core by enabling it on the MRA file, and
then adding a new PicoBlaze instruction ROM to the MiSTer's cheat.zip. Do not
confuse MiSTer's cheat.zip file with MAME's cheat.zip. They are named the same
but the contents have nothing to do.

This tutorial will show how to modify two games, one for CPS1 and one for CPS2.

You will need the MAME file cheat.zip. Uncompress it to a folder.

## Eco Fighters (CPS2)

Look for the file ecofghtr.xml in your uncompressed cheat.zip. You will see a
list of XML elements like this one:

```
  <cheat desc="Infinite Credits">
    <script state="run">
      <action>maincpu.pb@FF02E8=09</action>
    </script>
  </cheat>
```

This means that once per frame, the CPU RAM mapped at FF02E8 must be set to 9.

The PicoBlaze has the vertical blanking mapped to bit 5 of port $80. In order to
check when blanking has occur there is a small piece of code that you can just
reuse:

```
    load sa,0   ; SA = frame counter, modulo 60
    load sb,0
BEGIN:
    output s0,0x40

    ; Detect blanking
    input s0,0x80
    and   s0,0x20;   test for blanking
    jump z,inblank
    jump notblank
inblank:
    fetch s1,0
    test s1,0x20
    jump z,notblank
    store s0,0  ; stores last LVBL
    call ISR ; do blank procedure
    jump BEGIN
notblank:
    store s0,0
    jump BEGIN
```

The important thing is that register **SA** contains the frame counter, from
0 to 59. If you want to do something once per second, just compare SA to any
number in the 0 to 59 range. SA will pass through that number exactly once per
second.

This code will clean the watchdog too. The watchdog is a hardware counter that
will reset this CPU after a certain time. This is a safety measure. The code
`output s0,0x40` clears the count, so no reset occurs.

When a blanking event happens, the code will jump to **ISR** (Interrupt Service
Response).

The ISR code  starts by checking the cheat flags, which the user has modified
via the MiSTer OSD menu.

```
ISR:
    input sf,0x10
    test sf,0xff
    jump z,.nothing

    compare sa,0
    jump nz,PARSE_FLAGS
    ; invert LED signal
    add sb,1
    jump PARSE_FLAGS
.nothing:
    load sb,0      ; turn off LED
    jump CLOSE_FRAME
```

The flags are read from port $10. If no cheats are enabled (all flags zero),
then the LED is turned off. The LED status is held in register **SB**. If
there are enabled cheats, then the LED will be toggled `add sb,1` and the
code will jump to PARSE_FLAGS.

Parsing the flags consists on checking the relevant bit -as specified in the
MRA file- and then performing the relevant action, which in general will be
a single write to the game RAM.

```
PARSE_FLAGS:
    input sf,0x10
    test  sf,1      ; bit 0
    jump Z,TEST_FLAG1
    ; Infinite Credits
    ; FF02E8=09 -> (02E8/2+30'0000) = 300174
    load  s0,0x74
    load  s1,0x01
    load  s2,0x30
    load  s3,0
    load  s4,9
    load  s5,1
    call  WRITE_SDRAM
TEST_FLAG1:
```

This code checks bit 0, and if set it will write the value 9 to the RAM
address FF02E8. For convenience, there is a function called **WRITE_SDRAM** which
will write the contents of registers **S4-S3** to the memory address set by
registers **S2-S1-S0**. As the memory is made of 16-bit words, the byte that is
being written is set by **S5**, 1 means that the high byte (register **S4**) is
accessed, 2 means the low byte (**S3**) and 0 means both.

Now, in order to convert the system address (FF02E8) to the SDRAM address, you
need to know where the RAM is stored in the SDRAM. This information is typically
in the jtcps1_sdram file of the game, for instance in [CPS.](https://github.com/jotego/jtcps1/blob/d05f18f8981c55ada00e1b3365848cf9ba4486bb/cores/cps1/hdl/jtcps1_sdram.v#L150).

For CPS cores the work RAM is in $30'0000. So this offset must be added to the
game address. But another point is that the top 8 bits of the address are not
part of the data address, but only serve to indicate that the work RAM portion
of the memory mapped is active. This can be seen in the MAME driver or in the
core decoder logic and is different for each system. But for all CPS cores, the
same logic applies. Another caveat is that for 16-bit CPUs, the address must be
divided by 2. So finally the address **FF02E8** becomes **30'0174**.

The code loads that address and the 9 value. Note that in 16-bit systems, the
byte location may be confusing to because of endianness. For M68000 games, just
follow this example.

Once this code is executed, the next flag will be checked, and eventually the
frame processing will get closed with:

```
CLOSE_FRAME:
    output sb,6     ; LED
    ; Frame counter
    add sa,1
    compare sa,59'd
    jump nz,.else
    load sa,0
.else:
    return
```

The closing frame just updates the LED and the frame counter. You can see the
full code of this example [here](cheat/ecofghtr.s).

Now you need to assemble the new file and add it to MiSTer's cheat.zip. The
file [cheatzip](cheat/cheatzip) shows how to do it. Here are the steps as
individual linux commands:

```
> opbasm -6 -x -m 1024 ecofghtr.s
> pico2hex ecofghtr.hex
> zip cheat.zip ecofghtr.bin
> sshpass -p 1 scp cheat.zip root@MiSTer.home:/media/fat/games/mame
```

First, the file is assembled using [opbasm](https://github.com/kevinpt/opbasm).
Then the output is converted to a binary format that MiSTer can handle using
pico2hex (available in JTBIN's bin folder). This utility basically converts
a 18-bit hex stream to a 8-bit one. Finally the binary file is added to
cheat.zip and transferred to MiSTer.

The MRA needs to load this binary to the ROM position 16:

```
    <rom index="16" zip="cheat.zip" md5="None">
        <part name="ecofghtr.bin"/>
    </rom>
```

And of course, it must include descriptions of each cheat:

```
    <cheats>
        <dip name="Infinite Credits" bits="0" ids="No,Yes"/>
        <dip name="P1 Infinite Lives" bits="1" ids="No,Yes"/>
        <dip name="P1 Invincibility" bits="2" ids="No,Yes"/>
    </cheats>
```

The full MRA example is [here](https://github.com/jotego/jtcps1/blob/master/rom/mra/Eco%20Fighters%20(cheat).mra)

And that covers the basics, it may look like many concepts but if you start
with the example you will find that it is easy to modify it to add more cheats
or target other games.

Check the example for Ghouls'n Ghosts too:

* [Assembler File](cheat/ghouls.s)
* [MRA](https://github.com/jotego/jtcps1/blob/master/rom/mra/Ghouls'n%20Ghosts%20(cheat).mra)

Finally, sometimes you need to read data from the SDRAM, you can find sample
code for reading in [sf2hf.s](cheat/sf2hf.s).

```
    ; Read FF8AC2 => 304561 and check that its zero
    load  s0,0x61
    load  s1,0x45
    load  s2,0x30
    call  READ_SDRAM
    compare s7,0
    jump nz,char_select
```

This code reads the data in game address FF8AC2. The data is returned in
registers s7 and s6. Because of the M68000 endianness, the lower byte is
written in s7, and the upper in s6. Then you can perform a check on the
value and jump accordingly.