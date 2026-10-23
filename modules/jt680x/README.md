# JT680x MC68x0x Compatible Modules

By Jose Tejada (@topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github](https://github.com/sponsors/jotego)

## Device differences

Item           | MC6801            | MC6805          | HD6301
---------------|-------------------|-----------------|-------
Type           | MCU               | MCU             | MCU
B              | present           | absent
X/S            | 16 bits           | 8 bits
Idx addr.      | 8-bit offset      | 8/16-bit offset

## Device Usage on Arcade Games

### MC6802 profile

Select `cfg/jt6802.yaml` and define `JT680X_6802` to use the 6802 bus profile
with the shared `jt680x` controller, registers and ALU. Instantiate `jt6802`
for the physical bus wrapper. This profile exposes
E, VMA, MR, memory readiness and completed transfers. `cen` is the crystal
enable, at four times the nominal E frequency; `enable` is a host pause.
IRQ, NMI and `ext_halt` retain the family's normalized active-high convention.
An external chip-level wrapper must map physical pin polarity and RAM/RE.

The profile includes the common `680x.yaml` arithmetic sequences and overrides
addressing, stack and vector timing in YAML. The ordinary fixed-rate scheduler
advances once per accepted crystal enable; the bus wrapper holds that enable for
memory stalls. There is no second dispatch or execution scheduler. Cycle checking
is enabled, and the existing 6801/6301 generated microcode remains unchanged.
The 6802 profile uses 32-step entries; the controller uses the matching profile width.

The runtime `nsc8105` input selects opcode translation and the four derivative
operations. These extension timing/flag interpretations remain provisional.
`FC_COMPAT` defaults to zero; Seicro opts into its undocumented Frisky Tom
compatibility handling. Each build selects one microcode profile, using the
existing `6801` generated-file prefix shared with the ALU.

Run `modules/jt680x/ver/6802/sim.sh` from the repository root for Docker/Verilator
interrupt, WAI, HALT, TSX/TXS bus-address and FC-policy checks plus the 6801/6301 regressions. The
unit-simulation workflow runs this command in its MC6802 job. Generated sources,
objects and logs remain in `ver/6802/scratch/`.

See [MC6802 completion](doc/complete_6802.md) for remaining work.

### MC6800

Some games from Taito and Atari in the late 1970's used the MC6800. KONAMI's Whizz Quiz (1985) uses it too.

- cball
- destroyr
- destroyr1
- dragrace
- fgoal
- fgoala
- firetrk
- lbeach
- montecar
- orbit
- poolshrk
- proteus3
- sflush
- skydiver
- speedrs
- sprint8
- sprint8a
- superbug
- tank8
- toratora
- triplhnt
- wizzquiz

### MC6801

Two Taito titles. The MCU is referred to as PS4 in the schematics.

- bublbobl
- kicknrun

### MC6803

IREM M62 system runs on this CPU. Currently implemented on MiSTer using [Open Core's CPU68](https://github.com/MiSTer-devel/Arcade-IremM62_MiSTer/blob/master/rtl/6800/cpu68.vhd)

- 10yard
- 10yard85
- 10yardj
- alpha1v
- banctec
- battroad
- bcrusher
- bkungfu
- ddragonba
- dpb7000
- horizon
- kidniki
- kncljoe
- kungfum
- ldrun
- ldrun2
- ldrun3
- ldrun3j
- ldrun4
- ldruna
- lithero
- lotlot
- mc10
- motorace
- mototour
- mpatrol
- mranger
- newtangl
- shtrider
- spelunk2
- spelunkr
- travrusa
- troangel
- vs10yard
- yanchamr
- youjyudn

## 68705

Many Taito titles. Schematics available for


- Arkanoid
- Buggy Challenge
- The Fairy Land Story (JT schematics)


Complete list (trying not to repeat sets from the same machine driver)

- 40love
- alcon
- ark1ball
- arkanoid
- arkatour
- bballs
- bigevglf
- bking3
- bub68705
- buggychl
- bygone
- chaknpop
- changela
- cshootert
- daikaiju
- darktowr
- ddungeon
- elecyoyo
- elevator
- empcity
- fieldday
- flstory
- frontlin
- getstarj
- grdian
- hotsmash
- kikstart
- knightb
- kram
- kram2
- kuniokun
- lkage
- lsasquad
- maniach
- maniach2
- maxaflex
- maxidpkr
- megadpkr
- mexico86
- mf_achas
- mf_bdash
- mf_brist
- mf_flip
- midresb
- ncd16
- nycaptor
- onna34ro
- pbillian
- pipeline
- pitnrun
- pushman
- puzznic
- quizpun
- renegade
- retofinv
- rumba
- sdungeon
- sfposeid
- slapfigh
- solrwarr
- stfight
- tbasebal
- tigerh
- tinstar
- tokio
- topgunnr
- tstrike
- undoukai
- victnine
- wyvernf0
- xsleena
- zookeep
- zookeep3
- a2mouse

### 63701

aliensec
bakutotu
baraduke
berabohm
blastoff
blazer
boxyboy
dangseed
darktowr
ddragon
ddragonb2
ddragonu
ddragonua
ddragonub
ddragonw
ddragonw1
ddungeon
ddungeone
drgnbstr
dspirit
dspirit1
dspirit2
faceoff
galaga88
galaga88a
galaga88j
genpeitd
hopmappy
metrocrs
metrocrsa
mmaze
mmaze2
nkdodge
nkdodgeb
pacland
paclandj
paclandjo
paclandjo2
paclandm
paclandm2
pacmania
pacmaniaj
pacmaniao
pistoldm
puzlclub
quester
questers
roishtar
rompers
romperso
rthunder
rthunder0
rthunder1
rthunder2
rthundera
rvoicepc
shadowld
skykid
skykidd
skykiddx
skykiddxo
skykido
skykids
soukobdx
spdodgeb
splatter
splatter2
splatterj
tankfrce
tankfrce4
tankfrcej
tceptor
tceptor2
tstrike
tstrikea
wldcourt
wndrmomo
ws
ws89
ws90
youkaidk1
youkaidk2

### 63705

an1x
assault
assaultj
assaultp
bubbletr
bubbletrj
burnforc
burnforco
cosmogng
cosmogngj
dirtfoxj
dsaber
dsabera
dsaberj
finalap2
finalap2j
finallap
finallapc
finallapd
finallapjb
finallapjc
finehour
fourtrax
fourtraxa
fourtraxj
gollygho
kyukaidk
kyukaidko
marvland
marvlandup
metlhawk
metlhawkj
mirninja
mirninjaa
ordyne
ordynej
ordyneje
phelios
pheliosj
psr500
psu
rthun2
rthun2j
sgunner
sgunnerj
sy35
valkyrie
winrun
winrun91
winrungp
namcoc65
