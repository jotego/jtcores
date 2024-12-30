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
3style                      DrMnike                 Mick Stone
80's spaceman               Ed Balan                Mike Jegenjan
Adam Davis                  Edward Rana             Mike Parks
Alan Shurvinton             Eric J Faulkes          MiSTerFPGA.co.uk
Alonso J. Núñez             Filip Kindt             Nailbomb
Anders Rensberg             Francis B               natalie
Andrea Chiavazza            Frank Hoedemakers       Neil St Clair
Andreas Micklei             Frederic FONTANA        Nico Stamp
Andrew Ajello               Frédéric Mahé           nullobject
Andrew Boudreau             GA                      Oliver Jaksch
Andrew Francomb             Gavin                   Oliver Wndmth
Andrew Moore                Greg                    Oscar Laguna Garcia
Andy Palmer                 Gregory Val             Oskar Sigvardsson
Andyways                    Gus Douboulidis         Patrick Roman Fabri
Angelo Kanaris              Hard Rich               Paweł Mandes
Anthony Monaco              Henrik Nordström        Per Sweden
Aquijacks (Flashjacks MSX)  HFSPlay                 Phillip McMahon
Arcade Express              hyp36rmax               PsyFX
Arjan de Lang               Jeremy Kelaher          Purple Tinker
asdfgasfhsn                 Jesse Clark             RandomRetro
Ben Toman                   Jo Tomiyori             RetroDriven
ben01623                    Joeri van Dooren        Richard Eng
Bender                      Johan Smolinski         Richard Murillo
Bob Gallardo                John Casey              Richard Simpson
Brent Fraser Weatherall     Jonathan Loor           Robert Forbes
Brett T Davis               Jonathan Tuttle         Robert MacLean
brian burney                Jorge Slowfret          Roman Buser
Brian Sallee                Josiah Wilson           Ryan Fig
Carrboroman                 JPS (RetroFPGA)         Sassbasket Silvercloud
Charles                     Juan E. Gayon           Skeeter
Chi Wai Tran                Justin D'Arcangelo      Sofia Rose
Chris Jardine               Kitsuake                Spank Minister
Chris smith                 KnC                     Stephen Goldberg
Chris W Miller              Kyle Good               Steven Wilson
Christian                   Lee Osborne             Steven Yedwab
Christian Bailey            Leslie Law              Thomas Barrand
Christopher Gelatt          Lionel LENOBLE          Thomas Irwin
Christopher Harvey          Louis Martinez          Toby Boreham
cohge                       Luc JOLY                Tony Toon
Coldheat007                 Magnus Kvevlander       Trifle
Dan                         Manuel Astudillo        Ulf Skutnabba
Daniel Bauza                Marcus Hogue            Ultrarobotninja
Daniel Estreito             Matt Evans              Victor Bly
Darren Wootton              Matthew Woodford        Víctor Gomariz
David Ashby                 Matthew Young           XC-3730C
David Fleetwood             Max Schütz              Xzarian
David Jones                 Michael Deshaies        yoaarond
David Mills                 Michael Yount
Don Gafford                 Michele Zilli
```
