# JTHARIER

**Enduro Racer**... currently listed on eBay for over $1,000 and **Space Harrier**... not even listed. These are two boards really hard to get your hands on.

This core is based on the schematics for Space Harrier, the JTS16 and JTOUTRUN cores for parts of the graphics and sound system, and on the documentation of sprites on MAME.

The core has been worked by Chris Watson for several weeks and reviewed by Jose Tejada until it got to a rather mature state. Then finished by Jose Tejada to integrate Enduro Racer in.

You can show your appreciation through

* Patreon: https://patreon.com/jotego
* Paypal: https://paypal.me/topapate
* Github: https://github.com/sponsors/jotego

## Analog controllers

Space Harrier uses the left analog stick for its flight stick: horizontal is X
and vertical is Y.

Enduro Racer uses both analog sticks. The left stick horizontal axis steers,
and its vertical axis controls the motorcycle bank. The right stick vertical
axis is split into pedals: up accelerates and down brakes.

Hang-On uses the left stick horizontal axis to steer. The right stick vertical
axis is split into pedals: up accelerates and down brakes.

The current version only supports a dual-stick analog controller for Enduro Racer and Hang-On. That will be improved soon.

## CPU Bus Timing

Space Harrier and Enduro Racer main CPU: the IC26 LS164 shift register, clocked by the CPU clock and cleared while AS is inactive, is tapped at QB by factory jumper J2 for the program ROM: 1 wait state. Hang-On's main CPU acknowledges with AS through 4F. Both boards add VWAIT for video RAM, a board wait that the core does not recover.

These wait states were derived from the schematics and have not been checked on a PCB yet.
