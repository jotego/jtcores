# JTCORES FPGA Arcade Hardware by Jose Tejada (@topapate)

You can show your appreciation through
* [Patreon](https://patreon.com/jotego)
* [Paypal](https://paypal.me/topapate)
* [Github](https://github.com/sponsors/jotego)

Yes, you always wanted to have an arcade board at home. First you couldn't get it because your parents somehow did not understand you. Then you grow up and your wife doesn't understand you either. Don't worry, JT cores are here to the rescue.

I hope you will have as much fun with this project as I had while working on it!

# KNOWN ISSUES

If you enable flip mode and wait for the CAPCOM logo screen to appear for the second time, the animation will not be displayed correctly. This occurs because that logo is printed using two sprites right at the limit of the vertical split line (schematics 5/8). This is a genuine bug of the original hardware. The CAPCOM logo works correctly when not in flip mode.


# Higemaru

## conversion details

The conversion was done based on 1942 schematics and MAME driver for Higemaru. Based on the available
documentation, the implementation I have made is very likely to be highly accurate but I cannot confirm
it because I do not have access to the PCB nor the schematics -assuming schematics still exist for this game.

Interrupts are generated directly from the PROM and they do not occur at the same time as in MAME.
The connection for the interrupt PROM is based on 1942. Palette PROMs are also used where needed. I didn't
check the timing PROM and just assumed it was the same as all the other 8-bit CAPCOM games, which is very
likely to be the case.

## test screen

Press the action button while powering up to enter the test screen. Some text in the test screens is not
displayed correctly. I think there is one input signal which is not being provided correctly. This doesn't
seem to be a problem during gameplay.

# Patreon supporters

## 1942/Vulgus
```
    Andyways
    albconde
    Blue1597
    Bruno Silva
    Dag J.
    Darren Newman
    Don Gafford
    Ed Balan
    Fred Fryolator
    Fredrik Berglind
    Jacob Proctor
    JD
    John Klimek
    Juan Javier Rivera Lopez
    loloC2C
    Manuel Fernández
    Matt Charlesworth
    Matthew Coyne
    Michael Stegen
    PsyFX
    remowilliams
    Salvador Perugorria Lorente
    Scralings
    SmokeMonster
    Suvodip Mitra
    Víctor Gomariz Ladrón de Guevara
    Vorvek
```

## Higemaru
```
3style                      DrMnike                 Mike Jegenjan
80's spaceman               Ed Balan                Mike Parks
Adam Davis                  Edward Rana             MiSTerFPGA.co.uk
Alan Shurvinton             Eric J Faulkes          Nailbomb
Alonso J. Núñez             Filip Kindt             natalie
Anders Rensberg             Francis B               Neil St Clair
Andrea Chiavazza            Frank Hoedemakers       Nico Stamp
Andreas Micklei             Frederic FONTANA        nullobject
Andrew Ajello               Frédéric Mahé           Oliver Jaksch
Andrew Boudreau             GA                      Oliver Wndmth
Andrew Francomb             Gavin                   Oscar Laguna Garcia
Andrew Moore                Greg                    Oskar Sigvardsson
Andy Palmer                 Gregory Val             Patrick Roman Fabri
Andyways                    Gus Douboulidis         Paweł Mandes
Angelo Kanaris              Hard Rich               Per Sweden
Anthony Monaco              Henrik Nordström        Phillip McMahon
Aquijacks (Flashjacks MSX)  HFSPlay                 PsyFX
Arcade Express              hyp36rmax               Purple Tinker
Arjan de Lang               Jeremy Kelaher          RandomRetro
asdfgasfhsn                 Jesse Clark             RetroDriven
atrac17                     Jo Tomiyori             Richard Eng
Ben Toman                   Joeri van Dooren        Richard Murillo
ben01623                    Johan Smolinski         Richard Simpson
Bender                      John Casey              Robert Forbes
Bob Gallardo                Jonathan Loor           Robert MacLean
Brent Fraser Weatherall     Jonathan Tuttle         Roman Buser
Brett T Davis               Jorge Slowfret          Ryan Fig
brian burney                Josiah Wilson           Sassbasket Silvercloud
Brian Sallee                JPS (RetroFPGA)         Skeeter
Carrboroman                 Juan E. Gayon           Sofia Rose
Charles                     Justin D'Arcangelo      Spank Minister
Chi Wai Tran                Kitsuake                Stephen Goldberg
Chris Jardine               KnC                     Steven Wilson
Chris smith                 Kyle Good               Steven Yedwab
Chris W Miller              Lee Osborne             Thomas Barrand
Christian                   Leslie Law              Thomas Irwin
Christian Bailey            Lionel LENOBLE          Toby Boreham
Christopher Gelatt          Louis Martinez          Tony Toon
Christopher Harvey          Luc JOLY                Trifle
cohge                       Magnus Kvevlander       Ulf Skutnabba
Coldheat007                 Manuel Astudillo        Ultrarobotninja
Dan                         Marcus Hogue            Victor Bly
Daniel Bauza                Matt Evans              Víctor Gomariz Ladrón de Guevara
Daniel Estreito             Matthew Woodford        XC-3730C
Darren Wootton              Matthew Young           Xzarian
David Ashby                 Max Schütz              yoaarond
David Fleetwood             Michael Deshaies
David Jones                 Michael Yount
David Mills                 Michele Zilli
Don Gafford                 Mick Stone
```
